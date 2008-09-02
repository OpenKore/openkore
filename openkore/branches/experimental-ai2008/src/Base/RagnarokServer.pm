# A basic implementation of an abstract Ragnarok Online server.
# This is the abstract base class for @MODULE(Base::Ragnarok::AccountServer),
# @MODULE(Base::Ragnarok::CharServer) and @MODULE(Base::Ragnarok::MapServer).
package Base::RagnarokServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use Network::MessageTokenizer;
use Utils::Exceptions;
use Misc;

sub new {
	my ($class, $host, $port, $serverType, $rpackets) = @_;
	my $self = $class->SUPER::new($port, $host);
	$self->{serverType} = $serverType;
	$self->{rpackets} = $rpackets;
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
	my $type;
	while (my $message = $client->{tokenizer}->readNext(\$type)) {
		if ($type == Network::MessageTokenizer::KNOWN_MESSAGE) {
			my $ID = Network::MessageTokenizer::getMessageID($message);
			my $handler = $self->can('process_' . $ID);
			if ($handler) {
				$handler->($self, $client, $message);
			} else {
				$self->unhandledMessage($client, $message);
			}
		} else {
			$client->close();
		}
	}
}

sub displayMessage {
	if (defined &Misc::visualDump) {
		Misc::visualDump($_[1]);
	}
}

sub unhandledMessage {
}

1;
