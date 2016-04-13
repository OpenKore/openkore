#########################################################################
#  OpenKore - Ragnarok Online Assistent
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
# MODULE DESCRIPTION: Basic implementation of a WebSocket server
#
# <b>Derived from Base::Server.pm</b>
package Base::WebSocketServer;

use strict;
use Time::HiRes qw(time);
use Protocol::WebSocket;
use Base::Server;
use base qw(Base::Server);


##
# Base::WebSocketServer Base::WebSocketServer->new([int port, String bind])
# port: the port to bind the server socket to. If unspecified, the first available port (as returned by the operating system) will be used.
# bind: the IP address to bind the server socket to. If unspecified, the socket will be bound to "localhost". Specify "0.0.0.0" to not bind to any address.
#
# Create a new Base::WebSocketServer object at the specified port and IP address.

sub onClientData {
	my ($self, $client, $data, $index) = @_;

	$client->{websocket_hs} ||= Protocol::WebSocket::Handshake::Server->new;
	$client->{websocket_frame} ||= Protocol::WebSocket::Frame->new;

	unless ($client->{websocket_hs}->is_done) {
		$client->{websocket_hs}->parse($data);

		if ($client->{websocket_hs}->is_done) {
			$client->send($client->{websocket_hs}->to_string);
		}

		return
	}

	$client->{websocket_frame}->append($data);

	while (defined(my $message = $client->{websocket_frame}->next)) {
		$self->message($message, $client);
	}
}

##
# abstract void $BaseWebSocketServer->message(String message, Base::WebServer::Client client)
#
# This virtual method will be called every time a message is received.
sub message {}

##
# void $BaseWebSocketServer->broadcast(String message)
#
# Send a message to all clients.
sub broadcast {
	my ($self, $message) = @_;

	for my $client (@{$self->{BS_clients}->getItems}) {
		next unless $client->{websocket_hs} && $client->{websocket_hs}->is_done;

		$client->send($client->{websocket_frame}->new($message)->to_bytes);
	}
}


1;
