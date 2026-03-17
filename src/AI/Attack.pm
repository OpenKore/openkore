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

use constant {
	LOCALDEBUGLEVEL => 1
};

use strict;
use Time::HiRes qw(time);

use Globals;
use AI;
use Actor;
use Field;
use Log qw(message debug warning error);
use Translation qw(T TF);
use Misc;
use Network::Send ();
use Skill;
use List::Util qw(max);
use Utils;
use Utils::PathFinding;

# Cached relative attack-cell offsets by target range.
my %TARGET_ATTACK_OFFSETS_CACHE;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use constant {
	MOVING_TO_ATTACK => 1,
	ATTACKING => 2,
};

# TODOs:
# Limit runfromtarget safety bonus to an acceptable value
# Check if casting / emoticons stop movement (casting Emotion on itself in spores makes mob stop)
# Fallback when no safe wroute allow for attack
# Fallback when we don't want to attack (attackmethod = running)
# Walls near score ? So don't get trapped easily
# Threat near score ? Don't get moobed
# TARGET_ATTACK_OFFSETS_CACHE by map or clear on map change

sub process {
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
                    AI::dequeue while ( AI::inQueue("attack") );
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
    message TF( "Finished attacking\n"), "ai_attack";
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

sub get_attack_preferred_min_distance {
	my ($args) = @_;

	return 1 unless $args;
	return 1 unless $args->{attackMethod};
	return 1 unless defined $args->{attackMethod}{maxDistance};

	my $preferred = $config{attackPreferredMinDistance};
	return 1 unless defined $preferred;
	return 1 if $preferred <= 0;

	my $max = $args->{attackMethod}{maxDistance};
	$preferred = $max if $preferred > $max;

	return $preferred;
}

sub should_reposition_for_preferred_opening {
	my ($args, $target, $realMyPos, $realMonsterPos, $being_chased, $canAttack) = @_;

	return 0 unless $canAttack == 1;
	my $ctx = get_meeting_position_ctx($args);
	return 0 if $ctx && $ctx->{runFromTarget};
	return 0 if $being_chased; # preferred opening range only for non-chasing mobs

	my $effective_min_dist = get_attack_preferred_min_distance($args);
	return 0 unless $effective_min_dist > 1;

	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);
	return ($realMonsterDist < $effective_min_dist) ? 1 : 0;
}

sub should_disable_run_from_target {
	my ($ctx) = @_;

	return 0 unless $ctx;
	return 0 unless $ctx->{runFromTargetConfigured};
	return 0 unless $ctx->{being_chased_preliminary};
	return 0 unless defined $ctx->{preferred_min_dist} && $ctx->{preferred_min_dist} > 0;
	return 0 unless defined $ctx->{realMonsterDist} && $ctx->{realMonsterDist} < $ctx->{preferred_min_dist};
	return 0 unless defined $ctx->{targetSpeed} && defined $ctx->{mySpeed};

	# Lower walk_speed values mean faster movement.
	return ($ctx->{targetSpeed} < $ctx->{mySpeed}) ? 1 : 0;
}

