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
# (At this time, some stuff is still handled by the parseCommand() function in functions.pl. The plan is to eventually move everything to this module.)

package Commands;

use strict;
use warnings;
no warnings qw(redefine uninitialized);

use Globals;
use Log qw(message error);
use Network::Send;
use Settings;
use Plugins;
use Utils;
use Misc;


our %handlers = (
	ai	=> \&cmdAI,
	aiv	=> \&cmdAIv,
	auth	=> \&cmdAuthorize,
	bestow	=> \&cmdBestow,
	buy	=> \&cmdBuy,
	chatmod	=> \&cmdChatMod,
	chist	=> \&cmdChist,
	closeshop => \&cmdCloseShop,
	conf	=> \&cmdConf,
	crl	=> \&cmdChatRoomList,
	debug	=> \&cmdDebug,
	e	=> \&cmdEmotion,
	eq	=> \&cmdEquip,
	i	=> \&cmdInventory,
	ignore	=> \&cmdIgnore,
	il	=> \&cmdItemList,
	im	=> \&cmdUseItemOnMonster,
	ip	=> \&cmdUseItemOnPlayer,
	is	=> \&cmdUseItemOnSelf,
	leave	=> \&cmdLeaveChatRoom,
	help	=> \&cmdHelp,
	reload	=> \&cmdReload,
	memo	=> \&cmdMemo,
	ml	=> \&cmdMonsterList,
	nl	=> \&cmdNPCList,
	pl	=> \&cmdPlayerList,
	plugin	=> \&cmdPlugin,
	portals	=> \&cmdPortalList,
	s	=> \&cmdStatus,
	send	=> \&cmdSendRaw,
	skills	=> \&cmdSkills,
	st	=> \&cmdStats,
	stat_add => \&cmdStatAdd,
	tank	=> \&cmdTank,
	timeout	=> \&cmdTimeout,
	uneq	=> \&cmdUnequip,
	verbose	=> \&cmdVerbose,
	warp	=> \&cmdWarp,
	who	=> \&cmdWho,
);

our %descriptions = (
	ai	=> 'Enable/disable AI.',
	aiv	=> 'Display current AI sequences.',
	auth	=> '(Un)authorize a user for using Kore chat commands.',
	bestow	=> 'Bestow admin in a chat room',
	buy	=> 'Buy an item from the current NPC shop.',
	chatmod	=> 'Modify chat room settings.',
	chist	=> 'Display last few entries from the chat log.',
	closeshop => 'Close your shop.',
	conf	=> 'Change a configuration key.',
	crl	=> 'List chat rooms.',
	debug	=> 'Toggle debug on/off.',
	e	=> 'Show emotion.',
	eq	=> 'Equip an item.',
	i	=> 'Display inventory items.',
	ignore	=> 'Ignore a user (block his messages).',
	il	=> 'Display items on the ground.',
	im	=> 'Use item on monster.',
	ip	=> 'Use item on player.',
	is	=> 'Use item on yourself.',
	leave	=> 'Leave chat room.',
	reload	=> 'Reload configuration files.',
	memo	=> 'Save current position for warp portal.',
	ml	=> 'List monsters that are on screen.',
	nl	=> 'List NPCs that are on screen.',
	pl	=> 'List players that are on screen.',
	plugin	=> 'Control plugins.',
	portals	=> 'List portals that are on screen.',
	s	=> 'Display character status.',
	send	=> 'Send a raw packet to the server.',
	skills	=> 'Show skills or add skill point.',
	st	=> 'Display stats.',
	stat_add => 'Add status point.',
	tank	=> 'Tank for a player.',
	timeout	=> 'Set a timeout.',
	verbose	=> 'Toggle verbose on/off.',
	warp	=> 'Open warp portal.',
	who	=> 'Display the number of people on the current server.',
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
	my ($switch, $args) = split(' ', $input, 2);

	# Resolve command aliases
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
		($switch, $args) = split(' ', $input, 2);
	}

	if ($handlers{$switch}) {
		$handlers{$switch}->($switch, $args);
		return 1;
	} else {
		# TODO: print error message here once we've fully migrated this stuff
		return 0;
	}
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
	sendCloseShop(\$remote_socket);
}

sub cmdConf {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ ([\s\S]+)$/;

	my @keys = keys %config;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'conf' (Change a Configuration Key)\n" .
			"Usage: conf <variable> [<value>]\n";

	} elsif ($arg2 eq "value") {
		my $value = undef;
		Plugins::callHook('Commands::cmdConf', {
			key => $arg1,
			val => \$value
		});

		if (!defined $value) {
			if (!exists $config{$arg1}) {
				error "Config variable $arg1 doesn't exist\n";
			} else {
				$value = "$config{$arg1}";
			}
		}
		message("Config '$arg1' is $value\n", "info") if defined $value;

	} else {
		configModify($arg1, $arg2);
	}
}

