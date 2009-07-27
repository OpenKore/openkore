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
# MODULE DESCRIPTION: Task manager.
#
# Please read
# <a href="http://www.openkore.com/wiki/index.php/AI_subsystem_and_task_framework_overview">
# the AI subsystem and task framework overview
# </a>
# for an overview.
#
package AI::TaskManager;

# Make all References Strict
use strict;

# Coro Support
use Coro;

# Others (Perl Related)
use Carp::Assert;

# Others (Kore related)
use Modules 'register';
use AI::Task;
use Utils::Set;
use Utils::CallbackList;
use Log qw(warning debug);

####################################
### CATEGORY: Constructor
####################################

##
# AI::TaskManager->new()
#
# Create a new AI::TaskManager.
#
sub new {
	my ($class) = @_;
	my %self = (
		# Utils::Set<AI::Task>
		# Indexed set of currently active tasks.
		# Invariant:
		#     for all $task in activeTasks:
		#         $task->getStatus() == AI::Task::RUNNING or AI::Task::STOPPED
		#         !$inactiveTasks->has($task)
		#         if $task is not in $grayTasks:
		#             $task owns all its mutexes.
		activeTasks => new Utils::Set(),

		# Utils::Set<AI::Task>
		# Indexed set of currently inactive tasks.
		# Invariant:
		#     for all $task in inactiveTasks:
		#         $task->getStatus() == AI::Task::INTERRUPTED, AI::Task::INACTIVE, or AI::Task::STOPPED
		#         !$activeTasks->has($task)
		#         $task owns none of its mutexes.
		inactiveTasks => new Utils::Set(),

		# Hash<String, AI::Task->{T_ID}>
		#
		# Currently active mutexes. The keys are the mutex names, and the
		# values are the tasks that have a lock on the mutex (the mutex owner).
		#
		# Invariant: all tasks in $activeMutexes appear in $activeTasks.
		activeMutexes => {},

		# Utils::Set<AI::Task>
		# Indexed set of tasks for which the mutex list has changed. These tasks
		# must be re-scheduled.
		# Invariant:
		#     for all $task in grayTasks:
		#         $task->getStatus() == AI::Task::RUNNING
		#         $activeTasks->has($task)
		#         !$inactiveTasks->has($task)
		grayTasks => new Utils::Set(),

		# Hash<String, int>
		# This variable remembers the number of instances for each task name.
		#
		# Invariant:
		#     All task names in $activeTasks and $inactiveTasks are in $tasksByName.
		#     for all $value in $tasksByName:
		#         defined($value) && $value > 0
		tasksByName => {},

		# Maps a Task to an array of callback IDs. Used to unregister callbacks.
		# Invariant: Every task in $activeTasks and $inactiveTasks is in $events.
		events => {},

		# Whether tasks should be rescheduled on the
		# next iteration.
		shouldReschedule => 0,

		# OnTaskFinished Event List
		onTaskFinished => new CallbackList(),

		# Last Task ID
		lastID => 0,

		# List of Free task ID's, SO we do not overload $self->{lastID}
		freeIDs => []
	);
	return bless \%self, $class;
}

sub DESTROY {
	my ($self) = @_;
	if ($self->can("SUPER::DESTROY")) {
		debug "Destroying: ".__PACKAGE__."!\n";
		$self->SUPER::DESTROY();
	}
}

##
# void $TaskManager->add(AI::Task task)
# Requires: $task->getStatus() == AI::Task::INACTIVE
#
# Add a new task to this task manager.
#
sub add {
	my ($self, $task) = @_;
	assert(defined $task) if DEBUG;
	assert($task->getStatus() == AI::Task::INACTIVE) if DEBUG;

	# Avoid adding already existing module phase 1
	if ($self->{activeTasks}->has($task) || $self->{inactiveTasks}->has($task) || $self->{grayTasks}->has($task)) {
		return 0;
	};

	# Avoid adding already existing task phase 2
	if ($task->{T_ID} > 0) {
		# We do not allow adding already added modules
		return 0;
	}

	# Assign task ID
	$task->{T_ID} = $self->_gen_id();

	$self->{inactiveTasks}->add($task);
	$self->{tasksByName}{$task->getName()}++;
	$self->{shouldReschedule} = 1;

	my $ID1 = $task->onMutexesChanged->add($self, \&onMutexesChanged);
	my $ID2 = $task->onStop->add($self, \&onStop);
	$self->{events}{$task->{T_ID}} = [$ID1, $ID2];
}

