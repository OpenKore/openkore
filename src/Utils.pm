#########################################################################
#  OpenKore - Utility Functions
#
#  Copyright (c) 2004,2005,2006,2007 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Utility functions
#
# This module contains various general-purpose and independant utility
# functions. Functions in this module should have <b>no</b> dependancies
# on other Kore modules.

package Utils;

use strict;
use Time::HiRes qw(time usleep);
use IO::Socket::INET;
use Math::Trig;
use Text::Wrap;
use Scalar::Util;
use Exporter;
use base qw(Exporter);
use Config;
use FastUtils;

use Globals qw($masterServer);
use Utils::DataStructures (':all', '!/^binFind$/');


our @EXPORT = (
	@{$Utils::DataStructures::EXPORT_TAGS{all}},

	# Math
	qw(get_client_solution get_client_easy_solution get_solution calcPosFromPathfinding calcTimeFromPathfinding calcStepsWalkedFromTimeAndSolution calcTimeFromSolution
	calcPosFromTime calcTime calcPosition
	checkMovementDirection
	distance blockDistance specifiedBlockDistance adjustedBlockDistance getClientDist canAttack
	intToSignedInt intToSignedShort
	getVector moveAlong moveAlongVector
	normalize vectorToDegree max min round ceil),
	# OS-specific
	qw(checkLaunchedApp launchApp launchScript),
	# Other stuff
	qw(dataWaiting dumpHash formatNumber getCoordString getCoordString2
	getFormattedDate getFormattedDateShort getHex giveHex getRange getTickCount
	inRange judgeSkillArea makeCoordsDir makeCoordsXY makeCoordsFromTo makeDistMap makeIP encodeIP parseArgs parse_portal_conversation_args
	quarkToString stringToQuark shiftPack swrite timeConvert timeOut
	urldecode urlencode unShiftPack vocalString wrapText pin_encode)
);

our %strings;
our %quarks;

use constant {
	MOVE_COST => 10,
	MOVE_DIAGONAL_COST => 14,
};

################################
################################
### CATEGORY: Math
################################
################################

##
# get_client_solution(field, pos, pos_to)
#
# Returns: the walking path from $pos to $pos_to using the A* pathfinding
#
# Reference: hercules src\map\path.c path_search
sub get_client_solution {
	my ($field, $pos, $pos_to) = @_;

	my $solution = [];

	# Optimization so we don't need to call the Pathfinding just to get this cell
	if ($pos->{x} == $pos_to->{x} && $pos->{y} == $pos_to->{y}) {
		push(@{$solution}, { x => $pos->{x}, y => $pos->{y} });
		return $solution;
	}

	# Game client uses the same A* Pathfinding as openkore but uses and inadmissible heuristic (Manhattan distance)
	# To better simulate the client pathfinding we tell openkore's pathfinding to use the same Manhattan heuristic
	# We also deactivate any custom pathfinding weights (randomFactor, avoidWalls, customWeights)
	# TODO: This 35 probably should be something dynamic like (max(abs(pos_x-posto_x),abs(pos_y-posto_y)))
	my ($min_pathfinding_x, $min_pathfinding_y, $max_pathfinding_x, $max_pathfinding_y) = $field->getSquareEdgesFromCoord($pos, 35);
	my $dist_path = new PathFinding(
		field => $field,
		start => $pos,
		dest => $pos_to,
		avoidWalls => 0,
		randomFactor => 0,
		useManhattan => 1,
		min_x => $min_pathfinding_x,
		max_x => $max_pathfinding_x,
		min_y => $min_pathfinding_y,
		max_y => $max_pathfinding_y
	)->run($solution);
	return $solution;
}

##
# get_client_easy_solution(pos, pos_to)
#
# Returns: the walking path from $pos to $pos_to using "easy path search"
#
# Walls and pathfinding are not considered.
# Obstacles should be checked using Field::checkPathFree
#
# Reference: hercules src\map\path.c path_search - flag&1
sub get_client_easy_solution {
	my ($pos, $pos_to) = @_;

	my $posX = $$pos{x};
	my $posY = $$pos{y};
	my $pos_toX = $$pos_to{x};
	my $pos_toY = $$pos_to{y};

	# 1 - vertical or horizontal
	# 2 - diagonal
	my $stepType = 0;

	my $solution = [];

	while (1) {
		push(@{$solution}, { x => $posX, y => $posY });

		$stepType = 0;
		if ($posX < $pos_toX) {
			$posX++;
			$stepType++;
		}
		if ($posX > $pos_toX) {
			$posX--;
			$stepType++;
		}
		if ($posY < $pos_toY) {
			$posY++;
			$stepType++;
		}
		if ($posY > $pos_toY) {
			$posY--;
			$stepType++;
		}

		if ($stepType == 2) {
			next;
		} elsif ($stepType == 1) {
			next;
		}

		# $stepType == 0 then $pos == $pos_to
		last;
	}

	return $solution;
}

##
# get_solution(field, pos, pos_to)
#
# Returns: the walking path from $pos to $pos_to
#
# Wrapper that checks if an easy solution is possible, if it is then return easy solution, if it isn't then return client solution
sub get_solution {
	my ($field, $pos, $pos_to) = @_;

	# If there are no obstacles between Pos and PosTo use calcPosFromTime to save time.
	if ($field->checkPathFree($pos, $pos_to)) {
		return get_client_easy_solution($pos, $pos_to);

	# If there are obstacles then use the client pathfinding to solve it
	} else {
		return get_client_solution($field, $pos, $pos_to);
	}
}

# Currently the go-to function to get the position of a given actor on critical ocasions (eg. Attack logic)
sub calcPosFromPathfinding {
	my ($field, $actor, $extra_time) = @_;
	my $speed = ($actor->{walk_speed} || 0.12);
	my $time = time - $actor->{time_move} + $extra_time;

	# If Pos and PosTo are the same return Pos
	if ($actor->{pos}{x} == $actor->{pos_to}{x} && $actor->{pos}{y} == $actor->{pos_to}{y}) {
		return $actor->{pos};
	}

	my $solution;

	# If the actor is the character then we should have already saved the time calc and solution at Receive.pm::character_moves
	if (UNIVERSAL::isa($actor, "Actor::You")) {
		if ($time >= $actor->{time_move_calc}) {
			return $actor->{pos_to};
		}
		$solution = $actor->{solution};

	} else {
		$solution = get_solution($field, $actor->{pos}, $actor->{pos_to});
	}

	my $steps_walked = calcStepsWalkedFromTimeAndSolution($solution, $speed, $time);

	my $pos = $solution->[$steps_walked];

	return $pos;
}

# Wrapper for calcTimeFromSolution so you don't need to call get_client_solution and calcTimeFromSolution when you only need the time
# Used in Misc::meetingPosition to calculate if the target would have time to catch-up with the character when running away from it
sub calcTimeFromPathfinding {
	my ($field, $pos, $pos_to, $speed) = @_;

	if ($pos->{x} == $pos_to->{x} && $pos->{y} == $pos_to->{y}) {
		return 0;
	}

	my $solution = get_solution($field, $pos, $pos_to);

	my $summed_time = calcTimeFromSolution($solution, $speed);
	return $summed_time;
}

