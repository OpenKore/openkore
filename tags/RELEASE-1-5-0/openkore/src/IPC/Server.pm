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
# This module implements a system which allows external programs to communicate
# with Kore (through a socket). Possibilities provided by this system includes:
# `l
# - Different Kore instances will be able to communicate with each other,
#   allowing better cooporation.
# - External programs can control Kore. You can, for example, write a user
#   interface for Kore as an external program.
# `l`
#
# <h3>How it works</h3>
# <img src="ipc.png" width="323" height="365" alt="Overview of the IPC system">
#
# The IPC subsystem sets up a server socket. Clients (which could be,
# for example, another Kore instance) can connect to that server socket
# to communicate with Kore.
#
# This module handles all the connection issues. The core Kore code
# doesn't have to worry about that.
#
# <h3>Usage</h3>
# The IPC system can be used in two ways:
# `l
# - Clients can register for events. Whenever Kore prints a message,
#   that message will be sent to the client too. This only happens if the
#   client has explicitly registered itself to receive events (in order to
#   reduce network traffic; not all clients have the need to receive events).
#   <br><img src="ipc-events.png" alt="Overview of how events are sent" width="568" height="563">
# - Clients can explicitly request information from Kore. They can, for example,
#   request the current HP, the current list of monsters on screen, etc.
# `l`
#
# This module implements the IPC server.

package IPC::Server;

use strict;
use warnings;
no warnings 'redefine';
use File::Spec;
use IO::Socket::INET;
use Exporter;
use base qw(Exporter);

use Log qw(message error debug);
use IPC::Protocol;
use Utils qw(binAdd dataWaiting);


##
# IPC::Server->new([port])
# port: Start the server at the specified port.
# Returns: an IPC::Server object.
#
# Initializes an IPC server.
sub new {
	my $class = shift;
	my $port = (shift || 0);
	my %self;
	$self{server} = IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr	=> 'localhost',
		LocalPort	=> $port,
		Proto		=> 'tcp',
		ReuseAddr	=> 1);
	return undef if (!$self{server});

	$self{port} = $self{server}->sockport();
	$self{clients} = {};
	$self{listeners} = [];
	$self{maxID} = 0;
	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my $self = shift;
	foreach (values %{$self->{clients}}) {
		next unless ($_ && $_->{sock});
		$_->{sock}->close;
	}
	$self->{server}->close if ($self->{server});
}


sub _readData {
	my $socket = shift;
	my $data;

	undef $@;
	eval {
		$socket->recv($data, 1024 * 32, 0);
	};

	if ($@ || !defined($data) || length($data) == 0) {
		return undef;
	}
	return $data;
}

sub _sendData {
	my ($socket, $data) = @_;

	undef $@;
	eval {
		$socket->send($data, 0);
		$socket->flush;
	};
	return 0 if ($@);
	return 1;
}

sub _newClient {
	my $self = shift;
	my %client;

	# Accept connection from new client
	$client{sock} = $self->{server}->accept;
	$client{sock}->autoflush(0);
	$client{host} = $client{sock}->peerhost;
	$client{buffer} = '';
	$client{ID} = $self->{maxID};
	$self->{maxID}++;

	$self->{clients}{$client{ID}} = \%client;
	debug("New client: $client{host} ($client{ID})\n", "ipc");

	foreach my $listener (@{$self->{listeners}}) {
		next if (!defined $listener);
		$listener->{func}->("connect", $client{ID}, undef, undef, $listener->{user_data});
	}
}

sub _processClient {
	my ($self, $clientID, $client, $r_messages) = @_;

	my $data = _readData($client->{sock});
	if (!defined $data) {
		# Client disconnected
		foreach my $listener (@{$self->{listeners}}) {
			next if (!defined $listener);
			$listener->{func}->("disconnect", $clientID, undef, undef, $listener->{user_data});
		}

		debug("Client $client->{host} ($clientID) disconnected\n", "ipc");
		delete $self->{clients}{$clientID};
		return;
	}

	my ($msgID, %hash);
	$client->{buffer} .= $data;

	while ( ($msgID = IPC::Protocol::decode($client->{buffer}, \%hash, \$client->{buffer})) ) {
		my %copy = %hash;
		foreach my $listener (@{$self->{listeners}}) {
			next if (!defined $listener);
			$listener->{func}->("msg", $clientID, $msgID, \%copy, $listener->{user_data});
		}
		push @{$r_messages}, {
			ID => $msgID,
			from => $clientID,
			params => \%copy
		};
		undef %hash;
	}
}


