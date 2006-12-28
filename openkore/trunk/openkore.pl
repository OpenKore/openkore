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

sub __start {

use Time::HiRes qw(time usleep);
use IO::Socket;
use Digest::MD5;
use Carp;
use Carp::Assert;

use ErrorHandler;
use XSTools;

srand();


##### PARSE ARGUMENTS, FURTHER INITIALIZE INTERFACE & LOAD PLUGINS #####

use Translation;
use Settings qw(%sys);

eval "use OpenKoreMod;";
undef $@;
my $parseArgResult = Settings::parseArguments();
Settings::parseSysConfig();
Translation::initDefault(undef, $sys{locale});

use Globals;
use Interface;
$interface = Interface->switchInterface($Settings::default_interface, 1);

if ($parseArgResult eq '2') {
	$interface->displayUsage($Settings::usageText);
	exit 1;

} elsif ($parseArgResult ne '1') {
	$interface->errorDialog($parseArgResult);
	exit 1;
}

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


# Use 'require' here because XSTools.so might not be compiled yet at startup
if (!defined &XSTools::majorVersion) {
	$interface->errorDialog(TF("Your version of the XSTools library is too old.\n" .
		"Please read %s", ""));
	exit 1;
} elsif (XSTools::majorVersion() != 4) {
	$interface->errorDialog(TF("Your version of XSTools library is incompatible.\n" .
		"Please read %s", "http://www.openkore.com/aliases/xstools.php"));
	exit 1;
} elsif (XSTools::minorVersion() < 3) {
	$interface->errorDialog(TF("Your version of the XSTools library is too old. Please upgrade it.\n" .
		"Please read %s", "http://www.openkore.com/aliases/xstools.php"));
	exit 1;
}
require Utils::PathFinding;
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
use Skills;
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
use Task::TalkNPC;
use Utils::Benchmark;
use Utils::HttpReader;
use Utils::Whirlpool;
use Poseidon::Client;
Modules::register(qw/Log Utils Settings Plugins FileParsers
	Network::Receive Network::Send Misc AI AI::CoreLogic
	AI::Attack AI::Homunculus Skills
	Interface ChatQueue Actor Actor::Player Actor::Monster Actor::You
	Actor::Party Actor::Unknown Actor::Item Match Utils::Benchmark/);

Log::message("$Settings::versionText\n");
if (!Plugins::loadAll()) {
	$interface->errorDialog(T("One or more plugins failed to load."));
	exit 1;
}
Log::message("\n");
Plugins::callHook('start');
undef $@;

##### PARSE CONFIGURATION AND DATA FILES #####

import Settings qw(addConfigFile);
addConfigFile($Settings::config_file, \%config,\&parseConfigFile);
addConfigFile($Settings::items_control_file, \%items_control,\&parseItemsControl);
addConfigFile($Settings::mon_control_file, \%mon_control, \&parseMonControl);
addConfigFile("$Settings::control_folder/overallAuth.txt", \%overallAuth, \&parseDataFile);
addConfigFile($Settings::pickupitems_file, \%pickupitems, \&parseDataFile_lc);
addConfigFile("$Settings::control_folder/responses.txt", \%responses, \&parseResponses);
addConfigFile("$Settings::control_folder/timeouts.txt", \%timeout, \&parseTimeouts);
addConfigFile($Settings::shop_file, \%shop, \&parseShopControl);
addConfigFile("$Settings::control_folder/chat_resp.txt", \@chatResponses, \&parseChatResp);
addConfigFile("$Settings::control_folder/avoid.txt", \%avoid, \&parseAvoidControl);
addConfigFile("$Settings::control_folder/priority.txt", \%priority, \&parsePriority);
addConfigFile("$Settings::control_folder/consolecolors.txt", \%consoleColors, \&parseSectionedFile);
addConfigFile("$Settings::control_folder/routeweights.txt", \%routeWeights, \&parseDataFile);
addConfigFile("$Settings::control_folder/arrowcraft.txt", \%arrowcraft_items, \&parseDataFile_lc);

addConfigFile("$Settings::tables_folder/cities.txt", \%cities_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/commanddescriptions.txt", \%descriptions, \&parseCommandsDescription);
addConfigFile("$Settings::tables_folder/directions.txt", \%directions_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/elements.txt", \%elements_lut, \&parseROLUT);
addConfigFile("$Settings::tables_folder/emotions.txt", \%emotions_lut, \&parseEmotionsFile);
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
addConfigFile("$Settings::tables_folder/servers.txt", \%masterServers, \&parseSectionedFile);
addConfigFile("$Settings::tables_folder/sex.txt", \%sex_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skills.txt", \%Skills::skills, \&parseSkills);
addConfigFile("$Settings::tables_folder/spells.txt", \%spells_lut, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsdescriptions.txt", \%skillsDesc_lut, \&parseRODescLUT);
addConfigFile("$Settings::tables_folder/skillssp.txt", \%skillsSP_lut, \&parseSkillsSPLUT);
addConfigFile("$Settings::tables_folder/skillsstatus.txt", \%skillsStatus, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsailments.txt", \%skillsAilments, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsstate.txt", \%skillsState, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillslooks.txt", \%skillsLooks, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsarea.txt", \%skillsArea, \&parseDataFile2);
addConfigFile("$Settings::tables_folder/skillsencore.txt", \%skillsEncore, \&parseList);

Plugins::callHook('start2');
if (!Settings::load()) {
	$interface->errorDialog(T("A configuration file failed to load. Did you download the latest configuration files?"));
	exit 1;
}
Plugins::callHook('start3');


if ($config{'adminPassword'} eq 'x' x 10) {
	Log::message(T("\nAuto-generating Admin Password due to default...\n"));
	configModify("adminPassword", vocalString(8));
#} elsif ($config{'adminPassword'} eq '') {
#	# This is where we protect the stupid from having a blank admin password
#	Log::message(T("\nAuto-generating Admin Password due to blank...\n"));
#	configModify("adminPassword", vocalString(8));
} elsif ($config{'secureAdminPassword'} eq '1') {
	# This is where we induldge the paranoid and let them have session generated admin passwords
	Log::message(T("\nGenerating session Admin Password...\n"));
	configModify("adminPassword", vocalString(8));
}

Log::message("\n");


##### INITIALIZE X-KORE ######

our $XKore_dontRedirect = 0;
my $XKore_version = $config{XKore}? $config{XKore} : $sys{XKore};
eval {
	if ($XKore_version eq "1" || $XKore_version eq "inject") {
		# Inject DLL to running Ragnarok process
		require Network::XKore;
		$net = new Network::XKore;
	} elsif ($XKore_version eq "2") {
		# Run as a proxy bot, allowing Ragnarok to connect while botting
		require Network::XKore2;
		$net = new Network::XKore2;
	} elsif ($XKore_version eq "3" || $XKore_version eq "proxy") {
		# Proxy Ragnarok client connection
		require Network::XKoreProxy;
		$net = new Network::XKoreProxy;
	} else {
		# Run as a standalone bot, with no interface to the official RO client
		require Network::DirectConnection;
		$net = new Network::DirectConnection;
	}
};
if ($@) {
	# Problem with networking.
	$interface->errorDialog($@);
	exit 1;
}

if ($sys{ipc}) {
	require IPC;
	require IPC::Processors;
	Modules::register("IPC", "IPC::Processors");

	my $host = $sys{ipc_manager_host};
	my $port = $sys{ipc_manager_port};
	$host = undef if ($host eq '');
	$port = undef if ($port eq '');
	$ipc = new IPC(undef, $host, $port, 1,
		       $sys{ipc_manager_bind}, $sys{ipc_manager_startAtPort});
	if (!$ipc && $@) {
		Log::error(TF("Unable to initialize the IPC subsystem: %s\n", $@));
		undef $@;
	}

	$ipc->send("new bot", userName => $config{username});
}


### COMPILE PORTALS ###

Log::message(T("Checking for new portals... "));
if (compilePortals_check()) {
	Log::message(T("found new portals!\n"));
	my $choice = $interface->showMenu(T("Compile portals?"),
		T("New portals have been added to the portals database. " .
		"The portals database must be compiled before the new portals can be used. " .
		"Would you like to compile portals now?\n"),
		[T("Yes, compile now."), T("No, don't compile it.")]);
	if ($choice == 0) {
		Log::message(T("compiling portals") . "\n\n");
		compilePortals();
	} else {
		Log::message(T("skipping compile") . "\n\n");
	}
} else {
	Log::message(T("none found\n\n"));
}


### PROMPT USERNAME AND PASSWORD IF NECESSARY ###

if ($net->version != 1) {
	my $msg;
	if (!$config{username}) {
		$msg = $interface->askInput(T("Enter Username: "));
		if (!defined($msg)) {
			exit;
		}
		configModify('username', $msg, 1);
	}
	if (!$config{password}) {
		$msg = $interface->askPassword(T("Enter Password: "));
		if (!defined($msg)) {
			exit;
		}
		configModify('password', $msg, 1);
	}

	if ($config{'master'} eq "" || $config{'master'} =~ /^\d+$/ || !exists $masterServers{$config{'master'}}) {
		my @servers = sort { lc($a) cmp lc($b) } keys(%masterServers);
		my $choice = $interface->showMenu(T("Master servers"),
			T("Please choose a master server to connect to: "),
			\@servers);
		if ($choice == -1) {
			exit;
		} else {
			configModify('master', $servers[$choice], 1);
		}
	}

} elsif ($net->version != 1 && (!$config{'username'} || !$config{'password'})) {
	$interface->errorDialog(T("No username or password set."));
	exit 1;
}

undef $msg;
undef $msgOut;
$KoreStartTime = time;
$conState = 1;
our $nextConfChangeTime;
$bExpSwitch = 2;
$jExpSwitch = 2;
$totalBaseExp = 0;
$totalJobExp = 0;
$startTime_EXP = time;
$taskManager = new TaskManager();

$itemsList = new ActorList('Actor::Item');
$monstersList = new ActorList('Actor::Monster');
$playersList = new ActorList('Actor::Player');
$petsList = new ActorList('Actor::Pet');
$npcsList = new ActorList('Actor::NPC');
$portalsList = new ActorList('Actor::Portal');
foreach my $list ($itemsList, $monstersList, $playersList, $petsList, $npcsList, $portalsList) {
	$list->onAdd()->add(undef, \&actorAdded);
	$list->onRemove()->add(undef, \&actorRemoved);
	$list->onClearBegin()->add(undef, \&actorListClearing);
}

StdHttpReader::init();
initStatVars();
initRandomRestart();
initUserSeed();
initConfChange();
Log::initLogFiles();
$timeout{'injectSync'}{'time'} = time;

Log::message("\n");


##### MAIN LOOP #####

Plugins::callHook('initialized');
XSTools::initVersion();
Benchmark::begin("Real time") if DEBUG;
$interface->mainLoop();
Benchmark::end("Real time") if DEBUG;
Plugins::unloadAll();

# Shutdown everything else
undef $net;
# Translation Comment: Kore's exit message
Log::message(T("Bye!\n"));
Log::message($Settings::versionText);

if (DEBUG && open(F, ">:utf8", "benchmark-results.txt")) {
	print F Benchmark::results("mainLoop");
	close F;
	print "Benchmark results saved to benchmark-results.txt\n";
}

} # __start()

__start() unless defined $ENV{INTERPRETER};
