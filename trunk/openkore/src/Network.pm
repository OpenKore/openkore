#########################################################################
#  OpenKore - Packet sending
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
package Network;

use strict;
use IO::Socket::INET;

use Globals;
use Plugins;
use Log qw(message error);
use Network::Send;


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


return 1;
