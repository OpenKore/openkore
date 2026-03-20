package edenPortalExitSync;

# Plugin: edenPortalExitSync
# Author: henrybk
#
# Keeps config.txt -> EdenPortalExit synchronized with real Eden Group travel.
#
# How to configure:
# 1. Enable this plugin.
# 2. Keep the dynamic Eden exit portals marked with [EdenPortalExit] in portals.txt.
# 3. Add the config key in config.txt:
#    EdenPortalExit prontera
#    The plugin will keep this value updated automatically.
#
# How it works:
# - When a routed TalkNPC warp sends the character into moc_para01, the plugin
#   reads the current Task::MapRoute step and saves the source city as the
#   EdenPortalExit value.
# - When the character leaves moc_para01 through the exit portal, the plugin
#   checks the map and landing position that was actually reached and updates
#   EdenPortalExit if the configured value was wrong.
# - The valid exit destinations come from the dynamic portal group generated
#   from portals.txt, so the plugin stays aligned with the portal table.
#
# Notes:
# - Unique destinations are stored as just the map name, like "prontera".
# - Ambiguous destinations with multiple exits on the same map are stored as a
#   full destination id, like "que_ng 33 63".

use strict;

use Plugins;
use Globals qw(%config $char $field);
use Misc qw(configModify getDynamicPortalDestinations);
use AI;
use Field;
use Log qw(warning);
use Translation qw(TF);

Plugins::register(
	'edenPortalExitSync',
	'Keeps EdenPortalExit aligned with Eden Group travel',
	\&onUnload
);

my $hooks = Plugins::addHooks(
	['Network::Receive::map_changed', \&onMapChanged, undef],
);

sub onUnload {
	Plugins::delHooks($hooks);
}

# Track both entering and leaving Eden from map change events.
sub onMapChanged {
	my (undef, $args) = @_;
	return unless $field;

	my $oldMap = _normalizeMap($args->{oldMap});
	my $newMap = _normalizeMap($field->baseName);
	return unless $newMap;

	if ($newMap eq 'moc_para01') {
		_updateFromEdenArrival($oldMap);
	} elsif ($oldMap eq 'moc_para01') {
		_updateFromEdenExit($newMap);
	}
}

# Save the city we used to enter Eden when the current route step is the NPC warp.
sub _updateFromEdenArrival {
	my ($oldMap) = @_;
	return unless $oldMap;

	my $task = _getActiveMapRouteTask();
	return unless $task;

	my $subtask = eval { $task->getSubtask() };
	return unless $subtask && eval { $subtask->isa('Task::TalkNPC') };

	my $step = $task->{mapSolution}[0];
	return unless $step && $step->{steps};
	return unless $step->{portal};

	my ($from, $to) = split /=/, $step->{portal}, 2;
	return unless defined $from && defined $to;

	my ($fromMap) = split / /, $from, 2;
	my ($toMap) = split / /, $to, 2;
	$fromMap = _normalizeMap($fromMap);
	$toMap = _normalizeMap($toMap);

	return unless $toMap eq 'moc_para01';
	return unless $fromMap eq $oldMap;
	return unless _isValidEdenExitMap($fromMap);

	my $destID = _resolveExitDestinationForSource($from);
	return unless $destID;

	_setEdenPortalExit(_configValueForDestination($destID), "entered Eden from $fromMap");
}

# Correct the configured exit when the actual post-Eden destination differs.
sub _updateFromEdenExit {
	my ($newMap) = @_;
	return unless _isValidEdenExitMap($newMap);

	my $destID = _resolveExitDestinationForPosition($newMap);
	return unless $destID;

	_setEdenPortalExit(_configValueForDestination($destID), "left Eden through the exit portal");
}

