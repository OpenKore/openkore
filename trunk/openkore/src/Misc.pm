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
use Log qw(message);

our @EXPORT = qw(
	printItemDesc
	whenAffected
	whenAffectedPL
	whenStatusActive
	whenStatusActivePL
	);


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
		$affected += $chars[$config{char}]{ailments}{$arr[$j]};
	}
	return $affected;
}

sub whenAffectedPL {
	my $ID = shift;
	my $ailments= shift;
	my $affected = 0;
	my @arr = split / *, */, $ailments;
	for (my $j = 0; $j < @arr; $j++) {
		$affected += $players{$ID}{ailments}{$arr[$j]};
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

sub whenStatusActivePL {
	my $ID = shift;
	my $statuses = shift;
	my $active = 0;
	my @arr = split / *, */, $statuses;
	for (my $j = 0; $j < @arr; $j++) {
		$active += $players{$ID}{statuses}{$arr[$j]};
	}
	return $active;
}

return 1;
