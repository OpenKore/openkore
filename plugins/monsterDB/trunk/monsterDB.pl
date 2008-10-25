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
# In equipAuto you have to leave the target_ part,
# this is due some coding inconsistency in the funtions.pl
#
# You can use monsterEquip if you think that equipAuto is to slow.
# It supports the new equip syntax. It is event-driven and is called
# when a monster: is attacked, changes status, changes element
#
# Note: It will check all monsterEquip blocks but it respects priority.
# If you check in the first block for element fire and in the second
# for race Demi-Human and in both you use different arrows but in the
# Demi-Human block you use a bow, it will take the arrows form the first
# matching block and equip the bow since the fire block didn't specified it.
#
#
# Note: monsterEquip will modify your attackEquip_{slot} so don't be surprised
# about having other attackEquips as you set before.
#
# Be careful with right and leftHand those slots will not be checked for
# two-handed weapons that may conflict.
#
# Example:
# monsterEquip {
# 	target_Element Earth
# 	equip_arrow Fire Arrow
# }
#
# For the element names just scroll a bit down and you'll find it.
# You can check for element Lvls too, eg. target_Element Dark4
#
# $Revision: 5549 $
# $Id: monsterDB.pl 5549 2007-03-21 00:55:47Z h4rry_84 $
############################

package monsterDB;

use strict;
use Plugins;
use Globals qw(%config %monsters $accountID %equipSlot_lut @ai_seq @ai_seq_args);
use Settings;
use Log qw(message warning error debug);
use Misc qw(whenStatusActiveMon bulkConfigModify);
use Utils;


Plugins::register('monsterDB', 'extends Monster infos', \&onUnload);
my $hooks = Plugins::addHooks(
	['checkMonsterCondition', \&extendedCheck, undef],
	['packet/skill_use', \&onPacketSkillUse, undef],
	['packet/skill_use_no_damage', \&onPacketSkillUseNoDamage, undef],
	['packet/actor_action', \&onPacketAttack,undef],
	['attack_start', \&onAttackStart,undef],
	['changed_status', \&onStatusChange,undef]
);


my @monsterDB;
my @element_lut = ('Neutral','Water','Earth','Fire','Wind','Poison','Holy','Dark','Sense','Undead');
my @race_lut = ('Formless','Undead','Brute','Plant','Insect','Fish','Demon','Demi-Human','Angel','Dragon');
my @size_lut = ('Small','Medium','Large');
debug ("MonsterDB: Finished init.\n",'monsterDB',2);
loadMonDB(); # Load MonsterDB into Memory

sub onUnload {
    Plugins::delHooks($hooks);
    @monsterDB = undef;
}

sub loadMonDB {
	@monsterDB = undef;
	my @temp;
	debug ("MonsterDB: Loading DataBase\n",'monsterDB',2);
	error ("MonsterDB: cannot load $Settings::tables_folder/monsterDB.txt\n",'monsterDB',0) unless (-r "$Settings::tables_folder/monsterDB.txt");
	open MDB ,"<$Settings::tables_folder/monsterDB.txt";
	@temp = <MDB>;
	close MDB;
	my $i = 0;
	foreach my $line (@temp) {
		next unless ($line =~ /(\d{4})\s+(\d+)\s+(\d)\s+(\d)\s+(\d+)/);
		$monsterDB[(int($1) - 1000)] = [$2,$3,$4,$5];
		$i++;
	}
	message "MonsterDB: loaded $i Monsters\n",'monsterDB';
}

sub extendedCheck {
    my (undef,$args) = @_;

	return 0 if !$args->{monster} || $args->{monster}->{nameID} eq '';

	my $monsterInfo = $monsterDB[(int($args->{monster}->{nameID}) - 1000)];

    if (!defined $monsterInfo) {
    	debug("monsterDB: Monster {$args->{monster}->{name}} not found\n", 'monsterDB', 2);
    	return 0;
    } #return if monster is not in DB


    my $element = $element_lut[($monsterInfo->[3] % 10)];
    my $element_lvl = int($monsterInfo->[3] / 20);
    my $race = $race_lut[$monsterInfo->[2]];
    my $size = $size_lut[$monsterInfo->[1]];

	if ($args->{monster}->{element} && $args->{monster}->{element} ne '') {
		$element = $args->{monster}->{element};
		debug("monsterDB: Monster $args->{monster}->{name} has changed element to $args->{monster}->{element}\n", 'monsterDB', 3);
	}

	if (whenStatusActiveMon($args->{monster},'Petrified')) {
		$element = 'Earth';
		debug("monsterDB: Monster $args->{monster}->{name} is petrified changing element to Earth\n", 'monsterDB', 3);
	}

	if (whenStatusActiveMon($args->{monster},'Frozen')) {
		$element = 'Water';
		debug("monsterDB: Monster $args->{monster}->{name} is frozen changing element to Water\n", 'monsterDB', 3);
	}

    if ($config{$args->{prefix} . '_Element'}
    && (!existsInList($config{$args->{prefix} . '_Element'},$element)
    	&& !existsInList($config{$args->{prefix} . '_Element'},$element.$element_lvl))) {
		return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notElement'}
    && (existsInList($config{$args->{prefix} . '_notElement'},$element)
    	|| existsInList($config{$args->{prefix} . '_notElement'},$element.$element_lvl))) {
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
    && !inRange(($monsterInfo->[0] + $args->{monster}->{deltaHp}),$config{$args->{prefix} . '_hpLeft'})) {
		return $args->{return} = 0;
    }

    return 1;
}

