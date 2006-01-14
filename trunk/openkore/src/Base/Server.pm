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
# MODULE DESCRIPTION: Basic implementation of a TCP/IP server
#
# When writing TCP servers, a significant amount of time is spent in
# handling connection issues (such as establishing connections, client
# multiplexing, etc). This class makes it easier to write a TCP server
# by handling all connection issues for you, so you can concentrate
# on handling the protocol.
#
# You are supposed to create a class which is derived from Base::Server.
# Override the abstract methods onClientNew(), onClientExit() and
# onClientData() (see the API specification).
#
# <h3>Example</h3>
# Here is an example of how to use Base::Server (MyServer.pm):
# <pre class="example">
# package MyServer;
#
# use strict;
# use Base::Server;
# use base qw(Base::Server);
#
# sub onClientNew {
#     my ($self, $client, $index) = @_;
#     print "Client $index connected.\n";
# }
#
# sub onClientExit {
#     my ($self, $client, $index) = @_;
#     print "Client $index disconnected.\n";
# }
#
# sub onClientData {
#     my ($self, $client, $data, $index) = @_;
#     print "Client $index sent the following data: $data\n";
# }
#
# 1;
# </pre>
# And in the main script you write:
# <pre class="example">
# use strict;
# use MyServer;
#
# my $port = 1234;
# my $server = new MyServer($port);
# while (1) {
#     # Main loop
#     $server->iterate;
# }
# </pre>
#
# <h3>The client object</h3>
# See @MODULE(Base::Server::Client) for more information about how to use $client.

package Base::Server;

use strict;
use warnings;
no warnings 'redefine';
use IO::Socket::INET;
use Base::Server::Client;


################################
### CATEGORY: Constructor
################################

##
# Base::Server Base::Server->new([int port, String bind])
# port: the port to bind the server socket to. If unspecified, the first available port (as returned by the operating system) will be used.
# bind: the IP address to bind the server socket to. If unspecified, the socket will be bound to "localhost". Specify "0.0.0.0" to not bind to any address.
#
# Start a server at the specified port and IP address.
sub new {
	my $class = shift;
	my $port = (shift || 0);
	my $bind = (shift || 'localhost');
	my %self;

	$self{server} = IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr	=> $bind,
		LocalPort	=> $port,
		Proto		=> 'tcp',
		ReuseAddr	=> 1);
	return undef if (!$self{server});

	$self{port} = $self{server}->sockport;
	$self{clients} = [];
	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my $self = shift;

	# Disconnect all clients and close the server
	foreach my $client (@{$self->{clientsID}}) {
		$client->{sock}->close if ($client && $client->{sock}
					   && $client->{sock}->connected);
	}
	$self->{server}->close if ($self->{server});
}


################################
### CATEGORY: Methods
################################

sub clients {
	return $_[0]->{clients};
}

##
# int $BaseServer->port()
# Returns: a port number.
# Ensure: result > 0
#
# Get the port on which the server is started.
sub port {
	return $_[0]->{port};
}

##
# void $BaseServer->iterate()
#
# Handle connection issues. You should call this function in your
# program's main loop.
sub iterate {
	my $self = shift;

	# Checks whether a new client wants to connect
	my $bits = '';
        vec($bits, fileno($self->{server}), 1) = 1;
	if (select($bits, undef, undef, 0) > 0) {
		$self->_newClient();
	}

	foreach my $client (@{$self->{clients}}) {
		next if (!$client);
		if (!$client->{sock} || !$client->{sock}->connected) {
			# A client disconnected
			$self->_exitClient($client, $client->{index});
			next;
		}

		$bits = '';
		vec($bits, $client->{fd}, 1) = 1;
		if (select($bits, undef, undef, 0) > 0) {
			# Incoming data from client
			my $data;

			eval {
				$client->{sock}->recv($data, 32 * 1024, 0);
			};
			if (!defined($data) || length($data) == 0) {
				# Client disconnected
				$self->_exitClient($client, $client->{index});

			} else {
				$self->onClientData($client, $data, $client->{index});
			}
		}
	}
}

##
# boolean $BaseServer->sendData(Base::Server::Client client, Bytes data)
#
# This function is obsolete. Use $BaseServerClient->send() instead.
sub sendData {
	my ($self, $client) = @_;
	return $client->send($_[2]);
}


####################################
### CATEGORY: Abstract methods
####################################

##
# abstract void $BaseServer->onClientNew(Base::Server::Client client, int index)
# client: a client object (see overview).
# index: the client's index (same as $client->getIndex).
# Requires: defined($client)
#
# This method is called when a new client has connected to the server.
sub onClientNew {
}

##
# abstract void $BaseServer->onClientExit(Base::Server::Client client, int index)
# client: a client object (see overview).
# index: the client's index (same as $client->getIndex).
# Requires: defined($client)
#
# This method is called when a client has disconnected from the server.
sub onClientExit {
}

##
# abstract void $BaseServer->onClientData(Base::Server::Client client, Bytes data, int index)
# client: a client object (see overview).
# data: the data this client received.
# index: the client's index (same as $client->getIndex).
# Requires: defined($client) && defined($data)
#
# This method is called when a client has received data.
sub onClientData {
}


##############
# Private
##############

# Accept connection from new client
sub _newClient {
	my $self = shift;
	my ($sock, $client, $index);

	$sock = $self->{server}->accept;
	$sock->autoflush(0);

	# Find an empty slot in the client list
	$index = @{$self->{clients}};
	for (my $i = 0; $i < @{$self->{clients}}; $i++) {
		if (!$self->{clients}[$i]) {
			$index = $i;
			last;
		}
	}

	$client = new Base::Server::Client($sock, $sock->peerhost, fileno($sock), $index);
	$self->{clients}[$index] = $client;
	$self->onClientNew($client, $index);
}

# A client disconnected
sub _exitClient {
	my ($self, $client, $i) = @_;

	$self->onClientExit($client, $i);
	delete $self->{clients}[$i];
}


return 1;
