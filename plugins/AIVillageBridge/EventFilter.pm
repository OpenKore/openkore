package AIVillageBridge::EventFilter;

use strict;
use warnings;

use Log qw(message debug warning);
use Time::HiRes qw(time);

# Deduplication windows (seconds) per event type.
# Event types not present here are never deduplicated.
my %DEDUP_WINDOWS = (
    pub_msg       => 5,
    priv_msg      => 2,
    monster_exist => 1,
    player_exist  => 10,
    item_appeared => 2,
    is_casting    => 1,
);

# Priority sort order (lowest number = highest priority, dropped last from overflow)
my %PRIORITY_ORDER = (
    critical => 0,
    high     => 1,
    medium   => 2,
    low      => 3,
);

# new(%args)
# Args:
#   rate_limit     => events/sec (default 10)
#   burst_limit    => max burst tokens (default 20)
#   item_threshold => min item value in zeny (default 100)
sub new {
    my ($class, %args) = @_;

    my $rate_limit     = $args{rate_limit}     // 10;
    my $burst_limit    = $args{burst_limit}    // 20;
    my $item_threshold = $args{item_threshold} // 100;

    my $self = bless {
        rate_limit     => $rate_limit,
        burst_limit    => $burst_limit,
        item_threshold => $item_threshold,

        # Dedup state
        dedup_cache => {},   # key => last_seen_time (float)

        # Token bucket state
        tokens      => $burst_limit,   # start full
        last_refill => time(),

        # Overflow queue: arrayref of {event_type, dedup_key, priority, data, ts}
        overflow    => [],

        # Metrics counters
        metrics => {
            events_received            => 0,
            events_passed              => 0,
            events_dedup_dropped       => 0,
            events_significance_dropped => 0,
            events_rate_limited        => 0,
            events_critical_bypass     => 0,
            overflow_drained           => 0,
            overflow_expired           => 0,
        },
    }, $class;

    debug("[AIVillageBridge::EventFilter] Initialized: rate=$rate_limit/s burst=$burst_limit item_threshold=$item_threshold\n");

    return $self;
}

# should_send($event_type, $dedup_key, $priority, $data) -> 1 (send) or 0 (drop)
#
# Runs the three-stage filter pipeline:
#   1. Deduplication
#   2. Significance
#   3. Rate limiter (token bucket), with overflow queue for non-critical events
#
# Critical priority events always bypass the rate limiter.
sub should_send {
    my ($self, $event_type, $dedup_key, $priority, $data) = @_;

    $priority //= 'medium';
    $data     //= {};

    $self->{metrics}{events_received}++;

    # ------------------------------------------------------------------
    # Stage 1: Deduplication
    # ------------------------------------------------------------------
    if (exists $DEDUP_WINDOWS{$event_type}) {
        my $window    = $DEDUP_WINDOWS{$event_type};
        my $last_seen = $self->{dedup_cache}{$dedup_key};

        if (defined $last_seen && (time() - $last_seen) < $window) {
            debug("[AIVillageBridge::EventFilter] Dedup drop: type=$event_type key=$dedup_key\n");
            $self->{metrics}{events_dedup_dropped}++;
            return 0;
        }

        # Update last-seen timestamp
        $self->{dedup_cache}{$dedup_key} = time();
    }

    # ------------------------------------------------------------------
    # Stage 2: Significance check
    # ------------------------------------------------------------------
    # item_appeared: ground items are filtered by value (avoids spamming low-value drops)
    # item_gathered: value is not available from the hook args, so no significance check
    if ($event_type eq 'item_appeared') {
        my $value = $data->{value} // 0;
        if ($value < $self->{item_threshold}) {
            debug("[AIVillageBridge::EventFilter] Significance drop: type=$event_type value=$value threshold=$self->{item_threshold}\n");
            $self->{metrics}{events_significance_dropped}++;
            return 0;
        }
    }

    # ------------------------------------------------------------------
    # Stage 3: Rate limiter (token bucket)
    # ------------------------------------------------------------------

    # Critical events always pass, no token consumed
    if ($priority eq 'critical') {
        debug("[AIVillageBridge::EventFilter] Critical bypass: type=$event_type\n");
        $self->{metrics}{events_critical_bypass}++;
        $self->{metrics}{events_passed}++;
        return 1;
    }

    $self->_refill();

    if ($self->{tokens} >= 1) {
        $self->{tokens} -= 1;
        $self->{metrics}{events_passed}++;
        return 1;
    }

    # No tokens available — add to overflow queue
    $self->_enqueue_overflow($event_type, $dedup_key, $priority, $data);
    $self->{metrics}{events_rate_limited}++;
    return 0;
}

