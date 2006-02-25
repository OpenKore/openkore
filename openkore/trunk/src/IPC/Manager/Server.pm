package IPC::Manager::Server;

use strict;
use Time::HiRes qw(sleep);
use IPC::Server;
use base qw(IPC::Server);


# New client connected to network
sub onClientNew {
	my ($self, $client, $index) = @_;
	$self->SUPER::onClientNew($client, $index);

	# Initiate handshake
	my %args = (
		ID => $client->{ID}
	);
	$self->send($client->{ID}, "HELLO", \%args);
	$client->{userAgent} = "Unknown";
	$client->{name} = "Unknown:$client->{ID}";
}

# A client disconnected
sub onClientExit {
	my ($self, $client) = @_;
	my %args = (
		id => $client->{ID},
		name => $client->{name},
		userAgent => $client->{userAgent}
	);
	$self->SUPER::onClientExit($client);
	$self->broadcast(undef, 'LEAVE', \%args);
}

# A client sent a message
sub onIPCData {
	my ($self, $client, $msgID, $args) = @_;

	print "Message: $msgID (from $client->{name})\n";

	# Process known messages internally.
	# Deliver unknown messages to client(s).

	if ($msgID eq "HELLO") {
		# A new client just connected
		$client->{userAgent} = $args->{userAgent};
		$client->{wantGlobals} = exists($args->{wantGlobals}) ? $args->{wantGlobals} : 1;
		$client->{ready} = 1;
		$client->{name} = $args->{userAgent} . ":" . $client->{ID};

		# Broadcast a JOIN message about this client
		print "Client identified as $client->{name}; broadcasting JOIN\n";
		my %args = (
			    id => $client->{ID},
			    name => $client->{name},
			    userAgent => $client->{userAgent},
			    ip => $client->{host}
		);
		$self->broadcast(undef, "JOIN", \%args, $client);

	} elsif ($msgID eq "_LIST-CLIENTS") {
		my %args;
		my $i = 0;

		foreach my $c (@{$self->{clients}}) {
			next if (!$c || !$c->{ready});
			$args{"client$i"} = $c->{ID};
			$args{"clientUserAgent$i"} = $c->{userAgent};
			$i++;
		}
		$args{count} = $i;
		$self->send($client->{ID}, "_LIST-CLIENTS", \%args);

	} elsif (exists $args->{TO}) {
		# Deliver private message
		my $failed;
		my $recepient = $self->{ipc_clients}{$args->{TO}};
		my $recepientName;

		if ($recepient) {
			$recepientName = $recepient->{name};
			print "Delivering message from $client->{name} to $recepientName\n";
			$args->{FROM} = $client->{ID};

			if ($self->send($args->{TO}, $msgID, $args) == -1) {
				$failed = 1;
			}
		} else {
			$failed = 1;
			$recepientName = "client $args->{TO}";
		}

		if ($failed) {
			# Unable to deliver the message because the specified client doesn't exist.
			# Notify the sender.
			my %args = (msgID => $msgID, recepient => $args->{TO});
			$self->send($client->{ID}, 'CLIENT_NOT_FOUND', \%args);
			print "Failed to deliver message from $client->{name} to $recepientName\n";
		}

	} else {
		# Broadcast global messages:
		$self->broadcast($client, $msgID, $args);
	}
}

# Broadcast a message (which comes from $sender) to other clients on the network,
# except clients that aren't done with handshaking yet, or don't want to have
# global messages. Set $sender to undef if the message is from the IPC manager.
sub broadcast {
	my ($self, $sender, $msgID, $args, $exclude) = @_;
	$args->{FROM} = $sender->{ID} if ($sender);
	foreach my $c (@{$self->{clients}}) {
		next if (!$c || (defined($sender) && $c eq $sender) || (defined($exclude) && $c eq $exclude) || !$c->{ready} || !$c->{wantGlobals});
		$self->send($c->{ID}, $msgID, $args);
	}
}

1;
