#Originally made by Lahan (openkore.com)
#rebirth by dvdc (rofan.ru)

package scrollingChat;

use strict;
use Globals qw(%config);
use Log qw(message error);
use Utils qw (timeOut);

Plugins::register('scrollingChat', 'Can make the text of your chat window scroll', \&Unload);

my $hooks = Plugins::addHook('mainLoop_post', \&mainLoop_hook);

my $commandsID = Commands::register(
	["sctitle", "Set the title of your chat (Can be as long as you want)", \&scSetTitle],
	["scadd", "Used when a title gets turncated", \&scAdd],
	["scspeed", "Set the chat scroll speed", \&scSetSpeed],
	["scdirection", "Set the scroll direction (left or right)", \&scSetDirection],
	["scchars", "Set the amount of characters to move at once", \&scSetChars],
	["scprefix", "Set a prefix to have at the start of every chat line", \&scSetPrefix],
	["sctitlesclear", "Clear the list of titles", \&scTitleListClear],
	["scshowtitle", "Display the current title / titles", \&scShowTitle],
	["scmode", "Swap between the chat modes", \&scModeToggle],
	["schelp", "Displays a help message", \&scShowHelp],
	["scconflist", "List all loaded configs", \&scConfList],
	["sc", "Toggles scrolling chat on and off", \&scToggle]
);

my $tmpStr; #Used to store the entered 36 letter string when you enter more than 36 char titles in swap mode
my $scPrefix = "";
my $scSpeed = 1;
my $scActive = 0;
my $scMode = 0; #0 = Scroll, 1 = List Swapping
my $scDirection = 1; #1 = Scroll Right (Move last char first), 0 = Scroll Left (Move first char last)
my $scCharsAtOnce = 2; #Allows to move more than one char at a time.
my $scTitle = "This is a scrolling chat! Amazing! - ";
my @scTitleList;
my $scTitleNum = -1;
my $scChatMaxLen = 36;
my $scTimeout = time;


sub Unload {
	#Plugins::delHooks($hooks);
	Plugins::delHook('mainLoop_post', $hooks);
	message "scrollingChat plugin unloaded";
}

sub mainLoop_hook {
	if (timeOut($scTimeout, $scSpeed) && ($scActive) ) {
	  $scTimeout = time;
	  scChangeChatTopic();
	}
}

# Get arguments from chat command
# my ($self, $args) = @_;



sub scChangeChatTopic {
	#First we fix the string
	if ($scMode) { #If we are in swap mode
		my $element_count = scalar(@scTitleList);
		if ($element_count > 0) {
			if ($scTitleNum < $element_count - 1) {
			$scTitleNum++;
			} else {
			$scTitleNum = 0;
			}
		Commands::run("chat modify \"" . $scTitleList[$scTitleNum] . "\"");
		}
	} else { #If we are in scroll mode
		if ($scDirection) {
			#Move the first char last
			substr($scTitle, -1, 1) = substr($scTitle, -1, 1) . substr($scTitle, 0, $scCharsAtOnce);
			#Remove the first char
			substr($scTitle, 0, $scCharsAtOnce) = "";
		} else {
			#Move the last char first
			substr($scTitle, 0, 0) = substr($scTitle, 0 - $scCharsAtOnce, $scCharsAtOnce);
			#Remove the last char
			substr($scTitle, 0 - $scCharsAtOnce, $scCharsAtOnce) = "";
		}
		#Then we modify the chat room
		Commands::run("chat modify \"" . substr($scPrefix . $scTitle, 0, $scChatMaxLen) . "\"");
	}
}

sub scAdd {
	if ($tmpStr =~ /^([\s\S]{1,$scChatMaxLen}?)/ ) {
		my $element_count = scalar(@scTitleList);
		$scTitleList[$element_count] = $tmpStr;
		message "Chat title added : \"" . $tmpStr . "\"\n","success";
	}
	$tmpStr = "";
}

