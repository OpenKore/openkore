#!/usr/bin/env perl
BEGIN {
	chdir "..";
}
use strict;
use Interface;
use Interface::Console;
use IPC::Server;
use Globals;

$config{verbose} = 1;
$config{debug} = 1;
$interface = new Interface::Console;
$ipc = new IPC::Server;

while (1) {
	my @messages = $ipc->iterate();

	my $input = $interface->getInput(0.02);
	if ($input eq "q" || $input eq "quit") {
		last;

	} elsif ($input eq "list") {
		my @servers = IPC::Server::list();
		print "Active servers on ports: @servers\n";

	} elsif ($input =~ /^b (.+) (.+) (.+)/) {
		my %hash;
		$hash{$2} = $3;
		$ipc->broadcast($1, \%hash);
		print "Broadcasted message $1\n";
	}

	foreach (@messages) {
		my ($ID, $hash) = @{$_};
		print "Incoming message from client: $ID\n";
		foreach (keys %{$hash}) {
			print "$_ = $$hash{$_}\n";
		}
		print "--------\n";
	}
}
