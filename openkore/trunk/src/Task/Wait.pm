#########################################################################
#  OpenKore - Waiting task
#  Copyright (c) 2006 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This tasks waits a specified number of seconds. After that time has
# elasped, it can run a specified subtask.
#
# So Task::Wait can be used to run a task in a point in the future. Here
# is an example:
# <pre class="">
# # Suppose SomeTestTask is a task which prints "hello!" and then immediately exits.
# my $testTask = new SomeTestTask();
#
# my $waitTask = new Task::Wait(
#         seconds => 3,
#         inGame => 1,
#         task => $testTask);
# $taskManager->add($waitTask);
#
# # If we're logged into RO, then after 3 seconds $testTask will be run, and
# # the message "hello!" will be printed.
# </pre>
#
# When running the subtask, Task::Wait will behave completely like the subtask. That
# is: getMutexes() will return the mutexes of the subtask, onMutexesChanged() events
# from the subtask are propagated, etc.
package Task::Wait;

use strict;
use Time::HiRes qw(time);

use Modules 'register';
use Task::WithSubtask;
use base qw(Task::WithSubtask);
use Globals qw($net);
use Utils qw(timeOut);
use Network;


##
# Task::Wait->new(options...)
#
# Create a new Task::Wait object. The following options are allowed:
# `l`
# - All options allowed for Task::WithSubtask->new(), except autostop.
# - seconds - The number of seconds to wait before marking this task as done or running a subtask.
# - inGame - Whether this task should only do things when we're logged into the game.
#            If not specified, 0 is assumed.
#            If inGame is set to 1 and we're not logged in, then the time we spent while not
#            being logged in does not count as waiting time.
# - task - The subtask to run when Task::Wait is done waiting.
# `l`
# You may pass the 'mutexes' option. getMutexes() will return that mutex list. But if the subtask
# is active then those mutexes are ignored, and the subtask's mutexes are returned instead.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_, autostop => 1);

	$self->{wait}{timeout} = $args{seconds};
	$self->{inGame} = defined($args{inGame}) ? $args{inGame} : 1;

	if ($args{task}) {
		$self->{task} = $args{task};
		$self->{event} = $args{task}->onMutexesChanged->add($self, \&onSubtaskMutexesChanged);
	}

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	if ($self->{task}) {
		$self->{task}->onMutexesChanged->remove($self->{event});
	}
}

sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	$self->{interruptionTime} = time;
}

sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	$self->{wait}{time} += time - $self->{interruptionTime};
}

sub iterate {
	my ($self) = @_;
	return unless ($self->SUPER::iterate() && ( !$self->{inGame} || $net->getState() == Network::IN_GAME ));

	$self->{wait}{time} = time if (!defined $self->{wait}{time});
	if (timeOut($self->{wait})) {
		if ($self->{task}) {
			$self->setSubtask($self->{task});
			$self->onMutexesChanged->call($self);
		} else {
			$self->setDone();
		}
	}
}

sub getMutexes {
	my ($self) = @_;
	my $task = $self->getSubtask();
	if ($task) {
		return $task->getMutexes();
	} else {
		return $self->SUPER::getMutexes();
	}
}

sub subtaskDone {
	my ($self, $task) = @_;
	my $error = $task->getError();
	if ($error) {
		$self->setError($error->{code}, $error->{message});
	} else {
		$self->setDone();
	}
	subtaskStopped($self, $task);
}

sub subtaskStopped {
	my ($self, $task) = @_;
	$task->onMutexesChanged->remove($self->{event});
	delete $self->{event};
}

sub onSubtaskMutexesChanged {
	$_[0]->onMutexesChanged->call($_[0]);
}

1;