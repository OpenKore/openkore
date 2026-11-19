##
# MODULE DESCRIPTION: Teleporting task.
#
# Base class for teleporting tasks.
package Task::Teleport;

use strict;
use Carp::Assert;
use Time::HiRes qw(time);

use Modules 'register';
use Skill;
use Task::SitStand;
use base 'Task::WithSubtask';
use Globals qw($messageSender $net %timeout %config @ai_seq @ai_seq_args);
use Log qw(debug warning message);
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
	$self->{flee} = $args{flee} ? 1 : 0;
	$self->{retry}{timeout} = $args{retryTime} || $timeout{ai_teleport_retry}{timeout} || 0.5;
	$self->{giveup}{timeout} = $args{giveupTime} || 3;

	Scalar::Util::weaken(my $weak = $self);
	$self->{hooks} = Plugins::addHooks(
		['packet/map_changed' => sub { $weak->{mapChanged} = 1 }],
		['packet/map_change' => sub { $weak->{mapChanged} = 1 }],
		['packet_useitem' => sub { $weak->onItemUseAck(@_) if $weak }],
		['npc_chat' => sub { $weak->onNpcChat(@_) if $weak }],
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
		message T("Danger/flee teleport completed\n"), "teleport" if $self->{flee};
		Plugins::callHook('taskTeleport_mapChanged', { task => $self });
		$self->setDone;

	} elsif (timeOut($self->{giveup})) {
		debug "Teleport $self->{actor} - timeout\n", "teleport";
		$self->setError(undef, TF("%s tried too long to teleport", $self->{actor}));

	} elsif (timeOut($self->{retry})) {
		debug "Teleport $self->{actor} - (re)trying\n", "teleport";
		delete $self->{pendingTeleportSkill};
		delete $self->{pendingTeleportItemMenu};
		my $item = $self->getInventoryItem;
		my $method;

		if (my $chat_command = $self->chatCommand) { # 1 - try to use chat command
			debug "Teleport $self->{actor} - Using chat command to teleport : $chat_command\n", "teleport";
			Misc::sendMessage($messageSender, "c", $chat_command);
			Plugins::callHook('teleport_sent' => $self->hookArgs);

		} elsif (($method = $self->selectTeleportMethod($item)) && $method eq 'equip_skill') {
			# No skill try to equip a Tele clip or something,
			# if teleportAuto_equip_* is set
			debug "Teleport $self->{actor} - Equipping item to teleport\n", "teleport";
			$self->useEquip;

		} elsif (defined($method) && $method eq 'equip_item') {
			debug "Teleport $self->{actor} - Equipping teleport item before use: $item->{name}\n", "teleport";
			$self->equipTeleportItem($item);

		} elsif (defined($method) && $method eq 'wait_item') {
			debug "Teleport $self->{actor} - Teleport item still on cooldown: $item->{name}\n", "teleport";

		} elsif($self->{actor}->{sitting}) { # 4 check if actor is sitting
			my $task = new Task::SitStand(actor => $self->{actor}, mode => 'stand', wait => $timeout{ai_stand_wait}{timeout});
			$self->setSubtask($task);

		} elsif (defined($method) && $method eq 'skill') {
			debug "Teleport $self->{actor} - Using skill to teleport\n", "teleport";
			$self->reportFleeMethod('skill', T("Teleport skill"));
			$self->useSkill;
			Plugins::callHook('teleport_sent' => $self->hookArgs);

		} elsif (defined($method) && $method eq 'item') {
			debug "Using item to teleport : $item->{name}\n", "teleport";
			
			# We have Fly Wing/Butterfly Wing.
			# Don't spam the "use fly wing" packet, or we'll end up using too many wings.
			if (timeOut($timeout{ai_teleport})) {
				$self->reportFleeMethod('item:'.$item->{nameID}, $item->{name});
				$self->{pendingTeleportItemUse} = {
					index => $item->{ID},
					nameID => $item->{nameID},
					name => $item->{name},
					time => time,
				};
				if ($self->{teleportItemRule} && $self->{teleportItemRule}{itemID}) {
					Misc::registerTeleportItemPendingUse($self->{teleportItemRule}{itemID});
				}
				$self->{pendingTeleportItemMenu} = $self->hookArgs->{level} unless $config{noAutoSkill};
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

# Both settings order usable methods; neither removes skill capability.
# Respawn's separate teleportAuto_useItemForRespawn restriction stays in its
# capability checks. Random teleports override this preference for danger.
sub prefersSkill {
	return !defined($config{teleportAuto_useSkill}) || $config{teleportAuto_useSkill} != 0;
}

sub selectTeleportMethod {
	my ($self, $item) = @_;
	my $skill = $self->canUseSkill;
	my $equipSkill = !$skill && $self->isEquipNeededToTeleport;
	my $cooldown = $item && $self->isTeleportItemOnCooldown($item);
	my $readyItem = $item && !$cooldown && $self->isTeleportItemEquipRequirementSatisfied($item);
	my $equipItem = $item && !$cooldown && !$readyItem && $self->canEquipTeleportItem($item);
	# A rejected item gets a skill fallback on the next attempt. If no skill is
	# usable, keep the existing bounded item retries for transient server states.
	my $rejected = $item && $self->{rejectedTeleportItems}{$item->{nameID}};
	my @order = $self->prefersSkill || $rejected
		? qw(skill equip_skill item equip_item) : qw(item equip_item skill equip_skill);
	my %usable = (skill => $skill, equip_skill => $equipSkill, item => $readyItem, equip_item => $equipItem);
	for my $method (@order) {
		return $method if $usable{$method};
	}
	return 'wait_item' if $cooldown;
	return;
}

# Keep normal console output explicit about flee intent and the chosen method.
# Retries using the same method do not repeat this acknowledgement.
sub reportFleeMethod {
	my ($self, $method, $description) = @_;
	return unless $self->{flee};
	return if ($self->{lastReportedFleeMethod} || '') eq $method;
	$self->{lastReportedFleeMethod} = $method;
	message TF("Teleporting to flee danger using %s\n", $description), "teleport";
}

sub queueTeleportSkill {
	my ($self, $level) = @_;
	my $result;
	main::ai_skillUse('AL_TELEPORT', $level, 0, 0, $self->{actor}{ID}, undef, undef, \$result);
	if (AI::is('skill_use') && AI::args()->{ret} && AI::args()->{ret} == \$result) {
		$self->{pendingTeleportSkill} = AI::args();
	}
	$timeout{ai_teleport}{time} = time;
}

sub consumeWarpMenu {
	my ($self) = @_;
	return if $self->{mapChanged};
	my $skill = $self->{pendingTeleportSkill};
	return delete $self->{pendingTeleportItemMenu} unless $skill;
	return unless $skill->{skill_used} && !$skill->{mapChanged};
	return if defined ${$skill->{ret}} && ${$skill->{ret}} ne 'ok';

	delete $self->{pendingTeleportSkill};
	for my $i (0 .. $#ai_seq) {
		next unless AI::action($i) eq 'skill_use' && AI::args($i) == $skill;
		splice(@ai_seq, $i, 1);
		splice(@ai_seq_args, $i, 1);
		last;
	}
	return $skill->{lv};
}

sub canEquipTeleportItem {
	my ($self, $item) = @_;
	return 0 unless $item;
	return 0 unless $item->equippable;
	return 0 unless $item->{type_equip};
	return 0 unless $item->{identified};
	return 1;
}

sub equipTeleportItem {
	my ($self, $item) = @_;
	return unless ($item && $self->canEquipTeleportItem($item));
	$item->equip;
	$self->{retry}{time} = time;
}

sub hasEnoughSPForTeleportSkill {
	my ($self, $skill_level) = @_;
	return 0 unless $skill_level;

	my $skill = Skill->new(handle => 'AL_TELEPORT');
	my $sp_cost = $skill->getSP($skill_level);
	return 1 unless defined $sp_cost;

	return (($self->{actor}{sp} // 0) >= $sp_cost) ? 1 : 0;
}

sub isTeleportSkillSuppressedByStatus {
	my ($self) = @_;
	return 1 if $self->{actor}->{muted};
	return 0 unless $self->{actor}->can('statusActive');
	return $self->{actor}->statusActive('HEALTHSTATE_SILENCE, EFST_HEALTHSTATE_SILENCE') ? 1 : 0;
}

sub isTeleportItemEquipRequirementSatisfied {
	my ($self, $item) = @_;
	return 0 unless $item;
	return 1 unless ($item->equippable && $item->{type_equip});
	return $item->{equipped} ? 1 : 0;
}

sub isTeleportItemOnCooldown {
	my ($self, $item) = @_;
	return 0 unless $item;
	my $entry = $self->{actor}{last_teleport_item_use}{$item->{nameID}};
	return 0 unless (ref($entry) eq 'HASH' && $entry->{timeout});
	return !timeOut($entry->{time}, $entry->{timeout});
}

sub onItemUseAck {
	my ($self, undef, $args) = @_;
	my $pending = $self->{pendingTeleportItemUse} or return;
	return if (!$args || !defined $args->{serverIndex});
	return if ($args->{serverIndex} ne $pending->{index});

	if ($args->{success}) {
		delete $self->{rejectedTeleportItems}{$pending->{nameID}};
		my $timeout = Misc::getTeleportItemCooldownTimeoutSec($pending->{nameID});
		Misc::setTeleportItemCooldownEntry($pending->{nameID}, time, $timeout);
	} else {
		$self->{rejectedTeleportItems}{$pending->{nameID}} = 1;
		debug "Teleport $self->{actor} - Teleport item use failed: $pending->{name}\n", "teleport";
		delete $self->{pendingTeleportItemMenu};
	}
	delete $self->{pendingTeleportItemUse};
}

sub onNpcChat {
	my ($self, undef, $args) = @_;
	my $message = $args->{message} // return;
	my $pending = $self->{pendingTeleportItemUse} || return;
	return unless $message =~ /Item Failed/i;
	return unless $message =~ /\Q[$pending->{name}]\E/i;

	my $seconds;
	if ($message =~ /Wait\s+([0-9]+(?:\.[0-9]+)?)\s*minutes?/i) {
		$seconds = $1 * 60;
	} elsif ($message =~ /Wait\s+([0-9]+(?:\.[0-9]+)?)\s*seconds?/i) {
		$seconds = $1;
	}
	return unless defined $seconds;

	Misc::setTeleportItemCooldownEntry($pending->{nameID}, time, $seconds);
	delete $self->{pendingTeleportItemUse};
	delete $self->{pendingTeleportItemMenu};
}

sub subtaskDone {
	my ($self, $task) = @_;
	my $error = $task->getError();
	if ($error) {
		$self->setError($error->{code}, $error->{message});
	}
}

1;
