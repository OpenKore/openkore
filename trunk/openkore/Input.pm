#########################################################################
#  OpenKore - Keyboard input system
#  Asynchronously read from console.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Keyboard input system
#
# There's no good way to asynchronously read keyboard input.
# To work around this problem, Kore uses a so-called input server.
#
# Kore starts a server socket and forks a new process:
# `l
# - The parent process is the main process and input server. It and handles
#   the connection to the RO server, the AI, etc.
# - The child process is the input client. It reads from STDIN and sends
#   the data to the input server.
# - The parent process polls the input server for available data. If there's
#   data, read from it and parse it.
# `l`
#
# <img src="input-client.png" width="453" height="448" alt="Overview of the input system">
#
# The functions in this module are only meant to be used in the main process.

package Input;

use strict;
use warnings; #can comment this out for releases, but If I do my job that will never be needed
use Exporter;
#use IO::Socket::INET;
use Settings;
use Log;
use Utils;
#use POSIX;

our @ISA = "Exporter";
our @EXPORT_OK = qw(&init &stop &canRead &readLine $enabled);

our $use_curses = 0; #hasn't been writen yet

##
# This will load proper OS module at run time
if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
	eval <<"	EOW32";
		use Input::Win32;
	EOW32
	die $@ if $@; #rethrow errors
} else {
	if ($use_curses) {
		eval <<"		EOC";
			use Input::Curses;
		EOC
		#if that didn't work it's probably because curses is missing
		#that's ok, just try to use the IO::Select method instead
		#we may want to warn, but we may not, but this isn't OpenKore,
		#so we don't have nice logging
		warn $@ if $@;
	}
	if (!$use_curses || $@) {
		eval <<"		EOO";
			use Input::Other;
		EOO
		die $@ if $@; #rethrow errors
	}
}

##
# Input::start()
#
# Initializes the input system. You must call this function
# to be able to use the input system.
#
# Exported from a Input::* module

##
# Input::stop()
#
# Stops the input system. The input client process
# will be terminated and sockets will be freed.
#
# Exported from a Input::* module


##
# Input::canRead()
# Returns: 1 if there is keyboard data, 0 if not or if the input system hasn't been initialized.
#
# Checks whether there is keyboard data available. You don't have to use this function.
# Just call getInput(0) instead.
#
# Example:
# # The following lines are semantically equal:
# Input::canRead() && Input::getInput(0);
# Input::getInput(1);
#
# Exported from a Input::* module

##
# Input::getInput(wait)
# wait: Whether to wait until keyboard data is available.
# Returns: The keyboard data (including newline) as a string, or undef if there's no
#          keyboard data available or if the input system hasn't been initialized.
#
# Reads keyboard data.
#
# Exported from a Input::* module


END {
	stop();
}

return 1;
