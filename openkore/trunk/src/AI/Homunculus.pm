#########################################################################
#  OpenKore - Homunculus AI
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
package AI::Homunculus;

use strict;
use Time::HiRes qw(time);

use Globals;
use Log qw(message warning error debug);
use AI;
use Utils;
use Misc;
use Translation;

# homunculus commands/skills can only be used
# if the homunculus is within this range
use constant MAX_DISTANCE => 17;

our @homun_ai_seq;
our @homun_ai_seq_args;

our @homun_skillsID;

our $homun_AI = 2;
our $homun_AI_forcedOff;

my $attack_route_adjust;
my $move_retry;

sub action {
	my $i = (defined $_[0] ? $_[0] : 0);
	return $homun_ai_seq[$i];
}

sub args {
	my $i = (defined $_[0] ? $_[0] : 0);
	return \%{$homun_ai_seq_args[$i]};
}

sub dequeue {
	shift @homun_ai_seq;
	shift @homun_ai_seq_args;
}

sub queue {
	unshift @homun_ai_seq, shift;
	my $args = shift;
	unshift @homun_ai_seq_args, ((defined $args) ? $args : {});
}

sub clear {
	if (@_) {
		my $changed;
		for (my $i = 0; $i < @homun_ai_seq; $i++) {
			if (defined binFind(\@_, $homun_ai_seq[$i])) {
				delete $homun_ai_seq[$i];
				delete $homun_ai_seq_args[$i];
				$changed = 1;
			}
		}

		if ($changed) {
			my (@new_seq, @new_args);
			for (my $i = 0; $i < @homun_ai_seq; $i++) {
				if (defined $homun_ai_seq[$i]) {
					push @new_seq, $homun_ai_seq[$i];
					push @new_args, $homun_ai_seq_args[$i];
				}
			}
			@homun_ai_seq = @new_seq;
			@homun_ai_seq_args = @new_args;
		}

	} else {
		undef @homun_ai_seq;
		undef @homun_ai_seq_args;
	}
}

sub suspend {
	my $i = (defined $_[0] ? $_[0] : 0);
	$homun_ai_seq_args[$i]{suspended} = time if $i < @homun_ai_seq_args;
}

sub mapChanged {
	my $i = (defined $_[0] ? $_[0] : 0);
	$homun_ai_seq_args[$i]{mapChanged} = time if $i < @homun_ai_seq_args;
}

sub findAction {
	return binFind(\@homun_ai_seq, $_[0]);
}

sub inQueue {
	foreach (@_) {
		# Apparently using a loop is faster than calling
		# binFind() (which is optimized in C), because
		# of function call overhead.
		#return 1 if defined binFind(\@homun_ai_seq, $_);
		foreach my $seq (@homun_ai_seq) {
			return 1 if ($_ eq $seq);
		}
	}
	return 0;
}

sub isIdle {
	return $homun_ai_seq[0] eq "";
}

sub is {
	foreach (@_) {
		return 1 if ($homun_ai_seq[0] eq $_);
	}
	return 0;
}

sub processFeeding {
	# Homun loses intimacy if you let hunger fall lower than 11 and if you feed it above 75 (?)
	$char->{homunculus}{hungerThreshold} = int(rand($config{homunculus_hungerMin}))+($config{homunculus_hungerMax} - $config{homunculus_hungerMin});
	# Make a random timeout, to appear more humanlike when we have to feed our homun more than once in a row.
	$char->{homunculus}{feed_timeout} = int(rand(($config{homunculus_hungerTimeoutMax})-$config{homunculus_hungerTimeoutMin}))+$config{homunculus_hungerTimeoutMin};
	$char->{homunculus}{feed_time} = time;
}
##########################################

