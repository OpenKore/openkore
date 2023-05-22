#########################################################################
#  OpenKore - Inter-map movement task
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# The MapRoute task is like the Route task, but allows you to walk routes
# that span different maps.
package Task::MapRoute;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;

use Modules 'register';
use Globals;
use Task::WithSubtask;
use Task::Route;
use Task::CalcMapRoute;
use Task::TalkNPC;
use base qw(Task::WithSubtask);
use Translation qw(T TF);
use Log qw(message debug warning error);
use Network;
use Plugins;
use Misc qw(canUseTeleport portalExists);
use Utils qw(timeOut blockDistance existsInList);
use Utils::PathFinding;
use Utils::Exceptions;
use AI qw(ai_useTeleport);


# Error constants.
use enum (
	# Routing errors
	qw(TOO_MUCH_TIME
	CANNOT_CALCULATE_ROUTE
	STUCK
	CANNOT_LOAD_FIELD),

	# NPC errors
	qw(NPC_NOT_FOUND
	NPC_NO_RESPONSE
	NO_SHOP_ITEM
	WRONG_NPC_INSTRUCTIONS),

	qw(UNKNOWN_ERROR)
);


# TODO: this task should lock the 'npc' mutex when talking to NPCs!


##
# Task::MapRoute->new(options...)
#
# Create a new Task::Route object. The following options are allowed:
# `l
# - All options allowed by Task::WithSubtask->new(), except 'mutexes', 'autostop' and 'autofail'.
# - map (required) - The map you want to go to, for example "prontera".
# - x, y - The coordinate on the destination map you want to walk to. On some maps this is
#          important because they're split by a river. Depending on which side of the river
#          you want to be, the route may be different.
# - maxDistance - The maximum distance (in blocks) that the route may be. If
#                 not specified, then there is no limit.
# - maxTime - The maximum time that may be spent on walking the route. If not
#             specified, then there is no time limit.
# - distFromGoal - Stop walking if we're within the specified distance (in blocks)
#                  from the goal. If not specified, then we'll walk until the
#                  destination is reached.
# - pyDistFromGoal - Same as distFromGoal, but this allows you to specify the
#                    Pythagorian distance instead of block distance.
# - avoidWalls - Whether to avoid walls. The default is true.
# - notifyUponArrival - Whether to print a message when we've reached the destination.
#                       The default is no.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	# TODO: do we need a mutex 'npc' too?
	my $self = $class->SUPER::new(@_, autostop => 1, autofail => 0, mutexes => ['movement']);

	unless ($args{actor}->isa('Actor') and $args{map}) {
		ArgumentException->throw(error => "Task::MapRoute: Invalid arguments.");
	}

	my $allowed = new Set(qw(maxDistance maxTime distFromGoal pyDistFromGoal avoidWalls notifyUponArrival attackID attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget));
	foreach my $key (keys %args) {
		if ($allowed->has($key) && defined $args{$key}) {
			$self->{$key} = $args{$key};
		}
	}

	$self->{actor} = $args{actor};
	($self->{dest}{map}, undef) = Field::nameToBaseName(undef, $args{map}); # Hack to clean up InstanceID
	# $self->{dest}{map} = $args{map};
	$self->{dest}{pos}{x} = $args{x};
	$self->{dest}{pos}{y} = $args{y};
	if ($config{'route_avoidWalls'}) {
		$self->{avoidWalls} = 1 if (!defined $self->{avoidWalls});
	} else {$self->{avoidWalls} = 0;}

	# Watch for map change events. Pass a weak reference to ourselves in order
	# to avoid circular references (memory leaks).
	my @holder = ($self);
	Scalar::Util::weaken($holder[0]);
	$self->{mapChangedHook} = Plugins::addHook('Network::Receive::map_changed', \&mapChanged, \@holder);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{mapChangedHook}) if $self->{mapChangedHook};
	$self->SUPER::DESTROY();
}

sub activate {
	my ($self) = @_;
	$self->SUPER::activate();
	$self->initMapCalculator() if ($net->getState() == Network::IN_GAME && $field);
	$self->{time_start} = time;
}

