=pod

=head1 NAME 

Input::Other

=head1 DESCRIPTION

Functions to support asyncronous input on MS Windows computers

=cut

package Input::Other;

use strict;
use warnings;
use base qw/Exporter/;

use IO::Select;

our @EXPORT = qw(&start &stop &canRead &getInput $enabled);
our $select;
our $enabled;

=head1 FUNCTIONS

=over 4

=item C<start()>

Initializes the input system. You must call this function to be able
to use the input system.

=cut

sub start {
	return undef if ($enabled);
	$select = IO::Select->new(\*STDIN);
	$enabled = 1;
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
	my $timeout = shift;
	my $msg;
	if ($timeout < 0) {
		$msg = <STDIN> until defined($msg) && $msg ne "\n";
	} elsif ($timeout > 0) {
		
	} else {
		if ($select->can_read(0.00)) {
			$msg = <STDIN>;
		}
	}
	$msg =~ y/\r\n//d if defined $msg;
	undef $msg if (defined $msg && $msg eq "");
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
	return $select->can_read(0.00);
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
	my $block = shift;
	my $msg;
	if ($block) {
		$msg = getInput2(-1);
	} else {
		$msg = getInput2(0);
	}
	return $msg;
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
