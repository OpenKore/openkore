##
# MODULE DESCRIPTION: Respawn teleport task.
package Task::Teleport::Respawn;

use strict;

use Modules 'register';
use base 'Task::Teleport';
use Globals qw(%config %timeout);
use Translation qw(T TF);
use Log qw(debug);

sub hookArgs {
	{level => 2}
}

sub chatCommand {
	my ($self) =  @_;
	return undef if ($self->{actor}->{muted});
	return $config{saveMap_warpChatCommand};
}

# use nameID, names can be different for different servers
sub getInventoryItem {
	my ($self) =  @_;
	return undef unless ($self->{actor}->inventory->isReady());

	my $item;
	if ($config{teleportAuto_item2}) {
		$item = $self->{actor}->inventory->getByName($config{teleportAuto_item2});
		$item = $self->{actor}->inventory->getByNameID($config{teleportAuto_item2}) if (!($item) && $config{teleportAuto_item2} =~ /^\d{3,}$/);
	}
	$item = $self->{actor}->inventory->getByNameID(12324) unless $item; # Novice Butterfly Wing
	$item = $self->{actor}->inventory->getByNameID(602) unless $item; # Butterfly Wing
	return $item;
 }

# return 0 if char is muted or dont have skill teleport at lv 2
# return 1 if char have skill teleport at lv 2
sub canUseSkill {
	my ($self) =  @_;
	return 0 if ($self->{actor}->{muted});
	return 0 if $config{'teleportAuto_useItemForRespawn'};
	return ($self->{actor}->getSkillLevel(new Skill(handle => 'AL_TELEPORT')) == 2) ? 1 : 0;
}

# return the number of items necessary to teleport
sub isEquipNeededToTeleport {
	my ($self) =  @_;
	return 0 unless ($self->{actor}->inventory->isReady());
	return 0 if $config{'teleportAuto_useItemForRespawn'};
	return Actor::Item::scanConfigAndCheck('teleportAuto_equip');
}

sub useSkill {
	my ($self) =  @_;
	# We have the teleport skill, and should use it
	my $skill = new Skill(handle => 'AL_TELEPORT');

	debug "Teleport $self->{actor} - Sending Teleport using Level 2\n", "teleport";
	main::ai_skillUse($skill->getHandle(), 2, 0, 0, $self->{actor}->{ID});
	$timeout{ai_teleport}{time} = time;
}

sub useEquip {
	my ($self) = @_;
	Actor::Item::scanConfigAndEquip('teleportAuto_equip');
	$self->{retry}{time} = time;
}

sub error {
	my ($self) = @_;
	$self->setError(Task::Teleport::NO_ITEM_OR_SKILL, TF("%s don't have the Teleport skill or a Butterfly Wing", $self->{actor}));
}

1;
