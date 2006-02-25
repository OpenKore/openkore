#########################################################################
#  OpenKore - Interface to the GNU readline library
#  This module is used internally by the Console::Unix interface.
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

# Functions in this module are implemented in auto/XSTools/unix/readline.xs
package ReadLine;

use 5.006;
use strict;
use warnings;
use Carp;

use XSTools;
XSTools::bootModule("ReadLine");

1;
