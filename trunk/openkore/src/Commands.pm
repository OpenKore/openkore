#########################################################################
#  OpenKore - Commandline
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################
##
# MODULE DESCRIPTION: Commandline input processing
#
# This module processes commandline input.
#
# (At this time, some stuff is still handled by the parseCommand() function in
# functions.pl. The plan is to eventually move everything to this module.)

package Commands;

use strict;
use warnings;
no warnings qw(redefine uninitialized);
use Time::HiRes qw(time);

use Globals;
use Log qw(message error);
use Network::Send;
use Settings;
use Plugins;
use Skills;
use Utils;
use Misc;
use AI;

our %handlers = (
	ai		=> \&cmdAI,
	aiv		=> \&cmdAIv,
	arrowcraft	=> \&cmdArrowCraft,
	auth		=> \&cmdAuthorize,
	bestow		=> \&cmdBestow,
	buy		=> \&cmdBuy,
	cart		=> \&cmdCart,
	chatmod		=> \&cmdChatMod,
	chist		=> \&cmdChist,
	closeshop	=> \&cmdCloseShop,
	conf		=> \&cmdConf,
	crl		=> \&cmdChatRoomList,
	debug		=> \&cmdDebug,
	e		=> \&cmdEmotion,
	eq		=> \&cmdEquip,
	guild		=> \&cmdGuild,
	i		=> \&cmdInventory,
	ignore		=> \&cmdIgnore,
	il		=> \&cmdItemList,
	im		=> \&cmdUseItemOnMonster,
	ip		=> \&cmdUseItemOnPlayer,
	is		=> \&cmdUseItemOnSelf,
	kill		=> \&cmdKill,
	leave		=> \&cmdLeaveChatRoom,
	help		=> \&cmdHelp,
	reload		=> \&cmdReload,
	memo		=> \&cmdMemo,
	ml		=> \&cmdMonsterList,
	nl		=> \&cmdNPCList,
	openshop	=> \&cmdOpenShop,
	pl		=> \&cmdPlayerList,
	plugin		=> \&cmdPlugin,
	pm		=> \&cmdPrivateMessage,
	portals		=> \&cmdPortalList,
	s		=> \&cmdStatus,
	send		=> \&cmdSendRaw,
	skills		=> \&cmdSkills,
	sl		=> \&cmdUseSkill,
	sm		=> \&cmdUseSkill,
	sp		=> \&cmdPlayerSkill,
	ss		=> \&cmdUseSkill,
	st		=> \&cmdStats,
	stat_add	=> \&cmdStatAdd,
	tank		=> \&cmdTank,
	testshop	=> \&cmdTestShop,
	timeout		=> \&cmdTimeout,
	uneq		=> \&cmdUnequip,
	verbose		=> \&cmdVerbose,
	warp		=> \&cmdWarp,
	who		=> \&cmdWho,
);

our %completions = (
	sp		=> \&cmdPlayerSkill,
);

our %descriptions = (
	ai		=> 'Enable/disable AI.',
	aiv		=> 'Display current AI sequences.',
	arrowcraft	=> 'Create Arrows.',
	auth		=> '(Un)authorize a user for using Kore chat commands.',
	bestow		=> 'Bestow admin in a chat room',
	buy		=> 'Buy an item from the current NPC shop',
	cart		=> 'Cart management',
	chatmod		=> 'Modify chat room settings.',
	chist		=> 'Display last few entries from the chat log.',
	closeshop	=> 'Close your vending shop.',
	conf		=> 'Change a configuration key.',
	crl		=> 'List chat rooms.',
	debug		=> 'Toggle debug on/off.',
	e		=> 'Show emotion.',
	eq		=> 'Equip an item.',
	guild		=> 'Guild management.',
	i		=> 'Display inventory items.',
	ignore		=> 'Ignore a user (block his messages).',
	il		=> 'Display items on the ground.',
	im		=> 'Use item on monster.',
	ip		=> 'Use item on player.',
	is		=> 'Use item on yourself.',
	kill		=> 'Attack another player (PVP/GVG only).',
	leave		=> 'Leave chat room.',
	reload		=> 'Reload configuration files.',
	memo		=> 'Save current position for warp portal.',
	monocell	=> 'Cast Monocell spell on a monster when granted by Abracadabra.',
	monster		=> 'Cast Summon Monster spell when granted by Abracadabra.',
	ml		=> 'List monsters that are on screen.',
	mvp		=> 'Change a monster into an MVP when granted by Abracadabra.',
	nl		=> 'List NPCs that are on screen.',
	openshop	=> 'Open your vending shop.',
	pl		=> 'List players that are on screen.',
	plugin		=> 'Control plugins.',
	portals		=> 'List portals that are on screen.',
	s		=> 'Display character status.',
	send		=> 'Send a raw packet to the server.',
	skills		=> 'Show skills or add skill point.',
	sl		=> 'Use skill on location.',
	sm		=> 'Use skill on monster.',
	sp		=> 'Use skill on player.',
	ss		=> 'Use skill on self.',
	st		=> 'Display stats.',
	stat_add	=> 'Add status point.',
	tank		=> 'Tank for a player.',
	testshop	=> 'Show what your vending shop would well.',
	timeout		=> 'Set a timeout.',
	verbose		=> 'Toggle verbose on/off.',
	warp		=> 'Open warp portal.',
	who		=> 'Display the number of people on the current server.',
);


##
# Commands::run(input)
# input: a command.
#
# Processes $input. See also <a href="http://openkore.sourceforge.net/wiki/">the user documentation</a>
# for a list of commands.
#
# Example:
# # Same effect as typing 's' in the console. Displays character status
# Commands::run("s");
sub run {
	my $input = shift;
	my ($switch, $args) = split(/ +/, $input, 2);

	# Resolve command aliases
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
		($switch, $args) = split(/ +/, $input, 2);
	}

	if ($handlers{$switch}) {
		$handlers{$switch}->($switch, $args);
		return 1;
	} else {
		# TODO: print error message here once we've fully migrated this stuff
		return 0;
	}
}

sub complete {
	my $input = shift;
	my ($switch, $args) = split(/ +/, $input, 2);

	# Resolve command aliases
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
		($switch, $args) = split(/ +/, $input, 2);
	}

	my $completor;
	if ($completions{$switch}) {
		$completor = $completions{$switch};
	} else {
		$completor = \&defaultCompletor;
	}

	my ($last_arg_pos, $matches) = $completor->($switch, $input, 'c');
	if (@{$matches} == 1) {
		my $arg = $matches->[0];
		$arg = "\"$arg\"" if ($arg =~ / /);
		my $new = substr($input, 0, $last_arg_pos) . $arg;
		if (length($new) > length($input)) {
			return "$new ";
		} elsif (length($new) == length($input)) {
			return "$input ";
		}

	} elsif (@{$matches} > 1) {
		$interface->writeOutput("message", "\n" . join("\t", @{$matches}) . "\n", "info");

		## Find largest common prefix

		# Find item with smallest length
		my $smallest;
		foreach (@{$matches}) {
			if (!defined $smallest || length($_) < $smallest) {
				$smallest = length($_);
			}
		}

		my $commonStr;
		for (my $len = $smallest; $len >= 0; $len--) {
			my $first = lc(substr($matches->[0], 0, $len));
			my $common = 1;
			foreach (@{$matches}) {
				if ($first ne lc(substr($_, 0, $len))) {
					$common = 0;
					last;
				}
			}
			if ($common) {
				$commonStr = $first;
				last;
			}
		}
		
		my $new = substr($input, 0, $last_arg_pos) . $commonStr;
		return $new if (length($new) > length($input));
	}
	return $input;
}


##################################


sub completePlayerName {
	my $arg = quotemeta shift;
	my @matches;
	foreach (@playersID) {
		next if (!$_);
		if ($players{$_}{name} =~ /^$arg/i) {
			push @matches, $players{$_}{name};
		}
	}
	return @matches;
}

