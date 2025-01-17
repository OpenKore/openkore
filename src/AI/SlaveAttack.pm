package AI::SlaveAttack;

use strict;

use Time::HiRes qw(time);
use base qw/Actor::Slave/;

use Globals;
use AI;
use Actor;
use Field;
use Log qw/message warning error debug/;
use Translation qw(T TF);
use Misc;
use Skill;
use Utils;
use Utils::PathFinding;

use constant {
	MOVING_TO_ATTACK => 1,
	ATTACKING => 2,
};

use AI::Slave;
use AI::Slave::Homunculus;
use AI::Slave::Mercenary;


##### ATTACK #####
sub process {
	my $slave = shift;

	if (shouldAttack($slave, $slave->action, $slave->args)) {
		my $ID;
		my $ataqArgs;
		my $stage; # 1 - moving to attack | 2 - attacking
		if ($slave->action eq "attack") {
			$ID = $slave->args->{ID};
			$ataqArgs = $slave->args(0);
			$stage = ATTACKING;
		} else {
			if ($slave->action(1) eq "attack") {
				$ataqArgs = $slave->args(1);

			} elsif ($slave->action(2) eq "attack") {
				$ataqArgs = $slave->args(2);
			}
			$ID = $slave->args->{attackID};
			$stage = MOVING_TO_ATTACK;
		}

		if (targetGone($slave, $ataqArgs, $ID)) {
			finishAttacking($slave, $ataqArgs, $ID);
			return;
		} elsif (shouldGiveUp($slave, $ataqArgs, $ID)) {
			giveUp($slave, $ataqArgs, $ID, 0);
			return;
		}

		my $target = Actor::get($ID);
		unless ($target && $target->{type} ne 'Unknown') {
			finishAttacking($slave, $ataqArgs, $ID);
			return;
		}
		my $party = $config{$slave->{configPrefix}.'attackAuto_party'} ? 1 : 0;
		my $target_is_aggressive = is_aggressive_slave($slave, $target, undef, 0, $party);
		my @aggressives = ai_slave_getAggressives($slave, 0, $party);
		if ($config{$slave->{configPrefix}.'attackChangeTarget'} && !$target_is_aggressive && @aggressives) {
			my $attackTarget = getBestTarget(\@aggressives, $config{$slave->{configPrefix}.'attackCheckLOS'}, $config{$slave->{configPrefix}.'attackCanSnipe'});
			if ($attackTarget) {
				$slave->sendAttackStop;
				$slave->dequeue while ($slave->inQueue("attack"));
				$slave->setSuspend(0);
				my $new_target = Actor::get($attackTarget);
				warning TF("%s target is not aggressive: %s, changing target to aggressive: %s.\n", $slave, $target, $new_target), 'slave_attack';
				$slave->attack($attackTarget);
				AI::SlaveAttack::process($slave);
				return;
			}
		}

		my $cleanMonster = slave_checkMonsterCleanness($slave, $ID);
		if (!$cleanMonster) {
			message TF("%s dropping target %s - will not kill steal others\n", $slave, $target), 'slave_attack';
			$slave->sendAttackStop;
			$target->{slave_ignore} = 1;
			$slave->dequeue while ($slave->inQueue("attack"));

			if ($config{$slave->{configPrefix}.'teleportAuto_dropTargetKS'}) {
				message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
				ai_useTeleport(1);
			}
			return;
		}
	
		if ($stage == MOVING_TO_ATTACK) {
			# Check for hidden monsters
			if (($target->{statuses}->{EFFECTSTATE_BURROW} || $target->{statuses}->{EFFECTSTATE_HIDING}) && $config{avoidHiddenMonsters}) {
				message TF("Slave %s Dropping target %s - will not attack hidden monsters\n", $slave, $target), 'ai_attack';
				$slave->sendAttackStop;
				$target->{ignore} = 1;

				$slave->dequeue while ($slave->inQueue("attack"));
				if ($config{teleportAuto_dropTargetHidden}) {
					message T("Teleport due to dropping hidden target\n");
					ai_useTeleport(1);
				}
				return;
			}
			
			# We're on route to the monster; check whether the monster has moved
			if ($slave->args->{attackID} && timeOut($timeout{$slave->{ai_route_adjust_timeout}})) {
				my $reset = 0;
				if ($target->{type} ne 'Unknown') {
					# Monster has moved; stop moving and let the attack AI readjust route
					if (
						$ataqArgs->{monsterLastMoveTime} &&
						$ataqArgs->{monsterLastMoveTime} != $target->{time_move}
					) {
						if (
							($slave->args->{monsterLastMovePosTo}{x} == $target->{pos_to}{x} && $slave->args->{monsterLastMovePosTo}{y} == $target->{pos_to}{y})
						) {
							$slave->args->{monsterLastMoveTime} = $target->{time_move};
							$slave->args->{monsterLastMovePosTo}{x} = $target->{pos_to}{x};
							$slave->args->{monsterLastMovePosTo}{y} = $target->{pos_to}{y};
						} else {
							debug "$slave target $target has moved since we started routing to it - Adjusting route\n", 'slave_attack';
							$reset = 1;
						}

					# Master has moved; stop moving and let the attack AI readjust route
					} elsif (
						$ataqArgs->{masterLastMoveTime} &&
						$ataqArgs->{masterLastMoveTime} != $char->{time_move}
					) {
						if (
							($slave->args->{masterLastMovePosTo}{x} == $char->{pos_to}{x} && $slave->args->{masterLastMovePosTo}{y} == $char->{pos_to}{y})
						) {
							$slave->args->{masterLastMoveTime} = $char->{time_move};
							$slave->args->{masterLastMovePosTo}{x} = $char->{pos_to}{x};
							$slave->args->{masterLastMovePosTo}{y} = $char->{pos_to}{y};
						} else {
							debug "$slave master $char has moved since we started routing to target $target - Adjusting route\n", 'slave_attack';
							$reset = 1;
						}
					}
					if ($reset) {
						$slave->dequeue while ($slave->is("move", "route"));
						$ataqArgs->{ai_attack_giveup}{time} = time;
						$ataqArgs->{sentApproach} = 0;
						undef $slave->args->{unstuck}{time};
						undef $slave->args->{avoiding};
						undef $slave->args->{move_start};
					}
				}
			
				$timeout{$slave->{ai_route_adjust_timeout}}{time} = time;
			}
		}

		if ($stage == ATTACKING) {
			if ($slave->args->{suspended}) {
				$slave->args->{ai_attack_giveup}{time} += time - $slave->args->{suspended};
				delete $slave->args->{suspended};
			
			# We've just finished moving to the monster.
			# Don't count the time we spent on moving
			} elsif ($slave->args->{move_start}) {
				$slave->args->{ai_attack_giveup}{time} += time - $slave->args->{move_start};
				undef $slave->args->{unstuck}{time};
				undef $slave->args->{move_start};

			} elsif ($slave->args->{avoiding}) {
				$slave->args->{ai_attack_giveup}{time} = time;
				undef $slave->args->{avoiding};
				debug "$slave finished avoiding movement from target $target, updating ai_attack_giveup\n", 'slave_attack';
			}

			if (timeOut($timeout{$slave->{ai_attack_main}})) {
				main($slave);
				$timeout{$slave->{ai_attack_main}}{time} = time;
			}
		}
	}
}

