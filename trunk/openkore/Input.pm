#########################################################################
#  OpenKore - Input Client
#  Asynchronously read from console.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

# There's no good way to asynchronously read from standard input.
# To work around this problem, kore uses a so-called input server.
#
# Kore starts a server socket and forks a new process:
# - The parent process is the main process and input server. It and handles
#   the connection to the RO server, the AI, etc.
# - The child process is the input client. It reads from STDIN and sends
#   the data to the input server.
# - The parent process polls the input server for available data. If there's
#   data, read from it and parse it.

package Input;

use strict;
use Exporter;
use IO::Socket::INET;

our @ISA = "Exporter";
our @EXPORT_OK = qw(&init &stop &canRead &readLine $enabled);

our $enabled;
our $input_server;
our $input_socket;
our $input_pid;


sub start {
	return undef if ($enabled);

	$input_server = IO::Socket::INET->new(
			Listen		=> 5,
			LocalAddr 	=> 'localhost',
			Proto		=> 'tcp');
	($input_server) || die "Error creating local input server: $!";
	print "Local input server started (" . $input_server->sockhost() . ":" . $input_server->sockport() . ")\n";
	$input_pid = startInputClient();
	$enabled = 1;
	return 1;
}

sub stop {
	return unless ($enabled);

	$enabled = 0;
	close($input_server);
	close($input_socket);
	kill(9, $input_pid);
}


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
		($local_socket) || die "Error creating connection to local server: $!";

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

sub canRead {
	return undef unless ($enabled);
	my $bits = '';
	vec($bits, $input_socket->fileno, 1) = 1;
	return (select($bits, $bits, $bits, 0.01) > 1);
}

sub readLine {
	return undef unless ($enabled);

	my $input;
	$input_socket->recv($input, 30000);
	return $input;
}


return 1;
