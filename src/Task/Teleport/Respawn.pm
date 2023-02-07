##
# MODULE DESCRIPTION: Respawn teleport task.
package Task::Teleport::Respawn;

use strict;

use Modules 'register';
use base 'Task::Teleport';
use Globals qw($char %config $accountID %timeout);
use Log qw(debug);

sub hookArgs {
	{level => 2, emergency => $_[0]{emergency}}
}

sub chatCommand {
	return undef if ($char->{muted});
	return $config{saveMap_warpChatCommand};
}

# use nameID, names can be different for different servers
sub getInventoryItem {
	my $item;
	if ($config{teleportAuto_item2}) {
		$item = $char->inventory->getByName($config{teleportAuto_item2});
		$item = $char->inventory->getByNameID($config{teleportAuto_item2}) if (!($item) && $config{teleportAuto_item2} =~ /^\d{3,}$/);
	}
	$item = $char->inventory->getByNameID(12324) unless $item; # Novice Butterfly Wing
	$item = $char->inventory->getByNameID(602) unless $item; # Butterfly Wing
	return $item;
 }

# return 0 if char is muted or dont have skill teleport at lv 2
# return 1 if char have skill teleport at lv 2
sub canUseSkill {
	return 0 if ($char->{muted});
	return ($char->{skills}{AL_TELEPORT}{lv} == 2) ? 1 : 0;
}

sub isEquipNeededToTeleport {
	return 0 if $config{'teleportAuto_useItemForRespawn'};
	return Actor::Item::scanConfigAndCheck('teleportAuto_equip');
}

sub useSkill {
	# We have the teleport skill, and should use it
	my $skill = new Skill(handle => 'AL_TELEPORT');
	if (defined AI::findAction('attack')) {
		AI::clear("attack");
		$char->sendAttackStop;
	}

	debug "Teleport - Sending Teleport using Level 2\n", "task_teleport";
	main::ai_skillUse($skill->getHandle(), 2, 0, 0, $accountID);
	$timeout{ai_teleport}{time} = time;

	# add hook when receive list?
	# $messageSender->sendWarpTele(26, "Respawn");
}

sub useEquip {
	my ($self) = @_;
	Actor::Item::scanConfigAndEquip('teleportAuto_equip');
	$self->{retry}{time} = time;
}

sub error {
	my ($self) = @_;
	$self->setError("You don't have the Teleport skill or a Butterfly Wing");
}

1;