# Reschedule tasks. Do not call this method directly!
sub reschedule {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $activeTasks      = \%{$self->{activeTasks}};
	my $inactiveTasks    = \%{$self->{inactiveTasks}};
	my $grayTasks        = \%{$self->{grayTasks}};
	my $activeMutexes    = $self->{activeMutexes};
	my $oldActiveTasks   = $activeTasks->deepCopy();
	my $oldInactiveTasks = $inactiveTasks->deepCopy();

	# The algorithm produces the following result:
	# All active tasks do not conflict with each other, such tasks with higher
	# priority will be active compared to conflicting tasks with lower priority.
	#
	# This algorithm does not produce the optimal result as that would take
	# far too much time, but the result should be good enough in most cases.

	# Deactivate gray tasks that conflict with active mutexes.
	while (@{$grayTasks} > 0) {
		my $task = $grayTasks->get(0);
		my $hasConflict = 0;
		foreach my $mutex (@{$task->getMutexes()}) {
			if (exists $activeMutexes->{$mutex}) {
				$hasConflict = 1;
				last;
			}
		}

		if ($hasConflict) {
			# There is a conflict, so make this task inactive.
			$self->deactivateTask($activeTasks, $inactiveTasks,
				$grayTasks, $activeMutexes, $self->{tasksByName},
				$task);
		} else {
			# No conflict, so assign mutex locks to this task
			# and remove its "gray" mark.
			foreach my $mutex (@{$task->getMutexes()}) {
				$activeMutexes->{$mutex} = $task->{T_ID};
			}
			shift @{$grayTasks};
		}
	}

	# Activate inactive tasks such that active tasks don't conflict with each other.
	for (my $i = 0; $i < @{$inactiveTasks}; $i++) {
		my $task = $inactiveTasks->get($i);
		my @conflictingMutexes;

		# If this task is stopped then we just throw it away.
		if ($task->getStatus() == AI::Task::STOPPED) {
			$inactiveTasks->remove($task);
			$i--;

		# Check whether this task conflicts with the currently locked mutexes.
		} elsif ((@conflictingMutexes = intersect($activeMutexes, $task->getMutexes())) == 0) {
			# No conflicts, we can activate this task.
			$activeTasks->add($task);
			$inactiveTasks->remove($task);
			$i--;
			foreach my $mutex (@{$task->getMutexes()}) {
				$activeMutexes->{$mutex} = $task->{T_ID};
			}

		} elsif ($self->higherPriority($task, $activeMutexes, \@conflictingMutexes)) {
			# There are conflicts. Does this task have a higher priority
			# than all tasks specified by the conflicting mutexes?
			# If yes, let it steal the mutex, activate it and deactivate
			# the previous mutex owner.

			$activeTasks->add($task);
			$inactiveTasks->remove($task);
			$i--;

			foreach my $mutex (@{$task->getMutexes()}) {
				my $oldTask = $self->_find_task_by_id($activeMutexes->{$mutex});
				if ($oldTask) {
					# Mutex was locked by lower priority task.
					# Deactivate old task.
					$self->deactivateTask($activeTasks, $inactiveTasks,
						$grayTasks, $activeMutexes, $self->{tasksByName},
						$oldTask);
				}
				$activeMutexes->{$mutex} = $task->{T_ID};
			}
		}
	}

	# Resume/activate newly activated tasks.
	foreach my $task (@{$activeTasks}) {
		if (!$oldActiveTasks->has($task)) {
			my $status = $task->getStatus();
			if ($status == AI::Task::INACTIVE) {
				$task->activate();
			} elsif ($status == AI::Task::INTERRUPTED) {
				$task->resume();
			}
		}
	}

	# Interrupt newly deactivated tasks.
	foreach my $task (@{$inactiveTasks}) {
		if (!$oldInactiveTasks->has($task)) {
			my $status = $task->getStatus();
			$task->interrupt() if ($status != AI::Task::INTERRUPTED && $status != AI::Task::INACTIVE && $status != AI::Task::STOPPED);
		}
	}

	$self->{shouldReschedule} = 0;
}

