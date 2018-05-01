package vendingLog;

use strict;

use Commands;
use Globals qw(%timeout $messageSender $net %config);
use Settings qw(%sys);
use I18N qw(bytesToString);
use Log qw(warning message debug);
use Misc qw(shopLog center setTimeout configModify);
use Plugins;
use Utils qw(getHex timeOut swrite getFormattedDateShort formatNumber);
use Utils::DataStructures qw(binRemoveAllAndShift);

use lib $Plugins::current_plugin_folder;
use VendingLog::HookManager;

use constant {
	PACKET_STRING => "shop_sold_long",
	
	PLUGIN_PREFIX => "[vendingLog]",
	PLUGIN_NAME => "vendingLog",
	PLUGIN_PODIR => "$Plugins::current_plugin_folder/po",
	
	TIMEOUT_KEY_REQUEST => "vendingLog_request",
	TIMEOUT_VALUE_REQUEST => 5,
	
	MAX_ATTEMPTS_KEY_REQUEST => "vendingLog_maxAttempts",
	MAX_ATTEMPTS_VALUE_REQUEST => 3,
	
	COMMAND_HANDLE => "vendinglog",
	
	DATE_FORMAT_KEY => "vendingLog_dateFormat",
	
	DATE_FORMAT_VALUE_X_MEANING => [ "y-m-d", "h:m:s", "Mon d h:m:s y" ],
};

my $translator = new Translation(PLUGIN_PODIR, $sys{locale});
my $main_command;
my $terminateWhenDone = 0;

my %shopLog;
my %knownNames;
my %requestCounter;

my @requestQueue;

my %hooks = (
	init => new VendingLog::HookManager("start3", \&onInitialized),
	shop_sold => new VendingLog::HookManager("vending_item_sold", \&onItemSold),
	shop_close => new VendingLog::HookManager("shop_closed", \&onShopClose),
	packet_character_name => new VendingLog::HookManager("packet/character_name", \&onReceiveCharacterName),
	mainLoop_post => new VendingLog::HookManager("mainLoop_post", \&onMainLoop),
);

Plugins::register(PLUGIN_NAME, $translator->translate("Logs vending for servers with shop_sold_long"), \&onUnload, \&onReload);
$hooks{init}->hook();

# We sold something!
sub onItemSold {
	my (undef, $args) = @_;
	
	my $charID = getHex($args->{buyerCharID});
	
	debug $translator->translatef("%s We sold something to %s!\n", PLUGIN_PREFIX, $charID);
	
	unless ($args->{packetType} eq "long") {
		warning $translator->translatef("%s Your sever doesn't use %s, unloading %s\n", PLUGIN_PREFIX, PACKET_STRING, PLUGIN_NAME);
		Plugins::unload("vendingLog");
		return;
	}
	
	if (exists $knownNames{$charID}) {
		debug $translator->translatef("%s Already known buyer, using cached name (%s)\n", PLUGIN_PREFIX, $knownNames{$charID});
	} else {
		debug $translator->translatef("%s New charID, queuing name request.\n", PLUGIN_PREFIX);

		push @requestQueue, $args->{buyerCharID};
		$hooks{mainLoop_post}->hook();
	}
	
	push @{$shopLog{$charID}{item}}, $args->{vendArticle}{name};
	push @{$shopLog{$charID}{amount}}, $args->{amount};
	push @{$shopLog{$charID}{zenyEarned}}, $args->{zenyEarned};
	push @{$shopLog{$charID}{time}}, $args->{time};
}

# Hook onto mainLoop to request char names
sub onMainLoop {
	if (scalar @requestQueue == 0) {
		debug $translator->translatef("%s Queue is empty.\n", PLUGIN_PREFIX);
		$hooks{mainLoop_post}->unhook();
			
		if ($terminateWhenDone == 1) {
			debug $translator->translatef("%s Shutting down...\n", PLUGIN_PREFIX);
			prepareShopShutdown(1);
		} else {
			return;
		}		
	}
	
	if (timeOut($timeout{&TIMEOUT_KEY_REQUEST})) {
		requestCharacterName();
		
		$timeout{&TIMEOUT_KEY_REQUEST}{time} = time;
	}
}

