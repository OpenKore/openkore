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
use Time::HiRes qw(time);
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
	
	my %request = (
		client => $client,
		username => $args->{username}
	);
	Scalar::Util::weaken($request{client});
	
	my $rag_client_index = $self->{"$CLASS server"}->find_bounded_client($args->{username});
	
	if ($rag_client_index == -1) {
		$request{error} = "[PoseidonServer]-> This username doesn't have a ragnarok client bounded to it";
		
	} else {
		my $rag_client = $self->{"$CLASS server"}->{clients_servers}[$rag_client_index];
		
		if (!$rag_client) {
			$request{error} = "[PoseidonServer]-> Ragnarok client of this username has disconnected";
			
		} elsif (!$rag_client->{client}->{connectedToMap}) {
			$request{error} = "[PoseidonServer]-> Ragnarok client of this username is not connected to the map server";
			
		} else {
			print "[PoseidonServer]-> This username uses the ragnrok client of index ".$rag_client_index." with port ".$rag_client->getPort()."\n";
			$request{packet} = $args->{packet};
			$request{rag_client} = $rag_client;
			$request{state} = 'received_from_server';

			# perform client authentication here
			Plugins::callHook('Poseidon/server_authenticate', {
				args_hash => $args,
			});

			# note: the authentication plugin must set auth_failed to true if it doesn't
			# want the Poseidon server to respond to the query
			return if ($args->{auth_failed});
		}
	}
	
	if (exists $request{error}) {
		print $request{error}."\n";
		$request{state} = 'failed';
	}
	push @{$self->{"$CLASS queue"}}, \%request;
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
	
	my $queue_last = $#{$queue};
	my $current = 0;
	while ($current <= $queue_last) {
		my $request = $queue->[$current];

		# received response packet from client, send success to openkore
		if ($request->{state} eq 'requested_to_client' && $request->{rag_client}->getState() eq 'requested') {
			my ($data, %args);
			$args{packet} = $request->{rag_client}->readResponse();
			$data = serialize("Poseidon Reply", \%args);
			$request->{client}->send($data);
			$request->{client}->close();
			
			my $elapsed = (time - $request->{request_time});
			$request->{rag_client}->addQueryTime($elapsed);
			my $query_count = $request->{rag_client}->getQueryCount;
			my $everage = $request->{rag_client}->getEverageQueryTime;
			
			print "[PoseidonServer]-> Sent success result to client [Name: " . $request->{username} . "] [Time: " . time . "]\n";
			print "[PoseidonServer]-> Reply of number ".$query_count." took ".$elapsed." seconds, everage client reply time is ".$everage." seconds\n";
			
			splice(@{$queue}, $current, 1);
			$queue_last = $#{$queue};

		# send request to client
		} elsif ($request->{state} eq 'received_from_server' && $request->{rag_client}->getState() eq 'ready') {
			print "[PoseidonServer]-> Querying Ragnarok Online client [Name: " . $request->{username} . "] [Time: " . time . "]...\n";
			$request->{rag_client}->query($request->{packet});
			$request->{state} = 'requested_to_client';
			$request->{request_time} = time;
			
			$current++;
		
		# send fail notice to openkore
		} elsif ($request->{state} eq 'failed') {
			my ($data, %args);
			$args{error} = $request->{error};
			$args{packet} = -1;
			$data = serialize("Poseidon Reply", \%args);
			$request->{client}->send($data);
			$request->{client}->close();
			print "[PoseidonServer]-> Sent failed result to client [Name: " . $request->{username} . "] [Time: " . time . "]\n";
			
			splice(@{$queue}, $current, 1);
			$queue_last = $#{$queue};
			
		} else {
			$current++;
		}
	}
}

1;
