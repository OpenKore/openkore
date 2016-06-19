#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################

package main;
use strict;
use Time::HiRes qw(time usleep);
use IO::Socket;
use Text::ParseWords;
use Carp::Assert;
use Config;
use utf8;

use Globals;
use Modules;
use Settings qw(%sys %options);
use Log qw(message warning error debug);
use Interface;
use Misc;
use Network::Receive;
use Network::Send ();
use Network::ClientReceive;
use Network::PaddedPackets;
use Network::MessageTokenizer;
use Commands;
use Plugins;
use Utils;
use ChatQueue;
use I18N;
use Utils::Benchmark;
use Utils::HttpReader;


#######################################
# PROGRAM INITIALIZATION
#######################################

use constant {
	STATE_LOAD_PLUGINS          => 0,
	STATE_LOAD_DATA_FILES       => 1,
	STATE_INIT_NETWORKING       => 2,
	STATE_INIT_PORTALS_DATABASE => 3,
	STATE_PROMPT                => 4,
	STATE_FINAL_INIT            => 5,
	STATE_INITIALIZED           => 6
};

our $state;

sub mainLoop {
	Benchmark::begin('mainLoop') if DEBUG;
	$state = STATE_LOAD_PLUGINS if (!defined $state);

	# Parse command input
	my $input;
	if (defined($input = $interface->getInput(0))) {
		Misc::checkValidity("parseInput (pre)");
		parseInput($input);
		Misc::checkValidity("parseInput");
	}


	if ($state == STATE_INITIALIZED) {
		Plugins::callHook('mainLoop_pre');
		mainLoop_initialized();
		Plugins::callHook('mainLoop_post');

	} elsif ($state == STATE_LOAD_PLUGINS) {
		Log::message("$Settings::versionText\n");
		loadPlugins();
		return if $quit;
		Log::message("\n");
		Plugins::callHook('start');
		$state = STATE_LOAD_DATA_FILES;

	} elsif ($state == STATE_LOAD_DATA_FILES) {
		loadDataFiles();
		$state = STATE_INIT_NETWORKING;

	} elsif ($state == STATE_INIT_NETWORKING) {
		initNetworking();
		$state = STATE_INIT_PORTALS_DATABASE;

	} elsif ($state == STATE_INIT_PORTALS_DATABASE) {
		initPortalsDatabase();
		$state = STATE_PROMPT;

	} elsif ($state == STATE_PROMPT) {
		promptFirstTimeInformation();
		$state = STATE_FINAL_INIT;

	} elsif ($state == STATE_FINAL_INIT) {
		finalInitialization();
		$state = STATE_INITIALIZED;

	} else {
		die "Unknown state $state.";
	}

	Benchmark::end('mainLoop') if DEBUG;
	# Reload any modules that requested to be reloaded
	Modules::reloadAllInQueue();
}

sub loadPlugins {
	eval {
		Plugins::loadAll();
	};
	my $e;
	if ($e = caught('Plugin::LoadException')) {
		$interface->errorDialog(TF("This plugin cannot be loaded because of a problem in the plugin. " .
			"Please notify the plugin's author about this problem, " .
			"or remove the plugin so %s can start.\n\n" .
			"The error message is:\n" .
			"%s",
			$Settings::NAME, $e->message));
		$quit = 1;
	} elsif ($e = caught('Plugin::DeniedException')) {
		$interface->errorDialog($e->message);
		$quit = 1;
	} elsif ($@) {
		die $@;
	}

	# Allow plugins to use command line arguments.
	Plugins::callHook( 'parse_command_line' );
	main::checkEmptyArguments();
}

