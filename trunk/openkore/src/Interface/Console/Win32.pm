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
BEGIN { $SIG{__DIE__} = sub {confess @_}; }
use Time::HiRes qw/time/;
use Text::Wrap;
use Win32::Console;

use Settings;

our ($out_con, $out_top, $out_bot, $out_line, $out_col);
our $last_line_end = 1;
our ($left, $right);
our ($in_con, $in_line, $in_pos);
our @input_list;
our $input_offset = 0;
our @input_lines;
our $input_part = '';

our $enabled;

our %fgcolors;
our %bgcolors;

sub start {
	return undef if ($enabled);
	$out_con = new Win32::Console(STD_OUTPUT_HANDLE()) 
			or die "Could not init output Console: $!\n";
	$in_con = new Win32::Console(STD_INPUT_HANDLE()) 
			or die "Could not init input Console: $!\n";

	#get some window and buffer information
	my($wLeft, $wTop, $wRight, $wBottom) = $out_con->Window() or die "Can't find initial dimentions for the output window\n";
	my($bCol, $bRow) = $out_con->Size() or die "Can't find dimentions for the output buffer\n";
	$out_con->Window(1, $wLeft, $bRow - $wBottom - 1, $wRight, $bRow - 1);# or die "Can't set dimentions for the output window\n";
	($left, $out_top, $right, $in_line) = $out_con->Window() or die "Can't find new dimentions for the output window\n";
	$out_bot = $in_line - 1; #one line above the input line
	$out_line = $in_line;
	$out_col = $in_pos = $left;

	$out_con->Cursor(0, $in_line);
	$enabled = 1;
	return 1;
}

sub stop {
	undef @input_list;
	undef @input_lines;
#	$out_con->Free();
#	$in_con->Free();
}

