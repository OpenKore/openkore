=pod

=head1 NAME 

Input::Win32

=head1 DESCRIPTION

Functions to support asyncronous input on MS Windows computers

=cut

package Input::Win32;

use strict;
use warnings;

die "W32 only, this module should never be called on any other OS\n"
		unless ($^O eq 'MSWin32' || $^O eq 'cygwin');

use Time::HiRes qw/time/;
use Text::Wrap;
use Win32::Console;

use base qw/Exporter/;

our @EXPORT = qw(&start &stop &canRead &readLine $enabled);
our $in_con;
our $in_pos;
our @input_lines;
our $input_part = '';
our $enabled;

=head1 FUNCTIONS

=over 4

=item C<start()>

Initializes the input system. You must call this function to be able
to use the input system.

=cut

sub start {
	return undef if ($enabled);
#	$out_con = new Win32::Console(STD_OUTPUT_HANDLE()) 
#			or die "Could not init output Console: $!\n";
	$in_con = new Win32::Console(STD_INPUT_HANDLE()) 
			or die "Could not init input Console: $!\n";

	#get some window and buffer information
#	my($wLeft, $wTop, $wRight, $wBottom) = $out_con->Window();
#	my($bCol, $bRow) = $out_con->Size();
	
#	$out_con->Window(1, $wLeft, $bRow - $wBottom - 1, $wRight, $bRow - 1);
#	($left, $out_top, $right, $in_line) = $out_con->Window();
#	$out_bot = $in_line - 1; #one line above the input line
#	$out_line = $in_line;
#	$out_col = $in_pos = $left;
	
#	$out_con->Cursor(0, $in_line);
	$enabled = 1;
	return 1;
}

=item C<stop()>

Stops the input system. The input client process will be terminated
and sockets will be freed.

=cut

sub stop {
	#doesn't need to stop
}

=item C<getInput2($timeout)>

Called any time kore wants to read input from the users

=over 4

=item Options:

=over 4

=item C<$timeout>

< 0 wait forever (fully blocking) until there is input to return
= 0 don't wait, if there is input return it, otherwise return undef
> 0 wait for $timeout seconds for input to arive, return undef if time runs out

=back

=item Returns:

The keyboard data (including newline) as a string, or undef if there's no
keyboard data available or if the input system hasn't been initialized.

=back

=cut

sub getInput2 {
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
	return $msg;
}



=item C<canRead()>

=over 4

=item Returns:

1 if there is keyboard data, 0 if not or if the input system hasn't been initialized.

=back

Checks whether there is keyboard data available. You don't have to use this function.
Just call getInput(0) instead.

=over 4

=item Example:

The following lines are semantically equal:

 Input::canRead() && Input::getInput(0);
 Input::getInput(1);

=back

=cut

sub canRead {
	return undef unless ($enabled);
	return scalar(@input_lines);
}


=item C<Input::getInput($wait)>

=over 4

=item Options:

=over 4

=item C<$wait>

Whether to wait until keyboard data is available.

=back

=item Returns:

The keyboard data (including newline) as a string, or undef if there's no
keyboard data available or if the input system hasn't been initialized.

=back

Reads keyboard data.

=cut

sub getInput {
	return undef unless ($enabled);
	my $timeout = shift;
	my $msg;
	if ($timeout) {
		$msg = getInput2(-1);
	} else {
		$msg = getInput2(0);
	}
	return $msg;
}

=item C<readEvents()>

reads low level events from the input console, for key presses it
updates the console input variables

note: most of this is commented out, it need a cordinated output
system to use the separate input line (meaning output does not
over write your input line)

=cut

sub readEvents {
	local($|) = 1;
	while ($in_con->GetEvents()) {
		my @event = $in_con->Input();
		if (defined($event[0]) && $event[0] == 1 && $event[1]) {
			##Backspace
			if ($event[5] == 8) {
				$in_pos-- if $in_pos > 0;
				substr($input_part, $in_pos, 1, '');
#				$out_con->Scroll(
#					$in_pos, $in_line, $right, $in_line,
#					$in_pos-1, $in_line, ord(' '), $main::ATTR_NORMAL, 
#					$in_pos, $in_line, $right, $in_line,
#				);
#				$out_con->Cursor($in_pos, $in_line);
				print "\010 \010";
			##Enter
			} elsif ($event[5] == 13) {
#				my $ret = $out_con->Scroll(
#					$left, 0, $right, $in_line,
#					0, -1, ord(' '), $main::ATTR_NORMAL, 
#					$left, 0, $right, $in_line
#				);
#				$out_con->Cursor(0, $in_line);
				$in_pos = 0;
				push @input_lines, $input_part;
				$input_part = '';
				print chr $event[5];
			#Other ASCII (+ ISO Latin-*)
			} elsif ($event[5] >= 32 && $event[5] != 127 && $event[5] <= 255) {
#				if ($in_pos < length($input_part)) {
#					$out_con->Scroll(
#						$in_pos, $in_line, $right, $in_line,
#						$in_pos+1, $in_line, ord(' '), $main::ATTR_NORMAL, 
#						$in_pos, $in_line, $right, $in_line,
#					);
#				}
#				$out_con->Cursor($in_pos, $in_line);
#				$out_con->Write(chr($event[5]));
				substr($input_part, $in_pos, 0, chr($event[5]));
				$in_pos++;
				print chr $event[5];
#			} elsif ($event[3] == 33) {
#				__PACKAGE__->print("pgup\n");
#			} elsif ($event[3] == 34) {
#				__PACKAGE__->print("pgdn\n");
			##End
#			} elsif ($event[3] == 35) {
#				$out_con->Cursor($in_pos = length($input_part), $in_line);
			##Home
#			} elsif ($event[3] == 36) {
#				$out_con->Cursor($in_pos = 0, $in_line);
			##Left Arrow
#			} elsif ($event[3] == 37) {
#				$in_pos--;
#				$out_con->Cursor($in_pos, $in_line);
			##Up Arrow
#			} elsif ($event[3] == 38) {
#				__PACKAGE__->print("up key\n");
			##Right Arrow
#			} elsif ($event[3] == 39) {
#				$in_pos++;
#				$out_con->Cursor($in_pos, $in_line);
			##Down Arrow
#			} elsif ($event[3] == 40) {
#				__PACKAGE__->print("down key\n");
			##Insert
#			} elsif ($event[3] == 45) {
#				__PACKAGE__->print("insert\n");
			##Delete
#			} elsif ($event[3] == 46) {
#				substr($input_part, $in_pos, 1, '');
#				$out_con->Scroll(
#					$in_pos+1, $in_line, $right, $in_line,
#					$in_pos, $in_line, ord(' '), $main::ATTR_NORMAL, 
#					$in_pos+1, $in_line, $right, $in_line,
#				);
			##F1-F12
#			} elsif ($event[3] >= 112 && $event[3] <= 123) {
#				__PACKAGE__->print("F" . ($event[3] - 111) . "\n");
#			} else {
#				__PACKAGE__->print(join '-', @event, "\n");
			}
#		} else {
#			__PACKAGE__->print(join '-', @event, "\n");
		}
	}	
}

=item AUTHORS

James Morgan <ventatsu-ok@deadlode.com>

=item COPYRIGHT

Copyright (c) 2004 James Morgan 

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut

1 #end of module