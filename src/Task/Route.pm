#########################################################################
#  OpenKore - Long intra-map movement task
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Long intra-map movement task.
#
# This task is able to move long distances within the same map. Unlike
# the Move task, this task can walk to destinations which are outside the
# character's screen.
package Task::Route;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;
use Carp::Assert;
use Utils::Assert;

use Modules 'register';
use Task::WithSubtask;
use base qw(Task::WithSubtask);
use Task::Move;

use Globals qw($field $net %config %timeout $npcsList);
use AI qw(ai_useTeleport);
use Log qw(message error debug warning);
use Network;
use Field;
use Translation qw(T TF);
use Misc;
use Utils qw(timeOut adjustedBlockDistance distance blockDistance calcPosFromPathfinding);
use Utils::Exceptions;
use Utils::Set;
use Utils::PathFinding;

# Stage constants.
use constant {
	NOT_INITIALIZED => 1,
	CALCULATE_ROUTE => 2,
	ROUTE_SOLUTION_READY => 3,
	WALK_ROUTE_SOLUTION => 4
};

# Error code constants.
use enum qw(
	TOO_MUCH_TIME
	CANNOT_CALCULATE_ROUTE
	STUCK
	UNEXPECTED_STATE
);

# TODO: Add Homunculus support


##
# Task::Route->new(options...)
#
# Create a new Task::Route object. The following options are allowed:
# - All options allowed by Task::WithSubtask->new(), except 'mutexes', 'autostop' and 'autofail'.
#
# Required arguments:
# `l
# - actor - The Actor object which this task should move.
# - x - The X-coordinate that you want to move to.
# - y - The Y-coordinate that you want to move to.
# - field: The Field object of the map that you want to move to.
# `l`
#
# Optional arguments:
# `l`
# - maxDistance - The maximum distance (in blocks) that the route may be. If
#                 not specified, then there is no limit.
# - maxTime - The maximum time that may be spent on walking the route. If not
#             specified, then there is no time limit.
# - distFromGoal - Stop walking if we're within the specified distance (in blocks)
#                  from the goal. If not specified, then we'll walk until the
#                  destination is reached.
# - pyDistFromGoal - Same as distFromGoal, but this allows you to specify the
#                    Pythagorian distance instead of block distance.
# - avoidWalls - Whether to avoid walls. The default is yes.
# - notifyUponArrival - Whether to print a message when we've reached the destination.
#                       The default is no.
# `l`
#
# x and y may not be lower than 0 or undef. Otherwise, an ArgumentException will be thrown.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, autostop => 1, autofail => 0, mutexes => ['movement']);

	unless ($args{field}->isa('Field')) {
		ArgumentException->throw(error => "Invalid Field argument.");
	}

	unless ($args{actor}->isa('Actor')) {
		ArgumentException->throw(error => "Invalid Actor argument.");
	}

	if (!defined $args{x} || !defined $args{y} || $args{x} < 0 || $args{y} < 0) {
		ArgumentException->throw(error => "Invalid Coordinates argument.");
	}

	my $allowed = new Set(qw(targetNpcPos maxDistance maxTime distFromGoal pyDistFromGoal avoidWalls randomFactor useManhattan notifyUponArrival attackID sendAttackWithMove attackOnRoute noSitAuto LOSSubRoute meetingSubRoute isRandomWalk isFollow isIdleWalk isSlaveRescue isMoveNearSlave isEscape isItemTake isItemGather isDeath isToLockMap runFromTarget));
	foreach my $key (keys %args) {
		if ($allowed->has($key) && defined($args{$key})) {
			$self->{$key} = $args{$key};
		}
	}

	$self->{actor} = $args{actor};

	# Pass a weak reference of mercenary/homunculus to ourselves in order to avoid circular references (memory leaks).
	if ($self->{actor}->isa("AI::Slave::Homunculus") || $self->{actor}->isa("Actor::Slave::Homunculus") || $self->{actor}->isa("AI::Slave::Mercenary") || $self->{actor}->isa("Actor::Slave::Mercenary")) {
		Scalar::Util::weaken($self->{actor});
	}

	$self->{dest}{map} = $args{field};
	$self->{dest}{pos}{x} = $args{x};
	$self->{dest}{pos}{y} = $args{y};
	if ($config{$self->{actor}{configPrefix}.'route_avoidWalls'}) {
		if (!defined $self->{avoidWalls}) {
			$self->{avoidWalls} = 1;
		}
	} else {
		$self->{avoidWalls} = 0;
	}
	
	if ($config{$self->{actor}{configPrefix}.'route_randomFactor'}) {
		if (!defined $self->{randomFactor}) {
			$self->{randomFactor} = $config{$self->{actor}{configPrefix}.'route_randomFactor'};
		}
	} else {
		$self->{randomFactor} = 0;
	}
	if (!defined $self->{useManhattan}) {
		$self->{useManhattan} = 0;
	}
	
	$self->{solution} = [];
	$self->{stage} = NOT_INITIALIZED;

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

