#
# eCast
# Author: Henrybk
#
# This plugin is based on the work of Damokles, kaliwanagan and xlr82xs.
#
# What this plugin does:
# This plugin extends monster condition checks used by OpenKore skill and
# equipment logic. It adds extra target filters based on monster database data
# from monsters_table.txt, plus a few runtime checks such as changed element,
# freeze/petrify overrides, and whether the cell behind the target is free.
#
# It mainly affects systems that rely on checkMonsterCondition, such as:
# - AttackSkillSlot
# - equipAuto
# - AttackComboSlot
# - monsterSkill
#
# Extra checks provided by this plugin:
# - target_Element
# - target_notElement
# - target_Race
# - target_notRace
# - target_Size
# - target_notSize
# - target_hpLeft
# - target_Level
# - target_cellBehindFree
#
# How to configure it:
# Use the normal skill or equipment condition prefixes in config.txt and add
# the extra eCast-specific target checks to them.
#
# Supported values:
# - Element names such as Neutral, Fire, Water, Earth, Wind, Poison, Holy,
#   Shadow, Ghost, Undead
# - Element plus level such as Dark4 or Fire2
# - Race names such as Formless, Undead, Brute, Plant, Insect, Fish, Demon,
#   Demi-Human, Angel, Dragon
# - Size values: Small, Medium, Large
# - Range values for HP and Level checks
# - target_cellBehindFree:
#   1 = require a free cell behind the target
#   0 = require that the cell behind the target is not free
#
# Examples:
# 1. Only cast a skill on Fire monsters:
#    attackSkillSlot_0_target_Element Fire
#
# 2. Only cast on Shadow level 4 targets:
#    attackSkillSlot_0_target_Element Shadow4
#
# 3. Avoid using a skill on Large monsters:
#    attackSkillSlot_0_target_notSize Large
#
# 4. Only cast when the target HP is in a certain range:
#    attackSkillSlot_0_target_hpLeft 0..5000
#
# 5. Only cast when the cell behind the target is free:
#    attackSkillSlot_0_target_cellBehindFree 1
#
# Notes:
# - This plugin reads monster data from monsters_table.txt.
# - If a monster changes element dynamically, the plugin uses the updated
#   runtime element instead of the default table value.
# - Petrified monsters are treated as Earth 1 and frozen monsters as Water 1.
#

package eCast;

use strict;
use Plugins;
use Globals;
use Log qw(message warning error debug);
use Misc qw(bulkConfigModify isCellOccupied);
use Translation qw(T TF);
use Utils;
use AI;
use POSIX qw(floor);

use constant {
	PLUGIN_NAME => 'eCast',
};

Plugins::register(PLUGIN_NAME, 'Extends Skill Selection and Placement', \&onUnload);

my $hooks = Plugins::addHooks(
	['checkMonsterCondition', \&extendedCheck, undef],
	['packet_skilluse', \&onPacketSkillUse, undef],
	['packet/skill_use_no_damage', \&onPacketSkillUseNoDamage, undef],
	['packet_attack', \&onPacketAttack, undef],
);

my @element_lut = qw(Neutral Water Earth Fire Wind Poison Holy Shadow Ghost Undead);
my @race_lut = qw(Formless Undead Brute Plant Insect Fish Demon Demi-Human Angel Dragon);
my @size_lut = qw(Small Medium Large);
my %skillChangeElement = qw(
	NPC_CHANGEWATER Water
	NPC_CHANGEGROUND Earth
	NPC_CHANGEFIRE Fire
	NPC_CHANGEWIND Wind
	NPC_CHANGEPOISON Poison
	NPC_CHANGEHOLY Holy
	NPC_CHANGEDARKNESS Shadow
	NPC_CHANGETELEKINESIS Ghost
);

sub onUnload {
	Plugins::delHooks($hooks);
}

