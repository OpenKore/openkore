package AIVillageBridge::NoveltyDetector;

use strict;
use warnings;

use Log qw(message debug warning);
use Time::HiRes qw(time);

# Event types that are always escalated to the sidecar, regardless of familiarity.
my %ALWAYS_ESCALATE = map { $_ => 1 } qw(
    self_died
    base_level_changed
    job_level_changed
    party_invite
    incoming_deal
);

# How many entries to keep per context hash before we cap and evict the oldest.
use constant MAX_CONTEXT_ENTRIES => 1000;

# Context entry expiry: entries not seen for this many seconds are pruned.
use constant CONTEXT_TTL => 3600;

# new(%args)
# Args:
#   player_familiar_threshold  => encounters before player is "familiar" (default 5)
#   monster_familiar_threshold => kills before monster type is "routine"  (default 10)
#   map_familiar_threshold     => visits before map is "known"            (default 3)
#   npc_familiar_threshold     => interactions before NPC is "known"      (default 2)
sub new {
    my ($class, %args) = @_;

    my $self = bless {
        player_familiar_threshold  => $args{player_familiar_threshold}  // 5,
        monster_familiar_threshold => $args{monster_familiar_threshold} // 10,
        map_familiar_threshold     => $args{map_familiar_threshold}     // 3,
        npc_familiar_threshold     => $args{npc_familiar_threshold}     // 2,

        # Ruleset: {version => ..., generated_at => ..., rules => [...]}
        ruleset => { version => 0, generated_at => 0, rules => [] },

        # Context tracking hashes
        seen_players     => {},   # player_name => {count, first_seen, last_seen}
        seen_monsters    => {},   # "type:map"  => {count, first_seen, last_killed}
        visited_maps     => {},   # map_name    => {count, first_visit, last_visit}
        npc_interactions => {},   # "id:map"    => {count, last_interaction}

        # Metrics counters
        metrics => {
            events_analyzed              => 0,
            events_escalated             => 0,
            events_local                 => 0,
            events_ignored               => 0,
            events_pickup                => 0,
            events_flee                  => 0,
            always_escalations           => 0,
            first_occurrence_escalations => 0,
            unfamiliar_escalations       => 0,
            social_escalations           => 0,
            chat_resp_local              => 0,
            ruleset_matches              => 0,
        },
    }, $class;

    debug("[AIVillageBridge::NoveltyDetector] Initialized with thresholds: "
        . "player=$self->{player_familiar_threshold} "
        . "monster=$self->{monster_familiar_threshold} "
        . "map=$self->{map_familiar_threshold} "
        . "npc=$self->{npc_familiar_threshold}\n");

    return $self;
}

