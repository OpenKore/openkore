##
# MODULE DESCRIPTION: Teleporting task.
#
# Base class for teleporting tasks.
package Task::Teleport;

use strict;
use Carp::Assert;
use Time::HiRes qw(time);

use Modules 'register';
use base 'Task::WithSubtask'; # TODO equipping
use Globals qw($messageSender $net %timeout);
use Log qw(debug);
use Misc qw(sendMessage);
use Translation qw(T TF);
use Utils qw(timeOut);

use constant MUTEXES => ['teleport']; # allow only one active teleport task

##
# Task::Teleport->new(options...)
#
# Create a new Task::Teleport object.
# Only Task::Teleport::Random and Task::Teleport::Respawn instances should be created with this method.
sub new {
	my ($class, %args) = @_;
	
	debug "Initializing $class\n", __PACKAGE__, 2 if DEBUG;
	
	my $self = $class->SUPER::new(%args, autostop => 1, autofail => 1, mutexes => MUTEXES);
	
	$self->{emergency} = $args{emergency};
	$self->{retry}{timeout} = $args{retryTime} || $timeout{ai_teleport_retry}{timeout} || 0.5;
	$self->{giveup}{timeout} = $args{giveupTime} || 3;
	
	Scalar::Util::weaken(my $weak = $self);
	$self->{hooks} = Plugins::addHooks(
		['Network::Receive::map_changed' => sub { $weak->{mapChanged} = 1 }],
	);
	
	$self
}

# TODO srsly refactor time adjustment out of all tasks
sub activate {
	my ($self) = @_;
	$self->SUPER::activate;
	
	$self->{giveup}{time} = time;
}

sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt;
	
	$self->{interruptionTime} = time;
}

sub resume {
	my ($self) = @_;
	$self->SUPER::resume;
	
	$self->{giveup}{time} += time - $self->{interruptionTime};
}

sub iterate {
	my ($self) = @_;
	
	return unless $self->SUPER::iterate;
	return unless $net->getState == Network::IN_GAME;
	
	if ($self->{mapChanged}) {
		# TODO respawn task may be not done, if a regular mapchange was occurred
		debug "Map change occurred, marking teleport as done\n", __PACKAGE__, 2 if DEBUG;
		$self->setDone;
		
	} elsif (timeOut($self->{giveup})) {
		debug "Teleport $self->{actor} - timeout\n", __PACKAGE__, 2 if DEBUG;
		$self->setError(undef, TF("%s tried too long to teleport", $self->{actor}));
		
	} elsif (timeOut($self->{retry})) {
		debug "Teleport $self->{actor} - (re)trying\n", __PACKAGE__, 2 if DEBUG;
		
		if (my $chat_command = $self->chatCommand) {
			debug "Using teleport chat command\n", __PACKAGE__, 2 if DEBUG;
			
			Plugins::callHook(teleport_sent => $self->hookArgs);
			sendMessage($messageSender, c => $chat_command);
			
		} else {
			die 'not implemented';
		}
		
		$self->{retry}{time} = time;
	}
}

1;
