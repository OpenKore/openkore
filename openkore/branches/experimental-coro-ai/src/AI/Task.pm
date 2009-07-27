#########################################################################
#  OpenKore - Task framework
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
# MODULE DESCRIPTION: Abstract task base class.
#
# This is the abstract base class for all tasks. Please read
# <a href="http://www.openkore.com/wiki/index.php/AI_subsystem_and_task_framework_overview">
# the AI subsystem and task framework overview
# </a>
# for an overview.
#
# <h3>Notes on priority constants</h3>
# The only things you may assume about the values of priority contants are:
# `l
# - Each priority constant differ at least a value of 100 from other priority constants.
#   That is, <tt>abs(c1 - c2) >= 300</tt> if c1 and c2 are two random priority constants.
# - A higher value means a higher priority.
# `l`
#
package AI::Task;

# Make all References Strict
use strict;

# Coro Support
use Coro;

# Others (Perl Related)
use Carp;
use Carp::Assert;

# Others (Kore related)
use Modules 'register';
use Utils::CallbackList;
use Utils::Set;


####################################
### CATEGORY: Priority constants
###################################

##
# Task::LOW_PRIORITY
#
# Indicates a low task priority.
#
use constant LOW_PRIORITY    => 100;

##
# Task::NORMAL_PRIORITY
#
# Indicates a normal task priority.
#
use constant NORMAL_PRIORITY => 500;

##
# Task::HIGH_PRIORITY
#
# Indicates a high task priority.
#
use constant HIGH_PRIORITY   => 1000;

##
# Task::USER_PRIORITY
#
# Priority used for user-invoked commands.
#
use constant USER_PRIORITY   => 5000;


###################################
### CATEGORY: Status constants
###################################

##
# Task::INACTIVE
#
# Indicates that the task has just been created.
#
use constant INACTIVE    => 0;

##
# Task::RUNNING
#
# Indicates that the task is running.
#
use constant RUNNING     => 1;

##
# Task::INTERRUPTED
#
# Indicates that the task is interrupted, and not running.
#
use constant INTERRUPTED => 2;

##
# Task::STOPPED
#
# Indicates that the task is stopped. A stopped task cannot resume.
#
use constant STOPPED     => 3;

##
# Task::DONE
#
# Indicates that the task is completed. A completed task cannot be stopped or interrupted.
#
use constant DONE        => 4;


####################################
### CATEGORY: Constructor
####################################

##
# Task->new(options...)
# Ensures: result->getStatus() == Task::INACTIVE
#
# Create a new Task object. The following options are allowed:
# `l
# - <tt>name</tt> - A name for this task. $Task->getName() will return this name.
#                   If not specified, the class's name (excluding the "Task::" prefix) will be used as name.
# - <tt>priority</tt> - A priority for this task. $Task->getPriority() will return this value.
#                       The default priority is Task::NORMAL_PRIORITY
# - <tt>mutexes</tt> - A reference to an array of mutexes. $Task->getMutexes() will return this value.
#                      The default is an empty mutex list.
# `l`
#
sub new {
	my $class = shift;
	my %args = @_;
	my $allowed = new Utils::Set("name", "priority", "mutexes");
	my %self;

	foreach my $key (keys %args) {
		if ($allowed->has($key)) {
			$self{"T_$key"} = $args{$key};
		}
	}

	if (!defined $self{T_name}) {
		$self{T_name} = $class;
		$self{T_name} =~ s/.*:://;
	}
	$self{T_status} = INACTIVE;
	$self{T_priority} = NORMAL_PRIORITY if (!defined $self{T_priority});
	$self{T_mutexes} = [] if (!defined $self{T_mutexes});

	$self{T_onMutexesChanged} = new CallbackList("onMutexesChanged");
	$self{T_onStop} = new CallbackList("onStop");

	return bless \%self, $class;
}

