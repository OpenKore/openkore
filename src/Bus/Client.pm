##########################################################
#  OpenKore - Bus System
#  Bus client fascade
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
# MODULE DESCRIPTION: High level interface to the bus system
#
# <h2>About the bus system</h2>
# The bus system's goal is to allow different OpenKore instances to easily
# communicate with each other, and to allow external tools to easily
# communicate with a running OpenKore instance.
#
# The bus is a communication channel which supports broadcast communication
# as well as private communication. One can compare it to an open street:
# anyone can shout a message to everybody (broadcast communication) or
# whisper a message into someone else's ears (private communication).
#
# Furthermore, the bus system is based on discrete <em>messages</em> instead
# of byte streams. See @MODULE(Bus::Messages) for information the message
# format.
#
# This module provides an easy to use interface to interact with the bus
# system.
package Bus::Client;

use strict;
use Time::HiRes qw(time);

use Modules 'register';
use Bus::SimpleClient;
use base qw(Bus::SimpleClient);
use Bus::Server::Starter;
use Bus::Query;
use Bus::DialogMaster;
use Bus::DialogSlave;
use Utils::Exceptions;
use Utils::CallbackList;


# State constants.
use constant {
	NOT_CONNECTED   => 1,
	STARTING_SERVER => 2,
	HANDSHAKING     => 3,
	CONNECTED       => 4
};

# Time constants.
use constant {
	RECONNECT_INTERVAL => 5,
	RESTART_INTERVAL   => 5
};


sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {}, $class;

	$self->{verbose} = $args{verbose};
	$self->{host} = $args{host};
	$self->{port} = $args{port};
	$self->{userAgent}   = $args{userAgent} || "OpenKore";
	$self->{privateOnly} = defined($args{privateOnly}) ? $args{privateOnly} : 0;
	
	# Control Timeout for Waiting Reply from Poseidon (GG/HS Query)
	$self->{gstimeout} = 0;
	
	# A queue containing messages to be sent next time we're
	# connected to the bus.
	$self->{sendQueue} = [];
	$self->{seq} = 0;
	$self->{onConnected} = new CallbackList();
	$self->{onMessageReceived} = new CallbackList();
	$self->{onDialogRequested} = new CallbackList();

	if (!$args{host} && !$args{port}) {
		$self->{starter} = new Bus::Server::Starter();
		$self->{state} = STARTING_SERVER;
	} else {
		$self->reconnect();
	}

	return $self;
}

sub iterate {
	my ($self) = @_;
	my $state = $self->{state};

	if ($state == NOT_CONNECTED) {
		if (time - $self->{connectTime} > RECONNECT_INTERVAL) {
			$self->reconnect();
		}

	} elsif ($state == STARTING_SERVER) {
		if (time - $self->{startTime} > RESTART_INTERVAL) {
			print "Starting\n" if $self->{verbose};
			my $starter = $self->{starter};
			my $state = $starter->iterate();
			if ($state == Bus::Server::Starter::STARTED) {
				$self->{state} = HANDSHAKING;
				$self->{host}  = $starter->getHost();
				$self->{port}  = $starter->getPort();
				print "Bus server started at $self->{host}:$self->{port}\n" if $self->{verbose};
				$self->reconnect();
				$self->{startTime} = time;

			} elsif ($state == Bus::Server::Starter::FAILED) {
				# Cannot start; try again.
				print "Start failed.\n" if $self->{verbose};
				$self->{starter} = new Bus::Server::Starter();
				$self->{startTime} = time;
			}
		}

	} elsif ($state == HANDSHAKING) {
		print "Handshaking\n" if $self->{verbose};
		my $ID;
		my $args = $self->readNext(\$ID);
		if ($args) {
			print "Sending HELLO\n" if $self->{verbose};
			$self->{ID} = $args->{yourID};
			$self->{client}->send("HELLO", {
				userAgent   => $self->{userAgent},
				privateOnly => $self->{privateOnly}
			});
			$self->{state} = CONNECTED;
			print "Connected\n" if $self->{verbose};
			$self->onConnected->call($self);
		}

	} elsif ($state == CONNECTED) {
		# Send queued messages.
		while (@{$self->{sendQueue}} > 0) {
			my $message = shift @{$self->{sendQueue}};
			last if (!$self->send($message->[0], $message->[1]));
		}

		if ($self->{state} == CONNECTED) {
			my $onMessageReceived = $self->{onMessageReceived};
			my $onDialogRequested = $self->{onDialogRequested};
			my $mrEmpty = $onMessageReceived->empty();
			my $drEmpty = $onDialogRequested->empty();
			my $MID;
			while (my $args = $self->readNext(\$MID)) {
				if (!$mrEmpty) {
					$onMessageReceived->call($self, {
						messageID => $MID,
						args => $args
					});
				}
				if ($MID eq 'REQUEST_DIALOG') {
					my $slave = new Bus::DialogSlave({
						bus          => $self,
						peerID       => $args->{FROM},
						peerDialogID => $args->{dialogID},
						seq          => $args->{SEQ}
					});
					$onDialogRequested->call($self, {
						reason => $args->{reason},
						args   => $args,
						dialog => $slave
					}) if (!$drEmpty);
					# If there are no callbacks registered for the
					# onDialogRequested event, then the DialogSlave
					# object will reply with a REFUSED message because
					# it's destroyed outside of this scope.
				}
			}
		}
	}

	return $self->{state};
}

