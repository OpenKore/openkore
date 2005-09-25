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

package Commands;

use strict;
use warnings;
no warnings qw(redefine uninitialized);
use Time::HiRes qw(time);

use Globals;
use Log qw(message debug error warning);
use Network::Send;
use Settings;
use Plugins;
use Skills;
use Utils;
use Misc;
use AI;
use Match;


our %handlers;
our %completions;

undef %handlers;
undef %completions;

our %customCommands;


# use SelfLoader; 1;
# __DATA__

sub initHandlers {
	%handlers = (
	a			=> \&cmdAttack,
	ai			=> \&cmdAI,
	aiv			=> \&cmdAIv,
	al			=> \&cmdShopInfoSelf,
	arrowcraft	=> \&cmdArrowCraft,
	as			=> \&cmdAttackStop,
	autobuy		=> \&cmdAutoBuy,
	autosell	=> \&cmdAutoSell,
	autostorage	=> \&cmdAutoStorage,
	auth		=> \&cmdAuthorize,
	bangbang	=> \&cmdBangBang,
	bingbing	=> \&cmdBingBing,
	buy			=> \&cmdBuy,
	c			=> \&cmdChat,
	card		=> \&cmdCard,
	cart		=> \&cmdCart,
	chat		=> \&cmdChatRoom,
	chist		=> \&cmdChist,
	cil			=> \&cmdItemLogClear,
	cl			=> \&cmdChatLogClear,
	closeshop	=> \&cmdCloseShop,
	conf		=> \&cmdConf,
	damage		=> \&cmdDamage,
	deal		=> \&cmdDeal,
	debug		=> \&cmdDebug,
	dl			=> \&cmdDealList,
	doridori	=> \&cmdDoriDori,
	drop		=> \&cmdDrop,
	dump		=> \&cmdDump,
	dumpnow		=> \&cmdDumpNow,
	e			=> \&cmdEmotion,
	eq			=> \&cmdEquip,
	equipment	=> \&cmdEquipment,
	eval		=> \&cmdEval,
	exp			=> \&cmdExp,
	follow		=> \&cmdFollow,
	friend		=> \&cmdFriend,
	g			=> \&cmdGuildChat,
	getplayerinfo		=> \&cmdGetPlayerInfo,
	guild		=> \&cmdGuild,
	i			=> \&cmdInventory,
	identify	=> \&cmdIdentify,
	ignore		=> \&cmdIgnore,
	ihist		=> \&cmdIhist,
	il			=> \&cmdItemList,
	im			=> \&cmdUseItemOnMonster,
	ip			=> \&cmdUseItemOnPlayer,
	is			=> \&cmdUseItemOnSelf,
	kill		=> \&cmdKill,
	look		=> \&cmdLook,
	lookp		=> \&cmdLookPlayer,
	help		=> \&cmdHelp,
	reload		=> \&cmdReload,
	memo		=> \&cmdMemo,
	ml			=> \&cmdMonsterList,
	move		=> \&cmdMove,
	nl			=> \&cmdNPCList,
	openshop	=> \&cmdOpenShop,
	p			=> \&cmdPartyChat,
	party		=> \&cmdParty,
	#pet		=> \&cmdPet,
	petl		=> \&cmdPetList,
	pl			=> \&cmdPlayerList,
	plugin		=> \&cmdPlugin,
	pm			=> \&cmdPrivateMessage,
	pml			=> \&cmdPMList,
	portals		=> \&cmdPortalList,
	quit		=> \&cmdQuit,
	rc			=> \&cmdReloadCode,
	relog		=> \&cmdRelog,
	repair		=> \&cmdRepair,
	respawn		=> \&cmdRespawn,
	s			=> \&cmdStatus,
	sell		=> \&cmdSell,
	send		=> \&cmdSendRaw,
	sit			=> \&cmdSit,
	skills		=> \&cmdSkills,
	spells		=> \&cmdSpells,
	storage		=> \&cmdStorage,
	store		=> \&cmdStore,
	sl			=> \&cmdUseSkill,
	sm			=> \&cmdUseSkill,
	sp			=> \&cmdPlayerSkill,
	ss			=> \&cmdUseSkill,
	st			=> \&cmdStats,
	stand		=> \&cmdStand,
	stat_add	=> \&cmdStatAdd,
	switchconf	=> \&cmdSwitchConf,
	take		=> \&cmdTake,
	talk		=> \&cmdTalk,
	talknpc		=> \&cmdTalkNPC,
	tank		=> \&cmdTank,
	tele		=> \&cmdTeleport,
	testshop	=> \&cmdTestShop,
	timeout		=> \&cmdTimeout,
	uneq		=> \&cmdUnequip,
	vender		=> \&cmdVender,
	verbose		=> \&cmdVerbose,
	version		=> \&cmdVersion,
	vl			=> \&cmdVenderList,
	warp		=> \&cmdWarp,
	weight		=> \&cmdWeight,
	where		=> \&cmdWhere,
	who			=> \&cmdWho,
	whoami		=> \&cmdWhoAmI,

	north		=> \&cmdManualMove,
	south		=> \&cmdManualMove,
	east		=> \&cmdManualMove,
	west		=> \&cmdManualMove,
	northeast	=> \&cmdManualMove,
	northwest	=> \&cmdManualMove,
	southeast	=> \&cmdManualMove,
	southwest	=> \&cmdManualMove,
	);
}

sub initCompletions {
	%completions = (
	sp		=> \&cmdPlayerSkill,
	);
}

##
# Commands::run(input)
# input: a command.
#
# Processes $input. See also <a href="http://openkore.sourceforge.net/docs.php">the user documentation</a>
# for a list of commands.
#
# Example:
# # Same effect as typing 's' in the console. Displays character status
# Commands::run("s");
sub run {
	my $input = shift;
	my ($switch, $args) = split(/ +/, $input, 2);
	my $handler;

	initHandlers() if (!%handlers);

	# Resolve command aliases
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
		($switch, $args) = split(/ +/, $input, 2);
	}

	$handler = $customCommands{$switch}{callback} if ($customCommands{$switch});
	$handler = $handlers{$switch} if (!$handler && $handlers{$switch});

	if ($handler) {
		$handler->($switch, $args);
		return 1;
	} else {
		my %params = ( switch => $switch, input => $input );
		Plugins::callHook('Command_post', \%params);
		if (!$params{return}) {
			error "Unknown command '$switch'. Please read the documentation for a list of commands.\n";
		}
	}
}


##
# Commands::register([name, description, callback]...)
# Returns: an ID for use with Commands::unregister()
#
# Register new commands.
#
# Example:
# my $ID = Commands::register(
#     ["my_command", "My custom command's description", \&my_callback],
#     ["another_command", "Yet another command description", \&another_callback]
# );
# Commands::unregister($ID);
sub register {
	my @result;

	foreach my $cmd (@_) {
		my $name = $cmd->[0];
		my %item = (
			desc => $cmd->[1],
			callback => $cmd->[2]
		);
		$customCommands{$name} = \%item;
		push @result, $name;
	}
	return \@result;
}


##
# Commands::unregister(ID)
# ID: an ID returned by Commands::register()
#
# Unregisters a registered command.
sub unregister {
	my $ID = shift;

	foreach my $name (@{$ID}) {
		delete $customCommands{$name};
	}
}


sub complete {
	my $input = shift;
	my ($switch, $args) = split(/ +/, $input, 2);

	return if ($input eq '');
	initCompletions() if (!%completions);

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
		delete $ai_v{temp};
		undef $char->{dead};
		message "AI sequences cleared\n", "success";

	} elsif ($args eq 'print') {
		# Display detailed info about current AI sequence
		message("------ AI Sequence ---------------------\n", "list");
		my $index = 0;
		foreach (@ai_seq) {
			message("$index: $_ " . dumpHash(\%{$ai_seq_args[$index]}) . "\n\n", "list");
			$index++;
		}

		message("------ AI Sequences --------------------\n", "list");

	} elsif ($args eq 'ai_v') {
		message dumpHash(\%ai_v) . "\n", "list";

	} elsif ($args eq 'on') {
		# Turn AI on
		if ($AI) {
			message "AI is already on\n", "success";
		} else {
			$AI = 1;
			undef $AI_forcedOff;
			message "AI turned on\n", "success";
		}
	} elsif ($args eq 'off') {
		# Turn AI off
		if ($AI) {
			undef $AI;
			$AI_forcedOff = 1;
			message "AI turned off\n", "success";
		} else {
			message "AI is already off\n", "success";
		}

	} elsif ($args eq '') {
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

	} else {
		error	"Syntax Error in function 'ai' (AI Commands)\n" .
			"Usage: ai [ clear | print | ai_v | on | off ]\n";
	}
}

sub cmdAIv {
	# Display current AI sequences
	my $on = $AI ? 'on' : 'off';
	message("ai_seq ($on) = @ai_seq\n", "list");
	message("solution\n", "list") if ($ai_seq_args[0]{'solution'});
}

sub cmdArrowCraft {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

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
			message("-------------------------------------------------\n","list")
		} else {
			error	"Error in function 'arrowcraft' (Create Arrows)\n" .
				"Type 'arrowcraft use' to get list.\n";
		}
	} elsif ($arg1 eq "use") {
		if (defined binFind(\@skillsID, 'AC_MAKINGARROW')) {
			main::ai_skillUse('AC_MAKINGARROW', 1, 0, 0, $accountID);
		} else {
			error	"Error in function 'arrowcraft' (Create Arrows)\n" .
				"You don't have Arrow Making Skill.\n";
		}
	} elsif ($arg1 eq "forceuse") {
		if ($char->{inventory}[$arg2] && %{$char->{inventory}[$arg2]}) {
			sendArrowCraft(\$remote_socket, $char->{inventory}[$arg2]{nameID});
		} else {
			error	"Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item $arg2 in your inventory.\n";
		}
	} else {
		if ($arrowCraftID[$arg1] ne "") {
			sendArrowCraft(\$remote_socket, $char->{inventory}[$arrowCraftID[$arg1]]{nameID});
		} else {
			error	"Error in function 'arrowcraft' (Create Arrows)\n" .
				"Usage: arrowcraft [<identify #>]",
				"Type 'arrowcraft use' to get list.\n";
		}
	}
}

sub cmdAttack {
	my (undef, $arg1) = @_;
	if ($arg1 =~ /^\d+$/) {
		if ($monstersID[$arg1] eq "") {
			error	"Error in function 'a' (Attack Monster)\n" .
				"Monster $arg1 does not exist.\n";
		} else {
			main::attack($monstersID[$arg1]);
		}
	} elsif ($arg1 eq "no") {
		configModify("attackAuto", 1);

	} elsif ($arg1 eq "yes") {
		configModify("attackAuto", 2);

	} else {
		error	"Syntax Error in function 'a' (Attack Monster)\n" .
			"Usage: attack <monster # | no | yes >\n";
	}
}

