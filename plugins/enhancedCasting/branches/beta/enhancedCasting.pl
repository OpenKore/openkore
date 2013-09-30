###########################
# Enhanced Casting plugin for OpenKore by xlr82xs
#
# This software is open source, licensed under the GNU General Public
# License, version 2.
#
# This plugin is based on the work of Damokles and kaliwanagan
#
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
# target_immovable boolean
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
#    target_Element Earth
#    equip_arrow Fire Arrow
# }
#
# For the element names just scroll a bit down and you'll find it.
# You can check for element Lvls too, eg. target_Element Dark4
#
#
# new config block enhancedCasting <skill name> {}
# supports all the enhanced modifiers (except _hpLeft)
# ignores selected level and automatically selects it for you.
#

package enhancedCasting;

use 5.010;
use strict;
use Plugins;
use Globals;
use Settings;
use Log qw(message warning error debug);
use Misc qw(bulkConfigModify);
use Translation qw(T TF);
use Utils;
use AI;
use enum qw(BITMASK:MD_ CANMOVE LOOTER AGGRESSIVE ASSIST CASTSENSOR_IDLE BOSS PLANT CANATTACK DETECTOR CASTSENSOR_CHASE CHANGECHASE ANGRY CHANGETARGET_MELEE CHANGETARGET_CHASE TARGETWEAK RANDOMTARGET);
use POSIX qw(floor);
use Data::Dumper;

Plugins::register('enhancedCasting', 'Extends Skill Selection and Placement', \&onUnload);
my $hooks = Plugins::addHooks(
    ['checkMonsterCondition',      \&extendedCheck,            undef],
    ['packet_skilluse',            \&onPacketSkillUse,         undef],
    ['packet/skill_use_no_damage', \&onPacketSkillUseNoDamage, undef],
    ['packet_attack',              \&onPacketAttack,           undef],
    ['attack_start',               \&onAttackStart,            undef],
    ['changed_status',             \&onStatusChange,           undef],
    ['AI_post',                    \&choose,                   undef]
);

my %monsterDB;
my @element_lut = qw(Neutral Water Earth Fire Wind Poison Holy Shadow Ghost Undead);
my @race_lut = qw(Formless Undead Brute Plant Insect Fish Demon Demi-Human Angel Dragon);
my @size_lut           = qw(Small Medium Large);
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

my $currentTarget;
my %skillUse;
my %delay;

my %element_modifiers;

my %raw_modifiers;
$raw_modifiers{lvl1} = "
100     100     100     100     100     100     100     100     25      100
100     25      100     150     50      100     75      100     100     100
100     100     100     50      150     100     75      100     100     100
100     50      150     25      100     100     75      100     100     125
100     175     50      100     25      100     75      100     100     100
100     100     125     125     125     0       75      50      100     -25
100     100     100     100     100     100     0       125     100     150
100     100     100     100     100     50      125     0       100     -25
25      100     100     100     100     100     75      75      125     100
100     100     100     100     100     50      100     0       100     0";

$raw_modifiers{lvl2} = "
100     100     100     100     100     100     100     100     25      100
100     0       100     175     25      100     50      75      100     100
100     100     50      25      175     100     50      75      100     100
100     25      175     0       100     100     50      75      100     150
100     175     25      100     0       100     50      75      100     100
100     75      125     125     125     0       50      25      75      -50
100     100     100     100     100     100     -25     150     100     175
100     100     100     100     100     25      150     -25     100     -50
0       75      75      75      75      75      50      50      150     125
100     75      75      75      75      25      125     0       100     0";

$raw_modifiers{lvl3} = "
100     100     100     100     100     100     100     100     0       100
100     -25     100     200     0       100     25      50      100     125
100     100     0       0       200     100     25      50      100     75
100     0       200     -25     100     100     25      50      100     175
100     200     0       100     -25     100     25      50      100     100
100     50      100     100     100     0       25      0       50      -75
100     100     100     100     100     125     -50     175     100     200
100     100     100     100     100     0       175     -50     100     -75
0       50      50      50      50      50      25      25      175     150
100     50      50      50      50      0       150     0       100     0
";