sub defaultCompletor {
	my $switch = shift;
	my $last_arg_pos;
	my @args = parseArgs(shift, undef, undef, \$last_arg_pos);
	my @matches;

	my $arg = $args[$#args];
	@matches = completePlayerName($arg);
	@matches = Skills::complete($arg) if (!@matches);
	return ($last_arg_pos, \@matches);
}


##################################


sub cmdAI {
	my (undef, $args) = @_;
	$args =~ s/ .*//;

	# Clear AI
	if ($args eq 'clear') {
		undef @ai_seq;
		undef @ai_seq_args;
		undef %ai_v;
		undef $chars[$config{char}]{dead};
		message "AI sequences cleared\n", "success";
		return;

	} elsif ($args eq 'print') {
		# Display detailed info about current AI sequence
		message("------ AI Sequence ---------------------\n", "list");
		my $index = 0;
		foreach (@ai_seq) {
			message("$index: $_ " . dumpHash(\%{$ai_seq_args[$index]}) . "\n\n", "list");
			$index++;
		}

		message("------ AI Sequences --------------------\n", "list");
		return;

	} elsif ($args eq 'ai_v') {
		message dumpHash(\%ai_v) . "\n", "list";
		return;
	}

	# Toggle AI
	if ($AI) {
		undef $AI;
		$AI_forcedOff = 1;
		message "AI turned off\n", "success";
	} else {
		$AI = 1;
		undef $AI_forcedOff;
		message "AI turned on\n", "success";
	}
}

sub cmdAIv {
	# Display current AI sequences
	message("ai_seq = @ai_seq\n", "list");
	message("solution\n", "list") if ($ai_seq_args[0]{'solution'});
}

sub cmdAuthorize {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^([\s\S]*) ([\s\S]*?)$/;
	if ($arg1 eq "" || ($arg2 ne "1" && $arg2 ne "0")) {
		error	"Syntax Error in function 'auth' (Overall Authorize)\n" .
			"Usage: auth <username> <flag>\n";
	} else {
		auth($arg1, $arg2);
	}
}

sub cmdBestow {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\s\S]*)/;
	if ($currentChatRoom eq "") {
		error	"Error in function 'bestow' (Bestow Admin in Chat)\n" .
			"You are not in a Chat Room.\n";
	} elsif ($arg1 eq "") {
		error	"Syntax Error in function 'bestow' (Bestow Admin in Chat)\n" .
			"Usage: bestow <user #>\n";
	} elsif ($currentChatRoomUsers[$arg1] eq "") {
		error	"Error in function 'bestow' (Bestow Admin in Chat)\n" .
			"Chat Room User $arg1 doesn't exist; type 'cri' to see the list of users\n";
	} else {
		sendChatRoomBestow(\$remote_socket, $currentChatRoomUsers[$arg1]);
	}
}

sub cmdBuy {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)$/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'buy' (Buy Store Item)\n" .
			"Usage: buy <item #> [<amount>]\n";
	} elsif ($storeList[$arg1] eq "") {
		error	"Error in function 'buy' (Buy Store Item)\n" .
			"Store Item $arg1 does not exist.\n";
	} else {
		if ($arg2 <= 0) {
			$arg2 = 1;
		}
		sendBuy(\$remote_socket, $storeList[$arg1]{'nameID'}, $arg2);
	}
}

sub cmdCart {
	my (undef, $input) = @_;
	my ($arg1) = $input =~ /^(\w+)/;
	my ($arg2) = $input =~ /^\w+ (\d+)/;
	my ($arg3) = $input =~ /^\w+ \d+ (\d+)/;

	if (!defined $cart{'inventory'}) {
		error "Cart inventory is not available.\n";
		return;

	} elsif ($arg1 eq "") {
		my $msg = "-------------Cart--------------\n" .
			"#  Name\n";
		for (my $i = 0; $i < @{$cart{'inventory'}}; $i++) {
			next if (!$cart{'inventory'}[$i] || !%{$cart{'inventory'}[$i]});
			my $display = "$cart{'inventory'}[$i]{'name'} x $cart{'inventory'}[$i]{'amount'}";
			$display .= " -- Not Identified" if !$cart{inventory}[$i]{identified};
			$msg .= sprintf("%-2d %-34s\n", $i, $display);
		}
		$msg .= "\nCapacity: " . int($cart{'items'}) . "/" . int($cart{'items_max'}) . "  Weight: " . int($cart{'weight'}) . "/" . int($cart{'weight_max'}) . "\n";
		$msg .= "-------------------------------\n";
		message($msg, "list");

	} elsif ($arg1 eq "add") {
		my $hasCart = 0;
		if ($char->{statuses}) {
			foreach (keys %{$char->{statuses}}) {
				if ($_ =~ /^Level \d Cart$/) {
					$hasCart = 1;
					last;
				}
			}
		}

		if ($arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
			error	"Error in function 'cart add' (Add Item to Cart)\n" .
				"Inventory Item $arg2 does not exist.\n";

		} elsif ($arg2 =~ /\d+/ && !$hasCart) {
			error	"Error in function 'cart add' (Add Item to Cart)\n" .
				"You do not have a cart.\n";

		} elsif ($arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'}) {
				$arg3 = $chars[$config{'char'}]{'inventory'}[$arg2]{'amount'};
			}
			sendCartAdd(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg2]{'index'}, $arg3);

		} else {
			error	"Syntax Error in function 'cart add' (Add Item to Cart)\n" .
				"Usage: cart add <item #>\n";
		}

	} elsif ($arg1 eq "get") {
		if ($arg2 =~ /\d+/ && (!$cart{'inventory'}[$arg2] || !%{$cart{'inventory'}[$arg2]})) {
			error	"Error in function 'cart get' (Get Item from Cart)\n" .
				"Cart Item $arg2 does not exist.\n";
		} elsif ($arg2 =~ /\d+/) {
			if (!$arg3 || $arg3 > $cart{'inventory'}[$arg2]{'amount'}) {
				$arg3 = $cart{'inventory'}[$arg2]{'amount'};
			}
			sendCartGet(\$remote_socket, $arg2, $arg3);
		} elsif ($arg2 eq "") {
			error	"Syntax Error in function 'cart get' (Get Item from Cart)\n" .
				"Usage: cart get <cart item #>\n";
		}

	} elsif ($arg1 eq "desc") {
		if (!($arg2 =~ /\d+/)) {
			error	"Syntax Error in function 'cart desc' (Show Cart Item Description)\n" .
				"'$arg2' is not a valid cart item number.\n";
		} elsif (!$cart{'inventory'}[$arg2]) {
			error	"Error in function 'cart desc' (Show Cart Item Description)\n" .
				"Cart Item $arg2 does not exist.\n";
		} else {
			main::printItemDesc($cart{'inventory'}[$arg2]{'nameID'});
		}

	} else {
		error	"Error in function 'cart'\n" .
			"Command '$arg1' is not a known command.\n";
	}
}

