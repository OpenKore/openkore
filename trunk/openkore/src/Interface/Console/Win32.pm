#########################################################################
#  OpenKore - Interface::Console::Win32
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
##
# MODULE DESCRIPTION: 
#
# Support for asyncronous input on MS Windows computers

package Interface::Console::Win32;

use strict;
use warnings;

die "W32 only, this module should never be called on any other OS\n"
		unless ($^O eq 'MSWin32' || $^O eq 'cygwin');

use Carp;
use Time::HiRes qw/time sleep/;
use Text::Wrap;
use Win32::Console;

use Globals;
use base qw(Interface::Console);

our %fgcolors;
our %bgcolors;

sub new {
	my $class = shift;
	my $self = {
		input_list => [],
		last_line_end => 1,
		input_lines => [],
		input_offset => 0,
		input_part => '',
	};
	bless $self, $class;
	$self->{out_con} = new Win32::Console(STD_OUTPUT_HANDLE()) 
			or die "Could not init output Console: $!\n";
	$self->{in_con} = new Win32::Console(STD_INPUT_HANDLE()) 
			or die "Could not init input Console: $!\n";
	$self->setWinDim();
	
	$self->{out_con}->Cursor(0, $self->{in_line});
	return $self;
}

sub DESTROY {
	my $self = shift;

	$self->color('reset');
}

sub setWinDim {
	my $self = shift;
	my($wLeft, $wTop, $wRight, $wBottom) = $self->{out_con}->Window() or die "Can't find initial dimentions for the output window\n";
	my($bCol, $bRow) = $self->{out_con}->Size() or die "Can't find dimentions for the output buffer\n";
	$self->{out_con}->Window(1, $wLeft, $bRow - $wBottom - 1, $wRight, $bRow - 1);# or die "Can't set dimentions for the output window\n";
	@{$self}{qw(left out_top right in_line)} = $self->{out_con}->Window() or die "Can't find new dimentions for the output window\n";
	$self->{out_bot} = $self->{in_line} - 1; #one line above the input line
	$self->{out_line} = $self->{in_line};
	$self->{out_col} = $self->{in_pos} = $self->{left};
}

sub getInput {
#	return undef unless ($enabled);
	my $self = shift;
	my $timeout = shift;
	$self->readEvents();
	my $msg;
	if ($timeout < 0) {
		until (defined $msg) {
			$self->readEvents();
			sleep 0.01;
			if (@{$self->{input_lines}}) {
				$msg = shift @{$self->{input_lines}};
			}
		}
	} elsif ($timeout > 0) {
		my $end = time + $timeout;
		until ($end < time || defined $msg) {
			$self->readEvents();
			sleep 0.01;
			if (@{$self->{input_lines}}) {
				$msg = shift @{$self->{input_lines}};
			}
		}
	} else {
		if (@{$self->{input_lines}}) {
			$msg = shift @{$self->{input_lines}};
		}
	}
	undef $msg if (defined $msg && $msg eq '');

	return $msg;
}


