#########################################################################
#  OpenKore - Interface::Console::Unix
#  Console interface for Unix/Linux.
#
#  Copyright (c) 2005 OpenKore development team 
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

package Interface::Console::Unix;

use strict;
use IO::Socket;
use Time::HiRes qw(time sleep);
use POSIX;
use bytes;
no encoding 'utf8';

use Globals qw(%consoleColors);
use Interface;
use base 'Interface::Console::Simple';
use Utils qw(timeOut);
use I18N qw(UTF8ToString);
use Utils::Unix;

sub new {
	my $class = shift;
	
	# Only initialize readline if we have a controlling
	# terminal to read input from.
	return new Interface::Console::Simple(@_) unless POSIX::ttyname(0) && POSIX::tcgetpgrp(0) == POSIX::getpgrp;
	
	Utils::Unix::ConsoleUI::start();
	return bless {}, $class;
}

sub DESTROY {
	Utils::Unix::ConsoleUI::stop;
}

sub getInput {
	my ($self, $timeout) = @_;
	my $line;

	if ($timeout < 0) {
		do {
			$line = Utils::Unix::ConsoleUI::getInput();
			sleep 0.01;
		} while (!defined $line);

	} elsif ($timeout == 0) {
		$line = Utils::Unix::ConsoleUI::getInput();

	} else {
		my $time = time;
		do {
			$line = Utils::Unix::ConsoleUI::getInput();
			sleep 0.01;
		} while (!defined($line) && !timeOut($time, $timeout));
	}

	$line = undef if (defined($line) && $line eq '');
	$line = I18N::UTF8ToString($line) if (defined($line));
	return $line;
}

sub errorDialog {
	# UNIX consoles don't close when the program exits,
	# so don't block execution
	my ($self, $message) = @_;
	$self->writeOutput("error", $message . "\n");
	Utils::Unix::ConsoleUI::waitUntilPrinted;
}

sub writeOutput {
	my ($self, $type, $message, $domain) = @_;
	
	# Hide prompt and input buffer
	my ($code, $reset) = (
		Utils::Unix::getColorForMessage(\%consoleColors, $type, $domain),
		Utils::Unix::getColor('reset'),
	);
	$message =~ s/\n/$reset\n$code/sg;
	$message = $code.$message.$reset;
	
	Utils::Unix::ConsoleUI::print($_) for split /(?<=\n)/, $message;
}

1;