$raw_modifiers{lvl4} = "
100     100     100     100     100     100     100     100     0       100
100     -50     100     200     0       75      0       25      100     150
100     100     -25     0       200     75      0       25      100     50
100     0       200     -50     100     75      0       25      100     200
100     200     0       100     -50     75      0       25      100     100
100     25      75      75      75      0       0       -25     25      -100
100     75      75      75      75      125     -100    200     100     200
100     75      75      75      75      -25     200     -100    100     -100
0       25      25      25      25      25      0       0       200     175
100     25      25      25      25      -25     175     0       100     0
";

for my $tlevel (1 .. 4) {
    my $x;
    foreach (split /^/, $raw_modifiers{'lvl' . $tlevel}) {
        next unless m/^\w+/;
        my $base       = $element_lut[$x++];
        my @emodifiers = (split);
        for my $i (0 .. $#element_lut) {
            $element_modifiers{$element_lut[$i] . $tlevel}->{$base} = $emodifiers[$i] / 100;
        }
    }
    delete $raw_modifiers{'lvl' . $tlevel};
}
undef %raw_modifiers;

debug("Enhanced Casting: Finished init.\n", 'enhancedCasting', 2);
loadMonDB();    # Load MonsterDB into Memory

sub onUnload {
    Plugins::delHooks($hooks);
    %monsterDB = undef;
}

sub choose {
    if (AI::action eq 'enhancedCasting') {
        my $args = AI::args;
        if ($args->{'stage'} eq 'end') {
            AI::dequeue;
        } elsif (!$currentTarget) {
            AI::dequeue;
        } elsif ($args->{'stage'} eq 'stepBack') {
            Actor::move($args->{'stepBack'}{'x'}, $args->{'stepBack'}{'y'});
            my $charpos = main::calcPosition($char);
            $args->{'stage'} = 'end';
        } elsif (($args->{'stage'} eq 'skillUse')) {
            main::ai_skillUse(
                $args->{'handle'},
                $args->{'lvl'},
                $args->{'maxCastTime'},
                $args->{'minCastTime'},
                $args->{'target'}
            );
            #$currentTarget = "";
            $args->{'stage'} = exists $args->{'stepBack'} ? 'stepBack' : 'end';
        } elsif ($args->{'stage'} eq 'move') {
            Actor::move($args->{'move'}{'x'}, $args->{'move'}{'y'});
            $args->{'stage'} = 'skillUse';
        } elsif ($args->{'stage'} eq 'adjust') {
            Actor::move($args->{'adjust'}{'x'}, $args->{'adjust'}{'y'});
            $args->{'stage'} = 'reCast';
        } elsif ($args->{'stage'} eq 'reCast') {
            AI::dequeue;
            castBetween() if ($currentTarget);
        } elsif (!$currentTarget) {
            $args->{'stage'} = 'end';
        }
    }
    if ($currentTarget && AI::action eq "attack") {
        selectSkill();
    }
}

sub checkCoordsCondition {
    my $prefix = shift;
    my $coord  = shift;

    if ($config{$prefix . "_whenGround"}) {
        return 0 unless main::whenGroundStatus($coord, $config{$prefix . "_whenGround"});
    }
    if ($config{$prefix . "_whenNotGround"}) {
        return 0 if main::whenGroundStatus($coord, $config{$prefix . "_whenNotGround"});
    }

    return 1;
}