sub iterate {
	my ($self) = @_;
	return if (!$self->SUPER::iterate() || $net->getState() != Network::IN_GAME);
	# FIXME: don't use global $field in tasks
	return unless defined $field && defined $self->{actor}{pos_to} && defined $self->{actor}{pos_to}{x} && defined $self->{actor}{pos_to}{y};

	# When the CalcMapRouter subtask finishes, a new Route task may be set as subtask.
	# In that case we don't want to continue or this MapRoute task may end prematurely.
	#
	# If the Route task bails out with an error then our subtaskDone() method will set
	# an error in this task too. In that case we don't want to continue.
	return if ($self->getSubtask() || $self->getStatus() != Task::RUNNING);

	my @solution;
	if (!$self->{mapSolution}) {
		$self->initMapCalculator();

	} elsif (@{$self->{mapSolution}} == 0) {
		$self->setDone();
		debug "Map Router has finished traversing the map solution\n", "route";

	} elsif ( $field->baseName ne $self->{mapSolution}[0]{map}
	     || ( $self->{mapChanged} && !$self->{teleport} ) ) {
		# Solution Map does not match current map
		debug "Current map " . $field->baseName . " does not match solution [ $self->{mapSolution}[0]{portal} ].\n", "route";
		delete $self->{substage};
		delete $self->{timeout};
		delete $self->{mapChanged};
		delete $self->{missing_portal};
		delete $self->{guess_portal};
		shift @{$self->{mapSolution}};

	} elsif ( $self->{mapSolution}[0]{steps} ) {
		my $min_npc_dist = 8;
		my $max_npc_dist = 10;
		my $dist_to_npc = blockDistance($self->{actor}{pos}, $self->{mapSolution}[0]{pos});

		# If current solution has conversation steps specified
		if ( $self->{substage} eq 'Waiting for Warp' ) {
			$self->{timeout} = time unless $self->{timeout};

			if (exists $self->{mapSolution}[0]{error} || timeOut($self->{timeout}, $timeout{ai_route_npcTalk}{timeout} || 10)) {
				delete $self->{substage};
				delete $self->{timeout};

				warning TF("Failed to teleport using NPC at %s (%s,%s).\n", $field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}), "route";
				warning TF("NPC error: %s.\n", $self->{mapSolution}[0]{error}), "route" if (exists $self->{mapSolution}[0]{error});

				if ($self->{mapSolution}[0]{retry} < ($config{route_maxNpcTries} || 5)) {
					warning "Retrying for the ".$self->{mapSolution}[0]{retry}." time...\n", "route";
					delete $self->{mapSolution}[0]{error};

				} else {


					my %plugin_args = (
						x            => $self->{mapSolution}[0]{pos}{x},
						y            => $self->{mapSolution}[0]{pos}{y},
						steps        => $self->{mapSolution}[0]{steps},
						portal       => $self->{mapSolution}[0]{portal},
						plugin_retry => $self->{mapSolution}[0]{plugin_retry}
					);
					$plugin_args{plugin_retry} = 0 if (!defined $plugin_args{plugin_retry});
					$plugin_args{return} = 0;

					Plugins::callHook('npc_teleport_missing' => \%plugin_args);

					if ($plugin_args{return}) {
						$self->{mapSolution}[0]{retry} = 0;
						$self->{mapSolution}[0]{plugin_retry}++;
						$self->{mapSolution}[0]{pos}{x} = $plugin_args{x};
						$self->{mapSolution}[0]{pos}{y} = $plugin_args{y};
						$self->setNpcTalk();
					} else {
						# NPC sequence is a failure
						if ($config{route_removeMissingPortals_NPC}) {
							# We delete that portal and try again
							my $missed = {};
							$missed->{time} = time;
							$missed->{name} = "$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}";
							$missed->{portal} = $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
							push(@portals_lut_missed, $missed);
							delete $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
						}

						error TF("Failed to teleport using NPC at %s (%s,%s) after %s tries, ignoring NPC and recalculating route.\n", $field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}, $self->{mapSolution}[0]{retry}), "route";
						$self->initMapCalculator();	# redo MAP router
					}
				}
			}

		} elsif ($dist_to_npc <= $max_npc_dist) {
			my ($from,$to) = split /=/, $self->{mapSolution}[0]{portal};
			if (($self->{actor}{zeny} >= $portals_lut{$from}{dest}{$to}{cost}) || ($char->inventory->getByNameID(7060) && $portals_lut{$from}{dest}{$to}{allow_ticket})) {
				# We have enough money for this service.
				$self->setNpcTalk();

			} else {
				error TF("You need %sz to pay for warp service at %s (%s,%s), you have %sz.\n",
					$portals_lut{$from}{dest}{$to}{cost},
					$field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y},
					$self->{actor}{zeny}), "route";
					AI::clear(qw/move route mapRoute/);
					message T("Stopped all movement\n"), "success";
				$self->initMapCalculator();	# redo MAP router
			}

		} elsif ( $self->{maxTime} && time - $self->{time_start} > $self->{maxTime} ) {
			# We spent too long a time.
			debug "MapRoute - We spent too much time; bailing out.\n", "route";
			$self->setError(TOO_MUCH_TIME, "Too much time spent on route traversal.");

		} elsif ( Task::Route->getRoute(\@solution, $field, $self->{actor}{pos}, $self->{mapSolution}[0]{pos}) ) {
			# NPC is reachable from current position
			# >> Then "route" to it

			debug "Walking towards the NPC, min_npc_dist $min_npc_dist, max_npc_dist $max_npc_dist, current dist_to_npc $dist_to_npc\n", "route";
			my $task = new Task::Route(
				actor => $self->{actor},
				x => $self->{mapSolution}[0]{pos}{x},
				y => $self->{mapSolution}[0]{pos}{y},
				field => $field,
				maxTime => $self->{maxTime},
				distFromGoal => $min_npc_dist,
				avoidWalls => $self->{avoidWalls},
				solution => \@solution
			);
			$self->setSubtask($task);

		} else {
			# Error, NPC is not reachable from current pos
			debug "CRITICAL ERROR: NPC is not reachable from current location.\n", "route";
			error TF("Unable to walk from %s (%s,%s) to NPC at (%s,%s).\n", $field->baseName, @{$self->{actor}{pos}}{qw(x y)}, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}), "route";
			shift @{$self->{mapSolution}};
		}

	} elsif ( $self->{mapSolution}[0]{portal} eq "$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}=$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}" ) {
		# This solution points to an X,Y coordinate
		my $distFromGoal = $self->{pyDistFromGoal}
			? $self->{pyDistFromGoal}
			: ($self->{distFromGoal} ? $self->{distFromGoal} : 0);
		if ( $self->{mapSolution}[0]{routed} || $distFromGoal + 2 > blockDistance($self->{actor}{pos_to}, $self->{mapSolution}[0]{pos})) {
			# We need to specify +2 because sometimes the exact spot is occupied by someone else
			shift @{$self->{mapSolution}};

		} elsif ( $self->{maxTime} && time - $self->{time_start} > $self->{maxTime} ) {
			# We spent too long a time.
			debug "We spent too much time; bailing out.\n", "route";
			$self->setError(TOO_MUCH_TIME, "Too much time spent on route traversal.");

		} elsif ( Task::Route->getRoute(\@solution, $field, $self->{actor}{pos}, $self->{mapSolution}[0]{pos}) ) {
			# X,Y is reachable from current position
			# >> Then "route" to it
			my $task = new Task::Route(
				actor => $self->{actor},
				x => $self->{mapSolution}[0]{pos}{x},
				y => $self->{mapSolution}[0]{pos}{y},
				field => $field,
				maxTime => $self->{maxTime},
				avoidWalls => $self->{avoidWalls},
				distFromGoal => $self->{distFromGoal},
				pyDistFromGoal => $self->{pyDistFromGoal},
				solution => \@solution
			);
			$task->{$_} = $self->{$_} for qw(attackID attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget);
			$self->setSubtask($task);
			$self->{mapSolution}[0]{routed} = 1;

		} else {
			warning TF("No LOS from %s (%s,%s) to Final Destination at (%s,%s).\n",
				$field->baseName, @{$self->{actor}{pos}}{qw(x y)},
				$self->{mapSolution}[0]{pos}{x},
				$self->{mapSolution}[0]{pos}{y}), "route";
			error TF("Cannot reach (%s,%s) from current position.\n",
				$self->{mapSolution}[0]{pos}{x},
				$self->{mapSolution}[0]{pos}{y}), "route";
			shift @{$self->{mapSolution}};
		}

	} elsif ( $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"}{source} ) {
		# This is a portal solution

		if ($self->{missing_portal}) {

			if (!$config{route_tryToGuessMissingPortalByDistance}) {
				my $missed = {};
				$missed->{time} = time;
				$missed->{name} = "$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}";
				$missed->{portal} = $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
				push(@portals_lut_missed, $missed);
				delete $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
				warning TF("Unable to use portal at %s (%s,%s).\n", $field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}), "route";
				delete $self->{missing_portal};
				delete $self->{guess_portal};
				$self->initMapCalculator();	# redo MAP router

			} else {
				my $closest_portal_binID;
				my $closest_portal_dist;

				my $current_portal = portalExists($field->baseName, $self->{mapSolution}[0]{pos});
				my ($current_from,$current_to) = split /=/, $self->{mapSolution}[0]{portal};
				my ($current_to_map,$current_to_x,$current_to_y) = split / /, $current_to;
				my $current_pos = { x=>$current_to_x, y=>$current_to_y };
				debug TF("Bugged current portal at %s (%s,%s) to %s (%s,%s).\n", $field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}, $current_to_map, $current_to_x, $current_to_y), "route";
				PORTAL: for my $portal (@$portalsList) {
					my $exist_portal = portalExists($field->baseName, $portal->{pos});
					if ($current_portal && $exist_portal) {
						my $entry = $portals_lut{$exist_portal};
						DEST: for my $dest (grep { $entry->{dest}{$_}{enabled} } keys %{$entry->{dest}}) {
						debug TF("Possible exist portal at %s (%s,%s) to %s (%s,%s).\n", $field->baseName, $portal->{pos}{x}, $portal->{pos}{y}, $entry->{dest}{$dest}{map}, $entry->{dest}{$dest}{x}, $entry->{dest}{$dest}{y}), "route";
							next DEST unless ($entry->{dest}{$dest}{map} eq $current_to_map);
							next DEST unless ( ($entry->{dest}{$dest}{x} == $current_to_x && $entry->{dest}{$dest}{y} == $current_to_y) || (Task::Route->getRoute( \@solution, $field, $entry->{dest}{$dest}, $current_pos )) );
							#next DEST unless (blockDistance($entry->{dest}{$dest}, $current_pos) < 20);

							my $missed = {};
							$missed->{time} = time;
							$missed->{name} = "$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}";
							$missed->{portal} = $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
							push(@portals_lut_missed, $missed);
							delete $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
							warning TF("Unable to use portal at %s (%s,%s) but there is another similar close portal at %s (%s,%s).\n", $field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}, $field->baseName, $entry->{dest}{$dest}{x}, $entry->{dest}{$dest}{y}), "route";
							delete $self->{missing_portal};
							delete $self->{guess_portal};
							$self->initMapCalculator();	# redo MAP router
							return;
						}
						next PORTAL; # Only guess unknown portals
					}

					next PORTAL unless ( Task::Route->getRoute( \@solution, $field, $self->{actor}{pos}, $portal->{pos} ) );

					my $dist = blockDistance($self->{mapSolution}[0]{pos}, $portal->{pos});
					next PORTAL if (defined $closest_portal_dist && $closest_portal_dist < $dist);

					$closest_portal_binID = $portal->{binID};
					$closest_portal_dist = $dist;
				}

				if (!defined $closest_portal_binID) {
					my $missed = {};
					$missed->{time} = time;
					$missed->{name} = "$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}";
					$missed->{portal} = $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
					push(@portals_lut_missed, $missed);
					delete $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
					warning TF("Unable to use portal at %s (%s,%s).\n", $field->baseName, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}), "route";
					delete $self->{missing_portal};
					$self->initMapCalculator();	# redo MAP router

				} else {
					$self->{guess_portal} = $portalsList->get($closest_portal_binID);
					warning TF("Guessing our desired portal to be  %s (%s,%s).\n", $field->baseName, $self->{guess_portal}{pos}{x}, $self->{guess_portal}{pos}{y}), "route";
					my %params = (
						field => $field,
						solution => \@solution
					);
					$params{$_} = $self->{guess_portal}{pos}{$_} for qw(x y);
					$params{$_} = $self->{$_} for qw(actor maxTime avoidWalls);
					my $task = new Task::Route(%params);
					$task->{$_} = $self->{$_} for qw(attackID attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget);
					$self->setSubtask($task);
				}
			}

		} elsif ( $config{route_removeMissingPortals} && blockDistance($self->{actor}{pos_to}, $self->{mapSolution}[0]{pos}) == 0 ) {
				if (!exists $timeout{ai_portal_give_up}{time}) {
					$timeout{ai_portal_give_up}{time} = time;
					$timeout{ai_portal_give_up}{timeout} = $timeout{ai_portal_give_up}{timeout} || 10;
					return;
				}
				return unless (timeOut($timeout{ai_portal_give_up}));
				delete $timeout{ai_portal_give_up}{time};

				my %plugin_args;
				$plugin_args{object} = $self;
				$plugin_args{solution} = \@solution;
				$plugin_args{return} = 1;
				Plugins::callHook('Task::MapRoute::iterate::missing_portal', \%plugin_args);
				return if (!$plugin_args{return});

				$self->{missing_portal} = 1;

		} elsif ( blockDistance($self->{actor}{pos_to}, $self->{mapSolution}[0]{pos}) < 2 ) {

			# Portal is within 'Enter Distance'
			$timeout{ai_portal_wait}{timeout} = $timeout{ai_portal_wait}{timeout} || 0.5;
			if ( timeOut($timeout{ai_portal_wait}) ) {
				$self->{actor}->sendMove(map int, @{$self->{mapSolution}[0]{pos}}{qw(x y)});
				$timeout{'ai_portal_wait'}{'time'} = time;
			}

		} else {
			my $walk = 1;

			# Teleport until we're close enough to the portal
			$self->{teleport} = $config{route_teleport} if (!defined $self->{teleport});

			if ($self->{teleport} && !$field->isCity
			&& !existsInList($config{route_teleport_notInMaps}, $field->baseName)
			&& ( !$config{route_teleport_maxTries} || $self->{teleportTries} <= $config{route_teleport_maxTries} )) {
				my $minDist = $config{route_teleport_minDistance};

				if ($self->{mapChanged}) {
					undef $self->{sentTeleport};
					undef $self->{mapChanged};
				}

				if (!$self->{sentTeleport}) {
					# Find first inter-map portal
					my $portal;
					for my $x (@{$self->{mapSolution}}) {
						$portal = $x;
						last unless $x->{map} eq $x->{dest_map};
					}

					my $dist = new PathFinding(
						start => $self->{actor}{pos_to},
						dest => $portal->{pos},
						field => $field
					)->runcount;
					debug "Distance to portal ($portal->{portal}) is $dist\n", "route_teleport";

					if ($dist < 0 || $dist > $minDist) {
						if ($dist > 0 && $config{route_teleport_maxTries} && $self->{teleportTries} >= $config{route_teleport_maxTries}) {
							debug "Teleported $config{route_teleport_maxTries} times. Falling back to walking.\n", "route_teleport";
						} else {
							message TF("Attempting to teleport near portal, try #%s\n", ($self->{teleportTries} + 1)), "route_teleport";
							if (!canUseTeleport(1)) {
								$self->{teleport} = 0;
							} else {
								ai_useTeleport(1);
								$walk = 0;
								$self->{sentTeleport} = 1;
								$self->{teleportTime} = time;
								$self->{teleportTries}++;
							}
						}
					}

				} elsif (timeOut($self->{teleportTime}, 4)) {
					debug "Unable to teleport; falling back to walking.\n", "route_teleport";
					$self->{teleport} = 0;
				} else {
					$walk = 0;
				}
			}

			if ($walk) {
				if ( Task::Route->getRoute( \@solution, $field, $self->{actor}{pos}, $self->{mapSolution}[0]{pos} ) ) {
					# Portal is reachable from current position
					# >> Then "route" to it
					debug "Portal route within same map.\n", "route";
					my %plugin_args;
					$plugin_args{object} = $self;
					$plugin_args{solution} = \@solution;
					Plugins::callHook('Task::MapRoute::iterate::route_portal_near', \%plugin_args);
					return 0 if ($plugin_args{return});
					$self->{teleportTries} = 0;
					my $task = new Task::Route(
						actor => $self->{actor},
						x => $self->{mapSolution}[0]{pos}{x},
						y => $self->{mapSolution}[0]{pos}{y},
						field => $field,
						maxTime => $self->{maxTime},
						avoidWalls => $self->{avoidWalls},
						solution => \@solution
					);
					$task->{$_} = $self->{$_} for qw(attackID attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget);
					$self->setSubtask($task);

				} else {
					warning TF("No LOS from %s (%s,%s) to Portal at (%s,%s).\n",
						$field->baseName, @{$self->{actor}{pos}}{qw(x y)},
						$self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}),
						"route";
					error T("Cannot reach portal from current position\n"), "route";
					shift @{$self->{mapSolution}};
				}
			}
		}
	}
}