##
# Hash* $Task_Route->destCoords()
#
# Returns the destination coordinates. The result is a hash with the items 'x' and 'y'.
sub destCoords {
	return $_[0]->{dest}{pos};
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate();
	$self->{stage} = CALCULATE_ROUTE;
	$self->{time_start} = time;
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	$self->{interruptionTime} = time;
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	$self->{time_start} += time - $self->{interruptionTime};
	undef $self->{time_step};
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	return unless ($self->SUPER::iterate() && $net->getState() == Network::IN_GAME);
	return unless $field && defined $self->{actor}{pos_to} && defined $self->{actor}{pos_to}{x} && defined $self->{actor}{pos_to}{y};

	if ( $self->{maxTime} && timeOut($self->{time_start}, $self->{maxTime})) {
		# We spent too much time
		debug "Route $self->{actor} - we spent too much time; bailing out.\n", "route";
		$self->setError(TOO_MUCH_TIME, "Too much time spent on walking.");

	} elsif ($field->baseName ne $self->{dest}{map}->baseName || $self->{mapChanged}) {
		debug "Map changed: ".$self->{dest}{map}->baseName." -> ".$field->baseName."\n", "route";
		$self->setDone();

	} elsif ($self->{stage} == CALCULATE_ROUTE) {
		my $pos = $self->{actor}{pos};
		my $pos_to = $self->{actor}{pos_to};
		
		my $calc_pos = calcPosFromPathfinding($field, $self->{actor});
		
		debug "Route $self->{actor}: Calculating. Your pos ($pos->{x} $pos->{y}). Your pos_to ($pos_to->{x} $pos_to->{y}). calcPosFromPathfinding ($calc_pos->{x} $calc_pos->{y})\n", "route";
		
		my $begin = time;

		if (!$self->{meetingSubRoute} && !$self->{LOSSubRoute} && $pos_to->{x} == $self->{dest}{pos}{x} && $pos_to->{y} == $self->{dest}{pos}{y}) {
			debug "Route $self->{actor}: Current position and destination are the same.\n", "route";
			$self->setDone();
		
		} elsif ($self->getRoute($self->{solution}, $self->{dest}{map}, $calc_pos, $self->{dest}{pos}, $self->{avoidWalls}, $self->{randomFactor}, $self->{useManhattan}, 1)) {
			$self->{stage} = ROUTE_SOLUTION_READY;

			@{$self->{last_pos}}{qw(x y)} = @{$calc_pos}{qw(x y)};
			@{$self->{last_pos_to}}{qw(x y)} = @{$pos_to}{qw(x y)};
			$self->{start} = 1;
			$self->{confirmed_correct_vector} = 0;
			
			if ($self->{pyDistFromGoal} || $self->{distFromGoal}) {
				$self->{anyDistFromGoal} = 1;
				
				my $current_i = $#{$self->{solution}};
				
				while (1) {
					my $dest = $self->{solution}[$current_i];
					
					if ($self->{distFromGoal}) {
						if (blockDistance($dest, $self->{dest}{pos}) <= $self->{distFromGoal}) {
							$self->{solution}[$current_i]{closeToEnd} = 1;
						} else {
							$self->{solution}[$current_i]{closeToEnd} = 0;
							last;
						}
						
					} elsif ($self->{pyDistFromGoal}) {
						if (distance($dest, $self->{dest}{pos}) <= $self->{pyDistFromGoal}) {
							$self->{solution}[$current_i]{closeToEnd} = 1;
						} else {
							$self->{solution}[$current_i]{closeToEnd} = 0;
							last;
						}
					}
					last if ($current_i == 0);
				} continue {
					$current_i--;
				}
				
			} else {
				$self->{anyDistFromGoal} = 0;
			}

			debug "Route $self->{actor} Solution Ready! Found path on ".$self->{dest}{map}->baseName." from ".$calc_pos->{x}." ".$calc_pos->{y}." to ".$self->{dest}{pos}{x}." ".$self->{dest}{pos}{y}.". Size: ".@{$self->{solution}}." steps.\n", "route";

			$self->iterate();

		} else {
			debug "Something's wrong; there is no path from " . $self->{dest}{map}->baseName . "($calc_pos->{x},$calc_pos->{y}) to " . $self->{dest}{map}->baseName . "($self->{dest}{pos}{x},$self->{dest}{pos}{y}).\n", "route";
			$self->setError(CANNOT_CALCULATE_ROUTE, "Unable to calculate a route.");
		}

	} elsif ($self->{stage} == ROUTE_SOLUTION_READY) {
		my $begin = time;
		my $solution = $self->{solution};
		
		# TODO: What is this Fractional route motion bellow?
		if ($self->{maxDistance} > 0 && $self->{maxDistance} < 1) {
			# Fractional route motion
			$self->{maxDistance} = int($self->{maxDistance} * scalar(@{$solution}));
		}
		if ($self->{maxDistance} && $self->{maxDistance} < @{$solution}) {
			splice(@{$solution}, 1 + $self->{maxDistance});
		}

		undef $self->{mapChanged};
		undef $self->{step_index};
		undef $self->{decreasing_step_index};
		#undef $self->{last_pos};
		#undef $self->{last_pos_to};
		#undef $self->{start};
		#undef $self->{confirmed_correct_vector};
		undef $self->{last_best_pos_step};
		undef $self->{last_best_pos_to_step};
		undef $self->{next_pos};
		undef $self->{time_step};

		$self->{stage} = WALK_ROUTE_SOLUTION;

		if (@{$self->{solution}} == 0) {
			debug "Route $self->{actor}: DistFromGoal|pyDistFromGoal trimmed all solution steps.\n", "route";
			$self->setDone();
		} else {
			$self->iterate();
		}

	# Actual walking algorithm
	} elsif ($self->{stage} == WALK_ROUTE_SOLUTION) {
		my $solution = $self->{solution};
		$self->{route_out_time} = time if !exists $self->{route_out_time};

		if (!defined $self->{step_index}) {
			$self->{step_index} = $config{$self->{actor}{configPrefix}.'route_step'};
		}

		my ($current_pos, $current_pos_to, $current_calc_pos);

		# $actor->{pos} is the position the character moved FROM in the last move packet received
		@{$current_pos}{qw(x y)} = @{$self->{actor}{pos}}{qw(x y)};

		# $actor->{pos_to} is the position the character moved TO in the last move packet received
		@{$current_pos_to}{qw(x y)} = @{$self->{actor}{pos_to}}{qw(x y)};
		
		$current_calc_pos = calcPosFromPathfinding($field, $self->{actor});
		
		if ($current_calc_pos->{x} == $solution->[$#{$solution}]{x} && $current_calc_pos->{y} == $solution->[$#{$solution}]{y}) {
			# Actor position is the destination; we've arrived at the destination
			if ($self->{notifyUponArrival}) {
				message TF("%s reached the destination.\n", $self->{actor}), "route";
			} else {
				debug "$self->{actor} reached the destination.\n", "route";
			}

			Plugins::callHook('route', {status => 'success'});
			$self->setDone();
			return;

		} else {
			# Failsafe
			my $lookahead_failsafe_max = $self->{step_index} + 1;
			my $lookahead_failsafe_count;

			# This looks ahead in the solution array and finds the closest position in it to our current {pos}, then it looks $lookahead_failsafe_max further, just to be sure
			
			$lookahead_failsafe_count = 0;
			my $best_index;
			my $best_dist;
			
			foreach my $step_i (0..$#{$solution}) {
				my $step = $solution->[$step_i];
				if ($step->{x} == $current_calc_pos->{x} && $step->{y} == $current_calc_pos->{y}) {
					$best_index = $step_i;
					$best_dist = 0;
					last;
				}
				my $dist = adjustedBlockDistance($current_calc_pos, $step);
				if (!defined $best_dist || $best_dist > $dist) {
					$best_index = $step_i;
					$best_dist = $dist;
					$lookahead_failsafe_count = 0;
				} else {
					$lookahead_failsafe_count++;
				}
				if ($lookahead_failsafe_count == $lookahead_failsafe_max) {
					last;
				}
			}
			my $best_pos_step = $best_index;

			# This does the same, but with {pos_to}
			undef $best_index;
			undef $best_dist;
			foreach my $step_i (0..$#{$solution}) {
				my $step = $solution->[$step_i];
				if ($step->{x} == $current_pos_to->{x} && $step->{y} == $current_pos_to->{y}) {
					$best_index = $step_i;
					$best_dist = 0;
					last;
				}
				my $dist = adjustedBlockDistance($current_pos_to, $step);
				if (!defined $best_dist || $best_dist > $dist) {
					$best_index = $step_i;
					$best_dist = $dist;
					$lookahead_failsafe_count = 0;
				} else {
					$lookahead_failsafe_count++;
				}
				if ($lookahead_failsafe_count == $lookahead_failsafe_max) {
					last;
				}
			}
			my $best_pos_to_step = $best_index;

			# Here there may be the need to check if 'pos' has changed yet best_pos_step is still the same, creating a lag in the movement

			# Last change in pos and pos_to put us in a walk path oposite to the desired one
			# TODO: This confirmed_correct_vector could probably be removed
			if ($best_pos_step > $best_pos_to_step) {
				if ($self->{confirmed_correct_vector}) {
					debug "Route $self->{actor} - movement interrupted: reset route (last change in pos and pos_to put us in a walk path oposite to the desired one)\n", "route";
					$self->{solution} = [];
					$self->{stage} = CALCULATE_ROUTE;
					return;
				}
			} elsif (!$self->{confirmed_correct_vector}) {
				debug "Route $self->{actor} - movement vector confirmed.\n", "route";
				$self->{confirmed_correct_vector} = 1;
			}

			# Last move was to the cell we are already at, lag?, buggy code?
			if ($self->{start}) {
				debug "Route $self->{actor} - not trimming down solution (" . @{$solution} . ") because we have not moved yet.\n", "route";
				
			} elsif ($best_pos_step == 0) {
				debug "Route $self->{actor} - not trimming down solution (" . @{$solution} . ") because best_pos_step is 0.\n", "route";

			} else {
				# Should we trimm only the known walk ones ($best_pos_step) or the known + the guessed (calcStepsWalkedFromTimeAndRoute)? Default was both.

				# Currently testing delete up to known + the guessed
				debug "Route $self->{actor} - trimming down solution (" . @{$solution} . ") by ".($best_pos_step)." steps\n", "route";

				splice(@{$solution}, 0, $best_pos_step);
			}

			$self->{last_best_pos_step} = $best_pos_step;
			$self->{last_best_pos_to_step} = $best_pos_to_step;
		}

		my $pos_changed;
		if ($self->{last_current_calc_pos}{x} == $current_calc_pos->{x} && $self->{last_current_calc_pos}{y} == $current_calc_pos->{y}) {
			$pos_changed = 0;
		} else {
			$pos_changed = 1;
		}

		my $stepsleft = @{$solution};
		
		$self->{lastStep} = 0;

		if ($stepsleft == 0) {
			# No more points to cover; we've arrived at the destination
			if ($self->{notifyUponArrival}) {
				message TF("%s reached the destination.\n", $self->{actor}), "route";
			} else {
				debug "$self->{actor} reached the destination.\n", "route";
			}

			Plugins::callHook('route', {status => 'success'});
			$self->setDone();

		} elsif ($stepsleft == 2 && isCellOccupied($solution->[-1]) && !$self->{meetingSubRoute}) {
			# 2 more steps to cover (current position and the destination)
			debug "Stoping 1 cell away from destination because there is an obstacle in it.\n", "route";
			if ($self->{notifyUponArrival}) {
				message TF("%s reached the destination.\n", $self->{actor}), "route";
			} else {
				debug "$self->{actor} reached the destination.\n", "route";
			}

			Plugins::callHook('route', {status => 'success'});
			$self->setDone();
		} elsif ($stepsleft <= 2 && isCellOccupied($solution->[-1]) && $self->{attackID}) {
			# If the destination cell is occupied, then we can't walk there but we need to attack

			# Get the cells around the destination cell
			my @cells = calcRectArea2($solution->[-1]{x}, $solution->[-1]{y}, 1, 1);
			my $walk_pos;
			my $index;
			while (@cells) {
				$index = int(rand(@cells));
				my $cell = $cells[$index];
				next if ((!$field->isWalkable($cell->{x}, $cell->{y})) || ($field->isCellOccupied($cell->{x}, $cell->{y})));
				
				$walk_pos = $cell;
				last;
			} continue {
				splice(@cells, $index, 1);
			}
			# If the cells around the destination cell are all occupied, then we can't walk there
			if (!(defined $walk_pos)) {
				# Log error message
				error TF("Destination cell (%d,%d) is occupied and there are no walkable cells around it.\n",
					$solution->[-1]{x}, $solution->[-1]{y}), "route";
				# Emit error message
				$self->setError(STUCK, T("Stuck during route."));
				Plugins::callHook('route', {status => 'stuck'});
			} else {
				# If we have a walkable cell, then walk there
				warning TF("Destination cell (%d,%d) is occupied, replacing it with (%d,%d).\n",
					$solution->[-1]{x}, $solution->[-1]{y}, $walk_pos->{x}, $walk_pos->{y}), "route";
				#
				$self->{dest}{pos}{x} = $walk_pos->{x};
				$self->{dest}{pos}{y} = $walk_pos->{y};
				#
				$self->{route_out_time} = time;
				$self->resetRoute();
			}
		} elsif (timeOut($self->{route_out_time}, 3)) {
			# Because of attack monster, get item or something else we are out of our route for a long time
			# recalculate again
			debug "We are out of our route for a long time, recalculating...\n", "route";
			$self->{route_out_time} = time;
			$self->resetRoute();
		} elsif (!$self->{start} && $pos_changed == 0 && defined $self->{time_step} && timeOut($self->{time_step}, $timeout{ai_route_unstuck}{timeout})) {
			# We tried to move for 3 seconds, but we are still on the same spot, decrease step size.
			# However, if $self->{step_index} was already 0, then that means we were almost at the destination (only 1 more step is needed).
			# But we got interrupted (by auto-attack for example). Don't count that as stuck.
			$self->{decreasing_step_index}++;
			$self->{step_index}--;
			if ($self->{step_index} > 0) {
				debug "Route $self->{actor} - not moving, decreasing step size to $self->{step_index}\n", "route";
				if ($stepsleft) {
					# If we still have more points to cover, walk to next point
					if ($self->{step_index} >= $stepsleft) {
						$self->{step_index} = $stepsleft - 1;
						$self->{lastStep} = 1;
					}
					@{$self->{next_pos}}{qw(x y)} = @{$solution->[$self->{step_index}]}{qw(x y)};
					$self->{time_step} = time;
					$self->setMove();
				}

			} else {
				# We're stuck
				my $msg = TF("Stuck at %s (%d,%d), while walking from (%d,%d) to (%d,%d).",
					$self->{dest}{map}->baseName, @{$self->{actor}{pos_to}}{qw(x y)},
					$current_calc_pos->{x}, $current_calc_pos->{y}, $self->{dest}{pos}{x}, $self->{dest}{pos}{y}
				);
				$msg .= T(" Teleporting to unstuck.") if ($config{$self->{actor}{configPrefix}.'teleportAuto_unstuck'});
				$msg .= "\n";
				warning $msg, "route";
				ai_useTeleport(1) if $config{$self->{actor}{configPrefix}.'teleportAuto_unstuck'};
				$self->setError(STUCK, T("Stuck during route."));
				Plugins::callHook('route', {status => 'stuck'});
			}

		} else {
			# We're either starting to move or already moving, so send out more
			# move commands periodically to keep moving and updating our position
			my $begin = time;

			if ($self->{decreasing_step_index}) {
				if ($pos_changed) {
					debug "Route $self->{actor} - started moving again, increasing step size by $self->{decreasing_step_index} (from ".($self->{step_index})." to ".($self->{step_index}+$self->{decreasing_step_index}).")\n", "route";
					$self->{step_index} += $self->{decreasing_step_index};
					$self->{decreasing_step_index} = 0;
				} else {
					debug "Route $self->{actor} - won't increase step size because pos did not change ($current_pos->{x} $current_pos->{y})\n", "route";
				}
			}

			# If there are less steps to cover than the step size move to the last step (the destination).
			if ($self->{step_index} >= $stepsleft) {
				$self->{step_index} = $stepsleft - 1;
				$self->{lastStep} = 1;
			}

			# Here maybe we should also use pos_to (in the form of best_pos_to_step) to decide the next step index, as it can make the routing way more responsive

			
			if ($self->{anyDistFromGoal}) {
				my $step = $solution->[$self->{step_index}];
				# We are close enough to the destination
				if (exists $step->{closeToEnd} && $step->{closeToEnd}) {
					my $current_i = $self->{step_index};
					while (1) {
						last if ($current_i == 0);
						last if ($solution->[($current_i-1)]{closeToEnd} == 0);
						$current_i--;
					}
					$self->{step_index} = $current_i;
				}
			}
			@{$self->{next_pos}}{qw(x y)} = @{$solution->[$self->{step_index}]}{qw(x y)};

			# But first, check whether the distance of the next point isn't abnormally large.
			# If it is, then we've moved to an unexpected place. This could be caused by auto-attack, for example.
			# TODO: This should be calcDistFromPath or something like that
			my %nextPos = (x => $self->{next_pos}{x}, y => $self->{next_pos}{y});
			if (blockDistance(\%nextPos, $current_calc_pos) > 17) {
				debug "Route $self->{actor} - movement interrupted: reset route (the distance of the next point is abnormally large ($current_calc_pos->{x} $current_calc_pos->{y} -> $nextPos{x} $nextPos{y}))\n", "route";
				$self->{solution} = [];
				$self->{stage} = CALCULATE_ROUTE;

			} else {
				
				if ($self->{targetNpcPos}) {
					my $found = 0;
					foreach my $actor (@{$npcsList->getItems()}) {
						my $pos = $actor->{pos};
						next if ($actor->{statuses}->{EFFECTSTATE_BURROW});
						if ($pos->{x} == $self->{dest}{pos}{x} && $pos->{y} == $self->{dest}{pos}{y}) {
							if (defined $actor->{name}) {
								$found = 1;
								last;
							}
						}
					}
					if ($found) {
						debug "[Route] [targetNpcPos] Found target npc.\n", "route";
						if ($self->{pyDistFromGoal} || $self->{distFromGoal}) {
							if ($self->{distFromGoal} && blockDistance($self->{dest}{pos}, $current_calc_pos) <= $self->{distFromGoal}) {
								debug "[Route] [targetNpcPos] [distFromGoal] Target npc is already close enough, ending movement.\n", "route";
								$self->setDone();
								return;
								
							} elsif ($self->{pyDistFromGoal} && distance($self->{dest}{pos}, $current_calc_pos) <= $self->{pyDistFromGoal}) {
								debug "[Route] [targetNpcPos] [pyDistFromGoal] Target npc is already close enough, ending movement.\n", "route";
								$self->setDone();
								return;
							}
						} else {
							debug "[Route] [targetNpcPos] Target npc is already on screen, ending movement.\n", "route";
							$self->setDone();
							return;
						}
					}
					
				} elsif ($self->{pyDistFromGoal} || $self->{distFromGoal}) {
					if ($self->{distFromGoal} && blockDistance($self->{dest}{pos}, $current_calc_pos) <= $self->{distFromGoal}) {
						debug "[Route] [distFromGoal] Target cell is already close enough, ending movement.\n", "route";
						$self->setDone();
						return;
						
					} elsif ($self->{pyDistFromGoal} && distance($self->{dest}{pos}, $current_calc_pos) <= $self->{pyDistFromGoal}) {
						debug "[Route] [pyDistFromGoal] Target cell is already close enough, ending movement.\n", "route";
						$self->setDone();
						return;
					}
				}
				
				my %hookArgs;
				$hookArgs{args} = $self;
				$hookArgs{pos} = $current_calc_pos;
				Plugins::callHook("route_before_move", \%hookArgs);
				return if ($hookArgs{return});
				
				if (!$self->{start} && $current_pos_to->{x} == $self->{next_pos}{x} && $current_pos_to->{y} == $self->{next_pos}{y}) {
					debug "[Route] Not sending next step ($self->{next_pos}{x}, $self->{next_pos}{y}) because our pos_to is the same as it.\n", "route";
					if ($self->{lastStep} == 1 && !$self->{sendAttackWithMove} && $self->{meetingSubRoute}) {
						debug "[Route] Also ending task now ang giving back control to AI::Attack.\n", "route";
						Plugins::callHook('route', {status => 'success'});
						$self->setDone();
					}
					return;
				}
				
                if ($self->{actor}->isa('Actor::You') && $self->{isRandomWalk} && $self->{actor}{slaves}) {
					my $slave = AI::SlaveManager::mustWaitMinDistance();
					if (defined $slave) {
						debug TF("Waiting for slave %s before next randomWalk step.\n", $slave), 'route', 2;
						return;
					}
				}

				if ($self->{start} || ($self->{last_pos}{x} != $current_pos->{x} || $self->{last_pos}{y} != $current_pos->{y})) {
					$self->{time_step} = time;
				}

				$self->{start} = 0;

				@{$self->{last_pos}}{qw(x y)} = @{$current_pos}{qw(x y)};
				@{$self->{last_pos_to}}{qw(x y)} = @{$current_pos_to}{qw(x y)};
				@{$self->{last_current_calc_pos}}{qw(x y)} = @{$current_calc_pos}{qw(x y)};

				debug "Route $self->{actor} - next step moving to ($self->{next_pos}{x}, $self->{next_pos}{y}), index $self->{step_index}, $stepsleft steps left\n", "route";
				
				$self->setMove();
			}
		}
		$self->{route_out_time} = time;
	} else {
		# This statement should never be reached.
		debug "Unexpected route stage [".$self->{stage}."] occured.\n", "route";
		$self->setError(UNEXPECTED_STATE, "Unexpected route stage [".$self->{stage}."] occured.\n");
	}
}

sub setMove {
	my ($self) = @_;
	
	my $task = new Task::Move(
		actor => $self->{actor},
		x => $self->{next_pos}{x},
		y => $self->{next_pos}{y}
	);
	
	if ($self->{lastStep} == 1 && $self->{attackID} && $self->{sendAttackWithMove}) {
		$task->{sendAttack} = 1;
		$task->{attackID} = $self->{attackID};
	} else {
		$task->{sendAttack} = 0;
	}
	
	$self->setSubtask($task);
	$self->iterate();
}

sub resetRoute {
	my ($self) = @_;
	$self->{solution} = [];
	$self->{stage} = CALCULATE_ROUTE;
}

##
# boolean Task::Route->getRoute(Array* solution, Field field, Hash* start, Hash* dest, [boolean avoidWalls = true], [boolean self_call = false])
# $solution: The route solution will be stored in here.
# field: the field on which a route must be calculated.
# start: The is the start coordinate.
# dest: The destination coordinate.
# avoidWalls: 0 if you don't want to avoid walls on route.
# self_call: 1 if it was called from inside this module.
# Returns: 1 if the calculation succeeded, 0 if not.
#
# Calculate how to walk from $start to $dest on field $field, or check whether there
# is a path from $start to $dest on field $field.
#
# If $solution is given, then the blocks you have to walk on in order to get to $dest
# are stored in there.
#
# This function is a convenience wrapper function for the stuff
# in Utils/PathFinding.pm
sub getRoute {
	my ($class, $solution, $field, $start, $dest, $avoidWalls, $randomFactor, $useManhattan, $self_call) = @_;
	assertClass($field, 'Field') if DEBUG;
	if (!defined $dest->{x} || $dest->{y} eq '') {
		@{$solution} = () if ($solution);
		return 1;
	}

	# The exact destination may not be a spot that we can walk on.
	# So we find a nearby spot that is walkable.
	my %start = %{$start};
	my %dest = %{$dest};

	my $closest_start = $field->closestWalkableSpot(\%start, 1);
	my $closest_dest = $field->closestWalkableSpot(\%dest, 1);
	$closest_dest = $field->closestWalkableSpot(\%dest, 10) if(!$closest_dest); # can't find a closest walkable spot

	if (!defined $closest_start || !defined $closest_dest) {
		return 0;
	}

	my %plugin_args;
	$plugin_args{self} = $class;
	$plugin_args{self_call} = $self_call;
	$plugin_args{start} = $closest_start;
	$plugin_args{dest} = $closest_dest;
	$plugin_args{field} = $field;
	$plugin_args{avoidWalls} = $avoidWalls;
	$plugin_args{randomFactor} = $randomFactor;
	$plugin_args{useManhattan} = $useManhattan;
	$plugin_args{return} = 0;

	Plugins::callHook('getRoute' => \%plugin_args);

	my $pathfinding;
	if ($plugin_args{return}) {
		$pathfinding = $plugin_args{pathfinding};
	} else {
		$pathfinding = new PathFinding();
	}

	# Calculate path
	$pathfinding->reset(
		start => $closest_start,
		dest  => $closest_dest,
		field => $field,
		avoidWalls => $avoidWalls,
		randomFactor => $randomFactor,
		useManhattan => $useManhattan,
		getRoute => 1
	);
	return undef if (!$pathfinding);

	my $ret;
	if ($solution) {
		$ret = $pathfinding->run($solution);
	} else {
		$ret = $pathfinding->runcount();
	}

	return ($ret >= 0 ? 1 : 0);
}

sub mapChanged {
	my (undef, undef, $holder) = @_;
	my $self = $holder->[0];
	$self->{mapChanged} = 1;
}

1;
