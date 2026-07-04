package CastConditionsTest;

use strict;
use FindBin qw($RealBin);
use Test::More;
use Globals;
use ActorList;
use Actor::You;
use Actor::Player;
use Actor::Monster;
use Misc;
use Skill;

sub start {
	note('Starting ' . __PACKAGE__);
	__PACKAGE__->new->run;
}

sub new {
	return bless {}, $_[0];
}

sub run {
	my ($self) = @_;

	Skill::StaticInfo::parseSkillsDatabase_id2handle("$RealBin/SKILL_id_handle.txt");
	Skill::StaticInfo::parseSkillsDatabase_handle2name("$RealBin/skillnametable.txt");
	Skill::DynamicInfo::add(288, 'HP_ASSUMPTIO', 5, 30, 9, Skill::TARGET_ACTORS(), Skill::OWNER_CHAR());
	Skill::DynamicInfo::add(931, 'MER_DECAGI', 10, 15, 9, Skill::TARGET_ENEMY(), Skill::OWNER_CHAR());
	Skill::DynamicInfo::add(777, 'PR_MAGNIFICAT', 5, 40, 9, Skill::TARGET_SELF(), Skill::OWNER_CHAR());

	$self->testSelfConditionBlocksWhileBeingCasted;
	$self->testSelfConditionRequiresWhileBeingCasted;
	$self->testSelfConditionBlocksWhileNearPartyMemberCasting;
	$self->testSelfConditionRequiresNearPartyMemberCasting;
	$self->testPlayerConditionBlocksPartyTargetCast;
	$self->testPlayerConditionRequiresWhileBeingCasted;
	$self->testMonsterConditionBlocksMonsterTargetCast;
	$self->testMonsterConditionRequiresWhileBeingCasted;
}

sub testSelfConditionBlocksWhileBeingCasted {
	my $char = _fresh_char();
	my $caster = _player(2);
	$caster->{casting} = {
		skill => Skill->new(auto => 'Blessing'),
		targetID => $char->{ID},
		target => $char,
	};
	$Globals::playersList->add($caster);

	local %Globals::config = (
		selftest_manualAI => 2,
		selftest_notWhileBeingCasted => 'Blessing',
	);
	local %Misc::config = %Globals::config;

	ok(!Misc::checkSelfCondition('selftest'), 'self condition fails while blessing is being cast on self');

	$Globals::config{selftest_notWhileBeingCasted} = 'Assumption';
	$Misc::config{selftest_notWhileBeingCasted} = 'Assumption';
	ok(Misc::checkSelfCondition('selftest'), 'self condition ignores other skills being cast on self');
}

sub testSelfConditionRequiresWhileBeingCasted {
	my $char = _fresh_char();
	my $caster = _player(9);
	$caster->{casting} = {
		skill => Skill->new(auto => 'Blessing'),
		targetID => $char->{ID},
		target => $char,
	};
	$Globals::playersList->add($caster);

	local %Globals::config = (
		selftest_manualAI => 2,
		selftest_whileBeingCasted => 'Blessing',
	);
	local %Misc::config = %Globals::config;

	ok(Misc::checkSelfCondition('selftest'), 'self condition passes while the requested skill is being cast on self');

	$Globals::config{selftest_whileBeingCasted} = 'Assumption';
	$Misc::config{selftest_whileBeingCasted} = 'Assumption';
	ok(!Misc::checkSelfCondition('selftest'), 'self condition fails when self is not being casted with the requested skill');
}

sub testSelfConditionBlocksWhileNearPartyMemberCasting {
	my $char = _fresh_char();
	my $party_caster = _player(7);
	my $outsider = _player(8);
	$party_caster->{casting} = {
		skill => Skill->new(auto => 'PR_MAGNIFICAT'),
		targetID => $party_caster->{ID},
		target => $party_caster,
	};
	$outsider->{casting} = {
		skill => Skill->new(auto => 'PR_MAGNIFICAT'),
		targetID => $outsider->{ID},
		target => $outsider,
	};
	$Globals::playersList->add($party_caster);
	$Globals::playersList->add($outsider);
	$char->{party}{joined} = 1;
	$char->{party}{users}{$party_caster->{ID}} = {online => 1};

	local %Globals::config = (
		selftest_manualAI => 2,
		selftest_whenNoNearPartyMemberCasting => 'PR_MAGNIFICAT',
	);
	local %Misc::config = %Globals::config;

	ok(!Misc::checkSelfCondition('selftest'), 'self condition fails while a nearby party member is casting the same skill');

	delete $party_caster->{casting};
	ok(Misc::checkSelfCondition('selftest'), 'self condition ignores non-party players casting the same skill');
}

sub testSelfConditionRequiresNearPartyMemberCasting {
	my $char = _fresh_char();
	my $party_caster = _player(10);
	my $outsider = _player(11);
	$party_caster->{casting} = {
		skill => Skill->new(auto => 'PR_MAGNIFICAT'),
		targetID => $party_caster->{ID},
		target => $party_caster,
	};
	$outsider->{casting} = {
		skill => Skill->new(auto => 'PR_MAGNIFICAT'),
		targetID => $outsider->{ID},
		target => $outsider,
	};
	$Globals::playersList->add($party_caster);
	$Globals::playersList->add($outsider);
	$char->{party}{joined} = 1;
	$char->{party}{users}{$party_caster->{ID}} = {online => 1};

	local %Globals::config = (
		selftest_manualAI => 2,
		selftest_whenNearPartyMemberCasting => 'PR_MAGNIFICAT',
	);
	local %Misc::config = %Globals::config;

	ok(Misc::checkSelfCondition('selftest'), 'self condition passes while a nearby party member is casting the requested skill');

	delete $party_caster->{casting};
	ok(!Misc::checkSelfCondition('selftest'), 'self condition fails when no nearby party member is casting the requested skill');
}