sub selectSkill {
    my $prefix = "enhancedCasting_";
    my $i      = 0;
    while (exists $config{$prefix . $i}) {
        my $fellThrough = 0;
        if ((main::checkSelfCondition($prefix . $i)) &&
            main::timeOut($delay{$prefix . $i . "_blockDelayBeforeUse"})
          ) {
            my $skillObj = Skill->new(name => $config{$prefix . $i});
            unless ($skillObj->getHandle) {
                my $msg = "Unknown skill name " . $config{$prefix . $i} . " in $prefix.$i\n";
                error $msg;
                configModify($prefix . $i . "_disabled", 1);
                next;
            }
            debug("Trying $config{$prefix.$i}\n", 'enhancedCasting', 1);
            my %skill;
            my $ID          = int($currentTarget->{nameID});
            my $element     = $monsterDB{$ID}{element};
            my $element_lvl = $monsterDB{$ID}{elementLevel};
            my $race        = $monsterDB{$ID}{race};
            my $size        = $monsterDB{$ID}{size};
            my $charpos     = main::calcPosition($char);
            my $monsterpos  = main::calcPosition($currentTarget);
            my $angle;
            my $dist = $config{$prefix . $i . "_skillDist"};

            # Here is a bunch of code that needs to be optimised.
            # However, we're going for functionality testing currently..

            if ($dist > 0) {
                my %vec; getVector(\%vec, $monsterpos, $charpos);
                moveAlongVector(\%skill, $charpos, \%vec, abs($dist));
            } elsif ($dist < 0) {
                my %vec; getVector(\%vec, $charpos, $monsterpos);
                moveAlongVector(\%skill, $monsterpos, \%vec, abs($dist));
            } elsif ($dist eq "vertical") {
                my %vec; getVector(\%vec, $monsterpos, $charpos);
                $angle = vectorToDegree(\%vec);
                if ($angle == 0) {
                    $skill{'adjust'}{'x'} = $charpos->{'x'} - ($config{$prefix . $i . "_stepBack"} || 1);
                    $skill{'adjust'}{'y'} = $charpos->{'y'};
                    $skill{'stage'} = 'adjust';
                    AI::queue('castBetween', \%skill);
                    last;
                } elsif ($angle == 90) {
                    $skill{'adjust'}{'x'} = $charpos->{'x'};
                    $skill{'adjust'}{'y'} = $charpos->{'y'} + ($config{$prefix . $i . "_stepBack"} || 1);
                    $skill{'stage'} = 'adjust';
                    AI::queue('castBetween', \%skill);
                    last;
                } elsif ($angle == 180) {
                    $skill{'adjust'}{'x'} = $charpos->{'x'} + ($config{$prefix . $i . "_stepBack"} || 1);
                    $skill{'adjust'}{'y'} = $charpos->{'y'};
                    $skill{'stage'} = 'adjust';
                    AI::queue('castBetween', \%skill);
                    last;
                } elsif ($angle == 270) {
                    $skill{'adjust'}{'x'} = $charpos->{'x'};
                    $skill{'adjust'}{'y'} = $charpos->{'y'} - ($config{$prefix . $i . "_stepBack"} || 1);
                    $skill{'stage'} = 'adjust';
                    AI::queue('castBetween', \%skill);
                    last;
                } elsif (($angle > 0 && $angle < 45) || ($angle > 135 && $angle < 180) || ($angle == 45)) {
                    $skill{'x'} = $charpos->{'x'} + 1;
                    $skill{'y'} = $charpos->{'y'};
                } elsif (($angle > 45 && $angle < 90) || ($angle > 270 && $angle < 315) || ($angle == 315)) {
                    $skill{'x'} = $charpos->{'x'};
                    $skill{'y'} = $charpos->{'y'} + 1;
                } elsif (($angle > 90 && $angle < 135) || ($angle > 225 && $angle < 270) || ($angle == 135)) {
                    $skill{'x'} = $charpos->{'x'};
                    $skill{'y'} = $charpos->{'y'} - 1;
                } elsif (($angle > 180 && $angle < 225) || ($angle > 315 && $angle < 360) || ($angle == 225)) {
                    $skill{'x'} = $charpos->{'x'} - 1;
                    $skill{'y'} = $charpos->{'y'};
                }
            } elsif ((!$dist) || ($dist == 0)) {
                my %vec; getVector(\%vec, $charpos, $monsterpos);
                moveAlongVector(\%skill, $monsterpos, \%vec, (distance($charpos, $monsterpos) / 2));
            }

            if ($config{$prefix . $i . "_stepBack"}) {
                if ($dist eq "vertical") {
                    if (($angle > 315 && $angle < 360) || ($angle > 0 && $angle < 45) || ($angle == 45)) {
                        $skill{'stepBack'}{'x'} = $charpos->{'x'};
                        $skill{'stepBack'}{'y'} = $charpos->{'y'} - $config{$prefix . $i . "_stepBack"};
                    } elsif (($angle > 45 && $angle < 90) || ($angle > 90 && $angle < 135) || ($angle == 135)) {
                        $skill{'stepBack'}{'x'} = $charpos->{'x'} - $config{$prefix . $i . "_stepBack"};
                        $skill{'stepBack'}{'y'} = $charpos->{'y'};
                    } elsif (($angle > 135 && $angle < 180) || ($angle > 180 && $angle < 225) || ($angle == 225)) {
                        $skill{'stepBack'}{'x'} = $charpos->{'x'};
                        $skill{'stepBack'}{'y'} = $charpos->{'y'} + $config{$prefix . $i . "_stepBack"};
                    } elsif (($angle > 225 && $angle < 270) || ($angle > 270 && $angle < 315) || ($angle == 315)) {
                        $skill{'stepBack'}{'x'} = $charpos->{'x'} + $config{$prefix . $i . "_stepBack"};
                        $skill{'stepBack'}{'y'} = $charpos->{'y'};
                    }
                } else {
                    my %stepBack;
                    my %vec; getVector(\%vec, $charpos, $monsterpos);
                    moveAlongVector(\%stepBack, \%skill, \%vec, $config{$prefix . $i . "_stepBack"});
                    $skill{'stepBack'}{'x'} = sprintf("%.0f", $stepBack{'x'});
                    $skill{'stepBack'}{'y'} = sprintf("%.0f", $stepBack{'y'});
                }
            }

            $skill{'x'} = sprintf("%.0f", $skill{'x'});
            $skill{'y'} = sprintf("%.0f", $skill{'y'});

            $delay{$prefix . $i . "_blockDelayBeforeUse"}{'timeout'} = $config{$prefix . $i . "_blockDelayBeforeUse"};
            if (!$delay{$prefix . $i . "_blockDelayBeforeUse"}{'set'}) {
                $delay{$prefix . $i . "_blockDelayBeforeUse"}{'time'} = time;
                $delay{$prefix . $i . "_blockDelayBeforeUse"}{'set'}  = 1;
            }

            $delay{$prefix . $skillObj->getHandle . "_skillDelay"}{'timeout'} = $config{$prefix . $i . "_skillDelay"};
            if ($skillUse{$skillObj->getIDN}) { # set the delays only when the skill gets successfully cast
                $delay{$prefix . $skillObj->getHandle . "_skillDelay"}{'time'} = time;
                $skillUse{$skillObj->getIDN} = 0;
            }

            if ($currentTarget->{element} && $currentTarget->{element} ne '') {
                $element = $currentTarget->{element};
                debug("enhancedCasting: Monster $currentTarget->{name} has changed element to $currentTarget->{element}\n", 'enhancedCasting', 3);
            }

            if ($currentTarget->statusActive('BODYSTATE_STONECURSE, BODYSTATE_STONECURSE_ING')) {
                $element     = 'Earth';
                $element_lvl = 1;
                debug("enhancedCasting: Monster $currentTarget->{name} is petrified changing element to Earth\n", 'enhancedCasting', 3);
            }

            if ($currentTarget->statusActive('BODYSTATE_FREEZING')) {
                $element     = 'Water';
                $element_lvl = 1;
                debug("enhancedCasting: Monster $currentTarget->{name} is frozen changing element to Water\n", 'enhancedCasting', 3);
            }

            if (main::timeOut($delay{$prefix . $skillObj->getHandle . "_skillDelay"}) &&
                main::timeOut($delay{$prefix . $i . "_blockDelayAfterUse"}) &&
                ((!$config{$prefix . $i . "_target"}) || existsInList($config{$prefix . $i . "_target"}, $currentTarget->{'name'})) &&
                ((!$config{$prefix . $i . "_notTarget"}) || !existsInList($config{$prefix . $i . "_notTarget"}, $currentTarget->{'name'})) &&
                ((!$config{$prefix . $i . "_Element"}) || (existsInList($config{$prefix . $i . "_Element"}, $element) || existsInList($config{$prefix . $i . "_Element"}, $element . $element_lvl))) &&
                ((!$config{$prefix . $i . "_notElement"}) || (!existsInList($config{$prefix . $i . "_notElement"}, $element) && !existsInList($config{$prefix . $i . "_notElement"}, $element . $element_lvl))) &&
                ((!$config{$prefix . $i . "_Race"}) || existsInList($config{$prefix . $i . "_Race"}, $race)) &&
                ((!$config{$prefix . $i . "_notRace"}) || !existsInList($config{$prefix . $i . "_notRace"}, $race)) &&
                ((!$config{$prefix . $i . "_Size"}) || existsInList($config{$prefix . $i . "_Size"}, $size)) &&
                ((!$config{$prefix . $i . "_notSize"}) || !existsInList($config{$prefix . $i . "_notSize"}, $size)) &&
                ((!$config{$prefix . $i . "_notImmovable"}) || ($monsterDB{$ID}{mode} & MD_CANMOVE)) &&
                ((!$config{$prefix . $i . "_whenStatusActive"}) || ($char->statusActive($config{$prefix . $i . "_whenStatusActive"}))) &&
                ((!$config{$prefix . $i . "_whenStatusInactive"}) || (!$char->statusActive($config{$prefix . $i . "_whenStatusInactive"}))) &&
                (round(distance($charpos, $monsterpos)) <= $config{$prefix . $i . "_dist"}) &&
                (!$config{$prefix . $i . "_skillDist"})
              ) {
                my $monsterID = $currentTarget->{type};
                my $castLevel = 10;
                my $damageNeeded = $monsterDB{$monsterID}{HP} + $currentTarget->{deltaHp};
                my $estimatedDamage;

                $skill{'handle'}  = $skillObj->getHandle;
                $skill{'skillID'} = $skillObj->getIDN;
                my $formula    = $config{$prefix . $i . '_damageFormula'};
                my $damageType = $config{$prefix . $i . '_damageType'};
                for (my $x = 1 ; $x <= $char->{'skills'}->{$skillObj->getHandle}->{'lv'} ; $x++) {
                    $castLevel = $x;
                    $estimatedDamage = calcSkillDamage($formula, $x, int($currentTarget->{type}), $damageType);
                    debug("Checking $skill{'handle'} at level $x need $damageNeeded estimate $estimatedDamage\n", 'enhancedCasting', 1);
                    last if ($estimatedDamage >= $damageNeeded);
                }
                if (($estimatedDamage < $damageNeeded) && ($config{$prefix . $i . "_fallThrough"})) {
                    debug("I am allowed to fall through to the next skill because my damage is too low\n", 'enhancedCasting', 1);
                    $fellThrough = 1;
                }
                $i++;
                next if $fellThrough;
                last if ($damageNeeded <= 0);
                $skill{'lvl'}         = $castLevel;
                $skill{'maxCastTime'} = $config{$prefix . $i . "_maxCastTime"};
                $skill{'minCastTime'} = $config{$prefix . $i . "_minCastTime"};
                $skill{'target'}      = $currentTarget->{ID};
                $skill{'stage'}       = 'skillUse';
                $skillUse{$skill{'skillID'}} = 0;
                AI::queue('enhancedCasting', \%skill);
                $delay{$prefix . $i . "_blockDelayAfterUse"}{'timeout'} = $config{$prefix . $i . "_blockDelayAfterUse"};
                $delay{$prefix . $i . "_blockDelayAfterUse"}{'time'} = time;
                $delay{$prefix . $i . "_blockDelayBeforeUse"}{'set'} = 0;
                debug("Selected level $skill{'lvl'} for $skill{'handle'} to attack $currentTarget->{'name_given'}\n", 'enhancedCasting', 1);
                last;
            } elsif (
				  (checkCoordsCondition($prefix . $i . "_coords", \%skill)) &&
                  main::timeOut($delay{$prefix . $skillObj->getHandle . "_skillDelay"}) &&
                  main::timeOut($delay{$prefix . $i . "_blockDelayAfterUse"}) &&
                  ((!$config{$prefix . $i . "_target"}) || existsInList($config{$prefix . $i . "_target"}, $currentTarget->{'name'})) &&
                  ((!$config{$prefix . $i . "_notTarget"}) || !existsInList($config{$prefix . $i . "_notTarget"}, $currentTarget->{'name'})) &&
                  ((!$config{$prefix . $i . "_Element"}) || (existsInList($config{$prefix . $i . "_Element"}, $element) || existsInList($config{$prefix . $i . "_Element"}, $element . $element_lvl))) &&
                  ((!$config{$prefix . $i . "_notElement"}) || (!existsInList($config{$prefix . $i . "_notElement"}, $element) && !existsInList($config{$prefix . $i . "_notElement"}, $element . $element_lvl))) &&
                  ((!$config{$prefix . $i . "_Race"}) || existsInList($config{$prefix . $i . "_Race"}, $race)) &&
                  ((!$config{$prefix . $i . "_notRace"}) || !existsInList($config{$prefix . $i . "_notRace"}, $race)) &&
                  ((!$config{$prefix . $i . "_Size"}) || existsInList($config{$prefix . $i . "_Size"}, $size)) &&
                  ((!$config{$prefix . $i . "_notSize"}) || !existsInList($config{$prefix . $i . "_notSize"}, $size)) &&
                  ((!$config{$prefix . $i . "_notImmovable"}) || ($monsterDB{$ID}{mode} & MD_CANMOVE)) &&
                  ((!$config{$prefix . $i . "_whenStatusActive"}) || ($char->statusActive($config{$prefix . $i . "_whenStatusActive"}))) &&
                  ((!$config{$prefix . $i . "_whenStatusInactive"}) || (!$char->statusActive($config{$prefix . $i . "_whenStatusInactive"}))) &&
                  (distance($charpos, $monsterpos) <= $config{$prefix . $i . "_dist"}) &&
                  ($config{$prefix . $i . "_skillDist"})
              ) {
                $skill{'handle'}    = $skillObj->getHandle;
                  $skill{'skillID'} = $skillObj->getIDN;
                  $skill{'lvl'}     = ($config{$prefix . $i . "_lvl"}) || 10;
                  $skill{'maxCastTime'} = $config{$prefix . $i . "_maxCastTime"};
                  $skill{'minCastTime'} = $config{$prefix . $i . "_minCastTime"};
                  $skill{'stage'} = 'skillUse';
                  $skillUse{$skill{'skillID'}} = 0;
                  AI::queue('castBetween', \%skill);
                  $delay{$prefix . $i . "_blockDelayAfterUse"}{'timeout'} = $config{$prefix . $i . "_blockDelayAfterUse"};
                  $delay{$prefix . $i . "_blockDelayAfterUse"}{'time'} = time;
                  $delay{$prefix . $i . "_blockDelayBeforeUse"}{'set'} = 0;
                  last;
                }
        }
        $i++;
    }
}

