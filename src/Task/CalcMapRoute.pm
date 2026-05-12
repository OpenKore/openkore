#########################################################################
#  OpenKore - Calculation of inter-map routes
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This task calculates a route between different maps. When the calculation
# is successfully completed, the result can be retrieved with
# $task->getRoute() or $task->getRouteString().
#
# Note that this task only performs calculation. The MapRoute task is
# responsible for actually walking from a map to another.
package Task::CalcMapRoute;

use strict;
use Time::HiRes qw(time);

use Modules 'register';
use Task;
use base qw(Task);
use Task::Route;
use Field;
use Globals qw(%config $field %portals_lut %portals_los %timeout $char %routeWeights %portals_commands %portals_spawns %portals_airships %teleport_items);
use Translation qw(T TF);
use Log qw(debug warning error);
use Misc qw(
	canUseTeleport
	hasMapCoords
	isRoutePointDefined
	isRoutePointReachableOnField
	isRouteSourceRemoved
	itemNameSimple
);
use Utils qw(timeConvert timeOut);
use Utils::Exceptions;
use Utils::DataStructures qw(hashSafeGetValue);

# Stage constants.
use constant {
	INITIALIZE => 1,
	CALCULATE_ROUTE => 2
};

# Error constants.
use enum qw(
	CANNOT_LOAD_FIELD
	CANNOT_CALCULATE_ROUTE
);


##
# Task::CalcMapRoute->new(options...)
#
# Create a new Task::CalcMapRoute object. The following options are allowed:
# `l
# - All options allowed for Task->new()
# - targets - An arrayref of hashrefs, each of which must contain "map", "x", "y" keys. The
#             path to the closest target will be calculated and returned.
#   - map (required) - The map you want to go to, for example "prontera".
#   - x, y - The coordinate on the destination map you want to walk to. On some maps this is
#            important because they're split by a river. Depending on which side of the river
#            you want to be, the route may be different.
# - sourceMap - The map you're coming from. If not specified, the current map
#               (where the character is) is assumed.
# - sourceX and sourceY - The source position where you're coming from. If not specified,
#                         the character's current position is assumed.
# - budget - The maximum amount of money you want to spend on walking the route (Kapra
#            teleport service requires money).
# - maxTime - The maximum time to spend on calculation. If not specified,
#             $timeout{ai_route_calcRoute}{timeout} is assumed.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	if ( $args{map} && !$args{targets} ) {
		$args{targets} = [ { map => $args{map}, x => $args{x}, y => $args{y} } ];
	}

	if ( !$args{targets} || ref $args{targets} ne 'ARRAY' || !@{ $args{targets} } ) {
		ArgumentException->throw( error => "Invalid arguments." );
	}

	$self->{source}{field} = defined($args{sourceMap}) ? Field->new(name => $args{sourceMap}) : $field;
	$self->{source}{map} = $self->{source}{field}->baseName;
	$self->{source}{x} = defined($args{sourceX}) ? $args{sourceX} : $char->{pos_to}{x};
	$self->{source}{y} = defined($args{sourceY}) ? $args{sourceY} : $char->{pos_to}{y};
	$self->{targets} = [map { { %$_ } } @{ $args{targets} }];
	$_->{map} = ( Field::nameToBaseName( undef, $_->{map} ) )[0] foreach @{ $self->{targets} };
	if ($args{budget} ne '') {
		$self->{budget} = $args{budget};
	} elsif ($config{route_maxWarpFee} ne '') {
		if ($config{route_maxWarpFee} > $char->{zeny}) {
			$self->{budget} = $char->{zeny};
		} else {
			$self->{budget} = $config{route_maxWarpFee};
		}
	} else {
		$self->{budget} = $char->{zeny};
	}

	for my $flag (qw(noGoCommand noTeleSpawn noWarpItem noAirship)) {
		$self->{$flag} = exists $args{$flag} ? $args{$flag} : 0;
	}
	$self->{noGoCommandMaps} = $args{noGoCommandMaps} || {};
	$self->{noTeleSpawnMaps} = $args{noTeleSpawnMaps} || {};
	$self->{noWarpItemMaps} = $args{noWarpItemMaps} || {};
	$self->{noWarpItemIDs} = $args{noWarpItemIDs} || {};

	$self->{maxTime} = $args{maxTime} || $timeout{ai_route_calcRoute}{timeout};

	my $tickets;
	if ($char && eval { $char->inventory }) {
		$tickets = $char->inventory->getByNameID(7060);
	}
	$self->{tickets_amount} = $tickets ? $tickets->{amount} : 0;

	$self->{stage} = INITIALIZE;
	$self->{openlist} = {};
	$self->{closelist} = {};
	$self->{mapSolution} = [];
	$self->{solution} = [];
	$self->{suppressDebug} = $args{suppressDebug} ? 1 : 0;
	$self->{routeWeightCache} = {
		PORTAL        => defined $routeWeights{PORTAL} ? $routeWeights{PORTAL} : 20,
		NPC           => defined $routeWeights{NPC} ? $routeWeights{NPC} : 200,
		COMMAND       => defined $routeWeights{COMMAND} ? $routeWeights{COMMAND} : 20,
		WARPTOSAVEMAP => defined $routeWeights{WARPTOSAVEMAP} ? $routeWeights{WARPTOSAVEMAP} : 200,
		AIRSHIP       => defined $routeWeights{AIRSHIP} ? $routeWeights{AIRSHIP} : 200,
		WARPITEM      => defined $routeWeights{WARPITEM} ? $routeWeights{WARPITEM} : 80,
		ZENY          => defined $routeWeights{ZENY} ? $routeWeights{ZENY} : 0.1,
		TICKET        => defined $routeWeights{TICKET} ? $routeWeights{TICKET} : 100,
	};
	$self->{mapRouteWeightCache} = {};

	return $self;
}

sub canUseTeleportInRouteContext {
	return $char && eval { $char->inventory } ? canUseTeleport(2) : 0;
}

sub shouldLogDebug {
	my ($self) = @_;
	return !$self->{suppressDebug};
}

sub getRouteWeight {
	my ($self, $key) = @_;
	return $self->{routeWeightCache}{$key};
}

sub getMapRouteWeight {
	my ($self, $map) = @_;
	return 0 unless defined $map && $map ne '';
	return $self->{mapRouteWeightCache}{$map} if exists $self->{mapRouteWeightCache}{$map};
	my $key = lc $map;
	return $self->{mapRouteWeightCache}{$key} if exists $self->{mapRouteWeightCache}{$key};
	return $self->{mapRouteWeightCache}{$key} = int($routeWeights{$key} || 0);
}

sub getAccumulatedZeny {
	my ($self, $baseCost) = @_;
	return ($baseCost && ref($baseCost) eq 'HASH' && defined $baseCost->{zeny}) ? $baseCost->{zeny} : 0;
}

sub getAccumulatedTickets {
	my ($self, $baseCost) = @_;
	return ($baseCost && ref($baseCost) eq 'HASH' && defined $baseCost->{amount_of_tickets_used}) ? $baseCost->{amount_of_tickets_used} : 0;
}

sub buildRouteValue {
	my ($self, %args) = @_;
	my $baseCost = $args{baseCost};
	my $extraWalk = defined $args{extraWalk} ? $args{extraWalk} : 0;
	my $extraZeny = defined $args{extraZeny} ? $args{extraZeny} : 0;
	my $extraTickets = defined $args{extraTickets} ? $args{extraTickets} : 0;
	my $extraMapWeight = defined $args{extraMapWeight} ? $args{extraMapWeight} : 0;

	my $baseWalk = ($baseCost && ref($baseCost) eq 'HASH' && defined $baseCost->{walk}) ? $baseCost->{walk} : 0;
	my $zeny = $self->getAccumulatedZeny($baseCost) + $extraZeny;
	my $amount_of_tickets_used = $self->getAccumulatedTickets($baseCost) + $extraTickets;
	my $walk = $baseWalk + $extraWalk
		+ $extraMapWeight
		+ ($extraZeny * $self->getRouteWeight('ZENY'))
		+ ($extraTickets * $self->getRouteWeight('TICKET'));

	my $value = {
		type => $args{type},
		walk => $walk,
		zeny => $zeny,
		amount_of_tickets_used => $amount_of_tickets_used,
		blockedPortalGroups => defined $args{blockedPortalGroups}
			? $args{blockedPortalGroups}
			: $self->cloneBlockedPortalGroups($baseCost),
	};

	$value->{parent} = $args{parent} if exists $args{parent};
	$value->{allow_ticket} = $args{allow_ticket} if exists $args{allow_ticket};
	return $value;
}