sub cmdChatMod {
	my (undef, $args) = @_;
	my ($replace, $title) = $args =~ /(^\"([\s\S]*?)\" ?)/;
	my $qm = quotemeta $replace;
	my $input =~ s/$qm//;
	my @arg = split / /, $input;
	if ($title eq "") {
		error	"Syntax Error in function 'chatmod' (Modify Chat Room)\n" .
			"Usage: chatmod \"<title>\" [<limit #> <public flag> <password>]\n";
	} else {
		if ($arg[0] eq "") {
			$arg[0] = 20;
		}
		if ($arg[1] eq "") {
			$arg[1] = 1;
		}
		sendChatRoomChange(\$remote_socket, $title, $arg[0], $arg[1], $arg[2]);
	}
}

sub cmdChatRoomList {
	message("-----------Chat Room List-----------\n" .
		"#   Title                     Owner                Users   Public/Private\n",
		"list");
	for (my $i = 0; $i < @chatRoomsID; $i++) {
		next if ($chatRoomsID[$i] eq "");
		my $owner_string = ($chatRooms{$chatRoomsID[$i]}{'ownerID'} ne $accountID) ? $players{$chatRooms{$chatRoomsID[$i]}{'ownerID'}}{'name'} : $chars[$config{'char'}]{'name'};
		my $public_string = ($chatRooms{$chatRoomsID[$i]}{'public'}) ? "Public" : "Private";
		my $limit_string = $chatRooms{$chatRoomsID[$i]}{'num_users'}."/".$chatRooms{$chatRoomsID[$i]}{'limit'};
		message(swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<          @<<<<<< @<<<<<<<<<",
			[$i, $chatRooms{$chatRoomsID[$i]}{'title'}, $owner_string, $limit_string, $public_string]),
			"list");
	}
	message("------------------------------------\n", "list");
}

sub cmdChist {
	# Display chat history
	my (undef, $args) = @_;
	$args = 5 if ($args eq "");

	if (!($args =~ /^\d+$/)) {
		error	"Syntax Error in function 'chist' (Show Chat History)\n" .
			"Usage: chist [<number of entries #>]\n";

	} elsif (open(CHAT, "<", $Settings::chat_file)) {
		my @chat = <CHAT>;
		close(CHAT);
		message("------ Chat History --------------------\n", "list");
		my $i = @chat - $args;
		$i = 0 if ($i < 0);
		for (; $i < @chat; $i++) {
			message($chat[$i], "list");
		}
		message("----------------------------------------\n", "list");

	} else {
		error "Unable to open $Settings::chat_file\n";
	}
}

sub cmdCloseShop {
	main::closeShop();
}

sub cmdConf {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+\s+([\s\S]+)\s*$/;

	if ($arg1 eq "") {
		error	"Syntax Error in function 'conf' (Change a Configuration Key)\n" .
			"Usage: conf <variable> [<value>|none]\n";

	} elsif (!exists $config{$arg1}) {
		error "Config variable $arg1 doesn't exist\n";

	} elsif ($arg2 eq "") {
		my $value = $config{$arg1};
		$value = "-not-displayed-" if ($arg1 =~ /password/i);
		message "Config '$arg1' is $value\n", "info";

	} else {
		undef $arg2 if ($arg2 eq "none");
		Plugins::callHook('Commands::cmdConf', {
			key => $arg1,
			val => \$arg2
		});
		configModify($arg1, $arg2);
	}
}

sub cmdDebug {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\w\d]+)/;

	if ($arg1 eq "0") {
		configModify("debug", 0);
	} elsif ($arg1 eq "1") {
		configModify("debug", 1);
	} elsif ($arg1 eq "2") {
		configModify("debug", 2);

	} elsif ($arg1 eq "info") {
		my $connected = ($remote_socket && $remote_socket->connected()) ? "yes" : "no";
		my $time = sprintf("%.2f", time - $lastPacketTime);
		my $ai_timeout = sprintf("%.2f", time - $timeout{'ai'}{'time'});
		my $ai_time = sprintf("%.4f", time - $ai_v{'AI_last_finished'});

		message "------------ Debug information ------------\n", "list";
		message "ConState: $conState              Connected: $connected\n", "list";
		message "AI enabled: $AI            AI_forcedOff: $AI_forcedOff\n", "list";
		message "\@ai_seq = @ai_seq\n", "list";
		message "Last packet: $time secs ago\n", "list";
		message "\$timeout{ai}: $ai_timeout secs ago  (value should be >$timeout{'ai'}{'timeout'})\n", "list";
		message "Last AI() call: $ai_time secs ago\n", "list";
		message "-------------------------------------------\n", "list";
	}
}

sub cmdEmotion {
	# Show emotion
	my (undef, $args) = @_;
	my ($num) = $args =~ /^(\d+)$/;

	if (!defined $emotions_lut{$num}) {
		error	"Syntax Error in function 'e' (Emotion)\n" .
			"Usage: e <emotion #>\n";
	} else {
		sendEmotion(\$remote_socket, $num);
	}
}

sub cmdEquip {
	# Equip an item
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\w+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'equip' (Equip Inventory Item)\n" .
			"Usage: equip <item #> [r]\n";

	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1] || !%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'equip' (Equip Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";

	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} && $chars[$config{'char'}]{'inventory'}[$arg1]{'type'} != 10) {
		error	"Error in function 'equip' (Equip Inventory Item)\n" .
			"Inventory Item $arg1 can't be equipped.\n";

	} else {
		sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'});
	}
}

sub cmdGuild {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 eq "join") {
		if ($arg2 ne "1" && $arg2 ne "0") {
			error	"Syntax Error in function 'guild join' (Accept/Deny Guild Join Request)\n" .
				"Usage: guild join <flag>\n";
			return;
		} elsif ($incomingGuild{'ID'} eq "") {
			error	"Error in function 'guild join' (Join/Request to Join Guild)\n" .
				"Can't accept/deny guild request - no incoming request.\n";
			return;
		}

		sendGuildJoin(\$remote_socket, $incomingGuild{ID}, $arg2);
		undef %incomingGuild;
		if ($arg2) {
			message "You accepted the guild join request.\n", "success";
		} else {
			message "You denied the guild join request.\n", "info";
		}

	} elsif (!defined $char->{guild}) {
		error "You are not in a guild.\n";

	} elsif ($arg1 eq "" || !%guild) {
		message	"Requesting guild information...\n", "info";
		sendGuildInfoRequest(\$remote_socket);
		sendGuildRequest(\$remote_socket, 0);
		sendGuildRequest(\$remote_socket, 1);
		if ($arg1 eq "") {
			message "Enter command to view guild information: guild < info | member >\n", "info";
		} else {
			message	"Type 'guild $args' again to view the information.\n", "info";
		}

	} elsif ($arg1 eq "info") {
		message("---------- Guild Information ----------\n", "info");
		message(swrite(
			"Name    : @<<<<<<<<<<<<<<<<<<<<<<<<",	[$guild{name}],
			"Lv      : @<<",			[$guild{lvl}],
			"Exp     : @>>>>>>>>>/@<<<<<<<<<<",	[$guild{exp}, $guild{next_exp}],
			"Master  : @<<<<<<<<<<<<<<<<<<<<<<<<",	[$guild{master}],
			"Connect : @>>/@<<",			[$guild{conMember}, $guild{maxMember}]),
			"info");
		message("---------------------------------------\n", "info");

	} elsif ($arg1 eq "member") {
		if (!$guild{member}) {
			error "No guild member information available.\n";
			return;
		}

		my $msg = "------------ Guild  Member ------------\n";
		$msg .= "#  Name                       Job        Lv  Title                       Online\n";

		my ($i, $name, $job, $lvl, $title, $online);
		my $count = @{$guild{member}};
		for ($i = 0; $i < $count; $i++) {
			$name  = $guild{member}[$i]{name};
			next if (!defined $name);

			$job   = $jobs_lut{$guild{member}[$i]{jobID}};
			$lvl   = $guild{member}[$i]{lvl};
			$title = $guild{member}[$i]{title};
			$online = $guild{member}[$i]{online} ? "Yes" : "No";

			$msg .= swrite("@< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<< @>  @<<<<<<<<<<<<<<<<<<<<<<<<<< @<<",
					[$i, $name, $job, $lvl, $title, $online]);
		}
		$msg .= "---------------------------------------\n";
		message $msg, "list";

	}
}

