#########################################################################
#  OpenKore - User interface system
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
# MODULE DESCRIPTION: User interface system
#
# This module provides functions for controlling Kore's user interface.
#
# The interface system has several implementations for different platforms.
# This module glues them all together under one interface.

package Interface;

use strict;
use warnings;
no warnings 'redefine';
use Exporter;
use base qw(Exporter);
use Time::HiRes qw(usleep);

use Globals qw(%config $quit);
use Modules;


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
	Modules::register("Interface::$new_if_name");
	undef $self;
	return $new_interface;
}

##
# $interface->mainLoop()
#
# Enter the interface's main loop.
sub mainLoop {
	my $self = shift;
	while (!$quit) {
		usleep($config{sleepTime} || 1);
		$self->iterate();
		main::mainLoop();
	}
}

##
# $interface->iterate()
#
# Process messages in the user interface message queue.
# In other words: make sure the user interface updates itself
# (redraw controls when necessary, etc.).
sub iterate {
	# Do nothing; this is a dummy parent class
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
# $interface->beep()
# 
# Emit a beep on the available audio device.
sub beep {
	# Do nothing; this is a dummy parent class
}

##
# $interface->title([title])
#
# If $title is given, set the interface's window's title to $title.
# If not given, returns the current window title.
sub title {
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
# $interface->errorDialog(message, [fatal = 1])
# message: The error message to display.
# fatal: Indicate that this is a fatal error (meaning that the application will
#        exit after this dialog is closed). If set, the console interfaces
#        will warn the user that the app is about to exit.
#
# Display an error dialog. This function blocks until the user has closed the dialog.
#
# Consider using Log::error() if your message is not a fatal error, because Log::error()
# does not require any user interaction.
sub errorDialog {
	my $self = shift;
	my $message = shift;
	my $fatal = shift;
	$fatal = 1 unless defined $fatal;

	$self->writeOutput("error", "$message\n");
	if ($fatal) {
		$self->writeOutput("message", "Press ENTER to exit this program.\n")
	} else {
		$self->writeOutput("message", "Press ENTER to continue...\n")
	}
	$self->getInput(-1);
}


1 #end of module
