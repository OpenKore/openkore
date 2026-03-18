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
use Misc qw(canUseTeleport);
use Utils qw(timeOut);
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
	$self->{targets} = $args{targets};
	$_->{map} = ( Field::nameToBaseName( undef, $_->{map} ) )[0] foreach @{ $args{targets} };
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

	if (exists $args{noGoCommand}) {
		$self->{noGoCommand} = $args{noGoCommand}
	} else {
		$self->{noGoCommand} = 0;
	}
	$self->{noGoCommandMaps} = $args{noGoCommandMaps} || {};

	if (exists $args{noTeleSpawn}) {
		$self->{noTeleSpawn} = $args{noTeleSpawn}
	} else {
		$self->{noTeleSpawn} = 0;
	}
	$self->{noTeleSpawnMaps} = $args{noTeleSpawnMaps} || {};
	$self->{noWarpItemMaps} = $args{noWarpItemMaps} || {};

	if (exists $args{noWarpItem}) {
		$self->{noWarpItem} = $args{noWarpItem}
	} else {
		$self->{noWarpItem} = 0;
	}

	if (exists $args{noAirship}) {
		$self->{noAirship} = $args{noAirship}
	} else {
		$self->{noAirship} = 0;
	}

	$self->{maxTime} = $args{maxTime} || $timeout{ai_route_calcRoute}{timeout};

	my $tickets = $char->inventory->getByNameID(7060);

	if ($tickets) {
		$self->{tickets_amount} = $tickets->{amount};
	} else {
		$self->{tickets_amount} = 0;
	}

	$self->{stage} = INITIALIZE;
	$self->{openlist} = {};
	$self->{closelist} = {};
	$self->{mapSolution} = [];
	$self->{solution} = [];
	$self->{mapChangeWeight} = $args{mapChangeWeight} || 1;

	return $self;
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();

	if ($self->{stage} == INITIALIZE) {
		my $openlist = $self->{openlist};
		my $closelist = $self->{closelist};
		foreach ( @{ $self->{targets} } ) {
			$_->{field} = eval { Field->new( name => $_->{map} ) };
			if ( caught( 'FileNotFoundException', 'IOException' ) ) {
				$self->setError( CANNOT_LOAD_FIELD, TF( "Cannot load field '%s'.", $_->{map} ) );
				return;
			} elsif ( $@ ) {
				die $@;
			}

			# Check whether destination is walkable from the starting point.
			if ( $self->{source}{map} eq $_->{map} && Task::Route->getRoute( undef, $_->{field}, $self->{source}, $_, 0 ) ) {
				$self->{mapSolution} = [];
				$self->{target} = $_;
				$self->{target}->{pos}->{x} = $_->{x};
				$self->{target}->{pos}->{y} = $_->{y};
				$self->setDone();
				return;
			}
		}

		# Initializes the openlist with portals walkable from the starting point.
		foreach my $portal (keys %portals_lut) {
			my $entry = $portals_lut{$portal};
			next if ($entry->{source}{map} ne $self->{source}{field}->baseName);
			my $ret = Task::Route->getRoute($self->{solution}, $self->{source}{field}, $self->{source}, $entry->{source});
			if ($ret) {
				for my $dest (grep { $entry->{dest}{$_}{enabled} } keys %{$entry->{dest}}) {
					my $penalty = int(($entry->{dest}{$dest}{steps} ne '') ? $routeWeights{NPC} : $routeWeights{PORTAL});
					$openlist->{"$portal=$dest"}{walk} = $penalty + scalar @{$self->{solution}};
					$openlist->{"$portal=$dest"}{zeny} = $entry->{dest}{$dest}{cost};
					$openlist->{"$portal=$dest"}{allow_ticket} = $entry->{dest}{$dest}{allow_ticket};
					if ($self->{tickets_amount} > 0 && $openlist->{"$portal=$dest"}{allow_ticket}) {
						$openlist->{"$portal=$dest"}{zeny_covered_by_tickets} = $openlist->{"$portal=$dest"}{zeny};
						$openlist->{"$portal=$dest"}{amount_of_tickets_used} = 1;
					} else {
						$openlist->{"$portal=$dest"}{zeny_covered_by_tickets} = 0;
						$openlist->{"$portal=$dest"}{amount_of_tickets_used} = 0;
					}
				}
			}
		}

		$self->populateOpenListWithGoCommands(
			"$self->{source}{map} $self->{source}{x} $self->{source}{y}",
			{ walk => 0, zeny => 0, zeny_covered_by_tickets => 0, amount_of_tickets_used => 0 },
			undef,
		) unless ($self->{noGoCommand});

		delete $self->{tempPortalsSaveMap} if (exists $self->{tempPortalsSaveMap});
		delete $self->{tempPortalsWarpItems} if (exists $self->{tempPortalsWarpItems});
		if (!$self->{noTeleSpawn} && canUseTeleport(2) && $self->isSaveMapSetAndValid()) {
			$self->populateOpenListWithWarpToSaveMap(
				"$self->{source}{map} $self->{source}{x} $self->{source}{y}",
				{ walk => 0, zeny => 0, zeny_covered_by_tickets => 0, amount_of_tickets_used => 0 },
				undef,
			);
		}
		unless ($self->{noWarpItem}) {
			$self->populateOpenListWithWarpByItems(
				"$self->{source}{map} $self->{source}{x} $self->{source}{y}",
				{ walk => 0, zeny => 0, zeny_covered_by_tickets => 0, amount_of_tickets_used => 0 },
				undef,
			);
		}

		# Initializes the openlist with airships walkable from the starting point.
		unless ($self->{noAirship}) {
			foreach my $portal (keys %portals_airships) {
				my $entry = $portals_airships{$portal};
				next if ($entry->{source}{map} ne $self->{source}{field}->baseName);
				my $ret = Task::Route->getRoute($self->{solution}, $self->{source}{field}, $self->{source}, $entry->{source});
				if ($ret) {
					for my $dest (grep { $entry->{dest}{$_}{enabled} } keys %{$entry->{dest}}) {
						my $penalty = $routeWeights{AIRSHIP};
						$openlist->{"$portal=$dest"}{walk} = $penalty + scalar @{$self->{solution}};
						$openlist->{"$portal=$dest"}{is_airship} = 1;
						$openlist->{"$portal=$dest"}{airship_message} = $entry->{dest}{$dest}{message};
					}
				}
			}
		}

		$self->{stage} = CALCULATE_ROUTE;
		debug "CalcMapRoute - initialized with '".(scalar keys %{$openlist})."' options.\n", "calc_map_route";

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
			debug "Map Solution Ready for traversal.\n", "calc_map_route";
			debug sprintf("%s\n", $self->getRouteString()), "calc_map_route";

		} elsif ($self->{done}) {
			my $destpos = $self->{targets}[0]->{x} ? " (".$self->{targets}[0]->{x}.",".$self->{targets}[0]->{y}.")" : undef;
			$self->setError(CANNOT_CALCULATE_ROUTE, TF("Cannot calculate a route from %s (%d,%d) to %s%s",
				$self->{source}{field}->baseName, $self->{source}{x}, $self->{source}{y},
				$self->{targets}[0]->{map} || T("unknown"), $destpos));
			debug "CalcMapRoute failed.\n", "calc_map_route";
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
	my $parent = (sort {$openlist->{$a}{walk} <=> $openlist->{$b}{walk}} keys %{$openlist})[0];
	debug "[CalcMapRoute - searchStep - Loop] $parent, $openlist->{$parent}{walk}\n", "calc_map_route";

	# Uncomment this if you want minimum MAP count. Otherwise use the above for minimum step count
	#foreach my $parent (keys %{$openlist})
		my ($portal, $dest) = split /=/, $parent;
		# skip if budget exceeded
		if ($self->{budget} ne '' && $self->{budget} < ($openlist->{$parent}{zeny} - $openlist->{$parent}{zeny_covered_by_tickets})) {
			# This link is too expensive
			delete $openlist->{$parent};
			next;

		} else {
			# MOVE this entry into the CLOSELIST
			$closelist->{$parent} = delete $openlist->{$parent};
		}

		# support to multiple targets
		foreach my $target ( @{ $self->{targets} } ) {
			my $map_name = hashSafeGetValue(\%portals_lut, $portal, 'dest', $dest, 'map')
						|| hashSafeGetValue(\%portals_commands, $dest, 'dest', $dest, 'map') 
						|| hashSafeGetValue($self->{tempPortalsSaveMap}, $dest, 'dest', $dest, 'map') 
						|| hashSafeGetValue($self->{tempPortalsWarpItems}, $dest, 'dest', $dest, 'map')
						|| hashSafeGetValue(\%portals_airships, $portal, 'dest', $dest, 'map')
						|| undef;

			my $map_destination = hashSafeGetValue(\%portals_lut, $portal, 'dest', $dest)
							|| hashSafeGetValue(\%portals_commands, $dest, 'dest', $dest)
							|| hashSafeGetValue($self->{tempPortalsSaveMap}, $dest, 'dest', $dest)
							|| hashSafeGetValue($self->{tempPortalsWarpItems}, $dest, 'dest', $dest)
							|| hashSafeGetValue(\%portals_airships, $portal, 'dest', $dest)
							|| undef;

			next if $map_name ne $target->{map}; # checks if the current destination map matches any of the search targets.
			# if no x or y consider that is already at destination
			if ( !$target->{x} || !$target->{y} ) {
				$self->{found} = $parent;
			}
			# uses getRoute to check whether you have reached exactly the desired point on the map.
			elsif ( Task::Route->getRoute($self->{solution}, $target->{field}, $map_destination, $target) ) {
				my $walk = $self->{found} = "$target->{map} $target->{x} $target->{y}=$target->{map} $target->{x} $target->{y}";
				$closelist->{$walk}         = { %{ $closelist->{$parent} } };
				$closelist->{$walk}{walk}   = scalar @{ $self->{solution} } + $closelist->{$parent}{walk};
				$closelist->{$walk}{parent} = $parent;
				$closelist->{$walk}{is_command} = 0;
				$closelist->{$walk}{command} = undef;
				$closelist->{$walk}{is_teleportToSaveMap} = 0;
				$closelist->{$walk}{is_teleportItemWarp} = 0;
				$closelist->{$walk}{teleportItemID} = undef;
				$closelist->{$walk}{teleportItemTimeoutSec} = 0;
				$closelist->{$walk}{teleportItemRequiredEquipSlot} = undef;
				$closelist->{$walk}{teleportItemRequiredEquipItemID} = undef;
				$closelist->{$walk}{is_airship} = 0;
				$closelist->{$walk}{airship_message} = undef;
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
					my %arg;
					$arg{portal} = $this;
					my ($from, $to) = split /=/, $this;
					($arg{map}, $arg{pos}{x}, $arg{pos}{y}) = split / /, $from;
					$arg{walk} = $closelist->{$this}{walk};
					$arg{zeny} = $closelist->{$this}{zeny};
					$arg{allow_ticket} = $closelist->{$this}{allow_ticket};
					$arg{zeny_covered_by_tickets} = $closelist->{$this}{zeny_covered_by_tickets};
					$arg{amount_of_tickets_used} = $closelist->{$this}{amount_of_tickets_used};
					if ($closelist->{$this}{is_airship}) {
						$arg{steps} = $portals_airships{$from}{dest}{$to}{steps};
					} else {
						$arg{steps} = $portals_lut{$from}{dest}{$to}{steps};
					}
					$arg{is_command} =  $closelist->{$this}{is_command} || 0;
					$arg{command} = $closelist->{$this}{command};
					$arg{is_teleportToSaveMap} = $closelist->{$this}{is_teleportToSaveMap} || 0;
					$arg{is_teleportItemWarp} = $closelist->{$this}{is_teleportItemWarp} || 0;
					$arg{teleportItemID} = $closelist->{$this}{teleportItemID};
					$arg{teleportItemTimeoutSec} = $closelist->{$this}{teleportItemTimeoutSec} || 0;
					$arg{teleportItemRequiredEquipSlot} = $closelist->{$this}{teleportItemRequiredEquipSlot};
					$arg{teleportItemRequiredEquipItemID} = $closelist->{$this}{teleportItemRequiredEquipItemID};
					$arg{is_airship} = $closelist->{$this}{is_airship} || 0;
					$arg{airship_message} = $closelist->{$this}{airship_message};

					unshift @{$self->{mapSolution}}, \%arg;
					$this = $closelist->{$this}{parent};
				}
				return;
			}
		}

		# get all children of each openlist.
		$self->populateOpenListWithGoCommands($dest, $closelist->{$parent}, $parent) unless ($self->{noGoCommand});
		if (!$self->{noTeleSpawn} && canUseTeleport(2) && $self->isSaveMapSetAndValid()) {
			$self->populateOpenListWithWarpToSaveMap($dest, $closelist->{$parent}, $parent);
		}
		if (!$self->{noWarpItem}) {
			$self->populateOpenListWithWarpByItems($dest, $closelist->{$parent}, $parent);
		}
		
		# explore connected portals and NPC warps
		foreach my $child (keys %{$portals_los{$dest}}) {
			next unless $portals_los{$dest}{$child}; # next if no child
			# iterates through the child's/portals that have connection to destination
			foreach my $subchild (grep { $portals_lut{$child}{dest}{$_}{enabled} } keys %{$portals_lut{$child}{dest}}) {
				my $destID = $subchild;
				my $mapName = $portals_lut{$child}{source}{map};
				#############################################################
				my $penalty = int($routeWeights{lc($mapName)}) +
					int(($portals_lut{$child}{dest}{$subchild}{steps} ne '') ? $routeWeights{NPC} : $routeWeights{PORTAL}); # get node/child penalty based on routeWeights
				my $thisWalk = $penalty + $closelist->{$parent}{walk} + $portals_los{$dest}{$child}; # calculate the final node/child penalty routeWeights + walk distance + accumulated cost
				if (!exists $closelist->{"$child=$subchild"}) { # check if node is already explorated
					if ( !exists $openlist->{"$child=$subchild"} || $openlist->{"$child=$subchild"}{walk} > $thisWalk ) { # check the current node cost less
						debug "[CalcMapRoute - searchStep - Add] from '$parent' to '$child=$subchild' cost '$thisWalk'\n", "calc_map_route", 2;
						my $key = "$child=$subchild";
						my $value = {
							parent => $parent,
							walk => $thisWalk,
							allow_ticket => $portals_lut{$child}{dest}{$subchild}{allow_ticket}
						};

						if ($value->{allow_ticket} && $self->{tickets_amount} > $closelist->{$parent}{amount_of_tickets_used}) {
							$value->{zeny_covered_by_tickets} = $closelist->{$parent}{zeny_covered_by_tickets} + $portals_lut{$child}{dest}{$subchild}{cost};
							$value->{amount_of_tickets_used} = $closelist->{$parent}{amount_of_tickets_used} + 1;
							$value->{zeny} = $closelist->{$parent}{zeny};

						} else {
							$value->{zeny_covered_by_tickets} = $closelist->{$parent}{zeny_covered_by_tickets};
							$value->{amount_of_tickets_used} = $closelist->{$parent}{amount_of_tickets_used};
							$value->{zeny} = $closelist->{$parent}{zeny} + $portals_lut{$child}{dest}{$subchild}{cost};
						}

						$self->add_key_to_openList($key, $value);
					}
				}
			}

			next if ($self->{noAirship} || !exists $portals_airships{$child});
			# iterates airships
			foreach my $subchild (grep { $portals_airships{$child}{dest}{$_}{enabled} } keys %{$portals_airships{$child}{dest}}) {
				my $destID = $subchild;
				my $mapName = $portals_airships{$child}{source}{map};
				#############################################################
				my $penalty = int($routeWeights{lc($mapName)}) + $routeWeights{AIRSHIP}; # get node/child penalty based on routeWeights
				my $thisWalk = $penalty + $closelist->{$parent}{walk} + $portals_los{$dest}{$child}; # calculate the final node/child penalty routeWeights + walk distance + accumulated cost
				if (!exists $closelist->{"$child=$subchild"}) { # check if node is already explorated
					if ( !exists $openlist->{"$child=$subchild"} || $openlist->{"$child=$subchild"}{walk} > $thisWalk ) { # check the current node cost less
						my $key = "$child=$subchild";
						my $value = {
							parent => $parent,
							walk => $thisWalk,
							zeny => $closelist->{$parent}{zeny},
							zeny_covered_by_tickets => $closelist->{$parent}{zeny_covered_by_tickets},
							amount_of_tickets_used => $closelist->{$parent}{amount_of_tickets_used}
						};
						$value->{airship_message} = $portals_airships{$child}{dest}{$subchild}{message};
						$value->{is_airship} = 1;
						$self->add_key_to_openList($key, $value);
					}
				}
			}
		}
}

