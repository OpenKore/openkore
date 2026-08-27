package TeleportDirectWarpTest;

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/lib";
use OpenKoreTestStubs;
use Test::More;
use Actor::You;

sub start {
	note('Starting ' . __PACKAGE__);
	__PACKAGE__->new->run;
}

sub new {
	return bless {}, $_[0];
}

sub run {
	my ($self) = @_;

	$self->testDirectRandomTeleportBypassesExistingTeleportQueue;
	$self->testRespawnTeleportKeepsTheTaskPath;
}

sub testDirectRandomTeleportBypassesExistingTeleportQueue {
	local %Actor::config = (teleportAuto_useSkill => 4);
	local @AI::ai_seq = ('teleport');
	local @AI::ai_seq_args = ({level => 1});
	local $Actor::messageSender = TeleportDirectWarpTest::FakeSender->new;
	my $char = _char_without_teleport_skill_or_sp();

	$char->useTeleport(1);
	$char->useTeleport(1);

	is_deeply(
		$Actor::messageSender->{warps},
		[[26, 'Random'], [26, 'Random']],
		'mode 4 sends a random warp selection for every random teleport request'
	);
	is_deeply(
		\@AI::ai_seq,
		['teleport'],
		'mode 4 does not add a teleport task or wait for the existing teleport queue'
	);
}

sub testRespawnTeleportKeepsTheTaskPath {
	local %Actor::config = (teleportAuto_useSkill => 4);
	local @AI::ai_seq;
	local @AI::ai_seq_args;
	local $Actor::messageSender = TeleportDirectWarpTest::FakeSender->new;
	my $char = _char_without_teleport_skill_or_sp();

	$char->useTeleport(2);

	is_deeply($Actor::messageSender->{warps}, [], 'mode 4 does not send a random warp selection for respawn teleport');
	is_deeply(\@AI::ai_seq, ['teleport'], 'respawn teleport stays on the existing task path');
}

sub _char_without_teleport_skill_or_sp {
	my $char = Actor::You->new;
	$char->{ID} = pack('V', 1);
	$char->{sp} = 0;
	return $char;
}

package TeleportDirectWarpTest::FakeSender;

sub new {
	return bless {warps => []}, $_[0];
}

sub sendWarpTele {
	my ($self, @args) = @_;
	push @{$self->{warps}}, \@args;
}

1;
