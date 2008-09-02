#!/usr/bin/env perl
###########################################################
# Poseidon server - XKore Integrated version
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
###########################################################
package Poseidon::EmbedServer;

use strict;
use Scalar::Util;
use Base::Server;
use Bus::MessageParser;
use Bus::Messages qw(serialize);
use Log qw(message);
use Translation qw(T TF);
use base qw(Base::Server);
use Globals;

my $CLASS = "Poseidon::EmbedServer";

use constant QUERY_SERVER_HOST => '127.0.0.1';
use constant QUERY_SERVER_PORT => 24390;
use constant POSEIDON_SUPPORT_URL => 'http://www.openkore.com/aliases/poseidon.php';


##
# Poseidon::EmbedServer->new
#
# Create a new Poseidon::EmbedServer object.
sub new {
	my $class = shift;
	my $ip = QUERY_SERVER_HOST;
	my $port = QUERY_SERVER_PORT;
	my $self = $class->SUPER::new($port, $ip);

	# Array<Request> queue
	#
	# The GameGuard query packets queue. Both received and awaiting response
	#
	# Invariant: defined(queue)
	$self->{"$CLASS queue"} = [];
	$self->{"$CLASS responseQueue"} = [];
	$self->{sentQuery} = 0;
	message TF("Embed Poseidon Server initialized\n" . 
		"Please read %s for more information.\n\n", POSEIDON_SUPPORT_URL), "startup";

	return $self;
}

##
# void $EmbedServer->process(Base::Server::Client client, String ID, Hash* args)
#
# Push an OpenKore GameGuard query to the queue.
sub process {
	my ($self, $client, $ID, $args) = @_;

	if ($ID ne "Poseidon Query") {
		$client->close();
		return;
	}
	message TF("Poseidon: received query from client %s\n", $client->getIndex()), "poseidon";

	my %request = (
		packet => $args->{packet},
		client => $client
	);
	
	Scalar::Util::weaken($request{client});
	push @{$self->{"$CLASS queue"}}, \%request;
}

sub onClientNew {
	my ($self, $client) = @_;
	$client->{"$CLASS parser"} = new Bus::MessageParser();
}

sub onClientData {
	my ($self, $client, $msg) = @_;
	my ($ID, $args, $rest);

	my $parser = $client->{"$CLASS parser"};
	$parser->add($msg);
	while ($args = $parser->readNext(\$ID)) {
		$self->process($client, $ID, $args);
	}
}

sub iterate {
	my $self = shift;
	my $r_net = shift;
	my ($response, $queue);

	$self->SUPER::iterate();
	$response = $self->{"$CLASS responseQueue"};
	$queue = $self->{"$CLASS queue"};

	if (@{$response} > 0) {
		# Send the response to the client.
		if (@{$queue} > 0 && $queue->[0]{client}) {
			my ($data, %args);

			$args{packet} = shift @{$response};

			# FIXME: somehow, xkoreproxy makes the RO client send two identical gameguard syncs making the receiver
			# disconnect from the server - this happens intermittently
			$args{packet} = substr($args{packet}, 0, 18);

			$data = serialize("Poseidon Reply", \%args);
			$queue->[0]{client}->send($data);
			$queue->[0]{client}->close();
			message TF("Poseidon: Sent result to client %s\n", $queue->[0]{client}->getIndex()), "poseidon";
		}
		$self->{sentQuery} = 0;
		shift @{$queue};

	} elsif (@{$queue} > 0 && !$self->{sentQuery}) {
		message T("Poseidon: Querying Ragnarok Online client.\n"), "poseidon";
		#$r_net->clientSend($queue->[0]{packet});
		# send the query to the connected RO client
		$messageSender->{net}->clientSend($queue->[0]{packet});
		$self->{sentQuery} = 1;
	}
}

sub setResponse {
	my $self = shift;
	my $packet = shift;
	
	push @{$self->{"$CLASS responseQueue"}}, $packet;	
}

sub awaitingResponse {
	my $self = shift;
	
	return ($self->{sentQuery} && @{$self->{"$CLASS responseQueue"}} == 0);
}

1;