sub getState {
	return $_[0]->{state};
}

sub serverHost {
	return $_[0]->{host};
}

sub serverPort {
	return $_[0]->{port};
}

sub ID {
	return $_[0]->{ID};
}

sub reconnect {
	my ($self) = @_;
	eval {
		print "(Re)connecting\n" if $self->{verbose};
		$self->{client} = new Bus::SimpleClient($self->{host}, $self->{port});
		$self->{state} = HANDSHAKING;
	};
	if (caught('SocketException')) {
		print "Cannot connect: $@\n" if $self->{verbose};
		$self->{state} = NOT_CONNECTED;
		$self->{connectTime} = time;
	} elsif ($@) {
		die $@;
	}
}

# Handle an I/O exception by reconnecting to the bus or restarting the
# bus server.
sub handleIOException {
	my ($self) = @_;
	if ($self->{starter}) {
		$self->{starter} = new Bus::Server::Starter();
		$self->{state} = STARTING_SERVER;
		# We add a random delay to prevent clients from starting
		# the server at the same time.
		$self->{startTime} = time + rand(3);
	} else {
		$self->{state} = NOT_CONNECTED;
		$self->{connectTime} = time + rand(3);
	}
}

# Read the next message from the bus, if any. This method returns undef immediately
# when there are no messages.
#
# If the connection with the bus broke while reading the message, then
# undef is returned, and we'll attempt to reconnect (or restart the bus
# server) on the next iteration.
sub readNext {
	my ($self, $MID) = @_;
	my $args;
	eval {
		$args = $self->{client}->readNext($MID);
	};
	if (caught('IOException')) {
		print "Disconnected from IPC server.\n" if $self->{verbose};
		$self->handleIOException();
		return undef;
	} elsif ($@) {
		die $@;
	} else {
		return $args;
	}
}

##
# boolean $Bus_Client->send(String messageID, args)
# Returns: Whether the message was successfully sent.
#
# Send a message over the bus.
#
# If the connection with the bus broke while sending the message, then
# the message is placed in a queue, and we'll attempt to reconnect (or
# restart the bus server) on the next iteration. Once reconnected,
# all queued messages will be sent.
#
# If you expect a reply for this message then you should use
# $Bus_Client->query() instead.
sub send {
	my ($self, $MID, $args) = @_;
	if ($self->{state} == CONNECTED) {
		eval {
			$self->{client}->send($MID, $args);
		};
		if (caught('IOException')) {
			print "Failed to send $MID: " . $self->handleIOException . "\n";
			$self->handleIOException();
			push @{$self->{sendQueue}}, [$MID, $args];
			return 0;
		} elsif ($@) {
			die $@;
		} else {
			return 1;
		}
	} else {
		push @{$self->{sendQueue}}, [$MID, $args];
		return 0;
	}
}

