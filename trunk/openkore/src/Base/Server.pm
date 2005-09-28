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
#     my ($client, $index) = @_;
#     print "Client $index connected.\n";
# }
#
# sub onClientExit {
#     my ($client, $index) = @_;
#     print "Client $index disconnected.\n";
# }
#
# sub onClientData {
#     my ($client, $data, $index) = @_;
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
# The client object is a reference to a hash with the following members:
# <dl class="hashkeys">
# <dt>sock</dt>
# <dd>The client's socket.</dd>
#
# <dt>host</dt>
# <dd>The client's IP address in text form.</dd>
#
# <dt>fd</dt>
# <dd>The file descriptor of sock, as returned by fileno().</dd>
#
# <dt>index</dt>
# <dd>An ID for this client. This ID is unique for this Base::Server object.
# In other words, the same Base::Server object will not have two clients with the
# same index.</dd>
# </dl>

package Base::Server;

use strict;
use warnings;
no warnings 'redefine';
use IO::Socket::INET;


################################
### CATEGORY: Constructor
################################

##
# Base::Server->new([port, bind])
#
# Start a server at the specified port.
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
		$client->{sock}->close if ($client);
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
# $server->port()
# Returns: a port number.
#
# Get the port on which the server is started.
sub port {
	return $_[0]->{port};
}

##
# $server->sendData(client, data)
# client: a client object (see overview).
# data: the data to send.
# Returns: 1 on success, 0 on failure.
#
# Send data to $client.
sub sendData {
	my ($self, $client) = @_;

	undef $@;
	eval {
		$client->{sock}->send($_[2], 0);
		$client->{sock}->flush;
	};
	if ($@) {
		# Client disconnected
		$self->_exitClient($client, $client->{index});
		return 0;
	}
	return 1;
}

##
# $server->iterate()
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


####################################
### CATEGORY: Abstract methods
####################################

##
# $server->onClientNew(client, index)
# client: a client object (see overview).
# index: the client's index (same as $client->{index}).
#
# This method is called when a new client has connected to the server.
sub onClientNew {
}

##
# $server->onClientExit(client, index)
# client: a client object (see overview).
# index: the client's index (same as $client->{index}).
#
# This method is called when a client has disconnected from the server.
sub onClientExit {
}

##
# $server->onClientData(client, data, index)
# client: a client object (see overview).
# data: the data this client received.
# index: the client's index (same as $client->{index}).
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
	my $sock;
	my %client;

	$sock = $self->{server}->accept;
	$sock->autoflush(0);
	$client{sock} = $sock;
	$client{host} = $sock->peerhost;
	$client{fd} = fileno($sock);

	my $index;
	# Insert hash into an empty slot in the array
	for (my $i = 0; $i < @{$self->{clients}}; $i++) {
		if (!$self->{clients}[$i]) {
			$self->{clients}[$i] = \%client;
			$index = $i;
			last;
		}
	}

	if (!defined $index) {
		$index = @{$self->{clients}};
		push @{$self->{clients}}, \%client;
	}
	$client{index} = $index;
	$self->onClientNew(\%client, $index);
}

# A client disconnected
sub _exitClient {
	my ($self, $client, $i) = @_;

	$self->onClientExit($client, $i);
	$client->{sock}->close;
	delete $self->{clients}[$i];
}


return 1;
