#!/usr/bin/env perl
#################################################
# IPC manager server
#
# This server keeps track of all clients. A client can query
# a list of all other clients, or broadcast a message.
#################################################

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use Time::HiRes qw(sleep);

use Globals qw(%config);
use IPC::Manager::Core;
use IPC::Manager::Server;


my $server;
my %clients;

$config{debug} = 1;


sub __start {
	my $feedback;
	my $port = 0;

	if ($ARGV[0] eq "--quiet") {
		shift @ARGV;
		close(STDOUT);
		close(STDERR);
	}

	# There are two ways to launch this manager server.
	if ($ARGV[0] =~ /^--feedback=(\d+)$/) {
		# 1. Automatically launched by IPC.pm
		# We must tell IPC.pm the port of our server.
		$feedback = new IO::Socket::INET("localhost:$1");
		if (!$feedback) {
			print STDERR "Unable to connect to feedback server at port $1\n";
			exit 2;
		}

	} else {
		# 2. Manually launched
		if (!$ARGV[0] || $ARGV[0] !~ /^\d+$/) {
			print STDERR "Usage: manager.pl <PORT>\n" .
				"Start a manager server at the specified port.\n";
			exit 1;
		}
		$port = $ARGV[0];
	}


	#### Start server ####
	$server = new IPC::Manager::Server($port);
	if (!$server) {
		# Failure
		if ($feedback) {
			$feedback->send($@, 0);
			undef $feedback;
		} else {
			print STDERR "Unable to start a manager server at port $port.\n" . 
				"$@\n";
		}
		exit 3;
	}

	#### Server started ####
	# Now try to create a lockfile

	my $error;
	if (!IPC::Manager::Core::start(\$error)) {
		if ($feedback) {
			$feedback->send($error, 0);
		} else {
			print STDERR "$error\n";
		}
		exit 4;
	}
	IPC::Manager::Core::setPort($server->port);

	$SIG{INT} = sub { IPC::Manager::Core::stop(); exit 10; };
	$SIG{TERM} = sub { IPC::Manager::Core::stop(); exit 10; };

	if ($feedback) {
		$feedback->send($server->port);
	} elsif ($port == 0) {
		printf "Server started at port %d\n", $server->port;
	}


	#### Main loop ####
	while (1) {
		$server->iterate;
		sleep 0.01;
	}
}

END {
	IPC::Manager::Core::stop();
}

__start() unless defined $ENV{INTERPRETER};