sub _getStatusName {
	my ($status) = @_;
	if ($status == INACTIVE) {
		return 'INACTIVE';
	} elsif ($status == RUNNING) {
		return 'RUNNING';
	} elsif ($status == INTERRUPTED) {
		return 'INTERRUPTED';
	} elsif ($status == STOPPED) {
		return 'STOPPED';
	} elsif ($status == DONE) {
		return 'DONE';
	} else {
		return $status;
	}
}

sub _assertStatus {
	my $self = shift;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $currentStatus = $self->{T_status};
	foreach my $status (@_) {
		if ($status == $currentStatus) {
			return;
		}
	}

	my @expectedStatuses = map { _getStatusName($_) } @_;
	Carp::confess("The current task's status should be one of: (" . join(',', @expectedStatuses) . ")\n" .
		"But it's actually: " . _getStatusName($currentStatus) . "\n");
}

####################################
### CATEGORY: Destructor
###################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY() if ($self->can("SUPER::DESTROY"));
}

############################
### CATEGORY: Queries
############################

##
# String $Task->getName()
# Ensures: $result ne ""
#
# Returns a human-readable name for this task.
#
sub getName {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	return $_[0]->{T_name};
}

##
# $Task->getStatus()
#
# Returns the task's status. This is one of AI::Task::RUNNING, AI::Task::INTERRUPTED, AI::Task::STOPPED or AI::Task::DONE.
#
sub getStatus {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	return $_[0]->{T_status};
}

##
# Hash* $Task->getError()
# Requires: $self->getStatus() == AI::Task::DONE
#
# If the status is AI::Task::DONE, then return information about the error (if the task
# completed with an error).
# Otherwise (if the task completed successfully), return undef.
#
# The error information is a reference to a hash, containing two items:
# `l
# - code - The error code.
# - message - The error message.
# `l`
#
sub getError {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	$_[0]->_assertStatus(DONE) if DEBUG;
	return $_[0]->{T_error};
}

##
# Array<String>* $Task->getMutexes()
# Ensures: defined(result)
#
# Returns a reference to an array of mutexes for this task. Note that the mutex list may
# change during a Task's life time. This list must not be modified outside the AI::Task object.
#
# If you override this method, then you <b>must</b> ensure that when the mutex list changes,
# you trigger a onMutexesChanged event. Otherwise the task manager will not behave correctly.
#
sub getMutexes {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	return $_[0]->{T_mutexes};
}

##
# int $Task->getPriority()
#
# Get the priority for this task. This priority is guaranteed to never change during a Task's
# life time.
#
sub getPriority {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	return $_[0]->{T_priority};
}


#####################################
### CATEGORY: Events
#####################################

##
# CallbackList $Task->onMutexesChanged()
#
# This event is triggered when the mutex list for this task has changed.
#
sub onMutexesChanged {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	return $_[0]->{T_onMutexesChanged};
}

##
# CallbackList $Task->onStop()
#
# This event is triggered when the task's status has been set to AI::Task::STOPPED.
#
sub onStop {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	return $_[0]->{T_onStop};
}


#####################################
### CATEGORY: Protected commands
#####################################

##
# void $Task->setError(code, message)
# code: An error code.
# message: An error message.
# Requires: $self->getStatus() == AI::Task::INACTIVE or AI::Task::RUNNING
#
# Indicate that the task has been completed, but with an error.
# The status will be set to AI::Task::DONE, and $Task->getError() will return
# the error information passed to this method.
#
# Do not call this method outside $Task->iterate(), or bad things will happen!
#
sub setError {
	my ($self, $code, $message) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	$self->_assertStatus(INACTIVE, RUNNING) if DEBUG;
	$self->{T_error} = {
		code => $code,
		message => $message
	};
	$self->{T_status} = DONE;
}

##
# void $Task->setDone()
# Requires: $self->getStatus() == AI::Task::INACTIVE or AI::Task::RUNNING
#
# Indicate that the task has been completed, without error. The
# status will be set to AI::Task::DONE.
#
# Do not call this method outside $Task->iterate(), or bad things will happen!
#
sub setDone {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	$self->_assertStatus(INACTIVE, RUNNING) if DEBUG;
	$self->{T_status} = DONE;
}