sub cmdAttackStop {
	my $index = AI::findAction("attack");
	if ($index ne "") {
		my $args = AI::args($index);
		my $monster = Actor::get($args->{ID});
		if ($monster) {
			$monster->{ignore} = 1;
			stopAttack();
			message "Stopped attacking $monster->{name} ($monster->{binID})\n", "success";
			AI::clear("attack");
		}
	}
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

sub cmdAutoBuy {
	message "Initiating auto-buy.\n";
	AI::queue("buyAuto");
}

sub cmdAutoSell {
	message "Initiating auto-sell.\n";
	AI::queue("sellAuto");
}

sub cmdAutoStorage {
	message "Initiating auto-storage.\n";
	AI::queue("storageAuto");
}

sub cmdBangBang {
	my $bodydir = $char->{look}{body} - 1;
	$bodydir = 7 if ($bodydir == -1);
	sendLook(\$remote_socket, $bodydir, $char->{look}{head});
}

sub cmdBingBing {
	my $bodydir = ($char->{look}{body} + 1) % 8;
	sendLook(\$remote_socket, $bodydir, $char->{look}{head});
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

sub cmdCard {
	my (undef, $input) = @_;
	my ($arg1) = $input =~ /^(\w+)/;
	my ($arg2) = $input =~ /^\w+ (\d+)/;
	my ($arg3) = $input =~ /^\w+ \d+ (\d+)/;

	if ($arg1 eq "mergecancel") {
		if ($cardMergeIndex ne "") {
			undef $cardMergeIndex;
			sendCardMerge(\$remote_socket, -1, -1);
		} else {
			error	"Error in function 'card mergecancel' (Cancel a card merge request)\n" .
				"You are not currently in a card merge session.\n";
		}
	} elsif ($arg1 eq "mergelist") {
		# FIXME: if your items change order or are used, this list will be wrong
		if (@cardMergeItemsID) {
			my $msg;
			$msg .= "-----Card Merge Candidates-----\n";
			foreach my $card (@cardMergeItemsID) {
				next if $card eq "" || !$char->{inventory}[$card] ||
					!%{$char->{inventory}[$card]};
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$card, $char->{inventory}[$card]]);
			}
			$msg .= "-------------------------------\n";
			message $msg, "list";
		} else {
			error	"Error in function 'card mergelist' (List availible card merge items)\n" .
				"You are not currently in a card merge session.\n";
		}
	} elsif ($arg1 eq "merge") {
		if ($arg2 =~ /^\d+$/) {
			my $found = binFind(\@cardMergeItemsID, $arg2);
			if (defined $found) {
				sendCardMerge(\$remote_socket, $char->{inventory}[$cardMergeIndex]{index}, $char->{inventory}[$arg2]{index});
			} else {
				if ($cardMergeIndex ne "") {
					error	"Error in function 'card merge' (Finalize card merging onto item)\n" .
						"There is no item $arg2 in the card mergelist.\n";
				} else {
					error	"Error in function 'card merge' (Finalize card merging onto item)\n" .
						"You are not currently in a card merge session.\n";
				}
			}
		} else {
			error	"Syntax Error in function 'card merge' (Finalize card merging onto item)\n" .
				"Usage: card merge <item number>\n" .
				"<item number> - Merge item number. Type 'card mergelist' to get number.\n";
		}
	} elsif ($arg1 eq "use") {
		if ($arg2 =~ /^\d+$/) {
			if ($char->{inventory}[$arg2] && %{$char->{inventory}[$arg2]}) {
				$cardMergeIndex = $arg2;
				sendCardMergeRequest(\$remote_socket, $char->{inventory}[$cardMergeIndex]{index});
				message "Sending merge list request for $char->{inventory}[$cardMergeIndex]{name}...\n";
			} else {
				error	"Error in function 'card use' (Request list of items for merging with card)\n" .
					"Card $arg2 does not exist.\n";
			}
		} else {
			error	"Syntax Error in function 'card use' (Request list of items for merging with card)\n" .
				"Usage: card use <item number>\n" .
				"<item number> - Card inventory number. Type 'i' to get number.\n";
		}
	} elsif ($arg1 eq "list") {
		my $msg;
		$msg .= "-----------Card List-----------\n";
		for (my $i = 0; $i < @{$char->{inventory}}; $i++) {
			next if (!$char->{'inventory'}[$i] || !%{$char->{'inventory'}[$i]});
			if ($char->{inventory}[$i]{type} == 6) {
				$msg .= "$i $char->{inventory}[$i]{name} x $char->{inventory}[$i]{amount}\n";
			}
		}
		$msg .= "-------------------------------\n";
		message $msg, "list";
	} elsif ($arg1 eq "forceuse") {
		if (!$char->{inventory}[$arg2] || !%{$char->{inventory}[$arg2]}) {
			error	"Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item $arg2 in your inventory.\n";
		} elsif (!$char->{inventory}[$arg3] || !%{$char->{inventory}[$arg3]}) {
			error	"Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item $arg3 in your inventory.\n";
		} else {
			sendCardMerge(\$remote_socket, $char->{inventory}[$arg2]{index}, $char->{inventory}[$arg3]{index});
		}
	} else {
		error	"Syntax Error in function 'card' (Card Compounding)\n" .
			"Usage: card <use|mergelist|mergecancel|merge>\n";
	}
}

sub cmdCart {
	my (undef, $input) = @_;
	my ($arg1, $arg2) = split(' ', $input, 2);

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
		cmdCart_add($arg2);

	} elsif ($arg1 eq "get") {
		cmdCart_get($arg2);

	} elsif ($arg1 eq "desc") {
		if (!($arg2 =~ /\d+/)) {
			error	"Syntax Error in function 'cart desc' (Show Cart Item Description)\n" .
				"'$arg2' is not a valid cart item number.\n";
		} elsif (!$cart{'inventory'}[$arg2]) {
			error	"Error in function 'cart desc' (Show Cart Item Description)\n" .
				"Cart Item $arg2 does not exist.\n";
		} else {
			printItemDesc($cart{'inventory'}[$arg2]{'nameID'});
		}

	} else {
		error	"Error in function 'cart'\n" .
			"Command '$arg1' is not a known command.\n";
	}
}

sub cmdCart_add {
	my ($name) = @_;

	if (!defined $name) {
		error	"Syntax Error in function 'cart add' (Add Item to Cart)\n" .
			"Usage: cart add <item>\n";
		return;
	}

	if (!hasCart()) {
		error	"Error in function 'cart add' (Add Item to Cart)\n" .
			"You do not have a cart.\n";
		return;
	}

	my $amount;
	if ($name =~ /^(.*?) (\d+)$/) {
		$name = $1;
		$amount = $2;
	}

	my $item = Match::inventoryItem($name);

	if (!$item) {
		error	"Error in function 'cart add' (Add Item to Cart)\n" .
			"Inventory Item $name does not exist.\n";
		return;
	}

	if (!$amount || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	sendCartAdd($item->{index}, $amount);
}

sub cmdCart_get {
	my ($name) = @_;

	if (!defined $name) {
		error	"Syntax Error in function 'cart get' (Get Item from Cart)\n" .
			"Usage: cart get <cart item>\n";
		return;
	}

	my $amount;
	if ($name =~ /^(.*?) (\d+)$/) {
		$name = $1;
		$amount = $2;
	}

	my $item = Match::cartItem($name);
	if (!$item) {
		error	"Error in function 'cart get' (Get Item from Cart)\n" .
			"Cart Item $name does not exist.\n";
		return;
	}

	if (!$amount || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	sendCartGet($item->{index}, $amount);
}


sub cmdChat {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'c' (Chat)\n" .
			"Usage: c <message>\n";
	} else {
		sendMessage(\$remote_socket, "c", $arg1);
	}
}

sub cmdChatLogClear {
	chatLog_clear();
	message("Chat log cleared.\n", "success");
}

sub cmdChatRoom {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;

	if ($arg1 eq "bestow") {
		my ($arg2) = $args =~ /^\w+ (\d+)/;

		if ($currentChatRoom eq "") {
			error	"Error in function 'chat bestow' (Bestow Admin in Chat)\n" .
				"You are not in a Chat Room.\n";
		} elsif ($arg2 eq "") {
			error	"Syntax Error in function 'chat bestow' (Bestow Admin in Chat)\n" .
				"Usage: chat bestow <user #>\n";
		} elsif ($currentChatRoomUsers[$arg2] eq "") {
			error	"Error in function 'chat bestow' (Bestow Admin in Chat)\n" .
				"Chat Room User $arg2 doesn't exist; type 'chat info' to see the list of users\n";
		} else {
			sendChatRoomBestow(\$remote_socket, $currentChatRoomUsers[$arg2]);
		}

	} elsif ($arg1 eq "modify") {
		my ($title) = $args =~ /^\w+ \"([\s\S]*?)\"/;
		my ($users) = $args =~ /^\w+ \"[\s\S]*?\" (\d+)/;
		my ($public) = $args =~ /^\w+ \"[\s\S]*?\" \d+ (\d+)/;
		my ($password) = $args =~ /^\w+ \"[\s\S]*?\" \d+ \d+ ([\s\S]+)/;

		if ($title eq "") {
			error	"Syntax Error in function 'chatmod' (Modify Chat Room)\n" .
				"Usage: chat modify \"<title>\" [<limit #> <public flag> <password>]\n";
		} else {
			if ($users eq "") {
				$users = 20;
			}
			if ($public eq "") {
				$public = 1;
			}
			sendChatRoomChange(\$remote_socket, $title, $users, $public, $password);
		}

	} elsif ($arg1 eq "kick") {
		my ($arg2) = $args =~ /^\w+ (\d+)/;

		if ($currentChatRoom eq "") {
			error	"Error in function 'chat kick' (Kick from Chat)\n" .
				"You are not in a Chat Room.\n";
		} elsif ($arg2 eq "") {
			error	"Syntax Error in function 'chat kick' (Kick from Chat)\n" .
				"Usage: chat kick <user #>\n";
		} elsif ($currentChatRoomUsers[$arg2] eq "") {
			error	"Error in function 'chat kick' (Kick from Chat)\n" .
				"Chat Room User $arg2 doesn't exist\n";
		} else {
			sendChatRoomKick(\$remote_socket, $currentChatRoomUsers[$arg2]);
		}

	} elsif ($arg1 eq "join") {
		my ($arg2) = $args =~ /^\w+ (\d+)/;
		my ($arg3) = $args =~ /^\w+ \d+ (\d+)/;

		if ($arg2 eq "") {
			error	"Syntax Error in function 'chat join' (Join Chat Room)\n" .
				"Usage: chat join <chat room #> [<password>]\n";
		} elsif ($currentChatRoom ne "") {
			error	"Error in function 'chat join' (Join Chat Room)\n" .
				"You are already in a chat room.\n";
		} elsif ($chatRoomsID[$arg2] eq "") {
			error	"Error in function 'chat join' (Join Chat Room)\n" .
				"Chat Room $arg2 does not exist.\n";
		} else {
			sendChatRoomJoin(\$remote_socket, $chatRoomsID[$arg2], $arg3);
		}

	} elsif ($arg1 eq "leave") {
		if ($currentChatRoom eq "") {
			error	"Error in function 'chat leave' (Leave Chat Room)\n" .
				"You are not in a Chat Room.\n";
		} else {
			sendChatRoomLeave(\$remote_socket);
		}

	} elsif ($arg1 eq "create") {
		my ($title) = $args =~ /^\w+ \"([\s\S]*?)\"/;
		my ($users) = $args =~ /^\w+ \"[\s\S]*?\" (\d+)/;
		my ($public) = $args =~ /^\w+ \"[\s\S]*?\" \d+ (\d+)/;
		my ($password) = $args =~ /^\w+ \"[\s\S]*?\" \d+ \d+ ([\s\S]+)/;

		if ($title eq "") {
			error	"Syntax Error in function 'chat create' (Create Chat Room)\n" .
				"Usage: chat create \"<title>\" [<limit #> <public flag> <password>]\n";
		} elsif ($currentChatRoom ne "") {
			error	"Error in function 'chat create' (Create Chat Room)\n" .
				"You are already in a chat room.\n";
		} else {
			if ($users eq "") {
				$users = 20;
			}
			if ($public eq "") {
				$public = 1;
			}
			$title = ($config{chatTitleOversize}) ? $title : substr($title,0,36);
			sendChatRoomCreate(\$remote_socket, $title, $users, $public, $password);
			$createdChatRoom{'title'} = $title;
			$createdChatRoom{'ownerID'} = $accountID;
			$createdChatRoom{'limit'} = $users;
			$createdChatRoom{'public'} = $public;
			$createdChatRoom{'num_users'} = 1;
			$createdChatRoom{'users'}{$char->{name}} = 2;
		}

	} elsif ($arg1 eq "list") {
		message("------------------------------- Chat Room List --------------------------------\n" .
			"#   Title                                  Owner                Users   Type\n",
			"list");
		for (my $i = 0; $i < @chatRoomsID; $i++) {
			next if ($chatRoomsID[$i] eq "");
			my $owner_string = ($chatRooms{$chatRoomsID[$i]}{'ownerID'} ne $accountID) ? $players{$chatRooms{$chatRoomsID[$i]}{'ownerID'}}{'name'} : $char->{'name'};
			my $public_string = ($chatRooms{$chatRoomsID[$i]}{'public'}) ? "Public" : "Private";
			my $limit_string = $chatRooms{$chatRoomsID[$i]}{'num_users'}."/".$chatRooms{$chatRoomsID[$i]}{'limit'};
			message(swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<<<<",
				[$i, $chatRooms{$chatRoomsID[$i]}{'title'}, $owner_string, $limit_string, $public_string]),
				"list");
		}
		message("-------------------------------------------------------------------------------\n", "list");

	} elsif ($arg1 eq "info") {
		if ($currentChatRoom eq "") {
			error "There is no chat room info - you are not in a chat room\n";
		} else {
			message("-----------Chat Room Info-----------\n" .
				"Title                     Users   Public/Private\n",
				"list");
			my $public_string = ($chatRooms{$currentChatRoom}{'public'}) ? "Public" : "Private";
			my $limit_string = $chatRooms{$currentChatRoom}{'num_users'}."/".$chatRooms{$currentChatRoom}{'limit'};

			message(swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<<<<<<<",
				[$chatRooms{$currentChatRoom}{'title'}, $limit_string, $public_string]),
				"list");

			message("-- Users --\n", "list");
			for (my $i = 0; $i < @currentChatRoomUsers; $i++) {
				next if ($currentChatRoomUsers[$i] eq "");
				my $user_string = $currentChatRoomUsers[$i];
				my $admin_string = ($chatRooms{$currentChatRoom}{'users'}{$currentChatRoomUsers[$i]} > 1) ? "(Admin)" : "";
				message(swrite(
					"@<< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<",
					[$i, $user_string, $admin_string]),
					"list");
			}
			message("------------------------------------\n", "list");
		}
	} else {
		error	"Syntax Error in function 'chat' (Chat room management)\n" .
			"Usage: chat <create|modify|join|kick|leave|info|list|bestow>\n";
	}

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
		Log::initLogFiles();
	}
}