sub getInput {
	return undef unless ($enabled);
	my $class = shift;
	my $timeout = shift;
	readEvents();
	my $msg;
	if ($timeout < 0) {
		until ($msg) {
			readEvents();
			if (@input_lines) {
				$msg = shift @input_lines;
			}
		}
	} elsif ($timeout > 0) {
		my $end = time + $timeout;
		until ($end < time || $msg) {
			readEvents();
			if (@input_lines) {
				$msg = shift @input_lines;
			}
		}
	} else {
		if (@input_lines) {
			$msg = shift @input_lines;
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
	local($|) = 1;
	while ($in_con->GetEvents()) {
		my @event = $in_con->Input();
		if (defined($event[0]) && $event[0] == 1 && $event[1]) {
			##Backspace
			if ($event[5] == 8) {
				$in_pos-- if $in_pos > 0;
				substr($input_part, $in_pos, 1, '');
				$out_con->Scroll(
					$in_pos, $in_line, $right, $in_line,
					$in_pos-1, $in_line, ord(' '), $main::ATTR_NORMAL, 
					$in_pos, $in_line, $right, $in_line,
				);
				$out_con->Cursor($in_pos, $in_line);
#				print "\010 \010";
			##Enter
			} elsif ($event[5] == 13) {
				my $ret = $out_con->Scroll(
					$left, 0, $right, $in_line,
					0, -1, ord(' '), $main::ATTR_NORMAL, 
					$left, 0, $right, $in_line
				);
				$out_con->Cursor(0, $in_line);
				$in_pos = 0;
				$input_list[0] = $input_part;
				unshift(@input_list, "");
				$input_offset = 0;
				push @input_lines, $input_part;
				$input_part = '';
#				print "\n";
			#Other ASCII (+ ISO Latin-*)
			} elsif ($event[5] >= 32 && $event[5] != 127 && $event[5] <= 255) {
				if ($in_pos < length($input_part)) {
					$out_con->Scroll(
						$in_pos, $in_line, $right, $in_line,
						$in_pos+1, $in_line, ord(' '), $main::ATTR_NORMAL, 
						$in_pos, $in_line, $right, $in_line,
					);
				}
				$out_con->Cursor($in_pos, $in_line);
				$out_con->Write(chr($event[5]));
				substr($input_part, $in_pos, 0, chr($event[5]));
				$in_pos++;
#			} elsif ($event[3] == 33) {
#				__PACKAGE__->writeOutput("pgup\n");
#			} elsif ($event[3] == 34) {
#				__PACKAGE__->writeOutput("pgdn\n");
			##End
			} elsif ($event[3] == 35) {
				$out_con->Cursor($in_pos = length($input_part), $in_line);
			##Home
			} elsif ($event[3] == 36) {
				$out_con->Cursor($in_pos = 0, $in_line);
			##Left Arrow
			} elsif ($event[3] == 37) {
				$in_pos--;
				$out_con->Cursor($in_pos, $in_line);
			##Up Arrow
			} elsif ($event[3] == 38) {
				unless ($input_offset) {
					$input_list[$input_offset] = $input_part;
				}
				$input_offset++;
				$input_offset -= $#input_list + 1 while $input_offset > $#input_list;

				$out_con->Cursor(0, $in_line);
				$out_con->Write(' ' x length($input_part));
				$out_con->Cursor(0, $in_line);
				$input_part = $input_list[$input_offset];
				$out_con->Write($input_part);
				$in_pos = length($input_part);
			##Right Arrow
			} elsif ($event[3] == 39) {
				$in_pos++;
				$out_con->Cursor($in_pos, $in_line);
			##Down Arrow
			} elsif ($event[3] == 40) {
				unless ($input_offset) {
					$input_list[$input_offset] = $input_part;
				}
				$input_offset--;
				$input_offset += $#input_list + 1 while $input_offset < 0;

				$out_con->Cursor(0, $in_line);
				$out_con->Write(' ' x length($input_part));
				$out_con->Cursor(0, $in_line);
				$input_part = $input_list[$input_offset];
				$out_con->Write($input_part);
				$in_pos = length($input_part);
			##Insert
#			} elsif ($event[3] == 45) {
#				__PACKAGE__->writeOutput("insert\n");
			##Delete
			} elsif ($event[3] == 46) {
				substr($input_part, $in_pos, 1, '');
				$out_con->Scroll(
					$in_pos+1, $in_line, $right, $in_line,
					$in_pos, $in_line, ord(' '), $main::ATTR_NORMAL, 
					$in_pos+1, $in_line, $right, $in_line,
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
	unless ($enabled) {
		cluck("called before being start()ed\n");
		return undef;
	}

	my $class = shift;
	my $type = shift;
	my $message = shift;
	my $domain = shift;
	
	#wrap the text
	local($Text::Wrap::columns) = $right - $left;
	my ($endspace) = $message =~ /(\s*)$/; #Save trailing whitespace: wrap kills spaces near wraps, especialy at the end of stings, so "\n" becomes "", not what we want
	$message = wrap('', '', $message);
	$message =~ s/\s*$/$endspace/; #restore the whitespace
	
	my $lines = $message =~ s/\r?\n/\n/g; #fastest? way to count newlines
	
	#this paragraph is all about handleing lines that don't end in a newline. I have no clue how it works, even though I wrote it, but it does. =)
	$lines++ if (!$lines && $last_line_end);
	if ($lines && !$last_line_end) {
		$lines--;
		$out_line--;
	} elsif (!$last_line_end) {
		$out_line--;
	}
	$last_line_end = ($message =~ /\n$/) ? 1 : 0;

	my $ret = $out_con->Scroll(
		$left, 0, $right, $out_bot,
		0, 0-$lines, ord(' '), $main::ATTR_NORMAL, 
		$left, 0, $right, $out_bot
	);

	my ($ocx, $ocy) = $out_con->Cursor();
	$out_con->Cursor($out_col, $out_line - $lines);
	setColor($type, $domain);
	$out_con->Write($message);
	color('reset');
	($out_col, $out_line) = $out_con->Cursor();
	$out_line -= $last_line_end - 1;
	$out_con->Cursor($ocx, $ocy);
}

sub setColor {
	return if (!$consoleColors{''}{'useColors'});
	my ($type, $domain) = @_;
	my $color = $consoleColors{$type}{$domain};
	$color = $consoleColors{$type}{'default'} if (!defined $color);
	color($color) if (defined $color);
}

sub color {
	return if ($config{'XKore'}); # Don't print colors in X-Kore mode; this is a temporary hack!
	my $color = shift;
	
	$color =~ s/\/(.*)//;
	my $bgcolor = $1 || "default";
	
	my $fgcode = $fgcolors{$color} || $fgcolors{'default'};
	my $bgcode = $bgcolors{$bgcolor} || $bgcolors{'default'};
	$out_con->Attr($fgcode | $bgcode);
}

$fgcolors{"reset"}		= $main::FG_GRAY;
$fgcolors{"default"}	= $main::FG_GRAY;

$fgcolors{"black"}		= $main::FG_BLACK;

$fgcolors{"red"}		= $main::FG_RED;
$fgcolors{"darkred"}	= $main::FG_RED;

$fgcolors{"lightred"}	= $main::FG_LIGHTRED;

$fgcolors{"brown"}		= $main::FG_BROWN;

$fgcolors{"green"}		= $main::FG_GREEN;
$fgcolors{"lightgreen"}	= $main::FG_LIGHTGREEN;

$fgcolors{"darkgreen"}	= $main::FG_GREEN;

$fgcolors{"yellow"}		= $main::FG_YELLOW;

$fgcolors{"blue"}		= $main::FG_BLUE;

$fgcolors{"lightblue"}	= $main::FG_LIGHTBLUE;

$fgcolors{"magenta"}	= $main::FG_MAGENTA;

$fgcolors{"lightmagenta"}	= $main::FG_LIGHTMAGENTA;

$fgcolors{"cyan"}		= $main::FG_CYAN;
$fgcolors{"lightcyan"}	= $main::FG_LIGHTCYAN;

$fgcolors{"darkcyan"}	= $main::FG_CYAN;

$fgcolors{"white"}		= $main::FG_WHITE;

$fgcolors{"gray"}		= $main::FG_GRAY;
$fgcolors{"grey"}		= $main::FG_GRAY;

$fgcolors{"darkgray"}	= FOREGROUND_INTENSITY();
$fgcolors{"darkgrey"}   = FOREGROUND_INTENSITY();



$bgcolors{"black"}		= $main::BG_BLACK;
$bgcolors{""}			= $main::BG_BLACK;
$bgcolors{"default"}	= $main::BG_BLACK;

$bgcolors{"red"}		= $main::BG_RED;
$bgcolors{"lightred"}	= $main::BG_LIGHTRED;

$bgcolors{"brown"}		= $main::BG_BROWN;
$bgcolors{"darkred"}	= $main::BG_BROWN;

$bgcolors{"green"}		= $main::BG_GREEN;
$bgcolors{"lightgreen"}	= $main::BG_LIGHTGREEN;

$bgcolors{"darkgreen"}	= $main::BG_GREEN;

$bgcolors{"yellow"}		= $main::BG_YELLOW;

$bgcolors{"blue"}		= $main::BG_BLUE;

$bgcolors{"lightblue"}	= $main::BG_LIGHTBLUE;

$bgcolors{"magenta"}	= $main::BG_MAGENTA;

$bgcolors{"lightmagenta"}	= $main::BG_LIGHTMAGENTA;

$bgcolors{"cyan"}		= $main::BG_CYAN;
$bgcolors{"lightcyan"}	= $main::BG_LIGHTCYAN;

$bgcolors{"darkcyan"}	= $main::BG_CYAN;

$bgcolors{"white"}		= $main::BG_WHITE;

$bgcolors{"gray"}		= $main::BG_GRAY;
$bgcolors{"grey"}		= $main::BG_GRAY;

$bgcolors{"darkgray"}	= BACKGROUND_INTENSITY();
$bgcolors{"darkgrey"}   = BACKGROUND_INTENSITY();

1 #end of module