sub cmdDebug {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	if ($arg1 eq "0") {
		configModify("debug", 0);
	} elsif ($arg1 eq "1") {
		configModify("debug", 1);
	} elsif ($arg1 eq "2") {
		configModify("debug", 2);
	}
}

sub cmdEmotion {
	# Show emotion
	my (undef, $args) = @_;
	my ($num) = $args =~ /^(\d+)$/;

	if ($num eq "" || $num > 33 || $num < 0) {
		error	"Syntax Error in function 'e' (Emotion)\n" .
			"Usage: e <emotion # (0-33)>\n";
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

	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'equip' (Equip Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";

	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'} == 0 && $chars[$config{'char'}]{'inventory'}[$arg1]{'type'} != 10) {
		error	"Error in function 'equip' (Equip Inventory Item)\n" .
			"Inventory Item $arg1 can't be equipped.\n";

	} else {
		sendEquip(\$remote_socket, $chars[$config{'char'}]{'inventory'}[$arg1]{'index'}, $chars[$config{'char'}]{'inventory'}[$arg1]{'type_equip'});
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
	my $display;
	message("-----------Item List-----------\n" .
		"#    Name                      \n",
		"list");
	for (my $i = 0; $i < @itemsID; $i++) {
		next if ($itemsID[$i] eq "");
		$display = $items{$itemsID[$i]}{'name'};
		$display .= " x $items{$itemsID[$i]}{'amount'}";
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $display]),
			"list");
	}
	message("-------------------------------\n", "list");
}

sub cmdInventory {
	# Display inventory items
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "u" || $arg1 eq "nu") {
		my @useable;
		my @equipment;
		my @non_useable;
		my ($i, $display, $index);

		for ($i = 0; $i < @{$chars[$config{'char'}]{'inventory'}}; $i++) {
			my $item = $chars[$config{'char'}]{'inventory'}[$i];
			next if !%{$item};
			if ($item->{type} == 3 ||
			    $item->{type} == 6 ||
				$item->{type} == 10) {
				push @non_useable, $i;
			} elsif ($item->{type} <= 2) {
				push @useable, $i;
			} else {
				push @equipment, $i;
			} 
		}

		message("-----------Inventory-----------\n", "list");
		if ($arg1 eq "" || $arg1 eq "eq") {
			message("-- Equipment --\n", "list");
			for ($i = 0; $i < @equipment; $i++) {
				$index = $equipment[$i];
				$display = $chars[$config{'char'}]{'inventory'}[$index]{'name'};
				$display .= " ($itemTypes_lut{$chars[$config{'char'}]{'inventory'}[$index]{'type'}})";
				if ($chars[$config{'char'}]{'inventory'}[$index]{'equipped'}) {
					$display .= " -- Eqp: $equipTypes_lut{$chars[$config{'char'}]{'inventory'}[$equipment[$i]]{'equipped'}}";
				}

				if (!$chars[$config{'char'}]{'inventory'}[$index]{'identified'}) {
					$display .= " -- Not Identified";
				}

				message(sprintf("%-3d  %s\n", $index, $display), 'list');
			}
		}
		if ($arg1 eq "" || $arg1 eq "nu") {
			message("-- Non-Usable --\n", "list");
			for ($i = 0; $i < @non_useable; $i++) {
				$index = $non_useable[$i];
				$display = $chars[$config{'char'}]{'inventory'}[$index]{'name'};
				$display .= " x $chars[$config{'char'}]{'inventory'}[$index]{'amount'}";
				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]),
					"list");
			}
		}
		if ($arg1 eq "" || $arg1 eq "u") {
			message("-- Usable --\n", "list");
			for ($i = 0; $i < @useable; $i++) {
				$display = $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'name'};
				$display .= " x $chars[$config{'char'}]{'inventory'}[$useable[$i]]{'amount'}";
				$index = $useable[$i];
				message(swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]),
					"list");
			}
		}
		message("-------------------------------\n", "list");

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'inventory'}[$arg2] eq "") {
		error	"Error in function 'i' (Inventory Item Desciption)\n" .
			"Inventory Item $arg2 does not exist\n";
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		main::printItemDesc($chars[$config{'char'}]{'inventory'}[$arg2]{'nameID'});

	} else {
		error	"Syntax Error in function 'i' (Inventory List)\n" .
			"Usage: i [<u|eq|nu|desc>] [<inventory #>]\n";
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
			[$i, getHex($monstersID[$i])." ".$monsters{$monstersID[$i]}{'name'}, $dmgTo, $dmgFrom, $dist, $pos]),
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