sub should_try_run_from_target {
	my ($args, $actor, $target, $type) = @_;

	if ($args->{target_state}{pending_death_1}) {
		debug TF("[should_try_run_from_target] pending_death_1 == 1.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return 0;
	}

	return 0 unless $config{runFromTarget};
	return 0 unless $args;
	return 0 unless $args->{attackMethod};
	return 0 unless $args->{attackMethod}{type};
	return 0 unless defined $args->{attackMethod}{maxDistance};

	my $ctx = get_meeting_position_ctx($args);
	if ($ctx && $ctx->{runFromTargetDisabled}) {
		debug "[should_try_run_from_target] runFromTarget disabled for this cycle because the target is already chasing, is closer than the preferred distance, and is faster than us.\n", "ai_attack";
		return 0;
	}
	
	my $safety_buffer = defined $config{runFromTargetSafety} ? $config{runFromTargetSafety} : 0;
	my $attack_buffer = 0.1;

	my $spot;
	my $t_enemy_hit;
	my $t_our_hit;
	if ($args->{approachTargetSpot}) {
		$spot = $args->{approachTargetSpot};
		$t_enemy_hit = estimate_time_next_target_damage_will_trigger($args, $actor, $target, 1, $spot);
		$t_our_hit   = get_estimate_time_my_next_damage_will_resolve($args, $actor, $target, 1, $spot);
	} else {
		$spot = $args->{meetingPositionCtx}{realMyPos};
		$t_enemy_hit = estimate_time_next_target_damage_will_trigger($args, $actor, $target, 2, $spot);
		$t_our_hit   = get_estimate_time_my_next_damage_will_resolve($args, $actor, $target, 2, $spot);
	}

	my $remaining_alive_time = $args->{target_state}{remaining_alive_time};
	
	debug "[should_try_run_from_target] [safety_buffer] $safety_buffer\n", "ai_attack";
	debug "[should_try_run_from_target] [t_our_hit] $t_our_hit\n", "ai_attack";
	debug "[should_try_run_from_target] [t_enemy_hit] $t_enemy_hit\n", "ai_attack";
	debug "[should_try_run_from_target] [remaining_alive_time] $remaining_alive_time\n", "ai_attack";

	#return 1 if ($args->{attackMethod}{type} eq "running");
	return 0 unless defined $t_enemy_hit && defined $t_our_hit;

	if (defined $remaining_alive_time) {
		if ($t_enemy_hit > ($remaining_alive_time + $safety_buffer)) {
			debug "[should_try_run_from_target] remaining_alive_time [$remaining_alive_time] less than t_enemy_hit [$t_enemy_hit + $safety_buffer] early return\n", "ai_attack";
			return 0;
		} else {
			return 1;
		}
	}

	my $will_kill = will_our_next_attack_kill_target($target);
	debug "[should_try_run_from_target] [will_kill] $will_kill\n", "ai_attack";

	return 1 if $t_enemy_hit < $t_our_hit;
	return 0 if $will_kill && ($t_our_hit + $attack_buffer) <= $t_enemy_hit;
	return 1 if !$will_kill && $t_enemy_hit <= ($t_our_hit + $safety_buffer);

	return 0;
}

# Starts movement toward the chosen tactical tile and tags whether it is an attack or staging route.
sub route_to_meeting_position {
	my ($args, $ID, $target, $pos, $realMyPos, $realMonsterPos, $debugTag, $mode) = @_;

	return 0 unless $pos;

	$mode ||= ($pos && $pos->{route_choice_mode}) ? $pos->{route_choice_mode} : 'attack';

	debug TF(
		"[%s] %s moving from (%d %d) to (%d %d), mob at (%d %d), mode %s.\n",
		$debugTag,
		$char,
		$realMyPos->{x}, $realMyPos->{y},
		$pos->{x}, $pos->{y},
		$realMonsterPos->{x}, $realMonsterPos->{y},
		$mode,
	), 'ai_attack';

	$args->{move_start} = time;
	my $cleared_routes = clear_attack_route_actions($ID);
	debug TF(
		"[%s] cleared %d stale tactical route task(s) before queueing the new one.\n",
		$debugTag,
		$cleared_routes,
	), 'ai_attack' if $cleared_routes;
	store_approach_context($args, $pos, $target);

	my $sendAttackWithMove = 0;
	if (
		$mode eq 'attack'
		&& !$args->{target_state}{pending_death_2}
		&& $config{"attackSendAttackWithMove"}
		&& defined $args->{attackMethod}{type}
		&& $args->{attackMethod}{type} eq "weapon"
	) {
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
		noMapRoute => 1,
		singleMovePacket => 1,
		immediateStart => 1,
		solution => ($pos->{route_eval} ? $pos->{route_eval}{solution} : undef),
	);

	return 1;
}

# Remembers the route target and target movement state so we can decide whether to keep or refresh it.
sub store_approach_context {
	my ($args, $pos, $target) = @_;

	return unless $args;
	return unless $pos;
	return unless $target;

	$args->{sentApproach} = 1;

	$args->{approachTargetSpot} = $pos;

	my $ctx = get_meeting_position_ctx($args);

	$args->{approachBeingChased} = $ctx ? ($ctx->{being_chased} ? 1 : 0) : 0;

	$args->{monsterLastMoveTime} = $target->{time_move};

	if ($target->{pos_to}) {
		$args->{monsterLastMovePosTo} = {
			x => $target->{pos_to}{x},
			y => $target->{pos_to}{y},
		};
	}
}

# Clears the cached approach metadata once we arrive or intentionally give up the current route.
sub clear_approach_context {
	my ($args) = @_;

	return unless $args;

	$args->{sentApproach} = 0;
	delete $args->{approachTargetSpot};
	delete $args->{approachBeingChased};
	delete $args->{monsterLastMoveTime};
	delete $args->{monsterLastMovePosTo};
}

# Builds a reusable flood-fill map so spot evaluation can query many travel costs cheaply.
sub build_dijkstra_map {
	my ($start_pos, $max_cost) = @_;

	my $pf = PathFinding->new();

	$pf->floodfill_reset(
		\$field->{weightMap},
		$field->width,
		$field->height,
		$start_pos->{x},
		$start_pos->{y},
		$max_cost,
		10,                 # orthogonal cost
		14,                 # diagonal cost
		0,
		$field->width - 1,
		0,
		$field->height - 1,
	);

	my @dummy;
	$pf->floodfill_run(\@dummy);

	return $pf;
}

sub calcTimeFromFloodCost {
	my ($cost, $walk_speed) = @_;
	return ($cost * $walk_speed) / 10;
}

sub clamp_solution_index {
	my ($solution, $index) = @_;
	return 0 unless $solution && @{$solution};
	return 0 if $index < 0;
	return $#{$solution} if $index > $#{$solution};
	return $index;
}

sub get_real_position_from_solution {
	my ($solution, $speed, $elapsed, $finish_time, $final_pos) = @_;

	return $final_pos if !$solution || !@{$solution};
	return $final_pos if $elapsed >= $finish_time;

	my $step = calcStepsWalkedFromTimeAndSolution($solution, $speed, $elapsed);
	$step = clamp_solution_index($solution, $step);
	return $solution->[$step];
}

# Captures enough movement state to predict where an actor really is during motion.
sub build_motion_snapshot {
	my ($actor, $solution, $speed, $elapsed, $final_pos) = @_;

	my $finish_time = calcTimeFromSolution($solution, $speed);
	my $moving = ($elapsed < $finish_time) ? 1 : 0;
	my $real_pos = get_real_position_from_solution($solution, $speed, $elapsed, $finish_time, $final_pos);

	return {
		solution    => $solution,
		speed       => $speed,
		elapsed     => $elapsed,
		finish_time => $finish_time,
		moving      => $moving,
		real_pos    => $real_pos,
		final_pos   => $final_pos,
	};
}

sub predict_position_at_total_elapsed {
	my ($snapshot, $total_elapsed) = @_;

	return $snapshot->{final_pos} unless $snapshot->{solution} && @{$snapshot->{solution}};
	return $snapshot->{final_pos} if $total_elapsed >= $snapshot->{finish_time};

	my $step = calcStepsWalkedFromTimeAndSolution(
		$snapshot->{solution},
		$snapshot->{speed},
		$total_elapsed,
	);
	$step = clamp_solution_index($snapshot->{solution}, $step);
	return $snapshot->{solution}->[$step];
}

# Convenience wrapper for predicting where a moving actor will be after an additional delay.
sub predict_position_after_delta {
	my ($snapshot, $delta_time) = @_;
	my $total_elapsed = $snapshot->{elapsed} + $delta_time;
	return predict_position_at_total_elapsed($snapshot, $total_elapsed);
}

sub target_has_temporary_chase_blocker {
	my ($target) = @_;

	return 0 unless $target;

	if (exists $target->{casting} && defined $target->{casting} && $target->{casting}) {
		debug TF("[target_has_temporary_chase_blocker] is casting.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return 1;
	}
	if ($target->statusActive('EFST_STONECURSE, EFST_FREEZE, EFST_STUN, EFST_SLEEP, EFST_DEEPSLEEP, EFST_WHITEIMPRISON, EFST_BLADESTOP, EFST_BITE, EFST_ANKLESNARE, EFST_SPIDERWEB, EFST_ELECTRICSHOCKER, EFST_WUGBITE, EFST_CRYSTALIZE')) {
		debug TF("[target_has_temporary_chase_blocker] has status.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return 1;
	}

	# TODO: add hunter trap and shadow chaser painted hole here

	return 0;
}

# Heuristic for deciding when a monster should be treated as already chasing us.
sub isTargetProbablyChasingMe {
	my ($actor, $actor_pos, $target, $target_pos) = @_;

	return 0 unless $target && $target->{ID};

	if (target_has_temporary_chase_blocker($target)) {
		debug TF("[isTargetProbablyChasingMe] target_has_temporary_chase_blocker == 1.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return 0;
	}

	# Already engaged with us in some way.
	return 1 if (
		($target->{dmgToYou} || 0) > 0
		|| ($target->{missedYou} || 0) > 0
		|| ($target->{castOnToYou} || 0) > 0
		|| ($target->{dmgFromYou} || 0) > 0
	);

	my $target_is_aggressive = is_aggressive($target, undef, 0, 0);

	# If the monster is aggressive, clean, and close enough, assume it will try to come.
	return 1 if ($target_is_aggressive && blockDistance($actor_pos, $target_pos) <= 11);

	return 0;
}

# Builds a synthetic chase path that assumes the target runs toward the cell it would attack from.
sub build_chasing_target_snapshot_to_attack_cell {
	my ($target, $realTargetPos, $targetSpeed, $targetAttackCell) = @_;

	return unless $targetAttackCell;

	my $chase_solution = get_solution($field, $realTargetPos, $targetAttackCell);
	return unless ($chase_solution && @{$chase_solution});

	my $chase_snapshot = build_motion_snapshot(
		$target,
		$chase_solution,
		$targetSpeed,
		0,
		$targetAttackCell,
	);

	return {
		attack_cell => $targetAttackCell,
		snapshot    => $chase_snapshot,
	};
}

# Stores the last chosen tactical spot so later loops can reuse or compare against it.
sub store_meeting_position_choice {
	my ($args, $choice) = @_;
	return unless $args;

	if ($choice) {
		$args->{meetingPositionBestSpot} = $choice;
	} else {
		delete $args->{meetingPositionBestSpot};
	}
}

# Small accessor to keep the route/spot helpers consistent.
sub get_meeting_position_ctx {
	my ($args) = @_;
	return unless $args && $args->{meetingPositionCtx};
	return $args->{meetingPositionCtx};
}

# Builds the motion/pathfinding snapshot reused while evaluating attack and staging spots.
sub prepare_meeting_position_context {
	my ($args, $actor, $target, $attackMaxDistance) = @_;

	return unless $args && $actor && $target;
	return unless defined $attackMaxDistance;

	my $ctx = {};

	$ctx->{extra_time_actor}  = 0;
	$ctx->{extra_time_target} = 0;

	$ctx->{run_safety_extra}                = defined $config{runFromTargetSafety} ? $config{runFromTargetSafety} : 0;
	$ctx->{readjust_tolerance}              = defined $config{attackRouteReajustTolerance} ? $config{attackRouteReajustTolerance} : 0;

	$ctx->{mySpeed} = ($actor->{walk_speed} || 0.12);
	$ctx->{timeSinceActorMoved} = time - $actor->{time_move} + $ctx->{extra_time_actor};

	$ctx->{attackRouteMaxPathDistance}    = $config{attackRouteMaxPathDistance} || 13;
	$ctx->{runFromTarget_maxPathDistance} = $config{runFromTarget_maxPathDistance} || 13;
	$ctx->{runFromTargetConfigured}       = $config{runFromTarget};
	$ctx->{runFromTarget}                 = $config{runFromTarget};
	$ctx->{maxWalkPathDistance}           = $config{maxWalkPathDistance} || 17;

	$ctx->{attackPreferredMinDistance}     = $config{attackPreferredMinDistance};
	$ctx->{attackRouteReajustTolerance} = $config{attackRouteReajustTolerance} || 0;
	$ctx->{runFromTargetSafety}         = $config{runFromTargetSafety};
	$ctx->{followDistanceMax}           = $config{followDistanceMax};
	$ctx->{attackCanSnipe}              = $config{attackCanSnipe};
	$ctx->{attackMaxDistance}           = $attackMaxDistance;



	my $master;
	my $masterPos = 0;
	if ($config{follow}) {
		foreach (keys %players) {
			if ($players{$_}{name} eq $config{followTarget}) {
				$master = $players{$_};
				last;
			}
		}
		$masterPos = 1 if $master;
	}
	$ctx->{master} = $master if $masterPos;
	$ctx->{masterPos} = $masterPos;

	my $my_solution = $actor->{solution} || $char->{solution};
	$ctx->{my_solution} = $my_solution;
	$ctx->{actor_snapshot} = build_motion_snapshot(
		$actor,
		$my_solution,
		$ctx->{mySpeed},
		$ctx->{timeSinceActorMoved},
		$actor->{pos_to},
	);
	$ctx->{realMyPos} = $ctx->{actor_snapshot}{real_pos};

	$ctx->{targetSpeed} = ($target->{walk_speed} || 0.12);
	$ctx->{timeSinceTargetMoved} = time - $target->{time_move} + $ctx->{extra_time_target};
	$ctx->{target_solution} = get_solution($field, $target->{pos}, $target->{pos_to});
	$ctx->{target_snapshot} = build_motion_snapshot(
		$target,
		$ctx->{target_solution},
		$ctx->{targetSpeed},
		$ctx->{timeSinceTargetMoved},
		$target->{pos_to},
	);
	$ctx->{realTargetPos} = $ctx->{target_snapshot}{real_pos};

	if ($masterPos && $master) {
		my $masterSpeed = ($master->{walk_speed} || 0.12);
		my $timeSinceMasterMoved = time - $master->{time_move} + $ctx->{extra_time_actor};
		my $master_solution = get_solution($field, $master->{pos}, $master->{pos_to});

		$ctx->{master_snapshot} = build_motion_snapshot(
			$master,
			$master_solution,
			$masterSpeed,
			$timeSinceMasterMoved,
			$master->{pos_to},
		);

		$ctx->{realMasterPos} = $ctx->{master_snapshot}{real_pos} unless $ctx->{master_snapshot}{moving};
	}

	$ctx->{preferred_min_dist} = defined $ctx->{attackPreferredMinDistance} ? $ctx->{attackPreferredMinDistance} : 0;
	$ctx->{preferred_min_dist} = $attackMaxDistance if $ctx->{preferred_min_dist} > $attackMaxDistance;
	$ctx->{preferred_min_dist} = 0 if $ctx->{preferred_min_dist} < 0;

	$ctx->{effective_min_dist} = $ctx->{preferred_min_dist};
	$ctx->{effective_min_dist} = 1 if ($ctx->{effective_min_dist} < 1);

	$ctx->{realMonsterDist} = blockDistance($ctx->{realMyPos}, $ctx->{realTargetPos});
	$ctx->{being_chased_preliminary} = isTargetProbablyChasingMe($actor, $ctx->{realMyPos}, $target, $ctx->{realTargetPos}) ? 1 : 0;
	$ctx->{runFromTargetDisabled} = should_disable_run_from_target($ctx) ? 1 : 0;
	if ($ctx->{runFromTargetDisabled}) {
		debug TF(
			"[prepare_meeting_position_context] disabling runFromTarget for %s because it is already chasing, is within preferred distance (%d < %d), and is faster than us (%.3f < %.3f).\n",
			$target,
			$ctx->{realMonsterDist},
			$ctx->{preferred_min_dist},
			$ctx->{targetSpeed},
			$ctx->{mySpeed},
		), 'ai_attack';
	}
	$ctx->{runFromTarget} = ($ctx->{runFromTargetConfigured} && !$ctx->{runFromTargetDisabled}) ? 1 : 0;

	$ctx->{desired_dist} = $ctx->{runFromTarget}
		? $attackMaxDistance
		: ($ctx->{effective_min_dist} > 0 ? $ctx->{effective_min_dist} : $attackMaxDistance);

	$ctx->{max_path_dist} = $ctx->{runFromTarget}
		? $ctx->{runFromTarget_maxPathDistance}
		: $ctx->{attackRouteMaxPathDistance};
	$ctx->{max_path_dist} += 1;
	$ctx->{max_path_dist} = $ctx->{maxWalkPathDistance} if $ctx->{max_path_dist} > $ctx->{maxWalkPathDistance};

	$ctx->{actor_max_cost} = $ctx->{max_path_dist} * 14;
	$ctx->{actor_pf} = build_dijkstra_map($ctx->{realMyPos}, $ctx->{actor_max_cost});

	$ctx->{target_max_cost} = $ctx->{max_path_dist} * 14;
	$ctx->{target_pf} = build_dijkstra_map($ctx->{realTargetPos}, $ctx->{target_max_cost});

	$ctx->{clientDist} = getClientDist($ctx->{realMyPos}, $ctx->{realTargetPos});

	$ctx->{attack_resolve_buffer} = 0.1;
	$ctx->{my_amotion} = get_my_amotion($actor);

	$ctx->{my_remaning_time_to_act} = get_remaning_time_to_act($actor);
	$ctx->{target_remaning_time_to_act} = get_remaning_time_to_act($target);

	$ctx->{loop_start_time} = time;

	$ctx->{target_attack_range} = get_target_attack_range($target);
	$ctx->{target_attack_bbox}  = build_target_attack_cache_bbox($ctx);
	$ctx->{target_attack_eval}  = build_target_attack_cell_cache_for_bbox(
		$ctx,
		$ctx->{target_attack_bbox},
	);
	$ctx->{target_can_reach_me} = can_target_reach_spot_to_attack($ctx, $ctx->{realMyPos});

	my $being_chased = $ctx->{being_chased_preliminary};
	if ($being_chased && !$ctx->{target_can_reach_me}) {
		debug TF(
			"[prepare_meeting_position_context] blocking being_chased for %s because it cannot reach an attack tile on us from (%d %d) to (%d %d).\n",
			$target,
			$ctx->{realTargetPos}{x}, $ctx->{realTargetPos}{y},
			$ctx->{realMyPos}{x}, $ctx->{realMyPos}{y},
		), 'ai_attack';
		$being_chased = 0;
	}
	$ctx->{being_chased} = $being_chased;
	$ctx->{route_eval_sample_count} = 5;

	$args->{meetingPositionCtx} = $ctx;
	return $ctx;
}

# Reads the monster's effective melee/ranged attack range from runtime data or mob_db.
sub get_target_attack_range {
	my ($target) = @_;

	return 1 unless $target;

	my $mob = get_monster_table_data($target);
	if ($mob) {
		# This is here if we want to add skillrange later on
		for my $key (qw(AttackRange)) {
			if (defined $mob->{$key} && $mob->{$key} > 0) {
				return $mob->{$key};
			}
		}
	}

	return 1;
}

# Caches relative offsets for every tile a target can use to attack a spot at a given range.
sub get_attack_offsets_for_range {
	my ($range) = @_;

	$range = 1 unless defined $range && $range > 0;
	return $TARGET_ATTACK_OFFSETS_CACHE{$range} if exists $TARGET_ATTACK_OFFSETS_CACHE{$range};

	my @offsets;
	my $origin = { x => 0, y => 0 };

	for my $dx (-$range .. $range) {
		for my $dy (-$range .. $range) {
			next if $dx == 0 && $dy == 0;
			my $p = { x => $dx, y => $dy };
			my $dist = getClientDist($origin, $p);
			next if $dist > $range;
			push @offsets, { dx => $dx, dy => $dy, dist => $dist };
		}
	}

	@offsets = sort {
		$a->{dist} <=> $b->{dist}
		|| $a->{dx} <=> $b->{dx}
		|| $a->{dy} <=> $b->{dy}
	} @offsets;

	$TARGET_ATTACK_OFFSETS_CACHE{$range} = \@offsets;
	return $TARGET_ATTACK_OFFSETS_CACHE{$range};
}

# Limits the precomputed target-attack cache to the local area relevant to this engagement.
sub build_target_attack_cache_bbox {
	my ($ctx) = @_;

	return unless $ctx;
	return unless $ctx->{realMyPos};
	return unless $ctx->{realTargetPos};

	my $pad = 2;
	my $base = $ctx->{max_path_dist} || 12;
	my $range = $ctx->{target_attack_range} || 1;
	my $reach = $base + $range + $pad;

	my $min_x = $ctx->{realMyPos}{x} < $ctx->{realTargetPos}{x} ? $ctx->{realMyPos}{x} : $ctx->{realTargetPos}{x};
	my $max_x = $ctx->{realMyPos}{x} > $ctx->{realTargetPos}{x} ? $ctx->{realMyPos}{x} : $ctx->{realTargetPos}{x};
	my $min_y = $ctx->{realMyPos}{y} < $ctx->{realTargetPos}{y} ? $ctx->{realMyPos}{y} : $ctx->{realTargetPos}{y};
	my $max_y = $ctx->{realMyPos}{y} > $ctx->{realTargetPos}{y} ? $ctx->{realMyPos}{y} : $ctx->{realTargetPos}{y};

	$min_x -= $reach;
	$max_x += $reach;
	$min_y -= $reach;
	$max_y += $reach;

	$min_x = 0 if $min_x < 0;
	$min_y = 0 if $min_y < 0;
	$max_x = $field->width  - 1 if $max_x > $field->width  - 1;
	$max_y = $field->height - 1 if $max_y > $field->height - 1;

	return {
		min_x => $min_x,
		max_x => $max_x,
		min_y => $min_y,
		max_y => $max_y,
	};
}

# Precomputes the best attack cell and travel time the target would need for each candidate tile.
sub build_target_attack_cell_cache_for_bbox {
	my ($ctx, $bbox) = @_;

	return unless $ctx;
	return unless $bbox;
	return unless $ctx->{target_pf};

	my $range = $ctx->{target_attack_range} || 1;
	my $attack_offsets = get_attack_offsets_for_range($range);
	my %map;

	for my $x ($bbox->{min_x} .. $bbox->{max_x}) {
		for my $y ($bbox->{min_y} .. $bbox->{max_y}) {
			next unless $field->isWalkable($x, $y);
			my $best = get_best_attack_cell_by_pf(
				$ctx->{target_pf},
				{ x => $x, y => $y },
				$range,
				$ctx->{target_max_cost},
				$attack_offsets,
			);
			next unless $best;
			$map{$x}{$y} = {
				can_attack  => 1,
				attack_cell => $best->{attack_cell},
				cost        => $best->{cost},
				time        => calcTimeFromFloodCost($best->{cost}, $ctx->{targetSpeed}),
			};
		}
	}

	return {
		range          => $range,
		bbox           => $bbox,
		attack_offsets => $attack_offsets,
		map            => \%map,
	};
}

# Fetches the precomputed "target can attack this spot from here" data for a candidate tile.
sub get_cached_target_attack_info_for_spot {
	my ($ctx, $spot) = @_;

	return unless $ctx;
	return unless $ctx->{target_attack_eval};
	return unless $spot;
	return unless defined $spot->{x} && defined $spot->{y};

	return $ctx->{target_attack_eval}{map}{$spot->{x}}{$spot->{y}};
}

# Returns whether the target can path to any tile from which it could attack the given spot with LOS.
sub can_target_reach_spot_to_attack {
	my ($ctx, $spot) = @_;

	return 0 unless $ctx;
	return 0 unless $spot;
	return 0 unless defined $spot->{x} && defined $spot->{y};
	return 0 unless $ctx->{target_pf};

	my $cached = get_cached_target_attack_info_for_spot($ctx, $spot);
	return 1 if $cached && $cached->{can_attack};

	my $best = get_best_attack_cell_by_pf(
		$ctx->{target_pf},
		$spot,
		$ctx->{target_attack_range},
		$ctx->{target_max_cost},
		($ctx->{target_attack_eval} ? $ctx->{target_attack_eval}{attack_offsets} : undef),
	);
	return $best ? 1 : 0;
}

# Converts a path index back into travel time so sampled route safety checks stay cheap.
sub calc_time_until_solution_index {
	my ($solution, $speed, $index) = @_;

	return 0 unless $solution && @{$solution};
	return 0 if !defined $index || $index <= 0;

	my $time = 0;
	for my $i (1 .. $index) {
		my $prev = $solution->[$i - 1];
		my $curr = $solution->[$i];
		my $dx = abs($curr->{x} - $prev->{x});
		my $dy = abs($curr->{y} - $prev->{y});
		my $step_cost = ($dx == 1 && $dy == 1) ? 14 : 10;
		$time += calcTimeFromFloodCost($step_cost, $speed);
	}
	return $time;
}

# Picks evenly spaced checkpoints plus the closest-to-target node for route safety sampling.
sub get_route_sample_indices {
	my ($solution, $target_pos, $sample_count) = @_;

	return [] unless $solution && @{$solution};
	my $last = $#{$solution};
	$sample_count = 5 unless defined $sample_count && $sample_count >= 2;
	my %seen;
	my @idx;
	for my $sample_index (0 .. ($sample_count - 1)) {
		my $i = int(($last * $sample_index) / ($sample_count - 1));
		$i = 0 if $i < 0;
		$i = $last if $i > $last;
		next if $seen{$i}++;
		push @idx, $i;
	}

	if ($target_pos) {
		my ($closest_i, $closest_d);
		for my $i (0 .. $last) {
			my $p = $solution->[$i];
			my $d = blockDistance($p, $target_pos);
			if (!defined $closest_d || $d < $closest_d) {
				$closest_d = $d;
				$closest_i = $i;
			}
		}
		if (defined $closest_i && !$seen{$closest_i}++) {
			push @idx, $closest_i;
		}
	}

	@idx = sort { $a <=> $b } @idx;
	return \@idx;
}

# Fast path-level guard: spots outside melee range are still penalized if the route cuts through threat range.
sub route_crosses_target_danger_zone_fast {
	my ($solution, $target_pos, $danger_dist) = @_;

	return 0 unless $solution && @{$solution};
	return 0 unless $target_pos;
	$danger_dist = 1 unless defined $danger_dist;

	my $left_initial_danger_zone = 0;
	foreach my $node (@{$solution}) {
		my $d = getClientDist($node, $target_pos);
		if ($d <= $danger_dist) {
			# Allow routes that start inside threat range and immediately step out of it.
			return 1 if $left_initial_danger_zone;
		} else {
			$left_initial_danger_zone = 1;
		}
	}

	return 0;
}

# Rejects a route if any step lands on an exact portal cell.
sub route_crosses_prohibited_cells {
	my ($solution, $prohibited_cells) = @_;

	return 0 unless $solution && @{$solution};
	return 0 unless $prohibited_cells;

	foreach my $node (@{$solution}) {
		next unless $node;
		return 1 if $prohibited_cells->{$node->{x}} && $prohibited_cells->{$node->{x}}{$node->{y}};
	}

	return 0;
}

# Scores whether the full route to a spot stays safe enough for an immediate attack or only for staging.
sub evaluate_route_safety_for_spot {
	my ($args, $actor, $target, $spot) = @_;

	my $ctx = get_meeting_position_ctx($args);
	return unless $ctx;
	return unless $spot;

	my $solution = get_solution($field, $ctx->{realMyPos}, $spot);
	return {
		has_route             => 0,
		is_attack_route_safe  => 0,
		is_staging_route_safe => 0,
		min_slack             => undef,
		route_penalty         => 9999,
	} unless ($solution && @{$solution});

	if (route_crosses_prohibited_cells($solution, $ctx->{portal_route_prohibited_spots})) {
		return {
			has_route                 => 0,
			is_attack_route_safe      => 0,
			is_staging_route_safe     => 0,
			min_slack                 => undef,
			route_penalty             => 9999,
			crosses_prohibited_portal => 1,
		};
	}

	my $sample_idx = get_route_sample_indices(
		$solution,
		$ctx->{realTargetPos},
		$ctx->{route_eval_sample_count},
	);
	my $time_to_act    = $ctx->{target_remaning_time_to_act};
	my $time_to_attack = get_remaning_time_to_attack($target);
	my $required_attack_margin  = defined $ctx->{run_safety_extra} ? $ctx->{run_safety_extra} : 0;
	my $required_staging_margin = 0;

	my ($min_slack, $worst_idx);
	my $attack_route_penalty = 0;
	my $staging_route_penalty = 0;

	foreach my $idx (@{$sample_idx}) {
		my $node = $solution->[$idx];
		my $t_me = calc_time_until_solution_index($solution, $ctx->{mySpeed}, $idx);
		my $attack_info = get_cached_target_attack_info_for_spot($ctx, $node);
		my $t_enemy;
		if ($attack_info && defined $attack_info->{time}) {
			$t_enemy = max($time_to_attack, ($time_to_act + $attack_info->{time}));
		} else {
			$t_enemy = 999;
		}
		my $slack = $t_enemy - $t_me;
		if (!defined $min_slack || $slack < $min_slack) {
			$min_slack = $slack;
			$worst_idx = $idx;
		}
		if ($slack < $required_attack_margin) {
			$attack_route_penalty += ($required_attack_margin - $slack) * 8;
		}
		if ($slack < $required_staging_margin) {
			$staging_route_penalty += ($required_staging_margin - $slack) * 8;
		}
	}

	my $danger_dist = $ctx->{target_attack_range} || 1;
	my $crosses_target_danger_zone = route_crosses_target_danger_zone_fast(
		$solution,
		$ctx->{realTargetPos},
		$danger_dist,
	) ? 1 : 0;

	if ($crosses_target_danger_zone) {
		$attack_route_penalty += 6;
		$staging_route_penalty += 6;
	}

	my $is_attack_route_safe = (defined $min_slack && $min_slack >= $required_attack_margin) ? 1 : 0;
	my $is_staging_route_safe = (defined $min_slack && $min_slack >= $required_staging_margin) ? 1 : 0;

	return {
		has_route             => 1,
		solution              => $solution,
		sample_idx            => $sample_idx,
		min_slack             => $min_slack,
		worst_idx             => $worst_idx,
		route_penalty         => $attack_route_penalty,
		attack_route_penalty  => $attack_route_penalty,
		staging_route_penalty => $staging_route_penalty,
		crosses_danger_zone   => $crosses_target_danger_zone,
		is_attack_route_safe  => $is_attack_route_safe,
		is_staging_route_safe => $is_staging_route_safe,
	};
}

# Scores fallback movement that is safe to reach even if it is not yet an immediate attack tile.
sub score_staging_spot {
	my ($args, $spot) = @_;

	my $ctx = get_meeting_position_ctx($args);
	return -9999 unless $ctx && $spot;

	my $safe_bonus = 0;
	if ($spot->{route_eval} && defined $spot->{route_eval}{min_slack}) {
		$safe_bonus = $spot->{route_eval}{min_slack} * 2;
	}

	my $dist_penalty = 0;
	if (defined $spot->{blockDist_to_target}) {
		$dist_penalty = abs($spot->{blockDist_to_target} - $ctx->{desired_dist});
	}

	my $progress_bonus = 0;
	if (defined $spot->{blockDist_to_target} && defined $ctx->{realMonsterDist}) {
		my $current_error = abs($ctx->{realMonsterDist} - $ctx->{desired_dist});
		my $spot_error = abs($spot->{blockDist_to_target} - $ctx->{desired_dist});
		$progress_bonus = $current_error - $spot_error;
		$progress_bonus = 0 if $progress_bonus < 0;
	}

	my $score =
		  $safe_bonus
		+ $progress_bonus
		- $spot->{time_actor_to_get_to_spot}
		- ($spot->{route_eval}{staging_route_penalty} || 0)
		- $dist_penalty;

	return $score;
}

# Finds the cheapest tile the target can stand on to attack a candidate spot at its own range with LOS.
sub get_best_attack_cell_by_pf {
	my ($target_pf, $spot, $range, $max_cost, $attack_offsets) = @_;

	return unless $target_pf;
	return unless $spot;
	return unless defined $spot->{x} && defined $spot->{y};

	$range = 1 unless defined $range && $range > 0;
	$attack_offsets ||= get_attack_offsets_for_range($range);

	my ($best_block, $best_cost);
	foreach my $off (@{$attack_offsets}) {
		my $ax = $spot->{x} + $off->{dx};
		my $ay = $spot->{y} + $off->{dy};
		next unless $field->isWalkable($ax, $ay);
		my $cost = $target_pf->floodfill_getdist($ax, $ay);
		next if $cost < 0;
		next if defined $max_cost && $cost > $max_cost;
		next unless $field->checkLOS({ x => $ax, y => $ay }, $spot, 0);
		if (!defined $best_cost || $cost < $best_cost) {
			$best_cost = $cost;
			$best_block = { x => $ax, y => $ay };
		}
	}

	return unless $best_block;
	return {
		attack_cell => $best_block,
		cost        => $best_cost,
	};
}

sub get_monster_table_data {
	my ($target) = @_;

	return unless $target;
	return unless $target->{nameID};

	my $mob = $monstersTable{$target->{nameID}};
	return unless $mob;

	return $mob;
}

sub estimate_next_attack_damage {
	my ($target) = @_;

	return 0 unless (defined $target->{numAtkFromAtkFromYou} && $target->{numAtkFromAtkFromYou});
	return 0 unless (defined $target->{dmgFromAtkFromYou} && $target->{dmgFromAtkFromYou});

	my $mean_damage = $target->{dmgFromAtkFromYou} / $target->{numAtkFromAtkFromYou};

	my $extra_safety = 0.8;

	my $safe_damage = $mean_damage * $extra_safety;

	return $safe_damage;
}

sub get_my_amotion {
	my ($actor) = @_;

	return $actor->{lastAttackAttackMotion} if defined $actor->{lastAttackAttackMotion};

	# fallback formula seconds
	my $sec = (25/(200-$actor->{'attack_speed'}));

	return $sec;
}

sub get_remaning_time_to_act {
	my ($actor) = @_;
	my $amotion = get_remaining_amotion($actor);
	my $dmotion = get_remaining_dmotion($actor);
	my $max = max($amotion, $dmotion);
	return $max;
}

sub get_remaning_time_to_attack {
	my ($actor) = @_;
	my $time_to_act = get_remaning_time_to_act($actor);
	my $adelay = get_remaining_adelay($actor);
	my $max = max($time_to_act, $adelay);
	return $max;
}

# Time where actor is stuck after receiving damage
sub get_remaining_dmotion {
	my ($actor) = @_;
	return 0 unless ($actor->{lastRecvAttackTime} && $actor->{lastRecvDamageMotion});
	
	my $time = time;
	my $time_actor_will_end_dmotion = $actor->{lastRecvAttackTime} + $actor->{lastRecvDamageMotion};
	return 0 if ($time >= $time_actor_will_end_dmotion);

	my $remaining_time = $time_actor_will_end_dmotion - $time;
	return $remaining_time;
}

# Time where actor is stuck 
sub get_remaining_amotion {
	my ($actor) = @_;
	return 0 unless ($actor->{lastAttackTime} && $actor->{lastAttackAttackMotion});
	
	my $time = time;
	my $time_actor_will_end_amotion = $actor->{lastAttackTime} + $actor->{lastAttackAttackMotion};
	return 0 if ($time >= $time_actor_will_end_amotion);

	my $remaining_time = $time_actor_will_end_amotion - $time;
	return $remaining_time;
}

# For mobs get from table
# For char calculate
sub get_remaining_adelay {
	my ($actor) = @_;
	return 0 unless ($actor->{lastAttackTime});
	
	my $time = time;

	my $adelay;
	if ($actor->isa('Actor::You')) {
		return 0 unless ($actor->{lastAttackAttackMotion});
		$adelay = 2*$actor->{lastAttackAttackMotion};

	} elsif ($actor->isa('Actor::Monster')) {
		my $data = get_monster_table_data($actor);
		return 0 unless ($data);
		$adelay = $data->{AttackDelay}/1000;

	} else {
		# Should probably have another check for homun and merc
		return 0 unless ($actor->{lastAttackAttackMotion});
		$adelay = $actor->{lastAttackAttackMotion};
	}

	my $time_actor_will_end_adelay = $actor->{lastAttackTime} + $adelay;
	return 0 if ($time >= $time_actor_will_end_adelay);

	my $remaining_time = $time_actor_will_end_adelay - $time;
	return $remaining_time;
}

sub get_remaining_move_time {
	my ($actor, $args, $which) = @_;
	return 0 unless $actor;

	my $ctx = get_meeting_position_ctx($args);
	if ($ctx) {
		my $snapshot;
		if (defined $which && $which eq 'target') {
			$snapshot = $ctx->{target_snapshot};
		} elsif (defined $which && $which eq 'master') {
			$snapshot = $ctx->{master_snapshot};
		} elsif ($actor->isa('Actor::Monster')) {
			$snapshot = $ctx->{target_snapshot};
		} else {
			$snapshot = $ctx->{actor_snapshot};
		}

		if ($snapshot && $snapshot->{moving}) {
			my $remaining = $snapshot->{remaining_time};
			$remaining = $snapshot->{time_left} if !defined $remaining && exists $snapshot->{time_left};
			return $remaining if defined $remaining && $remaining > 0;
		}
	}

	my $remaining = 0;
	if (defined $actor->{time_move} && defined $actor->{time_move_calc}) {
		my $elapsed = time - $actor->{time_move};
		my $left = $actor->{time_move_calc} - $elapsed;
		$remaining = $left if $left > $remaining;
	}

	if ($actor->{pos} && $actor->{pos_to} && ($actor->{pos}{x} != $actor->{pos_to}{x} || $actor->{pos}{y} != $actor->{pos_to}{y})) {
		my $solution = get_solution($field, $actor->{pos}, $actor->{pos_to});
		if ($solution && @{$solution}) {
			my $speed = $actor->{walk_speed} || 0.12;
			my $move_time = calcTimeFromSolution($solution, $speed);
			my $elapsed = defined $actor->{time_move} ? (time - $actor->{time_move}) : 0;
			my $left = $move_time - $elapsed;
			$remaining = $left if $left > $remaining;
		}
	}

	return $remaining > 0 ? $remaining : 0;
}

sub set_target_resolution_state {
	my ($args, $target) = @_;

	if (!$target) {
		$args->{target_state}{has_unresolved_dmg} = 0;
		$args->{target_state}{pending_death_1} = 0;
		$args->{target_state}{pending_death_2} = 0;
		$args->{target_state}{remaining_alive_time} = undef;
		return;
	}

	my $has_unresolved = does_target_have_unresolved_damage_taken($target) ? 1 : 0;
	my $pending_death_1 = is_target_pending_death_type_1($target) ? 1 : 0;
	my $pending_death_2 = is_target_pending_death_type_2($target) ? 1 : 0;

	$args->{target_state}{has_unresolved_dmg} = $has_unresolved;
	$args->{target_state}{pending_death_1} = $pending_death_1;
	$args->{target_state}{pending_death_2} = $pending_death_2;

	$args->{target_state}{remaining_alive_time} = get_remaining_alive_time($target);

}

sub does_target_have_unresolved_damage_taken {
	my ($target) = @_;

	if (defined $target->{lastRecvAttackTime} && defined $target->{hp_lastUpdateTime}) {
		return 1 if ($target->{lastRecvAttackTime} > $target->{hp_lastUpdateTime});
	}

	return 1 if (defined $target->{lastRecvAttackTime} && !defined $target->{hp_lastUpdateTime});

	return 0;
}

# Server has already resolved that this monster will die, so it can't attack and move anymore, safe
sub is_target_pending_death_type_1 {
	my ($target) = @_;

	my $hp = $target->{hp};
	return 1 if (defined $hp && $target->{hp} == 0);

	return 0;
}

# Monster has already received lethal damage but the server has not yet resolved it, so it can still move and attack for a bit
sub is_target_pending_death_type_2 {
	my ($target) = @_;

	return 0 unless (defined $target->{deltaHp});

	my $max_hp = $target->{hp_max};
	unless (defined $max_hp) {
		my $data = get_monster_table_data($target);
		return 0 unless ($data);
		$max_hp = $data->{HP};
		return 0 unless (defined $max_hp);
	}

	my $remaining_hp = $target->{deltaHp} + $max_hp;

	return 1 if ($remaining_hp <= 0);

	return 1 if (exists $target->{pendingDeathTimer});

	return 0;
}

sub will_our_next_attack_kill_target {
	my ($target) = @_;

	return 0 unless $target;

	my $hp = $target->{hp};
	unless (defined $hp) {
		my $data = get_monster_table_data($target);
		return 0 unless ($data);
		$hp = $data->{HP};
	}
	return 0 unless (defined $hp);

	my $expected = estimate_next_attack_damage($target);
	return 0 unless defined $expected;

	return ($hp <= $expected) ? 1 : 0;
}

# types
# 0 - calculating meetingposition
# 1 - routing
# 1 - attacking
sub estimate_time_next_target_damage_will_trigger {
	my ($args, $actor, $target, $type, $spot) = @_;

	my $time_to_act = $args->{meetingPositionCtx}{target_remaning_time_to_act};
	my $time_to_attack = get_remaning_time_to_attack($target);

	my $total_time = 0;
	
	if ($type == 0) {
		$total_time += max($time_to_attack, ($time_to_act + $spot->{time_target_to_reach_attack_cell}));
	
	} elsif ($type == 1 || $type == 2) {
		my $ctx = $args->{meetingPositionCtx};
		my $cell = get_cached_target_attack_info_for_spot($ctx, $spot);
		unless ($cell) {
			$cell = get_best_attack_cell_by_pf(
				$ctx->{target_pf},
				$spot,
				$ctx->{target_attack_range},
				$ctx->{target_max_cost},
				get_attack_offsets_for_range($ctx->{target_attack_range}),
			);
			return undef unless $cell;
			$cell = {
				attack_cell => $cell->{attack_cell},
				cost        => $cell->{cost},
				time        => calcTimeFromFloodCost($cell->{cost}, $ctx->{targetSpeed}),
			};
		}
		$total_time += max($time_to_attack, ($time_to_act + $cell->{time}));
	}

	return $total_time;
}

# types
# 0 - calculating meetingposition
# 1 - route to attack
# 2 - attacking
sub get_estimate_time_my_next_damage_will_resolve {
	my ($args, $actor, $target, $type, $spot) = @_;

	my $time_to_act = $args->{meetingPositionCtx}{my_remaning_time_to_act};

	my $total_time = 0;
	
	if ($type == 0) {
		$total_time += $time_to_act + $spot->{time_actor_to_get_to_spot} + $args->{meetingPositionCtx}{attack_resolve_buffer} + $args->{meetingPositionCtx}{my_amotion};
	
	} elsif ($type == 1) {
		my $remaining = 0;
		if ($actor->{pos_to} && $actor->{pos_to}{x} == $spot->{x} && $actor->{pos_to}{y} == $spot->{y}) {
			my $elapsed = time - $actor->{time_move};
			my $left = $actor->{time_move_calc} - $elapsed;
			$remaining = $left if $left > $remaining;
		} else {
			$remaining = $spot->{time_actor_to_get_to_spot};
		}
		$total_time += $time_to_act + $remaining + $args->{meetingPositionCtx}{attack_resolve_buffer} + $args->{meetingPositionCtx}{my_amotion};
	
	} elsif ($type == 2) {
		my $remaining = 0;
		if ($actor->{lastAttackTarget} && $actor->{lastAttackTarget} eq $target->{ID} && $actor->{lastAttackTime}) {
			if (!$target->{hp_lastUpdateTime} || $target->{hp_lastUpdateTime} < $actor->{lastAttackTime}) {
				my $now = time;
				my $predicted = $actor->{lastAttackTime} + $args->{meetingPositionCtx}{my_amotion};
				if ($predicted > $now) {
					$remaining = $predicted - $now;
				}
			} else {
				$remaining = get_remaning_time_to_attack($actor) + $args->{meetingPositionCtx}{my_amotion};
			}
		} else {
			$remaining = get_remaning_time_to_attack($actor) + $args->{meetingPositionCtx}{my_amotion};
		}
		$total_time += $remaining;
	}

	return $total_time;
}

# Raw timer calculation for targets that already have a pending death resolution timestamp.
sub get_remaining_alive_time {
	my ($target) = @_;

	return undef unless $target;
	return undef unless exists $target->{pendingDeathTimer};

	my $time_now = time;
	my $remaining_alive_time = $target->{pendingDeathTimer} - $time_now;
	if ($remaining_alive_time <= 0) {
		$remaining_alive_time = 0;
	}

	return $remaining_alive_time;
}

# Caches the target movement state tied to the active approach route so we can detect route drift.
sub store_target_route_progress {
	my ($args, $target) = @_;

	return unless $args;
	return unless $target;

	$args->{monsterLastMoveTime} = $target->{time_move};

	if ($target->{pos_to}) {
		$args->{monsterLastMovePosTo} = {
			x => $target->{pos_to}{x},
			y => $target->{pos_to}{y},
		};
	}
}

# Resolves combo attacks before ordinary attack skills because combos are time-sensitive follow-ups.
sub resolve_combo_attack_method {
	my ($args, $target) = @_;

	return unless $args && $target;

	my $i = 0;
	while (exists $config{"attackComboSlot_$i"}) {
		next unless defined $config{"attackComboSlot_$i"};
		next unless checkSelfCondition("attackComboSlot_$i");
		next unless $config{"attackComboSlot_${i}_afterSkill"};
		next unless Skill->new(auto => $config{"attackComboSlot_${i}_afterSkill"})->getIDN == $char->{last_skill_used};
		next unless (!$config{"attackComboSlot_${i}_maxUses"} || $args->{attackComboSlot_uses}{$i} < $config{"attackComboSlot_${i}_maxUses"});
		next unless (!$config{"attackComboSlot_${i}_autoCombo"} || ($char->{combo_packet} && $config{"attackComboSlot_${i}_autoCombo"}));
		next unless (!defined($args->{ID}) || $args->{ID} eq $char->{last_skill_target} || !$config{"attackComboSlot_${i}_isSelfSkill"});
		next unless (!$config{"attackComboSlot_${i}_monsters"} || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{name}) || existsInList($config{"attackComboSlot_${i}_monsters"}, $target->{nameID}));
		next unless (!$config{"attackComboSlot_${i}_notMonsters"} || !(existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{name}) || existsInList($config{"attackComboSlot_${i}_notMonsters"}, $target->{nameID})));
		next unless checkMonsterCondition("attackComboSlot_${i}_target", $target);

		$args->{attackComboSlot_uses}{$i}++;
		delete $char->{last_skill_used};
		if ($config{"attackComboSlot_${i}_autoCombo"}) {
			$char->{combo_packet} = 1500 if ($char->{combo_packet} > 1500);
			# eAthena seems to have a bug where the combo_packet overflows and gives an
			# abnormally high number. This causes kore to get stuck in a waitBeforeUse timeout.
			$config{"attackComboSlot_${i}_waitBeforeUse"} = ($char->{combo_packet} / 1000);
		}
		delete $char->{combo_packet};

		return {
			type => "combo",
			comboSlot => $i,
			distance => $config{"attackComboSlot_${i}_dist"},
			maxDistance => $config{"attackComboSlot_${i}_maxDist"} || $config{"attackComboSlot_${i}_dist"},
		};
	} continue {
		$i++;
	}

	return;
}

# Uses configured attack skills when no combo follow-up is available.
sub resolve_skill_attack_method {
	my ($args, $target) = @_;

	return unless $args && $target;

	my $i = 0;
	while (exists $config{"attackSkillSlot_$i"}) {
		next unless defined $config{"attackSkillSlot_$i"};

		my $skill = Skill->new(auto => $config{"attackSkillSlot_$i"});
		next unless $skill;
		next unless $skill->getOwnerType == Skill::OWNER_CHAR;

		my $handle = $skill->getHandle();
		next unless checkSelfCondition("attackSkillSlot_$i");
		next unless (!$config{"attackSkillSlot_${i}_maxUses"} || $target->{skillUses}{$handle} < $config{"attackSkillSlot_${i}_maxUses"});
		next unless (!$config{"attackSkillSlot_${i}_maxAttempts"} || $args->{attackSkillSlot_attempts}{$i} < $config{"attackSkillSlot_${i}_maxAttempts"});
		next unless (!$config{"attackSkillSlot_${i}_monsters"} || existsInList($config{"attackSkillSlot_${i}_monsters"}, $target->{name}) || existsInList($config{"attackSkillSlot_${i}_monsters"}, $target->{nameID}));
		next unless (!$config{"attackSkillSlot_${i}_notMonsters"} || !(existsInList($config{"attackSkillSlot_${i}_notMonsters"}, $target->{name}) || existsInList($config{"attackSkillSlot_${i}_notMonsters"}, $target->{nameID})));
		next unless (!$config{"attackSkillSlot_${i}_previousDamage"} || inRange($target->{dmgTo}, $config{"attackSkillSlot_${i}_previousDamage"}));
		next unless checkMonsterCondition("attackSkillSlot_${i}_target", $target);

		return {
			type => "skill",
			skillSlot => $i,
			distance => $config{"attackSkillSlot_${i}_dist"},
			maxDistance => $config{"attackSkillSlot_${i}_maxDist"} || $config{"attackSkillSlot_${i}_dist"},
		};
	} continue {
		$i++;
	}

	return;
}

# Gives plugins a chance to supply a custom attack method after the built-in active choices are exhausted.
sub resolve_plugin_attack_method {
	my ($args, $target) = @_;

	return unless $args && $target;

	my %hook_args = (
		args         => $args,
		target       => $target,
		attackMethod => undef,
	);

	# Plugins can populate attackMethod with a hashref describing the selected method.
	Plugins::callHook('AI::Attack::resolve_attack_method', \%hook_args);

	return $hook_args{attackMethod};
}

# Resolves attack methods in priority order: combo, skill, weapon, plugin, then running fallback.
sub resolve_attack_method {
	my ($args, $target) = @_;

	delete $args->{attackMethod};

	my $method = resolve_combo_attack_method($args, $target);

	if (!$method) {
		$method = resolve_skill_attack_method($args, $target);
	}

	if (!$method && $config{'attackUseWeapon'}) {
		$method = {
			type => "weapon",
			distance => $config{'attackDistance'},
			maxDistance => $config{'attackMaxDistance'},
		};
	}

	if (!$method) {
		$method = resolve_plugin_attack_method($args, $target);
	}

	if (!$method && $config{runFromTarget}) {
		$method = {
			type => "running",
			distance => $config{attackMaxDistance},
			maxDistance => $config{attackMaxDistance},
		};
		debug T("[Attack] Can't determine a attackMethod but runFromTarget is active, so attackMethod is 'running'\n"), "ai_attack";
	}

	if (!$method) {
		$method = {
			distance => 1,
			maxDistance => 1,
		};
	}

	$method->{maxDistance} ||= $config{attackMaxDistance};
	$method->{distance} ||= $config{attackDistance};
	$method->{maxDistance} = $method->{distance} if $method->{maxDistance} < $method->{distance};

	$args->{attackMethod} = $method;
	return $method;
}

# Resolves attack methods in priority order: combo, skill, weapon, plugin, then running fallback.
sub resolve_attack_method_pending_death_2 {
	my ($args, $target) = @_;

	delete $args->{attackMethod};

	my $method;

	if (!$method && $config{runFromTarget}) {
		$method = {
			type => "running",
			distance => $config{attackMaxDistance},
			maxDistance => $config{attackMaxDistance},
		};
		debug T("[Attack-pending_death_2] Can't determine a attackMethod but runFromTarget is active, so attackMethod is 'running'\n"), "ai_attack";
	}

	if (!$method) {
		$method = {
			type => "none",
			distance => $config{attackMaxDistance},
			maxDistance => $config{attackMaxDistance},
		};
		debug T("[Attack-pending_death_2] Can't determine a attackMethod so attackMethod is 'none'\n"), "ai_attack";
	}

	$method->{maxDistance} ||= $config{attackMaxDistance};
	$method->{distance} ||= $config{attackDistance};
	$method->{maxDistance} = $method->{distance} if $method->{maxDistance} < $method->{distance};

	$args->{attackMethod} = $method;
	return $method;
}

# Prepares the per-cycle target state and hit/miss counters used by the attack loop.
sub prepare_attack_cycle_state {
	my ($args, $ID) = @_;

	my $target = Actor::get($ID);
	set_target_resolution_state($args, $target);

	if (!exists $args->{temporary_extra_range} || !defined $args->{temporary_extra_range}) {
		$args->{temporary_extra_range} = 0;
	}

	if (exists $char->{movetoattack_pos}) {
		if (!exists $char->{movetoattack_targetID} || $char->{movetoattack_targetID} ne $ID || $char->{time_move} > $char->{movetoattack_time}) {
			delete $char->{movetoattack_pos};
			delete $char->{movetoattack_time};
			delete $char->{movetoattack_targetID} if (exists $char->{movetoattack_targetID});
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
				delete $char->{movetoattack_time};
				delete $char->{movetoattack_targetID} if (exists $char->{movetoattack_targetID});
			}
		}
	}

	if ($target && exists $target->{movetoattack_pos}) {
		if ($target->{time_move} > $target->{movetoattack_time}) {
			delete $target->{movetoattack_pos};
			delete $target->{movetoattack_time};
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
				delete $target->{movetoattack_time};
			}
		}
	}

	return {
		target       => $target,
		hitYou       => 0,
		youHitTarget => 0,
	} unless $target;

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

	return {
		target       => $target,
		hitYou       => $hitYou,
		youHitTarget => $youHitTarget,
	};
}