sub getPortalStepCost {
	my ($self, $baseCost, $entry) = @_;
	my $useTicket = $entry->{allow_ticket} && $self->{tickets_amount} > $self->getAccumulatedTickets($baseCost);
	return (
		$useTicket ? 0 : ($entry->{cost} || 0),
		$useTicket ? 1 : 0,
	);
}

sub cloneRouteTargets {
	my ($self) = @_;
	return unless ($self->{targets} && ref($self->{targets}) eq 'ARRAY');
	return [map {{ map => $_->{map}, x => $_->{x}, y => $_->{y} }} @{$self->{targets}}];
}

sub runCalcMapRouteSubtask {
	my ($self, %args) = @_;
	my $task = Task::CalcMapRoute->new(%args);
	$task->activate();
	$task->iterate() while ($task->getStatus() != Task::DONE);
	return $task;
}

sub getRouteTailWalk {
	my ($self, $task) = @_;
	return undef unless $task;
	my $route = $task->getRoute();
	return ($route && @{$route}) ? $route->[-1]{walk} : undef;
}

sub getDirectWalkDistance {
	my ($self, $map, $source, $target) = @_;
	return 0 unless ($source && $target);
	return 0 unless (defined $map && $map ne '');
	return 0 unless hasMapCoords($target);

	my $routeField = ($self->{source}{field} && $self->{source}{map} eq $map)
		? $self->{source}{field}
		: eval { Field->new(name => $map) };
	if ($@ || !$routeField) {
		return undef;
	}

	my @solution;
	return Task::Route->getRoute(\@solution, $routeField, $source, $target)
		? scalar(@solution)
		: undef;
}

sub hasTargetOnMap {
	my ($self, $map) = @_;
	return 0 unless (defined $map && $map ne '');
	return 0 unless ($self->{targets} && ref($self->{targets}) eq 'ARRAY');
	return scalar grep { $_ && defined $_->{map} && $_->{map} eq $map } @{$self->{targets}};
}

sub getCompletedTaskRouteCost {
	my ($self, $task, $source) = @_;
	return undef unless $task;

	my $routeWalk = $self->getRouteTailWalk($task);
	return $routeWalk if defined $routeWalk;

	my $target = $task->{target};
	return undef unless ($target && ref($target) eq 'HASH');
	return 0 unless (defined $target->{map} && defined $source->{map} && $target->{map} eq $source->{map});

	my $directWalk = $self->getDirectWalkDistance($source->{map}, $source, $target);
	return defined $directWalk ? $directWalk : 0;
}

sub canAddOpenListEntry {
	my ($self, $key, $walk) = @_;
	return 0 if (exists $self->{closelist}{$key} && $self->{closelist}{$key}{walk} <= $walk);
	return 0 if (exists $self->{openlist}{$key} && $self->{openlist}{$key}{walk} <= $walk);
	return 1;
}

sub registerSyntheticPortalDestination {
	my ($self, $storeKey, $dest, $entry) = @_;
	return unless defined $storeKey && defined $dest;
	return unless ($entry && ref($entry) eq 'HASH');

	my $syntheticPortals = ($self->{SyntheticPortals} ||= {});
	$syntheticPortals->{$storeKey}{$dest}{dest}{$dest}{map} = $entry->{map};
	$syntheticPortals->{$storeKey}{$dest}{dest}{$dest}{x} = $entry->{x};
	$syntheticPortals->{$storeKey}{$dest}{dest}{$dest}{y} = $entry->{y};
	$syntheticPortals->{$storeKey}{$dest}{dest}{$dest}{enabled} = 1;
}

sub isWarpItemCandidatesCacheExpired {
	my ($self, $cache) = @_;
	return 1 unless ($cache && ref($cache) eq 'HASH' && defined $cache->{time});
	return timeOut($cache->{time}, 1);
}

sub buildReachedTargetState {
	my ($self, $parentKey, $parentValue, $targetPortalString) = @_;
	my $blockedPortalGroups = $self->cloneBlockedPortalGroups($parentValue);
	my $key = $self->buildRouteStateKey($targetPortalString, $blockedPortalGroups);
	my $value = {
		%{$parentValue},
		walk => scalar(@{$self->{solution}}) + $parentValue->{walk},
		parent => $parentKey,
		portal_string => $targetPortalString,
		blockedPortalGroups => $blockedPortalGroups,
		is_command => 0,
		command => undef,
		is_teleportToSaveMap => 0,
		is_teleportItemWarp => 0,
		teleportItemID => undef,
		teleportItemTimeoutSec => 0,
		teleportItemRequiredEquipSlot => undef,
		teleportItemRequiredEquipItemID => undef,
		is_airship => 0,
		airship_message => undef,
	};
	return ($key, $value);
}

