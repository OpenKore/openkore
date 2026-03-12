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
use Carp::Assert;
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

	return 0 unless $args;
	return 0 unless $args->{attackMethod};
	return 0 unless defined $args->{attackMethod}{maxDistance};

	my $preferred = $config{attackPreferredMinDistance};
	return 0 unless defined $preferred;
	return 0 if $preferred <= 0;

	my $max = $args->{attackMethod}{maxDistance};
	$preferred = $max if $preferred > $max;
	$preferred = 0 if $preferred < 0;

	return $preferred;
}

sub get_effective_attack_min_distance {
	my ($args) = @_;

	my $ctx = get_meeting_position_ctx($args);
	if ($ctx && defined $ctx->{effective_min_dist}) {
		return $ctx->{effective_min_dist};
	}

	my $preferred = get_attack_preferred_min_distance($args);
	return 1 unless $preferred > 0;

	my $effective = $preferred - 1; # built-in 1-cell hysteresis
	$effective = 1 if $effective < 1;

	return $effective;
}

sub should_reposition_for_preferred_opening {
	my ($args, $target, $realMyPos, $realMonsterPos, $being_chased, $canAttack) = @_;

	return 0 unless $canAttack == 1;
	return 0 if $config{runFromTarget};
	return 0 if $being_chased; # preferred opening range only for non-chasing mobs

	my $effective_min_dist = get_effective_attack_min_distance($args);
	return 0 unless $effective_min_dist > 1;

	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);
	return ($realMonsterDist < $effective_min_dist) ? 1 : 0;
}

sub should_try_run_from_target {
	my ($args, $actor, $target, $type) = @_;

	if ($args->{target_state}{pending_death_1}) {
		debug TF("[should_try_run_from_target] pending_death_1 == 1.\n", ), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return 0;
	}

	my $ctx = get_meeting_position_ctx($args);

	return 0 unless $config{runFromTarget};
	return 0 unless $args;
	return 0 unless $args->{attackMethod};
	return 0 unless $args->{attackMethod}{type};
	return 0 unless defined $args->{attackMethod}{maxDistance};

	my $should_kite = should_kite_to_prevent_hit_before_kill($args, $actor, $target, $type);
	debug "[should_try_run_from_target] should_kite is $should_kite\n", "ai_attack";

	return 1 if ($should_kite);

	return 1 if ($args->{attackMethod}{type} eq "running");

	#my $kite_trigger_dist = $ctx->{preferred_min_dist};
	#my $current_dist = $ctx->{clientDist};
	#return 1 if (defined $current_dist && $current_dist <= $kite_trigger_dist);

	return 0;
}

sub route_to_meeting_position {
	my ($args, $ID, $target, $pos, $realMyPos, $realMonsterPos, $debugTag) = @_;

	return 0 unless $pos;

	debug TF(
		"[%s] %s moving from (%d %d) to (%d %d), mob at (%d %d).\n",
		$debugTag,
		$char,
		$realMyPos->{x}, $realMyPos->{y},
		$pos->{x}, $pos->{y},
		$realMonsterPos->{x}, $realMonsterPos->{y},
	), 'ai_attack';

	$args->{move_start} = time;
	store_approach_context($args, $pos, $target);

	my $sendAttackWithMove = 0;
	if ($config{"attackSendAttackWithMove"} && defined $args->{attackMethod}{type} && $args->{attackMethod}{type} eq "weapon") {
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

	return 1;
}

sub store_approach_context {
	my ($args, $pos, $target) = @_;

	return unless $args;
	return unless $pos;
	return unless $target;

	$args->{sentApproach} = 1;

	$args->{approachTargetPos} = {
		x => $pos->{x},
		y => $pos->{y},
	};

	$args->{monsterLastMoveTime} = $target->{time_move};

	if ($target->{pos_to}) {
		$args->{monsterLastMovePosTo} = {
			x => $target->{pos_to}{x},
			y => $target->{pos_to}{y},
		};
	}
}

sub clear_approach_context {
	my ($args) = @_;

	return unless $args;

	$args->{sentApproach} = 0;
	delete $args->{approachTargetPos};
	delete $args->{monsterLastMoveTime};
	delete $args->{monsterLastMovePosTo};
}

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

sub predict_position_after_delta {
	my ($snapshot, $delta_time) = @_;
	my $total_elapsed = $snapshot->{elapsed} + $delta_time;
	return predict_position_at_total_elapsed($snapshot, $total_elapsed);
}

sub isTargetProbablyChasingMe {
	my ($actor, $actor_pos, $target, $target_pos) = @_;

	return 0 unless $target && $target->{ID};
	my $target_is_aggressive = is_aggressive($target, undef, 0, 0);

	# Already engaged with us in some way.
	return 1 if (
		($target->{dmgToYou} || 0) > 0
		|| ($target->{missedYou} || 0) > 0
		|| ($target->{castOnToYou} || 0) > 0
		|| ($target->{dmgFromYou} || 0) > 0
	);

	# If the monster is aggressive, clean, and close enough, assume it will try to come.
	return 1 if ($target_is_aggressive && blockDistance($actor_pos, $target_pos) <= 11);

	# Optional extra hint: if its current move endpoint is getting closer to us, that is also suspicious.
	if ($target_is_aggressive && $target->{pos} && $target->{pos_to}) {
		my $dist_from = adjustedBlockDistance($actor_pos, $target->{pos});
		my $dist_to   = adjustedBlockDistance($actor_pos, $target->{pos_to});
		return 1 if $dist_to < $dist_from;
	}

	return 0;
}

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

sub store_meeting_position_choice {
	my ($args, $choice) = @_;
	return unless $args;

	if ($choice) {
		$args->{meetingPositionBestSpot} = $choice;
	} else {
		delete $args->{meetingPositionBestSpot};
	}
}

sub get_meeting_position_ctx {
	my ($args) = @_;
	return unless $args && $args->{meetingPositionCtx};
	return $args->{meetingPositionCtx};
}

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
	$ctx->{runFromTarget}                 = $config{runFromTarget};

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

	$ctx->{desired_dist} = $ctx->{runFromTarget}
		? $attackMaxDistance
		: ($ctx->{effective_min_dist} > 0 ? $ctx->{effective_min_dist} : $attackMaxDistance);

	$ctx->{max_path_dist} = $ctx->{runFromTarget}
		? $ctx->{runFromTarget_maxPathDistance}
		: $ctx->{attackRouteMaxPathDistance};
	$ctx->{max_path_dist} += 1;

	$ctx->{actor_max_cost} = $ctx->{max_path_dist} * 14;
	$ctx->{actor_pf} = build_dijkstra_map($ctx->{realMyPos}, $ctx->{actor_max_cost});

	$ctx->{target_max_cost} = $ctx->{max_path_dist} * 14;
	$ctx->{target_pf} = build_dijkstra_map($ctx->{realTargetPos}, $ctx->{target_max_cost});

	$ctx->{being_chased} = isTargetProbablyChasingMe($actor, $ctx->{realMyPos}, $target, $ctx->{realTargetPos});

	$ctx->{realMonsterDist} = blockDistance($ctx->{realMyPos}, $ctx->{realTargetPos});
	$ctx->{clientDist} = getClientDist($ctx->{realMyPos}, $ctx->{realTargetPos});

	$ctx->{attack_resolve_buffer} = 0.1;
	$ctx->{my_amotion} = get_my_amotion($actor);

	$ctx->{my_remaning_time_to_act} = get_remaning_time_to_act($actor);
	$ctx->{target_remaning_time_to_act} = get_remaning_time_to_act($target);

	$ctx->{loop_start_time} = time;

	$args->{meetingPositionCtx} = $ctx;
	return $ctx;
}