# Resolves the current attack method unless the target is already dying.
sub choose_attack_method_for_cycle {
	my ($args, $ID, $target) = @_;

	resolve_attack_method($args, $target);

	if (defined $args->{attackMethod}{type} && exists $args->{ai_attack_failed_give_up} && defined $args->{ai_attack_failed_give_up}{time}) {
		debug "Deleting ai_attack_failed_give_up time.\n";
		delete $args->{ai_attack_failed_give_up}{time};
	}

	if (
		!defined $args->{attackMethod}{type} || !defined $args->{attackMethod}{maxDistance}
	) {
		debug T("Can't determine a attackMethod (check attackUseWeapon, Skills, and plugin hooks)\n"), "ai_attack";
		$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
		$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
		if (timeOut($args->{ai_attack_failed_give_up})) {
			delete $args->{ai_attack_failed_give_up}{time};
			warning T("Unable to determine a attackMethod (check attackUseWeapon, Skills, and plugin hooks), dropping target.\n"), "ai_attack";
			giveUp($args, $ID, 0);
			return {should_return => 1};
		}
	}

	if ($args->{attackMethod}{type} eq "weapon" && $args->{temporary_extra_range}) {
		$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};
		debug TF("[attack - main] [%d] Adding cached temporary_extra_range to weapon attack.\n", $args->{loop}), 'ai_attack';
	} elsif ($args->{temporary_extra_range}) {
		$args->{temporary_extra_range} = 0;
		debug TF("[attack - main] [%d] Deleting cached temporary_extra_range.\n", $args->{loop}), 'ai_attack';
	}

	return {should_return => 0};
}

