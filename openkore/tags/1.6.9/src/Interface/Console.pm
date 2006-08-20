#########################################################################
#  OpenKore - Console Interface Dynamic Loader
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
# MODULE DESCRIPTION: Console Interface dynamic loader
#
# Loads the apropriate Console Interface for each system at runtime.
# Primarily used to load Interface::Console::Win32 for windows systems and
# Interface::Console::Other for systems that support proper STDIN handles

package Interface::Console;

use strict;
use warnings;
use IO::Socket;
use Interface;
use base qw(Interface);
use Modules;
use Globals;


sub new {
	# Automatically load the correct module for
	# the current operating system

	if ($buildType == 0) {
		# Win32
		eval "use Interface::Console::Win32;";
		die $@ if $@;
		Modules::register("Interface::Console::Win32");
		return new Interface::Console::Win32;
	} else {
		# Linux/Unix
		my $mod = 'Interface::Console::Other';
		my $str = "use $mod;";
		eval ${\$str};
		die $@ if $@;
		Modules::register("$mod");
		return new Interface::Console::Other;
	}
}

sub beep {
	print STDOUT "\a";
	STDOUT->flush;
}


1 #end of module