sub loadDataFiles {
	# These pragmas are necessary in order to support non-ASCII filenames.
	# If we use UTF-8 strings then Perl will think the file doesn't exist,
	# if $Settings::control_folder or $Settings::tables_folder contains
	# non-ASCII characters.
	no encoding 'utf8';

	# Add loading of Control files
	Settings::addControlFile(Settings::getConfigFilename(),
		loader => [\&parseConfigFile, \%config],
		internalName => 'config.txt',
		autoSearch => 0);
	Settings::addControlFile('consolecolors.txt',
		loader => [\&parseSectionedFile, \%consoleColors]);
	Settings::addControlFile(Settings::getMonControlFilename(),
		loader => [\&parseMonControl, \%mon_control],
		internalName => 'mon_control.txt',
		autoSearch => 0);
	Settings::addControlFile(Settings::getItemsControlFilename(),
		loader => [\&parseItemsControl, \%items_control],
		internalName => 'items_control.txt',
		autoSearch => 0);
	Settings::addControlFile(Settings::getShopFilename(),
		loader => [\&parseShopControl, \%shop],
		internalName => 'shop.txt',
		autoSearch => 0);
	Settings::addControlFile('overallAuth.txt',
		loader => [\&parseDataFile, \%overallAuth]);
	Settings::addControlFile('pickupitems.txt',
		loader => [\&parseDataFile_lc, \%pickupitems]);
	Settings::addControlFile('responses.txt',
		loader => [\&parseResponses, \%responses]);
	Settings::addControlFile('timeouts.txt',
		loader => [\&parseTimeouts, \%timeout]);
	Settings::addControlFile('chat_resp.txt',
		loader => [\&parseChatResp, \@chatResponses]);
	Settings::addControlFile('avoid.txt',
		loader => [\&parseAvoidControl, \%avoid]);
	Settings::addControlFile('priority.txt',
		loader => [\&parsePriority, \%priority]);
	Settings::addControlFile('routeweights.txt',
		loader => [\&parseDataFile, \%routeWeights]);
	Settings::addControlFile('arrowcraft.txt',
		loader => [\&parseDataFile_lc, \%arrowcraft_items]);

	# Loading of Table files
	# Load Servers.txt first
	Settings::addTableFile('servers.txt',
		loader => [\&parseSectionedFile, \%masterServers],
		onLoaded => \&processServerSettings );
	# Load RecvPackets.txt second
 	Settings::addTableFile(Settings::getRecvPacketsFilename(),
 		loader => [\&parseRecvpackets, \%rpackets]);

	# Add 'Old' table pack, if user set
	if ( $sys{locale_compat} == 1) {
		# Holder for new path
		my @new_tables;
		my $pathDelimiter = ($^O eq 'MSWin32') ? ';' : ':';
		if ($options{tables}) {
			foreach my $dir ( split($pathDelimiter, $options{tables}) ) {
				push @new_tables, $dir . '/Old';
			}
		} else {
			push @new_tables, 'tables/Old';
		}
		# now set up new path to table folder
		Settings::setTablesFolders(@new_tables, Settings::getTablesFolders());
	}

	# Load all other tables
	Settings::addTableFile('cities.txt',
		loader => [\&parseROLUT, \%cities_lut]);
	Settings::addTableFile('commanddescriptions.txt',
		loader => [\&parseCommandsDescription, \%descriptions], mustExist => 0);
	Settings::addTableFile('directions.txt',
		loader => [\&parseDataFile2, \%directions_lut]);
	Settings::addTableFile('elements.txt',
		loader => [\&parseROLUT, \%elements_lut]);
	Settings::addTableFile('emotions.txt',
		loader => [\&parseEmotionsFile, \%emotions_lut]);
	Settings::addTableFile('equiptypes.txt',
		loader => [\&parseDataFile2, \%equipTypes_lut]);
	Settings::addTableFile('haircolors.txt',
		loader => [\&parseDataFile2, \%haircolors]);
	Settings::addTableFile('headgears.txt',
		loader => [\&parseArrayFile, \@headgears_lut]);
	Settings::addTableFile('items.txt',
		loader => [\&parseROLUT, \%items_lut]);
	Settings::addTableFile('itemsdescriptions.txt',
		loader => [\&parseRODescLUT, \%itemsDesc_lut], mustExist => 0);
	Settings::addTableFile('itemslots.txt',
		loader => [\&parseROSlotsLUT, \%itemSlots_lut]);
	Settings::addTableFile('itemslotcounttable.txt',
		loader => [\&parseROLUT, \%itemSlotCount_lut]);
	Settings::addTableFile('itemtypes.txt',
		loader => [\&parseDataFile2, \%itemTypes_lut]);
	Settings::addTableFile('resnametable.txt',
		loader => [\&parseROLUT, \%mapAlias_lut, 1, ".gat"]);
	Settings::addTableFile('maps.txt',
		loader => [\&parseROLUT, \%maps_lut]);
	Settings::addTableFile('monsters.txt',
		loader => [\&parseDataFile2, \%monsters_lut], createIfMissing => 1);
	Settings::addTableFile('npcs.txt',
		loader => [\&parseNPCs, \%npcs_lut], createIfMissing => 1);
	Settings::addTableFile('packetdescriptions.txt',
		loader => [\&parseSectionedFile, \%packetDescriptions], mustExist => 0);
	Settings::addTableFile('portals.txt',
		loader => [\&parsePortals, \%portals_lut]);
	Settings::addTableFile('portalsLOS.txt',
		loader => [\&parsePortalsLOS, \%portals_los], createIfMissing => 1);
	Settings::addTableFile('sex.txt',
		loader => [\&parseDataFile2, \%sex_lut]);
	Settings::addTableFile('SKILL_id_handle.txt',
		loader => \&Skill::StaticInfo::parseSkillsDatabase_id2handle);
	Settings::addTableFile('skillnametable.txt',
		loader => \&Skill::StaticInfo::parseSkillsDatabase_handle2name, mustExist => 0);
	Settings::addTableFile('spells.txt',
		loader => [\&parseDataFile2, \%spells_lut]);
	Settings::addTableFile('skillsdescriptions.txt',
		loader => [\&parseRODescLUT, \%skillsDesc_lut], mustExist => 0);
	Settings::addTableFile('skillssp.txt',
		loader => \&Skill::StaticInfo::parseSPDatabase);
	Settings::addTableFile('STATUS_id_handle.txt', loader => [\&parseDataFile2, \%statusHandle]);
	Settings::addTableFile('STATE_id_handle.txt', loader => [\&parseDataFile2, \%stateHandle]);
	Settings::addTableFile('LOOK_id_handle.txt', loader => [\&parseDataFile2, \%lookHandle]);
	Settings::addTableFile('AILMENT_id_handle.txt', loader => [\&parseDataFile2, \%ailmentHandle]);
	Settings::addTableFile('MAPTYPE_id_handle.txt', loader => [\&parseDataFile2, \%mapTypeHandle]);
	Settings::addTableFile('MAPPROPERTY_TYPE_id_handle.txt', loader => [\&parseDataFile2, \%mapPropertyTypeHandle]);
	Settings::addTableFile('MAPPROPERTY_INFO_id_handle.txt', loader => [\&parseDataFile2, \%mapPropertyInfoHandle]);
	Settings::addTableFile('statusnametable.txt', loader => [\&parseDataFile2, \%statusName], mustExist => 0);
	Settings::addTableFile('skillsarea.txt', loader => [\&parseDataFile2, \%skillsArea]);
	Settings::addTableFile('skillsencore.txt', loader => [\&parseList, \%skillsEncore]);
	Settings::addTableFile('quests.txt', loader => [\&parseROQuestsLUT, \%quests_lut], mustExist => 0);
	Settings::addTableFile('effects.txt', loader => [\&parseDataFile2, \%effectName], mustExist => 0);
	Settings::addTableFile('msgstringtable.txt', loader => [\&parseArrayFile, \@msgTable], mustExist => 0);

	use utf8;

	Plugins::callHook('start2');
	eval {
		my $progressHandler = sub {
			my ($filename) = @_;
			message TF("Loading %s...\n", $filename);
		};
		Settings::loadAll($progressHandler);
	};
	my $e;
	if ($e = caught('UTF8MalformedException')) {
		$interface->errorDialog(TF(
			"The file %s must be in UTF-8 encoding.",
			$e->textfile));
		$quit = 1;
	} elsif ($e = caught('FileNotFoundException')) {
		$interface->errorDialog(TF("Unable to load the file %s.", $e->filename));
		$quit = 1;
	} elsif ($@) {
		die $@;
	}
	return if $quit;

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
}

