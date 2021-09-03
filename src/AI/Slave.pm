package AI::Slave;

use strict;
use Time::HiRes qw(time);
use base qw/Actor::Slave/;
use Globals;
use Log qw/message warning error debug/;
use Utils;
use Misc;
use Translation;

use AI::Slave::Homunculus;
use AI::Slave::Mercenary;

# Slave's commands and skills can only be used
# if the slave is within this range
use constant MAX_DISTANCE => 17;

sub checkSkillOwnership {}

sub action {
	my $slave = shift;
	
	my $i = (defined $_[0] ? $_[0] : 0);
	return $slave->{slave_ai_seq}[$i];
}

sub args {
	my $slave = shift;
	
	my $i = (defined $_[0] ? $_[0] : 0);
	return \%{$slave->{slave_ai_seq_args}[$i]};
}

sub dequeue {
	my $slave = shift;
	
	shift @{$slave->{slave_ai_seq}};
	shift @{$slave->{slave_ai_seq_args}};
}

sub queue {
	my $slave = shift;
	
	unshift @{$slave->{slave_ai_seq}}, shift;
	my $args = shift;
	unshift @{$slave->{slave_ai_seq_args}}, ((defined $args) ? $args : {});
}

sub clear {
	my $slave = shift;
	
	if (@_) {
		my $changed;
		for (my $i = 0; $i < @{$slave->{slave_ai_seq}}; $i++) {
			if (defined binFind(\@_, $slave->{slave_ai_seq}[$i])) {
				delete $slave->{slave_ai_seq}[$i];
				delete $slave->{slave_ai_seq_args}[$i];
				$changed = 1;
			}
		}

		if ($changed) {
			my (@new_seq, @new_args);
			for (my $i = 0; $i < @{$slave->{slave_ai_seq}}; $i++) {
				if (defined $slave->{slave_ai_seq}[$i]) {
					push @new_seq, $slave->{slave_ai_seq}[$i];
					push @new_args, $slave->{slave_ai_seq_args}[$i];
				}
			}
			@{$slave->{slave_ai_seq}} = @new_seq;
			@{$slave->{slave_ai_seq_args}} = @new_args;
		}

	} else {
		undef @{$slave->{slave_ai_seq}};
		undef @{$slave->{slave_ai_seq_args}};
	}
}

sub suspend {
	my $slave = shift;
	
	my $i = (defined $_[0] ? $_[0] : 0);
	$slave->{slave_ai_seq_args}[$i]{suspended} = time if $i < @{$slave->{slave_ai_seq_args}};
}

sub mapChanged {
	my $slave = shift;
	
	my $i = (defined $_[0] ? $_[0] : 0);
	$slave->{slave_ai_seq_args}[$i]{mapChanged} = time if $i < @{$slave->{slave_ai_seq_args}};
}

sub findAction {
	my $slave = shift;
	
	return binFind(\@{$slave->{slave_ai_seq}}, $_[0]);
}

sub inQueue {
	my $slave = shift;
	
	foreach (@_) {
		# Apparently using a loop is faster than calling
		# binFind() (which is optimized in C), because
		# of function call overhead.
		#return 1 if defined binFind(\@homun_ai_seq, $_);
		foreach my $seq (@{$slave->{slave_ai_seq}}) {
			return 1 if ($_ eq $seq);
		}
	}
	return 0;
}

sub isIdle {
	my $slave = shift;
	
	return $slave->{slave_ai_seq}[0] eq "";
}

sub is {
	my $slave = shift;
	
	foreach (@_) {
		return 1 if ($slave->{slave_ai_seq}[0] eq $_);
	}
	return 0;
}

sub isLost {
	my $slave = shift;
	return 1 if ($slave->{isLost} == 1);
	return 0;
}

sub mustRescue {
	my $slave = shift;
	return 1 if ($config{$slave->{configPrefix}.'route_randomWalk_rescueWhenLost'});
	return 0;
}