sub loadMonDB {
    %monsterDB = undef;
    debug("Enhanced Casting: Loading Database\n", 'enhancedCasting', 2);
    my $file = Settings::getTableFilename('mob_db.txt');
    error("Enhanced Casting: can't load $file for monster information\n", 'enhancedCasting', 0) unless (-r $file);
    open my $fh, "<", $file;
    my $i = 0;
    while (<$fh>) {
        next unless m/^(\d{4}),/;
        my ($ID, $Sprite_Name, $kROName, $iROName, $LV, $HP, $SP, $EXP, $JEXP, $Range1, $ATK1, $ATK2, $DEF, $MDEF, $STR, $AGI, $VIT, $INT, $DEX, $LUK, $Range2, $Range3, $Scale, $Race, $Element, $Mode, $Speed, $aDelay, $aMotion, $dMotion, $MEXP, $ExpPer, $MVP1id, $MVP1per, $MVP2id, $MVP2per, $MVP3id, $MVP3per, $Drop1id, $Drop1per, $Drop2id, $Drop2per, $Drop3id, $Drop3per, $Drop4id, $Drop4per, $Drop5id, $Drop5per, $Drop6id, $Drop6per, $Drop7id, $Drop7per, $Drop8id, $Drop8per, $Drop9id, $Drop9per, $DropCardid, $DropCardper) = split /,/;
        $monsterDB{$ID}{HP}           = $HP;
        $monsterDB{$ID}{mDEF}         = $MDEF;
        $monsterDB{$ID}{element}      = $element_lut[($Element % 10)];
        $monsterDB{$ID}{elementLevel} = int($Element / 20);
        $monsterDB{$ID}{race}         = $race_lut[$Race];
        $monsterDB{$ID}{size}         = $size_lut[$Scale];
        $monsterDB{$ID}{mode}         = hex($Mode);
        $i++;
    }
    close $fh;
    message TF("%d monsters in database\n", $i), 'monsterDB';
}

