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

use Globals qw($field $net %config);
use Log qw(message debug warning);
use Network;
use Field;
use Translation qw(T TF);
use Misc;
use Utils qw(timeOut adjustedBlockDistance distance blockDistance calcPosition calcStepsWalkedFromTimeAndRoute);
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
# - actor - Which Actor this task should move.
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
# x and y may not be 0 or undef. Otherwise, an ArgumentException will be thrown.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, autostop => 1, autofail => 0, mutexes => ['movement']);

	unless ($args{actor}->isa('Actor') and $args{x} != 0 and $args{y} != 0) {
		ArgumentException->throw(error => "Invalid arguments.");
	}

	unless ($args{field}->isa('Field')) {
		ArgumentException->throw(error => "Invalid arguments.");
	}

	my $allowed = new Set('maxDistance', 'maxTime', 'distFromGoal', 'pyDistFromGoal', 'avoidWalls', 'notifyUponArrival');
	foreach my $key (keys %args) {
		if ($allowed->has($key) && defined($args{$key})) {
			$self->{$key} = $args{$key};
		}
	}

	$self->{actor} = $args{actor};
	# FIXME: don't use global $field in tasks
	$self->{dest}{map} = $args{field}->baseName;
	$self->{dest}{pos}{x} = $args{x};
	$self->{dest}{pos}{y} = $args{y};
	if ($config{$self->{actor}{configPrefix}.'route_avoidWalls'}) {
		$self->{avoidWalls} = 1 if (!defined $self->{avoidWalls});
	} else {
		$self->{avoidWalls} = 0;
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
	$self->{time_step} += time - $self->{interruptionTime};
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

	} elsif ($field->baseName ne $self->{dest}{map} || $self->{mapChanged}) {
		debug "Map changed: " . $field->baseName . " $self->{dest}{map}\n", "route";
		$self->setDone();

	} elsif ($self->{stage} == CALCULATE_ROUTE) {
		my $pos = calcPosition($self->{actor});
		my $begin = time;
		if ($pos->{x} == $self->{dest}{pos}{x} && $pos->{y} == $self->{dest}{pos}{y}) {
			debug "Route $self->{actor}: Current position and destination are the same.\n", "route";
			$self->setDone();
		} elsif ($self->getRoute($self->{solution}, $field, $pos, $self->{dest}{pos}, $self->{avoidWalls})) {
			$self->{stage} = ROUTE_SOLUTION_READY;
			
			# During the walking stage it is a good idea to keep the last position in the solution but since it is also a bad idea for the pathfinding algorithm to return a solution with the start position we add it here.
			# Should this be done in a separate variable? (for example $self->{current_pos})
			unshift(@{$self->{solution}}, { x => $pos->{x}, y => $pos->{y} });
			
			debug "Route $self->{actor} Solution Ready!\n", "route";

			if (time - $begin < 0.01) {
				# Optimization: immediately go to the next stage if we spent neglible time in this step.
				$self->iterate();
			}

		} else {
			debug "Something's wrong; there is no path from " . $field->baseName . "($pos->{x},$pos->{y}) to " . $field->baseName . "($self->{dest}{pos}{x},$self->{dest}{pos}{y}).\n", "debug";
			$self->setError(CANNOT_CALCULATE_ROUTE, "Unable to calculate a route.");
		}

	} elsif ($self->{stage} == ROUTE_SOLUTION_READY) {
		my $begin = time;
		my $solution = $self->{solution};
		if ($self->{maxDistance} > 0 && $self->{maxDistance} < 1) {
			# Fractional route motion
			$self->{maxDistance} = int($self->{maxDistance} * scalar(@{$solution}));
		}
		if ($self->{maxDistance} && $self->{maxDistance} < @{$solution}) {
			splice(@{$solution}, 1 + $self->{maxDistance});
		}

		# Trim down solution tree for pyDistFromGoal or distFromGoal
		if ($self->{pyDistFromGoal}) {
			my $trimsteps = 0;
			while ($trimsteps < @{$solution} && distance($solution->[@{$solution} - 1 - $trimsteps], $solution->[@{$solution} - 1]) < $self->{pyDistFromGoal}) {
				$trimsteps++;
			}
			debug "Route $self->{actor} - trimming down solution by $trimsteps steps for pyDistFromGoal $self->{pyDistFromGoal}\n", "route";
			splice(@{$self->{'solution'}}, -$trimsteps) if ($trimsteps);

		} elsif ($self->{distFromGoal}) {
			my $trimsteps = $self->{distFromGoal};
			$trimsteps = @{$self->{solution}} if ($trimsteps > @{$self->{solution}});
			debug "Route $self->{actor} - trimming down solution by $trimsteps steps for distFromGoal $self->{distFromGoal}\n", "route";
			splice(@{$self->{solution}}, -$trimsteps) if ($trimsteps);
		}

		undef $self->{mapChanged};
		undef $self->{index};
		undef $self->{old_x};
		undef $self->{old_y};
		undef $self->{new_x};
		undef $self->{new_y};
		$self->{time_step} = time;
		$self->{stage} = WALK_ROUTE_SOLUTION;

		if (time - $begin < 0.01) {
			# Optimization: immediately go to the next stage if we spent neglible time in this step.
			$self->iterate();
		}

	# Actual walking algorithm
	} elsif ($self->{stage} == WALK_ROUTE_SOLUTION) {
		my $solution = $self->{solution};
		my ($cur_x, $cur_y);
		
		my $actor_pos = $self->{actor}{pos};
		my $actor_pos_to = $self->{actor}{pos_to};
		my $guessed_pos;
		
		if ($actor_pos->{x} == $solution->[$#{$solution}]{x} && $actor_pos->{y} == $solution->[$#{$solution}]{y}) {
			# Actor position is the destination; we've arrived at the destination
			if ($self->{notifyUponArrival}) {
				message TF("%s reached the destination.\n", $self->{actor}), "success";
			} else {
				debug "$self->{actor} reached the destination.\n", "route";
			}

			Plugins::callHook('route', {status => 'success'});
			$self->setDone();
			return;
		
		# This is the first iteration since stage Walk the Route Solution was set
		} elsif (!defined $self->{old_x}) {
			$guessed_pos = calcPosition($self->{actor});
			($cur_x, $cur_y) = ($guessed_pos->{x}, $guessed_pos->{y});
			
		} else {
			my $best_pos_step = 0;
			while ($best_pos_step < @{$solution} && adjustedBlockDistance( { x => $actor_pos->{x}, y => $actor_pos->{y} }, $solution->[$best_pos_step]) > adjustedBlockDistance( { x => $actor_pos->{x}, y => $actor_pos->{y} }, $solution->[$best_pos_step + 1])) {
				$best_pos_step++;
			}
			$best_pos_step = @{$solution} - 1 if ($best_pos_step == @{$solution});
			
			my $best_pos_to_step = 0;
			while ($best_pos_to_step < @{$solution} && adjustedBlockDistance( { x => $actor_pos_to->{x}, y => $actor_pos_to->{y} }, $solution->[$best_pos_to_step]) > adjustedBlockDistance( { x => $actor_pos_to->{x}, y => $actor_pos_to->{y} }, $solution->[$best_pos_to_step + 1])) {
				$best_pos_to_step++;
			}
			$best_pos_to_step = @{$solution} - 1 if ($best_pos_to_step == @{$solution});
			
			# Last change in pos and pos_to put us in a walk path oposite to the desired one
			if ($best_pos_step > $best_pos_to_step) {
				debug "Route $self->{actor} - movement interrupted: reset route (last change in pos and pos_to put us in a walk path oposite to the desired one)\n", "route";
				$self->{stage} = CALCULATE_ROUTE;
				return;
			
			} elsif ($best_pos_step == $best_pos_to_step) {
				$guessed_pos = $solution->[$best_pos_step];
				($cur_x, $cur_y) = ($guessed_pos->{x}, $guessed_pos->{y});
				
				debug "Route $self->{actor} - trimming down solution (" . @{$solution} . ") by ".($best_pos_step+1)." steps\n", "route";
				# Never trimm the current guessed cell, because if we get stuck we will keep deleting the first cell of the solution over and over
				splice(@{$solution}, 0, $best_pos_step) if ($best_pos_step > 0);
				
			} else {
				my @steps = @{$solution}[$best_pos_step..$best_pos_to_step];
				
				my $speed = ($self->{actor}{walk_speed} || 0.12);
				my $elapsed = time - $self->{actor}{time_move};
				my $walked_from_pos = calcStepsWalkedFromTimeAndRoute(\@steps, $speed, $elapsed);
				
				my $guessed_steps = $best_pos_step + $walked_from_pos;
				$guessed_pos = $solution->[$guessed_steps];
				
				($cur_x, $cur_y) = ($guessed_pos->{x}, $guessed_pos->{y});
				
				# Should we trimm only the known walk ones ($best_pos_step) or the known + the guessed (calcStepsWalkedFromTimeAndRoute)? Default was both, keeping it for now.
				debug "Route $self->{actor} - trimming down solution (" . @{$solution} . ") by ".($guessed_steps)." steps\n", "route";
				# Never trimm the current guessed cell, because if we get stuck we will keep deleting the first cell of the solution over and over
				splice(@{$solution}, 0, $guessed_steps);
			}
		}

		if (@{$self->{solution}} == 0) {
			# No more points to cover; we've arrived at the destination
			if ($self->{notifyUponArrival}) {
				message TF("%s reached the destination.\n", $self->{actor}), "success";
			} else {
				debug "$self->{actor} reached the destination.\n", "route";
			}

			Plugins::callHook('route', {status => 'success'});
			$self->setDone();

		} elsif ($self->{old_x} == $cur_x && $self->{old_y} == $cur_y && timeOut($self->{time_step}, 3)) {
			# We tried to move for 3 seconds, but we are still on the same spot, decrease step size.
			# However, if $self->{index} was already 0, then that means we were almost at the destination (only 1 more step is needed).
			# But we got interrupted (by auto-attack for example). Don't count that as stuck.
			my $wasZero = $self->{index} == 0;
			$self->{index} = int($self->{index} * 0.8);
			if ($self->{index}) {
				debug "Route $self->{actor} - not moving, decreasing step size to $self->{index}\n", "route";
				if (@{$self->{solution}}) {
					# If we still have more points to cover, walk to next point
					$self->{index} = @{$self->{solution}} - 1 if $self->{index} >= @{$self->{solution}};
					$self->{new_x} = $self->{solution}[$self->{index}]{x};
					$self->{new_y} = $self->{solution}[$self->{index}]{y};
					$self->{time_step} = time;
					my $task = new Task::Move(
						actor => $self->{actor},
						x => $self->{new_x},
						y => $self->{new_y});
					$self->setSubtask($task);
				}

			} elsif (!$wasZero) {
				# FIXME: this code looks ugly!
				# We're stuck
				my $msg = TF("Stuck at %s (%d,%d), while walking from (%d,%d) to (%d,%d).",
					$field->baseName, @{$self->{actor}{pos_to}}{qw(x y)},
					$cur_x, $cur_y, $self->{dest}{pos}{x}, $self->{dest}{pos}{y});
				$msg .= T(" Teleporting to unstuck.") if ($config{$self->{actor}{configPrefix}.'teleportAuto_unstuck'});
				$msg .= "\n";
				warning $msg, "route";
				Misc::useTeleport(1) if $config{$self->{actor}{configPrefix}.'teleportAuto_unstuck'};
				$self->setError(STUCK, T("Stuck during route."));
				Plugins::callHook('route', {status => 'stuck'});
			} else {
				$self->{time_step} = time;
			}

		} else {
			# We're either starting to move or already moving, so send out more
			# move commands periodically to keep moving and updating our position
			my $begin = time;
			unless ($self->{index}) {
				$self->{index} = $config{$self->{actor}{configPrefix}.'route_step'} - 1;
			}
			if (($self->{index} < $config{$self->{actor}{configPrefix}.'route_step'}) && ($self->{old_x} != $cur_x || $self->{old_y} != $cur_y)) {
				$self->{index}++ ;
			}

			my $stepsleft = @{$solution};
			# If we still have more points to cover, walk to next point
			if ($self->{index} >= $stepsleft) {
				$self->{index} = $stepsleft - 1;
			}
			$self->{new_x} = $self->{solution}[$self->{index}]{x};
			$self->{new_y} = $self->{solution}[$self->{index}]{y};

			# But first, check whether the distance of the next point isn't abnormally large.
			# If it is, then we've moved to an unexpected place. This could be caused by auto-attack, for example.
			my %nextPos = (x => $self->{new_x}, y => $self->{new_y});
			if (blockDistance(\%nextPos, $guessed_pos) > 10) {
				debug "Route $self->{actor} - movement interrupted: reset route (the distance of the next point is abnormally large)\n", "route";
				$self->{stage} = CALCULATE_ROUTE;

			} else {
				$self->{time_step} = time if ($cur_x != $self->{old_x} || $cur_y != $self->{old_y});
				$self->{old_x} = $cur_x;
				$self->{old_y} = $cur_y;
				debug "Route $self->{actor} - next step moving to ($self->{new_x}, $self->{new_y}), index $self->{index}, $stepsleft steps left\n", "route";
				my $task = new Task::Move(
					actor => $self->{actor},
					x => $self->{new_x},
					y => $self->{new_y});
				$self->setSubtask($task);

				if (time - $begin < 0.01) {
					# Optimization: immediately begin moving, if we spent neglible time in this step.
					$self->iterate();
				}
			}
		}

	} else {
		# This statement should never be reached.
		debug "Unexpected route stage [".$self->{stage}."] occured.\n", "route";
		$self->setError(UNEXPECTED_STATE, "Unexpected route stage [".$self->{stage}."] occured.\n");
	}
}

sub resetRoute {
	my ($self) = @_;
	$self->{solution} = [];
	$self->{stage} = CALCULATE_ROUTE;
}

##
# boolean Task::Route->getRoute(Array* solution, Field field, Hash* start, Hash* dest, [boolean avoidWalls = true])
# $solution: The route solution will be stored in here.
# field: the field on which a route must be calculated.
# start: The is the start coordinate.
# dest: The destination coordinate.
# noAvoidWalls: 1 if you don't want to avoid walls on route.
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
	my ($class, $solution, $field, $start, $dest, $avoidWalls) = @_;
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
	
	if (!defined $closest_start || !defined $closest_dest) {
		return 0;
	}

	# Calculate path
	my $pathfinding = new PathFinding(
		start => $closest_start,
		dest  => $closest_dest,
		field => $field,
		avoidWalls => $avoidWalls
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