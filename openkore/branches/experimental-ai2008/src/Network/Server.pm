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
package Network::Server;


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
use Utils::Set;
use Utils::CallbackList;

####################################
### CATEGORY: Constructor
###################################


##
# Network::Server->new(Network::MessageTokenizer $tokenizer)
#
# Create a new Network Server main object.
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
	$self->{tokenizer} = $tokenizer;			# Message tokenizer
	$self->{host} = "";					# Host to which we connected
	$self->{port} = -1;					# Port to which we connected
	$self->{main_tid} = undef;				# Listener thread ID
	$self->{client_list} = new Utils::Set();		# Set of Server<->Client connections
	$self->{onConnected} = new Utils::CallbackList();	# OnConnected event Callback List
	$self->{onDisconnected} = new Utils::CallbackList();	# OnDisconnected event Callback List


	# TODO
	# May-be Something better for OnConnected/OnDisconnected ???

	# Add Listeners
	$self->{onConnected}->add($onConnected);
	$self->{onDisconnected}->add($onDisconnected);

	# Clients list Structure.
	# $self->{client_list}->[i]->{send_queue} = Thread::Queue->new();		# Send Queue
	# $self->{client_list}->[i]->{receive_queue} = Thread::Queue->new();		# Receive Queue
	# $self->{client_list}->[i]->{peerhost} = "";					
	# $self->{client_list}->[i]->{peerport} = -1;					
	# $self->{client_list}->[i]->{connected} = 0;					
	# $self->{client_list}->[i]->{tid} = undef;

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
# Enter the Network Server main loop.
sub mainLoop {
	my $self = shift;
	# 
	my $socket = shift;
	return if (!defined $socket);

	my $should_exit;

	# Handle 'CLOSE' signal.
	$SIG{'CLOSE'} = sub {
		# Destroy all Clients before we destroy main socket
		my $clients = \%{$self->{client_list}};
		foreach my $client (@{$clients }) {
			my $thr = $self->_get_child_thread($client->{tid});
			$thr->kill('CLOSE');
			# Wait for 'CLOSE' signal to work
			while ($thr->is_running()) {
				sleep(1);
				yeld();
			};
		}
		$socket->close();
		$should_exit = 1;
	};

	while (!$quit && !$should_exit && $socket && (my $client = $socket->accept())) {
		{ # Just make Unlock quicker.
			lock ($self) if (is_shared($self));

			my $connection = {};
			$connection->{send_queue} = Thread::Queue->new();		# Send Queue
			$connection->{receive_queue} = Thread::Queue->new();		# Receive Queue
			$connection->{peerhost} = "";					# Connected peer host
			$connection->{peerport} = -1;					# Connected peer port
			$connection->{connected} = 0;					# Is connected ???
			$connection->{tid} = undef;					# SubThread id.
			$connection = shared_clone($connection) if (is_shared($self));

			# Return vars ReadOnly flag
			SetReadOnly(\{$connection->{peerhost}});
			SetReadOnly(\{$connection->{peerport}});
			SetReadOnly(\{$connection->{is_connected}});

			my $trd = threads->create(\&Network::Server::subLoop, $connection, $client, $self);
			$connection->{tid} = $trd->tid();

			# Add to Connection List
			$self->{client_list}->add(\$connection);

			$self->{onConnected}->call($connection->{tid});
		}
		yield();
	}
}

##
# void $net->subLoop()
#
# Enter the Network Server<->Client sub loop.
sub subLoop {
	my ($self, $socket, $main) = @_;
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
					# Parse Message through global tokenizer
					my $parsed_message = $main->{tokenizer}->parse($msg, $self->{tid});
					if ($parsed_message != undef) {
						$self->{receive_queue}->enqueue(\$parsed_message);
					};
				};
			} else {
			};

			# Return vars ReadOnly flag
			SetReadOnly(\{$self->{peerhost}});
			SetReadOnly(\{$self->{peerport}});
			SetReadOnly(\{$self->{is_connected}});
		}
		yield();
	}

	# Client Disconnected.
	{ # Just to Unlock quicker.
		lock ($main) if (is_shared($main));
		$main->{onDisconnected}->call($self->{tid});
	};
}

