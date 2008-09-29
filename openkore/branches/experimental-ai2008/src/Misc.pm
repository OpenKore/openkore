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
# This module is a base class for classes that contains functions that do not belong in any other modules.
# The difference between Misc.pm and Utils.pm is that Misc.pm can have
# dependencies on other Kore modules.

package Misc;

use strict;
use Exporter;
use Carp::Assert;
use Data::Dumper;
use Compress::Zlib;
use base qw(Exporter);
# use encoding 'utf8';

sub MODINIT {
	OpenKoreMod::initMisc() if (defined(&OpenKoreMod::initMisc));
}

return 1;
