#########################################################################
#  OpenKore - Interface::Console::Other
#  Console interface for platforms other than Win32 (Linux and Unix)
#
#  Copyright (c) 2004 OpenKore development team 
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

package Interface::Console::Other;

use strict;
use warnings;
no warnings 'redefine';
use IO::Socket;
use IO::Select;
use Time::HiRes qw(time usleep);
use Settings;
use Utils;
use Interface::Console;
use base qw(Interface::Console);
use POSIX qw(:termios_h);
require 'sys/ioctl.ph';


our %fgcolors;
our %bgcolors;

our $term;
our ($width, $height);


##### TERMINAL FUNCTIONS #####

sub getTerminalSize {
	my $data = ' ' x 8;
	if (ioctl (STDOUT, TIOCGWINSZ(), $data) == 0) {
		($width, $height) = unpack("ss", $data);
	} else {
		$width = 80;
		$height = 24;
	}
}

sub MODINIT {
	$SIG{WINCH} = \&getTerminalSize;
	getTerminalSize();
}


###### METHODS #####

sub new {
	my %interface = ();
	my $term;

	bless \%interface, __PACKAGE__;
	$interface{select} = IO::Select->new(\*STDIN);

if (0) {
	$term = new POSIX::Termios;
	$interface{term} = $term;
	$term->getattr(fileno(STDIN));
	$interface{oterm} = $term->getlflag();

	# Set terminal on noecho and CBREAK
	my $echo = ECHO | ECHOK | ICANON;
	my $noecho = $interface{oterm} & ~$echo;
	$term->setlflag($noecho);
	$term->setcc(VTIME, 1);
	$term->setattr(fileno(STDIN), TCSANOW);
}

	return \%interface;
}

sub DESTROY {
	my $self = $_[0];

if (0) {
	$self->{term}->setlflag($self->{oterm});
	$self->{term}->setcc(VTIME, 0);
	$self->{term}->setattr(fileno(STDIN), TCSANOW);
}

	$self->color('reset');
	delete $SIG{WINCH};
}

sub getWindowSize {
	my $data = ' ' x 8;
	if (ioctl (STDOUT, TIOCGWINSZ(), $data) == 0) {
		($width, $height) = unpack("ss", $data);
	} else {
		$width = 80;
		$height = 24;
	}
}

sub getInput {
	my $class = shift;
	my $timeout = shift;
	my $msg;

	if ($timeout < 0) {
		$msg = <STDIN> until defined($msg) && $msg ne "\n";

	} elsif ($timeout > 0) {
		my %timeOut = ();

		$timeOut{time} = time;
		$timeOut{timeout} = $timeout;

		while (!timeOut(\%timeOut)) {
			$msg = $class->getInput(0);
			return $msg if (defined $msg);
			usleep(10000);
		}

	} else {
		if ($class->{select}->can_read(0.00)) {
			$msg = <STDIN>;
		}
	}

	$msg =~ y/\r\n//d if defined $msg;
	undef $msg if (defined $msg && $msg eq "");
	return $msg;
}

sub writeOutput {
	my $class = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;

	setColor($type, $domain);
	print $message;
	color('reset');
	STDOUT->flush;
}

sub setColor {
	return if (!$consoleColors{''}{'useColors'});
	my ($type, $domain) = @_;
	my $color = $consoleColors{$type}{$domain};
	$color = $consoleColors{$type}{'default'} if (!defined $color);
	color($color) if (defined $color);
}

sub color {
	my $color = shift;

	$color =~ s/\/(.*)//;
	my $bgcolor = $1 || "default";

	print $fgcolors{$color} if defined($fgcolors{$color});
	print $bgcolors{$bgcolor} if defined($bgcolors{$bgcolor});
}


%fgcolors = (
	'reset'		=> "\e[0m",
	'default'	=> "\e[0m",
	'black'		=> "\e[1;30m",
	'red'		=> "\e[1;31m",
	'lightred'	=> "\e[1;31m",
	'brown'		=> "\e[0;31m",
	'darkred'	=> "\e[0;31m",
	'green'		=> "\e[1;32m",
	'lightgreen'	=> "\e[1;32m",
	'darkgreen'	=> "\e[0;32m",
	'yellow'	=> "\e[1;33m",
	'blue'		=> "\e[0;34m",
	'lightblue'	=> "\e[1;34m",
	'magenta'	=> "\e[0;35m",
	'lightmagenta'	=> "\e[1;35m",
	'cyan'		=> "\e[1;36m",
	'lightcyan'	=> "\e[1;36m",
	'darkcyan'	=> "\e[0;36m",
	'white'		=> "\e[1;37m",
	'gray'		=> "\e[0;37m",
	'grey'		=> "\e[0;37m"
);

$bgcolors{"black"} = "\e[40m";
$bgcolors{""} = "\e[40m";
$bgcolors{"default"} = "\e[40m";

$bgcolors{"red"} = "\e[41m";
$bgcolors{"lightred"} = "\e[41m";
$bgcolors{"brown"} = "\e[41m";
$bgcolors{"darkred"} = "\e[41m";

$bgcolors{"green"} = "\e[42m";
$bgcolors{"lightgreen"} = "\e[42m";
$bgcolors{"darkgreen"} = "\e[42m";

$bgcolors{"yellow"} = "\e[43m";

$bgcolors{"blue"} = "\e[44m";
$bgcolors{"lightblue"} = "\e[44m";

$bgcolors{"magenta"} = "\e[45m";
$bgcolors{"lightmagenta"} = "\e[45m";

$bgcolors{"cyan"} = "\e[46m";
$bgcolors{"lightcyan"} = "\e[46m";
$bgcolors{"darkcyan"} = "\e[46m";

$bgcolors{"white"} = "\e[47m";
$bgcolors{"gray"} = "\e[47m";
$bgcolors{"grey"} = "\e[47m";


1; #end of module