sub extendedCheck {
    my (undef, $args) = @_;

    return 0 if !$args->{monster} || $args->{monster}->{nameID} eq '';

    if (!defined $monsterDB{int($args->{monster}->{nameID})}) {
        debug("Enhanced Casting: Monster {$args->{monster}->{name}} not found\n", 'enhancedCasting', 2);
        return 0;
    }    #return if monster is not in DB

    my $ID          = int($args->{monster}->{nameID});
    my $element     = $monsterDB{$ID}{element};
    my $element_lvl = $monsterDB{$ID}{elementLevel};
    my $race        = $monsterDB{$ID}{race};
    my $size        = $monsterDB{$ID}{size};
    my $skillBlock;
    ($skillBlock = $args->{prefix}) =~ s/_target//;

    if ($args->{monster}->{element} && $args->{monster}->{element} ne '') {
        $element = $args->{monster}->{element};
        debug("enhancedCasting: Monster $args->{monster}->{name} has changed element to $args->{monster}->{element}\n", 'enhancedCasting', 3);
    }

    if ($args->{monster}->statusActive('BODYSTATE_STONECURSE, BODYSTATE_STONECURSE_ING')) {
        $element     = 'Earth';
        $element_lvl = 1;
        debug("enhancedCasting: Monster $args->{monster}->{name} is petrified changing element to Earth\n", 'enhancedCasting', 3);
    }

    if ($args->{monster}->statusActive('BODYSTATE_FREEZING')) {
        $element     = 'Water';
        $element_lvl = 1;
        debug("enhancedCasting: Monster $args->{monster}->{name} is frozen changing element to Water\n", 'enhancedCasting', 3);
    }

    if ($config{$args->{prefix} . '_Element'}
        && (!existsInList($config{$args->{prefix} . '_Element'}, $element)
            && !existsInList($config{$args->{prefix} . '_Element'}, $element . $element_lvl))) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notElement'}
        && (existsInList($config{$args->{prefix} . '_notElement'}, $element)
            || existsInList($config{$args->{prefix} . '_notElement'}, $element . $element_lvl))) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_Race'}
        && !existsInList($config{$args->{prefix} . '_Race'}, $race)) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notRace'}
        && existsInList($config{$args->{prefix} . '_notRace'}, $race)) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_Size'}
        && !existsInList($config{$args->{prefix} . '_Size'}, $size)) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notSize'}
        && existsInList($config{$args->{prefix} . '_notSize'}, $size)) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_hpLeft'}
        && !inRange(($monsterDB{$ID}->{HP} + $args->{monster}->{deltaHp}), $config{$args->{prefix} . '_hpLeft'})) {
        return $args->{return} = 0;
    }

    if ($config{$args->{prefix} . '_notImmovable'} && (!($monsterDB{$ID}{mode} & MD_CANMOVE))) {
        debug("Will not cast $config{$skillBlock} on an immovable $args->{monster}\n", 'enhancedCasting', 1);
        return $args->{return} = 0;
    }

    my $skillLevel = $config{$skillBlock . '_lvl'};

    my $potentialDamage = calcSkillDamage($config{$skillBlock . '_damageFormula'}, $config{$skillBlock . '_lvl'}, int($args->{monster}->{nameID}), $config{$skillBlock . '_damageType'});
    if ($config{$skillBlock . '_damageFormula'}
        && inRange(($monsterDB{$ID}{HP} + $args->{monster}->{deltaHp}), '>= ' . $potentialDamage)) {
        debug("Rejected $config{$skillBlock} with estimated damage : $potentialDamage using skill level $skillLevel\n", 'enhancedCasting', 1);
        return $args->{return} = 0;
    }

    return 1;
}