# Returns:
# -1: No LOS
#  0: out of range
#  1: sucess
#
# Reference: hercules src\map\battle.c battle_check_range
sub canAttack {
	my ($field, $pos1, $pos2, $attackCanSnipe, $range, $clientSight) = @_;

	my $distance = blockDistance($pos1, $pos2);
	return 1 if ($distance < 2);

	# hercules conf\map\battle\client.conf area_size
	# Here the check is done against area_size (which is by default 14, can be higher, eg. 22 in OathRO)
	# Openkore clientSight should be area_size+1 (by default 15)
	return 0 if ($distance >= $clientSight);

	my $client_distance = getClientDist($pos1, $pos2);
	return 0 unless ($client_distance <= $range);

	return -1 unless ($field->checkLOS($pos1, $pos2, $attackCanSnipe));

	return 1;
}

# Only God and gravity developers know why this is done this way, but I tested in the client and it works 100% of the time
# Probably done this way because the client actually calculates distance in 3D and takes in consideration height ou the GAT file
# To save processing time the server just removes some distance (0.0625 in Hercules and 0.1 in rathena) to compensate
# Bound to fail sometimes as the server itself will fail in some cases
# This actually makes it so that openkore can target, in very specific cases, targets a bit further away than the client can (very large height diference)
# Reference: rathena src\map\path.c distance_client
sub getClientDist {
	my ($pos1, $pos2) = @_;
	my $xD = abs($pos1->{x} - $pos2->{x});
	my $yD = abs($pos1->{y} - $pos2->{y});
	my $temp_dist = sqrt(($xD*$xD) + ($yD*$yD));
	$temp_dist -= 0.1;
	$temp_dist = 0 if($temp_dist < 0);
	$temp_dist = int($temp_dist);
	return $temp_dist
}

##
# blockDistance(pos1, pos2)
# pos1, pos2: references to position hash tables.
# Returns: the distance in number of blocks (integer).
#
# Calculates the distance in number of blocks between pos1 and pos2.
# This is used for e.g. weapon range calculation.
#
# Reference: hercules src\map\path.c distance
sub blockDistance {
	my ($pos1, $pos2) = @_;

	return max(abs($pos1->{x} - $pos2->{x}),
	           abs($pos1->{y} - $pos2->{y}));
}