sub buildMapSolutionStep {
	my ($self, $key, $value) = @_;
	my ($routePortalString) = $self->parseRouteStateKey($key);
	my $portal = $value->{portal_string} || $routePortalString;
	my ($from, $to) = split /=/, $portal, 2;
	my ($map, $x, $y) = split(/\s+/, $from, 3);

	return {
		portal => $portal,
		map => $map,
		pos => { x => $x, y => $y },
		walk => $value->{walk},
		zeny => $value->{zeny},
		allow_ticket => $value->{allow_ticket},
		amount_of_tickets_used => $value->{amount_of_tickets_used},
		steps => $value->{is_airship}
			? hashSafeGetValue(\%portals_airships, $from, 'dest', $to, 'steps')
			: hashSafeGetValue(\%portals_lut, $from, 'dest', $to, 'steps'),
		is_command => $value->{is_command} || 0,
		command => $value->{command},
		is_teleportToSaveMap => $value->{is_teleportToSaveMap} || 0,
		is_teleportItemWarp => $value->{is_teleportItemWarp} || 0,
		teleportItemID => $value->{teleportItemID},
		teleportItemTimeoutSec => $value->{teleportItemTimeoutSec} || 0,
		teleportItemRequiredEquipSlot => $value->{teleportItemRequiredEquipSlot},
		teleportItemRequiredEquipItemID => $value->{teleportItemRequiredEquipItemID},
		is_airship => $value->{is_airship} || 0,
		airship_message => $value->{airship_message},
	};
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();

	if ($self->{stage} == INITIALIZE) {
		my $openlist = $self->{openlist};
		my $closelist = $self->{closelist};
		my $sourceNode = "$self->{source}{map} $self->{source}{x} $self->{source}{y}";
		my $initialBaseCost = { walk => 0, zeny => 0, amount_of_tickets_used => 0 };
		my @validTargets;
		foreach my $target ( @{ $self->{targets} } ) {
			$target->{field} = eval { Field->new( name => $target->{map} ) };
			if ( caught( 'FileNotFoundException', 'IOException' ) ) {
				debug sprintf(
					"CalcMapRoute - skipping unloadable target '%s'%s.\n",
					$target->{map},
					defined $target->{x} && defined $target->{y} ? " ($target->{x},$target->{y})" : ''
				), "calc_map_route" if $self->shouldLogDebug();
				next;
			} elsif ( $@ ) {
				die $@;
			}
			push @validTargets, $target;
		}

		if ( !@validTargets ) {
			$self->setError( CANNOT_LOAD_FIELD, TF( "Cannot load field '%s'.", $self->{targets}[0]{map} ) );
			return;
		}

		$self->{targets} = \@validTargets;

		foreach my $target ( @{ $self->{targets} } ) {
			# Check whether destination is walkable from the starting point.
			if ( $self->{source}{map} eq $target->{map} && Task::Route->getRoute( undef, $target->{field}, $self->{source}, $target, 0 ) ) {
				$self->{mapSolution} = [];
				$self->{target} = $target;
				$self->{target}->{pos}->{x} = $target->{x};
				$self->{target}->{pos}->{y} = $target->{y};
				$self->setDone();
				return;
			}
		}

		# Initializes the openlist with portals walkable from the starting point.
		foreach my $portal (keys %portals_lut) {
			my $entry = $portals_lut{$portal};
			next if isRouteSourceRemoved($entry);
			next unless $entry->{dest} && ref($entry->{dest}) eq 'HASH';
			next unless isRoutePointDefined($entry->{source});
			next if ($entry->{source}{map} ne $self->{source}{field}->baseName);
			next unless isRoutePointReachableOnField($self->{source}{field}, $entry->{source});
			my $ret = Task::Route->getRoute($self->{solution}, $self->{source}{field}, $self->{source}, $entry->{source});
			if ($ret) {
				for my $dest ($self->getPortalDestinationsForRoute($portal, undef)) {
					next unless isRoutePointDefined($entry->{dest}{$dest});
					my $penalty = $self->getMapRouteWeight($self->{source}{map})
						+ (($entry->{dest}{$dest}{steps} ne '') ? $self->getRouteWeight('NPC') : $self->getRouteWeight('PORTAL'));
					my $blockedPortalGroups = $self->getBlockedPortalGroupsAfterStep(
						$entry->{dest}{$dest},
						undef,
						"Portal branch [<initial>]",
					);
					my $portalString = "$portal=$dest";
					my $key = $self->buildRouteStateKey($portalString, $blockedPortalGroups);
					my ($extraZeny, $extraTickets) = $self->getPortalStepCost(undef, $entry->{dest}{$dest});
					my $value = $self->buildRouteValue(
						type => 'portal_or_npc',
						extraWalk => $penalty + scalar @{$self->{solution}},
						extraZeny => $extraZeny,
						extraTickets => $extraTickets,
						allow_ticket => $entry->{dest}{$dest}{allow_ticket},
						blockedPortalGroups => $blockedPortalGroups,
					);
					$self->add_key_to_openList($key, $value);
				}
			}
		}

		$self->populateOpenListWithGoCommands($sourceNode, $initialBaseCost, undef) unless ($self->{noGoCommand});

		if (my $syntheticPortals = $self->{SyntheticPortals}) {
			delete $syntheticPortals->{tempPortalsSaveMap};
			delete $syntheticPortals->{tempPortalsWarpItems};
		}
		if (!$self->{noTeleSpawn} && canUseTeleportInRouteContext() && $self->isSaveMapSetAndValid()) {
			$self->populateOpenListWithWarpToSaveMap($sourceNode, $initialBaseCost, undef);
		}
		if (!$self->{noWarpItem}) {
			$self->populateOpenListWithWarpByItems($sourceNode, $initialBaseCost, undef);
		}

		# Initializes the openlist with airships walkable from the starting point.
		unless ($self->{noAirship}) {
			foreach my $portal (keys %portals_airships) {
				my $entry = $portals_airships{$portal};
				next if isRouteSourceRemoved($entry);
				next unless $entry->{dest} && ref($entry->{dest}) eq 'HASH';
				next unless isRoutePointDefined($entry->{source});
				next if ($entry->{source}{map} ne $self->{source}{field}->baseName);
				next unless isRoutePointReachableOnField($self->{source}{field}, $entry->{source});
				my $ret = Task::Route->getRoute($self->{solution}, $self->{source}{field}, $self->{source}, $entry->{source});
				if ($ret) {
					for my $dest (grep { $entry->{dest}{$_}{enabled} } keys %{$entry->{dest}}) {
						next unless isRoutePointDefined($entry->{dest}{$dest});
						my $penalty = $self->getMapRouteWeight($self->{source}{map}) + $self->getRouteWeight('AIRSHIP');
						my $portalString = "$portal=$dest";
						my $key = $self->buildRouteStateKey($portalString, undef);
						my $value = $self->buildRouteValue(
							type => 'airship',
							extraWalk => $penalty + scalar @{$self->{solution}},
							blockedPortalGroups => {},
						);
						$value->{airship_message} = $entry->{dest}{$dest}{message};
						$value->{is_airship} = 1;
						$self->add_key_to_openList($key, $value);
					}
				}
			}
		}

		$self->{stage} = CALCULATE_ROUTE;
			debug "CalcMapRoute - initialized with '".(scalar keys %{$openlist})."' options.\n", "calc_map_route"
				if $self->shouldLogDebug();

	} elsif ( $self->{stage} == CALCULATE_ROUTE ) {
		my $time = time;
		while ( !$self->{done} && (!$self->{maxTime} || !timeOut($time, $self->{maxTime})) ) {
			$self->searchStep();
		}
		if ($self->{found}) {
			delete $self->{openlist};
			delete $self->{solution};
			delete $self->{closelist};
			delete $_->{field} foreach @{ $self->{targets} };
			$self->setDone();
				if ($self->shouldLogDebug()) {
					debug "Map Solution Ready for traversal.\n", "calc_map_route";
					debug sprintf("%s\n", $self->getRouteString()), "calc_map_route";
				}

		} elsif ($self->{done}) {
			my $destpos = $self->{targets}[0]->{x} ? " (".$self->{targets}[0]->{x}.",".$self->{targets}[0]->{y}.")" : undef;
			$self->setError(CANNOT_CALCULATE_ROUTE, TF("Cannot calculate a route from %s (%d,%d) to %s%s",
				$self->{source}{field}->baseName, $self->{source}{x}, $self->{source}{y},
				$self->{targets}[0]->{map} || T("unknown"), $destpos));
				debug "CalcMapRoute failed.\n", "calc_map_route" if $self->shouldLogDebug();
			Plugins::callHook('fail_calc_map_route', { 
				map_from	=> $self->{source}{field}->baseName,
				map_from_x	=> $self->{source}{x},
				map_from_y	=> $self->{source}{y},
				map_to   	=> $self->{targets}[0]->{map},
				map_to_x   	=> $self->{targets}[0]->{x} ? $self->{targets}[0]->{x} : undef,
				map_to_y   	=> $self->{targets}[0]->{y} ? $self->{targets}[0]->{y} : undef
			});
		}
	}
}

##
# Array<Hash>* $task->getRoute()
# Requires: $self->getStatus() == Task::DONE && !defined($self->getError())
#
# Return the calculated route.
sub getRoute {
	return $_[0]->{mapSolution};
}

##
# String $task->getRouteString()
# Requires: $self->getStatus() == Task::DONE && !defined($self->getError())
#
# Return a string which describes the calculated route. This string has
# the following form: "payon -> pay_arche -> pay_dun00 -> pay_dun01"
sub getRouteString {
	my ( $self ) = @_;
	join ' -> ', map { $_->{map} } @{ $self->getRoute }, $self->{target};
}

##
# String $task->getFullRouteString()
# Requires: $self->getStatus() == Task::DONE && !defined($self->getError())
#
# Return a string which describes the calculated route. This string has
# the following form: "payon 228 329 -> pay_arche 36 131 -> pay_dun00 184 33 -> pay_dun01 286 25"
sub getFullRouteString {
	my ( $self ) = @_;
	join ' -> ', map { "$_->{map} $_->{pos}->{x} $_->{pos}->{y}" } @{ $self->getRoute }, $self->{target};
}

