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
	srand();


	##### BASIC INITIALIZATION #####

	use Translation;
	use Settings qw(%sys);
	use Utils::Exceptions;

	eval "use OpenKoreMod;";
	undef $@;
	parseArguments();
	Settings::loadSysConfig();
	Translation::initDefault(undef, $sys{locale});

	use Globals;
	use Interface;
	$interface = Interface->loadInterface($Settings::default_interface);
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
	use Network::Receive;
	use Network::Send ();
	use Commands;
	use Misc;
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
		AI::Attack AI::Homunculus Skills
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

# Perform some self-checks to ensure everything is OK.
# Precondition: $interface is initialized.
sub selfCheck {
	use Globals qw($interface);

	if ($^O eq 'MSWin32' && !defined(getprotobyname("tcp"))) {
		$interface->errorDialog(TF(
			"Your Windows TCP/IP stack is broken. Please read\n" .
			"  %s\n" .
			"to learn how to solve this.",
			"http://www.visualkore-bot.com/faq.php#tcp"));
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
			"Please read %s", "http://www.openkore.com/aliases/xstools.php"));
		exit 1;
	} elsif (XSTools::majorVersion() != 4) {
		my $error;
		if (defined $ENV{INTERPRETER}) {
			$error = TF("Your version of (wx)start.exe is incompatible.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php");
		} else {
			$error = TF("Your version of XSTools library is incompatible.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php");
		}
		$interface->errorDialog($error);
		exit 1;
	} elsif (XSTools::minorVersion() < 4) {
		my $error;
		if (defined $ENV{INTERPRETER}) {
			$error = TF("Your version of (wx)start.exe is too old.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php")
		} else {
			$error = TF("Your version of the XSTools library is too old.\n" .
				"Please upgrade it by reading %s", "http://www.openkore.com/aliases/xstools.php")
		}
		$interface->errorDialog($error);
		exit 1;
	}
}

sub shutdown {
	Plugins::unloadAll();
	# Translation Comment: Kore's exit message
	Log::message(T("Bye!\n"));
	Log::message($Settings::versionText);

	if (DEBUG && open(F, ">:utf8", "benchmark-results.txt")) {
		print F Benchmark::results("mainLoop");
		close F;
		print "Benchmark results saved to benchmark-results.txt\n";
	}
}

__start() unless defined $ENV{INTERPRETER};
