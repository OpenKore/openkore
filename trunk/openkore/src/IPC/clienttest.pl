#!/usr/bin/env perl
BEGIN {
	chdir "..";
}
use strict;
use IPC::Server;
use IPC::Client;
use Interface;
use Interface::Console;

my $port;
if ($ARGV[0]) {
	$port = $ARGV[0];
} else {
	my @servers = IPC::Server::list();
	$port = $servers[0];
	die "No server" unless $port;
}


print "Server at $port\n";
my $ipc = new IPC::Client('localhost', $port);
$interface = new Interface::Console;

while (1) {
	my @packets;
	my $ret = $ipc->recvData(\@packets);

	if ($ret == -1) {
		print "Server died.\n";
		exit;

	} elsif ($ret) {
		foreach my $packet (@packets) {
			print "Incoming message from server: " . $packet->{ID} . "\n";
			foreach (keys %{$packet->{params}}) {
				print "$_ = " . $packet->{params}{$_} . "\n";
			}
			print "--------\n";
		}
	}

	my $input = $interface->getInput(0.02);
	if ($input eq "q" || $input eq "quit") {
		last;
	}
}
