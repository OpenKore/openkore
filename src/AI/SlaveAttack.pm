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

use AI::Slave;
use AI::Slave::Homunculus;
use AI::Slave::Mercenary;


##### ATTACK #####
sub process {
	my $slave = shift;

	if (
		   ($slave->action eq "attack" && $slave->args->{ID})
		|| ($slave->action eq "route" && $slave->action (1) eq "attack" && $slave->args->{attackID})
		|| ($slave->action eq "move" && $slave->action (2) eq "attack" && $slave->args->{attackID})
	) {
		my $ID;
		my $ataqArgs;
		if ($slave->action eq "attack") {
			$ID = $slave->args->{ID};
			$ataqArgs = $slave->args(0);
		} else {
			if ($slave->action(1) eq "attack") {
				$ataqArgs = $slave->args(1);

			} elsif ($slave->action(2) eq "attack") {
				$ataqArgs = $slave->args(2);
			}
			$ID = $slave->args->{attackID};
		}

		if (targetGone($slave, $ataqArgs, $ID)) {
			finishAttacking($slave, $ataqArgs, $ID);
			return;
		} elsif (shouldGiveUp($slave, $ataqArgs, $ID)) {
			giveUp($slave, $ataqArgs, $ID);
			return;
		}

		my $target = Actor::get($ID);
		if ($target) {
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
		}
	}

	if ($slave->action eq "attack" && $slave->args->{suspended}) {
		$slave->args->{ai_attack_giveup}{time} += time - $slave->args->{suspended};
		delete $slave->args->{suspended};
	}

	if ($slave->action eq "attack" && $slave->args->{move_start}) {
		# We've just finished moving to the monster.
		# Don't count the time we spent on moving
		$slave->args->{ai_attack_giveup}{time} += time - $slave->args->{move_start};
		undef $slave->args->{unstuck}{time};
		undef $slave->args->{move_start};

	} elsif ($slave->action eq "attack" && $slave->args->{avoiding} && $slave->args->{ID}) {
		my $ID = $slave->args->{ID};
		my $target = Actor::get($ID);
		$slave->args->{ai_attack_giveup}{time} = time;
		undef $slave->args->{avoiding};
		debug "$slave finished avoiding movement from target $target, updating ai_attack_giveup\n", 'slave_attack';

	} elsif ((($slave->action eq "route" && $slave->action (1) eq "attack") || ($slave->action eq "move" && $slave->action (2) eq "attack"))
	   && $slave->args->{attackID} && timeOut($timeout{$slave->{ai_route_adjust_timeout}})) {
		# We're on route to the monster; check whether the monster has moved
		my $ID = $slave->args->{attackID};
		my $attackSeq = ($slave->action eq "route") ? $slave->args (1) : $slave->args (2);
		my $target = Actor::get($ID);
		my $realMyPos = calcPosition($slave);
		my $realMonsterPos = calcPosition($target);

		if (
			$target->{type} ne 'Unknown' &&
			$attackSeq->{monsterPos} &&
			%{$attackSeq->{monsterPos}} &&
			$attackSeq->{monsterLastMoveTime} &&
			$attackSeq->{monsterLastMoveTime} != $target->{time_move}
		) {
			# Monster has moved; stop moving and let the attack AI readjust route
			debug "$slave target $target has moved since we started routing to it - Adjusting route\n", 'slave_attack';
			$slave->dequeue while ($slave->is("move", "route"));

			$attackSeq->{ai_attack_giveup}{time} = time;

		} elsif (
			$target->{type} ne 'Unknown' &&
			$attackSeq->{monsterPos} &&
			%{$attackSeq->{monsterPos}} &&
			$attackSeq->{monsterLastMoveTime} &&
			$attackSeq->{attackMethod}{maxDistance} == 1 &&
			canReachMeleeAttack($realMyPos, $realMonsterPos) &&
			(blockDistance($realMyPos, $realMonsterPos) < 2 || !$config{$slave->{configPrefix}.'attackCheckLOS'} ||($config{$slave->{configPrefix}.'attackCheckLOS'} && blockDistance($realMyPos, $realMonsterPos) == 2 && $field->checkLOS($realMyPos, $realMonsterPos, $config{$slave->{configPrefix}.'attackCanSnipe'})))
		) {
			debug "$slave target $target is now reachable by melee attacks during routing to it.\n", 'slave_attack';
			$slave->dequeue while ($slave->is("move", "route"));

			$attackSeq->{ai_attack_giveup}{time} = time;
		}

		$timeout{$slave->{ai_route_adjust_timeout}}{time} = time;
	}

	if ($slave->action eq "attack" && timeOut($slave->args->{attackMainTimeout}, 0.1)) {
		$slave->args->{attackMainTimeout} = time;
		main($slave);
	}

	# Check for kill steal while moving
	if (($slave->is("move", "route") && $slave->args->{attackID} && $slave->inQueue("attack")
		&& timeOut($slave->args->{movingWhileAttackingTimeout}, 0.2))) {

		my $ID = $slave->args->{attackID};
		my $monster = $monsters{$ID};

		# Check for kill steal while moving
		if ($monster && !Misc::slave_checkMonsterCleanness($slave, $ID)) {
			dropTargetWhileMoving($slave);
		}

		$slave->args->{movingWhileAttackingTimeout} = time;
	}
}

