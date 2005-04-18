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
use ReadLine;

use Interface;
use Utils qw(timeOut);
use base qw(Interface);


sub new {
	my $class = shift;
	my %self;

	ReadLine::init();

	bless \%self, $class;
	return \%self;
}

sub DESTROY {
	ReadLine::stop();
}

sub getInput {
	my ($self, $timeout) = @_;
	my $line;

	if ($timeout < 0) {
		do {
			$line = ReadLine::pop();
			sleep 0.01;
		} while (!defined $line);

	} elsif ($timeout == 0) {
		$line = ReadLine::pop();

	} else {
		my $time = time;
		do {
			$line = ReadLine::pop();
			sleep 0.01;
		} while (!defined($line) && !timeOut($time, $timeout));
	}

	$line = undef if (defined($line) && $line eq '');
	return $line;
}

sub writeOutput {
	my ($self, $type, $message, $domain) = @_;
	my $tail;

	ReadLine::hide();

	if ($message =~ /\n$/s) {
		print $message;
		if ($self->{last_message_had_no_newline}) {
			ReadLine::setPrompt("");
			$self->{last_message_had_no_newline} = 0;
		}

	} else {
		my @lines = split /\n/, $message;
		my $lastLine = $lines[@lines - 1];
		for (my $i = 0; $i < @lines - 1; $i++) {
			print $lines[$i];
		}
		ReadLine::setPrompt($lastLine);
		$self->{last_message_had_no_newline} = 1;
	}

	ReadLine::show();
}

1;
