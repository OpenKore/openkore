#########################################################################
#  OpenKore - Attack AI
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 4286 $
#  $Id: Commands.pm 4286 2006-04-17 14:02:27Z illusion_kore $
#
#########################################################################
#
# This module contains the attack AI's code.
package AI::Attack;

use strict;
use Carp::Assert;
use Time::HiRes qw(time);

use Globals;
use AI;
use Actor;
use Field;
use Log qw(message debug warning);
use Translation qw(T TF);
use Network::Send ();
use Skill;
use Misc;
use Utils;
use Utils::Benchmark;
use Utils::PathFinding;


sub process {
	Benchmark::begin("ai_attack") if DEBUG;
	my $args = AI::args;

	if (AI::action eq "attack" && AI::args->{suspended}) {
		$args->{ai_attack_giveup}{time} += time - $args->{suspended};
		delete $args->{suspended};
	}

	if (AI::action eq "attack" && $args->{move_start}) {
		# We've just finished moving to the monster.
		# Don't count the time we spent on moving
		$args->{ai_attack_giveup}{time} += time - $args->{move_start};
		undef $args->{unstuck}{time};
		undef $args->{move_start};

	} elsif (AI::action eq "attack" && $args->{avoiding} && $args->{attackID}) {
		my $target = Actor::get($args->{attackID});
		$args->{ai_attack_giveup}{time} = time + $target->{time_move_calc} + 3;
		undef $args->{avoiding};

	} elsif (((AI::action eq "route" && AI::action(1) eq "attack") || (AI::action eq "move" && AI::action(2) eq "attack"))
	   && $args->{attackID} && timeOut($AI::Temp::attack_route_adjust, 1)) {
		# We're on route to the monster; check whether the monster has moved
		my $ID = $args->{attackID};
		my $attackSeq = (AI::action eq "route") ? AI::args(1) : AI::args(2);
		my $target = Actor::get($ID);

		if ($target->{type} ne 'Unknown' && $attackSeq->{monsterPos} && %{$attackSeq->{monsterPos}}
		 && round(distance(calcPosition($target), $attackSeq->{monsterPos})) > $attackSeq->{attackMethod}{maxDistance}) {
			# Monster has moved; stop moving and let the attack AI readjust route
			AI::dequeue;
			AI::dequeue if (AI::action eq "route");

			$attackSeq->{ai_attack_giveup}{time} = time;
			debug "Target has moved more than $attackSeq->{attackMethod}{maxDistance} blocks; readjusting route\n", "ai_attack";

		} elsif ($target->{type} ne 'Unknown' && $attackSeq->{monsterPos} && %{$attackSeq->{monsterPos}}
		 && round(distance(calcPosition($target), calcPosition($char))) <= $attackSeq->{attackMethod}{maxDistance}) {
			# Monster is within attack range; stop moving
			AI::dequeue;
			AI::dequeue if (AI::action eq "route");

			$attackSeq->{ai_attack_giveup}{time} = time;
			debug "Target at ($attackSeq->{monsterPos}{x},$attackSeq->{monsterPos}{y}) is now within " .
				"$attackSeq->{attackMethod}{maxDistance} blocks; stop moving\n", "ai_attack";
		}
		$AI::Temp::attack_route_adjust = time;
	}

	if (AI::action eq "attack") {
		my $ID = $args->{ID};
		if (targetGone()) {
			finishAttacking();
		} elsif (shouldGiveUp()) {
			giveUp();
		} else {
			if (timeOut($args->{attackMainTimeout}, 0.1)) {
				$args->{attackMainTimeout} = time;
				main();
			}
		}
	}

	# Check for kill steal and mob-training while moving
	if ((AI::is("move", "route") && $args->{attackID} && AI::inQueue("attack")
		&& timeOut($args->{movingWhileAttackingTimeout}, 0.2))) {

		my $ID = AI::args->{attackID};
		my $monster = $monsters{$ID};

		# Check for kill steal while moving
		if ($monster && !Misc::checkMonsterCleanness($ID)) {
			message T("Dropping target - you will not kill steal others\n");
			$char->stopAttack;
			$monster->{ignore} = 1;

			# Right now, the queue is either
			#   move, route, attack
			# -or-
			#   route, attack
			AI::dequeue;
			AI::dequeue;
			AI::dequeue if (AI::action eq "attack");
			if ($config{teleportAuto_dropTargetKS}) {
				message T("Teleport due to dropping attack target\n");
				useTeleport(1);
			}
		}

		# Mob-training, stop attacking the monster if it is already aggressive
		if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
			if ($control->{attack_auto} == 3
				&& ($monster->{dmgToYou} || $monster->{missedYou} || $monster->{dmgFromYou})) {

				message TF("Dropping target - %s (%s) has been provoked\n", $monster->{name}, $monster->{binID});
				$char->stopAttack;
				$monster->{ignore} = 1;
				# Right now, the queue is either
				#   move, route, attack
				# -or-
				#   route, attack
				AI::dequeue;
				AI::dequeue;
				AI::dequeue if (AI::action eq "attack");
			}
		}

		$args->{movingWhileAttackingTimeout} = time;
	}

	Benchmark::end("ai_attack") if DEBUG;
}