sub shouldGiveUp {
	my ($slave, $args, $ID) = @_;
	return !$config{$slave->{configPrefix}.'attackNoGiveup'} && (timeOut($args->{ai_attack_giveup}) || $args->{unstuck}{count} > 5)
}

sub giveUp {
	my ($slave, $args, $ID) = @_;
	my $target = Actor::get($ID);
	$target->{$slave->{ai_attack_failed_timeout}} = time if $monsters{$ID};
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

		# Pickup loot when monster's dead
		if (AI::state == AI::AUTO && $config{itemsTakeAuto} && $monsters_old{$ID}{dmgFromPlayer}{$slave->{ID}} > 0 && !$monsters_old{$ID}{slave_ignore}) {
			AI::clear("items_take");
			AI::ai_items_take($monsters_old{$ID}{pos}{x}, $monsters_old{$ID}{pos}{y},
				$monsters_old{$ID}{pos_to}{x}, $monsters_old{$ID}{pos_to}{y});
		} elsif ($timeout{$slave->{ai_attack_waitAfterKill_timeout}}{'timeout'} > 0) {
			# Cheap way to suspend all movement to make it look real
			$slave->clientSuspend(0, $timeout{$slave->{ai_attack_waitAfterKill_timeout}}{'timeout'});
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

	} else {
		message TF("%s target lost\n", $slave), 'slave_attack';
	}

	Plugins::callHook('slave_attack_end', {
		ID => $ID,
		slave => $slave
	})

}

