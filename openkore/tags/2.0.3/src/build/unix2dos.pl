#!/usr/bin/env perl

use strict;
use warnings;

foreach my $f (@ARGV) {
	local($/);
	if (!open(F, "<", $f)) {
		print STDERR "Can't open $f for reading\n";
		exit 1;
	}

	print "Converting $f...\n";
	binmode F;
	my $data = <F>;
	close(F);

	if (!open(F, ">", $f)) {
		print STDERR "Can't open $f for writing\n";
		exit 1;
	}
	binmode F;
	$data =~ s/\r\n/\n/sg;
	$data =~ s/\n/\r\n/sg;
	print F $data;
	close(F);
}
