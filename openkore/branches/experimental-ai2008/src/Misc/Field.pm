package Misc::Field;

use strict;
use threads;
use threads::shared;
use Globals qw(%config %field $field @spellsID %spells $char $accountID @playersID $playersList);
use Log qw(message warning error debug);
use Plugins;
use FileParsers;
use Exporter;
use base qw(Exporter);

our %EXPORT_TAGS = (
	field  => [qw(
		calcRectArea
		calcRectArea2
		checkLineSnipable
		checkLineWalkable
		checkWallLength
		closestWalkableSpot
		objectInsideSpell
		objectIsMovingTowards
		objectIsMovingTowardsPlayer)],
);

our @EXPORT = (
	@{$EXPORT_TAGS{field}},
);

#######################################
#######################################
### CATEGORY: Field math
#######################################
#######################################

##
# calcRectArea($x, $y, $radius)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions of the border of the rectangle.
sub calcRectArea {
	my ($x, $y, $radius) = @_;
	my (%topLeft, %topRight, %bottomLeft, %bottomRight);

	sub capX {
		return 0 if ($_[0] < 0);
		return $field{width} - 1 if ($_[0] >= $field{width});
		return int $_[0];
	}
	sub capY {
		return 0 if ($_[0] < 0);
		return $field{height} - 1 if ($_[0] >= $field{height});
		return int $_[0];
	}

	# Get the avoid area as a rectangle
	$topLeft{x} = capX($x - $radius);
	$topLeft{y} = capY($y + $radius);
	$topRight{x} = capX($x + $radius);
	$topRight{y} = capY($y + $radius);
	$bottomLeft{x} = capX($x - $radius);
	$bottomLeft{y} = capY($y - $radius);
	$bottomRight{x} = capX($x + $radius);
	$bottomRight{y} = capY($y - $radius);

	# Walk through the border of the rectangle
	# Record the blocks that are walkable
	my @walkableBlocks;
	for (my $x = $topLeft{x}; $x <= $topRight{x}; $x++) {
		if ($field->isWalkable($x, $topLeft{y})) {
			push @walkableBlocks, {x => $x, y => $topLeft{y}};
		}
	}
	for (my $x = $bottomLeft{x}; $x <= $bottomRight{x}; $x++) {
		if ($field->isWalkable($x, $bottomLeft{y})) {
			push @walkableBlocks, {x => $x, y => $bottomLeft{y}};
		}
	}
	for (my $y = $bottomLeft{y} + 1; $y < $topLeft{y}; $y++) {
		if ($field->isWalkable($topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topLeft{x}, y => $y};
		}
	}
	for (my $y = $bottomRight{y} + 1; $y < $topRight{y}; $y++) {
		if ($field->isWalkable($topLeft{x}, $y)) {
			push @walkableBlocks, {x => $topRight{x}, y => $y};
		}
	}

	return @walkableBlocks;
}

##
# calcRectArea2($x, $y, $radius, $minRange)
# Returns: an array with position hashes. Each has contains an x and a y key.
#
# Creates a rectangle with center ($x,$y) and radius $radius,
# and returns a list of positions inside the rectangle that are
# not closer than $minRange to the center.
sub calcRectArea2 {
	my ($cx, $cy, $r, $min) = @_;

	my @rectangle;
	for (my $x = $cx - $r; $x <= $cx + $r; $x++) {
		for (my $y = $cy - $r; $y <= $cy + $r; $y++) {
			next if distance({x => $cx, y => $cy}, {x => $x, y => $y}) < $min;
			push(@rectangle, {x => $x, y => $y});
		}
	}
	return @rectangle;
}

##
# checkLineSnipable(from, to)
# from, to: references to position hashes.
#
# Check whether you can snipe a target standing at $to,
# from the position $from, without being blocked by any
# obstacles.
sub checkLineSnipable {
	return 0 if (!$field);
	my $from = shift;
	my $to = shift;

	# Simulate tracing a line to the location (modified Bresenham's algorithm)
	my ($X0, $Y0, $X1, $Y1) = ($from->{x}, $from->{y}, $to->{x}, $to->{y});

	my $steep;
	my $posX = 1;
	my $posY = 1;
	if ($X1 - $X0 < 0) {
		$posX = -1;
	}
	if ($Y1 - $Y0 < 0) {
		$posY = -1;
	}
	if (abs($Y0 - $Y1) < abs($X0 - $X1)) {
		$steep = 0;
	} else {
		$steep = 1;
	}
	if ($steep == 1) {
		my $Yt = $Y0;
		$Y0 = $X0;
		$X0 = $Yt;

		$Yt = $Y1;
		$Y1 = $X1;
		$X1 = $Yt;
	}
	if ($X0 > $X1) {
		my $Xt = $X0;
		$X0 = $X1;
		$X1 = $Xt;

		my $Yt = $Y0;
		$Y0 = $Y1;
		$Y1 = $Yt;
	}
	my $dX = $X1 - $X0;
	my $dY = abs($Y1 - $Y0);
	my $E = 0;
	my $dE;
	if ($dX) {
		$dE = $dY / $dX;
	} else {
		# Delta X is 0, it only occures when $from is equal to $to
		return 1;
	}
	my $stepY;
	if ($Y0 < $Y1) {
		$stepY = 1;
	} else {
		$stepY = -1;
	}
	my $Y = $Y0;
	my $Erate = 0.99;
	if (($posY == -1 && $posX == 1) || ($posY == 1 && $posX == -1)) {
		$Erate = 0.01;
	}
	for (my $X=$X0;$X<=$X1;$X++) {
		$E += $dE;
		if ($steep == 1) {
			return 0 if (!$field->isSnipable($Y, $X));
		} else {
			return 0 if (!$field->isSnipable($X, $Y));
		}
		if ($E >= $Erate) {
			$Y += $stepY;
			$E -= 1;
		}
	}
	return 1;
}