sub searchStep {
	my ($self) = @_;
	# declare portals list
	my $openlist = $self->{openlist}; # Nodes not visited yet
	my $closelist = $self->{closelist}; # Nodes already visited

	# exit early if no more paths to check
	unless ($openlist && %{$openlist}) {
		$self->{done} = 1;
		$self->{found} = '';
		return 0;
	}

	# selects the node with the lowest walk cost
	my $parent = $self->shiftOpenlistHeapMinKey();
	if (!defined $parent) {
		# Fallback: rebuild heap from openlist if it got out of sync.
		$self->rebuildOpenlistHeap();
		$parent = $self->shiftOpenlistHeapMinKey();
	}
	unless (defined $parent) {
		$self->{done} = 1;
		$self->{found} = '';
		return 0;
	}
	debug "[CalcMapRoute] [searchStep] $parent (cost $openlist->{$parent}{walk})\n", "calc_map_route" if $self->shouldLogDebug();

	# Uncomment this if you want minimum MAP count. Otherwise use the above for minimum step count
	#foreach my $parent (keys %{$openlist})
		my ($portalString) = $self->parseRouteStateKey($parent);
		my ($portal, $dest) = split /=/, $portalString, 2;
		# skip if budget exceeded
		if ($self->{budget} ne '' && $self->{budget} < $openlist->{$parent}{zeny}) {
			# This link is too expensive
			delete $openlist->{$parent};
			next;

		} else {
			# MOVE this entry into the CLOSELIST
			$closelist->{$parent} = delete $openlist->{$parent};
		}

		my $map_destination = $self->resolveRouteDestinationEntry($portal, $dest);
		# support to multiple targets
		foreach my $target ( @{ $self->{targets} } ) {
			next unless $map_destination;
			my $map_name = $map_destination->{map};
			next if $map_name ne $target->{map}; # checks if the current destination map matches any of the search targets.
			my $target_has_coords = hasMapCoords($target);
			my $map_destination_has_coords = hasMapCoords($map_destination);
			# if no x or y consider that is already at destination
			if (!$target_has_coords) {
				$self->{found} = $parent;
			}
			# uses getRoute to check whether you have reached exactly the desired point on the map.
			elsif ($map_destination_has_coords
			    && Task::Route->getRoute($self->{solution}, $target->{field}, $map_destination, $target)) {
				my $targetPortalString = "$target->{map} $target->{x} $target->{y}=$target->{map} $target->{x} $target->{y}";
				my ($walk, $value) = $self->buildReachedTargetState(
					$parent,
					$closelist->{$parent},
					$targetPortalString,
				);
				$self->{found} = $walk;
				$closelist->{$walk} = $value;
			}

			# Reconstructs the solution path by traversing the parents backwards, stacking the portals used in the final route.
			if ( $self->{found} ) {
				$self->{done} = 1;
				$self->{mapSolution} = [];
				$self->{target} = $target;
				$self->{target}->{pos}->{x} = $self->{target}->{x};
				$self->{target}->{pos}->{y} = $self->{target}->{y};
				my $this = $self->{found};
				while ($this) {
					unshift @{$self->{mapSolution}}, $self->buildMapSolutionStep($this, $closelist->{$this});
					$this = $closelist->{$this}{parent};
				}
				return;
			}
		}

		# get all children of each openlist.
		$self->populateOpenListWithGoCommands($dest, $closelist->{$parent}, $parent) unless ($self->{noGoCommand});
		if (!$self->{noTeleSpawn} && canUseTeleportInRouteContext() && $self->isSaveMapSetAndValid()) {
			$self->populateOpenListWithWarpToSaveMap($dest, $closelist->{$parent}, $parent);
		}
		if (!$self->{noWarpItem}) {
			$self->populateOpenListWithWarpByItems($dest, $closelist->{$parent}, $parent);
		}
		
		# explore connected portals and NPC warps
		my $children = $portals_los{$dest};
		if ($children && ref($children) eq 'HASH') {
			foreach my $child (keys %{$children}) {
				next unless $children->{$child}; # next if no child

				if (exists $portals_lut{$child}
				 && !isRouteSourceRemoved($portals_lut{$child})
				 && isRoutePointDefined($portals_lut{$child}{source})) {
					# iterates through the child's/portals that have connection to destination
					foreach my $subchild ($self->getPortalDestinationsForRoute($child, $closelist->{$parent})) {
						my $destID = $subchild;
						next unless isRoutePointDefined($portals_lut{$child}{dest}{$subchild});
						my $mapName = $portals_lut{$child}{source}{map};
						#############################################################
						my $penalty = $self->getMapRouteWeight($mapName) +
							(($portals_lut{$child}{dest}{$subchild}{steps} ne '') ? $self->getRouteWeight('NPC') : $self->getRouteWeight('PORTAL')); # get node/child penalty based on routeWeights
						my $thisWalk = $penalty + $closelist->{$parent}{walk} + $children->{$child}; # calculate the final node/child penalty routeWeights + walk distance + accumulated cost
						my $blockedPortalGroups = $self->getBlockedPortalGroupsAfterStep(
							$portals_lut{$child}{dest}{$subchild},
							$closelist->{$parent},
							"Portal branch [$closelist->{$parent}{portal_string}]",
						);
						my $portalString = "$child=$subchild";
						my $key = $self->buildRouteStateKey($portalString, $blockedPortalGroups);
						my ($extraZeny, $extraTickets) = $self->getPortalStepCost($closelist->{$parent}, $portals_lut{$child}{dest}{$subchild});
						next unless $self->canAddOpenListEntry($key, $thisWalk);
						my $value = $self->buildRouteValue(
							type => 'portal_or_npc',
							parent => $parent,
							baseCost => $closelist->{$parent},
							extraWalk => $penalty + $children->{$child},
							extraZeny => $extraZeny,
							extraTickets => $extraTickets,
							allow_ticket => $portals_lut{$child}{dest}{$subchild}{allow_ticket},
							blockedPortalGroups => $blockedPortalGroups,
						);
						$self->add_key_to_openList($key, $value);
					}
					next;
				}

				next if $self->{noAirship};
				next unless exists $portals_airships{$child};
				next if isRouteSourceRemoved($portals_airships{$child});
				next unless isRoutePointDefined($portals_airships{$child}{source});
				next unless $portals_airships{$child}{dest} && ref($portals_airships{$child}{dest}) eq 'HASH';
				# iterates airships
				foreach my $subchild (grep { $portals_airships{$child}{dest}{$_}{enabled} } keys %{$portals_airships{$child}{dest}}) {
					my $destID = $subchild;
					next unless isRoutePointDefined($portals_airships{$child}{dest}{$subchild});
					my $mapName = $portals_airships{$child}{source}{map};
					#############################################################
					my $penalty = $self->getMapRouteWeight($mapName) + $self->getRouteWeight('AIRSHIP'); # get node/child penalty based on routeWeights
					my $thisWalk = $penalty + $closelist->{$parent}{walk} + $children->{$child}; # calculate the final node/child penalty routeWeights + walk distance + accumulated cost
					my $key = $self->buildRouteStateKey("$child=$subchild", $closelist->{$parent}{blockedPortalGroups});
					next unless $self->canAddOpenListEntry($key, $thisWalk);
					my $value = $self->buildRouteValue(
						type => 'airship',
						parent => $parent,
						baseCost => $closelist->{$parent},
						extraWalk => $penalty + $children->{$child},
						blockedPortalGroups => $self->cloneBlockedPortalGroups($closelist->{$parent}),
					);
					$value->{airship_message} = $portals_airships{$child}{dest}{$subchild}{message};
					$value->{is_airship} = 1;
					$self->add_key_to_openList($key, $value);
				}
			}
		}
}

sub getPortalDestinationsForRoute {
	my ($self, $portal, $currentValue) = @_;
	return unless (exists $portals_lut{$portal} && exists $portals_lut{$portal}{dest});

	my @destinations;
	foreach my $destID (keys %{$portals_lut{$portal}{dest}}) {
		push @destinations, $destID if $self->isPortalDestinationEnabledForRoute($portal, $destID, $currentValue);
	}

	return @destinations;
}

sub isPortalDestinationEnabledForRoute {
	my ($self, $portal, $destID, $currentValue) = @_;
	my $entry = hashSafeGetValue(\%portals_lut, $portal, 'dest', $destID);
	return 0 unless isRoutePointDefined($entry);

	my $groupName = $entry->{dynamicPortalGroup};
	if (defined $groupName && $groupName ne '' && $self->isPortalGroupBlockedForValue($groupName, $currentValue)) {
		if ($self->shouldLogDebug()) {
			my $branchPortal = ($currentValue && ref($currentValue) eq 'HASH') ? ($currentValue->{portal_string} || '<initial>') : '<initial>';
			my $blocked = $self->formatBlockedPortalGroups($self->cloneBlockedPortalGroups($currentValue));
			debug sprintf(
				"CalcMapRoute - Blocking portal %s=%s because group '%s' is blocked for branch [%s] (blocked groups: %s).\n",
				$portal, $destID, $groupName, $branchPortal, $blocked
			), "calc_map_route";
		}
		return 0;
	}

	return $entry->{enabled} ? 1 : 0;
}

sub isPortalGroupBlockedForValue {
	my ($self, $groupName, $value) = @_;
	return 0 unless defined $groupName && $groupName ne '';

	my $blockedPortalGroups = $self->cloneBlockedPortalGroups($value);
	return exists $blockedPortalGroups->{$groupName} ? 1 : 0;
}

sub cloneBlockedPortalGroups {
	my ($self, $value) = @_;
	return {} unless ($value && ref($value) eq 'HASH');

	my $source;
	if (exists $value->{blockedPortalGroups}) {
		$source = $value->{blockedPortalGroups} if ref($value->{blockedPortalGroups}) eq 'HASH';
	} elsif (!exists $value->{walk}
		&& !exists $value->{zeny}
		&& !exists $value->{amount_of_tickets_used}
		&& !exists $value->{portal_string}
		&& !exists $value->{type}
		&& !exists $value->{parent}
		&& !exists $value->{allow_ticket}) {
		$source = $value;
	}

	my %blockedPortalGroups = $source ? %{$source} : ();
	return \%blockedPortalGroups;
}