sub shouldAttack {
    my ($slave, $action, $args) = @_;
    return (
        ($slave->action eq "attack" && $slave->args->{ID}) ||
		($slave->action eq "route" && $slave->action (1) eq "attack" && $slave->args->{attackID}) ||
		($slave->action eq "move" && $slave->action (2) eq "attack" && $slave->args->{attackID})
    );
}

sub shouldGiveUp {
	my ($slave, $args, $ID) = @_;
	return !$config{$slave->{configPrefix}.'attackNoGiveup'} && (timeOut($args->{ai_attack_giveup}) || $args->{unstuck}{count} > 5)
}

sub giveUp {
	my ($slave, $args, $ID, $LOS) = @_;
	my $target = Actor::get($ID);
	if ($monsters{$ID}) {
		if ($LOS) {
			$target->{attack_failedLOS} = time;
		} else {
			$target->{$slave->{ai_attack_failed_timeout}} = time;
		}
	}
	$target->{dmgFromPlayer}{$slave->{ID}} = 0; # Hack | TODO: Fix me
	$slave->dequeue while ($slave->inQueue("attack"));
	message TF("%s can't reach or damage target, dropping target\n", $slave), 'slave_attack';
	if ($config{$slave->{configPrefix}.'teleportAuto_dropTarget'}) {
		message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
		ai_useTeleport(1);
	}
}