sub iterate {
	return if (!$char->{homunculus});
	
	# homunculus is in rest
	if ($char->{homunculus}{state} & 2) {
		#if (!ai_getAggressives() && timeOut($char->{homunculus}{recall_time}, 2)) {
		#	$messageSender->sendSkillUse(243, 1, $accountID);
		#	$char->{homunculus}{recall_time} = time;
		#}
	
	# homunculus is dead
	} elsif ($char->{homunculus}{state} & 4) {
#		if ($config{homunculus_resurrectAuto} && (!ai_getAggressives() || $config{homunculus_resurrectAuto} >= 2) && timeOut($char->{homunculus}{resurrect_time}, 4)) {
#			ai_skillUse('AM_RESURRECTHOMUN', $char->{skills}{'AM_RESURRECTHOMUN'}{lv}, 0, 2, $accountID)
#			$messageSender->sendSkillUse(247, $char->{skills}{'AM_RESURRECTHOMUN'}{lv}, $accountID);
#			$char->{homunculus}{resurrect_time} = time;
#		}

	# homunculus is alive
	} elsif ($char->{homunculus}{appear_time} && $field{name} eq $char->{homunculus}{map}) {
		my $homun_dist = $char->{homunculus}->blockDistance();
		
		# auto-feed homunculus
		$config{homunculus_intimacyMax} = 999 if (!$config{homunculus_intimacyMax});
		$config{homunculus_intimacyMin} = 911 if (!$config{homunculus_intimacyMin});
		$config{homunculus_hungerTimeoutMax} = 60 if (!$config{homunculus_hungerTimeoutMax});
		$config{homunculus_hungerTimeoutMin} = 10 if (!$config{homunculus_hungerTimeoutMin});
		$config{homunculus_hungerMin} = 11 if (!$config{homunculus_hungerMin});
		$config{homunculus_hungerMax} = 24 if (!$config{homunculus_hungerMax});

		# Stop feeding when homunculus reaches 999~1000 intimacy, its useless to keep feeding from this point on
		# you can starve it till it gets 911 hunger (actually you can starve it till 1 but we wanna keep its intimacy loyal).
		if (($char->{homunculus}{intimacy} >= $config{homunculus_intimacyMax}) && $char->{homunculus}{feed}) {
			$char->{homunculus}{feed} = 0
		} elsif (($char->{homunculus}{intimacy} <= $config{homunculus_intimacyMin}) && !$char->{homunculus}{feed}) {
			$char->{homunculus}{feed} = 1
		}

		if ($char->{homunculus}{hungerThreshold} 
			&& $char->{homunculus}{hunger} ne '' 
			&& $char->{homunculus}{hunger} <= $char->{homunculus}{hungerThreshold} 
			&& timeOut($char->{homunculus}{feed_time},$char->{homunculus}{feed_timeout})
			&& $char->{homunculus}{feed}
			&& $config{homunculus_autoFeed} 
			&& (existsInList($config{homunculus_autoFeedAllowedMaps},$field{'name'}) || !$config{homunculus_autoFeedAllowedMaps})) {
			
			processFeeding();
			message T("Auto-feeding your Homunculus (".$char->{homunculus}{hunger}." hunger).\n"), 'homunculus';
			$messageSender->sendHomunculusFeed();
			message ("Next feeding at: ".$char->{homunculus}{hungerThreshold}." hunger.\n"), 'homunculus';
		
		# No random value at initial start of Kore, lets make a few =)
		} elsif (!$char->{homunculus}{hungerThreshold}) {
			processFeeding();

		# auto-follow
		} elsif (
			$AI::Homunculus::homun_AI == 2
			&& AI::action eq "move"
			&& !$char->{sitting}
			&& !AI::args->{mapChanged}
			&& !AI::args->{time_move} != $char->{time_move}
			&& !timeOut(AI::args->{ai_move_giveup})
			&& $homun_dist < MAX_DISTANCE
			&& (AI::Homunculus::isIdle
				|| blockDistance(AI::args->{move_to}, $char->{homunculus}{pos_to}) >= MAX_DISTANCE)
			&& (!defined AI::Homunculus::findAction('route') || !AI::Homunculus::args(AI::Homunculus::findAction('route'))->{follow_route})
		) {
			AI::Homunculus::clear('move', 'route');
			if (!checkLineWalkable($char->{homunculus}{pos_to}, $char->{pos_to})) {
				homunculus_route($char->{pos_to}{x}, $char->{pos_to}{y});
				AI::Homunculus::args->{follow_route} = 1 if (AI::Homunculus::action eq 'route');
				debug sprintf("Homunculus follow route (distance: %.2f)\n", $char->{homunculus}->distance()), 'homunculus';

			} elsif (timeOut($char->{homunculus}{move_retry}, 0.5)) {
				# No update yet, send move request again.
				# We do this every 0.5 secs
				$char->{homunculus}{move_retry} = time;
				# NOTE:
				# The default LUA uses sendHomunculusStandBy() for the follow AI
				# however, the server-side routing is very inefficient
				# (e.g. can't route properly around obstacles and corners)
				# so we make use of the sendHomunculusMove() to make up for a more efficient routing
				$messageSender->sendHomunculusMove($char->{homunculus}{ID}, $char->{pos_to}{x}, $char->{pos_to}{y});
				debug sprintf("Homunculus follow move (distance: %.2f)\n", $char->{homunculus}->distance()), 'homunculus';
			}

		# homunculus is found
		} elsif ($char->{homunculus}{lost}) {
			if ($homun_dist < MAX_DISTANCE) {
				delete $char->{homunculus}{lost};
				delete $char->{homunculus}{lostRoute};
				my $action = AI::Homunculus::findAction('route');
				if (defined $action && AI::Homunculus::args($action)->{lost_route}) {
					for (my $i = 0; $i <= $action; $i++) {
						AI::Homunculus::dequeue
					}
				}
				if (timeOut($char->{homunculus}{standby_time}, 1)) {
					$messageSender->sendHomunculusStandBy($char->{homunculus}{ID});
					$char->{homunculus}{standby_time} = time;
				}
				message T("Found your Homunculus!\n"), 'homunculus';

			# attempt to find homunculus on it's last known coordinates
			} elsif ($AI == 2 && !$char->{homunculus}{lostRoute}) {
				if ($config{teleportAuto_lostHomunculus}) {
					message T("Teleporting to get homunculus back\n"), 'teleport';
					useTeleport(1);
				} else {
					my $x = $char->{homunculus}{pos_to}{x};
					my $y = $char->{homunculus}{pos_to}{y};
					my $distFromGoal = $config{homunculus_followDistanceMax};
					$distFromGoal = MAX_DISTANCE if ($distFromGoal > MAX_DISTANCE);
					main::ai_route($field{name}, $x, $y, distFromGoal => $distFromGoal, attackOnRoute => 1, noSitAuto => 1);
					AI::Homunculus::args->{lost_route} = 1 if (AI::Homunculus::action eq 'route');
					message TF("Trying to find your homunculus at location %d, %d (you are currently at %d, %d)\n", $x, $y, $char->{pos_to}{x}, $char->{pos_to}{y}), 'homunculus';
				}
				$char->{homunculus}{lostRoute} = 1;
			}

		# homunculus is lost
		} elsif ($homun_dist >= MAX_DISTANCE && !$char->{homunculus}{lost}) {
			$char->{homunculus}{lost} = 1;
			message T("You lost your Homunculus!\n"), 'homunculus';

		# if your homunculus is idle, make it move near you
		} elsif (
			$AI::Homunculus::homun_AI == 2
			&& AI::Homunculus::isIdle
			&& $homun_dist > ($config{homunculus_followDistanceMin} || 3)
			&& $homun_dist < MAX_DISTANCE
			&& timeOut($char->{homunculus}{standby_time}, 2)
		) {
			$messageSender->sendHomunculusStandBy($char->{homunculus}{ID});
			$char->{homunculus}{standby_time} = time;
			debug sprintf("Homunculus standby (distance: %.2f)\n", $char->{homunculus}->distance());

		# if you are idle, move near the homunculus
		} elsif (
			$AI == 2 && AI::isIdle && !AI::Homunculus::isIdle
			&& $config{homunculus_followDistanceMax}
			&& $homun_dist > $config{homunculus_followDistanceMax}
		) {
			main::ai_route($field{name}, $char->{homunculus}{pos_to}{x}, $char->{homunculus}{pos_to}{y}, distFromGoal => ($config{homunculus_followDistanceMin} || 3), attackOnRoute => 1, noSitAuto => 1);
			message TF("Your Homunculus moves too far (distance: %.2f) - Moving near your Homunculus\n", $char->{homunculus}->distance()), 'homunculus';

		# Main Homunculus AI
		} else {
			return if (!$AI::Homunculus::homun_AI);
			return if (processClientSuspend());
			processAttack();
			processRouteAI();
			processMove();
			return if ($AI::Homunculus::homun_AI != 2);
			processAutoAttack();
		}
	}
}

##
# ai_clientSuspend(packet_switch, duration, args...)
# initTimeout: a number of seconds.
#
# Freeze the AI for $duration seconds. $packet_switch and @args are only
# used internally and are ignored unless XKore mode is turned on.
sub homunculus_clientSuspend {
	my ($type, $duration, @args) = @_;
	my %args;
	$args{type} = $type;
	$args{time} = time;
	$args{timeout} = $duration;
	@{$args{args}} = @args;
	AI::Homunculus::queue("clientSuspend", \%args);
	debug "Homunculus AI suspended by clientSuspend for $args{timeout} seconds\n";
}

sub homunculus_setSuspend {
	my $index = shift;
	$index = 0 if ($index eq "");
	if ($index < @AI::Homunculus::homun_ai_seq_args) {
		$AI::Homunculus::homun_ai_seq_args[$index]{'suspended'} = time;
	}
}

sub homunculus_setMapChanged {
	my $index = shift;
	$index = 0 if ($index eq "");
	if ($index < @AI::Homunculus::homun_seq_args) {
		$AI::Homunculus::homun_seq_args[$index]{'mapChanged'} = time;
	}
}

