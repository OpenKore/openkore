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
#
#
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Keyboard input system
#
# FIXME: this description is outdated. Update it.
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
use Settings;
use Interface;
use Log;
use Utils;

our @ISA = "Exporter";
our @EXPORT_OK = qw(&init &stop &canRead &readLine $enabled);

our $use_curses = 0; #hasn't been writen yet

# This will load proper OS module at run time
sub MODINIT {
}

##
# Input::start()
#
# Initializes the input system. You must call this function
# to be able to use the input system.
#
sub start {
	return Interface::start();
}

##
# Input::stop()
#
# Stops the input system. The input client process
# will be terminated and sockets will be freed.
#
sub stop {
	return Interface::stop();
}

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
# deprecated

##
# Input::getInput(wait)
# wait: Whether to wait until keyboard data is available.
# Returns: The keyboard data (including newline) as a string, or undef if there's no
#          keyboard data available or if the input system hasn't been initialized.
#
# Reads keyboard data.
#
# Now just a wrapper around Interface::getInput (though note that
# Interface::getInput's arguments are sligtly different)
sub getInput {
	my $wait = shift;
	return Interface::getInput(-1) if $wait;
	return Interface::getInput(0);
}

#END {
#	stop();
#}

return 1;
