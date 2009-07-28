package KoreStage::DataFiles;

use strict;

# Coro Support
use Coro;


use Globals qw(
		$interface
		%config
		%mon_control
		%items_control
		%shop
		%overallAuth
		%pickupitems
		%responses
		%timeout
		@chatResponses
		%avoid
		%priority
		%consoleColors
		%routeWeights
		%arrowcraft_items
		%rpackets
		%cities_lut
		%descriptions
		%directions_lut
		%elements_lut
		%emotions_lut
		%equipTypes_lut
		%haircolors
		@headgears_lut
		%items_lut
		%itemsDesc_lut
		%itemSlots_lut
		%itemSlotCount_lut
		%itemTypes_lut
		%maps_lut
		%monsters_lut
		%npcs_lut
		%packetDescriptions
		%portals_lut
		%portals_los
		%masterServers
		%sex_lut
		%spells_lut
		%skillsDesc_lut
		%skillsSP_lut
		%skillsStatus
		%skillsAilments
		%skillsState
		%skillsLooks
		%skillsArea
		%skillsEncore
		);
use Settings;
use FileParsers;
use Log qw(message warning error debug);
use Translation qw(T TF);
use Utils;
use Utils::Exceptions;
use Plugins;
use Skill;
use Misc::Config;
use KoreStage;
use base qw(KoreStage);

use Modules 'register';


sub new {
	my $class = shift;
	my %args = @_;
	my $self = {};
	bless $self, $class;
	$self->{priority} = 2;

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->SUPER::DESTROY();
}

