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
	}
	print "Received query from client " . $client->getIndex() . "\n";

	my %request = (
		packet => $args->{packet},
		client => $client
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
#	my $packet = substr($ipcArgs->{packet}, 0, 18);
}


##################################################


sub onClientNew {
	my ($self, $client) = @_;
	$client->{"$CLASS parser"} = new Bus::MessageParser();
}

sub onClientData {
	my ($self, $client, $msg) = @_;
	my ($ID, $args);

	my $parser = $client->{"$CLASS parser"};
	$parser->add($msg);
	while ($args = $parser->readNext(\$ID)) {
		$self->process($client, $ID, $args);
	}
}

sub iterate {
	my ($self) = @_;
	my ($server, $queue);

	$self->SUPER::iterate();
	$server = $self->{"$CLASS server"};
	$queue = $self->{"$CLASS queue"};

	if ($server->getState() eq 'requested') {
		# Send the response to the client.
		if (@{$queue} > 0 && $queue->[0]{client}) {
			my ($data, %args);

			$args{packet} = $server->readResponse();
			$data = serialize("Poseidon Reply", \%args);
			$queue->[0]{client}->send($data);
			$queue->[0]{client}->close();
			print "Sent result to client " . $queue->[0]{client}->getIndex() . "\n";
		}
		shift @{$queue};

	} elsif (@{$queue} > 0 && $server->getState() eq 'ready') {
		print "Querying Ragnarok Online client.\n";
		$server->query($queue->[0]{packet});
	}
}

1;
