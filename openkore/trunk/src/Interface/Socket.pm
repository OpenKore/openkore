#########################################################################
#  OpenKore - Socket interface
#
#  Copyright (c) 2007 OpenKore development team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#########################################################################
##
# MODULE DESCRIPTION: Socket interface.
#
# An interface which runs on a Unix socket. Any number of clients can
# connect to the socket to view OpenKore messages and to enter user input.
# This allows one to run OpenKore in the background without the use of tools
# like GNU screen.
package Interface::Socket;

use strict;
use Interface;
use base qw(Interface);
use Utils qw(timeOut);


sub new {
	my ($class) = @_;
	my %self = (
		server => new Interface::Socket::Server()
	);
	return bless \%self, $class;
}

sub iterate {
	my ($self) = @_;
	$self->{server}->iterate();
}

sub getInput {
	my ($self, $timeout) = @_;
	my $line;

	if ($timeout < 0) {
		$line = $self->{server}->getInput();

	} elsif ($timeout == 0) {
		if ($self->{server}->hasInput()) {
			$line = $self->{server}->getInput();
		}

	} else {
		my %time = (time => time, timeout => $timeout);
		while (!defined($line) && !timeOut(\%time)) {
			if ($self->{server}->hasInput()) {
				$line = $self->{server}->getInput();
			}
		}
	}

	return $line;
}

sub writeOutput {
	my $self = shift;
	$self->{server}->addMessage(@_);
}

sub title {
	my ($self, $title) = @_;
	if ($title) {
		if (defined($self->{title}) && $self->{title} ne $title) {
			$self->{title} = $title;
			$self->{server}->broadcast("SET_TITLE",	{ title => $title });
		}
	} else {
		return $self->{title};
	}
}


package Interface::Socket::Server;

use strict;
use IO::Socket::UNIX;
use Base::Server;
use base qw(Base::Server);
use Bus::Messages qw(serialize);
use Bus::MessageParser;

sub new {
	my ($class) = @_;
	my $socket_file = "openkore-console.socket";
	my $socket = new IO::Socket::UNIX(
		Local => $socket_file,
		Type => SOCK_STREAM,
		Listen => 5
	);
	if (!$socket && $! == 98) {
		$socket = new IO::Socket::UNIX(
			Peer => $socket_file,
			Type => SOCK_STREAM
		);
		if (!$socket) {
			unlink($socket_file);
			$socket = new IO::Socket::UNIX(
				Local => $socket_file,
				Type => SOCK_STREAM,
				Listen => 5
			);
		} else {
			print "There is already an OpenKore instance listening at '$socket_file'.\n";
			exit 1;
		}
	}
	if (!$socket) {
		print "Cannot listen at '$socket_file': $!\n";
		exit 1;
	}

	my $self = $class->SUPER::createFromSocket($socket);
	$self->{parser} = new Bus::MessageParser();
	$self->{messages} = [];
	$self->{inputs} = [];
	$self->{socket_file} = $socket_file;

	$SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {
		unlink $socket_file;
		exit 2;
	};

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	unlink $self->{socket_file};
	$self->SUPER::DESTROY();
}

sub addMessage {
	my ($self, $type, $message, $domain) = @_;
	$self->broadcast("OUTPUT", {
		type    => $type,
		message => $message,
		domain  => $domain
	});
	push @{$self->{messages}}, [$type, $message, $domain];
	if (@{$self->{messages}} > 20) {
		shift @{$self->{messages}};
	}
}

sub broadcast {
	my $self = shift;
	my $clients = $self->clients();
	if (@{$clients} > 0) {
		my $messageID = shift;
		my $message = serialize($messageID, @_);
		foreach my $client (@{$clients}) {
			if ($client->{started}) {
				$client->send($message);
			}
		}
	}
}

sub hasInput {
	my ($self) = @_;
	return @{$self->{inputs}} > 0;
}

sub getInput {
	my ($self) = @_;
	return shift @{$self->{inputs}};
}

sub onClientNew {
	my ($self, $client) = @_;
}

sub onClientData {
	my ($self, $client, $data) = @_;
	$self->{parser}->add($data);

	my $ID;
	while (my $args = $self->{parser}->readNext(\$ID)) {
		if ($ID eq "INPUT") {
			push @{$self->{inputs}}, $args->{data};
		} elsif ($ID eq "START") {
			$client->{started} = 1;
			foreach my $entry (@{$self->{messages}}) {
				my $message = serialize("OUTPUT", {
					type    => $entry->[0],
					message => $entry->[1],
					domain  => $entry->[2]
				});
				$client->send($message);
			}
		}
	}
}

1;