package sageFreeCastAttack;

use strict;
use warnings;

use AI;
use Globals qw($accountID $char $monstersList %config);
use Plugins;

Plugins::register(
	'sageFreeCastAttack',
	'Keeps weapon attacks active while a Sage casts supported spells.',
	\&on_unload
);

my $hooks = Plugins::addHooks(
	['is_casting', \&on_is_casting, undef],
);

my %supported_skill_ids = (
	14 => 'MG_COLDBOLT',
	19 => 'MG_FIREBOLT',
	20 => 'MG_LIGHTNINGBOLT',
	21 => 'MG_THUNDERSTORM',
);

sub on_unload {
	Plugins::delHooks($hooks) if $hooks;
}

sub on_is_casting {
	my (undef, $args) = @_;

	return unless $args;
	return unless $config{sageFreeCastAttack};
	return unless $config{attackUseWeapon};
	return unless $char && $char->getSkillLevelByHandle('SA_FREECAST') > 0;
	return unless defined $accountID
		&& defined $args->{sourceID}
		&& $args->{sourceID} eq $accountID;
	return unless defined $args->{skillID}
		&& exists $supported_skill_ids{$args->{skillID}};
	return unless ($args->{castTime} || 0) > 0;

	my $attack_index = AI::findAction('attack');
	return unless defined $attack_index;

	my $attack_args = AI::args($attack_index);
	return unless $attack_args && defined $attack_args->{ID};

	my $target = $monstersList && $monstersList->getByID($attack_args->{ID});
	return unless $target && !$target->{dead};

	$char->sendAttack($attack_args->{ID});
}

1;
