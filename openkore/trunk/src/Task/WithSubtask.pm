#########################################################################
#  OpenKore - NPC talking task
#  Copyright (c) 2004-2006 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# This is an abstract class for tasks which have at most one active subtask
# at any time. It provides convenience methods for making the usage of subtasks
# easy.
#
# Task::WithSubtask has the following features:
# `l
# - Allows you to easily switch context to a subtask, allowing to subtask to
#   temporarily have complete control.
# - interrupt(), resume() and stop() calls are automatically propagated to subtasks.
# - Allows you to define custom behavior when a subtask has completed or stopped.
# `l`
#
# When you override iterate(), don't forget to check the return value of the
# super method. See $Task_WithSubtask->iterate() for more information.
package Task::WithSubtask;

use strict;
use Carp::Assert;
use Modules 'register';
use Task;
use base qw(Task);

# TODO: handle mutex changes in subtasks

##
# Task::WithSubtask->new(options...)
#
# Create a new Task::WithSubtask object. All options for Task->new() are allowed.
#
# There's an extra allowed option, <tt>autostop</tt>, which will influence the effect
# of the stop() method:
# `l
# - If autostop is set to 1: If a subtask is currently running, then the subtask's
#   stop() method will be called, and the current task's status will be set to
#   Task::STOPPED after the subtask has stopped.<br>
#   If a subtask is not currently running, then the current task's status is
#   immediately set to Task::STOPPED.
# - If autostop is set to 0: If a subtask is currently running, then the subtask's
#   stop() method will be called. Nothing else will happen in the current task:
#   this is useful if you need to implement custom stop code.
# `l`
# If autostop is not specified, then it will be assumed to be 1.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);
	$self->{ST_autostop} = defined($args{autostop}) ? $args{autostop} : 1;
	return $self;
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	$self->{ST_subtask}->interrupt() if ($self->{ST_subtask});
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	$self->{ST_subtask}->resume() if ($self->{ST_subtask});
}

# Overrided method.
sub stop {
	my ($self) = @_;
	if ($self->{ST_subtask}) {
		my $task = $self->{ST_subtask};
		$task->stop();
		if ($task->getStatus() == Task::STOPPED) {
			$self->SUPER::stop() if ($self->{ST_autostop});
			delete $self->{ST_subtask};
			$self->subtaskStopped($task);
		}
	} elsif ($self->{ST_autostop}) {
		$self->SUPER::stop();
	}
}

##
# boolean $Task_WithSubtask->iterate()
#
# This is like $Task->iterate(), but return 0 when a subtask is running, and 1
# when a subtask is not running. If you override this method then you must check
# the super call's return value. If the return value is 0 then you should do
# nothing in the overrided iterate() method.
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();

	if ($self->{ST_subtask}) {
		# Run subtask if there is one.
		my $task = $self->{ST_subtask};
		$task->iterate();
		if ($task->getStatus() == Task::DONE) {
			delete $self->{ST_subtask};
			$self->subtaskDone($task);
		} elsif ($task->getStatus() == Task::STOPPED) {
			$self->setStopped() if ($self->{ST_autostop});
			delete $self->{ST_subtask};
			$self->subtaskStopped($task);
		}
		return 0;
	} else {
		return 1;
	}
}

##
# Task $Task_WithSubtask->getSubtask()
#
# Return the currently set subtask, or undef if there is none.
sub getSubtask {
	return $_[0]->{ST_subtask};
}

##
# void $Task_WithSubtask->setSubtask(Task subtask)
# Requires: !defined($self->getSubtask()) && $subtask->getStatus() == Task::INACTIVE
# Ensures: $self->getSubtask() == $subtask
#
# Set the currently active subtask.This subtask is immediately activated. In the next
# iteration, the subtask will be run, and iterate() will return 0 to indicate that
# we're currently running a subtask.
#
# When the subtask is done or stopped, getSubtask() will return undef.
sub setSubtask {
	my ($self, $subtask) = @_;
	assert(!defined($self->getSubtask())) if DEBUG;
	assert($subtask->getStatus() == Task::INACTIVE);
	$self->{ST_subtask} = $subtask;
	$subtask->activate() if ($subtask);
}

##
# void $Task_WithSubtask->subtaskDone(Task task)
#
# Called when a subtask has completed, either successfully or with an error.
sub subtaskDone {
}

##
# void $Task_WithSubtask->subtaskStopped(Task task)
#
# Called when a subtask is stopped by Task::WithSubtask.
sub subtaskStopped {
}

1;