##
# checkLineWalkable(from, to, [min_obstacle_size = 5])
# from, to: references to position hashes.
#
# Check whether you can walk from $from to $to in an (almost)
# straight line, without obstacles that are too large.
# Obstacles are considered too large, if they are at least
# the size of a rectangle with "radius" $min_obstacle_size.
sub checkLineWalkable {
	return 0 if (!$field);
	my $from = shift;
	my $to = shift;
	my $min_obstacle_size = shift;
	$min_obstacle_size = 5 if (!defined $min_obstacle_size);

	my $dist = round(distance($from, $to));
	my %vec;

	getVector(\%vec, $to, $from);
	# Simulate walking from $from to $to
	for (my $i = 1; $i < $dist; $i++) {
		my %p;
		moveAlongVector(\%p, $from, \%vec, $i);
		$p{x} = int $p{x};
		$p{y} = int $p{y};

		if ( !$field->isWalkable($p{x}, $p{y}) ) {
			# The current spot is not walkable. Check whether
			# this the obstacle is small enough.
			if (checkWallLength(\%p, -1,  0, $min_obstacle_size) || checkWallLength(\%p,  1, 0, $min_obstacle_size)
			 || checkWallLength(\%p,  0, -1, $min_obstacle_size) || checkWallLength(\%p,  0, 1, $min_obstacle_size)
			 || checkWallLength(\%p, -1, -1, $min_obstacle_size) || checkWallLength(\%p,  1, 1, $min_obstacle_size)
			 || checkWallLength(\%p,  1, -1, $min_obstacle_size) || checkWallLength(\%p, -1, 1, $min_obstacle_size)) {
				return 0;
			}
		}
	}
	return 1;
}

sub checkWallLength {
	my $pos = shift;
	my $dx = shift;
	my $dy = shift;
	my $length = shift;

	my $x = $pos->{x};
	my $y = $pos->{y};
	my $len = 0;
	do {
		last if ($x < 0 || $x >= $field{width} || $y < 0 || $y >= $field{height});
		$x += $dx;
		$y += $dy;
		$len++;
	} while (!$field->isWalkable($x, $y) && $len < $length);
	return $len >= $length;
}

##
# closestWalkableSpot(r_field, pos)
# r_field: a reference to a field hash.
# pos: reference to a position hash (which contains 'x' and 'y' keys).
# Returns: 1 if %pos has been modified, 0 of not.
#
# If the position specified in $pos is walkable, this function will do nothing.
# If it's not walkable, this function will find the closest position that is walkable (up to 2 blocks away),
# and modify the x and y values in $pos.
sub closestWalkableSpot {
	my $field = shift;
	my $pos = shift;

	foreach my $z ( [0,0], [0,1],[1,0],[0,-1],[-1,0], [-1,1],[1,1],[1,-1],[-1,-1],[0,2],[2,0],[0,-2],[-2,0] ) {
		next if !$field->isWalkable($pos->{x} + $z->[0], $pos->{y} + $z->[1]);
		$pos->{x} += $z->[0];
		$pos->{y} += $z->[1];
		return 1;
	}
	return 0;
}

##
# objectInsideSpell(object, [ignore_party_members = 1])
# object: reference to a player or monster hash.
#
# Checks whether an object is inside someone else's spell area.
# (Traps are also "area spells").
sub objectInsideSpell {
	my $object = shift;
	my $ignore_party_members = shift;
	$ignore_party_members = 1 if (!defined $ignore_party_members);

	my ($x, $y) = ($object->{pos_to}{x}, $object->{pos_to}{y});
	foreach (@spellsID) {
		my $spell = $spells{$_};
		if ((!$ignore_party_members || !$char->{party} || !$char->{party}{users}{$spell->{sourceID}})
		  && $spell->{sourceID} ne $accountID
		  && $spell->{pos}{x} == $x && $spell->{pos}{y} == $y) {
			return 1;
		}
	}
	return 0;
}

##
# objectIsMovingTowards(object1, object2, [max_variance])
#
# Check whether $object1 is moving towards $object2.
sub objectIsMovingTowards {
	my $obj = shift;
	my $obj2 = shift;
	my $max_variance = (shift || 15);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc})) {
		# $obj is still moving
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});
		return checkMovementDirection($obj->{pos}, \%vec, $obj2->{pos_to}, $max_variance);
	}
	return 0;
}

##
# objectIsMovingTowardsPlayer(object, [ignore_party_members = 1])
#
# Check whether an object is moving towards a player.
sub objectIsMovingTowardsPlayer {
	my $obj = shift;
	my $ignore_party_members = shift;
	$ignore_party_members = 1 if (!defined $ignore_party_members);

	if (!timeOut($obj->{time_move}, $obj->{time_move_calc}) && @playersID) {
		# Monster is still moving, and there are players on screen
		my %vec;
		getVector(\%vec, $obj->{pos_to}, $obj->{pos});

		my $players = $playersList->getItems();
		foreach my $player (@{$players}) {
			my $ID = $player->{ID};
			next if (
			     ($ignore_party_members && $char->{party} && $char->{party}{users}{$ID})
			  || ($ID eq $char->{homunculus}{ID})
			  || (defined($player->{name}) && existsInList($config{tankersList}, $player->{name}))
			  || $player->{statuses}{"GM Perfect Hide"});
			if (checkMovementDirection($obj->{pos}, \%vec, $player->{pos}, 15)) {
				return 1;
			}
		}
	}
	return 0;
}

