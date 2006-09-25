#########################################################################
#  OpenKore - Unix-specific functions
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
# MODULE DESCRIPTION: Unix-specific utility functions.

# Functions in this module are implemented in auto/XSTools/unix/unix.xs
package Utils::Unix;

use strict;
use warnings;

use XSTools;
XSTools::bootModule("Utils::Unix");

##
# Utils::Unix::getTerminalSize()
# Returns: an array with 2 elements: the width and height.
#
# Get the size of the active terminal.

1;
