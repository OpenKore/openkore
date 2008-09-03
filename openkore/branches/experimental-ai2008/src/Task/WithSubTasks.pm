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
	$self->{queSubTasks} = new Set(); # Set of Active SubTasks
	$self->{unactiveSubTasks} = new Set(); # Set on Non Active SubTasks

	$self->{activeMutexes} = {};
	$self->{events} = {};
	$self->{shouldReschedule} = 0;
	$self->{firstUse} = 1;

	# $self->{ST_oldmutexes};

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
		$self->interruptSubTask($task);
	}
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	foreach my $task @{$self->{activeSubTasks}}) {
		$self->resumeSubTask($task);
	}
}

# Overrided method.
sub stop {
	my ($self) = @_;
	$self->SUPER::stop();
	foreach my $task @{$self->{activeSubTasks}}) {
		@self->stopSubTask($task);
	}
}

# Overrided method.
sub iterate {
	my ($self) = @_;

	# Move all SubTasks from Que to Active list
	$self->resort() if ($self->{activeSubTasks}->size() < 1);

	# Activate All pending SubTasks
	$self->reschedule() if ($self->{shouldReschedule});

	# Copy of class Vars.
	my $activeSubTasks = $self->{activeSubTasks};
	my $activeMutexes = $self->{activeMutexes};

	# Itterate only one (Top) SubTask. If none in the list, then just do nothing.
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
			$self->deactivateSubTask($task);

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
			$self->{shouldReschedule} = 1;
		} else {
			# Move SubTask to Que list
			my $queTasks = $self->{queSubTasks};
			$activeSubTasks->remove($task);
			$queTasks->add($task);
		}
	}
}

#################################################### Public functions ####################################################

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
		my $ID1 = $task->onMutexesChanged->add($self, \&onMutexChanged);
		my $ID2 = $task->onStop->add($self, \&onSubTaskDone);
		# Set non standart events and their handlers
		my $ID3 = defined($args{onSubTaskInterrupt}) ? $task->onSubTaskInterrupt->add($self, $args{onSubTaskInterrupt}) : undef;
		my $ID4 = defined($args{onSubTaskResume}) ? $task->onSubTaskResume->add($self, $args{onSubTaskResume}) : undef;
		my $ID5 = defined($args{onSubTaskStop}) ? $task->onSubTaskStop->add($self, $args{onSubTaskStop}) : undef;
		my $ID6 = defined($args{onSubTaskDone}) ? $task->onSubTaskDone->add($self, $args{T_onSubTaskDone}) : undef;
		my $ID7 = defined($args{onSubTaskError}) ? $task->onSubTaskError->add($self, $args{onSubTaskError}) : undef;
		$self->{events}{$task} = [$ID1, $ID2, $ID3, $ID4, $ID5, $ID6, $ID7];

		# We will need to Rebuild Mutexes when First SubTask was Added.
		if ($self->{firstUse} == 1) {
			my $mutexes = $self->getMutexes();
			$self->{ST_oldmutexes} = [@{$mutexes}];
			$self->{firstUse} = 0;
		};
	}
}

# #######################################################################
# TODO:
# Really return Chosen SubTask by it's Name.
# #######################################################################
sub getSubTaskByName {
	# return $_[0]->{ST_subtask};
}

#################################################### Private functions ####################################################