sub getBlockedPortalGroupsAfterStep {
	my ($self, $entry, $baseValue, $debugLabel) = @_;
	my $blockedPortalGroups = $self->cloneBlockedPortalGroups($baseValue);
	return $blockedPortalGroups unless ($entry && ref($entry) eq 'HASH');

	my $groupName = $entry->{dynamicPortalGroupBlock};
	if (defined $groupName && $groupName ne '') {
		$blockedPortalGroups->{$groupName} = 1;
		if ($self->shouldLogDebug()) {
			my $blocked = $self->formatBlockedPortalGroups($blockedPortalGroups);
			debug sprintf(
				"CalcMapRoute - %s adds dynamic portal block '%s' (blocked groups now: %s).\n",
				$debugLabel,
				$groupName,
				$blocked,
			), "calc_map_route";
		}
	}

	return $blockedPortalGroups;
}

sub blockedPortalGroupsSignature {
	my ($self, $blockedPortalGroups) = @_;
	return '' unless ($blockedPortalGroups && ref($blockedPortalGroups) eq 'HASH' && %{$blockedPortalGroups});
	return join(',', sort keys %{$blockedPortalGroups});
}

sub formatBlockedPortalGroups {
	my ($self, $blockedPortalGroups) = @_;
	my $signature = $self->blockedPortalGroupsSignature($blockedPortalGroups);
	return $signature ne '' ? $signature : '<none>';
}

sub buildRouteStateKey {
	my ($self, $portalString, $blockedPortalGroups) = @_;
	my $signature = $self->blockedPortalGroupsSignature($blockedPortalGroups);
	return $signature ne '' ? "$portalString\t$signature" : $portalString;
}

sub parseRouteStateKey {
	my ($self, $key) = @_;
	return ('', '') unless defined $key;
	my ($portalString, $signature) = split(/\t/, $key, 2);
	return ($portalString, $signature || '');
}

sub resolveRouteDestinationEntry {
	my ($self, $portal, $destID) = @_;
	my @candidates = (
		hashSafeGetValue(\%portals_lut, $portal, 'dest', $destID),
		hashSafeGetValue(\%portals_commands, $destID, 'dest', $destID),
		hashSafeGetValue($self->{SyntheticPortals}, 'tempPortalsSaveMap', $destID, 'dest', $destID),
		hashSafeGetValue($self->{SyntheticPortals}, 'tempPortalsWarpItems', $destID, 'dest', $destID),
		hashSafeGetValue(\%portals_airships, $portal, 'dest', $destID),
	);

	for my $entry (@candidates) {
		next unless defined $entry;
		return $entry if isRoutePointDefined($entry);
	}

	return undef;
}

# Add @go commands to openlist
sub populateOpenListWithGoCommands {
	my ($self, $from_node, $baseCost, $parent) = @_;
	return unless $from_node;

	my ($current_map) = split / /, $from_node, 2;
	return unless $self->isGoCommandAllowedOnMap($current_map);

	# iterate through the commands
	foreach my $portal (keys %portals_commands) {
		next unless $portals_commands{$portal}{dest} && ref($portals_commands{$portal}{dest}) eq 'HASH';
		foreach my $dest (keys %{$portals_commands{$portal}{dest}}) {
			next unless isRoutePointDefined($portals_commands{$portal}{dest}{$dest});
			my $to_node = $portals_commands{$portal}{dest}{$dest}{map} . " " . $portals_commands{$portal}{dest}{$dest}{x} . " " . $portals_commands{$portal}{dest}{$dest}{y};
			my $key = $self->buildRouteStateKey("$from_node=$to_node", $baseCost->{blockedPortalGroups});
			my $walk = ($baseCost->{walk} || 0) + $self->getMapRouteWeight($current_map) + $self->getRouteWeight('COMMAND');
			next unless $self->canAddOpenListEntry($key, $walk);

			# add @go option as a synthetic portal
			my $value = $self->buildRouteValue(
				type => 'command',
				parent => $parent,
				baseCost => $baseCost,
				extraWalk => $self->getRouteWeight('COMMAND'),
				extraMapWeight => $self->getMapRouteWeight($current_map),
				allow_ticket => 0,
				blockedPortalGroups => $self->cloneBlockedPortalGroups($baseCost),
			);
			$value->{is_command} = 1;
			$value->{command} = $portals_commands{$portal}{dest}{$dest}{command};
			$self->add_key_to_openList($key, $value);
		}
	}
}


# Add teleport lv 2 (or butterfly wing) to openlist
sub populateOpenListWithWarpToSaveMap {
	my ($self, $from_node, $baseCost, $parent) = @_;
	return unless $from_node;
	return unless ($config{saveMap_warp});

	my ($current_map) = split / /, $from_node, 2;
	return unless $self->isWarpToSaveMapAllowedOnMap($current_map);

	return unless ($self->isWarpToSaveMapMinDistanceReached());
	my $saveMapDestination = $self->resolveSaveMapDestination();
	return unless ($saveMapDestination);

	my $dest_map = $saveMapDestination->{map};
	my $dest_x = $saveMapDestination->{x};
	my $dest_y = $saveMapDestination->{y};

	my $dest = $dest_map . " " . $dest_x . " " . $dest_y;

	debug "CalcMapRoute - Adding savemap '".( $dest )."' to openlist.\n", "calc_map_route" if $self->shouldLogDebug();

	return if ($dest eq $from_node);
	my $key = $self->buildRouteStateKey("$from_node=$dest", $baseCost->{blockedPortalGroups});
	my $walk = ($baseCost->{walk} || 0) + $self->getMapRouteWeight($current_map) + $self->getRouteWeight('WARPTOSAVEMAP');
	return unless $self->canAddOpenListEntry($key, $walk);

	my $value = $self->buildRouteValue(
		type => 'respawn',
		parent => $parent,
		baseCost => $baseCost,
		extraWalk => $self->getRouteWeight('WARPTOSAVEMAP'),
		extraMapWeight => $self->getMapRouteWeight($current_map),
		allow_ticket => 0,
		blockedPortalGroups => $self->cloneBlockedPortalGroups($baseCost),
	);
	$value->{is_teleportToSaveMap} = 1;
	$self->add_key_to_openList($key, $value);

	$self->registerSyntheticPortalDestination(
		'tempPortalsSaveMap',
		$dest,
		{ map => $dest_map, x => $dest_x, y => $dest_y },
	);
}