# Request char name
sub requestCharacterName {
	return unless scalar @requestQueue > 0 and $net->getState() == Network::IN_GAME;
	
	my $charID = getHex($requestQueue[0]);
	
	if ($requestCounter{$requestQueue[0]} > $config{&MAX_ATTEMPTS_KEY_REQUEST}) {
		warning $translator->translatef("%s Max name request attempts reached, giving up on charID %s\n", PLUGIN_PREFIX, $charID);

		delete $requestCounter{$requestQueue[0]};
		binRemoveAllAndShift(\@requestQueue, $requestQueue[0]);
	} else {
		$hooks{packet_character_name}->hook();
		
		debug $translator->translatef("%s Requesting player name with charID %s (attempt number %d)\n", PLUGIN_PREFIX, 
										$charID, $requestCounter{$requestQueue[0]});
		$messageSender->sendGetCharacterName($requestQueue[0]);
		$requestCounter{$requestQueue[0]}++;
	}
}

# Received char name
sub onReceiveCharacterName {
	my (undef, $args) = @_;
	
	if (scalar @requestQueue == 0) {
		$hooks{packet_character_name}->unhook();
		return;
	}
	
	$knownNames{getHex($requestQueue[0])} = bytesToString($args->{name});

	delete $requestCounter{$requestQueue[0]};
	binRemoveAllAndShift(\@requestQueue, $requestQueue[0]);
}

# Closing shop, report stuff
sub onShopClose {
	$terminateWhenDone = 1;
	$hooks{mainLoop_post}->hook();
	
	return;
}

sub prepareShopShutdown {
	my $forceStop = shift;
	
	if ($forceStop) {
		# Give up
		@requestQueue = ();
		
		$hooks{mainLoop_post}->unhook();
	}
	
	my $msg = prepareMessage();

	clearLists();
	
	message $msg, "list";
	shopLog($msg);
}

sub prepareMessage {
	my $msg = center($translator->translate(" Vending Log "), 79, '=') ."\n";
	
	my $offset = 0;
	my $totalZeny = 0;
	my $totalAmount = 0;
	my $i;
	my $name;

	foreach my $key (keys %shopLog) {
		if (exists $shopLog{$key}{item}) {
			if ($offset == 0) {
				$msg .= $translator->translate("#  Item                    Amount       Earned Buyer                 When     \n");
			}

			$name = (exists $knownNames{$key}) ? $knownNames{$key} : $translator->translate("Unknown");
			
			for ($i = 0; $i < scalar @{$shopLog{$key}{item}}; ++$i) {
				$msg .= swrite("@< @<<<<<<<<<<<<<<<<<<<<<< @<<<< @>>>>>>>>>>>z @<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<",
						[$offset+$i+1, ${$shopLog{$key}{item}}[$i], formatNumber(${$shopLog{$key}{amount}}[$i]),
						formatNumber(${$shopLog{$key}{zenyEarned}}[$i]), $name,
						getFormattedDateShort(${$shopLog{$key}{time}}[$i], $config{&DATE_FORMAT_KEY})]);
						
				$totalZeny += ${$shopLog{$key}{zenyEarned}}[$i];
				$totalAmount += ${$shopLog{$key}{amount}}[$i];
			}
		} else {
			last;
		}
		
		$offset += $i;
	}
	
	if ($offset == 0) {
		$msg .= center($translator->translate(" Nothing sold yet "), 79, ' ') ."\n";
	} else {
		$msg .= swrite("@< @<<<<<<<<<<<<<<<<<<<<<< @<<<< @>>>>>>>>>>>z @<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<",
					[undef, $translator->translate("Total"), formatNumber($totalAmount), formatNumber($totalZeny), undef, undef]);
	}

	return $msg;
}

