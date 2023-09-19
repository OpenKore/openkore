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
			giveUp($slave, $ataqArgs, $ID, 0);
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
		
		if ($target->{type} ne 'Unknown') {
			if (
				$attackSeq->{monsterLastMoveTime} &&
				$attackSeq->{monsterLastMoveTime} != $target->{time_move}
			) {
				# Monster has moved; stop moving and let the attack AI readjust route
				warning "$slave target $target has moved since we started routing to it - Adjusting route\n", 'slave_attack';
				$slave->dequeue while ($slave->is("move", "route"));

				$attackSeq->{ai_attack_giveup}{time} = time;
				$attackSeq->{needReajust} = 1;

			} elsif (
				$attackSeq->{masterLastMoveTime} &&
				$attackSeq->{masterLastMoveTime} != $char->{time_move}
			) {
				# Master has moved; stop moving and let the attack AI readjust route
				warning "$slave master $char has moved since we started routing to target $target - Adjusting route\n", 'slave_attack';
				$slave->dequeue while ($slave->is("move", "route"));

				$attackSeq->{ai_attack_giveup}{time} = time;
				$attackSeq->{needReajust} = 1;
			}
		}
		
		$timeout{$slave->{ai_route_adjust_timeout}}{time} = time;
	}

	if ($slave->action eq "attack" && timeOut($slave->args->{attackMainTimeout}, 0.1)) {
		$slave->args->{attackMainTimeout} = time;
		main($slave);
	}
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

	my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou, $youHitTarget);
	my $realMyPos = calcPosFromPathfinding($field, $slave);
	my $realMonsterPos = calcPosFromPathfinding($field, $target);
	
	my $realMonsterDist = blockDistance($realMyPos, $realMonsterPos);
	my $clientDist = getClientDist($realMyPos, $realMonsterPos);


	# If the damage numbers have changed, update the giveup time so we don't timeout
	if ($args->{dmgToYou_last}   != $target->{dmgToPlayer}{$slave->{ID}}
	 || $args->{missedYou_last}  != $target->{missedToPlayer}{$slave->{ID}}
	 || $args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$slave->{ID}}) {
		$args->{ai_attack_giveup}{time} = time;
		debug "Update slave attack giveup time\n", 'slave_attack', 2;
	}
	
	$hitYou = ($args->{dmgToYou_last} != $target->{dmgToPlayer}{$slave->{ID}} || $args->{missedYou_last} != $target->{missedToPlayer}{$slave->{ID}});
	$youHitTarget = ($args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$slave->{ID}});
	
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

	my $melee;
	my $ranged;
	if (defined $args->{attackMethod}{type} && exists $args->{ai_attack_failed_give_up} && defined $args->{ai_attack_failed_give_up}{time}) {
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
		$canAttack = canAttack($field, $realMyPos, $realMonsterPos, $config{$slave->{configPrefix}.'attackCanSnipe'}, $args->{attackMethod}{maxDistance}, $config{clientSight});
	}
	
	if (
		   $config{$slave->{configPrefix}."attackBeyondMaxDistance_waitForAgressive"}
		&& $target->{dmgFromPlayer}{$slave->{ID}} > 0
		&& $canAttack == 1
		&& exists $args->{ai_attack_failed_waitForAgressive_give_up}
		&& defined $args->{ai_attack_failed_waitForAgressive_give_up}{time}
	) {
		debug "Deleting ai_attack_failed_waitForAgressive_give_up time.\n";
		delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};;
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
			
			my $pos = meetingPosition($slave, 2, $target, $current_dist, 1);
			if ($pos) {
				debug TF("[runFromTarget] (+$current_beyond | $current_dist/$max_sight) %s kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $pos->{x}, $pos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
				$args->{avoiding} = 1;
				$args->{needReajust} = 0;
				$slave->route(
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
				debug TF("%s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
				last;
				
			} else {
				$current_beyond += $increase;
			}
		}
	
	} elsif($canAttack  == -2) {
		debug T("Slave $slave can't determine a attackMethod\n"), 'slave_attack';
		$args->{ai_attack_failed_give_up}{timeout} = 6 if !$args->{ai_attack_failed_give_up}{timeout};
		$args->{ai_attack_failed_give_up}{time} = time if !$args->{ai_attack_failed_give_up}{time};
		if (timeOut($args->{ai_attack_failed_give_up})) {
			delete $args->{ai_attack_failed_give_up}{time};
			message T("$slave unable to determine a attackMethod (check attackUseWeapon and Skills blocks)\n"), 'slave_attack';
			giveUp($slave, $args, $ID, 0);
		}


	} elsif (
		$config{$slave->{configPrefix}."attackBeyondMaxDistance_waitForAgressive"} &&
		$target->{dmgFromPlayer}{$slave->{ID}} > 0 &&
		($canAttack == 0 || $canAttack == -1)
	) {
		$args->{ai_attack_failed_waitForAgressive_give_up}{timeout} = 6 if !$args->{ai_attack_failed_waitForAgressive_give_up}{timeout};
		$args->{ai_attack_failed_waitForAgressive_give_up}{time} = time if !$args->{ai_attack_failed_waitForAgressive_give_up}{time};
		
		if ($ranged) {
			if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
				delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
				message T("[Out of Range - Ranged] $slave waited too long for target to get closer, dropping target\n"), 'slave_attack';
				giveUp($slave, $args, $ID, 0);
			} else {
				$slave->sendAttack($ID) if ($config{$slave->{configPrefix}."attackBeyondMaxDistance_sendAttackWhileWaiting"});
				warning TF("[Out of Range - Ranged - Waiting] %s (%d %d), target %s (%d %d), distance %d, maxDistance %d, dmgFromYou %d.\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromPlayer}{$slave->{ID}}), 'slave_attack';
			}
			
		} elsif ($melee) {
			if (timeOut($args->{ai_attack_failed_waitForAgressive_give_up})) {
				delete $args->{ai_attack_failed_waitForAgressive_give_up}{time};
				warning T("[Out of Range - Melee] $slave waited too long for target to get closer, dropping target\n"), "ai_attack";
				giveUp($slave, $args, $ID, 0);
			} else {
				$slave->sendAttack($ID) if ($config{$slave->{configPrefix}."attackBeyondMaxDistance_sendAttackWhileWaiting"});
				warning TF("[Out of Range - Melee - Waiting] %s (%d %d), target %s (%d %d) [(%d %d) -> (%d %d)], distance %d, maxDistance %d, dmgFromYou %d.\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y}, $target->{pos}{x}, $target->{pos}{y}, $target->{pos_to}{x}, $target->{pos_to}{y}, $realMonsterDist, $args->{attackMethod}{maxDistance}, $target->{dmgFromPlayer}{$slave->{ID}}), 'ai_attack';
			}
		}

	} elsif (
		$canAttack < 1
	) {
		debug "Attack $slave ($realMyPos->{x} $realMyPos->{y}) - target $target ($realMonsterPos->{x} $realMonsterPos->{y})\n";
		if ($ranged && $canAttack == 0) {
			debug "[Slave Attack] [Ranged] [No range] $slave Too far from us to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';
		} elsif ($melee && $canAttack == 0) {
			debug "[Slave Attack] [Melee] [No range] $slave Too far from us to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';
		
		} elsif ($ranged && $canAttack == -1) {
			debug "[Slave Attack] [Ranged] [No LOS] $slave No LOS\n", 'ai_attack';
			
		} elsif ($melee && $canAttack == -1) {
			debug "[Slave Attack] [Melee] [No LOS] $slave No LOS\n", 'ai_attack';
			
		}

		$args->{move_start} = time;
		$args->{monsterLastMoveTime} = $target->{time_move};
		$args->{masterLastMoveTime} = $char->{time_move};
		my $pos = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance});
		if ($pos) {
			debug "Attack $slave ($realMyPos->{x} $realMyPos->{y}) - moving to meeting position ($pos->{x} $pos->{y})\n", 'ai_attack';

			$args->{needReajust} = 0;
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
			message T("Unable to calculate a meetingPosition to target, dropping target\n"), "ai_attack";
			giveUp($slave, $args, $ID, 1);
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
			if ($config{$slave->{configPrefix}.'attack_dance_melee'} && $melee) {
				if (timeOut($timeout{$slave->{ai_dance_attack_melee_timeout}})) {
					my $cell = get_dance_position($slave, $target);
					debug TF("Slave %s will dance type %d from (%d, %d) to (%d, %d), target %s at (%d, %d).\n", $slave, $config{$slave->{configPrefix}.'attack_dance_melee'}, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $target, $realMonsterPos->{x}, $realMonsterPos->{y});
					$slave->sendMove ($cell->{x}, $cell->{y});
					$slave->sendMove ($realMyPos->{x},$realMyPos->{y});
					$slave->sendAttack ($ID);
					$timeout{$slave->{ai_dance_attack_melee_timeout}}{time} = time;
				}
				
			} elsif ($config{$slave->{configPrefix}.'attack_dance_ranged'} && $ranged) {
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
