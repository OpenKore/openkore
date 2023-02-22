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
use Misc;
use Network::Send ();
use Skill;
use Utils;
use Utils::Benchmark;
use Utils::PathFinding;


sub process {
	Benchmark::begin("ai_attack") if DEBUG;
	my $args = AI::args;

	if (
		   (AI::action eq "attack" && $args->{ID})
		|| (AI::action eq "route" && AI::action (1) eq "attack" && $args->{attackID})
		|| (AI::action eq "move" && AI::action (2) eq "attack" && $args->{attackID})
	) {
		my $ID;
		my $ataqArgs;
		if (AI::action eq "attack") {
			$ID = $args->{ID};
			$ataqArgs = AI::args(0);
		} else {
			if (AI::action(1) eq "attack") {
				$ataqArgs = AI::args(1);

			} elsif (AI::action(2) eq "attack") {
				$ataqArgs = AI::args(2);
			}
			$ID = $args->{attackID};
		}

		if (targetGone($ataqArgs, $ID)) {
			finishAttacking($ataqArgs, $ID);
			return;
		} elsif (shouldGiveUp($ataqArgs, $ID)) {
			giveUp($ataqArgs, $ID, 0);
			return;
		}

		my $target = Actor::get($ID);
		if ($target) {
			my $party = $config{'attackAuto_party'} ? 1 : 0;
			my $target_is_aggressive = is_aggressive($target, undef, 0, $party);
			my @aggressives = ai_getAggressives(0, $party);
			if ($config{attackChangeTarget} && !$target_is_aggressive && @aggressives) {
				my $attackTarget = getBestTarget(\@aggressives, $config{attackCheckLOS}, $config{attackCanSnipe});
				if ($attackTarget) {
					$char->sendAttackStop;
					AI::dequeue while (AI::inQueue("attack"));
					ai_setSuspend(0);
					my $new_target = Actor::get($attackTarget);
					warning TF("Your target is not aggressive: %s, changing target to aggressive: %s.\n", $target, $new_target), 'ai_attack';
					$char->attack($attackTarget);
					AI::Attack::process();
					return;
				}
			}
			
			my $cleanMonster = checkMonsterCleanness($ID);
			if (!$cleanMonster) {
				message TF("Dropping target %s - will not kill steal others\n", $target), 'ai_attack';
				$char->sendAttackStop;
				$target->{ignore} = 1;
				AI::dequeue while (AI::inQueue("attack"));
				
				if ($config{teleportAuto_dropTargetKS}) {
					message T("Teleport due to dropping attack target\n"), "teleport";
					useTeleport(1);
				}
				return;
			}
			
			if ((my $control = mon_control($target->{name},$target->{nameID}))) {
				if ($control->{attack_auto} == 3 && ($target->{dmgToYou} || $target->{missedYou} || $target->{dmgFromYou})) {
					message TF("Dropping target - %s (%s) has been provoked\n", $target->{name}, $target->{binID});
					$char->sendAttackStop;
					$target->{ignore} = 1;
					AI::dequeue while (AI::inQueue("attack"));
					return;
				}
			}
		}
	}

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

	} elsif (AI::action eq "attack" && $args->{avoiding} && $args->{ID}) {
		my $ID = $args->{ID};
		my $target = Actor::get($ID);
		$args->{ai_attack_giveup}{time} = time;
		undef $args->{avoiding};
		debug "Finished avoiding movement from target $target, updating ai_attack_giveup\n", "ai_attack";

	} elsif (((AI::action eq "route" && AI::action(1) eq "attack") || (AI::action eq "move" && AI::action(2) eq "attack"))
	   && $args->{attackID} && timeOut($timeout{ai_attack_route_adjust})) {
		# We're on route to the monster; check whether the monster has moved
		my $ID = $args->{attackID};
		my $attackSeq = (AI::action eq "route") ? AI::args(1) : AI::args(2);
		my $target = Actor::get($ID);

		if (
			$target->{type} ne 'Unknown' &&
			$attackSeq->{monsterLastMoveTime} &&
			$attackSeq->{monsterLastMoveTime} != $target->{time_move}
		) {
			# Monster has moved; stop moving and let the attack AI readjust route
			warning "Target $target has moved since we started routing to it - Adjusting route\n", "ai_attack";
			AI::dequeue while (AI::is("move", "route"));

			$attackSeq->{ai_attack_giveup}{time} = time;
			$attackSeq->{needReajust} = 1;

		}

		$timeout{ai_attack_route_adjust}{time} = time;
	}

	if (AI::action eq "attack" && timeOut($args->{attackMainTimeout}, 0.1)) {
		if ($char->{sitting}) {
			ai_setSuspend(0);
			stand();
		} else {
			main();
		}
		
		$args->{attackMainTimeout} = time;
	}

	Benchmark::end("ai_attack") if DEBUG;
}

