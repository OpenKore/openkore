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

use Modules;

our $use_curses = 0; #hasn't been writen yet

# This will load proper OS module at run time
sub MODINIT {
	if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
		eval {
			require Interface::Console::Win32;
			unshift our(@ISA), 'Interface::Console::Win32';
		};
		die $@ if $@; #rethrow errors
		Modules::register("Interface::Console::Win32");
	} else {
		if ($use_curses) {
			eval {
				require Interface::Console::Curses;
				unshift our(@ISA), 'Interface::Console::Curses';
			};
			#if that didn't work it's probably because curses is missing
			#that's ok, just try to use the IO::Select method instead
			#we may want to warn, but we may not, but this isn't OpenKore,
			#so we don't have nice logging
			if ($@) {
				warn $@;
			} else {
				#Modules::register("Interface::Console::Curses");
			}
		}
		if (!$use_curses || $@) {
			eval {
				require Interface::Console::Other;
				unshift our(@ISA), 'Interface::Console::Other';
			};
			if ($@) {
				#rethrow errors
				die $@;
			} else {
				#Modules::register("Interface::Console::Other");
			}
		}
	}
}

MODINIT();

END {
	Interface->stop();
}

1 #end of module
