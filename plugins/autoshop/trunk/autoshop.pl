package autoshop;

=head1 NAME

autoshop - an autoshop plugin for openkore

=head1 VERSION

Version 0.8

=head1 DESCRIPTION

The autoshop plugin creates a map of the area and adds players, shops and
chat rooms with different weights.

A player has a weight of 5. If that player has opened a shop the surrounding
fields will bei weighted depending on the distance to that player. Same for
chat rooms. The intension is to find a place where B<our> shop won't overlap
with others.

=head1 USAGE

=head2 configuration

=over

=item autoshop_maxweight

The maximum fieldweight that's accepted to be 'free'. Must be between 0 and 5.
Default is 0.

=item autoshop_tries

Number of tries to find a free place before giving up. Must be between 1 and 100.
Default is 16.

=item autoshop_radius

Start looking for a free place within the given radius. If it fails the radius
will be doubled. Must be between 1 and 14. Default is 5.

=item autoshop_reopenOnClose

Whether or not to reopen the shop when it's closed. Must be 0 or 1. Default is 0.

=back

=head2 commands

=over

=item suggest

Print suitable coordinates

=item shopmap

Dump the contents of the array to a file (C<shopmap.txt>)

=back

=head1 FOR THOSE WHO WANT TO KNOW

In a 30x30 array we save player characters (and homunculi) with a weight of 5.
If they own a shop or if they opened a chat room their surrounding fields will
get weights of 3 to 1. Non-walkable fields (walls, obstacles) cannot be
selected for a possible new position.

Example (size reduced):

 ....1..........
 ...121.........
 ..12321........
 .1235321....... <- there is a shop (5)
 ..12321........
 ...121.X....... <- the X marks our position
 ....1..........
 ...........5... <- the 5 marks another player
 ...............
 ...............
 ...............

 two shops (not overlapping)
 ...1...1.......
 ..121.121......
 .123222321.....
 12354445321.... <- the weights accumulate
 .123222321.....
 ..121.121......
 ...1...1.......


 two shops (overlapping)

 ...1.1.........
 ..12221........
 .1244421.......
 124767421...... <- the '7' mark the players
 .1244421.......
 ..12221........
 ...1.1.........



=head1 AVAILABILITY

C<svn co https://svn.sourceforge.net/svnroot/openkore/plugins/trunk/>

=head1 COPYRIGHT

This source code is licensed under the GNU General Public License, Version 2.
See L<http://www.gnu.org/licenses/gpl.html>

=head1 AUTHOR

Arachno <arachnophobia at users dot sf dot net>

=cut


use strict;
use Plugins;
use Globals;
use Utils;
use Misc;
use Log qw(message warning error);
use AI;

my $maxRad = 14;
my @vendermap;
my @chtRooms;
my $shopopen = 0;
                                        
Plugins::register('autoshop', 'checks our environment before opening shop', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['start3', \&checkConfig, undef],
	['AI_pre', \&autoshop, undef],
	['Command_post', \&commandHandler, undef]
);

sub Unload {
	Plugins::delHooks($hooks);
	message "autoshop unloaded.\n"
}

# checks configuration for silly settings
sub checkConfig {
	my $configs = {
		'autoshop_maxweight' => [0, 5, 0],
		'autoshop_tries' => [1, 100, 16],
		'autoshop_radius' => [1, $maxRad,  5],
		'autoshop_reopenOnClose' => [0, 1, 0]
	};
	foreach my $k (keys %{$configs}) {
		if ($::config{$k} < $configs->{$k}->[0] || $::config{$k} > $configs->{$k}->[1]) {
			error(sprintf("Your %s setting is either too high or too low (%d). Using default value (%d).\n",
				$k, $::config{$k}, $configs->{$k}->[2]));
			configModify($k, $configs->{$k}->[2])
		}
	}
}

# just a facade for "suggest" and "shopmap"
sub commandHandler {
	my (undef, $param) = @_;
	if ($param->{switch} eq 'suggest') {
		clearVendermap(); buildVendermap();
		if ($vendermap[$maxRad][$maxRad] <= $::config{autoshop_maxweight}) {
			message "your current position is okay (weight $vendermap[$maxRad][$maxRad])\n", "list"
		}
		my ($x, $y) = suggest($::config{autoshop_radius});
		if ($x && $y) {
			message "this would be a nice place for a shop: $x $y\n", "list"
		} else {
			message "could not find a free place. Try increasing autoshop_maxweight.\n", "list"
		}
		$param->{return} = 1
	} elsif ($param->{switch} eq 'shopmap') {
		showmap();
		$param->{return} = 1
	}
}


# walk to arg1, arg2
sub walkto {
	my %args;
	($args{move_to}{x}, $args{move_to}{y}) = @_;
	$args{time_move} = $char->{time_move};
	$args{ai_move_giveup}{timeout} = $timeout{ai_move_giveup}{timeout};
	AI::queue("move", \%args)
}

# suggests new coordinates
sub suggest {
	my $radius = shift;
	if ($radius > $maxRad) {
		$radius = $maxRad
	}
	my $pos = calcPosition($char);
	my ($randX, $randY, $realrandX, $realrandY);
	for (my $try = 0; $try <= $::config{autoshop_tries}; $try++) {
		$randX = $maxRad + $radius - int(rand(($radius*2)+1));
		$randY = $maxRad + $radius - int(rand(($radius*2)+1));
		next if $vendermap[$randX][$randY] > $::config{autoshop_maxweight};
		$realrandX = $pos->{x}+$randX-$maxRad;
		$realrandY = $pos->{y}+$randY-$maxRad;
		next unless $field->isWalkable($realrandX, $realrandY);
		return ($realrandX, $realrandY)
	}
	if ($radius == $maxRad) {
		warning "Could not find free coordinates. Giving up.";
		return (0,0)
	} else {
		return suggest($radius*2)
	}
}

