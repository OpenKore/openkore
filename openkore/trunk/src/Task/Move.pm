#########################################################################
#  OpenKore - Simple movement task
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
# MODULE DESCRIPTION: Simple movement task.
#
# The Move task is responsible for moving a single step. That is: to
# move to a near place on the same map, that can be reached by clicking
# one time inside the RO client.
#
# This task will keep sending the 'move' message to the server until the
# character has moved, or until a specific amount of time has passed.
# Furthermore, this task will also make sure that the character first
# stands up, if the character is sitting.
#
# You should take a look at the Route task instead, for movements which
# involve a longer route for which multiple steps are required.
package Task::Move;

use strict;
use Time::HiRes qw(time);
use Scalar::Util;

use Task;
use base qw(Task);
use Task::SitStand;
use Globals qw(%timeout $char $net $messageSender);
use Plugins;
use Network;
use Log qw(warning debug);
use Utils qw(timeOut);
use Utils::Exceptions;

# State constants.
use constant WORKING => 1;
use constant WAIT_FOR_TASK => 2;


##
# Task::Move->new(options...)
#
# Create a new Task::Move object. The following options are allowed:
# `l
# - All options allowed by Task->new(), except 'movement'.
# - <tt>x</tt> (required) - The X-coordinate that you want to move to.
# - <tt>y</tt> (required) - The Y-coordinate that you want to move to.
# - <tt>retryTime</tt> - After a 'move' message has been sent, if the character does not
#                        move within the specified amount of time, then this task will re-sent
#                        a 'move' message. The default is 0.5.
# - <tt>giveupTime</tt> - If the character still hasn't moved after the specified amount of time,
#                         then this task will give up and complete with an error.
# `l`
#
# x and y may not be 0 or undef. Otherwise, an ArgumentException will be thrown.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, mutexes => ['movement']);

	if ($args{x} == 0 || $args{y} == 0) {
		ArgumentException->throw();
	}

	$self->{x} = $args{x};
	$self->{y} = $args{y};
	$self->{retry}{timeout} = $args{retryTime} || 0.5;
	$self->{giveup}{timeout} = $args{giveupTime} || $timeout{ai_move_giveup}{timeout} || 3;

	# Watch for map change events. Pass a weak reference to ourselves in order
	# to avoid circular references (memory leaks).
	my $weak_self = $self;
	Scalar::Util::weaken($weak_self);
	$self->{mapChangedHook} = Plugins::addHook('Network::Receive::map_changed', \&mapChanged, $weak_self);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{mapChangedHook});
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate();
	$self->{state} = WORKING;
	$self->{giveup}{time} = time;
	$self->{start_time} = time;
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	$self->{interruptionTime} = time;
	$self->{task}->interrupt() if ($self->{task});
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	$self->{giveup}{time} += time - $self->{interruptionTime};
	$self->{retry}{time} += time - $self->{interruptionTime};
	$self->{task}->resume() if ($self->{task});
}

# Overrided method.
sub stop {
	my ($self) = @_;
	$self->SUPER::stop();
	$self->{task}->stop() if ($self->{task});
}

# Overrided method.
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();
	return unless ($net->getState() == Network::IN_GAME);

	if ($self->{state} == WORKING) {
		# If we're sitting, wait until we've stood up.
		if ($char->{sitting}) {
			$self->{task} = new Task::SitStand(mode => 'stand');
			$self->{task}->activate();
			$self->{state} = WAIT_FOR_TASK;

		# Stop if the map changed.
		} elsif ($self->{mapChanged}) {
			debug "Move - map change detected\n", "ai_move";
			$self->setDone();

		# Stop if we've moved.
		} elsif ($char->{time_move} > $self->{start_time}) {
			debug "Move - done\n", "ai_move";
			$self->setDone();

		# Stop if we've timed out.
		} elsif (timeOut($self->{giveup})) {
			debug "Move - timeout\n", "ai_move";
			$self->setError(1, "Tried too long to move");

		} elsif (timeOut($self->{retry})) {
			debug "Move - retrying\n", "ai_move";
			$messageSender->sendMove($self->{x}, $self->{y});
			$self->{retry}{time} = time;
		}

	} elsif ($self->{state} == WAIT_FOR_TASK) {
		my $task = $self->{task};
		$task->iterate();
		if ($task->getStatus() == Task::DONE) {
			my $error = $task->getError();
			if ($error) {
				$self->setError($error->{code}, $error->{message});
			} else {
				$self->{state} = WORKING;
				$self->{start_time} = time;
				$self->{giveup}{time} = time;
			}
			delete $self->{task};
		}
	}
}

sub mapChanged {
	my (undef, undef, $self) = @_;
	$self->{mapChanged} = 1;
}

1;