sub setNpcTalk {
	my ($self) = @_;
	$self->{substage} = 'Waiting for Warp';
	@{$self}{qw(old_x old_y)} = @{$self->{actor}{pos}}{qw(x y)};
	$self->{old_map} = $field->baseName;
	my $task = new Task::TalkNPC(
		type => 'talknpc',
		x => $self->{mapSolution}[0]{pos}{x},
		y => $self->{mapSolution}[0]{pos}{y},
		sequence => $self->{mapSolution}[0]{steps});
	$self->setSubtask($task);
}

sub initMapCalculator {
	my ($self) = @_;
	my $task = new Task::CalcMapRoute(
		sourceMap => $field->baseName,
		sourceX => $self->{actor}{pos}{x},
		sourceY => $self->{actor}{pos}{y},
		map => $self->{dest}{map},
		x => $self->{dest}{pos}{x},
		y => $self->{dest}{pos}{y}
	);
	$self->setSubtask($task);
}

sub subtaskDone {
	my ($self, $task) = @_;
	if ($task->isa('Task::CalcMapRoute')) {
		my $error = $task->getError();
		if ($error) {
			my $code;
			if ($error->{code} == Task::CalcMapRoute::CANNOT_LOAD_FIELD) {
				$code = CANNOT_LOAD_FIELD;
			} elsif ($error->{code} == Task::CalcMapRoute::CANNOT_CALCULATE_ROUTE) {
				$code = CANNOT_CALCULATE_ROUTE;
			}
			$self->setError($code, $error->{message});

		} else {
			$self->{mapSolution} = $task->getRoute();
			# The map solution is empty, meaning that the destination
			# is on the same map and that we can walk there directly.
			# Of course, we only do that if we have a specific position
			# to walk to.
			if (@{$self->{mapSolution}} == 0 && defined($self->{dest}{pos}{x}) && defined($self->{dest}{pos}{y})) {
				my $task = new Task::Route(
					actor => $self->{actor},
					x => $self->{dest}{pos}{x},
					y => $self->{dest}{pos}{y},
					field => $field,
					maxTime => $self->{maxTime},
					avoidWalls => $self->{avoidWalls},
					distFromGoal => $self->{distFromGoal},
					pyDistFromGoal => $self->{pyDistFromGoal}
				);
				$task->{$_} = $self->{$_} for qw(attackID attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget);
				$self->setSubtask($task);
			}
		}

	} elsif ($task->isa('Task::Route')) {
		my $error = $task->getError();
		if ($error) {
			my $code;
			if ($error->{code} == Task::Route::TOO_MUCH_TIME) {
				$code = TOO_MUCH_TIME;
			} elsif ($error->{code} == Task::Route::CANNOT_CALCULATE_ROUTE) {
				$code = CANNOT_CALCULATE_ROUTE;
			} elsif ($error->{code} == Task::Route::STUCK) {
				$code = STUCK;
			} else {
				$code = UNKNOWN_ERROR;
			}
			$self->setError($code, $error->{message});
		}

	} elsif ($task->isa('Task::TalkNPC')) {
		my $error = $task->getError();
		if ($error) {
			my $code;
			if ($error->{code} == Task::TalkNPC::NPC_NOT_FOUND) {
				$code = NPC_NOT_FOUND;
			} elsif ($error->{code} == Task::TalkNPC::NPC_NO_RESPONSE) {
				$code = NPC_NO_RESPONSE;
			} elsif ($error->{code} == Task::TalkNPC::NO_SHOP_ITEM) {
				$code = NO_SHOP_ITEM;
			} elsif ($error->{code} == Task::TalkNPC::WRONG_NPC_INSTRUCTIONS) {
				$code = WRONG_NPC_INSTRUCTIONS;
			} else {
				$code = UNKNOWN_ERROR;
			}
			$self->{mapSolution}[0]{retry}++;
			$self->{mapSolution}[0]{error} = $error->{message};
		}

	} elsif (my $error = $task->getError()) {
		$self->setError(UNKNOWN_ERROR, $error->{message});
	}
}

sub mapChanged {
	my (undef, undef, $holder) = @_;
	my $self = $holder->[0];
	$self->{mapChanged} = 1;
}

1;