##
# void $Task->setStopped()
# Requires: $self->getStatus() == AI::Task::RUNNING, AI::Task::INACTIVE or AI::Task::INTERRUPTED
# Ensures: $self->getStatus() == AI::Task::STOPPED
#
# Set the task's status to AI::Task::STOPPED and trigger an onStop event.
# This is useful for tasks that cannot stop immediately
# when stop() is called: they can mark the task as stopped when appropriate.
#
sub setStopped {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	$self->_assertStatus(INACTIVE, RUNNING, INTERRUPTED) if DEBUG;
	$self->{T_status} = STOPPED;
	$self->{T_onStop}->call($self);
}

##
# void $Task->setMutexes(mutexes...)
#
# Set the currently active mutexes for this task. This will trigger an
# onMutexesChanged event.
#
# You should only call this method inside the class's iterate() method,
# or during initialization. Otherwise you may confuse the task manager.
#
sub setMutexes {
	my $self = shift;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	$self->{T_mutexes} = \@_;
	$self->{T_onMutexesChanged}->call($self);
}


#####################################
### CATEGORY: Public commands
#####################################

##
# void $Task->activate()
# Requires: $self->getStatus() == AI::Task::INACTIVE
# Ensures: $self->getStatus() == AI::Task::RUNNING
#
# Notify a task that it will be activated. Activation happens only once:
# just before iterate() is called, but only if the task has just been created.
# This allows the task to perform initialization.
#
# This method will be called by the task manager.
#
sub activate {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	$_[0]->_assertStatus(INACTIVE) if DEBUG;
	$_[0]->{T_status} = RUNNING;
}

##
# void $Task->interrupt()
# Requires: $self->getStatus() == AI::Task::RUNNING
# Ensures: $self->getStatus() == AI::Task::INTERRUPTED
#
# Notify a (running) task that it is about to be interrupted. The task may take necessary actions
# (like updating internal timers) in preparation for interruption. The task must immediately
# cease all actions, and set the status to Task::INTERRUPTED.
#
# This method should only be called by the task manager.
#
# Task implementors may override this method to implement code for interruption handling.
#
sub interrupt {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	$_[0]->_assertStatus(RUNNING) if DEBUG;
	$_[0]->{T_status} = INTERRUPTED;
}

##
# void $Task->resume()
# Requires: $self->getStatus() == AI::Task::INTERRUPTED
# Ensures: $self->getStatus() == AI::Task::RUNNING
#
# Notify an (interrupted) task that it is about to be resumed. The task may take
# necessary actions in prepration for resuming. The task must set its status to
# AI::Task::RUNNING.
#
# This method should only be called by the task manager.
#
# Task implementors may override this method to implement code for resume handling.
#
sub resume {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	$_[0]->_assertStatus(INTERRUPTED) if DEBUG;
	$_[0]->{T_status} = RUNNING;
}

##
# void $Task->stop()
# Requires: $self->getStatus() == AI::Task::RUNNING, AI::Task::INACTIVE or AI::Task::INTERRUPTED
#
# Notify a task that it must completely stop. When the task is actually stopped,
# the status must be set to AI::Task::STOPPED.
#
# The default behavior is to immediate set the status to AI::Task::STOPPED
# by calling $Task->setStopped(), thereby triggering an onStop event.
# Task implementors may override this method to implement custom stop handling.
# You may choose to stop the task after a period of time, instead of immediately.
#
# This method may be called by anybody, not just the task manager.
#
sub stop {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	$_[0]->setStopped();
}

##
# void $Task->iterate()
# Requires: $self->getStatus() == AI::Task::RUNNING
#
# Run one iteration of this task. Task implementors must override this method to
# implement task code.
#
sub iterate {
	# MultiThreading Support
	lock ($_[0]) if (is_shared($_[0]));

	$_[0]->_assertStatus(RUNNING) if DEBUG;
}

1;
