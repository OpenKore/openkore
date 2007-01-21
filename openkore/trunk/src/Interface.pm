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
use Time::HiRes qw(usleep);
use encoding 'utf8';

use Globals qw(%config $quit);
use Modules;
use Translation qw(T TF);


##
# $interface->switchInterface(new_interface, die)
# new_interface: The name of the interface to be swiched to.
# die: Whether to die if we fail to load the new interface.
# Returns: The newly created interface object on success, or the previous
#          interface object on failure.
#
# Changes the interface being used by Kore.
# The default method may be overridden by an Interface that needs to do special
# work when changing to another interface.
sub switchInterface {
	my $self = shift;
	my $new_if_name = shift;
	my $die = shift;

	eval "use Interface::$new_if_name;";
	if ($@) {
		die $@ if ($die);
		Log::error(Translation::TF("Failed to load %s: %s\n", $new_if_name, $@));
		return $self;
	}

	my $new_interface = eval "new Interface::$new_if_name;";
	if (!defined($new_interface) || $@) {
		die $@ if ($die);
		Log::error(Translation::TF("Failed to create %s: %s\n", $new_if_name, $@));
		return $self;
	}
	Modules::register("Interface::$new_if_name");
	undef $self if ($self);
	return $new_interface;
}

##
# void $interface->mainLoop()
#
# Enter the interface's main loop.
sub mainLoop {
	my $self = shift;
	while (!$quit) {
		usleep($config{sleepTime} || 10000);
		$self->iterate();
		main::mainLoop();
	}
}

##
# void $interface->iterate()
#
# Process messages in the user interface message queue.
# In other words: make sure the user interface updates itself
# (redraw controls when necessary, etc.).
sub iterate {
	# Do nothing; this is a dummy parent class
}

##
# String $interface->getInput(float timeout)
# timeout: Number of second to wait until keyboard data is available. 
#          Negative numbers will wait forever, 0 will not wait at all.
# Returns: The keyboard data (excluding newline), or undef if there's no
#          keyboard data available.
#
# Reads keyboard data.
sub getInput {
	# Do nothing; this is a dummy parent class
}

##
# String $interface->askInput(String message, boolean cancelable = true)
# message: The message to display when asking for input.
# cancelable: Whether the user is allowed to enter nothing.
# Returns: The user input, or undef if the user cancelled.
# Requires: defined($message)
#
# Ask the user to enter a one-line input text.
# In GUIs this will be displayed as a dialog.
sub askInput {
	my ($self, $message, $cancelable) = @_;
	while (1) {
		$self->writeOutput("message", $message, "input");
		my $result = $self->getInput(-1);
		if (!defined($result) || $result eq '') {
			if ($cancelable || !exists($_[2])) {
				return undef;
			}
		} else {
			return $result;
		}
	}
}

##
# String $interface->askPassword(String message, boolean cancelable = true)
# message: The message to display when asking for a password.
# cancelable: Whether the user is allowed to enter nothing.
# Returns: The password, or undef if the user cancelled.
# Requires: defined($message)
#
# Ask the user to enter a password.
# In GUIs this will be displayed as a dialog.
sub askPassword {
	my ($self, $message) = @_;
	my $cancelable = !exists($_[2]) || $_[2];
	while (1) {
		$self->writeOutput("message", $message, "input");
		my $result = $self->getInput(-9);
		if (!defined($result) || $result eq '') {
			if ($cancelable) {
				return undef;
			}
		} else {
			return $result;
		}
	}
}

##
# int $interface->showMenu(String title, String message, Array<String>* choices, boolean cancelable = true)
# title: The title to display when presenting the choices to the user.
# message: The message to display while asking the user to make a choice.
# choices: The possible choices.
# cancelable: Whether the user is allowed to not choose.
# Returns: The index of the chosen item, or -1 if the user cancelled.
# Requires:
#     defined($title)
#     defined($message)
#     defined($choices)
#     for all $k in @{$choices}: defined($k)
# Ensures: -1 <= result < @{$choices}
#
# Ask the user to choose an item from a menu of choices.
sub showMenu {
	my ($self, $title, $message, $choices) = @_;
	my $cancelable = !exists($_[3]) || $_[3];

	my $maxNumberLength = length(@{$choices} + 1);
	my $format = "%-" . $maxNumberLength . "s   %-s\n";
	my $output = sprintf($format, "#", T("Choice"));

	my $i = 0;
	foreach my $item (@{$choices}) {
		$output .= sprintf($format, $i, $item);
		$i++;
	}
	$self->writeOutput("message", "-------- $title --------\n", "menu");
	$self->writeOutput("message", $output, "menu");

	while (1) {
		my $choice = $self->askInput($message, $cancelable);
		if (!defined($choice)) {
			return -1;
		} elsif ($choice !~ /^\d+$/ || $choice < 0 || $choice >= @{$choices}) {
			$self->writeOutput("error", TF("'%s' is not a valid choice number.\n", $choice), "default");
		} else {
			return $choice;
		}
	}
}

##
# void $interface->writeOutput(String type, String message, String domain)
# Requires: defined($type) && defined($message) && defined($domain)
# 
# Writes a message to the interface's console.
# This method should not be used directly, use Log::message() instead.
sub writeOutput {
	# Do nothing; this is a dummy parent class
}

##
# void $interface->beep()
# 
# Emit a beep on the available audio device.
sub beep {
	# Do nothing; this is a dummy parent class
}

##
# String $interface->title([String title])
#
# If $title is given, set the interface's window's title to $title.
# If not given, returns the current window title.
sub title {
	# Do nothing; this is a dummy parent class
}

##
# void $interface->errorDialog(String message, [boolean fatal = true])
# message: The error message to display.
# fatal: Indicate that this is a fatal error (meaning that the application will
#        exit after this dialog is closed). If set, the console interfaces
#        will warn the user that the app is about to exit.
# Requires: defined($message)
#
# Display an error dialog. This function blocks until the user has closed the
# dialog.
#
# Consider using Log::error() if your message is not a fatal error, because
# Log::error() does not require any user interaction.
sub errorDialog {
	my $self = shift;
	my $message = shift;
	my $fatal = shift;
	$fatal = 1 unless defined $fatal;

	$self->writeOutput("error", "$message\n", "error");
	if ($fatal) {
		$self->writeOutput("message", Translation::T("Press ENTER to exit this program.\n"), "console")
	} else {
		$self->writeOutput("message", Translation::T("Press ENTER to continue...\n"), "console")
	}
	$self->getInput(-1);
}


1 #end of module