sub shouldGiveUp {
	my $args = AI::args;
	return !$config{attackNoGiveup} && (timeOut($args->{ai_attack_giveup}) || $args->{unstuck}{count} > 5);
}

sub giveUp {
	my $ID = AI::args->{ID};
	my $target = Actor::get($ID);
	$target->{attack_failed} = time if ($monsters{$ID});
	AI::dequeue;
	message T("Can't reach or damage target, dropping target\n"), "ai_attack";
	if ($config{'teleportAuto_dropTarget'}) {
		message T("Teleport due to dropping attack target\n");
		useTeleport(1);
	}
}

sub targetGone {
	my $args = AI::args;
	return !$monsters{$args->{ID}} && (!$players{$args->{ID}} || $players{$args->{ID}}{dead});
}

sub finishAttacking {
	my $args = AI::args;
	$timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
	my $ID = $args->{ID};
	AI::dequeue;
	if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
		message T("Target died\n"), "ai_attack";
		Plugins::callHook("target_died");
		monKilled();

		# Pickup loot when monster's dead
		if ($AI == 2 && $config{'itemsTakeAuto'} && $monsters_old{$ID}{dmgFromYou} > 0 && !$monsters_old{$ID}{ignore}) {
			AI::clear("items_take");
			ai_items_take($monsters_old{$ID}{pos}{x}, $monsters_old{$ID}{pos}{y},
				      $monsters_old{$ID}{pos_to}{x}, $monsters_old{$ID}{pos_to}{y});
		} else {
			# Cheap way to suspend all movement to make it look real
			ai_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
		}

		## kokal start
		## mosters counting
		my $i = 0;
		my $found = 0;
		while ($monsters_Killed[$i]) {
			if ($monsters_Killed[$i]{'nameID'} eq $monsters_old{$ID}{'nameID'}) {
				$monsters_Killed[$i]{'count'}++;
				monsterLog($monsters_Killed[$i]{'name'});
				$found = 1;
				last;
			}
			$i++;
		}
		if (!$found) {
			$monsters_Killed[$i]{'nameID'} = $monsters_old{$ID}{'nameID'};
			$monsters_Killed[$i]{'name'} = $monsters_old{$ID}{'name'};
			$monsters_Killed[$i]{'count'} = 1;
			monsterLog($monsters_Killed[$i]{'name'})
		}
		## kokal end

	} elsif ($config{teleportAuto_lostTarget}) {
		message T("Target lost, teleporting.\n"), "ai_attack";
		useTeleport(1);
	} else {
		message T("Target lost\n"), "ai_attack";
	}

	Plugins::callHook('attack_end', {ID => $ID})

}

sub dropTargetWhileMoving {
	my $ID = AI::args->{attackID};
	message T("Dropping target - you will not kill steal others\n");
	$char->stopAttack;
	$monsters{$ID}{ignore} = 1;

	# Right now, the queue is either
	#   move, route, attack
	# -or-
	#   route, attack
	AI::dequeue;
	AI::dequeue;
	AI::dequeue if (AI::action eq "attack");
	if ($config{teleportAuto_dropTargetKS}) {
		message T("Teleport due to dropping attack target\n");
		useTeleport(1);
	}
}

