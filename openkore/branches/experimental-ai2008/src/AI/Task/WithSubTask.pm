#########################################################################
#  OpenKore - Convenience abstract base class for classes with subtasks.
#  Copyright (c) 2006,2007 OpenKore Developers
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Convenience abstract base class for classes with SubTask.
#
# This is an convenience abstract class for tasks which have at most one active subtask
# at any time. It provides convenience methods for making the usage of subtask
# easy.
#
# AI::Task::WithSubTask has the following features:
# `l
# - Allows you to easily switch context to a subtask, allowing to subtask to
#   temporarily have complete control.
# - interrupt(), resume() and stop() calls are automatically propagated to subtask.
# - Allows you to define custom behavior when a subtask has completed or stopped.
# `l`
#
# When you override iterate(), don't forget to check the return value of the
# super method. See $Task_WithSubTask->iterate() for more information.
#
package AI::Task::WithSubTask;

# Make all References Strict
use strict;

# Others (Perl Related)
use Carp::Assert;

# Others (Kore Related)
use Modules 'register';
use AI::Task;
use base qw(AI::Task);

##
# AI::Task::WithSubTask->new(options...)
#
# Create a new AI::Task::WithSubTask object. All options for AI::Task->new() are allowed.
# Two more options are allowed: <tt>autostop</tt> and <tt>autofail</tt> (both
# are booleans).
#
# <tt>autostop</tt> which will influence the effect of the stop() method:
# `l
# - If autostop is set to 1: If a subtask is currently running, then the subtask's
#   stop() method will be called, and the current task's status will be set to
#   AI::Task::STOPPED after the subtask has stopped.<br>
#   If a subtask is not currently running, then the current task's status is
#   immediately set to AI::Task::STOPPED.
# - If autostop is set to 0: If a subtask is currently running, then the subtask's
#   stop() method will be called. Nothing else will happen in the current task:
#   this is useful if you need to implement custom stop code.
# `l`
# The default value is true.
#
# <tt>autofail</tt> specifies whether this task should automatically fail if a subtask
# has failed.
# `l
# - If autofail is on, and the subtask fails, then this task's status will
#   be marked as DONE, and the error code and error message of the subtask will be
#   passed to this task.
# - If autofail is off, nothing will happen if a subtask fails. You are then responsible
#   for handling the failure yourself by placing appropriate code in the method
#   subtaskDone().
# `l`
# The default value is true.
#
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);
	$self->{ST_autostop} = defined($args{autostop}) ? $args{autostop} : 1;
	$self->{ST_autofail} = defined($args{autofail}) ? $args{autofail} : 1;
	$self->{ST_manageMutexes} = $args{manageMutexes};
	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
	delete $self->{ST_mutexesChangedEvent} if ($self);
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
		if ($task->getStatus() == AI::Task::STOPPED) {
			$self->SUPER::stop() if ($self->{ST_autostop});
			delete $self->{ST_subtask};
			$self->subtaskStopped($task);
		}
	} elsif ($self->{ST_autostop}) {
		$self->SUPER::stop();
	}
}

##
# boolean $Task_WithSubTask->iterate()
#
# This is like $Task->iterate(), but return 0 when a subtask is running, and 1
# when a subtask is not running. If you override this method then you must check
# the super call's return value. If the return value is 0 then you should do
# nothing in the overrided iterate() method.
#
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();

	if ($self->{ST_subtask}) {
		# Run subtask if there is one.
		my $task = $self->{ST_subtask};
		$task->iterate();

		# If the task is completed, then we return 1 (with one exception, see below).
		# This way the child class doesn't have to wait for the next
		# iteration before it can continue.
		if ($task->getStatus() == AI::Task::DONE) {
			my $error;
			my $result = 1;
			_restoreMutexes($self);
			delete $self->{ST_subtask};
			if ($self->{ST_autofail} && ($error = $task->getError())) {
				$error = $self->translateSubtaskError($task, $error);
				$self->setError($error->{code}, $error->{message});
				# We already set the current task's status to DONE,
				# so we don't want the child class's iterate() method
				# to do anything.
				$result = 0;
			}
			$self->subtaskDone($task);
			return $result;

		} elsif ($task->getStatus() == AI::Task::STOPPED) {
			$self->setStopped() if ($self->{ST_autostop});
			_restoreMutexes($self);
			delete $self->{ST_subtask};
			$self->subtaskStopped($task);
			return 1;

		} else {
			# Task is not completed.
			return 0;
		}

	} else {
		return 1;
	}
}

