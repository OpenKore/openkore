#########################################################################
#  OpenKore - Utility functions written in C for speed
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

# Functions in this module are implemented in auto/XSTools/misc/fastutils.xs
package FastUtils;

use strict;
use warnings;
use Time::HiRes;

use XSTools;
XSTools::bootModule('FastUtils');

1;
