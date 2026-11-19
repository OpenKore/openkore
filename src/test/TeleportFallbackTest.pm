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
use AI::CoreLogic;

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
	$self->testFleeUsesItemDespiteAvailableSkillAndEquipment;
	$self->testRoutineTeleportPrefersSkill;
	$self->testFleeWithoutWingsFallsBackToSkill;
	$self->testQueuedRoutineTeleportCanBecomeFlee;
	$self->testLowHPUpgradesRoutineTeleport;
	$self->testDangerSkillSetting;
	$self->testPreferenceAndFallbackMatrix;
	$self->testItemCooldownAndRejectionFallback;
	$self->testEquipmentFallback;
	$self->testFleeConsoleMessages;
	$self->testWarpMenuOwnership;
}

sub testDangerSkillSetting {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 20;
	my $danger = Task::Teleport::Random->new(actor => $char, flee => 1);
	my $routine = Task::Teleport::Random->new(actor => $char);
	$Globals::config{teleportAuto_useSkill} = 0;
	$Globals::config{teleportAuto_whenDanger_useSkill} = 1;
	ok($danger->canUseSkill, 'danger can prefer the skill independently of routine teleport');
	ok(!$routine->prefersSkill, 'routine teleport independently prefers items');
	ok($routine->canUseSkill, 'item preference does not block routine skill capability');
	my @skills;
	no warnings 'redefine';
	local *main::ai_skillUse = sub {push @skills, [@_]};
	$danger->activate;
	$danger->iterate;
	is(scalar @skills, 1, 'danger setting enabled actually casts Teleport');
	$Globals::config{teleportAuto_useSkill} = 1;
	$Globals::config{teleportAuto_whenDanger_useSkill} = 0;
	ok(!$danger->prefersSkill, 'danger item preference overrides routine skill preference');
	ok($danger->canUseSkill, 'danger item preference retains skill fallback');
	ok($routine->canUseSkill, 'routine teleport still prefers the skill');
	delete $Globals::config{teleportAuto_whenDanger_useSkill};
	ok($danger->prefersSkill, 'missing danger setting inherits routine skill preference');
	$Globals::config{teleportAuto_useSkill} = 0;
	ok(!$danger->prefersSkill, 'missing danger setting also inherits routine item preference');
	ok($danger->canUseSkill, 'inherited item preference still allows skill fallback');
}

sub testLowHPUpgradesRoutineTeleport {
	my $char = _fresh_char();
	$char->{hp} = 10;
	$char->{hp_max} = 100;
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 20;
	$Globals::config{teleportAuto_hp} = 20;
	local @AI::ai_seq;
	local @AI::ai_seq_args;
	local %AI::CoreLogic::timeout = (ai_teleport_hp => {time => 0, timeout => 0});
	no warnings 'redefine';
	local *AI::CoreLogic::ai_getAggressives = sub {return ('monster')};
	AI::CoreLogic::processAutoTeleport();
	ok(AI::args(0)->{flee}, 'low HP with an attacker queues a danger/flee teleport');
	AI::clear;
	$char->useTeleport(1);
	AI::CoreLogic::processAutoTeleport();
	ok(AI::args(0)->{flee}, 'low HP upgrades an already queued search/route teleport to flee');
	is(scalar @AI::ai_seq, 1, 'low HP does not queue a duplicate teleport');
}

sub testFleeUsesItemDespiteAvailableSkillAndEquipment {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 20;
	$char->inventory->add(_item(601, 110, 'Fly Wing'));
	$Globals::config{teleportAuto_useChatCommand} = '@jump';
	my @skills;
	my $sender = bless {items => []}, 'TeleportFallbackTest::Sender';
	local $Task::Teleport::messageSender = $sender;
	local %Task::Teleport::timeout = (ai_teleport => {time => 0, timeout => 0});
	no warnings 'redefine';
	local *main::ai_skillUse = sub {push @skills, [@_]};
	local *Actor::Item::scanConfigAndCheck = sub {1};
	my $task = Task::Teleport::Random->new(actor => $char, flee => 1);
	$task->activate;
	$task->iterate;
	is(scalar @{$sender->{items}}, 1, 'flee sends a Fly Wing use packet despite available Teleport skill and accessory');
	is($sender->{items}[0][0], pack('V', 110), 'flee uses the inventory Fly Wing');
	is(scalar @skills, 0, 'flee does not queue skill casting');
	ok(!$task->chatCommand, 'flee does not substitute a chat teleport command');
}

