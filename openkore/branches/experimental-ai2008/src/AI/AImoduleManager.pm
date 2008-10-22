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
# MODULE DESCRIPTION: Abstract AI Module base class.
#
# This is the abstract base class for all AI Modules.
#
# <h3>Notes on priority constants</h3>
# The only things you may assume about the values of priority contants are:
# `l
# - Each priority constant differ at least a value of 1 from other priority constants.
# - A higher value means a higher priority.
# `l`

package AI::AImodule;

###################################
### CATEGORY: Status constants
###################################

##
# AIModule::NON_EXCLUSIVE
#
# Indicates that the AIModule must wait before spawning a new task.
use constant NON_EXCLUSIVE    => 0;

##
# AIModule::EXCLUSIVE
#
# Indicates that the AIModule must not wait before spawning a new task, and can be checked every cycle.
use constant EXCLUSIVE    => 0;

####################################
### CATEGORY: Constructor
###################################

##
# AIModule->new(options...)
#
# Create a new AIModule object. The following options are allowed:
# `l
# - <tt>name</tt> - A name for this module. $AIModule->getName() will return this name.
#                   If not specified, the class's name (excluding the "AI::AIModule::" prefix) will be used as name.
# - <tt>priority</tt> - A priority for this module. $AIModule->getPriority() will return this value.
#                       The default priority is Task::NORMAL_PRIORITY
# - <tt>mutex</tt> - A marker, that show whatever module should be blocked before it's task get finished.
# - <tt>mutex</tt> - A reference to an array of mutexes. $AIModule->getMutexes() will return this value.
#                      The default is an empty mutex list.
# `l`
sub new {
	my $class = shift;
	my %args = @_;
	my %self;

	my $allowed = new Set("name", "priority", "mutex", "exclusive");

	foreach my $key (keys %args) {
		if ($allowed->has($key)) {
			$self{"T_$key"} = $args{$key};
		}
	}

	# Set default name, if none specifed.
	if (!defined $self{T_name}) {
		$self{T_name} = $class;
		$self{T_name} =~ s/.*:://;
	}

	# Set default empty mutes, if none specifed.
	$self{T_mutex} = [] if (!defined $self{T_mutex});

	# Set default exclusive marker, if none specifed
	$self{T_exclusive} = NON_EXCLUSIVE if (!defined $self{T_exclusive});

	# Set onTaskFinished empty Callback list.
	$self{T_onTaskFinished} = new CallbackList("onTaskFinished");

	return bless \%self, $class;
}

####################################
### CATEGORY: Destructor
###################################

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

############################
### CATEGORY: Queries
############################

##
# String $AImodule->getName()
# Ensures: $result ne ""
#
# Returns a human-readable name for this task.
sub getName {
	return $_[0]->{T_name};
}

##
# int $AImodule->getPriority()
#
# Get the priority for this AIModule. This priority is guaranteed to never change during a AIModule's
# life time.
sub getPriority {
	return $_[0]->{T_priority};
}

##
# Array<String>* $AImodule->getMutex()
# Ensures: defined(result)
#
# Returns a reference to an array of mutexes for this task. Note that the mutex list may
# change during a AIModule's life time. This list must not be modified outside the Task object.
#
# If you override this method, then you <b>must</b> ensure that when the mutex list changes,
# you trigger a onMutexesChanged event. Otherwise the task manager will not behave correctly.
sub getMutexes {
	return $_[0]->{T_mutex};
}

##
# int $AImodule->getExclusive()
#
# Get the 'exclusive' marker for this AIModule. This priority is guaranteed to never change during a AIModule's
# life time.
sub getExclusive {
	return $_[0]->{T_exclusive};
}

#####################################
### CATEGORY: Events
#####################################

##
# CallbackList $AIModule->onTaskFinished()
#
# This event is triggered when the task's status has been set to Task::STOPPED or Task::DONE.
sub onTaskFinished {
	return $_[0]->{T_onTaskFinished};
}

#####################################
### CATEGORY: Public commands
#####################################

##
# void $AImodule->check()
#
# Run one check for spawning Task. AIModule implementors must override this method to
# implement AIModule code.
sub check {
	
}

##
# void $AImodule->get_task()
#
# Get previously spawned Task by check(). AIModule implementors must override this method to
# implement AIModule code.
sub get_task {

}

