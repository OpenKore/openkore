package LastROActivity::Scheduler;

use strict;
use warnings;
use utf8;

sub new {
	my ($class, %args) = @_;

	my $lead_seconds = exists $args{lead_seconds} ? $args{lead_seconds} : 10;
	$lead_seconds = 10 if !_is_number($lead_seconds) || $lead_seconds < 0;

	my $clock = $args{clock};
	$clock = sub { time } if !defined $clock;
	die 'clock must be a coderef' if ref($clock) ne 'CODE';

	return bless {
		lead_seconds => $lead_seconds,
		clock => $clock,
		timers => {},
		revision => 0,
	}, $class;
}

sub parse_countdown {
	my ($message) = @_;
	return undef if !defined $message;

	my $seconds = 0;
	my $found = 0;
	while ($message =~ /([0-9]+)\s*(小时|小時|时|分钟?|秒钟?)/g) {
		my ($amount, $unit) = ($1, $2);
		$found = 1;
		if ($unit eq '小时' || $unit eq '小時' || $unit eq '时') {
			$seconds += $amount * 60 * 60;
		} elsif ($unit eq '分钟' || $unit eq '分') {
			$seconds += $amount * 60;
		} else {
			$seconds += $amount;
		}
	}

	return $found ? $seconds : undef;
}

sub extract_data_map {
	my ($message) = @_;
	return undef if !defined $message;

	if ($message =~ /data-map\s*=\s*(['"])([^\s#'"]+)#([0-9]+)#([0-9]+)\1/) {
		return {
			map => $2,
			x => 0 + $3,
			y => 0 + $4,
		};
	}

	return undef;
}

sub observe {
	my ($self, $rule, $message, $received_at) = @_;
	return undef if ref($rule) ne 'HASH';
	return undef if !_enabled($rule->{enabled});
	return undef if !defined $rule->{event_id} || $rule->{event_id} eq '';

	$received_at = $self->{clock}->() if !defined $received_at;
	return undef if !_is_number($received_at);
	return undef if !_matches($message, $rule->{announce_regex});
	# A countdown only supplies timing.  The explicit start pattern remains the
	# evidence that this particular server line is allowed to arm the rule.
	return undef if !_matches($message, $rule->{start_regex});

	my $countdown = parse_countdown($message);
	if (!defined $countdown) {
		$countdown = 0;
	}

	my $start_at = $received_at + $countdown;
	my $lead_seconds = exists $rule->{lead_seconds}
		? $rule->{lead_seconds}
		: $self->{lead_seconds};
	$lead_seconds = $self->{lead_seconds}
		if !_is_number($lead_seconds) || $lead_seconds < 0;

	my $trigger_at = $start_at - $lead_seconds;
	$trigger_at = $received_at if $trigger_at < $received_at;

	$self->{revision}++;
	my $event = {
		event_id => $rule->{event_id},
		rule => $rule,
		message => $message,
		received_at => $received_at,
		countdown_seconds => $countdown,
		start_at => $start_at,
		trigger_at => $trigger_at,
		lead_seconds => $lead_seconds,
		priority => _priority($rule->{priority}),
		revision => $self->{revision},
		revision_at => $received_at,
		dispatched => 0,
	};

	if (defined $rule->{map_source} && lc($rule->{map_source}) eq 'dynamic') {
		my $data_map = extract_data_map($message);
		$event->{data_map} = $data_map if defined $data_map;
	}

	$self->{timers}{$rule->{event_id}} = $event;
	return $event;
}

sub due {
	my ($self, $now) = @_;
	$now = $self->{clock}->() if !defined $now;
	return [] if !_is_number($now);

	my @due = grep {
		!$_->{dispatched} && $_->{trigger_at} <= $now
	} values %{$self->{timers}};

	@due = sort {
		$a->{start_at} <=> $b->{start_at}
			|| $b->{priority} <=> $a->{priority}
			|| $a->{event_id} cmp $b->{event_id}
			|| $a->{revision} <=> $b->{revision}
	} @due;

	$_->{dispatched} = 1 for @due;
	return \@due;
}

sub cancel {
	my ($self, $event_id) = @_;
	return 0 if !defined $event_id || !exists $self->{timers}{$event_id};
	delete $self->{timers}{$event_id};
	return 1;
}

sub clear {
	my ($self) = @_;
	$self->{timers} = {};
	return 1;
}

sub events {
	my ($self) = @_;
	return { %{$self->{timers}} };
}

sub _enabled {
	my ($enabled) = @_;
	return defined $enabled && $enabled =~ /^\s*1\s*\z/;
}

sub _is_number {
	my ($value) = @_;
	return defined $value && $value =~ /^\s*[+-]?(?:\d+(?:\.\d*)?|\.\d+)\s*\z/;
}

sub _matches {
	my ($message, $pattern) = @_;
	return 0 if !defined $message || !defined $pattern || $pattern eq '';

	my $matched = eval {
		ref($pattern) eq 'Regexp' ? $message =~ $pattern : $message =~ /$pattern/;
	};
	return $matched ? 1 : 0;
}

sub _priority {
	my ($priority) = @_;
	return 0 if !_is_number($priority);
	return 0 + $priority;
}

1;