##
# readEvents()
#
# reads low level events from the input console, for key presses it
# updates the console input variables
#
# note: most of this is commented out, it need a cordinated output
# system to use the separate input line (meaning output does not
# over write your input line)
sub readEvents {
	my $self = shift;
#	local($|) = 1;
	while ($self->{in_con}->GetEvents()) {
		my @event = $self->{in_con}->Input();
		if (defined($event[0]) && $event[0] == 1 && $event[1]) {
			##Backspace
			if ($event[5] == 8) {
				$self->{in_pos}-- if $self->{in_pos} > 0;
				substr($self->{input_part}, $self->{in_pos}, 1, '');
				$self->{out_con}->Scroll(
					$self->{in_pos}, $self->{in_line}, $self->{right}, $self->{in_line},
					$self->{in_pos}-1, $self->{in_line}, ord(' '), $main::ATTR_NORMAL, 
					$self->{in_pos}, $self->{in_line}, $self->{right}, $self->{in_line},
				);
				$self->{out_con}->Cursor($self->{in_pos}, $self->{in_line});
#				print "\010 \010";
			##Enter
			} elsif ($event[5] == 13) {
				my $ret = $self->{out_con}->Scroll(
					$self->{left}, 0, $self->{right}, $self->{in_line},
					0, -1, ord(' '), $main::ATTR_NORMAL, 
					$self->{left}, 0, $self->{right}, $self->{in_line}
				);
				$self->{out_con}->Cursor(0, $self->{in_line});
				$self->{in_pos} = 0;
				$self->{input_list}[0] = $self->{input_part};
				unshift(@{ $self->{input_list} }, "");
				$self->{input_offset} = 0;
				push @{ $self->{input_lines} }, $self->{input_part};
				$self->{out_col} = 0;
				$self->{input_part} = '';
#				print "\n";
			#Other ASCII (+ ISO Latin-*)
			} elsif ($event[5] >= 32 && $event[5] != 127 && $event[5] <= 255) {
				if ($self->{in_pos} < length($self->{input_part})) {
					$self->{out_con}->Scroll(
						$self->{in_pos}, $self->{in_line}, $self->{right}, $self->{in_line},
						$self->{in_pos}+1, $self->{in_line}, ord(' '), $main::ATTR_NORMAL, 
						$self->{in_pos}, $self->{in_line}, $self->{right}, $self->{in_line},
					);
				}
				$self->{out_con}->Cursor($self->{in_pos}, $self->{in_line});
				$self->{out_con}->Write(chr($event[5]));
				substr($self->{input_part}, $self->{in_pos}, 0, chr($event[5]));
				$self->{in_pos}++;
#			} elsif ($event[3] == 33) {
#				__PACKAGE__->writeOutput("pgup\n");
#			} elsif ($event[3] == 34) {
#				__PACKAGE__->writeOutput("pgdn\n");
			##End
			} elsif ($event[3] == 35) {
				$self->{out_con}->Cursor($self->{in_pos} = length($self->{input_part}), $self->{in_line});
			##Home
			} elsif ($event[3] == 36) {
				$self->{out_con}->Cursor($self->{in_pos} = 0, $self->{in_line});
			##Left Arrow
			} elsif ($event[3] == 37) {
				$self->{in_pos}--;
				$self->{out_con}->Cursor($self->{in_pos}, $self->{in_line});
			##Up Arrow
			} elsif ($event[3] == 38) {
				unless ($self->{input_offset}) {
					$self->{input_list}[$self->{input_offset}] = $self->{input_part};
				}
				$self->{input_offset}++;
				$self->{input_offset} -= $#{ $self->{input_list} } + 1 while $self->{input_offset} > $#{ $self->{input_list} };

				$self->{out_con}->Cursor(0, $self->{in_line});
				$self->{out_con}->Write(' ' x length($self->{input_part}));
				$self->{out_con}->Cursor(0, $self->{in_line});
				$self->{input_part} = $self->{input_list}[$self->{input_offset}];
				$self->{out_con}->Write($self->{input_part});
				$self->{in_pos} = length($self->{input_part});
			##Right Arrow
			} elsif ($event[3] == 39) {
				if ($self->{in_pos} + 1 <= length($self->{input_part})) {
					$self->{in_pos}++;
					$self->{out_con}->Cursor($self->{in_pos}, $self->{in_line});
				}
			##Down Arrow
			} elsif ($event[3] == 40) {
				unless ($self->{input_offset}) {
					$self->{input_list}[$self->{input_offset}] = $self->{input_part};
				}
				$self->{input_offset}--;
				$self->{input_offset} += $#{ $self->{input_list} } + 1 while $self->{input_offset} < 0;

				$self->{out_con}->Cursor(0, $self->{in_line});
				$self->{out_con}->Write(' ' x length($self->{input_part}));
				$self->{out_con}->Cursor(0, $self->{in_line});
				$self->{input_part} = $self->{input_list}[$self->{input_offset}];
				$self->{out_con}->Write($self->{input_part});
				$self->{in_pos} = length($self->{input_part});
			##Insert
#			} elsif ($event[3] == 45) {
#				__PACKAGE__->writeOutput("insert\n");
			##Delete
			} elsif ($event[3] == 46) {
				substr($self->{input_part}, $self->{in_pos}, 1, '');
				$self->{out_con}->Scroll(
					$self->{in_pos}, $self->{in_line}, $self->{right}, $self->{in_line},
					$self->{in_pos} - 1, $self->{in_line}, ord(' '), $main::ATTR_NORMAL, 
					$self->{in_pos}, $self->{in_line}, $self->{right}, $self->{in_line},
				);
			##F1-F12
#			} elsif ($event[3] >= 112 && $event[3] <= 123) {
#				__PACKAGE__->writeOutput("F" . ($event[3] - 111) . "\n");
#			} else {
#				__PACKAGE__->writeOutput(join '-', @event, "\n");
			}
#		} else {
#			__PACKAGE__->writeOutput(join '-', @event, "\n");
		}
	}	
}


