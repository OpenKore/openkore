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
# MODULE DESCRIPTION: Inter-process communication framework

package IPC;

use strict;
use Exporter;
use base qw(Exporter);
use File::Spec;
use Fcntl ':flock';
use Time::HiRes qw(time sleep);

use Log qw(debug);
use IPC::Client;
use Utils qw(timeOut dataWaiting launchScript checkLaunchedApp);


################################
### CATEGORY: Constructor
################################

##
# IPC->new([userAgent, host, port])
# userAgent: a name to identify yourself. Default value: 'openkore'.
# host: host address of the manager server. Default value: localhost.
# port: port number of the manager server.
# Returns: an IPC object, or undef if unable to connect.
#
# Connect to an IPC manager server. This gives you access to the IPC network.
#
# If $port is not given, and $host is not given or is localhost, then a connection
# will be made to the local manager server. The local manager server is automatically
# started, if not already started.
#
# The IPC object isn't immediately usable yet. It must first do some handshaking
# communication with the manager server. You must call $ipc->iterate() in a loop,
# until $ipc->ready() returns 1.
sub new {
	my ($class, $userAgent, $host, $port) = @_;
	my %self;

	$host = "localhost" if (!defined($host) || $host eq "127.0.0.1");
	$self{userAgent} = defined($userAgent) ? $userAgent : 'openkore';

	if ($host eq "localhost" && !$port) {
		$self{host} = $host;
		$self{manager} = {};
		$port = _checkManager();

	} elsif (!$port) {
		$@ = "No port number specified.";
		return undef;

	}

	if ($port) {
		$self{host} = $host;
		$self{port} = $port;
		$self{client} = new IPC::Client($host, $port);
		return undef if (!$self{client});
	}

	$self{connected} = 1;
	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my $self = shift;
	undef $self->{client};
}

# Check whether the manager server's already started
sub _checkManager {
	my $lockFile;
	if ($^O eq 'MSWin32') {
		$lockFile = File::Spec->catfile(File::Spec->tmpdir(), "KoreServer");
	} else {
		my $tmpdir = $ENV{TEMP};
		$tmpdir = "/tmp" if (!$tmpdir || ! -d $tmpdir);
		$lockFile = File::Spec->catfile($tmpdir, "KoreServer");
	}

	return 0 if (! -f $lockFile);

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
			if ($^O eq 'MSWin32') {
				# We can't read from locked files on Win32, bah
				close $f;
				open($f, "< ${lockFile}.port");
			}

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


################################
### CATEGORY: Methods
################################

##
# $ipc->iterate()
#
# Call this function in the program's main loop.
sub iterate {
	my $self = shift;

	return 0 if !$self->{connected};

	if (!$self->{port} && $self->{host} eq "localhost") {
		# The port is not given and we're on localhost.
		# Start the manager server if we haven't yet done so.
		my $manager = $self->{manager};
		if ($manager->{state} eq '') {
			# Create a server socket on a random port.
			# The manager server will also create a server socket on a random
			# port, and will tell us its port number by sending it to this
			# socket.
			debug "Starting server socket for manager server\n", "ipc";
			my $server = new IO::Socket::INET(
				Listen => 5,
				LocalHost => 'localhost',
				LocalPort => 0,
				Proto => 'tcp',
				ReuseAddr => 1,
				Timeout => 6
			);
			if (!$server) {
				#$@ = "Unable to start a server socket on a random port.";
				$self->{connected} = 0;
				return 0;
			}
			$manager->{server} = $server;
			$manager->{state} = 'Launch the manager server';

		} elsif ($manager->{state} eq 'Launch the manager server') {
			debug "Launching manager server\n", "ipc";
			$manager->{pid} = launchScript(1, undef, 'src/IPC/manager.pl',
				'--quiet', '--feedback=' . $manager->{server}->sockport);
			$manager->{time} = time;
			$manager->{state} = 'Connect to the manager server';

		} elsif ($manager->{state} eq 'Connect to the manager server') {
			if (!checkLaunchedApp($manager->{pid}) || timeOut($manager->{time}, 8)) {
				# Manager server exited abnormally, or failed to
				# start within 6 seconds
				debug "Manager server exited abnormally\n", "ipc";
				$manager->{server}->close;
				$self->{connected} = 0;
				return 0;

			} elsif (dataWaiting($manager->{server})) {
				my $client = $manager->{server}->accept;
				my $data;
				$client->recv($data, 1024 * 32);
				$manager->{server}->close;

				if ($data =~ /^\d+$/) {
					# We got the manager server's port!
					debug "Manager server started at port $data\n", "ipc";
					$self->{port} = $data;
					$self->{client} = new IPC::Client($self->{host}, $self->{port});
					return defined $self->{client};
				} else {
					debug "Manager server returned error: $data\n", "ipc";
					$self->{connected} = 0;
					return 0;
				}
			}
		}

	} elsif (!$self->{ready}) {
		# We've just connected to the manager server.
		# Perform handshaking communication.
		my @messages;
		my $ret = $self->{client}->recv(\@messages);

		if ($ret == -1) {
			$self->{connected} = 0;
			return 0;
		}
		foreach my $msg (@messages) {
			if ($msg->{ID} eq "_WELCOME") {
				$self->{ID} = $msg->{params}{ID};
				$self->{ready} = 1;
				debug "Received _WELCOME - our client ID: $self->{ID}\n", "ipc";
				$self->send("_WELCOME",
					"userAgent" => $self->{userAgent});
			}
		}
	}
	return 1;
}

##
# $ipc->ready()
#
# Check whether the handshaking communication with the manager server has
# been performed. The IPC connection is only usable when handshaking has been
# performed.
sub ready {
	return $_[0]->{ready};
}

##
# $ipc->connected()
#
# Check whether you're still connected to the manager server.
sub connected {
	return $_[0]->{connected};
}

##
# $ipc->host()
#
# Returns the host name of the manager server.
# You can only use this function when the connection is ready.
#
# See also: $ipc->ready(), $ipc->port()
sub host {
	return $_[0]->{host};
}

##
# $ipc->ID()
#
# Returns the ID of the client. Each client in the IPC network has a unique ID.
sub ID {
	return $_[0]->{ID};
}

##
# $ipc->port()
#
# Returns the port number of the manager server.
# You can only use this function when the connection is ready.
#
# See also: $ipc->ready(), $ipc->host()
sub port {
	return $_[0]->{port};
}

##
# $ipc->send(ID, hash | key => value)
#
# Send a message to the IPC network. This message will be broadcasted to
# all clients. If you want to send a message only to a specific client,
# set the TO key to that client's ID.
sub send {
	my $self = shift;
	return 2 if (!$self->{ready});
	return 0 if (!$self->{connected});
	return $self->{client}->send(@_);
}

##
# $ipc->recv(r_msgs)
sub recv {
	my $self = shift;
	return 0 if (!$self->{ready});
	return -1 if (!$self->{connected});

	my $ret = $self->{client}->recv(@_);
	$self->{connected} = 0 if ($ret == -1);
	return $ret;
}

1;
