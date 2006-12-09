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
use lib "$RealBin/../deps";
use Time::HiRes qw(sleep);
use Getopt::Long;

use Globals qw(%config);
use IPC::Manager::Core;
use IPC::Manager::Server;


my $server;

$config{debug} = 1;


sub usage {
	print "Usage: manager.pl [OPTIONS]\n\n";
	print "Options:\n";
	print " --port=PORT      Start the manager at the specified port. Leave empty to use\n" .
	      "                  the first available port.\n";
	print " --feedback=PORT  Send startup information to the TCP socket localhost:PORT.\n" .
	      "                  Sends the port on which the manager is running, or an error\n" .
	      "                  message if startup failed.\n";
	print " --bind=IP        Bind the server at the specified IP.\n";
	print " --quiet          Don't print status messages.\n";
	print " --help           Display this help message.\n";
}

sub __start {
	my %options;
	my $feedback;

	$options{port} = 0;
	if (!GetOptions(
		"port=i"     => \$options{port},
		"quiet"      => \$options{quiet},
		"feedback=i" => \$options{feedback},
		"bind=s"     => \$options{bind},
		"help"       => \$options{help}
	)) {
		usage();
		exit 1;
	} elsif ($options{help}) {
		usage();
		exit 0;
	}

	if (defined $options{feedback}) {
		$feedback = new IO::Socket::INET("localhost:$options{feedback}");
		if (!$feedback) {
			my $error = $@;
			$error =~ s/^IO::Socket::INET: //;
			print STDERR "Unable to connect to feedback server at port $options{feedback}: $error\n";
			exit 2;
		}
	}


	#### Start server ####
	$server = new IPC::Manager::Server($options{port}, $options{bind});
	if (!$server) {
		# Failure
		if ($feedback) {
			$feedback->send($@, 0);
			undef $feedback;
		} else {
			print STDERR "Unable to start a manager server at port $options{port}.\n" . 
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
	IPC::Manager::Core::setPort($server->getPort());

	$SIG{INT} = sub { IPC::Manager::Core::stop(); exit 10; };
	$SIG{TERM} = sub { IPC::Manager::Core::stop(); exit 10; };

	if ($feedback) {
		$feedback->send($server->getPort());
	} elsif ($options{port} == 0) {
		printf "Server started at port %d\n", $server->getPort();
	}

	if ($options{quiet}) {
		close(STDOUT);
		close(STDERR);
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
