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
use Fcntl ':flock';
use IO::Socket::INET;
use Exporter;
use base qw(Exporter);

use Globals;
use Log qw(message error debug);
use IPC::Protocol;
use Utils;

our $ipc;
our @EXPORT = qw($ipc);

my $lockDir = File::Spec->catfile(File::Spec->tmpdir(), "KoreServers");


##
# IPC::Server->new()
# Returns: an IPC::Server object.
#
# Initializes an IPC server.
sub new {
	my %ipc;
	$ipc{server} = IO::Socket::INET->new(
		Listen		=> 5,
		LocalAddr 	=> 'localhost',
		LocalPort	=> 0,
		Proto		=> 'tcp',
		ReuseAddr	=> 1);
	return undef if (!$ipc{server});

	if (! -d $lockDir) {
		if (!mkdir $lockDir) {
			error "Unable to create temporary directory $lockDir\n", "ipc";
			undef %ipc;
			return;
		}
		chmod(0777, $lockDir);
	}

	$ipc{lockFile} = File::Spec->catfile($lockDir, $ipc{server}->sockport());
	if (!open($ipc{lock}, '>', $ipc{lockFile})) {
		error "Unable to create lock file $ipc{lockFile}\n", "ipc";
		undef %ipc;
		return;
	}

	flock($ipc{lock}, LOCK_EX);
	chmod(0666, $ipc{lockFile});

	$ipc{clients} = [];
	$ipc{listeners} = [];
	bless \%ipc;
	return \%ipc;
}

sub DESTROY {
	my $ipc = shift;
	delete $ipc->{clients};
	delete $ipc->{server};

	flock($ipc->{lock}, LOCK_UN);
	close $ipc->{lock};
	unlink $ipc->{lockFile};
}


sub _readData {
	my $client = shift;
	my $data;
	eval {
		$data = $client->recv($data, 1024 * 32, 0);
	};

	if ($@ || !defined $data || length($data) == 0) {
		return undef;
	}
	return $data;
}

sub _sendData {
	my ($client, $data) = @_;

	eval {
		$client->send($data, 0);
		$client->flush;
	};
	return 0 if ($@);
	return 1;
}


##
# IPC::Server::list()
# Returns: an array of port numbers.
#
# List all ports on which a Kore IPC server exists.
sub list {
	my (@list, @servers, @dead);

	opendir(DIR, $lockDir);
	@list = grep { /^\d+$/ && -f File::Spec->catfile($lockDir, $_) } readdir(DIR);
	closedir DIR;

	foreach (@list) {
		my $file = File::Spec->catfile($lockDir, $_);
		open(F, '>', $file);
		if (!flock(F, LOCK_EX | LOCK_NB)) {
			push @servers, $_;
		} else {
			push @dead, $file;
		}
		close F;
	}

	foreach (@dead) {
		unlink $_;
	}

	return @servers;
}


##
# $ipc->iterate()
#
# Handle client connections input. You should call
# this function every time in the main loop.
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
		if (dataWaiting($client->{sock})) {
			my $data = _readData($client->{sock});
			if (!defined $data) {
				# Client disconnected
				debug("Client " . $client->{sock}->peerhost . " disconnected\n", "ipc");
				delete $ipc->{clients}[$i];
				next;
			}

			my ($ID, %hash);
			$client->{buffer} .= $data;

			while (($ID = IPC::Server::decode($client->{buffer}, \%hash, \$client->{buffer}))) {
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


END {
	undef $ipc if defined $ipc;
}

return 1;