sub testPlayerConditionBlocksPartyTargetCast {
	my $char = _fresh_char();
	my $target = _player(3);
	my $caster = _player(4);
	$caster->{casting} = {
		skill => Skill->new(auto => 'HP_ASSUMPTIO'),
		targetID => $target->{ID},
		target => $target,
	};
	$Globals::playersList->add($target);
	$Globals::playersList->add($caster);

	local %Globals::config = (
		playertest_target_notWhileBeingCasted => 'HP_ASSUMPTIO',
	);
	local %Misc::config = %Globals::config;

	ok(!Misc::checkPlayerCondition('playertest_target', $target->{ID}), 'player condition fails while target is already receiving assumption');

	$Globals::config{playertest_target_notWhileBeingCasted} = 'Blessing';
	$Misc::config{playertest_target_notWhileBeingCasted} = 'Blessing';
	ok(Misc::checkPlayerCondition('playertest_target', $target->{ID}), 'player condition allows target when a different skill is being cast');
}

sub testPlayerConditionRequiresWhileBeingCasted {
	my $char = _fresh_char();
	my $target = _player(12);
	my $caster = _player(13);
	$caster->{casting} = {
		skill => Skill->new(auto => 'HP_ASSUMPTIO'),
		targetID => $target->{ID},
		target => $target,
	};
	$Globals::playersList->add($target);
	$Globals::playersList->add($caster);

	local %Globals::config = (
		playertest_target_whileBeingCasted => 'HP_ASSUMPTIO',
	);
	local %Misc::config = %Globals::config;

	ok(Misc::checkPlayerCondition('playertest_target', $target->{ID}), 'player condition passes while target is receiving the requested cast');

	$Globals::config{playertest_target_whileBeingCasted} = 'Blessing';
	$Misc::config{playertest_target_whileBeingCasted} = 'Blessing';
	ok(!Misc::checkPlayerCondition('playertest_target', $target->{ID}), 'player condition fails when target is not receiving the requested cast');
}

sub testMonsterConditionBlocksMonsterTargetCast {
	my $char = _fresh_char();
	my $monster = _monster(5);
	my $caster = _player(6);
	$caster->{casting} = {
		skill => Skill->new(auto => 'MER_DECAGI'),
		targetID => $monster->{ID},
		target => $monster,
	};
	$Globals::monstersList->add($monster);
	$Globals::playersList->add($caster);

	local %Globals::config = (
		monstertest_target_notWhileBeingCasted => 'MER_DECAGI',
	);
	local %Misc::config = %Globals::config;

	ok(!Misc::checkMonsterCondition('monstertest_target', $monster), 'monster condition fails while the same debuff is already being cast');

	$Globals::config{monstertest_target_notWhileBeingCasted} = 'Blessing';
	$Misc::config{monstertest_target_notWhileBeingCasted} = 'Blessing';
	ok(Misc::checkMonsterCondition('monstertest_target', $monster), 'monster condition allows the target when another skill is being cast');
}

sub testMonsterConditionRequiresWhileBeingCasted {
	my $char = _fresh_char();
	my $monster = _monster(14);
	my $caster = _player(15);
	$caster->{casting} = {
		skill => Skill->new(auto => 'MER_DECAGI'),
		targetID => $monster->{ID},
		target => $monster,
	};
	$Globals::monstersList->add($monster);
	$Globals::playersList->add($caster);

	local %Globals::config = (
		monstertest_target_whileBeingCasted => 'MER_DECAGI',
	);
	local %Misc::config = %Globals::config;

	ok(Misc::checkMonsterCondition('monstertest_target', $monster), 'monster condition passes while the requested debuff is being cast');

	$Globals::config{monstertest_target_whileBeingCasted} = 'Blessing';
	$Misc::config{monstertest_target_whileBeingCasted} = 'Blessing';
	ok(!Misc::checkMonsterCondition('monstertest_target', $monster), 'monster condition fails when the requested debuff is not being cast');
}

sub _fresh_char {
	my $char = Actor::You->new;
	$char->{ID} = pack('V', 1);
	$Globals::char = $char;
	$Misc::char = $char;
	_reset_lists();
	return $char;
}

sub _reset_lists {
	$Globals::playersList = ActorList->new('Actor::Player');
	$Globals::monstersList = ActorList->new('Actor::Monster');
	$Globals::npcsList = ActorList->new('Actor::NPC');
	$Globals::petsList = ActorList->new('Actor::Pet');
	$Globals::slavesList = ActorList->new('Actor::Slave');
	$Globals::elementalsList = ActorList->new('Actor::Elemental');

	$Misc::playersList = $Globals::playersList;
	$Misc::monstersList = $Globals::monstersList;
	$Misc::npcsList = $Globals::npcsList;
	$Misc::petsList = $Globals::petsList;
	$Misc::slavesList = $Globals::slavesList;
	$Misc::elementalsList = $Globals::elementalsList;
}

sub _player {
	my ($id_num) = @_;
	my $player = Actor::Player->new;
	$player->{ID} = pack('V', $id_num);
	return $player;
}

sub _monster {
	my ($id_num) = @_;
	my $monster = Actor::Monster->new;
	$monster->{ID} = pack('V', $id_num);
	return $monster;
}

1;