sub cmdHelp {
	# Display help message
	my (undef, $args) = @_;
	my @commands = split(/ +/, $args);
	@commands = sort keys %descriptions if (!@commands);
	my @unknown;

	message("--------------- Available commands ---------------\n", "list");
	foreach my $switch (@commands) {
		if ($descriptions{$switch}) {
			message(sprintf("%-10s  %s\n", $switch, $descriptions{$switch}), "list");
		} else {
			push @unknown, $switch;
		}
	}

	if (@unknown) {
		if (@unknown == 1) {
			error("The command \"$unknown[0]\" doesn't exist.\n");
		} else {
			error("These commands don't exist: " . join(', ', @unknown) . "\n");
		}
		error("Type 'help' to see a list of all available commands.\n");
	}
	message("--------------------------------------------------\n", "list");
}

sub cmdIgnore {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^(\d+) ([\s\S]*)/;
	if ($arg1 eq "" || $arg2 eq "" || ($arg1 ne "0" && $arg1 ne "1")) {
		error	"Syntax Error in function 'ignore' (Ignore Player/Everyone)\n" .
			"Usage: ignore <flag> <name | all>\n";
	} else {
		if ($arg2 eq "all") {
			sendIgnoreAll(\$remote_socket, !$arg1);
		} else {
			sendIgnore(\$remote_socket, $arg2, !$arg1);
		}
	}
}

sub cmdItemList {
	message("-----------Item List-----------\n" .
		"   # Name                           Coord\n",
		"list");
	for (my $i = 0; $i < @itemsID; $i++) {
		next if ($itemsID[$i] eq "");
		my $item = $items{$itemsID[$i]};
		my $display = "$item->{name} x $item->{amount}";
		message(sprintf("%4d %-30s (%3d, %3d)\n",
			$i, $display, $item->{pos}{x}, $item->{pos}{y}),
			"list");
	}
	message("-------------------------------\n", "list");
}

sub cmdInventory {
	# Display inventory items
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if (!$chars[$config{'char'}]{'inventory'}) {
		error "Inventory is empty\n";
		return;
	}

	if ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "neq" || $arg1 eq "u" || $arg1 eq "nu") {
		my @useable;
		my @equipment;
		my @uequipment;
		my @non_useable;
		my ($i, $display, $index);

		for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}}; $i++) {
			my $item = $chars[$config{'char'}]{'inventory'}[$i];
			next unless $item && %{$item};
			if ($item->{type} == 3 ||
			    $item->{type} == 6 ||
				$item->{type} == 10) {
				push @non_useable, $i;
			} elsif ($item->{type} <= 2) {
				push @useable, $i;
			} else {
				my %eqp;
				$eqp{index} = $item->{index};
				$eqp{binID} = $i;
				$eqp{name} = $item->{name};
				$eqp{type} = $itemTypes_lut{$item->{type}};
				$eqp{equipped} = $equipTypes_lut{$item->{equipped}};
				$eqp{identified} = " -- Not Identified" if !$item->{identified};
				if ($item->{equipped}) {
					push @equipment, \%eqp;
				} else {
					push @uequipment, \%eqp;
				}
			} 
		}

		my $msg = "-----------Inventory-----------\n";
		if ($arg1 eq "" || $arg1 eq "eq") {
			$msg .= "-- Equipment (Equipped) --\n";
			foreach my $item (@equipment) {
				$msg .= sprintf("%-3d  %s -- %s\n", $item->{binID}, $item->{name}, $item->{equipped});
			}
		}
		if ($arg1 eq "" || $arg1 eq "neq") {
			$msg .= "-- Equipment (Not Equipped) --\n";
			foreach my $item (@uequipment) {
				$msg .= sprintf("%-3d  %s (%s) %s\n", $item->{binID}, $item->{name}, $item->{type}, $item->{identified});
			}
		}
		if ($arg1 eq "" || $arg1 eq "nu") {
			$msg .= "-- Non-Usable --\n";
			for ($i = 0; $i < @non_useable; $i++) {
				$index = $non_useable[$i];
				$display = $chars[$config{'char'}]{'inventory'}[$index]{'name'};
				$display .= " x $chars[$config{'char'}]{'inventory'}[$index]{'amount'}";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]);
			}
		}
		if ($arg1 eq "" || $arg1 eq "u") {
			$msg .= "-- Usable --\n";
			for ($i = 0; $i < @useable; $i++) {
				$display = $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'name'};
				$display .= " x $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'amount'}";
				$index = $useable[$i];
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]);
			}
		}
		$msg .= "-------------------------------\n";
		message($msg, "list");

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
		error	"Error in function 'i' (Inventory Item Desciption)\n" .
			"Inventory Item $arg2 does not exist\n";
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		main::printItemDesc($chars[$config{'char'}]{'inventory'}[$arg2]{'nameID'});

	} else {
		error	"Syntax Error in function 'i' (Inventory List)\n" .
			"Usage: i [<u|eq|neq|nu|desc>] [<inventory #>]\n";
	}
}

sub cmdLeaveChatRoom {
	if ($currentChatRoom eq "") {
		error	"Error in function 'leave' (Leave Chat Room)\n" .
			"You are not in a Chat Room.\n";
	} else {
		sendChatRoomLeave(\$remote_socket);
	}
}

sub cmdMemo {
	sendMemo(\$remote_socket);
}

sub cmdMonsterList {
	my ($dmgTo, $dmgFrom, $dist, $pos);
	message("-----------Monster List-----------\n" .
		"#    Name                     DmgTo    DmgFrom    Distance    Coordinates\n",
		"list");
	for (my $i = 0; $i < @monstersID; $i++) {
		next if ($monstersID[$i] eq "");
		$dmgTo = ($monsters{$monstersID[$i]}{'dmgTo'} ne "")
			? $monsters{$monstersID[$i]}{'dmgTo'}
			: 0;
		$dmgFrom = ($monsters{$monstersID[$i]}{'dmgFrom'} ne "")
			? $monsters{$monstersID[$i]}{'dmgFrom'}
			: 0;
		$dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$monsters{$monstersID[$i]}{'pos_to'}});
		$dist = sprintf("%.1f", $dist) if (index($dist, '.') > -1);
		$pos = '(' . $monsters{$monstersID[$i]}{'pos_to'}{'x'} . ', ' . $monsters{$monstersID[$i]}{'pos_to'}{'y'} . ')';

		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<    @<<<<      @<<<<<      @<<<<<<<<<<",
			[$i, $monsters{$monstersID[$i]}{'name'}, $dmgTo, $dmgFrom, $dist, $pos]),
			"list");
	}
	message("----------------------------------\n", "list");
}

sub cmdNPCList {
	message("-----------NPC List-----------\n" .
		"#    Name                         Coordinates   ID\n",
		"list");
	for (my $i = 0; $i < @npcsID; $i++) {
		next if ($npcsID[$i] eq "");
		my $pos = "($npcs{$npcsID[$i]}{'pos'}{'x'}, $npcs{$npcsID[$i]}{'pos'}{'y'})";
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<   @<<<<<<<<",
			[$i, $npcs{$npcsID[$i]}{'name'}, $pos, $npcs{$npcsID[$i]}{'nameID'}]),
			"list");
	}
	message("---------------------------------\n", "list");
}

sub cmdOpenShop {
	main::openShop();
}

