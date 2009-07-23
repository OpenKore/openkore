package Commands::AI;

use strict;

use threads;
use threads::shared;

use Utils::Exceptions;
use Commands;
use base qw(Commands);
use Log qw(debug error message warning);
use Translation qw(T TF);
use AI;
use AI::Task;
use AI::Task::Wait;
use Globals qw($AI);
use Switch;

sub new {
	my $class = shift;
	my $cmd = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;
	
	# register commands
	my $ID = $cmd->register(
		["ai", "Sets AI state.", \&cmdAI, $self],
		["wait", "wait task", \&cmdWait, $self],
		["task", "task status", \&cmdTask, $self],
	);

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	debug "Destroying: ".__PACKAGE__."!\n";
	$self->SUPER::DESTROY();
}

#######################################
#######################################
### COMMAND CATEGORY: AI
#######################################
#######################################

# arg 1: command class (ex. Commands::AI), arg2: command name (ex. ai), arg3: command arguments
sub cmdAI {
	my (undef, undef, $arg) = @_;
	# arg: on|ON|task|TASK|off|OFF|state|STATE
	my %S2N =("OFF"	=> AI::STATE_OFF,
			  "TASK"=> AI::STATE_TASK,
			  "ON"	=> AI::STATE_ON);

	switch (uc $arg) {
		case "STATE"								{ message TF("AI state is: %s\n", (AI::STATES)->[$AI->AI::GetState()]) }
		case ((AI::STATES)->[$AI->AI::GetState()])	{ message TF("AI state is already: %s\n", (AI::STATES)->[$AI->AI::GetState()]) }
		case ((AI::STATES))							{ message TF("AI state is now: %s\n", (AI::STATES)->[$S2N{uc $arg}]);
													  $AI->AI::SetState($S2N{uc $arg}) }
		else 										{ error T("Syntax Error in command parameters for command 'ai'\n" .
															  "Usage: ai [state|on|task|off]\n") }
	}
}

# for testing purposes only
sub cmdWait {
	my (undef, undef, $arg) = @_;
	my $task = new AI::Task::Wait(seconds => $arg, inGame => 0);
	$AI->TaskManager_add($task);
	message "AI::Task::Wait initiated: seconds: $arg seconds.\n";
}

sub cmdTask {
	my (undef) = @_;
	#message ("Total Tasks: %s\n", (defined $AI->TaskManager_countTasksByName()) ? $AI->TaskManager_countTasksByName() : ''), "info";
	my $active_tasks = $AI->TaskManager_activeTasksString();
	my $inactive_tasks = $AI->TaskManager_inactiveTasksString();
	my $active_mutexes = $AI->TaskManager_activeMutexesString();
	message TF("Active Tasks: %s\n", (defined $active_tasks) ? $active_tasks : ''), "info";
	message TF("Inactive Tasks: %s\n", (defined $inactive_tasks) ? $inactive_tasks : ''), "info";
	message TF("Active Mutexes (Task): %s\n", (defined $active_mutexes) ? $active_mutexes : ''), "info";
}

1;