sub cmdDamage {
	my (undef, $args) = @_;
	
	if ($args eq "") {
		my $total = 0;
		message("Damage Taken Report:\n", "list");
		message(sprintf("%-40s %-20s %-10s\n", 'Name', 'Skill', 'Damage'), "list");
		for my $monsterName (sort keys %damageTaken) {
			my $monsterHref = $damageTaken{$monsterName};
			for my $skillName (sort keys %{$monsterHref}) {
				message sprintf("%-40s %-20s %10d\n", $monsterName, $skillName, $monsterHref->{$skillName}), "list";
				$total += $monsterHref->{$skillName};
			}
		}
		message("Total Damage Taken: $total\n", "list");
		message("End of report.\n", "list");

	} elsif ($args eq "reset") {
		undef %damageTaken;
		message "Damage Taken Report reset.\n", "success";
	} else {
		error "Error in function 'damage' (Damage Report)\n" .
			"Usage: damage [reset]\n";
	}
}
sub cmdDeal {
	my (undef, $args) = @_;
	my @arg = split / /, $args;

	if (%currentDeal && $arg[0] =~ /\d+/) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"You are already in a deal\n";
	} elsif (%incomingDeal && $arg[0] =~ /\d+/) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"You must first cancel the incoming deal\n";
	} elsif ($arg[0] =~ /\d+/ && !$playersID[$arg[0]]) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"Player $arg[0] does not exist\n";
	} elsif ($arg[0] =~ /\d+/) {
		my $ID = $playersID[$arg[0]];
		my $player = Actor::get($ID);
		message "Attempting to deal $player\n";
		deal($player);

	} elsif ($arg[0] eq "no" && !%incomingDeal && !%outgoingDeal && !%currentDeal) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"There is no incoming/current deal to cancel\n";
	} elsif ($arg[0] eq "no" && (%incomingDeal || %outgoingDeal)) {
		sendDealCancel();
	} elsif ($arg[0] eq "no" && %currentDeal) {
		sendCurrentDealCancel();

	} elsif ($arg[0] eq "" && !%incomingDeal && !%currentDeal) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"There is no deal to accept\n";
	} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && !$currentDeal{'other_finalize'}) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"Cannot make the trade - $currentDeal{'name'} has not finalized\n";
	} elsif ($arg[0] eq "" && $currentDeal{'final'}) {
		error	"Error in function 'deal' (Deal a Player)\n" .
			"You already accepted the final deal\n";
	} elsif ($arg[0] eq "" && %incomingDeal) {
		sendDealAccept();
	} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && $currentDeal{'other_finalize'}) {
		sendDealTrade();
		$currentDeal{'final'} = 1;
		message("You accepted the final Deal\n", "deal");
	} elsif ($arg[0] eq "" && %currentDeal) {
		sendDealAddItem(0, $currentDeal{'you_zenny'});
		sendDealFinalize();

	} elsif ($arg[0] eq "add" && !%currentDeal) {
		error	"Error in function 'deal_add' (Add Item to Deal)\n" .
			"No deal in progress\n";
	} elsif ($arg[0] eq "add" && $currentDeal{'you_finalize'}) {
		error	"Error in function 'deal_add' (Add Item to Deal)\n" .
			"Can't add any Items - You already finalized the deal\n";
	} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/ && ( !$char->{'inventory'}[$arg[1]] || !%{$char->{'inventory'}[$arg[1]]} )) {
		error	"Error in function 'deal_add' (Add Item to Deal)\n" .
			"Inventory Item $arg[1] does not exist.\n";
	} elsif ($arg[0] eq "add" && $arg[2] && $arg[2] !~ /\d+/) {
		error	"Error in function 'deal_add' (Add Item to Deal)\n" .
			"Amount must either be a number, or not specified.\n";
	} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/) {
		if ($currentDeal{you_items} < 10) {
			if (!$arg[2] || $arg[2] > $char->{'inventory'}[$arg[1]]{'amount'}) {
				$arg[2] = $char->{'inventory'}[$arg[1]]{'amount'};
			}
			dealAddItem($char->{inventory}[$arg[1]], $arg[2]);
		} else {
			error("You can't add any more items to the deal\n", "deal");
		}
	} elsif ($arg[0] eq "add" && $arg[1] eq "z") {
		if (!$arg[2] || $arg[2] > $char->{'zenny'}) {
			$arg[2] = $char->{'zenny'};
		}
		$currentDeal{'you_zenny'} = $arg[2];
		message("You put forward " . formatNumber($arg[2]) . "z to Deal\n", "deal");

	} else {
		error	"Syntax Error in function 'deal' (Deal a player)\n" .
			"Usage: deal [<Player # | no | add>] [<item #>] [<amount>]\n";
	}
}

sub cmdDealList {
	if (!%currentDeal) {
		error "There is no deal list - You are not in a deal\n";

	} else {
		message("-----------Current Deal-----------\n", "list");
		my $other_string = $currentDeal{'name'};
		my $you_string = "You";
		if ($currentDeal{'other_finalize'}) {
			$other_string .= " - Finalized";
		}
		if ($currentDeal{'you_finalize'}) {
			$you_string .= " - Finalized";
		}

		message(swrite(
			"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
			[$you_string, $other_string]),
			"list");

		my @currentDealYou;
		my @currentDealOther;
		foreach (keys %{$currentDeal{'you'}}) {
			push @currentDealYou, $_;
		}
		foreach (keys %{$currentDeal{'other'}}) {
			push @currentDealOther, $_;
		}

		my ($lastindex, $display, $display2);
		$lastindex = @currentDealOther;
		$lastindex = @currentDealYou if (@currentDealYou > $lastindex);
		for (my $i = 0; $i < $lastindex; $i++) {
			if ($i < @currentDealYou) {
				$display = ($items_lut{$currentDealYou[$i]} ne "")
					? $items_lut{$currentDealYou[$i]}
					: "Unknown ".$currentDealYou[$i];
				$display .= " x $currentDeal{'you'}{$currentDealYou[$i]}{'amount'}";
			} else {
				$display = "";
			}
			if ($i < @currentDealOther) {
				$display2 = ($items_lut{$currentDealOther[$i]} ne "")
					? $items_lut{$currentDealOther[$i]}
					: "Unknown ".$currentDealOther[$i];
				$display2 .= " x $currentDeal{'other'}{$currentDealOther[$i]}{'amount'}";
			} else {
				$display2 = "";
			}

			message(swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$display, $display2]),
				"list");
		}
		$you_string = ($currentDeal{'you_zenny'} ne "") ? $currentDeal{'you_zenny'} : 0;
		$other_string = ($currentDeal{'other_zenny'} ne "") ? $currentDeal{'other_zenny'} : 0;

		message(swrite(
			"Zenny: @<<<<<<<<<<<<<            Zenny: @<<<<<<<<<<<<<",
			[formatNumber($you_string), formatNumber($other_string)]),
			"list");
		message("----------------------------------\n", "list");
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

sub cmdDoriDori {
	my $headdir;
	if ($char->{look}{head} == 2) {
		$headdir = 1;
	} else {
		$headdir = 2;
	}
	sendLook(\$remote_socket, $char->{look}{body}, $headdir);
}

sub cmdDrop {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\d,-]+)/;
	my ($arg2) = $args =~ /^[\d,-]+ (\d+)$/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'drop' (Drop Inventory Item)\n" .
			"Usage: drop <item #> [<amount>]\n";
	} else {
		my @temp = split(/,/, $arg1);
		@temp = grep(!/^$/, @temp); # Remove empty entries

		my @items = ();
		foreach (@temp) {
			if (/(\d+)-(\d+)/) {
				for ($1..$2) {
					push(@items, $_) if ($char->{inventory}[$_] && %{$char->{inventory}[$_]});
				}
			} else {
				push @items, $_ if ($char->{inventory}[$_] && %{$char->{inventory}[$_]});
			}
		}
		if (@items > 0) {
			main::ai_drop(\@items, $arg2);
		} else {
			error "No items were dropped.\n";
		}
	}
}

sub cmdDump {
	dumpData($msg);
	quit();
}

sub cmdDumpNow {
	dumpData($msg);
}

sub cmdEmotion {
	# Show emotion
	my (undef, $args) = @_;

	my $num = getEmotionByCommand($args);

	if (!defined $num) {
		error	"Syntax Error in function 'e' (Emotion)\n" .
			"Usage: e <command>\n";
	} else {
		sendEmotion(\$remote_socket, $num);
	}
}

sub cmdEquip {
	# Equip an item
	my (undef, $args) = @_;
	my ($arg1,$arg2) = $args =~ /^(\S+)\s*(.*)/;
	my $slot;
	my $item;

	if ($arg1 eq "") {
		error "You must specify an item to equip.\n";
		return;
	}


	if ($arg1 eq "slots") {
		message "Slots:\ntopHead\nmidHead\nlowHead\n".
				"leftHand\nrightHand\nleftAccessory\n".
				"rightAccessory\nrobe\narmor\nshoes\n";
		return;
	}

	if ($equipSlot_rlut{$arg1}) {
		$slot = $arg1;
	} else {
		$arg1 .= " $arg2" if $arg2;
	}

	$item = (defined $slot) ? (Item::get($arg2)) : (Item::get($arg1));

	if (!$item) {
		error "You don't have $arg1.\n";
		return;
	}

	if (!$item->{type_equip} && $item->{type} != 10) {
		error "Inventory Item $item->{name} ($item->{invIndex}) can't be equipped.\n";
		return;
	}
	if ($slot) {
		$item->equipInSlot($slot);
	}
	else {
		$item->equip();
	}
}

sub cmdEquipment {
	message(swrite(
	"    / \\   topHead:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{topHead})?"$char->{equipment}{topHead}{name} ($char->{equipment}{topHead}{invIndex})":''],
	"    | |   midHead:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{midHead})?"$char->{equipment}{midHead}{name} ($char->{equipment}{midHead}{invIndex})":''],
	"    \\ /   lowHead:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{lowHead})?"$char->{equipment}{lowHead}{name} ($char->{equipment}{lowHead}{invIndex})":''],
	"     |    robe:      @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{robe})?"$char->{equipment}{robe}{name} ($char->{equipment}{robe}{invIndex})":''],
	"   / | \\  armor:     @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{armor})?"$char->{equipment}{armor}{name} ($char->{equipment}{armor}{invIndex})":''],
	"  /  |  \\ leftHand:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{leftHand})?"$char->{equipment}{leftHand}{name} ($char->{equipment}{leftHand}{invIndex})":''],
	" /   |   \\rightHand: @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{rightHand})?"$char->{equipment}{rightHand}{name} ($char->{equipment}{rightHand}{invIndex})":''],
	"     |    leftAcc:   @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{leftAccessory})?"$char->{equipment}{leftAccessory}{name} ($char->{equipment}{leftAccessory}{invIndex})":''],
	"    / \\   rightAcc:  @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{rightAccessory})?"$char->{equipment}{rightAccessory}{name} ($char->{equipment}{rightAccessory}{invIndex})":''],
	"   /   \\  arrow:     @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{arrow})?"$char->{equipment}{arrow}{name} ($char->{equipment}{arrow}{invIndex})":''],
	"  /     \\ shoes:     @<<<<<<<<<<<<<<<<<<<<<<<<<<<",
	[($char->{equipment}{shoes})?"$char->{equipment}{shoes}{name} ($char->{equipment}{shoes}{invIndex})":''],
	" /       \\",
	[]
	));
}

sub cmdEval {
	if ($_[1] eq "") {
		error	"Syntax Error in function 'eval' (Evaluate a Perl expression)\n" .
			"Usage: eval <expression>\n";
	} else {
		package main;
		no strict;
		undef $@;
		eval $_[1];
		Log::error("$@") if ($@);
	}
}

