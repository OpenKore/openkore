###########################################################
# Poseidon server - OpenKore communication channel
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
###########################################################
package Poseidon::QueryServer;

use strict;
use Scalar::Util;
use Base::Server;
use Bus::MessageParser;
use Bus::Messages qw(serialize);
use Poseidon::RagnarokServer;
use Poseidon::RagnaServerHolder;
use base qw(Base::Server);
use Plugins;

my $CLASS = "Poseidon::QueryServer";


# struct Request {
#     Bytes packet;
#     Base::Server::Client client;
# }

##
# Poseidon::QueryServer->new(String port, String host, Poseidon::RagnarokServer ROServer)
# port: The port to start this server on.
# host: The host to bind this server to.
# ROServer: The RagnarokServer object to send GameGuard queries to.
# Require: defined($port) && defined($ROServer)
#
# Create a new Poseidon::QueryServer object.
sub new {
	my ($class, $port, $host, $roServer) = @_;
	my $self = $class->SUPER::new($port, $host);

	# Invariant: server isa 'Poseidon::RagnarokServer'
	$self->{"$CLASS server"} = $roServer;

	# Array<Request> queue
	#
	# The GameGuard query packets queue.
	#
	# Invariant: defined(queue)
	$self->{"$CLASS queue"} = [];

	return $self;
}

##
# void $QueryServer->process(Base::Server::Client client, String ID, Hash* args)
#
# Push an OpenKore GameGuard query to the queue.
sub process {
	my ($self, $client, $ID, $args) = @_;

	if ($ID ne "Poseidon Query") {
		$client->close();
		return;
	} elsif (!$args->{username}) {
		print "Username is needed \n";
		return $args->{auth_failed};
	}

	print "[PoseidonServer]-> Received query from bot client [Name: " . $args->{username} . "] [port: " . $self->getPort . "] [Time: " . time . "]\n";
	
	my $rag_client_index = $self->{"$CLASS server"}->find_bounded_client($args->{username});
	if ($rag_client_index == -1) {
		print "[PoseidonServer]-> This username doesn`t have a ragnarok client bounded to it \n";
	} else {
		my $rag_client = $self->{"$CLASS server"}->{clients_servers}[$rag_client_index];
		if (!$rag_client) {
			print "[PoseidonServer]-> Ragnarok client of this username has disconnected \n";
		} elsif (!$rag_client->{client}->{connectedToMap}) {
			print "[PoseidonServer]-> Ragnarok client of this username is not connected to the map server \n";
		} else {
			print "[PoseidonServer]-> This username uses the ragnrok client of index ".$rag_client_index." with port ".$rag_client->getPort()."\n";
			my %request = (
				packet => $args->{packet},
				client => $client,
				rag_client => $rag_client,
				username => $args->{username},
				qstate => 'received'
			);

			# perform client authentication here
			Plugins::callHook('Poseidon/server_authenticate', {
				args_hash => $args,
			});

			# note: the authentication plugin must set auth_failed to true if it doesn't
			# want the Poseidon server to respond to the query
			return if ($args->{auth_failed});

			Scalar::Util::weaken($request{client});
			push @{$self->{"$CLASS queue"}}, \%request;
		}
	}
}

##################################################

sub onClientNew {
	my ($self, $client, $index) = @_;
	$client->{"$CLASS parser"} = new Bus::MessageParser();
	print "[PoseidonServer]-> New Bot Client Connected on Query Server: " . $client->getIndex() . "\n";
}

sub onClientExit {
	my ($self, $client, $index) = @_;
	print "[PoseidonServer]-> Bot Client Disconnected from Query Server: " . $client->getIndex() . "\n";
}

sub onClientData {
	my ($self, $client, $msg) = @_;
	my ($ID, $args);

	my $parser = $client->{"$CLASS parser"};
	
	$parser->add($msg);
	
	while ($args = $parser->readNext(\$ID))
	{
		$self->process($client, $ID, $args);
	}
}

sub iterate {
	my ($self) = @_;
	my ($server, $queue);

	$self->SUPER::iterate();
	$server = $self->{"$CLASS server"};
	$queue = $self->{"$CLASS queue"};
	
	return unless (@{$queue} > 0);
	my $request = $queue->[0];

	if ($request->{rag_client}->getState() eq 'requested') {
		# Send the response to the client.
		if ($request->{client}) {
			my ($data, %args);

			$args{packet} = $request->{rag_client}->readResponse();
			$data = serialize("Poseidon Reply", \%args);
			$request->{client}->send($data);
			$request->{client}->close();
			print "[PoseidonServer]-> Sent result to client [Name: " . $request->{username} . "] [Time: " . time . "]\n";
		}
		shift @{$queue};

	} elsif ($request->{rag_client}->getState() eq 'ready') {
		print "[PoseidonServer]-> Querying Ragnarok Online client [Name: " . $request->{username} . "] [Time: " . time . "]...\n";
		$request->{rag_client}->query($request->{packet});
	}
}

1;
