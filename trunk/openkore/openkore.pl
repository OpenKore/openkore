#!/usr/bin/env perl
#########################################################################
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

use Time::HiRes qw(time usleep);
use Getopt::Long;
use IO::Socket;
use Digest::MD5 qw(md5);
unshift @INC, '.';


require 'functions.pl';
use Modules;
use Input;
use Log;
use Utils;
use Settings;
Modules::register(qw(Modules Input Log Utils Settings));


##### PARSE ARGUMENTS AND START INPUT SERVER #####

srand(time());
Settings::parseArguments();
print "$Settings::versionText\n";
Input::start() unless ($Settings::daemon);
print "\n";


##### PARSE CONFIGURATION AND DATA FILES #####

addParseFiles($Settings::config_file, \%config,\&parseDataFile2);
addParseFiles($Settings::items_control_file, \%items_control,\&parseItemsControl);
addParseFiles($Settings::mon_control_file, \%mon_control,\&parseMonControl);
addParseFiles("$Settings::control_folder/overallauth.txt", \%overallAuth, \&parseDataFile);
addParseFiles("$Settings::control_folder/pickupitems.txt", \%itemsPickup, \&parseDataFile_lc);
addParseFiles("$Settings::control_folder/responses.txt", \%responses, \&parseResponses);
addParseFiles("$Settings::control_folder/timeouts.txt", \%timeout, \&parseTimeouts);
addParseFiles($Settings::shop_file, \%shop, \&parseDataFile2);
addParseFiles("$Settings::control_folder/chat_resp.txt", \%chat_resp, \&parseDataFile2);
addParseFiles("$Settings::control_folder/avoid.txt", \%avoid, \&parseDataFile2);
addParseFiles("$Settings::control_folder/consolecolors.txt", \%consoleColors, \&parseSectionedFile);

addParseFiles("$Settings::tables_folder/cities.txt", \%cities_lut, \&parseROLUT);
addParseFiles("$Settings::tables_folder/emotions.txt", \%emotions_lut, \&parseDataFile2);
addParseFiles("$Settings::tables_folder/equiptypes.txt", \%equipTypes_lut, \&parseDataFile2);
addParseFiles("$Settings::tables_folder/items.txt", \%items_lut, \&parseROLUT);
addParseFiles("$Settings::tables_folder/itemsdescriptions.txt", \%itemsDesc_lut, \&parseRODescLUT);
addParseFiles("$Settings::tables_folder/itemslots.txt", \%itemSlots_lut, \&parseROSlotsLUT);
addParseFiles("$Settings::tables_folder/itemtypes.txt", \%itemTypes_lut, \&parseDataFile2);
addParseFiles("$Settings::tables_folder/jobs.txt", \%jobs_lut, \&parseDataFile2);
addParseFiles("$Settings::tables_folder/maps.txt", \%maps_lut, \&parseROLUT);
addParseFiles("$Settings::tables_folder/monsters.txt", \%monsters_lut, \&parseDataFile2);
addParseFiles("$Settings::tables_folder/npcs.txt", \%npcs_lut, \&parseNPCs);
addParseFiles("$Settings::tables_folder/portals.txt", \%portals_lut, \&parsePortals);
addParseFiles("$Settings::tables_folder/portalsLOS.txt", \%portals_los, \&parsePortalsLOS);
addParseFiles("$Settings::tables_folder/sex.txt", \%sex_lut, \&parseDataFile2);
addParseFiles("$Settings::tables_folder/skills.txt", \%skills_lut, \&parseSkillsLUT);
addParseFiles("$Settings::tables_folder/skills.txt", \%skillsID_lut, \&parseSkillsIDLUT);
addParseFiles("$Settings::tables_folder/skills.txt", \%skills_rlut, \&parseSkillsReverseLUT_lc);
addParseFiles("$Settings::tables_folder/skillsdescriptions.txt", \%skillsDesc_lut, \&parseRODescLUT);
addParseFiles("$Settings::tables_folder/skillssp.txt", \%skillsSP_lut, \&parseSkillsSPLUT);
addParseFiles("$Settings::tables_folder/cards.txt", \%cards_lut, \&parseROLUT);
addParseFiles("$Settings::tables_folder/elements.txt", \%elements_lut, \&parseROLUT);
addParseFiles("$Settings::tables_folder/recvpackets.txt", \%rpackets, \&parseDataFile2);

load(\@parseFiles);


##### INITIALIZE USAGE OF TOOLS.DLL/TOOLS.SO #####

if ($buildType == 0) {
	# MS Windows
	eval "use Win32::API;";
	require Win32::API;
	import Win32::API;
	die if ($@);

	$CalcPath_init = new Win32::API("Tools", "CalcPath_init", "PPNNPPN", "N");
	if (!$CalcPath_init) {
		Log::error("Could not locate Tools.dll", "startup");
		exit 1;
	}

	$CalcPath_pathStep = new Win32::API("Tools", "CalcPath_pathStep", "N", "N");
	if (!$CalcPath_pathStep) {
		Log::error("Could not locate Tools.dll", "startup");
		exit 1;
	}

	$CalcPath_destroy = new Win32::API("Tools", "CalcPath_destroy", "N", "V");
	if (!$CalcPath_destroy) {
		Log::error("Could not locate Tools.dll", "startup");
		exit 1;
	}
} else {
	# Linux
	if (! -f "Tools.so") {
		Log::error("Could not locate Tools.so. Type 'make' if you haven't done so.\n", "startup");
		exit 1;
	}
	require Tools;
	import Tools;
}

