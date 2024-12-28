package AI::Slave;

use strict;
use Time::HiRes qw(time);
use base qw/Actor::Slave/;
use Globals;
use Log qw/message warning error debug/;
use Utils;
use Misc;
use Translation;

use AI::SlaveAttack;

use AI::Slave::Homunculus;
use AI::Slave::Mercenary;

# Slave's commands and skills can only be used
# if the slave is within this range
use constant MAX_DISTANCE => 17;

sub checkSkillOwnership {}

sub getSkillLevel {
	my ($self, $skill) = @_;
	my $handle = $skill->getHandle();
	if ($self->{skills}{$handle}) {
		return $self->{skills}{$handle}{lv};
	} else {
		return 0;
	}
}

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
	my $action = shift;
	my $args = shift;
	
	unshift @{$slave->{slave_ai_seq}}, $action;
	unshift @{$slave->{slave_ai_seq_args}}, ((defined $args) ? $args : {});
}

sub clear {
	my $slave = shift;
	
	my $total = scalar @_;
	
	# If no arg was given clear all Slave AI queue
	if ($total == 0) {
		undef @{$slave->{slave_ai_seq}};
		undef @{$slave->{slave_ai_seq_args}};
	
	# If 1 arg was given find it in the queue
	} elsif ($total == 1) {
		my $wanted_action = shift;
		my $seq_index;
		foreach my $i (0..$#{$slave->{slave_ai_seq}}) {
			next unless ($slave->{slave_ai_seq}[$i] eq $wanted_action);
			$seq_index = $i;
			last;
		}
		return unless (defined $seq_index); # return unless we found the action in the queue
		
		splice(@{$slave->{slave_ai_seq}}, $seq_index , 1); # Splice it out of  @{$slave->{slave_ai_seq}}
		splice(@{$slave->{slave_ai_seq_args}}, $seq_index , 1);  # Splice it out of @{$slave->{slave_ai_seq_args}}
		# When there are multiple of the same action (route, attack, route) the splices of remove the first one
		# So recursively call $slave->clear again with the same action until none is found
		$slave->clear($wanted_action);
	
	# If more than 1 arg was given recursively call $slave->clear for each one
	} else {
		foreach (@_) {
			$slave->clear($_);
		}
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
	
	AI::SlaveAttack::process($slave);
	$slave->processSkillUse;
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
			$slave->route(undef, @{$char->{pos_to}}{qw(x y)}, noMapRoute => 1, avoidWalls => 0, randomFactor => 0, useManhattan => 1, isFollow => 1);
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
			$slave->route(undef, @{$walk_pos}{qw(x y)}, attackOnRoute => 2, noMapRoute => 1, avoidWalls => 0, randomFactor => 0, useManhattan => 1, isIdleWalk => 1);
			debug TF("%s IdleWalk route\n", $slave), 'slave';
		}
	}
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
	
	return if $slave->inQueue("attack");
	
	# The auto-attack logic is as follows:
	# 1. Generate a list of monsters that we are allowed to attack.
	# 2. Pick the "best" monster out of that list, and attack it.
	
	# Don't even think about attacking if attackAuto is -1.
	return if ($config{$slave->{configPrefix}.'attackAuto'} && $config{$slave->{configPrefix}.'attackAuto'} eq -1);
	
	return if (!$field);
	next unless ($slave->isIdle || $slave->is(qw/route/));

	next unless (
	    AI::isIdle ||
	    AI::is(qw(follow sitAuto attack skill_use)) ||
		(AI::action eq "route" && AI::action(1) eq "attack") ||
		(AI::action eq "move" && AI::action(2) eq "attack") ||
		($config{$slave->{configPrefix}.'attackAuto_duringItemsTake'} && AI::is(qw(take items_gather items_take))) ||
		($config{$slave->{configPrefix}.'attackAuto_duringRandomWalk'} && AI::is('route') && AI::args()->{isRandomWalk})
	);
	next unless (timeOut($timeout{$slave->{ai_attack_auto_timeout}}));
	next unless ($slave->{master_dist} <= $config{$slave->{configPrefix}.'followDistanceMax'});
	#next unless ((AI::action ne "move" && AI::action ne "route") || blockDistance($char->{pos_to}, $slave->{pos_to}) <= $config{$slave->{configPrefix}.'followDistanceMax'});
	next unless (!$config{$slave->{configPrefix}.'attackAuto_notInTown'} || !$field->isCity);
	next unless ($config{$slave->{configPrefix}.'attackAuto_inLockOnly'} <= 1 || $field->baseName eq $config{'lockMap'});
	next unless (!$config{$slave->{configPrefix}.'attackAuto_notWhile_storageAuto'} || !AI::inQueue("storageAuto"));
	next unless (!$config{$slave->{configPrefix}.'attackAuto_notWhile_buyAuto'} || !AI::inQueue("buyAuto"));
	next unless (!$config{$slave->{configPrefix}.'attackAuto_notWhile_sellAuto'} || !AI::inQueue("sellAuto"));

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
		# TODO: Is there any situation where we should use calcPosFromPathfinding or calcPosFromTime here?
		my $myPos = calcPosition($slave);

		# List aggressive monsters
		my $party = $config{$slave->{configPrefix}.'attackAuto_party'} ? 1 : 0;
		@aggressives = AI::ai_slave_getAggressives($slave, 1, $party) if ($config{$slave->{configPrefix}.'attackAuto'} && $attackOnRoute);

		# There are two types of non-aggressive monsters. We generate two lists:
		foreach (@monstersID) {
			next if (!$_ || !slave_checkMonsterCleanness($slave, $_));
			my $monster = $monsters{$_};

			# Never attack monsters that we failed to get LOS with
			next if (!timeOut($monster->{attack_failedLOS}, $timeout{ai_attack_failedLOS}{timeout}));

			# TODO: Is there any situation where we should use calcPosFromPathfinding or calcPosFromTime here?
			my $target_pos = calcPosition($monster);
			my $master_pos = $char->position;

			next if (blockDistance($master_pos, $target_pos) > ($config{$slave->{configPrefix}.'followDistanceMax'} + $config{$slave->{configPrefix}.'attackMaxDistance'}));

			# List monsters that master and other slaves are attacking
			if (
				   $config{$slave->{configPrefix}.'attackAuto_party'}
				&& $attackOnRoute
				&& timeOut($monster->{$slave->{ai_attack_failed_timeout}}, $timeout{ai_attack_unfail}{timeout})
				&& (
					   ($monster->{missedFromYou} && $config{$slave->{configPrefix}.'attackAuto_party'} != 2)
					|| ($monster->{dmgFromYou} && $config{$slave->{configPrefix}.'attackAuto_party'} != 2)
					|| ($monster->{castOnByYou} && $config{$slave->{configPrefix}.'attackAuto_party'} != 2)
					|| $monster->{dmgToYou}
					|| $monster->{missedYou}
					|| $monster->{castOnToYou}
					|| (scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedFromPlayer}}) && $config{$slave->{configPrefix}.'attackAuto_party'} != 2)
					|| (scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgFromPlayer}}) && $config{$slave->{configPrefix}.'attackAuto_party'} != 2)
					|| (scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{castOnByPlayer}}) && $config{$slave->{configPrefix}.'attackAuto_party'} != 2)
					|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{missedToPlayer}})
					|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{dmgToPlayer}})
					|| scalar(grep { isMySlaveID($_, $slave->{ID}) } keys %{$monster->{castOnToPlayer}})
				   )
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
			 && !positionNearPlayer($target_pos, $playerDist) && !positionNearPortal($target_pos, $portalDist)
			 && !$monster->{dmgFromYou}
			 && timeOut($monster->{$slave->{ai_attack_failed_timeout}}, $timeout{ai_attack_unfail}{timeout})
			) {
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

	#Benchmark::end("ai_homunculus_autoAttack") if DEBUG;
}