# when called, this function checks whether we are on an already occupied field
# or a field with a weight > maxweight. If so, selects new coordinates and calls
# walk_and_recheck. If not, open shop.
sub autoshop {
	# exit if plugin is disabled
	return unless $::config{autoshop};
	# exit if the shop is already open
	return if $shopstarted;
	# exit when not connected
	if ($conState < 5) {
		$timeout{ai_autoshop}{time} = $timeout{ai_shop}{time} = time;
		return
	}
	# exit when ai is not idle
	unless (AI::isIdle) {
		$timeout{ai_shop}{time} = time;
		return
	}
	# reset shop status
	if ($::config{autoshop_reopenOnClose} && $shopopen) {
		$shopopen = 0
	}
	# exit when shop is marked open and we don't want to open it again
	return if $shopopen;
	# else
	if (timeOut($timeout{ai_autoshop}) && !$char->{muted} && !$char->{sitting}) {
		clearVendermap(); buildVendermap();
		if ($vendermap[$maxRad][$maxRad] > $::config{autoshop_maxweight}) {
			my ($x, $y) = suggest($::config{autoshop_radius});
			walkto($x, $y) if ($x && $y)
		} elsif (timeOut($timeout{ai_shop}) && !$shopopen) {
			$shopopen = 1;
			::openShop();
			return
		}
		$timeout{ai_autoshop}{time} = time
	}
}

# for those who are interested: dump the map to a file
sub showmap {
	clearVendermap(); buildVendermap();
	my $pos = calcPosition($char);
	open SHOPMAP, "> $Settings::logs_folder/shopmap.txt";
	for (my $y = $maxRad*2; $y > 0; $y--) {
		my ($line, $realX, $realY);
		$realY = $pos->{y}+$y-$maxRad;
		for (my $x = 0; $x <= $maxRad*2; $x++) {
			$realX = $pos->{x}+$x-$maxRad;
			if ($x == $maxRad && $y == $maxRad) {
				$line .= "X"
			} else {
				if (!$field->isWalkable($realX, $realY)) {
					$line .= "#"
				} elsif ($vendermap[$x][$y] == 0) {
					$line .= " "
				} else {
					$line .= sprintf("%X",$vendermap[$x][$y])
				}
			}
		}
		$line .= "\n";
		print SHOPMAP $line
	}
	close SHOPMAP;
	message "wrote shopmap.\n", "list"
}

# adds the shop environment of a vendor to the map
sub addToVendermap {
	my ($posX, $posY, $type, $realX, $realY) = @_;
	return unless $posX;
	if ($posX < 0 || $posY < 0) {
		error "[autoshop] $type ($realX $realY) out of array ($posX $posY)\n";
		return
	}

	if ($type eq 'player') {
		$vendermap[$posX][$posY] += 5;
		return
	}

	for (my $a = 0; $a < 3; $a++) {
		$vendermap[$posX+$a-3][$posY] += $a+1 if $posX+$a-3 >= 0;
		$vendermap[$posX-$a+3][$posY] += $a+1 if $posX-$a+3 <= 30;
		$vendermap[$posX][$posY+$a-3] += $a+1 if $posX+$a-3 >= 0;
		$vendermap[$posX][$posY-$a+3] += $a+1 if $posX-$a+3 <= 30
	}

	$vendermap[$posX+1][$posY+1] += 2;
	$vendermap[$posX+1][$posY+2] += 1;
	$vendermap[$posX+2][$posY+1] += 1;

	if ($posX >= 1) {
		$vendermap[$posX-1][$posY+1] += 2;
		$vendermap[$posX-1][$posY+2] += 1;
		$vendermap[$posX-2][$posY+1] += 1 if $posX >= 2
	}

	if ($posY >= 1) {
		$vendermap[$posX+1][$posY-1] += 2;
		$vendermap[$posX+2][$posY-1] += 1;
		$vendermap[$posX+1][$posY-2] += 1 if $posY >= 2
	}

	if ($posX >= 1 && $posY >= 1) {
		$vendermap[$posX-1][$posY-1] += 2;
		$vendermap[$posX-1][$posY-2] += 1 if $posY >= 2;
		$vendermap[$posX-2][$posY-1] += 1 if $posX >= 2
	}
}

# scans for players / vendors and builds the map
sub buildVendermap {
	my $arr = $_[0];
	if (!$arr) {
		buildVendermap(\@::venderListsID);
		refreshChatRooms();
		buildVendermap(\@chtRooms);
		buildVendermap(\@::playersID);
		return
	}

	my $pos = calcPosition($char);

	for (my $i = 0; $i < @{$arr}; $i++) {
		next unless $$arr[$i];
		my $player = $players{$$arr[$i]};
		next unless $player->{pos_to}{x};
		addToVendermap(
			$maxRad - $pos->{x} + $player->{pos_to}{x},
			$maxRad + $player->{pos_to}{y} - $pos->{y},
			($arr == \@::playersID)?'player':'vender',
			$player->{pos_to}{x},
			$player->{pos_to}{y}
		)
	}
}

sub clearVendermap {
	@vendermap = ();
	for (my $x = 0; $x <= $maxRad*2; $x++) {
		for (my $y = 0; $y <= $maxRad*2; $y++) {
			$vendermap[$x][$y] = 0
		}
	}
}
          
sub refreshChatRooms {
	@chtRooms = ();
	for (my $i = 0; $i < @::chatRoomsID; $i++) {
		push(@chtRooms, $::chatRooms{$::chatRoomsID[$i]}{'ownerID'})
	}
}

1;