sub cmdPlayerList {
	message("-----------Player List-----------\n" .
		"#    Name                                    Sex   Job         Dist  Coord\n",
		"list");
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

		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<<<<<<<<< @<<<< @<<<<<<<<<<",
			[$i, $name, $sex_lut{$players{$playersID[$i]}{'sex'}}, $jobs_lut{$players{$playersID[$i]}{'jobID'}}, $dist, $pos]),
			"list");
	}
	message("---------------------------------\n", "list");
}

sub cmdPlugin {
	my (undef, $input) = @_;
	my @args = split(/ +/, $input, 2);

	if (@args == 0) {
		message("--------- Currently loaded plugins ---------\n", "list");
		message("#   Name              Description\n", "list");
		my $i = 0;
		foreach my $plugin (@Plugins::plugins) {
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
		message("----------Skill List-----------\n", "list");
		message("#  Skill Name                    Lv     SP\n", "list");
		for (my $i = 0; $i < @skillsID; $i++) {
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<    @<<<",
				[$i, $skills_lut{$skillsID[$i]}, $chars[$config{'char'}]{'skills'}{$skillsID[$i]}{'lv'}, $skillsSP_lut{$skillsID[$i]}{$chars[$config{'char'}]{'skills'}{$skillsID[$i]}{'lv'}}]),
				"list");
		}
		message("\nSkill Points: $chars[$config{'char'}]{'points_skill'}\n", "list");
		message("-------------------------------\n", "list");

	} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $skillsID[$arg2] eq "") {
		error	"Error in function 'skills add' (Add Skill Point)\n" .
			"Skill $arg2 does not exist.\n";
	} elsif ($arg1 eq "add" && $arg2 =~ /\d+/ && $chars[$config{'char'}]{'points_skill'} < 1) {
		error	"Error in function 'skills add' (Add Skill Point)\n" .
			"Not enough skill points to increase $skills_lut{$skillsID[$arg2]}.\n";
	} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
		sendAddSkillPoint(\$remote_socket, $chars[$config{'char'}]{'skills'}{$skillsID[$arg2]}{'ID'});

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $skillsID[$arg2] eq "") {
		error	"Error in function 'skills desc' (Skill Description)\n" .
			"Skill $arg2 does not exist.\n";
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		message("===============Skill Description===============\n", "info");
		message("Skill: $skills_lut{$skillsID[$arg2]}\n\n", "info");
		message($skillsDesc_lut{$skillsID[$arg2]}, "info");
		message("==============================================\n", "info");
	} else {
		error	"Syntax Error in function 'skills' (Skills Functions)\n" .
			"Usage: skills [<add | desc>] [<skill #>]\n";
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
	message("-----------Char Stats-----------\n", "info");
	message(swrite(
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
		[$chars[$config{'char'}]{'luk'}, $chars[$config{'char'}]{'luk_bonus'}, $chars[$config{'char'}]{'points_luk'}, $chars[$config{'char'}]{'guild'}{'name'}]),
		"info");
	message("--------------------------------\n", "info");
}