sub testRoutineTeleportPrefersSkill {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 20;
	$char->inventory->add(_item(601, 111, 'Fly Wing'));
	my @skills;
	my $sender = bless {items => []}, 'TeleportFallbackTest::Sender';
	local $Task::Teleport::messageSender = $sender;
	local %Task::Teleport::timeout = (ai_teleport => {time => 0, timeout => 0});
	no warnings 'redefine';
	local *main::ai_skillUse = sub {push @skills, [@_]};
	my $task = Task::Teleport::Random->new(actor => $char);
	$task->activate;
	$task->iterate;
	is(scalar @skills, 1, 'routine search/route teleport casts the available skill');
	is($skills[0][0], 'AL_TELEPORT', 'routine teleport casts Teleport');
	is(scalar @{$sender->{items}}, 0, 'routine teleport preserves Fly Wings when skill is usable');
}

sub testFleeWithoutWingsFallsBackToSkill {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 20;
	my @skills;
	no warnings 'redefine';
	local *main::ai_skillUse = sub {push @skills, [@_]};
	my $task = Task::Teleport::Random->new(actor => $char, flee => 1);
	$task->activate;
	$task->iterate;
	is(scalar @skills, 1, 'item-preferred flee falls back to casting when wings are missing');
	is($task->getStatus, Task::RUNNING, 'missing preferred item is not a task error when a skill is usable');
	$char->{sp} = 0;
	my $unavailable = Task::Teleport::Random->new(actor => $char, flee => 1);
	$unavailable->activate;
	$unavailable->iterate;
	is($unavailable->getError->{code}, Task::Teleport::NO_ITEM_OR_SKILL, 'neither usable method produces a task error');
	like($unavailable->getError->{message}, qr/cannot flee: no usable Teleport skill or teleport item/, 'flee error describes both unavailable methods');
}

