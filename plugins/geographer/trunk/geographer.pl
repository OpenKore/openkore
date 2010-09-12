#------------------------------------------------------------
# Geographer plugin - OpenKore Team
#
# Prohibit attacking a geographer:
# + healed by another one
# + situated too close to another one
# Stop attacking monsters under above circumstances
# (prohibit to attack means setting up null damage from kore
# and 1 damage from player (from kore's id))
#------------------------------------------------------------

package geographer;

use strict;
use Globals;
use Log;
use Misc;
use Plugins;
use Utils;

Plugins::register("geographer", "Reaction on two close geographers", \&Unload);
my $hooks = Plugins::addHooks(
	["AI_pre",\&positionReact, undef],
	["packet/skill_cast", \&healReact, undef],
	["packet/skill_used_no_damage", \&healReact, undef]);

sub positionReact {
	foreach (@monstersID) {
		my $monster = $monsters{$_};
		if ($monster->{type} == 1368 && !$monster->{dmgFromPlayer}) {
			foreach my $mobCopy (@monstersID) {
				my $monsterCopy = $monsters{$mobCopy};
				if ($monsterCopy->{type} == 1368) {
					if ($monster->{ID} ne $monsterCopy->{ID}) {
					  	if (distance($monster->{pos},$monsterCopy->{pos}) <= 10) {
							prohibitAttacking($monster);
							prohibitAttacking($monsterCopy);
							last;
						}
					}
				}
			}
		}
	}
}
sub healReact {
# After cast, not before
	my $monsterS = $monsters{@_[1]->{sourceID}};
	my $monsterO = $monsters{@_[1]->{targetID}};
	if(!$monsterO
	  || @_[1]->{skillID} != 28
	  || $monsterO->{type} != 1368) {
		return;
	}
	prohibitAttacking($monsterO);
	if ($monsterS->{type} == 1368) {
		prohibitAttacking($monsterS);
	}
}
sub prohibitAttacking {
	undef @_[0]->{dmgFromYou};
	undef @_[0]->{missedFromYou};
	@_[0]->{dmgFromPlayer}{$char->{ID}} = 1;
	if (AI::action eq "attack" && AI::args()->{ID} eq @_[0]->{ID}) {
		$char->dequeue;
		$char->stopAttack;
	}
}
sub Unload {
	Plugins::delHooks($hooks);
}
1;