# Builds the per-cycle context shared by route, wait, and attack decisions.
sub build_attack_cycle_context {
	my ($args, $ID, $target) = @_;

	prepare_meeting_position_context($args, $char, $target, $args->{attackMethod}{maxDistance});

	unless ($args->{meetingPositionCtx}) {
		warning T("prepare_meeting_position_context failed.\n"), "ai_attack";
		giveUp($args, $ID, 0);
		return {should_return => 1};
	}

	my $realMyPos = $args->{meetingPositionCtx}{realMyPos} if $args->{meetingPositionCtx}{realMyPos};
	my $realMonsterPos = $args->{meetingPositionCtx}{realTargetPos} if $args->{meetingPositionCtx}{realTargetPos};
	my $realMonsterDist = $args->{meetingPositionCtx}{realMonsterDist} if $args->{meetingPositionCtx}{realMonsterDist};
	my $clientDist = $args->{meetingPositionCtx}{clientDist} if $args->{meetingPositionCtx}{clientDist};

	my $being_chased = $args->{meetingPositionCtx}{being_chased};
	my $remaining_alive_time = $args->{target_state}{remaining_alive_time};

	debug TF("[attack - main] [%d] after prepare_meeting_position_context.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 2);
	debug TF("[attack - main] [%d] realMyPos %d %d\n", $args->{loop}, $realMyPos->{x}, $realMyPos->{y}), 'ai_attack';
	debug TF("[attack - main] [%d] realMonsterPos %d %d\n", $args->{loop}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
	debug TF("[attack - main] [%d] realMonsterDist %d\n", $args->{loop}, $realMonsterDist), 'ai_attack';
	debug TF("[attack - main] [%d] clientDist %d\n", $args->{loop}, $clientDist), 'ai_attack';
	debug TF("[attack - main] [%d] being_chased %d\n", $args->{loop}, $being_chased), 'ai_attack';
	debug TF("[attack - main] [%d] target_can_reach_me %d\n", $args->{loop}, ($args->{meetingPositionCtx}{target_can_reach_me} ? 1 : 0)), 'ai_attack';
	debug TF("[attack - main] [%d] {target_state}{has_unresolved_dmg} %d\n", $args->{loop}, $args->{target_state}{has_unresolved_dmg}), 'ai_attack';
	debug TF("[attack - main] [%d] {target_state}{pending_death_1} %d\n", $args->{loop}, $args->{target_state}{pending_death_1}), 'ai_attack';
	debug TF("[attack - main] [%d] {target_state}{pending_death_2} %d\n", $args->{loop}, $args->{target_state}{pending_death_2}), 'ai_attack';
	debug TF("[attack - main] [%d] remaining_alive_time %s\n", $args->{loop}, (defined $remaining_alive_time ? $remaining_alive_time : 'undef')), 'ai_attack';

	my $canAttack;
	if (defined $args->{attackMethod}{type} && defined $args->{attackMethod}{maxDistance}) {
		$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{attackCanSnipe}, $args->{attackMethod}{maxDistance}, $config{clientSight});
	} else {
		$canAttack = -2;
	}

	my $canAttack_fail_string = (($canAttack == -2) ? "No Method" : (($canAttack == -1) ? "No LOS" : (($canAttack == 0) ? "No Range" : "OK")));

	if (
		$config{"attackBeyondMaxDistance_waitForAgressive"} &&
		$canAttack == 1 &&
		exists $args->{ai_attack_failed_waitForAgressive_give_up} &&
		defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
	}

	return {
		should_return       => 0,
		realMyPos           => $realMyPos,
		realMonsterPos      => $realMonsterPos,
		realMonsterDist     => $realMonsterDist,
		clientDist          => $clientDist,
		being_chased        => $being_chased,
		remaining_alive_time => $remaining_alive_time,
		canAttack           => $canAttack,
		canAttack_fail_string => $canAttack_fail_string,
		hitTarget_when_not_possible => 0,
		can_attack_now      => ($canAttack == 1 ? 1 : 0),
	};
}

# Accepts one loop of "the server let us hit anyway" before forcing a route change.
sub maybe_accept_server_attack_resolution {
	my ($args, $target, $state, $youHitTarget) = @_;

	return unless ($args->{attackMethod}{type} eq "weapon");

	return unless !$args->{firstLoop} && $state->{canAttack} == 0 && $youHitTarget;

	debug TF("[%s] We were able to hit target even though it is out of range with LOS, accepting and continuing. (%s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], clientDist %d, maxDistance %d, dmgFromYou %d)\n",
		$state->{canAttack_fail_string}, $char,
		$state->{realMyPos}{x}, $state->{realMyPos}{y},
		$target,
		$state->{realMonsterPos}{x}, $state->{realMonsterPos}{y},
		$target->{pos}{x}, $target->{pos}{y},
		$target->{pos_to}{x}, $target->{pos_to}{y},
		$state->{clientDist}, $args->{attackMethod}{maxDistance},
		$target->{dmgFromYou}
	), 'ai_attack';

	if ($state->{clientDist} > $args->{attackMethod}{maxDistance} && $state->{clientDist} <= ($args->{attackMethod}{maxDistance} + 1) && $args->{temporary_extra_range} == 0) {
		debug TF("[%s] Probably extra range provided by the server due to chasing, increasing range by 1.\n", $state->{canAttack_fail_string}), 'ai_attack';
		$args->{temporary_extra_range} = 1;
		$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};
		$state->{canAttack} = canAttack($field, $state->{realMyPos}, $state->{realMonsterPos}, $config{attackCanSnipe}, $args->{attackMethod}{maxDistance}, $config{clientSight});
	} else {
		debug TF("[%s] Reason unknown, allowing once.\n", $state->{canAttack_fail_string}), 'ai_attack';
		$state->{hitTarget_when_not_possible} = 1;
	}

	if (
		$config{"attackBeyondMaxDistance_waitForAgressive"} &&
		exists $args->{ai_attack_failed_waitForAgressive_give_up} &&
		defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "[Accepting] Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
	}

	$state->{can_attack_now} = (($state->{canAttack} == 1) || $state->{hitTarget_when_not_possible}) ? 1 : 0;
}

