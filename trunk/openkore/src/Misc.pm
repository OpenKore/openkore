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

	checkFollowMode
	getPortalDestName
	printItemDesc
	whenStatusActive
	whenStatusActiveMon
	whenStatusActivePL

	center
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
	writeDataFile("control/overallAuth.txt", \%overallAuth);
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

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	$timeout{$timeout}{'timeout'} = $time;
	message "Timeout '$timeout' set to $time\n", "info";
	writeDataFileIntact2("control/timeouts.txt", \%timeout);
}


#######################################
#######################################
# OTHER STUFF
#######################################
#######################################


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
		return if exists($monsters{$ID}{statuses}{$_});
	return 0;
}

sub whenStatusActivePL {
	my ($ID, $statuses) = @_;
	if ($ID eq $accountID) { return whenStatusActive($statuses) }
	my @arr = split /,/, $statuses;
	foreach (@arr) {
		s/^\s+//g;
		s/\s+$//g;
		return 1 if exists($players{$ID}{statuses}{$_});
	}
	return 0;
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	writeDataFileIntact($Settings::config_file, \%config);
}

##
# center(<string>,<width>[,<fill>])
# 
# This function will center <string> within a field <width> characters wide,
# using <fill> characters for padding on either end of the string for
# centering. If <fill> is not specified, a space will be used.
sub center {
	my ($string, $width, $fill) = @_;

	$fill ||= ' ';
	my $left = int(($width - length($string)) / 2);
	my $right = ($width - length($string)) - $left;
	return $fill x $left . $string . $fill x $right;
}

return 1;