sub scSetTitle {
	# Get arguments from chat command
	my (undef, $args) = @_;
	if ($scMode) { #This is if we are in list mode
		if (!exists $_[1]) {
			error "Please use 'sctitle \"<title>\"'. With max " . $scChatMaxLen . " letters.\n";
			return;
		}
		if (!$_[1]) {
			error "Please use 'sctitle \"<title>\"'. With max " . $scChatMaxLen . " letters.\n";
			return;
		}
		my $element_count = scalar(@scTitleList);
		if ($args =~ /^\"([\s\S]{1,$scChatMaxLen}?)\"/ ) {
			$scTitleList[$element_count] = $1 ;
			message "Chat title added : \"" . $1 . "\"\n","success";
		} else {
			if ($args =~ /^\"([\s\S]+?)\"/) {
				$tmpStr = substr($1, 0, $scChatMaxLen);
				error "Your chat title contains more than " . $scChatMaxLen . " letters.\n" .
					"It has been truncated to : \"" . $tmpStr . "\".\n" .
					"If you wish to add the turncated string type 'scadd'\n" .
					"Please use 'sctitle \"<title>\"'. With max " . $scChatMaxLen . " letters.\n";
			} else {
				error "Please use 'sctitle \"<title>\"'. With max " . $scChatMaxLen . " letters.\n";
			}
		}
	} else { #This is if we are in scroll mode
		if ($args =~ /^\"([\s\S]+?)\"/ ) {
			$scTitle = $1 ;
			message "Chat title changed to : \"" . $scTitle . "\"\n","success";
		} else {
			error "Please use 'sctitle \"<title>\"'\n";
		}
	}
}

sub scSetPrefix {
	my (undef, $args) = @_;
	if ($args =~ /^\"([\s\S]+?)\"/ ) {
		$scPrefix = $1;
		message "Prefix has been set to : \"" . $1 . "\"\n","success";
	} else {
		error "Please use 'scprefix \"<prefix>\"'.\n";
	}
}

sub scSetSpeed {
	if ( ($_[1] =~ /^\d+$/) || ($_[1] =~ /^\d+\.?\d*$/)) {
		$scSpeed = $_[1];
		message "Chat scroll speed is set to : " . $scSpeed . "\n","success";
	} else {
		error "Please use 'scspeed <number>'. Where <number> is the delay in seconds.\n";
	}
}

sub scSetDirection {
	if ($_[1] eq "left") {
		$scDirection = 1;
		message "Chat is now scrolling left\n","success";
	} elsif ($_[1] eq "right") {
		$scDirection = 0;
		message "Chat is now scrolling right\n","success";
	} else {
		error "Please use 'scdirection <direction>'. Where <direction> is 'left' or 'right'.\n";
	}
}

sub scSetChars {
	if ($_[1] =~ /^\d+$/) {
		$scCharsAtOnce = $_[1];
		message "Amount of characters moved at once is now : " . $scCharsAtOnce . "\n","success";
	} else {
		error "Please use 'scchars <number>'. Where <number> is the number of characters to move.\n";
	}
}

sub scShowHelp {
	message "sc: Enables / Disables this plugin\n" .
			"sc [Config Num]: Enable the plugin and loads the specified config. Use 'scconflist' to get number.\n" .
			"scconflist: Will list all the configs that have been loaded\n" .
			"schelp: Displays this help message\n" .
			"sctitle <text>: Set the title of the chat\n" .
			"sctitlesclear: Can be used to clear all titles when in swap mode\n" .
			"scshowtitle: Will show the current title(s)\n" .
			"scprefix <text>: Sets a prefix that is used for scroll mode (not swap)\n" .
			"scmode: Will swap between chat modes (Scroll/swap)\n" .
			"scspeed <number>: Set the scroll speed in seconds\n" .
			"scchars <number>: Set the amount of characters to move each tick\n" .
			"scdirection <direction>: Set the scroll direction for the text\n", "list";
}

sub scTitleListClear {
	@scTitleList = ();
	$scTitleNum = -1;
	message "Title list has been cleared\n","success";	
}

