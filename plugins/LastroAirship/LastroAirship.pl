package LastroAirship;

use strict;
use warnings;
use Time::HiRes qw(time);
use Scalar::Util qw(weaken);

use AI;
use Globals qw(%config $char $field $masterServer $messageSender %portals_lut);
use Lastro::Airship qw(isEnabled normalizeMapName chooseRouteMap choosePreRouteMap);
use Log qw(debug warning);
use Plugins;
use Settings;
use Task::MapRoute ();

use constant DEFAULT_TIMEOUT => 5;

Plugins::register(
	'LastroAirship',
	'Uses Lastro free world-map transfers before and during cross-map routing',
	\&onUnload
);

my $freeMaps = {};
my $freeMapsFile;
my $pendingTask;
my $originalInitMapCalculator;
my $hooks = Plugins::addHooks(
	['MapRoute_iterate_start', \&onMapRouteIterateStart, undef],
	['Network::Receive::map_changed', \&onMapChanged, undef],
	['lastro_airship_result', \&onAirshipResult, undef],
);

sub onUnload {
	_restoreMapRouteInterceptor();
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

sub _requestTransfer {
	my ($task, $map, $context) = @_;
	return 0 unless $task && $map && $messageSender;

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

	$context ||= 'cross-map route';
	debug "[LastroAirship] Requested free world-map transfer to $map ($context).\n", 'lastro_airship';
	return 1;
}

sub _preMapRouteCalculation {
	my ($task) = @_;
	return 0 unless _enabled;
	return 0 unless $task && eval { $task->isa('Task::MapRoute') };
	return 0 if $task->{lastro_airship_used};
	return 1 if $task->{lastro_airship_pending};
	return 0 unless $field && $task->{dest} && $task->{dest}{map};

	my $currentMap = normalizeMapName($field->baseName);
	my $map = choosePreRouteMap(
		$task->{dest}{map},
		$currentMap,
		_freeMaps(),
		\%portals_lut,
	);
	return 0 unless $map;

	# If the best free gateway is already the current map, there is no reason
	# to teleport to ourselves. Let OpenKore calculate only the remaining route
	# from this map.
	if ($map eq $currentMap) {
		$task->{lastro_airship_used} = 1;
		debug "[LastroAirship] Already on best free gateway $map; using normal route from here.\n", 'lastro_airship';
		return 0;
	}

	return _requestTransfer($task, $map, 'before normal map-route calculation') ? 1 : 0;
}

# MapRoute currently starts CalcMapRoute from activate(), before the existing
# MapRoute_iterate_start plugin hook can run. Intercept initMapCalculator so
# LastRO's free private-airship layer gets first chance to move the character.
# The original method is restored when the plugin unloads.
sub _installMapRouteInterceptor {
	return if $originalInitMapCalculator;

	$originalInitMapCalculator = \&Task::MapRoute::initMapCalculator;
	no warnings 'redefine';
	*Task::MapRoute::initMapCalculator = sub {
		my @args = @_;
		return if _preMapRouteCalculation($args[0]);
		return $originalInitMapCalculator->(@args);
	};
}

sub _restoreMapRouteInterceptor {
	return unless $originalInitMapCalculator;

	no warnings 'redefine';
	*Task::MapRoute::initMapCalculator = $originalInitMapCalculator;
	$originalInitMapCalculator = undef;
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

	# Secondary optimization: if pre-routing could not find a gateway but the
	# native route calculator did find a solution, keep the old behavior and
	# skip the longest possible prefix of that route.
	return unless $task->{mapSolution} && @{$task->{mapSolution}};
	my $map = chooseRouteMap(
		$task->{mapSolution},
		$field ? $field->baseName : '',
		_freeMaps(),
		$task->{dest}{map},
	);
	return unless $map;

	if (_requestTransfer($task, $map, 'after native route solution')) {
		$args->{return} = 1;
	}
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

_installMapRouteInterceptor();

1;