sub cmdExp {
	my (undef, $args) = @_;
	# exp report
	my ($arg1) = $args =~ /^(\w+)/;
	if ($arg1 eq ""){
		my ($endTime_EXP,$w_sec,$total,$bExpPerHour,$jExpPerHour,$EstB_sec,$percentB,$percentJ,$zennyMade,$zennyPerHour,$EstJ_sec,$percentJhr,$percentBhr);
		$endTime_EXP = time;
		$w_sec = int($endTime_EXP - $startTime_EXP);
		if ($w_sec > 0) {
			$zennyMade = $char->{zenny} - $startingZenny;
			$bExpPerHour = int($totalBaseExp / $w_sec * 3600);
			$jExpPerHour = int($totalJobExp / $w_sec * 3600);
			$zennyPerHour = int($zennyMade / $w_sec * 3600);
			if ($char->{exp_max} && $bExpPerHour){
				$percentB = "(".sprintf("%.2f",$totalBaseExp * 100 / $char->{exp_max})."%)";
				$percentBhr = "(".sprintf("%.2f",$bExpPerHour * 100 / $char->{exp_max})."%)";
				$EstB_sec = int(($char->{exp_max} - $char->{exp})/($bExpPerHour/3600));
			}
			if ($char->{exp_job_max} && $jExpPerHour){
				$percentJ = "(".sprintf("%.2f",$totalJobExp * 100 / $char->{exp_job_max})."%)";
				$percentJhr = "(".sprintf("%.2f",$jExpPerHour * 100 / $char->{exp_job_max})."%)";
				$EstJ_sec = int(($char->{'exp_job_max'} - $char->{exp_job})/($jExpPerHour/3600));
			}
		}
		$char->{deathCount} = 0 if (!defined $char->{deathCount});
		message("------------Exp Report------------\n" .
		"Botting time : " . timeConvert($w_sec) . "\n" .
		"BaseExp      : " . formatNumber($totalBaseExp) . " $percentB\n" .
		"JobExp       : " . formatNumber($totalJobExp) . " $percentJ\n" .
		"BaseExp/Hour : " . formatNumber($bExpPerHour) . " $percentBhr\n" .
		"JobExp/Hour  : " . formatNumber($jExpPerHour) . " $percentJhr\n" .
		"Zenny        : " . formatNumber($zennyMade) . "\n" .
		"Zenny/Hour   : " . formatNumber($zennyPerHour) . "\n" .
		"Base Levelup Time Estimation : " . timeConvert($EstB_sec) . "\n" .
		"Job Levelup Time Estimation  : " . timeConvert($EstJ_sec) . "\n" .
		"Died : $char->{'deathCount'}\n", "info");

		message("-[Monster Killed Count]-----------\n" .
			"#   ID   Name                Count\n",
			"list");
		for (my $i = 0; $i < @monsters_Killed; $i++) {
			next if ($monsters_Killed[$i] eq "");
			message(swrite(
				"@<< @<<<< @<<<<<<<<<<<<<       @<<< ",
				[$i, $monsters_Killed[$i]{'nameID'}, $monsters_Killed[$i]{'name'}, $monsters_Killed[$i]{'count'}]),
				"list");
			$total += $monsters_Killed[$i]{'count'};
		}
		message("----------------------------------\n" .
			"Total number of killed monsters: $total\n" .
			"----------------------------------\n",
			"list");

		message("-[Item Change Count]-------------\n", "list");
		message(sprintf("%-40s %s\n", 'Name', 'Count'), "list");
		for my $item (sort keys %itemChange) {
			next unless $itemChange{$item};
			message(sprintf("%-40s %5d\n", $item, $itemChange{$item}), "list");
		}
		message("---------------------------------\n", "list");

	} elsif ($arg1 eq "reset") {
		($bExpSwitch,$jExpSwitch,$totalBaseExp,$totalJobExp) = (2,2,0,0);
		$startTime_EXP = time;
		$startingZenny = $char->{zenny};
		undef @monsters_Killed;
		$dmgpsec = 0;
		$totaldmg = 0;
		$elasped = 0;
		$totalelasped = 0;
		undef %itemChange;
		message "Exp counter reset.\n", "success";
	} else {
		error "Error in function 'exp' (Exp Report)\n" .
			"Usage: exp [reset]\n";
	}
}

sub cmdFollow {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'follow' (Follow Player)\n" .
			"Usage: follow <player #>\n";
	} elsif ($arg1 eq "stop") {
		AI::clear("follow");
		configModify("follow", 0);
	} elsif ($arg1 =~ /^\d+$/) {
		if (!$playersID[$arg1]) {
			error	"Error in function 'follow' (Follow Player)\n" .
				"Player $arg1 either not visible or not online in party.\n";
		} else {
			AI::clear("follow");
			main::ai_follow($players{$playersID[$arg1]}->name);
			configModify("follow", 1);
			configModify("followTarget", $players{$playersID[$arg1]}{name});
		}

	} else {
		AI::clear("follow");
		main::ai_follow($arg1);
		configModify("follow", 1);
		configModify("followTarget", $arg1);
	}
}

sub cmdFriend {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = split(' ', $args, 2);

	if ($arg1 eq "request") {
		my $player = Match::player($arg2);

		if (!$player) {
			error "Player $arg2 does not exist\n";
		} elsif (!$player->{gotName}) {
			error "Player name has not been received, please try again\n";
		} else {
			my $alreadyFriend = 0;
			for (my $i = 0; $i < @friendsID; $i++) {
				if ($friends{$i}{'name'} eq $player->{name}) {
					$alreadyFriend = 1;
					last;
				}
			}
			if ($alreadyFriend) {
				error "$player->{name} is already your friend\n";
			} else {
				message "Requesting $player->{name} to be your friend\n";
				sendFriendRequest(\$remote_socket, $players{$playersID[$arg2]}{name});
			}
		}

	} elsif ($arg1 eq "remove") {
		if ($arg2 < 1 || $arg2 > @friendsID) {
			error "Friend #$arg2 does not exist\n";
		} else {
			$arg2--;
			message "Attempting to remove $friends{$arg2}{'name'} from your friend list\n";
			sendFriendRemove(\$remote_socket, $friends{$arg2}{'accountID'}, $friends{$arg2}{'charID'});
		}

	} elsif ($arg1 eq "accept") {
		if ($incomingFriend{'accountID'} eq "") {
			error "Can't accept the friend request, no incoming request\n";
		} else {
			message "Accepting the friend request from $incomingFriend{'name'}\n";
			sendFriendAccept(\$remote_socket, $incomingFriend{'accountID'}, $incomingFriend{'charID'});
			undef %incomingFriend;
		}

	} elsif ($arg1 eq "reject") {
		if ($incomingFriend{'accountID'} eq "") {
			error "Can't reject the friend request - no incoming request\n";
		} else {
			message "Rejecting the friend request from $incomingFriend{'name'}\n";
			sendFriendReject(\$remote_socket, $incomingFriend{'accountID'}, $incomingFriend{'charID'});
			undef %incomingFriend;
		}

	} elsif ($arg1 eq "pm") {
		if ($arg2 < 1 || $arg2 > @friendsID) {
			error "Friend #$arg2 does not exist\n";
		} else {
			$arg2--;
			if (binFind(\@privMsgUsers, $friends{$arg2}{'name'}) eq "") {
				message "Friend $friends{$arg2}{'name'} has been added to the PM list as ".@privMsgUsers."\n";
				$privMsgUsers[@privMsgUsers] = $friends{$arg2}{'name'};
			} else {
				message "Friend $friends{$arg2}{'name'} is already in the PM list\n";
			}
		}

	} elsif ($arg1 ne "") {
		error "Syntax Error in function 'friend' (Manage Friends List)\n" .
			"Usage: friend [request|remove|accept|reject|pm]\n";

	} else {
		message("------------- Friends --------------\n", "list");
		message("#   Name                      Online\n", "list");
		for (my $i = 0; $i < @friendsID; $i++) {
			message(swrite(
				"@<  @<<<<<<<<<<<<<<<<<<<<<<<  @",
				[$i + 1, $friends{$i}{'name'}, $friends{$i}{'online'}? 'X':'']),
				"list");
		}
		message("----------------------------------\n", "list");
	}

}

sub cmdGetPlayerInfo {
	my (undef, $args) = @_;
	sendGetPlayerInfo(\$remote_socket, pack("V", $args));
}

sub cmdGuild {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = split(' ', $args, 2);

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

	} elsif ($arg1 eq "create") {
		if (!$arg2) {
			error	"Syntax Error in function 'guild create' (Create Guild)\n" .
				"Usage: guild create <name>\n";
		} else {
			sendGuildCreate($arg2);
		}

	} elsif (!defined $char->{guild}) {
		error "You are not in a guild.\n";

	} elsif ($arg1 eq "request") {
		my $player = Match::player($arg2);
		if (!$player) {
			error "Player $arg2 does not exist.\n";
		} else {
			sendGuildJoinRequest($player->{ID});
			message "Sent guild join request to $player->{name}\n";
		}

	} elsif ($arg1 eq "leave") {
		sendGuildLeave($arg2);
		message "Sending guild leave: $arg2\n";

	} elsif ($arg1 eq "break") {
		if (!$arg2) {
			error	"Syntax Error in function 'guild break' (Break Guild)\n" .
				"Usage: guild break <guild name>\n";
		} else {
			sendGuildBreak($arg2);
			message "Sending guild break: $arg2\n";
		}

	} elsif ($arg1 eq "" || !%guild) {
		message	"Requesting guild information...\n", "info";
		sendGuildInfoRequest(\$remote_socket);

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		sendGuildRequest(\$remote_socket, 0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
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

	} elsif ($arg1 eq "kick") {
		if (!$guild{member}) {
			error "No guild member information available.\n";
			return;
		}
		my @params = split(' ', $arg2, 2);
		if ($params[0] =~ /^\d+$/) {
			if ($guild{'member'}[$params[0]]) {
				sendGuildMemberKick($char->{guildID},
					$guild{member}[$params[0]]{ID},
					$guild{member}[$params[0]]{charID},
					$params[1]);
			} else {
				error	"Error in function 'guild kick' (Kick Guild Member)\n" .
					"Invalid guild member '$params[0]' specified.\n";
			}
		} else {
			error	"Syntax Error in function 'guild kick' (Kick Guild Member)\n" .
				"Usage: guild kick <number> <reason>\n";
		}

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

sub cmdGuildChat {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error 	"Syntax Error in function 'g' (Guild Chat)\n" .
			"Usage: g <message>\n";
	} else {
		sendMessage(\$remote_socket, "g", $arg1);
	}
}

sub cmdHelp {
	# Display help message
	my (undef, $args) = @_;
	my @commands_req = split(/ +/, $args);
	my @unknown;
	my @found;

	my @commands = (@commands_req)? @commands_req : (sort keys %descriptions);

	my ($message,$cmd);

	$message .= "--------------- Available commands ---------------\n" unless @commands_req;
	foreach my $switch (@commands) {
		if ($descriptions{$switch}) {
			if (ref($descriptions{$switch}) eq 'ARRAY') {
				if (@commands_req) {
					helpIndent($switch,$descriptions{$switch});
				} else {
					$message .= sprintf("%-11s  %s\n",$switch, $descriptions{$switch}->[0]);
				}
			}
			push @found, $switch;
		} else {
			push @unknown, $switch;
		}
	}

	@commands = (@commands_req)? @commands_req : (sort keys %customCommands);
	foreach my $switch (@commands) {
		if ($customCommands{$switch}) {
			if (ref($customCommands{$switch}{desc}) eq 'ARRAY') {
				if (@commands_req) {
					helpIndent($switch,$customCommands{$switch}{desc});
				} else {
					$message .= sprintf("%-11s  %s\n",$switch, $customCommands{$switch}{desc}->[0]);
				}
			}
			push @found, $switch;
		} else {
			push @unknown, $switch unless defined binFind(\@unknown,$switch);
		}
	}

	foreach (@found) {
		binRemoveAndShift(\@unknown,$_);
	}

	if (@unknown) {
		if (@unknown == 1) {
			error("The command \"$unknown[0]\" doesn't exist.\n");
		} else {
			error("These commands don't exist: " . join(', ', @unknown) . "\n");
		}
		error("Type 'help' to see a list of all available commands.\n");
	}
	$message .= "--------------------------------------------------\n"unless @commands_req;

	message $message, "list" unless @commands_req;
}

sub helpIndent {
	my $cmd = shift;
	my $desc = shift;
	my $message;
	my $messageTmp;
	my @words;
	my $length = 0;

	$message = "------------ Help for $cmd ------------\n";
	$message .= shift (@{$desc})."\n";

	foreach (@{$desc}) {
		$length = length ($_->[0]) if length ($_->[0]) > $length;
	}
	my $pattern = "$cmd %-${length}s    -%s\n";
	my $padsize = length($cmd) + $length + 5;
	my $pad = sprintf("%-${padsize}s",'');

	foreach (@{$desc}) {
		if ($padsize + length($_->[1]) > 79) {
			@words = split (/ /,$_->[1]);
			$message .= sprintf ("$cmd %-${length}s    ",$_->[0]);
			$messageTmp = '';
			foreach my $word (@words) {
				if ($padsize + length($messageTmp) + length($word) + 1 > 79) {
					$message .= $messageTmp . "\n$pad";
					$messageTmp = '';
				} else {
					$messageTmp .= "$word ";
				}
			}
			$message .= $messageTmp."\n";
		}
		else {
			$message .= sprintf ($pattern,$_->[0],$_->[1]);
		}
	}
	$message .= "--------------------------------------------------\n";
	message $message, "list";
}

sub cmdIdentify {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		message("---------Identify List--------\n", "list");
		for (my $i = 0; $i < @identifyID; $i++) {
			next if ($identifyID[$i] eq "");
			message(swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $char->{'inventory'}[$identifyID[$i]]{name}]),
				"list");
		}
		message("------------------------------\n", "list");

	} elsif ($arg1 =~ /^\d+$/) {
		if ($identifyID[$arg1] eq "") {
			error	"Error in function 'identify' (Identify Item)\n" .
				"Identify Item $arg1 does not exist\n";
		} else {
			sendIdentify(\$remote_socket, $char->{'inventory'}[$identifyID[$arg1]]{'index'});
		}

	} else {
		error	"Syntax Error in function 'identify' (Identify Item)\n" .
			"Usage: identify [<identify #>]\n";
	}
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