sub targetGone {
	my ($slave, $args, $ID) = @_;
	return !$monsters{$args->{ID}} && (!$players{$args->{ID}} || $players{$args->{ID}}{dead})
}

sub finishAttacking {
	my ($slave, $args, $ID) = @_;
	$timeout{$slave->{ai_attack_timeout}}{'time'} -= $timeout{$slave->{ai_attack_timeout}}{'timeout'};
	$slave->dequeue while ($slave->inQueue("attack"));

	if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
		message TF("%s target died\n", $slave), 'slave_attack';
		Plugins::callHook('slave_target_died', {
			ID => $ID,
			slave => $slave
		});
		monKilled();

		$slave->clientSuspend(0, $timeout{$slave->{ai_attack_waitAfterKill_timeout}}{'timeout'});

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

	} else {
		message TF("%s target lost\n", $slave), 'slave_attack';
	}

	Plugins::callHook('slave_attack_end', {
		ID => $ID,
		slave => $slave
	})
}

sub find_kite_position {
	my ($slave, $args, $inAdvance, $target, $realMyPos, $realMonsterPos, $noAttackMethodFallback_runFromTarget) = @_;
	
	my $maxDistance;
	if (!$noAttackMethodFallback_runFromTarget && defined $args->{attackMethod}{type} && defined $args->{attackMethod}{maxDistance}) {
		$maxDistance = $args->{attackMethod}{maxDistance};
	} elsif ($noAttackMethodFallback_runFromTarget) {
		$maxDistance = $config{$slave->{configPrefix}.'runFromTarget_noAttackMethodFallback_attackMaxDist'};
	} else {
		# Should never happen.
		return 0;
	}

	# We try to find a position to kite from at least runFromTarget_minStep away from the target but at maximun {attackMethod}{maxDistance} away from it
	my $pos = meetingPosition($slave, 2, $target, $maxDistance, ($noAttackMethodFallback_runFromTarget ? 2 : 1));
	if ($pos) {
		if ($inAdvance) {
			debug TF("[%s] [runFromTarget_inAdvance] kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} elsif ($noAttackMethodFallback_runFromTarget) {
			debug TF("[%s] [runFromTarget_noAttackMethodFallback] kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} else {
			debug TF("[%s] [runFromTarget] (attackmaxDistance %s) kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $maxDistance, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		}
		$args->{avoiding} = 1;
		$slave->route(
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
			debug TF("[%s] [runFromTarget_inAdvance] no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} elsif ($noAttackMethodFallback_runFromTarget) {
			debug TF("[%s] [runFromTarget_noAttackMethodFallback] no acceptable place to kite from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		} else {
			debug TF("[%s] [runFromTarget] no acceptable place to kite from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
		}
		return 0;
	}
}

sub main {
	my $slave = shift;
	# The attack sequence hasn't timed out and the monster is on screen

	# Update information about the monster and the current situation
	my $args = $slave->args;

	my $ID = $args->{ID};
	my $target = Actor::get($ID);
	my $myPos = $slave->{pos_to};
	my $monsterPos = $target->{pos_to};
	my $monsterDist = blockDistance($myPos, $monsterPos);

	my $realMyPos = calcPosFromPathfinding($field, $slave);
	my $realMonsterPos = calcPosFromPathfinding($field, $target);
	
	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);
	my $clientDist = getClientDist($realMyPos, $realMonsterPos);
	
	#my $realMasterPos = calcPosFromPathfinding($field, $char);
	#my $realMasterDistToSlave = blockDistance($realMasterPos, $realMyPos);
	#my $realMasterDistToTarget = blockDistance($realMasterPos, $realMonsterPos);
	
	if (!exists $args->{first_run}) {
		$args->{first_run} = 1;
	} elsif ($args->{first_run} == 1) {
		$args->{first_run} = 0;
	}
	
	#my $failed_to_attack_packet_recv = 0;
	
	if (!exists $args->{temporary_extra_range} || !defined $args->{temporary_extra_range}) {
		$args->{temporary_extra_range} = 0;
	}
	
	#if (exists $target->{movetoattack_pos} && exists $char->{movetoattack_pos}) {
	#	$failed_to_attack_packet_recv = 1;
	#	$args->{temporary_extra_range} = 0;
	#}

	# If the damage numbers have changed, update the giveup time so we don't timeout
	if ($args->{dmgToYou_last}   != $target->{dmgToPlayer}{$slave->{ID}}
	 || $args->{missedYou_last}  != $target->{missedToPlayer}{$slave->{ID}}
	 || $args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$slave->{ID}}) {
		$args->{ai_attack_giveup}{time} = time;
		debug "Update slave attack giveup time\n", 'slave_attack', 2;
	}
	
	my $hitYou = ($args->{dmgToYou_last} != $target->{dmgToPlayer}{$slave->{ID}} || $args->{missedYou_last} != $target->{missedToPlayer}{$slave->{ID}});
	my $youHitTarget = ($args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$slave->{ID}});
	
	# Hack - TODO: Fix me - If the homunculus dies trying to kill a monster and is resurrected still next to that monster it will think that it is still hitting the mob, this avoids that behaviour
	if ($youHitTarget && $args->{first_run}) {
		$youHitTarget = 0;
	}
	
	$args->{dmgToYou_last} = $target->{dmgToPlayer}{$slave->{ID}};
	$args->{missedYou_last} = $target->{missedToPlayer}{$slave->{ID}};
	$args->{dmgFromYou_last} = $target->{dmgFromPlayer}{$slave->{ID}};
	$args->{missedFromYou_last} = $target->{missedFromPlayer}{$slave->{ID}};
	
	delete $args->{attackMethod};
	# $target->{dmgFromPlayer}{$slave->{ID}} - $target->{dmgTo}
	# $target->{dmgFromPlayer}{$slave->{ID}} - $target->{dmgFromYou}
	
	### attackSkillSlot begin
	my $i = 0;
	while (exists $config{"attackSkillSlot_$i"}) {
		next unless (defined $config{"attackSkillSlot_$i"});

		my $skill = new Skill(auto => $config{"attackSkillSlot_$i"});
		next unless ($skill);
		next unless ($slave->checkSkillOwnership ($skill));

		next unless (checkSelfCondition("attackSkillSlot_$i"));
		next if $config{"attackSkillSlot_$i"."_maxUses"} && $target->{skillUses}{$skill->getHandle()} >= $config{"attackSkillSlot_$i"."_maxUses"};
		next unless (!$config{"attackSkillSlot_$i"."_maxAttempts"} || $args->{attackSkillSlot_attempts}{$i} < $config{"attackSkillSlot_$i"."_maxAttempts"});
		next unless (!$config{"attackSkillSlot_$i"."_monsters"} || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{'name'}) || existsInList($config{"attackSkillSlot_$i"."_monsters"}, $target->{nameID}));
		next unless (!$config{"attackSkillSlot_$i"."_notMonsters"} || !(existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{'name'}) || existsInList($config{"attackSkillSlot_$i"."_notMonsters"}, $target->{nameID})));
		next unless (!$config{"attackSkillSlot_$i"."_previousDamage"} || inRange($target->{dmgTo}, $config{"attackSkillSlot_$i"."_previousDamage"}));
		next unless (checkMonsterCondition("attackSkillSlot_$i"."_target", $target));

		$args->{attackMethod}{type} = "skill";
		$args->{attackMethod}{skillSlot} = $i;
		$args->{attackMethod}{distance} = $config{"attackSkillSlot_$i"."_dist"};
		$args->{attackMethod}{maxDistance} = $config{"attackSkillSlot_$i"."_maxDist"} || $config{"attackSkillSlot_$i"."_dist"};
		last;
	} continue {
		$i++;
	}
	### attackSkillSlot end
	
	if (!$args->{attackMethod}{type}) {
		if ($config{$slave->{configPrefix}.'attackUseWeapon'}) {
			$args->{attackMethod}{type} = "weapon";
			$args->{attackMethod}{distance} = $config{$slave->{configPrefix}.'attackDistance'};
			$args->{attackMethod}{maxDistance} = $config{$slave->{configPrefix}.'attackMaxDistance'};
		} else {
			undef $args->{attackMethod}{type};
			$args->{attackMethod}{distance} = 1;
			$args->{attackMethod}{maxDistance} = 1;
		}
	}
	
	if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
		$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
	}

	if (defined $args->{attackMethod}{type} && exists $args->{ai_attack_failed_give_up} && defined $args->{ai_attack_failed_give_up}{time}) {
		debug "[Slave $slave] Deleting ai_attack_failed_give_up time.\n";
		delete $args->{ai_attack_failed_give_up}{time};
		
	}
	
	#$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};
	
	# -2: undefined attackMethod
	# -1: No LOS
	#  0: out of range
	#  1: sucess
	my $canAttack = -2;
	if (defined $args->{attackMethod}{type} && defined $args->{attackMethod}{maxDistance}) {
		$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{$slave->{configPrefix}.'attackCanSnipe'}, $args->{attackMethod}{maxDistance}, $config{clientSight});
	} else {
		$canAttack = -2;
	}

	my $canAttack_fail_string = (($canAttack == -2) ? "No Method" : (($canAttack == -1) ? "No LOS" : (($canAttack == 0) ? "No Range" : "OK")));
	
	# Here we check if the monster which we are waiting to get closer to us is in fact close enough
	# If it is close enough delete the ai_attack_failed_waitForAgressive_give_up keys and loop attack logic
	if (
		   $config{$slave->{configPrefix}."attackBeyondMaxDistance_waitForAgressive"}
		&& $target->{dmgFromPlayer}{$slave->{ID}} > 0
		&& $canAttack == 1
		&& exists $args->{ai_attack_failed_waitForAgressive_give_up}
		&& defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "[Slave $slave] Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
	}
	
	# Here we check if we have finished moving to the meeting position to attack our target, only checks this if attackWaitApproachFinish is set to 1 in config
	# If so sets sentApproach to 0
	if (
		$config{$slave->{configPrefix}."attackWaitApproachFinish"} &&
		($canAttack == 0 || $canAttack == -1) &&
		$args->{sentApproach}
	) {
		if (!timeOut($slave->{time_move}, $slave->{time_move_calc})) {
			debug TF("[Slave] [Out of Range - Still Approaching - Waiting] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d.\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}), 'ai_attack';
			return;
		} else {
			debug TF("[Slave] [Out of Range - Ended Approaching] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d.\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}), 'ai_attack';
			$args->{sentApproach} = 0;
		}
	}
	
	my $found_action = 0;
	my $failed_runFromTarget = 0;
	my $hitTarget_when_not_possible = 0;

	# Here, if runFromTarget is active, we check if the target mob is closer to us than the minimun distance specified in runFromTarget_dist
	# If so try to kite it
	if (
		!$found_action &&
		$config{$slave->{configPrefix}."runFromTarget"} &&
		$realMonsterDist < $config{$slave->{configPrefix}."runFromTarget_dist"}
	) {
		my $try_runFromTarget = find_kite_position($slave, $args, 0, $target, $realMyPos, $realMonsterPos, 0);
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
		$config{$slave->{configPrefix}."runFromTarget_noAttackMethodFallback"} &&
		$realMonsterDist < $config{$slave->{configPrefix}."runFromTarget_noAttackMethodFallback_minStep"}
	) {
		my $try_runFromTarget = find_kite_position($slave, $args, 0, $target, $realMyPos, $realMonsterPos, 1);
		if ($try_runFromTarget) {
			$found_action = 1;
		}
	}

	if (
		!$found_action &&
		$canAttack  == -2
	) {
		debug T("[Slave $slave] Can't determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), "ai_attack";
		$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
		$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
		if (timeOut($args->{ai_attack_failed_give_up})) {
			delete $args->{ai_attack_failed_give_up}{time};
			warning T("[$slave] Unable to determine a attackMethod (check attackUseWeapon and Skills blocks), dropping target.\n"), "ai_attack";
			$found_action = 1;
			giveUp($args, $ID, 0);
		}
	}
	
	if ($canAttack == 0 && $youHitTarget) {
		debug TF("[%s] [%s] We were able to hit target even though it is out of range or LOS, accepting and continuing. (you (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d)\n", $slave, $canAttack_fail_string, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}), 'ai_attack';
		if ($clientDist > $args->{attackMethod}{maxDistance} && $clientDist <= ($args->{attackMethod}{maxDistance} + 1) && $args->{temporary_extra_range} == 0) {
			debug TF("[$canAttack_fail_string] Probably extra range provided by the server due to chasing, increasing range by 1.\n"), 'ai_attack';
			$args->{temporary_extra_range} = 1;
			$args->{attackMethod}{maxDistance} += $args->{temporary_extra_range};
			$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{$slave->{configPrefix}."attackCanSnipe"}, $args->{attackMethod}{maxDistance}, $config{clientSight});
		} else {
			debug TF("[%s] [%s] Reason unknown, allowing once.\n", $slave, $canAttack_fail_string), 'ai_attack';
			$hitTarget_when_not_possible = 1;
		}
		if (
			$config{$slave->{configPrefix}."attackBeyondMaxDistance_waitForAgressive"} &&
			exists $args->{ai_attack_failed_waitForAgressive_give_up} &&
			defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
		) {
			debug TF("[%s] [Accepting] Deleting ai_attack_failed_waitForAgressive_give_up time.\n", $slave), 'ai_attack';
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};;
		}
	}
	
	# Here we decide what to do when a mob we have already hit is no longer in range or we have no LOS to it
	# We also check if we have waited too long for the monster which we are waiting to get closer to us to approach
	# TODO: Maybe we should separate this into 2 sections, one for out of range and another for no LOS - low priority
	if (
		!$found_action &&
		$config{$slave->{configPrefix}."attackBeyondMaxDistance_waitForAgressive"} &&
		$target->{dmgFromPlayer}{$slave->{ID}} > 0 &&
		($canAttack == 0 || $canAttack == -1) &&
		!$hitTarget_when_not_possible
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};
		if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
			warning TF("[%s] [%s] Waited too long for target to get closer, dropping target. (you (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d)\n", $slave, $canAttack_fail_string, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}), 'ai_attack';
			giveUp($slave, $args, $ID, 0);
		} else {
			$slave->sendAttack($ID) if ($config{$slave->{configPrefix}."attackBeyondMaxDistance_sendAttackWhileWaiting"});
			debug TF("[%s] [%s] [Waiting] (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d.\n", $slave, $canAttack_fail_string, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}), 'ai_attack';
		}
		$found_action = 1;
	}

	# Here we decide what to do with a mob which is out of range or we have no LOS to
	if (
		!$found_action &&
		($canAttack == 0 || $canAttack == -1) &&
		!$hitTarget_when_not_possible
	) {
		debug "Attack $slave ($realMyPos->{x} $realMyPos->{y}) - target $target ($realMonsterPos->{x} $realMonsterPos->{y})\n";
		if ($canAttack == 0) {
			debug "[Slave $slave] [Attack] [No range] Too far from us to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';

		} elsif ($canAttack == -1) {
			debug "[Slave $slave] [Attack] [No LOS] No LOS from player to mob\n", 'ai_attack';
		}

		my $pos = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance});
		if ($pos) {
			debug "Attack $slave ($realMyPos->{x} $realMyPos->{y}) - moving to meeting position ($pos->{x} $pos->{y})\n", 'ai_attack';

			$args->{move_start} = time;
			$args->{monsterLastMoveTime} = $target->{time_move};
			$args->{monsterLastMovePosTo}{x} = $target->{pos_to}{x};
			$args->{monsterLastMovePosTo}{y} = $target->{pos_to}{y};
			
			$args->{masterLastMoveTime} = $char->{time_move};
			$args->{masterLastMovePosTo}{x} = $char->{pos_to}{x};
			$args->{masterLastMovePosTo}{y} = $char->{pos_to}{y};
			$args->{sentApproach} = 1;

			my $sendAttackWithMove = 0;
			if ($config{$slave->{configPrefix}."attackSendAttackWithMove"} && $args->{attackMethod}{type} eq "weapon") {
				$sendAttackWithMove = 1;
			}
			
			$slave->route(
				undef,
				@{$pos}{qw(x y)},
				maxRouteTime => $config{$slave->{configPrefix}.'attackMaxRouteTime'},
				attackID => $ID,
				sendAttackWithMove => $sendAttackWithMove,
				avoidWalls => 0,
				randomFactor => 0,
				useManhattan => 1,
				meetingSubRoute => 1,
				noMapRoute => 1
			);
		} else {
			message T("[Slave $slave] Unable to calculate a meetingPosition to target, dropping target\n"), "ai_attack";
			giveUp($slave, $args, $ID, 1);
		}
		$found_action = 1;
	}

	if (
		!$found_action &&
		(!$config{$slave->{configPrefix}."runFromTarget"} || $realMonsterDist >= $config{$slave->{configPrefix}."runFromTarget_dist"} || $failed_runFromTarget) &&
		(!$config{$slave->{configPrefix}."tankMode"} || !$target->{dmgFromPlayer}{$slave->{ID}})
	 ) {
		# Attack the target. In case of tanking, only attack if it hasn't been hit once.
		if (!$args->{firstAttack}) {
			$args->{firstAttack} = 1;
			debug "[Slave $slave] Ready to attack target $target ($realMonsterPos->{x} $realMonsterPos->{y}) ($realMonsterDist blocks away); we're at ($realMyPos->{x} $realMyPos->{y})\n", "ai_attack";
		}

		$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
		if (!$target->{dmgFromPlayer}{$slave->{ID}} && timeOut($args->{unstuck})) {
			# We are close enough to the target, and we're trying to attack it,
			# but some time has passed and we still haven't dealed any damage.
			# Our recorded position might be out of sync, so try to unstuck
			$args->{unstuck}{time} = time;
			debug("$slave attack - trying to unstuck\n", 'slave_attack');
			$slave->move($myPos->{x}, $myPos->{y});
			$args->{unstuck}{count}++;
		}

		if ($args->{attackMethod}{type} eq "weapon") {
			if ($config{$slave->{configPrefix}.'attack_dance_melee'}) {
				if (timeOut($timeout{$slave->{ai_dance_attack_melee_timeout}})) {
					my $cell = get_dance_position($slave, $target);
					debug TF("Slave %s will dance type %d from (%d, %d) to (%d, %d), target %s at (%d, %d).\n", $slave, $config{$slave->{configPrefix}.'attack_dance_melee'}, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y});
					$slave->sendMove ($cell->{x}, $cell->{y});
					$slave->sendMove ($realMyPos->{x},$realMyPos->{y});
					$slave->sendAttack ($ID);
					$timeout{$slave->{ai_dance_attack_melee_timeout}}{time} = time;
				}
				
			} elsif ($config{$slave->{configPrefix}.'attack_dance_ranged'}) {
				if (timeOut($timeout{$slave->{ai_dance_attack_ranged_timeout}})) {
					my $cell = get_dance_position($slave, $target);
					debug TF("Slave %s will range dance type %d from (%d, %d) to (%d, %d), target %s at (%d, %d).\n", $slave, $config{$slave->{configPrefix}.'attack_dance_ranged'}, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y});
					$slave->sendMove ($cell->{x}, $cell->{y});
					$slave->sendMove ($realMyPos->{x},$realMyPos->{y});
					$slave->sendAttack ($ID);
					$timeout{$slave->{ai_dance_attack_ranged_timeout}}{time} = time;
					
					if ($config{$slave->{configPrefix}."runFromTarget"} && $config{$slave->{configPrefix}."runFromTarget_inAdvance"} && $realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_minStep'}) {
						find_kite_position($slave, $args, 1, $target, $realMyPos, $realMonsterPos, 0);
					}
				}

			} else {
				if (timeOut($timeout{$slave->{ai_attack_timeout}})) {
					$slave->sendAttack ($ID);
					$timeout{$slave->{ai_attack_timeout}}{time} = time;
					
					if ($config{$slave->{configPrefix}."runFromTarget"} && $config{$slave->{configPrefix}."runFromTarget_inAdvance"} && $realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_minStep'}) {
						find_kite_position($slave, $args, 1, $target, $realMyPos, $realMonsterPos, 0);
					}
				}
			}
			delete $args->{attackMethod};
			$found_action = 1;
		
		# Attack with skill logic
		} elsif ($args->{attackMethod}{type} eq "skill") {
			my $slot = $args->{attackMethod}{skillSlot};
			delete $args->{attackMethod};

			$ai_v{"attackSkillSlot_${slot}_time"} = time;
			$ai_v{"attackSkillSlot_${slot}_target_time"}{$ID} = time;
			
			$args->{attackSkillSlot_attempts}{$i}++;

			ai_setSuspend(0);
			my $skill = new Skill(auto => $config{"attackSkillSlot_$slot"});
			my $skill_lvl = $config{"attackSkillSlot_${slot}_lvl"};# || $char->getSkillLevel($skill);?
			ai_skillUse2(
				$skill,
				$skill_lvl,
				$config{"attackSkillSlot_${slot}_maxCastTime"},
				$config{"attackSkillSlot_${slot}_minCastTime"},
				$config{"attackSkillSlot_${slot}_isSelfSkill"} ? $slave : $target,
				"attackSkillSlot_${slot}",
				undef,
				"attackSkill",
				$config{"attackSkillSlot_${slot}_isStartSkill"} ? 1 : 0,
			);

			debug "[Slave $slave] [attackSkillSlot] Auto-skill on monster ".getActorName($ID).": ".qq~$config{"attackSkillSlot_$slot"} (lvl $skill_lvl)\n~, "ai_attack";
			# TODO: We sould probably add a runFromTarget_inAdvance logic here also, we could want to kite using skills, but only instant cast ones like double strafe I believe
			
			$args->{monsterID} = $ID;
			$found_action = 1;
		}

	}
	
	if ($config{$slave->{configPrefix}.'tankMode'}) {
		if ($args->{'dmgTo_last'} != $target->{dmgFromPlayer}{$slave->{ID}}) {
			$args->{'ai_attack_giveup'}{'time'} = time;
			$slave->sendAttackStop;
		}
		$args->{'dmgTo_last'} = $target->{dmgFromPlayer}{$slave->{ID}};
		$found_action = 1;
	}
}

1;
