#!/usr/bin/env perl
# Program for testing Base::Server.
use strict;
use FindBin qw($RealBin);
use lib $RealBin;
use lib "$RealBin/deps";

my $server = new Server($ARGV[0] || 2894);
while (1) {
	$server->iterate(-1);
}

package Server;

use Base::Server;
use base qw(Base::Server);

sub onClientNew {
	my ($self, $client, $index) = @_;
	print "Client $index connected.\n";
}

sub onClientExit {
	my ($self, $client, $index) = @_;
	print "Client $index disconnected.\n";
}

sub onClientData {
	my ($self, $client, $data, $index) = @_;
	print "Client $index sent the following data: $data\n";
}