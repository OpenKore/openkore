##
# MODULE DESCRIPTION: Random teleport task.
package Task::Teleport::Random;

use strict;

use Modules 'register';
use base 'Task::Teleport';
use Globals qw($char %config $field $accountID %timeout);
use Log qw(debug);

sub hookArgs {
	{level => 1, emergency => $_[0]{emergency}}
}

sub chatCommand {
	return undef if ($char->{muted});
	return ($config{teleportAuto_useChatCommand}) ? $config{teleportAuto_useChatCommand} . " " . $field->baseName : undef;
}

# use nameID, names can be different for different servers
sub getInventoryItem {
	my $item;
	if ($config{teleportAuto_item1}) {
		$item = $char->inventory->getByName($config{teleportAuto_item1});
		$item = $char->inventory->getByNameID($config{teleportAuto_item1}) if (!($item) && $config{teleportAuto_item1} =~ /^\d{3,}$/);
	}
	$item = $char->inventory->getByNameID(23280) unless $item; # Beginner's Fly Wing
	$item = $char->inventory->getByNameID(12323) unless $item; # Novice Fly Wing
	$item = $char->inventory->getByNameID(601) unless $item; # Fly Wing
	return $item;
}

# return 0 if char is muted
# return 1 if char has teleport skill lvl
sub canUseSkill {
	return 0 if ($char->{muted});
	return ($char->{skills}{AL_TELEPORT}{lv}) ? 1 : 0;
}

sub isEquipNeededToTeleport {
	return Actor::Item::scanConfigAndCheck('teleportAuto_equip');
}

sub useSkill {
	# We have the teleport skill, and should use it
	my $skill = new Skill(handle => 'AL_TELEPORT');
	if (defined AI::findAction('attack')) {
		AI::clear("attack");
		$char->sendAttackStop;
	}

	debug "Teleport - Sending Teleport using Level 1\n", "task_teleport";
	main::ai_skillUse($skill->getHandle(), 1, 0, 0, $accountID);
	$timeout{ai_teleport}{time} = time;

	# add hook when receive list?
	# $messageSender->sendWarpTele(26, "Random");

	# if ($use_lvl == 2) {
	#	 # check for possible skill level abuse
	#	 message T("Using Teleport Skill Level 2 though we not have it!\n"), "useTeleport" if ($sk_lvl == 1);

	#	 # If saveMap is not set simply use a wrong .gat.
	#	 # eAthena servers ignore it, but this trick doesn't work
	#	 # on official servers.
	#	 my $telemap = "prontera.gat";
	#	 $telemap = "$config{saveMap}.gat" if ($config{saveMap} ne "");
	#	 Plugins::callHook('teleport_sent', \%args);
	#	 $messageSender->sendWarpTele(26, $telemap);
	#	 return 1;
	# }
}

sub useEquip {
	my ($self) = @_;
	Actor::Item::scanConfigAndEquip('teleportAuto_equip');
	$self->{retry}{time} = time;
}

sub error {
	my ($self) = @_;
	$self->setError("You don't have the Teleport skill or a Fly Wing");
}

1;