sub main {
	my $args = AI::args;

	Benchmark::begin("ai_attack (part 1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.1)") if DEBUG;
	# The attack sequence hasn't timed out and the monster is on screen

	# Update information about the monster and the current situation
	my $args = AI::args;
	my $followIndex = AI::findAction("follow");
	my $following;
	my $followID;
	if (defined $followIndex) {
		$following = AI::args($followIndex)->{following};
		$followID = AI::args($followIndex)->{ID};
	}

	my $ID = $args->{ID};
	my $target = Actor::get($ID);
	my $myPos = $char->{pos_to};
	my $monsterPos = $target->{pos_to};
	my $monsterDist = round(distance($myPos, $monsterPos));

	my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou);
	my $realMyPos = calcPosition($char);
	my $realMonsterPos = calcPosition($target);
	my $realMonsterDist = round(distance($realMyPos, $realMonsterPos));
	if (!$config{'runFromTarget'}) {
		$myPos = $realMyPos;
		$monsterPos = $realMonsterPos;
	}

	my $cleanMonster = checkMonsterCleanness($ID);


	# If the damage numbers have changed, update the giveup time so we don't timeout
	if ($args->{dmgToYou_last}   != $target->{dmgToYou}
	 || $args->{missedYou_last}  != $target->{missedYou}
	 || $args->{dmgFromYou_last} != $target->{dmgFromYou}
	 || $args->{lastSkillTime} != $char->{last_skill_time}) {
		$args->{ai_attack_giveup}{time} = time;
		debug "Update attack giveup time\n", "ai_attack", 2;
	}
	$hitYou = ($args->{dmgToYou_last} != $target->{dmgToYou}
		|| $args->{missedYou_last} != $target->{missedYou});
	$args->{dmgToYou_last} = $target->{dmgToYou};
	$args->{missedYou_last} = $target->{missedYou};
	$args->{dmgFromYou_last} = $target->{dmgFromYou};
	$args->{missedFromYou_last} = $target->{missedFromYou};
	$args->{lastSkillTime} = $char->{last_skill_time};

	Benchmark::end("ai_attack (part 1.1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.2)") if DEBUG;

	# Determine what combo skill to use
	delete $args->{attackMethod};
	my $i = 0;
	while (exists $config{"attackComboSlot_$i"}) {
		if (!$config{"attackComboSlot_$i"}) {
			$i++;
			next;
		}

		if (Skill->new(auto => $config{"attackComboSlot_${i}_afterSkill"})->getIDN == $char->{last_skill_used}
		 && ( !$config{"attackComboSlot_${i}_maxUses"} || $args->{attackComboSlot_uses}{$i} < $config{"attackComboSlot_${i}_maxUses"} )
		 && ( !$config{"attackComboSlot_${i}_autoCombo"} || ($char->{combo_packet} && $config{"attackComboSlot_${i}_autoCombo"}) )
		 && ( !defined($args->{ID}) || $args->{ID} eq $char->{last_skill_target} || !$config{"attackComboSlot_${i}_isSelfSkill"})
		 && checkSelfCondition("attackComboSlot_$i")
		 && (!$config{"attackComboSlot_${i}_monsters"} || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{name}))
		 && (!$config{"attackComboSlot_${i}_notMonsters"} || !existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{name}))
		 && checkMonsterCondition("attackComboSlot_${i}_target", $target)) {

			$args->{attackComboSlot_uses}{$i}++;
			delete $char->{last_skill_used};
			if ($config{"attackComboSlot_${i}_autoCombo"}) {
				$char->{combo_packet} = 1500 if ($char->{combo_packet} > 1500);
				# eAthena seems to have a bug where the combo_packet overflows and gives an
				# abnormally high number. This causes kore to get stuck in a waitBeforeUse timeout.
				$config{"attackComboSlot_${i}_waitBeforeUse"} = ($char->{combo_packet} / 1000);
			}
			delete $char->{combo_packet};
			$args->{attackMethod}{type} = "combo";
			$args->{attackMethod}{comboSlot} = $i;
			$args->{attackMethod}{distance} = $config{"attackComboSlot_${i}_dist"};
			$args->{attackMethod}{maxDistance} = $config{"attackComboSlot_${i}_dist"};
			$args->{attackMethod}{isSelfSkill} = $config{"attackComboSlot_${i}_isSelfSkill"};
			last;
		}
		$i++;
	}

	# Determine what skill to use to attack
	if (!$args->{attackMethod}{type}) {
		if ($config{'attackUseWeapon'}) {
			$args->{attackMethod}{distance} = $config{'attackDistance'};
			$args->{attackMethod}{maxDistance} = $config{'attackMaxDistance'};
			$args->{attackMethod}{type} = "weapon";
		} else {
			$args->{attackMethod}{distance} = 30;
			$args->{attackMethod}{maxDistance} = 30;
			undef $args->{attackMethod}{type};
		}

		$i = 0;
		while (exists $config{"attackSkillSlot_$i"}) {
			if (!$config{"attackSkillSlot_$i"}) {
				$i++;
				next;
			}

			my $skill = new Skill(auto => $config{"attackSkillSlot_$i"});
			if ($skill->getOwnerType == Skill::OWNER_CHAR
				&& checkSelfCondition("attackSkillSlot_$i")
				&& (!$config{"attackSkillSlot_$i"."_maxUses"} ||
				    $target->{skillUses}{$skill->getHandle()} < $config{"attackSkillSlot_$i"."_maxUses"})
				&& (!$config{"attackSkillSlot_$i"."_maxAttempts"} || $args->{attackSkillSlot_attempts}{$i} < $config{"attackSkillSlot_$i"."_maxAttempts"})
				&& (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{'name'}))
				&& (!$config{"attackSkillSlot_$i"."_notMonsters"} || !existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{'name'}))
				&& (!$config{"attackSkillSlot_$i"."_previousDamage"} || inRange($target->{dmgTo}, $config{"attackSkillSlot_$i"."_previousDamage"}))
				&& checkMonsterCondition("attackSkillSlot_${i}_target", $target)
			) {
				$args->{attackSkillSlot_attempts}{$i}++;
				$args->{attackMethod}{distance} = $config{"attackSkillSlot_$i"."_dist"};
				$args->{attackMethod}{maxDistance} = $config{"attackSkillSlot_$i"."_dist"};
				$args->{attackMethod}{type} = "skill";
				$args->{attackMethod}{skillSlot} = $i;
				last;
			}
			$i++;
		}

		if ($config{'runFromTarget'} && $config{'runFromTarget_dist'} > $args->{attackMethod}{distance}) {
			$args->{attackMethod}{distance} = $config{'runFromTarget_dist'};
		}
	}

	$args->{attackMethod}{maxDistance} ||= $config{attackMaxDistance};
	$args->{attackMethod}{distance} ||= $config{attackDistance};
	if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
		$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
	}

	Benchmark::end("ai_attack (part 1.2)") if DEBUG;
	Benchmark::end("ai_attack (part 1)") if DEBUG;



	if ($char->{sitting}) {
		ai_setSuspend(0);
		stand();

	} elsif (!$cleanMonster) {
		# Drop target if it's already attacked by someone else
		message T("Dropping target - you will not kill steal others\n"), "ai_attack";
		$messageSender->sendMove($realMyPos->{x}, $realMyPos->{y});
		AI::dequeue;
		if ($config{teleportAuto_dropTargetKS}) {
			message T("Teleporting due to dropping attack target\n"), "teleport";
			useTeleport(1);
		}

	} elsif (
		$config{attackCheckLOS} && $args->{attackMethod}{distance} > 2
		&& (($config{attackCanSnipe} && !checkLineSnipable($realMyPos, $realMonsterPos))
		|| (!$config{attackCanSnipe} && $realMonsterDist < $args->{attackMethod}{maxDistance} && !checkLineWalkable($realMyPos, $realMonsterPos)))
	) {
		# We are a ranged attacker without LOS
		# Calculate squares around monster within shooting range, but not
		# closer than runFromTarget_dist
		my @stand = calcRectArea2($realMonsterPos->{x}, $realMonsterPos->{y},
					  $args->{attackMethod}{distance},
								  $config{runFromTarget} ? $config{runFromTarget_dist} : 0);

		my ($master, $masterPos);
		if ($config{follow}) {
			foreach (keys %players) {
				if ($players{$_}{name} eq $config{followTarget}) {
					$master = $players{$_};
					last;
				}
			}
			$masterPos = calcPosition($master) if $master;
		}

		# Determine which of these spots are snipable
		my $best_spot;
		my $best_dist;
		for my $spot (@stand) {
			# Is this spot acceptable?
			# 1. It must have LOS to the target ($realMonsterPos).
			# 2. It must be within $config{followDistanceMax} of
			#    $masterPos, if we have a master.
			if (
			    (($config{attackCanSnipe} && checkLineSnipable($spot, $realMonsterPos))
				&& checkLineWalkable($spot, $realMonsterPos))
				&& $field->isWalkable($spot->{x}, $spot->{y})
				&& ($realMyPos->{x} != $spot->{x} && $realMyPos->{y} != $spot->{y})
				&& (!$master || round(distance($spot, $masterPos)) <= $config{followDistanceMax})
			) {
				my $dist = distance($realMyPos, $spot);
				if (!defined($best_dist) || $dist < $best_dist) {
					$best_dist = $dist;
					$best_spot = $spot;
				}
			}
		}

		# Move to the closest spot
		my $msg = "No LOS from ($realMyPos->{x}, $realMyPos->{y}) to target ($realMonsterPos->{x}, $realMonsterPos->{y})";
		if ($best_spot) {
			message TF("%s; moving to (%s, %s)\n", $msg, $best_spot->{x}, $best_spot->{y});
			if ($config{attackChangeTarget} == 1) {
				# Restart attack from processAutoAttack
				AI::dequeue;
				ai_route($field->name, $best_spot->{x}, $best_spot->{y}, LOSSubRoute => 1);
			} else {
				ai_route($field->name, $best_spot->{x}, $best_spot->{y});
			}
		} else {
			warning TF("%s; no acceptable place to stand\n", $msg);
			$target->{attack_failedLOS} = time;
			AI::dequeue;
			AI::dequeue;
			AI::dequeue if (AI::action eq "attack");
		}

	} elsif ($config{'runFromTarget'} && ($realMonsterDist < $config{'runFromTarget_dist'} || $hitYou)) {
		#my $begin = time;
		# Get a list of blocks that we can run to
		my @blocks = calcRectArea($myPos->{x}, $myPos->{y},
			# If the monster hit you while you're running, then your recorded
			# location may be out of date. So we use a smaller distance so we can still move.
			($hitYou) ? $config{'runFromTarget_dist'} / 2 : $config{'runFromTarget_dist'});

		# Find the distance value of the block that's farthest away from a wall
		my $highest;
		foreach (@blocks) {
			my $dist = ord(substr($field{dstMap}, $_->{y} * $field{width} + $_->{x}));
			if (!defined $highest || $dist > $highest) {
				$highest = $dist;
			}
		}

		# Get rid of rediculously large route distances (such as spots that are on a hill)
		# Get rid of blocks that are near a wall
		my $pathfinding = new PathFinding;
		use constant AVOID_WALLS => 4;
		for (my $i = 0; $i < @blocks; $i++) {
			# We want to avoid walls (so we don't get cornered), if possible
			my $dist = ord(substr($field{dstMap}, $blocks[$i]{y} * $field{width} + $blocks[$i]{x}));
			if ($highest >= AVOID_WALLS && $dist < AVOID_WALLS) {
				delete $blocks[$i];
				next;
			}

			$pathfinding->reset(
				field => \%field,
				start => $myPos,
				dest => $blocks[$i]);
			my $ret = $pathfinding->runcount;
			if ($ret <= 0 || $ret > $config{'runFromTarget_dist'} * 2) {
				delete $blocks[$i];
				next;
			}
		}

		# Find the block that's farthest to us
		my $largestDist;
		my $bestBlock;
		foreach (@blocks) {
			next unless defined $_;
			my $dist = distance($monsterPos, $_);
			if (!defined $largestDist || $dist > $largestDist) {
				$largestDist = $dist;
				$bestBlock = $_;
			}
		}

		#message "Time spent: " . (time - $begin) . "\n";
		#debug_showSpots('runFromTarget', \@blocks, $bestBlock);
		$args->{avoiding} = 1;
		move($bestBlock->{x}, $bestBlock->{y}, $ID);

	} elsif ($realMonsterDist > $args->{attackMethod}{maxDistance}
	  && timeOut($args->{ai_attack_giveup}, 0.5)) {
		# The target monster moved; move to target
		$args->{move_start} = time;
		$args->{monsterPos} = {%{$monsterPos}};

		my $pos = meetingPosition($target, $args->{attackMethod}{maxDistance});

		my $dist = sprintf("%.1f", $monsterDist);
		debug "Target distance $dist is >$args->{attackMethod}{maxDistance}; moving to target: " .
			"from ($myPos->{x},$myPos->{y}) to ($pos->{x},$pos->{y})\n", "ai_attack";

		my $result = ai_route($field{'name'}, $pos->{x}, $pos->{y},
			maxRouteTime => $config{'attackMaxRouteTime'},
			attackID => $ID,
			noMapRoute => 1,
			noAvoidWalls => 1);
		if (!$result) {
			# Unable to calculate a route to target
			$target->{attack_failed} = time;
			AI::dequeue;
				message T("Unable to calculate a route to target, dropping target\n"), "ai_attack";
			if ($config{'teleportAuto_dropTarget'}) {
				message T("Teleport due to dropping attack target\n");
				useTeleport(1);
			}
		}

	} elsif ((!$config{'runFromTarget'} || $realMonsterDist >= $config{'runFromTarget_dist'})
	 && (!$config{'tankMode'} || !$target->{dmgFromYou})) {
		# Attack the target. In case of tanking, only attack if it hasn't been hit once.
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			my $pos = "$myPos->{x},$myPos->{y}";
			debug "Ready to attack target (which is $realMonsterDist blocks away); we're at ($pos)\n", "ai_attack";
		}

		$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
		if (!$target->{dmgFromYou} && timeOut($args->{unstuck})) {
			# We are close enough to the target, and we're trying to attack it,
			# but some time has passed and we still haven't dealed any damage.
			# Our recorded position might be out of sync, so try to unstuck
			$args->{unstuck}{time} = time;
			debug("Attack - trying to unstuck\n", "ai_attack");
			move($myPos->{x}, $myPos->{y});
			$args->{unstuck}{count}++;
		}

		if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_attack})) {
			if (Actor::Item::scanConfigAndCheck("attackEquip")) {
				#check if item needs to be equipped
				Actor::Item::scanConfigAndEquip("attackEquip");
			} else {
				$messageSender->sendAction($ID,
					($config{'tankMode'}) ? 0 : 7);
				$timeout{ai_attack}{time} = time;
				delete $args->{attackMethod};
			}
		} elsif ($args->{attackMethod}{type} eq "skill") {
			my $slot = $args->{attackMethod}{skillSlot};
			delete $args->{attackMethod};

			ai_setSuspend(0);
			my $skill = new Skill(auto => $config{"attackSkillSlot_$slot"});
			if (!ai_getSkillUseType($skill->getHandle())) {
				ai_skillUse(
					$skill->getHandle(),
					$config{"attackSkillSlot_${slot}_lvl"},
					$config{"attackSkillSlot_${slot}_maxCastTime"},
					$config{"attackSkillSlot_${slot}_minCastTime"},
					$config{"attackSkillSlot_${slot}_isSelfSkill"} ? $accountID : $ID,
					undef,
					"attackSkill",
					undef,
					undef,
					"attackSkillSlot_${slot}");
			} else {
				my $pos = calcPosition($config{"attackSkillSlot_${slot}_isSelfSkill"} ? $char : $target);
				ai_skillUse(
					$skill->getHandle(),
					$config{"attackSkillSlot_${slot}_lvl"},
					$config{"attackSkillSlot_${slot}_maxCastTime"},
					$config{"attackSkillSlot_${slot}_minCastTime"},
					$pos->{x},
					$pos->{y},
					"attackSkill",
					undef,
					undef,
					"attackSkillSlot_${slot}");
			}
			$args->{monsterID} = $ID;

			debug "Auto-skill on monster ".getActorName($ID).": ".qq~$config{"attackSkillSlot_$slot"} (lvl $config{"attackSkillSlot_${slot}_lvl"})\n~, "ai_attack";

		} elsif ($args->{attackMethod}{type} eq "combo") {
			my $slot = $args->{attackMethod}{comboSlot};
			my $isSelfSkill = $args->{attackMethod}{isSelfSkill};
			my $skill = Skill->new(auto => $config{"attackComboSlot_$slot"})->getHandle;
			delete $args->{attackMethod};

			if (!ai_getSkillUseType($skill)) {
				my $targetID = ($isSelfSkill) ? $accountID : $ID;
				ai_skillUse(
					$skill,
					$config{"attackComboSlot_${slot}_lvl"},
					$config{"attackComboSlot_${slot}_maxCastTime"},
					$config{"attackComboSlot_${slot}_minCastTime"},
					$targetID,
					undef,
					undef,
					undef,
					$config{"attackComboSlot_${slot}_waitBeforeUse"});
			} else {
				my $pos = ($isSelfSkill) ? $char->{pos_to} : $target->{pos_to};
				ai_skillUse(
					$skill,
					$config{"attackComboSlot_${slot}_lvl"},
					$config{"attackComboSlot_${slot}_maxCastTime"},
					$config{"attackComboSlot_${slot}_minCastTime"},
					$pos->{x},
					$pos->{y},
					undef,
					undef,
					$config{"attackComboSlot_${slot}_waitBeforeUse"});
			}
			$args->{monsterID} = $ID;
		}

	} elsif ($config{tankMode}) {
		if ($args->{dmgTo_last} != $target->{dmgTo}) {
			$args->{ai_attack_giveup}{time} = time;
		}
		$args->{dmgTo_last} = $target->{dmgTo};
	}
}

1;