sub dropTargetWhileMoving {
	my $slave = shift;
	my $ID = $slave->args->{attackID};
	my $target = Actor::get($ID);
	message TF("%s dropping target %s - will not kill steal others\n", $slave, $target), 'slave_attack';
	$slave->sendAttackStop;
	$target->{slave_ignore} = 1;

	# Right now, the queue is either
	#   move, route, attack
	# -or-
	#   route, attack
	$slave->dequeue while ($slave->inQueue("attack"));
	if ($config{$slave->{configPrefix}.'teleportAuto_dropTargetKS'}) {
		message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
		ai_useTeleport(1);
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

	my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou);
	my $realMyPos = calcPosition($slave);
	my $realMonsterPos = calcPosition($target);
	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);

	my $cleanMonster = slave_checkMonsterCleanness($slave, $ID);


	# If the damage numbers have changed, update the giveup time so we don't timeout
	if ($args->{dmgToYou_last}   != $target->{dmgToPlayer}{$slave->{ID}}
	 || $args->{missedYou_last}  != $target->{missedToPlayer}{$slave->{ID}}
	 || $args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$slave->{ID}}) {
		$args->{ai_attack_giveup}{time} = time;
		debug "Update slave attack giveup time\n", 'slave_attack', 2;
	}
	$hitYou = ($args->{dmgToYou_last} != $target->{dmgToPlayer}{$slave->{ID}}
		|| $args->{missedYou_last} != $target->{missedToPlayer}{$slave->{ID}});
	$args->{dmgToYou_last} = $target->{dmgToPlayer}{$slave->{ID}};
	$args->{missedYou_last} = $target->{missedToPlayer}{$slave->{ID}};
	$args->{dmgFromYou_last} = $target->{dmgFromPlayer}{$slave->{ID}};
	$args->{missedFromYou_last} = $target->{missedFromPlayer}{$slave->{ID}};

	$args->{attackMethod}{type} = "weapon";

	### attackSkillSlot begin
	for (my ($i, $prefix) = (0, 'attackSkillSlot_0'); $prefix = "attackSkillSlot_$i" and exists $config{$prefix}; $i++) {
		next unless $config{$prefix};
		if (checkSelfCondition($prefix) && checkMonsterCondition("${prefix}_target", $target)) {
			my $skill = new Skill(auto => $config{$prefix});
			next unless $slave->checkSkillOwnership ($skill);

			next if $config{"${prefix}_maxUses"} && $target->{skillUses}{$skill->getHandle()} >= $config{"${prefix}_maxUses"};
			next if $config{"${prefix}_target"} && !existsInList($config{"${prefix}_target"}, $target->{name});

			# Donno if $char->getSkillLevel is the right place to look at.
			# my $lvl = $config{"${prefix}_lvl"} || $char->getSkillLevel($party_skill{skillObject});
			my $lvl = $config{"${prefix}_lvl"};
			my $maxCastTime = $config{"${prefix}_maxCastTime"};
			my $minCastTime = $config{"${prefix}_minCastTime"};
			debug "Slave attackSkillSlot on $target->{name} ($target->{binID}): ".$skill->getName()." (lvl $lvl)\n", "monsterSkill";
			my $skillTarget = $config{"${prefix}_isSelfSkill"} ? $slave : $target;
			AI::ai_skillUse2($skill, $lvl, $maxCastTime, $minCastTime, $skillTarget, $prefix);
			$ai_v{$prefix . "_time"} = time;
			$ai_v{$prefix . "_target_time"}{$ID} = time;
			last;
		}
	}
	### attackSkillSlot end

	$args->{attackMethod}{maxDistance} = $config{$slave->{configPrefix}.'attackMaxDistance'};
	$args->{attackMethod}{distance} = ($config{$slave->{configPrefix}.'runFromTarget'} && $config{$slave->{configPrefix}.'runFromTarget_dist'} > $config{$slave->{configPrefix}.'attackDistance'}) ? $config{$slave->{configPrefix}.'runFromTarget_dist'} : $config{$slave->{configPrefix}.'attackDistance'};
	if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
		$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
	}

	if (defined $args->{attackMethod}{type} && exists $args->{ai_attack_failed_give_up} && defined $args->{ai_attack_failed_give_up}{time}) {
		delete $args->{ai_attack_failed_give_up}{time};
	}

	if (!$cleanMonster) {
		# Drop target if it's already attacked by someone else
		$target->{$slave->{ai_attack_failed_timeout}} = time if $monsters{$ID};
		message TF("%s dropping target %s - will not kill steal others\n", $slave, $target), 'slave_attack';
		$slave->sendMove ($realMyPos->{x}, $realMyPos->{y});
		$slave->dequeue while ($slave->inQueue("attack"));
		if ($config{$slave->{configPrefix}.'teleportAuto_dropTargetKS'}) {
			message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
			ai_useTeleport(1);
		}

	} elsif ($config{$slave->{configPrefix}.'runFromTarget'} && ($realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_dist'} || $hitYou)) {
		my $cell = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance}, 1);
		if ($cell) {
			debug TF("[runFromTarget] %s kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
			$slave->args->{avoiding} = 1;
			$slave->route(undef, @{$cell}{qw(x y)}, noMapRoute => 1, avoidWalls => 0, runFromTarget => 1);
		} else {
			debug TF("%s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
		}

		if (!$cell) {
			my $max = $args->{attackMethod}{maxDistance} + 4;
			if ($max > 14) {
				$max = 14;
			}
			$cell = meetingPosition($slave, 2, $target, $max, 1);
			if ($cell) {
				debug TF("[runFromTarget] %s kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
				$args->{avoiding} = 1;
				$slave->route(undef, @{$cell}{qw(x y)}, noMapRoute => 1, avoidWalls => 0, runFromTarget => 1);
			} else {
				debug TF("%s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
			}
		}


	} elsif(!defined $args->{attackMethod}{type}) {
		debug T("Can't determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), 'slave_attack';
		$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
		$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
		if (timeOut($args->{ai_attack_failed_give_up})) {
			delete $args->{ai_attack_failed_give_up}{time};
			message T("$slave unable to determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), 'slave_attack';
			giveUp($slave, $args, $ID);
		}


	} elsif (
		# We are out of range, but already hit enemy, should wait for him in a safe place instead of going after him
		# Example at https://youtu.be/kTRk5Na1aCQ?t=25 in which this check did not exist, we tried getting closer intead of waiting and got hit
		($args->{attackMethod}{maxDistance} > 1 && $realMonsterDist > $args->{attackMethod}{maxDistance}) &&
		#(!$config{$slave->{configPrefix}.'attackCheckLOS'} || $field->checkLOS($realMyPos, $realMonsterPos, $config{$slave->{configPrefix}.'attackCanSnipe'})) && # Is this check needed?
		$config{$slave->{configPrefix}."attackBeyondMaxDistance_waitForAgressive"} &&
		$target->{dmgFromPlayer}{$slave->{ID}} > 0
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};

		if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
			delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
			message T("[Out of Range] $slave waited too long for target to get closer, dropping target\n"), 'slave_attack';
			giveUp($slave, $args, $ID);
		} else {
			warning TF("[Out of Range - Waiting] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromPlayer}{$slave->{ID}}), 'slave_attack';
		}

	} elsif (
		# We are out of range
		($args->{attackMethod}{maxDistance} == 1 && !canReachMeleeAttack($realMyPos, $realMonsterPos)) ||
		($args->{attackMethod}{maxDistance} > 1 && $realMonsterDist > $args->{attackMethod}{maxDistance})
	) {
		# The target monster moved; move to target
		$args->{move_start} = time;
		$args->{monsterPos} = {%{$monsterPos}};
		$args->{monsterLastMoveTime} = $target->{time_move};

		debug "$slave target $target ($realMonsterPos->{x} $realMonsterPos->{y}) is too far from slave ($realMyPos->{x} $realMyPos->{y}) to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'slave_attack';

		my $pos = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance});
		my $result;

		if ($pos) {
			debug "Attack $slave ($realMyPos->{x} $realMyPos->{y}) - moving to meeting position ($pos->{x} $pos->{y})\n", 'slave_attack';

			$result = $slave->route(
				undef,
				@{$pos}{qw(x y)},
				maxRouteTime => $config{$slave->{configPrefix}.'attackMaxRouteTime'},
				attackID => $ID,
				avoidWalls => 0,
				meetingSubRoute => 1,
				noMapRoute => 1
			);

			if (!$result) {
				# Unable to calculate a route to target
				$target->{$slave->{ai_attack_failed_timeout}} = time;
				$slave->dequeue while ($slave->inQueue("attack"));
				message TF("Unable to calculate a route to %s target, dropping target\n", $slave), 'slave_attack';
				if ($config{$slave->{configPrefix}.'teleportAuto_dropTarget'}) {
					message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
					ai_useTeleport(1);
				} else {
					debug "Attack $slave - successufully routing to $target\n", 'attack';
				}
			}
		} else {
			$target->{$slave->{ai_attack_failed_timeout}} = time;
			$slave->dequeue while ($slave->inQueue("attack"));
			message T("Unable to calculate a meetingPosition to target, dropping target\n"), 'slave_attack';
			if ($config{$slave->{configPrefix}.'teleportAuto_dropTarget'}) {
				message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
				ai_useTeleport(1);
			}
		}

	} elsif (
		# We are a ranged attacker in range without LOS
		$args->{attackMethod}{maxDistance} > 1 &&
		$config{$slave->{configPrefix}.'attackCheckLOS'} &&
		!$field->checkLOS($realMyPos, $realMonsterPos, $config{$slave->{configPrefix}.'attackCanSnipe'})
	) {
		my $best_spot = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance});

		# Move to the closest spot
		my $msg = TF("%s has no LOS from (%d, %d) to target %s (%d, %d) (distance: %d)", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist);
		if ($best_spot) {
			message TF("%s; moving to (%d, %d)\n", $msg, $best_spot->{x}, $best_spot->{y}), 'slave_attack';
			$slave->route(undef, @{$best_spot}{qw(x y)}, noMapRoute => 1, avoidWalls => 0, LOSSubRoute => 1);
		} else {
			$target->{attack_failedLOS} = time;
			warning TF("%s; no acceptable place to stand\n", $msg);
			$slave->dequeue while ($slave->inQueue("attack"));
		}

	} elsif (
		# We are a melee attacker in range without LOS
		$args->{attackMethod}{maxDistance} == 1 &&
		$config{$slave->{configPrefix}.'attackCheckLOS'} &&
		blockDistance($realMyPos, $realMonsterPos) == 2 &&
		!$field->checkLOS($realMyPos, $realMonsterPos, $config{$slave->{configPrefix}.'attackCanSnipe'})
	) {
		my $best_spot = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance});

		# Move to the closest spot
		my $msg = TF("%s has no LOS in melee from (%d, %d) to target %s (%d, %d) (distance: %d)", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist);
		if ($best_spot) {
			message TF("%s; moving to (%d, %d)\n", $msg, $best_spot->{x}, $best_spot->{y}), 'slave_attack';
			$slave->route(undef, @{$best_spot}{qw(x y)}, noMapRoute => 1, avoidWalls => 0, LOSSubRoute => 1);
		} else {
			$target->{attack_failedLOS} = time;
			warning TF("%s; no acceptable place to stand\n", $msg);
			$slave->dequeue while ($slave->inQueue("attack"));
		}

	} elsif ((!$config{$slave->{configPrefix}.'runFromTarget'} || $realMonsterDist >= $config{$slave->{configPrefix}.'runFromTarget_dist'})
	 && (!$config{$slave->{configPrefix}.'tankMode'} || !$target->{dmgFromPlayer}{$slave->{ID}})) {
		# Attack the target. In case of tanking, only attack if it hasn't been hit once.
		if (!$slave->args->{firstAttack}) {
			$slave->args->{firstAttack} = 1;
			my $pos = "$myPos->{x},$myPos->{y}";
			debug "$slave is ready to attack target $target (which is $realMonsterDist blocks away); we're at ($pos)\n", 'slave_attack';
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
			if ($config{$slave->{configPrefix}.'attack_dance_melee'} && $args->{attackMethod}{distance} == 1) {
				if (timeOut($timeout{$slave->{ai_dance_attack_melee_timeout}})) {
					my $cell = get_dance_position($slave, $target);
					debug TF("Slave %s will dance type %d from (%d, %d) to (%d, %d), target %s at (%d, %d).\n", $slave, $config{$slave->{configPrefix}.'attack_dance_melee'}, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y});
					$slave->sendMove ($cell->{x}, $cell->{y});
					$slave->sendMove ($realMyPos->{x},$realMyPos->{y});
					$slave->sendAttack ($ID);
					$timeout{$slave->{ai_dance_attack_melee_timeout}}{time} = time;
				}

			} elsif ($config{$slave->{configPrefix}.'attack_dance_ranged'} && $args->{attackMethod}{distance} > 2) {
				if (timeOut($timeout{$slave->{ai_dance_attack_ranged_timeout}})) {
					my $cell = get_dance_position($slave, $target);
					debug TF("Slave %s will range dance type %d from (%d, %d) to (%d, %d), target %s at (%d, %d).\n", $slave, $config{$slave->{configPrefix}.'attack_dance_ranged'}, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y});
					$slave->sendMove ($cell->{x}, $cell->{y});
					$slave->sendMove ($realMyPos->{x},$realMyPos->{y});
					$slave->sendAttack ($ID);
					if ($config{$slave->{configPrefix}.'runFromTarget'} && $config{$slave->{configPrefix}.'runFromTarget_inAdvance'} && $realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_minStep'}) {
						my $cell = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance}, 1);
						if ($cell) {
							debug TF("%s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
							$args->{avoiding} = 1;
							$slave->sendMove($cell->{x}, $cell->{y});
						} else {
							debug TF("%s no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
						}
					}
					$timeout{$slave->{ai_dance_attack_ranged_timeout}}{time} = time;
				}

			} else {
				if (timeOut($timeout{$slave->{ai_attack_timeout}})) {
					$slave->sendAttack ($ID);
					if ($config{$slave->{configPrefix}.'runFromTarget'} && $config{$slave->{configPrefix}.'runFromTarget_inAdvance'} && $realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_minStep'}) {
						my $cell = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance}, 1);
						if ($cell) {
							debug TF("%s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
							$args->{avoiding} = 1;
							$slave->sendMove($cell->{x}, $cell->{y});
						} else {
							debug TF("%s no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave_attack';
						}
					}
					$timeout{$slave->{ai_attack_timeout}}{time} = time;
				}
			}
			delete $args->{attackMethod};
		}

	} elsif ($config{$slave->{configPrefix}.'tankMode'}) {
		if ($args->{'dmgTo_last'} != $target->{dmgFromPlayer}{$slave->{ID}}) {
			$args->{'ai_attack_giveup'}{'time'} = time;
			$slave->sendAttackStop;
		}
		$args->{'dmgTo_last'} = $target->{dmgFromPlayer}{$slave->{ID}};
	}
}

1;
