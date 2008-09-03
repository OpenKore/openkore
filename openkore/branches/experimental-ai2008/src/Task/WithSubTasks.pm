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
package Task::WithSubTasks;

use strict;
use Carp::Assert;

use Modules 'register';
use Task;
use base qw(Task);

############################################### Constructor and Destructor  ###############################################

sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	# Multiple SubTask support
	$self->{activeSubTasks} = new Set(); # Set of Active SubTasks

	$self->{activeMutexes} = {};
	$self->{tasksByName} = {};
	$self->{events} = {};

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
	# delete $self->{ST_mutexesChangedEvent} if ($self);
}

#################################################### Overrided methods ####################################################

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	foreach my $task @{$self->{activeSubTasks}}) {
		$task->interrupt();
		if ($task->getStatus() == Task::INTERRUPTED) {
			if (! $task->onSubTaskInterrupt->empty()) {
				$task->onSubTaskInterrupt->call($task);
			}
		}
	}
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	foreach my $task @{$self->{activeSubTasks}}) {
		$task->resume();
		if ($task->getStatus() == Task::RUNNING) {
			if (! $task->onSubTaskResume->empty()) {
				$task->onSubTaskResume->call($task);
			}
		}
	}
}

# Overrided method.
sub stop {
	my ($self) = @_;
	$self->SUPER::stop();
	foreach my $task @{$self->{activeSubTasks}}) {
		$task->resume();
		if ($task->getStatus() == Task::STOPPED) {
			if (! $task->onSubTaskStop->empty()) {
				$task->onSubTaskStop->call($task);
			}
		}
	}
}

# ##############################################################
# TODO:
# 1) Itterate only one (first in set) SubTask a time. If it's still Active, move it to the end of list.
# 2) Call Apropriate event hadler
# 3) Intelligent manage of SubTasks
# ##############################################################
sub iterate {
	my ($self) = @_;

	# $self->checkValidity() if DEBUG;
	# $self->reschedule() if ($self->{shouldReschedule});
	# $self->checkValidity() if DEBUG;

	my $activeSubTasks = $self->{activeSubTasks};
	my $activeMutexes = $self->{activeMutexes};

	my $count = $activeSubTasks->size();
	if ($count < 1) $self->reschedule();

	if ($activeSubTasks->size() > 0) {
	# for (my $i = 0; $i < @{$activeSubTasks}; $i++) {
		my $task = $activeSubTasks->get(0);
		my $status = $task->getStatus();
		if ($status != Task::STOPPED) {
			$task->iterate();
			$status = $task->getStatus();
		}

		# Remove tasks that are stopped or done.
		my $status = $task->getStatus();
		if ($status == Task::DONE || $status == Task::STOPPED) {
			$self->deactivateTask($task);

			# Remove the callbacks that we registered in this task.
			my $IDs = $self->{events}{$task};
			# Standart events
			$task->onMutexesChanged->remove($IDs->[0]);
			$task->onStop->remove($IDs->[1]);
			# Custom events
			$task->onSubTaskInterrupt->remove($$IDs->[2]);
			$task->onSubTaskResume->remove($IDs->[3]);
			$task->onSubTaskStop->remove($IDs->[4]);
			$task->onSubTaskDone->remove($IDs->[5]);
			$task->onSubTaskError->remove($IDs->[6]);

			$i--;
			# $self->{shouldReschedule} = 1;
		}
	}
	# $self->checkValidity() if DEBUG;
}

#################################################### Public functions ####################################################

# ##############################################################
# TODO:
# Add some String Identifer, so we could get $task by that ID
# ##############################################################
sub addSubTask {
	my $self = shift;
	my %args = @_;

	if (defined($args{task})) {
		my $task = $args{task};
		$self->{allSubTasks}->add($task);
		$self->{tasksByName}{$task->getName()}++;
		
		# Create Custom Callback Handlers, to call parent event handlers for new task.
		$task{T_onSubTaskInterrupt} = new CallbackList("onSubTaskInterrupt");
		$task{T_onSubTaskResume} = new CallbackList("onSubTaskResume");
		$task{T_onSubTaskStop} = new CallbackList("onSubTaskStop");
		$task{T_onSubTaskDone} = new CallbackList("onSubTaskDone");
		$task{T_onSubTaskError} = new CallbackList("onSubTaskError");

		# Set events and their handlers
		my $ID1 = $task->onMutexesChanged->add($self, \&onMutexesChanged);
		my $ID2 = $task->onStop->add($self, \&onSubTaskDone);
		# Set non standart events and their handlers
		my $ID3 = defined($args{onSubTaskInterrupt}) ? $task->onSubTaskInterrupt->add($self, $args{onSubTaskInterrupt}) : undef;
		my $ID4 = defined($args{onSubTaskResume}) ? $task->onSubTaskResume->add($self, $args{onSubTaskResume}) : undef;
		my $ID5 = defined($args{onSubTaskStop}) ? $task->onSubTaskStop->add($self, $args{onSubTaskStop}) : undef;
		my $ID6 = defined($args{onSubTaskDone}) ? $task->onSubTaskDone->add($self, $args{T_onSubTaskDone}) : undef;
		my $ID7 = defined($args{onSubTaskError}) ? $task->onSubTaskError->add($self, $args{onSubTaskError}) : undef;
		$self->{events}{$task} = [$ID1, $ID2, $ID3, $ID4, $ID5, $ID6, $ID7];
	}
}

# #######################################################################
# TODO:
# Really return Chosen SubTask
# #######################################################################
sub getSubTaskByName {
	# return $_[0]->{ST_subtask};
}

#################################################### Private functions ####################################################

# #######################################################################
# TODO:
# Handle Reporting SubTask Errors
# #######################################################################
sub deactivateSubTask {
	my ($self, $task) = @_;

	my $activeTasks = $self->{activeTasks};
	my $inactiveTasks = $self->{inactiveTasks};
	my $grayTasks = $self->{grayTasks};
	my $tasksByName = $self->{tasksByName};
	my $status = $task->getStatus();
	if ($status != Task::DONE && $status != Task::STOPPED) {
		# $inactiveTasks->add($task);
	} else {
		my $name = $task->getName();
		$tasksByName->{$name}--;
		if ($tasksByName->{$name} == 0) {
			delete $tasksByName->{$name};
		}

		$self->{onSubTaskDone}->call($self, $task);
		$activeTasks->remove($task);
		# $grayTasks->remove($task);
	}

	# ##############################################
	# TODO
	# Rewrite Mutex Handling
	# ##############################################
	# foreach my $mutex (@{$task->getMutexes()}) {
	# 	if ($activeMutexes->{$mutex} == $task) {
	# 		delete $activeMutexes->{$mutex};
	# 	}
	# }
}

# #######################################################################
# TODO:
# Really Recalculate all the active SubTasks mutexes, and set our mutex.
# #######################################################################
sub recalcActiveSubTaskMutexes {
}

################################################ SubTask  callback handlers ################################################

# ###########################################
# TODO:
# Call Handler apropriate registered event for Finished SubTask
# ###########################################
sub onSubTaskDone {
	my ($self, $subtask) = @_;
	$task->onSubTaskDone->call($task);
}

sub onSubTaskMutexesChanged {
	my ($self, $subtask) = @_;
	$self->recalcActiveSubTaskMutexes();
}

sub onSubTaskRestoreMutexes {
	my ($self) = @_;
	$self->recalcActiveSubTaskMutexes();
}

1;