#!/usr/bin/env perl
#  Perl script launcher
#  Copyright (C) 2006 - written by VCL
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
use strict;
use bytes;

use constant MAX_SCRIPT_LENGTH => 255;
use constant DEFAULT_SCRIPT_VALUE => "script.pl";

use constant MAX_SEARCH_DIRS_LENGTH => 512;
use constant INVALID_SEARCH_DIRS_VALUE => "/INVALID_VALUE";

use constant DEFAULT_SEARCH_PATHS => ".;..";


if (! -f 'launcher.exe') {
	print STDERR "Cannot found launcher.exe - did you type 'make'?\n";
	exit 1;
}

my $script;
while ($script eq "") {
	print "Enter your Perl script's name:\n";
	$script = <STDIN>;
	$script =~ s/[\r\n]//g;
	if (length($script) > MAX_SCRIPT_LENGTH - 1) {
		$script = "";
		print STDERR "This name is too long, please enter a new one:\n";
	}
}

print "Enter a list of semicolon-seperated search paths to search for OpenKore launcher exe files. ";
print "Default search path: " . DEFAULT_SEARCH_PATHS . "\n";
my $searchPaths = <STDIN>;
if ($searchPaths eq "\n") {
	$searchPaths = DEFAULT_SEARCH_PATHS;
} else {
	$searchPaths =~ s/[\r\n]//g;
	if (length($script) > MAX_SEARCH_DIRS_LENGTH) {
		print STDERR "This search path is too long.";
		exit 1;
	}
}

if (!open(F, "<", "launcher.exe")) {
	print STDERR "Cannot open launcher.exe for reading.\n";
	exit 1;
}
binmode F;
my $data;
{
	local($/);
	$data = <F>;
}
close F;

my $i = index($data, DEFAULT_SCRIPT_VALUE);
my $replacement = pack("a" . (MAX_SCRIPT_LENGTH - 1), $script) . chr(0);
substr($data, $i, MAX_SCRIPT_LENGTH, $replacement);

$i = index($data, INVALID_SEARCH_DIRS_VALUE);
$replacement = pack("a" . (MAX_SEARCH_DIRS_LENGTH - 1), $searchPaths) . chr(0);
substr($data, $i, MAX_SEARCH_DIRS_LENGTH, $replacement);

if (!open(F, ">", "output.exe")) {
	print STDERR "Cannot write to output.exe\n";
	exit 1;
}
binmode F;
print F $data;
close F;
print "output.exe generated.\n";
print "Press Enter to exit.\n";
<STDIN>;
