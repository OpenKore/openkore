#########################################################################
#  OpenKore - Network
#  This module contains functions for sending packets to the server.
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
# MODULE DESCRIPTION: Connection handling
#
# The Network module handles connections to the Ragnarok Online server.
# The submodule Network::Send contains functions for sending all kinds of
# packets to the RO server.
#
# This module only handles connection issues, and nothing else. It doesn't do
# anything with the actual data. Network data is handled by another module.

package Network;

use strict;
use IO::Socket::INET;

use Globals;
use Plugins;
use Log qw(message error);
use Network::Send;


##
# Network::connectTo(r_socket, host, port)
# r_socket: a reference to a socket scalar.
# host: the host name/IP of the RO server to connect to.
# port: the port number of the RO server to connect to.
#
# Establish a connection to a Ragnarok Online server. You usually pass
# "\$remote_socket" (without the quotes) for the r_socket argument.
# An IO::Socket::INET scalar will be assigned to r_socket.
#
# This function is used internally by Network::checkConnection() and should not be used directly.
sub connectTo {
	my $r_socket = shift;
	my $host = shift;
	my $port = shift;
	my $return = 0;

	Plugins::callHook('Network::connectTo', {
		socket => $r_socket,
		return => \$return,
		host => $host,
		port => $port
	});
	return if ($return);

	message("Connecting ($host:$port)... ", "connection");
	$$r_socket = new IO::Socket::INET(
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp',
			Timeout		=> 4);
	($$r_socket && inet_aton($$r_socket->peerhost()) eq inet_aton($host)) ?
		message("connected\n", "connection") :
		error("couldn't connect\n", "connection");
}

##
# Network::disconnect(r_socket)
# r_socket: a reference to an IO::Socket::INET scalar.
#
# Disconnect from the current Ragnarok Online server.
# You usually pass "\$remote_socket" (without the quotes) for the r_socket argument.
#
# This function is used internally by Network::checkConnection() and should not be used directly.
sub disconnect {
	return if ($config{'XKore'});
	my $r_socket = shift;
	sendQuit(\$remote_socket) if ($conState == 5 && $remote_socket && $remote_socket->connected());

	if ($$r_socket && $$r_socket->connected()) {
		message("Disconnecting (".$$r_socket->peerhost().":".$$r_socket->peerport().")... ", "connection");
		close($$r_socket);
		!$$r_socket->connected() ?
			message("disconnected\n", "connection") :
			error("couldn't disconnect\n", "connection");
	}
}

##
# Network::checkConnection()
#
# (At this time, the checkConnection() function is in functions.pl. The plan is to eventually move that function to this module.)
# Handles any connection issues. Based on the current situation, this connect may
# re-connect to the RO server, disconnect, do nothing, etc.
# This function is meant to be run in the Kore main loop.
#
# See also: $conState (see the comment in <tt>functions.pl</tt>)


return 1;
