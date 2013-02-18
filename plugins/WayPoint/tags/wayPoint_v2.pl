# WayPoint v.2
#
# for OpenKore 1.9.x
# 03.02.2006
#
# How to use:
# You can type:
# <x> <y> [<map name>]		to the coordinates on a map
#[<map name>] <x> <y>		to the coordinates on a map
#<map name> 			to map
#<portal#> 			to portal
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
	my (undef, $args) = @_;
	my ($arg1, $arg2, $arg3) = $args =~ /^(.+?) (.+?)(?: (.*))?$/;

	my ($map, $x, $y);
	if ($arg1 eq "") {
		# map name or portal number
		$map = $args;
	} elsif ($arg3 eq "") {
		# coordinates
		$x = $arg1;
		$y = $arg2;
		$map = $field{name};
	} elsif ($arg1 =~ /^\d+$/) {
		# coordinates and map
		$x = $arg1;
		$y = $arg2;
		$map = $arg3;
	} else {
		# map and coordinates
		$x = $arg2;
		$y = $arg3;
		$map = $arg1;
	}
	
	if ((($x !~ /^\d+$/ || $y !~ /^\d+$/) && $arg1 ne "") || ($args eq "")) {
		error TF("Syntax Error in function 'waypoint'\n" .
			"Usage: wp <x> <y> [<map>]\n" .
			"       wp <map> [<x> <y>]\n" .
			"       wp <map>\n" .
			"       wp <portal#>\n");
	} elsif ($map eq "help") {
		message TF("------- WayPoint -------\n" .
			"<x> <y> [<map name>]		to the coordinates on a map\n" .
			"[<map name>] <x> <y>		to the coordinates on a map\n" .
			"<map name> 			to map\n" .
			"<portal#> 			to portal\n" .
			"----------------------------------------------\n"), "info";
	} else {
		AI::clear(qw/move route mapRoute/);
		if ($maps_lut{"${map}.rsw"}) {
			if ($x ne "") {
				message TF("Walking to waypoint: %s(%s): %s, %s\n", 
					$maps_lut{$map.'.rsw'}, $map, $x, $y), "route";
			} else {
				message TF("Walking to waypoint: %s(%s)\n", 
					$maps_lut{$map.'.rsw'}, $map), "route";
			}


				main::ai_route($map, $x, $y,
				attackOnRoute => 2,
				noSitAuto => 1,
				notifyUponArrival => 1);
		} elsif ($map =~ /^\d+$/) {
			if ($portalsID[$map]) {
				message TF("Walking into portal number %s (%s,%s)\n", 
					$map, $portals{$portalsID[$map]}{'pos'}{'x'}, $portals{$portalsID[$map]}{'pos'}{'y'});
				main::ai_route($field{name}, $portals{$portalsID[$map]}{'pos'}{'x'}, $portals{$portalsID[$map]}{'pos'}{'y'}, attackOnRoute => 2, noSitAuto => 1);
			} else {
				error TF("No portals exist.\n");
			}
		} else {
			error TF("Map %s does not exist\n", $map);
		}
	}
}

1;