sub cmdPlayerList {
	my (undef, $args) = @_;
	my $msg;

	if ($args ne "") {
		my $player;
		my $ID;
		if ($args =~ /^\d+$/) {
			if (!$playersID[$args]) {
				error "Player #$args does not exist.\n";
				return;
			}
			$player = $players{$playersID[$args]};
			$ID = $playersID[$args];
		} else {
			$args =~ s/ *$//;
			foreach (@playersID) {
				next unless $_;
				if (lc($players{$_}{name}) eq lc($args)) {
					$player = $players{$_};
					$ID = $_;
					last;
				}
			}
			if (!$player) {
				error "Player \"$args\" does not exist.\n";
				return;
			}
		}

		my $body = $player->{look}{body} % 8;
		my $head = $player->{look}{head};
		if ($head == 0) {
			$head = $body;
		} elsif ($head == 1) {
			$head = $body - 1;
		} else {
			$head = $body + 1;
		}

		my $pos = calcPosition($player);
		my $mypos = calcPosition($char);
		my $dist = sprintf("%.1f", distance($pos, $mypos));
		$dist =~ s/\.0$//;

		my %vecPlayerToYou;
		my %vecYouToPlayer;
		getVector(\%vecPlayerToYou, $mypos, $pos);
		getVector(\%vecYouToPlayer, $pos, $mypos);
		my $degPlayerToYou = vectorToDegree(\%vecPlayerToYou);
		my $degYouToPlayer = vectorToDegree(\%vecYouToPlayer);
		my $hex = getHex($ID);
		my $playerToYou = int(sprintf("%.0f", (360 - $degPlayerToYou) / 45)) % 8;
		my $youToPlayer = int(sprintf("%.0f", (360 - $degYouToPlayer) / 45)) % 8;

		$msg = "------------------ Player Info ------------------\n";
		$msg .= "$player->{name} ($player->{binID})\n";
		$msg .= "Account ID: $player->{nameID} (Hex: $hex)\n";
		$msg .= "Party: $player->{party}{name}\n" if ($player->{party} && $player->{party}{name} ne '');
		$msg .= "Guild: $player->{guild}{name}\n" if ($player->{guild});
		$msg .= "Position: $pos->{x}, $pos->{y} ($directions_lut{$youToPlayer} of you: " . int($degYouToPlayer) . " degrees)\n";
		$msg .= swrite(
			"Level: @<<      Distance: @<<<<<<<<<<<<<<<<<",
			[$player->{lv}, $dist]);
		$msg .= swrite(
			"Sex: @<<<<<<    Class: @<<<<<<<<<<<",
			[$sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}}]);

		my $headTop = $items_lut{$player->{headgear}{top}};
		my $headMid = $items_lut{$player->{headgear}{mid}};
		my $headLow = $items_lut{$player->{headgear}{low}};
		$msg .= "-------------------------------------------------\n";
		$msg .= swrite(
			"Body direction: @<<<<<<<<<<<<<<<<<<< Head direction:  @<<<<<<<<<<<<<<<<<<<",
			["$directions_lut{$body} ($body)", "$directions_lut{$head} ($head)"]);
		$msg .= swrite(
			"Upper headgear: @<<<<<<<<<<<<<<<<<<< Middle headgear: @<<<<<<<<<<<<<<<<<<<",
			[($headTop) ? $headTop : "none", ($headMid) ? $headMid : "none"]);
		$msg .= swrite(
			"Lower headgear: @<<<<<<<<<<<<<<<<<<< Hair color:      @<<<<<<<<<<<<<<<<<<<",
			[($headLow) ? $headLow : "none", "$haircolors{$player->{hair_color}} ($player->{hair_color})"]);
		
		$msg .= sprintf("Walk speed: %.2f secs per block\n", $player->{walk_speed});
		if ($player->{dead}) {
			$msg .= "Player is dead.\n";
		} elsif ($player->{sitting}) {
			$msg .= "Player is sitting.\n";
		}

		if ($degPlayerToYou >= $head * 45 - 29 && $degPlayerToYou <= $head * 45 + 29) {
			$msg .= "Player is facing towards you.\n";
		}

		$msg .= "-------------------------------------------------\n";
		message $msg, "info";
		return;
	}

	$msg =  "-----------Player List-----------\n" .
		"#    Name                                    Sex   Job         Dist  Coord\n";
	for (my $i = 0; $i < @playersID; $i++) {
		next if ($playersID[$i] eq "");
		my ($name, $dist, $pos);
		if ($players{$playersID[$i]}{'guild'} && %{$players{$playersID[$i]}{'guild'}}) {
			$name = "$players{$playersID[$i]}{'name'} [$players{$playersID[$i]}{'guild'}{'name'}]";
		} else {
			$name = $players{$playersID[$i]}{'name'};
		}
		$dist = distance(\%{$chars[$config{'char'}]{'pos_to'}}, \%{$players{$playersID[$i]}{'pos_to'}});
		$dist = sprintf("%.1f", $dist) if (index ($dist, '.') > -1);
		$pos = '(' . $players{$playersID[$i]}{'pos_to'}{'x'} . ', ' . $players{$playersID[$i]}{'pos_to'}{'y'} . ')';

		$msg .= swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<<<<<<<<< @<<<< @<<<<<<<<<<",
			[$i, $name, $sex_lut{$players{$playersID[$i]}{'sex'}}, $jobs_lut{$players{$playersID[$i]}{'jobID'}}, $dist, $pos]);
	}
	$msg .= "---------------------------------\n";
	message($msg, "list");
}

sub cmdPlugin {
	my (undef, $input) = @_;
	my @args = split(/ +/, $input, 2);

	if (@args == 0) {
		message("--------- Currently loaded plugins ---------\n", "list");
		message("#   Name              Description\n", "list");
		my $i = 0;
		foreach my $plugin (@Plugins::plugins) {
			next unless $plugin;
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $plugin->{name}, $plugin->{description}]
			), "list");
			$i++;
		}
		message("--------------------------------------------\n", "list");

	} elsif ($args[0] eq 'reload') {
		my @names;

		if ($args[1] =~ /^\d+$/) {
			push @names, $Plugins::plugins[$args[1]]{name};

		} elsif ($args[1] eq '') {
			error	"Syntax Error in function 'plugin reload' (Reload Plugin)\n" .
				"Usage: plugin reload <plugin name|plugin number#|\"all\">\n";
			return;

		} elsif ($args[1] eq 'all') {
			foreach my $plugin (@Plugins::plugins) {
				push @names, $plugin->{name};
			}

		} else {
			foreach my $plugin (@Plugins::plugins) {
				if ($plugin->{name} =~ /$args[1]/i) {
					push @names, $plugin->{name};
				}
			}
			if (!@names) {
				error	"Error in function 'plugin reload' (Reload Plugin)\n" .
					"The specified plugin names do not exist.\n";
				return;
			}
		}

		foreach (my $i = 0; $i < @names; $i++) {
			Plugins::reload($names[$i]);
		}
	} elsif ($args[0] eq 'load') {
		# FIXME: This doesn't work unless you specify the correct path
		Plugins::load($args[1]);

	} else {
		my $msg;
		$msg =	"--------------- Plugin command syntax ---------------\n" .
			"Command:                                              Description:\n" .
			" plugin                                                List loaded plugins\n" .
			" plugin load <filename>                                Load a plugin\n" .
			" plugin unload <plugin name|plugin number#|\"all\">    Unload a loaded plugin\n" .
			" plugin reload <plugin name|plugin number#|\"all\">    Reload a loaded plugin\n" .
			"-----------------------------------------------------\n";
		if ($args[0] eq 'help') {
			message($msg, "info");
		} else {
			error "Syntax Error in function 'plugin' (Control Plugins)\n";
			error($msg);
		}
	}
}

sub cmdPrivateMessage {
	my ($switch, $args) = @_;
	my ($user, $msg) = parseArgs($args, 2);

	if ($user eq "" || $msg eq "") {
		error	"Syntax Error in function 'pm' (Private Message)\n" .
			"Usage: pm (username) (message)\n" .
			"       pm (<#>) (message)\n";
		return;

	} elsif ($user =~ /^\d+$/) {
		if ($user - 1 >= @privMsgUsers) {
			error	"Error in function 'pm' (Private Message)\n" .
				"Quick look-up $user does not exist\n";
		} else {
			main::sendMessage(\$remote_socket, "pm", $msg, $privMsgUsers[$user - 1]);
			$lastpm{msg} = $msg;
			$lastpm{user} = $privMsgUsers[$user - 1];
		}

	} else {
		if (!defined binFind(\@privMsgUsers, $user)) {
			push @privMsgUsers, $user;
		}
		main::sendMessage(\$remote_socket, "pm", $msg, $user);
		$lastpm{msg} = $msg;
		$lastpm{user} = $user;
	}
}

