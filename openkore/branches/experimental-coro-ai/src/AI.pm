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
# MODULE DESCRIPTION: AI main class.
#
# This is the main class for AI.
# Used for accessing AI modules, Environment Queue and Task Manager.
package AI;

# Make all References Strict
use strict;

# Coro Support
use Coro;

# Others (Perl Related)
use warnings;
no warnings 'redefine';
use FindBin qw($RealBin);
use Time::HiRes qw(time);
use Scalar::Util qw(reftype refaddr blessed); 

# Others (Kore related)
use Modules 'register';
use Globals qw($quit);
use AI::AImoduleManager;
use AI::EnvironmentQueue;
use AI::TaskManager;
use Log qw(debug);
# use Utils::Set;
# use Utils::CallbackList;

###################################
### CATEGORY: Block flag constants
###################################

# defining constants
use constant {
	STATE_OFF	=> 0,
	STATE_TASK	=> 1,
	STATE_ON	=> 2,
};

use constant STATES	=> ["OFF", "TASK", "ON"];

####################################
### CATEGORY: Constructor
###################################

##
# AI->new()
#
# Create a new AI main object.
sub new {
	my $class = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;

	# Warning!!!!
	# Do not use Internal Values in other packages!
	$self->{state} = AI::STATE_OFF; # By default, AI is Disabled!
	$self->{module_manager} = AI::AImoduleManager->new();
	$self->{environment_queue} = AI::EnvironmentQueue->new();
	$self->{task_manager} = AI::TaskManager->new();

	return $self;
}

####################################
### CATEGORY: Destructor
###################################

sub DESTROY {
	my ($self) = @_;
	if ($self->can("SUPER::DESTROY")) {
		debug "Destroying an instance of class: ".__PACKAGE__."!\n";
		$self->SUPER::DESTROY;
	}
}

####################################
### CATEGORY: Public
####################################

##
# void $AI->mainLoop()
#
# Enter the AI main loop.
sub mainLoop {
	my $self = shift;
	while (!$quit) {
		$self->{module_manager}->iterate() if ($self->{state} > AI::STATE_TASK);
		$self->{environment_queue}->iterate();
		$self->{task_manager}->iterate() if ($self->{state}  > AI::STATE_OFF);
		cede;
	}
}

##
# void $AI->SetState(int State)
#
# Set AI State.
# AI::STATE_ON		Fully Active AI
# AI::STATE_TASK		Disable All AI Brain power (all AI Modules)
# AI::STATE_OFF		Fully Disabled AI
sub SetState {
	my ($self, $state) = @_;
	return if (($state > AI::STATE_ON)||($state < AI::STATE_OFF));
	
	# If Fully Disable AI, then All tasks get killed.
	if ($state == AI::STATE_OFF) {
		$self->{task_manager}->stopAll();
	};
	$self->{state} = $state;
}

##
# int $AI->GetState()
#
# Get AI State.
sub GetState {
	my $self = shift;
	return $self->{state};
}
####################################
### CATEGORY: Public (AI::AIModuleManager API)
####################################

##
# int $AI->AImodule_add(AI::AImodule module)
#
# Add a new AI module to this AI module manager.
sub AImodule_add {
	my $self = shift;
	return $self->{module_manager}->add(@_);
}

##
# bool $AI->AImodule_remove(int ID)
#
# Remove AI module from AI module manager Modules List by given ID.
sub AImodule_remove {
	my $self = shift;
	return $self->{module_manager}->remove(@_);
}

##
# bool $AI->AImodule_has(int ID)
#
# Return 1, if we have that module inside our Set.
sub AImodule_has {
	my $self = shift;
	return $self->{module_manager}->has(@_);
}

##
# void $AI->AImodule_postpone(String mutex, int timeout)
#
# Postpone modules with given mutex name for some time
# If timeout == 0 then that mutex will be permanently postponed 
sub AImodule_postpone {
	my $self = shift;
	$self->{module_manager}->postpone(@_);
}

####################################
### CATEGORY: Public (AI::Environment API)
####################################

##
# void $AI->AIenvironment_queue_add(String name, Hash* params)
#
# Add some structure to Queue.
sub AIenvironment_queue_add {
	my $self = shift;
	$self->{environment_queue}->queue_add(@_);
}

##
# int $AI->AIenvironment_register_listener(String name, listener_sub, Hash* listener_self, [Hash params, ...])
# Return: listener ID.
#
# Register new Environment Listener object.
#
# Example:
# my $ID = $AI->AIenvironment_register_listener("my_listener", \&my_callback, \$self, $params);
sub AIenvironment_register_listener {
	my $self = shift;
	return $self->{environment_queue}->register_listener(@_);
}

##
# void $AI->AIenvironment_unregister_listener(String name, int ID)
#
# UnRegister Listener Object by given name and ID.
sub AIenvironment_unregister_listener {
	my $self = shift;
	$self->{environment_queue}->unregister_listener(@_);
}

##
# int $AI->AIenvironment_register_event(String name, Hash* rules, event_sub, Hash* event_self, [Hash params, ...])
# Return: event ID
#
# Register Smart Event Object.
sub AIenvironment_register_event {
	my $self = shift;
	return $self->{environment_queue}->register_event(@_);
}

##
# void $AI->AIenvironment_unregister_event(int ID)
#
# UnRegister Smart Event Object by given ID.
sub AIenvironment_unregister_event {
	my $self = shift;
	$self->{environment_queue}->unregister_event(@_);
}

####################################
### CATEGORY: Public (AI::TaskManager API)
####################################

##
# void $AI->TaskManager_add(AI::Task task)
# Requires: $task->getStatus() == AI::Task::INACTIVE
#
# Add a new task to this task manager.
sub TaskManager_add {
	my $self = shift;
	$self->{task_manager}->add(@_);
}

##
# void $AI->TaskManager_stopAll()
#
# Tell all tasks (whether active or inactive) to stop.
sub TaskManager_stopAll {
	my $self = shift;
	$self->{task_manager}->stopAll();
}

##
# int $AI->TaskManager_countTasksByName(String name)
# Ensures: result >= 0
#
# Count the number of tasks that have the specified name.
sub TaskManager_countTasksByName {
	my $self = shift;
	return $self->{task_manager}->countTasksByName(@_);
}

##
# String $AI->TaskManager_activeTasksString()
#
# Returns a string which describes the current active tasks.
sub TaskManager_activeTasksString {
	my $self = shift;
	return $self->{task_manager}->activeTasksString();
}

##
# String $AI->TaskManager_inactiveTasksString()
#
# Returns a string which describes the currently inactive tasks.
sub TaskManager_inactiveTasksString {
	my $self = shift;
	return $self->{task_manager}->inactiveTasksString();
}

##
# String $AI->TaskManager_activeMutexesString()
#
# Returns a string which describes the currently active Task mutexes.
sub TaskManager_activeMutexesString {
	my $self = shift;
	return $self->{task_manager}->activeMutexesString();
}

1;