# Finds the live route/mapRoute action that belongs to the current attack target.
sub find_attack_route_action_index {
	my ($attack_id) = @_;

	return undef unless defined $attack_id;

	foreach my $i (0 .. $#ai_seq) {
		next unless ($ai_seq[$i] eq 'route' || $ai_seq[$i] eq 'mapRoute');

		my $routeArgs = AI::args($i);
		next unless $routeArgs;
		next unless defined $routeArgs->{attackID};
		return $i if $routeArgs->{attackID} eq $attack_id;
	}

	return undef;
}

sub clear_attack_route_actions {
	my ($attack_id) = @_;

	return 0 unless defined $attack_id;

	my $cleared = 0;
	for (my $i = $#ai_seq; $i >= 0; $i--) {
		next unless ($ai_seq[$i] eq 'route' || $ai_seq[$i] eq 'mapRoute');

		my $routeArgs = AI::args($i);
		next unless $routeArgs;
		next unless defined $routeArgs->{attackID};
		next unless $routeArgs->{attackID} eq $attack_id;

		splice(@ai_seq, $i, 1);
		splice(@ai_seq_args, $i, 1);
		$cleared++;
	}

	return $cleared;
}

sub get_route_task_destination_pos {
	my ($routeArgs) = @_;

	return unless $routeArgs;
	return $routeArgs->{dest}{pos} if $routeArgs->{dest} && $routeArgs->{dest}{pos};
	return $routeArgs->{dest} if $routeArgs->{dest} && defined $routeArgs->{dest}{x} && defined $routeArgs->{dest}{y};

	return;
}

