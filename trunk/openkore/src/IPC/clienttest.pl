#!/usr/bin/env perl
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";

use Globals qw($interface);
use IPC::Client;
use Interface::Console;
use Utils qw(parseArgs);

my $port;
if ($ARGV[0]) {
	$port = $ARGV[0];
} else {
	print STDERR "No server specified\n";
	exit 1;
}


print "Connecting to server at port $port\n";
my $ipc = new IPC::Client('localhost', $port);
$interface = new Interface::Console;

while (1) {
	my @messages;
	my $ret = $ipc->recv(\@messages);

	if ($ret == -1) {
		print "Server died.\n";
		exit;

	} elsif ($ret) {
		foreach my $msg (@messages) {
			process($msg);
		}
	}

	my $input = $interface->getInput(0.02);
	my @args;
	@args = parseArgs($input) if (defined $input);

	if ($args[0] eq "q" || $args[0] eq "quit") {
		last;

	} elsif ($args[0] eq "s") {
		if (@args == 4) {
			print "Sending $args[1]: $args[2] = $args[3]\n";
			$ipc->send($args[1], $args[2] => $args[3]);
		} else {
			print "Usage: s (ID) (KEY) (VALUE)\n";
			print "Send a message to the server\n";
		}

	} elsif ($args[0] eq "lc") {
		$ipc->send("_LIST-CLIENTS");

	} elsif (@args) {
		print "Unrecognized command $args[0]\n";
		print "Available commands: s, lc, quit\n";
	}
}

sub process {
	my $msg = shift;
	if ($msg->{ID} eq "_LIST-CLIENTS") {
		print "------- Client list --------\n";
		for (my $i = 0; $i < $msg->{args}{count}; $i++) {
			printf "%s: %s\n", $msg->{args}{"client$i"}, $msg->{args}{"clientUserAgent$i"};
		}
		print "----------------------------\n";

	} else {
		print "Incoming message from server: " . $msg->{ID} . "\n";
			foreach (keys %{$msg->{args}}) {
			print "$_ = " . $msg->{args}{$_} . "\n";
		}
		print "--------\n";
	}
}
