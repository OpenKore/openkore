#########################################################################
#  OpenKore - Keyboard input system
#  Asynchronously read from console.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Keyboard input system
#
# There's no good way to asynchronously read keyboard input.
# To work around this problem, Kore uses a so-called input server.
#
# Kore starts a server socket and forks a new process:
# `l
# - The parent process is the main process and input server. It and handles
#   the connection to the RO server, the AI, etc.
# - The child process is the input client. It reads from STDIN and sends
#   the data to the input server.
# - The parent process polls the input server for available data. If there's
#   data, read from it and parse it.
# `l`
#
# <img src="input-client.png" width="453" height="448" alt="Overview of the input system">
#
# The functions in this module are only meant to be used in the main process.

package Input;

use strict;
use Exporter;
use IO::Socket::INET;
use Settings;
use Log;
use Utils;

our @ISA = "Exporter";
our @EXPORT_OK = qw(&init &stop &canRead &readLine $enabled);

our $enabled;
our $input_server;
our $input_socket;
our $input_pid;


##
# Input::start()
#
# Initializes the input system. You must call this function
# to be able to use the input system.
sub start {
	return undef if ($enabled);

	$input_server = IO::Socket::INET->new(
			Listen		=> 5,
			LocalAddr 	=> 'localhost',
			Proto		=> 'tcp');
	if (!$input_server) {
		Log::error("Error creating local input server: $@", "startup");
		promptAndExit();
	}
	print "Local input server started (" . $input_server->sockhost() . ":" . $input_server->sockport() . ")\n";
	$input_pid = startInputClient();
	$enabled = 1;
	return 1;
}


##
# Input::stop()
#
# Stops the input system. The input client process
# will be terminated and sockets will be freed.
sub stop {
	return unless ($enabled);

	$enabled = 0;
	close($input_server);
	close($input_socket);
	kill(9, $input_pid);
}


##
# Input::startInputClient()
#
# Starts the input client. You must call this
# function before you are able to use canRead().
sub startInputClient {
	print "Spawning Input Socket...\n";
	my $host = $input_server->sockhost();
	my $port = $input_server->sockport();

	my $pid = fork();
	if ($pid == 0) {
		# Child; read data from stdin and send to input server
		my $local_socket = IO::Socket::INET->new(
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp');
		($local_socket) || die "Error creating connection to local server: $@";

		my $input;
		while (1) {
			$input = <STDIN>;
			last if (!defined($input));
			chomp $input;
			if ($input ne "") {
				$local_socket->send($input);
			}
			last if ($input eq "quit" || $input eq "dump");
		}
		close($local_socket);
		exit;

	} elsif ($pid) {
		# Parent; poll input server and read data when available
		$input_socket = $input_server->accept();
		(inet_aton($input_socket->peerhost()) eq inet_aton('localhost')) 
		|| die "Input Socket must be connected from localhost";
		print "Input Socket connected\n";
		return $pid;

	} else {
		die "Unable to fork input server process";
	}
}


##
# Input::canRead()
# Returns: 1 if there is keyboard data, 0 if not or if the input system hasn't been initialized.
#
# Checks whether there is keyboard data available. You don't have to use this function.
# Just call getInput(0) instead.
#
# Example:
# # The following lines are semantically equal:
# Input::canRead() && Input::getInput(0);
# Input::getInput(1);
sub canRead {
	return undef unless ($enabled);
	my $bits = '';
	vec($bits, $input_socket->fileno, 1) = 1;
	return (select($bits, $bits, $bits, 0.005) > 1);
}


##
# Input::getInput(wait)
# wait: Whether to wait until keyboard data is available.
# Returns: The keyboard data (including newline) as a string, or undef if there's no
#          keyboard data available or if the input system hasn't been initialized.
#
# Reads keyboard data.
sub getInput {
	return undef unless ($enabled);

	my $wait = shift;
	my $input;
	if ($wait || canRead()) {
		$input_socket->recv($input, $Settings::MAX_READ);
	}
	return $input;
}


END {
	stop();
}

return 1;