##
# $ipc->port()
# Returns: a port number.
#
# Get the port on which the server is started.
sub port {
	return $_[0]->{port};
}

##
# $ipc->iterate()
# Returns: an array of messages, if the clients sent any.
#
# Handle client connections input. You should call
# this function every time in the main loop.
#
# The messages that the clients sent are returned in an array.
# Each element in it is a hash, containing the following keys:
# `l
# - ID : the message ID
# - clientID : the ID of the client that sent the message
# - params : the message parameters
# `l`
#
# Example:
# while (1) {
# 	foreach my $msg ($ipc->iterate) {
# 		print "Received message with ID $msg->{ID} from client $msg->{clientID}.\n";
# 		print "Parameters:\n";
# 		foreach my $key (keys %{$msg->{params}}) {
# 			print "$key = $msg->{params}{$key}\n";
# 		}
# 	}
# }
sub iterate {
	my $self = shift;

	# Checks whether a new client wants to connect
	if (dataWaiting($self->{server})) {
		$self->_newClient();
	}

	# Check for input from clients
	my @messages;

	foreach my $clientID (keys %{$self->{clients}}) {
		my $client = $self->{clients}{$clientID};
		if (dataWaiting(\$client->{sock})) {
			$self->_processClient($clientID, $client, \@messages);
		}
	}

	return @messages;
}


##
# $ipc->addListener(r_func, user_data)
# r_func: Reference to a function.
# user_data: This argument will be passed to r_func when it's called.
# Returns: An ID which you can use to unregister this listener.
#
# Registers a listener function. Every time a client connected, sent data,
# or disconnected, r_func will be called, in this way:
# <pre>
# $r_func->($context, $clientID, $messageID, \%messageArguments, $user_data)
# </pre>
# $context is one of the following:
# `l
# - "connect" : a client connected.
# - "disconnect" : a client disconnected.
# - "msg" : a client sent a message.
# `l`
#
# Only when the context is "msg", $messageID and \%messageArguments are defined.
sub addListener {
	my ($ipc, $r_func, $user_data) = @_;
	my %listener;

	$listener{func} = $r_func;
	$listener{user_data} = $user_data;
	return binAdd($ipc->{listeners}, \%listener);
}

##
# $ipc->delListener(ID)
# ID: A listener ID, as returned by addListener().
#
# Unregisters a listener. r_func will not be called anymore each time a client has sent data.
sub delListener {
	my $ipc = shift;
	my $ID = shift;
	delete $ipc->{listeners}[$ID];
}


##
# $ipc->clients()
# Returns: an array of client IDs.
#
# List all clients currently connected to the server.
sub clients {
	my $self = shift;
	my @list;
	foreach (values %{$self->{clients}}) {
		next if (!$_);
		push @list, $_->{ID};
	}
	return @list;
}

##
# $ipc->broadcast(excludeClient, msgID, hash)
# excludeClient: A client ID. The message will be broadcasted to all clients, except this one. Pass undef if you want to broadcast to *all* clients.
# msgID: The ID of this message.
# hash: A reference to a hash, containing the arguments for this message.
#
# Send a message to all connected clients.
sub broadcast {
	my ($ipc, $exclude, $msgID, $hash) = @_;
	my $msg;

	$msg = IPC::Protocol::encode($msgID, $hash);
	foreach my $ID (keys %{$ipc->{clients}}) {
		my $client = $ipc->{clients}{$ID};
		next if (!defined $client || (defined($exclude) && $client->{ID} eq $exclude));

		if (!_sendData($client->{sock}, $msg)) {
			foreach my $listener (@{$ipc->{listeners}}) {
				next if (!defined $listener);
				$listener->{func}->("disconnect", $ID, undef, undef, $listener->{user_data});
			}

			debug("Client $client->{host} ($ID) disconnected\n", "ipc");
			delete $ipc->{clients}{$ID};
		}
	}
}

##
# $ipc->send(clientID, msgID, hash)
sub send {
	my ($ipc, $clientID, $msgID, $hash) = @_;

	if ( (my $client = $ipc->{clients}{$clientID}) ) {
		my $msg = IPC::Protocol::encode($msgID, $hash);
		if (!_sendData($client->{sock}, $msg)) {
			foreach my $listener (@{$ipc->{listeners}}) {
				next if (!defined $listener);
				$listener->{func}->("disconnect", $client->{ID}, undef, undef, $listener->{user_data});
			}

			debug("Client $client->{host} ($client->{ID}) disconnected\n", "ipc");
			delete $ipc->{clients}{$client->{ID}};
		}
	}
}

return 1;