sub cmdIhist {
	# Display item history
	my (undef, $args) = @_;
	$args = 5 if ($args eq "");

	if (!($args =~ /^\d+$/)) {
		error	"Syntax Error in function 'ihist' (Show Item History)\n" .
			"Usage: ihist [<number of entries #>]\n";

	} elsif (open(ITEM, "<", $Settings::item_log_file)) {
		my @item = <ITEM>;
		close(ITEM);
		message("------ Item History --------------------\n", "list");
		my $i = @item - $args;
		$i = 0 if ($i < 0);
		for (; $i < @item; $i++) {
			message($item[$i], "list");
		}
		message("----------------------------------------\n", "list");

	} else {
		error "Unable to open $Settings::item_log_file\n";
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

sub cmdItemLogClear {
	itemLog_clear();
	message("Item log cleared.\n", "success");
}

sub cmdInventory {
	# Display inventory items
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if (!$char->{'inventory'}) {
		error "Inventory is empty\n";
		return;
	}

	if ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "neq" || $arg1 eq "u" || $arg1 eq "nu") {
		my @useable;
		my @equipment;
		my @uequipment;
		my @non_useable;
		my ($i, $display, $index);

		for ($i = 0; $i < @{$char->{'inventory'}}; $i++) {
			my $item = $char->{'inventory'}[$i];
			next unless $item && %{$item};
			if (($item->{type} == 3 ||
			     $item->{type} == 6 ||
				 $item->{type} == 10) && !$item->{equipped}) {
				push @non_useable, $i;
			} elsif ($item->{type} <= 2) {
				push @useable, $i;
			} else {
				my %eqp;
				$eqp{index} = $item->{index};
				$eqp{binID} = $i;
				$eqp{name} = $item->{name};
				$eqp{type} = $itemTypes_lut{$item->{type}};
				$eqp{equipped} = ($item->{type} == 10) ? $item->{amount} . " left" : $equipTypes_lut{$item->{equipped}};
				$eqp{equipped} .= " ($item->{equipped})";
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
				$display = $char->{'inventory'}[$index]{'name'};
				$display .= " x $char->{'inventory'}[$index]{'amount'}";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]);
			}
		}
		if ($arg1 eq "" || $arg1 eq "u") {
			$msg .= "-- Usable --\n";
			for ($i = 0; $i < @useable; $i++) {
				$display = $char->{'inventory'}[$useable[$i]]{'name'};
				$display .= " x $char->{'inventory'}[$useable[$i]]{'amount'}";
				$index = $useable[$i];
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$index, $display]);
			}
		}
		$msg .= "-------------------------------\n";
		message($msg, "list");

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && $char->{'inventory'}[$arg2] eq "") {
		error	"Error in function 'i' (Inventory Item Desciption)\n" .
			"Inventory Item $arg2 does not exist\n";
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		printItemDesc($char->{'inventory'}[$arg2]{'nameID'});

	} else {
		error	"Syntax Error in function 'i' (Inventory List)\n" .
			"Usage: i [<u|eq|neq|nu|desc>] [<inventory #>]\n";
	}
}

#sub cmdJudge {
#	my (undef, $args) = @_;
#	my ($arg1) = $args =~ /^(\d+)/;
#	my ($arg2) = $args =~ /^\d+ (\d+)/;
#	if ($arg1 eq "" || $arg2 eq "") {
#		error	"Syntax Error in function 'judge' (Give an alignment point to Player)\n" .
#			"Usage: judge <player #> <0 (good) | 1 (bad)>\n";
#	} elsif ($playersID[$arg1] eq "") {
#		error	"Error in function 'judge' (Give an alignment point to Player)\n" .
#			"Player $arg1 does not exist.\n";
#	} else {
#		$arg2 = ($arg2 >= 1);
#		sendAlignment(\$remote_socket, $playersID[$arg1], $arg2);
#	}
#}

sub cmdLook {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)$/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'look' (Look a Direction)\n" .
			"Usage: look <body dir> [<head dir>]\n";
	} else {
		look($arg1, $arg2);
	}
}

sub cmdLookPlayer {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'lookp' (Look at Player)\n" .
			"Usage: lookp <player #>\n";
	} elsif (!$playersID[$arg1]) {
		error	"Error in function 'lookp' (Look at Player)\n" .
			"'$arg1' is not a valid player number.\n";
	} else {
		lookAtPosition($players{$playersID[$arg1]}{pos_to});
	}
}

sub cmdManualMove {
	my ($switch) = @_;
	if ($switch eq "east") {
		manualMove(5, 0);
	} elsif ($switch eq "west") {
		manualMove(-5, 0);
	} elsif ($switch eq "north") {
		manualMove(0, 5);
	} elsif ($switch eq "south") {
		manualMove(0, -5);
	} elsif ($switch eq "northeast") {
		manualMove(5, 5);
	} elsif ($switch eq "southwest") {
		manualMove(-5, -5);
	} elsif ($switch eq "northwest") {
		manualMove(-5, 5);
	} elsif ($switch eq "southeast") {
		manualMove(5, -5);
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
		$dist = distance(\%{$char->{'pos_to'}}, \%{$monsters{$monstersID[$i]}{'pos_to'}});
		$dist = sprintf("%.1f", $dist) if (index($dist, '.') > -1);
		$pos = '(' . $monsters{$monstersID[$i]}{'pos_to'}{'x'} . ', ' . $monsters{$monstersID[$i]}{'pos_to'}{'y'} . ')';

		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<    @<<<<      @<<<<<      @<<<<<<<<<<",
			[$i, $monsters{$monstersID[$i]}{'name'}, $dmgTo, $dmgFrom, $dist, $pos]),
			"list");
	}
	message("----------------------------------\n", "list");
}

sub cmdMove {
	my (undef, $args) = @_;
	my ($arg1, $arg2, $arg3) = $args =~ /^(\d+) (\d+)(.*?)$/;

	my $map;
	if ($arg1 eq "") {
		$map = $args;
	} else {
		$map = $arg3;
	}
	$map =~ s/\s//g;
	# FIXME: this should be integrated with the other numbers
	if ($args eq "0") {
		if ($portalsID[0]) {
			message("Move into portal number 0 ($portals{$portalsID[0]}{'pos'}{'x'},$portals{$portalsID[0]}{'pos'}{'y'})\n");
			main::ai_route($field{name}, $portals{$portalsID[0]}{'pos'}{'x'}, $portals{$portalsID[0]}{'pos'}{'y'}, attackOnRoute => 1, noSitAuto => 1);
		} else {
			error "No portals exist.\n";
		}
	} elsif (($arg1 eq "" || $arg2 eq "") && !$map) {
		error	"Syntax Error in function 'move' (Move Player)\n" .
			"Usage: move <x> <y> &| <map>\n";
	} elsif ($map eq "stop") {
		AI::clear(qw/move route mapRoute/);
		message "Stopped all movement\n", "success";
	} else {
		AI::clear(qw/move route mapRoute/);
		$map = $field{name} if ($map eq "");
		if ($maps_lut{"${map}.rsw"}) {
			my ($x, $y);
			if ($arg2 ne "") {
				message("Calculating route to: $maps_lut{$map.'.rsw'}($map): $arg1, $arg2\n", "route");
				$x = $arg1;
				$y = $arg2;
			} else {
				message("Calculating route to: $maps_lut{$map.'.rsw'}($map)\n", "route");
			}
			main::ai_route($map, $x, $y,
				attackOnRoute => 1,
				noSitAuto => 1,
				notifyUponArrival => 1);
		} elsif ($map =~ /^\d$/) {
			if ($portalsID[$map]) {
				message("Move into portal number $map ($portals{$portalsID[$map]}{'pos'}{'x'},$portals{$portalsID[$map]}{'pos'}{'y'})\n");
				main::ai_route($field{name}, $portals{$portalsID[$map]}{'pos'}{'x'}, $portals{$portalsID[$map]}{'pos'}{'y'}, attackOnRoute => 1, noSitAuto => 1);
			} else {
				error "No portals exist.\n";
			}
		} else {
			error "Map $map does not exist\n";
		}
	}
}

sub cmdNPCList {
	my (undef, $args) = @_;
	my @arg = parseArgs($args);
	my $msg = "-----------NPC List-----------\n" .
		"#    Name                         Coordinates   ID\n";

	if ($arg[0] =~ /^\d+$/) {
		my $i = $arg[0];
		if ($npcsID[$i]) {
			my $pos = "($npcs{$npcsID[$i]}{pos}{x}, $npcs{$npcsID[$i]}{pos}{y})";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<   @<<<<<<<<",
				[$i, $npcs{$npcsID[$i]}{name}, $pos, $npcs{$npcsID[$i]}{nameID}]);
			$msg .= "---------------------------------\n";
			message $msg, "info";

		} else {
			error	"Syntax Error in function 'nl' (List NPCs)\n" .
				"Usage: nl [<npc #>]\n";
		}
		return;
	}

	for (my $i = 0; $i < @npcsID; $i++) {
		next if ($npcsID[$i] eq "");
		my $pos = "($npcs{$npcsID[$i]}{pos}{x}, $npcs{$npcsID[$i]}{pos}{y})";
		$msg .= swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<   @<<<<<<<<",
			[$i, $npcs{$npcsID[$i]}{name}, $pos, $npcs{$npcsID[$i]}{nameID}]);
	}
	$msg .= "---------------------------------\n";
	message $msg, "list";
}

sub cmdOpenShop {
	main::openShop();
}

sub cmdParty {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w*)/;
	my ($arg2) = $args =~ /^\w* (\d+)\b/;

	if ($arg1 eq "" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
		error	"Error in function 'party' (Party Functions)\n" .
			"Can't list party - you're not in a party.\n";
	} elsif ($arg1 eq "") {
		message("----------Party-----------\n", "list");
		message($char->{'party'}{'name'}."\n", "list");
		message("#      Name                  Map                    Online    HP\n", "list");
		for (my $i = 0; $i < @partyUsersID; $i++) {
			next if ($partyUsersID[$i] eq "");
			my $coord_string = "";
			my $hp_string = "";
			my $name_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'name'};
			my $admin_string = ($char->{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) ? "(A)" : "";
			my $online_string;
			my $map_string;

			if ($partyUsersID[$i] eq $accountID) {
				$online_string = "Yes";
				($map_string) = $field{name};
				$coord_string = $char->{'pos'}{'x'}. ", ".$char->{'pos'}{'y'};
				$hp_string = $char->{'hp'}."/".$char->{'hp_max'}
						." (".int($char->{'hp'}/$char->{'hp_max'} * 100)
						."%)";
			} else {
				$online_string = ($char->{'party'}{'users'}{$partyUsersID[$i]}{'online'}) ? "Yes" : "No";
				($map_string) = $char->{'party'}{'users'}{$partyUsersID[$i]}{'map'} =~ /([\s\S]*)\.gat/;
				$coord_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'}
					. ", ".$char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'y'}
					if ($char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'} ne ""
						&& $char->{'party'}{'users'}{$partyUsersID[$i]}{'online'});
				$hp_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'hp'}."/".$char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'}
					." (".int($char->{'party'}{'users'}{$partyUsersID[$i]}{'hp'}/$char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} * 100)
					."%)" if ($char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} && $char->{'party'}{'users'}{$partyUsersID[$i]}{'online'});
			}
			message(swrite(
				"@< @<< @<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<< @<<       @<<<<<<<<<<<<<<<<<<",
				[$i, $admin_string, $name_string, $map_string, $coord_string, $online_string, $hp_string]),
				"list");
		}
		message("--------------------------\n", "list");

	} elsif ($arg1 eq "create") {
		my ($arg2) = $args =~ /^\w* ([\s\S]*)/;
		if ($arg2 eq "") {
			error	"Syntax Error in function 'party create' (Organize Party)\n" .
				"Usage: party create <party name>\n";
		} else {
			sendPartyOrganize(\$remote_socket, $arg2);
		}

	} elsif ($arg1 eq "join" && $arg2 ne "1" && $arg2 ne "0") {
		error	"Syntax Error in function 'party join' (Accept/Deny Party Join Request)\n" .
			"Usage: party join <flag>\n";
	} elsif ($arg1 eq "join" && $incomingParty{'ID'} eq "") {
		error	"Error in function 'party join' (Join/Request to Join Party)\n" .
			"Can't accept/deny party request - no incoming request.\n";
	} elsif ($arg1 eq "join") {
		sendPartyJoin(\$remote_socket, $incomingParty{'ID'}, $arg2);
		undef %incomingParty;

	} elsif ($arg1 eq "request" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
		error	"Error in function 'party request' (Request to Join Party)\n" .
			"Can't request a join - you're not in a party.\n";
	} elsif ($arg1 eq "request" && $playersID[$arg2] eq "") {
		error	"Error in function 'party request' (Request to Join Party)\n" .
			"Can't request to join party - player $arg2 does not exist.\n";
	} elsif ($arg1 eq "request") {
		sendPartyJoinRequest(\$remote_socket, $playersID[$arg2]);


	} elsif ($arg1 eq "leave" && (!$char->{'party'} || !%{$char->{'party'}} ) ) {
		error	"Error in function 'party leave' (Leave Party)\n" .
			"Can't leave party - you're not in a party.\n";
	} elsif ($arg1 eq "leave") {
		sendPartyLeave(\$remote_socket);


	} elsif ($arg1 eq "share" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
		error	"Error in function 'party share' (Set Party Share EXP)\n" .
			"Can't set share - you're not in a party.\n";
	} elsif ($arg1 eq "share" && $arg2 ne "1" && $arg2 ne "0") {
		error	"Syntax Error in function 'party share' (Set Party Share EXP)\n" .
			"Usage: party share <flag>\n";
	} elsif ($arg1 eq "share") {
		sendPartyShareEXP(\$remote_socket, $arg2);


	} elsif ($arg1 eq "kick" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
		error	"Error in function 'party kick' (Kick Party Member)\n" .
			"Can't kick member - you're not in a party.\n";
	} elsif ($arg1 eq "kick" && $arg2 eq "") {
		error	"Syntax Error in function 'party kick' (Kick Party Member)\n" .
			"Usage: party kick <party member #>\n";
	} elsif ($arg1 eq "kick" && $partyUsersID[$arg2] eq "") {
		error	"Error in function 'party kick' (Kick Party Member)\n" .
			"Can't kick member - member $arg2 doesn't exist.\n";
	} elsif ($arg1 eq "kick") {
		sendPartyKick(\$remote_socket, $partyUsersID[$arg2]
				,$char->{'party'}{'users'}{$partyUsersID[$arg2]}{'name'});
	} else {
		error	"Syntax Error in function 'party' (Party Management)\n" .
			"Usage: party [<create|join|request|leave|share|kick>]\n";
	}
}

