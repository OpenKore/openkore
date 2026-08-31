package LastroAirship;

use strict;
use warnings;
use Time::HiRes qw(time);
use Scalar::Util qw(weaken refaddr);

use AI;
use Commands ();
use Globals qw(%config $char $field $masterServer $messageSender %portals_lut %maps_lut);
use I18N qw(stringToBytes);
use Lastro::Airship qw(isEnabled normalizeMapName chooseRouteMap choosePreRouteMap);
use Log qw(debug error warning message);
use Plugins;
use Settings;
use Task::MapRoute ();

use constant DEFAULT_TIMEOUT => 5;

Plugins::register(
	'LastroAirship',
	'Uses Lastro free world-map transfers and allows Lastro raw Private Airship map names',
	\&onUnload
);

my $freeMaps = {};
my $freeMapsFile;
my $pendingTask;
my $originalInitMapCalculator;
my $originalPrivateAirshipCallback;
my $commands = Commands::register(
	['tt', 'tt <map> [x y [item_id]] - LastRO coordinate teleport', \&_cmdTeleport],
);
my $hooks = Plugins::addHooks(
	['MapRoute_iterate_start', \&onMapRouteIterateStart, undef],
	['Network::Receive::map_changed', \&onMapChanged, undef],
	['lastro_airship_result', \&onAirshipResult, undef],
	['mainLoop_pre', \&onMainLoopPre, undef],
);

sub onUnload {
	Commands::unregister($commands) if $commands;
	_restorePrivateAirshipInterceptor();
	_restoreMapRouteInterceptor();
	Plugins::delHooks($hooks);
}

sub _enabled {
	return isEnabled($masterServer) && (!defined $config{lastro_airshipRoute} || $config{lastro_airshipRoute});
}

sub _trim {
	my ($value) = @_;
	$value = '' unless defined $value;
	$value =~ s/^\s+|\s+$//g;
	return $value;
}

sub _cmdTeleport {
	my ($switch, $args) = @_;
	my @parts = grep { length } split /\s+/, _trim($args);
	unless (@parts == 1 || @parts == 3 || @parts == 4) {
		error "Usage: tt <map> [x y [item_id]]\n";
		return;
	}

	my ($map, $x, $y, $item_id) = @parts;
	$map = normalizeMapName($map);
	if ($map eq '' || length(stringToBytes($map)) > 16) {
		error "tt map name must fit the LastRO Private Airship Z16 field.\n";
		return;
	}

	my $type = @parts == 1 ? 0 : 1;
	if ($type) {
		unless ($x =~ /^\d+$/ && $x <= 65535 && $y =~ /^\d+$/ && $y <= 65535) {
			error "tt coordinates must be unsigned 16-bit integers.\n";
			return;
		}
	} else {
		$x = 0;
		$y = 0;
	}

	$item_id = 14527 unless defined $item_id;
	unless ($item_id =~ /^\d+$/ && $item_id > 0 && $item_id <= 4294967295) {
		error "tt item ID must be an unsigned 32-bit integer greater than zero.\n";
		return;
	}

	unless (isEnabled($masterServer)) {
		error "tt is available only for the configured LastRO server.\n";
		return;
	}
	unless ($messageSender && $messageSender->can('sendPrivateAirshipRequest')) {
		error "tt is unavailable for the active server type.\n";
		return;
	}

	$messageSender->sendPrivateAirshipRequest($map, $item_id, $x, $y, $type);
	message "[LastroAirship] Requested LastRO coordinate transfer to $map.\n", 'info';
	return;
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

	if ($map eq $currentMap) {
		$task->{lastro_airship_used} = 1;
		debug "[LastroAirship] Already on best free gateway $map; using normal route from here.\n", 'lastro_airship';
		return 0;
	}

	return _requestTransfer($task, $map, 'before normal map-route calculation') ? 1 : 0;
}

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

# Commands.pm normally rejects destinations that are not present in maps.txt
# before the packet reaches the server. Lastro's browser can use resource map
# names such as force_map3 that intentionally do not exist in maps.txt. For
# those names only, bypass the local LUT check and send the exact normalized
# map name in the server-specific 0A49 Z16 field.
sub _installPrivateAirshipInterceptor {
	my $entry = $Commands::commands{privateairship};
	return unless ref($entry) eq 'HASH' && ref($entry->{callback}) eq 'CODE';

	my $ours = \&_cmdPrivateAirship;
	if (!$originalPrivateAirshipCallback) {
		return if refaddr($entry->{callback}) == refaddr($ours);
		$originalPrivateAirshipCallback = $entry->{callback};
	}

	$entry->{callback} = $ours
		unless refaddr($entry->{callback}) == refaddr($ours);
}

sub _restorePrivateAirshipInterceptor {
	return unless $originalPrivateAirshipCallback;

	my $entry = $Commands::commands{privateairship};
	if (ref($entry) eq 'HASH' && ref($entry->{callback}) eq 'CODE'
		&& refaddr($entry->{callback}) == refaddr(\&_cmdPrivateAirship)) {
		$entry->{callback} = $originalPrivateAirshipCallback;
	}
	$originalPrivateAirshipCallback = undef;
}

sub _delegatePrivateAirship {
	return unless $originalPrivateAirshipCallback;
	return $originalPrivateAirshipCallback->(@_);
}

sub _cmdPrivateAirship {
	my ($switch, $args) = @_;
	return _delegatePrivateAirship(@_) unless isEnabled($masterServer);

	my ($map, $itemID) = defined $args
		? ($args =~ /^\s*(\S+)(?:\s+(\S+))?\s*$/)
		: ();
	return _delegatePrivateAirship(@_) unless defined $map && $map ne '';

	my $requested = normalizeMapName($map);
	return _delegatePrivateAirship(@_)
		if $requested eq '' || defined $maps_lut{"$requested.rsw"};

	my $requiredItemID = $masterServer->{privateAirshipItemID} || 14527;
	return _delegatePrivateAirship(@_)
		if defined $itemID && ($itemID !~ /^\d+$/ || $itemID != $requiredItemID);

	if (length($requested) > 16) {
		warning "[LastroAirship] Map name '$requested' is too long for the Lastro Private Airship Z16 field (maximum 16 characters).\n";
		return;
	}

	if ($pendingTask && $pendingTask->{lastro_airship_pending}) {
		warning "[LastroAirship] A route airship transfer is already pending; try the manual command again after it finishes.\n";
		return;
	}

	return _delegatePrivateAirship(@_) unless $messageSender;

	$char->{last_private_airship_item} = $requiredItemID if $char;
	$char->{last_private_airship_map} = $requested if $char;
	$messageSender->sendPrivateAirshipRequest($requested, $requiredItemID);
	message "[LastroAirship] Requested Lastro raw map transfer to $requested.\n", 'info';
	return;
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

	$pendingTask->{lastro_airship_failed} = $args->{type} if $args->{type} != 0;
}

sub onMainLoopPre {
	_installPrivateAirshipInterceptor();
}

_installMapRouteInterceptor();
_installPrivateAirshipInterceptor();

1;