##### SKILL USE #####
sub processSkillUse {
	my ($slave) = @_;
	
	#FIXME: need to move closer before using skill on player,
	#there might be line of sight problem too
	#or the player disappers from the area

	if ($slave->action eq "skill_use" && $slave->args->{suspended}) {
		$slave->args->{giveup}{time} += time - $slave->args->{suspended};
		$slave->args->{minCastTime}{time} += time - $slave->args->{suspended};
		$slave->args->{maxCastTime}{time} += time - $slave->args->{suspended};
		delete $slave->args->{suspended};
	}

	SKILL_USE: {
		last SKILL_USE if ($slave->action ne "skill_use");
		my $args = $slave->args;

		if ($args->{monsterID} && $skillsArea{$args->{skillHandle}} == 2) {
			delete $args->{monsterID};
		}

		if (timeOut($args->{waitBeforeUse})) {
			if (defined $args->{monsterID} && !defined $monsters{$args->{monsterID}}) {
				# This skill is supposed to be used for attacking a monster, but that monster has died
				$slave->dequeue;
				${$args->{ret}} = 'target gone' if ($args->{ret});

			# Use skill if we haven't done so yet
			} elsif (!$args->{skill_used}) {
				#if ($slave->{last_skill_used_is_continuous}) {
				#	message T("Stoping rolling\n");
				#	$messageSender->sendStopSkillUse($slave->{last_continuous_skill_used});
				#} elsif(($slave->{last_skill_used} == 2027 || $slave->{last_skill_used} == 147) && !$slave->{selected_craft}) {
				#	message T("No use skill due to not select the craft / poison\n");
				#	last SKILL_USE;
				#}
				my $handle = $args->{skillHandle};
				if (!defined $args->{skillID}) {
					my $skill = new Skill(handle => $handle);
					$args->{skillID} = $skill->getIDN();
				}
				my $skillID = $args->{skillID};

				$args->{skill_used} = 1;
				$args->{giveup}{time} = time;

				# Stop attacking, otherwise skill use might fail
				my $attackIndex = $slave->findAction("attack");
				if (defined($attackIndex) && $slave->args($attackIndex)->{attackMethod}{type} eq "weapon") {
					# 2005-01-24 pmak: Commenting this out since it may
					# be causing bot to attack slowly when a buff runs
					# out.
					#$slave->stopAttack();
				}

				# Give an error if we don't actually possess this skill
				my $skill = new Skill(handle => $handle);
				my $owner = $skill->getOwner();
				my $lvl = $owner->getSkillLevel($skill);

				if ($lvl <= 0) {
					debug "Attempted to use skill (".$skill->getName().") which you do not have.\n";
				}

				$args->{maxCastTime}{time} = time;
				if ($skillsArea{$handle} == 2) {
					$messageSender->sendSkillUse($skillID, $args->{lv}, $accountID);
				} elsif ($args->{x} ne "") {
					$messageSender->sendSkillUseLoc($skillID, $args->{lv}, $args->{x}, $args->{y});
				} elsif ($args->{isStartSkill}) {
					$messageSender->sendStartSkillUse($skillID, $args->{lv}, $args->{target});
				} else {
					$messageSender->sendSkillUse($skillID, $args->{lv}, $args->{target});
				}
				$args->{skill_use_last} = $slave->{skills}{$handle}{time_used};

				delete $slave->{cast_cancelled};

			} elsif (timeOut($args->{minCastTime})) {
				if ($args->{skill_use_last} != $slave->{skills}{$args->{skillHandle}}{time_used}) {
					$slave->dequeue;
					${$args->{ret}} = 'ok' if ($args->{ret});

				} elsif ($slave->{cast_cancelled} > $slave->{time_cast}) {
					$slave->dequeue;
					${$args->{ret}} = 'cancelled' if ($args->{ret});

				} elsif (timeOut($slave->{time_cast}, $slave->{time_cast_wait} + 0.5)
				  && ( (timeOut($slave->{giveup}) && (!$slave->{time_cast} || !$args->{maxCastTime}{timeout}) )
				      || ( $args->{maxCastTime}{timeout} && timeOut($args->{maxCastTime})) )
				) {
					$slave->dequeue;
					${$args->{ret}} = 'timeout' if ($args->{ret});
				}
			}
		}
	}
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