# analyze($event_type, $data) -> action hashref
#
# Runs the five-step decision tree and returns one of:
#   {action => 'send'}
#   {action => 'local', command => {...}}
#   {action => 'ignore'}
#   {action => 'pickup', item_id => $id}
#   {action => 'flee'}
sub analyze {
    my ($self, $event_type, $data) = @_;

    $data //= {};

    $self->{metrics}{events_analyzed}++;

    # ------------------------------------------------------------------
    # Step 1: Always-escalate events
    # ------------------------------------------------------------------
    if ($ALWAYS_ESCALATE{$event_type}) {
        debug("[AIVillageBridge::NoveltyDetector] Always-escalate: $event_type\n");
        $self->{metrics}{always_escalations}++;
        $self->{metrics}{events_escalated}++;
        return { action => 'send' };
    }

    # ------------------------------------------------------------------
    # Step 1b: Chat-response patterns (pub_msg / priv_msg only)
    # If a pattern matches, return a local 'say' command so the bot responds
    # without escalating to the sidecar.
    # ------------------------------------------------------------------
    if ($event_type eq 'pub_msg' || $event_type eq 'priv_msg') {
        my $patterns = $self->{chat_resp_patterns} // [];
        my $msg_text = $data->{msg} // $data->{message} // '';
        my $sender   = $data->{user} // '';

        for my $p (@$patterns) {
            next unless defined $p->{pattern} && length($p->{pattern});
            next unless defined $p->{response} && length($p->{response});

            # Type filter: 'pub' matches pub_msg, 'priv' matches priv_msg
            my $pat_type = $p->{type} // 'pub';
            next if $pat_type eq 'pub'  && $event_type ne 'pub_msg';
            next if $pat_type eq 'priv' && $event_type ne 'priv_msg';

            # Optional sender filter
            if (length($p->{from} // '')) {
                next unless $sender eq $p->{from};
            }

            my $matched = 0;
            eval { $matched = 1 if $msg_text =~ /$p->{pattern}/i };
            # Ignore regex compile errors silently
            next unless $matched;

            debug("[AIVillageBridge::NoveltyDetector] chat_resp match: pattern=$p->{pattern}\n");
            $self->{metrics}{chat_resp_local}++;
            $self->{metrics}{events_local}++;
            return {
                action  => 'local',
                command => {
                    type    => 'command',
                    command => 'say',
                    params  => { message => $p->{response} },
                },
            };
        }
    }

    # ------------------------------------------------------------------
    # Step 2: Ruleset match
    # ------------------------------------------------------------------
    my $rules = $self->{ruleset}{rules} // [];
    for my $rule (@$rules) {
        next unless defined $rule->{event} && $rule->{event} eq $event_type;
        next unless $self->_matches($rule->{match}, $data);

        my $action_def  = $rule->{action} // {};
        my $action_type = $action_def->{type} // '';

        $self->{metrics}{ruleset_matches}++;

        if ($action_type eq 'escalate') {
            debug("[AIVillageBridge::NoveltyDetector] Ruleset escalate: $event_type\n");
            $self->{metrics}{events_escalated}++;
            return { action => 'send' };
        }
        elsif ($action_type eq 'respond' || $action_type eq 'attack') {
            debug("[AIVillageBridge::NoveltyDetector] Ruleset local ($action_type): $event_type\n");
            $self->{metrics}{events_local}++;
            return { action => 'local', command => $action_def };
        }
        elsif ($action_type eq 'ignore') {
            debug("[AIVillageBridge::NoveltyDetector] Ruleset ignore: $event_type\n");
            $self->{metrics}{events_ignored}++;
            return { action => 'ignore' };
        }
        elsif ($action_type eq 'pickup') {
            debug("[AIVillageBridge::NoveltyDetector] Ruleset pickup: $event_type item=$data->{id}\n");
            $self->{metrics}{events_pickup}++;
            return { action => 'pickup', item_id => $data->{id} };
        }
        elsif ($action_type eq 'flee') {
            debug("[AIVillageBridge::NoveltyDetector] Ruleset flee: $event_type\n");
            $self->{metrics}{events_flee}++;
            return { action => 'flee' };
        }
    }

    # ------------------------------------------------------------------
    # Step 3: First-occurrence check
    # ------------------------------------------------------------------
    {
        my $now = time();

        if ($event_type eq 'pub_msg' || $event_type eq 'priv_msg') {
            my $player = $data->{user} // $data->{player} // '';
            if ($player && !exists $self->{seen_players}{$player}) {
                debug("[AIVillageBridge::NoveltyDetector] First msg from $player: send\n");
                $self->_init_player($player, $now);
                $self->{metrics}{first_occurrence_escalations}++;
                $self->{metrics}{events_escalated}++;
                return { action => 'send' };
            }
        }
        elsif ($event_type eq 'map_changed') {
            my $map = $data->{map} // '';
            if ($map && !exists $self->{visited_maps}{$map}) {
                debug("[AIVillageBridge::NoveltyDetector] First visit to map $map: send\n");
                $self->_init_map($map, $now);
                $self->{metrics}{first_occurrence_escalations}++;
                $self->{metrics}{events_escalated}++;
                return { action => 'send' };
            }
        }
        elsif ($event_type eq 'player_exist') {
            my $player = $data->{name} // '';
            if ($player && !exists $self->{seen_players}{$player}) {
                debug("[AIVillageBridge::NoveltyDetector] First sighting of player $player: send\n");
                $self->_init_player($player, $now);
                $self->{metrics}{first_occurrence_escalations}++;
                $self->{metrics}{events_escalated}++;
                return { action => 'send' };
            }
        }
        elsif ($event_type eq 'monster_exist') {
            my $type = $data->{name} // $data->{type} // '';
            my $map  = $data->{map}  // '';
            my $key  = "$type:$map";
            if ($type && !exists $self->{seen_monsters}{$key}) {
                debug("[AIVillageBridge::NoveltyDetector] First sighting of monster $key: send\n");
                $self->_init_monster($key, $now);
                $self->{metrics}{first_occurrence_escalations}++;
                $self->{metrics}{events_escalated}++;
                return { action => 'send' };
            }
        }
        elsif ($event_type eq 'npc_talk') {
            my $npc_id = $data->{id}  // '';
            my $map    = $data->{map} // '';
            my $key    = "$npc_id:$map";
            if ($npc_id && !exists $self->{npc_interactions}{$key}) {
                debug("[AIVillageBridge::NoveltyDetector] First NPC interaction $key: send\n");
                $self->_init_npc($key, $now);
                $self->{metrics}{first_occurrence_escalations}++;
                $self->{metrics}{events_escalated}++;
                return { action => 'send' };
            }
        }
    }

    # ------------------------------------------------------------------
    # Step 4: Familiarity check
    # ------------------------------------------------------------------
    {
        if ($event_type eq 'pub_msg' || $event_type eq 'priv_msg') {
            my $player = $data->{user} // $data->{player} // '';
            if ($player && exists $self->{seen_players}{$player}) {
                if ($self->{seen_players}{$player}{count} <= $self->{player_familiar_threshold}) {
                    debug("[AIVillageBridge::NoveltyDetector] Unfamiliar player $player (count=$self->{seen_players}{$player}{count}): send\n");
                    $self->{metrics}{unfamiliar_escalations}++;
                    $self->{metrics}{events_escalated}++;
                    return { action => 'send' };
                }
            }
        }
        elsif ($event_type eq 'player_exist') {
            my $player = $data->{name} // '';
            if ($player && exists $self->{seen_players}{$player}) {
                if ($self->{seen_players}{$player}{count} <= $self->{player_familiar_threshold}) {
                    debug("[AIVillageBridge::NoveltyDetector] Unfamiliar player_exist $player: send\n");
                    $self->{metrics}{unfamiliar_escalations}++;
                    $self->{metrics}{events_escalated}++;
                    return { action => 'send' };
                }
            }
        }
        elsif ($event_type eq 'monster_exist') {
            my $type = $data->{name} // $data->{type} // '';
            my $map  = $data->{map}  // '';
            my $key  = "$type:$map";
            if (exists $self->{seen_monsters}{$key}) {
                if ($self->{seen_monsters}{$key}{count} <= $self->{monster_familiar_threshold}) {
                    debug("[AIVillageBridge::NoveltyDetector] Unfamiliar monster $key: send\n");
                    $self->{metrics}{unfamiliar_escalations}++;
                    $self->{metrics}{events_escalated}++;
                    return { action => 'send' };
                }
            }
        }
        elsif ($event_type eq 'target_died') {
            my $type = $data->{name} // $data->{type} // '';
            my $map  = $data->{map}  // '';
            my $key  = "$type:$map";
            if (exists $self->{seen_monsters}{$key}) {
                if ($self->{seen_monsters}{$key}{count} <= $self->{monster_familiar_threshold}) {
                    debug("[AIVillageBridge::NoveltyDetector] Unfamiliar kill $key: send\n");
                    $self->{metrics}{unfamiliar_escalations}++;
                    $self->{metrics}{events_escalated}++;
                    return { action => 'send' };
                }
            }
        }
        elsif ($event_type eq 'map_changed') {
            my $map = $data->{map} // '';
            if ($map && exists $self->{visited_maps}{$map}) {
                if ($self->{visited_maps}{$map}{count} <= $self->{map_familiar_threshold}) {
                    debug("[AIVillageBridge::NoveltyDetector] Unfamiliar map $map: send\n");
                    $self->{metrics}{unfamiliar_escalations}++;
                    $self->{metrics}{events_escalated}++;
                    return { action => 'send' };
                }
            }
        }
        elsif ($event_type eq 'npc_talk') {
            my $npc_id = $data->{id}  // '';
            my $map    = $data->{map} // '';
            my $key    = "$npc_id:$map";
            if (exists $self->{npc_interactions}{$key}) {
                if ($self->{npc_interactions}{$key}{count} <= $self->{npc_familiar_threshold}) {
                    debug("[AIVillageBridge::NoveltyDetector] Unfamiliar NPC $key: send\n");
                    $self->{metrics}{unfamiliar_escalations}++;
                    $self->{metrics}{events_escalated}++;
                    return { action => 'send' };
                }
            }
        }
    }

    # ------------------------------------------------------------------
    # Step 4.5: Social events — always escalate if no rule matched
    # Chat messages are inherently novel in content even from familiar players.
    # ------------------------------------------------------------------
    if ($event_type eq 'pub_msg' || $event_type eq 'priv_msg') {
        debug("[AIVillageBridge::NoveltyDetector] Social escalate (no rule matched): $event_type\n");
        $self->{metrics}{social_escalations}++;
        $self->{metrics}{events_escalated}++;
        return { action => 'send' };
    }

    # ------------------------------------------------------------------
    # Step 5: Default — let OpenKore's native AI handle it
    # ------------------------------------------------------------------
    debug("[AIVillageBridge::NoveltyDetector] Default ignore: $event_type\n");
    $self->{metrics}{events_ignored}++;
    return { action => 'ignore' };
}

# track_player($player_name)
# Increments the encounter count for a player.
sub track_player {
    my ($self, $player_name) = @_;
    return unless defined $player_name && $player_name ne '';

    my $now = time();
    if (!exists $self->{seen_players}{$player_name}) {
        $self->_init_player($player_name, $now);
    }
    else {
        $self->{seen_players}{$player_name}{count}++;
        $self->{seen_players}{$player_name}{last_seen} = $now;
    }
}

# track_monster_kill($monster_type, $map)
# Increments the kill count for a monster type on a specific map.
sub track_monster_kill {
    my ($self, $monster_type, $map) = @_;
    return unless defined $monster_type && $monster_type ne '';

    $map //= '';
    my $key = "$monster_type:$map";
    my $now = time();

    if (!exists $self->{seen_monsters}{$key}) {
        $self->_init_monster($key, $now);
    }
    else {
        $self->{seen_monsters}{$key}{count}++;
        $self->{seen_monsters}{$key}{last_killed} = $now;
    }
}

# track_map_visit($map_name)
# Increments the visit count for a map.
sub track_map_visit {
    my ($self, $map_name) = @_;
    return unless defined $map_name && $map_name ne '';

    my $now = time();
    if (!exists $self->{visited_maps}{$map_name}) {
        $self->_init_map($map_name, $now);
    }
    else {
        $self->{visited_maps}{$map_name}{count}++;
        $self->{visited_maps}{$map_name}{last_visit} = $now;
    }
}

# track_npc($npc_id, $map)
# Increments the interaction count for a specific NPC on a map.
sub track_npc {
    my ($self, $npc_id, $map) = @_;
    return unless defined $npc_id && $npc_id ne '';

    $map //= '';
    my $key = "$npc_id:$map";
    my $now = time();

    if (!exists $self->{npc_interactions}{$key}) {
        $self->_init_npc($key, $now);
    }
    else {
        $self->{npc_interactions}{$key}{count}++;
        $self->{npc_interactions}{$key}{last_interaction} = $now;
    }
}

# set_ruleset($ruleset_hashref)
# Replaces the active ruleset. Logs version and generation timestamp.
sub set_ruleset {
    my ($self, $ruleset) = @_;

    unless (defined $ruleset && ref($ruleset) eq 'HASH') {
        warning("[AIVillageBridge::NoveltyDetector] set_ruleset() called with invalid argument\n");
        return;
    }

    $ruleset->{rules} //= [];
    $self->{ruleset} = $ruleset;

    my $version      = $ruleset->{version}      // 'unknown';
    my $generated_at = $ruleset->{generated_at} // 'unknown';
    message("[AIVillageBridge::NoveltyDetector] Loaded ruleset v$version generated_at $generated_at\n");
}

# ruleset_version() -> scalar
# Returns the version field of the currently loaded ruleset.
sub ruleset_version {
    my ($self) = @_;
    return $self->{ruleset}{version} // 0;
}

# cleanup_context()
# Prunes stale context entries (TTL = 1 hour) and caps each hash at 1000 entries.
# Call periodically (every ~5 minutes) from the main plugin loop.
sub cleanup_context {
    my ($self) = @_;

    my $now     = time();
    my $expiry  = CONTEXT_TTL;
    my $max     = MAX_CONTEXT_ENTRIES;

    $self->{seen_players}     = _prune_hash($self->{seen_players},     $now, $expiry, $max, 'last_seen');
    $self->{seen_monsters}    = _prune_hash($self->{seen_monsters},    $now, $expiry, $max, 'last_killed');
    $self->{visited_maps}     = _prune_hash($self->{visited_maps},     $now, $expiry, $max, 'last_visit');
    $self->{npc_interactions} = _prune_hash($self->{npc_interactions}, $now, $expiry, $max, 'last_interaction');

    debug("[AIVillageBridge::NoveltyDetector] cleanup_context done: "
        . "players=" . scalar(keys %{$self->{seen_players}}) . " "
        . "monsters=" . scalar(keys %{$self->{seen_monsters}}) . " "
        . "maps=" . scalar(keys %{$self->{visited_maps}}) . " "
        . "npcs=" . scalar(keys %{$self->{npc_interactions}}) . "\n");
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

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

# _matches($match_rule, $data) -> 1 or 0
# Evaluates a single match rule against an event data hashref.
sub _matches {
    my ($self, $match_rule, $data) = @_;

    return 1 unless defined $match_rule && ref($match_rule) eq 'HASH';

    # {any => 1} — unconditional match
    return 1 if $match_rule->{any};

    # {contains => $str, case_insensitive => 0/1}
    if (exists $match_rule->{contains}) {
        my $needle  = $match_rule->{contains};
        my $haystack = $data->{msg} // $data->{message} // '';
        if ($match_rule->{case_insensitive}) {
            return 0 unless index(lc($haystack), lc($needle)) >= 0;
        }
        else {
            return 0 unless index($haystack, $needle) >= 0;
        }
    }

    # {from_player => $name, any_content => 1}
    if (exists $match_rule->{from_player}) {
        my $expected = $match_rule->{from_player};
        my $actual   = $data->{user} // $data->{player} // '';
        return 0 unless $actual eq $expected;
        # any_content => 1 means we don't care about the message body — already matched
    }

    # {monster_name => $name}
    if (exists $match_rule->{monster_name}) {
        my $expected = $match_rule->{monster_name};
        my $actual   = $data->{name} // '';
        return 0 unless $actual eq $expected;
    }

    # {item_name => $name}
    if (exists $match_rule->{item_name}) {
        my $expected = $match_rule->{item_name};
        my $actual   = $data->{name} // $data->{item} // '';
        return 0 unless $actual eq $expected;
    }

    return 1;
}

# _init_player($name, $now)
sub _init_player {
    my ($self, $name, $now) = @_;
    $self->{seen_players}{$name} = {
        count      => 1,
        first_seen => $now,
        last_seen  => $now,
    };
}

# _init_monster($key, $now)  — key is "type:map"
sub _init_monster {
    my ($self, $key, $now) = @_;
    $self->{seen_monsters}{$key} = {
        count       => 1,
        first_seen  => $now,
        last_killed => $now,
    };
}

# _init_map($name, $now)
sub _init_map {
    my ($self, $name, $now) = @_;
    $self->{visited_maps}{$name} = {
        count       => 1,
        first_visit => $now,
        last_visit  => $now,
    };
}

# _init_npc($key, $now)  — key is "id:map"
sub _init_npc {
    my ($self, $key, $now) = @_;
    $self->{npc_interactions}{$key} = {
        count            => 1,
        last_interaction => $now,
    };
}

# _prune_hash($href, $now, $expiry_secs, $max_entries, $time_field) -> new hashref
# Removes entries not updated within $expiry_secs. If still over $max_entries,
# evicts the oldest entries (by $time_field) until within the cap.
sub _prune_hash {
    my ($href, $now, $expiry, $max, $time_field) = @_;

    # First pass: TTL eviction
    my %pruned = map  { $_ => $href->{$_} }
                 grep { ($now - ($href->{$_}{$time_field} // 0)) < $expiry }
                 keys %$href;

    # Second pass: cap at $max entries, drop oldest by $time_field
    if (scalar(keys %pruned) > $max) {
        my @sorted = sort {
            ($pruned{$a}{$time_field} // 0) <=> ($pruned{$b}{$time_field} // 0)
        } keys %pruned;

        my $to_drop = scalar(@sorted) - $max;
        delete @pruned{ @sorted[0 .. $to_drop - 1] };
    }

    return \%pruned;
}

1;