##
# void $TaskManager->checkValidity()
#
# Check whether the internal invariants are correct. Dies if that is not the case.
#
sub checkValidity {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $activeTasks   = \%{$self->{activeTasks}};
	my $inactiveTasks = \%{$self->{inactiveTasks}};
	my $grayTasks     = \%{$self->{grayTasks}};
	my $activeMutexes = $self->{activeMutexes};

	foreach my $task (@{$activeTasks}) {
		assert($task->getStatus() == AI::Task::RUNNING || $task->getStatus() == AI::Task::STOPPED);
		assert(!$inactiveTasks->has($task));
		if (!$grayTasks->has($task)) {
	 		foreach my $mutex (@{$task->getMutexes()}) {
				assert($activeMutexes->{$mutex} == $task->{T_ID});
 			}
 		}
	}
	foreach my $task (@{$inactiveTasks}) {
		my $status = $task->getStatus();
		assert($status == AI::Task::INTERRUPTED || $status == AI::Task::INACTIVE || $status == AI::Task::STOPPED);
		assert(!$activeTasks->has($task));
		foreach my $mutex (@{$task->getMutexes()}) {
			assert($activeMutexes->{$mutex} != $task->{T_ID});
		}
	}
	foreach my $task (@{$grayTasks}) {
		assert($activeTasks->has($task));
		assert(!$inactiveTasks->has($task));
	}

	# Wrong Mutex Cheking.
	$activeMutexes = $self->{activeMutexes};
	foreach my $mutex (keys %{$activeMutexes}) {
		my $owner = $self->_find_task_by_id($activeMutexes->{$mutex});
		next if ($owner == undef);
		assert($self->{activeTasks}->has($owner));
	}

	my $tasksByName = $self->{tasksByName};
	foreach my $value (values %{$tasksByName}) {
		assert(defined $value);
		assert($value > 0);
	}
}

##
# void $TaskManager->iterate()
#
# Reschedule tasks if necessary, and run one iteration of every active task.
#
sub iterate {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	$self->checkValidity() if DEBUG;
	$self->reschedule() if ($self->{shouldReschedule});
	$self->checkValidity() if DEBUG;

	my $activeTasks = \%{$self->{activeTasks}};
	my $activeMutexes = $self->{activeMutexes};
	for (my $i = 0; $i < @{$activeTasks}; $i++) {
		my $task = $activeTasks->get($i);
		my $status = $task->getStatus();
		if ($status != AI::Task::STOPPED) {
			$task->iterate();
			$status = $task->getStatus();
		}

		# Remove tasks that are stopped or done.
		$status = $task->getStatus();
		if ($status == AI::Task::DONE || $status == AI::Task::STOPPED) {
			$self->deactivateTask($activeTasks, \%{$self->{inactiveTasks}},
				$self->{grayTasks}, $activeMutexes, $self->{tasksByName},
				$task);

			# Remove the callbacks that we registered in this task.
			my $IDs = $self->{events}{$task->{T_ID}};
			$task->onMutexesChanged->remove($IDs->[0]);
			$task->onStop->remove($IDs->[1]);

			# free taken task ID
			$self->_free_id($task->{T_ID});

			$i--;
			$self->{shouldReschedule} = 1;
		}
	}
	$self->checkValidity() if DEBUG;
}

##
# void $Taskmanager->stopAll()
#
# Tell all tasks (whether active or inactive) to stop.
#
sub stopAll {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	foreach my $task (@{\%{$self->{activeTasks}}}, @{\%{$self->{inactiveTasks}}}) {
		$task->stop();
		if ($task->getStatus() == AI::Task::STOPPED) {
			$self->{shouldReschedule} = 1;
		}
		# If the task does not stop immediately, then we'll
		# be notified by the onStop event once it's stopped.
	}
}

##
# int $TaskManager->countTasksByName(String name)
# Ensures: result >= 0
#
# Count the number of tasks that have the specified name.
#
sub countTasksByName {
	my ($self, $name) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $result = $self->{tasksByName}{$name};
	$result = 0 if (!defined $result);
	return $result;
}

##
# String $TaskManager->activeTasksString()
#
# Returns a string which describes the current active tasks.
#
sub activeTasksString {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	return getTaskSetString(\%{$self->{activeTasks}});
}

##
# String $TaskManager->inactiveTasksString()
#
# Returns a string which describes the currently inactive tasks.
#
sub inactiveTasksString {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	return getTaskSetString(\%{$self->{inactiveTasks}});
}

##
# String $TaskManager->activeMutexesString()
#
# Returns a string which describes the currently active mutexes.
#
sub activeMutexesString {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	my $activeMutexes = $self->{activeMutexes};
	my @entries;
	foreach my $mutex (keys %{$activeMutexes}) {
		my $task = $self->_find_task_by_id($activeMutexes->{$mutex});
		next if ($task == undef);
		push @entries, "$mutex (<- " . $task->getName() . ")";
	}
	return join(', ', sort @entries);
}

sub getTaskSetString {
	my ($set) = @_;

	# MultiThreading Support
	lock ($set) if (is_shared($set));
	my $set = \%{$set} if (is_shared($set)); # Restore Utils::Set overloading, we will use it.

	if (@{$set}) {
		my @names;
		foreach my $task (@{$set}) {
			push @names, $task->getName() . " (" .  $task->getStatus() . ") ";
		}
		return join(', ', @names);
	} else {
		return '-';
	}
}

