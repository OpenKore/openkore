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
use Globals qw($messageSender $net %timeout $char);
use Log qw(debug);
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

	debug "Initializing $class\n", "task_teleport";

	my $self = $class->SUPER::new(%args, autostop => 1, autofail => 1, mutexes => MUTEXES);

	$self->{emergency} = $args{emergency};
	$self->{retry}{timeout} = $args{retryTime} || $timeout{ai_teleport_retry}{timeout} || 0.5;
	$self->{giveup}{timeout} = $args{giveupTime} || 3;

	Scalar::Util::weaken(my $weak = $self);
	$self->{hooks} = Plugins::addHooks(
		['packet/map_changed' => sub { $weak->{mapChanged} = 1 }],
        ['packet/map_change' => sub { $weak->{mapChanged} = 1 }],
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
		debug "Teleport - Map change occurred, marking teleport as done\n", "task_teleport";
		$self->setDone;

	} elsif (timeOut($self->{retry}) && !$char->inventory->isReady()) {
        # Inventory is not ready, can't search for items to teleport
        debug "Teleport - Inventory is not ready \n", "task_teleport";
        $self->{retry}{time} = time;

    } elsif (timeOut($self->{giveup})) {
		debug "Teleport - timeout\n", "task_teleport";
		$self->setError(undef, TF("%s tried too long to teleport", $char));

	} elsif (timeOut($self->{retry})) {
        debug "Teleport - (re)trying\n", "task_teleport";
        if (my $chat_command = $self->chatCommand) { # 1 - try to use chat command
			debug "Teleport - Using chat command to teleport : $chat_command\n", "task_teleport";

			Misc::sendMessage($messageSender, "c", $chat_command);
			Plugins::callHook('teleport_sent' => $self->hookArgs);

		} elsif($self->isEquipNeededToTeleport) { # 2 - check if equip is needed to use teleport
            # No skill try to equip a Tele clip or something,
            # if teleportAuto_equip_* is set
            debug "Teleport - Equipping item to teleport\n", "task_teleport";
            $self->useEquip;
			Plugins::callHook('teleport_sent' => $self->hookArgs);

        } elsif($self->canUseSkill) { # 3 - try to use teleport skill
            debug "Teleport - Using skill to teleport\n", "task_teleport";
            $self->useSkill;
			Plugins::callHook('teleport_sent' => $self->hookArgs);

        } elsif(my $item = $self->getInventoryItem) { # 4 - try to use item
            debug "Using item to teleport : $item->{name}\n", "task_teleport";
            # We have Fly Wing/Butterfly Wing.
            # Don't spam the "use fly wing" packet, or we'll end up using too many wings.
            if (timeOut($timeout{ai_teleport})) {
                $messageSender->sendItemUse($item->{ID}, $self->{actor}->{ID});
                Plugins::callHook('teleport_sent' => $self->hookArgs);
                $timeout{ai_teleport}{time} = time;

            }
	    } else { # task failed no method
            debug "Teleport - can't find method to teleport\n", "task_teleport";
			$self->error();

		}

		$self->{retry}{time} = time;
	}
}

1;
