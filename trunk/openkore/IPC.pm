#########################################################################
#  OpenKore - Inter-Process Communication system
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Inter-Process Communication system
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

package IPC;

use strict;
use Exporter;
use IO::Socket::INET;
use Settings;
use Log;
use Utils;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(start stop iterate);

our $server;
our @clients;
our @listeners;


##
# IPC::start()
# Returns: 1 on success, 0 on failure.
#
# Initializes the IPC system.
sub start {
	my ($port) = @_;

	$port = 3201 if (!defined $port);
	$server = IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr 	=> 'localhost',
		LocalPort	=> $port,
		Proto		=> 'tcp');
	if (!$server) {
		Log::error("Unable to create IPC socket at port $port: $@\n");
		return 0;
	}
	return 1;
}


##
# IPC::stop()
#
# Stops the IPC system. Resources are freed.
sub stop {
	for (my $i = 0; $i < @clients; $i++) {
		delete $clients[$i];
	}
	undef @clients;
	undef $server;
}


sub readData {
	my $client = shift;
	my $data;
	eval {
		$data = <$client>;
	};

	if ($@ || !defined $data || length($data) == 0) {
		return undef;
	}
	$data =~ s/\r?\n//;
	return $data;
}

sub sendData {
	my ($client, $data) = @_;

	eval {
		$client->send($data . "\n", 0);
		$client->flush;
	};
	return 0 if ($@);
	return 1;
}


##
# IPC::iterate()
#
# Handle client connections input. You should call
# this function every time in the main loop.
sub iterate {
	my $bits = '';

	# Checks whether a new client wants to connect
	vec($bits, $server->fileno, 1) = 1;
	if (select($bits, undef, undef, 0)) {
		# Accept connection from new client
		my $client = $server->accept;
		$client->autoflush(0);
		push @clients, $client;
		Log::debug("New client: " . $client->peerhost . "\n", "ipc");
	}

	# Check for input from clients
	my $i = 0;
	my $recreate = 0;

	foreach my $client (@clients) {
		if (!defined $client) {
			$recreate = 1;
			next;
		}

		my $disconnected = 0;
		$bits = '';
		vec($bits, $client->fileno, 1) = 1;

		# Input available
		if (select($bits, undef, undef, 0)) {
			my $data = undef;

			$data = readData($client);
			if (!defined $data) {
				$disconnected = 1;

			} else {
				foreach my $listener (@listeners) {
					next if (!defined $listener);
					$listener->{'func'}->($client, $data, $listener->{'user_data'});
				}
			}
		}

		# Client disconnected
		if ($disconnected || select(undef, undef, $bits, 0)) {
			Log::debug("Client " . $client->peerhost . " disconnected", "ipc");
			delete $clients[$i];
		}
		$i++;
	}

	# Recreate @clients so we won't have undefined values in it.
	if ($recreate) {
		my @newClients = ();
		foreach my $client (@clients) {
			push @newClients, $client if (defined $client);
		}
		undef @clients;
		@clients = @newClients;
	}
}


##
# IPC::addListener(r_func, user_data)
# r_func: Reference to a function.
# user_data: This argument will be passed to r_func when it's called.
# Returns: An ID which you can use to unregister this listener.
#
# Registers a listener function. Every time a client has sent data,
# r_func will be called, in this way:
# <pre>
# $r_func->($client_socket, $data_received_from_client, $data, $user_data)
# </pre>
sub addListener {
	my ($r_func, $user_data) = @_;
	my %listener = ();
	$listener{'func'} = $r_func;
	$listener{'user_data'} = $user_data;
	return binAdd(\@listeners, \%listener);
}

##
# IPC::delListener(ID)
# ID: A listener ID, as returned by addListener().
#
# Unregisters a listener. r_func will not be called anymore each time a client has sent data.
sub delListener {
	my $ID = shift;
	undef $listeners[$ID];
	delete $listeners[$ID] if (@listeners - 1 == $ID);
}


##
# IPC::broadcast(data)
# data: The data to send.
#
# Send $data to all connected clients.
sub broadcast {
	my ($data) = @_;
	my $i = 0;
	foreach my $client (@clients) {
		next if (!defined $client);
		if (!sendData($client, $data)) {
			Log::debug("Client " . $client->peerhost . " disconnected", "ipc");
			delete $clients[$i];
		}
		$i++;
	}
}


END {
	stop();
}

return 1;