# cleanup_cache()
# Remove stale dedup entries (older than 60 s) and overflow entries (older than 5 s).
# Call periodically from the main plugin loop.
sub cleanup_cache {
    my ($self) = @_;

    my $now           = time();
    my $dedup_expiry  = 60;
    my $overflow_expiry = 5;

    # Prune dedup cache
    my $dedup_pruned = 0;
    for my $key (keys %{$self->{dedup_cache}}) {
        if (($now - $self->{dedup_cache}{$key}) >= $dedup_expiry) {
            delete $self->{dedup_cache}{$key};
            $dedup_pruned++;
        }
    }

    # Prune overflow queue
    my $before = scalar @{$self->{overflow}};
    $self->{overflow} = [
        grep { ($now - $_->{ts}) < $overflow_expiry }
        @{$self->{overflow}}
    ];
    my $overflow_pruned = $before - scalar @{$self->{overflow}};
    $self->{metrics}{overflow_expired} += $overflow_pruned;

    if ($dedup_pruned || $overflow_pruned) {
        debug("[AIVillageBridge::EventFilter] cleanup_cache: removed $dedup_pruned dedup entries, $overflow_pruned overflow entries\n");
    }
}

# get_overflow_events([$limit]) -> arrayref of event hashrefs
# Drains and returns queued overflow events for the caller to process.
# If $limit is provided, returns at most $limit events and keeps the rest queued.
# Call periodically from the main plugin loop.
sub get_overflow_events {
    my ($self, $limit) = @_;

    return [] unless @{$self->{overflow}};

    if (defined $limit && $limit > 0 && scalar @{$self->{overflow}} > $limit) {
        my @batch = splice(@{$self->{overflow}}, 0, $limit);
        $self->{metrics}{overflow_drained} += scalar(@batch);
        debug("[AIVillageBridge::EventFilter] Partial drain: returning $limit of "
            . (scalar(@batch) + scalar @{$self->{overflow}}) . " overflow events\n");
        return \@batch;
    }

    my $events = $self->{overflow};
    $self->{overflow} = [];

    $self->{metrics}{overflow_drained} += scalar(@$events);

    debug("[AIVillageBridge::EventFilter] Draining " . scalar(@$events) . " overflow events\n")
        if @$events;

    return $events;
}

# get_metrics() -> hashref (shallow copy)
sub get_metrics {
    my ($self) = @_;
    return { %{$self->{metrics}} };
}

# reset_metrics()
sub reset_metrics {
    my ($self) = @_;
    $self->{metrics}{$_} = 0 for keys %{$self->{metrics}};
}

# _refill()
# Restock token bucket based on elapsed time since last refill.
sub _refill {
    my ($self) = @_;

    my $now     = time();
    my $elapsed = $now - $self->{last_refill};

    $self->{tokens} += $elapsed * $self->{rate_limit};
    $self->{tokens}  = $self->{burst_limit}
        if $self->{tokens} > $self->{burst_limit};

    $self->{last_refill} = $now;
}

# _enqueue_overflow($event_type, $dedup_key, $priority, $data)
# Adds an event to the overflow queue. If the queue exceeds 100 entries,
# the lowest-priority events are dropped to make room.
sub _enqueue_overflow {
    my ($self, $event_type, $dedup_key, $priority, $data) = @_;

    push @{$self->{overflow}}, {
        event_type => $event_type,
        dedup_key  => $dedup_key,
        priority   => $priority,
        data       => $data,
        ts         => time(),
    };

    # Cap at 100 entries: sort by priority (worst first) and trim from the tail
    if (scalar @{$self->{overflow}} > 100) {
        # Sort so lowest-priority (highest numeric value) are at the end
        $self->{overflow} = [
            sort {
                ($PRIORITY_ORDER{$a->{priority}} // 99)
                    <=>
                ($PRIORITY_ORDER{$b->{priority}} // 99)
            }
            @{$self->{overflow}}
        ];
        # Trim excess from the tail (lowest priority)
        my $dropped = scalar(@{$self->{overflow}}) - 100;
        splice @{$self->{overflow}}, 100;
        warning("[AIVillageBridge::EventFilter] Overflow queue full: dropped $dropped low-priority events\n");
    }
}

1;
