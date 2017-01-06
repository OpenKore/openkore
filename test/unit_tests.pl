#!/usr/bin/env perl

use strict;

use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/..";

# Try to find OpenKore.
our $openkore_dir;
BEGIN {
	foreach ( $ENV{OPENKORE_DIR} || '', "$RealBin/../..", "$RealBin/../../.." ) {
		next if !-d "$_/src/deps";
		$openkore_dir = $_;
		last;
	}
	die "Unable to find OpenKore directory. Please set OPENKORE_DIR. Aborting.\n" if !$openkore_dir;
};
BEGIN {
	use lib "$openkore_dir/src";
	use lib "$openkore_dir/src/deps";
};

use List::MoreUtils;
use Test::More qw(no_plan);

# OpenKore has some dependency loading order issues. Pre-load Misc to work around them.
use Misc;

my @tests = qw(
    Validator::NumericComparisonTest
	Validator::ListMemberCheckTest
);
@tests = @ARGV if @ARGV;

# Initialize the globals.
use eventMacro::Core;
use eventMacro::Data;
$eventMacro = eventMacro::Core->new( "$RealBin/empty.txt" );

foreach my $module ( @tests ) {
	$module =~ s/\.pm$//;
	my $file = $module;
	$file =~ s{::}{/}g;
	eval { require "$file.pm"; };
	if ( $@ ) {
		$@ =~ s/\(\@INC contains: .*?\) //s;
		print STDERR "Cannot load unit test $module:\n$@\n";
		exit 1;
	}
	$module->start;
}

print "Finished !\n";

system("pause");
