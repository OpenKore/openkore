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

my (%fgcolors, %bgcolors);

##
# Utils::Unix::getTerminalSize()
# Returns: an array with 2 elements: the width and height.
#
# Get the size of the active terminal.

##
# Bytes Utils::Unix::getColorForMessage(Hash consoleColors, String type, String domain)
#
# Return the ANSI color code for the given message type and domain.
sub getColorForMessage {
	my ($consoleColors, $type, $domain) = @_;

	return if (!$consoleColors->{''} || !$consoleColors->{''}{useColors});
	my $color;
	if ($consoleColors->{$type}) {
		$domain = 'default' if (!defined $domain);
		$color = $consoleColors->{$type}{$domain};
		$color = $consoleColors->{$type}{default} if (!defined $color);
	}
	$color = 'default' if (!defined $color);
	return getColor($color);
}

##
# Bytes Utils::Unix::getColor(String colorName)
#
# Return the ANSI color code for the given color name.
sub getColor {
	my $color = shift;
	my $code = '';

	$color =~ s/\/(.*)//;
	my $bgcolor = $1;

	$code = $fgcolors{$color} if (defined($color) && defined($fgcolors{$color}));
	$code .= $bgcolors{$bgcolor} if (defined($bgcolor) && defined($bgcolors{$bgcolor}));
	return $code;
}

# The following variables map foreground and background colors to ANSI color codes.
{
	use bytes;
	%fgcolors = (
		'reset'		=> "\e[0m",
		'default'	=> "\e[0m",

		'black'		=> "\e[0;30m",
		'darkgray'	=> "\e[1;30m",
		'darkgrey'	=> "\e[1;30m",

		'darkred'	=> "\e[0;31m",
		'red'		=> "\e[1;31m",

		'darkgreen'	=> "\e[0;32m",
		'green'		=> "\e[1;32m",

		'brown'		=> "\e[0;33m",
		'yellow'	=> "\e[1;33m",

		'darkblue'	=> "\e[0;34m",
		'blue'		=> "\e[1;34m",

		'darkmagenta'	=> "\e[0;35m",
		'magenta'	=> "\e[1;35m",

		'darkcyan'	=> "\e[0;36m",
		'cyan'		=> "\e[1;36m",

		'gray'		=> "\e[0;37m",
		'grey'		=> "\e[0;37m",
		'white'		=> "\e[1;37m",
	);

	%bgcolors = (
		'default'	=> "\e[22;40m",

		'black'		=> "\e[22;40m",
		'darkgray'	=> "\e[5;40m",
		'darkgrey'	=> "\e[5;40m",

		'darkred'	=> "\e[22;41m",
		'red'		=> "\e[5;41m",

		'darkgreen'	=> "\e[22;42m",
		'green'		=> "\e[5;42m",

		'brown'		=> "\e[22;43m",
		'yellow'	=> "\e[5;43m",

		'darkblue'	=> "\e[22;44m",
		'blue'		=> "\e[5;44m",

		'darkmagenta'	=> "\e[22;45m",
		'magenta'	=> "\e[5;45m",

		'darkcyan'	=> "\e[22;46m",
		'cyan'		=> "\e[5;46m",

		'gray'		=> "\e[22;47m",
		'grey'		=> "\e[22;47m",
		'white'		=> "\e[5;47m",
	);
}

1;