# Decides whether the current approach route should be recalculated before we keep following it.
# Returns a false value when the route can be kept as-is, or a short reason string when revalidation is needed.
sub should_revalidate_active_approach_route {
	my ($args, $target, $ID) = @_;

	return 'target_move_time_changed' if defined $args->{monsterLastMoveTime} && $args->{monsterLastMoveTime} != $target->{time_move};

	my $routeIndex = find_attack_route_action_index($ID);
	if ($routeIndex) {
		my $routeArgs = AI::args($routeIndex);
		my $routeDestPos = get_route_task_destination_pos($routeArgs);
		return 'route_destination_changed' unless (
			$routeDestPos
			&& $args->{approachTargetSpot}
			&& $routeDestPos->{x} == $args->{approachTargetSpot}{x}
			&& $routeDestPos->{y} == $args->{approachTargetSpot}{y}
		);
	}

	my $ctx = get_meeting_position_ctx($args);
	if ($ctx && exists $args->{approachBeingChased}) {
		my $current_being_chased = $ctx->{being_chased} ? 1 : 0;
		return 'target_chase_state_changed' if $args->{approachBeingChased} != $current_being_chased;
	}

	if ($args->{monsterLastMovePosTo} && $target->{pos_to}) {
		return 'target_move_destination_changed' unless (
			   $args->{monsterLastMovePosTo}{x} == $target->{pos_to}{x}
			&& $args->{monsterLastMovePosTo}{y} == $target->{pos_to}{y}
		);
	}

	return 0;
}

# Revalidates the currently active approach route and undefines it if it no longer makes sense.
sub revalidate_active_approach_route {
	my ($args, $ID, $target, $state, $reason) = @_;

	debug TF("[attack - main] [%d] revalidating active approach route (%s).\n", $args->{loop}, ($reason || 'unknown')), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	my $chosen_pos = meetingPosition(
		$args,
		$char,
		$target,
		$args->{attackMethod}{maxDistance},
		$args->{approachTargetSpot},
	);

	if (!$chosen_pos) {
		debug TF(
			"[%s - Route invalidated] no acceptable replacement found for current route target (%d %d), clearing route.\n",
			($args->{avoiding} ? "Avoiding" : "Approaching"),
			$args->{approachTargetSpot}{x}, $args->{approachTargetSpot}{y}
		), 'ai_attack';
		clear_approach_context($args);
		$args->{avoiding} = 0;
		return {route_defined => 0};
	}

	if (
		$args->{approachTargetSpot}
		&& $chosen_pos->{x} == $args->{approachTargetSpot}{x}
		&& $chosen_pos->{y} == $args->{approachTargetSpot}{y}
	) {
		debug TF(
			"[%s - Keep current route after revalidation] route target (%d %d) is still valid.\n",
			($args->{avoiding} ? "Avoiding" : "Approaching"),
			$args->{approachTargetSpot}{x}, $args->{approachTargetSpot}{y}
		), 'ai_attack';
		store_target_route_progress($args, $target);
		return {route_defined => 1, should_return => 1};
	}

	route_to_meeting_position(
		$args,
		$ID,
		$target,
		$chosen_pos,
		$state->{realMyPos},
		$state->{realMonsterPos},
		($args->{avoiding} ? "runFromTarget readjust" : "meetingPosition readjust"),
		($chosen_pos->{route_choice_mode} || 'attack')
	);
	return {route_defined => 1, should_return => 1};
}

# Keeps, clears, or refreshes the current approach route and tells main whether the loop is already spoken for.
sub handle_active_approach_route {
	my ($args, $ID, $target, $state) = @_;

	my $realMyPos = $state->{realMyPos};
	my $realMonsterPos = $state->{realMonsterPos};
	my $clientDist = $state->{clientDist};
	my $canAttack = $state->{canAttack};

	return { handled => 0 } unless $args->{sentApproach};

	if ($args->{target_state}{pending_death_2} && !$args->{avoiding}) {
		debug TF("[attack - main] [%d] pending_death_2 active, clearing attack approach route context.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		clear_approach_context($args);
		return { handled => 0 };
	}

	my $approach_finished = timeOut($char->{time_move}, $char->{time_move_calc});
	if ($approach_finished) {
		debug TF(
			"[%s - Ended] %s (%d %d), target %s (%d %d), clientDist %d, maxDistance %d, dmgFromYou %d.\n",
			($args->{avoiding} ? "Avoiding" : "Approaching"),
			$char, $realMyPos->{x}, $realMyPos->{y},
			$target, $realMonsterPos->{x}, $realMonsterPos->{y},
			$clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}
		), 'ai_attack';
		clear_approach_context($args);
		$args->{avoiding} = 0;
		return { handled => 0 };
	}

	if ($canAttack == 1 && !$config{attackWaitApproachFinish} && !$args->{meetingPositionCtx}{runFromTarget}) {
		debug TF(
			"[Approaching - Can now attack] %s (%d %d), target %s (%d %d), clientDist %d, maxDistance %d, dmgFromYou %d.\n",
			$char, $realMyPos->{x}, $realMyPos->{y},
			$target, $realMonsterPos->{x}, $realMonsterPos->{y},
			$clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}
		), 'ai_attack';
		clear_approach_context($args);
		return { handled => 0 };
	}

	my $revalidation_reason = should_revalidate_active_approach_route($args, $target, $ID);
	if ($revalidation_reason) {
		my $result = revalidate_active_approach_route($args, $ID, $target, $state, $revalidation_reason);
		return { handled => 0 } unless $result->{route_defined};
		return { handled => 1, found_action => 1 } if $result->{should_return};
	}

	debug TF(
		"[%s - Keep current route - target has not moved] %s (%d %d), target %s (%d %d), clientDist %d, maxDistance %d, route target (%d %d).\n",
		($args->{avoiding} ? "Avoiding" : "Approaching"),
		$char, $realMyPos->{x}, $realMyPos->{y},
		$target, $realMonsterPos->{x}, $realMonsterPos->{y},
		$clientDist, $args->{attackMethod}{maxDistance},
		$args->{approachTargetSpot}{x}, $args->{approachTargetSpot}{y}
	), 'ai_attack';

	return { handled => 1, found_action => 1 };
}

# Checks whether this cycle should create a new tactical route.
sub determine_needed_attack_route {
	my ($args, $target, $state) = @_;

	if ($args->{target_state}{pending_death_2}) {
		if (
			should_try_run_from_target($args, $char, $target, ($args->{sentApproach} ? 1 : 2))
		) {
			return {
				needs_route     => 1,
				debug_context   => "pending_death_2 should_try_run_from_target",
				debug_tag       => "pendingDeath runFromTarget",
				old_spot        => $state->{realMyPos},
				allow_same_cell => 0,
				set_avoiding    => 1,
			};
		}

		return {
			needs_route => 0,
			wait_only   => 1,
		};
	}

	if (
		should_reposition_for_preferred_opening($args, $target, $state->{realMyPos}, $state->{realMonsterPos}, $state->{being_chased}, $state->{canAttack})
	) {
		return {
			needs_route   => 1,
			debug_context => "should_reposition_for_preferred_opening",
			debug_tag     => "attackPreferredMinDistance",
			old_spot      => $args->{meetingPositionBestSpot},
			allow_same_cell => 0,
		};
	}

	if ($args->{firstLoop} && $args->{attackMethod}{maxDistance} > 1) {
		return {
			needs_route   => 1,
			debug_context => "Forced reposition firstLoop",
			debug_tag     => "Forced ranged firstLoop reposition",
			old_spot      => $args->{meetingPositionBestSpot},
			allow_same_cell => 0,
		};
	}

	if (
		should_try_run_from_target($args, $char, $target, ($args->{sentApproach} ? 1 : 2))
	) {
		return {
			needs_route   => 1,
			debug_context => "should_try_run_from_target",
			debug_tag     => "runFromTarget",
			old_spot      => $state->{realMyPos},
			allow_same_cell => 0,
			set_avoiding  => 1,
		};
	}

	if (
		($state->{canAttack} == 0 || $state->{canAttack} == -1) &&
		!$state->{hitTarget_when_not_possible}
	) {
		if ($config{"attackBeyondMaxDistance_waitForAgressive"} && $state->{being_chased}) {
			return {
				needs_route => 0,
				wait_only   => 1,
			};
		}

		return {
			needs_route   => 1,
			debug_context => "canAttack == 0 || canAttack == -1",
			debug_tag     => "meetingPosition",
			old_spot      => $args->{meetingPositionBestSpot},
			allow_same_cell => 0,
		};
	}

	return {
		needs_route => 0,
	};
}

# Builds and starts a new tactical route when the current cycle needs one.
sub build_needed_attack_route {
	my ($args, $ID, $target, $state, $route_request) = @_;

	debug TF("[attack - main] [%d] call meetingPosition in %s\n", $args->{loop}, $route_request->{debug_context}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	local $args->{meetingPositionUseRunFromTarget} = $route_request->{set_avoiding} ? 1 : 0;
	my $pos = meetingPosition(
		$args,
		$char,
		$target,
		$args->{attackMethod}{maxDistance},
		$route_request->{old_spot},
	);

	if (!$pos) {
		debug TF(
			"[attack - main] [%d] no route candidate produced for %s, leaving route undefined this cycle.\n",
			$args->{loop},
			$route_request->{debug_tag},
		), 'ai_attack';
		clear_approach_context($args);
		$args->{avoiding} = 0;
		return { route_outcome => 'route_failed' };
	}

	if (
		!$route_request->{allow_same_cell} &&
		$pos->{x} == $state->{realMyPos}{x} &&
		$pos->{y} == $state->{realMyPos}{y}
	) {
		if ($route_request->{set_avoiding}) {
			debug TF(
				"[runFromTarget] Keeping current tactical spot (%d %d), mob at (%d %d).\n",
				$state->{realMyPos}{x}, $state->{realMyPos}{y},
				$state->{realMonsterPos}{x}, $state->{realMonsterPos}{y}
			), 'ai_attack';
		}
		return { route_outcome => 'stay_put' };
	}

	if ($route_request->{set_avoiding}) {
		debug TF(
			"[runFromTarget] %s kiting from (%d %d) to (%d %d), mob at (%d %d).\n",
			$char,
			$state->{realMyPos}{x}, $state->{realMyPos}{y},
			$pos->{x}, $pos->{y},
			$state->{realMonsterPos}{x}, $state->{realMonsterPos}{y}
		), 'ai_attack';
		$args->{avoiding} = 1;
	}

	route_to_meeting_position(
		$args,
		$ID,
		$target,
		$pos,
		$state->{realMyPos},
		$state->{realMonsterPos},
		$route_request->{debug_tag},
		($pos->{route_choice_mode} || 'attack')
	);
	return {
		route_outcome => 'route_started',
	};
}

# Executes the attack action when this cycle does not need route work.
sub perform_attack_without_route {
	my ($args, $ID, $target, $state) = @_;

	if (!$config{"tankMode"} || !$target->{dmgFromYou}) {
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			debug "Ready to attack target $target ($state->{realMonsterPos}{x} $state->{realMonsterPos}{y}) (clientDist $state->{clientDist} blocks away); we're at ($state->{realMyPos}{x} $state->{realMyPos}{y})\n", "ai_attack";
		}

		$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
		if (!$target->{dmgFromYou} && timeOut($args->{unstuck})) {
			$args->{unstuck}{time} = time;
			debug("Attack - trying to unstuck\n", "ai_attack");
			$char->move(@{$state->{realMyPos}}{qw(x y)});
			$args->{unstuck}{count}++;
		}

		if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_attack}) && timeOut($timeout{ai_attack_after_skill})) {
			if (Actor::Item::scanConfigAndCheck("attackEquip")) {
				Actor::Item::scanConfigAndEquip("attackEquip");
			} else {
				debug "[Attack] Sending attack target $target ($state->{realMonsterPos}{x} $state->{realMonsterPos}{y}) (clientDist $state->{clientDist} blocks away); we're at ($state->{realMyPos}{x} $state->{realMyPos}{y})\n", "ai_attack";
				$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7);
				$timeout{ai_attack}{time} = time;
				delete $args->{attackMethod};
			}

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
			$timeout{ai_attack_after_skill}{time} = time;
			$args->{monsterID} = $ID;

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
		}
	}

	if ($config{tankMode}) {
		if ($args->{dmgTo_last} != $target->{dmgTo}) {
			$args->{ai_attack_giveup}{time} = time;
			$char->sendAttackStop;
		}
		$args->{dmgTo_last} = $target->{dmgTo};
	}
}

