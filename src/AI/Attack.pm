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

# Internal stages used to tell whether the AI is still closing distance
# or is already inside the active combat loop for a target.
use constant {
	MOVING_TO_ATTACK => 1,
	ATTACKING => 2,
};

sub process {
	# `process` is the lightweight dispatcher that watches the current AI queue,
	# validates the target, and decides whether we should continue into `main`.
	Benchmark::begin("ai_attack") if DEBUG;
	my $args = AI::args();
	my $action = AI::action();

	if (shouldAttack($action, $args)) {
		my $ID;
		my $ataqArgs;
		my $stage; # 1 - moving to attack | 2 - attacking
		# Figure out whether we are already attacking or are still moving/routeing
		# toward a queued attack target.
		if (AI::action() eq "attack") {
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

		# Stop immediately if the target disappeared or can no longer be resolved.
		if (targetGone($ataqArgs, $ID)) {
			finishAttacking($ataqArgs, $ID);
			return;
		}

		my $target = Actor::get($ID);
		unless ($target && $target->{type} ne 'Unknown') {
			finishAttacking($ataqArgs, $ID);
			return;
		}

		my $routeIndex = AI::findAction("route");
		$routeIndex = AI::findAction("mapRoute") if (!defined $routeIndex);
		my $routeArgs = defined $routeIndex ? AI::args($routeIndex) : undef;
		my $effectiveAttackMode = getEffectiveAttackOnRoute($routeArgs);
		my $assistParty = ($effectiveAttackMode >= 1 && $config{'attackAuto_party'}) ? 1 : 0;
		my $target_is_aggressive = is_aggressive($target, undef, 0, $assistParty);
		my $control = mon_control($target->{name},$target->{nameID});
		
		# Expose the current attack context so plugins can veto or alter handling.
		my %plugin_args;
		$plugin_args{target} = $target;
		$plugin_args{control} = $control;
		$plugin_args{stage} = $stage;
		$plugin_args{party} = $assistParty;
		$plugin_args{target_is_aggressive} = $target_is_aggressive;
		$plugin_args{actor} = $char;
		$plugin_args{configPrefix} = '';
		$plugin_args{return} = 0;
		Plugins::callHook('shouldDropTarget' => \%plugin_args);
		if ($plugin_args{return}) {
			giveUp($ataqArgs, $ID, 2);
			return;
		}

		# Abort when we have spent too long trying to reach or damage the target.
		if (shouldGiveUp($ataqArgs, $ID)) {
			message T("Can't reach or damage target\n"), "ai_attack";
			giveUp($ataqArgs, $ID, 0);
			return;
		}

		# Optionally swap to a more urgent aggressive target when our current one
		# is passive, or when another aggressive target has a higher priority.txt
		# priority than the monster we are currently hitting.
		if ($config{attackChangeTarget}) {
			my $aggressiveType = ($effectiveAttackMode >= 2) ? 2 : 0;
			my @aggressives = $effectiveAttackMode >= 0 ? ai_getAggressives($aggressiveType, $assistParty) : ();

			if (@aggressives) {
				my $attackTarget = getBestTarget(\@aggressives, $config{attackCheckLOS}, $config{attackCanSnipe}, $char, '');
				if ($attackTarget && $attackTarget ne $target->{ID}) {
					my $new_target = Actor::get($attackTarget);
					my $current_priority = Misc::monsterPriority($target->{name}, $target->{nameID});
					my $new_priority = Misc::monsterPriority($new_target->{name}, $new_target->{nameID});
					my $switch_to_aggressive = !$target_is_aggressive;
					my $switch_to_higher_priority = $target_is_aggressive && $new_priority > $current_priority;

					if ($switch_to_aggressive || $switch_to_higher_priority) {
						$char->sendAttackStop;
						AI::dequeue() while ( AI::inQueue("attack") );
						ai_setSuspend(0);
						if ($switch_to_higher_priority) {
							warning TF("Changing target to higher priority monster: %s -> %s.\n", $target, $new_target), 'ai_attack';
						} else {
							warning TF("Your target is not aggressive: %s, changing target to aggressive: %s.\n", $target, $new_target), 'ai_attack';
						}
						$target->{droppedForAggressive} = 1;
						$char->attack($attackTarget);
						AI::Attack::process();
						return;
					}
				}
			}
		}

		# Refuse targets that would count as kill-stealing according to the
		# configured monster ownership rules.
		my $cleanMonster = checkMonsterCleanness($ID);
		if (!$cleanMonster) {
			message TF("Dropping target %s - will not kill steal others\n", $target), 'ai_attack';
			$char->sendAttackStop;
			$target->{ignore} = 1;
			AI::dequeue() while (AI::inQueue("attack"));
			if ($config{teleportAuto_dropTargetKS}) {
				message T("Teleport due to dropping attack target\n"), "teleport";
				ai_useTeleport(1);
			}
			return;
		}
		
		# `attack_auto == 3` means "only untouched monsters", so drop anything
		# that has already interacted with us or been attacked.
		if ($control->{attack_auto} == 3 && ($target->{dmgToYou} || $target->{missedYou} || $target->{dmgFromYou})) {
			message TF("Dropping target - %s (%s) has been provoked\n", $target->{name}, $target->{binID});
			$char->sendAttackStop;
				$target->{ignore} = 1;
			AI::dequeue() while (AI::inQueue("attack"));
			return;
		}
		
		if ($stage == MOVING_TO_ATTACK) {
			# Check for hidden monsters
			if (($target->{statuses}->{EFFECTSTATE_BURROW} || $target->{statuses}->{EFFECTSTATE_HIDING}) && $config{avoidHiddenMonsters}) {
				message TF("Dropping target %s - will not attack hidden monsters\n", $target), 'ai_attack';
				$char->sendAttackStop;
				$target->{ignore} = 1;

				AI::dequeue() while (AI::inQueue("attack"));
				if ($config{teleportAuto_dropTargetHidden}) {
					message T("Teleport due to dropping hidden target\n");
					ai_useTeleport(1);
				}
				return;
			}

			# While routeing in, recalculate if the monster changed course since we
			# started approaching it.
			if ($args->{attackID} && approach_target_route_needs_reset($ataqArgs, $target)) {
				reset_approach_for_moved_target($ataqArgs, $target);
				return;
			}
		}

		if ($stage == ATTACKING) {
			# Keep the give-up timer fair by discounting time spent suspended,
			# approaching, or performing anti-stuck / avoidance movement.
			if (AI::args()->{suspended}) {
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

			# Throttle the heavy combat loop; `main` performs the expensive
			# positioning, skill, and attack decisions.
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
    # Return true only when the AI queue represents an attack directly, or a
    # route/move action that is merely the lead-in for an attack.
    my ($action, $args) = @_;
    return (
        ($action eq "attack" && $args->{ID}) ||
        ($action eq "route" && AI::action(1) eq "attack" && $args->{attackID}) ||
        ($action eq "move" && AI::action(2) eq "attack" && $args->{attackID})
    );
}

sub shouldGiveUp {
	# Give up after the configured timeout unless attackNoGiveup is active, or
	# after too many anti-stuck retries.
	my ($args, $ID) = @_;
	return !$config{attackNoGiveup} && (timeOut($args->{ai_attack_giveup}) || $args->{unstuck}{count} > 5);
}

sub approach_target_route_needs_reset {
	# Detect whether the target moved to a new destination after we already
	# committed to an approach route, which makes the old meeting point stale.
	my ($args, $target) = @_;
	return 0 unless $args && $target;
	return 0 if $target->{type} eq 'Unknown';
	return 0 unless $args->{sentApproach};
	return 0 unless $args->{monsterLastMoveTime};
	return 0 unless $args->{monsterLastMoveTime} != $target->{time_move};
	return 0 unless $target->{pos_to};

	if ($args->{monsterLastMovePosTo}) {
		return 0
			if $args->{monsterLastMovePosTo}{x} == $target->{pos_to}{x}
			&& $args->{monsterLastMovePosTo}{y} == $target->{pos_to}{y};
	}

	return 1;
}

sub reset_approach_for_moved_target {
	# Clear route-specific state so the next pass can compute a fresh approach
	# path for the monster's new movement direction.
	my ($args, $target) = @_;
	return unless $args && $target;

	debug "Target $target has moved since we started routing to it - Adjusting route\n", "ai_attack";
	AI::dequeue() while (AI::is("move", "route"));

	$args->{ai_attack_giveup}{time} = time;
	$args->{sentApproach} = 0;
	$args->{monsterLastMoveTime} = $target->{time_move};
	$args->{monsterLastMovePosTo} = { %{$target->{pos_to}} } if $target->{pos_to};
	undef $args->{unstuck}{time};
	undef $args->{avoiding};
	undef $args->{move_start};
}

sub giveUp {
	# Centralized cleanup for abandoned targets. This records why we failed,
	# clears attack queue state, and optionally teleports away.
	my ($args, $ID, $reason) = @_;
	my $target = Actor::get($ID);
	if ($monsters{$ID}) {
		if ($reason == 1) {
			$target->{attack_failedLOS} = time;
		} elsif ($reason == 0) {
			$target->{attack_failed} = time;
		}
	}
	$target->{dmgFromYou} = 0; # Hack | TODO: Fix me
	AI::dequeue() while (AI::inQueue("attack"));
	message T("Dropping target\n"), "ai_attack";
	if ($config{'teleportAuto_dropTarget'}) {
		message T("Teleport due to dropping attack target\n");
		ai_useTeleport(1);
	} elsif ($config{'teleportAuto_dropTargetEngaged'} && ($target->{sentAttack} || $target->{engaged})) {
		message T("Teleport due to dropping attack target already engaged\n");
		ai_useTeleport(1);
	}
}

sub targetGone {
	# Treat missing or dead actors as gone so the attack loop can terminate
	# without waiting for additional state updates.
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
    # Finalize the encounter: clear the attack queue, run death/loss handling,
    # loot when appropriate, and notify hooks that combat has ended.
    my ($args, $ID) = @_;
    $timeout{'ai_attack'}{'time'} -= $timeout{'ai_attack'}{'timeout'};
    AI::dequeue() while (AI::inQueue("attack"));
    message TF( "Finished attacking\n"), "ai_attack";
    if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
        message TF("Target %s died\n", $monsters_old{$ID}), "ai_attack";
        Plugins::callHook('target_died', {monster => $monsters_old{$ID}});
        monKilled();

    # Pickup loot when monster's dead
		if (AI::state() == AI::AUTO() && $config{'itemsTakeAuto'} && $monsters_old{$ID}{dmgFromYou} > 0 && !$monsters_old{$ID}{ignore}) {
			AI::clear("items_take");
			ai_items_take($monsters_old{$ID}{pos}{x}, $monsters_old{$ID}{pos}{y},
				      $monsters_old{$ID}{pos_to}{x}, $monsters_old{$ID}{pos_to}{y});
		} else {
			# Cheap way to suspend all movement to make it look real
			ai_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
		}

		# Maintain the historical per-monster kill counters used elsewhere by the
		# bot and logs.
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
	# Try to find a safe retreat tile that preserves enough distance to keep
	# attacking, then launch a short route to that tile.
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

sub resolve_movetoattack_pos {
	# When local movement prediction says an actor should already have arrived,
	# snap its tracked position to the predicted endpoint to prevent desync.
	my ($actor) = @_;
	return unless (actorFinishedMovement($actor, $field));
	debug TF("[Attack] [%s] Fixing failed to attack target, setting actor position to: %s %s\n", $actor, $actor->{movetoattack_pos}{x}, $actor->{movetoattack_pos}{y} ), "ai_attack";
	$actor->{pos}{x} = $actor->{movetoattack_pos}{x};
	$actor->{pos}{y} = $actor->{movetoattack_pos}{y};
	$actor->{pos_to}{x} = $actor->{movetoattack_pos}{x};
	$actor->{pos_to}{y} = $actor->{movetoattack_pos}{y};
	$actor->{time_move} = time;
	$actor->{time_move_calc} = 0;
	$actor->{solution} = [];
	delete $actor->{movetoattack_pos};
}

sub main {
	# `main` is the core combat brain. It predicts movement, chooses the attack
	# method, handles kiting/chasing, and finally sends weapon or skill attacks.
	my $args = AI::args();
	my $ID = $args->{ID};

	if (!defined $ID) {
		warning "[attack main] Bug where ID is undefined found.\n";
		warning "Args Dump: " . Dumper($args);
		warning "ML Dump: " . Dumper(\@$monstersList);
		warning "ai_seq Dump: " . Dumper(\@ai_seq);
		warning "ai_seq_args Dump: " . Dumper(\@ai_seq_args);
		Plugins::callHook('undefined_object_id');
	}

	Benchmark::begin("ai_attack (part 1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.1)") if DEBUG;
	# The attack sequence hasn't timed out and the monster is on screen

	my $target = Actor::get($ID);

	# Reset per-loop range adjustments and reconcile any temporary predicted
	# positions left over from move-to-attack logic.
	if (!exists $args->{temporary_extra_range} || !defined $args->{temporary_extra_range}) {
		$args->{temporary_extra_range} = 0;
	}

	if (exists $char->{movetoattack_pos}) {
		if (!exists $char->{movetoattack_targetID} || $char->{movetoattack_targetID} ne $ID || $char->{time_move} > $char->{movetoattack_time}) {
			delete $char->{movetoattack_pos};
		} else {
			resolve_movetoattack_pos($char);
		}
	}

	if (exists $target->{movetoattack_pos}) {
		if ($target->{time_move} > $target->{movetoattack_time}) {
			delete $target->{movetoattack_pos};
		} else {
			resolve_movetoattack_pos($target);
		}
	}

	# Build a predicted "real" position for both player and monster so range and
	# line-of-sight checks are based on movement in flight, not only stale cells.
	my $extra_time = exists $timeout{'ai_route_position_prediction_delay'}{'timeout'} ? $timeout{'ai_route_position_prediction_delay'}{'timeout'} : 0.1;
	$extra_time = 0 unless (defined $extra_time);

	my $myPosTo = $char->{pos_to};
	my $monsterPos = $target->{pos_to};
	my $monsterDist = blockDistance($myPosTo, $monsterPos);

	my $realMyPos = calcPosFromPathfinding($field, $char, $extra_time, 1);
	my $realMonsterPos = calcPosFromPathfinding($field, $target, $extra_time, 1);

	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);
	my $clientDist = getClientDist($realMyPos, $realMonsterPos);

	if (!exists $args->{firstLoop}) {
		$args->{firstLoop} = 1;
	} else {
		$args->{firstLoop} = 0;
	}
	
	my $hitYou = ((defined $args->{dmgToYou_last} && $args->{dmgToYou_last} != $target->{dmgToYou}) || (defined $args->{missedYou_last} && $args->{missedYou_last} != $target->{missedYou})) ? 1 : 0;
	my $casOnYou = (defined $args->{castOnToYou_last} &&  $args->{castOnToYou_last} != $target->{castOnToYou}) ? 1 : 0;
	my $youHitTarget = ((defined $args->{dmgFromYou_last} && $args->{dmgFromYou_last} != $target->{dmgFromYou}) || (defined $args->{missedFromYou_last} && $args->{missedFromYou_last} != $target->{missedFromYou})) ? 1 : 0;
	
	# Any exchange of damage, misses, or casts marks the fight as engaged.
	if ($hitYou || $casOnYou || $args->{dmgFromYou_last} != $target->{dmgFromYou} || ($args->{firstLoop} && ($target->{dmgToYou} || $target->{missedYou} || $target->{dmgFromYou} || $target->{castOnToYou}))) {
		$target->{engaged} = 1 if (!exists $target->{engaged} || !$target->{engaged});
	}
	
	# If the damage numbers have changed, update the giveup time so we don't timeout
	if ($args->{dmgToYou_last}   != $target->{dmgToYou}
	 || $args->{missedYou_last}  != $target->{missedYou}
	 || $args->{dmgFromYou_last} != $target->{dmgFromYou}
	 || $args->{lastSkillTime} != $char->{last_skill_time}) {
		$args->{ai_attack_giveup}{time} = time;
		debug "Update attack giveup time\n", "ai_attack", 2;
	}
	
	$args->{dmgToYou_last} = $target->{dmgToYou};
	$args->{missedYou_last} = $target->{missedYou};
	$args->{castOnToYou_last} = $target->{castOnToYou};
	$args->{dmgFromYou_last} = $target->{dmgFromYou};
	$args->{missedFromYou_last} = $target->{missedFromYou};

	$args->{lastSkillTime} = $char->{last_skill_time};

	Benchmark::end("ai_attack (part 1.1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.2)") if DEBUG;

	# Highest priority: see whether we are in a combo window that should replace
	# the normal attack flow for this pass.
	delete $args->{attackMethod};

	my $combo_state = $char->{combo_state};
	if ($combo_state && (!defined $combo_state->{expires_at} || time >= $combo_state->{expires_at})) {
		debug TF("[Attack] [Combo] %s, target %s, combo %d expired at pass 1 (%s).\n", $char, , $target, $char->{combo_state}{source_skill}, $combo_state->{expires_at}), 'ai_attack';
		delete $char->{combo_state};
		$combo_state = undef;
	}

	my $i = 0;
	while (exists $config{"attackComboSlot_$i"}) {
		next unless (defined $config{"attackComboSlot_$i"});
		next unless ($config{"attackComboSlot_${i}_afterSkill"});

		my $after_skill_id = Skill->new(auto => $config{"attackComboSlot_${i}_afterSkill"})->getIDN;
		my $combo_source_skill = $combo_state ? $combo_state->{source_skill} : undef;
		my $combo_target_id = $combo_state ? $combo_state->{target_id} : undef;
		my $combo_delay = $combo_state ? $combo_state->{delay} : undef;
		my $expected_target_id = defined $combo_target_id ? $combo_target_id : $char->{last_skill_target};
		my $combo_wait_before_use = $config{"attackComboSlot_${i}_waitBeforeUse"};

		next unless (checkSelfCondition("attackComboSlot_$i"));
		next unless ($after_skill_id == $char->{last_skill_used} || defined $combo_source_skill && $after_skill_id == $combo_source_skill);
		next unless (( !$config{"attackComboSlot_${i}_maxUses"} || $args->{attackComboSlot_uses}{$i} < $config{"attackComboSlot_${i}_maxUses"} ));
		next unless (( !$config{"attackComboSlot_${i}_autoCombo"} || ($combo_state && defined $combo_delay && $config{"attackComboSlot_${i}_autoCombo"}) ));
		next unless (( !defined($args->{ID}) || $args->{ID} eq $expected_target_id || !$config{"attackComboSlot_${i}_isSelfSkill"}));
		next unless ((!$config{"attackComboSlot_${i}_monsters"} || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{name}) || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{nameID})));
		next unless ((!$config{"attackComboSlot_${i}_notMonsters"} || !(existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{name}) || existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{nameID}))));
		next unless (checkMonsterCondition("attackComboSlot_${i}_target", $target));

		$args->{attackComboSlot_uses}{$i}++;
		debug TF("[Attack] [Combo] %s, target %s, last_skill_used %s expired at combo check (%s).\n", $char, , $target, $char->{last_skill_used}, $config{"attackComboSlot_$i"}), 'ai_attack';
		delete $char->{last_skill_used};
		if ($config{"attackComboSlot_${i}_autoCombo"}) {
			my $remaining_combo_delay = defined $combo_state->{expires_at}
				? $combo_state->{expires_at} - time
				: 0;
			$combo_delay = 1500 if ($combo_delay > 1500);
			# rAthena calculates 01D2 from the opener's current can-act / attack
			# motion delay, so OpenKore must treat it as a timer that started when
			# the packet arrived instead of re-waiting the full delay later.
			$combo_wait_before_use = $remaining_combo_delay > 0 ? $remaining_combo_delay : 0;
		}
		debug TF("[Attack] [Combo] %s, target %s, combo %d expired at pass 2 (%s) in combo check.\n", $char, , $target, $char->{combo_state}{source_skill}, $config{"attackComboSlot_$i"}), 'ai_attack';
		delete $char->{combo_state};
		$args->{attackMethod}{type} = "combo";
		$args->{attackMethod}{comboSlot} = $i;
		$args->{attackMethod}{waitBeforeUse} = $combo_wait_before_use;
		$args->{attackMethod}{distance} = $config{"attackComboSlot_${i}_dist"};
		$args->{attackMethod}{maxDistance} = $config{"attackComboSlot_${i}_maxDist"} || $config{"attackComboSlot_${i}_dist"};
		last;
	} continue {
		$i++;
	}

	# Otherwise fall back to the standard priority: weapon by default, then
	# override with the first attackSkillSlot whose conditions currently match.
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
			next unless ($skill->getOwnerType == Skill::OWNER_CHAR());

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
	# Keep the extra chase tolerance scoped to the loop where we actually
	# proved we could hit out of nominal range. Persisting it here lets melee
	# attacks get stuck spamming from clientDist 2 without re-approaching.

	# Evaluate whether the chosen attack method can be executed from the current
	# predicted positions.
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

	# If we are already walking to a meeting position, keep waiting, reset the
	# route if the target drifted, or clear the flag once we can attack again.
	if ($args->{sentApproach}) {
		if (approach_target_route_needs_reset($args, $target)) {
			reset_approach_for_moved_target($args, $target);
			return;
		}

		if ($realMyPos->{x} == $myPosTo->{x} && $realMyPos->{y} == $myPosTo->{y}) {
			debug TF("[Ended Approaching] %s (%d %d), target %s (%d %d), blockDist %d, clientDist %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			$args->{sentApproach} = 0;

		} elsif ($config{"attackWaitApproachFinish"}) {
			debug TF("[attackWaitApproachFinish - Waiting] %s (%d %d), target %s (%d %d), blockDist %d, clientDist %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			return;

		} elsif ($canAttack == 2) {
			debug TF("[Approaching - Can now attack] %s (%d %d), target %s (%d %d), blockDist %d, clientDist %d, maxDistance %d, dmgFromYou %d.\n", $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			$args->{sentApproach} = 0;
		}
	}

	my $found_action = 0;
	my $failed_runFromTarget = 0;
	my $hitTarget_when_not_possible = 0;

	# First defensive option: kite away when the target gets closer than the
	# configured minimum distance for run-from-target behavior.
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

	# Second defensive option: if we currently have no valid attack method at
	# all, still try to kite using the fallback run-from-target settings.
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
		debug TF("[%s] We were able to hit target even though it is out of range, accepting and continuing. (you %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d, dmgFromYou %d)\n", $canAttack_fail_string, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
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

	# If we already tagged the monster, optionally wait a little for it to walk
	# back into range/LOS before giving up entirely.
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

	if (
		!$found_action &&
		$timeout{'ai_attack_allowed_waitForTarget'}{'timeout'} &&
		($canAttack == 0 || $canAttack == -1) &&
		!$hitTarget_when_not_possible
	) {
		my $futureMonsterPos = calcPosFromPathfinding($field, $target, ($extra_time + $timeout{'ai_attack_allowed_waitForTarget'}{'timeout'}));
		my $futurecanAttack = canAttack($field, $realMyPos, $futureMonsterPos, $config{attackCanSnipe}, $args->{attackMethod}{maxDistance}, $config{clientSight});
		if ($futurecanAttack) {
			debug TF("[Attack] You currently cannot attack, but will be able to in up to [%s secs], waiting. %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)])\n",
			$timeout{'ai_attack_allowed_waitForTarget'}{'timeout'}, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}), 'ai_attack';
			$found_action = 1;
		}
	}

	# If we still cannot attack, compute a better meeting position and walk to it.
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
			$args->{monsterLastMovePosTo} = { %{$target->{pos_to}} } if $target->{pos_to};
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
		# We are in range and not committed to a movement action, so execute the
		# chosen attack method. In tank mode, only strike until initial aggro is secured.
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			$target->{sentAttack} = 1;
			debug "Ready to attack target $target ($realMonsterPos->{x} $realMonsterPos->{y}) ($realMonsterDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
		}

		$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
		if (!$target->{dmgFromYou} && timeOut($args->{unstuck})) {
			# We are close enough to the target, and we're trying to attack it,
			# but some time has passed and we still haven't dealed any damage.
			# Our recorded position might be out of sync, so try to unstuck
			$args->{unstuck}{time} = time;
			debug("Attack - trying to unstuck\n", "ai_attack");
			$char->move(@{$myPosTo}{qw(x y)});
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
			my $wait_before_use = $args->{attackMethod}{waitBeforeUse};
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
				$wait_before_use,
			);

			$args->{monsterID} = $ID;
			$found_action = 1;
		}

	}

	# Tank mode fallback: stop re-sending attacks once we already transferred
	# aggro and just keep the encounter alive by monitoring damage updates.
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
