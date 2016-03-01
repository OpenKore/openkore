# WayPoint
#
# for OpenKore 1.9.x
# 03.02.2006
#
# How to use:
# You can type:
# wp [map_coordinates]
# wp <x> <y> [<map name>]
# wp <map name>
#
# ICQ 266048166 (c) Click

package WayPoint;

use strict;
use Plugins;
use Log qw(message error);
use Translation qw(TF);
use Globals;
use Commands;
use AI qw(ai_route);

# Register command 'waypoint' hook
my $cmdHook = Commands::register( ['wp' , 'waypoint' , \&queuePoint] );


sub queuePoint {
	my $self;
	my (undef, $args) = @_;
	my ($arg1, $arg2, $arg3) = $args =~ /^(\d+) (\d+)(.*?)$/;

	my $map;
	if ($arg1 eq "") {
		$map = $args;
	} else {
		$map = $arg3;
	}
	$map =~ s/\s//g;
	my ($x, $y);
	if (($arg1 eq "" || $arg2 eq "") && !$map) {
		error TF("Syntax Error in function 'waypoint'\n" .
			"Usage: wp <x> <y> &| <map>\n"), "info";
	} elsif ($map eq "help") {
		message TF("------- WayPoint -------\n" .
			"<x> <y> [<map name>]		to the coordinates on a map\n" .
			"<map name> 			to map\n" .
			"----------------------------------------------\n"), "info";
	} else {
		AI::clear(qw/move route mapRoute/);
		$map = $field{name} if ($map eq "");
			if ($arg2 ne "") {
				message TF("Walking to waypoint: %s(%s, %s)\n", 
					$map, $arg1, $arg2), "success";
				$x = $arg1;
				$y = $arg2;
			} else {
				message TF("Walking to waypoint: %s(%s)\n", 
					$maps_lut{$map.'.rsw'}, $map), "success";
			}


				main::ai_route($map, $x, $y,
				attackOnRoute => 2,
				noSitAuto => 1,
				notifyUponArrival => 1);
		}
}

1;