sub populateOpenListWithWarpByItems {
	my ($self, $from_node, $baseCost, $parent) = @_;
	return unless $from_node;
	return unless $config{route_warpByItem};
	return unless $self->isWarpByItemMinDistanceReached();

	my ($current_map) = split / /, $from_node, 2;
	return unless $self->isWarpByItemAllowedOnMap($current_map);
	# By default, evaluate warp-item usage from the initial source node only.
	# This avoids chaining item-warps back and forth across maps (e.g. xmas <-> yuno)
	# during graph expansion. Set route_warpByItem_chaining to enable old behavior.
	my $allowWarpItemChaining = hashSafeGetValue(\%config, 'route_warpByItem_chaining');
	return if (defined $parent && !$allowWarpItemChaining);
	my $baselineNoWarpRouteCost;
	if (!defined $parent) {
		$baselineNoWarpRouteCost = $self->getSourceRouteCostToTargetNoWarp();
	}

	my $routeCostProbeEnabled = int(hashSafeGetValue(\%config, 'route_warpItem_routeCostProbe_maxPerTick') || 6) > 0;

	for my $entry ($self->getWarpItemCandidates()) {
		my $dest = $entry->{destMap} . ' ' . $entry->{destX} . ' ' . $entry->{destY};
		next if ($dest eq $from_node);
		my $branchPortal = ($baseCost && ref($baseCost) eq 'HASH') ? ($baseCost->{portal_string} || '<initial>') : '<initial>';
		my $blockedPortalGroups = $self->getBlockedPortalGroupsAfterStep(
			$entry,
			$baseCost,
			sprintf(
				"Teleport item branch [%s] item %s -> %s %s %s",
				$branchPortal,
				$entry->{itemID} || '?',
				$entry->{destMap} || '?',
				defined $entry->{destX} ? $entry->{destX} : '?',
				defined $entry->{destY} ? $entry->{destY} : '?',
			),
		);
		my $key = $self->buildRouteStateKey("$from_node=$dest", $blockedPortalGroups);
		my $walk = ($baseCost->{walk} || 0) + $self->getMapRouteWeight($current_map) + $self->getRouteWeight('WARPITEM');
		# Optional ranking heuristic: incorporate estimated route cost from item destination
		# to current targets so the heap can prefer warp items that actually shorten the route.
		# Controlled by route_warpItem_routeCostProbe_maxPerTick (>0 enables probing),
		# and bounded by route_warpItem_routeCostHeuristic_max (default: 10000).
		if ($routeCostProbeEnabled) {
			my $heuristic = $self->getWarpItemRouteCostToTarget($entry);
			if (defined $heuristic && $heuristic > 0) {
				if (!defined $parent && defined $baselineNoWarpRouteCost) {
					my $minGain = int(hashSafeGetValue(\%config, 'route_warpItem_minGain') || 0);
					my $estimatedWarpTotal = $self->getMapRouteWeight($current_map) + $self->getRouteWeight('WARPITEM') + $heuristic;
					next if ($estimatedWarpTotal + $minGain >= $baselineNoWarpRouteCost);
				}
				my $heuristicMax = int(hashSafeGetValue(\%config, 'route_warpItem_routeCostHeuristic_max') || 10000);
				$heuristicMax = 0 if $heuristicMax < 0;
				$heuristic = $heuristicMax if ($heuristicMax > 0 && $heuristic > $heuristicMax);
				$walk += $heuristic;
			}
		}
		next unless $self->canAddOpenListEntry($key, $walk);

		my $value = $self->buildRouteValue(
			type => 'item',
			parent => $parent,
			baseCost => $baseCost,
			extraWalk => ($walk - ($baseCost->{walk} || 0)),
			extraMapWeight => 0,
			allow_ticket => 0,
			blockedPortalGroups => $blockedPortalGroups,
		);
		$value->{is_teleportItemWarp} = 1;
		$value->{teleportItemID} = $entry->{itemID};
		$value->{teleportItemTimeoutSec} = $entry->{timeoutSec} || 0;
		$value->{teleportItemRequiredEquipSlot} = $entry->{requiredEquipSlot};
		$value->{teleportItemRequiredEquipItemID} = $entry->{requiredEquipItemID};
		$self->add_key_to_openList($key, $value);

		$self->registerSyntheticPortalDestination(
			'tempPortalsWarpItems',
			$dest,
			{ map => $entry->{destMap}, x => $entry->{destX}, y => $entry->{destY} },
		);
	}
}

sub isWarpByItemMinDistanceReached {
	my ($self) = @_;

	my $minDistance = int(hashSafeGetValue(\%config, 'route_warpByItem_minDistance') || 0);
	return 1 if ($minDistance <= 0);

	my $distance = $self->getSourceRouteCostToTargetNoWarp();
	return ($distance >= $minDistance) if (defined $distance);

	# If route distance cannot be calculated, don't block warp-item usage.
	return 1;
}

sub getSourceRouteCostToTargetNoWarp {
	my ($self) = @_;
	return unless ($self->{targets} && ref($self->{targets}) eq 'ARRAY' && @{$self->{targets}});
	return $self->{_source_route_cost_no_warp}
		if exists $self->{_source_route_cost_no_warp};

	my $task = $self->runCalcMapRouteSubtask(
		targets => $self->cloneRouteTargets(),
		sourceMap => $self->{source}{map},
		sourceX => $self->{source}{x},
		sourceY => $self->{source}{y},
		noGoCommand => $self->{noGoCommand} || 0,
		noTeleSpawn => 1,
		noWarpItem => 1,
		maxTime => 3,
		suppressDebug => 1,
	);
	if ($task->getError()) {
		$self->{_source_route_cost_no_warp} = undef;
		return undef;
	}
	$self->{_source_route_cost_no_warp} = $self->getCompletedTaskRouteCost($task, $self->{source});
	return $self->{_source_route_cost_no_warp};
}

sub add_key_to_openList {
	my ($self, $key, $value) = @_;
	$value->{portal_string} ||= ($self->parseRouteStateKey($key))[0];
	$value->{blockedPortalGroups} = $self->cloneBlockedPortalGroups($value);

	if ($self->shouldLogDebug() && $config{'debug'} >= 2) {
		debug "[CalcMapRoute] [Add] Added key [$value->{type}] [$key] [cost $value->{walk}] [blocked ".$self->formatBlockedPortalGroups($value->{blockedPortalGroups})."] (current size ".((scalar keys %{$self->{openlist}}) + 1).")\n", "calc_map_route", 2;
	}

	$self->{openlist}{$key} = $value;
	$self->pushOpenlistHeap($key, $value->{walk});

	# If stale heap entries accumulate too much, rebuild to keep memory and pop cost bounded.
	my $heapSize = $self->{openlist_heap} ? scalar(@{$self->{openlist_heap}}) : 0;
	my $openSize = scalar(keys %{$self->{openlist}});
	if ($heapSize > ($openSize * 3 + 1000)) {
		$self->rebuildOpenlistHeap();
	}
}

sub pushOpenlistHeap {
	my ($self, $key, $walk) = @_;
	return unless defined $key;
	return unless defined $walk;

	$self->{openlist_heap} ||= [];
	my $heap = $self->{openlist_heap};
	push @{$heap}, [$walk, $key];

	my $i = $#{$heap};
	while ($i > 0) {
		my $parent = int(($i - 1) / 2);
		last if $heap->[$parent][0] <= $heap->[$i][0];
		@{$heap}[$i, $parent] = @{$heap}[$parent, $i];
		$i = $parent;
	}
}

sub shiftOpenlistHeapMinKey {
	my ($self) = @_;
	$self->{openlist_heap} ||= [];
	my $heap = $self->{openlist_heap};

	while (@{$heap}) {
		my $top = $heap->[0];
		my $last = pop @{$heap};
		if (@{$heap}) {
			$heap->[0] = $last;
			my $i = 0;
			while (1) {
				my $left = 2 * $i + 1;
				my $right = $left + 1;
				last if $left > $#{$heap};
				my $smallest = $left;
				if ($right <= $#{$heap} && $heap->[$right][0] < $heap->[$left][0]) {
					$smallest = $right;
				}
				last if $heap->[$i][0] <= $heap->[$smallest][0];
				@{$heap}[$i, $smallest] = @{$heap}[$smallest, $i];
				$i = $smallest;
			}
		}

		my ($walk, $key) = @{$top};
		my $entry = $self->{openlist}{$key};
		next unless $entry;
		next if !defined $entry->{walk};
		next if $entry->{walk} != $walk;
		return $key;
	}

	return;
}

sub rebuildOpenlistHeap {
	my ($self) = @_;
	my $openlist = $self->{openlist};
	$self->{openlist_heap} = [];
	return unless ($openlist && %{$openlist});
	foreach my $key (keys %{$openlist}) {
		$self->pushOpenlistHeap($key, $openlist->{$key}{walk});
	}
}