sub deactivateSubTask {
	my ($self, $task) = @_;

	my $activeTasks = $self->{activeTasks};
	my $status = $task->getStatus();
	if ($status != Task::DONE && $status != Task::STOPPED) {
		if ($self->{activeSubTasks}->has($task)) { # Our Task is on Active List
			$self->{activeSubTasks}->remove($task);
			$self->{unactiveSubTasks}->add($task);
			$self->interruptSubTask($task);
		} elsif ($self->{queSubTasks}->has($task)) { # Our Task in on Que List
			$self->{queSubTasks}->remove($task);
			$self->{unactiveSubTasks}->add($task);
			$self->interruptSubTask($task);
		}
	} else {
		my $error;
		if ($error = $task->getError())) {
			if (! $subtask->onSubTaskError->empty()) {
				$task->onSubTaskError->call($task, $error);
			}
		} else {
			if (! $subtask->onSubTaskDone->empty()) {
				$task->onSubTaskDone->call($task);
			}
		}
		if ($self->{activeSubTasks}->has($task)) { # Our Task is on Active List
			$self->{activeSubTasks}->remove($task);
			$self->{onSubTaskDone}->call($self, $task);
		} elsif ($self->{queSubTasks}->has($task)) { # Our Task in on Que List
			$self->{queSubTasks}->remove($task);
			$self->{onSubTaskDone}->call($self, $task);
		}
	}
	$self->deleteTaskMutexes($task);
	$self->recalcActiveSubTaskMutexes();
}

sub reschedule {
	my ($self) = @_;
	my $recalcMutex;

	# Activate UnActive SubTasks that don't conflict Anymore
	foreach my $task (@{$self->{unactiveSubTasks}}) {
		if ($task->getStatus() == Task::INTERRUPTED) {
			# Only Do Restoration if SubTask don't conflict
			my @conflictingMutexes;
			if ((@conflictingMutexes = intersect($self->{activeMutexes}, $task->getMutexes())) == 0) {
				$self->resumeSubTask($task);
				if ($task->getStatus() == Task::RUNNING) {
					# May-be we left some Mutexes???
					$self->deleteTaskMutexes($task);
					# We add SubTask to Que List, so It will itterate Next time
					$self->{queSubTasks}->add($task);
					$self->{unactiveSubTasks}->remove($task);
					# Now Update Mutex List
					$self->addTaskMutexes($task);
					$recalcMutex = 1;
				}
			# Or We have High Priority then Active SubTask
			} elsif (higherPriority($task, $self->{activeMutexes}, \@conflictingMutexes)) {
					# May-be we left some Mutexes???
					$self->deleteTaskMutexes($task);
					# We add SubTask to Que List, so It will itterate Next time
					$self->{queSubTasks}->add($task);
					$self->{unactiveSubTasks}->remove($task);
					# Now Update Mutex List
					$self->addTaskMutexes($task);
					# Other Operations will handle DeActivation part, that will DeActivate Low Priority SubTask
					$recalcMutex = 1;
			}
		}
	}

	# DeActivete SubTasks that conflict Active/Que SubTasks
	foreach my $task (@{$self->{activeSubTasks}}, @{$self->{queSubTasks}}) {
		# 1st, delete Mutex of Currently checked SubTask
		$self->deleteTaskMutexes($task);

		# 2nd, determinate whatever SubTask has any conflict with all the other Active Mutexes
		my @conflictingMutexes;
		if ((@conflictingMutexes = intersect($self->{activeMutexes}, $task->getMutexes())) != 0) {
			# 3rd, we have conflicts. So check, whatever we have Higher priority
			if (higherPriority($task, $self->{activeMutexes}, \@conflictingMutexes)) {
				# Restore Our Mutexes
				$self->addTaskMutexes($task);
			} else {
				# We have Low Priority then Active/Que SubTask. Move SubTask to UnActive SubTask List.
				if ($self->{activeSubTasks}->has($task)) { # Our Task is on Active List
					$self->{activeSubTasks}->remove($task);
					$self->{unactiveSubTasks}->add($task);
					$self->interruptSubTask($task);
					$recalcMutex = 1;
				} elsif ($self->{queSubTasks}->has($task)) { # Our Task in on Que List
					$self->{queSubTasks}->remove($task);
					$self->{unactiveSubTasks}->add($task);
					$self->interruptSubTask($task);
					$recalcMutex = 1;
				}
			}
		} else {
			$self->addTaskMutexes($task);
		}
	}

	# Activate Pending SubTasks
	foreach my $task (@{$self->{activeSubTasks}}, @{$self->{queSubTasks}}) {
		my $status = $task->getStatus();
		if ($status == Task::INACTIVE) {
			$task->activate();
		}
	}

	if ($recalcMutex == 1) {
		$self->recalcActiveSubTaskMutexes();
	}

	$self->{shouldReschedule} = 0;

}