sub testQueuedRoutineTeleportCanBecomeFlee {
	my $char = _fresh_char();
	local @AI::ai_seq;
	local @AI::ai_seq_args;
	$char->useTeleport(1);
	my $task = AI::args(0);
	ok(!$task->{flee}, 'ordinary Actor teleport starts with skill preference');
	$char->useTeleport(1, flee => 1);
	is(scalar @AI::ai_seq, 1, 'danger request reuses the queued random teleport');
	ok($task->{flee}, 'danger request switches queued teleport to danger preference');
	AI::clear;
	$char->useTeleport(1, flee => 1);
	ok(AI::args(0)->{flee}, 'new Actor danger request propagates flee intent');
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

sub testWarpMenuOwnership {
    my $char = _fresh_char();
    local @AI::ai_seq;
    local @AI::ai_seq_args;
    no warnings 'redefine';
    local *Task::Teleport::ai_seq = \@AI::ai_seq;
    local *Task::Teleport::ai_seq_args = \@AI::ai_seq_args;
    local *main::ai_skillUse = sub {AI::queue('skill_use', {lv => $_[1], ret => $_[7], skill_used => 1})};
    for my $class ('Task::Teleport::Random', 'Task::Teleport::Respawn') {
        AI::clear;
        my $task = $class->new(actor => $char);
        $task->useSkill;
        AI::queue('skill_use', {lv => 99});
        my $unrelated = AI::args();
        is($task->consumeWarpMenu, $class eq 'Task::Teleport::Random' ? 1 : 2, "$class consumes its own completed skill menu");
        is(AI::args(), $unrelated, "$class leaves an unrelated skill task in place");
        is(scalar @AI::ai_seq, 1, "$class removes only its own completed skill task");
        ok(!defined $task->consumeWarpMenu, "$class cannot consume the same menu twice");
        $task->{pendingTeleportItemMenu} = 2;
        is($task->consumeWarpMenu, 2, "$class also handles an item-generated menu");
        ok(!defined $task->consumeWarpMenu, "$class consumes an item menu once");
        $task->{pendingTeleportItemMenu} = 1;
        $task->{mapChanged} = 1;
        ok(!defined $task->consumeWarpMenu, "$class ignores stale menus after a map change");
        delete $task->{mapChanged};
        $task->useSkill;
        ${$task->{pendingTeleportSkill}{ret}} = 'failed';
        ok(!defined $task->consumeWarpMenu, "$class does not answer a failed skill's menu");
    }
    AI::clear;
}

sub testPreferenceAndFallbackMatrix {
	for my $mode ('routine', 'danger', 'respawn') {
		for my $preference (0, 1) {
			for my $availability ('both', 'no_item', 'no_skill', 'low_sp', 'silenced') {
				my $char = _fresh_char();
				my $level = $mode eq 'respawn' ? 2 : 1;
				$char->{skills}{AL_TELEPORT}{lv} = $availability eq 'no_skill' ? 0 : $level;
				$char->{sp} = $availability eq 'low_sp' ? 0 : 20;
				$char->{statuses}{HEALTHSTATE_SILENCE} = 1 if $availability eq 'silenced';
				$char->inventory->add(_item($level == 1 ? 601 : 602, 120, 'Teleport Wing')) unless $availability eq 'no_item';
				$Globals::config{teleportAuto_useSkill} = $preference;
				$Globals::config{teleportAuto_whenDanger_useSkill} = $preference;
				my @skills;
				my $sender = bless {items => []}, 'TeleportFallbackTest::Sender';
				local $Task::Teleport::messageSender = $sender;
				local %Task::Teleport::timeout = (ai_teleport => {time => 0, timeout => 0});
				no warnings 'redefine';
				local *main::ai_skillUse = sub {push @skills, [@_]};
				my $class = $level == 1 ? 'Task::Teleport::Random' : 'Task::Teleport::Respawn';
				my $task = $class->new(actor => $char, flee => $mode eq 'danger');
				$task->activate;
				$task->iterate;
				my $expectedSkill = $availability eq 'no_item' || ($availability eq 'both' && $preference);
				is(scalar @skills, $expectedSkill ? 1 : 0, "$mode preference=$preference availability=$availability: skill selection");
				is(scalar @{$sender->{items}}, $expectedSkill ? 0 : 1, "$mode preference=$preference availability=$availability: item selection");
				is($task->getStatus, Task::RUNNING, "$mode preference=$preference availability=$availability: fallback succeeds");
			}
		}
	}
}

sub testItemCooldownAndRejectionFallback {
	for my $flee (0, 1) {
		my $char = _fresh_char();
		$char->{skills}{AL_TELEPORT}{lv} = 1;
		$char->{sp} = 20;
		$char->inventory->add(_item(601, 121, 'Fly Wing'));
		$char->{last_teleport_item_use}{601} = {time => time, timeout => 60};
		$Globals::config{teleportAuto_useSkill} = 0;
		my @skills;
		my $sender = bless {items => []}, 'TeleportFallbackTest::Sender';
		local $Task::Teleport::messageSender = $sender;
		local %Task::Teleport::timeout = (ai_teleport => {time => 0, timeout => 0});
		no warnings 'redefine';
		local *main::ai_skillUse = sub {push @skills, [@_]};
		my $task = Task::Teleport::Random->new(actor => $char, flee => $flee);
		$task->activate;
		$task->iterate;
		is(scalar @skills, 1, "flee=$flee: preferred item cooldown falls back to skill");
		is(scalar @{$sender->{items}}, 0, "flee=$flee: cooling-down item is not sent");
		delete $char->{last_teleport_item_use}{601};
		@skills = ();
		$task = Task::Teleport::Random->new(actor => $char, flee => $flee);
		$task->activate;
		$task->iterate;
		is(scalar @{$sender->{items}}, 1, "flee=$flee: ready preferred item is attempted first");
		$task->onItemUseAck(undef, {serverIndex => pack('V', 121), success => 0});
		$task->{retry}{time} = 0;
		$task->iterate;
		is(scalar @skills, 1, "flee=$flee: rejected item switches to skill");
		is(scalar @{$sender->{items}}, 1, "flee=$flee: usable skill avoids another rejected item attempt");
	}
}

sub testEquipmentFallback {
	my $char = _fresh_char();
	$char->{sp} = 20;
	my $equips = 0;
	no warnings 'redefine';
	local *Actor::Item::scanConfigAndCheck = sub {1};
	local *Actor::Item::scanConfigAndEquip = sub {$equips++};
	my $task = Task::Teleport::Random->new(actor => $char, flee => 1);
	$task->activate;
	$task->iterate;
	is($equips, 1, 'item-preferred flee can equip a skill accessory when no teleport item is available');
	$char->{sp} = 0;
	ok(!$task->isEquipNeededToTeleport, 'insufficient SP does not trigger futile skill equipment changes');
	$char->{sp} = 20;
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	my $unusableItem = _item(601, 122, 'Unidentified teleport equipment');
	$unusableItem->{type} = 4;
	$unusableItem->{type_equip} = 2;
	$unusableItem->{identified} = 0;
	is($task->selectTeleportMethod($unusableItem), 'skill', 'unusable teleport equipment does not block skill fallback');
	$char->{statuses}{HEALTHSTATE_SILENCE} = 1;
	ok(!$task->isEquipNeededToTeleport, 'silence does not trigger futile skill equipment changes');
}

sub testFleeConsoleMessages {
	my $char = _fresh_char();
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$char->{sp} = 20;
	$char->inventory->add(_item(601, 123, 'Fly Wing'));
	my @messages;
	my $sender = bless {items => []}, 'TeleportFallbackTest::Sender';
	local $Task::Teleport::messageSender = $sender;
	local %Task::Teleport::timeout = (ai_teleport => {time => 0, timeout => 0});
	local @AI::ai_seq;
	local @AI::ai_seq_args;
	no warnings 'redefine';
	local *Actor::message = sub {push @messages, $_[0]};
	local *Task::Teleport::message = sub {push @messages, $_[0]};
	local *main::ai_skillUse = sub {};
	$char->useTeleport(1, flee => 1);
	like(join('', @messages), qr/Queueing danger\/flee teleport/, 'new flee task identifies danger in normal console output');
	my $task = AI::args(0);
	$task->activate;
	$task->iterate;
	like(join('', @messages), qr/Teleporting to flee danger using Fly Wing/, 'console identifies danger and actual chosen item');
	$task->{retry}{time} = 0;
	$task->iterate;
	is(scalar(grep {/Teleporting to flee danger using Fly Wing/} @messages), 1, 'same-method retries do not spam flee acknowledgement');
	$task->onItemUseAck(undef, {serverIndex => pack('V', 123), success => 0});
	$task->{retry}{time} = 0;
	$task->iterate;
	like(join('', @messages), qr/Teleporting to flee danger using Teleport skill/, 'fallback identifies the actual skill method');
	$task->{mapChanged} = 1;
	$task->iterate;
	like(join('', @messages), qr/Danger\/flee teleport completed/, 'observed map change acknowledges flee completion');
	AI::clear;
	@messages = ();
	$char->useTeleport(1);
	$char->useTeleport(1, flee => 1);
	$char->useTeleport(1, flee => 1);
	is(scalar(grep {/Upgrading queued teleport to danger\/flee mode/} @messages), 1, 'upgrade acknowledgement is visible and not repeated');
	AI::clear;
}

sub _fresh_char {
	my $char = Actor::You->new;
	$char->{ID} = pack('V', 1);
	$char->{sp} = 0;
	$char->{muted} = 0;
	$char->inventory->{state} = 1;

	%Globals::config = (teleportAuto_useSkill => 1, teleportAuto_whenDanger_useSkill => 0);
	$Globals::char = $char;
	$Globals::field = bless { baseName => 'prt_fild05' }, 'TeleportFallbackTest::Field';
	$Globals::net = bless {}, 'TeleportFallbackTest::Net';

	$Misc::char = $Globals::char;
	$Misc::field = $Globals::field;
	$Misc::net = $Globals::net;
	%Misc::config = (teleportAuto_useSkill => 1, teleportAuto_whenDanger_useSkill => 0);

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

sub isCity {return 0}

package TeleportFallbackTest::Net;

sub getState {
	return Network::IN_GAME;
}

package TeleportFallbackTest::Sender;

sub sendItemUse {
	my ($self, @args) = @_;
	push @{$self->{items}}, \@args;
}

1;
