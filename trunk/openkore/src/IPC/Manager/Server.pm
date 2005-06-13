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
	$self->SUPER::onClientExit($client);

	my %args = (
		ID => $client->{ID},
	);
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
		my $to = $self->{ipc_clients}{$args->{TO}}{name};
		print "Delivering message from $client->{name} to $to\n";
		$args->{FROM} = $client->{ID};

		if ($self->send($args->{TO}, $msgID, $args) == -1) {
			# Unable to deliver the message because the specified client doesn't exist.
			# Notify the sender.
			my %args = (
				ID => $client->{ID}
			);
			$self->send($client->{ID}, 'CLIENT_NOT_FOUND', \%args);
		}

	} else {
		# Broadcast global messages to all clients except:
		# - The sender.
		# - Clients that aren't done with handshaking yet.

		foreach my $c (@{$self->{clients}}) {
			next if (!$c || $c eq $client || !$c->{ready} || !$c->{wantGlobals});
			$args->{FROM} = $client->{ID};
			$self->send($c->{ID}, $msgID, $args);
		}
	}
}

1;
