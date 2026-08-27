use strict;
use warnings;
use FindBin;
use Test::More;

BEGIN {
	package Plugins;
	our @registered_hooks;
	sub register {}
	sub addHooks {
		@registered_hooks = @_;
		return \@registered_hooks;
	}
	sub delHooks {}
	$INC{'Plugins.pm'} = 1;

	package Globals;
	use Exporter 'import';
	our @EXPORT_OK = qw($accountID $char $monstersList %config);
	our ($accountID, $char, $monstersList, %config);
	$INC{'Globals.pm'} = 1;

	package Log;
	use Exporter 'import';
	our @EXPORT_OK = qw(debug message);
	our @messages;
	sub debug { push @messages, $_[0]; }
	sub message { push @messages, $_[0]; }
	$INC{'Log.pm'} = 1;

	package AI;
	our $attack_index;
	our %action_args;
	our $queue_calls = 0;
	sub import {}
	sub findAction { return $attack_index; }
	sub args { return $action_args{$_[0]}; }
	sub queue { $queue_calls++; }
	$INC{'AI.pm'} = 1;

	package Utils;
	use Exporter 'import';
	our @EXPORT = qw(blockDistance calcPosition);
	sub blockDistance {
		my ($from, $to) = @_;
		my $dx = abs($from->{x} - $to->{x});
		my $dy = abs($from->{y} - $to->{y});
		return $dx > $dy ? $dx : $dy;
	}
	sub calcPosition {
		my ($actor) = @_;
		return $actor->{predicted_pos} || $actor->{pos_to};
	}
	$INC{'Utils.pm'} = 1;
}

{
	package TestChar;
	our @sent_attacks;
	our $queued_attacks = 0;
	sub sendAttack { push @sent_attacks, $_[1]; }
	sub attack { $queued_attacks++; }
	sub getSkillLevelByHandle { return $_[0]{skills}{$_[1]}{lv} || 0; }
}

{
	package TestMonsterList;
	sub getByID { return $_[0]{actors}{$_[1]}; }
}

{
	package TestSkill;
	sub getIDN { return $_[0]{id}; }
}

require "$FindBin::Bin/../sageFreeCastAttack.pl";

my $test_now = 100;
{
	no warnings 'redefine';
	*sageFreeCastAttack::_now = sub { return $test_now };
}

sub reset_fixture {
	sageFreeCastAttack::on_unload();
	$test_now = 100;
	@TestChar::sent_attacks = ();
	$TestChar::queued_attacks = 0;
	@Log::messages = ();
	$AI::queue_calls = 0;
	$AI::attack_index = 0;
	%AI::action_args = (0 => { ID => 'monster-1' });

	$Globals::accountID = 'self-id';
	$Globals::char = bless {
		skills => { SA_FREECAST => { lv => 10 } },
		attack_range => 1,
		pos => { x => 10, y => 10 },
		pos_to => { x => 10, y => 10 },
		time_move => 100,
		walk_speed => 0.12,
	}, 'TestChar';
	$Globals::monstersList = bless {
		actors => {
			'monster-1' => bless({
				ID => 'monster-1',
				name => 'Lava Poring',
				binID => 0,
				dead => 0,
				pos => { x => 11, y => 10 },
				pos_to => { x => 11, y => 10 },
				time_move => 100,
				walk_speed => 0.12,
			}, 'Actor::Monster'),
		},
	}, 'TestMonsterList';
	%Globals::config = (
		sageFreeCastAttack => 1,
		sageFreeCastAttack_debug => 0,
		attackUseWeapon => 1,
		attackDistance => 1,
		attackMaxDistance => 1,
	);
}

sub casting_event {
	my (%overrides) = @_;
	return {
		sourceID => 'self-id',
		targetID => 'monster-1',
		source => $Globals::char,
		target => $Globals::monstersList
			&& $Globals::monstersList->getByID('monster-1'),
		skillID => 19,
		skill => bless({ id => 19 }, 'TestSkill'),
		time => 100,
		castTime => 800,
		x => 0,
		y => 0,
		%overrides,
	};
}

sub start_cast {
	my (%overrides) = @_;
	my $event = casting_event(%overrides);
	$event->{skill} = bless({ id => $event->{skillID} }, 'TestSkill');
	$Globals::char->{casting} = {
		skill => $event->{skill},
		targetID => $event->{targetID},
		startTime => $test_now,
		castTime => $event->{castTime},
	};
	sageFreeCastAttack::on_is_casting(undef, $event);
	return $event;
}