sub iterate {
	my $slave = shift;
	
	return unless ($slave->{appear_time} && $field->baseName eq $slave->{map});
	
	return if $slave->processClientSuspend;
	
	return if ($slave->{slave_AI} == AI::OFF);
	
	$slave->{master_dist} = $slave->blockDistance_master;

	##### MANUAL AI STARTS HERE #####
	
	$slave->processAttack;
	$slave->processTask('route', onError => sub {
		my ($task, $error) = @_;
		if (!($task->isa('Task::MapRoute') && $error->{code} == Task::MapRoute::TOO_MUCH_TIME())
		 && !($task->isa('Task::Route') && $error->{code} == Task::Route::TOO_MUCH_TIME())) {
			error("$error->{message}\n");
		}
	});
	$slave->processTask('move');

	return unless ($slave->{slave_AI} == AI::AUTO);

	##### AUTOMATIC AI STARTS HERE #####
	
	$slave->processWasFound;
	$slave->processTeleportToMaster;
	$slave->processAutoAttack;
	$slave->processFollow;
	$slave->processIdleWalk;
}

sub processWasFound {
	my $slave = shift;
	if ($slave->{isLost} && $slave->{master_dist} < MAX_DISTANCE) {
		$slave->{lost_teleportToMaster_maxTries} = 0;
		$slave->{isLost} = 0;
		warning TF("%s was rescued.\n", $slave), 'slave';
		if (AI::is('route') && AI::args()->{isSlaveRescue}) {
			warning TF("Cleaning AI rescue sequence\n"), 'slave';
			AI::dequeue() while (AI::is(qw/move route mapRoute/) && AI::args()->{isSlaveRescue});
		}
	}
}

sub processTeleportToMaster {
	my $slave = shift;
	if (
		   !AI::args->{mapChanged}
		&& $slave->{master_dist} >= MAX_DISTANCE
		&& timeOut($timeout{$slave->{ai_standby_timeout}})
		&& !$slave->{isLost}
	) {
		if (!$slave->{lost_teleportToMaster_maxTries} || $config{$slave->{configPrefix}.'lost_teleportToMaster_maxTries'} > $slave->{lost_teleportToMaster_maxTries}) {
			$slave->clear('move', 'route');
			$slave->sendStandBy;
			$slave->{lost_teleportToMaster_maxTries}++;
			$timeout{$slave->{ai_standby_timeout}}{time} = time;
			warning TF("%s trying to teleport to master (distance: %d) (re)try: %d\n", $slave, $slave->{master_dist}, $slave->{lost_teleportToMaster_maxTries}), 'slave';
		} else {
			warning TF("%s is lost (distance: %d).\n", $slave, $slave->{master_dist}), 'slave';
			$slave->{isLost} = 1;
			$timeout{$slave->{ai_standby_timeout}}{time} = time;
		}
	}
}

sub processFollow {
	my $slave = shift;
	if (
		   (AI::action eq "move" || AI::action eq "route")
		&& !$char->{sitting}
		&& !AI::args->{mapChanged}
		&& $slave->{master_dist} < MAX_DISTANCE
		&& ($slave->isIdle || $slave->{master_dist} > $config{$slave->{configPrefix}.'followDistanceMax'} || blockDistance($char->{pos_to}, $slave->{pos_to}) > $config{$slave->{configPrefix}.'followDistanceMax'})
		&& (!defined $slave->findAction('route') || !$slave->args($slave->findAction('route'))->{isFollow})
	) {
		$slave->clear('move', 'route');
		if (!$field->canMove($slave->{pos_to}, $char->{pos_to})) {
			$slave->route(undef, @{$char->{pos_to}}{qw(x y)}, isFollow => 1);
			debug TF("%s follow route (distance: %d)\n", $slave, $slave->{master_dist}), 'slave';

		} elsif (timeOut($slave->{move_retry}, 0.5)) {
			# No update yet, send move request again.
			# We do this every 0.5 secs
			$slave->{move_retry} = time;
			# NOTE:
			# The default LUA uses sendSlaveStandBy() for the follow AI
			# however, the server-side routing is very inefficient
			# (e.g. can't route properly around obstacles and corners)
			# so we make use of the sendSlaveMove() to make up for a more efficient routing
			$slave->move($char->{pos_to}{x}, $char->{pos_to}{y});
			debug TF("%s follow move (distance: %d)\n", $slave, $slave->{master_dist}), 'slave';
		}
	}
}

