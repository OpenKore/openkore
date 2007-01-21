#!/usr/bin/env perl
#########################################################################
#  OpenKore - Web Start
#  Copyright (c) 2006 OpenKore Development Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
use strict;
use FindBin qw($RealBin);
use lib "$RealBin/..";
use lib "$RealBin/../deps";
use lib "$RealBin";
use constant DEBUG => 0;

BEGIN {
	print "Starting OpenKore, please wait...\n";
}

sub parseArguments {
	import Utils::Exceptions;
	eval {
		if (!Settings::parseArguments()) {
			print $Settings::usageText;
			exit 1;
		}
	};
	if (my $e = caught('IOException', 'ArgumentException')) {
		print "Error: $e\n";
		if ($e->isa('ArgumentException')) {
			print $Settings::usageText;
		}
		exit 1;
	} elsif ($@) {
		die $@;
	}
}

sub __start {
	chdir(File::Spec->catfile($RealBin, "..", ".."));

	if (@ARGV == 0) {
		require Settings;
		parseArguments();
		Settings::loadSysConfig();

		require WebstartServer;
		use Time::HiRes qw(time sleep);

		my $server;
		our $timeout = time;

		if (DEBUG || $^O ne 'MSWin32') {
			$server = new WebstartServer(2894);
			print "Please go to http://localhost:" . $server->getPort() . "\n";
		} else {
			require Utils::Win32;
			Utils::Win32::setConsoleTitle("OpenKore");
			$server = new WebstartServer();
			my $url = "http://localhost:" . $server->getPort();
			if (!Utils::Win32::ShellExecute(0, undef, $url)) {
				print STDERR "Unable to launch a web browser.\n";
				print STDERR "Please open your web browser and go to: $url\n";
			} else {
				print "Launching web browser...\n";
			}
		}

		while (1) {
			$server->iterate;
			sleep 0.1;
			if (time - $timeout > 60) {
				# Exit after 60 seconds of inactivity.
				exit;
			}
		}

	} else {
		require Utils::PerlLauncher;
		my $launcher = new PerlLauncher(undef, "openkore.pl", @ARGV);
		if ($^O eq 'MSWin32') {
			eval 'use Win32::Console; Win32::Console->new(STD_OUTPUT_HANDLE)->Free();';
			$launcher->launch(1);
		} else {
			$launcher->launch(0);
			while ($launcher->check()) {
				sleep 0.5;
			}
			exit $launcher->getExitCode();
		}
	}
}

__start() unless defined $ENV{INTERPRETER};
