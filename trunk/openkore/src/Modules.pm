#########################################################################
#OpenKore - Module Support Code
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.  Basically, this means that you're allowed to
#  modify and distribute this software. However, if you distribute
#  modified versions, you MUST also distribute the source code.  See
#  http://www.gnu.org/licenses/gpl.html for the full license.
#
#
#
#  $Revision$ $Id$
#
#########################################################################
## MODULE DESCRIPTION: Module support system
#
# The OpenKore source code is split into various files: openkore.pl,
# functions.pl, and some .pm files. These .pm files are modules: source
# code that's part of OpenKore.  Modules implement various subsystems.
#
# One of the features of OpenKore is "dynamic code reloading". This
# means that if you've modified source code, you can reload it at
# runtime, without restarting Kore.
#
# This module, Modules.pm, is what makes it possible. It "glues" all the
# other modules together. openkore.pl registers all the other modules,
# and this modules will save that list in memory.
#
# Modules must put initialization code in a function called MODINIT().
# This function is called at startup. Initialization code must not be
# put elsewhere, because that code will be called again every time the
# module is reloaded, and will overwrite existing values of variables.
# MODINIT() is only called once at startup (during registration), and is
# never called again.

package Modules;

use strict;
no strict 'refs';
use Exporter;
use Config;
use base qw(Exporter);

our @modules;
our @EXPORT_OK = qw(&register &reload &checkSyntax @modules);


##
# Modules::register(names...)
# names: the names of the modules to register.
#
# Register modules. Registered modules can be dynamically reloaded.
# Upon registration, the module's MODINIT() function is called.
# A module should only be registered once (at Kore's startup).
#
# Example:
# Modules::register("Log", "Input");  # Registers Log.pm and Input.pm
sub register {
	foreach (@_) {
		my $mod = $_;
		$mod =~ s/::/\//g;
		next if (! -f "$mod.pm");

		# Call the module's MODINIT() function when it's registered
		#my $initFunc = "${_}::MODINIT";
		#$initFunc->() if (defined(&{$initFunc}));
		# The above doesn't work in Win32 (??) so maybe this'll work:
		eval "${_}::MODINIT();";

		push @modules, $_;
	}
}

##
# Modules::reload(name, regex)
# name: Name of the module to reload.
# regex: Treat $name as a regular expression. All modules whose name matches
#        this regexp will be reloaded. The match is case-insensitive.
#
# Similar to the "reload" command you type in the console. The difference
# is that this function reloads source code, not config files.
sub reload {
	my ($arg, $regex) = @_;

	sub reload2 {
		my ($name, $regex) = @_;
		foreach (@modules) {
			my ($match, $mod);

			$mod = $_;
			if ($name eq "all") {
				$match = 1;
			} elsif ($regex) {
				$match = ($mod =~ /$name/i);
			} else {
				$match = (lc($mod) eq lc($name));
			}
			next if (!$match);

			$mod .= '.pm';
			$mod =~ s/::/\//g;
			if (! -f $mod) {
				print "Error: file $mod not found\n";
			} elsif (checkSyntax($mod)) {
				print "Reloading $mod...\n";
				if (!do $mod || $@) {
					print "Unable to reload $mod\n";
					print "$@\n" if ($@);
				}
			}
		}
	}

	if ($regex) {
		my @names = split(/ +/, $arg);
		foreach my $name (@names) {
			reload2($name, 1);
		}
	} else {
		reload2($arg, 0);
	}
}

##
# Modules::checkSyntax(file)
# file: Filename of a Perl source file.
# Returns: 1 if syntax is correct, 0 if syntax contains errors, -1 if unable to run the Perl interpreter.
#
# Checks whether $file's syntax is correct, by running 'perl -c'.
sub checkSyntax {
	my $filename = shift;

	if (-f $Config{'perlpath'}) {
		system($Config{'perlpath'}, '-c', $filename);
		if ($? == -1) {
			print "Error: failed to execute $Config{'perlpath'}\n";
			return -1;
		} elsif ($? & 127) {
			print "Error: $Config{'perlpath'} exited abnormally\n";
			return -1;
		} elsif (($? >> 8) == 0) {
			return 1;
		} else {
			print "Error: $filename contains syntax errors.\n";
			return 0;
		}
	}
	return 2;
}

return 1;