sub cmdPartyChat {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'p' (Party Chat)\n" .
			"Usage: p <message>\n";
	} else {
		sendMessage(\$remote_socket, "p", $arg1);
	}
}

sub cmdPet {
	my (undef, $subcmd) = @_;
	if (!%pet) {
		error	"Error in function 'pet' (Pet Management)\n" .
			"You don't have a pet.";

	} elsif ($subcmd eq "s" || $subcmd eq "status") {
		message "-----------Pet Status-----------\n" .
			swrite(
			"Name: @<<<<<<<<<<<<<<<<<<<<<<< Accessory: @*",
			[$pet{name}, itemNameSimple($pet{accessory})]), "list";

	} elsif ($subcmd eq "p" || $subcmd eq "performance") {
		sendPetPerformance(\$remote_socket);

	} elsif ($subcmd eq "r" || $subcmd eq "return") {
		sendPetReturnToEgg(\$remote_socket);

	} elsif ($subcmd eq "u" || $subcmd eq "unequip") {
		sendPetUnequipItem(\$remote_socket);
	}
}

sub cmdPetList {
	message("-----------Pet List-----------\n" .
		"#    Type                     Name\n",
		"list");
	for (my $i = 0; $i < @petsID; $i++) {
		next if ($petsID[$i] eq "");
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $pets{$petsID[$i]}{'name'}, $pets{$petsID[$i]}{'name_given'}]),
			"list");
	}
	message("----------------------------------\n", "list");
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
		$msg .= $player->name." ($player->{binID})\n";
		$msg .= "Account ID: $player->{nameID} (Hex: $hex)\n";
		$msg .= "Party: $player->{party}{name}\n" if ($player->{party} && $player->{party}{name} ne '');
		$msg .= "Guild: $player->{guild}{name}\n" if ($player->{guild});
		$msg .= "Position: $pos->{x}, $pos->{y} ($directions_lut{$youToPlayer} of you: " . int($degYouToPlayer) . " degrees)\n";
		$msg .= swrite(
			"Level: @<<      Distance: @<<<<<<<<<<<<<<<<<",
			[$player->{lv}, $dist]);
		$msg .= swrite(
			"Sex: @<<<<<<    Class: @*",
			[$sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}}]);

		my $headTop = headgearName($player->{headgear}{top});
		my $headMid = headgearName($player->{headgear}{mid});
		my $headLow = headgearName($player->{headgear}{low});
		$msg .= "-------------------------------------------------\n";
		$msg .= swrite(
			"Body direction: @<<<<<<<<<<<<<<<<<<< Head direction:  @<<<<<<<<<<<<<<<<<<<",
			["$directions_lut{$body} ($body)", "$directions_lut{$head} ($head)"]);
		$msg .= "Weapon: ".main::itemName({nameID => $player->{weapon}})."\n";
		$msg .= "Shield: ".main::itemName({nameID => $player->{shield}})."\n";
		$msg .= "Shoes : ".main::itemName({nameID => $player->{shoes}})."\n";
		$msg .= swrite(
			"Upper headgear: @<<<<<<<<<<<<<<<<<<< Middle headgear: @<<<<<<<<<<<<<<<<<<<",
			[$headTop, $headMid]);
		$msg .= swrite(
			"Lower headgear: @<<<<<<<<<<<<<<<<<<< Hair color:      @<<<<<<<<<<<<<<<<<<<",
			[$headLow, "$haircolors{$player->{hair_color}} ($player->{hair_color})"]);

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
		"#    Name                                Sex   Lv  Job         Dist  Coord\n";
	for (my $i = 0; $i < @playersID; $i++) {
		my $player = $players{$playersID[$i]};
		next unless UNIVERSAL::isa($player, 'Actor');
		my ($name, $dist, $pos);
		$name = $player->name;
		if ($player->{guild} && %{$player->{guild}}) {
			$name .= " [$player->{guild}{name}]";
		}
		$dist = distance(\%{$char->{'pos_to'}}, \%{$players{$playersID[$i]}{'pos_to'}});
		$dist = sprintf("%.1f", $dist) if (index ($dist, '.') > -1);
		$pos = '(' . $players{$playersID[$i]}{'pos_to'}{'x'} . ', ' . $players{$playersID[$i]}{'pos_to'}{'y'} . ')';

		$msg .= swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @>> @<<<<<<<<<< @<<<< @<<<<<<<<<<",
			[$i, $name, $sex_lut{$players{$playersID[$i]}{'sex'}}, $players{$playersID[$i]}{lv}, $jobs_lut{$players{$playersID[$i]}{'jobID'}}, $dist, $pos]);
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
		if ($args[1] eq '') {
			error   "Syntax Error in function 'plugin load' (Load Plugin)\n" .
				"Usage: plugin load <filename|\"all\">\n";
			return;
		} elsif ($args[1] eq 'all') {
			Plugins::loadAll();
		} else {
			Plugins::load($args[1]);
		}

	} elsif ($args[0] eq 'unload') {
		if ($args[1] =~ /^\d+$/) {
			if ($Plugins::plugins[$args[1]]) {
				my $name = $Plugins::plugins[$args[1]]{name};
				Plugins::unload($name);
				message "Plugin $name unloaded.\n", "system";
			} else {
				error "'$args[1]' is not a valid plugin number.\n";
			}

		} elsif ($args[1] eq '') {
			error	"Syntax Error in function 'plugin unload' (Unload Plugin)\n" .
				"Usage: plugin unload <plugin name|plugin number#|\"all\">\n";
			return;

		} elsif ($args[1] eq 'all') {
			Plugins::unloadAll();

		} else {
			foreach my $plugin (@Plugins::plugins) {
				if ($plugin->{name} =~ /$args[1]/i) {
					my $name = $plugin->{name};
					Plugins::unload($name);
					message "Plugin $name unloaded.\n", "system";
				}
			}
		}

	} else {
		my $msg;
		$msg =	"--------------- Plugin command syntax ---------------\n" .
			"Command:                                              Description:\n" .
			" plugin                                                List loaded plugins\n" .
			" plugin load <filename>                                Load a plugin\n" .
			" plugin unload <plugin name|plugin number#|\"all\">      Unload a loaded plugin\n" .
			" plugin reload <plugin name|plugin number#|\"all\">      Reload a loaded plugin\n" .
			"-----------------------------------------------------\n";
		if ($args[0] eq 'help') {
			message($msg, "info");
		} else {
			error "Syntax Error in function 'plugin' (Control Plugins)\n";
			error($msg);
		}
	}
}

sub cmdPMList {
	message("-----------PM List-----------\n", "list");
	for (my $i = 1; $i <= @privMsgUsers; $i++) {
		message(swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $privMsgUsers[$i - 1]]),
			"list");
	}
	message("-----------------------------\n", "list");
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
		} elsif (!@privMsgUsers) {
			error	"Error in function 'pm' (Private Message)\n" .
				"You have not pm-ed anyone before\n";
		} else {
			sendMessage(\$remote_socket, "pm", $msg, $privMsgUsers[$user - 1]);
			$lastpm{msg} = $msg;
			$lastpm{user} = $privMsgUsers[$user - 1];
		}

	} else {
		if (!defined binFind(\@privMsgUsers, $user)) {
			push @privMsgUsers, $user;
		}
		sendMessage(\$remote_socket, "pm", $msg, $user);
		$lastpm{msg} = $msg;
		$lastpm{user} = $user;
	}
}

sub cmdPortalList {
	my (undef, $args) = @_;
	my ($arg) = parseArgs($args,1);
	if ($arg eq '') {
		message("-----------Portal List-----------\n" .
			"#    Name                                Coordinates\n",
			"list");
		for (my $i = 0; $i < @portalsID; $i++) {
			next if $portalsID[$i] eq "";
			my $portal = $portals{$portalsID[$i]};
			my $coords = "($portal->{pos}{x}, $portal->{pos}{y})";
			message(swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<",
				[$i, $portal->{name}, $coords]),
				"list");
		}
		message("---------------------------------\n", "list");
	} elsif ($arg eq 'recompile') {
		Settings::parseReload("portals");
		Misc::compilePortals() if Misc::compilePortals_check();
	}
}

sub cmdQuit {
	quit();
}

sub cmdReloadCode {
	my (undef, $args) = @_;
	if ($args ne "") {
		Modules::reload($args, 1);

	} else {
		Modules::reloadFile('functions.pl');
	}
}

sub cmdRelog {
	my (undef, $arg) = @_;
	if (!$arg || $arg =~ /^\d+$/) {
		relog($arg);
	} else {
		error	"Syntax Error in function 'relog' (Log out then log in.)\n" .
			"Usage: relog [delay]\n";
	}
}

sub cmdReload {
	my (undef, $args) = @_;
	if ($args eq '') {
		error	"Syntax Error in function 'reload' (Reload Configuration Files)\n" .
			"Usage: reload <name|\"all\">\n";

	} else {
		Settings::parseReload($args);
		Log::initLogFiles();
	}
}

sub cmdRepair {
	my (undef, $args) = @_;
	if ($args =~ /^\d+$/) {
		sendRepairItem($args);
	} else {
		error	"Syntax Error in function 'repair' (Repair player's items.)\n" .
			"Usage: repair [item number]\n";
	}
}

sub cmdRespawn {
	if ($char->{dead}) {
		sendRespawn(\$remote_socket);
	} else {
		main::useTeleport(2);
	}
}

sub cmdSell {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)$/;
	if ($arg1 eq "" && $talk{'buyOrSell'}) {
		sendGetSellList(\$remote_socket, $talk{'ID'});

	} elsif ($arg1 eq "") {
		error	"Syntax Error in function 'sell' (Sell Inventory Item)\n" .
			"Usage: sell <item #> [<amount>]\n";
	} elsif (!$char->{'inventory'}[$arg1] || !%{$char->{'inventory'}[$arg1]}) {
		error	"Error in function 'sell' (Sell Inventory Item)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} else {
		if (!$arg2 || $arg2 > $char->{inventory}[$arg1]{amount}) {
			$arg2 = $char->{inventory}[$arg1]{amount};
		}
		sendSell(\$remote_socket, $char->{inventory}[$arg1]{index}, $arg2);
	}
}

sub cmdSendRaw {
	my (undef, $args) = @_;
	sendRaw(\$remote_socket, $args);
}

sub cmdSit {
	if (!$ai_v{sitConfig}) {
		my %cfg;

		foreach (qw/attackAuto_party route_randomWalk teleportAuto_idle itemsGatherAuto/) {
			$cfg{$_} = $config{$_};
			$config{$_} = 0;
		}
		if ($config{attackAuto}) {
			$cfg{attackAuto} = $config{attackAuto};
			$config{attackAuto} = 1;
		}
		$ai_v{sitConfig} = \%cfg;
	}

	AI::clear("move", "route", "mapRoute");
	main::sit();
	$ai_v{sitAuto_forceStop} = 0;
}

