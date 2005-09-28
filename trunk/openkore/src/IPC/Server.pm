#########################################################################
#  OpenKore - Inter-Process Communication system
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
# MODULE DESCRIPTION: Inter-process communication server
#
# This module implements a bare-bones IPC server. It knows how to parse
# messages, but knows nothing about the actual protocol.
# This module is used by the official IPC manager implementation and
# should not be used directly.
#
# This class is derived from Base::Server.pm and extends the client object
# with the following members:
# <dl class="hashkeys">
# <dt>ID</dt>
# <dd>An ID for this client (<b>client ID</b>). This ID is unique for this IPC::Server object.
# In other words, the same IPC::Server object will not have two clients with the
# same ID.</dd>
#
# <dt>buffer</dt>
# <dd>A buffer for network data. Don't use this.</dd>
# </dl>

package IPC::Server;

use strict;
use warnings;
no warnings 'redefine';
use base qw(Base::Server);

use Base::Server;
use Log qw(debug);
use IPC::Messages qw(encode decode);


##
# IPC::Server->new([port, bind])
# port: Start the server at the specified port.
# bind: Bind the server at the specified IP.
# Returns: an IPC::Server object.
#
# Starts an IPC server. See Base::Server->new() for a description of the parameters.
sub new {
	my ($class, $port, $bind) = @_;
	my $self;

	$self = $class->SUPER::new($port, $bind);
	return if (!$self);

	$self->{listeners} = [];
	$self->{maxID} = 0;
	$self->{messages} = [];
	$self->{ipc_clients} = {};

	return $self;
}

##
# $ipcserver->send(clientID, msgID, hash)
# Returns: 1 on success, 0 when failed to send data through the socket, -1 if the specified client doesn't exist.
#
# Send a message to the specified client.
sub send {
	my ($self, $clientID, $msgID, $hash) = @_;

	my $client = $self->{ipc_clients}{$clientID};
	if ($client) {
		my $msg = encode($msgID, $hash);
		return $self->sendData($client, $msg);
	} else {
		return -1;
	}
}


#######################################
### CATEGORY: Abstract methods
#######################################

##
# $ipcserver->onIPCData($client, $msgID, $args)
#
# Process an IPC message.
sub onIPCData {
}


#######################################
# Abstract method implementations
#######################################

sub onClientNew {
	my ($self, $client) = @_;

	$client->{buffer} = '';
	$client->{ID} = $self->{maxID};
	$self->{maxID}++;
	$self->{ipc_clients}{$client->{ID}} = $client;

	debug("New client: $client->{host} ($client->{ID})\n", "ipc");
}

sub onClientExit {
	my ($self, $client) = @_;

	debug("Client disconnected: $client->{host} ($client->{ID})\n", "ipc");
	delete $self->{ipc_clients}{$client->{ID}};
}

sub onClientData {
	my ($self, $client, $data) = @_;
	$client->{buffer} .= $data;

	my ($msgID, %hash);
	while ( ($msgID = decode($client->{buffer}, \%hash, \$client->{buffer})) ) {
		$self->onIPCData($client, $msgID, \%hash);
		undef %hash;
	}
}


return 1;
