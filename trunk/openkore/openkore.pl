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
Modules::register(qw(Modules Input Log Utils));


our $buildType = 0;
our $daemon = 0;
our $config_file = "control/config.txt";
our $items_control_file = "control/items_control.txt";
our $mon_control_file = "control/mon_control.txt";
our $chat_file = "chat.txt";
our $item_log_file = "items.txt";
our $shop_file = "control/shop.txt";
our $rpackets_file = 'tables/recvpackets.txt';

&GetOptions(
	'daemon', \$daemon,
	'config=s', \$config_file,
	'mon_control=s', \$mon_control_file,
	'items_control=s', \$items_control_file,
	'chat=s', \$chat_file,
	'shop=s', \$shop_file,
	'items=s', \$item_log_file,
	'rpackets=s', \$rpackets_file,
	'help', \$help_option);
if ($help_option) {
	print "Usage: skore.exe [options...]\n\n";
	print "The supported options are:\n\n";
	print "--help                     Displays this help message.\n";
	print "--daemon                   Start as daemon; don't listen for keyboard input.\n";
	print "--config=path/file         Which config.txt to use.\n";
	print "--mon_control=path/file    Which mon_control.txt to use.\n";
	print "--items_control=path/file  Which items_control.txt to use.\n";
	print "--chat=path/file           Which chat.txt to use.\n";
	print "--shop=path/file           Which shop.txt to use.\n";
	print "--rpackets=path/file       Which recvpackets.txt to use.\n";
	exit(1);
}

srand(time());

our $versionText = "*** OpenKore 1.0.0 - Custom Ragnarok Online client - http://openkore.sourceforge.net***\n";
our $welcomeText = "Welcome to X-OpenKore.";
our $MAX_READ = 30000;

print "$versionText\n";

Input::start() unless ($daemon);

print "\n";

addParseFiles($config_file, \%config,\&parseDataFile2);
addParseFiles($items_control_file, \%items_control,\&parseItemsControl);
addParseFiles($mon_control_file, \%mon_control,\&parseMonControl);
addParseFiles("control/overallauth.txt", \%overallAuth, \&parseDataFile);
addParseFiles("control/pickupitems.txt", \%itemsPickup, \&parseDataFile_lc);
addParseFiles("control/responses.txt", \%responses, \&parseResponses);
addParseFiles("control/timeouts.txt", \%timeout, \&parseTimeouts);
addParseFiles($shop_file, \%shop, \&parseDataFile2);
addParseFiles("control/chat_resp.txt", \%chat_resp, \&parseDataFile2);
addParseFiles("control/avoid.txt", \%avoid, \&parseDataFile2);
#addParseFiles("control/chat_ppl.txt", \%chat_resp, \&parseDataFile2);

addParseFiles("tables/cities.txt", \%cities_lut, \&parseROLUT);
addParseFiles("tables/emotions.txt", \%emotions_lut, \&parseDataFile2);
addParseFiles("tables/equiptypes.txt", \%equipTypes_lut, \&parseDataFile2);
addParseFiles("tables/items.txt", \%items_lut, \&parseROLUT);
addParseFiles("tables/itemsdescriptions.txt", \%itemsDesc_lut, \&parseRODescLUT);
addParseFiles("tables/itemslots.txt", \%itemSlots_lut, \&parseROSlotsLUT);
addParseFiles("tables/itemtypes.txt", \%itemTypes_lut, \&parseDataFile2);
addParseFiles("tables/jobs.txt", \%jobs_lut, \&parseDataFile2);
addParseFiles("tables/maps.txt", \%maps_lut, \&parseROLUT);
addParseFiles("tables/monsters.txt", \%monsters_lut, \&parseDataFile2);
addParseFiles("tables/npcs.txt", \%npcs_lut, \&parseNPCs);
addParseFiles("tables/portals.txt", \%portals_lut, \&parsePortals);
addParseFiles("tables/portalsLOS.txt", \%portals_los, \&parsePortalsLOS);
addParseFiles("tables/sex.txt", \%sex_lut, \&parseDataFile2);
addParseFiles("tables/skills.txt", \%skills_lut, \&parseSkillsLUT);
addParseFiles("tables/skills.txt", \%skillsID_lut, \&parseSkillsIDLUT);
addParseFiles("tables/skills.txt", \%skills_rlut, \&parseSkillsReverseLUT_lc);
addParseFiles("tables/skillsdescriptions.txt", \%skillsDesc_lut, \&parseRODescLUT);
addParseFiles("tables/skillssp.txt", \%skillsSP_lut, \&parseSkillsSPLUT);
addParseFiles("tables/cards.txt", \%cards_lut, \&parseROLUT); 
addParseFiles("tables/elements.txt", \%elements_lut, \&parseROLUT); 
addParseFiles($rpackets_file, \%rpackets, \&parseDataFile2); 

load(\@parseFiles);

if ($^O eq 'MSWin32' || $^O eq 'cygwin') {
	eval "use Win32::API;";
	die if ($@);

	$CalcPath_init = new Win32::API("Tools", "CalcPath_init", "PPNNPPN", "N");
	die "Could not locate Tools.dll" if (!$CalcPath_init);

	$CalcPath_pathStep = new Win32::API("Tools", "CalcPath_pathStep", "N", "N");
	die "Could not locate Tools.dll" if (!$CalcPath_pathStep);

	$CalcPath_destroy = new Win32::API("Tools", "CalcPath_destroy", "N", "V");
	die "Could not locate Tools.dll" if (!$CalcPath_destroy);

	$buildType = 0;
} else {
	eval "use Tools;";
	die if ($@);

	$buildType = 1;
}

if ($config{'XKore'}) {
	our $cwd = Win32::GetCwd();
	our $injectDLL_file = $cwd."\\Inject.dll";

	our $GetProcByName = new Win32::API("Tools", "GetProcByName", "P", "N");
	die "Could not locate Tools.dll" if (!$GetProcByName);
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


###COMPILE PORTALS###

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
		$i = 0;
		$~ = "MASTERS";
		print "--------- Master Servers ----------\n";
		print "#         Name\n";
		while ($config{"master_name_$i"} ne "") {
			format MASTERS =
@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$i  $config{"master_name_$i"}
.
			write;
			$i++;
		}
		print "-------------------------------\n";
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
			} while (!$procID);

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
		$remote_socket->recv($new, $MAX_READ);
		$msg .= $new;
		$msg_length = length($msg);
		while ($msg ne "") {
			$msg = parseMsg($msg);
			last if ($msg_length == length($msg));
			$msg_length = length($msg);
		}

	} elsif ($config{'XKore'} && dataWaiting(\$remote_socket)) {
		my $injectMsg;
		$remote_socket->recv($injectMsg, $MAX_READ);
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
print $versionText;
exit;
