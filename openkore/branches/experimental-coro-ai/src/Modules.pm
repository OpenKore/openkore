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
use Coro;
use warnings;
use Config;
use FindBin;
use File::Spec;

our %modules;
our @queue;


sub import {
	my ($class, $arg) = @_;
	if ($arg && $arg eq 'register') {
		my ($package) = caller();
		register($package);
	}
}

sub getModuleFilename {
	my ($moduleName) = @_;
	my @nameParts = split /::/, $moduleName;
	my $baseName = File::Spec->join(@nameParts) . ".pm";

	foreach my $dir (@INC) {
		my $file = File::Spec->join($dir, $baseName);
		if (-f $file) {
			return $file;
		}
	}
	return undef;
}

sub T {
	if (defined &Translation::T && defined &Translation::_translate) {
		return &Translation::T;
	} else {
		return $_[0];
	}
}

sub TF {
	if (defined &Translation::TF && defined &Translation::T && defined &Translation::_translate) {
		return &Translation::TF;
	} else {
		my $format = shift;
		return sprintf($format, @_);
	}
}

sub error {
	if (defined &Log::error) {
		&Log::error;
	} else {
		print STDERR $_[0];
	}
}

sub message {
	if (defined &Log::message) {
		&Log::message;
	} else {
		print STDERR $_[0];
	}
}

##
# void Modules::register(names...)
# names: the names of the modules to register.
#
# Register modules. Registered modules can be dynamically reloaded.
# Upon registration, the module's MODINIT() function is called.
#
# Nothing will happen on attempts to re-register an already
# registered module.
#
# Example:
# Modules::register("Log", "Interface");  # Registers Log.pm and Interface.pm
sub register {
	no strict 'refs';
	foreach my $module (@_) {
		if (!$modules{$module}) {
			my $func = UNIVERSAL::can($module, 'MODINIT');
			$func->() if ($func);
			$modules{$module} = 1;
		}
	}
}

##
# void Modules::addToReloadQueue(String namepart)
# namepart: A part of the name of a registered Perl module.
#
# All registered Perl module whose name contain $namepart will be put into the reload queue.
# Those modules are actually reloaded when Modules::reloadAllInQueue() is called.
sub addToReloadQueue {
	my ($namepart) = @_;
	my $re = quotemeta $namepart;
	foreach my $module (keys %modules) {
		if ($module =~ /$re/i) {
			my $file = getModuleFilename($module);
			if ($file) {
				push @queue, $file;
			} else {
				error(TF("Unable to reload code: %s not found\n", $file));
			}
		}
	}
}

##
# boolean Modules::checkSyntax(String file)
#
# Check whether the file's syntax is correct.
sub checkSyntax {
	my ($file) = @_;
	my (undef, undef, $baseName) = File::Spec->splitpath($file);
	system($Config{perlpath},
		'-I', "$FindBin::RealBin/src",
		'-I', "$FindBin::RealBin/src/deps",
		'-c', $file);
	if ($? == -1) {
		error(TF("Failed to execute %s\n", $Config{perlpath}));
		return 0;
	} elsif ($? & 127) {
		error(TF("%s exited abnormally\n", $Config{perlpath}));
		return 0;
	} elsif (($? >> 8) == 0) {
		message(TF("%s passed syntax check.\n", $baseName), "success");
		return 1;
	} else {
		error(TF("%s contains syntax errors.\n", $baseName));
		return 0;
	}
}

##
# Modules::reloadFile(String filename)
#
# Executes "do $filename" if $filename exists and does not contain syntax
# errors. This function is used internally by Modules::reloadAllInQueue(), do not
# use this directly.
sub reloadFile {
	my ($filename) = @_;
	my (undef, undef, $baseName) = File::Spec->splitpath($filename);

	if (!-f $Config{perlpath}) {
		error(TF("Cannot find Perl interpreter %s\n", $Config{perlpath}));
		return;
	}

	message(TF("Checking %s for errors...\n", $filename), "info");
	if (checkSyntax($filename)) {
		# Translation Comment: Reloading a Kore's module
		message(TF("Reloading %s...\n", $baseName), "info");
		{
			package main;
			if (!do $filename || $@) {
				# Translation Comment: Unable to Reload a Kore's module
				error(TF("Unable to reload %s\n", $baseName));
				error("$@\n", "syntax", 1) if ($@);
			}
		}
		# Translation Comment: Kore's module reloaded successfully
		message(T("Reloaded.\n"), "success");
	}
}

##
# void Modules::reloadAllInQueue()
#
# Reload all modules in the reload queue. This function is meant to be run in
# Kore's main loop. Do not call this function directly in any other places.
sub reloadAllInQueue {
	while (@queue > 0) {
		my $file = shift @queue;
		reloadFile($file);
	}
}

1;