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
# MODULE DESCRIPTION: Convenience abstract base class for classes with multiple SubTasks.
#
# This is an convenience abstract class for tasks which have at least one active subtask
# at any time. It provides convenience methods for making the usage of managing SubTasks
# easy.
#
# AI::Task::WithSubTasks has the following features:
# `l
# - Allows you to run at least one SubTask.
# - Allows you to easly manipulate any Running/Interrupted SubTask.
# - interrupt, resume and stop calls are automatically propagated to all SubTasks.
# - Allows you to define custom behavior when a subtask has completed, compleated with error, stopped, interrupted or even resumed.
# `l`
#
# When you override iterate(), don't forget to check the return value of the
# super method. See $Task_WithSubTasks->iterate() for more information.
#
package AI::Task::WithSubTasks;

# Make all References Strict
use strict;

# Coro Support
use Coro;

# Others (Perl Related)
use Carp::Assert;

# Others (Kore related)
use Modules 'register';
use Utils::Set;
use AI::Task;
use base qw(AI::Task);

####################################
### CATEGORY: Constructor
####################################

##
# AI::Task::WithSubTaks->new(options...)
#
# Create a new AI::Task::WithSubTaks object.
#
# The following options are allowed:
# `l
# - All options allowed for Task->new(), except 'mutexes'.
# `l`
#
sub new {
	my $class = shift;
	my %args = @_;
	my $self = $class->SUPER::new(@_);

	# Multiple SubTask support
	$self->{activeSubTasks} = new Utils::Set();	# Set of Active SubTasks
	$self->{queSubTasks} = new Utils::Set();		# Set of Que SubTasks that need to be Activated
	$self->{unactiveSubTasks} = new Utils::Set();	# Set on Non Active SubTasks

	$self->{activeMutexes} = {};
	$self->{events} = {};
	$self->{shouldReschedule} = 0;
	$self->{firstUse} = 1;

	$self->{ST_oldmutexes} = [];

	return $self;
}

####################################
### CATEGORY: Destructor
####################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
	# delete $self->{ST_mutexesChangedEvent} if ($self);
}

####################################
### CATEGORY: Overrided methods
####################################

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt();
	foreach my $task (@{\%{$self->{activeSubTasks}}}) {
		$self->interruptSubTask($task);
	}
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume();
	foreach my $task (@{\%{$self->{activeSubTasks}}}) {
		$self->resumeSubTask($task);
	}
}

# Overrided method.
sub stop {
	my ($self) = @_;
	$self->SUPER::stop();
	foreach my $task (@{\%{$self->{activeSubTasks}}}) {
		$self->stopSubTask($task);
	}
}

##
# boolean $Task_WithSubTasks->iterate()
#
# This is like $Task->iterate(), but return 0 when any SubTask is running, and 1
# when no SubTasks are running. If you override this method then you must check
# the super call's return value. If the return value is 0 then you should do
# nothing in the overrided iterate() method.
#
# <b>Note:</b> Iterate method will only Iterate one SubTasks a time, to reduce high CPU usage.
#
sub iterate {
	my ($self) = @_;
	$self->SUPER::iterate();

	# Move all SubTasks from Que to Active list
	$self->resort() if ($self->{activeSubTasks}->size() < 1);

	# Activate All pending SubTasks
	$self->reschedule() if ($self->{shouldReschedule});

	# Copy of class Vars.
	my $activeSubTasks = \%{$self->{activeSubTasks}};
	my $activeMutexes = \%{$self->{activeMutexes}};

	# Iterate only one (Top) SubTask. If none in the list, then just do nothing.
	if ($activeSubTasks->size() > 0) {
	# for (my $i = 0; $i < @{$activeSubTasks}; $i++) {
		my $task = $activeSubTasks->get(0);
		my $status = $task->getStatus();
		if ($status != AI::Task::STOPPED) {
			$task->iterate();
			$status = $task->getStatus();
		}

		# Remove tasks that are stopped or done.
		$status = $task->getStatus();
		if ($status == AI::Task::DONE || $status == AI::Task::STOPPED) {
			$self->deactivateSubTask($task);

			# Remove the callbacks that we registered in this task.
			my $IDs = $self->{events}{$task};
			# Standard events
			$task->onMutexesChanged->remove($IDs->[0]);
			$task->onStop->remove($IDs->[1]);
			# Custom events
			$task->onSubTaskInterrupt->remove($$IDs->[2]);
			$task->onSubTaskResume->remove($IDs->[3]);
			$task->onSubTaskStop->remove($IDs->[4]);
			$task->onSubTaskDone->remove($IDs->[5]);
			$task->onSubTaskError->remove($IDs->[6]);

			# $i--;
			$self->{shouldReschedule} = 1;
			return 0;
		} else {
			# Move SubTask to Que list
			my $queTasks = \%{$self->{queSubTasks}};
			$activeSubTasks->remove($task);
			$queTasks->add($task);
			return 0;
		}
	} else {
		return 1;
	}
}

####################################
### CATEGORY: methods
####################################