sub scShowTitle {
	if ($scMode) {
		my $element_count = scalar(@scTitleList);
		if ($element_count > 0) {
			message "The current titles are:\n";
			for (my $i = 0; $i < $element_count; $i++) {
				my $e = $i + 1;
				message $e . ". \"" . $scTitleList[$i] . "\"\n","list";
			}
		} else {
			error "There are no titles in the list, use 'sctitle' to add some\n";
		}
	} else {
		message "The current title is : \"" . $scTitle . "\"\n", "list";
	}
}

sub scModeToggle {
	if (exists $_[1]) {
		if ($_[1] =~ /^\b(1|0)$/) {
			$scMode = $_[1];
			message "scrollingChat is now set to mode " . $_[1] . "\n","success";
		} else {
			error "Invalid mode " . $_[1] . ". Please check your config file. Mode should be 0 or 1.\n";
		}
	} else {
		if ($scMode) {
			message "scrollingChat is now set to scroll mode\n","success";
			$scMode = 0;
		} else {
			message "scrollingChat is now set to swap mode\n","success";
			$scMode = 1;
			$scTitleNum = -1;
		}
	}
}

sub scConfList {
	my $confPrefix = "scrollingChat_";
	message "Config List:\n";
	for (my $i = 0; exists $config{$confPrefix.$i}; $i++) {
		#next if (!$config{$confPrefix.$i});
		my $e = $i + 1;
		message $e . ". " . $config{$confPrefix.$i} . "\n","list";
	}
}

sub scToggle {
	if (defined $_[1]) {
		if ($_[1] =~ /^\d+$/) { #If we get in here we are supposed to load a config
			&scLoadConfig($_[1]);
			message "Scrolling Chat Activated\n","success";
			Commands::run("chat create \".\"");
			$scActive = 1;
			&scChangeChatTopic();
			$scTimeout = time;
		} else {
			error "Please use 'sc'. To enable / disable\n" .
			"And use 'sc [Config Num]' to load settings from config. Use 'scconflist' to get number.\n";
		}
	} else {
		if ($scActive) {
			message "Scrolling Chat Deactivated\n","success";
			$scActive = 0;
		} else {
			message "Scrolling Chat Activated\n","success";
			Commands::run("chat create \".\"");
			$scActive = 1;
			&scChangeChatTopic();
			$scTimeout = time;
		}
	}
}

sub scSetDefaults {
	$tmpStr = "";
	$scPrefix = "";
	$scSpeed = 1;
	$scMode = 0;
	$scDirection = 1;
	$scCharsAtOnce = 2;
	$scTitleNum = -1;
	$scChatMaxLen = 36;
	&scTitleListClear();
}

sub scLoadConfig {
	my $confPrefix = "scrollingChat_".($_[0]-1);
	if (!exists $config{$confPrefix}) {
		message "Invalid config file";
		return;
	}
	&scSetDefaults();
	if (exists $config{$confPrefix."_speed"}) {
		&scSetSpeed(undef,$config{$confPrefix."_speed"}) ;
	}
	if (exists $config{$confPrefix."_prefix"}) {
		&scSetPrefix(undef,$config{$confPrefix."_prefix"}) ;
	}
	if (exists $config{$confPrefix."_direction"}) {
		&scSetDirection(undef,$config{$confPrefix."_direction"});
	}
	if (exists $config{$confPrefix."_chars"}) {
		&scSetChars(undef,$config{$confPrefix."_chars"});
	}
	if (exists $config{$confPrefix."_mode"}) {
		&scModeToggle(undef,$config{$confPrefix."_mode"});
	}
	if ($scMode) {
		for (my $i = 1; exists $config{$confPrefix."_title_".$i}; $i++) {
			&scSetTitle(undef,$config{$confPrefix."_title_".$i});
		}
	} else {
		my $tmpStr = "";
		for (my $i = 1; exists $config{$confPrefix."_title_".$i}; $i++) {
			if ($config{$confPrefix."_title_".$i} =~ /^\"([\s\S]+?)\"/) {
				$tmpStr .= $1;
			}
		}
		&scSetTitle(undef,"\"".$tmpStr."\"");
	}
	message "Loaded config \"" . ($_[0]-1) . ". " . $config{$confPrefix} . "\"\n","success";
}

1;