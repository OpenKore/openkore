package client;

use strict;
use IO::Socket::INET;
use IPC::Messages qw(encode decode);
use Globals;
use Log qw(message debug);

use constant DEFAULT_MEDIA_SERVER_PORT => 12701;
use constant MIN_MAX_VOLUME => 128;

our $instance;


# client->new(String host, int port)
#
# Create a new client object.
sub _new {
	my ($class, $host, $port) = @_;
	my %self = (
		host => $host,
		port => $port
	);
	return bless \%self, $class;
}

# $client->_connect()
#
# Connect to the server.
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
# $client->play(file, domain, loop, blocking)
sub play {
	my ($self, $file, $domain, $loop, $volume) = @_;
	my $socket = $self->_connect();
	if (!$socket) {
		debug "mediaServer not initalized.\n";
		return;
	}

	my (%args, $data);
	$args{file} = $file;
	$args{domain} = $domain;
	$args{loop} = $loop || 0;
	$args{volume} = $volume || MIN_MAX_VOLUME;
	$data = encode("mediaServer playfile", \%args);
	$socket->send($data);
	$socket->flush();
	$self->{socket} = $socket;
	$self->{buf} = '';
}

sub speak {
	my ($self, $message, $domain, $loop, $volume) = @_;
	my $socket = $self->_connect();
	if (!$socket) {
		debug "mediaServer not initalized.\n";
		return;
	}

	my (%args, $data);
	$args{message} = $message;
	$args{domain} = $domain;
	$args{loop} = $loop || 0;
	$args{volume} = $volume || MIN_MAX_VOLUME;
	$data = encode("mediaServer speak", \%args);
	$socket->send($data);
	$socket->flush();
	$self->{socket} = $socket;
	$self->{buf} = '';
}

sub quit {
	my ($self) = @_;
	my $socket = $self->_connect();
	if (!$socket) {
		debug "mediaServer not initalized.\n";
		return;
	}

	my (%args, $data);
	$args{command} = 'stop';
	$args{which} = 'ALL';
	$data = encode("mediaServer command", \%args);
	$socket->send($data);
	$socket->flush();
	$self->{socket} = $socket;
	$self->{buf} = '';
}

##
# client::getInstance()
#
# Get the global client instance.
sub getInstance {
	if (!$instance) {
		$instance = client->_new(
			$config{mediaServer} || 'localhost',
			$config{mediaPort} || DEFAULT_MEDIA_SERVER_PORT);
#		$instance = client->_new('localhost', DEFAULT_MEDIA_SERVER_PORT);
	}
	return $instance;
}

1;
