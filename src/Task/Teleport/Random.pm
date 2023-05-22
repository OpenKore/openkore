##
# MODULE DESCRIPTION: Random teleport task.
package Task::Teleport::Random;

use strict;

use Modules 'register';
use base 'Task::Teleport';
use Globals qw(%config $field %timeout);
use Translation qw(T TF);
use Log qw(debug);

sub hookArgs {
	{level => 1}
}

sub chatCommand {
	my ($self) =  @_;
	return undef if ($self->{actor}->{muted});
	return ($config{teleportAuto_useChatCommand}) ? $config{teleportAuto_useChatCommand} . " " . $field->baseName : undef;
}

# use nameID, names can be different for different servers
sub getInventoryItem {
	my ($self) =  @_;
	return undef unless ($self->{actor}->inventory->isReady());

	my $item;
	if ($config{teleportAuto_item1}) {
		$item = $self->{actor}->inventory->getByName($config{teleportAuto_item1});
		$item = $self->{actor}->inventory->getByNameID($config{teleportAuto_item1}) if (!($item) && $config{teleportAuto_item1} =~ /^\d{3,}$/);
	}
	$item = $self->{actor}->inventory->getByNameID(23280) unless $item; # Beginner's Fly Wing
	$item = $self->{actor}->inventory->getByNameID(12323) unless $item; # Novice Fly Wing
	$item = $self->{actor}->inventory->getByNameID(601) unless $item; # Fly Wing
	return $item;
}

# return 0 if actor is muted or dont have skill teleport at lv
# return 1 if actor has teleport skill lvl
sub canUseSkill {
	my ($self) =  @_;
	return 0 if ($self->{actor}->{muted});
	return $self->{actor}->getSkillLevel(new Skill(handle => 'AL_TELEPORT')) ? 1 : 0;
}

# return the number of items necessary to teleport
sub isEquipNeededToTeleport {
	my ($self) =  @_;
	return 0 unless ($self->{actor}->inventory->isReady());
	return Actor::Item::scanConfigAndCheck('teleportAuto_equip');
}

sub useSkill {
	my ($self) =  @_;
	# We have the teleport skill, and should use it
	my $skill = new Skill(handle => 'AL_TELEPORT');

	debug "Teleport $self->{actor} - Sending Teleport using Level 1\n", "teleport";
	main::ai_skillUse($skill->getHandle(), 1, 0, 0, $self->{actor}->{ID});
	$timeout{ai_teleport}{time} = time;

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
	$self->setError(Task::Teleport::NO_ITEM_OR_SKILL, TF("%s don't have the Teleport skill or a Fly Wing", $self->{actor}));
}

1;
