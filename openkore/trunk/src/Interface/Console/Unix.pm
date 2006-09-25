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
#
#
#  $Revision$
#  $Id$
#
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

our (%fgcolors, %bgcolors);


sub new {
	my $class = shift;
	my %self;

	if (POSIX::ttyname(0) && POSIX::tcgetpgrp(0) == POSIX::getpgrp()) {
		# Only initialize readline if we have a controlling
		# terminal to read input from.
		$self{readline} = 1;
		Utils::Unix::ConsoleUI::start();
	}

	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	my $self = shift;
	Utils::Unix::ConsoleUI::stop() if ($self->{readline});
	print getColor('default');
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
	$code = getColorForMessage($type, $domain);

	if (!$self->{readline}) {
		use bytes;
		print $code . $message . getColor('reset');
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

sub beep {
	print STDOUT "\a";
	STDOUT->flush;
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


#######################


# Print color code for the given message type and domain
sub getColorForMessage {
	return if (!$consoleColors{''}{useColors});
	my ($type, $domain) = @_;
	my $color = $consoleColors{$type}{$domain};
	$color = $consoleColors{$type}{default} if (!defined $color);
	$color = 'default' if (!defined $color);
	return getColor($color);
}

# Get the color code for the given color name
sub getColor {
	my $color = shift;
	my $code = '';

	$color =~ s/\/(.*)//;
	my $bgcolor = $1;

	$code = $fgcolors{$color} if (defined($color) && defined($fgcolors{$color}));
	$code .= $bgcolors{$bgcolor} if (defined($bgcolor) && defined($bgcolors{$bgcolor}));
	return $code;
}


{
	use bytes;
	%fgcolors = (
		'reset'		=> "\e[0m",
		'default'	=> "\e[0m",

		'black'		=> "\e[0;30m",
		'darkgray'	=> "\e[1;30m",
		'darkgrey'	=> "\e[1;30m",

		'darkred'	=> "\e[0;31m",
		'red'		=> "\e[1;31m",

		'darkgreen'	=> "\e[0;32m",
		'green'		=> "\e[1;32m",

		'brown'		=> "\e[0;33m",
		'yellow'	=> "\e[1;33m",

		'darkblue'	=> "\e[0;34m",
		'blue'		=> "\e[1;34m",

		'darkmagenta'	=> "\e[0;35m",
		'magenta'	=> "\e[1;35m",

		'darkcyan'	=> "\e[0;36m",
		'cyan'		=> "\e[1;36m",

		'gray'		=> "\e[0;37m",
		'grey'		=> "\e[0;37m",
		'white'		=> "\e[1;37m",
	);

	%bgcolors = (
		'default'	=> "\e[22;40m",

		'black'		=> "\e[22;40m",
		'darkgray'	=> "\e[5;40m",
		'darkgrey'	=> "\e[5;40m",

		'darkred'	=> "\e[22;41m",
		'red'		=> "\e[5;41m",

		'darkgreen'	=> "\e[22;42m",
		'green'		=> "\e[5;42m",

		'brown'		=> "\e[22;43m",
		'yellow'	=> "\e[5;43m",

		'darkblue'	=> "\e[22;44m",
		'blue'		=> "\e[5;44m",

		'darkmagenta'	=> "\e[22;45m",
		'magenta'	=> "\e[5;45m",

		'darkcyan'	=> "\e[22;46m",
		'cyan'		=> "\e[5;46m",

		'gray'		=> "\e[22;47m",
		'grey'		=> "\e[22;47m",
		'white'		=> "\e[5;47m",
	);
}


1;