# Reuse the active Task::MapRoute so we only sync during intentional routed travel.
sub _getActiveMapRouteTask {
	foreach my $action (qw(route mapRoute)) {
		my $index = AI::findAction($action);
		next unless defined $index;

		my $task = AI::args($index);
		next unless $task;
		next unless eval { $task->isa('Task::MapRoute') };

		return $task;
	}

	return;
}

sub _getEdenExitDestinations {
	return getDynamicPortalDestinations('EdenPortalExit');
}

# Normalize aliases like prontera.gat or instance names down to a base map name.
sub _normalizeMap {
	my ($map) = @_;
	return unless defined $map && $map ne '';

	($map, undef) = Field::nameToBaseName(undef, $map);
	return lc $map;
}

# Destination lookup helpers.
sub _destinationMapCounts {
	my %counts;

	foreach my $destID (keys %{_getEdenExitDestinations()}) {
		my ($map) = split / /, $destID, 2;
		$counts{lc $map}++;
	}

	return \%counts;
}

sub _getDestinationsForMap {
	my ($map) = @_;
	return unless $map;

	my @matches = grep {
		my ($destMap) = split / /, $_, 2;
		lc($destMap) eq $map;
	} keys %{_getEdenExitDestinations()};

	return @matches;
}

sub _isValidEdenExitMap {
	my ($map) = @_;
	return scalar _getDestinationsForMap($map);
}

# Resolve the most likely Eden exit entry for the source city that sent us in.
sub _resolveExitDestinationForSource {
	my ($sourceID) = @_;
	return unless $sourceID;

	my $destinations = _getEdenExitDestinations();
	return $sourceID if exists $destinations->{$sourceID};

	my ($map, $x, $y) = split / /, $sourceID, 3;
	$map = lc($map || '');
	return unless $map;

	my @matches = _getDestinationsForMap($map);
	return unless @matches;
	return $matches[0] if @matches == 1;

	if (defined $x && defined $y && $x =~ /^\d+$/ && $y =~ /^\d+$/) {
		@matches = sort {
			my (undef, $ax, $ay) = split / /, $a, 3;
			my (undef, $bx, $by) = split / /, $b, 3;
			(abs($ax - $x) + abs($ay - $y)) <=> (abs($bx - $x) + abs($by - $y))
		} @matches;
	}

	return $matches[0];
}

# Resolve the exit entry we actually landed on after leaving Eden.
sub _resolveExitDestinationForPosition {
	my ($map) = @_;
	return unless $map && $char;

	my $pos = $char->{pos_to} || $char->{pos};
	return unless $pos && defined $pos->{x} && defined $pos->{y};

	my $exact = join(' ', $map, $pos->{x}, $pos->{y});
	my $destinations = _getEdenExitDestinations();
	return $exact if exists $destinations->{$exact};

	my @matches = _getDestinationsForMap($map);
	return unless @matches;
	return $matches[0] if @matches == 1;

	@matches = sort {
		my (undef, $ax, $ay) = split / /, $a, 3;
		my (undef, $bx, $by) = split / /, $b, 3;
		(abs($ax - $pos->{x}) + abs($ay - $pos->{y})) <=> (abs($bx - $pos->{x}) + abs($by - $pos->{y}))
	} @matches;

	return $matches[0];
}

# Use plain map names when unique, otherwise store the full destination ID.
sub _configValueForDestination {
	my ($destID) = @_;
	return unless $destID;

	my ($map) = split / /, $destID, 2;
	$map = lc $map;

	my $counts = _destinationMapCounts();
	return $destID if ($counts->{$map} || 0) > 1;
	return $map;
}

# Write the config only when the effective value really changed.
sub _setEdenPortalExit {
	my ($value, $reason) = @_;
	return unless defined $value && $value ne '';
	return if defined $config{EdenPortalExit} && $config{EdenPortalExit} eq $value;

	warning TF("[edenPortalExitSync] Updating EdenPortalExit to '%s' (%s).\n", $value, $reason), "plugin";
	configModify('EdenPortalExit', $value);
}

return 1;
