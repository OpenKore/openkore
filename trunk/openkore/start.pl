#!/usr/bin/env perl
use strict;
use lib 'src';

if (0) {
	# Force PerlApp to include the following modules
	require base;
	require bytes;
	require warnings;
	require Exporter;
	require Carp;
	require FindBin;
	require Math::Trig;
	require Text::Wrap;
	require Time::HiRes;
	require IO::Socket;
	require Getopt::Long;
	require Digest::MD5;
	require Win32::Console;
}

if ($0 =~ /\.exe$/i) {
	$ENV{OPENKORE_INTERPRETER} = $0;
}

my $file = 'openkore.pl';
if ($ARGV[0] eq '!') {
	shift;
	$file = shift;
}

do $file;
die $@ if ($@);