sub run_after {
	my ($seconds) = @_;
	$test_now += $seconds;
	my $handler = sageFreeCastAttack->can('on_ai_pre');
	$handler->() if $handler;
}

reset_fixture();
start_cast();

is_deeply(
	\@TestChar::sent_attacks,
	[],
	'a supported self cast does not send an attack packet synchronously',
);
run_after(0.09);
is_deeply(\@TestChar::sent_attacks, [], 'the initial delay has not elapsed at 90 ms');
run_after(0.01);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'the current weapon attack is sent after the 100 ms initial delay',
);
is($TestChar::queued_attacks, 0, 'the plugin does not add a duplicate character attack action');
is($AI::queue_calls, 0, 'the plugin does not add a duplicate AI queue entry');

reset_fixture();
$AI::attack_index = 1;
%AI::action_args = (
	0 => { tag => 'attackSkill' },
	1 => { ID => 'monster-1', suspended => 100 },
);
start_cast();
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'the suspended attack below skill_use remains the weapon target',
);

my @supported_casts = (
	[14, 'Cold Bolt', {}],
	[19, 'Fire Bolt', {}],
	[20, 'Lightning Bolt', {}],
	[21, 'Thunder Storm', { targetID => '', target => undef, x => 50, y => 60 }],
);

reset_fixture();
for my $cast (@supported_casts) {
	my ($skill_id, undef, $event_overrides) = @{$cast};
	start_cast(skillID => $skill_id, %{$event_overrides});
	run_after(0.10);
}
is_deeply(
	\@TestChar::sent_attacks,
	[('monster-1') x 4],
	'all four supported Sage spells resume the current attack, including ground-targeted Thunder Storm',
);

reset_fixture();
start_cast(skillID => 18);
run_after(0.10);
is_deeply(\@TestChar::sent_attacks, [], 'an unrelated spell does not resume a weapon attack');

my @guard_cases = (
	[
		'the plugin switch is disabled',
		sub { $Globals::config{sageFreeCastAttack} = 0 },
		{},
	],
	[
		'weapon attacks are disabled',
		sub { $Globals::config{attackUseWeapon} = 0 },
		{},
	],
	[
		'Free Cast is not learned',
		sub { delete $Globals::char->{skills}{SA_FREECAST} },
		{},
	],
	[
		'another actor is casting',
		sub {},
		{ sourceID => 'other-actor' },
	],
	[
		'the skill has no cast time',
		sub {},
		{ castTime => 0 },
	],
);

for my $case (@guard_cases) {
	my ($description, $mutate_fixture, $event_overrides) = @{$case};
	reset_fixture();
	$mutate_fixture->();
	start_cast(%{$event_overrides});
	run_after(0.10);
	is_deeply(\@TestChar::sent_attacks, [], "no packet is sent when $description");
}

my @target_guard_cases = (
	[
		'there is no active attack action',
		sub { $AI::attack_index = undef },
	],
	[
		'the attack action has no target ID',
		sub { delete $AI::action_args{0}{ID} },
	],
	[
		'the monster list is unavailable',
		sub { $Globals::monstersList = undef },
	],
	[
		'the attack target is no longer visible',
		sub { delete $Globals::monstersList->{actors}{'monster-1'} },
	],
	[
		'the attack target is dead',
		sub { $Globals::monstersList->{actors}{'monster-1'}{dead} = 1 },
	],
);

for my $case (@target_guard_cases) {
	my ($description, $mutate_fixture) = @{$case};
	reset_fixture();
	$mutate_fixture->();
	start_cast();
	run_after(0.10);
	is_deeply(\@TestChar::sent_attacks, [], "no packet is sent when $description");
}

reset_fixture();
$Globals::monstersList->{actors}{'monster-1'}{pos_to} = { x => 13, y => 10 };
start_cast();
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'an out-of-range target is not attacked while casting',
);
$Globals::monstersList->{actors}{'monster-1'}{pos_to} = { x => 11, y => 10 };
run_after(0.01);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'the pending attack is sent once the target enters weapon range',
);

reset_fixture();
$Globals::char->{pos_to} = { x => 11, y => 10 };
$Globals::char->{predicted_pos} = { x => 10, y => 10 };
$Globals::monstersList->{actors}{'monster-1'}{pos} = { x => 12, y => 10 };
$Globals::monstersList->{actors}{'monster-1'}{pos_to} = { x => 12, y => 10 };
start_cast();
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'a player walking toward the target is gated by predicted current position, not destination',
);
$Globals::char->{predicted_pos} = { x => 11, y => 10 };
run_after(0.01);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'the moving player attacks after the predicted position enters range',
);

