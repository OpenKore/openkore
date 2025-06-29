############################################################
# Poseidon query interface for OpenKore
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2025 OpenKore Development Team
############################################################
##
# MODULE DESCRIPTION: Poseidon GameGuard query handler.
#
# Poseidon provides a simple way to respond to GameGuard queries.
package Poseidon::Client;

use strict;
use IO::Socket::INET;
use Globals qw(%config);
use Log qw(error debug);
use Bus::MessageParser;
use Bus::Messages qw(serialize);
use Utils qw(dataWaiting);
use Plugins;
use Misc;

use constant POSEIDON_SUPPORT_URL => 'https://openkore.com/wiki/Poseidon';

our $instance;


# Poseidon::Client Poseidon::Client->new(String host, int port)
#
# Create a new Poseidon::Client object.
sub _new {
	my ($class, $host, $port) = @_;
	my %self = (
		host => $host,
		port => $port
	);
	return bless \%self, $class;
}

# IO::Socket::INET $PoseidonClient->_connect()
#
# Connect to the poseidon server.
sub _connect {
	my ($self) = @_;
	my $socket = new IO::Socket::INET(
		PeerHost => $self->{host},
		PeerPort => $self->{port},
		Proto => 'tcp'
	);
	return $socket;
}

##
# void $PoseidonClient->query(Bytes packet)
# packet: A GameGuard query packet.
#
# Send a GameGuard query packet to the Poseidon core.
#
# When an appropriate response packet has been determined,
# it will be available through $PoseidonClient->getResult()
sub query {
	my ($self, $packet) = @_;
	my $socket = $self->_connect();
	if (!$socket) {
		error "Your Ragnarok Online server uses GameGuard. In order " .
			"to support GameGuard, you must use the Poseidon " .
			"server. Please read " . POSEIDON_SUPPORT_URL .
			" for more information.\n";
		# unsafe to continue, disconnect
		offlineMode();
		return;
	}

	my (%args, $data);
	# Plugin hook to make it possible to add additional data piggy-backed
	# to the Poseidon request packet (auth information for example)
	Plugins::callHook('Poseidon/client_authenticate', {
		args => \%args,
	});
	$args{packet} = $packet;
	$data = serialize("Poseidon Query", \%args);
	$socket->send($data);
	$socket->flush();
	$self->{socket} = $socket;
	$self->{parser} = new Bus::MessageParser();
}

##
# Bytes $PoseidonClient->getResult()
# Returns: the GameGuard query result, or undef if there is no result yet.
# Ensures: if defined(result): !defined($self->getResult())
#
# Get the result for the last query.
sub getResult {
	my ($self) = @_;

	if (!$self->{socket} || !$self->{socket}->connected
	 || !dataWaiting($self->{socket})) {
		return undef;
	}

	my ($buf, $ID, $args);
	$self->{socket}->recv($buf, 1024 * 32);
	if (!$buf) {
		# This shouldn't have happened.
		error "The Poseidon server closed the connection unexpectedly or could not respond " .
			"to your request due to a server bandwidth issue. Please report this bug.\n";
		$self->{socket} = undef;
		offlineMode();
		return undef;
	}

	$self->{parser}->add($buf);
	if ($args = $self->{parser}->readNext(\$ID)) {
		if ($ID ne "Poseidon Reply") {
			error "The Poseidon server sent a wrong reply ID ($ID). Please report this bug.\n";
			$self->{socket} = undef;
			offlineMode();
			return undef;
		} else {
			$self->{socket} = undef;
			return $args->{packet};
		}
	} else {
		# We haven't gotten a full message yet.
		return undef;
	}
}

##
# Poseidon::Client Poseidon::Client::getInstance()
#
# Get the global Poseidon::Client instance.
sub getInstance {
	if (!$instance) {
		$instance = Poseidon::Client->_new(
			$config{poseidonQueryServerIp} || 'localhost',
			$config{poseidonQueryServerPort} || 24390);
	}
	return $instance;
}

1;