sub cmdStatus {
	# Display character status
	my ($baseEXPKill, $jobEXPKill);

	print "Account ID: ".getHex($accountID)."\n";
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
			."%)" if $chars[$config{'char'}]{'exp_max'};
	$job_string = $chars[$config{'char'}]{'exp_job'}."/".$chars[$config{'char'}]{'exp_job_max'}." /$jobEXPKill ("
			.sprintf("%.2f",$chars[$config{'char'}]{'exp_job'}/$chars[$config{'char'}]{'exp_job_max'} * 100)
			."%)" if $chars[$config{'char'}]{'exp_job_max'};
	$weight_string = $chars[$config{'char'}]{'weight'}."/".$chars[$config{'char'}]{'weight_max'} .
			" (" . sprintf("%.1f", $chars[$config{'char'}]{'weight'}/$chars[$config{'char'}]{'weight_max'} * 100)
			. "%)"
			if $chars[$config{'char'}]{'weight_max'};
	$job_name_string = "$jobs_lut{$chars[$config{'char'}]{'jobID'}} $sex_lut{$chars[$config{'char'}]{'sex'}}";
	$zeny_string = formatNumber($chars[$config{'char'}]{'zenny'}) if (defined($chars[$config{'char'}]{'zenny'}));

	message("-----------------Status-----------------\n", "info");
	message(swrite(
		"@<<<<<<<<<<<<<<<<<<<<<<<<<<   HP: @<<<<<<<<<<<<<<<<<<",
		[$chars[$config{'char'}]{'name'}, $hp_string],
		"@<<<<<<<<<<<<<<<<<<<<<<<<<<   SP: @<<<<<<<<<<<<<<<<<<",
		[$job_name_string, $sp_string],
		"Base: @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$chars[$config{'char'}]{'lv'}, $base_string],
		"Job:  @<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$chars[$config{'char'}]{'lv_job'}, $job_string],
		"Weight: @>>>>>>>>>>>>>>>>>>   Zenny: @<<<<<<<<<<<<<<",
		[$weight_string, $zeny_string]),
		"info");

	my $activeSkills = 'none';
	my $ailments = 'none';
	my $looks = 'none';
	my $state = '';
	if (defined $chars[$config{char}]{statuses} && %{$chars[$config{char}]{statuses}}) {
		$activeSkills = join(", ", keys %{$chars[$config{char}]{statuses}});
	}
	if (defined $chars[$config{char}]{ailments} && %{$chars[$config{char}]{ailments}}) {
		$ailments = join(", ", keys %{$chars[$config{char}]{ailments}});
	}
	if (defined $chars[$config{char}]{state} && %{$chars[$config{char}]{state}}) {
		$state = join(", ", keys %{$chars[$config{char}]{state}});
	}
	if (defined $chars[$config{char}]{looks} && %{$chars[$config{char}]{looks}}) {
		$looks = join(", ", keys %{$chars[$config{char}]{looks}});
	}
	message("Active skills: $activeSkills\n", "info");
	message("Ailments: $ailments $state\n", "info");
	message("Looks: $looks\n", "info");
	message("Spirits: $chars[$config{char}]{spirits}\n", "info") if (exists $chars[$config{char}]{spirits});
	message("----------------------------------------\n", "info");


	my $dmgpsec_string = sprintf("%.2f", $dmgpsec);
	my $totalelasped_string = sprintf("%.2f", $totalelasped);
	my $elasped_string = sprintf("%.2f", $elasped);

	message(swrite(
		"Total Damage: @>>>>>>>>>>>>> Dmg/sec: @<<<<<<<<<<<<<<",
		[$totaldmg, $dmgpsec_string],
		"Total Time spent (sec): @>>>>>>>>",
		[$totalelasped_string],
		"Last Monster took (sec): @>>>>>>>",
		[$elasped_string]),
		"info");
	message("----------------------------------------\n", "info");
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

sub cmdTimeout {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^([\s\S]*) ([\s\S]*?)$/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'timeout' (set a timeout)\n" .
			"Usage: timeout <type> [<seconds>]\n";
	} elsif ($timeout{$arg1} eq "") {
		error	"Error in function 'timeout' (set a timeout)\n" .
			"Timeout $arg1 doesn't exist\n";
	} elsif ($arg2 eq "") {
		error "Timeout '$arg1' is $config{$arg1}\n";
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

	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
		error	"Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";

	} elsif ($chars[$config{'char'}]{'inventory'}[$arg1]{'equipped'} == 0 && $chars[$config{'char'}]{'inventory'}[$arg1]{'type'} != 10) {
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
	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
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
	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
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
	} elsif (!%{$chars[$config{'char'}]{'inventory'}[$arg1]}) {
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
		if ($map < 0 || $map > @{$chars[$config{'char'}]{'warp'}{'memo'}}) {
			error "Invalid map number $map.\n";
		} else {
			my $name = $chars[$config{'char'}]{'warp'}{'memo'}[$map];
			my $rsw = "$name.rsw";
			message "Attempting to open a warp portal to $maps_lut{$rsw} ($name)\n", "info";
			sendOpenWarp(\$remote_socket, "$name.gat");
		}

	} elsif ($map eq 'list') {
		if (!$chars[$config{'char'}]{'warp'}{'memo'} || !@{$chars[$config{'char'}]{'warp'}{'memo'}}) {
			error "You didn't cast warp portal.\n";
			return;
		}

		message("----------------- Warp Portal --------------------\n", "list");
		message("#  Place                           Map\n", "list");
		for (my $i = 0; $i < @{$chars[$config{'char'}]{'warp'}{'memo'}}; $i++) {
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
				[$i, $maps_lut{$chars[$config{'char'}]{'warp'}{'memo'}[$i].'.rsw'},
				$chars[$config{'char'}]{'warp'}{'memo'}[$i]]),
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

return 1;
