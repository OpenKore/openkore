#!/usr/bin/env perl
#########################################################################
#  OpenKore - Socket interface
#
#  Copyright (c) 2007 OpenKore development team
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
#########################################################################

# This program allows you to attach to a running OpenKore session that uses
# the Socket interface.

use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use IO::Socket::UNIX;

use ErrorHandler;
use Globals qw($interface $quit %consoleColors);
use Settings;
use FileParsers qw(parseSectionedFile);
use Interface::Console;
use Bus::Messages qw(serialize);
use Bus::MessageParser;

my $socket;
my $parser;
start();

sub start {
	if (!Settings::parseArguments()) {
		usage(1);
	}
	if (@ARGV != 1) {
		usage(1);
	}

	$socket = new IO::Socket::UNIX(
		Type => SOCK_STREAM,
		Peer => $ARGV[0]
	);
	if (!$socket) {
		print "Cannot connect to $ARGV[0]: $!\n";
		exit 1;
	}
	$socket->send(serialize("set active"));
	$socket->flush();

	$parser = new Bus::MessageParser();
	Settings::addControlFile("consolecolors.txt", loader => [\&parseSectionedFile, \%consoleColors]);
	Settings::loadAll();

	$interface = new Interface::Console();
	$interface->mainLoop();
}

sub usage {
	print "Usage: attach-to-console.pl <SOCKET FILE>\n";
	exit 1;
}

sub mainLoop {
	my $bits = '';
	vec($bits, fileno($socket), 1) = 1;
	if (select($bits, undef, undef, 0) > 0) {
		my ($data, $ID);
		$socket->recv($data, 1024 * 32);

		if (!defined($data) || length($data) == 0) {
			$quit = 1;
		} else {
			$parser->add($data);
			while (my $args = $parser->readNext(\$ID)) {
				if ($ID eq "output") {
					$interface->writeOutput($args->{type},
						$args->{message},
						$args->{domain});
				} elsif ($ID eq "title changed") {
					$interface->title($args->{title});
				}
			}
		}
	}

	if (my $input = $interface->getInput(0)) {
		if ($input eq "detach") {
			$quit = 1;
		} else {
			my $message = serialize("input", { data => $input });
			$socket->send($message);
			$socket->flush();
		}
	}
}
