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

use lib '.';
eval "no utf8;"; undef $@;
use bytes;
srand(time());

#### INITIALIZE INTERFACE ####
use Interface;
use Modules;
Modules::register(qw(Interface));
$interface = new Interface;


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
Modules::register(qw(Globals Modules Log Utils Settings Plugins FileParsers
	Network Network::Send Commands Misc));


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
addConfigFile($Settings::shop_file, \%shop, \&parseDataFile2);
addConfigFile("$Settings::control_folder/chat_resp.txt", \%chat_resp, \&parseDataFile2);
addConfigFile("$Settings::control_folder/avoid.txt", \%avoid, \&parseAvoidControl);
addConfigFile("$Settings::control_folder/priority.txt", \%priority, \&parsePriority);
addConfigFile("$Settings::control_folder/consolecolors.txt", \%consoleColors, \&parseSectionedFile);

addConfigFile("$Settings::tables_folder/cities.txt", \%cities_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/emotions.txt", \%emotions_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/equiptypes.txt", \%equipTypes_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/items.txt", \%items_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/itemsdescriptions.txt", \%itemsDesc_lut, \&parseRODescLUT);
addConfigFile("$Settings::tables_folder/itemslots.txt", \%itemSlots_lut, \&parseROSlotsLUT);
addConfigFile("$Settings::tables_folder/itemslotcounttable.txt", \%itemSlotCount_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/itemtypes.txt", \%itemTypes_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/maps.txt", \%maps_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/monsters.txt", \%monsters_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/npcs.txt", \%npcs_lut, \&parseNPCs);
addConfigFile("$Settings::tables_folder/portals.txt", \%portals_lut, \&parsePortals);
addConfigFile("$Settings::tables_folder/portalsLOS.txt", \%portals_los, \&parsePortalsLOS);
addConfigFile("$Settings::tables_folder/sex.txt", \%sex_lut, \&parseDataFile2);
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
addConfigFile("$Settings::tables_folder/cards.txt", \%cards_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/elements.txt", \%elements_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/recvpackets.txt", \%rpackets, \&parseDataFile2);

Plugins::callHook('start2');
Settings::load();
Plugins::callHook('start3');


##### INITIALIZE USAGE OF TOOLS.DLL/TOOLS.SO #####

if ($buildType == 0) {
	# MS Windows
	require Win32::API;
	import Win32::API;
	if ($@) {
		$interface->errorDialog("Unable to load the Win32::API Perl module. Please install this module first.");
		exit 1;
	}

	$CalcPath_init = new Win32::API("Tools", "CalcPath_init", "PPPNNPPN", "N");
	if (!$CalcPath_init) {
		$interface->errorDialog("Could not locate Tools.dll");
		exit 1;
	}

	$CalcPath_pathStep = new Win32::API("Tools", "CalcPath_pathStep", "N", "N");
	if (!$CalcPath_pathStep) {
		$interface->errorDialog("Could not locate Tools.dll");
		exit 1;
	}

	$CalcPath_destroy = new Win32::API("Tools", "CalcPath_destroy", "N", "V");
	if (!$CalcPath_destroy) {
		$interface->errorDialog("Could not locate Tools.dll");
		exit 1;
	}
} else {
	# Linux
	if (! -f "Tools.so") {
		# Tools.so doesn't exist; maybe it's somewhere else in @INC?
		my $found;
		foreach (@INC) {
			if (-f "$_/Tools.so") {
				$found = 1;
				last;
			}
		}

		if (!$found) {
			# Attempt to compile it
			Log::message("Tools.so does not exist; compiling it...\n", "startup");
			my $ret = system('make');
			if ($ret != 0) {
				if (($ret & 127) == 2) {
					# Ctrl+C pressed
					exit 1;
				} else {
					$interface->errorDialog("Unable to compile Tools.so. Please check the " .
						"terminal for the error message, and report this bug at our forums.");
					exit 1;
				}
			}
		}
	}

	eval "use Tools;";
	if ($@) {
		my $msg;
		if ($@ =~ /^Can't locate /s) {
			$msg = 'The file Tools.pm is not found. Please check your installation.';
		} else {
			$msg = $@;
		}
		$interface->errorDialog("Unable to load Tools.so:\n$msg");
		exit 1;
	}
}

if ($config{'XKore'}) {
	my $cwd = Win32::GetCwd();
	our $injectDLL_file = $cwd."\\Inject.dll";

	our $GetProcByName = new Win32::API("Tools", "GetProcByName", "P", "N");
	if (!$GetProcByName) {
		$interface->errorDialog("Could not locate Tools.dll");
		exit 1;
	}
	undef $cwd;
}

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


##### INITIALIZE X-KORE SERVER ######

