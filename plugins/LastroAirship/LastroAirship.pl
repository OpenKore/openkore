package LastroAirship;

use strict;
use warnings;
use Time::HiRes qw(time);
use Scalar::Util qw(weaken refaddr);

use AI;
use Commands ();
use Globals qw(%config $char $field $masterServer $messageSender %portals_lut %maps_lut);
use Lastro::Airship qw(
	isEnabled normalizeMapName chooseRouteMap choosePreRouteMap
	normalizeAirshipRequestName resolveMapAliasCandidates
);
use Log qw(debug warning message);
use Plugins;
use Settings;
use Task::MapRoute ();

use constant DEFAULT_TIMEOUT => 5;

Plugins::register(
	'LastroAirship',
	'Uses Lastro free world-map transfers before and during cross-map routing and resolves client map aliases',
	\&onUnload
);

my $freeMaps = {};
my $freeMapsFile;
my $pendingTask;
my $manualAlias;
my $originalInitMapCalculator;
my $originalPrivateAirshipCallback;
my $hooks = Plugins::addHooks(
	['MapRoute_iterate_start', \&onMapRouteIterateStart, undef],
	['Network::Receive::map_changed', \&onMapChanged, undef],
	['lastro_airship_result', \&onAirshipResult, undef],
	['mainLoop_pre', \&onMainLoopPre, undef],
);

sub onUnload {
	_restorePrivateAirshipInterceptor();
	_restoreMapRouteInterceptor();
	$manualAlias = undef;
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

# Manual privateairship commands may use the client-side resource name shown by
# LastRO (for example force_map3) instead of a logical map known by the server.
# Keep the stock Commands implementation for real map names and only intercept
# aliases that can be resolved backwards through resnametable.txt.
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

sub _sendManualAliasCandidate {
	return 0 unless $manualAlias && $messageSender;

	my $index = $manualAlias->{index};
	my $map = $manualAlias->{candidates}[$index];
	return 0 unless defined $map && $map ne '';

	my $itemID = $manualAlias->{item_id};
	$char->{last_private_airship_item} = $itemID if $char;
	$char->{last_private_airship_map} = $map if $char;
	$messageSender->sendPrivateAirshipRequest($map, $itemID);
	$manualAlias->{map} = $map;
	$manualAlias->{sent_at} = time;
	$manualAlias->{accepted} = 0;

	my $number = $index + 1;
	my $total = scalar @{$manualAlias->{candidates}};
	message "[LastroAirship] Alias '$manualAlias->{requested}' -> trying logical map $map ($number/$total).\n", 'info';
	return 1;
}

sub _advanceManualAlias {
	my ($reason) = @_;
	return 0 unless $manualAlias;

	my $failed = $manualAlias->{map};
	$manualAlias->{index}++;
	if ($manualAlias->{index} >= @{$manualAlias->{candidates}}) {
		my $requested = $manualAlias->{requested};
		$manualAlias = undef;
		warning "[LastroAirship] No logical map candidate for alias '$requested' was accepted; last attempt $failed $reason.\n";
		return 0;
	}

	my $next = $manualAlias->{candidates}[$manualAlias->{index}];
	warning "[LastroAirship] Alias candidate $failed $reason; trying $next.\n";
	return _sendManualAliasCandidate();
}

sub _cmdPrivateAirship {
	my ($switch, $args) = @_;
	return _delegatePrivateAirship(@_) unless isEnabled($masterServer);

	my ($map, $itemID) = defined $args
		? ($args =~ /^\s*(\S+)(?:\s+(\S+))?\s*$/)
		: ();
	return _delegatePrivateAirship(@_) unless defined $map && $map ne '';

	my $requested = normalizeAirshipRequestName($map);
	return _delegatePrivateAirship(@_)
		if $requested eq '' || defined $maps_lut{"$requested.rsw"};

	my $resnametable = Settings::getTableFilename('resnametable.txt');
	my $candidates = resolveMapAliasCandidates($map, \%maps_lut, $resnametable);
	return _delegatePrivateAirship(@_) unless @{$candidates};

	my @usable = grep { length($_) <= 16 } @{$candidates};
	unless (@usable) {
		warning "[LastroAirship] Alias '$requested' resolves only to map names longer than the 16-byte Private Airship limit.\n";
		return;
	}

	my $requiredItemID = $masterServer->{privateAirshipItemID} || 14527;
	return _delegatePrivateAirship(@_)
		if defined $itemID && ($itemID !~ /^\d+$/ || $itemID != $requiredItemID);

	if ($pendingTask && $pendingTask->{lastro_airship_pending}) {
		warning "[LastroAirship] A route airship transfer is already pending; try the manual alias command again after it finishes.\n";
		return;
	}

	if ($manualAlias) {
		warning "[LastroAirship] Replacing the previous pending map-alias transfer request.\n";
	}

	$manualAlias = {
		requested => $requested,
		candidates => \@usable,
		index => 0,
		item_id => $requiredItemID,
	};
	_sendManualAliasCandidate();
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
	if ($manualAlias && $field) {
		my $current = normalizeMapName($field->baseName);
		if ($manualAlias->{map} && $current eq $manualAlias->{map}) {
			debug "[LastroAirship] Alias '$manualAlias->{requested}' resolved successfully to $current.\n", 'lastro_airship';
			$manualAlias = undef;
		}
	}

	return unless $pendingTask && $pendingTask->{lastro_airship_pending} && $field;

	my $pending = $pendingTask->{lastro_airship_pending};
	if (normalizeMapName($field->baseName) eq $pending->{map}) {
		$pendingTask->{lastro_airship_arrived} = 1;
	}
}

sub onAirshipResult {
	my (undef, $args) = @_;
	return unless defined $args->{type};

	if ($manualAlias) {
		my $type = $args->{type};
		if ($type == 0) {
			# Packet acceptance is not enough; wait for the actual map change.
			$manualAlias->{accepted} = 1;
			$manualAlias->{sent_at} = time;
		} elsif ($type == 3) {
			# Destination map invalid: this is the expected failure when a client
			# resource alias maps to several server-side copies. Try the next copy.
			_advanceManualAlias('was rejected as an invalid destination');
		} else {
			my $requested = $manualAlias->{requested};
			$manualAlias = undef;
			warning "[LastroAirship] Alias transfer '$requested' stopped after Private Airship result $type; this error is not destination-specific.\n";
		}
		return;
	}

	return unless $pendingTask && $pendingTask->{lastro_airship_pending};
	$pendingTask->{lastro_airship_failed} = $args->{type} if $args->{type} != 0;
}

sub onMainLoopPre {
	_installPrivateAirshipInterceptor();
	return unless $manualAlias && $manualAlias->{sent_at};
	return if time - $manualAlias->{sent_at} < _timeout();

	_advanceManualAlias('timed out');
}

_installMapRouteInterceptor();
_installPrivateAirshipInterceptor();

1;