##
# Task $Task_WithSubTask->getSubtask()
#
# Return the currently set subtask, or undef if there is none.
#
sub getSubtask {
	return $_[0]->{ST_subtask};
}

##
# void $Task_WithSubTask->setSubtask(Task subtask)
# Requires: !defined($self->getSubtask()) && $subtask->getStatus() == AI::Task::INACTIVE
# Ensures: $self->getSubtask() == $subtask
#
# Set the currently active subtask. This subtask is immediately activated. In the next
# iteration, the subtask will be run, and iterate() will return 0 to indicate that
# we're currently running a subtask.
#
# When the subtask is done or stopped, getSubtask() will return undef.
#
sub setSubtask {
	my ($self, $subtask) = @_;
	assert(!defined($self->getSubtask())) if DEBUG;
	assert($subtask->getStatus() == AI::Task::INACTIVE) if DEBUG;
	$self->{ST_subtask} = $subtask;
	if ($subtask) {
		$subtask->activate();
		if ($self->{ST_manageMutexes}) {
			# Save the current mutexes (before we switched to the subtask).
			my $mutexes = $self->getMutexes();
			$self->{ST_oldmutexes} = [@{$mutexes}];

			# Watch for changes in the subtask's mutex list and assign the subtask's
			# current mutexes to current task.
			$self->{ST_mutexesChangedEvent} = $subtask->onMutexesChanged->add($self,
				\&_onSubtaskMutexesChanged);
			_onSubtaskMutexesChanged($self, $subtask);
		}
	}
}

##
# void $Task_WithSubTask->subtaskDone(Task subtask)
#
# Called when a subtask has completed, either successfully or with an error.
#
# <b>Note:</b> if autofail is on, and the subtask has completed with an error,
# then the following is true:
# `l
# - $self->getStatus() == AI::Task::DONE
# - The return value of $self->getError() is defined.
# `l`
#
sub subtaskDone {
}

##
# void $Task_WithSubTask->subtaskStopped(Task subtask)
#
# Called when a subtask is stopped by AI::Task::WithSubTask.
#
sub subtaskStopped {
}

##
# Hash* $Task_WithSubTask->translateSubtaskError(Task subtask, Hash* error)
# subtask: The subtask that finished with an error.
# error: The subtask's error hash.
# Returns: A new error hash.
# Ensures: defined(result)
#
# When 'autofail' is turned on, AI::Task::WithSubTask will set the error code and
# error message of this task to the same value as the error code/message of the
# subtask. If that is not what you want, then you can override that behavior
# by overriding this method.
#
# This method allows you to specify how a subtask's error should be translated
# into an error for this task.
#
sub translateSubtaskError {
	my ($self, $task, $error) = @_;
	return $error;
}

# If this method is called then it means automutex is on.
sub _onSubtaskMutexesChanged {
	my ($self, $subtask) = @_;
	my $mutexes = $subtask->getMutexes();
	$self->setMutexes(@{$mutexes});
}

# Remove the callback on the subtask's OnMutexesChanged event,
# and restore the mutex state to what it was before we switched
# to the subtask.
sub _restoreMutexes {
	my ($self) = @_;
	if ($self->{ST_manageMutexes}) {
		$self->{ST_subtask}->onMutexesChanged->remove($self->{ST_mutexesChangedEvent});
		delete $self->{ST_mutexesChangedEvent};
		$self->setMutexes(@{$self->{ST_oldmutexes}});
		delete $self->{ST_oldmutexes};
	}
}

1;