##
# CallbackList $TaskManager->onTaskFinished()
#
# This event is triggered when a task is finished, either successfully
# or with an error.
#
# The event argument is a hash containing this item:<br>
# <tt>task</tt> - The task that was finished.
#
sub onTaskFinished {
	return $_[0]->{onTaskFinished};
}


########## Private functions and callback handlers ##########


sub onMutexesChanged {
	my ($self, $task) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));
	lock ($task) if (is_shared($task));

	if ($task->getStatus() == AI::Task::RUNNING) {
		$self->{grayTasks}->add($task);

		# Release its mutex locks.
		my $activeMutexes = $self->{activeMutexes};
		foreach my $mutex (keys %{$activeMutexes}) {
			if ($activeMutexes->{$mutex} == $task->{T_ID}) {
				delete $activeMutexes->{$mutex};
			}
		}
	}
	$self->{shouldReschedule} = 1;
}

sub onStop {
	my ($self, $task) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));
	lock ($task) if (is_shared($task));

	if ($self->{inactiveTasks}->has($task)) {
		$self->{shouldReschedule} = 1;
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
	my ($self, $task, $mutexTaskMapper, $mutexes) = @_;

	# MultiThreading Support
	lock ($task) if (is_shared($task));

	my $priority = $task->getPriority();
	my $result = 1;
	for (my $i = 0; $i < @{$mutexes} && $result; $i++) {
		my $task2 = $self->_find_task_by_id($mutexTaskMapper->{$mutexes->[$i]});
		next if ($task2 == undef);
		$result = $result && $priority > $task2->getPriority();
	}
	return $result;
}

# Deactivate an active task by removing it from the active task list
# and the gray list, and removing its mutex locks. If the task isn't
# completed or stopped, then it will be added to the inactive task list.
sub deactivateTask {
	my ($self, $activeTasks, $inactiveTasks, $grayTasks, $activeMutexes, $tasksByName, $task) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));
	lock ($activeTasks) if (is_shared($activeTasks));
	lock ($inactiveTasks) if (is_shared($inactiveTasks));
	lock ($grayTasks) if (is_shared($grayTasks));
	lock ($activeMutexes) if (is_shared($activeMutexes));
	lock ($tasksByName) if (is_shared($tasksByName));
	lock ($task) if (is_shared($task));

	my $status = $task->getStatus();
	if ($status != AI::Task::DONE && $status != AI::Task::STOPPED) {
		$inactiveTasks->add($task);
	} else {
		my $name = $task->getName();
		$tasksByName->{$name}--;
		assert($tasksByName->{$name} >= 0) if DEBUG;
		if ($tasksByName->{$name} == 0) {
			delete $tasksByName->{$name};
		}

		$self->{onTaskFinished}->call($self, { task => \%{$task} });
	}
	$activeTasks->remove($task);
	$grayTasks->remove($task);
	foreach my $mutex (@{$task->getMutexes()}) {
		if ($activeMutexes->{$mutex} == $task->{T_ID}) {
			delete $activeMutexes->{$mutex};
		}
	}
}

# generate new task ID
sub _gen_id {
	my ($self) = @_;

	# MultiThreading Support
	lock ($self) if (is_shared($self));

	# Return Free task ID, so we do not overload "$self->{lastID}"
	my $id = shift @{$self->{freeIDs}};
	return $id if (defined $id);

	$self->{lastID} = $self->{lastID} + 1;
	return $self->{lastID};
}

# free allready taken task ID
# Note: this will not destroy task object
sub _free_id {
	my ($self, $id) = @_;
	
	# MultiThreading Support
	lock ($self) if (is_shared($self));
	
	push @{$self->{freeIDs}}, $id;
}

sub _find_task_by_id {
	my ($self, $id) = @_;
	
	# MultiThreading Support
	lock ($self) if (is_shared($self));
	
	foreach my $task (@{\%{$self->{activeTasks}}}, @{\%{$self->{inactiveTasks}}}, @{\%{$self->{grayTasks}}}) {
		return $task if ($task->{T_ID} == $id);
	}
	return undef;
}

# sub printTaskSet {
# 	my ($set, $name) = @_;
# 	my @names;
# 	foreach my $task (@{$set}) {
# 		push @names, $task->getName();
# 	}
# 	print "$name = " . join(',', @names) . "\n";
# }
# 
# sub printActiveMutexes {
# 	my ($activeMutexes) = @_;
# 	my @entries;
# 	foreach my $mutex (keys %{$activeMutexes}) {
# 		push @entries, "$mutex (owned by " . $activeMutexes->{$mutex}->getName . ")";
# 	}
# 	print "Active mutexes: " . join(', ', @entries) . "\n";
# }

1;
