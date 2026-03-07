###########################
# eCast plugin for OpenKore by Henrybk
#
# This plugin is based on the work of Damokles, kaliwanagan and xlr82xs
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
# target_notImmovable boolean
#
#
# For the element names just scroll a bit down and you'll find it.
# You can check for element Lvls too, eg. target_Element Dark4
#

package eCast;

use strict;
use Plugins;
use Globals;
use Settings;
use Log qw(message warning error debug);
use Misc qw(bulkConfigModify isCellOccupied);
use Translation qw(T TF);
use Utils;
use AI;
use POSIX qw(floor);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use YAML::XS 'LoadFile';

use constant {
	PLUGIN_NAME => 'eCast',
};

Plugins::register(PLUGIN_NAME, 'Extends Skill Selection and Placement', \&onUnload);

my $hooks = Plugins::addHooks(
	['start3',						\&on_start3, undef],
	['checkMonsterCondition', \&extendedCheck, undef],
	['packet_skilluse', \&onPacketSkillUse, undef],
	['packet/skill_use_no_damage', \&onPacketSkillUseNoDamage, undef],
	['packet_attack', \&onPacketAttack, undef],
	['check_attackLooter', \&oncheck_attackLooter, undef],
);

our $folder = $Plugins::current_plugin_folder;

my $mobs_info;

my %mobs_db;

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

my %ai_constant = (
        '01' => 0x81, '02' => 0x83, '03' => 0x1089, '04' => 0x3885,
        '05' => 0x2085, '06' => 0, '07' => 0x108B, '08' => 0x7085,
        '09' => 0x3095, '10' => 0x84, '11' => 0x84, '12' => 0x2085,
        '13' => 0x308D, '17' => 0x91, '19' => 0x3095, '20' => 0x3295,
        '21' => 0x3695, '24' => 0xA1, '25' => 0x1, '26' => 0xB695,
        '27' => 0x8084, 'ABR_PASSIVE' => 0x21, 'ABR_OFFENSIVE' => 0xA5
);

=pod
/// Monster mode definitions to clear up code reading. [Skotlex]
enum e_mode {
	MD_NONE					= 0x0000000,
	MD_CANMOVE				= 0x0000001,
	MD_LOOTER				= 0x0000002,
	MD_AGGRESSIVE			= 0x0000004,
	MD_ASSIST				= 0x0000008,
	MD_CASTSENSORIDLE		= 0x0000010,
	MD_NORANDOMWALK			= 0x0000020,
	MD_NOCAST				= 0x0000040,
	MD_CANATTACK			= 0x0000080,
	//FREE					= 0x0000100,
	MD_CASTSENSORCHASE		= 0x0000200,
	MD_CHANGECHASE			= 0x0000400,
	MD_ANGRY				= 0x0000800,
	MD_CHANGETARGETMELEE	= 0x0001000,
	MD_CHANGETARGETCHASE	= 0x0002000,
	MD_TARGETWEAK			= 0x0004000,
	MD_RANDOMTARGET			= 0x0008000,
	MD_IGNOREMELEE			= 0x0010000,
	MD_IGNOREMAGIC			= 0x0020000,
	MD_IGNORERANGED			= 0x0040000,
	MD_MVP					= 0x0080000,
	MD_IGNOREMISC			= 0x0100000,
	MD_KNOCKBACKIMMUNE		= 0x0200000,
	MD_TELEPORTBLOCK		= 0x0400000,
	//FREE					= 0x0800000,
	MD_FIXEDITEMDROP		= 0x1000000,
	MD_DETECTOR				= 0x2000000,
	MD_STATUSIMMUNE			= 0x4000000,
	MD_SKILLIMMUNE			= 0x8000000,
};
=cut

sub onUnload {
	Plugins::delHooks($hooks);
	undef %mobs_db;
	undef $mobs_info;
}

sub oncheck_attackLooter {
	my ($hook, $args) = @_;
	return 0 if (!$args->{monster} || $args->{monster}->{nameID} eq '');

	if (!exists $mobs_db{$args->{monster}->{nameID}}) {
		Log::warning("[eCast] [oncheck_attackLooter] : Monster {name '$args->{monster}->{name}'} {ID '$args->{monster}->{nameID}'} not found\n", 'eCast');
		return;
	}

	my $mob = $mobs_db{$args->{monster}->{nameID}};
	my $ai = $mob->{Ai};
	my $is_looter = is_monster_ai_looter($ai);
	if (!$is_looter) {
		Log::debug("[eCast] [oncheck_attackLooter] [False] $args->{monster} ($args->{monster}->{nameID}) is a not Looter\n", 'eCast');
		$args->{return} = 1;
	} else {
		Log::debug("[eCast] [oncheck_attackLooter] [True] $args->{monster} ($args->{monster}->{nameID}) is a Looter\n", 'eCast');
	}
}