sub onPacketSkillUse {
	my (undef,$args) = @_;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{nameID};
	monsterHp ($monsters{$args->{targetID}});
}

sub onPacketSkillUseNoDmg {
	my (undef,$args) = @_;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{nameID};
	monsterHp ($monsters{$args->{targetID}});
	if (($args->{targetID} eq $args->{sourceID}) && ($args->{targetID} ne $accountID)){
		if ($args->{skillID} eq 'NPC_CHANGEWATER'){
			$monsters{$args->{targetID}}{element} = 'Water';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEGROUND'){
			$monsters{$args->{targetID}}{element} = 'Earth';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEFIRE'){
			$monsters{$args->{targetID}}{element} = 'Fire';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEWIND'){
			$monsters{$args->{targetID}}{element} = 'Wind';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEPOISON'){
			$monsters{$args->{targetID}}{element} = 'Poison';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEHOLY'){
			$monsters{$args->{targetID}}{element} = 'Holy';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGEDARKNESS'){
			$monsters{$args->{targetID}}{element} = 'Dark';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
		elsif ($args->{skillID} eq 'NPC_CHANGETELEKINESIS'){
			$monsters{$args->{targetID}}{element} = 'Sense';
			monsterEquip($monsters{$args->{targetID}});
			return 1;
		}
	}
}

sub onPacketAttack {
	my (undef,$args) = @_;
	return 1 unless $args->{type} == 0 || $args->{type} > 3;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{nameID};
	monsterHp ($monsters{$args->{targetID}});

}

sub monsterHp {
	my $monster = shift;
	return 1 unless $monster && $monster->{nameID};
	my $monsterInfo = $monsterDB[(int($monster->{nameID}) - 1000)];
	return 1 unless defined $monsterInfo;
	message 'Monster has ['.($monsterInfo->[0] + $monster->{deltaHp}).'/'.$monsterInfo->[0]."] HP Left\n",'attackMon';
}

sub onAttackStart {
	my (undef,$args) = @_;
	monsterEquip($monsters{$args->{ID}});
}

sub onStatusChange {
	my (undef, $args) = @_;

	return unless $args->{changed};
	my $actor = $args->{actor};
	return unless (UNIVERSAL::isa($actor, 'Actor::Monster'));
	my $index = binFind(\@ai_seq, 'attack');
	return unless defined $index;
	return unless $ai_seq_args[$index]->{target} == $actor->{ID};
	monsterEquip($actor);
}

sub monsterEquip {
	my $monster = shift;
	return unless $monster;
	my %equip_list;

	my %args = ('monster' => $monster);
	my $slot;

	for (my $i=0;exists $config{"monsterEquip_$i"};$i++) {
		$args{prefix} = "monsterEquip_${i}_target";
		if (extendedCheck(undef,\%args)) {
			foreach $slot (%equipSlot_lut) {
				if ($config{"monsterEquip_${i}_equip_$slot"}
				&& !$equip_list{"attackEquip_$slot"}
				&& defined Actor::Item::get($config{"monsterEquip_${i}_equip_$slot"})) {
					$equip_list{"attackEquip_$slot"} = $config{"monsterEquip_${i}_equip_$slot"};
					debug "monsterDB: using ".$config{"monsterEquip_${i}_equip_$slot"}."\n",'monsterDB';
				}
			}
		}
	}
	foreach (keys %equip_list) {
		$config{$_} = $equip_list{$_};
	}
	Actor::Item::scanConfigAndEquip('attackEquip');
}

1;