sub writeOutput {
	my $self = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;
	
	#wrap the text
	local($Text::Wrap::columns) = $self->{right} - $self->{left} + 1;
	my ($endspace) = $message =~ /(\s*)$/; #Save trailing whitespace: wrap kills spaces near wraps, especialy at the end of stings, so "\n" becomes "", not what we want
	$message = wrap('', '', $message);
	$message =~ s/\s*$/$endspace/; #restore the whitespace
	
	my $lines = $message =~ s/\r?\n/\n/g; #fastest? way to count newlines
	
	#this paragraph is all about handleing lines that don't end in a newline. I have no clue how it works, even though I wrote it, but it does. =)
	$lines++ if (!$lines && $self->{last_line_end});
	if ($lines && !$self->{last_line_end}) {
		$lines--;
		$self->{out_line}--;
	} elsif (!$self->{last_line_end}) {
		$self->{out_line}--;
	}
	$self->{last_line_end} = ($message =~ /\n$/) ? 1 : 0;

	my $ret = $self->{out_con}->Scroll(
		$self->{left}, 0, $self->{right}, $self->{out_bot},
		0, 0-$lines, ord(' '), $main::ATTR_NORMAL, 
		$self->{left}, 0, $self->{right}, $self->{out_bot}
	);

	my ($ocx, $ocy) = $self->{out_con}->Cursor();
	$self->{out_con}->Cursor($self->{out_col}, $self->{out_line} - $lines);
	$self->setColor($type, $domain);
	$self->{out_con}->Write($message);
	$self->color('reset');
	($self->{out_col}, $self->{out_line}) = $self->{out_con}->Cursor();
	$self->{out_line} -= $self->{last_line_end} - 1;
	$self->{out_con}->Cursor($ocx, $ocy);
}

sub setColor {
	return if (!$consoleColors{''}{'useColors'});
	my $self = shift;
	my ($type, $domain) = @_;
	my $color;
	$color = $consoleColors{$type}{$domain} if (defined $type && defined $domain && defined $consoleColors{$type});
	$color = $consoleColors{$type}{'default'} if (!defined $color && defined $type);
	$self->color($color) if (defined $color);
}

sub color {
	my $self = shift;
	my $color = shift;
	my ($bgcolor, $fgcode, $bgcode);
	$color =~ s/\/(.*)//;
	$bgcolor = $1 || "default";

	$fgcode = $fgcolors{$color} || $fgcolors{'default'};
	$bgcode = $bgcolors{$bgcolor} || $bgcolors{'default'};
	$self->{out_con}->Attr($fgcode | $bgcode);
}

sub title {
	my $self = shift;
	my $title = shift;

	if (defined $title) {
		if (!defined $self->{currentTitle} || $self->{currentTitle} ne $title) {
			$self->{out_con}->Title($title);
			$self->{currentTitle} = $title;
		}
	} else {
		return $self->{out_con}->Title();
	}
}

#IRGB
#8421

%fgcolors = (
	'reset'		=> $main::FG_GRAY,
	'default'	=> $main::FG_GRAY,

	'black'		=> $main::FG_BLACK,
	'darkgray'	=> FOREGROUND_INTENSITY(),
	'darkgrey'	=> FOREGROUND_INTENSITY(),

	'darkred'	=> $main::FG_RED,
	'red'		=> $main::FG_LIGHTRED,

	'darkgreen'	=> $main::FG_GREEN,
	'green'		=> $main::FG_LIGHTGREEN,

	'brown'		=> $main::FG_BROWN,
	'yellow'	=> $main::FG_YELLOW,
	
	'darkblue'	=> $main::FG_BLUE,
	'blue'		=> $main::FG_LIGHTBLUE,

	'darkmagenta'	=> $main::FG_MAGENTA,
	'magenta'	=> $main::FG_LIGHTMAGENTA,
	
	'darkcyan'	=> $main::FG_CYAN,
	'cyan'		=> $main::FG_LIGHTCYAN,

	'gray'		=> $main::FG_GRAY,
	'grey'		=> $main::FG_GRAY,
	'white'		=> $main::FG_WHITE,
);

#  I  R  G  B
#128 64 32 16

%bgcolors = (
	''			=> $main::BG_BLACK,
	'default'	=> $main::BG_BLACK,

	'black'		=> $main::BG_BLACK,
	'darkgray'	=> BACKGROUND_INTENSITY(),
	'darkgrey'	=> BACKGROUND_INTENSITY(),

	'darkred'	=> $main::BG_RED,
	'red'		=> $main::BG_LIGHTRED,

	'darkgreen'	=> $main::BG_GREEN,
	'green'		=> $main::BG_LIGHTGREEN,

	'brown'		=> $main::BG_BROWN,
	'yellow'	=> $main::BG_YELLOW,
	
	'darkblue'	=> $main::BG_BLUE,
	'blue'		=> $main::BG_LIGHTBLUE,

	'darkmagenta'	=> $main::BG_MAGENTA,
	'magenta'	=> $main::BG_LIGHTMAGENTA,
	
	'darkcyan'	=> $main::BG_CYAN,
	'cyan'		=> $main::BG_LIGHTCYAN,

	'gray'		=> $main::BG_GRAY,
	'grey'		=> $main::BG_GRAY,
	'white'		=> $main::BG_WHITE,
);

1 #end of module