# Add @go commands to openlist
sub populateOpenListWithGoCommands {
	my ($self, $from_node, $baseCost, $parent) = @_;
	return unless $from_node;

	my ($current_map) = split / /, $from_node, 2;
	return unless $self->isGoCommandAllowedOnMap($current_map);

	# iterate through the commands
	foreach my $portal (keys %portals_commands) {
		foreach my $dest (keys %{$portals_commands{$portal}{dest}}) {
			my $to_node = $portals_commands{$portal}{dest}{$dest}{map} . " " . $portals_commands{$portal}{dest}{$dest}{x} . " " . $portals_commands{$portal}{dest}{$dest}{y};
			my $key = "$from_node=$to_node";
			my $walk = ($baseCost->{walk} || 0) + ($routeWeights{COMMAND} || 20);
			my $zeny = $baseCost->{zeny} || 0;
			my $zeny_covered_by_tickets = $baseCost->{zeny_covered_by_tickets} || 0;
			my $amount_of_tickets_used = $baseCost->{amount_of_tickets_used} || 0;

			next if (exists $self->{closelist}{$key} && $self->{closelist}{$key}{walk} <= $walk);
			next if (exists $self->{openlist}{$key} && $self->{openlist}{$key}{walk} <= $walk);

			# add @go option as a synthetic portal
			$self->add_key_to_openList($key, {
				parent                   => $parent,
				walk                     => $walk,
				zeny                     => $zeny,
				allow_ticket             => 0,
				zeny_covered_by_tickets  => $zeny_covered_by_tickets,
				amount_of_tickets_used   => $amount_of_tickets_used,
				is_command               => 1,
				command                  => $portals_commands{$portal}{dest}{$dest}{command},
			});
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

	my @warpItemCandidates = $self->getWarpItemCandidates();
	return unless @warpItemCandidates;

	return unless ($self->isWarpToSaveMapMinDistanceReached());
	my $saveMapDestination = $self->resolveSaveMapDestination();
	return unless ($saveMapDestination);

	my $dest_map = $saveMapDestination->{map};
	my $dest_x = $saveMapDestination->{x};
	my $dest_y = $saveMapDestination->{y};

	my $dest = $dest_map . " " . $dest_x . " " . $dest_y;

	debug "CalcMapRoute - Adding savemap '".( $dest )."' to openlist.\n", "calc_map_route";

	return if ($dest eq $from_node);
	my $key = "$from_node=$dest";
	my $walk = ($baseCost->{walk} || 0) + ($routeWeights{WARPTOSAVEMAP} || 200);
	my $zeny = $baseCost->{zeny} || 0;
	my $zeny_covered_by_tickets = $baseCost->{zeny_covered_by_tickets} || 0;
	my $amount_of_tickets_used = $baseCost->{amount_of_tickets_used} || 0;

	return if (exists $self->{closelist}{$key} && $self->{closelist}{$key}{walk} <= $walk);
	return if (exists $self->{openlist}{$key} && $self->{openlist}{$key}{walk} <= $walk);

	$self->add_key_to_openList($key, {
		parent                   => $parent,
		walk                     => $walk,
		zeny                     => $zeny,
		allow_ticket             => 0,
		zeny_covered_by_tickets  => $zeny_covered_by_tickets,
		amount_of_tickets_used   => $amount_of_tickets_used,
		is_teleportToSaveMap     => 1,
	});

	$self->{tempPortalsSaveMap}{$dest}{'dest'}{$dest}{'map'} = $dest_map;
	$self->{tempPortalsSaveMap}{$dest}{'dest'}{$dest}{'x'} = $dest_x;
	$self->{tempPortalsSaveMap}{$dest}{'dest'}{$dest}{'y'} = $dest_y;
	$self->{tempPortalsSaveMap}{$dest}{dest}{$dest}{enabled} = 1;
}


sub populateOpenListWithWarpByItems {
	my ($self, $from_node, $baseCost, $parent) = @_;
	return unless $from_node;
	return unless $config{route_warpByItem};

	my ($current_map) = split / /, $from_node, 2;
	return unless $self->isWarpByItemAllowedOnMap($current_map);

	for my $entry ($self->getWarpItemCandidates()) {
		my $dest = $entry->{destMap} . ' ' . $entry->{destX} . ' ' . $entry->{destY};
		next if ($dest eq $from_node);
		my $key = "$from_node=$dest";
		my $walk = ($baseCost->{walk} || 0) + ($routeWeights{WARPITEM} || 80);
		my $zeny = $baseCost->{zeny} || 0;
		my $zeny_covered_by_tickets = $baseCost->{zeny_covered_by_tickets} || 0;
		my $amount_of_tickets_used = $baseCost->{amount_of_tickets_used} || 0;

		next if (exists $self->{closelist}{$key} && $self->{closelist}{$key}{walk} <= $walk);
		next if (exists $self->{openlist}{$key} && $self->{openlist}{$key}{walk} <= $walk);

		$self->add_key_to_openList($key, {
			parent => $parent,
			walk => $walk,
			zeny => $zeny,
			allow_ticket => 0,
			zeny_covered_by_tickets => $zeny_covered_by_tickets,
			amount_of_tickets_used => $amount_of_tickets_used,
			is_teleportItemWarp => 1,
			teleportItemID => $entry->{itemID},
			teleportItemTimeoutSec => $entry->{timeoutSec} || 0,
			teleportItemRequiredEquipSlot => $entry->{requiredEquipSlot},
			teleportItemRequiredEquipItemID => $entry->{requiredEquipItemID},
		});

		$self->{tempPortalsWarpItems}{$dest}{'dest'}{$dest}{'map'} = $entry->{destMap};
		$self->{tempPortalsWarpItems}{$dest}{'dest'}{$dest}{'x'} = $entry->{destX};
		$self->{tempPortalsWarpItems}{$dest}{'dest'}{$dest}{'y'} = $entry->{destY};
		$self->{tempPortalsWarpItems}{$dest}{dest}{$dest}{enabled} = 1;
	}
}

sub add_key_to_openList {
	my ($self, $key, $value) = @_;
	debug "[add_key_to_openList] Adding key [$key] to openlist (now has ".(scalar keys %{$self->{openlist}})." items)\n";
	$self->{openlist}{$key} = $value;
}

sub getWarpItemCandidates {
	my ($self) = @_;
	return unless ($char && $char->inventory && $char->inventory->isReady());
	return unless (scalar keys %teleport_items);

	my @matches;
	for my $key (keys %teleport_items) {
		my $value = $teleport_items{$key};
		next unless ($value);
		my $entry = $value->{entry};
		next unless ($entry);
		
		next unless ($entry->{mode} eq 'warp' || $entry->{mode} eq 'any');
		next if ($entry->{minLevel} && $char->{lv} < $entry->{minLevel});
		next if ($entry->{maxLevel} && $char->{lv} > $entry->{maxLevel});
		next unless $self->isWarpItemRoutingDestinationValid($entry);

		my $item = $char->inventory->getByNameID($entry->{itemID});
		next unless $item;
		next unless Misc::canTeleportItemEquipRequirementBeSatisfied($entry);

		if ($entry->{timeoutSec} && $char->{last_teleport_item_use}{$entry->{itemID}}) {
			next if time - $char->{last_teleport_item_use}{$entry->{itemID}} < $entry->{timeoutSec};
		}

		push @matches, $entry;
	}
	return @matches;
}

sub isWarpItemRoutingDestinationValid {
	my ($self, $entry) = @_;
	return 0 unless ($entry && defined $entry->{destMap} && $entry->{destMap} ne '');

	my $destMap = lc($entry->{destMap});
	return 0 if ($destMap eq '*' || $destMap eq 'any' || $destMap eq 'save');
	return 1;
}

sub isWarpItemRoutingDestinationValid {
	my ($self, $entry) = @_;
	return 0 unless ($entry && defined $entry->{destMap} && $entry->{destMap} ne '');

	my $destMap = lc($entry->{destMap});
	return 0 if ($destMap eq '*' || $destMap eq 'any' || $destMap eq 'save');
	return 1;
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

	my $task = Task::CalcMapRoute->new(
		targets => [{ map => $dest_map, x => $dest_x, y => $dest_y }],
		sourceMap => $self->{source}{map},
		sourceX => $self->{source}{x},
		sourceY => $self->{source}{y},
		noGoCommand => 1,
		noTeleSpawn => 1,
		maxTime => 3,
	);
	$task->activate();

	while ($task->getStatus() != Task::DONE) {
		$task->iterate();
	}

	return if ($task->getError());
	my $route = $task->getRoute();
	my $distance = (!$route || !@{$route}) ? 0 : $route->[-1]{walk};
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

	my %candidates;
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

	foreach my $portal (keys %portals_spawns) {
		foreach my $dest (keys %{$portals_spawns{$portal}{dest}}) {
			next if (hashSafeGetValue(\%portals_spawns, $portal, 'dest', $dest, 'map') ne $dest_map);
			my $x = hashSafeGetValue(\%portals_spawns, $portal, 'dest', $dest, 'x');
			my $y = hashSafeGetValue(\%portals_spawns, $portal, 'dest', $dest, 'y');
			next if (!defined $x || !defined $y || $x eq '' || $y eq '');
			$candidates{"$x $y"} = { map => $dest_map, x => $x, y => $y };
		}
	}

	my @candidates = values %candidates;
	return unless @candidates;
	return $candidates[0] if (@candidates == 1);

	if ($target && $target->{map}) {
		my $neighborMap = $self->getSaveMapNeighborFromWalkingRoute($dest_map, $target);
		if (defined $neighborMap && $neighborMap ne '') {
			my %neighborCandidates;
			foreach my $portal (keys %portals_spawns) {
				my ($portal_map) = split(/\s+/, $portal, 2);
				next if (!defined $portal_map || $portal_map ne $neighborMap);
				foreach my $dest (keys %{$portals_spawns{$portal}{dest}}) {
					next if (hashSafeGetValue(\%portals_spawns, $portal, 'dest', $dest, 'map') ne $dest_map);
					my $x = hashSafeGetValue(\%portals_spawns, $portal, 'dest', $dest, 'x');
					my $y = hashSafeGetValue(\%portals_spawns, $portal, 'dest', $dest, 'y');
					next if (!defined $x || !defined $y || $x eq '' || $y eq '');
					$neighborCandidates{"$x $y"} = { map => $dest_map, x => $x, y => $y };
				}
			}

			if (%neighborCandidates) {
				my @bestCandidates = sort {
					$a->{x} <=> $b->{x}
					|| $a->{y} <=> $b->{y}
				} values %neighborCandidates;

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

	my $task = Task::CalcMapRoute->new(
		targets => [{ map => $target->{map}, x => $target->{x}, y => $target->{y} }],
		sourceMap => $self->{source}{map},
		sourceX => $self->{source}{x},
		sourceY => $self->{source}{y},
		noGoCommand => 1,
		noTeleSpawn => 1,
		maxTime => 3,
	);
	$task->activate();

	while ($task->getStatus() != Task::DONE) {
		$task->iterate();
	}

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
