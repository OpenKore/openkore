#########################################################################
#  OpenKore - AI framework
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
# MODULE DESCRIPTION: AI Module Manager.
#
package AI::AImoduleManager;

use strict;
use Carp::Assert;
use Modules 'register';
use AI::AImodule;
use Utils::Set;
use Utils::CallbackList;

####################################
### CATEGORY: Constructor
####################################

##
# AI::AImoduleManager->new()
#
# Create a new AI::AImoduleManager.
sub new {
	my ($class) = @_;
	my %self = (
		# Set<AI::AImodule>
		# Indexed set of currently active modules.
		activeModules => new Set(),

		# Array of IDs, that show in witch order to check AI::AIModules
		modules_list => [],

		# Whatever there is active AI module with exlusive marker.
		# If it's not -1, then it's module ID running Exclusive Task.
		activeExlusiveTask => -1,

		# Last generated ID.
		lastID => 0
	);
	return bless \%self, $class;
}

####################################
### CATEGORY: Destructor
###################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

#####################################
### CATEGORY: Public
#####################################

##
# int $AImoduleManager->add(AI::AImodule module)
#
# Add a new AI module to this AI module manager.
sub add {
	my ($self, $module) = @_;
	assert(defined $module) if DEBUG;

	lock ($self) if (is_shared($self));
	lock ($module) if (is_shared($module));

	# Avoid adding allready existing module phase 1
	if ($self->{activeModules}->has($module)) {
		return 0;
	};


	# Avoid adding allready existing module phase 2
	if ($module->{T_ID} > 0) {
		# We do not allow adding allready added modules
		return 0;
	}

	# Generate module ID.
	my $module_id = $self->_gen_id();
	$module->{T_ID} = $module_id;

	# Add our Event handler, to controll AI modules workflow.
	$module->onStop->add($self, \&onTaskFinished, $module->{T_ID});

	# Add module to Set
	$self->{activeModules}->add($module);
	
	# Calculate Priorities, and Order all modules
	$self->_calc_priority();

	# Return module ID
	return $module_id;
}

##
# bool $AImoduleManager->delete(int ID)
#
# Remove AI module from AI module manager Modules List by givven ID.
sub remove {
	my ($self, $id) = @_;
	assert(defined $id) if DEBUG;

	lock ($self) if (is_shared($self));

	# ToDo
	# check if that module have active Task's
	# check if that module has Exclusive Task running

	if ($id > 0) {
		foreach my $module (@{$self->{activeModules}}) {
	     		if ($module->getID() == $id) {
				# Check if given module has non finished tasks
				if ($self->_check_module($id) > 0) {
					return 0;
				};
				
				# Remove module from Set.
				$self->{activeModules}->remove($module);
	
				# Calculate Priorities, and Order all modules.
				$self->_calc_priority();

				# Return
				if ($self->{working} != 1) {
					return 1;
				};
			};
		};
	};

	# Callers should take actions, if we return 0.
	return 0;
}

##
# bool $AImoduleManager->has(int ID)
#
# Return 1, if we have that module inside out Set.
sub has {
	my ($self, $id) = @_;
	assert(defined $id) if DEBUG;

	foreach my $module (@{$self->{activeModules}}) {
     		if ($module->getID() == $id) {
			return 1;
		};
	};
	return 0;
}

##
# void $AImoduleManager->iterate() 
#
# Check all AI::AImodule for spawning Tasks.
# If AI::AImodule with Exclusive marker spawn a task
# it will stop checking other module's until module with
# that marker, tell that it's finished.
sub iterate {
	my ($self, $module) = @_;
	assert(defined $module) if DEBUG;

	# We have Exclusive Task, So just check it
	if ($self->{activeExlusiveTask} > -1) {
		my $id = $self->{activeExlusiveTask};
		# Check if we Really have it
		if ($self->has($id) > 0) {
			# Just whait to finish that module tasks.
			return;
		} else {
			# ToDo
			# Trow Error
		};
	};

	# Check every module, until all modules are checked,
	# or module with exclusive morker will popup.
	foreach my $id ($self->{modules_list}) {
		if ($self->_run_module($id) > 0) {
			if ($self->{activeExlusiveTask} == $id) {
				return;
			};
		};
	};
}

#####################################
### CATEGORY: Private
#####################################

# calculate witch module to check
# store their id's inside $self->{modules_list}
# block any module remove attemt
sub _calc_priority {
	my ($self) = @_;


	# ToDo
}

# generate new module ID
sub _gen_id {
	my ($self) = @_;
	$self->{lastID} = $self->{lastID} + 1;
	return $self->{lastID};
}

# run module by given id
sub _run_module {
	my ($self, $id) = @_;

	foreach my $module (@{$self->{activeModules}}) {
     		if ($module->getID() == $id) {
			$module->check();
			
			my $task = $module->get_task();
			if (defined $task) {
				$module->{T_task_count}++;

				# Add our Event handler, to controll AI modules workflow.
				$task->onStop->add($self, \&onTaskFinished, $module->{T_ID});

				if ($module->getExclusive() == AI::AIModule::EXCLUSIVE) {
					$self->{activeExlusiveTask} = $module->{T_ID};
				};

				# ToDo
				# Actually add task to TaskManager
				# $AI->{task_mgr}->add($task);

				# Return 1 becouse that module is running. Weeee!!!
				return 1;
			};
			return 0;
		};
	};
	return 0;
}

# check if module with given ID is still working
# return 1 if tasks spawned by module with given ID are still working.
sub _check_module {
	my ($self, $id) = @_;

	foreach my $module (@{$self->{activeModules}}) {
     		if ($module->getID() == $id) {
			if ($module->{T_task_count} > 0) {
				return 1;
			} else {
				return 0;
			};
		};
	};
	return 0;
}

#####################################
### CATEGORY: Events
#####################################

##
# void $AImoduleManager->onTaskFinished()
#
# This event is triggered when a task spawned by AI module is finished, either successfully
# or with an error.
sub onTaskFinished {
	my ($self, $id) = @_;
	foreach my $module (@{$self->{activeModules}}) {
     		if ($module->getID() == $id) {
			# Adjust module Tasks counter
			$module->{T_task_count}--;
			if ($module->{T_task_count} < 0) $module->{T_task_count} = 0;

			# Adjust Exclusive task marker
			if ($self->{activeExlusiveTask} == $id) {
				if ($module->{T_task_count} <= 0) {
					$self->{activeExlusiveTask} = -1;
				};
			};
			# Do not waste CPU time.
			return;
		};
	};
}


