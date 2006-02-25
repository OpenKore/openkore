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
use File::Spec;
use Fcntl ':flock';

use Globals qw(%config);
use IPC::Client;
use IPC::Server;

my $lockFile;
my $lockHandle;
my $server;
my %clients;

if ($^O eq 'MSWin32') {
	$lockFile = File::Spec->catfile(File::Spec->tmpdir(), "KoreServer");
} else {
	my $tmpdir = $ENV{TEMP};
	$tmpdir = "/tmp" if (!$tmpdir || ! -d $tmpdir);
	$lockFile = File::Spec->catfile($tmpdir, "KoreServer");
}
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
	$server = new IPC::Server($port);
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
	
	if (locked($lockFile)) {
		if ($feedback) {
			$feedback->send("A manager server is already running.", 0);
		} else {
			print STDERR "A manager server is already running.\n";
		}
		exit 4;
	}

	if (!open($lockHandle, "> $lockFile")) {
		# Unable to create lockfile :(
		if ($feedback) {
			$feedback->send("Unable to create a lock file. Please make sure " . File::Spec->tmpdir() . "is writable.", 0);
		} else {
			print STDERR "Unable to create a lock file. Please make sure " . File::Spec->tmpdir() . "is writable.\n";
		}
		exit 5;
	}

	flock($lockHandle, LOCK_EX);
	print $lockHandle $server->port;
	$lockHandle->flush;
	if ($^O eq 'MSWin32') {
		# We can't read from locked files on Win32, bah
		my $f;
		open($f, "> ${lockFile}.port");
		print $f $server->port;
		close $f;
	}

	$SIG{INT} = sub { cleanup(); exit 10; };
	$SIG{TERM} = sub { cleanup(); exit 10; };

	if ($feedback) {
		$feedback->send($server->port);
	} elsif ($port == 0) {
		printf "Server started at port %d\n", $server->port;
	}


	#### Main loop ####
	$server->addListener(\&onConnectionActivity);
	while (1) {
		foreach my $msg ($server->iterate) {
			process($msg);
		}
		sleep 0.01;
	}
}

# Process messages that the client sent to us.
# Some messages are special, and are for the manager server. Process those.
# Broadcast everything else throughout the network.
sub process {
	my $msg = shift;
	my $ID = $msg->{ID};
	my $from = $msg->{from};
	print "Message: $ID (from client $from)\n";

	# Special messages
	if ($ID eq "HELLO") {
		$clients{$from}{userAgent} = $msg->{args}{userAgent};
		$clients{$from}{wantGlobals} = exists($msg->{args}{wantGlobals}) ? $msg->{args}{wantGlobals} : 1;
		$clients{$from}{ready} = 1;

	} elsif ($ID eq "_LIST-CLIENTS") {
		my %args;
		my $i = 0;
		foreach ($server->clients) {
			if ($_ ne $from && $clients{$_}{ready}) {
				$args{"client$i"} = $_;
				$args{"clientUserAgent$i"} = $clients{$_}{userAgent};
				$i++;
			}
		}
		$args{count} = $i;
		$server->send($from, "_LIST-CLIENTS", \%args);

	} elsif (exists $msg->{args}{TO}) {
		# Send message only to one client
		print "Delivering message to client $msg->{args}{TO} only\n";
		$msg->{args}{FROM} = $msg->{from};
		$server->send($msg->{args}{TO}, $ID, $msg->{args});

	} else {
		# Broadcast the message to all clients except the sender,
		# or clients that aren't done with handshaking yet
		foreach my $clientID ($server->clients) {
			next if ($clientID eq $from || !$clients{$clientID}{ready} || !$clients{$clientID}{wantGlobals});
			$msg->{args}{FROM} = $msg->{from};
			$server->send($clientID, $ID, $msg->{args});
		}
	}
}

sub onConnectionActivity {
	my ($context, $clientID) = @_;

	if ($context eq "connect") {
		$clients{$clientID} = {};
		$server->send($clientID, "HELLO", { ID => $clientID });

	} elsif ($context eq "disconnect") {
		delete $clients{$clientID};
	}
}


sub locked {
	my $file = shift;
	my $f;
	return 0 unless (-f $file);

	open($f, "< $file");
	my $canLock = flock($f, LOCK_EX | LOCK_NB);
	close $f;
	return !$canLock;
}

sub cleanup {
	if ($lockHandle) {
		close $lockHandle;
		unlink $lockFile;
		unlink "${lockFile}.port";
	}
}

END {
	cleanup();
}

__start() unless defined $ENV{INTERPRETER};
