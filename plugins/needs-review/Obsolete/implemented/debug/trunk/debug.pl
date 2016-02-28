#!/usr/bin/env perl
# Debugging plugin.
# When OpenKore is sent the SIGQUIT signal, this plugin will print a
# stack trace and will initiate an evaluation console, in which you
# can evaluate any Perl expression.

package DebuggerPlugin;
use strict;
use Carp;
use IO::Socket;

sub out {
	if (defined $::interface) {
		$::interface->writeOutput('message', $_[0]);
	} else {
		print $_[0];
	}
}

sub get {
	if (defined $::interface) {
		return $::interface->getInput(-1);
	} else {
		print "eval> ";
		STDOUT->flush;
		my $ret = <STDIN>;
		$ret =~ s/\n//;
		return $ret;
	}
}

sub debug {
	out Carp::longmess("") . "\n";
	print "Evaluation console initialized (type 'q' to quit).\n";
	while (1) {
		my $input = get();
		if ($input eq "q" || $input eq "quit") {
			last;
		} else {
			undef $@;
			my $ret = eval $input;
			if ($@ ne '') {
				out "Error: $@\n";
			} else {
				out "$ret\n";
			}
		}
	}
	exit;
}

$SIG{QUIT} = \&debug;

1;
