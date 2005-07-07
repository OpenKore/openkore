############################
# MonsterDB plugin for OpenKore by Damokles
#
# This software is open source, licensed under the GNU General Public
# License, version 2.
#
# This plugin extends all functions which use 'checkMonsterCondition'.
# Basically these are AttackSkillSlot, equipAuto, AttackComboSlot, monsterSkill.
#
# Following new checks are possible:
#
# target_Element (list)
# target_notElement (list)
# target_Race (list)
# target_notRace (list)
# target_Size (list)
# target_notSize (list)
# target_hpLeft (range)
#
# For the element names just scroll a bit down and you'll find it.
#
############################

package monsterDB;

use strict;
use Plugins;
use Globals qw(%config %monsters $accountID);
use Settings;
use Log qw(message warning error debug);
use Utils;


Plugins::register('monsterDB', 'extends Monster infos', \&onUnload,\&onReload);
my $hooks = Plugins::addHooks(
	['checkMonsterCondition', \&extendedCheck, undef],
	['packet/skill_use', \&onPacketSkillUse, undef],
	['packet/skill_use_no_damage', \&onPacketSkillUseNoDamage, undef],
	['packet/actor_action', \&onPacketAttack,undef]
);


my %monsterDB;
my @element_lut = ('Neutral','Water','Earth','Fire','Wind','Poison','Holy','Dark','Sense','Undead');
my @race_lut = ('Formless','Undead','Brute','Plant','Insect','Fish','Demon','Demi-Human','Angel','Dragon');
my @size_lut = ('Small','Medium','Large');
debug ("MonsterDB: Finished init.\n",'monsterDB',2);
loadMonDB(); # Load MonsterDB into Memory

sub onUnload {
    Plugins::delHooks($hooks);
    %monsterDB = undef;
}

sub onReload {
	onUnload();
	loadMonDB();
}

sub loadMonDB {
	%monsterDB = undef;
	debug ("MonsterDB: Loading DataBase\n",'monsterDB',2);
	error ("MonsterDB: cannot load $Settings::tables_folder/monsterDB.txt\n",'monsterDB',0) unless (-r "$Settings::tables_folder/monsterDB.txt");
	open MDB ,"<$Settings::tables_folder/monsterDB.txt";
	foreach my $line (<MDB>) {
		$line =~ /([\w\s]+?)\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/;
		$monsterDB{$1} = [$2,$3,$4,$5];
	}
	close MDB;
}

sub extendedCheck {
    my ($hookName,$args) = @_;

	return 1 if !$args->{monster} || $args->{monster}->{name} eq '';

	my $monsterName = lc($args->{monster}->{name});

    if (!$monsterDB{$monsterName}[0]) {
    	debug("monsterDB: Monster {$args->{monster}->{name}} not found\n", 'monsterDB', 2);
    	return 1;
    } #return if monster is not in DB

    my $element = $element_lut[$monsterDB{$monsterName}[1]];
    my $race = $race_lut[$monsterDB{$monsterName}[2]];
    my $size = $size_lut[$monsterDB{$monsterName}[3]];

	if (main::whenStatusActiveMon($args->{monster},'Petrified')) {
		$element = 'Earth';
		debug("monsterDB: Monster $args->{monster}->{name} is petrified changing element to Earth\n", 'monsterDB', 3);
	}

	if (main::whenStatusActiveMon($args->{monster},'Frozen')) {
		$element = 'Water';
		debug("monsterDB: Monster $args->{monster}->{name} is frozen changing element to Water\n", 'monsterDB', 3);
	}

	if ($args->{monster}->{element} && $args->{monster}->{element} ne '') {
		$element = $args->{monster}->{element};
		debug("monsterDB: Monster $args->{monster}->{name} has changed element to $args->{monster}->{element}\n", 'monsterDB', 3);
	}

    if ($config{$args->{prefix} . '_Element'}
    && !existsInList($config{$args->{prefix} . '_Element'},$element)) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notElement'}
    && existsInList($config{$args->{prefix} . '_notElement'},$element)) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_Race'}
    && !existsInList($config{$args->{prefix} . '_Race'},$race)) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notRace'}
    && existsInList($config{$args->{prefix} . '_notRace'},$race)) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_Size'}
    && !existsInList($config{$args->{prefix} . '_Size'},$size)) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notSize'}
    && existsInList($config{$args->{prefix} . '_notSize'},$size)) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_hpLeft'}
    && !inRange(($monsterDB{$monsterName}[0] + $args->{monster}->{deltaHp}),$config{$args->{prefix} . '_hpLeft'})) {
		return $args->{return} = 0;
    }
}

sub onPacketSkillUse {
	my ($hookName,$args) = @_;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{name};
	my $monsterName = lc($monsters{$args->{targetID}}{name});
	message 'Monster has ['.($monsterDB{$monsterName}[0] + $monsters{$args->{targetID}}{deltaHp}).'/'.$monsterDB{$monsterName}[0]."] HP Left\n",'monsterDB';
}

sub onPacketSkillUseNoDmg {
	my ($hookName,$args) = @_;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{name};
	my $monsterName = lc($monsters{$args->{targetID}}{name});
	message 'Monster has ['.($monsterDB{$monsterName}[0] + $monsters{$args->{targetID}}{deltaHp}).'/'.$monsterDB{$monsterName}[0]."] HP Left\n",'monsterDB';
	if (($args->{targetID} eq $args->{sourceID}) && ($args->{targetID} ne $accountID)){
		if ($args->{skillID} eq 'NPC_CHANGEWATER'){
			$monsters{$args->{targetID}}{element} = 'Water';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEGROUND'){
			$monsters{$args->{targetID}}{element} = 'Earth';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEFIRE'){
			$monsters{$args->{targetID}}{element} = 'Fire';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEWIND'){
			$monsters{$args->{targetID}}{element} = 'Wind';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEPOISON'){
			$monsters{$args->{targetID}}{element} = 'Poison';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEHOLY'){
			$monsters{$args->{targetID}}{element} = 'Holy';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEDARKNESS'){
			$monsters{$args->{targetID}}{element} = 'Dark';
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGETELEKINESIS'){
			$monsters{$args->{targetID}}{element} = 'Sense';
			return 1;
		}
	}
}

sub onPacketAttack {
	my (undef,$args) = @_;
	return 1 unless $args->{type} == 0 || $args->{type} > 3;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{name};
	my $monsterName = lc($monsters{$args->{targetID}}{name});
	message 'Monster has ['.($monsterDB{$monsterName}[0] + $monsters{$args->{targetID}}{deltaHp}).'/'.$monsterDB{$monsterName}[0]."] HP Left\n",'monsterDB';

}


1;
