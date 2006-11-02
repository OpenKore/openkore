#########################################################################
#  OpenKore - User interface system
#
#  Copyright (c) 2006 OpenKore development team
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
##
# MODULE DESCRIPTION: Simple console interface which polls stdin for input.

package Interface::Console::Simple;

use strict;
use warnings;
no warnings 'redefine';
use Time::HiRes qw(usleep);
use IO::Socket;
use encoding 'utf8';

use Globals qw(%consoleColors);
use Interface;
use base qw(Interface);
use Utils qw(dataWaiting);
use I18N qw(UTF8ToString);
use Utils::Unix;

sub new {
	my $class = shift;
	my %self;

	return bless \%self, $class;
}

sub getInput {
	my ($self, $timeout) = @_;
	my $line;

	if ($timeout < 0) {
		$line = <STDIN>;

	} elsif ($timeout == 0) {
		if (dataWaiting(\*STDIN)) {
			$line = <STDIN>;
		}

	} else {
		my $bits = '';
		vec($bits, fileno(STDIN), 1) = 1;
		if (select($bits, undef, undef, $timeout) > 0) {
			$line = <STDIN>;
		}
	}

	if (defined $line) {
		$line =~ s/\n//;
		$line = undef if ($line eq '');
	}
	$line = I18N::UTF8ToString($line) if (defined($line));
	return $line;
}

sub writeOutput {
	my ($self, $type, $message, $domain) = @_;
	use bytes;
	my $code = Utils::Unix::getColorForMessage(\%consoleColors, $type, $domain);
	print $code . $message . Utils::Unix::getColor('reset');
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

1;
