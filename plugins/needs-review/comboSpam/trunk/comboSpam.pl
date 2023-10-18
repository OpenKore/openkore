package comboSpam;

use strict;
use Plugins;
use Globals;
use Commands;
use Log qw(message);
use List::Util qw(max);
use Time::HiRes qw(&time);

Plugins::register('comboSpam', 'spam combo packets', \&Unload, \&Reload);

my $hooks = Plugins::addHooks(
	['AI_pre', \&onLoop],
	['is_casting', \&onSkillCast],
	['packet_skilluse', \&onSkillUse],
	['packet_skillfail', \&onSkillFail]
);

my %report = ();
my %sequence = (
	263 => new Skill(idn => 272), # Raging Trifecta Blow  > Raging Quadruple Blow
	272 => new Skill(idn => 273), # Raging Quadruple Blow > Raging Thrust
	273 => new Skill(idn => 371), # Raging Thrust         > Glacier Fist
	371 => new Skill(idn => 372), # Glacier Fist          > Chain Crush Combo
	372 => undef
);

my $time;
my $skillId;
my $delay = 0.2;
my $commands = Commands::register(
	['combos', '', sub {
		foreach my $skill (sort %sequence) {
			next unless defined $skill && $skill->isa('Skill') && $report{$skill->getIDN()};
			message sprintf("%s: %s\n", $skill->getName(), $report{$skill->getIDN()}), 'info';
		}
	}]
);

sub Unload {
	foreach my $hook (@{$hooks}) {
		Plugins::delHook($hook);
	}
	Commands::unregister($commands);
	undef @{$hooks};
}

sub Reload {
	&Unload;
}

sub onLoop {
	my ($self, $args) = @_;

	return unless Utils::timeOut($time, $delay);
	$time = time;

	# return if($char->{statuses}->{EFST_POSTDELAY});
	return unless defined $skillId && exists $sequence{$skillId};
	return unless AI::inQueue('attack');

	my $skill = $sequence{$skillId};
	return unless defined $skill && $skill->isa('Skill');

	my $level = $char->getSkillLevel($skill);
	my $handle = $skill->getHandle();
	return unless $level > 0;

	# SP Cost: (Skill Level + 10) || 2 + (Skill Level × 2)
	my $skillSp = $char->{skills}{$handle}{sp} || max(10 + $level, 2 + ($level * 2));
	return unless $char->{sp} >= $skillSp;
	return unless $handle eq 'MO_CHAINCOMBO' || $char->{spirits} > 0;

	$messageSender->sendSkillUse($skill->getIDN(), $level, $accountID);
}

sub onSkillCast {
	my ($self, $args) = @_;
	undef $skillId;
}

sub onSkillFail {
	my ($hookName, $args) = @_;
	my $skillId = $args->{skillID};
	$args->{warn} = exists $sequence{$skillId} ? 0 : 1;
}

sub onSkillUse {
	my ($self, $args) = @_;

	$skillId = $args->{skillID};

    $report{$skillId} ||= 0;
    $report{$skillId}++;
}

1; 