sub load {
	my ($self) = @_;
	# no encoding 'utf8';

	Settings::addControlFile(Settings::getConfigFilename(),		loader => [\&FileParsers::parseConfigFile, 		\%config],		autoSearch => 0);
	Settings::addControlFile(Settings::getMonControlFilename(),	loader => [\&FileParsers::parseMonControl, 		\%mon_control],		autoSearch => 0);
	Settings::addControlFile(Settings::getItemsControlFilename(),	loader => [\&FileParsers::parseItemsControl, 		\%items_control],	autoSearch => 0);
	Settings::addControlFile(Settings::getShopFilename(),		loader => [\&FileParsers::parseShopControl, 		\%shop],		autoSearch => 0);
	Settings::addControlFile('overallAuth.txt', 			loader => [\&FileParsers::parseDataFile, 		\%overallAuth]);
	Settings::addControlFile('pickupitems.txt', 			loader => [\&FileParsers::parseDataFile_lc, 		\%pickupitems]);
	Settings::addControlFile('responses.txt',   			loader => [\&FileParsers::parseResponses, 		\%responses]);
	Settings::addControlFile('timeouts.txt',    			loader => [\&FileParsers::parseTimeouts, 		\%timeout]);
	Settings::addControlFile('chat_resp.txt',   			loader => [\&FileParsers::parseChatResp, 		\@chatResponses]);
	Settings::addControlFile('avoid.txt',       			loader => [\&FileParsers::parseAvoidControl, 		\%avoid]);
	Settings::addControlFile('priority.txt',    			loader => [\&FileParsers::parsePriority, 		\%priority]);
	Settings::addControlFile('consolecolors.txt', 			loader => [\&FileParsers::parseSectionedFile,		\%consoleColors]);
	Settings::addControlFile('routeweights.txt',  			loader => [\&FileParsers::parseDataFile, 		\%routeWeights]);
	Settings::addControlFile('arrowcraft.txt',  			loader => [\&FileParsers::parseDataFile_lc, 		\%arrowcraft_items]);

	Settings::addTableFile(Settings::getRecvPacketsFilename(),	loader => [\&FileParsers::parseDataFile2, 		\%rpackets],		autoSearch => 0);
	Settings::addTableFile('cities.txt',      			loader => [\&FileParsers::parseROLUT, 			\%cities_lut]);
	Settings::addTableFile('commanddescriptions.txt', 		loader => [\&FileParsers::parseCommandsDescription, 	\%descriptions]);
	Settings::addTableFile('directions.txt',  			loader => [\&FileParsers::parseDataFile2, 		\%directions_lut]);
	Settings::addTableFile('elements.txt',    			loader => [\&FileParsers::parseROLUT, 			\%elements_lut]);
	Settings::addTableFile('emotions.txt',    			loader => [\&FileParsers::parseEmotionsFile, 		\%emotions_lut]);
	Settings::addTableFile('equiptypes.txt',  			loader => [\&FileParsers::parseDataFile2, 		\%equipTypes_lut]);
	Settings::addTableFile('haircolors.txt',  			loader => [\&FileParsers::parseDataFile2, 		\%haircolors]);
	Settings::addTableFile('headgears.txt',   			loader => [\&FileParsers::parseArrayFile, 		\@headgears_lut]);
	Settings::addTableFile('items.txt',       			loader => [\&FileParsers::parseROLUT, 			\%items_lut]);
	Settings::addTableFile('itemsdescriptions.txt',   		loader => [\&FileParsers::parseRODescLUT, 		\%itemsDesc_lut]);
	Settings::addTableFile('itemslots.txt',   			loader => [\&FileParsers::parseROSlotsLUT, 		\%itemSlots_lut]);
	Settings::addTableFile('itemslotcounttable.txt',  		loader => [\&FileParsers::parseROLUT, 			\%itemSlotCount_lut]);
	Settings::addTableFile('itemtypes.txt',   			loader => [\&FileParsers::parseDataFile2,		\%itemTypes_lut]);
	Settings::addTableFile('maps.txt',        			loader => [\&FileParsers::parseROLUT, 			\%maps_lut]);
	Settings::addTableFile('monsters.txt',    			loader => [\&FileParsers::parseDataFile2, 		\%monsters_lut]);
	Settings::addTableFile('npcs.txt',        			loader => [\&FileParsers::parseNPCs, 			\%npcs_lut]);
	Settings::addTableFile('packetdescriptions.txt', 		loader => [\&FileParsers::parseSectionedFile, 		\%packetDescriptions]);
	Settings::addTableFile('portals.txt',     			loader => [\&FileParsers::parsePortals,			\%portals_lut]);
	Settings::addTableFile('portalsLOS.txt',  			loader => [\&FileParsers::parsePortalsLOS, 		\%portals_los]);
	Settings::addTableFile('servers.txt',     			loader => [\&FileParsers::parseSectionedFile, 		\%masterServers]);
	Settings::addTableFile('sex.txt',         			loader => [\&FileParsers::parseDataFile2, 		\%sex_lut]);
	Settings::addTableFile('skills.txt',      			loader => [\&Skill::StaticInfo::parseSkillsDatabase]);
	Settings::addTableFile('spells.txt',      			loader => [\&FileParsers::parseDataFile2, 		\%spells_lut]);
	Settings::addTableFile('skillsdescriptions.txt',  		loader => [\&FileParsers::parseRODescLUT, 		\%skillsDesc_lut]);
	Settings::addTableFile('skillssp.txt',    			loader => [\&FileParsers::parseSkillsSPLUT, 		\%skillsSP_lut]);
	Settings::addTableFile('skillssp.txt',    			loader => [\&Skill::StaticInfo::parseSPDatabase]);
	Settings::addTableFile('skillsstatus.txt',        		loader => [\&FileParsers::parseDataFile2, 		\%skillsStatus]);
	Settings::addTableFile('skillsailments.txt',      		loader => [\&FileParsers::parseDataFile2, 		\%skillsAilments]);
	Settings::addTableFile('skillsstate.txt', 			loader => [\&FileParsers::parseDataFile2, 		\%skillsState]);
	Settings::addTableFile('skillslooks.txt', 			loader => [\&FileParsers::parseDataFile2, 		\%skillsLooks]);
	Settings::addTableFile('skillsarea.txt',  			loader => [\&FileParsers::parseDataFile2, 		\%skillsArea]);
	Settings::addTableFile('skillsencore.txt',        		loader => [\&FileParsers::parseList, 			\%skillsEncore]);

	# use encoding 'utf8';

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
			"The file %s must be valid UTF-8 encoded, which it is \n" .
			"currently not. To solve this prolem, please use Notepad\n" .
			"to save that file as valid UTF-8.",
			$e->textfile));
		exit 1;
	} elsif ($e = caught('FileNotFoundException')) {
		$interface->errorDialog(TF("Unable to load the file %s.", $e->filename));
		exit 1;
	} elsif ($@) {
		die $@;
	}


	Plugins::callHook('start3');

	if ($config{'adminPassword'} eq 'x' x 10) {
		Log::message(T("\nAuto-generating Admin Password due to default...\n"));
		Misc::Config::configModify("adminPassword", Utils::vocalString(8));
	#} elsif ($config{'adminPassword'} eq '') {
	#	# This is where we protect the stupid from having a blank admin password
	#	Log::message(T("\nAuto-generating Admin Password due to blank...\n"));
	#	Misc::Config::configModify("adminPassword", Utils::vocalString(8));
	} elsif ($config{'secureAdminPassword'} eq '1') {
		# This is where we induldge the paranoid and let them have session generated admin passwords
		Log::message(T("\nGenerating session Admin Password...\n"));
		Misc::Config::configModify("adminPassword", Utils::vocalString(8));
	}

	Log::message("\n");
}

1;