sub statusMATK {
    return floor(($char->{lv} / 4) + ($char->{int} + $char->{int_bonus}) + (($char->{int} + $char->{int_bonus}) / 2) + (($char->{dex} + $char->{dex_bonus}) / 5) + (($char->{luk} + $char->{luk_bonus}) / 3));
}

sub elementalMultiplier {
    my ($targetElement, $attackElement) = @_;
    if (defined $attackElement) {
        return $element_modifiers{$targetElement}->{$attackElement};
    } else {
        return 1;
    }
}

sub powerMultiplier {
    if ($char->{'statuses'}->{'EFST_MAGICPOWER'}) {
        return 1 + ($char->{'skills'}->{'HW_MAGICPOWER'}->{'lv'} * 0.05);
    } else {
        return 1;
    }
}

sub calcSkillDamage {
    my ($formula, $skillLevel, $monsterID, $attackElement) = @_;
    my $matkstatus  = statusMATK();
    my $matkav      = $char->{attack_magic_max} + $matkstatus;
    my $mDEF_Bypass = 0;
    my $int         = $char->{int} + $char->{int_bonus};
    $formula =~ s/mATK/\(\$matkav - \(\$monsterDB\{\$monsterID\}\{mDEF\} - \$mDEF_Bypass\)\)/;
    $formula =~ s/sLVL/\$skillLevel/;
    $formula =~ s/bLVL/\$char->{lv}/;
    $formula =~ s/INT/\$int/;
    $formula = int(eval($formula));
    $formula *= powerMultiplier();
    $formula *= elementalMultiplier($monsterDB{$monsterID}{element} . $monsterDB{$monsterID}{elementLevel}, $attackElement);
    return floor($formula);
}