# Waits for the next cycle when we intentionally have no route and cannot attack right now.
sub wait_attack_cycle_without_route {
	my ($args, $ID, $target, $state) = @_;

	my %hook_args = (
		target                   => $target,
		canAttack                => $state->{canAttack},
		canAttackFailString      => $state->{canAttack_fail_string},
		being_chased             => $state->{being_chased},
		hitTargetWhenNotPossible => $state->{hitTarget_when_not_possible},
		handled                  => 0,
	);
	Plugins::callHook('AI::Attack::wait_for_next_cycle', \%hook_args);
	return if $hook_args{handled};

	if (
		$config{"attackBeyondMaxDistance_waitForAgressive"} &&
		$state->{being_chased} &&
		($state->{canAttack} == 0 || $state->{canAttack} == -1) &&
		!$state->{hitTarget_when_not_possible}
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};
		if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
			warning TF("[%s] Waited too long for target to get closer, dropping target. (you %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], clientDist %d, maxDistance %d, dmgFromYou %d)\n", $state->{canAttack_fail_string}, $char, $state->{realMyPos}{x}, $state->{realMyPos}{y}, $target, $state->{realMonsterPos}{x}, $state->{realMonsterPos}{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $state->{clientDist}, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			giveUp($args, $ID, 0);
		} else {
			$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7) if ($config{"attackBeyondMaxDistance_sendAttackWhileWaiting"});
			debug TF("[%s - Waiting] %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], clientDist %d, maxDistance %d, dmgFromYou %d.\n", $state->{canAttack_fail_string}, $char, $state->{realMyPos}{x}, $state->{realMyPos}{y}, $target, $state->{realMonsterPos}{x}, $state->{realMonsterPos}{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $state->{clientDist}, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
		}
		return;
	}

	debug TF(
		"[attack - main] [%d] No route defined and cannot attack (%s), waiting until next cycle.\n",
		$args->{loop},
		$state->{canAttack_fail_string},
	), 'ai_attack';
}

sub debug_undefined_object_id {
	my ($args) = @_;
	warning "[attack main] Bug where ID is undefined found.\n";
	warning "Args Dump: " . Dumper($args);
	warning "ML Dump: " . Dumper(\@$monstersList);
	warning "ai_seq Dump: " . Dumper(\@ai_seq);
	warning "ai_seq_args Dump: " . Dumper(\@ai_seq_args);
	Plugins::callHook('undefined_object_id');
}

sub args_loop_handler {
	my ($args, $loop_key, $min, $max) = @_;
	if (!exists $args->{$loop_key} || !defined $args->{$loop_key} || $args->{$loop_key} >= $max) {
		$args->{$loop_key} = $min;
	} else {
		$args->{$loop_key}++;
	}
}

sub end_attack_main {
	my ($args, $reason, %hook_args) = @_;

	my %payload = (
		args          => $args,
		reason        => $reason,
		%hook_args,
	);
	Plugins::callHook('AI::Attack::main_end', \%payload);
	return;
}

sub main {
	my $args = AI::args;
	my $ID = $args->{ID};

	args_loop_handler($args, 'loop', 1, 100);

	debug TF("[attack - main] [%d] start.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);

	if (!defined $ID) {
		debug_undefined_object_id($args);
	}

	my $cycle_state = prepare_attack_cycle_state($args, $ID);
	my $target = $cycle_state->{target};

	return end_attack_main($args, 'missing_target') unless $target;

	if ($args->{target_state}{pending_death_1}) {
		debug TF("[attack - main] [%d] Returning because pending_death_1 == 1.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return end_attack_main($args, 'pending_death_1', target => $target);
	}

	my $method_state = { should_return => 0 };

	if ($args->{target_state}{pending_death_2} && $config{attack_stopAttacking_pendingDeathMonsters}) {
		resolve_attack_method_pending_death_2($args, $target);
	} else {
		$method_state = choose_attack_method_for_cycle($args, $ID, $target);
		return end_attack_main($args, 'attack_method_sync_return', target => $target) if $method_state->{should_return};
	}

	my $state = build_attack_cycle_context($args, $ID, $target);
	return end_attack_main($args, 'build_attack_cycle_context_return', target => $target) if $state->{should_return};

	maybe_accept_server_attack_resolution($args, $target, $state, $cycle_state->{youHitTarget});

	my $approach_state = handle_active_approach_route($args, $ID, $target, $state);
	if ($approach_state->{handled}) {
		return end_attack_main($args, 'active_route_handled', target => $target, state => $state);
	}

	my $route_request = determine_needed_attack_route($args, $target, $state);
	if ($route_request->{needs_route}) {
		my $route_result = build_needed_attack_route($args, $ID, $target, $state, $route_request);
		return end_attack_main($args, 'route_started', target => $target, state => $state) if $route_result->{route_outcome} && $route_result->{route_outcome} eq 'route_started';
		return end_attack_main($args, 'route_failed', target => $target, state => $state) if $route_result->{route_outcome} && $route_result->{route_outcome} eq 'route_failed';
		return end_attack_main($args, 'route_stay_put', target => $target, state => $state) if $route_result->{route_outcome} && $route_result->{route_outcome} eq 'stay_put';
	}

	if ($args->{sentApproach}) {
		return end_attack_main($args, 'route_still_active', target => $target, state => $state);
	}

	if ($args->{target_state}{pending_death_2}) {
		debug TF("[attack - main] [%d] Returning because pending_death_2 == 1.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return end_attack_main($args, 'pending_death_2', target => $target, state => $state);
	}

	if ($state->{can_attack_now}) {
		perform_attack_without_route($args, $ID, $target, $state);
	} else {
		wait_attack_cycle_without_route($args, $ID, $target, $state);
	}

	return end_attack_main(
		$args,
		($state->{can_attack_now} ? 'attack_processed' : 'waiting_without_route'),
		target => $target,
		state  => $state,
	);
}

##
# meetingPosition(actor, target_actor, attackMaxDistance)
# actor: current object.
# target_actor: actor to meet.
# attackMaxDistance: attack distance based on attack method.
#
# Returns: the position where the character should go to meet a moving monster.
# Prefers safe attack spots first, then falls back to safe staging spots when no attack route is acceptable.
sub meetingPosition {
	my ($args, $actor, $target, $attackMaxDistance, $oldSpot) = @_;

	if ($attackMaxDistance < 1) {
		error "attackMaxDistance must be positive ($attackMaxDistance).\n";
		return;
	}

	my $lookahead_count = 5;
	my @weight_offset = reverse(1..$lookahead_count);

	my $weight_chase = 2;
	my $weight_safer_start_distance = 3;
	my $weight_safe_window = 5;
	my $compare = 0;
	my $defensive_only = $args->{target_state}{pending_death_2} ? 1 : 0;

	debug TF("[meetingPosition] start.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	debug TF("[meetingPosition] attackMaxDistance $attackMaxDistance.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	if (defined $oldSpot && defined $oldSpot->{x} && defined $oldSpot->{y}) {
		$compare = 1;
		debug TF("[meetingPosition] oldSpot $oldSpot->{x} $oldSpot->{y}.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	} else {
		debug TF("[meetingPosition] No given oldSpot.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	}

	my $ctx = $args->{meetingPositionCtx};
	my $run_safety_extra = $ctx->{run_safety_extra};
	my $readjust_tolerance = $ctx->{readjust_tolerance};
	my $mySpeed = $ctx->{mySpeed};
	my $runFromTarget = $ctx->{runFromTarget};
	my $runFromTargetActive = (
		$runFromTarget
		&& (
			$args->{avoiding}
			|| $args->{meetingPositionUseRunFromTarget}
			|| ($args->{attackMethod} && $args->{attackMethod}{type} && $args->{attackMethod}{type} eq 'running')
		)
	) ? 1 : 0;
	my $followDistanceMax = $ctx->{followDistanceMax};
	my $attackCanSnipe = $ctx->{attackCanSnipe};
	my $realMyPos = $ctx->{realMyPos};
	my $targetSpeed = $ctx->{targetSpeed};
	my $target_snapshot = $ctx->{target_snapshot};
	my $realTargetPos = $ctx->{realTargetPos};
	my $master_snapshot = $ctx->{master_snapshot};
	my $realMasterPos = $ctx->{realMasterPos};
	my $effective_min_dist = $ctx->{effective_min_dist};
	my $desired_dist = $ctx->{desired_dist};
	my $max_path_dist = $ctx->{max_path_dist};
	my $actor_max_cost = $ctx->{actor_max_cost};
	my $actor_pf = $ctx->{actor_pf};
	my $target_max_cost = $ctx->{target_max_cost};
	my $target_pf = $ctx->{target_pf};
	my $being_chased = $ctx->{being_chased};
	my $masterPos = $ctx->{masterPos};
	my $master = $ctx->{master};
	my $remaining_alive_time = $args->{target_state}{remaining_alive_time};

	my %allspots;
	my @blocks = calcRectArea2($realMyPos->{x}, $realMyPos->{y}, $max_path_dist, 0);
	foreach my $spot (@blocks) {
		$allspots{$spot->{x}}{$spot->{y}} = 1;
	}

	my %prohibitedSpots;
	my %portalRouteProhibitedSpots;
	foreach my $prohibited_actor (@$playersList, @$monstersList, @$npcsList, @$petsList, @$slavesList, @$elementalsList) {
		next unless ($prohibited_actor->{pos_to});
		next unless (defined $prohibited_actor->{ID});
		next if ($target && defined $target->{ID} && $prohibited_actor->{ID} eq $target->{ID});
		next if ($actor  && defined $actor->{ID}  && $prohibited_actor->{ID} eq $actor->{ID});
		next if ($masterPos && $master && defined $master->{ID} && $prohibited_actor->{ID} eq $master->{ID});
		$prohibitedSpots{$prohibited_actor->{pos_to}{x}}{$prohibited_actor->{pos_to}{y}} = 1;
	}

	for my $portal (@$portalsList) {
		next unless ($portal->{pos});
		$portalRouteProhibitedSpots{$portal->{pos}{x}}{$portal->{pos}{y}} = 1;
		my @portal_near_blocks = calcRectArea2($portal->{pos}{x}, $portal->{pos}{y}, $config{'attackMinPortalDistance'}, 0);
		foreach my $near_block (@portal_near_blocks) {
			$prohibitedSpots{$near_block->{x}}{$near_block->{y}} = 1;
		}
	}
	$ctx->{portal_route_prohibited_spots} = \%portalRouteProhibitedSpots;

	my ($best_attack_score, $best_attack_time, $best_attack_spot, $best_attack_targetPosNow, $best_attack_dist_to_target);
	my ($best_staging_score, $best_staging_time, $best_staging_spot, $best_staging_targetPosNow, $best_staging_dist_to_target);
	my $EPS = 0.15;

	foreach my $x_spot (sort { $a <=> $b } keys %allspots) {
		foreach my $y_spot (sort { $a <=> $b } keys %{$allspots{$x_spot}}) {
			my $spot = { x => $x_spot, y => $y_spot };
			next if ($prohibitedSpots{$spot->{x}}{$spot->{y}});
			next unless ($field->isWalkable($spot->{x}, $spot->{y}));

			$spot->{cost_actor_to_spot} = $actor_pf->floodfill_getdist($spot->{x}, $spot->{y});
			next if ($spot->{cost_actor_to_spot} < 0);
			next if ($spot->{cost_actor_to_spot} > $actor_max_cost);
			next unless $field->canMove($realMyPos, $spot);
			$spot->{time_actor_to_get_to_spot} = calcTimeFromFloodCost($spot->{cost_actor_to_spot}, $mySpeed);

			my $cell = get_cached_target_attack_info_for_spot($ctx, $spot);
			unless ($cell) {
				$cell = get_best_attack_cell_by_pf(
					$target_pf,
					$spot,
					$ctx->{target_attack_range},
					$target_max_cost,
					get_attack_offsets_for_range($ctx->{target_attack_range}),
				);
			}
			next unless $cell;
			
			$spot->{attack_cell} = $cell->{attack_cell};
			$spot->{attack_cell_cost} = $cell->{cost};
			$spot->{time_target_to_reach_attack_cell} = defined $cell->{time}
				? $cell->{time}
				: calcTimeFromFloodCost($spot->{attack_cell_cost}, $targetSpeed);
			$spot->{target_chase_ctx} = build_chasing_target_snapshot_to_attack_cell(
				$target,
				$realTargetPos,
				$targetSpeed,
				$spot->{attack_cell},
			);

			my $targetPosNow;
			if ($being_chased) {
				$targetPosNow = $spot->{target_chase_ctx}
					? predict_position_after_delta($spot->{target_chase_ctx}{snapshot}, $spot->{time_actor_to_get_to_spot})
					: $realTargetPos;
			} else {
				$targetPosNow = $target_snapshot->{moving}
					? predict_position_after_delta($target_snapshot, $spot->{time_actor_to_get_to_spot})
					: $realTargetPos;
			}

			next unless ($spot->{x} != $targetPosNow->{x} || $spot->{y} != $targetPosNow->{y});

			if ($master_snapshot) {
				my $masterPosNow = $master_snapshot->{moving}
					? predict_position_after_delta($master_snapshot, $spot->{time_actor_to_get_to_spot})
					: $realMasterPos;
				next unless ($spot->{x} != $masterPosNow->{x} || $spot->{y} != $masterPosNow->{y});
				next unless blockDistance($spot, $masterPosNow) <= $followDistanceMax;
				next unless blockDistance($targetPosNow, $masterPosNow) <= $followDistanceMax;
			}

			my $snapshot;
			if ($being_chased && $spot->{target_chase_ctx}) {
				$snapshot = $spot->{target_chase_ctx}{snapshot};
			} elsif ($target_snapshot->{moving}) {
				$snapshot = $target_snapshot;
			}

			my $found_valid_attack_timeframe = 0;
			my $can_attack_from_spot = 0;
			my $wait_time_at_spot = 0;
			my $instability_penalty = 0;
			my $too_close_too_soon_penalty = 0;
			my $too_far_too_soon_penalty = 0;

			if ($snapshot) {
				foreach my $offset (1..$lookahead_count) {
					my $off_time = $offset/10;
					$spot->{targetPos_lookahead}[$offset] = predict_position_after_delta(
						$snapshot,
						$spot->{time_actor_to_get_to_spot} + $off_time
					);

					my $weight = $weight_offset[$offset];


					if (canAttack($field, $spot, $spot->{targetPos_lookahead}[$offset], $attackCanSnipe, $attackMaxDistance, $config{clientSight}) == 1) {
						$found_valid_attack_timeframe++;

					} else {
						if (!$found_valid_attack_timeframe) {
							$wait_time_at_spot = $off_time;
						} else {
							$instability_penalty += $off_time*$weight;
						}
					}

					my $blockDistance = blockDistance($spot, $spot->{targetPos_lookahead}[$offset]);
					if ($blockDistance <= $effective_min_dist) {
						$too_close_too_soon_penalty += $off_time*$weight;
					} elsif ($blockDistance > $attackMaxDistance) {
						$too_far_too_soon_penalty += $off_time*$weight;
					}
				}
				$too_close_too_soon_penalty *= 2 if ($runFromTargetActive);
				$too_far_too_soon_penalty *= 2 if (!$being_chased);
				$can_attack_from_spot = $found_valid_attack_timeframe ? 1 : 0;

			} else {
				$can_attack_from_spot = (canAttack($field, $spot, $targetPosNow, $attackCanSnipe, $attackMaxDistance, $config{clientSight}) == 1) ? 1 : 0;
			}

			$spot->{blockDist_to_target} = blockDistance($spot, $targetPosNow);
			$spot->{adjustedBlockDistance_to_target} = adjustedBlockDistance($spot, $targetPosNow);
			$spot->{getClientDist_to_target} = getClientDist($spot, $targetPosNow);
			$spot->{can_attack_from_here} = $can_attack_from_spot;
			$spot->{wait_penalty} = $wait_time_at_spot * 5;
			$spot->{instability_penalty} = $instability_penalty;
			$spot->{too_close_too_soon_penalty} = $too_close_too_soon_penalty;
			$spot->{too_far_too_soon_penalty} = $too_far_too_soon_penalty;

			my $is_current_spot = (
				$spot->{x} == $realMyPos->{x}
				&& $spot->{y} == $realMyPos->{y}
			) ? 1 : 0;

			my $is_old_spot = 0;
			if ($spot->{x} == $oldSpot->{x} && $spot->{y} == $oldSpot->{y}) {
				$is_old_spot = 1;
			}

			next if !$can_attack_from_spot
				&& defined $ctx->{realMonsterDist}
				&& abs($spot->{blockDist_to_target} - $desired_dist) > abs($ctx->{realMonsterDist} - $desired_dist)
				&& !$runFromTargetActive;

			my $attack_runfromtarget_score = 0;
			my $staging_runfromtarget_score = 0;
			my $attack_safe_window;
			my $staging_safe_window;

			if ($runFromTargetActive && defined $remaining_alive_time) {
				if ($remaining_alive_time > $spot->{time_target_to_reach_attack_cell}) {
					next;
				} else {
					$attack_runfromtarget_score += 10;
					$staging_runfromtarget_score += 10;
				}
			
			} elsif ($runFromTargetActive) {
				my $time_until_our_next_damage_hits = $wait_time_at_spot + get_estimate_time_my_next_damage_will_resolve($args, $actor, $target, 0, $spot);
				my $time_until_enemy_hit = estimate_time_next_target_damage_will_trigger($args, $actor, $target, 0, $spot);

				$attack_safe_window = $time_until_enemy_hit - $time_until_our_next_damage_hits
					if defined $time_until_enemy_hit && defined $time_until_our_next_damage_hits;
				$staging_safe_window = $time_until_enemy_hit - $spot->{time_actor_to_get_to_spot}
					if defined $time_until_enemy_hit;

				if (!$being_chased) {
					my $start_distance_bonus = $spot->{time_target_to_reach_attack_cell} * $weight_safer_start_distance;
					$attack_runfromtarget_score += $start_distance_bonus;
					$staging_runfromtarget_score += $start_distance_bonus;
				}

				if (defined $attack_safe_window) {
					if ($attack_safe_window < $run_safety_extra) {
						$attack_runfromtarget_score -= ($run_safety_extra - $attack_safe_window) * 18;
					} else {
						$attack_runfromtarget_score += $attack_safe_window * $weight_safe_window;
					}
				}

				if (defined $staging_safe_window) {
					if ($staging_safe_window < 0) {
						$staging_runfromtarget_score -= (0 - $staging_safe_window) * 12;
					} else {
						$staging_runfromtarget_score += $staging_safe_window * 2;
					}
				}
			}

			$spot->{attack_safe_window} = $attack_safe_window if defined $attack_safe_window;
			$spot->{staging_safe_window} = $staging_safe_window if defined $staging_safe_window;

			$spot->{chase_bonus} = 0;
			if ($being_chased && !$runFromTargetActive && $attackMaxDistance <= 1 && defined $spot->{time_target_to_reach_attack_cell}) {
				my $diff = abs($spot->{time_target_to_reach_attack_cell} - $spot->{time_actor_to_get_to_spot});
				$spot->{chase_bonus} += ($diff * $weight_chase);
			}

			$spot->{old_spot_bonus} = 0;
			if ($compare && $is_old_spot) {
				$spot->{old_spot_bonus} = $readjust_tolerance;
			}

			$spot->{drag_bonus} = 0;
			if (((!$ctx->{actor_snapshot}{moving} && $spot->{x} == $ctx->{actor_snapshot}{real_pos}{x} && $spot->{y} == $ctx->{actor_snapshot}{real_pos}{y})
				|| ($ctx->{actor_snapshot}{moving} && $spot->{x} == $ctx->{actor_snapshot}{final_pos}{x} && $spot->{y} == $ctx->{actor_snapshot}{final_pos}{y})
				|| ($actor->{pos_to} && $spot->{x} == $actor->{pos_to}{x} && $spot->{y} == $actor->{pos_to}{y}))) {
				$spot->{drag_bonus} = 0.75;
			}

			$spot->{route_eval} = evaluate_route_safety_for_spot($args, $actor, $target, $spot);
			next unless $spot->{route_eval}{has_route};
			my $base_score =
				  $spot->{old_spot_bonus}
				+ $spot->{drag_bonus}
				+ $spot->{chase_bonus}
				- $spot->{time_actor_to_get_to_spot}
				- $spot->{too_close_too_soon_penalty}
				- $spot->{too_far_too_soon_penalty}
				- $spot->{instability_penalty}
				- $spot->{wait_penalty};

			$spot->{attack_score} = $base_score
				- ($spot->{route_eval}{attack_route_penalty} || 0)
				+ $attack_runfromtarget_score;

			$spot->{staging_score} = score_staging_spot($args, $spot)
				+ $staging_runfromtarget_score;

			my $can_use_as_attack  = $can_attack_from_spot ? 1 : 0;
			my $can_use_as_staging = 1;

			# A staging tile is a place to move to. If we are already standing on this tile and still
			# cannot attack from it, keeping it as the best "staging" spot just traps us in place.
			$can_use_as_staging = 0 if $is_current_spot && !$can_attack_from_spot;

			$can_use_as_attack = 0 unless ($spot->{route_eval}{is_attack_route_safe});
			$can_use_as_staging = 0 unless ($spot->{route_eval}{is_staging_route_safe});

			if ($runFromTargetActive && defined $attack_safe_window) {
				$can_use_as_attack = 0 if $attack_safe_window < $run_safety_extra;
			}
			if ($runFromTargetActive && defined $staging_safe_window) {
				$can_use_as_staging = 0 if $staging_safe_window < 0;
			}

			if ($compare && $is_old_spot) {
				debug "[mP] Old spot $spot->{x} $spot->{y} found.\n";
				debug "[Oldspot] can_use_as_attack $can_use_as_attack (score $spot->{attack_score}) | can_use_as_staging $can_use_as_staging (score $spot->{staging_score}).\n";
				debug "[Oldspot] Mob will be at $targetPosNow->{x} $targetPosNow->{y}, dist $spot->{blockDist_to_target}, it will take $spot->{time_actor_to_get_to_spot} seconds to get there.\n";
			}

			next if (!$can_use_as_attack && !$can_use_as_staging);

			if (!$defensive_only && $can_attack_from_spot && $can_use_as_attack) {
				my $should_replace = 0;
				if (!defined $best_attack_score || $spot->{attack_score} > $best_attack_score + $EPS) {
					$should_replace = 1;
				} elsif (defined $best_attack_score && abs($spot->{attack_score} - $best_attack_score) <= $EPS) {
					if (!defined $best_attack_time || $spot->{time_actor_to_get_to_spot} < $best_attack_time) {
						$should_replace = 1;
					} elsif (defined $best_attack_dist_to_target) {
						my $best_dist_error = abs($best_attack_dist_to_target - $desired_dist);
						my $this_dist_error = abs($spot->{blockDist_to_target} - $desired_dist);
						$should_replace = 1 if $this_dist_error < $best_dist_error;
					}
				}
				if ($should_replace) {
					$spot->{route_choice_mode} = 'attack';
					$best_attack_score = $spot->{attack_score};
					$best_attack_time  = $spot->{time_actor_to_get_to_spot};
					$best_attack_spot  = $spot;
					$best_attack_targetPosNow = $targetPosNow;
					$best_attack_dist_to_target = $spot->{blockDist_to_target};
				}
			}

			if ($can_use_as_staging) {
				my $should_replace_staging = 0;
				if (!defined $best_staging_score || $spot->{staging_score} > $best_staging_score + $EPS) {
					$should_replace_staging = 1;
				} elsif (defined $best_staging_score && abs($spot->{staging_score} - $best_staging_score) <= $EPS) {
					if (!defined $best_staging_time || $spot->{time_actor_to_get_to_spot} < $best_staging_time) {
						$should_replace_staging = 1;
					}
				}
				if ($should_replace_staging) {
					$spot->{route_choice_mode} = 'staging';
					$best_staging_score = $spot->{staging_score};
					$best_staging_time  = $spot->{time_actor_to_get_to_spot};
					$best_staging_spot  = $spot;
					$best_staging_targetPosNow = $targetPosNow;
					$best_staging_dist_to_target = $spot->{blockDist_to_target};
				}
			}
		}
	}

	my ($best_spot, $best_targetPosNow, $best_dist_to_target, $best_time, $best_mode, $best_score_log);
	if (!$defensive_only && $best_attack_spot) {
		$best_spot = $best_attack_spot;
		$best_targetPosNow = $best_attack_targetPosNow;
		$best_dist_to_target = $best_attack_dist_to_target;
		$best_time = $best_attack_time;
		$best_mode = 'attack';
		$best_score_log = $best_attack_score;
	} elsif ($best_staging_spot) {
		$best_spot = $best_staging_spot;
		$best_targetPosNow = $best_staging_targetPosNow;
		$best_dist_to_target = $best_staging_dist_to_target;
		$best_time = $best_staging_time;
		$best_mode = 'staging';
		$best_score_log = $best_staging_score;
	}

	if (!defined $best_spot) {
		store_meeting_position_choice($args, undef);
		debug "[mP] No good ATTACK or STAGING spot.\n";
		return;
	}

	$best_spot->{route_choice_mode} = $best_mode;
	debug "[mP] Best $best_mode spot is $best_spot->{x} $best_spot->{y} (score $best_score_log), mob will be at $best_targetPosNow->{x} $best_targetPosNow->{y}, dist $best_dist_to_target, it will take $best_time seconds to get there.\n";
	debug "[mP] [old_spot_bonus $best_spot->{old_spot_bonus}] | [drag_bonus $best_spot->{drag_bonus}] | [chase_bonus $best_spot->{chase_bonus}]\n";
	debug "[mP] [too_close_too_soon_penalty $best_spot->{too_close_too_soon_penalty}] | [too_far_too_soon_penalty $best_spot->{too_far_too_soon_penalty}] | [instability_penalty $best_spot->{instability_penalty}] | [wait_penalty $best_spot->{wait_penalty}]\n";
	store_meeting_position_choice($args, $best_spot);
	return $best_spot;
}

1;
