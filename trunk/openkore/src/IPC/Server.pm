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
	my %ipc;
	$ipc{server} = IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr	=> 'localhost',
		LocalPort	=> $port,
		Proto		=> 'tcp',
		ReuseAddr	=> 1);
	return undef if (!$ipc{server});

	$ipc{port} = $ipc{server}->sockport();
	$ipc{clients} = [];
	$ipc{listeners} = [];
	bless \%ipc, $class;
	return \%ipc;
}

sub DESTROY {
	my $ipc = shift;
	delete $ipc->{clients};
	delete $ipc->{server};
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
# Each element in it is an array with two elements: element 0 is the
# ID of the message, and element 1 is a hash containing the parameters.
#
# Example:
# while (1) {
# 	foreach my $msg ($ipc->iterate) {
# 		my $ID = $msg->[0];
# 		my $params = $msg->[1];
# 		print "Received message with ID $ID.\n";
# 		print "Parameters:\n";
# 		foreach my $key (keys %{$params}) {
# 			print "$key = $params->{$key}\n";
# 		}
# 	}
# }
sub iterate {
	my $ipc = shift;

	# Checks whether a new client wants to connect
	if (dataWaiting($ipc->{server})) {
		# Accept connection from new client
		my %client;
		$client{sock} = $ipc->{server}->accept;
		$client{sock}->autoflush(0);
		$client{buffer} = '';

		binAdd($ipc->{clients}, \%client);
		debug("New client: " . $client{sock}->peerhost . "\n", "ipc");
	}

	# Check for input from clients
	my @messages;

	for (my $i = 0; $i < @{$ipc->{clients}}; $i++) {
		my $client = $ipc->{clients}[$i];
		next if (!defined $client);

		# Input available
		if (dataWaiting(\$client->{sock})) {
			my $data = _readData($client->{sock});
			if (!defined $data) {
				# Client disconnected
				debug("Client " . $client->{sock}->peerhost . " disconnected\n", "ipc");
				delete $ipc->{clients}[$i];
				next;
			}

			my ($ID, %hash);
			$client->{buffer} .= $data;

			while (($ID = IPC::Protocol::decode($client->{buffer}, \%hash, \$client->{buffer}))) {
				my %copy = %hash;
				foreach my $listener (@{$ipc->{listeners}}) {
					next if (!defined $listener);
					$listener->{'func'}->($client, $ID, \%copy, $listener->{'user_data'});
				}
				push @messages, [$ID, \%copy];
				undef %hash;
			}
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
# Registers a listener function. Every time a client has sent data,
# r_func will be called, in this way:
# <pre>
# $r_func->($client_socket, $messageID, \%messageArguments, $user_data)
# </pre>
sub addListener {
	my ($ipc, $r_func, $user_data) = @_;
	my %listener;

	$listener{'func'} = $r_func;
	$listener{'user_data'} = $user_data;
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
# $ipc->broadcast(ID, hash)
# ID: The ID of this message.
# hash: A reference to a hash, containing the arguments for this message.
#
# Send a message to all connected clients.
sub broadcast {
	my ($ipc, $ID, $hash) = @_;
	my $msg;

	$msg = IPC::Protocol::encode($ID, $hash);
	for (my $i = 0; $i < @{$ipc->{clients}}; $i++) {
		my $client = $ipc->{clients}[$i];
		next if (!defined $client);

		if (!_sendData($client->{sock}, $msg)) {
			debug("Client " . $client->{sock}->peerhost . " disconnected\n", "ipc");
			delete $ipc->{clients}[$i];
		}
	}
}

return 1;