reset_fixture();
$Globals::monstersList->{actors}{'monster-1'}{pos} = { x => 11, y => 10 };
$Globals::monstersList->{actors}{'monster-1'}{pos_to} = { x => 13, y => 10 };
$Globals::monstersList->{actors}{'monster-1'}{predicted_pos} = { x => 11, y => 10 };
start_cast();
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'a moving target is attacked when its predicted current position is in range',
);

reset_fixture();
start_cast();
run_after(0.10);
run_after(0.29);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'a missing server acknowledgement is not retried before 300 ms',
);
run_after(0.02);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1', 'monster-1'],
	'a missing server acknowledgement triggers a rate-limited retry',
);

reset_fixture();
start_cast();
run_after(0.10);
my $packet_attack_handler = sageFreeCastAttack->can('on_packet_attack');
$packet_attack_handler->(undef, {
	sourceID => 'self-id',
	targetID => 'monster-1',
	dmg => 100,
	type => 0,
}) if $packet_attack_handler;
run_after(0.31);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'a server-confirmed self attack stops further retries',
);

reset_fixture();
start_cast();
run_after(0.10);
sageFreeCastAttack::on_packet_attack(undef, {
	sourceID => 'other-actor',
	targetID => 'monster-1',
	dmg => 100,
	type => 0,
});
run_after(0.31);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1', 'monster-1'],
	'another actor attacking the target does not acknowledge our packet',
);

reset_fixture();
start_cast();
sageFreeCastAttack::on_packet_attack(undef, {
	sourceID => 'self-id',
	targetID => 'monster-1',
	dmg => 100,
	type => 0,
});
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'a pre-existing attack event cannot acknowledge a packet not yet sent',
);

reset_fixture();
start_cast();
my $cast_cancelled_handler = sageFreeCastAttack->can('on_cast_cancelled');
$cast_cancelled_handler->(undef, { sourceID => 'self-id' }) if $cast_cancelled_handler;
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'a self cast-cancel packet cancels the pending attack',
);

reset_fixture();
start_cast(castTime => 250);
run_after(0.10);
run_after(0.31);
is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'retries stop when the cast-time window has ended',
);

reset_fixture();
start_cast();
$AI::action_args{0}{ID} = 'monster-2';
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'a changed AI attack target cancels the pending packet',
);

reset_fixture();
start_cast();
delete $Globals::char->{casting};
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'a cast that ended without an attack acknowledgement cancels the pending packet',
);

reset_fixture();
$Globals::config{sageFreeCastAttack_debug} = 1;
start_cast();
run_after(0.10);
like(
	join('', @Log::messages),
	qr/scheduled.+send attempt 1/s,
	'debug mode reports the scheduled and transmitted attack attempt',
);

reset_fixture();
start_cast();
$Globals::config{sageFreeCastAttack} = 0;
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'disabling the plugin cancels an already pending packet',
);

reset_fixture();
start_cast();
$Globals::config{attackUseWeapon} = 0;
run_after(0.10);
is_deeply(
	\@TestChar::sent_attacks,
	[],
	'disabling weapon attacks cancels an already pending packet',
);

reset_fixture();
$Globals::config{sageFreeCastAttack_debug} = 1;
$Globals::monstersList->{actors}{'monster-1'}{pos_to} = { x => 13, y => 10 };
start_cast();
run_after(0.10);
$Globals::monstersList->{actors}{'monster-1'}{pos_to} = { x => 11, y => 10 };
run_after(0.01);
sageFreeCastAttack::on_packet_attack(undef, {
	sourceID => 'self-id',
	targetID => 'monster-1',
	dmg => 100,
	type => 0,
});
like(
	join('', @Log::messages),
	qr/waiting for weapon range.+send attempt 1.+acknowledged/s,
	'debug mode reports range waiting, transmission, and acknowledgement',
);

reset_fixture();
$Globals::config{sageFreeCastAttack_debug} = 1;
start_cast();
sageFreeCastAttack::on_cast_cancelled(undef, { sourceID => 'self-id' });
like(
	join('', @Log::messages),
	qr/cancelled: cast cancelled by server/,
	'debug mode reports why a pending attack was cancelled',
);

done_testing();
