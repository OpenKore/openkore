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
no warnings 'redefine';
use Exporter;
use base qw(Exporter);
use Config;
use FindBin;

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
		if ($@ && !($@ =~ /^Undefined subroutine /)) {
			# The Log module may not be available at this time
			if (defined &Log::warning) {
				Log::warning($@);
			} else {
				print $@;
			}
		}
		undef $@;

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
	my $err = (defined &Log::error) ?
		sub { Log::error(@_); } :
		sub { print STDERR $_[0]; };
	my $msg = (defined &Log::message) ?
		sub { Log::message(@_); } :
		sub { print STDERR $_[0]; };
	my $path;
	for my $x (@INC) {
		if (-f "$x/$filename") {
			$found = 1;
			$path = $x;
			last;
		}
	}

	if (!$found) {
		$err->(Translation::TF("Unable to reload code: %s not found\n", $filename));
		return;
	}
	if (!-f $Config{'perlpath'}) {
		$err->(Translation::TF("Cannot find Perl interpreter %s\n", $Config{'perlpath'}));
		return;
	}

	$msg->(Translation::TF("Checking %s for errors...\n", $filename), "info");

	system($Config{perlpath}, '-I', "$FindBin::RealBin/src",,
		'-I', "$FindBin::RealBin/src/deps", '-c', "$path/$filename");
	if ($? == -1) {
		$err->(Translation::TF("Failed to execute %s\n", $Config{'perlpath'}));
		return;
	} elsif ($? & 127) {
		$err->(Translation::TF("%s exited abnormally\n", $Config{perlpath}));
		return;
	} elsif (($? >> 8) == 0) {
		$msg->(Translation::TF("%s passed syntax check.\n", $filename), "success");
	} else {
		$err->(Translation::TF("%s contains syntax errors.\n", $filename));
		return;
	}

	# Translation Comment: Reloading a Kore's module
	$msg->(Translation::TF("Reloading %s...\n", $filename), "info");
	{
		package main;
		if (!do $filename || $@) {
			# Translation Comment: Unable to Reload a Kore's module
			error(Translation::TF("Unable to reload %s\n", $filename));
			error("$@\n", "syntax", 1) if ($@);
		}
	}
	# Translation Comment: Kore's module reloaded successfully
	$msg->(Translation::T("Reloaded.\n"), "info");
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
