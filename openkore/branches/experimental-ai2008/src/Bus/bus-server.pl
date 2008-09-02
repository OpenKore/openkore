#!/usr/bin/env perl
#########################################################################
#  OpenKore - Bus System
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
# OpenKore Bus Server
#
# This server keeps track of all clients. A client can query
# a list of all other clients, or broadcast a message.
#########################################################################

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use Getopt::Long;

use Utils::Daemon;
use Utils::Exceptions;

my $server;
my %options;


sub __start {
	#### Parse arguments. ####
	$options{port} = 0;
	if (!GetOptions(
		"port=i"     => \$options{port},
		"quiet"      => \$options{quiet},
		"bind=s"     => \$options{bind},
		"help"       => \$options{help}
	)) {
		usage(1);
	} elsif ($options{help}) {
		usage(0);
	}


	#### Start the server, if not already running. ####
	my $daemon = new Utils::Daemon("OpenKore-Bus");
	eval {
		$daemon->init(\&startServer);
	};
	if (my $e = caught('Utils::Daemon::AlreadyRunning')) {
		my $address = $e->info->{host} . ":" . $e->info->{port};
		print STDERR "The bus server is already running at port $address\n";
		exit 2;
	} elsif ($@) {
		print "Cannot start bus server: $@\n";
		exit 3;
	}

	if (!$options{quiet}) {
		printf "Bus server started at port %d\n", $server->getPort();
	}
	while (1) {
		$server->iterate(-1);
	}
}

sub startServer {
	require Bus::Server::MainServer;
	$server = new Bus::Server::MainServer($options{port}, $options{bind},
			quiet => $options{quiet});
	return { host => $server->getHost(), port => $server->getPort() };
}

sub usage {
	print "Usage: bus-server.pl [OPTIONS]\n\n";
	print "Options:\n";
	print " --port=PORT      Start the server at the specified port. Leave empty to use\n" .
	      "                  the first available port.\n";
	print " --bind=IP        Bind the server at the specified IP.\n";
	print " --quiet          Don't print status messages.\n";
	print " --help           Display this help message.\n";
	exit $_[0];
}

__start() unless defined $ENV{INTERPRETER};
