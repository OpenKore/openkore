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

use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/src";

eval "no utf8;"; undef $@;
use bytes;
srand;


sub __start {
##### CHECK FOR THE XSTOOL LIBRARY #####

BEGIN {
	my $libName = $^O eq 'MSWin32' ? 'XSTools.dll' : 'XSTools.so';
	my $libFound = 0;
	foreach (@INC) {
		if (-f "$_/$libName" || -f "$_/auto/XSTools/$libName") {
			$found = 1;
			last;
		}
	}
	if (!$found) {
		if ($^O ne 'MSWin32') {
			# If we're on Unix, attempt to compile XSTools.so if it isn't available
			my $ret = system('gmake', '-C', 'src/auto/XSTools');
			if ($ret != 0) {
				if (($ret & 127) == 2) {
					# Ctrl+C pressed
					exit 1;
				} else {
					print STDERR "Unable to compile XSTools.so. Please report this error at our forums.\n";
					exit 1;
				}
			}
		} else {
			print STDERR "Error: XSTools.dll is not found. Please check your installation.\n";
			<STDIN>;
			exit 1;
		}
	}
}


##### SETUP WARNING AND ERROR HANDLER #####

$SIG{__DIE__} = sub {
	return unless (defined $^S && $^S == 0);

	# Determine what function to use to print the error
	my $err;
	if (!$Globals::interface || UNIVERSAL::isa($Globals::interface, "Interface::Startup")) {
		$err = sub { print "$_[0]\nPress ENTER to exit this program.\n"; <STDIN>; }
	} else {
		$err = sub { $Globals::interface->errorDialog($_[0]); };
	}

	# Extract file and line number from the die message 
	my ($file, $line) = $_[0] =~ / at (.+?) line (\d+)\.$/; 

	# Get rid of the annoying "@INC contains:" 
	my $dieMsg = $_[0]; 
	$dieMsg =~ s/ \(\@INC contains: .*\)//;

	# Create error message and display it 
	my $msg = "Program terminated unexpectedly. Error message:\n" .
		"$dieMsg\nA more detailed error report is saved to errors.txt";

	my $log = '';
	$log .= "\@ai_seq = @Globals::ai_seq\n\n" if (defined @Globals::ai_seq);
	if (defined &Carp::longmess) {
		$log .= Carp::longmess(@_);
	} else {
		$log .= $dieMsg;
	}
	# Find out which line died
	if (-f $file && open(F, "< $file")) {
		my @lines = <F>;
		close F;

		my $msg;
		$msg =  "  $lines[$line-2]" if ($line - 2 >= 0);
		$msg .= "* $lines[$line-1]";
		$msg .= "  $lines[$line]" if (@lines > $line);
		$msg .= "\n" unless $msg =~ /\n$/s;
		$log .= "\n\nDied at this line:\n$msg\n";
	}

	if (open(F, "> errors.txt")) {
		print F $log;
		close F;
	}
	$err->($msg);
	exit 9;
};


#### INITIALIZE STARTUP INTERFACE ####

use Interface::Startup;
$interface = new Interface::Startup;

use Time::HiRes qw(time usleep);
use Getopt::Long;
use IO::Socket;
use Digest::MD5;
use Carp;


##### PARSE ARGUMENTS, FURTHER INITIALIZE INTERFACE & LOAD PLUGINS #####

use Settings;

my $parseArgResult = Settings::parseArguments();
$interface = $interface->switchInterface($Settings::default_interface, 1);

if ($parseArgResult eq '2') {
	$interface->displayUsage($Settings::usageText);
	exit 1;

} elsif ($parseArgResult ne '1') {
	$interface->errorDialog($parseArgResult);
	exit 1;
}


require PathFinding;
require WinUtils if ($^O eq 'MSWin32');

require 'functions.pl';
use Globals;
use Modules;
use Log;
use Utils;
use Plugins;
use FileParsers;
use Network;
use Network::Send;
use Commands;
use Misc;
use AI;
use Skills;
use Interface;
use IPC;
use IPC::Processors;
Modules::register(qw/Globals Modules Log Utils Settings Plugins FileParsers
	Network Network::Send Commands Misc AI Skills Interface
	IPC IPC::Processors/);

Log::message("$Settings::versionText\n");
Plugins::loadAll();
Log::message("\n");
Plugins::callHook('start');
undef $@;

##### PARSE CONFIGURATION AND DATA FILES #####

import Settings qw(addConfigFile);
addConfigFile($Settings::config_file, \%config,\&parseDataFile2);
addConfigFile($Settings::items_control_file, \%items_control,\&parseItemsControl);
addConfigFile($Settings::mon_control_file, \%mon_control, \&parseMonControl);
addConfigFile("$Settings::control_folder/overallAuth.txt", \%overallAuth, \&parseDataFile);
addConfigFile($Settings::pickupitems_file, \%itemsPickup, \&parseDataFile_lc);
addConfigFile("$Settings::control_folder/responses.txt", \%responses, \&parseResponses);
addConfigFile("$Settings::control_folder/timeouts.txt", \%timeout, \&parseTimeouts);
addConfigFile($Settings::shop_file, \%shop, \&parseShopControl);
addConfigFile("$Settings::control_folder/chat_resp.txt", \%chat_resp, \&parseDataFile2);
addConfigFile("$Settings::control_folder/avoid.txt", \%avoid, \&parseAvoidControl);
addConfigFile("$Settings::control_folder/priority.txt", \%priority, \&parsePriority);
addConfigFile("$Settings::control_folder/consolecolors.txt", \%consoleColors, \&parseSectionedFile);
addConfigFile("$Settings::control_folder/routeweights.txt", \%routeWeights, \&parseDataFile);

addConfigFile("$Settings::tables_folder/cities.txt", \%cities_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/directions.txt", \%directions_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/elements.txt", \%elements_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/emotions.txt", \%emotions_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/equiptypes.txt", \%equipTypes_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/haircolors.txt", \%haircolors, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/headgears.txt", \@headgears_lut, \&parseArrayFile);
addConfigFile("$Settings::tables_folder/items.txt", \%items_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/itemsdescriptions.txt", \%itemsDesc_lut, \&parseRODescLUT);
addConfigFile("$Settings::tables_folder/itemslots.txt", \%itemSlots_lut, \&parseROSlotsLUT);
addConfigFile("$Settings::tables_folder/itemslotcounttable.txt", \%itemSlotCount_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/itemtypes.txt", \%itemTypes_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/maps.txt", \%maps_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/monsters.txt", \%monsters_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/npcs.txt", \%npcs_lut, \&parseNPCs);
addConfigFile("$Settings::tables_folder/packetdescriptions.txt", \%packetDescriptions, \&parseSectionedFile);
addConfigFile("$Settings::tables_folder/portals.txt", \%portals_lut, \&parsePortals);
addConfigFile("$Settings::tables_folder/portalsLOS.txt", \%portals_los, \&parsePortalsLOS);
addConfigFile("$Settings::tables_folder/recvpackets.txt", \%rpackets, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/sex.txt", \%sex_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skills.txt", \@Skills::skills, \&parseSkills);
addConfigFile("$Settings::tables_folder/skills.txt", \%skills_lut, \&parseSkillsLUT);
addConfigFile("$Settings::tables_folder/skills.txt", \%skills_rlut, \&parseSkillsReverseLUT_lc);
addConfigFile("$Settings::tables_folder/skills.txt", \%skillsID_lut, \&parseSkillsIDLUT);
addConfigFile("$Settings::tables_folder/skills.txt", \%skillsID_rlut, \&parseSkillsReverseIDLUT_lc);
addConfigFile("$Settings::tables_folder/skillsdescriptions.txt", \%skillsDesc_lut, \&parseRODescLUT);
addConfigFile("$Settings::tables_folder/skillssp.txt", \%skillsSP_lut, \&parseSkillsSPLUT);
addConfigFile("$Settings::tables_folder/skillsstatus.txt", \%skillsStatus, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsailments.txt", \%skillsAilments, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsstate.txt", \%skillsState, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillslooks.txt", \%skillsLooks, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsarea.txt", \%skillsArea, \&parseDataFile2);

Plugins::callHook('start2');
Settings::load();
Plugins::callHook('start3');


if ($config{'adminPassword'} eq 'x' x 10) {
	Log::message("\nAuto-generating Admin Password due to default...\n");
	configModify("adminPassword", vocalString(8));
} elsif ($config{'adminPassword'} eq '') {
	# This is where we protect the stupid from having a blank admin password
	Log::message("\nAuto-generating Admin Password due to blank...\n");
	configModify("adminPassword", vocalString(8));
} elsif ($config{'secureAdminPassword'} eq '1') {
	# This is where we induldge the paranoid and let them have session generated admin passwords
	Log::message("\nGenerating session Admin Password...\n");
	configModify("adminPassword", vocalString(8));
}

Log::message("\n");


##### INITIALIZE X-KORE ######

our $XKore_dontRedirect = 0;
if ($config{'XKore'}) {
	require XKore;
	Modules::register("XKore");
	$xkore = new XKore;
	if (!$xkore) {
		$interface->errorDialog($@);
		exit 1;
	}

	# Redirect messages to the RO client
	# I don't use a reference to redirectXKoreMessages here;
	# otherwise dynamic code reloading won't have any effect
	Log::addHook(sub { &redirectXKoreMessages; });
}

our $remote_socket = new IO::Socket::INET;
$ipc = new IPC if ($config{'ipc'});


### COMPILE PORTALS ###

Log::message("Checking for new portals... ");
if (compilePortals_check()) {
	Log::message("found new portals!\n");
	Log::message("Auto-compile in $timeout{'compilePortals_auto'}{'timeout'} seconds...\n");
	Log::message("Compile portals now? (Y/n) ");
	$timeout{'compilePortals_auto'}{'time'} = time;

	my $msg = $interface->getInput($timeout{'compilePortals_auto'}{'timeout'});
	if ($msg =~ /y/ || $msg eq "") {
		Log::message("compiling portals\n\n");
		compilePortals();
	} else {
		Log::message("skipping compile\n\n");
	}
	undef $msg;
} else {
	Log::message("none found\n\n");
}


### PROMPT USERNAME AND PASSWORD IF NECESSARY ###

if (!$config{'XKore'}) {
	if (!$config{'username'}) {
		Log::message("Enter Username: ");
		$msg = $interface->getInput(-1);
		configModify('username', $msg, 1);
	}
	if (!$config{'password'}) {
		Log::message("Enter Password: ");
		$msg = $interface->getInput(-1);
		configModify('password', $msg, 1);
	}

	if ($config{'master'} eq "") {
		Log::message("------- Master Servers --------\n", "connection");
		Log::message("#         Name\n", "connection");
		my $i = 0;
		while ($config{"master_name_$i"} ne "") {
			Log::message(swrite(
				"@<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i,   $config{"master_name_$i"}],
				), "connection");
			$i++;
		}
		undef $i;
		Log::message("-------------------------------\n", "connection");

		Log::message("Choose your master server: ");
		$msg = $interface->getInput(-1);
		configModify('master', $msg, 1);
	}

} elsif (!$config{'XKore'} && (!$config{'username'} || !$config{'password'})) {
	$interface->errorDialog("No username or password set.");
	exit 1;
}

undef $msg;
our $KoreStartTime = time;
our $conState = 1;
our $nextConfChangeTime;
our $bExpSwitch = 2;
our $jExpSwitch = 2;
our $totalBaseExp = 0;
our $totalJobExp = 0;
our $startTime_EXP = time;

initStatVars();
initRandomRestart();
initConfChange();
$timeout{'injectSync'}{'time'} = time;

Log::message("\n");


##### MAIN LOOP #####

Plugins::callHook('initialized');

while ($quit != 1) {
	my $input;

	usleep($config{'sleepTime'});
	$interface->iterate();

	if ($xkore && !$xkore->alive) {
		# (Re-)initialize X-Kore if necessary
		$conState = 1;
		my $printed;
		my $pid;
		# Wait until the RO client has started
		while (!($pid = WinUtils::GetProcByName($config{exeName}))) {
			Log::message("Please start the Ragnarok Online client ($config{exeName})\n", "startup") unless $printed;
			$printed = 1;
			$interface->iterate;
			if (defined($input = $interface->getInput(0))) {
				if ($input eq "quit") {
					$quit = 1;
					last;
				} else {
					Log::message("Error: You cannot type anything except 'quit' right now.\n");
				}
			}
			usleep 10000;
			last if $quit;
		}
		last if $quit;

		# Inject DLL
		Log::message("Ragnarok Online client found\n", "startup");
		sleep 1 if $printed;
		if (!$xkore->inject($pid)) {
			# Failed to inject
			$interface->errorDialog($@);
			exit 1;
		}

		# Wait until the RO client has connected to us
		$remote_socket = $xkore->waitForClient;
		Log::message("You can login with the Ragnarok Online client now.\n", "startup");
		$timeout{'injectSync'}{'time'} = time;
	}

	# Parse command input
	if (defined($input = $interface->getInput(0))) {
		parseInput($input);
	}

	# Receive and handle data from the RO server
	if ($xkore) {
		my $injectMsg = $xkore->recv;
		while ($injectMsg ne "") {
			if (length($injectMsg) < 3) {
				undef $injectMsg;
				last;
			}

			my $type = substr($injectMsg, 0, 1);
			my $len = unpack("S",substr($injectMsg, 1, 2));
			my $newMsg = substr($injectMsg, 3, $len);
			$injectMsg = (length($injectMsg) >= $len+3) ? substr($injectMsg, $len+3, length($injectMsg) - $len - 3) : "";

			if ($type eq "R") {
				$msg .= $newMsg;
				$msg_length = length($msg);
				while ($msg ne "") {
					$msg = parseMsg($msg);
					last if ($msg_length == length($msg));
					$msg_length = length($msg);
				}
			} elsif ($type eq "S") {
				parseSendMsg($newMsg);
			}
		}
		
		if (timeOut($timeout{'injectSync'})) {
			$xkore->sync;
			$timeout{'injectSync'}{'time'} = time;
		}

	} elsif (dataWaiting(\$remote_socket)) {
		$remote_socket->recv($new, $Settings::MAX_READ);
		$msg .= $new;
		$msg_length = length($msg);
		while ($msg ne "") {
			$msg = parseMsg($msg);
			last if ($msg_length == length($msg));
			$msg_length = length($msg);
		}
	}

	# Process AI
	my $i = 0;
	do {
		if ($conState == 5 && timeOut($timeout{'ai'}) && $remote_socket && $remote_socket->connected()) {
			AI($ai_cmdQue[$i]);
		}
		$ai_cmdQue-- if ($ai_cmdQue > 0);
		$i++;
	} while ($ai_cmdQue > 0);
	undef @ai_cmdQue;

	# Handle connection states
	checkConnection() unless $quit;

	# Process messages from the IPC network
	my @ipcMessages;
	if ($ipc && $ipc->recv(\@ipcMessages)) {
		foreach (@ipcMessages) {
			IPC::Processors::process($ipc, $_);
		}
	}

	# Other stuff that's run in the main loop
	mainLoop();

	# Reload any modules that requested to be reloaded
	Modules::doReload();
}


Plugins::unloadAll();

# Shutdown everything else
close($remote_socket);
Network::disconnect(\$remote_socket);

Log::message("Bye!\n");
Log::message($Settings::versionText);
}

__start() unless defined $ENV{INTERPRETER};