sub get_my_amotion {
	my ($actor) = @_;

	return $actor->{lastAttackAttackMotion} if defined $actor->{lastAttackAttackMotion};

	# fallback formula seconds
	my $sec = (25/(200-$actor->{'attack_speed'}));

	return $sec;
}

##
# meetingPosition(actor, target_actor, attackMaxDistance)
# actor: current object.
# target_actor: actor to meet.
# attackMaxDistance: attack distance based on attack method.
#
# Returns: the position where the character should go to meet a moving monster.
sub meetingPosition {
	my ($args, $actor, $target, $attackMaxDistance, $oldSpot) = @_;

	if ($attackMaxDistance < 1) {
		error "attackMaxDistance must be positive ($attackMaxDistance).\n";
		return;
	}

	my $lookahead_count = 4;

	my $weight_chase = 2;

	my $weight_safer_start_distance = 3;
	my $weight_safe_window = 5;

	my $compare = 0;

	debug TF("[meetingPosition] start.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	debug TF("[meetingPosition] attackMaxDistance $attackMaxDistance.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	if (defined $oldSpot && defined $oldSpot->{x} && defined $oldSpot->{y}) {
		$compare = 1;
		debug TF("[meetingPosition] oldSpot $oldSpot->{x} $oldSpot->{y}.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	} else {
		debug TF("[meetingPosition] No given oldSpot.\n"), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	}


	my $run_safety_extra = $args->{meetingPositionCtx}{run_safety_extra};

	my $readjust_tolerance = $args->{meetingPositionCtx}{readjust_tolerance};
	my $mySpeed = $args->{meetingPositionCtx}{mySpeed};
	my $runFromTarget = $args->{meetingPositionCtx}{runFromTarget};
	my $followDistanceMax = $args->{meetingPositionCtx}{followDistanceMax};
	my $attackCanSnipe = $args->{meetingPositionCtx}{attackCanSnipe};
	my $actor_snapshot = $args->{meetingPositionCtx}{actor_snapshot};
	my $realMyPos = $args->{meetingPositionCtx}{realMyPos};
	my $targetSpeed = $args->{meetingPositionCtx}{targetSpeed};
	my $target_snapshot = $args->{meetingPositionCtx}{target_snapshot};
	my $realTargetPos = $args->{meetingPositionCtx}{realTargetPos};
	my $master_snapshot = $args->{meetingPositionCtx}{master_snapshot};
	my $realMasterPos = $args->{meetingPositionCtx}{realMasterPos};
	my $preferred_min_dist = $args->{meetingPositionCtx}{preferred_min_dist};
	my $effective_min_dist = $args->{meetingPositionCtx}{effective_min_dist};
	my $desired_dist = $args->{meetingPositionCtx}{desired_dist};
	my $max_path_dist = $args->{meetingPositionCtx}{max_path_dist};
	my $actor_max_cost = $args->{meetingPositionCtx}{actor_max_cost};
	my $actor_pf = $args->{meetingPositionCtx}{actor_pf};
	my $target_max_cost = $args->{meetingPositionCtx}{target_max_cost};
	my $target_pf = $args->{meetingPositionCtx}{target_pf};
	my $being_chased = $args->{meetingPositionCtx}{being_chased};
	my $masterPos = $args->{meetingPositionCtx}{masterPos};
	my $master = $args->{meetingPositionCtx}{master};

	my %allspots;
	my @blocks = calcRectArea2($realMyPos->{x}, $realMyPos->{y}, $max_path_dist, 0);
	foreach my $spot (@blocks) {
		$allspots{$spot->{x}}{$spot->{y}} = 1;
	}

	my %prohibitedSpots;
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
		my @portal_near_blocks = calcRectArea2($portal->{pos}{x}, $portal->{pos}{y}, $config{'attackMinPortalDistance'}, 0);
		foreach my $near_block (@portal_near_blocks) {
			$prohibitedSpots{$near_block->{x}}{$near_block->{y}} = 1;
		}
	}

	my $best_score;
	my $best_time;
	my $best_spot;
	my $best_targetPosNow;
	my $best_dist_to_target;

	my $old_spot_valid = 0;

	foreach my $x_spot (sort { $a <=> $b } keys %allspots) {
		foreach my $y_spot (sort { $a <=> $b } keys %{$allspots{$x_spot}}) {
			my $spot = {
				x => $x_spot,
				y => $y_spot,
			};
			
			next if ($prohibitedSpots{$spot->{x}}{$spot->{y}});

			next unless ($field->isWalkable($spot->{x}, $spot->{y}));

			$spot->{cost_actor_to_spot} = $actor_pf->floodfill_getdist($spot->{x}, $spot->{y});
			next if ($spot->{cost_actor_to_spot} < 0);
			next if ($spot->{cost_actor_to_spot} > $actor_max_cost);

			$spot->{time_actor_to_get_to_spot} = calcTimeFromFloodCost($spot->{cost_actor_to_spot}, $mySpeed);

			my $cell = get_best_adjacent_attack_cell_by_pf($target_pf, $spot, $target_max_cost);
			next unless $cell;

			$spot->{attack_cell} = $cell->{attack_cell};
			$spot->{attack_cell_cost} = $cell->{cost};
			$spot->{time_target_to_reach_attack_cell} = calcTimeFromFloodCost($spot->{attack_cell_cost}, $targetSpeed);
			$spot->{target_chase_ctx} = build_chasing_target_snapshot_to_attack_cell(
				$target,
				$realTargetPos,
				$targetSpeed,
				$spot->{attack_cell},
			);

			my $targetPosNow;
			if ($being_chased) {
				$targetPosNow = predict_position_after_delta(
					$spot->{target_chase_ctx}{snapshot},
					$spot->{time_actor_to_get_to_spot}
				);
			} else {
				$targetPosNow = $target_snapshot->{moving}
					? predict_position_after_delta($target_snapshot, $spot->{time_actor_to_get_to_spot})
					: $realTargetPos;
			}

			next unless ($spot->{x} != $targetPosNow->{x} || $spot->{y} != $targetPosNow->{y});

			my $cheap_dist = blockDistance($spot, $targetPosNow);
			next if ($cheap_dist > $attackMaxDistance + 3) && !$runFromTarget;

			if ($master_snapshot) {
				my $masterPosNow = $master_snapshot->{moving}
					? predict_position_after_delta($master_snapshot, $spot->{time_actor_to_get_to_spot})
					: $realMasterPos;

				next unless ($spot->{x} != $masterPosNow->{x} || $spot->{y} != $masterPosNow->{y});
				next unless blockDistance($spot, $masterPosNow) <= $followDistanceMax;
				next unless blockDistance($targetPosNow, $masterPosNow) <= $followDistanceMax;
			}

			my $snapshot;
			my $snapshot_type = 0;;
			if ($being_chased && $spot->{target_chase_ctx}) {
				$snapshot = $spot->{target_chase_ctx}{snapshot};
				$snapshot_type = 1;
			} elsif ($target_snapshot->{moving}) {
				$snapshot = $target_snapshot;
				$snapshot_type = 2;
			}
			#debug TF("[meetingPosition] [$spot->{x} $spot->{y}] [targetPosNow $targetPosNow->{x} $targetPosNow->{y}] after snapshot definition - snapshot_type $snapshot_type.\n"), 'ai_attack';

			my $found_valid_attack_timeframe = 0;
			my $wait_penalty = 0;
			my $instability_penalty = 0;
			my $too_close_too_soon_penalty = 0;

			if ($snapshot) {
				foreach my $offset (0..$lookahead_count) {
					my $off_time = $offset/10;
					$spot->{targetPos_lookahead}[$offset] = predict_position_after_delta(
						$snapshot,
						$spot->{time_actor_to_get_to_spot} + $off_time
					);

					if (canAttack($field, $spot, $spot->{targetPos_lookahead}[$offset], $attackCanSnipe, $attackMaxDistance, $config{clientSight} ) == 1) {
						$found_valid_attack_timeframe++;
					} else {
						if (!$found_valid_attack_timeframe) {
							$wait_penalty += $off_time;
						} else {
							$instability_penalty += $off_time;
						}
					}
					my $adjustedBlockDistance = adjustedBlockDistance($spot, $spot->{targetPos_lookahead}[$offset]);
					if ($adjustedBlockDistance < $effective_min_dist) {
						$too_close_too_soon_penalty += (($lookahead_count - $offset)/10);
					}
				}
				next unless ($found_valid_attack_timeframe);
			
			} else {
				next unless (canAttack($field, $spot, $targetPosNow, $attackCanSnipe, $attackMaxDistance, $config{clientSight} ) == 1);
			}

			$spot->{blockDist_to_target} = blockDistance($spot, $targetPosNow);
			$spot->{adjustedBlockDistance_to_target} = adjustedBlockDistance($spot, $targetPosNow);
			$spot->{getClientDist_to_target} = getClientDist($spot, $targetPosNow);
			#debug TF("[meetingPosition] [$spot->{x} $spot->{y}] [targetPosNow $targetPosNow->{x} $targetPosNow->{y}] after snapshot end [blockDist $spot->{blockDist_to_target}] [ClientDist $spot->{getClientDist_to_target}].\n"), 'ai_attack';

			my $runfromtarget_penalty = 0;

			if ($runFromTarget && defined $args->{target_state}{remaining_alive_time}) {
				if ($args->{target_state}{remaining_alive_time} > $spot->{time_target_to_reach_attack_cell}) {
					next;
				} else {
					$runfromtarget_penalty -= 10;
				}

			} elsif ($runFromTarget) {

				my $time_until_our_next_damage_hits = get_estimate_time_my_next_damage_will_resolve($args, $actor, $target, 0, $spot);

				if (!$being_chased) {
					$runfromtarget_penalty -= $spot->{time_target_to_reach_attack_cell} * $weight_safer_start_distance;
					
				} else {
					my $time_until_enemy_hit = estimate_time_next_target_damage_will_trigger($args, $actor, $target, 0, $spot);

					my $safe_window = $time_until_enemy_hit - $time_until_our_next_damage_hits;

					if ($safe_window < $run_safety_extra) {
							# When we are already in avoidance/kiting mode, keep this strict.
							# When we are just trying to reach a valid attack spot, do not
							# discard every candidate; penalize unsafe spots instead.
							#debug TF(
							#	"[meetingPosition] [%d %d] rejected by runFromTarget safety: required %.2f > enemy %.2f\n",
							#	$spot->{x}, $spot->{y},
							#	$required_safe_until, $time_until_enemy_hit
							#), 'ai_attack';
							next;
					} else {
						$runfromtarget_penalty -= $safe_window * $weight_safe_window;
					}
				}
			}
			#debug TF("[meetingPosition] [$spot->{x} $spot->{y}] after runfromtarget block.\n"), 'ai_attack';

			# TODO review this
			my $chase_bonus = 0;
			if (
				$being_chased
				&& !$runFromTarget
				&& $attackMaxDistance <= 1
				&& defined $spot->{time_target_to_reach_attack_cell}
			) {
				my $diff = abs($spot->{time_target_to_reach_attack_cell} - $spot->{time_actor_to_get_to_spot});
				$chase_bonus += ($diff * $weight_chase) ;
			}

			my $old_spot_bonus = 0;
			if (
				$compare
				&& $spot->{x} == $oldSpot->{x}
				&& $spot->{y} == $oldSpot->{y}
			) {
				$old_spot_valid = 1;
				$old_spot_bonus = $readjust_tolerance;
			}

			my $drag_bonus = 0;
			if (
				(!$args->{meetingPositionCtx}{actor_snapshot}{moving}
				&& $spot->{x} == $args->{meetingPositionCtx}{actor_snapshot}{real_pos}{x}
				&& $spot->{y} == $args->{meetingPositionCtx}{actor_snapshot}{real_pos}{y})
				||
				($args->{meetingPositionCtx}{actor_snapshot}{moving}
				&& $spot->{x} == $args->{meetingPositionCtx}{actor_snapshot}{final_pos}{x}
				&& $spot->{y} == $args->{meetingPositionCtx}{actor_snapshot}{final_pos}{y})
				||
				($spot->{x} == $actor->{pos_to}{x} && $spot->{y} == $actor->{pos_to}{y})
			) {
				$drag_bonus = 2;
			}

			$spot->{spot_score} = $spot->{time_actor_to_get_to_spot}
				+ $too_close_too_soon_penalty
				+ $instability_penalty
				+ $wait_penalty
				+ $runfromtarget_penalty
				- $old_spot_bonus
				- $drag_bonus
				- $chase_bonus;
			
			#debug TF("[meetingPosition] [$spot->{x} $spot->{y}] end - score $spot->{spot_score}.\n"), 'ai_attack';

			my $should_replace = 0;

			if (!defined $best_score || $spot->{spot_score} < $best_score) {
				$should_replace = 1;
			} elsif (defined $best_score && $spot->{spot_score} == $best_score) {
				if (!defined $best_time || $spot->{time_actor_to_get_to_spot} < $best_time) {
					$should_replace = 1;
				} elsif (defined $best_dist_to_target) {
					my $best_dist_error = abs($best_dist_to_target - $desired_dist);
					my $this_dist_error = abs($spot->{blockDist_to_target} - $desired_dist);
					$should_replace = 1 if $this_dist_error < $best_dist_error;
				}
			}

			if ($should_replace) {
				debug TF(
					"  →→→  [meetingPosition] Set best ".
					"[$spot->{x} $spot->{y}] [targetPosNow $targetPosNow->{x} $targetPosNow->{y}] score $spot->{spot_score}\n".
					"[actor time $spot->{time_actor_to_get_to_spot}] [target time $spot->{time_target_to_reach_attack_cell}] [blockDist $spot->{blockDist_to_target}] [ClientDist $spot->{getClientDist_to_target}]\n".
					"[instability_penalty $instability_penalty] [wait_penalty $wait_penalty] [runfromtarget_penalty $runfromtarget_penalty] [old_spot_bonus $old_spot_bonus] [drag_bonus $drag_bonus] [chase_bonus $chase_bonus]\n\n"
				), 'ai_attack';
				
				$best_score = $spot->{spot_score};
				$best_time = $spot->{time_actor_to_get_to_spot};
				$best_spot = $spot;
				$best_targetPosNow = $targetPosNow;
				$best_dist_to_target = $spot->{blockDist_to_target};
			}
		}
	}

	if (!defined $best_spot) {
		store_meeting_position_choice($args, undef);
		debug "[mP] [Chase $being_chased] No good spot.\n";
		return;
	}

	if ($compare) {
		if ($old_spot_valid) {
			if ($best_spot->{x} == $oldSpot->{x} && $best_spot->{y} == $oldSpot->{y}) {
				debug "[mP] [Chase $being_chased] Keeping old spot $oldSpot->{x} $oldSpot->{y}, best spot $best_spot->{x} $best_spot->{y}, best score $best_score, tolerance $readjust_tolerance.\n";
				store_meeting_position_choice($args, $oldSpot);
				return $oldSpot;
			} else {
				debug "[mP] [Chase $being_chased] Discarding old spot $oldSpot->{x} $oldSpot->{y}, best spot $best_spot->{x} $best_spot->{y}, best score $best_score, tolerance $readjust_tolerance.\n";
			}
		} else {
			debug "[mP] [Chase $being_chased] Discarding old spot $oldSpot->{x} $oldSpot->{y} as it is no longer valid.\n";
		}
	}

	debug "[mP] [Chase $being_chased] Best spot is $best_spot->{x} $best_spot->{y}, mob will be at $best_targetPosNow->{x} $best_targetPosNow->{y}, dist $best_dist_to_target, it will take $best_time seconds to get there.\n";
	store_meeting_position_choice($args, $best_spot);
	return $best_spot;
}

# TODO: shorten the path here if the range is greater than 1
sub get_best_adjacent_attack_cell_by_pf {
	my ($target_pf, $spot, $max_cost) = @_;

	my @blocks = $field->calcRectArea($spot->{x}, $spot->{y}, 1);

	my $best_block;
	my $best_cost;

	foreach my $block (@blocks) {
		next if ($block->{x} == $spot->{x} && $block->{y} == $spot->{y});
		next unless $field->isWalkable($block->{x}, $block->{y});

		my $cost = $target_pf->floodfill_getdist($block->{x}, $block->{y});
		next if $cost < 0;
		next if defined $max_cost && $cost > $max_cost;

		if (!defined $best_cost || $cost < $best_cost) {
			$best_cost  = $cost;
			$best_block = $block;
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

sub set_target_resolution_state {
	my ($args, $target) = @_;

	my $has_unresolved = does_target_have_unresolved_damage_taken($target) ? 1 : 0;
	my $pending_death_1 = is_target_pending_death_type_1($target) ? 1 : 0;
	my $pending_death_2 = is_target_pending_death_type_2($target) ? 1 : 0;

	$args->{target_state}{has_unresolved_dmg} = $has_unresolved;
	$args->{target_state}{pending_death_1} = $pending_death_1;
	$args->{target_state}{pending_death_2} = $pending_death_2;

	$args->{target_state}{remaining_alive_time} = undef;
	if (exists $target->{pendingDeathTimer}) {
		my $time_now = time;
		my $remaining_alive_time = $target->{pendingDeathTimer} - $time_now;
		if ($remaining_alive_time <= 0) {
			$remaining_alive_time = 0;
		}
		$args->{target_state}{remaining_alive_time} = $remaining_alive_time;
	}

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
# 1 - other
sub estimate_time_next_target_damage_will_trigger {
	my ($args, $actor, $target, $type, $spot) = @_;

	my $time_to_act = $args->{meetingPositionCtx}{target_remaning_time_to_act};
	my $time_to_attack = get_remaning_time_to_attack($target);

	my $total_time = 0;
	
	if ($type == 0) {
		$total_time += max($time_to_attack, ($time_to_act + $spot->{time_target_to_reach_attack_cell}));
	
	} elsif ($type == 1) {
		my $cell = get_best_adjacent_attack_cell_by_pf($args->{meetingPositionCtx}{target_pf}, $spot, $args->{meetingPositionCtx}{target_max_cost});
		my $time_target_to_reach_attack_cell = calcTimeFromFloodCost($cell->{cost}, $args->{meetingPositionCtx}{targetSpeed});
		$total_time += max($time_to_attack, ($time_to_act + $time_target_to_reach_attack_cell));
	}

	return $total_time;
}

sub get_remaining_alive_time {
	my ($target) = @_;
	if (exists $target->{pendingDeathTimer}) {
		my $time_now = time;
		my $remaining_alive_time = $target->{pendingDeathTimer} - $time_now;
		if ($remaining_alive_time <= 0) {
			$remaining_alive_time = 0;
		}
		return $remaining_alive_time;
	} else {
		return undef;
	}
}

sub should_kite_to_prevent_hit_before_kill {
	my ($args, $actor, $target, $type) = @_;
	unless (defined $args->{meetingPositionBestSpot}) {
		debug "[should_kite_to_prevent_hit_before_kill] Returning 0 because meetingPositionBestSpot is undefined\n", "ai_attack";
		return 0;
	}

	my $safety_buffer = defined $config{runFromTargetSafety} ? $config{runFromTargetSafety} : 0;

	return 0 unless $actor && $target && $args;

	my $t_enemy_hit = estimate_time_next_target_damage_will_trigger($args, $actor, $target, 1, $args->{meetingPositionBestSpot});
	
	if (defined $args->{target_state}{remaining_alive_time}) {
		if ($t_enemy_hit > ($args->{target_state}{remaining_alive_time} + $safety_buffer)) {
			debug "[should_kite_to_prevent_hit_before_kill] get_remaining_alive_time [$args->{target_state}{remaining_alive_time}] less than t_enemy_hit [$t_enemy_hit + $safety_buffer] early return\n", "ai_attack";
			return 0;
		} else {
			return 1;
		}
	} else {
		my $t_our_hit   = get_estimate_time_my_next_damage_will_resolve($args, $actor, $target, $type, $args->{meetingPositionBestSpot});

		debug "[should_kite_to_prevent_hit_before_kill] [meetspot] $args->{meetingPositionBestSpot}{x} $args->{meetingPositionBestSpot}{y}\n", "ai_attack";
		debug "[should_kite_to_prevent_hit_before_kill] [t_enemy_hit] $t_enemy_hit\n", "ai_attack";
		debug "[should_kite_to_prevent_hit_before_kill] [t_our_hit] $t_our_hit\n", "ai_attack";

		return 0 unless defined $t_enemy_hit && defined $t_our_hit;

		my $will_kill = will_our_next_attack_kill_target($target);
		debug "[should_kite_to_prevent_hit_before_kill] [will_kill] $will_kill\n", "ai_attack";

		return 1 if $t_enemy_hit < $t_our_hit;
		return 0 if $will_kill && $t_our_hit <= $t_enemy_hit;
		return 1 if !$will_kill && $t_enemy_hit <= ($t_our_hit + $safety_buffer);

		return 0;
	}
}

# At Rathena
# Explanation of the mob_db.yml file and structure.
# AttackDelay: Attack Delay of the monster, also known as ASPD. Low value means faster attack speed, but don't make it too low or it will lag when a player got mobbed by several of these mobs.
# AttackMotion: Attack animation motion. Low value means monster's attack will be displayed in higher FPS (making it shorter, too). (Thanks to Wallex for this)
# DamageMotion: Damage animation motion, same as aMotion but used to display the "I am hit" animation. Coincidentally, this same value is used to determine how long it is before the monster/player can move again. Endure is dMotion = 0, obviously.

# For players:
# AttackMotion = 500 / (50/(200-ASPD))
# AttackDelay = 2 * AttackMotion
# DamageMotion = cap_value((800-agi*4), 400, 800)

# at battle.ccp - battle_weapon_attack

#wd.amotion = (skill_id && skill_get_inf(skill_id)&INF_GROUND_SKILL)?0:sstatus->amotion; //Amotion should be 0 for ground skills.

#// ----- DMOTION -----
#i =  800-base_status->agi*4;
#base_status->dmotion = cap_value(i, 400, 800);
#wd.dmotion = tstatus->dmotion;
# clif_damage(*src, *target, tick, wd.amotion, wd.dmotion, wd.damage, wd.div_, wd.type, wd.damage2, wd.isspdamage);
# at clif.cpp
#clif_damage
#/// 08c8 <src ID>.L <dst ID>.L <server tick>.L <src speed>.L <dst speed>.L <damage>.L <IsSPDamage>.B <div>.W <type>.B <damage2>.L (ZC_NOTIFY_ACT3)
#p.srcSpeed = sdelay;
#p.dmgSpeed = ddelay;

# At Openkore
#'08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],

# For mobs amotion and dmotion just use monster table
# For players dmotion is sent by 08c8 when receiving damage, amotion can be calculated from stats and is also sent when dealing damage

# When a source attacks a target we set these vars:
#my $source = Actor::get($args->{sourceID});
#my $target = Actor::get($args->{targetID});
#my $dmgTime = time;

#$source->{lastAttackTime} = $dmgTime;
#$target->{lastRecvAttackTime} = $dmgTime;

# Time until src can do anything again, moving, attacking, using skills (AttackMotion)
# Time until src can actually attack again is AttackDelay, not sent by the server
#$source->{lastAttackAttackMotion} = $args->{src_speed};

# Time until target can do anything again, moving, attacking, using skills (DamageMotion)
# TODO: check if it is 0 when endure is active
#$target->{lastRecvDamageMotion} = $args->{dst_speed};

# monsters table at %monstersTable holds these values - extracted from rathena
# ID	Level	Hp	AttackRange	SkillRange	AttackDelay	AttackMotion	Size	Race	Element	ElementLevel	ChaseRange


# Hercules unit.cpp unit_walktoxy_sub
#
#// Monsters always target an adjacent tile even if ranged, no need to shorten the path
#	if (ud->target_to != 0 && ud->chaserange > 1 && bl->type != BL_MOB) {
#		// Generally speaking, the walk path is already to an adjacent tile
#		// so we only need to shorten the path if the range is greater than 1.
#		// Trim the last part of the path to account for range,
#		// but always move at least one cell when requested to move.
#		for (i = (ud->chaserange*10)-10; i > 0 && ud->walkpath.path_len>1;) {
#			ud->walkpath.path_len--;
#			enum directions dir = ud->walkpath.path[ud->walkpath.path_len];
#			if (direction_diagonal(dir))
#				i -= MOVE_COST * 2; //When chasing, units will target a diamond-shaped area in range [Playtester]
#			else
#				i -= MOVE_COST;
#			ud->to_x -= dirx[dir];
#			ud->to_y -= diry[dir];
#		}
#	}

=pod
/**
 * Sets the delays that prevent attacks and skill usage considering the bl type
 * Makes sure that delays are not decreased in case they are already higher
 * Will also invoke bl type specific delay functions when required
 * @param bl Object to apply attack delay to
 * @param tick Current tick
 * @param event The event that resulted in calling this function
 */
void unit_set_attackdelay(block_list& bl, t_tick tick, e_delay_event event)
{
	unit_data* ud = unit_bl2ud(&bl);

	if (ud == nullptr)
		return;

	t_tick attack_delay = 0;
	t_tick act_delay = 0;

	switch (bl.type) {
		case BL_PC:
			switch (event) {
				case DELAY_EVENT_CASTBEGIN_ID:
				case DELAY_EVENT_CASTBEGIN_POS:
					if (reinterpret_cast<map_session_data*>(&bl)->skillitem == ud->skill_id) {
						// Skills used from items don't seem to give any attack or act delay
						return;
					}
					[[fallthrough]];
				case DELAY_EVENT_ATTACK:
				case DELAY_EVENT_PARRY:
					// Officially for players it just remembers the last attack time here and applies the delays during the comparison
					// But we pre-calculate the delays instead and store them in attackabletime and canact_tick
					attack_delay = status_get_adelay(&bl);
					// A fixed delay is added here which is equal to the minimum attack motion you can get
					// This ensures that at max ASPD attackabletime and canact_tick are equal
					act_delay = status_get_amotion(&bl) + (pc_maxaspd(reinterpret_cast<map_session_data*>(&bl)) / AMOTION_DIVIDER_PC);
					break;
			}
			break;
		case BL_MOB:
			switch (event) {
				case DELAY_EVENT_ATTACK:
				case DELAY_EVENT_CASTEND:
				case DELAY_EVENT_CASTCANCEL:
					// This represents setting of attack delay (recharge time) that happens for non-PCs
					attack_delay = status_get_adelay(&bl);
					break;
				case DELAY_EVENT_CASTBEGIN_ID:
				case DELAY_EVENT_CASTBEGIN_POS:
					// When monsters use skills, they only get delays on cast end and cast cancel
					break;
			}
			// Set monster-specific delays (inactive AI time, monster skill delays)
			mob_set_delay(reinterpret_cast<mob_data&>(bl), tick, event);
			break;
		case BL_HOM:
			switch (event) {
				case DELAY_EVENT_ATTACK:
					// This represents setting of attack delay (recharge time) that happens for non-PCs
					attack_delay = status_get_adelay(&bl);
					break;
				case DELAY_EVENT_CASTBEGIN_ID:
				case DELAY_EVENT_CASTBEGIN_POS:
					// For non-PCs that can be controlled from the client, there is a security delay of 200ms
					// However to prevent tricks to use skills faster, we have a config to use amotion instead
					if (battle_config.amotion_min_skill_delay == 1)
						act_delay = status_get_amotion(&bl) + MAX_ASPD_NOPC;
					else
						act_delay = MIN_DELAY_SLAVE;
					break;
			}
			break;
		case BL_MER:
			switch (event) {
				case DELAY_EVENT_ATTACK:
					// This represents setting of attack delay (recharge time) that happens for non-PCs
					attack_delay = status_get_adelay(&bl);
					break;
				case DELAY_EVENT_CASTBEGIN_ID:
					// For non-PCs that can be controlled from the client, there is a security delay of 200ms
					// However to prevent tricks to use skills faster, we have a config to use amotion instead
					if (battle_config.amotion_min_skill_delay == 1)
						act_delay = status_get_amotion(&bl) + MAX_ASPD_NOPC;
					else
						act_delay = MIN_DELAY_SLAVE;
					break;
				case DELAY_EVENT_CASTBEGIN_POS:
					// For ground skills, mercenaries work similar to players
					attack_delay = status_get_adelay(&bl);
					act_delay = status_get_amotion(&bl) + MAX_ASPD_NOPC;
					break;
			}
			break;
		default:
			// Fallback to original behavior as unit type is not fully integrated yet
			switch (event) {
				case DELAY_EVENT_ATTACK:
					attack_delay = status_get_adelay(&bl);
					break;
				case DELAY_EVENT_CASTBEGIN_ID:
				case DELAY_EVENT_CASTBEGIN_POS:
					act_delay = status_get_amotion(&bl);
					break;
			}
			break;
	}

	// When setting delays, we need to make sure not to decrease them in case they've been set by another source already
	if (attack_delay > 0)
		ud->attackabletime = i64max(tick + attack_delay, ud->attackabletime);
	if (act_delay > 0)
		ud->canact_tick = i64max(tick + act_delay, ud->canact_tick);
}

/**
 * Gets the status data of the given bl
 * @param bl: Object whose status to get [PC|MOB|PET|HOM|MER|ELEM|NPC]
 * @return status or "dummy_status" if any other bl->type than noted above
 */
status_data* status_get_status_data(block_list& bl){
	switch (bl.type) {
		case BL_PC:
			return &reinterpret_cast<map_session_data*>( &bl )->battle_status;
		case BL_MOB:
			return &reinterpret_cast<mob_data*>( &bl )->status;
		case BL_PET:
			return &reinterpret_cast<pet_data*>( &bl )->status;
		case BL_HOM:
			return &reinterpret_cast<homun_data*>( &bl )->battle_status;
		case BL_MER:
			return &reinterpret_cast<s_mercenary_data*>( &bl )->battle_status;
		case BL_ELEM:
			return &reinterpret_cast<s_elemental_data*>( &bl )->battle_status;
		case BL_NPC: {
				npc_data* nd = reinterpret_cast<npc_data*>( &bl );

				if( mobdb_checkid( nd->class_ ) == 0 ){
					return &nd->status;
				}else{
					return &dummy_status;
				}
			}
		default:
			return &dummy_status;
	}
}

=cut

sub invalidate_meeting_spot_if_stale {
	my ($args, $realMyPos) = @_;
	my $spot = $args->{meetingPositionBestSpot} or return;

	my $same_cell = $realMyPos
		&& $spot->{x} == $realMyPos->{x}
		&& $spot->{y} == $realMyPos->{y};
	return if ($same_cell);

	my $heading_there = $char->{pos_to}
		&& $char->{pos_to}{x} == $spot->{x}
		&& $char->{pos_to}{y} == $spot->{y};
	return if ($heading_there);

	my $routeIndex = AI::findAction("route");
	$routeIndex = AI::findAction("mapRoute") if (!defined $routeIndex);
	if (defined $routeIndex) {
		my $routeArgs = AI::args($routeIndex);
		return if ($routeArgs->{dest} && $routeArgs->{dest}{x} == $spot->{x} && $routeArgs->{dest}{y} == $spot->{y});
	}

	message TF("[attack] [invalidate_meeting_spot_if_stale] Clearing\n"), 'ai_attack';
	delete $args->{meetingPositionBestSpot};
	clear_approach_context($args);
}

sub main {
	my $args = AI::args;
	my $ID = $args->{ID};

	Benchmark::begin("ai_attack (part 1)") if DEBUG;
	Benchmark::begin("ai_attack (part 1.1)") if DEBUG;
	# The attack sequence hasn't timed out and the monster is on screen

	# Update information about the monster and the current situation

	if (!exists $args->{loop} || !defined $args->{loop}) {
		$args->{loop} = 0;
	} elsif ($args->{loop} < 100) {
		$args->{loop}++;
	} else {
		$args->{loop} = 0;
	}

	debug TF("[attack - main] [%d] start.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
	if ($args->{target_state}{pending_death_1}) {
		debug TF("[attack - main] [%d] Returning because pending_death_1 == 1.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		return;
	}

	if (!defined $ID) {
		warning "[attack main] Bug where ID is undefined found.\n";
		warning "Args Dump: " . Dumper($args);
		warning "ML Dump: " . Dumper(\@$monstersList);
		warning "ai_seq Dump: " . Dumper(\@ai_seq);
		warning "ai_seq_args Dump: " . Dumper(\@ai_seq_args);
		Plugins::callHook('undefined_object_id');
	}

	my $target = Actor::get($ID);
	set_target_resolution_state($args, $target);



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
			next unless defined $config{"attackSkillSlot_$i"};

			my $skill = Skill->new(auto => $config{"attackSkillSlot_$i"});
			next unless $skill;
			next unless $skill->getOwnerType == Skill::OWNER_CHAR;

			my $handle = $skill->getHandle();

			next unless checkSelfCondition("attackSkillSlot_$i");
			next unless (!$config{"attackSkillSlot_$i"."_maxUses"} || $target->{skillUses}{$handle} < $config{"attackSkillSlot_$i"."_maxUses"});
			next unless (!$config{"attackSkillSlot_$i"."_maxAttempts"} || $args->{attackSkillSlot_attempts}{$i} < $config{"attackSkillSlot_$i"."_maxAttempts"});
			next unless (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{name}) || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{nameID}));
			next unless (!$config{"attackSkillSlot_$i"."_notMonsters"} || !(existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{name}) || existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{nameID})));
			next unless (!$config{"attackSkillSlot_$i"."_previousDamage"} || inRange($target->{dmgTo}, $config{"attackSkillSlot_$i"."_previousDamage"}));
			next unless checkMonsterCondition("attackSkillSlot_${i}_target", $target);

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

	if (
		!defined $args->{attackMethod}{type} || !defined $args->{attackMethod}{maxDistance}
	) {
		if ($config{runFromTarget}) {
			$args->{attackMethod}{type} = "running";
			$args->{attackMethod}{distance} = $config{attackMaxDistance};
			$args->{attackMethod}{maxDistance} = $config{attackMaxDistance};
			debug T("[Attack] Can't determine a attackMethod but runFromTarget is active, so attackMethod is 'running'\n"), "ai_attack";
		} else {
			debug T("Can't determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), "ai_attack";
			$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
			$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
			if (timeOut($args->{ai_attack_failed_give_up})) {
				delete $args->{ai_attack_failed_give_up}{time};
				warning T("Unable to determine a attackMethod (check attackUseWeapon and Skills blocks), dropping target.\n"), "ai_attack";
				giveUp($args, $ID, 0);
				return;
			}
		}
	}

	if (defined $args->{attackMethod}{type} && $args->{attackMethod}{type} eq "weapon" && $args->{temporary_extra_range}) {
		$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};
		debug TF("[attack - main] [%d] Adding cached temporary_extra_range to weapon attack.\n", $args->{loop}), 'ai_attack';
	} elsif ($args->{temporary_extra_range}) {
		$args->{temporary_extra_range} = 0;
		debug TF("[attack - main] [%d] Deleting cached temporary_extra_range.\n", $args->{loop}), 'ai_attack';
	}

	prepare_meeting_position_context($args, $char, $target, $args->{attackMethod}{maxDistance});
	
	unless ($args->{meetingPositionCtx}) {
		warning T("prepare_meeting_position_context failed.\n"), "ai_attack";
		giveUp($args, $ID, 0);
		return;
	}
	
	my $realMyPos = $args->{meetingPositionCtx}{realMyPos} if $args->{meetingPositionCtx}{realMyPos};
	my $realMonsterPos = $args->{meetingPositionCtx}{realTargetPos} if $args->{meetingPositionCtx}{realTargetPos};
	my $realMonsterDist = $args->{meetingPositionCtx}{realMonsterDist} if $args->{meetingPositionCtx}{realMonsterDist};
	my $clientDist = $args->{meetingPositionCtx}{clientDist} if $args->{meetingPositionCtx}{clientDist};

	my $being_chased = $args->{meetingPositionCtx}{being_chased};

	debug TF("[attack - main] [%d] after prepare_meeting_position_context.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 2);

	debug TF("[attack - main] [%d] realMyPos %d %d\n", $args->{loop}, $realMyPos->{x}, $realMyPos->{y}), 'ai_attack';
	debug TF("[attack - main] [%d] realMonsterPos %d %d\n", $args->{loop}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
	debug TF("[attack - main] [%d] realMonsterDist %d\n", $args->{loop}, $realMonsterDist), 'ai_attack';
	debug TF("[attack - main] [%d] clientDist %d\n", $args->{loop}, $clientDist), 'ai_attack';
	debug TF("[attack - main] [%d] being_chased %d\n", $args->{loop}, $being_chased), 'ai_attack';
	debug TF("[attack - main] [%d] {target_state}{has_unresolved_dmg} %d\n", $args->{loop}, $args->{target_state}{has_unresolved_dmg}), 'ai_attack';
	debug TF("[attack - main] [%d] {target_state}{pending_death_1} %d\n", $args->{loop}, $args->{target_state}{pending_death_1}), 'ai_attack';
	debug TF("[attack - main] [%d] {target_state}{pending_death_2} %d\n", $args->{loop}, $args->{target_state}{pending_death_2}), 'ai_attack';
	debug TF("[attack - main] [%d] get_remaining_alive_time $args->{target_state}{remaining_alive_time}\n", $args->{loop}), 'ai_attack';

	invalidate_meeting_spot_if_stale ($args, $realMyPos, $target);
	
	my $found_action = 0;
	my $failed_runFromTarget = 0;
	my $hitTarget_when_not_possible = 0;

	# -2: undefined attackMethod
	# -1: No LOS
	#  0: out of range
	#  1: success
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
		$being_chased &&
		$canAttack == 1 &&
		exists $args->{ai_attack_failed_waitForAgressive_give_up} &&
		defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
	}
	
	my $preferredMinDistance = get_attack_preferred_min_distance($args);
	

	if ($args->{sentApproach}) {
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
		
		} elsif ($canAttack == 1 && !$config{attackWaitApproachFinish} && !$config{runFromTarget}) {
			debug TF(
				"[Approaching - Can now attack] %s (%d %d), target %s (%d %d), clientDist %d, maxDistance %d, dmgFromYou %d.\n",
				$char, $realMyPos->{x}, $realMyPos->{y},
				$target, $realMonsterPos->{x}, $realMonsterPos->{y},
				$clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}
			), 'ai_attack';
			clear_approach_context($args);

		} else {
			my $target_route_changed = 0;

			if (
				defined $args->{monsterLastMoveTime}
				&& $args->{monsterLastMoveTime} != $target->{time_move}
			) {
				debug TF("[attack - main] [%d] call meetingPosition in sentApproach 1\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
				my $chosen_pos = meetingPosition(
					$args,
					$char,
					$target,
					$args->{attackMethod}{maxDistance},
					$args->{approachTargetPos},
				);

				if (!$chosen_pos) {
					debug TF(
						"[%s - Keep current route after target move] no better valid replacement found for current route target (%d %d).\n",
						($args->{avoiding} ? "Avoiding" : "Approaching"),
						$args->{approachTargetPos}{x}, $args->{approachTargetPos}{y}
					), 'ai_attack';

					$args->{monsterLastMoveTime} = $target->{time_move};
					if ($target->{pos_to}) {
						$args->{monsterLastMovePosTo} = {
							x => $target->{pos_to}{x},
							y => $target->{pos_to}{y},
						};
					}

					return;
				
				} elsif (
					$chosen_pos
					&& $args->{approachTargetPos}
					&& $chosen_pos->{x} == $args->{approachTargetPos}{x}
					&& $chosen_pos->{y} == $args->{approachTargetPos}{y}
				) {
					debug TF(
						"[%s - Keep current route after target move] route target (%d %d) still acceptable, mob route now (%d %d).\n",
						($args->{avoiding} ? "Avoiding" : "Approaching"),
						$args->{approachTargetPos}{x}, $args->{approachTargetPos}{y},
						$target->{pos_to}{x}, $target->{pos_to}{y}
					), 'ai_attack';

					$args->{monsterLastMoveTime} = $target->{time_move};
					if ($target->{pos_to}) {
						$args->{monsterLastMovePosTo} = {
							x => $target->{pos_to}{x},
							y => $target->{pos_to}{y},
						};
					}

					return;
				} else {
					route_to_meeting_position(
						$args,
						$ID,
						$target,
						$chosen_pos,
						$realMyPos,
						$realMonsterPos,
						($args->{avoiding} ? "runFromTarget readjust" : "meetingPosition readjust")
					);
					$found_action = 1;
				}
				
			} else {
				debug TF(
					"[%s - Keep current route - target has not moved] %s (%d %d), target %s (%d %d), clientDist %d, maxDistance %d, route target (%d %d).\n",
					($args->{avoiding} ? "Avoiding" : "Approaching"),
					$char, $realMyPos->{x}, $realMyPos->{y},
					$target, $realMonsterPos->{x}, $realMonsterPos->{y},
					$clientDist, $args->{attackMethod}{maxDistance},
					$args->{approachTargetPos}{x}, $args->{approachTargetPos}{y}
				), 'ai_attack';
				$found_action = 1;
			}
		}
	}

	# Preferred opening range for non-chasing mobs:
	# if we can already attack but we are too close, relocate before starting.
	if (
		!$found_action &&
		should_reposition_for_preferred_opening($args, $target, $realMyPos, $realMonsterPos, $being_chased, $canAttack)
	) {
		debug TF("[attack - main] [%d] call meetingPosition in should_reposition_for_preferred_opening\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		my $pos = meetingPosition(
			$args,
			$char,
			$target,
			$args->{attackMethod}{maxDistance},
			$args->{meetingPositionBestSpot}
		);

		if ($pos && !($pos->{x} == $realMyPos->{x} && $pos->{y} == $realMyPos->{y})) {
			route_to_meeting_position($args, $ID, $target, $pos, $realMyPos, $realMonsterPos, "attackPreferredMinDistance");
			$found_action = 1;
		}
	}

	# Forced reposition
	if (!$found_action && $args->{firstLoop} && $args->{attackMethod}{maxDistance} > 1) {
		debug TF("[attack - main] [%d] call meetingPosition in Forced reposition firstLoop\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		my $pos = meetingPosition(
			$args,
			$char,
			$target,
			$args->{attackMethod}{maxDistance},
			$args->{meetingPositionBestSpot},
			$realMyPos
		);

		if ($pos && !($pos->{x} == $realMyPos->{x} && $pos->{y} == $realMyPos->{y})) {
			route_to_meeting_position($args, $ID, $target, $pos, $realMyPos, $realMonsterPos, "Forced ranged firstLoop reposition");
			$found_action = 1;
		}
	}

	if (!defined $args->{meetingPositionBestSpot}) {
		debug TF("[attack - main] [%d] call meetingPosition in Force define meetingPositionBestSpot\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		my $pos = meetingPosition(
			$args,
			$char,
			$target,
			$args->{attackMethod}{maxDistance},
			$realMyPos
		);

		if ($pos) {
			route_to_meeting_position($args, $ID, $target, $pos, $realMyPos, $realMonsterPos, "attackPreferredMinDistance");
			$found_action = 1;
		}
	}

	# Kiting mode:
	# if runFromTarget is enabled and we are not near our preferred far range, try to kite first.
	if (
		!$found_action &&
		should_try_run_from_target($args, $char, $target, ($args->{sentApproach} ? 1 : 2))
	) {
		debug TF("[attack - main] [%d] call meetingPosition in should_try_run_from_target\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		my $pos = meetingPosition(
			$args,
			$char,
			$target,
			$args->{attackMethod}{maxDistance},
			$realMyPos,
		);

		if ($pos) {
			if (
				$pos->{x} == $realMyPos->{x}
				&& $pos->{y} == $realMyPos->{y}
			) {
				debug TF(
					"[runFromTarget] Keeping current tactical spot (%d %d), mob at (%d %d).\n",
					$realMyPos->{x}, $realMyPos->{y},
					$realMonsterPos->{x}, $realMonsterPos->{y}
				), 'ai_attack';

			} else {
				debug TF(
					"[runFromTarget] %s kiting from (%d %d) to (%d %d), mob at (%d %d).\n",
					$char,
					$realMyPos->{x}, $realMyPos->{y},
					$pos->{x}, $pos->{y},
					$realMonsterPos->{x}, $realMonsterPos->{y}
				), 'ai_attack';

				$args->{avoiding} = 1;
				route_to_meeting_position(
					$args,
					$ID,
					$target,
					$pos,
					$realMyPos,
					$realMonsterPos,
					"runFromTarget"
				);
				$found_action = 1;
			}

		} else {
			debug TF(
				"[runFromTarget] %s no acceptable place to kite from (%d %d), mob at (%d %d).\n",
				$char,
				$realMyPos->{x}, $realMyPos->{y},
				$realMonsterPos->{x}, $realMonsterPos->{y}
			), 'ai_attack';
			$failed_runFromTarget = 1;
		}
	}

	if ($args->{target_state}{pending_death_2}) {
		debug TF("[attack - main] [%d] Blocking attacking because pending_death_2 == 1.\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		$found_action = 1;
		return;
	}
	
	if (!$args->{firstLoop} && $canAttack == 0 && $youHitTarget) {
		debug TF("[%s] We were able to hit target even though it is out of range or LOS, accepting and continuing. (%s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], clientDist %d, maxDistance %d, dmgFromYou %d)\n",
			$canAttack_fail_string, $char,
			$realMyPos->{x}, $realMyPos->{y},
			$target,
			$realMonsterPos->{x}, $realMonsterPos->{y},
			$target->{pos}{x}, $target->{pos}{y},
			$target->{pos_to}{x}, $target->{pos_to}{y},
			$clientDist, $args->{attackMethod}{maxDistance},
			$target->{dmgFromYou}
		), 'ai_attack';
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
		$being_chased &&
		($canAttack == 0 || $canAttack == -1) &&
		!$hitTarget_when_not_possible
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};
		if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
			warning TF("[%s] Waited too long for target to get closer, dropping target. (you %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], clientDist %d, maxDistance %d, dmgFromYou %d)\n", $canAttack_fail_string, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
			giveUp($args, $ID, 0);
			# TODO: Here add a move to target fallback
		} else {
			$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7) if ($config{"attackBeyondMaxDistance_sendAttackWhileWaiting"});
			debug TF("[%s - Waiting] %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], clientDist %d, maxDistance %d, dmgFromYou %d.\n", $canAttack_fail_string, $char, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $clientDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromYou}), 'ai_attack';
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
			debug "[Attack] [No range] Too far from us to attack, clientDist is $clientDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';

		} elsif ($canAttack == -1) {
			debug "[Attack] [No LOS] No LOS from player to mob\n", 'ai_attack';
		}
		debug TF("[attack - main] [%d] call meetingPosition in canAttack == 0 || canAttack == -1\n", $args->{loop}), 'ai_attack' if (LOCALDEBUGLEVEL >= 1);
		my $pos = meetingPosition(
			$args,
			$char,
			$target,
			$args->{attackMethod}{maxDistance},
			$args->{meetingPositionBestSpot}
		);

		if ($pos) {
			route_to_meeting_position($args, $ID, $target, $pos, $realMyPos, $realMonsterPos, "meetingPosition");
		} else {
			message T("Unable to calculate a meetingPosition to target, dropping target\n"), "ai_attack";
			giveUp($args, $ID, 1);
		}
		$found_action = 1;
	}

	if (
		!$found_action &&
		(!$config{"tankMode"} || !$target->{dmgFromYou})
	) {
		# Attack the target. In case of tanking, only attack if it hasn't been hit once.
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			debug "Ready to attack target $target ($realMonsterPos->{x} $realMonsterPos->{y}) (clientDist $clientDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
		}

		$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
		if (!$target->{dmgFromYou} && timeOut($args->{unstuck})) {
			# We are close enough to the target, and we're trying to attack it,
			# but some time has passed and we still haven't dealed any damage.
			# Our recorded position might be out of sync, so try to unstuck
			$args->{unstuck}{time} = time;
			debug("Attack - trying to unstuck\n", "ai_attack");
			$char->move(@{$realMyPos}{qw(x y)});
			$args->{unstuck}{count}++;
		}

		# Attack with weapon logic
		if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_attack}) && timeOut($timeout{ai_attack_after_skill})) {
			if (Actor::Item::scanConfigAndCheck("attackEquip")) {
				#check if item needs to be equipped
				Actor::Item::scanConfigAndEquip("attackEquip");
			} else {
				debug "[Attack] Sending attack target $target ($realMonsterPos->{x} $realMonsterPos->{y}) (clientDist $clientDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
				$messageSender->sendAction($ID, ($config{'tankMode'}) ? 0 : 7);
				$timeout{ai_attack}{time} = time;
				delete $args->{attackMethod};
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
