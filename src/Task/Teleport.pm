##
# MODULE DESCRIPTION: Teleporting task.
#
# Base class for teleporting tasks.
package Task::Teleport;

use strict;
use Carp::Assert;
use Time::HiRes qw(time);

use Modules 'register';
use Task::SitStand;
use base 'Task::WithSubtask';
use Globals qw($messageSender $net %timeout);
use Log qw(debug);
use Translation qw(T TF);
use Utils qw(timeOut);

use constant MUTEXES => ['teleport']; # allow only one active teleport task

# Error codes
use enum qw(NO_ITEM_OR_SKILL);

##
# Task::Teleport->new(options...)
#
# Create a new Task::Teleport object.
# Only Task::Teleport::Random and Task::Teleport::Respawn instances should be created with this method.
sub new {
	my ($class, %args) = @_;

	debug "Initializing $class\n", "teleport";

	my $self = $class->SUPER::new(%args, autostop => 1, autofail => 1, mutexes => MUTEXES);

	unless ($args{actor}->isa('Actor')) {
		ArgumentException->throw(error => "Invalid arguments.");
	}

	$self->{actor} = $args{actor};
	$self->{retry}{timeout} = $args{retryTime} || $timeout{ai_teleport_retry}{timeout} || 0.5;
	$self->{giveup}{timeout} = $args{giveupTime} || 3;

	Scalar::Util::weaken(my $weak = $self);
	$self->{hooks} = Plugins::addHooks(
		['packet/map_changed' => sub { $weak->{mapChanged} = 1 }],
		['packet/map_change' => sub { $weak->{mapChanged} = 1 }],
	);

	$self
}

# Overrided method.
sub activate {
	my ($self) = @_;
	$self->SUPER::activate;
	$self->{giveup}{time} = time;
}

# Overrided method.
sub interrupt {
	my ($self) = @_;
	$self->SUPER::interrupt;
	$self->{interruptionTime} = time;
}

# Overrided method.
sub resume {
	my ($self) = @_;
	$self->SUPER::resume;
	$self->{giveup}{time} += time - $self->{interruptionTime};
	$self->{retry}{time} += time - $self->{interruptionTime};
}

sub DESTROY {
	my ($self) = @_;
	Plugins::delHook($self->{hooks}) if $self->{hooks};
}

sub iterate {
	my ($self) = @_;

	return unless $self->SUPER::iterate;
	return unless $net->getState == Network::IN_GAME;

	if ($self->{mapChanged}) {
		# TODO respawn task may be not done, if a regular mapchange was occurred
		debug "Teleport $self->{actor} - Map change occurred, marking teleport as done\n", "teleport";
		$self->setDone;

	} elsif (timeOut($self->{giveup})) {
		debug "Teleport $self->{actor} - timeout\n", "teleport";
		$self->setError(undef, TF("%s tried too long to teleport", $self->{actor}));

	} elsif (timeOut($self->{retry})) {
		debug "Teleport $self->{actor} - (re)trying\n", "teleport";
		if (my $chat_command = $self->chatCommand) { # 1 - try to use chat command
			debug "Teleport $self->{actor} - Using chat command to teleport : $chat_command\n", "teleport";
			Misc::sendMessage($messageSender, "c", $chat_command);
			Plugins::callHook('teleport_sent' => $self->hookArgs);

		} elsif($self->isEquipNeededToTeleport) { # 2 - check if equip is needed to use teleport
			# No skill try to equip a Tele clip or something,
			# if teleportAuto_equip_* is set
			debug "Teleport $self->{actor} - Equipping item to teleport\n", "teleport";
			$self->useEquip;

		} elsif($self->{actor}->{sitting}) { # 3 check if actor is sitting
			my $task = new Task::SitStand(actor => $self->{actor}, mode => 'stand', wait => $timeout{ai_stand_wait}{timeout});
			$self->setSubtask($task);

		} elsif($self->canUseSkill) { # 4 - try to use teleport skill
			debug "Teleport $self->{actor} - Using skill to teleport\n", "teleport";
			$self->useSkill;
			Plugins::callHook('teleport_sent' => $self->hookArgs);

		} elsif(my $item = $self->getInventoryItem) { # 5 - try to use item
			debug "Using item to teleport : $item->{name}\n", "teleport";
			# We have Fly Wing/Butterfly Wing.
			# Don't spam the "use fly wing" packet, or we'll end up using too many wings.
			if (timeOut($timeout{ai_teleport})) {
				$messageSender->sendItemUse($item->{ID}, $self->{actor}->{ID});
				Plugins::callHook('teleport_sent' => $self->hookArgs);
				$timeout{ai_teleport}{time} = time;

			}
		} else { # task failed no method
			debug "Teleport $self->{actor} - can't find method to teleport\n", "teleport";
			$self->error();

		}

		$self->{retry}{time} = time;
	}
}

sub subtaskDone {
	my ($self, $task) = @_;
	my $error = $task->getError();
	if ($error) {
		$self->setError($error->{code}, $error->{message});
	}
}

1;
