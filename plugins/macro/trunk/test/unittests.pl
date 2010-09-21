#!/usr/bin/env perl
use strict;

use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/..";

use Test::More;

BEGIN {
	plan skip_all => "deps test failed" unless subtest "deps" => sub {
		use_ok('Misc');
		use_ok('Utils');
		use_ok('Macro::Data');
		use_ok('Macro::Script');
		use_ok('Macro::Parser', qw(parseMacroFile));
		use_ok('Macro::Automacro', qw(automacroCheck consoleCheckWrapper releaseAM));
		use_ok('Macro::Utilities', qw(callMacro));
		done_testing
	}
}

for (@ARGV || qw(
	VariableTest
	AutomacroTest
)) {
	subtest $_ => sub {
		require_ok($_) or BAIL_OUT("cannot load $_");
		no strict 'refs';
		&{"${_}::start"};
		done_testing
	}
}

done_testing