sub initNetworking {
	our $XKore_dontRedirect = 0;
	my $XKore_version = $config{XKore};
	eval {
		$clientPacketHandler = Network::ClientReceive->new;
		
		if ($XKore_version eq "1") {
			# Inject DLL to running Ragnarok process
			require Network::XKore;
			$net = new Network::XKore;
		} elsif ($XKore_version eq "2") {
			# Run as a proxy bot, allowing Ragnarok to connect while botting
			require Network::DirectConnection;
			require Network::XKore2;
			$net = new Network::DirectConnection;
			Network::XKore2::start();
		} elsif ($XKore_version eq "3") {
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
		$quit = 1;
		return;
	}

	if ($sys{bus}) {
		require Bus::Client;
		require Bus::Handlers;
		my $host = $sys{bus_server_host};
		my $port = $sys{bus_server_port};
		my $userAgent = $sys{bus_userAgent};
		$host = undef if ($host eq '');
		$port = undef if ($port eq '');
		$bus = new Bus::Client(host => $host, port => $port, userAgent => $userAgent);
		our $busMessageHandler = new Bus::Handlers($bus);
	}
	
	Network::PaddedPackets::init();
}

sub initPortalsDatabase {
	# $config{portalCompile}
	# -1: skip compile
	#  0: ask user
	#  1: auto compile
	
	# TODO: detect when another instance already compiles portals?
	
	return if $config{portalCompile} < 0;
	
	Log::message(T("Checking for new portals... "));
	if (compilePortals_check()) {
		Log::message(T("found new portals!\n"));
		my $choice = $config{portalCompile} ? 0 : $interface->showMenu(
			T("New portals have been added to the portals database. " .
			"The portals database must be compiled before the new portals can be used. " .
			"Would you like to compile portals now?\n"),
			[T("Yes, compile now."), T("No, don't compile it.")],
			title => T("Compile portals?"));
		if ($choice == 0) {
			Log::message(T("compiling portals") . "\n\n");
			compilePortals();
		} else {
			Log::message(T("skipping compile") . "\n\n");
		}
	} else {
		Log::message(T("none found\n\n"));
	}
}

sub promptFirstTimeInformation {
	if ($net->version != 1) {
		my $msg;
		if (!$config{username}) {
			$msg = $interface->query(T("Please enter your Ragnarok Online username."));
			if (!defined($msg)) {
				$quit = 1;
				return;
			}
			configModify('username', $msg, 1);
		}
		if (!$config{password}) {
			$msg = $interface->query(T("Please enter your Ragnarok Online password."), isPassword => 1);
			if (!defined($msg)) {
				$quit = 1;
				return;
			}
			configModify('password', $msg, 1);
		}
	}
}

sub processServerSettings {
	my $filename = shift;
	# Select Master server on Demand

	if ($config{master} eq "" || $config{master} =~ /^\d+$/ || !exists $masterServers{$config{master}}) {
		my @servers = sort { lc($a) cmp lc($b) } keys(%masterServers);
		@servers = grep { not $masterServers{$_}{dead} } @servers;
		my $choice = $interface->showMenu(
			T("Please choose a master server to connect to."),
			[map { $masterServers{$_}{title} || $_ } @servers],
			title => T("Master servers"));
		if ($choice == -1) {
			$quit = 1;
			return;
		} else {
			bulkConfigModify({
				master => $servers[$choice],
				# ask for server and character if we're connected to "new" master server
				server => '',
				char => '',
			}, 1);
		}
	}

	# Parse server settings
	my $master = $masterServer = $masterServers{$config{master}};
	
	# Stop if server now marked as dead
	if ($master->{dead}) {
		$interface->errorDialog($master->{dead_message} || TF("Server you've selected (%s) is now marked as dead.", $master->{title} || $config{master}));
		$quit = 1;
		return;
	}

	# Check for required options
	my @options;
	if ($config{'XKore'} eq "1") {
		@options = 'serverType';
	} else {
		@options = qw(ip port master_version version serverType);
	}
	if (my @missingOptions = grep { $master->{$_} eq '' } @options) {
		$interface->errorDialog(TF("Required server options are not set: %s\n", "@missingOptions"));
		$quit = 1;
		return;
	}
	
	foreach my $serverOption ('storageEncryptKey', 'gameGuard','paddedPackets','paddedPackets_attackID',
				'paddedPackets_skillUseID') {
		if ($master->{$serverOption} ne '' && !(defined $config{$serverOption})) {
			# Delete Wite Space
			# why only one, if deleting any?
			$master->{$serverOption} =~ s/^\s//;
			# can't happen due to FileParsers::parseSectionedFile
			$master->{$serverOption} =~ s/\s$//;
			# Set config
			configModify($serverOption, $master->{$serverOption});
		}
	}
	
	# Process adding Custom Table folders
	if($masterServer->{addTableFolders}) {
		Settings::addTablesFolders($masterServer->{addTableFolders});
	}
	
	# Process setting custom recvpackets option
	Settings::setRecvPacketsName($masterServer->{recvpackets} && $masterServer->{recvpackets} ne '' ? $masterServer->{recvpackets} : Settings::getRecvPacketsFilename() );
}

sub finalInitialization {
	$incomingMessages = new Network::MessageTokenizer(\%rpackets);
	$outgoingClientMessages = new Network::MessageTokenizer(\%rpackets);

	$KoreStartTime = time;
	$conState = 1;
	our $nextConfChangeTime;
	$bExpSwitch = 2;
	$jExpSwitch = 2;
	$totalBaseExp = 0;
	$totalJobExp = 0;
	$startTime_EXP = time;
	$taskManager = new TaskManager();

	if (DEBUG) {
		# protect various stuff from autovivification
		
		require Utils::BlessedRefTie;
		tie $char, 'Tie::BlessedRef';
		
		require Utils::ActorHashTie;
		tie %items, 'Tie::ActorHash';
		tie %monsters, 'Tie::ActorHash';
		tie %players, 'Tie::ActorHash';
		tie %pets, 'Tie::ActorHash';
		tie %npcs, 'Tie::ActorHash';
		tie %portals, 'Tie::ActorHash';
		tie %slaves, 'Tie::ActorHash';
	}

	$itemsList = new ActorList('Actor::Item');
	$monstersList = new ActorList('Actor::Monster');
	$playersList = new ActorList('Actor::Player');
	$petsList = new ActorList('Actor::Pet');
	$npcsList = new ActorList('Actor::NPC');
	$portalsList = new ActorList('Actor::Portal');
	$slavesList = new ActorList('Actor::Slave');
	foreach my $list ($itemsList, $monstersList, $playersList, $petsList, $npcsList, $portalsList, $slavesList) {
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
	
	Log::message("Initialized, use 'connect' to continue\n") if $Settings::no_connect;

	Plugins::callHook('initialized');
	XSTools::initVersion();
}


#######################################
# VARIABLE INITIALIZATION FUNCTIONS
#######################################

# Calculate next random restart time.
# The restart time will be autoRestartMin + rand(autoRestartSeed)
sub initRandomRestart {
	if ($config{'autoRestart'}) {
		my $autoRestart = $config{'autoRestartMin'} + int(rand $config{'autoRestartSeed'});
		message TF("Next restart in %s\n", timeConvert($autoRestart)), "system";
		configModify("autoRestart", $autoRestart, 1);
	}
}

# Initialize random configuration switching time
sub initConfChange {
	my $i = 0;
	while (exists $ai_v{"autoConfChange_${i}_timeout"}) {
		delete $ai_v{"autoConfChange_${i}_timeout"};
		$i++;
	}

	$i = 0;
	while (exists $config{"autoConfChange_$i"}) {
		$ai_v{"autoConfChange_${i}_timeout"} = $config{"autoConfChange_${i}_minTime"} +
			int(rand($config{"autoConfChange_${i}_varTime"}));
		$i++;
	}
	$lastConfChangeTime = time;
}

# Initialize variables when you start a connection to a map server
sub initConnectVars {
	# we must use $chars[$config{char}] here because $char may not be set
	initMapChangeVars();
	if ($char) {
		$char->{skills} = {};
		delete $char->{spirits};
		delete $char->{mute_period};
		delete $char->{muted};
		delete $char->{party};
		delete $char->{statuses};
	}
	undef @skillsID;
	undef @partyUsersID;
	undef %cashShop;
}

# Initialize variables when you change map (after a teleport or after you walked into a portal)
sub initMapChangeVars {
	# we must use $chars[$config{char}] here because $char may not be set
	@portalsID_old = @portalsID;
	%portals_old = %portals;
	foreach (@portalsID_old) {
		next if (!$_ || !$portals_old{$_});
		$portals_old{$_}{gone_time} = time if (!$portals_old{$_}{gone_time});
	}

	# this is just used for portalRecord (add opposite portal by guessing method)
	if ($char) {
		$char->{old_pos_to} = {%{$char->{pos_to}}} if ($char->{pos_to});
		delete $char->{sitting};
		delete $char->{dead};
		delete $char->{warp};
		delete $char->{casting};
		delete $char->{homunculus}{appear_time} if $char->{homunculus};
		$char->inventory->clear();
	}
	$timeout{play}{time} = time;
	$timeout{ai_sync}{time} = time;
	$timeout{ai_sit_idle}{time} = time;
	$timeout{ai_teleport}{time} = time;
	$timeout{ai_teleport_idle}{time} = time;
	$timeout{ai_teleport_safe_force}{time} = time;

	delete $timeout{ai_teleport_retry}{time};
	delete $timeout{ai_teleport_delay}{time};

	undef %incomingDeal;
	undef %outgoingDeal;
	undef %currentDeal;
	undef $currentChatRoom;
	undef @currentChatRoomUsers;
	undef @itemsID;
	undef @identifyID;
	undef @spellsID;
	undef @arrowCraftID;
	undef %items;
	undef %spells;
	undef %incomingParty;
	undef %talk;
	$ai_v{cart_time} = time + 60;
	$ai_v{inventory_time} = time + 60;
	$ai_v{temp} = {};
	$cart{inventory} = [];
	delete $storage{opened};
	undef @venderItemList;
	undef $venderID;
	undef $venderCID;
	undef @venderListsID;
	undef %venderLists;
	undef $buyerID;
	undef $buyingStoreID;
	undef @buyerListsID;
	undef %buyerLists;
	undef %incomingGuild;
	undef @chatRoomsID;
	undef %chatRooms;
	undef %createdChatRoom;
	undef @lastpm;
	undef %incomingFriend;
	undef $repairList;
	undef $devotionList;
	undef $cookingList;
	$captcha_state = 0;

	$itemsList->clear();
	$monstersList->clear();
	$playersList->clear();
	$petsList->clear();
	$portalsList->clear();
	$npcsList->clear();
	$slavesList->clear();

	@unknownPlayers = ();
	@unknownNPCs = ();
	@sellList = ();

	$shopstarted = 0;
	$timeout{ai_shop}{time} = time;
	$timeout{ai_storageAuto}{time} = time + 5;
	$timeout{ai_buyAuto}{time} = time + 5;
	$timeout{ai_shop}{time} = time;

	AI::clear(qw(attack move teleport));
	AI::SlaveManager::clear("attack", "route", "move");
	ChatQueue::clear;

	Plugins::callHook('packet_mapChange');

	$logAppend = ($config{logAppendUsername}) ? "_$config{username}_$config{char}" : '';
	$logAppend = ($config{logAppendServer}) ? "_$servers[$config{'server'}]{'name'}".$logAppend : $logAppend;
	
	if ($config{logAppendUsername} && index($Settings::storage_log_file, $logAppend) == -1) {
		$Settings::chat_log_file     = substr($Settings::chat_log_file,    0, length($Settings::chat_log_file)    - 4) . "$logAppend.txt";
		$Settings::storage_log_file  = substr($Settings::storage_log_file, 0, length($Settings::storage_log_file) - 4) . "$logAppend.txt";
		$Settings::shop_log_file     = substr($Settings::shop_log_file,    0, length($Settings::shop_log_file)    - 4) . "$logAppend.txt";
		$Settings::monster_log_file  = substr($Settings::monster_log_file, 0, length($Settings::monster_log_log)  - 4) . "$logAppend.txt";
		$Settings::item_log_file     = substr($Settings::item_log_file,    0, length($Settings::item_log_file)    - 4) . "$logAppend.txt";
	}
}

# Initialize variables when your character logs in
sub initStatVars {
	$totaldmg = 0;
	$dmgpsec = 0;
	$startedattack = 0;
	$monstarttime = 0;
	$monkilltime = 0;
	$elasped = 0;
	$totalelasped = 0;
}


#####################################################
# MISC. MAIN LOOP FUNCTIONS
#####################################################


# This function is called every time in the main loop, when OpenKore has been
# fully initialized.
sub mainLoop_initialized {
	Benchmark::begin("mainLoop_part1") if DEBUG;

	# Handle connection states
	$net->checkConnection();

	# Receive and handle data from the RO server
	my $data = $net->serverRecv;
	if (defined($data) && length($data) > 0) {
		Benchmark::begin("parseMsg") if DEBUG;

		$incomingMessages->add($data);
		$net->clientSend($_) for $packetParser->process(
			$incomingMessages, $packetParser
		);
		$net->clientFlush() if (UNIVERSAL::isa($net, 'Network::XKoreProxy'));
		Benchmark::end("parseMsg") if DEBUG;
	}

	# Receive and handle data from the RO client
	$data = $net->clientRecv;
	if (defined($data) && length($data) > 0) {
		my $type;
		#$messageSender->encryptMessageID(\$data);
		$outgoingClientMessages->add($data);
		$messageSender->sendToServer($_) for $messageSender->process(
			$outgoingClientMessages, $clientPacketHandler
		);
	}

	# GameGuard support
	if ($config{gameGuard} && ($net->version != 1 || ($net->version == 1 && $config{gameGuard} eq '2'))) {
		my $result = Poseidon::Client::getInstance()->getResult();
		if (defined($result)) {
			debug "Received Poseidon result.\n", "poseidon";
			#$messageSender->encryptMessageID(\$result, unpack("v", $result));
			$messageSender->sendToServer($result);
		}
	}

	Benchmark::end("mainLoop_part1") if DEBUG;
	Benchmark::begin("mainLoop_part2") if DEBUG;

	# Process AI
	if ($net->getState() == Network::IN_GAME && timeOut($timeout{ai}) && $net->serverAlive()) {
		Misc::checkValidity("AI (pre)");
		Benchmark::begin("ai") if DEBUG;
		AI::CoreLogic::iterate();
		Benchmark::end("ai") if DEBUG;
		Benchmark::begin("ai_homunculus") if DEBUG;
		AI::SlaveManager::iterate();
		Benchmark::end("ai_homunculus") if DEBUG;
		Misc::checkValidity("AI");
		return if $quit;
	}
	Misc::checkValidity("mainLoop_part2.1");
	$taskManager->iterate();

	Benchmark::end("mainLoop_part2") if DEBUG;
	Benchmark::begin("mainLoop_part3") if DEBUG;

	# Process bus events.
	$bus->iterate() if ($bus);
	Misc::checkValidity("mainLoop_part2.2");


	###### Other stuff that's run in the main loop #####

	if ($config{'autoRestart'} && time - $KoreStartTime > $config{'autoRestart'}
	 && $net->getState() == Network::IN_GAME && !AI::inQueue(qw/attack take items_take/)) {
		message T("\nAuto-restarting!!\n"), "system";

		if ($config{'autoRestartSleep'}) {
			my $sleeptime = $config{'autoSleepMin'} + int(rand $config{'autoSleepSeed'});
			$timeout_ex{'master'}{'timeout'} = $sleeptime;
			$sleeptime = $timeout{'reconnect'}{'timeout'} if ($sleeptime < $timeout{'reconnect'}{'timeout'});
			message TF("Sleeping for %s\n", timeConvert($sleeptime)), "system";
		} else {
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		}

		$timeout_ex{'master'}{'time'} = time;
		$KoreStartTime = time + $timeout_ex{'master'}{'timeout'};
		AI::clear();
		AI::SlaveManager::clear();
		undef %ai_v;
		$net->serverDisconnect;
		$net->setState(Network::NOT_CONNECTED);
		undef $conState_tries;
		initRandomRestart();
	}
	
	Misc::checkValidity("mainLoop_part2.3");

	# Automatically switch to a different config file
	# based on certain conditions
	if ($net->getState() == Network::IN_GAME && timeOut($AI::Timeouts::autoConfChangeTime, 0.5)
	 && !AI::inQueue(qw/attack take items_take/)) {
		my $selected;
		my $i = 0;
		while (exists $config{"autoConfChange_$i"}) {
			if ($config{"autoConfChange_$i"}
			 && ( !$config{"autoConfChange_${i}_minTime"} || timeOut($lastConfChangeTime, $ai_v{"autoConfChange_${i}_timeout"}) )
			 && inRange($char->{lv}, $config{"autoConfChange_${i}_lvl"})
			 && inRange($char->{lv_job}, $config{"autoConfChange_${i}_joblvl"})
			 && ( !$config{"autoConfChange_${i}_isJob"} || $jobs_lut{$char->{jobID}} eq $config{"autoConfChange_${i}_isJob"} )
			) {
				$selected = $config{"autoConfChange_$i"};
				last;
			}
			$i++;
		}

		if ($selected) {
			# Choose a random configuration file
			my @files = split(/,+/, $selected);
			my $file = $files[rand(@files)];
			message TF("Changing configuration file (from \"%s\" to \"%s\")...\n", $Settings::config_file, $file), "system";

			# A relogin is necessary if the server host/port, username
			# or char is different.
			my $oldMaster = $masterServer;
			my $oldUsername = $config{'username'};
			my $oldChar = $config{'char'};

			switchConfigFile($file);

			my $master = $masterServer = $masterServers{$config{'master'}};
			if ($net->version != 1
			 && $oldMaster->{ip} ne $master->{ip}
			 || $oldMaster->{port} ne $master->{port}
			 || $oldMaster->{master_version} ne $master->{master_version}
			 || $oldMaster->{version} ne $master->{version}
			 || $oldUsername ne $config{'username'}
			 || $oldChar ne $config{'char'}) {
				AI::clear;
				AI::SlaveManager::clear();
				relog();
			} else {
				AI::clear("move", "route", "mapRoute");
				AI::SlaveManager::clear("move", "route", "mapRoute");
			}

			initConfChange();
		}

		$AI::Timeouts::autoConfChangeTime = time;
	}

	#processStatisticsReporting() unless ($sys{sendAnonymousStatisticReport} eq "0");

	Misc::checkValidity("mainLoop_part2.4");
	
	# Set interface title
	my $charName;
	my $title;
	$charName = "$char->{name}: " if ($char);
	if ($net->getState() == Network::IN_GAME) {
		my ($basePercent, $jobPercent, $weight, $pos);

		assert(defined $char);
		$basePercent = sprintf("%.2f", $char->{exp} / $char->{exp_max} * 100) if ($char->{exp_max});
		$jobPercent = sprintf("%.2f", $char->{exp_job} / $char->{exp_job_max} * 100) if ($char->{exp_job_max});
		$weight = int($char->{weight} / $char->{weight_max} * 100) . "%" if ($char->{weight_max});
		$pos = " : $char->{pos_to}{x},$char->{pos_to}{y} " . $field->name if ($char->{pos_to} && $field);

		# Translation Comment: Interface Title with character status
		$title = TF("%s B%s (%s), J%s (%s) : w%s%s - %s",
			$charName, $char->{lv}, $basePercent . '%',
			$char->{lv_job}, $jobPercent . '%',
			$weight, $pos, $Settings::NAME);

	} elsif ($net->getState() == Network::NOT_CONNECTED) {
		# Translation Comment: Interface Title
		$title = TF("%sNot connected - %s", $charName, $Settings::NAME);
	} else {
		# Translation Comment: Interface Title
		$title = TF("%sConnecting - %s", $charName, $Settings::NAME);
	}
	my %args = (return => $title);
	Plugins::callHook('mainLoop::setTitle',\%args);
	$interface->title($args{return});

	Misc::checkValidity("mainLoop_part3");
	Benchmark::end("mainLoop_part3") if DEBUG;
}

=pod
# Anonymous statistics reporting. This gives us insight about
# servers that our users bot on.
sub processStatisticsReporting {
	our %statisticsReporting;
	if (!$statisticsReporting{reported} && $config{master} && $config{username}) {
		if (!$statisticsReporting{http}) {
			use Utils qw(urlencode);
			import Utils::Whirlpool qw(whirlpool_hex);

			# Note that ABSOLUTELY NO SENSITIVE INFORMATION about the
			# user is sent. The username is filtered through an
			# irreversible hashing algorithm before it is sent to the
			# server. It is impossible to deduce the user's username
			# from the data sent to the server.
			#
			# If you're still not convinced about the security of this,
			# please read the following web pages for more details and explanation:
			#   http://www.openkore.com/statistics.php
			# -and-
			#   http://forums.openkore.com/viewtopic.php?t=28044
			my $url = "http://www.openkore.com/statistics.php";
			my $post = "server=" . urlencode($config{master});
			$post .= "&product=" . urlencode($Settings::NAME);
			$post .= "&version=" . urlencode($Settings::VERSION);
			$post .= "&uid=" . urlencode(whirlpool_hex($config{master} . $config{username} . $userSeed));
			$statisticsReporting{http} = new StdHttpReader($url, $post);
			debug "Posting anonymous usage statistics to $url\n", "statisticsReporting";
		}

		my $http = $statisticsReporting{http};
		if ($http->getStatus() == HttpReader::DONE) {
			$statisticsReporting{reported} = 1;
			delete $statisticsReporting{http};
			debug "Statistics posting completed.\n", "statisticsReporting";

		} elsif ($http->getStatus() == HttpReader::ERROR) {
			$statisticsReporting{reported} = 1;
			delete $statisticsReporting{http};
			debug "Statistics posting failed: " . $http->getError() . "\n", "statisticsReporting";
		}

	} elsif (!$statisticsReporting{infoPosted} && $masterServer && $masterServer->{ip}
	      && $config{master} && $net && $net->getState() == Network::IN_GAME && $monstarttime) {
		if (!$statisticsReporting{http}) {
			my $url = "http://www.openkore.com/server-info.php";
			my $serverData = "";
			foreach my $key (sort keys %{$masterServer}) {
				$serverData .= "$key $masterServer->{$key}\n";
			}
			my $post = "server=" . urlencode($config{master}) . "&data=" . urlencode($serverData);
			$statisticsReporting{http} = new StdHttpReader($url, $post);
			debug "Posting server info to $url\n", "statisticsReporting";
		}

		my $http = $statisticsReporting{http};
		if ($http->getStatus() == HttpReader::DONE) {
			$statisticsReporting{infoPosted} = 1;
			delete $statisticsReporting{http};
			debug "Server info posting completed.\n", "statisticsReporting";

		} elsif ($http->getStatus() == HttpReader::ERROR) {
			$statisticsReporting{infoPosted} = 1;
			delete $statisticsReporting{http};
			debug "Server info posting failed: " . $http->getError() . "\n", "statisticsReporting";
		}
	}
}
=cut

sub parseInput {
	my $input = shift;
	my $printType;
	my ($hook, $msg);
	$printType = shift if ($net && $net->clientAlive);

	debug("Input: $input\n", "parseInput", 2);

	if ($printType) {
		my $hookOutput = sub {
			my ($type, $domain, $level, $globalVerbosity, $message, $user_data) = @_;
			$msg .= $message if ($type ne 'debug' && $level <= $globalVerbosity);
		};
		$hook = Log::addHook($hookOutput);
		$interface->writeOutput("console", "$input\n");
	}
	$XKore_dontRedirect = 1;

	Commands::run($input);

	if ($printType) {
		Log::delHook($hook);
		if (defined $msg && $net->getState() == Network::IN_GAME && $config{XKore_silent}) {
			$msg =~ s/\n*$//s;
			$msg =~ s/\n/\\n/g;
			sendMessage($messageSender, "k", $msg);
		}
	}
	$XKore_dontRedirect = 0;
}

return 1;
