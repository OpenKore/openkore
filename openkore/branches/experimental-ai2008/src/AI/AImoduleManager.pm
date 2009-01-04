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

		# Array of IDs, that show with Index from Set correspond to with ID
		# Only recalculated when ActiveModules Set changes
		modules_index_list => {},

		# Whatever there is active AI module with exlusive marker.
		# If it's not -1, then it's module ID.
		activeExlusiveTask => -1,

		# Last generated ID.
		lastID => -1
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

	# ToDo
	# generate new ID
	# avoid duplicating modules

	# Add module to Set
	$self->{activeModules}->add($module);
	
	# Calculate Priorities, and Order all modules
	$self->_calc_priority();
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
	# determinate, witch module has given ID
	# check if that module have active Task's
	# check if that module has Exclusive Task running

	if ($id > 0) {
		foreach my $module (@{$self->{activeModules}}) {
	     		if ($module->getID() == $id) {
				# Remove module from Set.
				$self->{activeModules}->remove($module);
	
				# Calculate Priorities, and Order all modules.
				$self->_calc_priority();

				# Return
				if ($self->{working} != 1) {
					return 1;
				};
			}
		}
	}


	# Only do stuff, if we have that module inside our Set.
	if ($self->has($module)) {
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

	# ToDo

}

#####################################
### CATEGORY: Private
#####################################

# calculate witch module to check
# store their indexes inside $self->{modules_list}
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

# check if module with given ID is still working
sub _check_module {
	my ($self, $id) = @_;
	$self->{lastID} = $self->{lastID} + 1;

	foreach my $module (@{$self->{activeModules}}) {
     		if ($module->getID() == $id) {

			# ToDo
			return 1;
		}
	};
	return 0;
}


#####################################
### CATEGORY: Events
#####################################

##
# CallbackList $AImoduleManager->onTaskFinished()
#
# This event is triggered when a task spawned by AI module is finished, either successfully
# or with an error.
#
# The event argument is a hash containing this item:<br>
# <tt>task</tt> - The task that was finished.
sub onTaskFinished {

}


