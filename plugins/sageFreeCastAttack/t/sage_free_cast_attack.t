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

require "$FindBin::Bin/../sageFreeCastAttack.pl";

sub reset_fixture {
	@TestChar::sent_attacks = ();
	$TestChar::queued_attacks = 0;
	$AI::queue_calls = 0;
	$AI::attack_index = 0;
	%AI::action_args = (0 => { ID => 'monster-1' });

	$Globals::accountID = 'self-id';
	$Globals::char = bless {
		skills => { SA_FREECAST => { lv => 10 } },
	}, 'TestChar';
	$Globals::monstersList = bless {
		actors => {
			'monster-1' => bless({ ID => 'monster-1', dead => 0 }, 'Actor::Monster'),
		},
	}, 'TestMonsterList';
	%Globals::config = (
		sageFreeCastAttack => 1,
		attackUseWeapon => 1,
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
		skill => bless({ id => 19 }, 'Skill'),
		time => 100,
		castTime => 800,
		x => 0,
		y => 0,
		%overrides,
	};
}

reset_fixture();
sageFreeCastAttack::on_is_casting(undef, casting_event());

is_deeply(
	\@TestChar::sent_attacks,
	['monster-1'],
	'a supported self cast resumes the current weapon attack with one direct packet',
);
is($TestChar::queued_attacks, 0, 'the plugin does not add a duplicate character attack action');
is($AI::queue_calls, 0, 'the plugin does not add a duplicate AI queue entry');

my @supported_casts = (
	[14, 'Cold Bolt', {}],
	[19, 'Fire Bolt', {}],
	[20, 'Lightning Bolt', {}],
	[21, 'Thunder Storm', { targetID => '', target => undef, x => 50, y => 60 }],
);

reset_fixture();
for my $cast (@supported_casts) {
	my ($skill_id, undef, $event_overrides) = @{$cast};
	sageFreeCastAttack::on_is_casting(
		undef,
		casting_event(skillID => $skill_id, %{$event_overrides}),
	);
}
is_deeply(
	\@TestChar::sent_attacks,
	[('monster-1') x 4],
	'all four supported Sage spells resume the current attack, including ground-targeted Thunder Storm',
);

reset_fixture();
sageFreeCastAttack::on_is_casting(undef, casting_event(skillID => 18));
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
	sageFreeCastAttack::on_is_casting(undef, casting_event(%{$event_overrides}));
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
	sageFreeCastAttack::on_is_casting(undef, casting_event());
	is_deeply(\@TestChar::sent_attacks, [], "no packet is sent when $description");
}

done_testing();
