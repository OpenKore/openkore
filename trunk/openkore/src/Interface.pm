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
# This module provides the public methods to the interface system.
#
# The interface system has several implementations for different platforms.
# This module glues them all together under one interface.

package Interface;

use strict;
use warnings;
no warnings 'redefine';
use Exporter;
use base qw(Exporter);

our $interface;
our @EXPORT = qw($interface);


sub new {
	# Default interface until we switch to a new one
	use Interface::Startup;
	return new Interface::Startup;
}

END {
	undef $interface if defined $interface;
}

##
# $interface->switchInterface(new_interface, die)
# new_interface: The name of the interface to be swiched to.
# die: Whether to die if we fail to load the new interface.
# Returns: The newly created interface object on success, or the previous
#          interface object on failure.
#
# Changes the interface being used by Kore.
# The default method may be overridden by an Interface that needs to do special work
# when changing to another interface.
sub switchInterface {
	my $self = shift;
	my $new_if_name = shift;
	my $die = shift;

	eval "use Interface::$new_if_name;";
	if ($@) {
		die $@ if ($die);
		Log::error("Failed to load $new_if_name: $@\n");
		return $self;
	}

	my $new_interface = eval "new Interface::$new_if_name;";
	if (!defined($new_interface) || $@) {
		die $@ if ($die);
		Log::error("Failed to create $new_if_name: $@\n");
		return $self;
	}
	undef $self;
	return $new_interface;
}

##
# $interface->getInput(timeout)
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
# $interface->writeOutput(type, message, domain)
# 
# Writes a message to the interface's console.
# This method should not be used directly, use Log::message() instead.
sub writeOutput {
	# Do nothing; this is a dummy parent class
}

##
# $interface->displayUsage(text)
# text: The 'usage' text to display.
#
# Display a 'usage' text. This method is only used for displaying the usage text
# when the user runs the "openkore --help" command in the operating system's commandline.
sub displayUsage {
	my $self = shift;
	my $text = shift;
	$self->writeOutput("message", $text, "usage");
}

##
# $interface->errorDialog(message)
# message: The error message to display.
#
# Display an error dialog.
sub errorDialog {
	my $self = shift;
	my $message = shift;
	$self->writeOutput("error", "$message\n");
}


1 #end of module