sub homunculus_attack {
	my $ID = shift;
	#my $priorityAttack = shift;
	my %args;

	my $target = Actor::get($ID);

	$args{'ai_attack_giveup'}{'time'} = time;
	$args{'ai_attack_giveup'}{'timeout'} = $timeout{'ai_attack_giveup'}{'timeout'};
	$args{'ID'} = $ID;
	$args{'unstuck'}{'timeout'} = ($timeout{'ai_attack_unstuck'}{'timeout'} || 1.5);
	%{$args{'pos_to'}} = %{$target->{'pos_to'}};
	%{$args{'pos'}} = %{$target->{'pos'}};
	AI::Homunculus::queue("attack", \%args);

	#if ($priorityAttack) {
	#	message TF("Priority Attacking: %s\n", $target);
	#} else {
		message TF("Homunculus attacking: %s\n", $target), 'homunculus_attack';
	#}
}

sub homunculus_move {
	my $x = shift;
	my $y = shift;
	my $attackID = shift;
	my %args;
	my $dist;
	$args{move_to}{x} = $x;
	$args{move_to}{y} = $y;
	$args{attackID} = $attackID;
	$args{time_move} = $char->{homunculus}{time_move};
	$dist = distance($char->{homunculus}{pos}, $args{move_to});
	$args{ai_move_giveup}{timeout} = $timeout{ai_move_giveup}{timeout};

	if ($x == 0 && $y == 0) {
		error "BUG: move(0, 0) called!\n";
		return;
	}
	debug sprintf("Sending homunculus move from (%d,%d) to (%d,%d) - distance %.2f\n",
		$char->{homunculus}{pos}{x}, $char->{homunculus}{pos}{y}, $x, $y, $dist), "ai_move";
	AI::Homunculus::queue("move", \%args);
}

sub homunculus_route {
	my $map = $field{name};
	my $x = shift;
	my $y = shift;
	my %param = @_;
	debug "Homunculus on route to: $maps_lut{$map.'.rsw'}($map): $x, $y\n", "route";

	my %args;
	$x = int($x) if ($x ne "");
	$y = int($y) if ($y ne "");
	$args{'dest'}{'map'} = $map;
	$args{'dest'}{'pos'}{'x'} = $x;
	$args{'dest'}{'pos'}{'y'} = $y;
	$args{'maxRouteDistance'} = $param{maxRouteDistance} if exists $param{maxRouteDistance};
	$args{'maxRouteTime'} = $param{maxRouteTime} if exists $param{maxRouteTime};
	$args{'attackOnRoute'} = $param{attackOnRoute} if exists $param{attackOnRoute};
	$args{'distFromGoal'} = $param{distFromGoal} if exists $param{distFromGoal};
	$args{'pyDistFromGoal'} = $param{pyDistFromGoal} if exists $param{pyDistFromGoal};
	$args{'attackID'} = $param{attackID} if exists $param{attackID};
	$args{'noSitAuto'} = $param{noSitAuto} if exists $param{noSitAuto};
	$args{'noAvoidWalls'} = $param{noAvoidWalls} if exists $param{noAvoidWalls};
	$args{notifyUponArrival} = $param{notifyUponArrival} if exists $param{notifyUponArrival};
	$args{'tags'} = $param{tags} if exists $param{tags};
	$args{'time_start'} = time;

	if (!$param{'_internal'}) {
		$args{'solution'} = [];
		$args{'mapSolution'} = [];
	} elsif (exists $param{'_solution'}) {
		$args{'solution'} = $param{'_solution'};
	}

	# Destination is same map and isn't blocked by walls/water/whatever
	my $pos = calcPosition($char->{homunculus});
	require Task::Route;
	if ($param{'_internal'} || (Task::Route->getRoute(\@{$args{solution}}, $field, $pos, $args{dest}{pos}, !$args{noAvoidWalls}))) {
		# Since the solution array is here, we can start in "Route Solution Ready"
		$args{'stage'} = 'Route Solution Ready';
		debug "Homunculus route Solution Ready\n", "route";
		AI::Homunculus::queue("route", \%args);
	}
}

sub homunculus_stopAttack {
	#$messageSender->sendHomunculusStandBy($char->{homunculus}{ID});
	my $pos = calcPosition($char->{homunculus});
	$messageSender->sendHomunculusMove($char->{homunculus}{ID}, $pos->{x}, $pos->{y});
}

