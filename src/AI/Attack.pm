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
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use constant {
	MOVING_TO_ATTACK => 1,
	ATTACKING => 2,
};

sub process {
	Benchmark::begin("ai_attack") if DEBUG;
	my $args = AI::args;
	my $action = AI::action;

	if (shouldAttack($action, $args)) {
		my $ID;
		my $ataqArgs;
		my $stage; # 1 - moving to attack | 2 - attacking
		if (AI::action eq "attack") {
			$ID = $args->{ID};
			$ataqArgs = AI::args(0);
			$stage = ATTACKING;
		} else {
			if (AI::action(1) eq "attack") {
				$ataqArgs = AI::args(1);

			} elsif (AI::action(2) eq "attack") {
				$ataqArgs = AI::args(2);
			}
			$ID = $args->{attackID};
			$stage = MOVING_TO_ATTACK;
		}

		if (targetGone($ataqArgs, $ID)) {
			finishAttacking($ataqArgs, $ID);
			return;
		} elsif (shouldGiveUp($ataqArgs, $ID)) {
			giveUp($ataqArgs, $ID, 0);
			return;
		}

		my $target = Actor::get($ID);
		unless ($target && $target->{type} ne 'Unknown') {
			finishAttacking($ataqArgs, $ID);
			return;
		}

		my $party = $config{'attackAuto_party'} ? 1 : 0;
		my $target_is_aggressive = is_aggressive($target, undef, 0, $party);

		if ($config{attackChangeTarget}) {
			my $routeIndex = AI::findAction("route");
			$routeIndex = AI::findAction("mapRoute") if (!defined $routeIndex);
			my $attackOnRoute;
			if (defined $routeIndex) {
				$attackOnRoute = AI::args($routeIndex)->{attackOnRoute};
			} else {
				$attackOnRoute = 2;
			}

			my @aggressives = ai_getAggressives($attackOnRoute, $party);

			if (!$target_is_aggressive && @aggressives) {
				my $attackTarget = getBestTarget(\@aggressives, $config{attackCheckLOS}, $config{attackCanSnipe});
				if ($attackTarget && $attackTarget ne $target->{ID}) {
					$char->sendAttackStop;
					AI::dequeue 
					while (AI::inQueue("attack"));
					ai_setSuspend(0);
					my $new_target = Actor::get($attackTarget);
					warning TF("Your target is not aggressive: %s, changing target to aggressive: %s.\n", $target, $new_target), 'ai_attack';
					$target->{droppedForAggressive} = 1;
					$char->attack($attackTarget);
					AI::Attack::process();
					return;
				}
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
				ai_useTeleport(1);
			}
			return;
		}
		
		my $control = mon_control($target->{name},$target->{nameID});
		if ($control->{attack_auto} == 3 && ($target->{dmgToYou} || $target->{missedYou} || $target->{dmgFromYou})) {
			message TF("Dropping target - %s (%s) has been provoked\n", $target->{name}, $target->{binID});
			$char->sendAttackStop;
				$target->{ignore} = 1;
			AI::dequeue while (AI::inQueue("attack"));
			return;
		}
		
		my %plugin_args;
		$plugin_args{target} = $target;
		$plugin_args{control} = $control;
		$plugin_args{stage} = $stage;
		$plugin_args{party} = $party;
		$plugin_args{target_is_aggressive} = $target_is_aggressive;
		$plugin_args{return} = 0;
		Plugins::callHook('AI::Attack::process' => \%plugin_args);
		return if ($plugin_args{return});
		
		if ($stage == MOVING_TO_ATTACK) {
			# Check for hidden monsters
			if (($target->{statuses}->{EFFECTSTATE_BURROW} || $target->{statuses}->{EFFECTSTATE_HIDING}) && $config{avoidHiddenMonsters}) {
				message TF("Dropping target %s - will not attack hidden monsters\n", $target), 'ai_attack';
				$char->sendAttackStop;
				$target->{ignore} = 1;

				AI::dequeue while (AI::inQueue("attack"));
				if ($config{teleportAuto_dropTargetHidden}) {
					message T("Teleport due to dropping hidden target\n");
					ai_useTeleport(1);
				}
				return;
			}

			# We're on route to the monster; check whether the monster has moved
			if ($args->{attackID} && timeOut($timeout{ai_attack_route_adjust})) {
				if (
					$target->{type} ne 'Unknown' &&
					$ataqArgs->{monsterLastMoveTime} &&
					$ataqArgs->{monsterLastMoveTime} != $target->{time_move}
				) {
					if (
						($args->{monsterLastMovePosTo}{x} == $target->{pos_to}{x} && $args->{monsterLastMovePosTo}{y} == $target->{pos_to}{y})
					) {
						$args->{monsterLastMoveTime} = $target->{time_move};
						$args->{monsterLastMovePosTo}{x} = $target->{pos_to}{x};
						$args->{monsterLastMovePosTo}{y} = $target->{pos_to}{y};
					} else {
						# Monster has moved; stop moving and let the attack AI readjust route
						debug "Target $target has moved since we started routing to it - Adjusting route\n", "ai_attack";
						AI::dequeue while (AI::is("move", "route"));

						$ataqArgs->{ai_attack_giveup}{time} = time;
						$ataqArgs->{sentApproach} = 0;
						undef $args->{unstuck}{time};
						undef $args->{avoiding};
						undef $args->{move_start};
					}
				} else {
					$timeout{ai_attack_route_adjust}{time} = time;
				}
			}
		}

		if ($stage == ATTACKING) {
			if (AI::args->{suspended}) {
				$args->{ai_attack_giveup}{time} += time - $args->{suspended};
				delete $args->{suspended};

			# We've just finished moving to the monster.
			# Don't count the time we spent on moving
			} elsif ($args->{move_start}) {
				$args->{ai_attack_giveup}{time} += time - $args->{move_start};
				undef $args->{unstuck}{time};
				undef $args->{move_start};

			} elsif ($args->{avoiding}) {
				$args->{ai_attack_giveup}{time} = time;
				undef $args->{avoiding};
				debug "Finished avoiding movement from target $target, updating ai_attack_giveup\n", "ai_attack";
			}

			if (timeOut($timeout{ai_attack_main})) {
				if ($char->{sitting}) {
					ai_setSuspend(0);
					stand();
				} else {
					main();
				}
				$timeout{ai_attack_main}{time} = time;
			}

		}
	}

	Benchmark::end("ai_attack") if DEBUG;
}