#####################
# Plugin Management #
#####################
sub onInitialized {
	if (!exists $timeout{&TIMEOUT_KEY_REQUEST} or $timeout{&TIMEOUT_KEY_REQUEST}{timeout} <= 0) {
		warning $translator->translatef("%s timeout %s is undefined, equal to zero or invalid. Defaulting to %s second(s)\n", 
				PLUGIN_PREFIX, TIMEOUT_KEY_REQUEST, TIMEOUT_VALUE_REQUEST);
		setTimeout(TIMEOUT_KEY_REQUEST, TIMEOUT_VALUE_REQUEST);
	} else {
		debug $translator->translatef("%s timeout %s set to %s second(s)\n",
				PLUGIN_PREFIX, TIMEOUT_KEY_REQUEST, $timeout{TIMEOUT_KEY_REQUEST}{timeout});
	}
	
	if (!exists $config{&MAX_ATTEMPTS_KEY_REQUEST} or $config{&MAX_ATTEMPTS_KEY_REQUEST} <= 0) {
		warning $translator->translatef("%s max tries %s is undefined, equal to zero or invalid. Defaulting to %s attempt(s)\n", 
				PLUGIN_PREFIX, MAX_ATTEMPTS_KEY_REQUEST, MAX_ATTEMPTS_VALUE_REQUEST);
		configModify(MAX_ATTEMPTS_KEY_REQUEST, MAX_ATTEMPTS_VALUE_REQUEST);
	}
	
	if (!exists $config{&DATE_FORMAT_KEY} or 
		($config{&DATE_FORMAT_KEY} != 0 && $config{&DATE_FORMAT_KEY} != 1 && $config{&DATE_FORMAT_KEY} != 2)) {
		warning $translator->translatef("%s date format %s is undefined or invalid. Defaulting to %s (%s)\n",
				PLUGIN_PREFIX, DATE_FORMAT_KEY, 1, DATE_FORMAT_VALUE_X_MEANING->[1]);
		configModify(DATE_FORMAT_KEY, 1);
	} else {
		debug $translator->translatef("%s date format %s set to %s (%s)\n",
				PLUGIN_PREFIX, DATE_FORMAT_KEY, $config{&DATE_FORMAT_KEY}, DATE_FORMAT_VALUE_X_MEANING->[$config{&DATE_FORMAT_KEY}]);
	}
	
	$hooks{shop_sold}->hook();
	$hooks{shop_close}->hook();
	
	$main_command = Commands::register([COMMAND_HANDLE, $translator->translate("Command used by vendingLog plugin"), \&onCommandCall]);
}

sub onUnload {
	warning $translator->translatef("%s Unloading plugin...\n", PLUGIN_PREFIX);

	$hooks{packet_character_name}->unhook();
	$hooks{mainLoop_post}->unhook();
	$hooks{shop_sold}->unhook();
	$hooks{shop_close}->unhook();
	$hooks{init}->unhook();
	
	Commands::unregister($main_command);
	$main_command = undef;
	
	prepareShopShutdown(1);
	clearLists();
	
	$terminateWhenDone = 0;

	warning $translator->translatef("%s Plugin unloaded.\n", PLUGIN_PREFIX);
}

sub onReload {
	onUnload();

	warning $translator->translatef("%s Reloading plugin...\n", PLUGIN_PREFIX);
	
	onInitialized();
	
	warning $translator->translatef("%s Plugin reloaded.\n", PLUGIN_PREFIX);
}

sub clearLists {
	%shopLog = ();
	%requestCounter = ();
	@requestQueue = ();
}

sub onCommandCall {
	my (undef, $args) = @_;
	
	my $msg = prepareMessage();
	message $msg, "list";
	
	if ($args eq "log") {
		debug $translator->translatef("%s Logging vending\n", PLUGIN_PREFIX);
		shopLog($msg);
	}
}

1;