# TODO: Revisar
sub extendedCheck {
	my (undef, $args) = @_;
	
	return 0 if (!$args->{monster} || $args->{monster}->{nameID} eq '');
	
	my $skillBlock;
	($skillBlock = $args->{prefix}) =~ s/_target//;

	if (defined $config{$args->{prefix} . '_cellBehindFree'}) {
		my $hasFreeCell = hasFreeCellBehind($args->{monster});
		if ($config{$args->{prefix} . '_cellBehindFree'} == 0 && $hasFreeCell) {
			debug("Will not cast $config{$skillBlock} on $args->{monster} because of free behind cell\n", 'eCast', 1);
			return $args->{return} = 0;
		} elsif ($config{$args->{prefix} . '_cellBehindFree'} == 1 && !$hasFreeCell) {
			debug("Will not cast $config{$skillBlock} on $args->{monster} because of occupied behind cell\n", 'eCast', 1);
			return $args->{return} = 0;
		}
	}

	if (!exists $monstersTable{$args->{monster}->{nameID}}) {
		Log::warning("eCast: Monster {name '$args->{monster}->{name}'} {ID '$args->{monster}->{nameID}'} not found\n", 'eCast');
		return 0;
	}

	my $ID = $args->{monster}->{nameID};
	my $mob = $monstersTable{$args->{monster}->{nameID}};
	
	my $element = $mob->{Element};
	my $element_lvl = $mob->{ElementLevel};
	my $race = $mob->{Race};
	my $size = $mob->{Size};

	if ($args->{monster}->{element} && $args->{monster}->{element} ne '') {
		$element = $args->{monster}->{element};
		debug("eCast: Monster $args->{monster}->{name} has changed element to $args->{monster}->{element}\n", 'eCast', 3);
	}

	if ($args->{monster}->statusActive('BODYSTATE_STONECURSE, BODYSTATE_STONECURSE_ING')) {
		$element = 'Earth';
		$element_lvl = 1;
		debug("eCast: Monster $args->{monster}->{name} is petrified changing element to Earth\n", 'eCast', 3);
	}

	if ($args->{monster}->statusActive('BODYSTATE_FREEZING')) {
		$element = 'Water';
		$element_lvl = 1;
		debug("eCast: Monster $args->{monster}->{name} is frozen changing element to Water\n", 'eCast', 3);
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
	&& !inRange(($mob->{HP} + $args->{monster}->{deltaHp}),$config{$args->{prefix} . '_hpLeft'})) {
	return $args->{return} = 0;
	}

	if ($config{$args->{prefix} . '_Level'}
	&& !inRange(($mob->{Level}),$config{$args->{prefix} . '_Level'})) {
	return $args->{return} = 0;
	}

	return 1;
}

sub hasFreeCellBehind {
	my ($monster) = @_;

	my $charPos = calcPosFromPathfinding($field, $char);
	my $targetPos = calcPosFromPathfinding($field, $monster);
	
	my $dir = map_calc_dir_xy($charPos->{x}, $charPos->{y}, $targetPos->{x}, $targetPos->{x}); 

	my ($x, $y);

	if ($dir > 0 && $dir < 4) {
		$x = -1;
	} 
	elsif ($dir > 4) {
		$x = 1;
	} 
	else {
		$x = 0;
	}

	if ($dir > 2 && $dir < 6) {
		$y = -1;
	} 
	elsif ($dir == 7 || $dir < 2) {
		$y = 1;
	} 
	else {
		$y = 0;
	}

	my $fx = $targetPos->{x} + $x;
	my $fy = $targetPos->{y} + $y;

	return 0 unless ($field->isWalkable($fx, $fy));
	return 0 if (isCellOccupied({ x=> $fx, y=> $fy }));

	
	return 1;
}

sub map_calc_dir_xy {
    my ($srcx, $srcy, $x, $y) = @_;
    my $dx = $x - $srcx;
    my $dy = $y - $srcy;

    if ($dx == 0 && $dy == 0) {
        # Same position: use knockback_left setting if available, else default to srcdir
        return 6;
    }
    elsif ($dx >= 0 && $dy >= 0) {  # Upper-right quadrant
        return 6 if ($dx >= 3 * $dy);     # Right
        return 0 if (3 * $dx < $dy);      # Up
        return 7;                         # Up-right
    }
    elsif ($dx >= 0 && $dy <= 0) {  # Lower-right quadrant
        return 6 if ($dx >= -3 * $dy);    # Right
        return 4 if (3 * $dx < -$dy);     # Down
        return 5;                         # Down-right
    }
    elsif ($dx <= 0 && $dy <= 0) {  # Lower-left quadrant
        return 4 if (3 * $dx >= $dy);     # Down (dy negative, dx negative)
        return 2 if ($dx < 3 * $dy);      # Left
        return 3;                         # Down-left
    }
    else {                          # Upper-left quadrant (dx <=0, dy>=0)
        return 0 if (3 * -$dx <= $dy);    # Up
        return 2 if (-$dx > 3 * $dy);     # Left
        return 1;                         # Up-left
    }
}

# TODO: Revisar
sub onPacketSkillUse { monsterHp($monsters{$_[1]->{targetID}}, $_[1]->{disp}) if $_[1]->{disp} }

# TODO: Revisar
sub onPacketSkillUseNoDmg {
	my (undef,$args) = @_;
	return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{nameID};
	if (
		$args->{targetID} eq $args->{sourceID} && $args->{targetID} ne $accountID
		&& $skillChangeElement{$args->{skillID}}
	) {
		$monsters{$args->{targetID}}{element} = $skillChangeElement{$args->{skillID}};
		#monsterEquip($monsters{$args->{targetID}});
		return 1;
	}
}

# TODO: Revisar
sub onPacketAttack { monsterHp($monsters{$_[1]->{targetID}}, $_[1]->{msg}) if $_[1]->{msg} }

# TODO: Revisar
sub monsterHp {
	my ($monster, $message) = @_;
	return 1 unless $monster && $monster->{nameID};
	my $ID = int($monster->{nameID});
	return 1 unless my $monsterInfo = $monstersTable{$ID};
	$$message =~ s~(?=\n)~TF(" (Hp: %d/%d)", $monsterInfo->{HP} + $monster->{deltaHp}, $monsterInfo->{HP})~se;
}

1;
