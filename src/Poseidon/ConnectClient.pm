package Poseidon::ConnectClient;

use strict;
use IO::Socket::INET;
use Globals qw(%config);
use Log qw(error debug);
use Bus::MessageParser;
use Bus::Messages qw(serialize);
use Utils qw(dataWaiting);
use Plugins;
use Misc;

sub new {
	my ($class, $host, $port) = @_;
	my %self = (
		host => $host,
		port => $port
	);
	return bless \%self, $class;
}

sub _connect {
	my ($self) = @_;
	my $socket = new IO::Socket::INET(
		PeerHost => $self->{host},
		PeerPort => $self->{port},
		Proto => 'tcp'
	);
	return $socket;
}

sub askForConnection {
	my ($self) = @_;
	my $socket = $self->_connect();
	if (!$socket) {
		error "Your server uses gameguard, please use poseidon.\n";
		offlineMode();
		return -1;
	}

	my %args;
	$args{username} = $config{username};
	my $request = serialize("Poseidon Connect", \%args);
	$socket->send($request);
	$socket->flush;
	$self->{socket} = $socket;
	$self->{parser} = new Bus::MessageParser();
	return;
}

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
			return ({client => $args->{client_index}, port => $args->{query_server_port}});
		}
	} else {
		# We haven't gotten a full message yet.
		return undef;
	}
}

1;