##
# void $Task_WithSubTasks->addSubTask()
# task: (required) The SubTask you want to run.
# onSubTaskInterrupt: Pointer to function which will be called when <tt>task</tt> is Interrupted.
# onSubTaskResume: Pointer to function which will be called when <tt>task</tt> is Resumed.
# onSubTaskStop: Pointer to function which will be called when <tt>task</tt> is Stopped/Done without Error.
# onSubTaskError: Pointer to function which will be called when <tt>task</tt> is Stopped/Done with Error.
#
# Adds newly created Task to the list of Que SubTasks.
#
# <b>Note:</b> SubTask name must be set, so you could use $Task_WithSubTasks->getSubTaskByName($name).
#
# Example:
# $self->addSubTask(
#	task => new AI::Task::Move(x => $self->{new_x}, y => $self->{new_y}, name => 'move to target'),
#	onSubTaskInterrupt => &onMoveInterrupt,
#	onSubTaskResume => &onMoveResume
#	onSubTaskStop => &onMoveDone
#	onSubTaskError => &onMoveError );
#
sub addSubTask {
	my $self = shift;
	my %args = @_;
	if (defined($args{task})) {
		my $task = $args{task};
		$self->{allSubTasks}->add($task);
		# $self->{tasksByName}{$task->getName()}++;
		
		# Create Custom Callback Handlers, to call parent event handlers for new task.
		$task->{T_onSubTaskInterrupt} = new CallbackList("onSubTaskInterrupt");
		$task->{T_onSubTaskResume} = new CallbackList("onSubTaskResume");
		$task->{T_onSubTaskStop} = new CallbackList("onSubTaskStop");
		$task->{T_onSubTaskDone} = new CallbackList("onSubTaskDone");
		$task->{T_onSubTaskError} = new CallbackList("onSubTaskError");

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

##
# Task $Task_WithSubTasks->getSubTaskByName()
# name: (required) The SubTask name you want to get.
#
# Return SubTask by it's <tt>name</tt>, or undef if there is none.
#
# <b>Note:</b> SubTask name must be set, so you could use this method.
#
# Example:
# my $move_task = $self->getSubTaskByName('move to target');
#
sub getSubTaskByName {
	my ($self, $name) = @_;
	foreach my $task (@{\%{$self->{activeSubTasks}}}, @{\%{$self->{queSubTasks}}}, @{\%{$self->{unactiveSubTasks}}}) {
		my $subtask_name = $task->getName();
		if ($subtask_name eq $name) {
			return $task;
		}
	}
	return undef;
}

# ###############################################################
# Deactivate/Interrupt Active/Que SubTask.
# Note: Don't call this procedure directly.
# ###############################################################
sub deactivateSubTask {
	my ($self, $task) = @_;
	my $activeTasks = \%{$self->{activeTasks}};
	my $status = $task->getStatus();
	if ($status != AI::Task::DONE && $status != AI::Task::STOPPED) {
		$self->interruptSubTask($task);
	} else {
		my $error= $task->getError();
		if ($error) {
			if (! $task->onSubTaskError->empty()) {
				$task->onSubTaskError->call($task, $error);
			}
		} else {
			if (! $task->onSubTaskDone->empty()) {
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
		$self->deleteTaskMutexes($task);
		$self->recalcActiveSubTaskMutexes();
	}
}

# Reschedule All current SubTasks
# Note: Don't call this procedure directly.
sub reschedule {
	my ($self) = @_;
	my $recalcMutex;
	# Activate UnActive SubTasks that don't conflict Anymore
	foreach my $task (@{\%{$self->{unactiveSubTasks}}}) {
		if ($task->getStatus() == AI::Task::INTERRUPTED) {
			# Only Do Restoration if SubTask don't conflict
			my @conflictingMutexes;
			if ((@conflictingMutexes = intersect($self->{activeMutexes}, $task->getMutexes())) == 0) {
				$self->resumeSubTask($task);
				if ($task->getStatus() == AI::Task::RUNNING) {
					# May-be we left some Mutexes???
					$self->deleteTaskMutexes($task);
					# We add SubTask to Que List, so It will iterate Next time
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
					# We add SubTask to Que List, so It will iterate Next time
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
	foreach my $task (@{\%{$self->{activeSubTasks}}}, @{\%{$self->{queSubTasks}}}) {
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
	foreach my $task (@{\%{$self->{activeSubTasks}}}, @{\%{$self->{queSubTasks}}}) {
		my $status = $task->getStatus();
		if ($status == AI::Task::INACTIVE) {
			$task->activate();
		}
	}

	if ($recalcMutex == 1) {
		$self->recalcActiveSubTaskMutexes();
	}

	$self->{shouldReschedule} = 0;

}

# Move all Pending Tasks from Que to Active List
# Note: Don't call this procedure directly.
sub resort {
	my ($self) = @_;

	# Move SubTasks from Que to Active list
	foreach my $task (@{\%{$self->{queSubTasks}}}) {
		# Restore Mutexes part 1
		$self->deleteTaskMutexes($task);
		# Move Task
		$self->{activeSubTasks}->add($task);
		$self->{queSubTasks}->remove($task);
		# Restore Mutexes part 2
		$self->addTaskMutexes($task);
	}

	# We need to Reshedule them, becouse Order may change. 
	$self->{shouldReschedule} = 1;
}

# Add Task Mutexes to list of Active Task Mutexes
# Note: Don't call this procedure directly.
sub addTaskMutexes {
	my ($self, $task) = @_;
	my $activeMutexes    = $self->{activeMutexes};
	foreach my $mutex (@{ $task->getMutexes() }) {
		$activeMutexes->{$mutex} = $task;
	}
}

# Delete Task Mutexes from list of Active Task Mutexes
# Note: Don't call this procedure directly.
sub deleteTaskMutexes {
	my ($self, $task) = @_;
	my $activeMutexes    = $self->{activeMutexes};
	foreach my $mutex (@{$task->getMutexes()}) {
		if ($activeMutexes->{$mutex} == $task) {
			delete $activeMutexes->{$mutex};
		}
	}
}

# Recalculates and Set's current Task mutexes based on SelfMutex and all Active SubTasks mutexes
# Note: Don't call this procedure directly.
sub recalcActiveSubTaskMutexes {
	my ($self) = @_;
	my @activeMutexes;

	foreach my $task (@{\%{$self->{activeSubTasks}}}, @{\%{$self->{queSubTasks}}}) {
		push @activeMutexes, $task->getMutexes();
	}
	push @activeMutexes, $self->{ST_oldmutexes};
	$self->setMutexes(@activeMutexes);
}

##
# void $Task_WithSubTasks->interruptSubTask()
# task: (required) The SubTask you want to Interrupt.
#
# Interrupts the given <tt>task</tt>.
#
# Example:
# $self->interruptSubTask(task=> $self->getSubTaskByName('move to target'));
#
sub interruptSubTask {
	my ($self, $task) = @_;

	if (($self->{activeSubTasks}->has($task))||($self->{queSubTasks}->has($task))) {
		$task->interrupt();
		if ($task->getStatus() == AI::Task::INTERRUPTED) {
			if (! $task->onSubTaskInterrupt->empty()) {
				$task->onSubTaskInterrupt->call($task);
			}
			# May-be we left some Mutexes???
			$self->deleteTaskMutexes($task);
			if ($self->{activeSubTasks}->has($task)) { # Our Task is on Active List
				$self->{activeSubTasks}->remove($task);
				$self->{unactiveSubTasks}->add($task);
			} elsif ($self->{queSubTasks}->has($task)) { # Our Task in on Que List
				$self->{queSubTasks}->remove($task);
				$self->{unactiveSubTasks}->add($task);
			}
			# Now recalc SubTask Mutexes
			$self->recalcActiveSubTaskMutexes();
		}
	}
}

##
# void $Task_WithSubTasks->resumeSubTask()
# task: (required) The SubTask you want to Resume.
#
# Resumes the given <tt>task</tt>.
#
# Example:
# $self->resumeSubTask(task=> $self->getSubTaskByName('move to target'));
#
sub resumeSubTask {
	my ($self, $task) = @_;
	$task->resume();
	if ($task->getStatus() == AI::Task::RUNNING) {
		if (! $task->onSubTaskResume->empty()) {
			$task->onSubTaskResume->call($task);
		}
		# May-be we left some Mutexes???
		$self->deleteTaskMutexes($task);
		if ($self->{unactiveSubTasks}->has($task)) { # Our Task is on Unactive List
			$self->{unactiveSubTasks}->remove($task);
			$self->{queSubTasks}->add($task);
		}
		# Add Current SubTasks Mutexes to the list
		$self->addTaskMutexes($task);
		# Now recalc SubTask Mutexes
		$self->recalcActiveSubTaskMutexes();
	}
}

##
# void $Task_WithSubTasks->stopSubTask()
# task: (required) The SubTask you want to Stop.
#
# Stop the given <tt>task</tt>.
#
# Example:
# $self->stopSubTask(task=> $self->getSubTaskByName('move to target'));
#
sub stopSubTask {
	my ($self, $task) = @_;

	$task->stop();
	if ($task->getStatus() == AI::Task::STOPPED) {
		if (! $task->onSubTaskStop->empty()) {
			$task->onSubTaskStop->call($task);
		}
		# Call SubTask Deactivation
		$self->deactivateSubTask($task);
	}
}

# Return the intersection of the given sets.
#
# set1: A reference to a hash whose keys are the set elements.
# set2: A reference to an array which contains the elements in the set.
# Returns: An array containing the intersect elements.
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

# Check whether $task has a higher priority than all tasks specified
# by the given mutexes.
#
# task: The task to check.
# mutexTaskMapper: A hash which maps a mutex name to a task that owns that mutex.
# mutexes: A list of mutexes to check.
# Requires: All elements in $mutexes can be successfully mapped by $mutexTaskMapper.
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


sub onSubTaskDone {
	my ($self, $task) = @_;

	$self->deactivateSubTask($task);
}

sub onMutexChanged {
	my ($self) = @_;

	$self->recalcActiveSubTaskMutexes();
}

1;
