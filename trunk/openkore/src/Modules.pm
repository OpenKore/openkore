#########################################################################
#  OpenKore - Module Support Code
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.  Basically, this means that you're allowed to
#  modify and distribute this software. However, if you distribute
#  modified versions, you MUST also distribute the source code.  See
#  http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
##
# MODULE DESCRIPTION: Module support system
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
use warnings;
use Exporter;
use Config;
use Log qw(error warning message);
use base qw(Exporter);

our @modules;
our @queue;


##
# Modules::register(names...)
# names: the names of the modules to register.
#
# Register modules. Registered modules can be dynamically reloaded.
# Upon registration, the module's MODINIT() function is called.
# A module should only be registered once (at Kore's startup).
#
# Example:
# Modules::register("Log", "Interface");  # Registers Log.pm and Interface.pm
sub register {
	foreach (@_) {
		my $mod = $_;
		$mod =~ s/::/\//g;

		eval "${_}::MODINIT();";
		warning $@ if ($@ && !($@ =~ /^Undefined subroutine /));

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
#
# Note that this function does not reload the module(s) immediately.
# Instead, it puts the name of the module in a queue.
# All files in this queue are reloaded when Modules::doReload() is called.
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
			push @queue, $mod;
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
# Modules::reloadFile(filename)
#
# Executes "do $filename" if $filename exists and does not contain syntax
# errors. This function is used internally by Modules::doReload(), do not
# use this directly.
sub reloadFile {
	my $filename = shift;

	my $found = 0;
	for my $path (@INC) {
		if (-f "$path/$filename") {
			$found = 1;
			last;
		}
	}
	if (!$found) {
		error("Unable to reload code: $filename not found\n");
		return;
	}
	if (!-f $Config{'perlpath'}) {
		error("Cannot find Perl interpreter $Config{'perlpath'}\n");
		return;
	}

	message "Checking $filename for errors...\n", "info";
	system($Config{'perlpath'}, '-c', $filename);
	if ($? == -1) {
		error("Failed to execute $Config{'perlpath'}\n");
		return;
	} elsif ($? & 127) {
		error("$Config{'perlpath'} exited abnormally\n");
		return;
	} elsif (($? >> 8) == 0) {
		message("$filename passed syntax check.\n", "success");
	} else {
		error("$filename contains syntax errors.\n");
		return;
	}

	message("Reloading $filename...\n", "info");
	{
		package main;
		if (!do $filename || $@) {
			error("Unable to reload $filename\n");
			error("$@\n", "syntax", 1) if ($@);
		}
	}
	message("Reloaded.\n", "info");
}

##
# Modules::doReload()
#
# Reload all modules in the reload queue. This function is meant to be run in
# Kore's main loop.
# Do not call this function directly in any other places.
#
# See also: Modules::reload()
sub doReload {
	foreach my $mod (@queue) {
		reloadFile($mod);
	}
	undef @queue;
}

return 1;
