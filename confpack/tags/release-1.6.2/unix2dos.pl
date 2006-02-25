#!/usr/bin/env perl

use strict;
use warnings;

foreach my $f (@ARGV) {
	if (!open(F, "< $f")) {
		print STDERR "Can't open $f for reading\n";
		next;
	}

	print "Converting $f...\n";
	my @lines = <F>;
	close(F);

	if (!open(F, "> $f")) {
		print STDERR "Can't open $f for writing\n";
		next;
	}
	foreach (@lines) {
		s/[\r\n]//g;
	}
	print F join("\r\n", @lines) . "\r\n";
	close(F);
}
