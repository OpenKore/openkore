#########################################################################
#  OpenKore - Miscellaneous functions
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Miscellaneous functions
#
# This module contains functions that do not belong in any other modules.
# The difference between Misc.pm and Utils.pm is that Misc.pm can have
# dependancies on other Kore modules.

package Misc;

use strict;
use Exporter;
use base qw(Exporter);

use Globals;
use Log qw(message warning);
use Plugins;
use FileParsers;
use Settings;
use Utils;

our @EXPORT = qw(
	auth
	configModify
	setTimeout
	saveConfigFile

	center
	checkFollowMode
	closestWalkableSpot
	getMapPoint
	getPortalDestName
	printItemDesc
	whenStatusActive
	whenStatusActiveMon
	whenStatusActivePL
	);



#######################################
#######################################
#CONFIG MODIFIERS
#######################################
#######################################

sub auth {
	my $user = shift;
	my $flag = shift;
	if ($flag) {
		message "Authorized user '$user' for admin\n", "success";
	} else {
		message "Revoked admin privilages for user '$user'\n", "success";
	}	
	$overallAuth{$user} = $flag;
	writeDataFile("$Settings::control_folder/overallAuth.txt", \%overallAuth);
}

##
# configModify(key, val, [silent])
# key: a key name.
# val: the new value.
# silent: if set to 1, do not print a message to the console.
#
# Changes the value of the configuration variable $key to $val.
# %config and config.txt will be updated.
sub configModify {
	my $key = shift;
	my $val = shift;
	my $silent = shift;

	Plugins::callHook('configModify', {
		key => $key,
		val => $val,
		silent => $silent
	});

	message("Config '$key' set to $val\n", "info") unless ($silent);
	$config{$key} = $val;
	saveConfigFile();
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	writeDataFileIntact($Settings::config_file, \%config);
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	$timeout{$timeout}{'timeout'} = $time;
	message "Timeout '$timeout' set to $time\n", "info";
	writeDataFileIntact2("$Settings::control_folder/timeouts.txt", \%timeout);
}


#######################################
#######################################
# OTHER STUFF
#######################################
#######################################


##
# center(string, width, [fill])
#
# This function will center $string within a field $width characters wide,
# using $fill characters for padding on either end of the string for
# centering. If $fill is not specified, a space will be used.
sub center {
	my ($string, $width, $fill) = @_;

	$fill ||= ' ';
	my $left = int(($width - length($string)) / 2);
	my $right = ($width - length($string)) - $left;
	return $fill x $left . $string . $fill x $right;
}

##
# checkFollowMode()
# Returns: 1 if in follow mode, 0 if not.
#
# Check whether we're current in follow mode.
sub checkFollowMode { 	 
	my $followIndex;
	if ($config{follow} && defined($followIndex = binFind(\@ai_seq, "follow"))) {
		return 1 if ($ai_seq_args[$followIndex]{following});
	}
	return 0;
}

##
# closestWalkableSpot(r_field, pos)
# r_field: a reference to a field hash.
# pos: reference to a position hash (which contains 'x' and 'y' keys).
#
# If the position specified in $pos is walkable, this function will do nothing.
# If it's not walkable, this function will find the closest position that is walkable (up to 2 blocks away),
# and modify the x and y values in $pos.
sub closestWalkableSpot {
	my $r_field = shift;
	my $pos = shift;

	foreach my $z ( [0,0], [0,1],[1,0],[0,-1],[-1,0], [-1,1],[1,1],[1,-1],[-1,-1],[0,2],[2,0],[0,-2],[-2,0] ) {
		next if getMapPoint($r_field,
				$pos->{'x'} + $z->[0],
				$pos->{'y'} + $z->[1]);
		$pos->{'x'} += $z->[0];
		$pos->{'y'} += $z->[1];
		last;
	}
}

##
# getMapPoint(r_field, x, y)
# r_field: a reference to a field hash.
# x, y: the coordinate on the map to check.
# Returns: 0 = walkable, 1 = not walkable, 5 = cliff (not walkable, but you can snipe)
#
# Check whether the coordinate specified by ($x, $y) is walkable.
sub getMapPoint {
	my $r_field = shift;
	my $x = shift;
	my $y = shift;

	if ($x < 0 || $x >= $r_field->{'width'} || $y < 0 || $y >= $r_field->{'height'}) {
		return 1;
	}
	return ord(substr($r_field->{rawMap}, ($y * $r_field->{'width'}) + $x, 1));
}

sub getPortalDestName {
	my $ID = shift;
	my %hash; # We only want unique names, so we use a hash
	foreach (keys %{$portals_lut{$ID}{'dest'}}) {
		my $key = $portals_lut{$ID}{'dest'}{$_}{'map'};
		$hash{$key} = 1;
	}

	my @destinations = sort keys %hash;
	return join('/', @destinations);
}

##
# printItemDesc(itemID)
#
# Print the description for $itemID.
sub printItemDesc {
	my $itemID = shift;
	message("===============Item Description===============\n", "info");
	message("Item: $items_lut{$itemID}\n\n", "info");
	message($itemsDesc_lut{$itemID}, "info");
	message("==============================================\n", "info");
}

sub whenStatusActive {
	my $statuses = shift;
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if exists($char->{statuses}{$_});
	}
	return 0;
}

sub whenStatusActiveMon {
	my ($ID, $statuses) = @_;
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if $monsters{$ID}{statuses}{$_};
	}
	return 0;
}

sub whenStatusActivePL {
	my ($ID, $statuses) = @_;
	if ($ID eq $accountID) { return whenStatusActive($statuses) }
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if $players{$ID}{statuses}{$_};
	}
	return 0;
}


return 1;