sub shouldGiveUp {
	my ($args, $ID) = @_;
	return !$config{attackNoGiveup} && (timeOut($args->{ai_attack_giveup}) || $args->{unstuck}{count} > 5);
}

sub giveUp {
	my ($args, $ID, $LOS) = @_;
	my $target = Actor::get($ID);
	if ($monsters{$ID}) {
		if ($LOS) {
			$target->{attack_failedLOS} = time;
		} else {
			$target->{attack_failed} = time;
		}
	}
	$target->{dmgFromYou} = 0; # Hack | TODO: Fix me
	AI::dequeue while (AI::inQueue("attack"));
	message T("Can't reach or damage target, dropping target\n"), "ai_attack";
	if ($config{'teleportAuto_dropTarget'}) {
		message T("Teleport due to dropping attack target\n");
		useTeleport(1);
	}
}

sub targetGone {
	my ($args, $ID) = @_;
	return !$monsters{$args->{ID}} && (!$players{$args->{ID}} || $players{$args->{ID}}{dead});
}

sub finishAttacking {
	my ($args, $ID) = @_;
	$timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
	AI::dequeue while (AI::inQueue("attack"));
	if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
		message TF("Target %s died\n", $monsters_old{$ID}), "ai_attack";
		Plugins::callHook('target_died', {monster => $monsters_old{$ID}});
		monKilled();

		# Pickup loot when monster's dead
		if (AI::state == AI::AUTO && $config{'itemsTakeAuto'} && $monsters_old{$ID}{dmgFromYou} > 0 && !$monsters_old{$ID}{ignore}) {
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

sub main {
	my $args = AI::args;

	Benchmark::begin("ai_attack (part 1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.1)") if DEBUG;
	# The attack sequence hasn't timed out and the monster is on screen

	# Update information about the monster and the current situation
	my $args = AI::args;

	my $ID = $args->{ID};
	my $target = Actor::get($ID);
	my $myPos = $char->{pos_to};
	my $monsterPos = $target->{pos_to};
	my $monsterDist = blockDistance($myPos, $monsterPos);

	my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou, $youHitTarget);
	my $realMyPos = calcPosFromPathfinding($field, $char);
	my $realMonsterPos = calcPosFromPathfinding($field, $target);
	
	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);
	my $clientDist = getClientDist($realMyPos, $realMonsterPos);

	# If the damage numbers have changed, update the giveup time so we don't timeout
	if ($args->{dmgToYou_last}   != $target->{dmgToYou}
	 || $args->{missedYou_last}  != $target->{missedYou}
	 || $args->{dmgFromYou_last} != $target->{dmgFromYou}
	 || $args->{lastSkillTime} != $char->{last_skill_time}) {
		$args->{ai_attack_giveup}{time} = time;
		debug "Update attack giveup time\n", "ai_attack", 2;
	}
	
	$hitYou = ($args->{dmgToYou_last} != $target->{dmgToYou} || $args->{missedYou_last} != $target->{missedYou});
	$youHitTarget = ($args->{dmgFromYou_last} != $target->{dmgFromYou});
	
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

		if ($config{"attackComboSlot_${i}_afterSkill"}
		 && Skill->new(auto => $config{"attackComboSlot_${i}_afterSkill"})->getIDN == $char->{last_skill_used}
		 && ( !$config{"attackComboSlot_${i}_maxUses"} || $args->{attackComboSlot_uses}{$i} < $config{"attackComboSlot_${i}_maxUses"} )
		 && ( !$config{"attackComboSlot_${i}_autoCombo"} || ($char->{combo_packet} && $config{"attackComboSlot_${i}_autoCombo"}) )
		 && ( !defined($args->{ID}) || $args->{ID} eq $char->{last_skill_target} || !$config{"attackComboSlot_${i}_isSelfSkill"})
		 && checkSelfCondition("attackComboSlot_$i")
		 && (!$config{"attackComboSlot_${i}_monsters"} || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{name}) ||
				existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{nameID}))
		 && (!$config{"attackComboSlot_${i}_notMonsters"} || !(existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{name}) ||
				existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{nameID})))
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
			$args->{attackMethod}{maxDistance} = $config{"attackComboSlot_${i}_maxDist"} || $config{"attackComboSlot_${i}_dist"};
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
			$args->{attackMethod}{distance} = 1;
			$args->{attackMethod}{maxDistance} = 1;
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
				&& (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{'name'}) ||
					existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{nameID}))
				&& (!$config{"attackSkillSlot_$i"."_notMonsters"} || !(existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{'name'}) ||
					existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{nameID})))
				&& (!$config{"attackSkillSlot_$i"."_previousDamage"} || inRange($target->{dmgTo}, $config{"attackSkillSlot_$i"."_previousDamage"}))
				&& checkMonsterCondition("attackSkillSlot_${i}_target", $target)
			) {
				$args->{attackSkillSlot_attempts}{$i}++;
				$args->{attackMethod}{distance} = $config{"attackSkillSlot_$i"."_dist"};
				$args->{attackMethod}{maxDistance} = $config{"attackSkillSlot_$i"."_maxDist"} || $config{"attackSkillSlot_$i"."_dist"};
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

	my $melee;
	my $ranged;
	if (defined $args->{attackMethod}{type} && exists $args->{ai_attack_failed_give_up} && defined $args->{ai_attack_failed_give_up}{time}) {
		debug "Deleting ai_attack_failed_give_up time.\n";
		delete $args->{ai_attack_failed_give_up}{time};
		
	} elsif ($args->{attackMethod}{maxDistance} == 1) {
		$melee = 1;

	} elsif ($args->{attackMethod}{maxDistance} > 1) {
		$ranged = 1;
	}
	
	# -2: undefined attackMethod
	# -1: No LOS
	#  0: out of range
	#  1: sucess
	my $canAttack = -2;
	if ($melee || $ranged) {
		$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{attackCanSnipe}, $args->{attackMethod}{maxDistance}, $config{clientSight});
	}
	
	if (
		   $config{"attackBeyondMaxDistance_waitForAgressive"}
		&& $target->{dmgFromYou} > 0
		&& $canAttack == 1
		&& exists $args->{ai_attack_failed_waitForAgressive_give_up}
		&& defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};;
	}
	
	if (
		   $config{"attackWaitApproachFinish"}
		&& ($canAttack == 0 || $canAttack == -1)
		&& $args->{sentApproach}
		&& !$args->{needReajust}
	) {
		if (!timeOut($char->{time_move}, $char->{time_move_calc})) {
			debug TF("[Out of Range - Still Approaching - Waiting] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			return;
		} else {
			warning TF("[Out of Range - Ended Approaching] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			$args->{sentApproach} = 0;
		}
	}

	if ($config{'runFromTarget'} && ($realMonsterDist < $config{'runFromTarget_dist'} || $hitYou)) {
		my $max_sight = $config{clientSight} - 1;
		my $current_beyond = 0;
		my $increase = 3;
		
		while (1) {
			my $current_dist = $args->{attackMethod}{maxDistance} + $current_beyond;
			if ($current_dist > $max_sight) {
				$current_dist = $max_sight;
			}
			
			my $pos = meetingPosition($char, 1, $target, $current_dist, 1);
			if ($pos) {
				debug TF("[runFromTarget] (+$current_beyond | $current_dist/$max_sight) %s kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
				$args->{avoiding} = 1;
				$args->{needReajust} = 0;
				$char->route(
					undef,
					@{$pos}{qw(x y)},
					noMapRoute => 1,
					avoidWalls => 0,
					randomFactor => 0,
					useManhattan => 1,
					runFromTarget => 1
				);
				last;
				
			} elsif ($current_dist == $max_sight) {
				debug TF("%s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
				last;
				
			} else {
				$current_beyond += $increase;
			}
		}

	} elsif($canAttack  == -2) {
		debug T("Can't determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), "ai_attack";
		$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
		$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
		if (timeOut($args->{ai_attack_failed_give_up})) {
			delete $args->{ai_attack_failed_give_up}{time};
			warning T("Unable to determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), "ai_attack";
			giveUp($args, $ID, 0);
		}
	
	} elsif (
		$config{"attackBeyondMaxDistance_waitForAgressive"} &&
		$target->{dmgFromYou} > 0 &&
		($canAttack == 0 || $canAttack == -1)
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};
		
		if ($ranged) {
			if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
				delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
				warning T("[Out of Range - Ranged] Waited too long for target to get closer, dropping target\n"), "ai_attack";
				giveUp($args, $ID, 0);
			} else {
				$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7) if ($config{"attackBeyondMaxDistance_sendAttackWhileWaiting"});
				warning TF("[Out of Range - Ranged - Waiting] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			}
			
		} elsif ($melee) {
			if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
				delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
				warning T("[Out of Range - Melee] Waited too long for target to get closer, dropping target\n"), "ai_attack";
				giveUp($args, $ID, 0);
			} else {
				$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7) if ($config{"attackBeyondMaxDistance_sendAttackWhileWaiting"});
				warning TF("[Out of Range - Melee - Waiting] %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			}
		}

	} elsif (
		$canAttack < 1
	) {
		debug "Attack $char ($realMyPos->{x} $realMyPos->{y}) - target $target ($realMonsterPos->{x} $realMonsterPos->{y})\n";
		if ($ranged && $canAttack == 0) {
			debug "[Attack] [Ranged] [No range] Too far from us to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';
		} elsif ($melee && $canAttack == 0) {
			debug "[Attack] [Melee] [No range] Too far from us to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';
		
		} elsif ($ranged && $canAttack == -1) {
			debug "[Attack] [Ranged] [No LOS] No LOS\n", 'ai_attack';
			
		} elsif ($melee && $canAttack == -1) {
			debug "[Attack] [Melee] [No LOS] No LOS\n", 'ai_attack';
			
		}

		$args->{move_start} = time;
		$args->{monsterLastMoveTime} = $target->{time_move};
		my $pos = meetingPosition($char, 1, $target, $args->{attackMethod}{maxDistance});
		if ($pos) {
			debug "Attack $char ($realMyPos->{x} $realMyPos->{y}) - moving to meeting position ($pos->{x} $pos->{y})\n", 'ai_attack';

			$args->{needReajust} = 0;
			$args->{sentApproach} = 1;
			$char->route(
				undef,
				@{$pos}{qw(x y)},
				maxRouteTime => $config{'attackMaxRouteTime'},
				attackID => $ID,
				avoidWalls => 0,
				randomFactor => 0,
				useManhattan => 1,
				meetingSubRoute => 1,
				noMapRoute => 1
			);
		} else {
			message T("Unable to calculate a meetingPosition to target, dropping target\n"), "ai_attack";
			giveUp($args, $ID, 1);
		}

	} elsif ((!$config{'runFromTarget'} || $realMonsterDist >= $config{'runFromTarget_dist'})
	 && (!$config{'tankMode'} || !$target->{dmgFromYou})) {
		# Attack the target. In case of tanking, only attack if it hasn't been hit once.
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			debug "Ready to attack target (which is $realMonsterDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
		}

		$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
		if (!$target->{dmgFromYou} && timeOut($args->{unstuck})) {
			# We are close enough to the target, and we're trying to attack it,
			# but some time has passed and we still haven't dealed any damage.
			# Our recorded position might be out of sync, so try to unstuck
			$args->{unstuck}{time} = time;
			debug("Attack - trying to unstuck\n", "ai_attack");
			$char->move(@{$myPos}{qw(x y)});
			$args->{unstuck}{count}++;
		}

		if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_attack})) {
			if (Actor::Item::scanConfigAndCheck("attackEquip")) {
				#check if item needs to be equipped
				Actor::Item::scanConfigAndEquip("attackEquip");
			} else {
				debug "[Attack] Sending attack target $target (which is $realMonsterDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
				$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7);
				$timeout{ai_attack}{time} = time;
				delete $args->{attackMethod};

				if ($config{'runFromTarget'} && $config{'runFromTarget_inAdvance'} && $realMonsterDist < $config{'runFromTarget_minStep'}) {
					my $pos = meetingPosition($char, 1, $target, $args->{attackMethod}{maxDistance}, 1);
					if ($pos) {
						debug TF("%s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
						$args->{avoiding} = 1;
						$char->move($pos->{x}, $pos->{y}, $ID);
					} else {
						debug TF("%s no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
					}
				}
			}
		} elsif ($args->{attackMethod}{type} eq "skill") {
			my $slot = $args->{attackMethod}{skillSlot};
			delete $args->{attackMethod};

			$ai_v{"attackSkillSlot_${slot}_time"} = time;
			$ai_v{"attackSkillSlot_${slot}_target_time"}{$ID} = time;

			ai_setSuspend(0);
			my $skill = new Skill(auto => $config{"attackSkillSlot_$slot"});
			ai_skillUse2(
				$skill,
				$config{"attackSkillSlot_${slot}_lvl"} || $char->getSkillLevel($skill),
				$config{"attackSkillSlot_${slot}_maxCastTime"},
				$config{"attackSkillSlot_${slot}_minCastTime"},
				$config{"attackSkillSlot_${slot}_isSelfSkill"} ? $char : $target,
				"attackSkillSlot_${slot}",
				undef,
				"attackSkill",
			);
			$args->{monsterID} = $ID;
			my $skill_lvl = $config{"attackSkillSlot_${slot}_lvl"} || $char->getSkillLevel($skill);
			debug "Auto-skill on monster ".getActorName($ID).": ".qq~$config{"attackSkillSlot_$slot"} (lvl $skill_lvl)\n~, "ai_attack";

		} elsif ($args->{attackMethod}{type} eq "combo") {
			my $slot = $args->{attackMethod}{comboSlot};
			my $isSelfSkill = $args->{attackMethod}{isSelfSkill};
			my $skill = Skill->new(auto => $config{"attackComboSlot_$slot"});
			delete $args->{attackMethod};

			$ai_v{"attackComboSlot_${slot}_time"} = time;
			$ai_v{"attackComboSlot_${slot}_target_time"}{$ID} = time;

			ai_skillUse2(
				$skill,
				$config{"attackComboSlot_${slot}_lvl"} || $char->getSkillLevel($skill),
				$config{"attackComboSlot_${slot}_maxCastTime"},
				$config{"attackComboSlot_${slot}_minCastTime"},
				$isSelfSkill ? $char : $target,
				undef,
				$config{"attackComboSlot_${slot}_waitBeforeUse"},
			);
			$args->{monsterID} = $ID;
		}

	} elsif ($config{tankMode}) {
		if ($args->{dmgTo_last} != $target->{dmgTo}) {
			$args->{ai_attack_giveup}{time} = time;
		}
		$args->{dmgTo_last} = $target->{dmgTo};
	}

	Plugins::callHook('AI::Attack::main', {target => $target})
}

1;