if ($config{'XKore'}) {
	our $cwd = Win32::GetCwd();
	our $injectDLL_file = $cwd."\\Inject.dll";

	our $GetProcByName = new Win32::API("Tools", "GetProcByName", "P", "N");
	if (!$GetProcByName) {
		Log::error("Could not locate Tools.dll", "startup");
		exit 1;
	}
	undef $cwd;
	undef $injectDLL_file;
}

if ($config{'adminPassword'} eq 'x' x 10) {
	print "\nAuto-generating Admin Password due to default...\n";
	configModify("adminPassword", vocalString(8));
}
# This is where we protect the stupid from having a blank admin password
elsif ($config{'adminPassword'} eq '') {
	print "\nAuto-generating Admin Password due to blank...\n";
	configModify("adminPassword", vocalString(8));
}
# This is where we induldge the paranoid and let them have session generated admin passwords
elsif ($config{'secureAdminPassword'} eq '1') {
	print "\nGenerating session Admin Password...\n";
	configModify("adminPassword", vocalString(8));
}

print "\n";

our $injectServer_socket;
if ($config{'XKore'}) {
	$injectServer_socket = IO::Socket::INET->new(
			Listen		=> 5,
			LocalAddr	=> 'localhost',
			LocalPort	=> 2350,
			Proto		=> 'tcp');
	($injectServer_socket) || die "Error creating local inject server: $!";
	print "Local inject server started (".$injectServer_socket->sockhost().":2350)\n";
}

our $remote_socket = IO::Socket::INET->new();


### COMPILE PORTALS ###

print "Checking for new portals...";
compilePortals_check(\$found);

if ($found) {
	print "found new portals!\n";

	if ($Input::enabled) {
		print "Compile portals now? (y/n)\n";
		print "Auto-compile in $timeout{'compilePortals_auto'}{'timeout'} seconds...";
		$timeout{'compilePortals_auto'}{'time'} = time;
		undef $msg;
		while (!timeOut(\%{$timeout{'compilePortals_auto'}})) {
			if (Input::canRead) {
				$msg = Input::readLine();
			}
			last if $msg;
		}
		if ($msg =~ /y/ || $msg eq "") {
			print "compiling portals\n\n";
			compilePortals();
		} else {
			print "skipping compile\n\n";
		}
	} else {
		print "compiling portals\n\n";
		compilePortals();
	}
} else {
	print "none found\n\n";
}


if (!$config{'XKore'}) {
	if (!$config{'username'}) {
		print "Enter Username:\n";
		$msg = Input::readLine;
		$config{'username'} = $msg;
		writeDataFileIntact($config_file, \%config);
	}
	if (!$config{'password'}) {
		print "Enter Password:\n";
		$msg = Input::readLine;
		$config{'password'} = $msg;
		writeDataFileIntact($config_file, \%config);
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

		print "Choose your master server:\n";
		$msg = Input::readLine;
		$config{'master'} = $msg;
		writeDataFileIntact($config_file, \%config);
	}

	$timeout{'injectSync'}{'time'} = time;
}

undef $msg;
our $KoreStartTime = time;
our $AI = 1;
our $conState = 1;
our $nextConfChangeTime;

initStatVars();
initRandomRestart();
initConfChange();

print "\n";


##### MAIN LOOP #####

while ($quit != 1) {
	usleep($config{'sleepTime'});

	if ($config{'XKore'}) {
		if (timeOut(\%{$timeout{'injectKeepAlive'}})) {
			$conState = 1;
			my $printed = 0;
			my $procID = 0;
			do {
				$procID = $GetProcByName->Call($config{'exeName'});
				if (!$procID) {
					print "Error: Could not locate process $config{'exeName'}.\n";
					print "Waiting for you to start the process...\n" if (!$printed);
					$printed = 1;
				}
				sleep 1;
			} while (!$procID && !$quit);

			if ($printed == 1) {
				print "Process found\n";
			}
			my $InjectDLL = new Win32::API("Tools", "InjectDLL", "NP", "I");
			my $retVal = $InjectDLL->Call($procID, $injectDLL_file);
			die "Could not inject DLL" if ($retVal != 1);

			print "Waiting for InjectDLL to connect...\n";
			$remote_socket = $injectServer_socket->accept();
			(inet_aton($remote_socket->peerhost()) eq inet_aton('localhost'))
			|| die "Inject Socket must be connected from localhost";
			print "InjectDLL Socket connected - Ready to start botting\n";
			$timeout{'injectKeepAlive'}{'time'} = time;
		}
		if (timeOut(\%{$timeout{'injectSync'}})) {
			sendSyncInject(\$remote_socket);
			$timeout{'injectSync'}{'time'} = time;
		}
	}

	if (Input::canRead) {
		$input = Input::readLine();
		parseInput($input);

	} elsif (!$config{'XKore'} && dataWaiting(\$remote_socket)) {
		$remote_socket->recv($new, $Settings::MAX_READ);
		$msg .= $new;
		$msg_length = length($msg);
		while ($msg ne "") {
			$msg = parseMsg($msg);
			last if ($msg_length == length($msg));
			$msg_length = length($msg);
		}

	} elsif ($config{'XKore'} && dataWaiting(\$remote_socket)) {
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

	$ai_cmdQue_shift = 0;
	do {
		AI(\%{$ai_cmdQue[$ai_cmdQue_shift]}) if ($conState == 5 && timeOut(\%{$timeout{'ai'}}) && $remote_socket && $remote_socket->connected());
		undef %{$ai_cmdQue[$ai_cmdQue_shift++]};
		$ai_cmdQue-- if ($ai_cmdQue > 0);
	} while ($ai_cmdQue > 0);
	checkConnection();
}


Input::stop();
close($remote_socket);
unlink('buffer') if ($config{'XKore'} && -f 'buffer');
killConnection(\$remote_socket);

print "Bye!\n";
print $Settings::versionText;
exit;