sub resort {
	my ($self) = @_;
	my $activeTasks	= $self->{activeSubTasks};
	my $queTasks	= $self->{queSubTasks};
	my $oldQueTasks	= $queTasks->deepCopy();

	# Move SubTasks from Que to Active list
	foreach my $task (@{$queTasks}) {
		# Restore Mutexes part 1
		$self->deleteTaskMutexes($task);
		# Move Task
		$activeTasks->add($task);
		$queTasks->remove($task);
		# Restore Mutexes part 2
		$self->addTaskMutexes($task);
	}

	# We need to Reshedule them, becouse Order may change. 
	$self->{shouldReschedule} = 1;
}

# ###############################################################
# Add Task Mutexes to list of Active Task Mutexes
# ###############################################################
sub addTaskMutexes {
	my ($self, $subtask) = @_;

	my $activeMutexes    = $self->{activeMutexes};
	foreach my $mutex (@{$task->getMutexes()}) {
		$activeMutexes->{$mutex} = $task;
	}
}

# ###############################################################
# Delete Task Mutexes from list of Active Task Mutexes
# ###############################################################
sub deleteTaskMutexes {
	my ($self, $subtask) = @_;

	my $activeMutexes    = $self->{activeMutexes};
	foreach my $mutex (@{$subtask->getMutexes()}) {
		if ($activeMutexes->{$mutex} == $subtask) {
			delete $activeMutexes->{$mutex};
		}
	}
}

# #######################################################################
# TODO:
# Make it work.
# "activeMutexes" must hold a list of all active Mutexes used bu all SubTasks
# When Setting Mutexes, it must set the whole list (SelfMutex + All SubTask Mutexes).
# #######################################################################
sub recalcActiveSubTaskMutexes {
	my ($self) = @_;
	my $activeMutexes;
	foreach my $task (@{$self->{activeSubTasks}}, @{$self->{queSubTasks}}) {
		# $task->getMutexes();
	}

	$self->setMutexes(@{$self->{ST_oldmutexes}, $activeMutexes});
}

sub interruptSubTask {
	my ($self, $subtask) = @_;
	$subtask->interrupt();
	if ($subtask->getStatus() == Task::INTERRUPTED) {
		if (! $subtask->onSubTaskInterrupt->empty()) {
			$subtask->onSubTaskInterrupt->call($subtask);
		}
	}
}

sub resumeSubTask {
	my ($self, $subtask) = @_;
	$subtask->resume();
	if ($subtask->getStatus() == Task::RUNNING) {
		if (! $subtask->onSubTaskResume->empty()) {
			$subtask->onSubTaskResume->call($subtask);
		}
	}
}

sub stopSubTask {
	my ($self, $subtask) = @_;
	$subtask->stop();
	if ($subtask->getStatus() == Task::STOPPED) {
		if (! $subtask->onSubTaskStop->empty()) {
			$subtask->onSubTaskStop->call($subtask);
		}
	}
}

# Copy form TaskManager
sub intersect {
	my ($set1, $set2) = @_;
	my @result;
	foreach my $element (@{$set2}) {
		if (exists $set1->{$element}) {
			push @result, $element;
		}
	}
	return @result;
}

# Copy form TaskManager
sub higherPriority {
	my ($task, $mutexTaskMapper, $mutexes) = @_;
	my $priority = $task->getPriority();
	my $result = 1;
	for (my $i = 0; $i < @{$mutexes} && $result; $i++) {
		my $task2 = $mutexTaskMapper->{$mutexes->[$i]};
		$result = $result && $priority > $task2->getPriority();
	}
	return $result;
}


################################################ SubTask  callback handlers ################################################

sub onSubTaskDone {
	my ($self, $subtask) = @_;
	$self->deactivateSubTask($task);
}

sub onMutexChanged {
	my ($self) = @_;
	$self->recalcActiveSubTaskMutexes();
}

1;