sub onPacketSkillUse { monsterHp($monsters{$_[1]->{targetID}}, $_[1]->{disp}) if $_[1]->{disp} }

sub onPacketSkillUseNoDmg {
    my (undef, $args) = @_;
    return 1 unless $monsters{$args->{targetID}} && $monsters{$args->{targetID}}{nameID};
    if (
        $args->{targetID} eq $args->{sourceID} && $args->{targetID} ne $accountID
        && $skillChangeElement{$args->{skillID}}
      ) {
        $monsters{$args->{targetID}}{element} = $skillChangeElement{$args->{skillID}};
        monsterEquip($monsters{$args->{targetID}});
        return 1;
    }
}

sub onPacketAttack { monsterHp($monsters{$_[1]->{targetID}}, $_[1]->{msg}) if $_[1]->{msg} }

sub monsterHp {
    my ($monster, $message) = @_;
    return 1 unless $monster && $monster->{nameID};
    my $ID = int($monster->{nameID});
    return 1 unless my $monsterInfo = $monsterDB{$ID};
    $$message =~ s~(?=\n)~TF(" (HP: %d/%d)", $monsterDB{$ID}{HP} + $monster->{deltaHp}, $monsterDB{$ID}{HP})~se;
}

sub onAttackStart {
    my (undef, $args) = @_;
    $currentTarget = $monsters{$args->{ID}};
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

    for (my $i = 0 ; exists $config{"monsterEquip_$i"} ; $i++) {
        $args{prefix} = "monsterEquip_${i}_target";
        if (extendedCheck(undef, \%args)) {
            foreach $slot (%equipSlot_lut) {
                if ($config{"monsterEquip_${i}_equip_$slot"}
                    && !$equip_list{"attackEquip_$slot"}
                    && defined Actor::Item::get($config{"monsterEquip_${i}_equip_$slot"})) {
                    $equip_list{"attackEquip_$slot"} = $config{"monsterEquip_${i}_equip_$slot"};
                    debug "monsterDB: using " . $config{"monsterEquip_${i}_equip_$slot"} . "\n", 'enhancedCasting';
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
