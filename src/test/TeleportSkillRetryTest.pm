package TeleportSkillRetryTest;

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/lib";
use OpenKoreTestStubs;
use Test::More;
use AI;
use Skill;
use Actor::You;
use Task::Teleport::Random;

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

	$self->testRandomTeleportTaskSendsSkillWithoutSkillUseQueue;
	$self->testDuplicateRandomTeleportRetriesExistingTaskWithoutNewQueue;
	$self->testNpcQueueDoesNotStartTeleport;
	$self->testModeFourUsesTheNormalTeleportTask;
}

sub testRandomTeleportTaskSendsSkillWithoutSkillUseQueue {
	_with_state(sub {
		my ($char, $sender) = @_;
		my $task = Task::Teleport::Random->new(actor => $char);

		$task->useSkill;

		is_deeply($sender->{skills}, [[26, 1, $char->{ID}]],
			'random teleport task sends the level 1 teleport skill directly');
		is_deeply(\@AI::ai_seq, [], 'random teleport does not create a skill_use queue entry');
	});
}

sub testDuplicateRandomTeleportRetriesExistingTaskWithoutNewQueue {
	_with_state(sub {
		my ($char, $sender) = @_;
		my $task = Task::Teleport::Random->new(actor => $char);
		AI::queue('teleport', $task);

		$char->useTeleport(1);
		$char->useTeleport(1);

		is_deeply($sender->{skills}, [[26, 1, $char->{ID}], [26, 1, $char->{ID}]],
			'each duplicate random teleport request retries the existing task immediately');
		is_deeply(\@AI::ai_seq, ['teleport'], 'duplicate random teleport does not add another queue entry');
	});
}

sub testNpcQueueDoesNotStartTeleport {
	_with_state(sub {
		my ($char, $sender) = @_;
		AI::queue('NPC', {});

		$char->useTeleport(1);

		is_deeply($sender->{skills}, [], 'NPC queue alone does not send a teleport skill');
		is_deeply(\@AI::ai_seq, ['NPC'], 'NPC queue alone does not create a teleport task');
	});
}

sub testModeFourUsesTheNormalTeleportTask {
	_with_state(sub {
		my ($char, $sender) = @_;
		local %Actor::config = (teleportAuto_useSkill => 4);

		$char->useTeleport(1);

		is_deeply($sender->{warps}, [], 'mode 4 does not send a warp selection packet');
		is_deeply(\@AI::ai_seq, ['teleport'], 'mode 4 follows the normal teleport task path');
	});
}

sub _with_state {
	my ($callback) = @_;
	local %Actor::config = (teleportAuto_useSkill => 1);
	local @AI::ai_seq;
	local @AI::ai_seq_args;
	local $Globals::char;
	local $AI::char;
	local $Misc::char;
	local $Misc::field;
	local %Task::Teleport::Random::config = (teleportAuto_useSkill => 1);
	local $Task::Teleport::Random::field = bless {baseName => 'prt_fild05'}, 'TeleportSkillRetryTest::Field';
	local $Task::Teleport::Random::messageSender = TeleportSkillRetryTest::FakeSender->new;
	local $Actor::messageSender = $Task::Teleport::Random::messageSender;
	my $char = Actor::You->new;
	$char->{ID} = pack('V', 1);
	$char->{sp} = 20;
	$char->{skills}{AL_TELEPORT}{lv} = 1;
	$Globals::char = $char;
	$AI::char = $char;
	$Misc::char = $char;
	$Misc::field = $Task::Teleport::Random::field;

	$callback->($char, $Task::Teleport::Random::messageSender);
}

package TeleportSkillRetryTest::Field;

sub baseName {
	return $_[0]{baseName};
}

package TeleportSkillRetryTest::FakeSender;

sub new {
	return bless {skills => [], warps => []}, $_[0];
}

sub sendSkillUse {
	my ($self, @args) = @_;
	push @{$self->{skills}}, \@args;
}

sub sendWarpTele {
	my ($self, @args) = @_;
	push @{$self->{warps}}, \@args;
}

1;