sub cmdShopInfoSelf {
	if (!$shopstarted) {
		error("You do not have a shop open.\n");
		return;
	}
	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	message(center(" $shop{title} ", 79, '-')."\n", "list");
	message("#  Name                                     Type         Qty       Price   Sold\n", "list");

	my $priceAfterSale=0;
	my $i = 1;
	for my $item (@articles) {
		next unless $item;
		message(swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @>>> @>>>>>>>>>z @>>>>>",
			[$i++, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, formatNumber($item->{price}), $item->{sold}]),
			"list");
		$priceAfterSale += ($item->{quantity} * $item->{price});
	}
	message(('-'x79)."\n", "list");
	message("You have earned: " . formatNumber($shopEarned) . "z.\n", "list");
	message("Current zeny:    " . formatNumber($char->{zenny}) . "z.\n", "list");
	message("Maximum earned:  " . formatNumber($priceAfterSale) . "z.\n", "list");
	message("Maximum zeny:   " . formatNumber($priceAfterSale + $char->{zenny}) . "z.\n", "list");
}

sub cmdSpells {
	message "-----------Area Effects List-----------\n", "list";
	message "  # Type                 Source                   X   Y\n", "list";
	for my $ID (@spellsID) {
		my $spell = $spells{$ID};
		next unless $spell;

		message sprintf("%3d %-20s %-20s   %3d %3d\n", $spell->{binID}, getSpellName($spell->{type}), main::getActorName($spell->{sourceID}), $spell->{pos}{x}, $spell->{pos}{y}), "list";
	}
	message "---------------------------------------\n", "list";
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
			my $sp = $char->{skills}{$handle}{sp} || '';
			$msg .= swrite(
				"@>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>    @>>>",
				[$skill->id, $skill->name, $char->{skills}{$handle}{lv}, $sp]);
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
			my $description = $skillsDesc_lut{$skill->handle} || "Error: No description available.\n";
			message("===============Skill Description===============\n", "info");
			message("Skill: ".$skill->name."\n\n", "info");
			message($description, "info");
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
	my $char_skill = $char->{skills}{$skill->handle};
	my $lv = $args[2] || $char_skill->{lv} || 10;

	if (!defined $skill->id) {
		error	"Error in function 'sp' (Use Skill on Player)\n" .
			"'$args[0]' is not a valid skill.\n";
		return;
	}

	if ($args[1] ne "") {
		$target = Match::player($args[1], 1);
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

sub cmdStorage {
	my (undef, $args) = @_;

	my ($switch, $items) = split(' ', $args, 2);
	if (!$switch || $switch eq 'eq' || $switch eq 'u' || $switch eq 'nu') {
		cmdStorage_list($switch);
	} elsif ($switch eq 'add') {
		cmdStorage_add($items);
	} elsif ($switch eq 'addfromcart') {
		cmdStorage_addfromcart($items);
	} elsif ($switch eq 'get') {
		cmdStorage_get($items);
	} elsif ($switch eq 'gettocart') {
		cmdStorage_gettocart($items);
	} elsif ($switch eq 'close') {
		cmdStorage_close();
	} elsif ($switch eq 'log') {
		cmdStorage_log();
	} else {
		error <<"_";
Syntax Error in function 'storage' (Storage Functions)
Usage: storage [<eq|u|nu>]
       storage close
       storage add <inventory_item> [<amount>]
       storage addfromcart <cart_item> [<amount>]
       storage get <storage_item> [<amount>]
       storage gettocart <storage_item> [<amount>]
       storage log
_
	}
}

sub cmdStorage_list {
	if ($storage{opened}) {
		my $type = shift;
		message "$type\n";
		
		my @useable;
		my @equipment;
		my @non_useable;

		for (my $i = 0; $i < @storageID; $i++) {
			next if ($storageID[$i] eq "");
			my $item = $storage{$storageID[$i]};
			if ($item->{type} == 3 ||
			    $item->{type} == 6 ||
			    $item->{type} == 10) {
				push @non_useable, $item;
			} elsif ($item->{type} <= 2) {
				push @useable, $item;
			} else {
				my %eqp;
				$eqp{binID} = $i;
				$eqp{name} = $item->{name};
				$eqp{type} = $itemTypes_lut{$item->{type}};
				$eqp{identified} = " -- Not Identified" if !$item->{identified};
				push @equipment, \%eqp;
			}
		}

		my $msg = "-----------Storage-------------\n";
		
		if (!$type || $type eq 'eq') {
			$msg .= "-- Equipment --\n";
			foreach my $item (@equipment) {
				$msg .= sprintf("%-3d  %s (%s) %s\n", $item->{binID}, $item->{name}, $item->{type}, $item->{identified});
			}
		}
		
		if (!$type || $type eq 'nu') {
			$msg .= "-- Non-Usable --\n";
			for (my $i = 0; $i < @non_useable; $i++) {
				my $item = $non_useable[$i];
				my $binID = $item->{binID};
				my $display = $item->{name};
				$display .= " x $item->{amount}";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$binID, $display]);
			}
		}
		
		if (!$type || $type eq 'u') {
			$msg .= "-- Usable --\n";
			for (my $i = 0; $i < @useable; $i++) {
				my $item = $useable[$i];
				my $binID = $item->{binID};
				my $display = $item->{name};
				$display .= " x $item->{amount}";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$binID, $display]);
			}
		}
		
		$msg .= "-------------------------------\n";
		$msg .= "Capacity: $storage{items}/$storage{items_max}\n";
		$msg .= "-------------------------------\n";
		message($msg, "list");

	} else {
		error "No information about storage; it has not been opened before in this session\n";
	}
}

