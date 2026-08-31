#!/usr/bin/env perl

use strict;
use warnings;

use FindBin qw($RealBin);
use lib $RealBin;
use lib "$RealBin/..";

our $openkore_dir;
BEGIN {
	for my $candidate ($ENV{OPENKORE_DIR} || '', "$RealBin/../..", "$RealBin/../../..") {
		next unless -d "$candidate/src/deps";
		$openkore_dir = $candidate;
		last;
	}
	die "Unable to find OpenKore directory. Please set OPENKORE_DIR. Aborting.\n"
		unless $openkore_dir;
}
BEGIN {
	use lib "$openkore_dir/src";
	use lib "$openkore_dir/src/deps";
}

use Test::More qw(no_plan);

my @tests = qw(LastroAirshipTest);
@tests = @ARGV if @ARGV;

for my $module (@tests) {
	$module =~ s/\.pm$//;
	my $file = $module;
	$file =~ s{::}{/}g;
	eval { require "$file.pm"; 1 } or do {
		my $error = $@;
		$error =~ s/\(\@INC contains: .*?\) //s;
		print STDERR "Cannot load unit test $module:\n$error\n";
		exit 1;
	};
	print "#### Starting $module test ####\n";
	$module->start;
}