sub cmdPortalList {
	message("-----------Portal List-----------\n" .
		"#    Name                                Coordinates\n",
		"list");
	for (my $i = 0; $i < @portalsID; $i++) {
		next if ($portalsID[$i] eq "");
		my $coords = "($portals{$portalsID[$i]}{'pos'}{'x'},$portals{$portalsID[$i]}{'pos'}{'y'})";
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<",
			[$i, $portals{$portalsID[$i]}{'name'}, $coords]),
			"list");
	}
	message("---------------------------------\n", "list");
}

sub cmdReload {
	my (undef, $args) = @_;
	if ($args eq '') {
		error	"Syntax Error in function 'reload' (Reload Configuration Files)\n" .
			"Usage: reload <name|\"all\">\n";

	} else {
		Settings::parseReload($args);
	}
}

sub cmdSendRaw {
	my (undef, $args) = @_;
	sendRaw(\$remote_socket, $args);
}

sub cmdSkills {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;
	if ($arg1 eq "") {
		my $msg = "----------Skill List-----------\n";
		$msg .=   "  # Skill Name                     Lv      SP\n";
		for my $handle (@skillsID) {
			my $skill = Skills->new(handle => $handle);
			$msg .= swrite(
				"@>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>    @>>>",
				[$skill->id, $skill->name, $char->{skills}{$handle}{lv}, $skillsSP_lut{$handle}{$char->{skills}{$handle}{lv}}]);
		}
		$msg .= "\nSkill Points: $char->{points_skill}\n";
		$msg .= "-------------------------------\n";
		message($msg, "list");

	} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
		my $skill = Skills->new(id => $arg2);
		if (!$skill->id || !$char->{skills}{$skill->handle}) {
			error	"Error in function 'skills add' (Add Skill Point)\n" .
				"Skill $arg2 does not exist.\n";
		} elsif ($char->{points_skill} < 1) {
			error	"Error in function 'skills add' (Add Skill Point)\n" .
				"Not enough skill points to increase ".$skill->name.".\n";
		} else {
			sendAddSkillPoint(\$remote_socket, $skill->id);
		}

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		my $skill = Skills->new(id => $arg2);
		if (!$skill->id) {
			error	"Error in function 'skills desc' (Skill Description)\n" .
				"Skill $arg2 does not exist.\n";
		} else {
			message("===============Skill Description===============\n", "info");
			message("Skill: ".$skill->name."\n\n", "info");
			message($skillsDesc_lut{$skill->handle}, "info");
			message("==============================================\n", "info");
		}
	} else {
		error	"Syntax Error in function 'skills' (Skills Functions)\n" .
			"Usage: skills [<add | desc>] [<skill #>]\n";
	}
}