##
# bool $net->connect(int port, bool only_local)
# host: the host name/IP of the Server to connect to.
# port: the port number of the Server to connect to.
#
# Establish a connection to a Server.
sub connect {
	my ($self, $port, $only_local) = @_;

	# Establish Connection.
	message(TF("Starting Server at port %s... ", $port), "connection");
	my $server;
	if ($only_local) {
		$server = new IO::Socket::INET(
				LocalAddr	=> 'localhost',
				Proto     	=> 'tcp',
                        	LocalPort 	=> $port,
                        	Listen    	=> SOMAXCONN,
                        	Reuse     	=> 1);
	} else {
		$server = new IO::Socket::INET(
				Proto     	=> 'tcp',
                        	LocalPort 	=> $port,
                        	Listen    	=> SOMAXCONN,
                        	Reuse     	=> 1);
	};

	if ($server) {
		message T("Listening\n"), "connection";
		$self->{port} = $port;
		# Disable Bloking
		$socket->blocking(0);
		# We create Thread that will send and receive data
		my $trd = threads->create(\&Network::Server::mainLoop, $self, $server);
		$self->{main_tid} = $trd->tid();
		return 1;
	} else {
		error(TF("couldn't create socket: %s (error code %d)\n", "$!", int($!)), "connection");
		return 0;
	};
}

##
# bool $net->connected(int $tid)
# 
#
# Return $tid Socket status.
sub connected {
	my ($self, $tid) = @_;
	lock ($self) if (is_shared($self));

	my $clients = \%{$self->{client_list}};
	foreach my $client (@{$clients }) {
		if ($client->{tid} == $tid) {
			return $client->{connected};
		};
	}

	return 0;
}

##
# String $net->peerhost(int $tid)
#
# Return $tid Socket peer host.
sub peerhost {
	my ($self, $tid) = @_;
	lock ($self) if (is_shared($self));

	my $clients = \%{$self->{client_list}};
	foreach my $client (@{$clients }) {
		if ($client->{tid} == $tid) {
			return $client->{peerhost};
		};
	}

	return "";
}

##
# int $net->peerport(int $tid)
#
# Return $tid Socket peer port.
sub peerport {
	my ($self, $tid) = @_;
	lock ($self) if (is_shared($self));

	my $clients = \%{$self->{client_list}};
	foreach my $client (@{$clients }) {
		if ($client->{tid} == $tid) {
			return $client->{peerport};
		};
	}

	return -1;
}

##
# void $net->send(String msg, int $tid)
#
# Add packet to Send Queue
# If $tid == 0, then broadcast to all clients.
sub send {
	my ($self, $msg, $tid) = @_;
	lock ($self) if (is_shared($self));

	my $clients = \%{$self->{client_list}};
	foreach my $client (@{$clients }) {
		if ($client->{tid} == $tid || $tid == 0) {
			return $client->{send_queue}->enqueue(\$msg);
		};
	}
}

##
# String $net->recv()
#
# Receive already splitted packet by Messagetokenizer from Socket.
# Returns undef if nothing to receive.
sub recv {
	my $self = shift;
	my $msg = shift;
	lock ($self) if (is_shared($self));

	my $clients = \%{$self->{client_list}};
	foreach my $client (@{$clients }) {
		if ($client->{tid} == $tid) {
			if ($client->{receive_queue}->pending() > 0) {
				my $msg = $client->{receive_queue}->dequeue();
				return ($msg, $tid);
			};
		};
	}
	return undef;
}

##
# void $net->close(int $tid)
#
# Close Socket.
# If $tid == 0, then cloase all sockets.
# Note: Socket needs some time to close
sub close {
	my ($self, $tid) = shift;
	lock ($self) if (is_shared($self));

	my $clients = \%{$self->{client_list}};
	foreach my $client (@{$clients }) {
		if ($client->{tid} == $tid || $tid == 0) {
			$self->_get_child_thread($tid)->kill('CLOSE')
		};
	}

	# Kill main thread also.
	if ($tid == 0) {
		$self->_get_thread()->kill('CLOSE');
	}
}

sub _get_thread {
	my $self = shift;
	foreach my $thr (threads->list) {
		# Don’t join the main thread or ourselves
		if ($thr->tid && $thr->tid == $self->{main_tid}) {
			return $thr;
		}
	}

}

sub _get_child_thread {
	my ($self, $tid) = shift;
	foreach my $thr (threads->list) {
		# Don’t join the main thread or ourselves
		if ($thr->tid && $thr->tid == $tid) {
			return $thr;
		}
	}

}

1;
