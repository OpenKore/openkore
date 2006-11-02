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

use Globals qw(%consoleColors);
use Interface;
use base qw(Interface);
use Utils qw(timeOut);
use I18N qw(UTF8ToString);
use Utils::Unix;


sub new {
	my $class = shift;
	my %self;

	if (POSIX::ttyname(0) && POSIX::tcgetpgrp(0) == POSIX::getpgrp()) {
		# Only initialize readline if we have a controlling
		# terminal to read input from.
		$self{readline} = 1;
		Utils::Unix::ConsoleUI::start();
	}

	return bless \%self, $class;
}

sub DESTROY {
	my $self = shift;
	Utils::Unix::ConsoleUI::stop() if ($self->{readline});
	print Utils::Unix::getColor('default');
	STDOUT->flush;
}

sub getInput {
	my ($self, $timeout) = @_;
	my $line;

	return if (!$self->{readline});

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
	$self->writeOutput("error", "$message\n");
	Utils::Unix::ConsoleUI::waitUntilPrinted() if ($self->{readline});
}

sub writeOutput {
	my ($self, $type, $message, $domain) = @_;
	my $code;

	# Hide prompt and input buffer
	$code = Utils::Unix::getColorForMessage(\%consoleColors, $type, $domain);

	if (!$self->{readline}) {
		use bytes;
		print $code . $message . Utils::Unix::getColor('reset');
		STDOUT->flush;
	} else {
		while (length($message) > 0) {
			$message =~ /^(.*?)(\n|$)(.*)/s;
			my $line = $1 . $2;
			$message = $3;
			{
				use bytes;
				Utils::Unix::ConsoleUI::print($code . $line);
			}
		}
	}
}

sub title {
	my ($self, $title) = @_;

	if ($title) {
		$self->{title} = $title;
		if ($ENV{TERM} eq 'xterm' || $ENV{TERM} eq 'screen') {
			print "\e]2;$title\a";
			STDOUT->flush;
		}
	} else {
		return $self->{title};
	}
}

1;
