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
#
# <h2>Protocol</h2>
#
# <h3>Passive vs active modes</h3>
# Clients can be in two modes:
# `l
# - Passive. In this state, no data is sent to the client unless the
#   client queries the server for certain information.
# - Active. In this state, the server will actively send the latest events
#   (new log messages, title changes, etc.) to the client.
# `l`
# Upon connecting to the server, a client is set to passive mode by default.
#
# The client can switch to passive or active modes with the messages
# "set passive" and "set active".
#
# <h3>Interface event messages</h3>
#
# <h4>output (server to client)</h4>
# This message is sent when a message is to be displayed on screen. It has the following
# parameters: "type", "message", "domain".
#
# <h4>title changed (server to client)</h4>
# This message is sent whenever the title of the interface is changed. It has one parameter, "title".
#
# <h4>input (client to server)</h4>
# Tell the server that the user has entered some text as input. It has one parameter, "data".
package Interface::Socket;

use strict;
use Interface;
use base qw(Interface);
use Utils qw(timeOut);
use Interface::Console::Simple;


sub new {
	my ($class) = @_;
	my %self = (
		server => new Interface::Socket::Server(),
		console => new Interface::Console::Simple()
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

	if (my $input = $self->{console}->getInput(0)) {
		$self->{server}->addInput($input);
	}

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
	$self->{console}->writeOutput(@_);
}

sub title {
	my ($self, $title) = @_;
	if ($title) {
		if (!defined($self->{title}) || $self->{title} ne $title) {
			$self->{title} = $title;
			$self->{server}->setTitle($title);
			$self->{console}->title($title);
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
use Settings;
use Bus::Messages qw(serialize);
use Bus::MessageParser;

# Client modes.
use enum qw(PASSIVE ACTIVE);

sub new {
	my ($class) = @_;
	my $socket_file = "$Settings::logs_folder/console.socket";
	my $pid_file = "$Settings::logs_folder/openkore.pid";
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
			print STDERR "There is already an OpenKore instance listening at '$socket_file'.\n";
			exit 1;
		}
	}
	if (!$socket) {
		print STDERR "Cannot listen at '$socket_file': $!\n";
		exit 1;
	}

	my $f;
	if (open($f, ">", $pid_file)) {
		print $f $$;
		close($f);
	} else {
		unlink $socket_file;
		print STDERR "Cannot write to PID file '$pid_file'.\n";
		exit 1;
	}

	my $self = $class->SUPER::createFromSocket($socket);
	$self->{parser} = new Bus::MessageParser();
	# A message log, used to sent the last 20 messages to the client
	# when that client switches to active mode.
	$self->{messages} = [];
	$self->{inputs} = [];
	$self->{socket_file} = $socket_file;
	$self->{pid_file} = $pid_file;

	$SIG{INT} = $SIG{TERM} = $SIG{QUIT} = sub {
		unlink $socket_file;
		unlink $pid_file;
		exit 2;
	};

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	unlink $self->{socket_file};
	unlink $self->{pid_file};
	$self->SUPER::DESTROY();
}

sub addMessage {
	my ($self, $type, $message, $domain) = @_;
	$self->broadcast("output", {
		type    => $type,
		message => $message,
		domain  => $domain
	});
	# Add to message log.
	push @{$self->{messages}}, [$type, $message, $domain];
	if (@{$self->{messages}} > 20) {
		shift @{$self->{messages}};
	}
}

# Broadcast a message to all clients.
sub broadcast {
	my $self = shift;
	my $clients = $self->clients();
	if (@{$clients} > 0) {
		my $messageID = shift;
		my $message = serialize($messageID, @_);
		foreach my $client (@{$clients}) {
			if ($client->{mode} == ACTIVE) {
				$client->send($message);
			}
		}
	}
}

# Check there is anything in the input queue.
sub hasInput {
	my ($self) = @_;
	return @{$self->{inputs}} > 0;
}

# Get the first input from the input queue.
sub getInput {
	my ($self) = @_;
	return shift @{$self->{inputs}};
}

# Put something in the input queue.
sub addInput {
	my ($self, $input) = @_;
	push @{$self->{inputs}}, $input;
}

sub setTitle {
	my ($self, $title) = @_;
	$self->{title} = $title;
	$self->broadcast("title changed", { title => $title });
}

sub onClientNew {
	my ($self, $client) = @_;
	$client->{mode} = PASSIVE;
}

sub onClientData {
	my ($self, $client, $data) = @_;
	$self->{parser}->add($data);

	my $ID;
	while (my $args = $self->{parser}->readNext(\$ID)) {
		if ($ID eq "input") {
			$self->addInput($args->{data});

		} elsif ($ID eq "set active") {
			$client->{mode} = ACTIVE;
			# Send the last few messages and the current title.
			foreach my $entry (@{$self->{messages}}) {
				my $message = serialize("output", {
					type    => $entry->[0],
					message => $entry->[1],
					domain  => $entry->[2]
				});
				$client->send($message);
			}
			$client->send(serialize("title changed", { title => $self->{title} })) if ($self->{title});

		} elsif ($ID eq "set passive") {
			$client->{mode} = PASSIVE;
		}
	}
}

1;