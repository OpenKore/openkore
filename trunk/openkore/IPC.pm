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

package IPC;

use strict;
use Exporter;
use IO::Socket::INET;
use Settings;
use Log;

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
	foreach (@clients) {
		undef $_;
	}
	undef @clients;
	undef $server;
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
	if (select($bits, undef, undef, 0.001)) {
		# Accept connection from new client
		my $client = $server->accept;
		$client->autoflush(0);
		push @clients, $client;
		Log::debug("New client: " . $client->peerhost . "\n", "ipc");
	}

	# Check for input from clients
	my $i = 0;
	foreach my $client (@clients) {
		my $disconnected = 0;
		$bits = '';
		vec($bits, $client->fileno, 1) = 1;

		# Input available
		if (select($bits, undef, undef, 0)) {
			my $data = undef;

			eval {
				# FIXME: don't do this. We should come up with a protocol. One line per command or a binary protocol?
				$client->recv($data, $Settings::MAX_READ);
			};

			if ($@ || !defined $data || length($data) == 0) {
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
			undef $client;
			delete $clients[$i];
			next;
		}
		$i++;
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
	# FIXME: circular dependancy with Utils.pm?
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
		eval {
			$client->send($data, 0);
			$client->flush;
		};
		if ($@) {
			delete $clients[$i];
			$i--;
		}
		$i++;
	}
}


END {
	stop();
}

return 1;
