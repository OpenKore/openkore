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

package IPC;

use strict;
use Exporter;
use base qw(Exporter);
use File::Spec;
use Fcntl ':flock';
use Time::HiRes qw(time sleep);

use IPC::Client;
use Utils qw(timeOut dataWaiting);


##
# IPC->new([host, port])
# host: host address of the manager server.
# port: port number of the manager server.
# Returns: an IPC object, or undef if unable to connect.
#
# Connect to an IPC manager server. This gives you access to the IPC network.
#
# If $port is not given, and $host is not given or is localhost, then a connection
# will be made to the local manager server. The local manager server is automatically
# started, if not already started.
sub new {
	my $class = shift;
	my $host = shift;
	my $port = shift;

	$host = "localhost" if (!defined($host) || $host eq "127.0.0.1");
	if ($host eq "localhost" && !$port) {
		$port = _checkManager();
		$port = _startManager() if (!$port);
		return undef if (!$port);

	} elsif (!$port) {
		$@ = "No port number specified.";
		return undef;
	}

	my %self;
	$self{client} = new IPC::Client($host, $port);
	return undef if (!$self{client});

	bless \%self, $class;
	return \%self;
}

# Check whether the manager server's already started
sub _checkManager {
	my $lockFile = File::Spec->catfile(File::Spec->tmpdir(), "KoreServer");

	if (! -f $lockFile) {
		return 0;
	} else {
		my $f;
		if (open($f, "< $lockFile")) {
			if (flock($f, LOCK_EX | LOCK_NB)) {
				# We are able to obtain a lock; this means the
				# manager server's not locking it (= not running)
				close $f;
				return 0;
			} else {
				# We can't lock the lockfile; manager server is already
				# started at the specified port
				local ($/);
				my $port = <$f>;
				$port =~ s/\n.*//s;
				close $f;
				return $port;
			}
		} else {
			# Can't open lockfile; something's wrong, attempt to delete
			# it and start a manager server anyway
			unlink $lockFile;
			return 0;
		}
	}
}

# Start the manager server
sub _startManager {
	my $server = new IO::Socket::INET(
		Listen => 5,
		LocalHost => 'localhost',
		LocalPort => 0,
		Proto => 'tcp',
		ReuseAddr => 1,
		Timeout => 6
		);
	system("perl src/IPC/manager.pl --feedback=" . $server->sockport() . " &");

	my $time = time;
	while (!timeOut($time, 6)) {
		if (dataWaiting($server)) {
			my $client = $server->accept;
			my $data;
			$client->recv($data, 1024 * 32);

			if ($data =~ /^\d+$/) {
				return $data;
			} else {
				$@ = $data;
				return 0;
			}
		}
		sleep 0.01;
	}
	$@ = "Manager server failed to start\n";
	return 0;
}


sub broadcast {
	my $self = shift;
	$self->{client}->send(@_);
}

1;
