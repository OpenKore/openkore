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
use Term::Cap;
use POSIX qw(:termios_h);
require 'sys/ioctl.ph';

use Settings;
use Utils;
use Interface::Console;

use base qw(Interface::Console);


our %fgcolors;
our %bgcolors;

our ($width, $height);


##### TERMINAL FUNCTIONS #####

sub getTerminalSize {
	my $data = ' ' x 8;
	my $result = ioctl (STDOUT, TIOCGWINSZ(), $data);
	if (defined $result && $result == 0) {
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

# Move cursor to left
sub cursorLeft {
	return if ($_[1] <= 0);
	# For some reason the 'linux' terminal doesn't
	# support LE (or terminfo's 'cub').
	# So we just print many 'le' commands.
	if ($ENV{TERM} eq 'xterm') {
		$_[0]->{cap}->Tgoto('LE', undef, $_[1], \*STDOUT);
	} else {
		for (my $i = 0; $i < $_[1]; $i++) {
			$_[0]->{cap}->Tputs('le', 1, \*STDOUT);
		}
	}
}

# Move cursor to right
sub cursorRight {
	return if ($_[1] <= 0);
	# Same story as bove
	if ($ENV{TERM} eq 'xterm') {
		$_[0]->{cap}->Tgoto('RI', undef, $_[1], \*STDOUT);
	} else {
		for (my $i = 0; $i < $_[1]; $i++) {
			$_[0]->{cap}->Tputs('nd', 1, \*STDOUT);
		}
	}
}

sub delLine {
	$_[0]->{cap}->Tgoto('DC', 0, $width, \*STDOUT);
}


###### METHODS #####

sub new {
	my %interface = ();
	my $term;

	$interface{select} = IO::Select->new(\*STDIN);
	$interface{input} = {};
	$interface{input}{buf} = '';
	$interface{input}{pos} = 0;

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

	# Setup termcap
	my $OSPEED = $term->getospeed;
	$interface{cap} = Term::Cap->Tgetent({ OSPEED => $OSPEED });

	getTerminalSize();
	STDOUT->autoflush(0);

	bless \%interface, __PACKAGE__;
	return \%interface;
}

sub DESTROY {
	my $self = $_[0];

	$self->{term}->setlflag($self->{oterm});
	$self->{term}->setcc(VTIME, 0);
	$self->{term}->setattr(fileno(STDIN), TCSANOW);

	$self->color('reset');
	delete $SIG{WINCH};
	STDOUT->autoflush(1);
}


# Insert a substring into a string.
# insert(str, pos, substr)
sub insert {
	my $i = $_[1];
	$i = 0 if ($i < 0);
	$i = length($_[0]) if ($i > length($_[0]));
	$_[0] = substr($_[0], 0, $i) . $_[2] . substr($_[0], $i);
}

# Delete a substring from a string.
# strdel(str, pos, length)
sub strdel {
	return if ($_[1] > length($_[0]) || $_[2] <= 0);
	my $p = $_[1];
	my $i = $_[2];
	if ($p < 0) {
		$i += $p;
		$p = 0;
	} else {
		$i = length($_[0]) - $p if ($i > length($_[0]) - $p);
	}
	$_[0] = substr($_[0], 0, $p) . substr($_[0], $p + $i);
}

# This function handles key events
# TODO:
# * Input history
# * TAB completion
# * Handle other Ctrl characters
sub readEvents {
	my $interface = shift;
	my %input = %{$interface->{input}};
	my $entered = undef;

	while ($interface->{select}->can_read(0)) {
		my $key = '';
		sysread(STDIN, $key, 1);
		insert($input{buf}, $input{pos}, $key);
		$input{pos}++;

		# Home
		if (index($input{buf}, "\e[1~") > -1) {
			# Remove escape sequence from input buffer
			strdel($input{buf}, $input{pos} - 4, 4);
			$input{pos} -= 4;

			# Move cursor to beginning
			$interface->cursorLeft($input{pos});
			$input{pos} = 0;

		# End
		} elsif (index($input{buf}, "\e[4~") > -1) {
			# Remove escape sequence from input buffer
			strdel($input{buf}, $input{pos} - 4, 4);
			$input{pos} -= 4;

			# Move cursor to end
			$interface->cursorRight(length($input{buf}) - $input{pos});
			$input{pos} = length($input{buf});

		# Delete
		} elsif (index($input{buf}, "\e[3~") > -1) {
			# Remove escape sequence and next character
			strdel($input{buf}, $input{pos} - 4, 5);
			$input{pos} -= 4;

			# Move cursor to beginning, delete whole line and print buffer
			$interface->cursorLeft($input{pos});
			$interface->delLine;
			print $input{buf};

			# Move cursor back to where it's supposed to be
			if ($input{pos} < length($input{buf})) {
				$interface->cursorLeft(length($input{buf}) - $input{pos});
			}

		# Backspace
		} elsif (ord($key) == 127) {
			# Remove backspace character from input buffer
			strdel($input{buf}, $input{pos} - 2, 2);

			if ($input{pos} != 1) {
				# Move cursor to beginning, delete whole line and print buffer
				$interface->cursorLeft($input{pos} - 1);
				$interface->delLine;
				print $input{buf};

				# Move cursor back to where it's supposed to be
				$input{pos} -= 2;
				if ($input{pos} < length($input{buf})) {
					$interface->cursorLeft(length($input{buf}) - $input{pos});
				}

			} else {
				# Don't do anything if the cursor is already at the beginning
				$input{pos} = 0;
			}

		# Ctrl+D (end of input)
		} elsif (ord($key) == 4) {
			# Ignore this
			strdel($input{buf}, $input{pos} - 1, 1);
			$input{pos}--;

		# Left arrow key
		} elsif (index($input{buf}, "\e[D") > -1) {
			# Remove escape sequence from input buffer
			strdel($input{buf}, $input{pos} - 3, 3);

			# Move cursor one left
			$input{pos} -= 4;
			$interface->cursorLeft(1) if ($input{pos} >= 0);

		# Right arrow key
		} elsif (index($input{buf}, "\e[C") > -1) {
			# Remove escape sequence from input buffer
			strdel($input{buf}, $input{pos} - 3, 3);
			$input{pos} -= 3;

			# Move cursor one right
			if ($input{pos} < length($input{buf})) {
				$input{pos}++;
				$interface->cursorRight(1);
			}

		# Ctrl+U - delete entire line
		} elsif (ord($key) == 21) {
			# Remove Ctrl+U character from input buffer
			strdel($input{buf}, $input{pos} - 2, 2);

			# Move cursor to beginning and delete whole line
			$interface->cursorLeft($input{pos} - 1);
			$interface->delLine;

			# Reset buffer
			undef $input{buf};
			$input{buf} = '';
			$input{pos} = 0;

		# TAB
		} elsif (index($input{buf}, "\t") > -1) {
			# Ignore tabs for now
			strdel($input{buf}, $input{pos} - 1, 1);
			$input{pos}--;

		# F1-F4
		} elsif (length($input{buf}) >= 4 && $input{buf} =~ /\e(\[\[[A-Z]|O[A-Z])/) {
			# Ignore them
			$input{pos} -= length($1) + 1;
			$input{buf} =~ s/\e(\[\[[A-Z]|O[A-Z])//g;

		# Normal character
		} elsif (index($input{buf}, "\e") == -1) {
			if (index($input{buf}, "\n") == -1) {
				# If Enter has not been pressed,
				# move cursor to beginning, delete whole line and print buffer
				$interface->cursorLeft($input{pos} - 1);
				$interface->delLine;
				print $input{buf};

				# Move cursor back to where it's supposed to be
				if ($input{pos} < length($input{buf})) {
					$interface->cursorLeft(length($input{buf}) - $input{pos});
				}

			} else {
				# Enter has been pressed; delete newline character,
				# return and reset buffer
				strdel($input{buf}, $input{pos} - 1, 1);
				print "\n";
				$entered = $input{buf};
				undef $input{buf};
				$input{buf} = '';
				$input{pos} = 0;
			}

		# Somehow an escape character got into our buffer and is not removed.
		# Remove it if it's a full escape character (4 bytes)
		} elsif (length($input{buf}) >= 4 && $input{buf} =~ /\e\[(\d{1,2}~|[A-Z])/) {
			$input{pos} -= length($1) + 2;
			$input{buf} =~ s/\e\[(\d{1,2}~|[A-Z])//g;

		# There's an escape key in the buffer but the user pressed Enter.
		# Apparently he pressed Escape on accident.
		} elsif ($key eq "\n") {
			# Remove all escape and newline characters.
			# Restore prompt.
			my $len = length($input{buf});
			$input{buf} =~ s/[\e\n]//g;
			$input{pos} = $len - length($input{buf}) + 1;
		}
	}

	#open(F, '>/dev/pts/2'); # Debugging stuff
	#print F "\n";
	#close F;
	$input{pos} = 0 if ($input{pos} < 0);
	STDOUT->flush;


	undef $interface->{input};
	$interface->{input} = \%input;
	return $entered;
}


sub getInput {
	my $class = shift;
	my $timeout = shift;
	my $msg;

	if ($timeout < 0) {
		$msg = $class->readEvents until defined($msg);

	} elsif ($timeout > 0) {
		my %timeOut = ();

		$timeOut{time} = time;
		$timeOut{timeout} = $timeout;

		while (!timeOut(\%timeOut)) {
			$msg = $class->readEvents;
			last if (defined $msg);
			usleep 10000;
		}

	} else {
		$msg = $class->readEvents;
	}

	undef $msg if (defined $msg && $msg eq "");
	return $msg;
}

sub writeOutput {
	my $class = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;

	# This code keeps the input prompt visible even on output
	if (length $class->{input}{buf} == 0) {
		# Just print our message if there is no input buffer
		setColor($type, $domain);
		print $message;
		color('reset');

	} else {
		# If there's an input buffer, clear it
		$class->cursorLeft($class->{input}{pos});
		$class->delLine;

		# Print the message
		setColor($type, $domain);
		print $message;
		color('reset');

		# Print the input buffer
		print $class->{input}{buf};

		# Move cursor to where it's supposed to be
		if ($class->{input}{pos} < length($class->{input}{buf})) {
			$class->cursorLeft(length($class->{input}{buf}) - $class->{input}{pos});
		}
	}

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
	''			=> "\e[22;40m";
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

1; #end of module
