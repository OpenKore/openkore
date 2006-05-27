#!/usr/bin/env perl
use strict;
no strict 'refs';
use FindBin qw($RealBin);
use lib "$RealBin/..";

use Test::More qw(no_plan);
my @tests = qw(CallbackListTest ObjectListTest ActorListTest);
if ($^O eq 'MSWin32') {
	push @tests, qw(HttpReaderTest);
}

foreach my $module (@tests) {
	require "${module}.pm";
	my $start = "${module}::start";
	$start->();
}
