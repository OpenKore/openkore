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

package IPC::Server;

use strict;
use warnings;
no warnings 'redefine';
use base qw(Base::Server);

use Base::Server;
use Log qw(debug);
use IPC::Messages qw(encode decode);


##
# IPC::Server->new([port])
# port: Start the server at the specified port.
# Returns: an IPC::Server object.
#
# Initializes an IPC server.
sub new {
	my ($class, $port) = @_;
	my $self;

	$self = $class->SUPER::new($port);
	return if (!$self);

	$self->{listeners} = [];
	$self->{maxID} = 0;
	$self->{messages} = [];
	$self->{ipc_clients} = {};

	return $self;
}

##
# $ipc->broadcast(excludeClient, msgID, hash)
# excludeClient: A client ID. The message will be broadcasted to all clients, except this one. Pass undef if you want to broadcast to all clients.
# msgID: The ID of this message.
# hash: A reference to a hash, containing the arguments for this message.
#
# Send a message to all connected clients.
sub broadcast {
	my ($self, $exclude, $msgID, $hash) = @_;
	my $msg;

	$msg = encode($msgID, $hash);
	foreach my $client (@{$self->{clients}}) {
		next if (!defined $client || (defined($exclude) && $client->{ID} eq $exclude));
		$self->sendData($client, $msg);
	}
}

##
# $ipc->send(clientID, msgID, hash)
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

# Process IPC message
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