sub getWarpItemCandidates {
	my ($self) = @_;
	return unless ($char && $char->inventory && $char->inventory->isReady());
	return unless ($teleport_items{list} && @{$teleport_items{list}});

	my $cacheKey = $self->buildWarpItemCandidateCacheKey();
	my $cache = $self->{_warp_item_candidates_cache};
	if ($cache
		&& $cache->{key}
		&& $cache->{key} eq $cacheKey
		&& !$self->isWarpItemCandidatesCacheExpired($cache)) {
		return @{$cache->{value}};
	}

	my ($matchesRef, $availableEntriesRef, $cooldownEntriesRef) = $self->collectWarpItemCandidateBuckets();
	my @matches = @{$matchesRef};
	my @availableEntries = @{$availableEntriesRef};
	my @cooldownEntries = @{$cooldownEntriesRef};

	if (!@cooldownEntries) {
		$self->setWarpItemCandidatesCache($cacheKey, \@matches);
		return @matches;
	}

	my $bestAvailableCost;
	# Optional tuning: max amount of route-cost probes per getWarpItemCandidates() call.
	# config key: route_warpItem_routeCostProbe_maxPerTick (default: 6)
	my $probeBudget = int(hashSafeGetValue(\%config, 'route_warpItem_routeCostProbe_maxPerTick') || 6);
	$probeBudget = 0 if $probeBudget < 0;
	my $fetchRouteCost = sub {
		my ($entry) = @_;
		return if !$entry;
		return if ($probeBudget <= 0);
		$probeBudget--;
		return $self->getWarpItemRouteCostToTarget($entry);
	};
	if (@availableEntries) {
		for my $entry (@availableEntries) {
			last if ($probeBudget <= 0);
			my $routeCost = $fetchRouteCost->($entry);
			next unless defined $routeCost;
			$bestAvailableCost = $routeCost if (!defined $bestAvailableCost || $routeCost < $bestAvailableCost);
			last if (defined $bestAvailableCost && $bestAvailableCost <= 0);
		}
	}

	# Nothing can beat direct target-map cost.
	if (defined $bestAvailableCost && $bestAvailableCost <= 0) {
		$self->setWarpItemCandidatesCache($cacheKey, \@matches);
		return @matches;
	}

	my @cooldownCandidates;
	my $needsCooldownCostCompare = defined $bestAvailableCost ? 1 : 0;
	my $cooldownWarned = $self->{_warp_item_cooldown_warned};
	for my $candidate (@cooldownEntries) {
		last if ($needsCooldownCostCompare && $probeBudget <= 0);
		next if ($cooldownWarned && $cooldownWarned->{$candidate->{entry}{itemID}});
		push @cooldownCandidates, {
			entry => $candidate->{entry},
			remaining => $candidate->{remaining},
			itemName => $candidate->{itemName},
			itemInvIndex => $candidate->{itemInvIndex},
			routeCost => $needsCooldownCostCompare ? $fetchRouteCost->($candidate->{entry}) : undef,
		};
	}

	for my $candidate (sort { ($a->{routeCost} // 9_999_999) <=> ($b->{routeCost} // 9_999_999) } @cooldownCandidates) {
		next unless ($candidate->{entry});
		if (defined $bestAvailableCost) {
			next if (!defined $candidate->{routeCost});
			next if ($candidate->{routeCost} >= $bestAvailableCost);
		}
		my $entry = $candidate->{entry};
		my $itemLabel = $self->formatWarpItemLabel($candidate);
		my $remaining = int(($candidate->{remaining} || 0) + 0.5);
		my $cooldown = sprintf("%s (%s sec)", timeConvert($remaining), $remaining);
		debug TF("[CalcMapRoute] Teleport item %s: cooldown active, wait %s.\n", $itemLabel, $cooldown), "route";
		($self->{_warp_item_cooldown_warned} ||= {})->{$entry->{itemID}} = 1;
		last;
	}

	$self->setWarpItemCandidatesCache($cacheKey, \@matches);

	return @matches;
}

sub buildWarpItemCandidateCacheKey {
	my ($self) = @_;
	# Route targets/noWarpItemIDs are stable during a single CalcMapRoute task
	# execution, so keep the key cheap and let the cache entry expire separately.
	return join('|', ($char->{lv} // ''), scalar(@{$teleport_items{list} || []}));
}

sub collectWarpItemCandidateBuckets {
	my ($self) = @_;
	my (@matches, @availableEntries, @cooldownEntries);

	for my $value (@{$teleport_items{list}}) {
		next unless ($value && ref($value) eq 'HASH');
		my $entry = $value;

		next unless ($entry->{mode} eq 'warp' || $entry->{mode} eq 'any');
		next unless Misc::isTeleportItemEntryWithinLevelRange($entry, $char->{lv});
		next if ($self->{noWarpItemIDs}{$entry->{itemID}});
		next unless $self->isWarpItemRoutingDestinationValid($entry);

		my $item = $char->inventory->getByNameID($entry->{itemID});
		next unless $item;
		next unless Misc::canTeleportItemEquipRequirementBeSatisfied($entry);

		my $remaining = Misc::getTeleportItemCooldownRemainingSec($entry);
		if ($remaining > 0) {
			push @cooldownEntries, {
				entry => $entry,
				remaining => $remaining,
				itemName => $item->{name},
				itemInvIndex => $item->{invIndex},
			};
			next;
		}

		push @availableEntries, $entry;
		push @matches, $entry;
	}

	return (\@matches, \@availableEntries, \@cooldownEntries);
}

sub formatWarpItemLabel {
	my ($self, $candidate) = @_;
	return '' unless ($candidate && $candidate->{entry});
	my $entry = $candidate->{entry};
	my $itemName = $candidate->{itemName};
	$itemName = itemNameSimple($entry->{itemID}) if (!defined $itemName || $itemName eq '');
	return $itemName if (!defined $candidate->{itemInvIndex});
	return sprintf("%s (%s)", $itemName, $candidate->{itemInvIndex});
}

sub setWarpItemCandidatesCache {
	my ($self, $cacheKey, $matchesRef) = @_;
	return unless defined $cacheKey;
	return unless ($matchesRef && ref($matchesRef) eq 'ARRAY');
	$self->{_warp_item_candidates_cache} = {
		key => $cacheKey,
		time => time,
		value => [@{$matchesRef}],
	};
}

sub collectSpawnCandidatesForMap {
	my ($self, $dest_map, $portal_map_filter) = @_;
	my %candidates;
	return \%candidates unless (defined $dest_map && $dest_map ne '');

	foreach my $portal (keys %portals_spawns) {
		my $portalEntry = $portals_spawns{$portal};
		next unless ($portalEntry->{dest} && ref($portalEntry->{dest}) eq 'HASH');

		if (defined $portal_map_filter && $portal_map_filter ne '') {
			my ($portal_map) = split(/\s+/, $portal, 2);
			next if (!defined $portal_map || $portal_map ne $portal_map_filter);
		}

		foreach my $dest (keys %{$portalEntry->{dest}}) {
			my $destEntry = $portalEntry->{dest}{$dest};
			next unless ($destEntry && ref($destEntry) eq 'HASH');
			next if (($destEntry->{map} // '') ne $dest_map);
			my $x = $destEntry->{x};
			my $y = $destEntry->{y};
			next if (!defined $x || !defined $y || $x eq '' || $y eq '');
			$candidates{"$x $y"} = { map => $dest_map, x => $x, y => $y };
		}
	}

	return \%candidates;
}

sub isWarpItemRoutingDestinationValid {
	my ($self, $entry) = @_;
	return 0 unless ($entry && defined $entry->{destMap} && $entry->{destMap} ne '');

	my $destMap = lc($entry->{destMap});
	return 0 if ($destMap eq '*' || $destMap eq 'any' || $destMap eq 'save');
	return 1;
}

sub getWarpItemRouteCostToTarget {
	my ($self, $entry) = @_;
	return unless ($entry && defined $entry->{destMap} && $entry->{destMap} ne '');
	return unless ($self->{targets} && ref($self->{targets}) eq 'ARRAY' && @{$self->{targets}});
	return unless ($self->hasTargetOnMap($entry->{destMap}) || $self->mapHasPortalLOS($entry->{destMap}));

	my $targetKey = $self->getTargetRouteCostCacheKey();
	my $cacheKey = join('|', $entry->{destMap}, $targetKey, ($self->{noGoCommand} || 0));
	my $routeCostCache = $self->{_warp_item_route_cost_cache};
	return $routeCostCache->{$cacheKey}
		if ($routeCostCache && exists $routeCostCache->{$cacheKey});

	my $task = $self->runCalcMapRouteSubtask(
		targets => $self->cloneRouteTargets(),
		sourceMap => $entry->{destMap},
		sourceX => $entry->{destX},
		sourceY => $entry->{destY},
		noGoCommand => $self->{noGoCommand} || 0,
		noTeleSpawn => 1,
		noWarpItem => 1,
		maxTime => 3,
		suppressDebug => 1,
	);

	my $routeCost;
	if ($task->getError()) {
		$routeCost = undef;
	} else {
		$routeCost = $self->getCompletedTaskRouteCost($task, {
			map => $entry->{destMap},
			x => $entry->{destX},
			y => $entry->{destY},
		});
	}
	# Optional tuning: maximum number of cached warp route-cost entries kept in memory.
	# config key: route_warpItem_routeCostCache_max (default: 3000)
	my $maxRouteCostCacheEntries = int(hashSafeGetValue(\%config, 'route_warpItem_routeCostCache_max') || 3000);
	if ($maxRouteCostCacheEntries > 0
		&& $routeCostCache
		&& scalar(keys %{$routeCostCache}) > $maxRouteCostCacheEntries) {
		# Keep cache bounded inside long-running route calculations.
		$self->{_warp_item_route_cost_cache} = {};
		$routeCostCache = $self->{_warp_item_route_cost_cache};
	}
	($routeCostCache ||= ($self->{_warp_item_route_cost_cache} ||= {}))->{$cacheKey} = $routeCost;
	return $routeCost;
}

sub mapHasPortalLOS {
	my ($self, $map) = @_;
	return 0 unless defined $map && $map ne '';
	$self->{_map_has_portals_los_cache} ||= {};

	if (!$self->{_map_has_portals_los_cache_initialized}) {
		foreach my $portal (keys %portals_los) {
			my ($portalMap) = split(/\s+/, $portal, 2);
			next unless defined $portalMap && $portalMap ne '';
			$self->{_map_has_portals_los_cache}{$portalMap} = 1;
		}
		$self->{_map_has_portals_los_cache_initialized} = 1;
	}

	return $self->{_map_has_portals_los_cache}{$map} ? 1 : 0;
}

sub getTargetRouteCostCacheKey {
	my ($self) = @_;
	return '' unless ($self->{targets} && ref($self->{targets}) eq 'ARRAY');
	return $self->{_target_route_cost_cache_key}
		if defined $self->{_target_route_cost_cache_key};

	my @targets = sort grep { $_ ne '' } map {
		next unless ($_ && defined $_->{map});
		join(',', $_->{map}, ($_->{x} // ''), ($_->{y} // ''));
	} @{$self->{targets}};
	$self->{_target_route_cost_cache_key} = join('|', @targets);
	return $self->{_target_route_cost_cache_key};
}

sub isWarpByItemAllowedOnMap {
	my ($self, $map) = @_;
	return 0 if !$map;
	return 0 if hashSafeGetValue($self->{noWarpItemMaps}, $map);
	return 1;
}

sub isGoCommandAllowedOnMap {
	my ($self, $map) = @_;
	return 0 if !$map;
	return 0 if hashSafeGetValue($self->{noGoCommandMaps}, $map);
	return 1;
}

sub isWarpToSaveMapAllowedOnMap {
	my ($self, $map) = @_;
	return 0 if !$map;
	return 0 if hashSafeGetValue($self->{noTeleSpawnMaps}, $map);
	return 1;
}

sub isWarpToSaveMapMinDistanceReached {
	my ($self) = @_;

	my $minDistance = int(hashSafeGetValue(\%config, 'saveMap_warp_minDistance') || 0);
	return 1 if ($minDistance <= 0);

	my $saveMapDestination = $self->resolveSaveMapDestination();
	return 1 unless ($saveMapDestination);

	my $dest_map = $saveMapDestination->{map};
	my $dest_x = $saveMapDestination->{x};
	my $dest_y = $saveMapDestination->{y};

	my $distance = $self->getDistanceToSaveMap($dest_map, $dest_x, $dest_y);
	return ($distance >= $minDistance) if (defined $distance);

	# If route distance cannot be calculated, don't block warp usage.
	return 1;
}

sub getDistanceToSaveMap {
	my ($self, $dest_map, $dest_x, $dest_y) = @_;

	my $cacheKey = join('|', $self->{source}{map}, $self->{source}{x}, $self->{source}{y}, $dest_map, $dest_x, $dest_y);
	if ($self->{saveMapDistanceCache} && $self->{saveMapDistanceCache}{key} eq $cacheKey) {
		return $self->{saveMapDistanceCache}{value};
	}

	if ($self->{source}{map} eq $dest_map) {
		my @solution;
		if (Task::Route->getRoute(\@solution, $self->{source}{field}, {x => $self->{source}{x}, y => $self->{source}{y}}, {x => $dest_x, y => $dest_y})) {
			my $distance = scalar(@solution);
			$self->{saveMapDistanceCache} = { key => $cacheKey, value => $distance };
			return $distance;
		}
		return;
	}

	my $task = $self->runCalcMapRouteSubtask(
		targets => [{ map => $dest_map, x => $dest_x, y => $dest_y }],
		sourceMap => $self->{source}{map},
		sourceX => $self->{source}{x},
		sourceY => $self->{source}{y},
		noGoCommand => 1,
		noTeleSpawn => 1,
		maxTime => 3,
		suppressDebug => 1,
	);

	return if ($task->getError());
	my $distance = $self->getRouteTailWalk($task);
	$distance = 0 if !defined $distance;
	$self->{saveMapDistanceCache} = { key => $cacheKey, value => $distance };
	return $distance;
}

sub isSaveMapSetAndValid {
	my ($self) = @_;
	return defined $self->resolveSaveMapDestination();
}

sub resolveSaveMapDestination {
	my ($self) = @_;

	my $target = ($self->{targets} && ref($self->{targets}) eq 'ARRAY' && @{$self->{targets}}) ? $self->{targets}[0] : undef;
	my $cacheKey = join('|',
		hashSafeGetValue(\%config, 'saveMap') // '',
		hashSafeGetValue(\%config, 'saveMap_x') // '',
		hashSafeGetValue(\%config, 'saveMap_y') // '',
		($target && defined $target->{map}) ? $target->{map} : '',
		($target && defined $target->{x}) ? $target->{x} : '',
		($target && defined $target->{y}) ? $target->{y} : '',
	);
	if ($self->{saveMapDestinationCache} && $self->{saveMapDestinationCache}{key} eq $cacheKey) {
		return $self->{saveMapDestinationCache}{value};
	}

	my $dest_map = hashSafeGetValue(\%config, 'saveMap');
	return unless (defined $dest_map && $dest_map ne '');

	my $candidates = $self->collectSpawnCandidatesForMap($dest_map);
	my $dest_x = hashSafeGetValue(\%config, 'saveMap_x');
	my $dest_y = hashSafeGetValue(\%config, 'saveMap_y');
	if (defined $dest_x && defined $dest_y && $dest_x ne '' && $dest_y ne '') {
		my $dest = $dest_map . " " . $dest_x . " " . $dest_y;
		if (hashSafeGetValue(\%portals_spawns, $dest, 'dest', $dest)) {
			my $fixedSaveMapDestination = { map => $dest_map, x => $dest_x, y => $dest_y };
			$self->{saveMapDestinationCache} = { key => $cacheKey, value => $fixedSaveMapDestination };
			return $fixedSaveMapDestination;
		}
	}

	my @candidates = values %{$candidates};
	return unless @candidates;
	return $candidates[0] if (@candidates == 1);

	if ($target && $target->{map}) {
		my $neighborMap = $self->getSaveMapNeighborFromWalkingRoute($dest_map, $target);
		if (defined $neighborMap && $neighborMap ne '') {
			my $neighborCandidates = $self->collectSpawnCandidatesForMap($dest_map, $neighborMap);

			if (%{$neighborCandidates}) {
				my @bestCandidates = sort {
					$a->{x} <=> $b->{x}
					|| $a->{y} <=> $b->{y}
				} values %{$neighborCandidates};

				$self->{saveMapDestinationCache} = { key => $cacheKey, value => $bestCandidates[0] };
				return $bestCandidates[0];
			}
		}
	}

	@candidates = sort {
		$a->{x} <=> $b->{x}
		|| $a->{y} <=> $b->{y}
	} @candidates;

	$self->{saveMapDestinationCache} = { key => $cacheKey, value => $candidates[0] };
	return $candidates[0];
}

sub getSaveMapNeighborFromWalkingRoute {
	my ($self, $saveMap, $target) = @_;
	return unless ($target && $target->{map});

	my $task = $self->runCalcMapRouteSubtask(
		targets => [{ map => $target->{map}, x => $target->{x}, y => $target->{y} }],
		sourceMap => $self->{source}{map},
		sourceX => $self->{source}{x},
		sourceY => $self->{source}{y},
		noGoCommand => 1,
		noTeleSpawn => 1,
		maxTime => 3,
		suppressDebug => 1,
	);

	return if ($task->getError());
	my $route = $task->getRoute();
	return if (!$route || !@{$route});

	foreach my $step (@{$route}) {
		my ($from, $to) = split(/=/, $step->{portal} || '', 2);
		next unless (defined $from && defined $to);
		my ($from_map) = split(/\s+/, $from, 2);
		my ($to_map) = split(/\s+/, $to, 2);
		next unless (defined $from_map && defined $to_map);

		if ($to_map eq $saveMap) {
			return $from_map;
		} elsif ($from_map eq $saveMap) {
			return $to_map;
		}
	}

	return;
}

1;