our $injectServer_socket;
our $XKore_dontRedirect = 0;
if ($config{'XKore'}) {
	$injectServer_socket = IO::Socket::INET->new(
			Listen		=> 5,
			LocalAddr	=> 'localhost',
			LocalPort	=> 2350,
			Proto		=> 'tcp');
	if (!$injectServer_socket) {
		$interface->errorDialog("Unable to start the X-Kore server.\n" .
				"You can only run one X-Kore session at the same time.\n\n" .
				"And make sure no other servers are running on port 2350.");
		exit 1;
	}
	Log::message("Local X-Kore server started (".$injectServer_socket->sockhost().":2350)\n", "startup");

	# Redirect messages to the RO client
	# I don't use a reference to redirectXKoreMessages here;
	# otherwise dynamic code reloading won't have any effect
	Log::addHook(sub { &redirectXKoreMessages; });
}

our $remote_socket = IO::Socket::INET->new();


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


##### SETUP WARNING AND ERROR HANDLER #####

$SIG{__DIE__} = sub {
	return unless (defined $^S && $^S == 0);
	if (defined &Carp::longmess) {
		$interface->writeOutput("error", "Program terminated unexpectedly. Error message: @_\n");
		my $msg = Carp::longmess(@_);
		Log::message("\@ai_seq = @ai_seq\n");
		if (open(F, "> errors.txt")) {
			print F "\@ai_seq = @ai_seq\n";
			print F $msg;
			close F;
		}
	} else {
		Log::message("Program terminated unexpectedly.\n");
	}

	Log::message("Press ENTER to exit this program.\n");
	$interface->getInput(-1) if defined $interface;
};


##### MAIN LOOP #####

Plugins::callHook('initialized');

while ($quit != 1) {
	my $input;

	usleep($config{'sleepTime'});

	if ($config{'XKore'}) {
		# (Re-)initialize X-Kore if necessary

		if (timeOut($timeout{'injectKeepAlive'})) {
			$conState = 1;
			my $printed = 0;
			my $procID = 0;
			do {
				$procID = $GetProcByName->Call($config{'exeName'});
				if (!$procID && !$printed) {
					Log::message("Error: Could not locate process $config{'exeName'}.\n");
					Log::message("Waiting for you to start the process...\n");
					$printed = 1;
				}

				if (defined($input = $interface->getInput(0))) {
				   	if ($input eq 'quit') {
						$quit = 1;
						last;
					} else {
						Log::message("Error: You cannot type anything except 'quit' right now.\n");
					}
				}

				usleep 100000;
			} while (!$procID && !$quit);
			last if ($quit);

			if ($printed == 1) {
				Log::message("Process found\n");
			}
			my $InjectDLL = new Win32::API("Tools", "InjectDLL", "NP", "I");
			my $retVal = $InjectDLL->Call($procID, $injectDLL_file);
			if ($retVal != 1) {
				Log::error("Could not inject DLL\n", "startup");
				$timeout{'injectKeepAlive'}{'time'} = time;
			} else {
				Log::message("Waiting for InjectDLL to connect...\n");
				$remote_socket = $injectServer_socket->accept();
				(inet_aton($remote_socket->peerhost()) eq inet_aton('localhost'))
				|| die "Inject Socket must be connected from localhost";
				Log::message("InjectDLL Socket connected - Ready to start botting\n");
				$timeout{'injectKeepAlive'}{'time'} = time;
			}
		}
		if (timeOut(\%{$timeout{'injectSync'}})) {
			sendSyncInject(\$remote_socket);
			$timeout{'injectSync'}{'time'} = time;
		}
	}

	# Parse command input
	if (defined($input = $interface->getInput(0))) {
		parseInput($input);
	}

	# Receive and handle data from the RO server
	if (dataWaiting(\$remote_socket)) {
		if (!$config{'XKore'}) {
			$remote_socket->recv($new, $Settings::MAX_READ);
			$msg .= $new;
			$msg_length = length($msg);
			while ($msg ne "") {
				$msg = parseMsg($msg);
				last if ($msg_length == length($msg));
				$msg_length = length($msg);
			}

		} else {
			my $injectMsg;
			$remote_socket->recv($injectMsg, $Settings::MAX_READ);
			while ($injectMsg ne "") {
				if (length($injectMsg) < 3) {
					undef $injectMsg;
					break;
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
				$timeout{'injectKeepAlive'}{'time'} = time;
			}
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
	checkConnection();

	# Other stuff that's run in the main loop
	mainLoop();

	# Reload any modules that requested to be reloaded
	Modules::doReload();
}


Plugins::unloadAll();

# Shutdown everything else
close($remote_socket);
unlink('buffer') if ($config{'XKore'} && -f 'buffer');
Network::disconnect(\$remote_socket);

Log::message("Bye!\n");
Log::message($Settings::versionText);

undef $interface;