sub cmdStorage_add {
	my $items = shift;

	my ($name, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my $item = Match::inventoryItem($name);
	if (!$item) {
		error "Inventory Item '$name' does not exist.\n";
		return;
	}

	if ($item->{equipped}) {
		error "Inventory Item '$name' is equipped.\n";
		return;
	}

	if (!defined($amount) || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	sendStorageAdd($item->{index}, $amount);
}

sub cmdStorage_addfromcart {
	my $items = shift;

	my ($name, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my $item = Match::cartItem($name);
	if (!$item) {
		error "Cart Item '$name' does not exist.\n";
		return;
	}

	if (!defined($amount) || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	sendStorageAddFromCart($item->{index}, $amount);
}

sub cmdStorage_get {
	my $items = shift;

	my ($names, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my @names = split(',', $names);
	my @items;

	for my $name (@names) {
		if ($name =~ /^(\d+)\-(\d+)$/) {
			for my $i ($1..$2) {
				push @items, $storage{$storageID[$i]} if ($storage{$storageID[$i]});
			}

		} else {
			my $item = Match::storageItem($name);
			if (!$item) {
				error "Storage Item '$name' does not exist.\n";
				next;
			}
			push @items, $item;
		}
	}

	storageGet(\@items, $amount) if @items;
}

sub cmdStorage_gettocart {
	my $items = shift;

	my ($names, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my @names = split(',', $names);
	my @items;

	for my $name (@names) {
		if ($name =~ /^(\d+)\-(\d+)$/) {
			for my $i ($1..$2) {
				push @items, $storage{$storageID[$i]} if ($storage{$storageID[$i]});
			}

		} else {
			my $item = Match::storageItem($name);
			if (!$item) {
				error "Storage Item '$name' does not exist.\n";
				next;
			}
			push @items, $item;
		}
	}

	sendStorageGetToCart(\@items, $amount) if @items;
}

sub cmdStorage_close {
	sendStorageClose();
}

sub cmdStorage_log {
	if ($storage{opened}) {
		writeStorageLog(1);
	} else {
		error "No information about storage; it has not been opened before in this session\n";
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
		if ($targetNum !~ /^\d+$/) {
			error "$targetNum is not a number.\n";
			return;
		}
	}
	# Attempt to fill in unspecified skill level
	$lv ||= $char_skill->{lv};
	$lv ||= 10; # Server should fix excessively high skill level for us

	# Resolve target
	if ($switch eq 'sl') {
		if (!defined($x) || !defined($y)) {
			#error "(X, Y) coordinates not specified.\n";
			#return;
			my $pos = calcPosition($char);
			my @positions = calcRectArea($pos->{x}, $pos->{y}, int(rand 2) + 2);
			$pos = $positions[rand(@positions)];
			($x, $y) = ($pos->{x}, $pos->{y});
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

sub cmdStand {
	if ($ai_v{sitConfig}) {
		foreach my $key (keys %{$ai_v{sitConfig}}) {
			$config{$key} = $ai_v{sitConfig}{$key};
		}
		delete $ai_v{sitConfig};
	}
	$ai_v{sitAuto_forceStop} = 1;
	main::stand();
}

sub cmdStatAdd {
	# Add status point
	my (undef, $arg) = @_;
	if ($arg ne "str" && $arg ne "agi" && $arg ne "vit" && $arg ne "int"
	 && $arg ne "dex" && $arg ne "luk") {
		error	"Syntax Error in function 'stat_add' (Add Status Point)\n" .
			"Usage: stat_add <str | agi | vit | int | dex | luk>\n";

	} elsif ($char->{'$arg'} >= 99) {
		error	"Error in function 'stat_add' (Add Status Point)\n" .
			"You cannot add more stat points than 99\n";

	} elsif ($char->{"points_$arg"} > $char->{'points_free'}) {
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

		$char->{$arg} += 1;
		sendAddStatusPoint(\$remote_socket, $ID);
	}
}

sub cmdStats {
	my $msg = "-----------Char Stats-----------\n";
	$msg .= swrite(
		"Str: @<<+@<< #@< Atk:  @<<+@<< Def:  @<<+@<<",
		[$char->{'str'}, $char->{'str_bonus'}, $char->{'points_str'}, $char->{'attack'}, $char->{'attack_bonus'}, $char->{'def'}, $char->{'def_bonus'}],
		"Agi: @<<+@<< #@< Matk: @<<@@<< Mdef: @<<+@<<",
		[$char->{'agi'}, $char->{'agi_bonus'}, $char->{'points_agi'}, $char->{'attack_magic_min'}, '~', $char->{'attack_magic_max'}, $char->{'def_magic'}, $char->{'def_magic_bonus'}],
		"Vit: @<<+@<< #@< Hit:  @<<     Flee: @<<+@<<",
		[$char->{'vit'}, $char->{'vit_bonus'}, $char->{'points_vit'}, $char->{'hit'}, $char->{'flee'}, $char->{'flee_bonus'}],
		"Int: @<<+@<< #@< Critical: @<< Aspd: @<<",
		[$char->{'int'}, $char->{'int_bonus'}, $char->{'points_int'}, $char->{'critical'}, $char->{'attack_speed'}],
		"Dex: @<<+@<< #@< Status Points: @<<<",
		[$char->{'dex'}, $char->{'dex_bonus'}, $char->{'points_dex'}, $char->{'points_free'}],
		"Luk: @<<+@<< #@< Guild: @<<<<<<<<<<<<<<<<<<<<<",
		[$char->{'luk'}, $char->{'luk_bonus'}, $char->{'points_luk'}, $char->{guild} ? $char->{guild}{name} : 'None']);
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

	if ($char->{'exp_last'} > $char->{'exp'}) {
		$baseEXPKill = $char->{'exp_max_last'} - $char->{'exp_last'} + $char->{'exp'};
	} elsif ($char->{'exp_last'} == 0 && $char->{'exp_max_last'} == 0) {
		$baseEXPKill = 0;
	} else {
		$baseEXPKill = $char->{'exp'} - $char->{'exp_last'};
	}
	if ($char->{'exp_job_last'} > $char->{'exp_job'}) {
		$jobEXPKill = $char->{'exp_job_max_last'} - $char->{'exp_job_last'} + $char->{'exp_job'};
	} elsif ($char->{'exp_job_last'} == 0 && $char->{'exp_job_max_last'} == 0) {
		$jobEXPKill = 0;
	} else {
		$jobEXPKill = $char->{'exp_job'} - $char->{'exp_job_last'};
	}


	my ($hp_string, $sp_string, $base_string, $job_string, $weight_string, $job_name_string, $zeny_string);

	$hp_string = $char->{'hp'}."/".$char->{'hp_max'}." ("
		.int($char->{'hp'}/$char->{'hp_max'} * 100)
		."%)" if $char->{'hp_max'};
	$sp_string = $char->{'sp'}."/".$char->{'sp_max'}." ("
		.int($char->{'sp'}/$char->{'sp_max'} * 100)
		."%)" if $char->{'sp_max'};
	$base_string = formatNumber($char->{'exp'})."/".formatNumber($char->{'exp_max'})." /$baseEXPKill ("
			.sprintf("%.2f",$char->{'exp'}/$char->{'exp_max'} * 100)
			."%)"
			if $char->{'exp_max'};
	$job_string = formatNumber($char->{'exp_job'})."/".formatNumber($char->{'exp_job_max'})." /$jobEXPKill ("
			.sprintf("%.2f",$char->{'exp_job'}/$char->{'exp_job_max'} * 100)
			."%)"
			if $char->{'exp_job_max'};
	$weight_string = $char->{'weight'}."/".$char->{'weight_max'} .
			" (" . sprintf("%.1f", $char->{'weight'}/$char->{'weight_max'} * 100)
			. "%)"
			if $char->{'weight_max'};
	$job_name_string = "$jobs_lut{$char->{'jobID'}} $sex_lut{$char->{'sex'}}";
	$zeny_string = formatNumber($char->{'zenny'}) if (defined($char->{'zenny'}));

	$msg = "---------------------- Status ----------------------\n" .
		swrite(
		"@<<<<<<<<<<<<<<<<<<<<<<<      HP: @>>>>>>>>>>>>>>>>>",
		[$char->{'name'}, $hp_string],
		"@<<<<<<<<<<<<<<<<<<<<<<<      SP: @>>>>>>>>>>>>>>>>>",
		[$job_name_string, $sp_string],
		"Base: @<<    @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$char->{'lv'}, $base_string],
		"Job : @<<    @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>",
		[$char->{'lv_job'}, $job_string],
		"Zeny: @<<<<<<<<<<<<<<<<<  Weight: @>>>>>>>>>>>>>>>>>",
		[$zeny_string, $weight_string]);

	my $statuses = 'none';
	if (defined $char->{statuses} && %{$char->{statuses}}) {
		$statuses = join(", ", keys %{$char->{statuses}});
	}
	$msg .= "Statuses: $statuses\n";
	$msg .= "Spirits: $char->{spirits}\n" if (exists $char->{spirits});
	$msg .= "----------------------------------------------------\n";


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
	$msg .= "----------------------------------------------------\n";
	message($msg, "info");
}

sub cmdStore {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;
	if ($arg1 eq "" && !$talk{'buyOrSell'}) {
		message("----------Store List-----------\n", "list");
		message("#  Name                    Type           Price\n", "list");
		my $display;
		for (my $i = 0; $i < @storeList; $i++) {
			$display = $storeList[$i]{'name'};
			message(swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>>>>z",
				[$i, $display, $itemTypes_lut{$storeList[$i]{'type'}}, $storeList[$i]{'price'}]),
				"list");
		}
		message("-------------------------------\n", "list");
	} elsif ($arg1 eq "" && $talk{'buyOrSell'}) {
		sendGetStoreList(\$remote_socket, $talk{'ID'});

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && !$storeList[$arg2]) {
		error	"Error in function 'store desc' (Store Item Description)\n" .
			"Usage: Store item $arg2 does not exist\n";
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		printItemDesc($storeList[$arg2]{nameID});

	} else {
		error	"Syntax Error in function 'store' (Store Functions)\n" .
			"Usage: store [<desc>] [<store item #>]\n";
	}
}

sub cmdSwitchConf {
	my (undef, $filename) = @_;
	if (!defined $filename) {
		error	"Syntax Error in function 'switchconf' (Switch Configuration File)\n" .
			"Usage: switchconf <filename>\n";
	} elsif (! -f $filename) {
		error	"Syntax Error in function 'switchconf' (Switch Configuration File)\n" .
			"File $filename does not exist.\n";
	} else {
		switchConfigFile($filename);
		message "Switched config file to \"$filename\".\n", "system";
	}
}

sub cmdTake {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'take' (Take Item)\n" .
			"Usage: take <item #>\n";
	} elsif ($itemsID[$arg1] eq "") {
		error	"Error in function 'take' (Take Item)\n" .
			"Item $arg1 does not exist.\n";
	} else {
		main::take($itemsID[$arg1]);
	}
}

sub cmdTalk {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 =~ /^\d+$/ && $npcsID[$arg1] eq "") {
		error	"Error in function 'talk' (Talk to NPC)\n" .
			"NPC $arg1 does not exist\n";
	} elsif ($arg1 =~ /^\d+$/) {
		sendTalk(\$remote_socket, $npcsID[$arg1]);

	} elsif (($arg1 eq "resp" || $arg1 eq "num" || $arg1 eq "text") && !%talk) {
		error	"Error in function 'talk resp' (Respond to NPC)\n" .
			"You are not talking to any NPC.\n";

	} elsif ($arg1 eq "resp" && $arg2 eq "") {
		my $display = $talk{name};
		message("----------Responses-----------\n", "list");
		message("NPC: $display\n", "list");
		message("#  Response\n", "list");
		for (my $i = 0; $i < @{$talk{'responses'}}; $i++) {
			message(sprintf(
				"%2s %s\n",
				$i, $talk{'responses'}[$i]),
				"list");
		}
		message("-------------------------------\n", "list");

	} elsif ($arg1 eq "resp" && $arg2 ne "" && $talk{'responses'}[$arg2] eq "") {
		error	"Error in function 'talk resp' (Respond to NPC)\n" .
			"Response $arg2 does not exist.\n";

	} elsif ($arg1 eq "resp" && $arg2 ne "") {
		if ($talk{'responses'}[$arg2] eq "Cancel Chat") {
			$arg2 = 255;
		} else {
			$arg2 += 1;
		}
		sendTalkResponse(\$remote_socket, $talk{'ID'}, $arg2);

	} elsif ($arg1 eq "num" && $arg2 eq "") {
		error "Error in function 'talk num' (Respond to NPC)\n" .
			"You must specify a number.\n";

	} elsif ($arg1 eq "num" && !($arg2 =~ /^\d+$/)) {
		error "Error in function 'talk num' (Respond to NPC)\n" .
			"$arg2 is not a valid number.\n";

	} elsif ($arg1 eq "num" && $arg2 =~ /^\d+$/) {
		sendTalkNumber(\$remote_socket, $talk{'ID'}, $arg2);

	} elsif ($arg1 eq "text") {
		my ($arg2) = $args =~ /^\w+ (.*)/;
		if ($arg2 eq "") {
			error "Error in function 'talk text' (Respond to NPC)\n" .
				"You must specify a string.\n";
		} else {
			sendTalkText(\$remote_socket, $talk{'ID'}, $arg2);
		}

	} elsif ($arg1 eq "cont" && !%talk) {
		error	"Error in function 'talk cont' (Continue Talking to NPC)\n" .
			"You are not talking to any NPC.\n";

	} elsif ($arg1 eq "cont") {
		sendTalkContinue(\$remote_socket, $talk{'ID'});

	} elsif ($arg1 eq "no") {
		if (!%talk) {
			error "You are not talking to any NPC.\n";
		} else {
			sendTalkCancel(\$remote_socket, $talk{'ID'});
		}

	} else {
		error	"Syntax Error in function 'talk' (Talk to NPC)\n" .
			"Usage: talk <NPC # | cont | resp | num> [<response #>|<number #>]\n";
	}
}

sub cmdTalkNPC {
	my (undef, $args) = @_;

	my ($x, $y, $sequence) = $args =~ /^(\d+) (\d+) (.+)$/;
	unless (defined $x) {
		error "Syntax Error in function 'talknpc' (Talk to an NPC)\n".
			"Usage: talknpc <x> <y> <sequence>\n";
		return;
	}

	message "Talking to NPC at ($x, $y) using sequence: $sequence\n";
	main::ai_talkNPC($x, $y, $sequence);
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

sub cmdTeleport {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d)/;
	$arg1 = 1 unless $arg1;
	main::useTeleport($arg1);
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
	my ($arg1) = $args;

	if ($arg1 eq "") {
		error "You must specify an item to unequip.\n";
		return;
	}

	my $item = Match::inventoryItem($arg1);

	if (!$item) {
		error "You don't have $arg1.\n";
		return;
	}

	if (!$item->{equipped} && $item->{type} != 10) {
		error	"Error in function 'unequip' (Unequip Inventory Item)\n" .
			"Inventory Item $arg1 is not equipped.\n";
		return;
	}
	sendUnequip(\$remote_socket, $item->{index});
}

sub cmdUseItemOnMonster {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;

	if ($arg1 eq "" || $arg2 eq "") {
		error	"Syntax Error in function 'im' (Use Item on Monster)\n" .
			"Usage: im <item #> <monster #>\n";
	} elsif (!$char->{'inventory'}[$arg1] || !%{$char->{'inventory'}[$arg1]}) {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($char->{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} elsif ($monstersID[$arg2] eq "") {
		error	"Error in function 'im' (Use Item on Monster)\n" .
			"Monster $arg2 does not exist.\n";
	} else {
		$char->{'inventory'}[$arg1]->use($monstersID[$arg2]);
	}
}

sub cmdUseItemOnPlayer {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;
	if ($arg1 eq "" || $arg2 eq "") {
		error	"Syntax Error in function 'ip' (Use Item on Player)\n" .
			"Usage: ip <item #> <player #>\n";
	} elsif (!$char->{'inventory'}[$arg1] || !%{$char->{'inventory'}[$arg1]}) {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($char->{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} elsif ($playersID[$arg2] eq "") {
		error	"Error in function 'ip' (Use Item on Player)\n" .
			"Player $arg2 does not exist.\n";
	} else {
		$char->{'inventory'}[$arg1]->use($playersID[$arg2]);
	}
}

sub cmdUseItemOnSelf {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	if ($arg1 eq "") {
		error	"Syntax Error in function 'is' (Use Item on Yourself)\n" .
			"Usage: is <item #>\n";
	} elsif (!$char->{'inventory'}[$arg1] || !%{$char->{'inventory'}[$arg1]}) {
		error	"Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item $arg1 does not exist.\n";
	} elsif ($char->{'inventory'}[$arg1]{'type'} > 2) {
		error	"Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item $arg1 is not of type Usable.\n";
	} else {
		$char->{'inventory'}[$arg1]->use();
	}
}

sub cmdVender {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\d\w]+)/;
	my ($arg2) = $args =~ /^[\d\w]+ (\d+)/;
	my ($arg3) = $args =~ /^[\d\w]+ \d+ (\d+)/;
	if ($arg1 eq "") {
		error	"Error in function 'vender' (Vender Shop)\n" .
			"Usage: vender <vender # | end> [<item #> <amount>]\n";
	} elsif ($arg1 eq "end") {
		undef @venderItemList;
		undef $venderID;
	} elsif ($venderListsID[$arg1] eq "") {
		error	"Error in function 'vender' (Vender Shop)\n" .
			"Vender $arg1 does not exist.\n";
	} elsif ($arg2 eq "") {
		sendEnteringVender(\$remote_socket, $venderListsID[$arg1]);
	} elsif ($venderListsID[$arg1] ne $venderID) {
		error	"Error in function 'vender' (Vender Shop)\n" .
			"Vender ID is wrong.\n";
	} else {
		if ($arg3 <= 0) {
			$arg3 = 1;
		}
		sendBuyVender(\$remote_socket, $venderID, $arg2, $arg3);
	}
}

sub cmdVenderList {
	message("-----------Vender List-----------\n" .
		"#   Title                                Coords     Owner\n",
		"list");
	for (my $i = 0; $i < @venderListsID; $i++) {
		next if ($venderListsID[$i] eq "");
		my $player = Actor::get($venderListsID[$i]);
		# autovivifies $obj->{pos_to} but it doesnt matter
		message(sprintf(
			"%3d %-36s (%3s, %3s) %-20s\n",
			$i, $venderLists{$venderListsID[$i]}{'title'},
			$player->{pos_to}{x} || '?', $player->{pos_to}{y} || '?', $player->name),
			"list");
	}
	message("----------------------------------\n", "list");
}

sub cmdVerbose {
	if ($config{'verbose'}) {
		configModify("verbose", 0);
	} else {
		configModify("verbose", 1);
	}
}

sub cmdVersion {
	message "$Settings::versionText";
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

sub cmdWeight {
	my (undef, $itemWeight) = @_;

	$itemWeight ||= 1;

	if ($itemWeight !~ /^\d$/) {
		error	"Error in function 'weight' (Inventory Weight Info)\n" .
			"Usage: weight [item weight]\n";
		return;
	}

	my $itemString = $itemWeight == 1 ? '' : "*$itemWeight";
	message "Weight: $char->{weight}/$char->{weight_max} (".
		sprintf("%.02f", $char->weight_percent)."%)\n", "list";
	if ($char->weight_percent < 90) {
		if ($char->weight_percent < 50) {
			my $weight_50 = int((int($char->{weight_max}*0.5) - $char->{weight}) / $itemWeight);
			message "You can carry $weight_50$itemString before 50% overweight.\n", "list";
		} else {
			message "You are 50% overweight.\n", "list";
		}
		my $weight_90 = int((int($char->{weight_max}*0.9) - $char->{weight}) / $itemWeight);
		message "You can carry $weight_90$itemString before 90% overweight.\n", "list";
	} else {
		message "You are 90% overweight.\n";
	}
}

sub cmdWhere {
	my $pos = calcPosition($char);
	message("Location $maps_lut{$field{name}.'.rsw'} ($field{name}) : $pos->{x}, $pos->{y}\n", "info");
}

sub cmdWho {
	sendWho(\$remote_socket);
}

sub cmdWhoAmI {
	my $GID = unpack("L1", $charID);
	my $AID = unpack("L1", $accountID);
	message "Name:    $char->{name} (Level $char->{lv} $sex_lut{$char->{sex}} $jobs_lut{$char->{jobID}})\n", "list";
	message "Char ID: $GID\n", "list";
	message "Acct ID: $AID\n", "list";
}

sub cmdKill {
	my (undef, $ID) = @_;

	my $target = $playersID[$ID];
	unless ($target) {
		error "Player $ID does not exist.\n";
		return;
	}

	attack($target);
}

return 1;
