#!/usr/bin/env perl
# Win32 Perl script launcher
# This file is meant to be compiled by PerlApp. It acts like a mini-Perl interpreter.
#
# Your script's initialization and main loop code should be placed in a function
# called __start() in the main package. That function will be called by this
# launcher. The reason for this is that otherwise, the perl interpreter will be
# in "eval" all the time while running your script. It will break __DIE__ signal
# handlers that check for the value of $^S.
#
# If your script is run by this launcher, the environment variable INTERPRETER is
# set. Your script should call __start() manually if this environment variable is not
# set.
#
# example script:
# our $quit = 0;
#
# sub __start {
#	print "Hello world initialized.\n";
#	while (!$quit) {
#		...
#	}
# }
#
# __start() unless defined $ENV{INTERPRETER};
package StarterScript;

BEGIN {
       if ($ENV{BUILDING_WX} == 1 && $^O eq 'MSWin32') {
               require Wx::Perl::Packager;
       } elsif ($ENV{BUILDING_WX} == 2 && $^O eq 'MSWin32') {
               require Tk;
       } elsif ($ENV{BUILDING_WX} == 3 && $^O eq 'MSWin32') {
               require Win32::GUI;
       }
}

use strict;
use Config;

if ($^O ne 'MSWin32') {
	# We are not on Windows, so tell the user about it
	print "\nThis file is meant to be compiled by PerlApp.\n";
	print "To run kore, execute openkore.pl instead.\n\n";
	exit 1;
}


# PerlApp 6's @INC doesn't contain '.', so add it
my $hasCurrentDir;
foreach (@INC) {
	if ($_ eq ".") {
		$hasCurrentDir = 1;
		last;
	}
}
push @INC, "." if (!$hasCurrentDir);

if (0) {
	# Force PerlApp to include the following modules
	use FindBin;
	require base;
	require bytes;
	require lib;
	require integer;
	require warnings;
	require UNIVERSAL;
	require Exporter;
	require Fcntl;
	require Carp;
	require Math::Trig;
	require Text::Wrap;
	require Text::ParseWords;
	require Time::HiRes;
	require IO::Socket::INET;
	require Getopt::Long;
	require Digest::MD5;
	require SelfLoader;
	require Data::Dumper;
	require Win32;
	require Win32::Console;
	require Win32::Process;
	require XSTools;
	require Encode;
	require Encode::KR;
	require Encode::TW;
	require Encode::JP;
	require Encode::CN;
	require encoding;
	require Storable;
	require Compress::Zlib;
	# new Perl 5.12 and more
	require "unicore/lib/Perl/SpacePer.pl";
	require "unicore/lib/Perl/Word.pl";
	require "unicore/lib/Nt/De.pl";
	require "unicore/lib/Gc/Cc.pl";
	require "unicore/lib/Blk/ASCII.pl";
	# Old Perl 5.10 and less
	# require "unicore/lib/gc_sc/SpacePer.pl";
	# require "unicore/lib/gc_sc/Word.pl";
	# require "unicore/lib/gc_sc/Digit.pl";
	# require "unicore/lib/gc_sc/Cntrl.pl";
	# require "unicore/lib/gc_sc/ASCII.pl";
	require HTML::Entities;
}


if ($PerlApp::TOOL eq "PerlApp") {
	$ENV{INTERPRETER} = PerlApp::exe();
	if (PerlApp::exe() =~ /wxstart\.exe$/i) {
		$ENV{OPENKORE_DEFAULT_INTERFACE} = 'Wx';
	}

	if (PerlApp::exe() =~ /vxstart\.exe$/i) {
		$ENV{OPENKORE_DEFAULT_INTERFACE} = 'Vx';
	}

	if (PerlApp::exe() =~ /winguistart\.exe$/i) {
		$ENV{OPENKORE_DEFAULT_INTERFACE} = 'Win32';
	}

	if (PerlApp::exe() =~ /tkstart\.exe$/i) {
		$ENV{OPENKORE_DEFAULT_INTERFACE} = 'Tk';
	}


} else {
	print "Do not run start.pl directly! If you're using Perl then run openkore.pl instead!\n";
	<STDIN>;
	exit 1;
}

my $file = "openkore.pl";
if ($ARGV[0] eq '!') {
	shift;
	while (@ARGV) {
		if ($ARGV[0] =~ /^-I(.*)/) {
			unshift @INC, $1;
		} else {
			last;
		}
		shift;
	}
	$file = shift;
}

$0 = $file;
FindBin::again();

{
	package main;
	do $file;
}
if ($@) {
	print $@;
	print "\nPress ENTER to exit.\n";
	<STDIN>;
	exit 1;
} elsif (defined $ENV{INTERPRETER}) {
	main::__start() if defined(&main::__start);
}
