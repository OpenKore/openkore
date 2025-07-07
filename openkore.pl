#!/usr/bin/env perl
#########################################################################
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#########################################################################

package main;
use strict;
use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";
use lib "$RealBin/src/deps";

use Time::HiRes qw(time usleep);
use Carp::Assert;


sub __start {
	use ErrorHandler;
	use XSTools;
	use Utils::Rijndael;
	srand();


	##### BASIC INITIALIZATION #####

	use Translation;
	use Settings qw(%sys);
	use Utils::Exceptions;

	eval "use OpenKoreMod;";
	undef $@;
	parseArguments();
	Settings::loadSysConfig();
	Translation::initDefault($sys{locale});

	use Globals;
	use Interface;
	$interface = Interface->loadInterface($Settings::interface);
	$interface->title($Settings::NAME);
	selfCheck();

	##### LOAD OPENKORE MODULES #####

	use Utils::PathFinding;
	require Utils::Win32 if ($^O eq 'MSWin32');
	require 'functions.pl';

	use Modules;
	use Log;
	use Utils;
	use Plugins;
	use FileParsers;
	use Misc;
	use Network::Receive;
	use Network::Send ();
	use Commands;
	use AI;
	use AI::CoreLogic;
	use AI::Attack;
	use Actor;
	use Actor::Player;
	use Actor::Monster;
	use Actor::You;
	use Actor::Party;
	use Actor::Portal;
	use Actor::NPC;
	use Actor::Pet;
	use Actor::Unknown;
	use ActorList;
	use Interface;
	use ChatQueue;
	use TaskManager;
	use Task;
	use Task::WithSubtask;
	use Task::TalkNPC;
	use Utils::Benchmark;
	use Utils::HttpReader;
	use Utils::Whirlpool;
	use Poseidon::Client;
	Modules::register(qw/Utils FileParsers
		Network::Receive Network::Send Misc AI AI::CoreLogic
		AI::Attack AI::Slave AI::Slave::Homunculus AI::Slave::Mercenary
		ChatQueue Actor Actor::Player Actor::Monster Actor::You
		Actor::Party Actor::Unknown Actor::Item Match Utils::Benchmark/);


	##### MAIN LOOP #####
	# Note: Further initialization is done in the mainLoop() function in functions.pl.

	Benchmark::begin("Real time") if DEBUG;
	$interface->mainLoop();
	Benchmark::end("Real time") if DEBUG;

	main::shutdown();
}

# Parse command-line arguments.
sub parseArguments {
	eval {
		Settings::parseArguments();
		if ($Settings::options{version}) {
			print "$Settings::versionText\n";
			exit 0;
		}
	};
	if (my $e = caught('IOException', 'ArgumentException')) {
		print "Error: $e\n";
		if ($e->isa('ArgumentException')) {
			print Settings::getUsageText();
		}
		exit 1;
	} elsif ($@) {
		die $@;
	}
}

# Make sure there aren't any unhandled arguments left.
sub checkEmptyArguments {
	if ( $Settings::options{help} ) {
		print Settings::getUsageText();
		exit 0;
	}
	eval {
		use Getopt::Long;
		local $SIG{__WARN__} = sub { ArgumentException->throw( $_[0] ); };
		# Turn off the "pass_through" option so any remaining options will be considered an error.
		Getopt::Long::Configure( 'default' );
		GetOptions();
	};
	if ( my $e = caught( 'IOException', 'ArgumentException' ) ) {
		print "Error: $e\n";
		if ( $e->isa( 'ArgumentException' ) ) {
			print Settings::getUsageText();
		}
		exit 1;
	} elsif ( $@ ) {
		die $@;
	}
}

# Perform some self-checks to ensure everything is OK.
# Precondition: $interface is initialized.
sub selfCheck {
	use Globals qw($interface);

	if ($^O eq 'MSWin32' && !defined(getprotobyname("tcp"))) {
		$interface->errorDialog(TF(
			"Your Windows TCP/IP stack is broken. Please read\n" .
			"  %s\n" .
			"to learn how to solve this.",
			"https://openkore.com/wiki/Frequently_Asked_Questions#Your_Windows_TCP.2FIP_stack_is_broken"));
		exit 1;
	}

	# If Misc.pm is in the same folder as openkore.pl, then the
	# user is still using the old (pre-CVS cleanup) source tree.
	# So bail out to prevent weird errors.
	if (-f "$RealBin/Misc.pm") {
		$interface->errorDialog(T("You have old files in the OpenKore folder, which may cause conflicts.\n" .
			"Please delete your entire OpenKore source folder, and redownload everything."));
		exit 1;
	}

	if (!defined &XSTools::majorVersion) {
		$interface->errorDialog(TF("Your version of the XSTools library is too old.\n" .
			"Please upgrade it from %s", "https://misc.openkore.com/"));
		exit 1;
	} elsif (XSTools::majorVersion() != 5) {
		my $error;
		if (defined $ENV{INTERPRETER}) {
			$error = TF("Your version of (wx)start.exe is incompatible.\n" .
				"Please upgrade it from %s", "https://misc.openkore.com/");
		} else {
			$error = TF("Your version of XSTools library is incompatible.\n" .
				"Please upgrade it from %s", "https://misc.openkore.com/");
		}
		$interface->errorDialog($error);
		exit 1;
	} elsif (XSTools::minorVersion() < 8) {
		my $error;
		if (defined $ENV{INTERPRETER}) {
			$error = TF("Your version of (wx)start.exe is too old.\n" .
				"Please upgrade it from %s", "https://misc.openkore.com/")
		} else {
			$error = TF("Your version of the XSTools library is too old.\n" .
				"Please upgrade it from %s", "https://misc.openkore.com/")
		}
		$interface->errorDialog($error);
		exit 1;
	}
}

sub shutdown {
	Plugins::unloadAll();
	if ($bus) {
		$bus->close();
		undef $bus;
	}
	# Translation Comment: Kore's exit message
	Log::message($Settings::versionText);

	if (DEBUG && open(F, ">:utf8", "benchmark-results.txt")) {
		print F Benchmark::results("mainLoop");
		close F;
		print "Benchmark results saved to benchmark-results.txt\n";
	}
		$interface->errorDialog(T("Bye!\n")) if $config{dcPause};
}

if (!defined($ENV{INTERPRETER}) && !$ENV{NO_AUTOSTART}) {
	__start();
}

1;
