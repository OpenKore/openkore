# A basic implementation of an abstract Ragnarok Online server.
# This is the abstract base class for @MODULE(Base::Ragnarok::AccountServer),
# @MODULE(Base::Ragnarok::CharServer) and @MODULE(Base::Ragnarok::MapServer).
package Base::RagnarokServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use Network::MessageTokenizer;
use Utils::Exceptions;
use Globals qw($masterServer);
use Misc;
use Log qw(debug);

sub new {
	my ($class, $host, $port, $serverType, $rpackets) = @_;
	my $self = $class->SUPER::new($port, $host);
	$self->{serverType} = $serverType;
	$self->{rpackets} = $rpackets;
	$self->{recvPacketParser} = Network::Receive->create(undef, $serverType);
	$self->{sendPacketParser} = Network::Send->create(undef, $serverType);
	return $self;
}

sub getServerType {
	return $_[0]->{serverType};
}

sub setServerType {
	my ($self, $serverType) = @_;
	if ($self->{severType} != $serverType) {
		$self->{serverType} = $serverType;
		foreach my $client (@{$self->clients()}) {
			my $buffer = $client->{tokenizer}->getBuffer();
			$client->{tokenizer} = new Network::MessageTokenizer(
				$self->{rpackets});
			$client->{tokenizer}->add($buffer);
		}
	}
}

sub getRecvPackets {
	return $_[0]->{rpackets};
}

sub onClientNew {
	my ($self, $client) = @_;
	$client->{tokenizer} = new Network::MessageTokenizer(
		$self->{rpackets});
}

sub onClientData {
	my ($self, $client, $data) = @_;
	$client->{tokenizer}->add($data);
	
	$client->{outbox} && $client->{outbox}->add($_) for $self->{sendPacketParser}->process(
		$client->{tokenizer}, $self, $client
	);
}

sub displayMessage {
	if (defined &Misc::visualDump) {
		Misc::visualDump($_[1]);
	}
}

sub unhandledMessage {
}

sub unknownMessage {
	my ($self, $args, $client) = @_;
	$client->close;
}

1;
