#########################################################################
#  OpenKore - Win32-specific functions
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Windows-specific utility functions.

# Functions in this module are implemented in auto/XSTools/win32/wrapper.xs
package Utils::Win32;

use 5.006;
use strict;
use warnings;
use Carp;

use XSTools;
XSTools::bootModule('Utils::Win32');

##
# void Utils::Win32::playSound(String file)
# Requires: defined($file)
#
# Play a .wav file.

##
# void Utils::Win32::printConsole(String message)
# Requires: defined($message)
#
# Print a message to the console. This function supports Unicode.

##
# void Utils::Win32::setConsoleTitle(String title)
# Requires: defined($title)
#
# Sets the current console's title. This function supports Unicode.

##
# boolean Utils::Win32::ShellExecute(int windowHandle, String operation, String file)
#
# Open a file.

1;