sub cmdPlayerSkill {
	my $switch = shift;
	my $last_arg_pos;
	my @args = parseArgs(shift, undef, undef, \$last_arg_pos);
	my $mode = shift;

	if ($mode eq 'c') {
		# Completion mode
		my $arg = $args[$#args];
		my @matches;

		if (@args == 2) {
			# Complete skill name
			@matches = Skills::complete($arg);
		} elsif (@args == 3) {
			# Complete player name
			@matches = completePlayerName($arg);
		}

		return ($last_arg_pos, \@matches);
	}

	if (@args < 1) {
		error	"Syntax Error in function 'sp' (Use Skill on Player)\n" .
			"Usage: sp (skill # or name) [player # or name] [level]\n";
		return;
	}

	my $skill = new Skills(auto => $args[0]);
	my $target;
	my $targetID;
	my $lv = $args[2];

	if (!defined $skill->id) {
		error	"Error in function 'sp' (Use Skill on Player)\n" .
			"'$args[0]' is not a valid skill.\n";
		return;
	}

	if ($args[1] ne "") {
		$target = getPlayer($args[1], 1);
		if (!$target) {
			error	"Error in function 'sp' (Use Skill on Player)\n" .
				"Player '$args[1]' does not exist.\n";
			return;
		}
		$targetID = $target->{ID};
	} else {
		$target = $char;
		$targetID = $accountID;
	}

	if (main::ai_getSkillUseType($skill->handle)) {
		main::ai_skillUse($skill->handle, $lv, 0, 0,
			$target->{pos_to}{x}, $target->{pos_to}{y});
	} else {
		main::ai_skillUse($skill->handle, $lv, 0, 0, $targetID);
	}
}

sub cmdUseSkill {
	my ($switch, $args) = @_;
	my ($skillID, $lv, $target, $targetNum, $targetID, $x, $y);

	# Resolve skill ID
	($skillID, $args) = split(/ /, $args, 2);
	my $skill = Skills->new(id => $skillID);
	if (!defined $skill->id) {
		error "Skill $skillID does not exist.\n";
		return;
	}
	my $char_skill = $char->{skills}{$skill->handle};

	# Resolve skill level
	if ($switch eq 'sl') {
		($x, $y, $lv) = split(/ /, $args);
	} elsif ($switch eq "ss") {
		($lv) = split(/ /, $args);
	} else {
		($targetNum, $lv) = split(/ /, $args);
	}
	# Attempt to fill in unspecified skill level
	$lv ||= $char_skill->{lv};
	$lv ||= 10; # Server should fix excessively high skill level for us

	# Resolve target
	if ($switch eq 'sl') {
		if (!defined($x) || !defined($y)) {
			error "(X, Y) coordinates not specified.\n";
			return;
		}
	} elsif ($switch eq 'ss' || ($switch eq 'sp' && !defined($targetNum))) {
		$targetID = $accountID;
		$target = $char;
	} elsif ($switch eq 'sp') {
		$targetID = $playersID[$targetNum];
		if (!$targetID) {
			error "Player $targetNum does not exist.\n";
			return;
		}
		$target = $players{$targetID};
	} elsif ($switch eq 'sm') {
		$targetID = $monstersID[$targetNum];
		if (!$targetID) {
			error "Monster $targetNum does not exist.\n";
			return;
		}
		$target = $monsters{$targetID};
	}

	# Resolve target location as necessary
	if (main::ai_getSkillUseType($skill->handle)) {
		if ($targetID) {
			$x = $target->{pos_to}{x};
			$y = $target->{pos_to}{y};
		}
		main::ai_skillUse($skill->handle, $lv, 0, 0, $x, $y);
	} else {
		main::ai_skillUse($skill->handle, $lv, 0, 0, $targetID);
	}
}

sub cmdStatAdd {
	# Add status point
	my (undef, $arg) = @_;
	if ($arg ne "str" && $arg ne "agi" && $arg ne "vit" && $arg ne "int" 
	 && $arg ne "dex" && $arg ne "luk") {
		error	"Syntax Error in function 'stat_add' (Add Status Point)\n" .
			"Usage: stat_add <str | agi | vit | int | dex | luk>\n";

	} elsif ($chars[$config{'char'}]{'$arg'} >= 99) {
		error	"Error in function 'stat_add' (Add Status Point)\n" .
			"You cannot add more stat points than 99\n";

	} elsif ($chars[$config{'char'}]{"points_$arg"} > $chars[$config{'char'}]{'points_free'}) {
			error	"Error in function 'stat_add' (Add Status Point)\n" .
				"Not enough status points to increase $arg\n";

	} else {
		my $ID;
		if ($arg eq "str") {
			$ID = 0x0D;
		} elsif ($arg eq "agi") {
			$ID = 0x0E;
		} elsif ($arg eq "vit") {
			$ID = 0x0F;
		} elsif ($arg eq "int") {
			$ID = 0x10;
		} elsif ($arg eq "dex") {
			$ID = 0x11;
		} elsif ($arg eq "luk") {
			$ID = 0x12;
		}

		$chars[$config{'char'}]{$arg} += 1;
		sendAddStatusPoint(\$remote_socket, $ID);
	}
}

sub cmdStats {
	my $msg = "-----------Char Stats-----------\n";
	$msg .= swrite(
		"Str: @<<+@<< #@< Atk:  @<<+@<< Def:  @<<+@<<",
		[$chars[$config{'char'}]{'str'}, $chars[$config{'char'}]{'str_bonus'}, $chars[$config{'char'}]{'points_str'}, $chars[$config{'char'}]{'attack'}, $chars[$config{'char'}]{'attack_bonus'}, $chars[$config{'char'}]{'def'}, $chars[$config{'char'}]{'def_bonus'}],
		"Agi: @<<+@<< #@< Matk: @<<@@<< Mdef: @<<+@<<",
		[$chars[$config{'char'}]{'agi'}, $chars[$config{'char'}]{'agi_bonus'}, $chars[$config{'char'}]{'points_agi'}, $chars[$config{'char'}]{'attack_magic_min'}, '~', $chars[$config{'char'}]{'attack_magic_max'}, $chars[$config{'char'}]{'def_magic'}, $chars[$config{'char'}]{'def_magic_bonus'}],
		"Vit: @<<+@<< #@< Hit:  @<<     Flee: @<<+@<<",
		[$chars[$config{'char'}]{'vit'}, $chars[$config{'char'}]{'vit_bonus'}, $chars[$config{'char'}]{'points_vit'}, $chars[$config{'char'}]{'hit'}, $chars[$config{'char'}]{'flee'}, $chars[$config{'char'}]{'flee_bonus'}],
		"Int: @<<+@<< #@< Critical: @<< Aspd: @<<",
		[$chars[$config{'char'}]{'int'}, $chars[$config{'char'}]{'int_bonus'}, $chars[$config{'char'}]{'points_int'}, $chars[$config{'char'}]{'critical'}, $chars[$config{'char'}]{'attack_speed'}],
		"Dex: @<<+@<< #@< Status Points: @<<",
		[$chars[$config{'char'}]{'dex'}, $chars[$config{'char'}]{'dex_bonus'}, $chars[$config{'char'}]{'points_dex'}, $chars[$config{'char'}]{'points_free'}],
		"Luk: @<<+@<< #@< Guild: @<<<<<<<<<<<<<<<<<<<<<",
		[$chars[$config{'char'}]{'luk'}, $chars[$config{'char'}]{'luk_bonus'}, $chars[$config{'char'}]{'points_luk'}, $chars[$config{'char'}]{'guild'}{'name'}]);
	$msg .= "--------------------------------\n";

	$msg .= swrite(
		"Hair color: @<<<<<<<<<<<<<<<<<",
		["$haircolors{$char->{hair_color}} ($char->{hair_color})"]);
	$msg .= sprintf("Walk speed: %.2f secs per block\n", $char->{walk_speed});
	$msg .= "You are sitting.\n" if ($char->{sitting});

	$msg .= "--------------------------------\n";
	message $msg, "info";
}

sub cmdStatus {
	# Display character status
	my $msg;
	my ($baseEXPKill, $jobEXPKill);

	if ($chars[$config{'char'}]{'exp_last'} > $chars[$config{'char'}]{'exp'}) {
		$baseEXPKill = $chars[$config{'char'}]{'exp_max_last'} - $chars[$config{'char'}]{'exp_last'} + $chars[$config{'char'}]{'exp'};
	} elsif ($chars[$config{'char'}]{'exp_last'} == 0 && $chars[$config{'char'}]{'exp_max_last'} == 0) {
		$baseEXPKill = 0;
	} else {
		$baseEXPKill = $chars[$config{'char'}]{'exp'} - $chars[$config{'char'}]{'exp_last'};
	}
	if ($chars[$config{'char'}]{'exp_job_last'} > $chars[$config{'char'}]{'exp_job'}) {
		$jobEXPKill = $chars[$config{'char'}]{'exp_job_max_last'} - $chars[$config{'char'}]{'exp_job_last'} + $chars[$config{'char'}]{'exp_job'};
	} elsif ($chars[$config{'char'}]{'exp_job_last'} == 0 && $chars[$config{'char'}]{'exp_job_max_last'} == 0) {
		$jobEXPKill = 0;
	} else {
		$jobEXPKill = $chars[$config{'char'}]{'exp_job'} - $chars[$config{'char'}]{'exp_job_last'};
	}


	my ($hp_string, $sp_string, $base_string, $job_string, $weight_string, $job_name_string, $zeny_string);

	$hp_string = $chars[$config{'char'}]{'hp'}."/".$chars[$config{'char'}]{'hp_max'}." ("
		.int($chars[$config{'char'}]{'hp'}/$chars[$config{'char'}]{'hp_max'} * 100)
		."%)" if $chars[$config{'char'}]{'hp_max'};
	$sp_string = $chars[$config{'char'}]{'sp'}."/".$chars[$config{'char'}]{'sp_max'}." ("
		.int($chars[$config{'char'}]{'sp'}/$chars[$config{'char'}]{'sp_max'} * 100)
		."%)" if $chars[$config{'char'}]{'sp_max'};
	$base_string = $chars[$config{'char'}]{'exp'}."/".$chars[$config{'char'}]{'exp_max'}." /$baseEXPKill ("
			.sprintf("%.2f",$chars[$config{'char'}]{'exp'}/$chars[$config{'char'}]{'exp_max'} * 100)
			."%)"
			if $chars[$config{'char'}]{'exp_max'};
	$job_string = $chars[$config{'char'}]{'exp_job'}."/".$chars[$config{'char'}]{'exp_job_max'}." /$jobEXPKill ("
			.sprintf("%.2f",$chars[$config{'char'}]{'exp_job'}/$chars[$config{'char'}]{'exp_job_max'} * 100)
			."%)"
			if $chars[$config{'char'}]{'exp_job_max'};
	$weight_string = $chars[$config{'char'}]{'weight'}."/".$chars[$config{'char'}]{'weight_max'} .
			" (" . sprintf("%.1f", $chars[$config{'char'}]{'weight'}/$chars[$config{'char'}]{'weight_max'} * 100)
			. "%)"
			if $chars[$config{'char'}]{'weight_max'};
	$job_name_string = "$jobs_lut{$chars[$config{'char'}]{'jobID'}} $sex_lut{$chars[$config{'char'}]{'sex'}}";
	$zeny_string = formatNumber($chars[$config{'char'}]{'zenny'}) if (defined($chars[$config{'char'}]{'zenny'}));

	$msg = "-----------------Status-----------------\n" .
		swrite(
		"@<<<<<<<<<<<<<<<<<<<<<<<<<<   HP: @<<<<<<<<<<<<<<<<<<",
		[$chars[$config{'char'}]{'name'}, $hp_string],
		"@<<<<<<<<<<<<<<<<<<<<<<<<<<   SP: @<<<<<<<<<<<<<<<<<<",
		[$job_name_string, $sp_string],
		"Base: @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$chars[$config{'char'}]{'lv'}, $base_string],
		"Job:  @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$chars[$config{'char'}]{'lv_job'}, $job_string],
		"Weight: @>>>>>>>>>>>>>>>>>>   Zenny: @<<<<<<<<<<<<<<",
		[$weight_string, $zeny_string]);

	my $statuses = 'none';
	if (defined $chars[$config{char}]{statuses} && %{$chars[$config{char}]{statuses}}) {
		$statuses = join(", ", keys %{$chars[$config{char}]{statuses}});
	}
	$msg .= "Statuses: $statuses\n";
	$msg .= "Spirits: $chars[$config{char}]{spirits}\n" if (exists $chars[$config{char}]{spirits});
	$msg .= "----------------------------------------\n";


	my $dmgpsec_string = sprintf("%.2f", $dmgpsec);
	my $totalelasped_string = sprintf("%.2f", $totalelasped);
	my $elasped_string = sprintf("%.2f", $elasped);

	$msg .= swrite(
		"Total Damage: @>>>>>>>>>>>>> Dmg/sec: @<<<<<<<<<<<<<<",
		[$totaldmg, $dmgpsec_string],
		"Total Time spent (sec): @>>>>>>>>",
		[$totalelasped_string],
		"Last Monster took (sec): @>>>>>>>",
		[$elasped_string]);
	$msg .= "----------------------------------------\n";
	message($msg, "info");
}

sub cmdTank {
	my (undef, $arg) = @_;
	$arg =~ s/ .*//;

	if ($arg eq "") {
		error	"Syntax Error in function 'tank' (Tank for a Player)\n" .
			"Usage: tank <player #|player name>\n";

	} elsif ($arg eq "stop") {
		configModify("tankMode", 0);

	} elsif ($arg =~ /^\d+$/) {
		if (!$playersID[$arg]) {
			error	"Error in function 'tank' (Tank for a Player)\n" .
				"Player $arg does not exist.\n";
		} else {
			configModify("tankMode", 1);
			configModify("tankModeTarget", $players{$playersID[$arg]}{name});
		}

	} else {
		my $found;
		foreach my $ID (@playersID) {
			next if !$ID;
			if (lc $players{$ID}{name} eq lc $arg) {
				$found = $ID;
				last;
			}
		}

		if ($found) {
			configModify("tankMode", 1);
			configModify("tankModeTarget", $players{$found}{name});
		} else {
			error	"Error in function 'tank' (Tank for a Player)\n" .
				"Player $arg does not exist.\n";
		}
	}
}

sub cmdTestShop {
	my @items = main::makeShop();
	return unless @items;

	message(center(" $shop{title} ", 79, '-')."\n", "list");
	message(sprintf("%-40s  %-7s %-10s\n", 'Name', 'Amount', 'Price'), "list");
	for my $item (@items) {
		message(sprintf("%-40s %7d %10s z\n", $item->{name}, $item->{amount}, main::formatNumber($item->{price})), "list");
	}
	message("-------------------------------------------------------------------------------\n", "list");
	message("Total of ".@items." items to sell.\n", "list");
}

sub cmdTimeout {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+\s+([\s\S]+)\s*$/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'timeout' (set a timeout)\n" .
			"Usage: timeout <type> [<seconds>]\n";
	} elsif ($timeout{$arg1} eq "") {
		error	"Error in function 'timeout' (set a timeout)\n" .
			"Timeout $arg1 doesn't exist\n";
	} elsif ($arg2 eq "") {
		message "Timeout '$arg1' is $timeout{$arg1}{timeout}\n", "info";
	} else {
		setTimeout($arg1, $arg2);
	}
}