sub shouldAttack {
    my ($action, $args) = @_;
    return (
        ($action eq "attack" && $args->{ID}) ||
        ($action eq "route" && AI::action(1) eq "attack" && $args->{attackID}) ||
        ($action eq "move" && AI::action(2) eq "attack" && $args->{attackID})
    );
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
		ai_useTeleport(1);
	}
}

sub targetGone {
	my ($args, $ID) = @_;
	my $target = Actor::get($ID, 1);
	unless ($target) {
		return 1;
	}
	if (exists $target->{dead} && $target->{dead} == 1) {
		return 1;
	}
	return 0;
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
		ai_useTeleport(1);
	} else {
		message T("Target lost\n"), "ai_attack";
	}

	$messageSender->sendStopSkillUse($char->{last_continuous_skill_used}) if $char->{last_skill_used_is_continuous};
	Plugins::callHook('attack_end', {ID => $ID})
}

sub find_kite_position {
	my ($args, $inAdvance, $target, $realMyPos, $realMonsterPos, $noAttackMethodFallback_runFromTarget) = @_;

	my $maxDistance;
	if (!$noAttackMethodFallback_runFromTarget && defined $args->{attackMethod}{type} && defined $args->{attackMethod}{maxDistance}) {
		$maxDistance = $args->{attackMethod}{maxDistance};
	} elsif ($noAttackMethodFallback_runFromTarget) {
		$maxDistance = $config{'runFromTarget_noAttackMethodFallback_attackMaxDist'};
	} else {
		# Should never happen.
		return 0;
	}

	# We try to find a position to kite from at least runFromTarget_minStep away from the target but at maximun {attackMethod}{maxDistance} away from it
	my $pos = meetingPosition($char, 1, $target, $maxDistance, ($noAttackMethodFallback_runFromTarget ? 2 : 1));
	if ($pos) {
		if ($inAdvance) {
			debug TF("[runFromTarget_inAdvance] %s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} elsif ($noAttackMethodFallback_runFromTarget) {
			debug TF("[runFromTarget_noAttackMethodFallback] %s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} else {
			debug TF("[runFromTarget] (attackmaxDistance %s) %s kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $maxDistance, $char, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		}
		$args->{avoiding} = 1;
		$char->route(
			undef,
			@{$pos}{qw(x y)},
			noMapRoute => 1,
			avoidWalls => 0,
			randomFactor => 0,
			useManhattan => 1,
			runFromTarget => 1
		);
		return 1;

	} else {
		if ($inAdvance) {
			debug TF("[runFromTarget_inAdvance] %s no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} elsif ($noAttackMethodFallback_runFromTarget) {
			debug TF("[runFromTarget_noAttackMethodFallback] %s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} else {
			debug TF("[runFromTarget] %s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $char, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		}
		return 0;
	}
}

sub main {
	my $args = AI::args;

	Benchmark::begin("ai_attack (part 1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.1)") if DEBUG;
	# The attack sequence hasn't timed out and the monster is on screen

	# Update information about the monster and the current situation
	my $args = AI::args;
	my $ID = $args->{ID};

	if (!defined $ID) {
		warning "[attack main] Bug where ID is undefined found.\n";
		warning "Args Dump: " . Dumper($args);
		warning "ML Dump: " . Dumper(\@$monstersList);
		warning "ai_seq Dump: " . Dumper(\@ai_seq);
		warning "ai_seq_args Dump: " . Dumper(\@ai_seq_args);
	}

	my $target = Actor::get($ID);

	if (!exists $args->{temporary_extra_range} || !defined $args->{temporary_extra_range}) {
		$args->{temporary_extra_range} = 0;
	}

	if (exists $char->{movetoattack_pos}) {
		if (!exists $char->{movetoattack_targetID} || $char->{movetoattack_targetID} ne $ID || $char->{time_move} > $char->{movetoattack_time}) {
			delete $char->{movetoattack_pos};
		} else {
			my $time_since_char_moved = time - $char->{time_move};
			if ($time_since_char_moved > $char->{time_move_calc}) {
				debug "[Attack] [Char] Fixing failed to attack target, setting char position to: $char->{movetoattack_pos}{x} $char->{movetoattack_pos}{y}\n", "ai_attack";
				$char->{pos}{x} = $char->{movetoattack_pos}{x};
				$char->{pos}{y} = $char->{movetoattack_pos}{y};
				$char->{pos_to}{x} = $char->{movetoattack_pos}{x};
				$char->{pos_to}{y} = $char->{movetoattack_pos}{y};
				$char->{time_move} = time;
				$char->{time_move_calc} = 0;
				delete $char->{movetoattack_pos};
			}
		}
	}

	if (exists $target->{movetoattack_pos}) {
		if ($target->{time_move} > $target->{movetoattack_time}) {
			delete $target->{movetoattack_pos};
		} else {
			my $target_solution = get_solution($field, $target->{pos}, $target->{pos_to});
			my $target_time_to_move = calcTimeFromSolution($target_solution, $target->{walk_speed});
			my $time_since_target_moved = time - $target->{time_move};
			if ($time_since_target_moved > $target_time_to_move) {
				debug "[Attack] [Target] Fixing failed to attack target, setting target $target position to: $target->{movetoattack_pos}{x} $target->{movetoattack_pos}{y}\n", "ai_attack";
				$target->{pos}{x} = $target->{movetoattack_pos}{x};
				$target->{pos}{y} = $target->{movetoattack_pos}{y};
				$target->{pos_to}{x} = $target->{movetoattack_pos}{x};
				$target->{pos_to}{y} = $target->{movetoattack_pos}{y};
				$target->{time_move} = time;
				$target->{time_move_calc} = 0;
				delete $target->{movetoattack_pos};
			}
		}
	}

	my $myPos = $char->{pos_to};
	my $monsterPos = $target->{pos_to};
	my $monsterDist = blockDistance($myPos, $monsterPos);

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

	if (!exists $args->{firstLoop}) {
		$args->{firstLoop} = 1;
	} else {
		$args->{firstLoop} = 0;
	}
	
	my $hitYou = ($args->{dmgToYou_last} != $target->{dmgToYou} || $args->{missedYou_last} != $target->{missedYou});
	my $youHitTarget = ($args->{dmgFromYou_last} != $target->{dmgFromYou} || $args->{missedFromYou_last} != $target->{missedFromYou});
	
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
		next unless (defined $config{"attackComboSlot_$i"});

		next unless (checkSelfCondition("attackComboSlot_$i"));
		next unless ($config{"attackComboSlot_${i}_afterSkill"});
		next unless (Skill->new(auto => $config{"attackComboSlot_${i}_afterSkill"})->getIDN == $char->{last_skill_used});
		next unless (( !$config{"attackComboSlot_${i}_maxUses"} || $args->{attackComboSlot_uses}{$i} < $config{"attackComboSlot_${i}_maxUses"} ));
		next unless (( !$config{"attackComboSlot_${i}_autoCombo"} || ($char->{combo_packet} && $config{"attackComboSlot_${i}_autoCombo"}) ));
		next unless (( !defined($args->{ID}) || $args->{ID} eq $char->{last_skill_target} || !$config{"attackComboSlot_${i}_isSelfSkill"}));
		next unless ((!$config{"attackComboSlot_${i}_monsters"} || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{name}) || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{nameID})));
		next unless ((!$config{"attackComboSlot_${i}_notMonsters"} || !(existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{name}) || existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{nameID}))));
		next unless (checkMonsterCondition("attackComboSlot_${i}_target", $target));

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
		last;
	} continue {
		$i++;
	}

	# Determine what skill to use to attack
	if (!$args->{attackMethod}{type}) {
		if ($config{'attackUseWeapon'}) {
			$args->{attackMethod}{type} = "weapon";
			$args->{attackMethod}{distance} = $config{'attackDistance'};
			$args->{attackMethod}{maxDistance} = $config{'attackMaxDistance'};
		} else {
			undef $args->{attackMethod}{type};
			$args->{attackMethod}{distance} = 1;
			$args->{attackMethod}{maxDistance} = 1;
		}

		$i = 0;
		while (exists $config{"attackSkillSlot_$i"}) {
			next unless (defined $config{"attackSkillSlot_$i"});

			my $skill = new Skill(auto => $config{"attackSkillSlot_$i"});
			next unless ($skill);
			next unless ($skill->getOwnerType == Skill::OWNER_CHAR);

			my $handle = $skill->getHandle();

			next unless (checkSelfCondition("attackSkillSlot_$i"));
			next unless ((!$config{"attackSkillSlot_$i"."_maxUses"} || $target->{skillUses}{$handle} < $config{"attackSkillSlot_$i"."_maxUses"}));
			next unless ((!$config{"attackSkillSlot_$i"."_maxAttempts"} || $args->{attackSkillSlot_attempts}{$i} < $config{"attackSkillSlot_$i"."_maxAttempts"}));
			next unless ((!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{'name'}) || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{nameID})));
			next unless ((!$config{"attackSkillSlot_$i"."_notMonsters"} || !(existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{'name'}) ||existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{nameID}))));
			next unless ((!$config{"attackSkillSlot_$i"."_previousDamage"} || inRange($target->{dmgTo}, $config{"attackSkillSlot_$i"."_previousDamage"})));
			next unless (checkMonsterCondition("attackSkillSlot_${i}_target", $target));

			$args->{attackMethod}{type} = "skill";
			$args->{attackMethod}{skillSlot} = $i;
			$args->{attackMethod}{distance} = $config{"attackSkillSlot_$i"."_dist"};
			$args->{attackMethod}{maxDistance} = $config{"attackSkillSlot_$i"."_maxDist"} || $config{"attackSkillSlot_$i"."_dist"};
			last;
		} continue {
			$i++;
		}
	}

	$args->{attackMethod}{maxDistance} ||= $config{attackMaxDistance};
	$args->{attackMethod}{distance} ||= $config{attackDistance};

	if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
		$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
	}

	Benchmark::end("ai_attack (part 1.2)") if DEBUG;
	Benchmark::end("ai_attack (part 1)") if DEBUG;

	if (defined $args->{attackMethod}{type} && exists $args->{ai_attack_failed_give_up} && defined $args->{ai_attack_failed_give_up}{time}) {
		debug "Deleting ai_attack_failed_give_up time.\n";
		delete $args->{ai_attack_failed_give_up}{time};

	}

	$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};

	# -2: undefined attackMethod
	# -1: No LOS
	#  0: out of range
	#  1: sucess
	my $canAttack;
	if (defined $args->{attackMethod}{type} && defined $args->{attackMethod}{maxDistance}) {
		$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{attackCanSnipe}, $args->{attackMethod}{maxDistance}, $config{clientSight});
	} else {
		$canAttack = -2;
	}

	my $canAttack_fail_string = (($canAttack == -2) ? "No Method" : (($canAttack == -1) ? "No LOS" : (($canAttack == 0) ? "No Range" : "OK")));

	# Here we check if the monster which we are waiting to get closer to us is in fact close enough
	# If it is close enough delete the ai_attack_failed_waitForAgressive_give_up keys and loop attack logic
	if (
		$config{"attackBeyondMaxDistance_waitForAgressive"} &&
		$target->{dmgFromYou} > 0 &&
		$canAttack == 1 &&
		exists $args->{ai_attack_failed_waitForAgressive_give_up} &&
		defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
	}

	# Here we check if we have finished moving to the meeting position to attack our target, only checks this if attackWaitApproachFinish is set to 1 in config
	# If so sets sentApproach to 0
	if ($args->{sentApproach}) {
		if ($config{"attackWaitApproachFinish"}) {
			if (!timeOut($char->{time_move}, $char->{time_move_calc})) {
				debug TF("[attackWaitApproachFinish - Waiting] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
				return;
			} else {
				debug TF("[attackWaitApproachFinish - Ended Approaching] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
				$args->{sentApproach} = 0;
			}
		} else {
			if ($canAttack == 2) {
				debug TF("[Approaching - Can now attack] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
				$args->{sentApproach} = 0;
			} elsif (timeOut($char->{time_move}, $char->{time_move_calc})) {
				debug TF("[Approaching - Ended] Still no LOS/Range - %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
				$args->{sentApproach} = 0;
			}
		}
	}

	my $found_action = 0;
	my $failed_runFromTarget = 0;
	my $hitTarget_when_not_possible = 0;

	# Here, if runFromTarget is active, we check if the target mob is closer to us than the minimun distance specified in runFromTarget_dist
	# If so try to kite it
	if (
		!$found_action &&
		$config{"runFromTarget"} &&
		$realMonsterDist < $config{"runFromTarget_dist"}
	) {
		my $try_runFromTarget = find_kite_position($args, 0, $target, $realMyPos, $realMonsterPos, 0);
		if ($try_runFromTarget) {
			$found_action = 1;
		} else {
			$failed_runFromTarget = 1;
		}
	}

	# Here, if runFromTarget is active, and we can't attack right now (eg. all skills in cooldown) we check if the target mob is closer to us than the minimun distance specified in runFromTarget_noAttackMethodFallback_minStep
	# If so try to kite it using maxdistance of runFromTarget_noAttackMethodFallback_attackMaxDist
	if (
		!$found_action &&
		$canAttack  == -2 &&
		#$config{"runFromTarget"} &&
		$config{'runFromTarget_noAttackMethodFallback'} &&
		$realMonsterDist < $config{'runFromTarget_noAttackMethodFallback_minStep'}
	) {
		my $try_runFromTarget = find_kite_position($args, 0, $target, $realMyPos, $realMonsterPos, 1);
		if ($try_runFromTarget) {
			$found_action = 1;
		}
	}

	if (
		!$found_action &&
		$canAttack  == -2
	) {
		debug T("Can't determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), "ai_attack";
		$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
		$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
		if (timeOut($args->{ai_attack_failed_give_up})) {
			delete $args->{ai_attack_failed_give_up}{time};
			warning T("Unable to determine a attackMethod (check attackUseWeapon and Skills blocks), dropping target.\n"), "ai_attack";
			$found_action = 1;
			giveUp($args, $ID, 0);
		}
	}
	
	if (!$args->{firstLoop} && $canAttack == 0 && $youHitTarget) {
		debug TF("[%s] We were able to hit target even though it is out of range or LOS, accepting and continuing. (you %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d, dmgFromYou %d)\n", $canAttack_fail_string, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
		if ($clientDist > $args->{attackMethod}{maxDistance} && $clientDist <= ($args->{attackMethod}{maxDistance} + 1) && $args->{temporary_extra_range} == 0) {
			debug TF("[%s] Probably extra range provided by the server due to chasing, increasing range by 1.\n", $canAttack_fail_string), 'ai_attack';
			$args->{temporary_extra_range} = 1;
			$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};
			$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{attackCanSnipe}, $args->{attackMethod}{maxDistance}, $config{clientSight});
		} else {
			debug TF("[%s] Reason unknown, allowing once.\n", $canAttack_fail_string), 'ai_attack';
			$hitTarget_when_not_possible = 1;
		}
		if (
			$config{"attackBeyondMaxDistance_waitForAgressive"} &&
			exists $args->{ai_attack_failed_waitForAgressive_give_up} &&
			defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
		) {
			debug "[Accepting] Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};;
		}
	}

	# Here we decide what to do when a mob we have already hit is no longer in range or we have no LOS to it
	# We also check if we have waited too long for the monster which we are waiting to get closer to us to approach
	# TODO: Maybe we should separate this into 2 sections, one for out of range and another for no LOS - low priority
	if (
		!$found_action &&
		$config{"attackBeyondMaxDistance_waitForAgressive"} &&
		$target->{dmgFromYou} > 0 &&
		($canAttack == 0 || $canAttack == -1) &&
		!$hitTarget_when_not_possible
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};
		if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
			warning TF("[%s] Waited too long for target to get closer, dropping target. (you %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d, dmgFromYou %d)\n", $canAttack_fail_string, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			giveUp($args, $ID, 0);
		} else {
			$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7) if ($config{"attackBeyondMaxDistance_sendAttackWhileWaiting"});
			debug TF("[%s - Waiting] %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d, dmgFromYou %d.\n", $canAttack_fail_string, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
		}
		$found_action = 1;
	}

	# Here we decide what to do with a mob which is out of range or we have no LOS to
	if (
		!$found_action &&
		($canAttack == 0 || $canAttack == -1) &&
		!$hitTarget_when_not_possible
	) {
		debug "Attack $char ($realMyPos->{x} $realMyPos->{y}) - target $target ($realMonsterPos->{x} $realMonsterPos->{y})\n";
		if ($canAttack == 0) {
			debug "[Attack] [No range] Too far from us to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';

		} elsif ($canAttack == -1) {
			debug "[Attack] [No LOS] No LOS from player to mob\n", 'ai_attack';
		}

		my $pos = meetingPosition($char, 1, $target, $args->{attackMethod}{maxDistance});
		if ($pos) {
			debug "Attack $char ($realMyPos->{x} $realMyPos->{y}) - moving to meeting position ($pos->{x} $pos->{y})\n", 'ai_attack';

			$args->{move_start} = time;
			$args->{monsterLastMoveTime} = $target->{time_move};
			$args->{sentApproach} = 1;

			my $sendAttackWithMove = 0;
			if ($config{"attackSendAttackWithMove"} && $args->{attackMethod}{type} eq "weapon") {
				$sendAttackWithMove = 1;
			}

			$char->route(
				undef,
				@{$pos}{qw(x y)},
				maxRouteTime => $config{'attackMaxRouteTime'},
				attackID => $ID,
				sendAttackWithMove => $sendAttackWithMove,
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
		$found_action = 1;
	}

	if (
		!$found_action &&
		(!$config{"runFromTarget"} || $realMonsterDist >= $config{"runFromTarget_dist"} || $failed_runFromTarget) &&
		(!$config{"tankMode"} || !$target->{dmgFromYou})
	 ) {
		# Attack the target. In case of tanking, only attack if it hasn't been hit once.
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			debug "Ready to attack target $target ($realMonsterPos->{x} $realMonsterPos->{y}) ($realMonsterDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
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

		# Attack with weapon logic
		if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_attack}) && timeOut($timeout{ai_attack_after_skill})) {
			if (Actor::Item::scanConfigAndCheck("attackEquip")) {
				#check if item needs to be equipped
				Actor::Item::scanConfigAndEquip("attackEquip");
			} else {
				debug "[Attack] Sending attack target $target ($realMonsterPos->{x} $realMonsterPos->{y}) ($realMonsterDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
				$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7);
				$timeout{ai_attack}{time} = time;
				delete $args->{attackMethod};

				if ($config{"runFromTarget"} && $config{"runFromTarget_inAdvance"} && $realMonsterDist < $config{"runFromTarget_minStep"}) {
					find_kite_position($args, 1, $target, $realMyPos, $realMonsterPos, 0);
				}
			}
			$found_action = 1;

		# Attack with skill logic
		} elsif ($args->{attackMethod}{type} eq "skill") {
			my $slot = $args->{attackMethod}{skillSlot};
			delete $args->{attackMethod};

			$ai_v{"attackSkillSlot_${slot}_time"} = time;
			$ai_v{"attackSkillSlot_${slot}_target_time"}{$ID} = time;

			$args->{attackSkillSlot_attempts}{$slot}++;

			ai_setSuspend(0);
			my $skill = new Skill(auto => $config{"attackSkillSlot_$slot"});
			my $skill_lvl = $config{"attackSkillSlot_${slot}_lvl"} || $char->getSkillLevel($skill);
			ai_skillUse2(
				$skill,
				$skill_lvl,
				$config{"attackSkillSlot_${slot}_maxCastTime"},
				$config{"attackSkillSlot_${slot}_minCastTime"},
				$config{"attackSkillSlot_${slot}_isSelfSkill"} ? $char : $target,
				"attackSkillSlot_${slot}",
				undef,
				"attackSkill",
				$config{"attackSkillSlot_${slot}_isStartSkill"} ? 1 : 0,
			);
			debug "[attackSkillSlot] Auto-skill on monster ".getActorName($ID).": ".qq~$config{"attackSkillSlot_$slot"} (lvl $skill_lvl)\n~, "ai_attack";
			# TODO: We sould probably add a runFromTarget_inAdvance logic here also, we could want to kite using skills, but only instant cast ones like double strafe I believe

			$timeout{ai_attack_after_skill}{time} = time;

			$args->{monsterID} = $ID;
			$found_action = 1;

		# Attack with combo logic
		} elsif ($args->{attackMethod}{type} eq "combo") {
			my $slot = $args->{attackMethod}{comboSlot};
			delete $args->{attackMethod};

			$ai_v{"attackComboSlot_${slot}_time"} = time;
			$ai_v{"attackComboSlot_${slot}_target_time"}{$ID} = time;

			my $skill = Skill->new(auto => $config{"attackComboSlot_$slot"});
			my $skill_lvl = $config{"attackComboSlot_${slot}_lvl"} || $char->getSkillLevel($skill);
			ai_skillUse2(
				$skill,
				$skill_lvl,
				$config{"attackComboSlot_${slot}_maxCastTime"},
				$config{"attackComboSlot_${slot}_minCastTime"},
				$config{"attackComboSlot_${slot}_isSelfSkill"} ? $char : $target,
				undef,
				$config{"attackComboSlot_${slot}_waitBeforeUse"},
			);

			$args->{monsterID} = $ID;
			$found_action = 1;
		}

	}

	if (!$found_action && $config{tankMode}) {
		if ($args->{dmgTo_last} != $target->{dmgTo}) {
			$args->{ai_attack_giveup}{time} = time;
			$char->sendAttackStop;
		}
		$args->{dmgTo_last} = $target->{dmgTo};
		$found_action = 1;
	}

	Plugins::callHook('AI::Attack::main', {target => $target})
}

1;
