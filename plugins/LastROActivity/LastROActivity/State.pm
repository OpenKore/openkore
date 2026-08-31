package LastROActivity::State;

use strict;
use warnings;

my @CONFIG_KEYS = qw(
	lockMap
	lockMap_x
	lockMap_y
	lockMap_randX
	lockMap_randY
	teleportAuto_search
	teleportAuto_idle
	route_randomWalk
	attackAuto
	itemsTakeAuto
	itemsGatherAuto
);

my %TRANSITIONS = (
	IDLE => {
		arm  => 'ARMED',
		fail => 'FAILED',
	},
	ARMED => {
		trigger => 'INTERRUPTING',
		fail    => 'FAILED',
	},
	INTERRUPTING => {
		snapshot => 'SNAPSHOTTED',
		fail     => 'FAILED',
	},
	SNAPSHOTTED => {
		depart => 'DEPARTING',
		fail   => 'FAILED',
	},
	DEPARTING => {
		enter => 'ENTERING',
		fail  => 'FAILED',
	},
	ENTERING => {
		running => 'RUNNING',
		fail    => 'FAILED',
	},
	RUNNING => {
		finish => 'FINISHING',
		fail   => 'FAILED',
	},
	FINISHING => {
		return => 'RETURNING',
		fail   => 'FAILED',
	},
	RETURNING => {
		resume => 'RESUMED',
		fail   => 'FAILED',
	},
	RESUMED => {},
	FAILED  => {},
);

sub new {
	my ($class) = @_;
	return bless {state => 'IDLE'}, $class;
}

sub state {
	my ($self) = @_;
	return $self->{state};
}

sub transition {
	my ($self, $event) = @_;
	my $current = $self->{state};
	my $next = defined $event && exists $TRANSITIONS{$current}
		? $TRANSITIONS{$current}{$event}
		: undef;

	if (!defined $next) {
		my $event_name = defined $event ? $event : '<undef>';
		die "invalid transition from $current via $event_name\n";
	}

	$self->{state} = $next;
	return $next;
}

sub snapshot_config {
	my ($config) = @_;
	_die_unless_hashref($config, 'config');

	my (%values, %present);
	for my $key (@CONFIG_KEYS) {
		$present{$key} = exists $config->{$key} ? 1 : 0;
		$values{$key} = $config->{$key};
	}

	return {
		values  => \%values,
		present => \%present,
	};
}

sub apply_activity_config {
	my ($config, $search_idle, $combat_mode, $activity) = @_;
	my $old_snapshot = snapshot_config($config);

	$config->{lockMap} = '';
	if (_is_normal_combat_mode($combat_mode)) {
		$config->{teleportAuto_search} = 0;
		$config->{teleportAuto_idle} = 1;
		$config->{route_randomWalk} = 1;
		if (_is_dojo_activity($activity)) {
			$config->{attackAuto} = 2;
			$config->{itemsTakeAuto} = 2;
			$config->{itemsGatherAuto} = 2;
		}
	} else {
		$config->{teleportAuto_search} = 1;
		$config->{teleportAuto_idle} = $search_idle;
	}

	return $old_snapshot;
}

sub restore_config {
	my ($config, $snapshot) = @_;
	_die_unless_hashref($config, 'config');
	_die_unless_hashref($snapshot, 'snapshot');
	_die_unless_hashref($snapshot->{values}, 'snapshot values');
	_die_unless_hashref($snapshot->{present}, 'snapshot presence');

	for my $key (@CONFIG_KEYS) {
		if ($snapshot->{present}{$key}) {
			$config->{$key} = $snapshot->{values}{$key};
		} else {
			delete $config->{$key};
		}
	}

	return $config;
}

sub _die_unless_hashref {
	my ($value, $name) = @_;
	die "$name must be a hash reference" if ref($value) ne 'HASH';
}

sub _is_normal_combat_mode {
	my ($combat_mode) = @_;
	if (ref($combat_mode) eq 'HASH') {
		$combat_mode = $combat_mode->{combat_mode};
	}
	return defined $combat_mode
		&& !ref($combat_mode)
		&& $combat_mode =~ /^\s*normal\s*$/i;
}

sub _is_dojo_activity {
	my ($activity) = @_;
	return lc($activity->{entry_dialog_mode} || '') eq 'dojo'
		if ref($activity) eq 'HASH';
	return defined $activity && !ref($activity)
		&& $activity =~ /^dojo_challenge$/i;
}

1;