sub cmdUnequip {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Usage: unequip <item #>\n";

	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1] || !%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";

	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1]{'equipped'} && $chars[$config{'char'}]{'inventory'}[$arg1]{'type'} != 10) {
		error	"Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Inventory Item $arg1 is not equipped.\n";

	} else {
		sendUnequip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'});
	}
}

sub cmdUseItemOnMonster {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;

	if ($arg1 eq "" || $arg2 eq "") {
		error	"Syntax Error in function 'im' (Use Item on Monster)\n" .
			"Usage: im <item #> <monster #>\n";
	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1] || !%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} elsif ($monstersID[$arg2] eq "") {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Monster $arg2 does not exist.\n";
	} else {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $monstersID[$arg2]);
	}
}

sub cmdUseItemOnPlayer {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;
	if ($arg1 eq "" || $arg2 eq "") {
		error	"Syntax Error in function 'ip' (Use Item on Player)\n" .
			"Usage: ip <item #> <player #>\n";
	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1] || !%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} elsif ($playersID[$arg2] eq "") {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Player $arg2 does not exist.\n";
	} else {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $playersID[$arg2]);
	}
}

sub cmdUseItemOnSelf {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'is' (Use Item on Yourself)\n" .
			"Usage: is <item #>\n";
	} elsif (!$chars[$config{'char'}]{'inventory'}[$arg1] || !%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} else {
		sendItemUse(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $accountID);
	}
}

sub cmdVerbose {
	if ($config{'verbose'}) {
		configModify("verbose", 0);
	} else {
		configModify("verbose", 1);
	}
}

sub cmdWarp {
	my (undef, $map) = @_;

	if ($map eq '') {
		error	"Error in function 'warp' (Open/List Warp Portal)\n" .
			"Usage: warp <map name | map number# | list>\n";

	} elsif ($map =~ /^\d+$/) {
		if (!$char->{warp}{memo} || !@{$char->{warp}{memo}}) {
			error "You didn't cast warp portal.\n";
			return;
		}

		if ($map < 0 || $map > @{$char->{warp}{memo}}) {
			error "Invalid map number $map.\n";
		} else {
			my $name = $char->{warp}{memo}[$map];
			my $rsw = "$name.rsw";
			message "Attempting to open a warp portal to $maps_lut{$rsw} ($name)\n", "info";
			sendOpenWarp(\$remote_socket, "$name.gat");
		}

	} elsif ($map eq 'list') {
		if (!$char->{warp}{memo} || !@{$char->{warp}{memo}}) {
			error "You didn't cast warp portal.\n";
			return;
		}

		message("----------------- Warp Portal --------------------\n", "list");
		message("#  Place                           Map\n", "list");
		for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
				[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'},
				$char->{warp}{memo}[$i]]),
				"list");
		}
		message("--------------------------------------------------\n", "list");

	} elsif (!defined $maps_lut{$map.'.rsw'}) {
		error "Map '$map' does not exist.\n";

	} else {
		my $rsw = "$map.rsw";
		message "Attempting to open a warp portal to $maps_lut{$rsw} ($map)\n", "info";
		sendOpenWarp(\$remote_socket, "$map.gat");
	}
}

sub cmdWho {
	sendWho(\$remote_socket);
}

sub cmdKill {
	my (undef, $ID) = @_;

	my $target = $playersID[$ID];
	unless ($target) {
		error "Player $ID does not exist.\n";
		return;
	}

	# The current attack code assumes that the target is a monster.
	# So we must add the target into the %monsters hash.
	$monsters{$target} = $players{$target};
	main::attack($target);
}

sub cmdArrowCraft {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\w\d]+)/;

	#print "-$arg1-\n";
	if ($arg1 eq "") {
		if (@arrowCraftID) {
			message("----------------- Item To Craft -----------------\n", "info");
			for (my $i = 0; $i < @arrowCraftID; $i++) {
				next if ($arrowCraftID[$i] eq "");
				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$i, $char->{inventory}[$arrowCraftID[$i]]{name}]),"list");

			}
			message("-------------------------------------------------","list")
		} else {
			error	"Error in function 'arrowcraft' (Create Arrows)\n" .
				"Type 'arrowcraft use' to get list.\n";
		}
	} elsif ($arg1 eq "use") {
		if (defined binFind(\@skillsID, 'AC_MAKINGARROW')) {
			#main::ai_skillUse(\$remote_socket, 'AC_MAKINGARROW', 1, $accountID);
			main::ai_skillUse('AC_MAKINGARROW', 1, 0, 0, $accountID);
		} else {
			error	"Error in function 'arrowcraft' (Create Arrows)\n" .
				"You don't have Arrow Making Skill.\n";
		}
	} else {
		if ($arrowCraftID[$arg1] ne "") {
			sendIdentify(\$remote_socket, $char->{inventory}[$arrowCraftID[$arg1]]{index});
		} else {
			error	"Error in function 'arrowcraft' (Create Arrows)\n" .
				"Usage: arrowcraft [<identify #>]",
				"Type 'arrowcraft use' to get list.\n";
		}
	}
}


return 1;
