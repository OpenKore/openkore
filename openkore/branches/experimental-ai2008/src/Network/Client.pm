#########################################################################
#  OpenKore - Networking subsystem
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package Network::Client;


# Make all References Strict
use strict;

# MultiThreading Support
use threads qw(yield);
use threads::shared;
use Thread::Queue::Any;

# Others (Perl Related)
use warnings;
no warnings 'redefine';
use FindBin qw($RealBin);
use Time::HiRes qw(time);
use Scalar::Util qw(reftype refaddr blessed); 
use Internals qw(SetReadOnly SetReadWrite);

# Others (Kore related)
use Modules 'register';
use Globals qw($quit $config);
use Log qw(message error);
# use Utils::Set;
# use Utils::CallbackList;

####################################
### CATEGORY: Constructor
###################################


##
# Network::Client->new(Network::MessageTokenizer $tokenizer)
#
# Create a new Network Client main object.
sub new {
	my $class = shift;
	my $tokenizer = shift;
	return undef if (!defined $tokenizer);
	return undef if (! $tokenizer->isa("parse"));

	my %args = @_;
	my $self = {};
	bless $self, $class;


	# Warning!!!!
	# Do not set Internal Varuables in other packages!
	$self->{send_queue} = Thread::Queue->new();		# Send Queue
	$self->{receive_queue} = Thread::Queue->new();		# Receive Queue
	$self->{tokenizer} = $tokenizer;			# Message tokenizer
	$self->{host} = "";					# Host to which we connected
	$self->{port} = -1;					# Port to which we connected
	$self->{peerhost} = "";					
	$self->{peerport} = -1;					
	$self->{connected} = 0;					
	$self->{tid} = undef;					# Listener thread ID

	# Set vars ReadOnly flag
	SetReadOnly(\{$self->{peerhost}});
	SetReadOnly(\{$self->{peerport}});
	SetReadOnly(\{$self->{is_connected}});

	return $self;
}

####################################
### CATEGORY: Destructor
###################################

sub DESTROY {
	my ($self) = @_;
	
	# Kill Listener Thread
	my $thr = $self->_get_thread();
	$thr->kill('CLOSE');
	# Wait for 'CLOSE' signal to work
	while ($thr->is_running()) {
		sleep(1);
		yeld();
	};

	# Recursivly destroy all Child Objects
	if $self->can("SUPER::DESTROY") {
		debug "Destroying: ".__PACKAGE__."!\n";
		$self->SUPER::DESTROY;
	}
}

####################################
### CATEGORY: Public
####################################

##
# void $net->mainLoop()
#
# Enter the Network Client main loop.
sub mainLoop {
	my $self = shift;
	# 
	my $socket = shift;
	return if (!defined $socket);

	my $should_exit;

	# Handle 'CLOSE' signal.
	$SIG{'CLOSE'} = sub {
		$socket->close();
		$should_exit = 1;
	};

	while (!$quit && !$should_exit && $socket) {
		{ # Just make Unlock quicker.
			lock ($self) if (is_shared($self));

			# Set vars ReadWrite flag
			SetReadWrite(\{$self->{peerhost}});
			SetReadWrite(\{$self->{peerport}});
			SetReadWrite(\{$self->{connected}});

			# Set Connected Status
			$self->{is_connected} = $socket->connected();

			if ($self->{is_connected}) {
				$self->{peerhost} = $socket->peerhost();
				$self->{peerport} = $socket->peerport();

				# Send all pending data
				while ($self->{send_queue}->pending() > 0) {
					my $msg = $self->{send_queue}->dequeue();
					$socket->send($msg);
				};

				# Receive all pending data
				my $msg;
				$socket->recv($msg, 1024 * 32);
				if (!defined($msg) || length($msg) == 0) {
					# Connection from server closed.
					close($socket);
					return;
				} else {
					# Parse Message through tokenizer
					my $parsed_message = $self->{tokenizer}->parse(0, $msg); # Client 0 (default for client->server connections)
					if ($parsed_message != undef) {
						$self->{receive_queue}->enqueue(\$parsed_message);
					};
				};
			};

			# Return vars ReadOnly flag
			SetReadOnly(\{$self->{peerhost}});
			SetReadOnly(\{$self->{peerport}});
			SetReadOnly(\{$self->{is_connected}});
		}
		yield();
	}
}

##
# bool $net->connect(String host, int port)
# host: the host name/IP of the Server to connect to.
# port: the port number of the Server to connect to.
#
# Establish a connection to a Server.
sub connect {
	my $self = shift;
	my $host = shift;
	my $port = shift;

	# We are already connected
	if ($self->{connected} > 0) {
		error(TF("Already connected to: %s:%d\n", $self->{peerhost}, $self->{peerport}), "connection");
		return 0;
	};


	# Establish Connection.
	message(TF("Connecting (%s:%s)... ", $host, $port), "connection");
	my $socket = new IO::Socket::INET(
			LocalAddr	=> $config{bindIp} || undef,
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp',
			Timeout		=> 4);
	if ($socket && inet_aton($socket->peerhost()) eq inet_aton($host)) {
		message T("connected\n"), "connection";
		$self->{host} = $host;
		$self->{port} = $port;
		# Disable Bloking
		# $socket->blocking(0);
		# We create Thread that will send and receive data
		my $trd = threads->create(\&Network::Client::mainLoop, $self, $socket);
		$self->{tid} = $trd->tid();
		return 1;
	} else {
		error(TF("couldn't connect: %s (error code %d)\n", "$!", int($!)), "connection");
		return 0;
	};
}

##
# bool $net->connected()
#
# Return Socket status.
sub connected {
	my $self = shift;
	lock ($self) if (is_shared($self));
	return $self->{is_connected};
}

##
# String $net->peerhost()
#
# Return peer host.
sub peerhost {
	my $self = shift;
	lock ($self) if (is_shared($self));
	return $self->{peerhost};
}

##
# int $net->peerport()
#
# Return peer port.
sub peerport {
	my $self = shift;
	lock ($self) if (is_shared($self));
	return $self->{peerport};
}

##
# void $net->send(String msg)
#
# Add packet to Send Queue
sub send {
	my $self = shift;
	my $msg = shift;
	lock ($self) if (is_shared($self));
	$self->{send_queue}->enqueue(\$msg);
}

##
# String $net->recv()
#
# Receive already splitted packet by Messagetokenizer from Socket.
# Returns undef if nothing to receive.
sub recv {
	my $self = shift;
	lock ($self) if (is_shared($self));
	if ($self->{receive_queue}->pending() > 0) {
		my $msg = $self->{receive_queue}->dequeue();
		return $msg;
	};
	return undef;
}

##
# void $net->close()
#
# Close Socket.
# Note: Socket needs some time to close
sub close {
	my $self = shift;
	lock ($self) if (is_shared($self));
	$self->_get_thread()->kill('CLOSE');
}

sub _get_thread {
	my $self = shift;
	foreach my $thr (threads->list) {
		# Don’t join the main thread or ourselves
		if ($thr->tid && $thr->tid == $self->{tid}) {
			return $thr;
		}
	}

}

1;
