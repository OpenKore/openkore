package AntiKSTest;

use strict;
use warnings;

use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use lib "$RealBin/lib";
use Test::More;

use OpenKoreTestStubs;
use Globals;
use Misc;

sub start {
	subtest 'antiKS defaults to allowing a monster already damaged by another player' => sub {
		my ($monster, $lists) = _foreign_owned_monster();
		local %Misc::config = (attackAuto => 2, attackAuto_party => 0);
		local $Misc::char = _character();
		local $Misc::playersList = $lists->{players};
		local $Misc::slavesList = $lists->{slaves};
		local $Misc::monstersList = $lists->{monsters};
		local *Misc::objectInsideSpell = sub { return 0; };
		local *Misc::objectInsideCasting = sub { return 0; };
		local *Misc::objectIsMovingTowardsPlayer = sub { return 0; };

		is(
			Misc::checkMonsterCleanness($monster->{ID}),
			1,
			'player AI may select a monster damaged by another player when antiKS is omitted',
		);
		done_testing();
	};

	subtest 'antiKS disabled accepts the same target for a slave' => sub {
		my ($monster, $lists) = _foreign_owned_monster();
		local %Misc::config = (
			attackAuto => 2,
			attackAuto_party => 0,
			homunculus_attackAuto => 2,
			homunculus_attackAuto_party => 0,
			antiKS => 0,
		);
		local $Misc::char = _character();
		local $Misc::playersList = $lists->{players};
		local $Misc::slavesList = $lists->{slaves};
		local $Misc::monstersList = $lists->{monsters};
		local *Misc::objectInsideSpell = sub { return 0; };
		local *Misc::objectInsideCasting = sub { return 0; };
		local *Misc::objectIsMovingTowardsPlayer = sub { return 0; };

		my $slave = {ID => 'slave', configPrefix => 'homunculus_'};
		is(
			Misc::slave_checkMonsterCleanness($slave, $monster->{ID}),
			1,
			'slave AI may select a monster damaged by another player when antiKS is disabled',
		);
		done_testing();
	};

	subtest 'antiKS enabled preserves the existing ownership protection' => sub {
		my ($monster, $lists) = _foreign_owned_monster();
		local %Misc::config = (attackAuto => 2, attackAuto_party => 0, antiKS => 1);
		local $Misc::char = _character();
		local $Misc::playersList = $lists->{players};
		local $Misc::slavesList = $lists->{slaves};
		local $Misc::monstersList = $lists->{monsters};
		local *Misc::objectInsideSpell = sub { return 0; };
		local *Misc::objectInsideCasting = sub { return 0; };
		local *Misc::objectIsMovingTowardsPlayer = sub { return 0; };

		is(
			Misc::checkMonsterCleanness($monster->{ID}),
			0,
			'player AI still rejects a monster damaged by another player when antiKS is enabled',
		);
		done_testing();
	};

	subtest 'antiKS enabled preserves the existing ownership protection for a slave' => sub {
		my ($monster, $lists) = _foreign_owned_monster();
		local %Misc::config = (
			attackAuto => 2,
			attackAuto_party => 0,
			homunculus_attackAuto => 2,
			homunculus_attackAuto_party => 0,
			antiKS => 1,
		);
		local $Misc::char = _character();
		local $Misc::playersList = $lists->{players};
		local $Misc::slavesList = $lists->{slaves};
		local $Misc::monstersList = $lists->{monsters};
		local *Misc::objectInsideSpell = sub { return 0; };
		local *Misc::objectInsideCasting = sub { return 0; };
		local *Misc::objectIsMovingTowardsPlayer = sub { return 0; };

		my $slave = {ID => 'slave', configPrefix => 'homunculus_'};
		is(
			Misc::slave_checkMonsterCleanness($slave, $monster->{ID}),
			0,
			'slave AI still rejects a monster damaged by another player when antiKS is enabled',
		);
		done_testing();
	};
}

sub _foreign_owned_monster {
	my $monster = {
		ID => 'monster',
		dmgFromParty => 0,
		castOnByParty => 0,
		missedFromParty => 0,
		dmgToParty => 0,
		castOnToParty => 0,
		missedToParty => 0,
		missedFromPlayer => {},
		dmgFromPlayer => {other_player => 1},
		castOnByPlayer => {},
		missedToPlayer => {},
		dmgToPlayer => {},
		castOnToPlayer => {},
		dmgToYou => 0,
		missedYou => 0,
		castOnToYou => 0,
		dmgFromYou => 0,
		missedFromYou => 0,
		castOnByYou => 0,
	};

	my $lists = {
		players => AntiKSTest::List->new({}),
		slaves => AntiKSTest::List->new({}),
		monsters => AntiKSTest::List->new({$monster->{ID} => $monster}),
	};
	return ($monster, $lists);
}

sub _character {
	return {
		ID => 'self',
		slaves => {slave => 1},
		party => {joined => 0, users => {}},
	};
}

package AntiKSTest::List;

sub new {
	my ($class, $items) = @_;
	return bless {items => $items}, $class;
}

sub getByID {
	my ($self, $id) = @_;
	return $self->{items}{$id};
}

1;
