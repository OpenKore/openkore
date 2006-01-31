package Poseidon::QueryServer;

use strict;
use Scalar::Util;
use Base::Server;
use IPC::Messages qw(encode decode);
use Poseidon::RagnarokServer;
use base qw(Base::Server);

my $CLASS = "Poseidon::QueryServer";


# struct Request {
#     Bytes packet;
#     Base::Server::Client client;
# }

# Poseidon::QueryServer->new(String port, String host, Poseidon::RagnarokServer ROServer)
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

sub onClientNew {
	my ($self, $client) = @_;
	$client->{"$CLASS data"} = '';
}

sub onClientData {
	my ($self, $client, $msg) = @_;
	my ($ID, %args, $rest);

	$client->{"$CLASS data"} .= $msg;
	$ID = decode($client->{"$CLASS data"}, \%args, \$rest);
	if (defined($ID)) {
		$self->process($client, $ID, \%args);
	}
}

# void $QueryServer->process(Base::Server::Client client, String ID, Hash* args)
#
# Add an OpenKore GameGuard query to the queue.
sub process {
	my ($self, $client, $ID, $args) = @_;

	if ($ID ne "GameGuard Query") {
		$client->close();
		return;
	}
	print "Received query from client " . $client->getIndex() . "\n";

	my %request = (
		packet => $args->{packet},
		client => $client
	);
	Scalar::Util::weaken($request{client});
	push @{$self->{"$CLASS queue"}}, \%request;
#	my $packet = substr($ipcArgs->{packet}, 0, 18);
}

sub iterate {
	my ($self) = @_;
	my ($server, $queue);

	$self->SUPER::iterate();
	$server = $self->{"$CLASS server"};
	$queue = $self->{"$CLASS queue"};

	if ($server->getState() eq 'requested') {
		if ($queue->[0]{client}) {
			my ($data, %args);

			$args{packet} = $server->readResponse();
			$data = encode("GameGuard Response", \%args);
			$queue->[0]{client}->send($data);
			$queue->[0]{client}->close();
		}
		shift @{$queue};

	} elsif (@{$queue} > 0 && $server->getState() eq 'ready') {
		$server->query($queue->[0]{packet});
	}
}

1;
