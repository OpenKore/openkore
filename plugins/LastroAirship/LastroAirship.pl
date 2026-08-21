package LastroAirship;

use strict;
use warnings;
use Time::HiRes qw(time);
use Scalar::Util qw(weaken);

use AI;
use Globals qw(%config $char $field $masterServer $messageSender);
use Lastro::Airship qw(isEnabled normalizeMapName chooseRouteMap);
use Log qw(debug warning);
use Plugins;
use Settings;

use constant DEFAULT_TIMEOUT => 5;

Plugins::register(
	'LastroAirship',
	'Uses Lastro free world-map transfers for cross-map routing',
	\&onUnload
);

my $freeMaps = {};
my $freeMapsFile;
my $pendingTask;
my $hooks = Plugins::addHooks(
	['MapRoute_iterate_start', \&onMapRouteIterateStart, undef],
	['Network::Receive::map_changed', \&onMapChanged, undef],
	['lastro_airship_result', \&onAirshipResult, undef],
);

sub onUnload {
	Plugins::delHooks($hooks);
}

sub _enabled {
	return isEnabled($masterServer) && (!defined $config{lastro_airshipRoute} || $config{lastro_airshipRoute});
}

sub _freeMaps {
	my $file = Settings::getTableFilename('lastro_airship_free_maps.txt');
	return $freeMaps unless defined $file;
	return $freeMaps if defined $freeMapsFile && $freeMapsFile eq $file;

	my %maps;
	if (open my $handle, '<', $file) {
		while (my $line = <$handle>) {
			$line =~ s/\r?\n\z//;
			$line =~ s/#.*\z//;
			$line =~ s/^\s+|\s+\z//g;
			next if $line eq '';
			$maps{normalizeMapName($line)} = 1;
		}
		close $handle;
	} else {
		warning "[LastroAirship] Cannot read $file: $!\n";
	}

	$freeMaps = \%maps;
	$freeMapsFile = $file;
	return $freeMaps;
}

sub _timeout {
	my $timeout = $config{lastro_airshipRoute_timeout};
	$timeout = DEFAULT_TIMEOUT unless defined $timeout && $timeout =~ /^\d+(?:\.\d+)?$/;
	return $timeout > 0 ? $timeout : DEFAULT_TIMEOUT;
}

sub _clearPending {
	my ($task) = @_;
	delete $task->{lastro_airship_pending};
	delete $task->{lastro_airship_failed};
	delete $task->{lastro_airship_arrived};
}

sub onMapRouteIterateStart {
	my (undef, $args) = @_;
	return unless _enabled;

	my $task = $args->{args};
	return unless $task && eval { $task->isa('Task::MapRoute') };
	return if $task->{lastro_airship_used};

	my $pending = $task->{lastro_airship_pending};
	if ($pending) {
		if ($task->{lastro_airship_arrived}) {
			$task->{lastro_airship_used} = 1;
			_clearPending($task);
			$task->initMapCalculator();
			$args->{return} = 1;
			return;
		}

		if ($task->{lastro_airship_failed} || time - $pending->{sent_at} >= _timeout()) {
			$task->{lastro_airship_used} = 1;
			my $reason = $task->{lastro_airship_failed}
				? 'server rejected the transfer'
				: 'transfer timed out';
			_clearPending($task);
			warning "[LastroAirship] $reason; continuing normal route.\n";
			return;
		}

		$args->{return} = 1;
		return;
	}

	return unless $task->{mapSolution} && @{$task->{mapSolution}};
	my $map = chooseRouteMap(
		$task->{mapSolution},
		$field ? $field->baseName : '',
		_freeMaps(),
		$task->{dest}{map},
	);
	return unless $map;

	my $itemID = $masterServer->{privateAirshipItemID} || 14527;
	$char->{last_private_airship_item} = $itemID if $char;
	$char->{last_private_airship_map} = $map if $char;
	$messageSender->sendPrivateAirshipRequest($map, $itemID);
	$task->{lastro_airship_pending} = {
		map => $map,
		sent_at => time,
	};
	$pendingTask = $task;
	weaken($pendingTask);
	debug "[LastroAirship] Requested free world-map transfer to $map.\n", 'lastro_airship';
	$args->{return} = 1;
}

sub onMapChanged {
	return unless $pendingTask && $pendingTask->{lastro_airship_pending} && $field;

	my $pending = $pendingTask->{lastro_airship_pending};
	if (normalizeMapName($field->baseName) eq $pending->{map}) {
		$pendingTask->{lastro_airship_arrived} = 1;
	}
}

sub onAirshipResult {
	my (undef, $args) = @_;
	return unless $pendingTask && $pendingTask->{lastro_airship_pending};
	return unless defined $args->{type};

	# Result 0 is accepted; success is only finalized after the actual map change.
	$pendingTask->{lastro_airship_failed} = $args->{type} if $args->{type} != 0;
}

1;