##
# Bus::Query $Bus_Client->query(String messageID, [Hash args], [Hash options])
# messageID: The message ID of the message to send.
# args: The arguments for the message.
# options: Extra options for this query.
#
# Send a query message over the bus. The returned Bus::Query object allows you to
# asynchronously check for replies for this message, and to fetch replies.
#
# So sending a query over the bus involves these steps:
# `l
# - Send the query.
# - Use the returned Bus::Query object to periodically check whether replies have
#   been received for this query.
# - Fetch the replies.
# `l`
#
# Here is a simple example:
# <pre class="code">
# # Send the query.
# my $query = $Bus_Client->query("hello", { name => "Joe" },
#                 { timeout => 10, collectAll => 1 });
#
# # Wait until the query is done or has timed out.
# while ($query->getState() == Bus::Query::WAITING) {
#     sleep 1;
# }
#
# if ($query->getState() == Bus::Query::DONE) {
#     while (my ($messageID, $args) = $query->getReply()) {
#         print "We have received a reply!\n";
#         # Do something with $messageID and $args...
#     }
#
# } else { # The stat is Bus::Query::TIMEOUT
#     print "10 seconds passed and we still don't have a reply!\n";
# }
# </pre>
#
# The following options are allowed:
# `l
# - timeout (float) - The maximum number of seconds to wait for clients to respond to
#       this query. If this reply has been reached, and not a single reply has been
#       received, then the query object's state will be set to Bus::Query::TIMEOUT.
#       But if at least one reply has been received by the time the timeout is reached,
#       then the state will be set to Bus::Query::DONE.<br>
#       The default timeout is 5 seconds.
# - collectAll (boolean) - Set to false if you only want to receive one reply for this query,
#       set to true if you want to receive multiple replies for this query.<br>
#       If collectAll is false, and a reply has been received (within the timeout), then
#       the Bus::Query object's state is immediately set to Bus::Query::DONE.<br>
#       If collectAll is true, then the query's state will stay at Bus::Query::WAITING
#       until the timeout has been reached. Once the timeout has been reached, the
#       state will be set to Bus::Query::DONE (if there are replies) or
#       Bus::Query::TIMEOUT (if there are no replies).
# `l`
#
# If the connection with the bus broke while sending the message, then
# the message is placed in a queue, and we'll attempt to reconnect (or
# restart the bus server) on the next iteration. Once reconnected,
# all queued messages will be sent.
sub query {
	my ($self, $MID, $args, $options) = @_;
	my %params = (
		bus  => $self,
		seq  => $self->{seq},
		messageID => $MID,
		args => $args
	);
	if ($options) {
		while (my ($key, $value) = each %{$options}) {
			$params{$key} = $value;
		}
	}

	my %params2 = ($args) ? (%{$args}) : ();
	$params2{SEQ} = $self->{seq};
	$self->send($MID, \%params2);

	$self->{seq} = ($self->{seq} + 1) % 4294967295;
	return new Bus::Query(\%params);
}

# requestDialog(Bytes clientID, String reason, args, Hash options)
sub requestDialog {
	my ($self, $clientID, $reason, $args, $options) = @_;
	$options ||= {};
	return new Bus::DialogMaster({
		bus => $self,
		peerID => $clientID,
		reason => $reason,
		args   => $args || {},
		timeout => $options->{timeout}
	});
}

##
# CallbackList $Bus_Client->onMessageReceived()
#
# This event is triggered when a message has been received from the bus.
# The event argument is a hash, containing these two items:
# `l
# - messageID (String): The message ID.
# - args (Hash): The message arguments.
# `l`
sub onMessageReceived {
	return $_[0]->{onMessageReceived};
}

##
# CallbackList $Bus_Client->onConnected()
#
# This event is triggered when the client connects.  It may happen more than
# once, if the client has to reconnect for any reason.  The event argument
# is undef.
sub onConnected {
	return $_[0]->{onConnected};
}

sub onDialogRequested {
	return $_[0]->{onDialogRequested};
}

1;
