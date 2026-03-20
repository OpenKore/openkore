package edenPortalExitSync;

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

sub _updateFromEdenExit {
	my ($newMap) = @_;
	return unless _isValidEdenExitMap($newMap);

	my $destID = _resolveExitDestinationForPosition($newMap);
	return unless $destID;

	_setEdenPortalExit(_configValueForDestination($destID), "left Eden through the exit portal");
}

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

sub _normalizeMap {
	my ($map) = @_;
	return unless defined $map && $map ne '';

	($map, undef) = Field::nameToBaseName(undef, $map);
	return lc $map;
}

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

sub _configValueForDestination {
	my ($destID) = @_;
	return unless $destID;

	my ($map) = split / /, $destID, 2;
	$map = lc $map;

	my $counts = _destinationMapCounts();
	return $destID if ($counts->{$map} || 0) > 1;
	return $map;
}

sub _setEdenPortalExit {
	my ($value, $reason) = @_;
	return unless defined $value && $value ne '';
	return if defined $config{EdenPortalExit} && $config{EdenPortalExit} eq $value;

	warning TF("[edenPortalExitSync] Updating EdenPortalExit to '%s' (%s).\n", $value, $reason), "plugin";
	configModify('EdenPortalExit', $value);
}

return 1;