##
# calcStepsWalkedFromTimeAndSolution(solution, speed, time_elapsed)
# solution: Reference to an array in which the solution is stored. It will contain hashes of x and y coordinates from the start to the end of the path, the first array element should be the current position.
# speed: The actor speed in blocks / second.
# time_elapsed: The amount of time that has passed since movement started.
#
# Returns in which step of solution the character currently is, including possibly step 0.
#
# Example:
# my $steps_walked;
# $steps_walked = calcStepsWalkedFromTimeAndSolution($solution, $speed, $time_elapsed)
# print "You are currently at: $solution->[$steps_walked]{x} $solution->[$steps_walked]{y}\n";
sub calcStepsWalkedFromTimeAndSolution {
	my ($solution, $speed, $time_elapsed) = @_;

	my $stepType = 0; # 1 - vertical or horizontal; 2 - diagonal
	my $current_step = 0; # step

	my %current_pos = ( x => $solution->[0]{x}, y => $solution->[0]{y} );
	my %next_pos;

	my @steps = @{$solution}[1..$#{$solution}];

	my $dist = @steps;

	my $time_needed_ortogonal = $speed;
	my $time_needed_diagonal = $speed * (MOVE_DIAGONAL_COST / MOVE_COST);
	my $time_needed;

	while ($current_step < $dist) {
		%next_pos = ( x => $steps[$current_step]{x}, y => $steps[$current_step]{y} );

		$stepType = 0;

		if ($current_pos{x} != $next_pos{x}) {
			$stepType++;
		}

		if ($current_pos{y} != $next_pos{y}) {
			$stepType++;
		}

		if ($stepType == 2) {
			$time_needed = $time_needed_diagonal;
		} elsif ($stepType == 1) {
			$time_needed = $time_needed_ortogonal;
		}

		if ($time_elapsed > $time_needed) {
			$time_elapsed -= $time_needed;
			%current_pos = %next_pos;
			$current_step++;
		} else {
			last;
		}
	}

	return $current_step;
}

##
# calcTimeFromSolution(solution, speed)
# solution: Reference to an array in which the solution is stored. It will contain hashes of x and y coordinates from the start to the end of the path, the first array element should be the current position.
# speed: The actor speed in blocks / second.
#
# Returns the amount of seconds to walk the given Solution with the given speed.
sub calcTimeFromSolution {
	my ($solution, $speed) = @_;

	my $stepType = 0; # 1 - vertical or horizontal; 2 - diagonal
	my $current_step = 0; # step

	my %current_pos = ( x => $solution->[0]{x}, y => $solution->[0]{y} );
	my %next_pos;

	my @steps = @{$solution}[1..$#{$solution}];

	my $dist = @steps;

	my $time_needed_ortogonal = $speed;
	my $time_needed_diagonal = $speed * (MOVE_DIAGONAL_COST / MOVE_COST);
	my $time_needed;

	my $summed_time = 0;

	while ($current_step < $dist) {
		%next_pos = ( x => $steps[$current_step]{x}, y => $steps[$current_step]{y} );

		$stepType = 0;

		if ($current_pos{x} != $next_pos{x}) {
			$stepType++;
		}

		if ($current_pos{y} != $next_pos{y}) {
			$stepType++;
		}

		if ($stepType == 2) {
			$time_needed = $time_needed_diagonal;
		} elsif ($stepType == 1) {
			$time_needed = $time_needed_ortogonal;
		}

		$summed_time += $time_needed;
		%current_pos = %next_pos;
		$current_step++;
	}

	return $summed_time;
}

##
# calcPosFromTime(pos, pos_to, speed, time)
#
# Returns: the position where an actor moving from $pos to $pos_to with
# the speed $speed will be in $time amount of time.
#
# Walls and pathfinding are not considered.
sub calcPosFromTime {
	my ($pos, $pos_to, $speed, $time) = @_;

	# If Pos and PosTo are the same return Pos
	if ($pos->{x} == $pos_to->{x} && $pos->{y} == $pos_to->{y}) {
		return $pos;
	}

	my $solution = get_client_easy_solution($pos, $pos_to);
	my $steps_walked = calcStepsWalkedFromTimeAndSolution($solution, $speed, $time);
	my $pos = $solution->[$steps_walked];
	return $pos;
}

##
# calcTime(pos, pos_to, speed)
#
# Returns: time to move from $pos to $pos_to with $speed speed.
#
# Walls and pathfinding are not considered.
sub calcTime {
	my ($pos, $pos_to, $speed) = @_;

	if ($pos->{x} == $pos_to->{x} && $pos->{y} == $pos_to->{y}) {
		return 0;
	}

	my $solution = get_client_easy_solution($pos, $pos_to);
	my $summed_time = calcTimeFromSolution($solution, $speed);
	return $summed_time;
}

##
# calcPosition(object, [extra_time, float])
# object: $char (yourself), or a value in %monsters or %players.
# float: If set to 1, return coordinates as floating point.
# Returns: reference to a position hash.
#
# Walls and pathfinding are not considered.
#
# The position information server that the server sends indicates a motion:
# it says that an object is walking from A to B, and that it will arrive at B shortly.
# This function calculates the current position of $object based on the motion information.
#
# If $extra_time is given, this function will calculate where $object will be
# after $extra_time seconds.
#
# Example:
# my $pos;
# $pos = calcPosition($char);
# print "You are currently at: $pos->{x}, $pos->{y}\n";
#
# $pos = calcPosition($monsters{$ID});
# # Calculate where the player will be after 2 seconds
# $pos = calcPosition($players{$ID}, 2);
sub calcPosition {
	my ($object, $extra_time, $float) = @_;
	my $time_needed = $object->{time_move_calc};
	my $elasped = time - $object->{time_move} + $extra_time;

	if ($elasped >= $time_needed || !$time_needed) {
		return $object->{pos_to};
	} else {
		my (%vec, %result, $dist);
		my $pos = $object->{pos};
		my $pos_to = $object->{pos_to};

		getVector(\%vec, $pos_to, $pos);
		$dist = (distance($pos, $pos_to) - 1) * ($elasped / $time_needed);
		moveAlongVector(\%result, $pos, \%vec, $dist);
		$result{x} = int sprintf("%.0f", $result{x}) if (!$float);
		$result{y} = int sprintf("%.0f", $result{y}) if (!$float);
		return \%result;
	}
}

# Only God and gravity developers know why this is done this way, but I tested in the client and it works 100% of the time
#
# Reference: hercules src\map\path.c distance_client
# 956ns -> 618ns
sub getClientDist {
	my ($pos1, $pos2) = @_;
	return PathFinding::getClientDist($pos1->{x}, $pos1->{y}, $pos2->{x}, $pos2->{y});
}

##
# blockDistance(pos1, pos2)
# pos1, pos2: references to position hash tables.
# Returns: the distance in number of blocks (integer).
#
# Calculates the distance in number of blocks between pos1 and pos2.
# This is used for e.g. weapon range calculation.
#
# Reference: hercules src\map\path.c distance
# 650ns -> 580ns
sub blockDistance {
	my ($pos1, $pos2) = @_;
	return PathFinding::blockDistance($pos1->{x}, $pos1->{y}, $pos2->{x}, $pos2->{y});
}

##
# checkMovementDirection(pos1, vec, pos2, fuzziness)
#
# Check whether an object - which is moving into the direction of vector $vec,
# and is currently at position $pos1 - is moving towards $pos2.
#
# Example:
# # Get monster movement direction
# my %vec;
# getVector(\%vec, $monster->{pos_to}, $monster->{pos});
# if (checkMovementDirection($monster->{pos}, \%vec, $char->{pos}, 15)) {
# 	warning "Monster $monster->{name} is moving towards you\n";
#}
sub checkMovementDirection {
	my ($pos1, $vec, $pos2, $fuzziness) = @_;
	my %objVec;
	getVector(\%objVec, $pos2, $pos1);

	my $movementDegree = vectorToDegree($vec);
	my $obj1ToObj2Degree = vectorToDegree(\%objVec);
	return abs($obj1ToObj2Degree - $movementDegree) <= $fuzziness ||
		(($obj1ToObj2Degree - $movementDegree) % 360) <= $fuzziness;
}

##
# distance(r_hash1, r_hash2)
# pos1, pos2: references to position hash tables.
# Returns: the distance as a floating point number.
#
# Calculates the pythagorean distance between pos1 and pos2.
#
# FIXME: Some things in RO should use block distance instead.
# Discussion at
# http://openkore.sourceforge.net/forum/viewtopic.php?t=9176
#
# Example:
# # Calculates the distance between you and a monster
# my $dist = distance($char->{pos_to},
#                     $monsters{$ID}{pos_to});
sub distance {
    my $pos1 = shift;
    my $pos2 = shift;
    return 0 if (!$pos1 && !$pos2);

    my %line;
    if (defined $pos2) {
        $line{x} = abs($pos1->{x} - $pos2->{x});
        $line{y} = abs($pos1->{y} - $pos2->{y});
    } else {
        %line = %{$pos1};
    }
    return sqrt($line{x} ** 2 + $line{y} ** 2);
}

##
# int intToSignedInt(int i)
#
# Convert a 32-bit unsigned integer into a signed integer.
sub intToSignedInt {
	my $result = $_[0];
	# Check most significant bit.
	if ($result & 2147483648) {
		return -0xFFFFFFFF + $result - 1;
	} else {
		return $result;
	}
}

##
# int intToSignedShort(int i)
#
# Convert a 16-bit unsigned integer into a signed integer.
sub intToSignedShort {
	my $result = $_[0];
	# Check most significant bit.
	if ($result & 32768) {
		return -0xFFFF + $result - 1;
	} else {
		return $result;
	}
}

##
# specifiedBlockDistance(pos1, pos2)
# pos1, pos2: references to position hash tables.
# Returns: array containing [diagonal block dist, ortogonal block dist]
sub specifiedBlockDistance {
	my ($pos1, $pos2) = @_;

	my $xDistance = abs($pos1->{x} - $pos2->{x});
	my $yDistance = abs($pos1->{y} - $pos2->{y});

	my $max = max($xDistance, $yDistance);
	my $min = min($xDistance, $yDistance);

	my $orto = $max - $min;

	return ($min, $orto);
}

##
# adjustedBlockDistance(pos1, pos2)
# pos1, pos2: references to position hash tables.
# Returns: the distance in "time to walk blocks" (in RO walking diagonally takes square root of 2 times longer than walking the same amount of cells orthogonally).
#
# Calculates the distance between pos1 and pos2.
# This is used for e.g. walking time calculation.
sub adjustedBlockDistance {
	my ($pos1, $pos2) = @_;

	my $xDistance = abs($pos1->{x} - $pos2->{x});
	my $yDistance = abs($pos1->{y} - $pos2->{y});

	my $dist = $xDistance + $yDistance - ((2-sqrt(2)) * min($xDistance, $yDistance));

	return $dist;
}

##
# getVector(r_store, to, from)
# r_store: reference to a hash. The result will be stored here.
# to, from: reference to position hashes.
#
# Create a vector object. For those who don't know: a vector
# is a mathematical term for describing a movement and its direction.
# So this function creates a vector object, which describes the direction of the
# movement %from to %to. You can use this vector object with other math functions.
#
# See also: moveAlongVector(), vectorToDegree()
sub getVector {
	my $r_store = shift;
	my $to = shift;
	my $from = shift;
	$r_store->{x} = $to->{x} - $from->{x};
	$r_store->{y} = $to->{y} - $from->{y};
}

##
# moveAlong(pos, pos_to, step)
#
# Returns: the position where an actor will be after $step steps
# while walking from $pos to $pos_to.
# Walls are not considered.
sub moveAlong {
	my ($pos, $pos_to, $step) = @_;
	my $posX = $$pos{x};
	my $posY = $$pos{y};
	my $pos_toX = $$pos_to{x};
	my $pos_toY = $$pos_to{y};

	my %result;
	$result{x} = $posX;
	$result{y} = $posY;

	if (!$step) {
		return %result;
	}
	for (my $s = 1; $s <= $step; $s++) {
		if ($posX < $pos_toX) {
			$posX++;
		}
		if ($posX > $pos_toX) {
			$posX--;
		}
		if ($posY < $pos_toY) {
			$posY++;
		}
		if ($posY > $pos_toY) {
			$posY--;
		}
	}
	$result{x} = $posX;
	$result{y} = $posY;
	return %result;
}

##
# moveAlongVector(result, r_pos, r_vec, dist)
# result: reference to a hash, in which the destination position is stored.
# r_pos: the source position.
# r_vec: a vector object, as created by getVector()
# dist: the distance to move from the source position.
#
# Calculate where you will end up to, if you walk $dist blocks from %r_pos
# into the direction specified by %r_vec.
#
# See also: getVector()
#
# Example:
# my %from = (x => 100, y => 100);
# my %to = (x => 120, y => 120);
# my %vec;
# getVector(\%vec, \%to, \%from);
# my %result;
# moveAlongVector(\%result, \%from, \%vec, 10);
# print "You are at $from{x},$from{y}.\n";
# print "If you walk $dist blocks into the direction of $to{x},$to{y}, you will end up at:\n";
# print "$result{x},$result{y}\n";
sub moveAlongVector {
	my $result = shift;
	my $r_pos = shift;
	my $r_vec = shift;
	my $dist = shift;
	if ($dist) {
		my %norm;
		normalize(\%norm, $r_vec);
		$result->{x} = round($$r_pos{'x'} + $norm{'x'} * $dist);
		$result->{y} = round($$r_pos{'y'} + $norm{'y'} * $dist);
	} else {
		$result->{x} = $$r_pos{'x'} + $$r_vec{'x'};
		$result->{y} = $$r_pos{'y'} + $$r_vec{'y'};
	}
}

sub normalize {
	my $r_store = shift;
	my $r_vec = shift;
	my $dist;
	$dist = distance($r_vec);
	if ($dist > 0) {
		$$r_store{'x'} = $$r_vec{'x'} / $dist;
		$$r_store{'y'} = $$r_vec{'y'} / $dist;
	} else {
		$$r_store{'x'} = 0;
		$$r_store{'y'} = 0;
	}
}

##
# vectorToDegree(vector)
# vector: a reference to a vector hash, as created by getVector().
# Returns: the degree as a number.
#
# Converts a vector into a degree number.
#
# See also: getVector()
#
# Example:
# my %from = (x => 100, y => 100);
# my %to = (x => 120, y => 120);
# my %vec;
# getVector(\%vec, \%to, \%from);
# vectorToDegree(\%vec);	# => 45
sub vectorToDegree {
	my $vec = shift;
	my $x = $vec->{x};
	my $y = $vec->{y};

	if ($y == 0) {
		if ($x < 0) {
			return 270;
		} elsif ($x > 0) {
			return 90;
		} else {
			return undef;
		}
	} else {
		my $ret = rad2deg(atan2($x, $y));
		if ($ret < 0) {
			return 360 + $ret;
		} else {
			return $ret;
		}
	}
}

##
# max($a, $b)
#
# Returns the greater of $a or $b.
sub max {
	my ($a, $b) = @_;

	return $a > $b ? $a : $b;
}

##
# min($a, $b)
#
# Returns the lesser of $a or $b.
sub min {
	my ($a, $b) = @_;

	return $a < $b ? $a : $b;
}

##
# round($number)
#
# Returns the rounded number
sub round {
	my($number) = shift;
	return int($number + .5 * ($number <=> 0));
}

##
# ceil($number)
#
# Returns the rounded up number
# Used for distances (only deciles taken into consideration)
sub ceil {
	my($number) = shift;
	return int($number + .9 * ($number <=> 0));
}


#################################################
#################################################
### CATEGORY: Operating system-specific stuff
#################################################
#################################################

##
# checkLaunchApp(pid, [retval])
# pid: the return value of launchApp() or launchScript()
# retval: a reference to a scalar. If the app exited, the return value will be stored in here.
# Returns: 1 if the app is still running, 0 if it has exited.
#
# If you ran a script or an app asynchronously, you can use this function to check
# whether it's currently still running.
#
# See also: launchApp(), launchScript()
sub checkLaunchedApp {
	my ($pid, $retval) = @_;
	if ($^O eq 'MSWin32') {
		my $result = ($pid->Wait(0) == 0);
		if ($result == 0 && $retval) {
			my $code;
			$pid->GetExitCode($code);
			$$retval = $code;
		}
		return $result;
	} else {
		import POSIX ':sys_wait_h';
		my $wnohang = eval "WNOHANG";
		return (waitpid($pid, $wnohang) <= 0);
	}
}

##
# launchApp(detach, args...)
# detach: set to 1 if you don't care when this application exits.
# args: the application's name and arguments.
# Returns: a PID on Unix; a Win32::Process object on Windows.
#
# Asynchronously launch an application.
#
# See also: checkLaunchedApp()
sub launchApp {
	my $detach = shift;
	if ($^O eq 'MSWin32') {
		my @args = @_;
		foreach (@args) {
			$_ = "\"$_\"";
		}

		my ($priority, $obj);
		undef $@;
		eval 'use Win32::Process; $priority = NORMAL_PRIORITY_CLASS;';
		die if ($@);
		Win32::Process::Create($obj, $_[0], "@args", 0, $priority, '.');
		return $obj;

	} else {
		require POSIX;
		import POSIX;
		my $pid = fork();

		if ($detach) {
			if ($pid == 0) {
				open(STDOUT, "> /dev/null");
				open(STDERR, "> /dev/null");
				POSIX::setsid();
				if (fork() == 0) {
					exec(@_);
				}
				POSIX::_exit(1);
			} elsif ($pid) {
				waitpid($pid, 0);
			}
		} else {
			if ($pid == 0) {
				#open(STDOUT, "> /dev/null");
				#open(STDERR, "> /dev/null");
				POSIX::setsid();
				exec(@_);
				POSIX::_exit(1);
			}
		}
		return $pid;
	}
}

##
# launchScript(async, module_paths, script, [args...])
# async: 1 if you want to run the script in the background, or 0 if you want to wait until the script has exited.
# module_paths: reference to an array which contains paths to look for modules, or undef.
# script: filename of the Perl script.
# args: parameters to pass to the script.
# Returns: a PID on Unix, a Win32::Process object on Windows.
#
# Run a Perl script.
#
# See also: launchApp(), checkLaunchedApp()
sub launchScript {
	my $async = shift;
	my $module_paths = shift;
	my $script = shift;
	my @interp;

	if (-f $Config{perlpath}) {
		@interp = ($Config{perlpath});
		delete $ENV{INTERPRETER};
	} else {
		@interp = ($ENV{INTERPRETER}, '!');
	}

	my @paths;
	if ($module_paths) {
		foreach (@{$module_paths}) {
			push @paths, "-I$_";
		}
	}

	if ($async) {
		return launchApp(0, @interp, @paths, $script, @_);
	} else {
		system(@interp, @paths, $script, @_);
	}
}


########################################
########################################
### CATEGORY: Misc utility functions
########################################
########################################


##
# dataWaiting(r_handle)
# r_handle: A reference to a handle or a socket.
# Returns: 1 if there's pending incoming data, 0 if not.
#
# Checks whether the socket $r_handle has pending incoming data.
# If there is, then you can read from $r_handle without being blocked.
sub dataWaiting {
	my $r_fh = shift;
	return 0 if (!defined $r_fh || !defined $$r_fh);

	my $bits = '';
	vec($bits, fileno($$r_fh), 1) = 1;
	# The timeout was 0.005
	return (select($bits, undef, undef, 0) > 0);
	#return select($bits, $bits, $bits, 0) > 1);
}

##
# dumpHash(r_hash)
# r_hash: a reference to a hash/array.
#
# Return a formated output of the contents of a hash/array, for debugging purposes.
sub dumpHash {
	my $out;
	my $buf = $_[0];
	if (ref($buf) eq "") {
		$buf =~ s/'/\\'/gs;
		$buf =~ s/[\000-\037]/\./gs;
		$out .= "'$buf'";
	} elsif (ref($buf) eq "HASH") {
		$out .= "{";
		foreach (keys %{$buf}) {
			s/'/\\'/gs;
			$out .= "$_=>" . dumpHash($buf->{$_}) . ",";
		}
		chop $out;
		$out .= "}";
	} elsif (ref($buf) eq "ARRAY") {
		$out .= "[";
		for (my $i = 0; $i < @{$buf}; $i++) {
			s/'/\\'/gs;
			$out .= "$i=>" . dumpHash($buf->[$i]) . ",";
		}
		chop $out;
		$out .= "]";
	}
	$out = '{empty}' if ($out eq '}');
	return $out;
}

##
# formatNumber(num)
# num: An integer number.
# Returns: A formatted number with commas.
#
# Add commas to $num so large numbers are more readable.
# $num must be an integer, not a floating point number.
#
# Example:
# formatNumber(1000000);   # -> 1,000,000
sub formatNumber {
	my $num = reverse $_[0];
	if ($num == 0) {
		return 0;
	}else {
		$num =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
		return scalar reverse $num;
	}
}

sub _find_x {
	my ($x, $y) = @_;
	my $a = _find_x_top($x, $y);

	my @ans = (
		[$a,$a+1,$a+2,$a+3,$a+4,$a+5,$a+6,$a+7],
		[$a+1,$a,$a+3,$a+2,$a+5,$a+4,$a+7,$a+6],
		[$a+2,$a+3,$a,$a+1,$a+6,$a+7,$a+4,$a+5],
		[$a+3,$a+2,$a+1,$a,$a+7,$a+6,$a+5,$a+4],
		[$a+4,$a+5,$a+6,$a+7,$a,$a+1,$a+2,$a+3],
		[$a+5,$a+4,$a+7,$a+6,$a+1,$a,$a+3,$a+2],
		[$a+6,$a+7,$a+4,$a+5,$a+2,$a+3,$a,$a+2],
		[$a+7,$a+6,$a+5,$a+4,$a+3,$a+2,$a+1,$a]
	);
	return $ans[int($x % 32) / 4][int($y % 32) / 4];
}

sub _find_x_top {
	my ($x, $y) = @_;
	my $b;

	if ($x < 256 && $y < 256) {
		$b = 0;
	} elsif ($x >= 256 && $y >= 256) {
		$b = 0;
	} else {
		$b = 64;
	}

	my @ans = (
		[$b,$b+1*8,$b+2*8,$b+3*8,$b+4*8,$b+5*8,$b+6*8,$b+7*8],
		[$b+1*8,$b,$b+3*8,$b+2*8,$b+5*8,$b+4*8,$b+7*8,$b+6*8],
		[$b+2*8,$b+3*8,$b,$b+1*8,$b+6*8,$b+7*8,$b+4*8,$b+5*8],
		[$b+3*8,$b+2*8,$b+1*8,$b,$b+7*8,$b+6*8,$b+5*8,$b+4*8],
		[$b+4*8,$b+5*8,$b+6*8,$b+7*8,$b,$b+1*8,$b+2*8,$b+3*8],
		[$b+5*8,$b+4*8,$b+7*8,$b+6*8,$b+1*8,$b,$b+3*8,$b+2*8],
		[$b+6*8,$b+7*8,$b+4*8,$b+5*8,$b+2*8,$b+3*8,$b,$b+2*8],
		[$b+7*8,$b+6*8,$b+5*8,$b+4*8,$b+3*8,$b+2*8,$b+1*8,$b]
	);
	return $ans[int($x % 256) / 32][int($y % 256) / 32];
}

sub getCoordString {
	my $x = int(shift);
	my $y = int(shift);
	my $nopadding = shift;
	my $coords = "";

	shiftPack(\$coords, 0x44, 8);
	shiftPack(\$coords, $x, 10);
	shiftPack(\$coords, $y, 10);
	shiftPack(\$coords, 0, 4);
	$coords = substr($coords, 1)
		if (($masterServer->{serverType} == 0) || $nopadding);

	return $coords;
}

sub getCoordString2 {
	my $x = int(shift);
	my $y = int(shift);
	my $nopadding = shift;
	my $coords = "";

	shiftPack(\$coords, 0x44, 8);
	shiftPack(\$coords, $x, 10);
	shiftPack(\$coords, $y, 10);
	shiftPack(\$coords, 0, 28);
	$coords = substr($coords, 1)
		if (($masterServer->{serverType} == 0) || ($masterServer->{serverType} == 3) || ($masterServer->{serverType} == 5) || $nopadding);

	return $coords;
}

# Year.Month.Day Hour:Minute:Second
# 2021.03.13 01:58:08.12
sub getFormattedDate {
	my $thetime = shift;
	my $r_date = shift;
	my @localtime = localtime $thetime;

	$$r_date = sprintf("%4d.%02d.%02d %02d:%02d:%02d", $localtime[5] + 1900, $localtime[4] + 1, $localtime[3], $localtime[2], $localtime[1], $localtime[0]);
	return $$r_date;
}

# Year.Month.Day (0)
# Hour:Minute:Second (1)
# \&getFormattedDate (2)
# YYYYMMDD (3)
sub getFormattedDateShort {
	my $thetime = shift;
	my $mode = shift;
	my $r_date = shift;

	return getFormattedDate($thetime, $r_date) if ($mode == 2);

	my @localtime = localtime $thetime;

	if ($mode == 0) {
		$$r_date = sprintf("%4d.%02d.%02d", ($localtime[5] + 1900), $localtime[4] + 1, $localtime[3]);
	} elsif ($mode == 1) {
		$$r_date = sprintf("%02d:%02d:%02d", $localtime[2], $localtime[1], $localtime[0]);
	} elsif($mode == 3) {
		$$r_date = sprintf("%4d%02d%02d", ($localtime[5] + 1900), $localtime[4] + 1, $localtime[3]);
	}

	return $$r_date;
}

sub getHex {
	my $data = shift;
	my $i;
	my $return;
	for ($i = 0; $i < length($data); $i++) {
		$return .= uc(unpack("H2",substr($data, $i, 1)));
		if ($i + 1 < length($data)) {
			$return .= " ";
		}
	}
	return $return;
}

sub giveHex {
	return pack("H*",split(' ',shift));
}


sub getRange {
	my $param = shift;
	return if (!defined $param);

	# remove % from the first number here (i.e. hp 50%..60%) because it's easiest
	if ($param =~ /(-?\d+(?:\.\d+)?)\%?\s*(?:-|\.\.)\s*(-?\d+(?:\.\d+)?)/) {
		return ($1, $2, 1);
	} elsif ($param =~ />\s*(-?\d+(?:\.\d+)?)/) {
		return ($1, undef, 0);
	} elsif ($param =~ />=\s*(-?\d+(?:\.\d+)?)/) {
		return ($1, undef, 1);
	} elsif ($param =~ /<\s*(-?\d+(?:\.\d+)?)/) {
		return (undef, $1, 0);
	} elsif ($param =~ /<=\s*(-?\d+(?:\.\d+)?)/) {
		return (undef, $1, 1);
	} elsif ($param =~/^(-?\d+(?:\.\d+)?)/) {
		return ($1, $1, 1);
	}
}

sub getTickCount {
	my $time = int(time()*1000);
	if (length($time) > 9) {
		return substr($time, length($time) - 8, length($time));
	} else {
		return $time;
	}
}

sub inRange {
	my $value = shift;
	my $param = shift;

	return 1 if (!defined $param);
	return 0 if (!defined $value);
	my ($min, $max, $inclusive) = getRange($param);

	if (defined $min && defined $max) {
		return 1 if ($value >= $min && $value <= $max);
	} elsif (defined $min) {
		return 1 if ($value > $min || ($inclusive && $value == $min));
	} elsif (defined $max) {
		return 1 if ($value < $max || ($inclusive && $value == $max));
	}

	return 0;
}

##
# judgeSkillArea(ID)
# ID: a skill ID.
# Returns: the size of the skill's area.
#
# Figure out how large the skill area is, in diameters.
sub judgeSkillArea {
	my $id = shift;

	if ($id == 81 || $id == 85 || $id == 89 || $id == 83 || $id == 110 || $id == 91) {
		 return 5;
	} elsif ($id == 70 || $id == 79 ) {
		 return 4;
	} elsif ($id == 21 || $id == 17 ){
		 return 3;
	} elsif ($id == 88  || $id == 80
	      || $id == 11  || $id == 18
	      || $id == 140 || $id == 229 ) {
		 return 2;
	} else {
		 return 0;
	}
}

##
# makeCoords()
#
# The maximum value for either coordinate (x or y) is 1023,
# thus making the number of bits for each coordinate 10.
#
# When both coordinates are packed together,
# the bit usage becomes double that, 20 bits or 2.5 bytes.
#
# Note: so we don't have to repeat documentation

##
# makeCoordsDir(r_hash, rawCoords, bodyDir)
#
# Read makeCoords()
#
# Another 0.5 bytes or 4 bits are reserved for body direction.
#
# ex. stand/spawn packet (4 + 10 + 10 = 24 bits = 3 bytes = a3)
sub makeCoordsDir {
	my ($r_hash, $rawCoords, $bodyDir) = @_;
	unShiftPack(\$rawCoords, $bodyDir, 4);
	makeCoordsXY($r_hash, \$rawCoords);
}

##
# makeCoordsFromTo(r_hashFrom, r_hashTo, rawCoords)
#
# Read makeCoords()
#
# Coordinates for From & To packed together require 5 bytes.
#
# Another 1 byte or 2*4 bits are reserved for a clientside feature:
# x0+=sx0*0.0625-0.5 and y0+=sy0*0.0625-0.5
# Note: if sx0/sy0 is 8, this will respectively add 0 to x0/y0
# Reference: hercules src\map\clif.c // client-side: x0+=sx0*0.0625-0.5 and y0+=sy0*0.0625-0.5
#
# ex. walk packet (4 + 4 + 10 + 10 + 10 + 10 = 48 bits = 6 bytes = a6)
#
# TODO: Maybe aegis, athena, cronus, brathena or other emulators actually use this sx0/sy0 argument and we don't know
sub makeCoordsFromTo {
	my ($r_hashFrom, $r_hashTo, $rawCoords) = @_;
	unShiftPack(\$rawCoords, undef, 4); # seems to be returning 8 (always?)
	unShiftPack(\$rawCoords, undef, 4); # seems to be returning 8 (always?)
	makeCoordsXY($r_hashTo, \$rawCoords);
	makeCoordsXY($r_hashFrom, \$rawCoords);
}

##
# makeCoordsXY(r_hashFrom, r_hashRawCoords)
#
# Read makeCoords()
#
# Note: this function is used as a help function for: makeCoordsDir, makeCoordsFromTo
sub makeCoordsXY {
	my ($r_hash, $r_hashRawCoords) = @_;
	unShiftPack($r_hashRawCoords, \$r_hash->{y}, 10);
	unShiftPack($r_hashRawCoords, \$r_hash->{x}, 10);
}

##
# shiftPack(data, value, bits)
# data: reference to existing data in which to pack onto
# value: value to pack
# bits: maximum number of bits used by value
#
# Packs a value onto a set of data using bitwise shifts
sub shiftPack {
	my ($data, $value, $bits) = @_;
 	my ($newdata, $dw1, $dw2, $i, $mask, $done);

	$mask = 2 ** (32 - $bits) - 1;
	$i = length($$data);

	$newdata = "";
	$done = 0;

	$dw1 = $value & (2 ** $bits - 1);
 	do {
		$i -= 4;
		$dw2 = ($i > 0) ?
			unpack('N', substr($$data, $i, 4)) :
			unpack('N', pack('x' . abs($i)) . substr($$data, 0, 4 + $i));

		$dw1 = $dw1 | (($dw2 & $mask) << $bits);
		$newdata = pack('N', $dw1) . $newdata;
		$dw1 = $dw2 >> (32 - $bits);
	} while ($i + 4 > 0);

	$newdata = substr($newdata, 1) while (substr($newdata, 0, 1) eq pack('C', 0) && length($newdata));
	$$data = $newdata;
}

##
# urldecode(encoded_string)
#
# Decode an URL-encoded string.
sub urldecode {
	my ($str) = @_;
	$str =~ tr/+?/  /;
	$str =~ s/%([0-9a-fA-F]{2})/pack('H2',$1)/ge;
	return $str;
}

##
# urlencode(str)
#
# URL-encodes a string.
sub urlencode {
	my ($str) = @_;
	$str =~ s/([\W])/"%" . uc(sprintf("%2.2x", ord($1)))/eg;
	return $str;
}

##
# unShiftPack(data, reference, bits)
# data: data to unpack a value from
# reference: reference to store the value in
# bits: number of bits value requires
#
# This is the reverse operation of shiftPack.
sub unShiftPack {
	my ($data, $reference, $bits) = @_;
	my ($newdata, $dw1, $dw2, $i, $mask, $done);

	$mask = 2 ** $bits - 1;
	$i = length($$data);

	$newdata = "";
	$done = 0;

	do {
		$i -= 4;
		$dw2 = ($i > 0) ?
			unpack('N', substr($$data, $i, 4)) :
			unpack('N', pack('x' . abs($i)) . substr($$data, 0, 4 + $i));

		unless ($done) {
			$$reference = $dw2 & (2 ** $bits - 1) if (defined $reference);
			$done = 1;
		} else {
			$dw1 = $dw1 | (($dw2 & $mask) << (32 - $bits));
			$newdata = pack('N', $dw1) . $newdata;
		}

		$dw1 = $dw2 >> $bits;
	} while ($i + 4 > 0);

	$newdata = substr($newdata, 1) while (substr($newdata, 0, 1) eq pack('C', 0) && length($newdata));
	$$data = $newdata;
}

##
# makeDistMap(data, width, height)
# data: the raw field data.
# width: the field's width.
# height: the field's height.
# Returns: the raw data of the distance map.
#
# Create a distance map from raw field data. This distance map data is used by pathfinding
# for wall avoidance support.

# sub old_makeDistMap {
# 	# makeDistMap() is now written in C++ (src/auto/XSTools/misc/fastutils.xs)
# 	# The old Perl function is still here in case anyone wants to read it
# 	my $data = shift;
# 	my $width = shift;
# 	my $height = shift;
#
# 	# Simplify the raw map data. Each byte in the raw map data
# 	# represents a block on the field, but only some bytes are
# 	# interesting to pathfinding.
# 	for (my $i = 0; $i < length($data); $i++) {
# 		my $v = ord(substr($data, $i, 1));
# 		# 0 is open, 3 is walkable water
# 		if ($v == 0 || $v == 3) {
# 			$v = 255;
# 		} else {
# 			$v = 0;
# 		}
# 		substr($data, $i, 1, chr($v));
# 	}
#
# 	my $done = 0;
# 	until ($done) {
# 		$done = 1;
# 		#'push' wall distance right and up
# 		for (my $y = 0; $y < $height; $y++) {
# 			for (my $x = 0; $x < $width; $x++) {
# 				my $i = $y * $width + $x;
# 				my $dist = ord(substr($data, $i, 1));
# 				if ($x != $width - 1) {
# 					my $ir = $y * $width + $x + 1;
# 					my $distr = ord(substr($data, $ir, 1));
# 					my $comp = $dist - $distr;
# 					if ($comp > 1) {
# 						my $val = $distr + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $i, 1, chr($val));
# 						$done = 0;
# 					} elsif ($comp < -1) {
# 						my $val = $dist + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $ir, 1, chr($val));
# 						$done = 0;
# 					}
# 				}
# 				if ($y != $height - 1) {
# 					my $iu = ($y + 1) * $width + $x;
# 					my $distu = ord(substr($data, $iu, 1));
# 					my $comp = $dist - $distu;
# 					if ($comp > 1) {
# 						my $val = $distu + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $i, 1, chr($val));
# 						$done = 0;
# 					} elsif ($comp < -1) {
# 						my $val = $dist + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $iu, 1, chr($val));
# 						$done = 0;
# 					}
# 				}
# 			}
# 		}
# 		#'push' wall distance left and down
# 		for (my $y = $height - 1; $y >= 0; $y--) {
# 			for (my $x = $width - 1; $x >= 0 ; $x--) {
# 				my $i = $y * $width + $x;
# 				my $dist = ord(substr($data, $i, 1));
# 				if ($x != 0) {
# 					my $il = $y * $width + $x - 1;
# 					my $distl = ord(substr($data, $il, 1));
# 					my $comp = $dist - $distl;
# 					if ($comp > 1) {
# 						my $val = $distl + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $i, 1, chr($val));
# 						$done = 0;
# 					} elsif ($comp < -1) {
# 						my $val = $dist + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $il, 1, chr($val));
# 						$done = 0;
# 					}
# 				}
# 				if ($y != 0) {
# 					my $id = ($y - 1) * $width + $x;
# 					my $distd = ord(substr($data, $id, 1));
# 					my $comp = $dist - $distd;
# 					if ($comp > 1) {
# 						my $val = $distd + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $i, 1, chr($val));
# 						$done = 0;
# 					} elsif ($comp < -1) {
# 						my $val = $dist + 1;
# 						$val = 255 if $val > 255;
# 						substr($data, $id, 1, chr($val));
# 						$done = 0;
# 					}
# 				}
# 			}
# 		}
# 	}
# 	return $data;
# }

sub makeIP {
	my $raw = shift;
	my $ret;
	for (my $i = 0; $i < 4; $i++) {
		$ret .= hex(getHex(substr($raw, $i, 1)));
		if ($i + 1 < 4) {
			$ret .= ".";
		}
	}
	return $ret;
}

sub encodeIP {
	return pack("C*", split(/\./, shift));
}


##
# Array<String> parseArgs(String command, [int max], [String delimiters = ' '], [int* last_arg_pos])
# command: a command string.
# max: maximum number of arguments.
# delimiters: a character array of delimiters for arguments.
# last_arg_pos: reference to a scalar. The position of the start of the last argument is stored here.
# Returns: an array of arguments.
#
# Parse a command string and split it into an array of arguments.
# Quoted parts inside the command strings are considered one argument.
# Backslashes can be used to escape a special character (like quotes).
# Leadingand trailing whitespaces are ignored, unless quoted.
#
# Example:
# parseArgs("guild members");		# => ("guild", "members")
# parseArgs("c hello there", 2);	# => ("c", "hello there")
# parseArgs("pm 'My Friend' hey there", 3);	# ("pm", "My Friend", "hey there")
sub parseArgs {
	my ($command, $max, $delimiters, $r_last_arg_pos) = @_;
	my @args;

	if (!defined $delimiters) {
		$delimiters = qr/ /;
	} else {
		$delimiters = quotemeta $delimiters;
		$delimiters = qr/[$delimiters]/;
	}

	my $last_arg_pos;
	my $tmp;
	($tmp, $command) = $command =~ /^( *)(.*)/;
	$last_arg_pos = length($tmp);
	$command =~ s/ *$//;

	my $len = length $command;
	my $within_quote;
	my $quote_char = '';
	my $i;

	for ($i = 0; $i < $len; $i++) {
		my $char = substr($command, $i, 1);

		if ($max && @args == $max) {
			$args[0] = $command;
			last;

		} elsif ($char eq '\\') {
			$args[0] .= substr($command, $i + 1, 1);
			$i++;

		} elsif (($char eq '"' || $char eq "'") && ($quote_char eq '' || $quote_char eq $char)) {
			$within_quote = !$within_quote;
			$quote_char = ($within_quote) ? $char : '';

		} elsif ($within_quote) {
			$args[0] .= $char;

		} elsif ($char =~ /$delimiters/) {
			unshift @args, '';
			$command = substr($command, $i + 1);
			($tmp, $command) =~ /^(${delimiters}*)(.*)/;
			$len = length $command;
			$last_arg_pos += $i + 1;
			$i = -1;

		} else {
			$args[0] .= $char;
		}
	}
	$$r_last_arg_pos = $last_arg_pos if ($r_last_arg_pos);
	return reverse @args;
}

sub parse_portal_conversation_args {
    my ($command) = @_;
    my @args;
    my $i = 0;
    my $len = length($command);

    while ($i < $len) {
        # Skip leading whitespace
        $command =~ /\G\s*/gc;

        # End of string
        last if $i >= $len;

        # Check current position
        $i = pos($command);

        # Handle quoted strings
        if ($command =~ /\G(["'])(.*?)\1\s*/gc) {
            push @args, $2;
        }
        # Handle regex r~/.../flags
        elsif ($command =~ /\Gr~\/((?:\\\/|[^\/])+)\/([a-z]*)\s*/gc) {
            my ($regex, $flags) = ($1, $2);
            push @args, "r~/$regex/$flags";
        }
        # Handle normal token (non-whitespace)
        elsif ($command =~ /\G(\S+)\s*/gc) {
            push @args, $1;
        } else {
            # Fallback: skip one character
            pos($command)++;
        }

        $i = pos($command);
    }

    return @args;
}

##
# quarkToString(quark)
# quark: A quark as returned by stringToQuark()
#
# Convert a quark back into a string. See stringToQuark() for details.
sub quarkToString {
	my $quark = $_[0];
	return $strings{$quark};
}

##
# stringToQuark(string)
#
# Convert a string into a so-called quark. Each string will be converted to a unique quark.
# This can be used to save memory, if your application uses many identical strings.
#
# For example, consider the following:
# <pre class="example">
# my @array;
# for (1..10000) {
#     push @array, "this is a string";
# }
# </pre>
# The above example will store 10000 different copies of the string "this is my string" into
# the array. Even though each string has the same content, each string uses its own memory.
#
# By using quarks, one can save a lot of memory:
# <pre class="example">
# my @array;
# for (1..10000) {
#     push @array, stringToQuark("this is a string");
# }
# </pre>
# The array will now contain 10000 instances of the same quark, so very little memory is wasted.
#
# To convert a quark back to a string, use quarkToString().
sub stringToQuark {
	my $string = $_[0];
	if (exists $quarks{$string}) {
		return $quarks{$string};
	} else {
		my $ref = \$string;
		$quarks{$string} = $ref;
		$strings{$ref} = $string;
		return $ref;
	}
}

sub swrite {
	my $result = '';
	for (my $i = 0; $i < @_; $i += 2) {
		my $format = $_[$i];
		my @args = @{$_[$i+1]};
		if ($format =~ /@[<|>]/) {
			$^A = '';
			formline($format, @args);
			$result .= "$^A\n";
		} else {
			$result .= "$format\n";
		}
	}
	$^A = '';
	return $result;
}

##
# timeConvert(seconds)
# seconds: number of seconds.
# Returns: a human-readable version of $seconds.
#
# Converts $seconds into a string in the form of "x hours y minutes z seconds".
sub timeConvert {
	my $time = shift;
	my $hours = int($time / 3600);
	my $time = $time % 3600;
	my $minutes = int($time / 60);
	my $time = $time % 60;
	my $seconds = $time;
	my $gathered = '';

	$gathered = "$hours hours " if ($hours);
	$gathered .= "$minutes minutes " if ($minutes);
	$gathered .= "$seconds seconds" if ($seconds);
	$gathered =~ s/ $//;
	$gathered = '0 seconds' if ($gathered eq '');
	return $gathered;
}

##
# timeOut(r_time, [timeout])
# r_time: a time value, or a hash.
# timeout: the timeout value to use if $r_time is a time value.
# Returns: a boolean.
#
# If r_time is a time value:
# Check whether $timeout seconds have passed since $r_time.
#
# If r_time is a hash:
# Check whether $r_time->{timeout} seconds have passed since $r_time->{time}.
#
# This function is usually used to handle timeouts in a loop.
#
# Example:
# my %time;
# $time{time} = time;
# $time{timeout} = 10;
#
# while (1) {
#     if (timeOut(\%time)) {
#         print "10 seconds have passed since this loop was started.\n";
#         last;
#     }
# }
#
# my $startTime = time;
# while (1) {
#     if (timeOut($startTime, 6)) {
#         print "6 seconds have passed since this loop was started.\n";
#         last;
#     }
# }

# timeOut() is implemented in tools/misc/fastutils.xs

##
# vocalString(letter_length, [r_string])
# letter_length: the requested length of the result.
# r_string: a reference to a scalar. If given, the result will be stored here.
# Returns: the resulting string.
#
# Creates a random string of $letter_length long. The resulting string is pronouncable.
# This function can be used to generate a random password.
#
# Example:
# for (my $i = 0; $i < 5; $i++) {
#     printf("%s\n", vocalString(10));
# }
sub vocalString {
	my $letter_length = shift;
	return if ($letter_length <= 0);
	my $r_string = shift;
	my $test;
	my $i;
	my $password;
	my @cons = ("b", "c", "d", "g", "h", "j", "k", "l", "m", "n", "p", "r", "s", "t", "v", "w", "y", "z", "tr", "cl", "cr", "br", "fr", "th", "dr", "ch", "st", "sp", "sw", "pr", "sh", "gr", "tw", "wr", "ck");
	my @vowels = ("a", "e", "i", "o", "u" , "a", "e" ,"i","o","u","a","e","i","o", "ea" , "ou" , "ie" , "ai" , "ee" ,"au", "oo");
	my %badend = ( "tr" => 1, "cr" => 1, "br" => 1, "fr" => 1, "dr" => 1, "sp" => 1, "sw" => 1, "pr" =>1, "gr" => 1, "tw" => 1, "wr" => 1, "cl" => 1, "kr" => 1);
	for (;;) {
		$password = "";
		for($i = 0; $i < $letter_length; $i++){
			$password .= $cons[rand(@cons - 1)] . $vowels[rand(@vowels - 1)];
		}
		$password = substr($password, 0, $letter_length);
		($test) = ($password =~ /(..)\z/);
		last if ($badend{$test} != 1);
	}
	$$r_string = $password if ($r_string);
	return $password;
}

##
# String wrapText(String text, int maxLineLength)
# text: The text to wrap.
# maxLineLength: The maximum length of a line.
# Requires: defined($text) && $maxLineLength > 1
# Ensures: defined(result)
#
# Wrap the given text at the given length.
sub wrapText {
	local($Text::Wrap::columns) = $_[1];
	return wrap('', '', $_[0]);
}

##
# int pin_encode(int pin, int key)
# pin: the PIN code
# key: the encryption key
#
# PIN Encode Function, used to hide the real PIN code, using KEY.
sub pin_encode {
	my ($pin, $key) = @_;
	$key &= 0xFFFFFFFF;
	$key ^= 0xFFFFFFFF;
	# Check PIN len
	if ((length($pin) > 3) && (length($pin) < 9)) {
		my $pincode;
		# Convert String to number
		$pincode = $pin;
		# Encryption loop
		for(my $loopin = 0; $loopin < length($pin); $loopin++) {
			$pincode &= 0xFFFFFFFF;
			$pincode += 0x05F5E100; # Static Encryption Key
			$pincode &= 0xFFFFFFFF;
		}
		# Finalize Encryption
		$pincode &= 0xFFFFFFFF;
		$pincode ^= $key;
		$pincode &= 0xFFFFFFFF;
		return $pincode;
	} elsif (length($pin) == 0) {
		my $pincode;
		# Convert String to number
		$pincode = 0;
		# Finalize Encryption
		$pincode &= 0xFFFFFFFF;
		$pincode ^= $key;
		$pincode &= 0xFFFFFFFF;
		return $pincode;
	} else {
		return 0;
	}
}

1;