sub processIdleWalk {
	my $slave = shift;
	if (
		$slave->isIdle
		&& $slave->{master_dist} <= MAX_DISTANCE
		&& $config{$slave->{configPrefix}.'idleWalkType'}
	) {
		# Standby
		if ($config{$slave->{configPrefix}.'idleWalkType'} == 1) {
			return unless ($slave->{master_dist} > ($config{$slave->{configPrefix}.'followDistanceMin'} || 3));
			return unless (timeOut($timeout{$slave->{ai_standby_timeout}}));
			$timeout{$slave->{ai_standby_timeout}}{time} = time;
			$slave->sendStandBy;
			debug TF("%s standby\n", $slave), 'slave';

		# Random square
		} elsif ($config{$slave->{configPrefix}.'idleWalkType'} == 2) {
			my @cells = calcRectArea2($char->{pos_to}{x}, $char->{pos_to}{y}, $config{$slave->{configPrefix}.'followDistanceMax'}, $config{$slave->{configPrefix}.'followDistanceMin'});
			my $walk_pos;
			my $index;
			while (@cells) {
				$index = int(rand(@cells));
				my $cell = $cells[$index];
				next if (!$field->isWalkable($cell->{x}, $cell->{y}));
				
				$walk_pos = $cell;
				last;
			} continue {
				splice(@cells, $index, 1);
			}
			return unless ($walk_pos);
			$slave->route(undef, @{$walk_pos}{qw(x y)}, attackOnRoute => 2, noMapRoute => 1, noAvoidWalls => 1, isIdleWalk => 1);
			debug TF("%s IdleWalk route\n", $slave), 'slave';
		}
	}
}

