package TeleportFallbackTest;

use strict;

use FindBin qw($RealBin);
use Test::More;
use Globals;
use Misc;
use Skill;
use Actor::You;
use Actor::Item;
use Task::Teleport::Random;
use Task::Teleport::Respawn;

sub start {
	note('Starting ' . __PACKAGE__);
	Skill::StaticInfo::parseSkillsDatabase_id2handle("$RealBin/../../tables/SKILL_id_handle.txt");
	Skill::StaticInfo::parseSkillsDatabase_handle2name("$RealBin/../../tables/Old/skillnametable.txt");
	Skill::StaticInfo::parseSPDatabase("$RealBin/../../tables/Old/skillssp.txt");

	__PACKAGE__->new->run;
}

sub new {
	return bless {}, $_[0];
}

sub run {
	my ($self) = @_;

	$self->testRandomTeleportFallsBackToItemWhenSPIsTooLow;
	$self->testRespawnTeleportFallsBackToItemWhenSPIsTooLow;
	$self->testSharedTeleportCheckRejectsSkillWithoutSP;
	$self->testMutedBlocksTeleportSkillChecks;
	$self->testSilenceBlocksTeleportSkillChecks;
}

sub testRandomTeleportFallsBackToItemWhenSPIsTooLow {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 5;
	$char->inventory->add(_item(601, 101, 'Fly Wing'));

	my $task = Task::Teleport::Random->new(actor => $char);

	ok(!$task->canUseSkill, 'random teleport skill is not considered usable without enough SP');
	ok($task->getInventoryItem, 'random teleport still finds a teleport item fallback');
	ok(Misc::canUseTeleport(1), 'shared random teleport check still allows teleport via item fallback');
}

sub testRespawnTeleportFallsBackToItemWhenSPIsTooLow {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 2;
	$char->{sp} = 5;
	$char->inventory->add(_item(602, 102, 'Butterfly Wing'));

	my $task = Task::Teleport::Respawn->new(actor => $char);

	ok(!$task->canUseSkill, 'respawn teleport skill is not considered usable without enough SP');
	ok($task->getInventoryItem, 'respawn teleport still finds a teleport item fallback');
	ok(Misc::canUseTeleport(2), 'shared respawn teleport check still allows teleport via item fallback');
}

sub testSharedTeleportCheckRejectsSkillWithoutSP {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 2;
	$char->{sp} = 5;

	ok(!Misc::canUseTeleport(1), 'shared random teleport check rejects skill-only teleport without enough SP');
	ok(!Misc::canUseTeleport(2), 'shared respawn teleport check rejects skill-only teleport without enough SP');

	$char->{sp} = 20;
	ok(Misc::canUseTeleport(1), 'shared random teleport check accepts skill teleport once SP is sufficient');
	ok(Misc::canUseTeleport(2), 'shared respawn teleport check accepts skill teleport once SP is sufficient');
}

sub testMutedBlocksTeleportSkillChecks {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 2;
	$char->{sp} = 20;
	$char->{muted} = 1;

	ok(!Misc::canUseTeleport(1), 'shared random teleport check rejects skill teleport while muted');
	ok(!Misc::canUseTeleport(2), 'shared respawn teleport check rejects skill teleport while muted');

	$char->inventory->add(_item(601, 103, 'Fly Wing'));
	$char->inventory->add(_item(602, 104, 'Butterfly Wing'));
	ok(Misc::canUseTeleport(1), 'shared random teleport check still allows item teleport while muted');
	ok(Misc::canUseTeleport(2), 'shared respawn teleport check still allows item teleport while muted');
}

sub testSilenceBlocksTeleportSkillChecks {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 2;
	$char->{sp} = 20;
	$char->{statuses}{HEALTHSTATE_SILENCE} = 1;

	my $randomTask = Task::Teleport::Random->new(actor => $char);
	my $respawnTask = Task::Teleport::Respawn->new(actor => $char);

	ok(!$randomTask->canUseSkill, 'random teleport skill is rejected while HEALTHSTATE_SILENCE is active');
	ok(!$respawnTask->canUseSkill, 'respawn teleport skill is rejected while HEALTHSTATE_SILENCE is active');
	ok(!Misc::canUseTeleport(1), 'shared random teleport check rejects skill teleport while silenced');
	ok(!Misc::canUseTeleport(2), 'shared respawn teleport check rejects skill teleport while silenced');

	$char->inventory->add(_item(601, 105, 'Fly Wing'));
	$char->inventory->add(_item(602, 106, 'Butterfly Wing'));
	ok(Misc::canUseTeleport(1), 'shared random teleport check still allows item teleport while silenced');
	ok(Misc::canUseTeleport(2), 'shared respawn teleport check still allows item teleport while silenced');
}

sub _fresh_char {
	my $char = Actor::You->new;
	$char->{ID} = pack('V', 1);
	$char->{sp} = 0;
	$char->{muted} = 0;
	$char->inventory->{state} = 1;

	%Globals::config = ();
	$Globals::char = $char;
	$Globals::field = bless { baseName => 'prt_fild05' }, 'TeleportFallbackTest::Field';
	$Globals::net = bless {}, 'TeleportFallbackTest::Net';

	$Misc::char = $Globals::char;
	$Misc::field = $Globals::field;
	$Misc::net = $Globals::net;
	%Misc::config = ();

	return $char;
}

sub _item {
	my ($nameID, $id_num, $name) = @_;

	my $item = Actor::Item->new;
	$item->{ID} = pack('V', $id_num);
	$item->{nameID} = $nameID;
	$item->{name} = $name;
	return $item;
}

package TeleportFallbackTest::Field;

sub baseName {
	return $_[0]{baseName};
}

package TeleportFallbackTest::Net;

sub getState {
	return Network::IN_GAME;
}

1;
