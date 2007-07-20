#########################################################################
#  OpenKore - Bus System
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
# MODULE DESCRIPTION: Abstract bus server
#
# This module implements a bare-bones bus server. It knows how to parse
# messages, but knows nothing about the actual protocol.
# This module is used by the official bus server implementation and
# should not be used directly.
#
# This class is derived from @MODULE(Base::Server) and extends the client object
# with the following members:
# <dl class="hashkeys">
# <dt>int ID</dt>
# <dd>An ID for this client (<b>client ID</b>). This ID is unique in this Bus::AbstractServer object.
# In other words, the same Bus::AbstractServer object will not have two clients with the
# same ID.</dd>
#
# <dt>Bytes buffer</dt>
# <dd>A buffer for network data. Don't use this.</dd>
# </dl>

package Bus::Server::AbstractServer;

use strict;
use warnings;
no warnings 'redefine';

use Base::Server;
use base qw(Base::Server);
use Bus::Messages qw(serialize);
use Bus::MessageParser;
use Log qw(debug);


##
# Bus::Server::AbstractServer->new([int port, String bind])
# port: Start the server at the specified port.
# bind: Bind the server at the specified IP.
#
# Create a new bus server. See Base::Server->new() for a description of the parameters.
sub new {
	my ($class, $port, $bind) = @_;
	my $self;

	$self = $class->SUPER::new($port, $bind);
	$self->{BAS_maxID} = 0;
	$self->{BAS_busClients} = {};

	return $self;
}

##
# $Bus_Server_AbstractServer->send(int clientID, String messageID, args)
# Returns: 1 on success, 0 when failed to send data through the socket, -1 if the specified client doesn't exist.
#
# Send a message to the specified client.
sub send {
	my ($self, $clientID, $messageID, $args) = @_;

	my $client = $self->{BAS_busClients}{$clientID};
	if ($client) {
		return $client->send(serialize($messageID, $args));
	} else {
		return -1;
	}
}

sub getBusClient {
	my ($self, $clientID) = @_;
	return $self->{BAS_busClients}{$clientID};
}


#######################################
### CATEGORY: Abstract methods
#######################################

##
# $Bus_Server_AbstractServer->messageReceived(client, String messageID, args)
#
# Process a bus message.
sub messageReceived {
}


#######################################
# Abstract method implementations
#######################################

sub onClientNew {
	my ($self, $client) = @_;

	$client->{BAS_parser} = new Bus::MessageParser();
	$client->{ID} = $self->{BAS_maxID};
	$self->{BAS_maxID}++;
	$self->{BAS_busClients}{$client->{ID}} = $client;

	debug("New client: " . $client->getIP() . " ($client->{ID})\n", "bus");
}

sub onClientExit {
	my ($self, $client) = @_;

	debug("Client disconnected: " . $client->getIP() . " ($client->{ID})\n", "bus");
	delete $self->{BAS_busClients}{$client->{ID}};
}

sub onClientData {
	my ($self, $client, $data) = @_;
	my $parser = $client->{BAS_parser};
	$parser->add($data);

	my $ID;
	while (my $args = $parser->readNext(\$ID)) {
		$self->messageReceived($client, $ID, $args);
	}
}


return 1;
