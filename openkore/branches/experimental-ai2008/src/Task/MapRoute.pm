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
use Task::WithSubTask;
use Task::Route;
use Task::CalcMapRoute;
use Task::TalkNPC;
use base qw(Task::WithSubTask);
use Translation qw(T TF);
use Log qw(message debug warning error);
use Network;
use Plugins;
use Misc qw(useTeleport);
use Utils qw(timeOut distance existsInList);
use Utils::PathFinding;
use Utils::Exceptions;


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

	if (!$args{map}) {
		ArgumentException->throw(error => "Invalid arguments.");
	}

	my $allowed = new Set('maxDistance', 'maxTime', 'distFromGoal', 'pyDistFromGoal',
		'avoidWalls', 'notifyUponArrival');
	foreach my $key (keys %args) {
		if ($allowed->has($key) && defined $args{$key}) {
			$self->{$key} = $args{$key};
		}
	}

	$self->{dest}{map} = $args{map};
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
	Plugins::delHook($self->{mapChangedHook});
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
	return if (!$field || !defined $char->{pos_to}{x} || !defined $char->{pos_to}{y});

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

	} elsif ( $field->name() ne $self->{mapSolution}[0]{map}
	     || ( $self->{mapChanged} && !$self->{teleport} ) ) {
		# Solution Map does not match current map
		debug "Current map " . $field->name() . " does not match solution [ $self->{mapSolution}[0]{portal} ].\n", "route";
		delete $self->{substage};
		delete $self->{timeout};
		delete $self->{mapChanged};
		shift @{$self->{mapSolution}};

	} elsif ( $self->{mapSolution}[0]{steps} ) {
		# If current solution has conversation steps specified
		if ( $self->{substage} eq 'Waiting for Warp' ) {
			$self->{timeout} = time unless $self->{timeout};
			if (timeOut($self->{timeout}, $timeout{ai_route_npcTalk}{timeout} || 10)
			 || $ai_v{npc_talk}{talk} eq 'close') {
				# We waited for 10 seconds and got nothing
				delete $self->{substage};
				delete $self->{timeout};
				if (++$self->{mapSolution}[0]{retry} >= ($config{route_maxNpcTries} || 5)) {
					# NPC sequence is a failure
					# We delete that portal and try again
					delete $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"};
					warning TF("Unable to talk to NPC at %s (%s,%s).\n", $field->name(), $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}), "route";
					$self->initMapCalculator();	# redo MAP router
				}
			}

		} elsif (distance($char->{pos_to}, $self->{mapSolution}[0]{pos}) <= 10) {
			my ($from,$to) = split /=/, $self->{mapSolution}[0]{portal};
			if ($char->{zenny} >= $portals_lut{$from}{dest}{$to}{cost}) {
				# We have enough money for this service.
				$self->{substage} = 'Waiting for Warp';
				$self->{old_x} = $char->{pos_to}{x};
				$self->{old_y} = $char->{pos_to}{y};
				$self->{old_map} = $field->name();
				my $task = new Task::TalkNPC(
					x => $self->{mapSolution}[0]{pos}{x},
					y => $self->{mapSolution}[0]{pos}{y},
					sequence => $self->{mapSolution}[0]{steps});
				$self->setSubtask($task);
			} else {
				error TF("Insufficient zenny to pay for service at %s (%s,%s).\n",
					$field->name(), $self->{mapSolution}[0]{pos}{x},
					$self->{mapSolution}[0]{pos}{y}), "route";
				$self->initMapCalculator(); # Redo MAP router
			}

		} elsif ( $self->{maxTime} && time - $self->{time_start} > $self->{maxTime} ) {
			# We spent too long a time.
			debug "MapRoute - We spent too much time; bailing out.\n", "route";
			$self->setError(TOO_MUCH_TIME, "Too much time spent on route traversal.");

		} elsif ( Task::Route->getRoute(\@solution, $field, $char->{pos_to}, $self->{mapSolution}[0]{pos}) ) {
			# NPC is reachable from current position
			# >> Then "route" to it
			debug "Walking towards the NPC\n", "route";
			my $task = new Task::Route(
				x => $self->{mapSolution}[0]{pos}{x},
				y => $self->{mapSolution}[0]{pos}{y},
				maxTime => $self->{maxTime},
				distFromGoal => 10,
				avoidWalls => $self->{avoidWalls},
				solution => \@solution
			);
			$self->setSubtask($task);

		} else {
			# Error, NPC is not reachable from current pos
			debug "CRITICAL ERROR: NPC is not reachable from current location.\n", "route";
			error TF("Unable to walk from %s (%s,%s) to NPC at (%s,%s).\n", $field->name(), $char->{pos_to}{x}, $char->{pos_to}{y}, $self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}), "route";
			shift @{$self->{mapSolution}};
		}

	} elsif ( $self->{mapSolution}[0]{portal} eq "$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}=$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}" ) {
		# This solution points to an X,Y coordinate
		my $distFromGoal = $self->{pyDistFromGoal}
			? $self->{pyDistFromGoal}
			: ($self->{distFromGoal} ? $self->{distFromGoal} : 0);
		if ( $distFromGoal + 2 > distance($char->{pos_to}, $self->{mapSolution}[0]{pos})) {
			# We need to specify +2 because sometimes the exact spot is occupied by someone else
			shift @{$self->{mapSolution}};

		} elsif ( $self->{maxTime} && time - $self->{time_start} > $self->{maxTime} ) {
			# We spent too long a time.
			debug "We spent too much time; bailing out.\n", "route";
			$self->setError(TOO_MUCH_TIME, "Too much time spent on route traversal.");

		} elsif ( Task::Route->getRoute(\@solution, $field, $char->{pos_to}, $self->{mapSolution}[0]{pos}) ) {
			# X,Y is reachable from current position
			# >> Then "route" to it
			my $task = new Task::Route(
				x => $self->{mapSolution}[0]{pos}{x},
				y => $self->{mapSolution}[0]{pos}{y},
				maxTime => $self->{maxTime},
				avoidWalls => $self->{avoidWalls},
				distFromGoal => $self->{distFromGoal},
				pyDistFromGoal => $self->{pyDistFromGoal},
				solution => \@solution
			);
			$self->setSubtask($task);

		} else {
			warning TF("No LOS from %s (%s,%s) to Final Destination at (%s,%s).\n",
				$field->name(), $char->{pos_to}{x}, $char->{pos_to}{y},
				$self->{mapSolution}[0]{pos}{x},
				$self->{mapSolution}[0]{pos}{y}), "route";
			error TF("Cannot reach (%s,%s) from current position.\n",
				$self->{mapSolution}[0]{pos}{x},
				$self->{mapSolution}[0]{pos}{y}), "route";
			shift @{$self->{mapSolution}};
		}

	} elsif ( $portals_lut{"$self->{mapSolution}[0]{map} $self->{mapSolution}[0]{pos}{x} $self->{mapSolution}[0]{pos}{y}"}{source} ) {
		# This is a portal solution

		if ( distance($char->{pos_to}, $self->{mapSolution}[0]{pos}) < 2 ) {
			# Portal is within 'Enter Distance'
			$timeout{ai_portal_wait}{timeout} = $timeout{ai_portal_wait}{timeout} || 0.5;
			if ( timeOut($timeout{ai_portal_wait}) ) {
				$messageSender->sendMove(int($self->{mapSolution}[0]{'pos'}{'x'}), int($self->{mapSolution}[0]{'pos'}{'y'}) );
				$timeout{'ai_portal_wait'}{'time'} = time;
			}

		} else {
			my $walk = 1;

			# Teleport until we're close enough to the portal
			$self->{teleport} = $config{route_teleport} if (!defined $self->{teleport});

			if ($self->{teleport} && !$cities_lut{$field->name() . ".rsw"}
			&& !existsInList($config{route_teleport_notInMaps}, $field->name())
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
						start => $char->{pos_to},
						dest => $portal->{pos},
						field => $field
					)->runcount;
					debug "Distance to portal ($portal->{portal}) is $dist\n", "route_teleport";

					if ($dist <= 0 || $dist > $minDist) {
						if ($dist > 0 && $config{route_teleport_maxTries} && $self->{teleportTries} >= $config{route_teleport_maxTries}) {
							debug "Teleported $config{route_teleport_maxTries} times. Falling back to walking.\n", "route_teleport";
						} else {
							message TF("Attempting to teleport near portal, try #%s\n", ($self->{teleportTries} + 1)), "route_teleport";
							if (!useTeleport(1)) {
								$self->{teleport} = 0;
							} else {
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
				if ( Task::Route->getRoute( \@solution, $field, $char->{pos_to}, $self->{mapSolution}[0]{pos} ) ) {
					# Portal is reachable from current position
					# >> Then "route" to it
					debug "Portal route within same map.\n", "route";
					$self->{teleportTries} = 0;
					my $task = new Task::Route(
						x => $self->{mapSolution}[0]{pos}{x},
						y => $self->{mapSolution}[0]{pos}{y},
						maxTime => $self->{maxTime},
						avoidWalls => $self->{avoidWalls},
						solution => \@solution
					);
					$self->setSubtask($task);

				} else {
					warning TF("No LOS from %s (%s,%s) to Portal at (%s,%s).\n",
						$field->name(), $char->{pos_to}{x}, $char->{pos_to}{y},
						$self->{mapSolution}[0]{pos}{x}, $self->{mapSolution}[0]{pos}{y}),
						"route";
					error T("Cannot reach portal from current position\n"), "route";
					shift @{$self->{mapSolution}};
				}
			}
		}
	}
}

sub initMapCalculator {
	my ($self) = @_;
	my $task = new Task::CalcMapRoute(
		sourceMap => $field->name(),
		sourceX => $char->{pos_to}{x},
		sourceY => $char->{pos_to}{y},
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
					x => $self->{dest}{pos}{x},
					y => $self->{dest}{pos}{y},
					maxTime => $self->{maxTime},
					avoidWalls => $self->{avoidWalls},
					distFromGoal => $self->{distFromGoal},
					pyDistFromGoal => $self->{pyDistFromGoal}
				);
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
			$self->setError($code, $error->{message});
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
