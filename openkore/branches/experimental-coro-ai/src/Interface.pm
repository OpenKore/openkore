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
# MODULE DESCRIPTION: User interface system.
#
# In OpenKore, the user interface code is seperated from the core code.
# Each user interface is implemented in a class. The Interface class is an
# abstract base class for all OpenKore user interface classes.

package Interface;

use strict;
use warnings;
no warnings 'redefine';
use threads qw(yield);
use Time::HiRes qw(usleep);
# use encoding 'utf8'; # Makes unknown Threading Bugs.

use Globals qw(%config $command $quit);
use Commands;
use Log qw(message warning error debug);
use Translation qw(T TF);
use Utils::Exceptions;
use Modules 'register';


##
# Interface->loadInterface(String name)
# name: The class name of the interface to load, excluding the 'Interface::' prefix.
# Returns: The newly created interface object.
#
# Create a new interface of the specified class.
#
# Throws ModuleLoadException if the interface's Perl module cannot be loaded.
# Throws ClassCreateException if the interface class cannot be created.
sub loadInterface {
	my ($self, $name) = @_;

	my $module = "Interface::$name";
	eval "use $module;";
	if ($@) {
		ModuleLoadException->throw(error => "Cannot load interface $module. Error:\n$@",
			module => $module);
	}

	my $constructor = UNIVERSAL::can($module, 'new');
	if (!$constructor) {
		ClassCreateException->throw(error => "Class $module has no constructor.", class => $module);
	}

	my $interface = $constructor->($module);
	Modules::register($module);
	return $interface;
}

##
# void $interface->mainLoop()
#
# Enter the interface's main loop.
sub mainLoop {
	my $self = shift;
	while (!$quit) {
		{ # Just make Unlock quicker.
			lock ($self);
			$self->iterate();
			my $input;
			if (defined($input = $self->getInput(0))) {
				$self->parseInput($input);
			}
			$command->check_timed_out_cmd();
		}
		yield();
	}
}

##
# void $interface->parseInput()
#
# Parse User Input.
sub parseInput {
	my $self = shift;
	my $input = shift;
	my ($hook, $msg);
	# We don't have networking yet.
	# my $printType = shift if ($net && $net->clientAlive); 

	# debug("Input: $input\n", "parseInput", 2);

	# if ($printType) {
		my $hookOutput = sub {
			my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
			$msg .= $message if ($type ne 'debug' && $level <= $globalVerbosity);
		};
		# $hook = Log::addHook($hookOutput);
		# This cause Console to Write Twice. Write to Console, if Interface is not Console.
		# $self->writeOutput("console", "$input\n");
	# }
	# $XKore_dontRedirect = 1;

	# We don't have Command Interface yet.
	$command->parse($input);

	# if ($printType) {
		Log::delHook($hook);
	#	if (defined $msg && $net->getState() == Network::IN_GAME && $config{XKore_silent}) {
	#		$msg =~ s/\n*$//s;
	#		$msg =~ s/\n/\\n/g;
	#		sendMessage($messageSender, "k", $msg);
	#	}
	#}
	#$XKore_dontRedirect = 0;
}

##
# void $interface->iterate()
#
# Process messages in the user interface message queue.
# In other words: make sure the user interface updates itself.
# (redraw controls when necessary, etc.)
sub iterate {
}

##
# String $interface->getInput(float timeout)
# timeout: Number of second to wait until keyboard data is available. 
#          Negative numbers will wait forever, 0 will not wait at all.
# Returns: The keyboard data (excluding newline), or undef if there's no
#          keyboard data available.
#
# Reads keyboard data.

##
# String $interface->query(String message, options...)
# message: A message to display when asking for input.
# Returns: The user input, or undef if the user cancelled.
# Requires: defined($message)
#
# Ask the user to enter a one-line input text.
# The following options are allowed:
# `l
# - cancelable - Whether the user is allowed to enter nothing. If this is set to true,
#       then the user will be asked the same thing over and over until he
#       replies with a non-empty input. The default is true.
# - title - A title to display in the query dialog. The default is "Query".
# - isPassword - Whether this query is a password query. The default is false.
# `l`
sub query {
	my $self = shift;
	my $message = shift;
	my %args = @_;

	$args{title} = "Query" if (!defined $args{title});
	$args{cancelable} = 1 if (!exists $args{cancelable});

	my $title = "------------ $args{title} ------------";
	my $footer = '-' x length($title);
	$message =~ s/\n+$//s;
	$message = "$title\n$message\n$footer\n";

	while (1) {
		$self->writeOutput("message", $message, "input");
		$self->writeOutput("message", T("Enter your answer: "), "input");
		my $mode = $args{isPassword} ? -9 : -1;
		my $result = $self->getInput($mode);
		if (!defined($result) || $result eq '') {
			if ($args{cancelable}) {
				return undef;
			}
		} else {
			return $result;
		}
	}
}

##
# int $interface->showMenu(String message, Array<String>* choices, options...)
# message: The message to display while asking the user to make a choice.
# choices: The possible choices.
# Returns: The index of the chosen item, or -1 if the user cancelled.
# Requires:
#     defined($message)
#     defined($choices)
#     for all $k in @{$choices}: defined($k)
# Ensures: -1 <= result < @{$choices}
#
# Ask the user to choose an item from a menu of choices.
#
# The following options are allowed:
# `l
# - title - The title to display when presenting the choices to the user.
#           The default is 'Menu'.
# - cancelable - Whether the user is allowed to not choose.
#                The default is true.
# `l`
sub showMenu {
	my $self = shift;
	my $message = shift;
	my $choices = shift;
	my %args = @_;

	$args{title} = "Menu" if (!defined $args{title});
	$args{cancelable} = 1 if (!exists $args{cancelable});

	# Create a nicely formatted choice list.
	my $maxNumberLength = length(@{$choices} + 1);
	my $format = "%-" . $maxNumberLength . "s   %-s\n";
	my $output = sprintf($format, "#", T("Choice"));
	my $i = 0;
	foreach my $item (@{$choices}) {
		$output .= sprintf($format, $i, $item);
		$i++;
	}

	$message = "${output}------------------------\n$message";

	while (1) {
		my $choice = $self->query($message,
			cancelable => $args{cancelable},
			title => $args{title});
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
	lock($self);
	$fatal = 1 unless defined $fatal;

	$self->writeOutput("error", "$message\n", "error");
	if ($fatal) {
		$self->writeOutput("message", Translation::T("Press ENTER to exit this program.\n"), "console")
	} else {
		$self->writeOutput("message", Translation::T("Press ENTER to continue...\n"), "console")
	}
	$self->getInput(-1);
	$quit = 1 if ($fatal);
}

1;
