#!/usr/bin/env perl
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";

use Globals qw(%config $interface);
use Interface::Console;
use IPC::Server;
use Utils qw(parseArgs);

$config{verbose} = 1;
$config{debug} = 1;
$interface = new Interface::Console;
my $ipc = new IPC::Server;
printf "Server started at port %s\n", $ipc->port;

while (1) {
	my @messages = $ipc->iterate;
	my $input = $interface->getInput(0.02);
	my @args;
	@args = parseArgs($input) if defined $input;

	if ($args[0] eq "q" || $args[0] eq "quit") {
		last;

	} elsif ($args[0] eq "b") {
		if (@args == 4) {
			my %hash;
			$hash{$args[2]} = $args[3];
			$ipc->broadcast(undef, $args[1], \%hash);
			print "Broadcasted message $args[1]\n";
		} else {
			print "Usage: b (ID) (KEY) (VALUE)\n";
			print "Broadcast a message.\n";
		}

	} elsif (@args) {
		print "Unrecognized command $args[0]\n";
		print "Available commands: b, quit\n";
	}

	foreach my $msg (@messages) {
		print "Incoming message from client $msg->{clientID}: $msg->{ID}\n";
		foreach (keys %{$msg->{args}}) {
			print "$_ = $msg->{args}{$_}\n";
		}
		print "--------\n";
	}
}