##### ATTACK #####
sub processAttack {
	#Benchmark::begin("ai_homunculus_attack") if DEBUG;

	if (AI::Homunculus::action eq "attack" && AI::Homunculus::args->{suspended}) {
		AI::Homunculus::args->{ai_attack_giveup}{time} += time - AI::Homunculus::args->{suspended};
		delete AI::Homunculus::args->{suspended};
	}

	if (AI::Homunculus::action eq "attack" && AI::Homunculus::args->{move_start}) {
		# We've just finished moving to the monster.
		# Don't count the time we spent on moving
		AI::Homunculus::args->{ai_attack_giveup}{time} += time - AI::Homunculus::args->{move_start};
		undef AI::Homunculus::args->{unstuck}{time};
		undef AI::Homunculus::args->{move_start};

	} elsif (AI::Homunculus::action eq "attack" && AI::Homunculus::args->{avoiding} && AI::Homunculus::args->{attackID}) {
		my $target = Actor::get(AI::Homunculus::args->{attackID});
		AI::Homunculus::args->{ai_attack_giveup}{time} = time + $target->{time_move_calc} + 3;
		undef AI::Homunculus::args->{avoiding};

	} elsif (((AI::Homunculus::action eq "route" && AI::Homunculus::action(1) eq "attack") || (AI::Homunculus::action eq "move" && AI::Homunculus::action(2) eq "attack"))
	   && AI::Homunculus::args->{attackID} && timeOut($AI::Homunculus::attack_route_adjust, 1)) {
		# We're on route to the monster; check whether the monster has moved
		my $ID = AI::Homunculus::args->{attackID};
		my $attackSeq = (AI::Homunculus::action eq "route") ? AI::Homunculus::args(1) : AI::Homunculus::args(2);
		my $target = Actor::get($ID);

		if ($target->{type} ne 'Unknown' && $attackSeq->{monsterPos} && %{$attackSeq->{monsterPos}}
		 && distance(calcPosition($target), $attackSeq->{monsterPos}) > $attackSeq->{attackMethod}{maxDistance}) {
			# Monster has moved; stop moving and let the attack AI readjust route
			AI::Homunculus::dequeue;
			AI::Homunculus::dequeue if (AI::Homunculus::action eq "route");

			$attackSeq->{ai_attack_giveup}{time} = time;
			debug "Homunculus target has moved more than $attackSeq->{attackMethod}{maxDistance} blocks; readjusting route\n", "ai_attack";

		} elsif ($target->{type} ne 'Unknown' && $attackSeq->{monsterPos} && %{$attackSeq->{monsterPos}}
		 && distance(calcPosition($target), calcPosition($char->{homunculus})) <= $attackSeq->{attackMethod}{maxDistance}) {
			# Monster is within attack range; stop moving
			AI::Homunculus::dequeue;
			AI::Homunculus::dequeue if (AI::Homunculus::action eq "route");

			$attackSeq->{ai_attack_giveup}{time} = time;
			debug "Homunculus target at ($attackSeq->{monsterPos}{x},$attackSeq->{monsterPos}{y}) is now within " .
				"$attackSeq->{attackMethod}{maxDistance} blocks; stop moving\n", "ai_attack";
		}
		$AI::Homunculus::attack_route_adjust = time;
	}

	if (AI::Homunculus::action eq "attack" &&
	    (timeOut(AI::Homunculus::args->{ai_attack_giveup}) ||
		 AI::Homunculus::args->{unstuck}{count} > 5) &&
		!$config{homunculus_attackNoGiveup}) {
		my $ID = AI::Homunculus::args->{ID};
		my $target = Actor::get($ID);
		$target->{homunculus_attack_failed} = time if ($monsters{$ID});
		AI::Homunculus::dequeue;
		message T("Homunculus can't reach or damage target, dropping target\n"), 'homunculus_attack';
		if ($config{homunculus_teleportAuto_dropTarget}) {
			message T("Teleport due to dropping homunculus attack target\n"), 'teleport';
			useTeleport(1);
		}

	} elsif (AI::Homunculus::action eq "attack" && !$monsters{AI::Homunculus::args->{ID}} && (!$players{AI::Homunculus::args->{ID}} || $players{AI::Homunculus::args->{ID}}{dead})) {
		# Monster died or disappeared
		$timeout{'ai_homunculus_attack'}{'time'} -= $timeout{'ai_homunculus_attack'}{'timeout'};
		my $ID = AI::Homunculus::args->{ID};
		AI::Homunculus::dequeue;

		if ($monsters_old{$ID} && $monsters_old{$ID}{dead}) {
			message T("Homunculus target died\n"), 'homunculus_attack';
			Plugins::callHook("homonulus_target_died");
			monKilled();

			# Pickup loot when monster's dead
			if ($AI == 2 && $config{itemsTakeAuto} && $monsters_old{$ID}{dmgFromPlayer}{$char->{homunculus}{ID}} > 0 && !$monsters_old{$ID}{homunculus_ignore}) {
				AI::clear("items_take");
				ai_items_take($monsters_old{$ID}{pos}{x}, $monsters_old{$ID}{pos}{y},
					$monsters_old{$ID}{pos_to}{x}, $monsters_old{$ID}{pos_to}{y});
			} else {
				# Cheap way to suspend all movement to make it look real
				homunculus_clientSuspend(0, $timeout{'ai_attack_waitAfterKill'}{'timeout'});
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
			message T("Homunculus target lost\n"), 'homunculus_attack';
		}

	} elsif (AI::Homunculus::action eq "attack") {
		# The attack sequence hasn't timed out and the monster is on screen

		# Update information about the monster and the current situation
		my $args = AI::Homunculus::args;
		my $ID = $args->{ID};
		my $target = Actor::get($ID);
		my $myPos = $char->{homunculus}{pos_to};
		my $monsterPos = $target->{pos_to};
		my $monsterDist = distance($myPos, $monsterPos);

		my ($realMyPos, $realMonsterPos, $realMonsterDist, $hitYou);
		my $realMyPos = calcPosition($char->{homunculus});
		my $realMonsterPos = calcPosition($target);
		my $realMonsterDist = distance($realMyPos, $realMonsterPos);
		if (!$config{homunculus_runFromTarget}) {
			$myPos = $realMyPos;
			$monsterPos = $realMonsterPos;
		}

		my $cleanMonster = checkMonsterCleanness($ID);


		# If the damage numbers have changed, update the giveup time so we don't timeout
		if ($args->{dmgToYou_last}   != $target->{dmgToPlayer}{$char->{homunculus}{ID}}
		 || $args->{missedYou_last}  != $target->{missedToPlayer}{$char->{homunculus}{ID}}
		 || $args->{dmgFromYou_last} != $target->{dmgFromPlayer}{$char->{homunculus}{ID}}) {
			$args->{ai_attack_giveup}{time} = time;
			debug "Update homunculus attack giveup time\n", "ai_attack", 2;
		}
		$hitYou = ($args->{dmgToYou_last} != $target->{dmgToPlayer}{$char->{homunculus}{ID}}
			|| $args->{missedYou_last} != $target->{missedToPlayer}{$char->{homunculus}{ID}});
		$args->{dmgToYou_last} = $target->{dmgToPlayer}{$char->{homunculus}{ID}};
		$args->{missedYou_last} = $target->{missedToPlayer}{$char->{homunculus}{ID}};
		$args->{dmgFromYou_last} = $target->{dmgFromPlayer}{$char->{homunculus}{ID}};
		$args->{missedFromYou_last} = $target->{missedFromPlayer}{$char->{homunculus}{ID}};

		$args->{attackMethod}{type} = "weapon";
		$args->{attackMethod}{maxDistance} = $config{homunculus_attackMaxDistance};
		$args->{attackMethod}{distance} = ($config{homunculus_runFromTarget} && $config{homunculus_runFromTarget_dist} > $config{homunculus_attackDistance}) ? $config{homunculus_runFromTarget_dist} : $config{homunculus_attackDistance};
		if ($args->{attackMethod}{maxDistance} < $args->{attackMethod}{distance}) {
			$args->{attackMethod}{maxDistance} = $args->{attackMethod}{distance};
		}

		if (!$cleanMonster) {
			# Drop target if it's already attacked by someone else
			$target->{homunculus_attack_failed} = time if ($monsters{$ID});
			message T("Dropping target - homunculus will not kill steal others\n"), 'homunculus_attack';
			$messageSender->sendHomunculusMove($char->{homunculus}{ID}, $realMyPos->{x}, $realMyPos->{y});
			AI::Homunculus::dequeue;
			if ($config{homunculus_teleportAuto_dropTargetKS}) {
				message T("Teleporting due to dropping homunculus attack target\n"), 'teleport';
				useTeleport(1);
			}

		} elsif ($config{homunculus_attackCheckLOS} &&
			 $args->{attackMethod}{distance} > 2 &&
			 !checkLineSnipable($realMyPos, $realMonsterPos)) {
			# We are a ranged attacker without LOS

			# Calculate squares around monster within shooting range, but not
			# closer than runFromTarget_dist
			my @stand = calcRectArea2($realMonsterPos->{x}, $realMonsterPos->{y},
						  $args->{attackMethod}{distance},
									  $config{homunculus_runFromTarget} ? $config{homunculus_runFromTarget_dist} : 0);

			# Determine which of these spots are snipable
			my $best_spot;
			my $best_dist;
			for my $spot (@stand) {
				# Is this spot acceptable?
				# 1. It must have LOS to the target ($realMonsterPos).
				# 2. It must be within $config{followDistanceMax} of
				#    $masterPos, if we have a master.
				if (checkLineSnipable($spot, $realMonsterPos) &&
				    (distance($spot, $char->{pos_to}) <= 15)) {
					# FIXME: use route distance, not pythagorean distance
					my $dist = distance($realMyPos, $spot);
					if (!defined($best_dist) || $dist < $best_dist) {
						$best_dist = $dist;
						$best_spot = $spot;
					}
				}
			}

			# Move to the closest spot
			my $msg = "Homunculus has no LOS from ($realMyPos->{x}, $realMyPos->{y}) to target ($realMonsterPos->{x}, $realMonsterPos->{y})";
			if ($best_spot) {
				message TF("%s; moving to (%s, %s)\n", $msg, $best_spot->{x}, $best_spot->{y}), 'homunculus_attack';
				homunculus_route($best_spot->{x}, $best_spot->{y});
			} else {
				warning TF("%s; no acceptable place for homunculus to stand\n", $msg);
				AI::Homunculus::dequeue;
			}

		} elsif ($config{homunculus_runFromTarget} && ($monsterDist < $config{homunculus_runFromTarget_dist} || $hitYou)) {
			#my $begin = time;
			# Get a list of blocks that we can run to
			my @blocks = calcRectArea($myPos->{x}, $myPos->{y},
				# If the monster hit you while you're running, then your recorded
				# location may be out of date. So we use a smaller distance so we can still move.
				($hitYou) ? $config{homunculus_runFromTarget_dist} / 2 : $config{homunculus_runFromTarget_dist});

			# Find the distance value of the block that's farthest away from a wall
			my $highest;
			foreach (@blocks) {
				my $dist = ord(substr($field{dstMap}, $_->{y} * $field{width} + $_->{x}));
				if (!defined $highest || $dist > $highest) {
					$highest = $dist;
				}
			}

			# Get rid of rediculously large route distances (such as spots that are on a hill)
			# Get rid of blocks that are near a wall
			my $pathfinding = new PathFinding;
			use constant AVOID_WALLS => 4;
			for (my $i = 0; $i < @blocks; $i++) {
				# We want to avoid walls (so we don't get cornered), if possible
				my $dist = ord(substr($field{dstMap}, $blocks[$i]{y} * $field{width} + $blocks[$i]{x}));
				if ($highest >= AVOID_WALLS && $dist < AVOID_WALLS) {
					delete $blocks[$i];
					next;
				}

				$pathfinding->reset(
					field => $field,
					start => $myPos,
					dest => $blocks[$i]);
				my $ret = $pathfinding->runcount;
				if ($ret <= 0 || $ret > $config{homunculus_runFromTarget_dist} * 2) {
					delete $blocks[$i];
					next;
				}
			}

			# Find the block that's farthest to us
			my $largestDist;
			my $bestBlock;
			foreach (@blocks) {
				next unless defined $_;
				my $dist = distance($monsterPos, $_);
				if (!defined $largestDist || $dist > $largestDist) {
					$largestDist = $dist;
					$bestBlock = $_;
				}
			}

			#message "Time spent: " . (time - $begin) . "\n";
			#debug_showSpots('runFromTarget', \@blocks, $bestBlock);
			AI::Homunculus::args->{avoiding} = 1;
			homunculus_move($bestBlock->{x}, $bestBlock->{y}, $ID);

		} elsif (!$config{homunculus_runFromTarget} && $monsterDist > $args->{attackMethod}{maxDistance}
		  && timeOut($args->{ai_attack_giveup}, 0.5)) {
			# The target monster moved; move to target
			$args->{move_start} = time;
			$args->{monsterPos} = {%{$monsterPos}};

			# Calculate how long it would take to reach the monster.
			# Calculate where the monster would be when you've reached its
			# previous position.
			my $time_needed;
			if (objectIsMovingTowards($target, $char->{homunculus}, 45)) {
				$time_needed = $monsterDist * $char->{homunculus}{walk_speed};
			} else {
				# If monster is not moving towards you, then you need more time to walk
				$time_needed = $monsterDist * $char->{homunculus}{walk_speed} + 2;
			}
			my $pos = calcPosition($target, $time_needed);

			my $dist = sprintf("%.1f", $monsterDist);
			debug "Homunculus target distance $dist is >$args->{attackMethod}{maxDistance}; moving to target: " .
				"from ($myPos->{x},$myPos->{y}) to ($pos->{x},$pos->{y})\n", "ai_attack";

			my $result = homunculus_route($pos->{x}, $pos->{y},
				distFromGoal => $args->{attackMethod}{distance},
				maxRouteTime => $config{homunculus_attackMaxRouteTime},
				attackID => $ID,
				noMapRoute => 1,
				noAvoidWalls => 1);
			if (!$result) {
				# Unable to calculate a route to target
				$target->{homunculus_attack_failed} = time;
				AI::Homunculus::dequeue;
 				message T("Unable to calculate a route to homunculus target, dropping target\n"), 'homunculus_attack';
				if ($config{homunculus_teleportAuto_dropTarget}) {
					message T("Teleport due to dropping homunculus attack target\n"), 'teleport';
					useTeleport(1);
				}
			}

		} elsif ((!$config{homunculus_runFromTarget} || $realMonsterDist >= $config{homunculus_runFromTarget_dist})
		 && (!$config{homunculus_tankMode} || !$target->{dmgFromPlayer}{$char->{homunculus}{ID}})) {
			# Attack the target. In case of tanking, only attack if it hasn't been hit once.
			if (!AI::Homunculus::args->{firstAttack}) {
				AI::Homunculus::args->{firstAttack} = 1;
				my $dist = sprintf("%.1f", $monsterDist);
				my $pos = "$myPos->{x},$myPos->{y}";
				debug "Homunculus is ready to attack target (which is $dist blocks away); we're at ($pos)\n", "ai_attack";
			}

			$args->{unstuck}{time} = time if (!$args->{unstuck}{time});
			if (!$target->{dmgFromPlayer}{$char->{homunculus}{ID}} && timeOut($args->{unstuck})) {
				# We are close enough to the target, and we're trying to attack it,
				# but some time has passed and we still haven't dealed any damage.
				# Our recorded position might be out of sync, so try to unstuck
				$args->{unstuck}{time} = time;
				debug("Homunculus attack - trying to unstuck\n", "ai_attack");
				homunculus_move($myPos->{x}, $myPos->{y});
				$args->{unstuck}{count}++;
			}

			if ($args->{attackMethod}{type} eq "weapon" && timeOut($timeout{ai_homunculus_attack})) {
				$messageSender->sendHomunculusAttack($char->{homunculus}{ID}, $ID);#,
					#($config{homunculus_tankMode}) ? 0 : 7);
				$timeout{ai_homunculus_attack}{time} = time;
				delete $args->{attackMethod};
			}

		} elsif ($config{homunculus_tankMode}) {
			if ($args->{'dmgTo_last'} != $target->{dmgFromPlayer}{$char->{homunculus}{ID}}) {
				$args->{'ai_attack_giveup'}{'time'} = time;
			}
			$args->{'dmgTo_last'} = $target->{dmgFromPlayer}{$char->{homunculus}{ID}};
		}
	}

	# Check for kill steal while moving
	if (AI::Homunculus::is("move", "route") && AI::Homunculus::args->{attackID} && AI::Homunculus::inQueue("attack")) {
		my $ID = AI::Homunculus::args->{attackID};
		if ((my $target = $monsters{$ID}) && !checkMonsterCleanness($ID)) {
			$target->{homunculus_attack_failed} = time;
			message T("Dropping target - homunculus will not kill steal others\n"), 'homunculus_attack';
			homunculus_stopAttack();
			$monsters{$ID}{homunculus_ignore} = 1;

			# Right now, the queue is either
			#   move, route, attack
			# -or-
			#   route, attack
			AI::Homunculus::dequeue;
			AI::Homunculus::dequeue;
			AI::Homunculus::dequeue if (AI::Homunculus::action eq "attack");
			if ($config{homunculus_teleportAuto_dropTargetKS}) {
				message T("Teleport due to dropping homunculus attack target\n"), 'teleport';
				useTeleport(1);
			}
		}
	}

	#Benchmark::end("ai_homunculus_attack") if DEBUG;
}

####### ROUTE #######
sub processRouteAI {
	if (AI::Homunculus::action eq "route" && AI::Homunculus::args->{suspended}) {
		AI::Homunculus::args->{time_start} += time - AI::Homunculus::args->{suspended};
		AI::Homunculus::args->{time_step} += time - AI::Homunculus::args->{suspended};
		delete AI::Homunculus::args->{suspended};
	}

	if (AI::Homunculus::action eq "route" && $field{'name'} && $char->{homunculus}{pos_to}{x} ne '' && $char->{homunculus}{pos_to}{y} ne '') {
		my $args = AI::Homunculus::args;

		if ( $args->{maxRouteTime} && timeOut($args->{time_start}, $args->{maxRouteTime})) {
			# We spent too much time
			debug "Homunculus route - we spent too much time; bailing out.\n", "route";
			AI::Homunculus::dequeue;

		} elsif ($field{name} ne $args->{dest}{map} || $args->{mapChanged}) {
			debug "Homunculus map changed: $field{name} $args->{dest}{map}\n", "route";
			AI::Homunculus::dequeue;

		} elsif ($args->{stage} eq '') {
			my $pos = calcPosition($char->{homunculus});
			$args->{solution} = [];
			if (Task::Route->getRoute($args->{solution}, $field, $pos, $args->{dest}{pos})) {
				$args->{stage} = 'Route Solution Ready';
				debug "Homunculus route Solution Ready\n", "route";
			} else {
				debug "Something's wrong; there is no path to $field{name}($args->{dest}{pos}{x},$args->{dest}{pos}{y}).\n", "debug";
				AI::Homunculus::dequeue;
			}

		} elsif ($args->{stage} eq 'Route Solution Ready') {
			my $solution = $args->{solution};
			if ($args->{maxRouteDistance} > 0 && $args->{maxRouteDistance} < 1) {
				# Fractional route motion
				$args->{maxRouteDistance} = int($args->{maxRouteDistance} * scalar(@{$solution}));
			}
			splice(@{$solution}, 1 + $args->{maxRouteDistance}) if $args->{maxRouteDistance} && $args->{maxRouteDistance} < @{$solution};

			# Trim down solution tree for pyDistFromGoal or distFromGoal
			if ($args->{pyDistFromGoal}) {
				my $trimsteps = 0;
				$trimsteps++ while ($trimsteps < @{$solution}
						 && distance($solution->[@{$solution} - 1 - $trimsteps], $solution->[@{$solution} - 1]) < $args->{pyDistFromGoal}
					);
				debug "Homunculus route - trimming down solution by $trimsteps steps for pyDistFromGoal $args->{'pyDistFromGoal'}\n", "route";
				splice(@{$args->{'solution'}}, -$trimsteps) if ($trimsteps);
			} elsif ($args->{distFromGoal}) {
				my $trimsteps = $args->{distFromGoal};
				$trimsteps = @{$args->{'solution'}} if $trimsteps > @{$args->{'solution'}};
				debug "Homunculus route - trimming down solution by $trimsteps steps for distFromGoal $args->{'distFromGoal'}\n", "route";
				splice(@{$args->{solution}}, -$trimsteps) if ($trimsteps);
			}

			undef $args->{mapChanged};
			undef $args->{index};
			undef $args->{old_x};
			undef $args->{old_y};
			undef $args->{new_x};
			undef $args->{new_y};
			$args->{time_step} = time;
			$args->{stage} = 'Walk the Route Solution';

		} elsif ($args->{stage} eq 'Walk the Route Solution') {

			my $pos = calcPosition($char->{homunculus});
			my ($cur_x, $cur_y) = ($pos->{x}, $pos->{y});

			unless (@{$args->{solution}}) {
				# No more points to cover; we've arrived at the destination
				if ($args->{notifyUponArrival}) {
 					message T("Homunculus destination reached.\n"), "success";
				} else {
					debug "Homunculus destination reached.\n", "route";
				}
				AI::Homunculus::dequeue;

			} elsif ($args->{old_x} == $cur_x && $args->{old_y} == $cur_y && timeOut($args->{time_step}, 3)) {
				# We tried to move for 3 seconds, but we are still on the same spot,
				# decrease step size.
				# However, if $args->{index} was already 0, then that means
				# we were almost at the destination (only 1 more step is needed).
				# But we got interrupted (by auto-attack for example). Don't count that
				# as stuck.
				my $wasZero = $args->{index} == 0;
				$args->{index} = int($args->{index} * 0.8);
				if ($args->{index}) {
					debug "Homunculus route - not moving, decreasing step size to $args->{index}\n", "route";
					if (@{$args->{solution}}) {
						# If we still have more points to cover, walk to next point
						$args->{index} = @{$args->{solution}} - 1 if $args->{index} >= @{$args->{solution}};
						$args->{new_x} = $args->{solution}[$args->{index}]{x};
						$args->{new_y} = $args->{solution}[$args->{index}]{y};
						$args->{time_step} = time;
						homunculus_move($args->{new_x}, $args->{new_y}, $args->{attackID});
					}
				} elsif (!$wasZero) {
					# We're stuck
					my $msg = TF("Homunculus is stuck at %s (%d,%d), while walking from (%d,%d) to (%d,%d).", 
						$field{name}, $char->{homunculus}{pos_to}{x}, $char->{homunculus}{pos_to}{y}, $cur_x, $cur_y, $args->{dest}{pos}{x}, $args->{dest}{pos}{y});
					$msg .= T(" Teleporting to unstuck.") if $config{homunculus_teleportAuto_unstuck};
					$msg .= "\n";
					warning $msg, "route";
					useTeleport(1) if $config{homunculus_teleportAuto_unstuck};
					AI::Homunculus::dequeue;
				} else {
					$args->{time_step} = time;
				}

			} else {
				# We're either starting to move or already moving, so send out more
				# move commands periodically to keep moving and updating our position
				my $solution = $args->{solution};
				$args->{index} = $config{homunculus_route_step} unless $args->{index};
				$args->{index}++ if ($args->{index} < $config{homunculus_route_step});

				if (defined($args->{old_x}) && defined($args->{old_y})) {
					# See how far we've walked since the last move command and
					# trim down the soultion tree by this distance.
					# Only remove the last step if we reached the destination
					my $trimsteps = 0;
					# If position has changed, we must have walked at least one step
					$trimsteps++ if ($cur_x != $args->{'old_x'} || $cur_y != $args->{'old_y'});
					# Search the best matching entry for our position in the solution
					while ($trimsteps < @{$solution}
							 && distance( { x => $cur_x, y => $cur_y }, $solution->[$trimsteps + 1])
							    < distance( { x => $cur_x, y => $cur_y }, $solution->[$trimsteps])
						) {
						$trimsteps++;
					}
					# Remove the last step also if we reached the destination
					$trimsteps = @{$solution} - 1 if ($trimsteps >= @{$solution});
					#$trimsteps = @{$solution} if ($trimsteps <= $args->{'index'} && $args->{'new_x'} == $cur_x && $args->{'new_y'} == $cur_y);
					$trimsteps = @{$solution} if ($cur_x == $solution->[$#{$solution}]{x} && $cur_y == $solution->[$#{$solution}]{y});
					debug "Homunculus route - trimming down solution (" . @{$solution} . ") by $trimsteps steps\n", "route";
					splice(@{$solution}, 0, $trimsteps) if ($trimsteps > 0);
				}

				my $stepsleft = @{$solution};
				if ($stepsleft > 0) {
					# If we still have more points to cover, walk to next point
					$args->{index} = $stepsleft - 1 if ($args->{index} >= $stepsleft);
					$args->{new_x} = $args->{solution}[$args->{index}]{x};
					$args->{new_y} = $args->{solution}[$args->{index}]{y};

					# But first, check whether the distance of the next point isn't abnormally large.
					# If it is, then we've moved to an unexpected place. This could be caused by auto-attack,
					# for example.
					my %nextPos = (x => $args->{new_x}, y => $args->{new_y});
					if (distance(\%nextPos, $pos) > $config{homunculus_route_step}) {
						debug "Homunculus route - movement interrupted: reset route\n", "route";
						$args->{stage} = '';

					} else {
						$args->{old_x} = $cur_x;
						$args->{old_y} = $cur_y;
						$args->{time_step} = time if ($cur_x != $args->{old_x} || $cur_y != $args->{old_y});
						debug "Homunculus route - next step moving to ($args->{new_x}, $args->{new_y}), index $args->{index}, $stepsleft steps left\n", "route";
						homunculus_move($args->{new_x}, $args->{new_y}, $args->{attackID});
					}
				} else {
					# No more points to cover
					if ($args->{notifyUponArrival}) {
 						message T("Homunculus destination reached.\n"), "success";
					} else {
						debug "Homunculus destination reached.\n", "route";
					}
					AI::Homunculus::dequeue;
				}
			}

		} else {
			debug "Unexpected homunculus route stage [$args->{stage}] occured.\n", "route";
			AI::Homunculus::dequeue;
		}
	}
}

##### MOVE #####
sub processMove {
	if (AI::Homunculus::action eq "move") {
		my $args = AI::Homunculus::args();
		$args->{ai_move_giveup}{time} = time unless $args->{ai_move_giveup}{time};

		# Stop if the map changed
		if ($args->{mapChanged}) {
			debug "Homunculus move - map change detected\n", "ai_move";
			AI::Homunculus::dequeue;

		# Stop if we've moved
		} elsif ($args->{time_move} != $char->{homunculus}{time_move}) {
			debug "Homunculus move - moving\n", "ai_move";
			AI::Homunculus::dequeue;

		# Stop if we've timed out
		} elsif (timeOut($args->{ai_move_giveup})) {
			debug "Homunculus move - timeout\n", "ai_move";
			AI::Homunculus::dequeue;

		} elsif (timeOut($char->{homunculus}{move_retry}, 0.5)) {
			# No update yet, send move request again.
			# We do this every 0.5 secs
			$char->{homunculus}{move_retry} = time;
			$messageSender->sendHomunculusMove($char->{homunculus}{ID}, $args->{move_to}{x}, $args->{move_to}{y});
		}
	}
}

sub processClientSuspend {
	##### CLIENT SUSPEND #####
	# The clientSuspend AI sequence is used to freeze all other AI activity
	# for a certain period of time.

	if (AI::Homunculus::action eq 'clientSuspend' && timeOut(AI::Homunculus::args)) {
		debug "Homunculus AI suspend by clientSuspend dequeued\n";
		AI::Homunculus::dequeue;
	} elsif (AI::Homunculus::action eq "clientSuspend" && $net->clientAlive()) {
		# When XKore mode is turned on, clientSuspend will increase it's timeout
		# every time the user tries to do something manually.
		my $args = AI::Homunculus::args;

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
	# The auto-attack logic is as follows:
	# 1. Generate a list of monsters that we are allowed to attack.
	# 2. Pick the "best" monster out of that list, and attack it.

	#Benchmark::begin("ai_homunculus_autoAttack") if DEBUG;

	if (((AI::Homunculus::isIdle || AI::Homunculus::action eq 'route') && (AI::isIdle || AI::is(qw(follow sitAuto take items_gather items_take attack skill_use))))
	     # Don't auto-attack monsters while taking loot, and itemsTake/GatherAuto >= 2
	  && timeOut($timeout{ai_homunculus_attack_auto})
	  && (!$config{homunculus_attackAuto_notInTown} || !$cities_lut{$field{name}.'.rsw'})) {

		# If we're in tanking mode, only attack something if the person we're tanking for is on screen.
		my $foundTankee;
		if ($config{homunculus_tankMode}) {
			if ($config{homunculus_tankModeTarget} eq $char->{name}) {
				$foundTankee = 1;
			} else {
				foreach (@playersID) {
					next if (!$_);
					if ($config{homunculus_tankModeTarget} eq $players{$_}{'name'}) {
						$foundTankee = 1;
						last;
					}
				}
			}
		}

		my $attackTarget;
		my $priorityAttack;

		if (!$config{homunculus_tankMode} || $foundTankee) {
			# This variable controls how far monsters must be away from portals and players.
			my $portalDist = $config{'attackMinPortalDistance'} || 4;
			my $playerDist = $config{'attackMinPlayerDistance'};
			$playerDist = 1 if ($playerDist < 1);
		
			my $routeIndex = AI::Homunculus::findAction("route");
			my $attackOnRoute;
			if (defined $routeIndex) {
				$attackOnRoute = AI::Homunculus::args($routeIndex)->{attackOnRoute};
			} else {
				$attackOnRoute = 2;
			}

			### Step 1: Generate a list of all monsters that we are allowed to attack. ###
			my @aggressives;
			my @partyMonsters;
			my @cleanMonsters;

			# List aggressive monsters
			@aggressives = ai_getPlayerAggressives($char->{homunculus}{ID}) if ($config{homunculus_attackAuto} && $attackOnRoute);

			# There are two types of non-aggressive monsters. We generate two lists:
			foreach (@monstersID) {
				next if (!$_ || !checkMonsterCleanness($_));
				my $monster = $monsters{$_};
				# Ignore ignored monsters in mon_control.txt
				if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
					next if ( ($control->{attack_auto} ne "" && $control->{attack_auto} <= 0)
						|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
						|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
						|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
						|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
						);
				}

				my $pos = calcPosition($monster);

				# List monsters that party members are attacking
				if ($config{homunculus_attackAuto_party} && $attackOnRoute
				 && ((($monster->{dmgFromYou} || $monster->{dmgFromParty}) && $config{homunculus_attackAuto_party} != 2) ||
				     $monster->{dmgToYou} || $monster->{dmgToParty} || $monster->{missedYou} || $monster->{missedToParty})
				 && timeOut($monster->{homunculus_attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @partyMonsters, $_;
					next;
				}

				### List normal, non-aggressive monsters. ###

				# Ignore monsters that
				# - Have a status (such as poisoned), because there's a high chance
				#   they're being attacked by other players
				# - Are inside others' area spells (this includes being trapped).
				# - Are moving towards other players.
				# - Are behind a wall
				next if (( $monster->{statuses} && scalar(keys %{$monster->{statuses}}) )
					|| objectInsideSpell($monster)
					|| objectIsMovingTowardsPlayer($monster));
				if ($config{homunculus_attackCanSnipe}) {
					next if (!checkLineSnipable($char->{homunculus}{pos_to}, $pos));
				} else {
					next if (!checkLineWalkable($char->{homunculus}{pos_to}, $pos));
				}

				my $safe = 1;
				if ($config{homunculus_attackAuto_onlyWhenSafe}) {
					foreach (@playersID) {
						next if ($_ eq $char->{homunculus}{ID});
						if ($_ && !$char->{party}{users}{$_}) {
							$safe = 0;
							last;
						}
					}
				}

				if ($config{homunculus_attackAuto} >= 2
				 && $attackOnRoute >= 2 && !$monster->{dmgFromYou} && $safe
				 && !positionNearPlayer($pos, $playerDist) && !positionNearPortal($pos, $portalDist)
				 && timeOut($monster->{homunculus_attack_failed}, $timeout{ai_attack_unfail}{timeout})) {
					push @cleanMonsters, $_;
				}
			}


			### Step 2: Pick out the "best" monster ###

			my $myPos = calcPosition($char->{homunculus});
			my $highestPri;

			# Look for the aggressive monster that has the highest priority
			foreach (@aggressives) {
				my $monster = $monsters{$_};
				my $pos = calcPosition($monster);
				# Don't attack monsters near portals
				next if (positionNearPortal($pos, $portalDist));

				# Don't attack ignored monsters
				if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
					next if ( ($control->{attack_auto} == -1)
						|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
						|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
						|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
						|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
						);
				}

				my $name = lc $monster->{name};
				if (defined($priority{$name}) && $priority{$name} > $highestPri) {
					$highestPri = $priority{$name};
				}
			}

			my $smallestDist;
			if (!defined $highestPri) {
				# If not found, look for the closest aggressive monster (without priority)
				foreach (@aggressives) {
					my $monster = $monsters{$_};
					next if !timeOut($monster->{homunculus_attack_failed}, $timeout{ai_attack_unfail}{timeout});
					my $pos = calcPosition($monster);
					# Don't attack monsters near portals
					next if (positionNearPortal($pos, $portalDist));

					# Don't attack ignored monsters
					if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
						next if ( ($control->{attack_auto} == -1)
							|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
							|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
							|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
							|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
							);
					}

					if (!defined($smallestDist) || (my $dist = distance($myPos, $pos)) < $smallestDist) {
						$smallestDist = $dist;
						$attackTarget = $_;
					}
				}
			} else {
				# If found, look for the closest aggressive monster with the highest priority
				foreach (@aggressives) {
					my $monster = $monsters{$_};
					my $pos = calcPosition($monster);
					# Don't attack monsters near portals
					next if (positionNearPortal($pos, $portalDist));

					# Don't attack ignored monsters
					if ((my $control = mon_control($monster->{name},$monster->{nameID}))) {
						next if ( ($control->{attack_auto} == -1)
							|| ($control->{attack_lvl} ne "" && $control->{attack_lvl} > $char->{lv})
							|| ($control->{attack_jlvl} ne "" && $control->{attack_jlvl} > $char->{lv_job})
							|| ($control->{attack_hp}  ne "" && $control->{attack_hp} > $char->{hp})
							|| ($control->{attack_sp}  ne "" && $control->{attack_sp} > $char->{sp})
							);
					}

					my $name = lc $monster->{name};
					if ((!defined($smallestDist) || (my $dist = distance($myPos, $pos)) < $smallestDist)
					  && $priority{$name} == $highestPri) {
						$smallestDist = $dist;
						$attackTarget = $_;
						$priorityAttack = 1;
					}
				}
			}

			if (!$attackTarget) {
				undef $smallestDist;
				# There are no aggressive monsters; look for the closest monster that a party member/master is attacking
				foreach (@partyMonsters) {
					my $monster = $monsters{$_};
					my $pos = calcPosition($monster);
					if (!defined($smallestDist) || (my $dist = distance($myPos, $pos)) < $smallestDist) {
						$smallestDist = $dist;
						$attackTarget = $_;
					}
				}
			}

			if (!$attackTarget) {
				# No party monsters either; look for the closest, non-aggressive monster that:
				# 1) nobody's attacking
				# 2) has the highest priority

				undef $smallestDist;
				foreach (@cleanMonsters) {
					my $monster = $monsters{$_};
					next unless $monster;
					my $pos = calcPosition($monster);
					my $dist = distance($myPos, $pos);
					my $name = lc $monster->{name};

					if (!defined($smallestDist) || $priority{$name} > $highestPri
					  || ( $priority{$name} == $highestPri && $dist < $smallestDist )) {
						$smallestDist = $dist;
						$attackTarget = $_;
						$highestPri = $priority{$monster};
					}
				}
			}
		}
		# If an appropriate monster's found, attack it. If not, wait ai_attack_auto secs before searching again.
		if ($attackTarget) {
			homunculus_setSuspend(0);
			homunculus_attack($attackTarget, $priorityAttack);
		} else {
			$timeout{'ai_homunculus_attack_auto'}{'time'} = time;
		}
	}

	#Benchmark::end("ai_homunculus_autoAttack") if DEBUG;
}

1;