sub is_monster_ai_looter {
    my ($ai_str) = @_;
    $ai_str = uc($ai_str);  # Normalize to uppercase

    # Use the AI's value if defined, else default to '06' (0)
    my $mode_value = exists $ai_constant{$ai_str} 
                   ? $ai_constant{$ai_str} 
                   : $ai_constant{'06'};

    # Check if MD_LOOTER bit (0x2) is set
    return ($mode_value & 0x2) ? 1 : 0;
}

sub on_start3 {
    $mobs_info = LoadFile((File::Spec->catdir($folder,'mob_db.yml')));
	if (!defined $mobs_info) {
		error "[".PLUGIN_NAME."] Could not load mobs info due to a file loading problem.\n.";
		return;
	}
	
	#Log::warning Data::Dumper::Dumper ($mobs_info);
	
	my @list = (qw(Id AegisName Name JapaneseName Level Hp Sp BaseExp JobExp MvpExp Attack Attack2 Defense MagicDefense Resistance MagicResistance Str Agi Vit Int Dex Luk AttackRange SkillRange ChaseRange Size Race Element ElementLevel WalkSpeed AttackDelay AttackMotion DamageMotion DamageTaken Ai Class));
	my @deaf = (qw(0 xxx xxx xxx 1 1 1 0 0 0 0 0 0 0 0 0 1 1 1 1 1 1 0 0 0 Small Formless Neutral 1 150 0 0 0 100 06 Normal));
	my $i = 0;
	foreach my $mob (@{$mobs_info->{'Body'}}) {
		next unless (exists $mob->{Id} && defined $mob->{Id});
		my $ID = $mob->{Id};
		
		foreach my $index (0..$#list) {
			my $key = $list[$index];
			my $default = $deaf[$index];
			if (exists $mob->{$key}) {
				$mobs_db{$ID}{$key} = $mob->{$key};
			} else {
				$mobs_db{$ID}{$key} = $default;
			}
		}
		$i++;
	}
	
	#Log::warning Data::Dumper::Dumper (\%mobs_db);
	
	message TF("%d monsters in database\n", $i), 'mobs_db';
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

	if (!exists $mobs_db{$args->{monster}->{nameID}}) {
		Log::warning("eCast: Monster {name '$args->{monster}->{name}'} {ID '$args->{monster}->{nameID}'} not found\n", 'eCast');
		return 0;
	}

	my $ID = $args->{monster}->{nameID};
	my $mob = $mobs_db{$args->{monster}->{nameID}};
	
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
	&& !inRange(($mob->{Hp} + $args->{monster}->{deltaHp}),$config{$args->{prefix} . '_hpLeft'})) {
	return $args->{return} = 0;
	}

	if ($config{$args->{prefix} . '_Level'}
	&& !inRange(($mob->{Level}),$config{$args->{prefix} . '_Level'})) {
	return $args->{return} = 0;
	}

	#my $skillLevel = $config{$skillBlock.'_lvl'};
	
	#my $potentialDamage = calcSkillDamage($config{$skillBlock.'_damageFormula'}, $config{$skillBlock.'_lvl'}, int($args->{monster}->{nameID}), $config{$skillBlock.'_damageType'});
	#if ($config{$skillBlock.'_damageFormula'}
	#&& inRange(($mob->{Hp} + $args->{monster}->{deltaHp}),'>= '.$potentialDamage)) {
	#	debug("Rejected $config{$skillBlock} with estimated damage : $potentialDamage using skill level $skillLevel\n", 'eCast', 1);
	#	return $args->{return} = 0;
	#}

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
	return 1 unless my $monsterInfo = $mobs_db{$ID};
	$$message =~ s~(?=\n)~TF(" (Hp: %d/%d)", $mobs_db{$ID}{Hp} + $monster->{deltaHp}, $mobs_db{$ID}{Hp})~se;
}

1;