##### ATTACK #####
sub processAttack {
	my $slave = shift;
	#Benchmark::begin("ai_homunculus_attack") if DEBUG;

	$slave->dequeue if $slave->action eq "checkMonsters";
	
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

	} elsif ($slave->action eq "attack" && $slave->args->{avoiding} && $slave->args->{attackID}) {
		my $target = Actor::get($slave->args->{attackID});
		$slave->args->{ai_attack_giveup}{time} = time + $target->{time_move_calc} + 3;
		undef $slave->args->{avoiding};

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
			debug "$slave target $target has moved since we started routing to it - Adjusting route\n", "ai_attack";
			$slave->dequeue;
			$slave->dequeue if $slave->action eq "route";

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
			debug "$slave target $target is now reachable by melee attacks during routing to it.\n", "ai_attack";
			$slave->dequeue;
			$slave->dequeue if $slave->action eq "route";

			$attackSeq->{ai_attack_giveup}{time} = time;
		}

		$timeout{$slave->{ai_route_adjust_timeout}}{time} = time;
	}

	if ($slave->action eq "attack" &&
	    (timeOut($slave->args->{ai_attack_giveup}) ||
		 $slave->args->{unstuck}{count} > 5) &&
		!$config{$slave->{configPrefix}.'attackNoGiveup'}) {
		my $ID = $slave->args->{ID};
		my $target = Actor::get($ID);
		$target->{$slave->{ai_attack_failed_timeout}} = time if $monsters{$ID};
		$slave->dequeue;
		message TF("%s can't reach or damage target, dropping target\n", $slave), 'slave_attack';
		if ($config{$slave->{configPrefix}.'teleportAuto_dropTarget'}) {
			message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
			useTeleport(1);
		}

	} elsif ($slave->action eq "attack" && !$monsters{$slave->args->{ID}} && (!$players{$slave->args->{ID}} || $players{$slave->args->{ID}}{dead})) {
		# Monster died or disappeared
		$timeout{$slave->{ai_attack_timeout}}{time} -= $timeout{$slave->{ai_attack_timeout}}{timeout};
		my $ID = $slave->args->{ID};
		$slave->dequeue;

		if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
			message TF("%s target died\n", $slave), 'slave_attack';
			Plugins::callHook("homonulus_target_died");
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

	} elsif ($slave->action eq "attack") {
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
		if (!$config{$slave->{configPrefix}.'runFromTarget'}) {
			$myPos = $realMyPos;
			$monsterPos = $realMonsterPos;
		}

		my $cleanMonster = slave_checkMonsterCleanness($slave, $ID);


		# If the damage numbers have changed, update the giveup time so we don't timeout
		if ($args->{dmgToYou_last}   != $target->{dmgToPlayer}{$slave->{ID}}
		 || $args->{missedYou_last}  != $target->{missedToPlayer}{$slave->{ID}}
		 || $args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$slave->{ID}}) {
			$args->{ai_attack_giveup}{time} = time;
			debug "Update slave attack giveup time\n", "ai_attack", 2;
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

		if (!$cleanMonster) {
			# Drop target if it's already attacked by someone else
			$target->{$slave->{ai_attack_failed_timeout}} = time if $monsters{$ID};
			message TF("Dropping target - %s will not kill steal others\n", $slave), 'slave_attack';
			$slave->sendMove ($realMyPos->{x}, $realMyPos->{y});
			$slave->dequeue;
			if ($config{$slave->{configPrefix}.'teleportAuto_dropTargetKS'}) {
				message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
				useTeleport(1);
			}

		} elsif ($config{$slave->{configPrefix}.'runFromTarget'} && ($realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_dist'} || $hitYou)) {
			my $cell = get_kite_position($slave, 2, $target);
			if ($cell) {
				debug TF("%s kiteing from (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave';
				$slave->args->{avoiding} = 1;
				$slave->move($cell->{x}, $cell->{y}, $ID);
			} else {
				debug TF("%s no acceptable place to kite from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'slave';
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
			
			debug "$slave target $target ($realMonsterPos->{x} $realMonsterPos->{y}) is too far from slave ($realMyPos->{x} $realMyPos->{y}) to attack, distance is $realMonsterDist, attack maxDistance is $args->{attackMethod}{maxDistance}\n", 'ai_attack';
			
			my $pos = meetingPosition($slave, 2, $target, $args->{attackMethod}{maxDistance});
			my $result;
			
			if ($pos) {
				debug "Attack $slave ($realMyPos->{x} $realMyPos->{y}) - moving to meeting position ($pos->{x} $pos->{y})\n", 'ai_attack';
				
				$result = $slave->route(
					undef,
					@{$pos}{qw(x y)},
					maxRouteTime => $config{$slave->{configPrefix}.'attackMaxRouteTime'},
					attackID => $ID,
					avoidWalls => 0,
					meetingSubRoute => 1,
					LOSSubRoute => 1
				);
				
				if (!$result) {
					# Unable to calculate a route to target
					$target->{$slave->{ai_attack_failed_timeout}} = time;
					$slave->dequeue;
					message TF("Unable to calculate a route to %s target, dropping target\n", $slave), 'slave_attack';
					if ($config{$slave->{configPrefix}.'teleportAuto_dropTarget'}) {
						message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
						useTeleport(1);
					} else {
						debug "Attack $slave - successufully routing to $target\n", 'attack';
					}
				}
			} else {
				$target->{$slave->{ai_attack_failed_timeout}} = time;
				$slave->dequeue;
				message T("Unable to calculate a meetingPosition to target, dropping target\n"), 'slave_attack';
				if ($config{$slave->{configPrefix}.'teleportAuto_dropTarget'}) {
					message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
					useTeleport(1);
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
				$slave->route(undef, @{$best_spot}{qw(x y)}, LOSSubRoute => 1, avoidWalls => 0);
			} else {
				$target->{attack_failedLOS} = time;
				warning TF("%s; no acceptable place to stand\n", $msg);
				$slave->dequeue;
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
				$slave->route(undef, @{$best_spot}{qw(x y)}, LOSSubRoute => 1, avoidWalls => 0);
			} else {
				$target->{attack_failedLOS} = time;
				warning TF("%s; no acceptable place to stand\n", $msg);
				$slave->dequeue;
			}

		} elsif ((!$config{$slave->{configPrefix}.'runFromTarget'} || $realMonsterDist >= $config{$slave->{configPrefix}.'runFromTarget_dist'})
		 && (!$config{$slave->{configPrefix}.'tankMode'} || !$target->{dmgFromPlayer}{$slave->{ID}})) {
			# Attack the target. In case of tanking, only attack if it hasn't been hit once.
			if (!$slave->args->{firstAttack}) {
				$slave->args->{firstAttack} = 1;
				my $pos = "$myPos->{x},$myPos->{y}";
				debug "$slave is ready to attack target $target (which is $realMonsterDist blocks away); we're at ($pos)\n", "ai_attack";
			}

			$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
			if (!$target->{dmgFromPlayer}{$slave->{ID}} && timeOut($args->{unstuck})) {
				# We are close enough to the target, and we're trying to attack it,
				# but some time has passed and we still haven't dealed any damage.
				# Our recorded position might be out of sync, so try to unstuck
				$args->{unstuck}{time} = time;
				debug("$slave attack - trying to unstuck\n", "ai_attack");
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
							my $cell = get_kite_position($slave, 1, $target);
							if ($cell) {
								debug TF("%s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
								$args->{avoiding} = 1;
								$slave->sendMove($cell->{x}, $cell->{y});
							} else {
								debug TF("%s no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
							}
						}
						$timeout{$slave->{ai_dance_attack_ranged_timeout}}{time} = time;
					}
				
				} else {
					if (timeOut($timeout{$slave->{ai_attack_timeout}})) {
						$slave->sendAttack ($ID);
						if ($config{$slave->{configPrefix}.'runFromTarget'} && $config{$slave->{configPrefix}.'runFromTarget_inAdvance'} && $realMonsterDist < $config{$slave->{configPrefix}.'runFromTarget_minStep'}) {
							my $cell = get_kite_position($slave, 1, $target);
							if ($cell) {
								debug TF("%s kiting in advance (%d %d) to (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $cell->{x}, $cell->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
								$args->{avoiding} = 1;
								$slave->sendMove($cell->{x}, $cell->{y});
							} else {
								debug TF("%s no acceptable place to kite in advance from (%d %d), mob at (%d %d).\n", $slave, $realMyPos->{x}, $realMyPos->{y}, $realMonsterPos->{x}, $realMonsterPos->{y}), 'ai_attack';
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

	# Check for kill steal while moving
	if ($slave->is("move", "route") && $slave->args->{attackID} && $slave->inQueue("attack")) {
		my $ID = $slave->args->{attackID};
		if ((my $target = $monsters{$ID}) && !slave_checkMonsterCleanness($slave, $ID)) {
			$target->{$slave->{ai_attack_failed_timeout}} = time;
			message TF("Dropping target - %s will not kill steal others\n", $slave), 'slave_attack';
			$slave->sendAttackStop;
			$monsters{$ID}{slave_ignore} = 1;

			# Right now, the queue is either
			#   move, route, attack
			# -or-
			#   route, attack
			$slave->dequeue;
			$slave->dequeue;
			$slave->dequeue if ($slave->action eq "attack");
			if ($config{$slave->{configPrefix}.'teleportAuto_dropTargetKS'}) {
				message TF("Teleport due to dropping %s attack target\n", $slave), 'teleport';
				useTeleport(1);
			}
		}
	}

	#Benchmark::end("ai_homunculus_attack") if DEBUG;
}

sub processClientSuspend {
	my $slave = shift;
	##### CLIENT SUSPEND #####
	# The clientSuspend AI sequence is used to freeze all other AI activity
	# for a certain period of time.

	if ($slave->action eq 'clientSuspend' && timeOut($slave->args)) {
		debug "Slave AI suspend by clientSuspend dequeued\n";
		$slave->dequeue;
	} elsif ($slave->action eq "clientSuspend" && $net->clientAlive()) {
		# When XKore mode is turned on, clientSuspend will increase it's timeout
		# every time the user tries to do something manually.
		my $args = $slave->args;

		if ($args->{'type'} eq "0089") {
			# Player's manually attacking
			if ($args->{'args'}[0] == 2) {
				if ($chars[$config{'char'}]{'sitting'}) {
					$args->{'time'} = time;
				}
			} elsif ($args->{'args'}[0] == 3) {
				$args->{'timeout'} = 6;
			} else {
				my $ID = $args->{args}[1];
				my $monster = $monstersList->getByID($ID);

				if (!$args->{'forceGiveup'}{'timeout'}) {
					$args->{'forceGiveup'}{'timeout'} = 6;
					$args->{'forceGiveup'}{'time'} = time;
				}
				if ($monster) {
					$args->{time} = time;
					$args->{dmgFromYou_last} = $monster->{dmgFromYou};
					$args->{missedFromYou_last} = $monster->{missedFromYou};
					if ($args->{dmgFromYou_last} != $monster->{dmgFromYou}) {
						$args->{forceGiveup}{time} = time;
					}
				} else {
					$args->{time} -= $args->{'timeout'};
				}
				if (timeOut($args->{forceGiveup})) {
					$args->{time} -= $args->{timeout};
				}
			}

		} elsif ($args->{'type'} eq "009F") {
			# Player's manually picking up an item
			if (!$args->{'forceGiveup'}{'timeout'}) {
				$args->{'forceGiveup'}{'timeout'} = 4;
				$args->{'forceGiveup'}{'time'} = time;
			}
			if ($items{$args->{'args'}[0]}) {
				$args->{'time'} = time;
			} else {
				$args->{'time'} -= $args->{'timeout'};
			}
			if (timeOut($args->{'forceGiveup'})) {
				$args->{'time'} -= $args->{'timeout'};
			}
		}

		# Client suspended, do not continue with AI
		return 1;
	}
}

##### AUTO-ATTACK #####
sub processAutoAttack {
	my $slave = shift;
	# The auto-attack logic is as follows:
	# 1. Generate a list of monsters that we are allowed to attack.
	# 2. Pick the "best" monster out of that list, and attack it.

	#Benchmark::begin("ai_homunculus_autoAttack") if DEBUG;

	if (
	    ($slave->isIdle || $slave->action eq 'route')
	 &&   (AI::isIdle
	    || AI::is(qw(follow sitAuto attack skill_use))
		|| ($config{$slave->{configPrefix}.'attackAuto_duringItemsTake'} && AI::is(qw(take items_gather items_take)))
		|| ($config{$slave->{configPrefix}.'attackAuto_duringRandomWalk'} && AI::is('route') && AI::args()->{isRandomWalk}))
	 && timeOut($timeout{$slave->{ai_attack_auto_timeout}})
	 && (!$config{$slave->{configPrefix}.'attackAuto_notInTown'} || !$field->isCity)
	 && $slave->{master_dist} <= $config{$slave->{configPrefix}.'followDistanceMax'}
	 && ((AI::action ne "move" && AI::action ne "route") || blockDistance($char->{pos_to}, $slave->{pos_to}) <= $config{$slave->{configPrefix}.'followDistanceMax'})
	) {

		# If we're in tanking mode, only attack something if the person we're tanking for is on screen.
		my $foundTankee;
		if ($config{$slave->{configPrefix}.'tankMode'}) {
			if ($config{$slave->{configPrefix}.'tankModeTarget'} eq $char->{name}) {
				$foundTankee = 1;
			} else {
				foreach (@playersID) {
					next if (!$_);
					if ($config{$slave->{configPrefix}.'tankModeTarget'} eq $players{$_}{'name'}) {
						$foundTankee = 1;
						last;
					}
				}
			}
		}

		my $attackTarget;
		my $priorityAttack;

		if (!$config{$slave->{configPrefix}.'tankMode'} || $foundTankee) {
			# This variable controls how far monsters must be away from portals and players.
			my $portalDist = $config{'attackMinPortalDistance'} || 0; # Homun do not have effect on portals
			my $playerDist = $config{'attackMinPlayerDistance'};
			$playerDist = 1 if ($playerDist < 1);
		
			my $routeIndex = $slave->findAction("route");
			my $attackOnRoute;
			if (defined $routeIndex) {
				$attackOnRoute = $slave->args($routeIndex)->{attackOnRoute};
			} else {
				$attackOnRoute = 2;
			}

			### Step 1: Generate a list of all monsters that we are allowed to attack. ###
			my @aggressives;
			my @partyMonsters;
			my @cleanMonsters;
			my $myPos = calcPosition($slave);

			# List aggressive monsters
			@aggressives = AI::ai_slave_getAggressives($slave, 1) if ($config{$slave->{configPrefix}.'attackAuto'} && $attackOnRoute);

			# There are two types of non-aggressive monsters. We generate two lists:
			foreach (@monstersID) {
				next if (!$_ || !slave_checkMonsterCleanness($slave, $_));
				my $monster = $monsters{$_};

				# Never attack monsters that we failed to get LOS with
				next if (!timeOut($monster->{attack_failedLOS}, $timeout{ai_attack_failedLOS}{timeout}));

				my $pos = calcPosition($monster);
				my $master_pos = $char->position;
				
				next if (blockDistance($master_pos, $pos) > ($config{$slave->{configPrefix}.'followDistanceMax'} + $config{$slave->{configPrefix}.'attackMaxDistance'}));

				# List monsters that master and other slaves are attacking
				if (
					$config{$slave->{configPrefix}.'attackAuto_party'} &&
					$attackOnRoute &&
					(
						$monster->{dmgFromYou} ||
						$monster->{dmgToYou} ||
						$monster->{missedYou} ||
						scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgFromPlayer}}) > 0 ||
						scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgToPlayer}}) > 0 ||
						scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedToPlayer}}) > 0
					) &&
					timeOut($monster->{$slave->{ai_attack_failed_timeout}}, $timeout{ai_attack_unfail}{timeout})
				) {
					push @partyMonsters, $_;
					next;
				}

				### List normal, non-aggressive monsters. ###

				# Ignore monsters that
				# - Are inside others' area spells (this includes being trapped).
				# - Are moving towards other players.
				next if (objectInsideSpell($monster) || objectIsMovingTowardsPlayer($monster));

				my $safe = 1;
				if ($config{$slave->{configPrefix}.'attackAuto_onlyWhenSafe'}) {
					foreach (@playersID) {
						next if ($_ eq $slave->{ID});
						if ($_ && !$char->{party}{users}{$_}) {
							$safe = 0;
							last;
						}
					}
				}
				
				my $control = mon_control($monster->{name}, $monster->{nameID});
				if ($config{$slave->{configPrefix}.'attackAuto'} >= 2
				 && ($control->{attack_auto} == 1 || $control->{attack_auto} == 3)
				 && $attackOnRoute >= 2 && $safe
				 && !positionNearPlayer($pos, $playerDist) && !positionNearPortal($pos, $portalDist)
				 && !$monster->{dmgFromYou}
				 && timeOut($monster->{$slave->{ai_attack_failed_timeout}}, $timeout{ai_attack_unfail}{timeout})) {
					push @cleanMonsters, $_;
				}
			}

			### Step 2: Pick out the "best" monster ###

			# We define whether we should attack only monsters in LOS or not
			my $checkLOS = $config{$slave->{configPrefix}.'attackCheckLOS'};
			my $canSnipe = $config{$slave->{configPrefix}.'attackCanSnipe'};
			$attackTarget = getBestTarget(\@aggressives,   $checkLOS, $canSnipe) ||
			                getBestTarget(\@partyMonsters, $checkLOS, $canSnipe) ||
			                getBestTarget(\@cleanMonsters, $checkLOS, $canSnipe);
		}

		# If an appropriate monster's found, attack it. If not, wait ai_attack_auto secs before searching again.
		if ($attackTarget) {
			$slave->setSuspend(0);
			$slave->attack($attackTarget, $priorityAttack);
		} else {
			$timeout{$slave->{ai_attack_auto_timeout}}{time} = time;
		}
	}

	#Benchmark::end("ai_homunculus_autoAttack") if DEBUG;
}

sub sendAttack {
	my ($slave, $targetID) = @_;
	$messageSender->sendSlaveAttack ($slave->{ID}, $targetID);
}

sub sendMove {
	my ($slave, $x, $y) = @_;
	$messageSender->sendSlaveMove ($slave->{ID}, $x, $y);
}

sub sendStandBy {
	my ($slave) = @_;
	$messageSender->sendSlaveStandBy ($slave->{ID});
}

1;
