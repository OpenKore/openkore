#########################################################################
#  OpenKore - Interface System Front End
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
# MODULE DESCRIPTION: Interface System Front End
#
# Provides the public methods to the interface system. All other parts of
# Kore should stick to these methods and ignore the methods of each
# interface implementation

package Interface;

use strict;
use warnings;
use Exporter;
use base qw(Exporter);
use Interface::Console;

our $interface;
our @EXPORT = qw($interface);


sub new {
	# Default interface until we switch to a new one
	return new Interface::Console;
}

END {
	undef $interface;
}


sub switchInterface {
	my $class = shift;
	my $new_interface = shift;
	eval "use $new_interface;";
	if ($@) {
		if ($interface) {
			$interface->printt('error', "Failed to load $new_interface: $@\n") if $interface->can('printt') or die "Failed to load $new_interface: $@\n";
			return undef;
		} else {
			die $@; #we can't fall back to the old interface
		}
	}
	unless ($new_interface->can('start')) { #checks if the class name and file name match case
		$interface->print("'start' method not found for $new_interface. Check to make sure you typed the package name correctly.\n");
		return undef;
	}
	$interface->stop() if $interface->can('stop');
	if (eval {$new_interface->start($class)}) { #$class should be the old interface
		$interface->free() if $interface->can('free');
	} else {
		my $err_str = "$new_interface failed to start" . ( $@ ? ": $@" :  ', ') . "trying to restart $interface...";
		print STDERR $err_str;
		eval { $interface->start($class) } or die " but it also failed; $@\n";
		$interface->print("$err_str ok\n");
		print STDERR " ok\n";
		return undef;
	}
	$interface = $new_interface;
	return 1;
}


sub start {
	# Do nothing; this is a dummy parent class
}


sub stop {
	# Do nothing; this is a dummy parent class
}


##
# Interface::getInput(timeout)
# timeout: Number of second to wait until keyboard data is available. 
#          Negative numbers will wait forever, 0 will not wait at all.
# Returns: The keyboard data (including newline) as a string, or undef if there's no
#          keyboard data available.
#
# Reads keyboard data.
sub getInput {
	# Do nothing; this is a dummy parent class
}


##
# Interface::writeOutput(type, message, domain)
# 
# Writes a message to the interface's console.
# This method should not be used directly, use Log::message() instead.
sub writeOutput {
	# Do nothing; this is a dummy parent class
}


1 #end of module
