#!/usr/bin/env perl
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";

use Globals qw($interface);
use Bus::SimpleClient;
use Interface::Console;
use Utils qw(parseArgs);

my $port;
if ($ARGV[0]) {
	$port = $ARGV[0];
} else {
	print STDERR "No server port specified.\n";
	exit 1;
}


print "Connecting to server at port $port\n";
$interface = new Interface::Console;
my $ipc;

eval {
	$ipc = new Bus::SimpleClient('localhost', $port);
	while (1) {
		my $ID;
		while (my $args = $ipc->readNext(\$ID)) {
			processMessage($ID, $args);
		}
	
		my $input = $interface->getInput(0.02);
		if ($input) {
			processInput(parseArgs($input));
		}
	}
};
if ($@) {
	print STDERR "Error: $@\n";
	exit 1;
}

sub processMessage {
	my ($MID, $args) = @_;

	if ($MID eq "LIST_CLIENTS") {
		print "------- Client list --------\n";
		for (my $i = 0; $i < $args->{count}; $i++) {
			printf "%s: %s\n", $args->{"client$i"}, $args->{"clientUserAgent$i"};
		}
		print "----------------------------\n";

	} else {
		print "Message from server: $MID\n";
		if (ref($args) eq 'HASH') {
			foreach my $key (keys %{$args}) {
				printf "%-14s = %s\n", $key, $args->{$key};
			}
		} else {
			foreach my $entry (@{$args}) {
				print "$entry\n";
			}
		}
		print "-----------------------\n";
	}
}

sub processInput {
	if ($_[0] eq "q" || $_[0] eq "quit") {
		exit;

	} elsif ($_[0] eq "s") {
		if (@_ == 4) {
			print "Sending $_[1]: $_[2] = $_[3]\n";
			$ipc->send($_[1], { $_[2] => $_[3] });
		} else {
			print "Usage: s (ID) (KEY) (VALUE)\n";
			print "Send a message to the server.\n";
		}

	} elsif ($_[0] eq "lc") {
		$ipc->send("LIST_CLIENTS");

	} else {
		print "Unrecognized command $_[0]\n";
		print "Available commands: s, lc, quit\n";
	}
}