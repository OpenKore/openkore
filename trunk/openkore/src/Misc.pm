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

our @EXPORT = qw(
	auth
	configModify
	setTimeout

	checkFollowMode
	getPortalDestName
	printItemDesc
	whenAffected
	whenAffectedMon
	whenAffectedPL
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

	message("Config '$key' set to $val\n") unless ($silent);
	$config{$key} = $val;
	saveConfigFile();
}

sub setTimeout {
	my $timeout = shift;
	my $time = shift;
	$timeout{$timeout}{'timeout'} = $time;
	message "Timeout '$timeout' set to $time\n";
	writeDataFileIntact2("control/timeouts.txt", \%timeout);
}


#######################################
#######################################
# OTHER STUFF
#######################################
#######################################


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

sub whenAffected {
	my $ailments = shift;
	my $affected = 0;
	my @arr = split / *, */, $ailments;
	for (my $j = 0; $j < @arr; $j++) {
		$affected += $chars[$config{char}]{ailments}{$arr[$j]} + $chars[$config{char}]{state}{$arr[$j]} + $chars[$config{char}]{looks}{$arr[$j]};
	}
	return $affected;
}

sub whenAffectedMon {
	my $ID = shift;
	my $ailments= shift;
	my $affected = 0;
	my @arr = split / *, */, $ailments;
	for (my $j = 0; $j < @arr; $j++) {
		$affected += $monsters{$ID}{ailments}{$arr[$j]} + $monsters{$ID}{state}{$arr[$j]} + $monsters{$ID}{looks}{$arr[$j]};
	}
	return $affected;
}

sub whenAffectedPL {
	my $ID = shift;
	my $ailments= shift;
	my $affected = 0;
	my @arr = split / *, */, $ailments;
	for (my $j = 0; $j < @arr; $j++) {
		$affected += $players{$ID}{ailments}{$arr[$j]} + $players{$ID}{state}{$arr[$j]} + $players{$ID}{looks}{$arr[$j]};
	}
	return $affected;
}

sub whenStatusActive {
	my $statuses = shift;
	my $active = 0;
	my @arr = split / *, */, $statuses;
	for (my $j = 0; $j < @arr; $j++) {
		$active += $chars[$config{char}]{statuses}{$arr[$j]};
	}
	return $active;
}

sub whenStatusActiveMon {
	my ($ID, $statuses) = @_;
	my $active = 0;
	my @arr = split / *, */, $statuses;
	for (my $j = 0; $j < @arr; $j++) {
		$active += $monsters{$ID}{statuses}{$arr[$j]};
	}
	return $active;
}

sub whenStatusActivePL {
	my ($ID, $statuses) = @_;
	if ($ID eq $accountID) { return whenStatusActive($statuses) }
	my $active = 0;
	my @arr = split / *, */, $statuses;
	for (my $j = 0; $j < @arr; $j++) {
		$active += $players{$ID}{statuses}{$arr[$j]};
	}
	return $active;
}

##
# saveConfigFile()
#
# Writes %config to config.txt.
sub saveConfigFile {
	writeDataFileIntact($Settings::config_file, \%config);
}

return 1;
