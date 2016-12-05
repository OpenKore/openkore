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
use utf8;

use Modules 'register';
use Globals;
use Log qw(message debug error warning);
use Misc;
use Network;
use Network::Send ();
use Settings;
use Plugins;
use Skill;
use Utils;
use Utils::Exceptions;
use AI;
use Task;
use Task::ErrorReport;
use Match;
use Translation;
use I18N qw(stringToBytes);
use Network::PacketParser qw(STATUS_STR STATUS_AGI STATUS_VIT STATUS_INT STATUS_DEX STATUS_LUK);

our %handlers;
our %completions;

undef %handlers;
undef %completions;

our %customCommands;


sub initHandlers {
	%handlers = (
	a					=> \&cmdAttack,
	ai					=> \&cmdAI,
	aiv					=> \&cmdAIv,
	al					=> \&cmdShopInfoSelf,
	arrowcraft			=> \&cmdArrowCraft,
	as					=> \&cmdAttackStop,
	autobuy				=> \&cmdAutoBuy,
	autosell			=> \&cmdAutoSell,
	autostorage			=> \&cmdAutoStorage,
	auth				=> \&cmdAuthorize,
	bangbang			=> \&cmdBangBang,
	bingbing			=> \&cmdBingBing,
	bg					=> \&cmdChat,
	bl					=> \&cmdBuyerList,
	booking				=> \&cmdBooking,
	buy					=> \&cmdBuy,
	buyer				=> \&cmdBuyer,
	bs					=> \&cmdBuyShopInfoSelf,
	c					=> \&cmdChat,
	card				=> \&cmdCard,
	cart				=> \&cmdCart,
	cash				=> \&cmdCash,
	charselect			=> \&cmdCharSelect,
	chat				=> \&cmdChatRoom,
	chist				=> \&cmdChist,
	cil					=> \&cmdItemLogClear,
	cl					=> \&cmdChatRoom,
	clearlog			=> \&cmdChatLogClear,
	closeshop			=> \&cmdCloseShop,
	closebuyshop		=> \&cmdCloseBuyShop,
	conf				=> \&cmdConf,
	connect				=> \&cmdConnect,
	damage				=> \&cmdDamage,
	dead				=> \&cmdDeadTime,
	deal				=> \&cmdDeal,
	debug				=> \&cmdDebug,
	dl					=> \&cmdDealList,
	doridori			=> \&cmdDoriDori,
	drop				=> \&cmdDrop,
	dump				=> \&cmdDump,
	dumpnow				=> \&cmdDumpNow,
	e					=> \&cmdEmotion,
	eq					=> \&cmdEquip,
	eval				=> \&cmdEval,
	exp					=> \&cmdExp,
	falcon				=> \&cmdFalcon,
	follow				=> \&cmdFollow,
	friend				=> \&cmdFriend,
	homun				=> \&cmdSlave,
	merc				=> \&cmdSlave,
	g					=> \&cmdChat,
	getplayerinfo		=> \&cmdGetPlayerInfo,
	getcharname			=> \&cmdGetCharacterName,
	# GM Commands - Start
	gmb					=> \&cmdGmb,
	gmbb				=> \&cmdGmb,
	gmnb				=> \&cmdGmb,
	gmlb				=> \&cmdGmb,
	gmlbb				=> \&cmdGmb,
	gmlnb				=> \&cmdGmb,
	gmmapmove			=> \&cmdGmmapmove,
	gmcreate			=> \&cmdGmcreate,
	gmhide				=> \&cmdGmhide,
	gmwarpto			=> \&cmdGmwarpto,
	gmsummon			=> \&cmdGmsummon,
	gmrecall			=> \&cmdGmrecall,
	gmremove			=> \&cmdGmremove,
	gmdc				=> \&cmdGmdc,
	gmresetskill		=> \&cmdGmresetskill,
	gmresetstate		=> \&cmdGmresetstate,
	gmmute				=> \&cmdGmmute,
	gmunmute			=> \&cmdGmunmute,
	gmkillall			=> \&cmdGmkillall,
	# GM Commands - End
	guild				=> \&cmdGuild,
	help				=> \&cmdHelp,
	i					=> \&cmdInventory,
	identify			=> \&cmdIdentify,
	ignore				=> \&cmdIgnore,
	ihist				=> \&cmdIhist,
	il					=> \&cmdItemList,
	im					=> \&cmdUseItemOnMonster,
	ip					=> \&cmdUseItemOnPlayer,
	is					=> \&cmdUseItemOnSelf,
	kill				=> \&cmdKill,
	look				=> \&cmdLook,
	lookp				=> \&cmdLookPlayer,
	memo				=> \&cmdMemo,
	ml					=> \&cmdMonsterList,
	move				=> \&cmdMove,
	nl					=> \&cmdNPCList,
	openshop			=> \&cmdOpenShop,
	p					=> \&cmdChat,
	party				=> \&cmdParty,
	pecopeco			=> \&cmdPecopeco,
	pet					=> \&cmdPet,
	petl				=> \&cmdPetList,
	pl					=> \&cmdPlayerList,
	plugin				=> \&cmdPlugin,
	pm					=> \&cmdPrivateMessage,
	pml					=> \&cmdPMList,
	portals				=> \&cmdPortalList,
	quit				=> \&cmdQuit,
	rc					=> \&cmdReloadCode,
	rc2					=> \&cmdReloadCode2,
	reload				=> \&cmdReload,
	relog				=> \&cmdRelog,
	repair				=> \&cmdRepair,
	respawn				=> \&cmdRespawn,
	s					=> \&cmdStatus,
	sell				=> \&cmdSell,
	send				=> \&cmdSendRaw,
	sit					=> \&cmdSit,
	skills				=> \&cmdSkills,
	sll					=> \&cmdSlaveList,
	spells				=> \&cmdSpells,
	storage				=> \&cmdStorage,
	store				=> \&cmdStore,
	sl					=> \&cmdUseSkill,
	sm					=> \&cmdUseSkill,
	sp					=> \&cmdUseSkill,
	ss					=> \&cmdUseSkill,
	ssl					=> \&cmdUseSkill,
	ssp					=> \&cmdUseSkill,
	st					=> \&cmdStats,
	stand				=> \&cmdStand,
	stat_add			=> \&cmdStatAdd,
	switchconf			=> \&cmdSwitchConf,
	take				=> \&cmdTake,
	talk				=> \&cmdTalk,
	talknpc				=> \&cmdTalkNPC,
	tank				=> \&cmdTank,
	tele				=> \&cmdTeleport,
	testshop			=> \&cmdTestShop,
	timeout				=> \&cmdTimeout,
	top10				=> \&cmdTop10,
	uneq				=> \&cmdUnequip,
	vender				=> \&cmdVender,
	verbose				=> \&cmdVerbose,
	version				=> \&cmdVersion,
	vl					=> \&cmdVenderList,
	vs					=> \&cmdShopInfoSelf,
	warp				=> \&cmdWarp,
	weight				=> \&cmdWeight,
	where				=> \&cmdWhere,
	who					=> \&cmdWho,
	whoami				=> \&cmdWhoAmI,

	m					=> \&cmdMail,	# see commands
	ms					=> \&cmdMail,	# send
	mi					=> \&cmdMail,	# inbox
	mo					=> \&cmdMail,	# open
	md					=> \&cmdMail,	# delete
	mw					=> \&cmdMail,	# window
	mr					=> \&cmdMail,	# return
	ma					=> \&cmdMail,	# attachement

	au					=> \&cmdAuction,	# see commands
	aua					=> \&cmdAuction,	# add item
	aur					=> \&cmdAuction,	# remove item
	auc					=> \&cmdAuction,	# create auction
	aue					=> \&cmdAuction,	# auction end
	aus					=> \&cmdAuction,	# search auction
	aub					=> \&cmdAuction,	# make bid
	aui					=> \&cmdAuction,	# info on buy/sell
	aud					=> \&cmdAuction,	# delete auction

	quest				=> \&cmdQuest,
	showeq				=> \&cmdShowEquip,
	cook				=> \&cmdCooking,
	refine				=> \&cmdWeaponRefine,

	north				=> \&cmdManualMove,
	south				=> \&cmdManualMove,
	east				=> \&cmdManualMove,
	west				=> \&cmdManualMove,
	northeast			=> \&cmdManualMove,
	northwest			=> \&cmdManualMove,
	southeast			=> \&cmdManualMove,
	southwest			=> \&cmdManualMove,
	captcha			   => \&cmdAnswerCaptcha
	);
}

sub initCompletions {
	%completions = ();
}

### CATEGORY: Functions

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
	initHandlers() if (!%handlers);

	# Resolve command aliases
	my ($switch, $args) = split(/ +/, $input, 2);
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
	}

	# Remove trailing spaces from input
	$input =~ s/^\s+//;

	my @commands = split(';;', $input);
	# Loop through all of the commands...
	foreach my $command (@commands) {
		my ($switch, $args) = split(/ +/, $command, 2);
		my $handler;
		$handler = $customCommands{$switch}{callback} if ($customCommands{$switch});
		$handler = $handlers{$switch} if (!$handler && $handlers{$switch});

		if (($switch eq 'pause') && (!$cmdQueue) && (!$AI_forcedOff) && ($net->getState() == Network::IN_GAME)) {
			$cmdQueue = 1;
			$cmdQueueStartTime = time;
			if ($args > 0) {
				$cmdQueueTime = $args;
			} else {
				$cmdQueueTime = 1;
			}
			debug "Command queueing started\n", "ai";
		} elsif (($switch eq 'pause') && ($cmdQueue > 0)) {
			push(@cmdQueueList, $command);
		} elsif (($switch eq 'pause') && (($AI_forcedOff == 1) || ($net->getState() != Network::IN_GAME))) {
			error T("Cannot use pause command now.\n");
		} elsif (($handler) && ($cmdQueue > 0) && (!defined binFind(\@cmdQueuePriority,$switch) && ($command ne 'cart') && ($command ne 'storage'))) {
			push(@cmdQueueList, $command);
		} elsif ($handler) {
			my %params;
			$params{switch} = $switch;
			$params{args} = $args;
			Plugins::callHook("Commands::run/pre", \%params);
			$handler->($switch, $args);
			Plugins::callHook("Commands::run/post", \%params);

		} else {
			my %params = ( switch => $switch, input => $command );
			Plugins::callHook('Command_post', \%params);
			if (!$params{return}) {
				error TF("Unknown command '%s'. Please read the documentation for a list of commands.\n"
						."http://openkore.com/index.php/Category:Console_Command\n", $switch);
			} else {
				return $params{return}
			}
		}
	}
	return 1;
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
	return ($last_arg_pos, \@matches);
}


##################################
### CATEGORY: Commands


sub cmdAI {
	my (undef, $args) = @_;
	$args =~ s/ .*//;

	# Clear AI
	@cmdQueueList = ();
	$cmdQueue = 0;
	if ($args eq 'clear') {
		AI::clear;
		$taskManager->stopAll() if defined $taskManager;
		delete $ai_v{temp};
		if ($char) {
			undef $char->{dead};
		}
		message T("AI sequences cleared\n"), "success";

	} elsif ($args eq 'print') {
		# Display detailed info about current AI sequence
		my $msg = center(T(" AI Sequence "), 50, '-') ."\n";
		my $index = 0;
		foreach (@ai_seq) {
			$msg .= ("$index: $_ " . dumpHash(\%{$ai_seq_args[$index]}) . "\n\n");
			$index++;
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";

	} elsif ($args eq 'ai_v') {
		message dumpHash(\%ai_v) . "\n", "list";

	} elsif ($args eq 'on' || $args eq 'auto') {
		# Set AI to auto mode
		if ($AI == AI::AUTO) {
			message T("AI is already set to auto mode\n"), "success";
		} else {
			$AI = AI::AUTO;
			undef $AI_forcedOff;
			message T("AI set to auto mode\n"), "success";
		}
	} elsif ($args eq 'manual') {
		# Set AI to manual mode
		if ($AI == AI::MANUAL) {
			message T("AI is already set to manual mode\n"), "success";
		} else {
			$AI = AI::MANUAL;
			$AI_forcedOff = 1;
			message T("AI set to manual mode\n"), "success";
		}
	} elsif ($args eq 'off') {
		# Turn AI off
		if ($AI == AI::OFF) {
			message T("AI is already off\n"), "success";
		} else {
			$AI = AI::OFF;
			$AI_forcedOff = 1;
			message T("AI turned off\n"), "success";
		}

	} elsif ($args eq '') {
		# Toggle AI
		if ($AI == AI::AUTO) {
			undef $AI;
			$AI_forcedOff = 1;
			message T("AI turned off\n"), "success";
		} elsif ($AI == AI::OFF) {
			$AI = AI::MANUAL;
			$AI_forcedOff = 1;
			message T("AI set to manual mode\n"), "success";
		} elsif ($AI == AI::MANUAL) {
			$AI = AI::AUTO;
			undef $AI_forcedOff;
			message T("AI set to auto mode\n"), "success";
		}

	} else {
		error T("Syntax Error in function 'ai' (AI Commands)\n" .
			"Usage: ai [ clear | print | ai_v | auto | manual | off ]\n");
	}
}

sub cmdAIv {
	# Display current AI sequences
	my $on;
	if ($AI == AI::OFF) {
		message TF("ai_seq (off) = %s\n", "@ai_seq"), "list";
	} elsif ($AI == AI::MANUAL) {
		message TF("ai_seq (manual) = %s\n", "@ai_seq"), "list";
	} elsif ($AI == AI::AUTO) {
		message TF("ai_seq (auto) = %s\n", "@ai_seq"), "list";
	}
	message T("solution\n"), "list" if (AI::args->{'solution'});
	message TF("Active tasks: %s\n", (defined $taskManager) ? $taskManager->activeTasksString() : ''), "info";
	message TF("Inactive tasks: %s\n", (defined $taskManager) ? $taskManager->inactiveTasksString() : ''), "info";
}

sub cmdArrowCraft {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	#print "-$arg1-\n";
	if ($arg1 eq "") {
		if (@arrowCraftID) {
			my $msg = center(T(" Item To Craft "), 50, '-') ."\n";
			for (my $i = 0; $i < @arrowCraftID; $i++) {
				next if ($arrowCraftID[$i] eq "");
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$i, $char->inventory->get($arrowCraftID[$i])->{name}]);
			}
			$msg .= ('-'x50) . "\n";
			message $msg, "list";
		} else {
			error T("Error in function 'arrowcraft' (Create Arrows)\n" .
			 	"Type 'arrowcraft use' to get list.\n");
		}
	} elsif ($arg1 eq "use") {
		if (defined binFind(\@skillsID, 'AC_MAKINGARROW')) {
			main::ai_skillUse('AC_MAKINGARROW', 1, 0, 0, $accountID);
		} else {
			error T("Error in function 'arrowcraft' (Create Arrows)\n" .
				"You don't have Arrow Making Skill.\n");
		}
	} elsif ($arg1 eq "forceuse") {
		my $item = $char->inventory->get($arg2);
		if ($item) {
			$messageSender->sendArrowCraft($item->{nameID});
		} else {
			error TF("Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item %s in your inventory.\n", $arg2);
		}
	} else {
		if ($arrowCraftID[$arg1] ne "") {
			$messageSender->sendArrowCraft($char->inventory->get($arrowCraftID[$arg1])->{nameID});
		} else {
			error T("Error in function 'arrowcraft' (Create Arrows)\n" .
				"Usage: arrowcraft [<identify #>]\n" .
				"Type 'arrowcraft use' to get list.\n");
		}
	}
}

sub cmdAttack {
	my (undef, $arg1) = @_;
	if ($arg1 =~ /^\d+$/) {
		if ($monstersID[$arg1] eq "") {
			error TF("Error in function 'a' (Attack Monster)\n" .
				"Monster %s does not exist.\n", $arg1);
		} else {
			main::attack($monstersID[$arg1]);
		}
	} elsif ($arg1 eq "no") {
		configModify("attackAuto", 1);

	} elsif ($arg1 eq "yes") {
		configModify("attackAuto", 2);

	} else {
		error T("Syntax Error in function 'a' (Attack Monster)\n" .
			"Usage: attack <monster # | no | yes >\n");
	}
}

sub cmdAttackStop {
	my $index = AI::findAction("attack");
	if ($index ne "") {
		my $args = AI::args($index);
		my $monster = Actor::get($args->{ID});
		if ($monster) {
			$monster->{ignore} = 1;
			$char->sendAttackStop;
			message TF("Stopped attacking %s (%s)\n",
				$monster->{name}, $monster->{binID}), "success";
			AI::clear("attack");
		}
	}
}

sub cmdAuthorize {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^([\s\S]*) ([\s\S]*?)$/;
	if ($arg1 eq "" || ($arg2 ne "1" && $arg2 ne "0")) {
		error T("Syntax Error in function 'auth' (Overall Authorize)\n" .
			"Usage: auth <username> <flag>\n");
	} else {
		auth($arg1, $arg2);
	}
}

sub cmdAutoBuy {
	message T("Initiating auto-buy.\n");
	AI::queue("buyAuto");
}

sub cmdAutoSell {
	my (undef, $arg) = @_;
	if ($arg eq 'simulate' || $arg eq 'test' || $arg eq 'debug') {
		# Simulate list of items to sell
		my @sellItems;
		my $msg = center(T(" Items to sell (simulation) "), 50, '-') ."\n".
				T("Amount  Item Name\n");
		foreach my $item (@{$char->inventory->getItems()}) {
			next if ($item->{unsellable});
			my $control = items_control($item->{name});
			if ($control->{'sell'} && $item->{'amount'} > $control->{keep}) {
				my %obj;
				$obj{index} = $item->{index};
				$obj{amount} = $item->{amount} - $control->{keep};
				my $item_name = $item->{name};
				$item_name .= ' (if unequipped)' if ($item->{equipped});
				$msg .= swrite(
						"@>>> x  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
						[$item->{amount}, $item_name]);
			}
		}
		$msg .= ('-'x50) . "\n";
		message ($msg, "list");
	} elsif (!$arg) {
		message T("Initiating auto-sell.\n");
		AI::queue("sellAuto");
	}
}

sub cmdAutoStorage {
	message T("Initiating auto-storage.\n");
	AI::queue("storageAuto");
}

sub cmdBangBang {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $bodydir = $char->{look}{body} - 1;
	$bodydir = 7 if ($bodydir == -1);
	$messageSender->sendLook($bodydir, $char->{look}{head});
}

sub cmdBingBing {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $bodydir = ($char->{look}{body} + 1) % 8;
	$messageSender->sendLook($bodydir, $char->{look}{head});
}

sub cmdBuy {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;
	my @bulkitemlist;

	foreach (split /\,/, $args) {
		my($index,$amount) = $_ =~ /^\s*(\d+)\s*(\d*)\s*$/;

		if ($index eq "") {
			error T("Syntax Error in function 'buy' (Buy Store Item)\n" .
				"Usage: buy <item #> [<amount>][, <item #> [<amount>]]...\n");
			return;

		} elsif ($storeList[$index] eq "") {
			error TF("Error in function 'buy' (Buy Store Item)\n" .
				"Store Item %s does not exist.\n", $index);
			return;

		} elsif ($amount eq "" || $amount <= 0) {
			$amount = 1;
		}

		my $itemID = $storeList[$index]{nameID};
		push (@bulkitemlist,{itemID  => $itemID, amount => $amount});
	}

	if (grep(defined, @bulkitemlist)) {
		$messageSender->sendBuyBulk(\@bulkitemlist);
	}
}

sub cmdCard {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $input) = @_;
	my ($arg1) = $input =~ /^(\w+)/;
	my ($arg2) = $input =~ /^\w+ (\d+)/;
	my ($arg3) = $input =~ /^\w+ \d+ (\d+)/;

	if ($arg1 eq "mergecancel") {
		if (!defined $messageSender) {
			error T("Error in function 'bingbing' (Change look direction)\n" .
				"Can't use command while not connected to server.\n");
		} elsif ($cardMergeIndex ne "") {
			undef $cardMergeIndex;
			$messageSender->sendCardMerge(-1, -1);
			message T("Cancelling card merge.\n");
		} else {
			error T("Error in function 'card mergecancel' (Cancel a card merge request)\n" .
				"You are not currently in a card merge session.\n");
		}
	} elsif ($arg1 eq "mergelist") {
		# FIXME: if your items change order or are used, this list will be wrong
		if (@cardMergeItemsID) {
			my $msg = center(T(" Card Merge Candidates "), 50, '-') ."\n";
			foreach my $card (@cardMergeItemsID) {
				next if $card eq "" || !$char->inventory->get($card);
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$card, $char->inventory->get($card)]);
			}
			$msg .= ('-'x50) . "\n";
			message $msg, "list";
		} else {
			error T("Error in function 'card mergelist' (List availible card merge items)\n" .
				"You are not currently in a card merge session.\n");
		}
	} elsif ($arg1 eq "merge") {
		if ($arg2 =~ /^\d+$/) {
			my $found = binFind(\@cardMergeItemsID, $arg2);
			if (defined $found) {
				$messageSender->sendCardMerge($char->inventory->get($cardMergeIndex)->{index},
					$char->inventory->get($arg2)->{index});
			} else {
				if ($cardMergeIndex ne "") {
					error TF("Error in function 'card merge' (Finalize card merging onto item)\n" .
						"There is no item %s in the card mergelist.\n", $arg2);
				} else {
					error T("Error in function 'card merge' (Finalize card merging onto item)\n" .
						"You are not currently in a card merge session.\n");
				}
			}
		} else {
			error T("Syntax Error in function 'card merge' (Finalize card merging onto item)\n" .
				"Usage: card merge <item number>\n" .
				"<item number> - Merge item number. Type 'card mergelist' to get number.\n");
		}
	} elsif ($arg1 eq "use") {
		if ($arg2 =~ /^\d+$/) {
			if ($char->inventory->get($arg2)) {
				$cardMergeIndex = $arg2;
				$messageSender->sendCardMergeRequest($char->inventory->get($cardMergeIndex)->{index});
				message TF("Sending merge list request for %s...\n",
					$char->inventory->get($cardMergeIndex)->{name});
			} else {
				error TF("Error in function 'card use' (Request list of items for merging with card)\n" .
					"Card %s does not exist.\n", $arg2);
			}
		} else {
			error T("Syntax Error in function 'card use' (Request list of items for merging with card)\n" .
				"Usage: card use <item number>\n" .
				"<item number> - Card inventory number. Type 'i' to get number.\n");
		}
	} elsif ($arg1 eq "list") {
		my $msg = center(T(" Card List "), 50, '-') ."\n";
		foreach my $item (@{$char->inventory->getItems()}) {
			if ($item->mergeable) {
				my $display = "$item->{name} x $item->{amount}";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$item->{invIndex}, $display]);
			}
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";
	} elsif ($arg1 eq "forceuse") {
		if (!$char->inventory->get($arg2)) {
			error TF("Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item %s in your inventory.\n", $arg2);
		} elsif (!$char->inventory->get($arg3)) {
			error TF("Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item %s in your inventory.\n"), $arg3;
		} else {
			$messageSender->sendCardMerge($char->inventory->get($arg2)->{index},
				$char->inventory->get($arg3)->{index});
		}
	} else {
		error T("Syntax Error in function 'card' (Card Compounding)\n" .
			"Usage: card <use|mergelist|mergecancel|merge>\n");
	}
}

sub cmdCart {
	my (undef, $input) = @_;
	my ($arg1, $arg2) = split(' ', $input, 2);

	if (!$char->cartActive) {
		error T("Error in function 'cart' (Cart Management)\n" .
			"You do not have a cart.\n");
		return;

	} elsif (!$char->cart->isReady()) {
		error T("Cart inventory is not available.\n");
		return;

	} elsif ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "nu" || $arg1 eq "u") {
		cmdCart_list($arg1);
		
	} elsif ($arg1 eq "desc") {
		cmdCart_desc($arg2);
		
	} elsif (($arg1 eq "add" || $arg1 eq "get" || $arg1 eq "release" || $arg1 eq "change") && (!$net || $net->getState() != Network::IN_GAME)) {
		error TF("You must be logged in the game to use this command '%s'\n", 'cart ' .$arg1);
			return;

	} elsif ($arg1 eq "add") {
		cmdCart_add($arg2);

	} elsif ($arg1 eq "get") {
		cmdCart_get($arg2);

	} elsif ($arg1 eq "release") {
		$messageSender->sendCompanionRelease();
		message T("Trying to released the cart...\n");
	
	} elsif ($arg1 eq "change") {
		if ($arg2 =~ m/^[1-5]$/) {
			$messageSender->sendChangeCart($arg2);
		} else {
			error T("Usage: cart change <1-5>\n");
		}
	
	} else {
		error TF("Error in function 'cart'\n" .
			"Command '%s' is not a known command.\n", $arg1);
	}
}

sub cmdCart_desc {
	my $arg = shift;
	if (!($arg =~ /\d+/)) {
		error TF("Syntax Error in function 'cart desc' (Show Cart Item Description)\n" .
			"'%s' is not a valid cart item number.\n", $arg);
	} else {
		my $item = $char->cart->get($arg);
		if (!$item) {
			error TF("Error in function 'cart desc' (Show Cart Item Description)\n" .
				"Cart Item %s does not exist.\n", $arg);
		} else {
			printItemDesc($item->{nameID});
		}
	}
}

sub cmdCart_list {
	my $type = shift;
	message "$type\n";

	my @useable;
	my @equipment;
	my @non_useable;
	my ($i, $display, $index);
	
	foreach my $item (@{$char->cart->getItems()}) {
		if ($item->usable) {
			push @useable, $item->{invIndex};
		} elsif ($item->equippable) {
			my %eqp;
			$eqp{index} = $item->{index};
			$eqp{binID} = $item->{invIndex};
			$eqp{name} = $item->{name};
			$eqp{amount} = $item->{amount};
			$eqp{identified} = " -- " . T("Not Identified") if !$item->{identified};
			$eqp{type} = $itemTypes_lut{$item->{type}};
			push @equipment, \%eqp;
		} else {
			push @non_useable, $item->{invIndex};
		}
	}

	my $msg = center(T(" Cart "), 50, '-') ."\n".
			T("#  Name\n");

	if (!$type || $type eq 'u') {
		$msg .= T("-- Usable --\n");
		for (my $i = 0; $i < @useable; $i++) {
			$index = $useable[$i];
			my $item = $char->cart->get($index);
			$display = $item->{name};
			$display .= " x $item->{amount}";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$index, $display]);
		}
	}

	if (!$type || $type eq 'eq') {
		$msg .= T("\n-- Equipment --\n");
		foreach my $item (@equipment) {
			## altered to allow for Arrows/Ammo which will are stackable equip.
			$display = sprintf("%-3d  %s (%s)", $item->{binID}, $item->{name}, $item->{type});
			$display .= " x $item->{amount}" if $item->{amount} > 1;
			$display .= $item->{identified};
			$msg .= sprintf("%-57s\n", $display);
		}
	}

	if (!$type || $type eq 'nu') {
		$msg .= T("\n-- Non-Usable --\n");
		for (my $i = 0; $i < @non_useable; $i++) {
			$index = $non_useable[$i];
			my $item = $char->cart->get($index);
			$display = $item->{name};
			$display .= " x $item->{amount}";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$index, $display]);
		}
	}

	$msg .= TF("\nCapacity: %d/%d  Weight: %d/%d\n",
			$char->cart->items, $char->cart->items_max, $char->cart->weight, $char->cart->weight_max).
			('-'x50) . "\n";
	message $msg, "list";
}

sub cmdCart_add {
	my ($name) = @_;

	if (!defined $name) {
		error T("Syntax Error in function 'cart add' (Add Item to Cart)\n" .
			"Usage: cart add <item>\n");
		return;
	}

	my $amount;
	if ($name =~ /^(.*?) (\d+)$/) {
		$name = $1;
		$amount = $2;
	}

	my $item = Match::inventoryItem($name);

	if (!$item) {
		error TF("Error in function 'cart add' (Add Item to Cart)\n" .
			"Inventory Item %s does not exist.\n", $name);
		return;
	}

	if (!$amount || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	$messageSender->sendCartAdd($item->{index}, $amount);
}

sub cmdCart_get {
	my ($name) = @_;

	if (!defined $name) {
		error T("Syntax Error in function 'cart get' (Get Item from Cart)\n" .
			"Usage: cart get <cart item>\n");
		return;
	}

	my $amount;
	if ($name =~ /^(.*?) (\d+)$/) {
		$name = $1;
		$amount = $2;
	}

	my $item = Match::cartItem($name);
	if (!$item) {
		error TF("Error in function 'cart get' (Get Item from Cart)\n" .
			"Cart Item %s does not exist.\n", $name);
		return;
	}

	if (!$amount || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	$messageSender->sendCartGet($item->{index}, $amount);
}

sub cmdCash {
	my (undef, $args) = @_;
	my ($sub_cmd, $arg) = split(/\s+/,$args, 2);
	if ($sub_cmd eq 'buy') {
		if ($arg =~ /^\s+$/) {
			error T("Syntax Error in function 'cash' (Cash shop)\n" .
				"Usage: cash <buy|points>\n");
			return;
		}
		my $int_arg;
		#my $r_arg;
		if ($arg =~ s/(\d+)$//) { # ending with number
			$int_arg = $1;
		}
		$arg =~ s/^[\t\s]*//;	# Remove leading tabs and whitespace
		$arg =~ s/\s+$//g;	# Remove trailing whitespace

		my $amount;
		my $item;

		if ($arg && $int_arg) { # recebi item (nao sei se é ID ou nome) e quantidade
			$amount = $int_arg;
			$item = $arg;
		} elsif (!$arg && $int_arg) { # recebi itemID, sem quantidade
			$amount = 1;
			$item = $int_arg;
		} elsif ($arg && !$int_arg) { # recebi nome do item, sem quantidade
			$amount = 1;
			$item = $arg;
		} else {
			error TF("Error in function 'cash buy': item %s not found or shop list is not ready yet.", itemNameSimple($item));
			return;
		}

		if ($item !~ /^\d+$/) {
			# transform itemName into itemID
			$item = itemNameToID($item);
			if (!$item) {
				error TF("Error in function 'cash buy': invalid item name or tables needs to be updated \n");
				return;
			}
		}

		$messageSender->sendCashShopOpen() unless (defined $cashShop{points});

		for (my $tab = 0; $tab < @{$cashShop{list}}; $tab++) {
			foreach my $itemloop (@{$cashShop{list}[$tab]}) {
				if ($itemloop->{item_id} == $item) {
					# found item! ... but do we have the money?
					unless ((defined $cashShop{points}) && ($itemloop->{price} > $cashShop{points}->{cash})) {
						# buy item
						message TF("Buying %s from cash shop \n", itemNameSimple($itemloop->{item_id}));
						$messageSender->sendCashBuy($itemloop->{item_id}, $amount, $tab);
						return;
					} else {
						error TF("Not enough cash to buy item %s (%sC), we have %sC\n", itemNameSimple($itemloop->{item_id}), formatNumber($itemloop->{price}), formatNumber($cashShop{points}->{cash}));
						return;
					}
				}
			} 
		}

		error TF("Error in function 'cash buy': item %s not found or shop list is not ready yet.", itemNameSimple($item));
		return;

	} elsif ($sub_cmd eq 'points') {
		if (defined $cashShop{points}) {
			message TF("Cash Points: %sC - Kafra Points: %sC\n", formatNumber($cashShop{points}->{cash}), formatNumber($cashShop{points}->{kafra}));
		} else {
			$messageSender->sendCashShopOpen();
		}
	} elsif ($sub_cmd eq 'list') {
		my %cashitem_tab = (
			0 => T('New'),
			1 => T('Popular'),
			2 => T('Limited'),
			3 => T('Rental'),
			4 => T('Perpetuity'),
			5 => T('Buff'),
			6 => T('Recovery'),
			7 => T('Etc'),
		);

		my $msg;
		for (my $tabcode = 0; $tabcode < @{$cashShop{list}}; $tabcode++) {
			$msg .= center(T(' Tab: ') . $cashitem_tab{$tabcode} . ' ', 50, '-') ."\n".
			T ("ID      Item Name                            Price\n");
			foreach my $itemloop (@{$cashShop{list}[$tabcode]}) {
				$msg .= swrite(
					"@<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>C",
					[$itemloop->{item_id}, itemNameSimple($itemloop->{item_id}), formatNumber($itemloop->{price})]);
			}
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";

	} else {
		error T("Syntax Error in function 'cash' (Cash shop)\n" .
			"Usage: cash <buy|points|list>\n");
	}
}

sub cmdCharSelect {
	my (undef,$arg1) = @_;
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	if($arg1 =~ "1"){
		configModify("char",'');
	}
	Log::initLogFiles();
	$messageSender->sendRestart(1);
}

# chat, party chat, guild chat, battlegrounds chat
sub cmdChat {
	my ($command, $arg1) = @_;

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", $command);
		return;
	}

	if ($arg1 eq "") {
		error TF("Syntax Error in function '%1\$s' (Chat)\n" .
			"Usage: %1\$s <message>\n", $command);
	} else {
		sendMessage($messageSender, $command, $arg1);
	}
}

sub cmdChatLogClear {
	chatLog_clear();
	message T("Chat log cleared.\n"), "success";
}

sub cmdChatRoom {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($command, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;

	if($command eq 'cl') {
		$arg1 = 'list';
	}

	if ($arg1 eq "bestow") {
		my ($arg2) = $args =~ /^\w+ (\d+)/;

		if ($currentChatRoom eq "") {
			error T("Error in function 'chat bestow' (Bestow Admin in Chat)\n" .
				"You are not in a Chat Room.\n");
		} elsif ($arg2 eq "") {
			error T("Syntax Error in function 'chat bestow' (Bestow Admin in Chat)\n" .
				"Usage: chat bestow <user #>\n");
		} elsif ($currentChatRoomUsers[$arg2] eq "") {
			error TF("Error in function 'chat bestow' (Bestow Admin in Chat)\n" .
				"Chat Room User %s doesn't exist; type 'chat info' to see the list of users\n", $arg2);
		} else {
			$messageSender->sendChatRoomBestow($currentChatRoomUsers[$arg2]);
		}

	} elsif ($arg1 eq "modify") {
		my ($title) = $args =~ /^\w+ \"([\s\S]*?)\"/;
		my ($users) = $args =~ /^\w+ \"[\s\S]*?\" (\d+)/;
		my ($public) = $args =~ /^\w+ \"[\s\S]*?\" \d+ (\d+)/;
		my ($password) = $args =~ /^\w+ \"[\s\S]*?\" \d+ \d+ ([\s\S]+)/;

		if ($title eq "") {
			error T("Syntax Error in function 'chatmod' (Modify Chat Room)\n" .
				"Usage: chat modify \"<title>\" [<limit #> <public flag> <password>]\n");
		} else {
			if ($users eq "") {
				$users = 20;
			}
			if ($public eq "") {
				$public = 1;
			}
			$messageSender->sendChatRoomChange($title, $users, $public, $password);
		}

	} elsif ($arg1 eq "kick") {
		my ($arg2) = $args =~ /^\w+ (\d+)/;

		if ($currentChatRoom eq "") {
			error T("Error in function 'chat kick' (Kick from Chat)\n" .
				"You are not in a Chat Room.\n");
		} elsif ($arg2 eq "") {
			error T("Syntax Error in function 'chat kick' (Kick from Chat)\n" .
				"Usage: chat kick <user #>\n");
		} elsif ($currentChatRoomUsers[$arg2] eq "") {
			error TF("Error in function 'chat kick' (Kick from Chat)\n" .
				"Chat Room User %s doesn't exist\n", $arg2);
		} else {
			$messageSender->sendChatRoomKick($currentChatRoomUsers[$arg2]);
		}

	} elsif ($arg1 eq "join") {
		my ($arg2) = $args =~ /^\w+ (\d+)/;
		my ($arg3) = $args =~ /^\w+ \d+ (\w+)/;

		if ($arg2 eq "") {
			error T("Syntax Error in function 'chat join' (Join Chat Room)\n" .
				"Usage: chat join <chat room #> [<password>]\n");
		} elsif ($currentChatRoom ne "") {
			error T("Error in function 'chat join' (Join Chat Room)\n" .
				"You are already in a chat room.\n");
		} elsif ($chatRoomsID[$arg2] eq "") {
			error TF("Error in function 'chat join' (Join Chat Room)\n" .
				"Chat Room %s does not exist.\n", $arg2);
		} else {
			$messageSender->sendChatRoomJoin($chatRoomsID[$arg2], $arg3);
		}

	} elsif ($arg1 eq "leave") {
		if ($currentChatRoom eq "") {
			error T("Error in function 'chat leave' (Leave Chat Room)\n" .
				"You are not in a Chat Room.\n");
		} else {
			$messageSender->sendChatRoomLeave();
		}

	} elsif ($arg1 eq "create") {
		my ($title) = $args =~ /^\w+ \"([\s\S]*?)\"/;
		my ($users) = $args =~ /^\w+ \"[\s\S]*?\" (\d+)/;
		my ($public) = $args =~ /^\w+ \"[\s\S]*?\" \d+ (\d+)/;
		my ($password) = $args =~ /^\w+ \"[\s\S]*?\" \d+ \d+ ([\s\S]+)/;

		if ($title eq "") {
			error T("Syntax Error in function 'chat create' (Create Chat Room)\n" .
				"Usage: chat create \"<title>\" [<limit #> <public flag> <password>]\n");
		} elsif ($currentChatRoom ne "") {
			error T("Error in function 'chat create' (Create Chat Room)\n" .
				"You are already in a chat room.\n");
		} else {
			if ($users eq "") {
				$users = 20;
			}
			if ($public eq "") {
				$public = 1;
			}
			$title = ($config{chatTitleOversize}) ? $title : substr($title,0,36);
			$messageSender->sendChatRoomCreate($title, $users, $public, $password);
			%createdChatRoom = ();
			$createdChatRoom{title} = $title;
			$createdChatRoom{ownerID} = $accountID;
			$createdChatRoom{limit} = $users;
			$createdChatRoom{public} = $public;
			$createdChatRoom{num_users} = 1;
			$createdChatRoom{users}{$char->{name}} = 2;
		}

	} elsif ($arg1 eq "list") {
		my $msg = center(T(" Chat Room List "), 79, '-') ."\n".
			T("#   Title                                  Owner                Users   Type\n");
		for (my $i = 0; $i < @chatRoomsID; $i++) {
			next if (!defined $chatRoomsID[$i]);
			my $room = $chatRooms{$chatRoomsID[$i]};
			my $owner_string = Actor::get($room->{ownerID})->name;
			my $public_string = ($room->{public}) ? "Public" : "Private";
			my $limit_string = $room->{num_users} . "/" . $room->{limit};
			$msg .= swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<<<<",
				[$i, $room->{title}, $owner_string, $limit_string, $public_string]);
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";
	} elsif ($arg1 eq "info") {
		if ($currentChatRoom eq "") {
			error T("There is no chat room info - you are not in a chat room\n");
		} else {
			my $msg = center(T(" Chat Room Info "), 56, '-') ."\n".
			 T("Title                                  Users   Pub/Priv\n");
			my $public_string = ($chatRooms{$currentChatRoom}{'public'}) ? "Public" : "Private";
			my $limit_string = $chatRooms{$currentChatRoom}{'num_users'}."/".$chatRooms{$currentChatRoom}{'limit'};
			$msg .= swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<<<<<<<",
				[$chatRooms{$currentChatRoom}{'title'}, $limit_string, $public_string]);
			# Translation Comment: Users in chat room
			$msg .=  T("-- Users --\n");
			for (my $i = 0; $i < @currentChatRoomUsers; $i++) {
				next if ($currentChatRoomUsers[$i] eq "");
				my $user_string = $currentChatRoomUsers[$i];
				my $admin_string = ($chatRooms{$currentChatRoom}{'users'}{$currentChatRoomUsers[$i]} > 1) ? "(Admin)" : "";
				$msg .= swrite(
					"@<< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<",
					[$i, $user_string, $admin_string]);
			}
			$msg .= ('-'x56) . "\n";
			message $msg, "list";
		}
	} else {
		error T("Syntax Error in function 'chat' (Chat room management)\n" .
			"Usage: chat <create|modify|join|kick|leave|info|list|bestow>\n");
	}

}

sub cmdChist {
	# Display chat history
	my (undef, $args) = @_;
	$args = 5 if ($args eq "");
	if (!($args =~ /^\d+$/)) {
		error T("Syntax Error in function 'chist' (Show Chat History)\n" .
			"Usage: chist [<number of entries #>]\n");
	} elsif (open(CHAT, "<:utf8", $Settings::chat_log_file)) {
		my @chat = <CHAT>;
		close(CHAT);
		my $msg = center(T(" Chat History "), 79, '-') ."\n";
		my $i = @chat - $args;
		$i = 0 if ($i < 0);
		for (; $i < @chat; $i++) {
			$msg .= $chat[$i];
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";
	} else {
		error TF("Unable to open %s\n", $Settings::chat_log_file);
	}
}

sub cmdCloseShop {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	main::closeShop();
}

sub cmdCloseBuyShop {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	$messageSender->sendCloseBuyShop();
	message T("Buying shop closed.\n", "BuyShop");
}

sub cmdConf {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^(\S+)\s*(.*?)\s*$/;

	# Basic Support for "label" in blocks. Thanks to "piroJOKE"
	if ($arg1 =~ /\./) {
		$arg1 =~ s/\.+/\./; # Filter Out Unnececary dot's
		my ($label, $param) = split /\./, $arg1, 2; # Split the label form parameter
		# This line is used for debug
		# message TF("Params label '%s' param '%s' arg1 '%s' arg2 '%s'\n", $label, $param, $arg1, $arg2), "info";
		foreach (%config) {
			if ($_ =~ /_\d+_label/){ # we only need those blocks witch have labels
				if ($config{$_} eq $label) {
					my ($real_key, undef) = split /_label/, $_, 2;
					# "<label>.block" param support. Thanks to "vit"
					if ($param ne "block") {
						$real_key .= "_";
						$real_key .= $param;
					}
					$arg1 = $real_key;
					last;
				};
			};
		};
	};

	if ($arg1 eq "") {
		error T("Syntax Error in function 'conf' (Change a Configuration Key)\n" .
			"Usage: conf <variable> [<value>|none]\n");

	} elsif ($arg1 =~ /\*/) {
		my $pat = $arg1;
		$pat =~ s/\*/.*/gso;
		my @keys = grep {/$pat/i} sort keys %config;
		error TF( "Config variables matching %s do not exist\n", $arg1 ) if !@keys;
		message TF( "Config '%s' is %s\n", $_, defined $config{$_} ? $config{$_} : 'not set' ), "info" foreach @keys;

	} elsif (!exists $config{$arg1}) {
		error TF("Config variable %s doesn't exist\n", $arg1);

	} elsif ($arg2 eq "") {
		my $value = $config{$arg1};
		if ($arg1 =~ /password/i) {
			message TF("Config '%s' is not displayed\n", $arg1), "info";
		} else {
			if (defined $value) {
				message TF("Config '%s' is %s\n", $arg1, $value), "info";
			} else {
				message TF("Config '%s' is not set\n", $arg1), "info";
			}
		}

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

sub cmdConnect {
	$Settings::no_connect = 0;
}

sub cmdDamage {
	my (undef, $args) = @_;

	if ($args eq "") {
		my $total = 0;
		message T("Damage Taken Report:\n"), "list";
		message(sprintf("%-40s %-20s %-10s\n", 'Name', 'Skill', 'Damage'), "list");
		for my $monsterName (sort keys %damageTaken) {
			my $monsterHref = $damageTaken{$monsterName};
			for my $skillName (sort keys %{$monsterHref}) {
				message sprintf("%-40s %-20s %10d\n", $monsterName, $skillName, $monsterHref->{$skillName}), "list";
				$total += $monsterHref->{$skillName};
			}
		}
		message TF("Total Damage Taken: %s\n", $total), "list";
		message T("End of report.\n"), "list";

	} elsif ($args eq "reset") {
		undef %damageTaken;
		message T("Damage Taken Report reset.\n"), "success";
	} else {
		error T("Syntax error in function 'damage' (Damage Report)\n" .
			"Usage: damage [reset]\n");
	}
}

sub cmdDeal {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;
	my @arg = parseArgs( $args );

	if ( $arg[0] && $arg[0] !~ /^(\d+|no|add)$/ ) {
		my ( $partner ) = grep { $_->name eq $arg[0] } @{ $playersList->getItems };
		if ( !$partner ) {
			error TF( "Unknown player [%s]. Player not nearby?\n", $arg[0] );
			return;
		}
		$arg[0] = $partner->{binID};
	}

	if (%currentDeal && $arg[0] =~ /\d+/) {
		error T("Error in function 'deal' (Deal a Player)\n" .
			"You are already in a deal\n");
	} elsif (%incomingDeal && $arg[0] =~ /\d+/) {
		error T("Error in function 'deal' (Deal a Player)\n" .
			"You must first cancel the incoming deal\n");
	} elsif ($arg[0] =~ /\d+/ && !$playersID[$arg[0]]) {
		error TF("Error in function 'deal' (Deal a Player)\n" .
			"Player %s does not exist\n", $arg[0]);
	} elsif ($arg[0] =~ /\d+/) {
		my $ID = $playersID[$arg[0]];
		my $player = Actor::get($ID);
		message TF("Attempting to deal %s\n", $player);
		deal($player);

	} elsif ($arg[0] eq "no" && !%incomingDeal && !%outgoingDeal && !%currentDeal) {
		error T("Error in function 'deal' (Deal a Player)\n" .
			"There is no incoming/current deal to cancel\n");
	} elsif ($arg[0] eq "no" && (%incomingDeal || %outgoingDeal)) {
		$messageSender->sendDealReply(4);
	} elsif ($arg[0] eq "no" && %currentDeal) {
		$messageSender->sendCurrentDealCancel();

	} elsif ($arg[0] eq "" && !%incomingDeal && !%currentDeal) {
		error T("Error in function 'deal' (Deal a Player)\n" .
			"There is no deal to accept\n");
	} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && !$currentDeal{'other_finalize'}) {
		error TF("Error in function 'deal' (Deal a Player)\n" .
			"Cannot make the trade - %s has not finalized\n", $currentDeal{'name'});
	} elsif ($arg[0] eq "" && $currentDeal{'final'}) {
		error T("Error in function 'deal' (Deal a Player)\n" .
			"You already accepted the final deal\n");
	} elsif ($arg[0] eq "" && %incomingDeal) {
		$messageSender->sendDealReply(3);
	} elsif ($arg[0] eq "" && $currentDeal{'you_finalize'} && $currentDeal{'other_finalize'}) {
		$messageSender->sendDealTrade();
		$currentDeal{'final'} = 1;
		message T("You accepted the final Deal\n"), "deal";
	} elsif ($arg[0] eq "" && %currentDeal) {
		$messageSender->sendDealAddItem(0, $currentDeal{'you_zeny'});
		$messageSender->sendDealFinalize();

	} elsif ($arg[0] eq "add" && !%currentDeal) {
		error T("Error in function 'deal_add' (Add Item to Deal)\n" .
			"No deal in progress\n");
	} elsif ($arg[0] eq "add" && $currentDeal{'you_finalize'}) {
		error T("Error in function 'deal_add' (Add Item to Deal)\n" .
			"Can't add any Items - You already finalized the deal\n");
	} elsif ($arg[0] eq "add" && $arg[1] =~ /\d+/ && !$char->inventory->get($arg[1])) {
		error TF("Error in function 'deal_add' (Add Item to Deal)\n" .
			"Inventory Item %s does not exist.\n", $arg[1]);
	} elsif ($arg[0] eq "add" && $arg[2] && $arg[2] !~ /\d+/) {
		error T("Error in function 'deal_add' (Add Item to Deal)\n" .
			"Amount must either be a number, or not specified.\n");
	} elsif ($arg[0] eq "add" && $arg[1] =~ /^(\d+(?:-\d+)?,?)+$/) {
		my $max_items = $config{dealMaxItems} || 10;
		my @items = Actor::Item::getMultiple($arg[1]);
		my $n = $currentDeal{you_items};
		if ($n >= $max_items) {
			error T("You can't add any more items to the deal\n"), "deal";
		}
		while (@items && $n < $max_items) {
			my $item = shift @items;
			next if $item->{equipped};
			my $amount = $item->{amount};
			if (!$arg[2] || $arg[2] > $amount) {
				$arg[2] = $amount;
			}
			dealAddItem($item, $arg[2]);
			$n++;
		}
	} elsif ($arg[0] eq "add" && $arg[1] eq "z") {
		if (!$arg[2] && !($arg[2] eq "0") || $arg[2] > $char->{'zeny'}) {
			$arg[2] = $char->{'zeny'};
		}
		$currentDeal{'you_zeny'} = $arg[2];
		message TF("You put forward %sz to Deal\n", formatNumber($arg[2])), "deal";

	} elsif ($arg[0] eq "add" && $arg[1] !~ /^\d+$/) {
		my $max_items = $config{dealMaxItems} || 10;
		if ($currentDeal{you_items} > $max_items) {
			error T("You can't add any more items to the deal\n"), "deal";
		}
		my $items = [ grep { $_ && lc( $_->{name} ) eq lc( $arg[1] ) && !$_->{equipped} } @{ $char->inventory->getItems } ];
		my $n = $currentDeal{you_items};
		my $a = $arg[2] || 1;
		my $c = 0;
		while ($n < $max_items && $c < $a && @$items) {
			my $item = shift @$items;
			my $amount = $arg[2] && $a - $c < $item->{amount} ? $a - $c : $item->{amount};
			dealAddItem($item, $amount);
			$n++;
			$c += $amount;
		}
	} else {
		error T("Syntax Error in function 'deal' (Deal a player)\n" .
			"Usage: deal [<Player # | no | add>] [<item #>] [<amount>]\n");
	}
}

sub cmdDealList {
	if (!%currentDeal) {
		error T("There is no deal list - You are not in a deal\n");

	} else {
		my $msg = center(T(" Current Deal "), 66, '-') ."\n";
		my $other_string = $currentDeal{'name'};
		my $you_string = T("You");
		if ($currentDeal{'other_finalize'}) {
			$other_string .= T(" - Finalized");
		}
		if ($currentDeal{'you_finalize'}) {
			$you_string .= T(" - Finalized");
		}

		$msg .= swrite(
			"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
			[$you_string, $other_string]);

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
					: T("Unknown ").$currentDealYou[$i];
				$display .= " x $currentDeal{'you'}{$currentDealYou[$i]}{'amount'}";
			} else {
				$display = "";
			}
			if ($i < @currentDealOther) {
				$display2 = ($items_lut{$currentDealOther[$i]} ne "")
					? $items_lut{$currentDealOther[$i]}
					: T("Unknown ").$currentDealOther[$i];
				$display2 .= " x $currentDeal{'other'}{$currentDealOther[$i]}{'amount'}";
			} else {
				$display2 = "";
			}

			$msg .= swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<   @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$display, $display2]);
		}
		$you_string = ($currentDeal{'you_zeny'} ne "") ? $currentDeal{'you_zeny'} : 0;
		$other_string = ($currentDeal{'other_zeny'} ne "") ? $currentDeal{'other_zeny'} : 0;

		$msg .= swrite(
				T("zeny: \@<<<<<<<<<<<<<<<<<<<<<<<   zeny: \@<<<<<<<<<<<<<<<<<<<<<<<"),
				[formatNumber($you_string), formatNumber($other_string)]);

		$msg .= ('-'x66) . "\n";
		message $msg, "list";
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
		my $connected = $net && "server=".($net->serverAlive ? "yes" : "no").
			",client=".($net->clientAlive ? "yes" : "no");
		my $time = $packetParser && sprintf("%.2f", time - $packetParser->{lastPacketTime});
		my $ai_timeout = sprintf("%.2f", time - $timeout{'ai'}{'time'});
		my $ai_time = sprintf("%.4f", time - $ai_v{'AI_last_finished'});

		message center(T(" Debug information "), 56, '-') ."\n".
			TF("ConState: %s\t\tConnected: %s\n" .
			"AI enabled: %s\t\tAI_forcedOff: %s\n" .
			"\@ai_seq = %s\n" .
			"Last packet: %.2f secs ago\n" .
			"\$timeout{ai}: %.2f secs ago  (value should be >%s)\n" .
			"Last AI() call: %.2f secs ago\n" .
			('-'x56) . "\n",
		$conState, $connected, $AI, $AI_forcedOff, "@ai_seq", $time, $ai_timeout,
		$timeout{'ai'}{'timeout'}, $ai_time), "list";
	}
}

sub cmdDoriDori {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $headdir;
	if ($char->{look}{head} == 2) {
		$headdir = 1;
	} else {
		$headdir = 2;
	}
	$messageSender->sendLook($char->{look}{body}, $headdir);
}

sub cmdDrop {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\d,-]+)/;
	my ($arg2) = $args =~ /^[\d,-]+ (\d+)$/;
	if (($arg1 eq "") or ($arg1 < 0)) {
		error T("Syntax Error in function 'drop' (Drop Inventory Item)\n" .
			"Usage: drop <item #> [<amount>]\n");
	} else {
		my @temp = split(/,/, $arg1);
		@temp = grep(!/^$/, @temp); # Remove empty entries

		my @items = ();
		foreach (@temp) {
			if (/(\d+)-(\d+)/) {
				for ($1..$2) {
					push(@items, $_) if ($char->inventory->get($_));
				}
			} else {
				push @items, $_ if ($char->inventory->get($_));
			}
		}
		if (@items > 0) {
			main::ai_drop(\@items, $arg2);
		} else {
			error T("No items were dropped.\n");
		}
	}
}

sub cmdDump {
	dumpData((defined $incomingMessages) ? $incomingMessages->getBuffer() : '');
	quit();
}

sub cmdDumpNow {
	dumpData((defined $incomingMessages) ? $incomingMessages->getBuffer() : '');
}

sub cmdEmotion {
	# Show emotion
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;

	my $num = getEmotionByCommand($args);

	if (!defined $num) {
		error T("Syntax Error in function 'e' (Emotion)\n" .
			"Usage: e <command>\n");
	} else {
		$messageSender->sendEmotion($num);
	}
}

sub cmdEquip {

	# Equip an item
	my (undef, $args) = @_;
	my ($arg1,$arg2) = $args =~ /^(\S+)\s*(.*)/;
	my $slot;
	my $item;

	if ($arg1 eq "") {
		cmdEquip_list();
		return;
	}

	if ($arg1 eq "slots") {
		# Translation Comment: List of equiped items on each slot
		message T("Slots:\n") . join("\n", @Actor::Item::slots). "\n", "list";
		return;
	}

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'eq ' .$args);
		return;
	}

	if ($equipSlot_rlut{$arg1}) {
		$slot = $arg1;
	} else {
		$arg1 .= " $arg2" if $arg2;
	}

	$item = Actor::Item::get(defined $slot ? $arg2 : $arg1, undef, 1);
	if (!$item) {
		$args =~ s/^($slot)\s//g if ($slot);
		error TF("No such non-equipped Inventory Item: %s\n", $args);
		return;
	}

	if (!$item->{type_equip} && $item->{type} != 10 && $item->{type} != 16 && $item->{type} != 17 && $item->{type} != 8) {
		error TF("Inventory Item %s (%s) can't be equipped.\n",
			$item->{name}, $item->{invIndex});
		return;
	}
	if ($slot) {
		$item->equipInSlot($slot);
	} else {
		$item->equip();
	}
}

sub cmdEquip_list {
	if (!$char) {
		error T("Character equipment not yet ready\n");
		return;
	}
	for my $slot (@Actor::Item::slots) {
		my $item = $char->{equipment}{$slot};
		my $name = $item ? $item->{name} : '-';
		($item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19) ?
			message sprintf("%-15s: %s x %s\n", $slot, $name, $item->{amount}), "list" :
			message sprintf("%-15s: %s\n", $slot, $name), "list";
	}
}

sub cmdEval {
	if (!$Settings::lockdown) {
		if ($_[1] eq "") {
			error T("Syntax Error in function 'eval' (Evaluate a Perl expression)\n" .
				"Usage: eval <expression>\n");
		} else {
			package main;
			no strict;
			undef $@;
			eval $_[1];
			if (defined $@ && $@ ne '') {
				$@ .= "\n" if ($@ !~ /\n$/s);
				Log::error($@);
			}
		}
	}
}

sub cmdExp {
	my (undef, $args) = @_;
	my $knownArg;
	my $msg;

	# exp report
	my ($arg1) = $args =~ /^(\w+)/;

	if ($arg1 eq "reset") {
		$knownArg = 1;
		($bExpSwitch,$jExpSwitch,$totalBaseExp,$totalJobExp) = (2,2,0,0);
		$startTime_EXP = time;
		$startingzeny = $char->{zeny} if $char;
		undef @monsters_Killed;
		$dmgpsec = 0;
		$totaldmg = 0;
		$elasped = 0;
		$totalelasped = 0;
		undef %itemChange;
		$char->{'deathCount'} = 0;
		$bytesSent = 0;
		$packetParser->{bytesProcessed} = 0 if $packetParser;
		message T("Exp counter reset.\n"), "success";
		return;
	}

	if (!$char) {
		error T("Exp report not yet ready\n");
		return;
	}

	if ($arg1 eq "output") {
		open(F, ">>:utf8", "$Settings::logs_folder/exp.txt");
	}
	
	if (($arg1 eq "") || ($arg1 eq "report") || ($arg1 eq "output")) {
		$knownArg = 1;
		my ($endTime_EXP, $w_sec, $bExpPerHour, $jExpPerHour, $EstB_sec, $percentB, $percentJ, $zenyMade, $zenyPerHour, $EstJ_sec, $percentJhr, $percentBhr);
		$endTime_EXP = time;
		$w_sec = int($endTime_EXP - $startTime_EXP);
		if ($w_sec > 0) {
			$zenyMade = $char->{zeny} - $startingzeny;
			$bExpPerHour = int($totalBaseExp / $w_sec * 3600);
			$jExpPerHour = int($totalJobExp / $w_sec * 3600);
			$zenyPerHour = int($zenyMade / $w_sec * 3600);
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

		$msg .= center(T(" Exp Report "), 50, '-') ."\n".
				TF( "Botting time : %s\n" .
					"BaseExp      : %s %s\n" .
					"JobExp       : %s %s\n" .
					"BaseExp/Hour : %s %s\n" .
					"JobExp/Hour  : %s %s\n" .
					"zeny         : %s\n" .
					"zeny/Hour    : %s\n" .
					"Base Levelup Time Estimation : %s\n" .
					"Job Levelup Time Estimation  : %s\n" .
					"Died : %s\n" .
					"Bytes Sent   : %s\n" .
					"Bytes Rcvd   : %s\n",
			timeConvert($w_sec), formatNumber($totalBaseExp), $percentB, formatNumber($totalJobExp), $percentJ,
			formatNumber($bExpPerHour), $percentBhr, formatNumber($jExpPerHour), $percentJhr,
			formatNumber($zenyMade), formatNumber($zenyPerHour), timeConvert($EstB_sec), timeConvert($EstJ_sec),
			$char->{'deathCount'}, formatNumber($bytesSent), $packetParser && formatNumber($packetParser->{bytesProcessed}));

		if ($arg1 eq "") {
			$msg .= ('-'x50) . "\n";
			message $msg, "list";
		}
	}

	if (($arg1 eq "monster") || ($arg1 eq "report") || ($arg1 eq "output")) {
		my $total;

		$knownArg = 1;

		$msg .= center(T(" Monster Killed Count "), 40, '-') ."\n".
			T("#   ID     Name                    Count\n");
		for (my $i = 0; $i < @monsters_Killed; $i++) {
			next if ($monsters_Killed[$i] eq "");
			$msg .= swrite(
				"@<< @<<<<< @<<<<<<<<<<<<<<<<<<<<<< @<<<<< ",
				[$i, $monsters_Killed[$i]{nameID}, $monsters_Killed[$i]{name}, $monsters_Killed[$i]{count}]);
			$total += $monsters_Killed[$i]{count};
		}
		$msg .= "\n" .
			TF("Total number of killed monsters: %s\n", $total) .
			('-'x40) . "\n";
		if ($arg1 eq "monster" || $arg1 eq "") {
			message $msg, "list";
		}
	}

	if (($arg1 eq "item") || ($arg1 eq "report") || ($arg1 eq "output")) {
		$knownArg = 1;

		$msg .= center(T(" Item Change Count "), 36, '-') ."\n".
			T("Name                           Count\n");
		for my $item (sort keys %itemChange) {
			next unless $itemChange{$item};
			$msg .= swrite(
				"@<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<",
				[$item, $itemChange{$item}]);
		}
		$msg .= ('-'x36) . "\n";
		message $msg, "list";
		
		if ($arg1 eq "output") {
			print F $msg;
			close(F);
		}
	}

	if (!$knownArg) {
		error T("Syntax error in function 'exp' (Exp Report)\n" .
			"Usage: exp [<report | monster | item | reset>]\n");
	}
}

sub cmdFalcon {
	my (undef, $arg1) = @_;

	my $hasFalcon = $char && $char->statusActive('EFFECTSTATE_BIRD');
	if ($arg1 eq "") {
		if ($hasFalcon) {
			message T("Your falcon is active\n");
		} else {
			message T("Your falcon is inactive\n");
		}
	} elsif ($arg1 eq "release") {
		if (!$hasFalcon) {
			error T("Error in function 'falcon release' (Remove Falcon Status)\n" .
				"You don't possess a falcon.\n");
		} elsif (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", 'falcon release');
			return;
		} else {
			$messageSender->sendCompanionRelease();
		}
	}
}

sub cmdFollow {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error T("Syntax Error in function 'follow' (Follow Player)\n" .
			"Usage: follow <player #>\n");
	} elsif ($arg1 eq "stop") {
		AI::clear("follow");
		configModify("follow", 0);
	} elsif ($arg1 =~ /^\d+$/) {
		if (!$playersID[$arg1]) {
			error TF("Error in function 'follow' (Follow Player)\n" .
				"Player %s either not visible or not online in party.\n", $arg1);
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

	if ($arg1 eq "") {
		my $msg = center(T(" Friends "), 36, '-') ."\n".
			T("#   Name                      Online\n");
		for (my $i = 0; $i < @friendsID; $i++) {
			$msg .= swrite(
				"@<  @<<<<<<<<<<<<<<<<<<<<<<<  @",
				[$i + 1, $friends{$i}{'name'}, $friends{$i}{'online'}? 'X':'']);
		}
		$msg .= ('-'x36) . "\n";
		message $msg, "list";

	} elsif (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'friend ' .$arg1);
		return;

	} elsif ($arg1 eq "request") {
		my $player = Match::player($arg2);

		if (!$player) {
			error TF("Player %s does not exist\n", $arg2);
		} elsif (!defined $player->{name}) {
			error T("Player name has not been received, please try again\n");
		} else {
			my $alreadyFriend = 0;
			for (my $i = 0; $i < @friendsID; $i++) {
				if ($friends{$i}{'name'} eq $player->{name}) {
					$alreadyFriend = 1;
					last;
				}
			}
			if ($alreadyFriend) {
				error TF("%s is already your friend\n", $player->{name});
			} else {
				message TF("Requesting %s to be your friend\n", $player->{name});
				$messageSender->sendFriendRequest($players{$playersID[$arg2]}{name});
			}
		}

	} elsif ($arg1 eq "remove") {
		if ($arg2 < 1 || $arg2 > @friendsID) {
			error TF("Friend #%s does not exist\n", $arg2);
		} else {
			$arg2--;
			message TF("Attempting to remove %s from your friend list\n", $friends{$arg2}{'name'});
			$messageSender->sendFriendRemove($friends{$arg2}{'accountID'}, $friends{$arg2}{'charID'});
		}

	} elsif ($arg1 eq "accept") {
		if ($incomingFriend{'accountID'} eq "") {
			error T("Can't accept the friend request, no incoming request\n");
		} else {
			message TF("Accepting the friend request from %s\n", $incomingFriend{'name'});
			$messageSender->sendFriendListReply($incomingFriend{'accountID'}, $incomingFriend{'charID'}, 1);
			undef %incomingFriend;
		}

	} elsif ($arg1 eq "reject") {
		if ($incomingFriend{'accountID'} eq "") {
			error T("Can't reject the friend request - no incoming request\n");
		} else {
			message TF("Rejecting the friend request from %s\n", $incomingFriend{'name'});
			$messageSender->sendFriendListReply($incomingFriend{'accountID'}, $incomingFriend{'charID'}, 0);
			undef %incomingFriend;
		}

	} elsif ($arg1 eq "pm") {
		if ($arg2 < 1 || $arg2 > @friendsID) {
			error TF("Friend #%s does not exist\n", $arg2);
		} else {
			$arg2--;
			if (binFind(\@privMsgUsers, $friends{$arg2}{'name'}) eq "") {
				message TF("Friend %s has been added to the PM list as %s\n", $friends{$arg2}{'name'}, @privMsgUsers);
				$privMsgUsers[@privMsgUsers] = $friends{$arg2}{'name'};
			} else {
				message TF("Friend %s is already in the PM list\n", $friends{$arg2}{'name'});
			}
		}

	} else {
		error T("Syntax Error in function 'friend' (Manage Friends List)\n" .
			"Usage: friend [request|remove|accept|reject|pm]\n");
	}
}

sub cmdSlave {
	my ($cmd, $subcmd) = @_;
	my @args = parseArgs($subcmd);

	if (!$char) {
		error T("Error: Can't detect slaves - character is not yet ready\n");
		return;
	}

	my $slave;
	if ($cmd eq 'homun') {
		$slave = $char->{homunculus};
	} elsif ($cmd eq 'merc') {
		$slave = $char->{mercenary};
	} else {
		error T("Error: Unknown command in cmdSlave\n");
	}
	my $string = $cmd;

	if (!$slave || !$slave->{appear_time}) {
		error T("Error: No slave detected.\n");

	} elsif ($slave->{actorType} eq 'Homunculus' && $slave->{state} & 2) {
			my $skill = new Skill(handle => 'AM_CALLHOMUN');
			error TF("Homunculus is in rest, use skills '%s' (ss %d).\n", $skill->getName, $skill->getIDN);

	} elsif ($slave->{actorType} eq 'Homunculus' && $slave->{state} & 4) {
			my $skill = new Skill(handle => 'AM_RESURRECTHOMUN');
			error TF("Homunculus is dead, use skills '%s' (ss %d).\n", $skill->getName, $skill->getIDN);
		
	} elsif ($subcmd eq "s" || $subcmd eq "status") {
		my $hp_string = $slave->{hp}. '/' .$slave->{hp_max} . ' (' . sprintf("%.2f",$slave->{hpPercent}) . '%)';
		my $sp_string = $slave->{sp}."/".$slave->{sp_max}." (".sprintf("%.2f",$slave->{spPercent})."%)";
		my $exp_string = (
			defined $slave->{exp}
			? T("Exp: ") . formatNumber($slave->{exp})."/".formatNumber($slave->{exp_max})." (".sprintf("%.2f",$slave->{expPercent})."%)"
			: (
				defined $slave->{kills}
				? T("Kills: ") . formatNumber($slave->{kills})
				: ''
			)
		);

		my ($intimacy_label, $intimacy_string) = (
			defined $slave->{intimacy}
			? (T('Intimacy:'), $slave->{intimacy})
			: (
				defined $slave->{faith}
				? (T('Faith:'), $slave->{faith})
				: ('', '')
			)
		);

		my $hunger_string = defined $slave->{hunger} ? $slave->{hunger} : T('N/A');
		my $accessory_string = defined $slave->{accessory} ? $slave->{accessory} : T('N/A');
		my $summons_string = defined $slave->{summons} ? $slave->{summons} : T('N/A');
		my $skillpt_string = defined $slave->{points_skill} ? $slave->{points_skill} : T('N/A');
		my $range_string = defined $slave->{attack_range} ? $slave->{attack_range} : T('N/A');
		my $contractend_string = defined $slave->{contract_end} ? getFormattedDate(int($slave->{contract_end})) : T('N/A');

		my $msg = swrite(
		center(T(" Slave Status "), 78, '-') . "\n" .
		T("Name: \@<<<<<<<<<<<<<<<<<<<<<<<<<  HP: \@>>>>>>>>>>>>>>>>>>\n" .
		"Type: \@<<<<<<<<<<<<<<<<<<<<<<<<<  SP: \@>>>>>>>>>>>>>>>>>>\n" .
		"Job:  \@<<<<<<<<<<<<<<<\n" .
		"Level: \@<<  \@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n") .
		"\n" .
		T("Atk:  \@>>>     Matk:     \@>>>     Hunger:       \@>>>\n" .
		"Hit:  \@>>>     Critical: \@>>>     \@<<<<<<<<<    \@>>>\n" .
		"Def:  \@>>>     Mdef:     \@>>>     Accessory:    \@>>>\n" .
		"Flee: \@>>>     Aspd:     \@>>>     Summons:      \@>>>\n" .
		"Range: \@>>     Skill pt: \@>>>     Contract End:  \@<<<<<<<<<<\n"),
		[$slave->{'name'}, $hp_string,
		$slave->{'actorType'}, $sp_string,
		$jobs_lut{$slave->{'jobId'}},
		$slave->{'level'}, $exp_string,
		$slave->{'atk'}, $slave->{'matk'}, $hunger_string,
		$slave->{'hit'}, $slave->{'critical'}, $intimacy_label, $intimacy_string,
		$slave->{'def'}, $slave->{'mdef'}, $accessory_string,
		$slave->{'flee'}, $slave->{'attack_speed'}, $summons_string,
		$range_string, $skillpt_string, $contractend_string]);

		$msg .= TF("Statuses: %s \n", $slave->statusesString);
		$msg .= ('-'x78) . "\n";

		message $msg, "info";

	} elsif ($subcmd eq "feed") {
		unless (defined $slave->{hunger}) {
			error T("This slave can not be feeded\n");
			return;
		}
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", $cmd .' ' .$subcmd);
			return;
		}
		if ($slave->{hunger} >= 76) {
			message T("Your homunculus is not yet hungry. Feeding it now will lower intimacy.\n"), "homunculus";
		} else {
			$messageSender->sendHomunculusCommand(1);
			message T("Feeding your homunculus.\n"), "homunculus";
		}

	} elsif ($subcmd eq "delete" || $subcmd eq "fire") {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", $cmd .' ' .$subcmd);
			return;
		}
		if ($slave->{actorType} eq 'Mercenary') {
			$messageSender->sendMercenaryCommand (2);
		} elsif ($slave->{actorType} eq 'Homunculus') {
			$messageSender->sendHomunculusCommand (2);
		}
	} elsif ($args[0] eq "move") {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", $cmd . ' ' .$subcmd);
			return;
		}
		if (!($args[1] =~ /^\d+$/) || !($args[2] =~ /^\d+$/)) {
			error TF("Error in function '%s move' (Slave Move)\n" .
				"Invalid coordinates (%s, %s) specified.\n", $cmd, $args[1], $args[2]);
			return;
		} else {
			# max distance that homunculus can follow: 17
			$messageSender->sendHomunculusMove($slave->{ID}, $args[1], $args[2]);
		}

	} elsif ($subcmd eq "standby") {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", $cmd .' ' .$subcmd);
			return;
		}
		$messageSender->sendHomunculusStandBy($slave->{ID});

	} elsif ($args[0] eq 'ai') {
		if ($args[1] eq 'clear') {
			$slave->clear();
			message T("Slave AI sequences cleared\n"), "success";

		} elsif ($args[1] eq 'print') {
			# Display detailed info about current AI sequence
			my $msg = center(T(" Slave AI Sequence "), 50, '-') ."\n";
			my $index = 0;
			foreach (@{$slave->{slave_ai_seq}}) {
				$msg .= "$index: $_ " . dumpHash(\%{$slave->{slave_ai_seq_args}[$index]}) . "\n\n";
				$index++;
			}
			$msg .= ('-'x50) . "\n";
			message $msg, "list";

		} elsif ($args[1] eq 'on' || $args[1] eq 'auto') {
			# Set AI to auto mode
			if ($slave->{slave_AI} == AI::AUTO) {
				message T("Slave AI is already set to auto mode\n"), "success";
			} else {
				$slave->{slave_AI} = AI::AUTO;
				undef $slave->{slave_AI_forcedOff};
				message T("Slave AI set to auto mode\n"), "success";
			}
		} elsif ($args[1] eq 'manual') {
			# Set AI to manual mode
			if ($slave->{slave_AI} == AI::MANUAL) {
				message T("Slave AI is already set to manual mode\n"), "success";
			} else {
				$slave->{slave_AI} = AI::MANUAL;
				$slave->{slave_AI_forcedOff} = 1;
				message T("Slave AI set to manual mode\n"), "success";
			}
		} elsif ($args[1] eq 'off') {
			# Turn AI off
			if ($slave->{slave_AI}) {
				undef $slave->{slave_AI};
				$slave->{slave_AI_forcedOff} = 1;
				message T("Slave AI turned off\n"), "success";
			} else {
				message T("Slave AI is already off\n"), "success";
			}

		} elsif ($args[1] eq '') {
			# Toggle AI
			if ($slave->{slave_AI} == AI::AUTO) {
				undef $slave->{slave_AI};
				$slave->{slave_AI_forcedOff} = 1;
				message T("Slave AI turned off\n"), "success";
			} elsif (!$slave->{slave_AI}) {
				$slave->{slave_AI} = AI::MANUAL;
				$slave->{slave_AI_forcedOff} = 1;
				message T("Slave AI set to manual mode\n"), "success";
			} elsif ($slave->{slave_AI} == AI::MANUAL) {
				$slave->{slave_AI} = AI::AUTO;
				undef $slave->{slave_AI_forcedOff};
				message T("Slave AI set to auto mode\n"), "success";
			}

		} else {
			error TF("Syntax Error in function 'slave ai' (Slave AI Commands)\n" .
				"Usage: %s ai [ clear | print | auto | manual | off ]\n", $string);
		}

	} elsif ($subcmd eq "aiv") {
		if (!$slave->{slave_AI}) {
			message TF("ai_seq (off) = %s\n", "@{$slave->{slave_ai_seq}}"), "list";
		} elsif ($slave->{slave_AI} == 1) {
			message TF("ai_seq (manual) = %s\n", "@{$slave->{slave_ai_seq}}"), "list";
		} elsif ($slave->{slave_AI} == 2) {
			message TF("ai_seq (auto) = %s\n", "@{$slave->{slave_ai_seq}}"), "list";
		}
		message T("solution\n"), "list" if ($slave->args()->{'solution'});

	} elsif ($args[0] eq "skills") {
		if ($args[1] eq '') {
			my $msg = center(T(" Slave Skill List "), 46, '-') ."\n".
				T("   # Skill Name                     Lv      SP\n");
			foreach my $handle (@{$slave->{slave_skillsID}}) {
				my $skill = new Skill(handle => $handle);
				my $sp = $char->{skills}{$handle}{sp} || '';
				$msg .= swrite(
					"@>>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>    @>>>",
					[$skill->getIDN(), $skill->getName(), $char->getSkillLevel($skill), $sp]);
			}
			$msg .= TF("\nSkill Points: %d\n", $slave->{points_skill}) if defined $slave->{points_skill};
			$msg .= ('-'x46) . "\n";
			message $msg, "list";

		} elsif ($args[1] eq "add" && $args[2] =~ /\d+/) {
			if (!$net || $net->getState() != Network::IN_GAME) {
				error TF("You must be logged in the game to use this command '%s'\n", $cmd .' ' .$subcmd);
				return;
			}
			my $skill = new Skill(idn => $args[2]);
			if (!$skill->getIDN() || !$char->{skills}{$skill->getHandle()}) {
				error TF("Error in function '%s skills add' (Add Skill Point)\n" .
					"Skill %s does not exist.\n", $cmd, $args[2]);
			} elsif ($slave->{points_skill} < 1) {
				error TF("Error in function '%s skills add' (Add Skill Point)\n" .
					"Not enough skill points to increase %s\n", $cmd, $skill->getName());
			} else {
				$messageSender->sendAddSkillPoint($skill->getIDN());
			}

		} elsif ($args[1] eq "desc" && $args[2] =~ /\d+/) {
			my $skill = new Skill(idn => $args[2]);
			if (!$skill->getIDN()) {
				error TF("Error in function '%s skills desc' (Skill Description)\n" .
					"Skill %s does not exist.\n", $cmd, $args[2]);
			} else {
				my $description = $skillsDesc_lut{$skill->getHandle()} || T("Error: No description available.\n");
				my $msg = center(T(" Skill Description "), 79, '=') ."\n".
						TF("Skill: %s", $description) .
						('='x79) . "\n";
				message $msg, "list";
			}

		} else {
			error TF("Syntax Error in function 'slave skills' (Slave Skills Functions)\n" .
				"Usage: %s skills [(<add | desc>) [<skill #>]]\n", $string);
		}

	} elsif ($args[0] eq "rename") {
		if ($char->{homunculus}{renameflag}) {
			if ($args[1] ne '') {
				if (length($args[1]) < 25) {
					$messageSender->sendHomunculusName($args[1]);
				} else {
					error T("The name can not exceed 24 characters\n");
				}
			} else {
				error TF("Syntax Error in function 'slave rename' (Slave Rename)\n" .
					"Usage: %s rename <new name>\n", $string);
			}
		} else {
			error T("His homunculus has been named or not under conditions to be renamed!\n");
		}

 	} else {
		error TF("Usage: %s <feed | s | status | move | standby | ai | aiv | skills | delete | rename>\n", $string);
	}
}

sub cmdGetPlayerInfo {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	return 0 if (isSafeActorQuery(pack("V", $args)) != 1); # Do not Query GM's
	$messageSender->sendGetPlayerInfo(pack("V", $args));
}

sub cmdGetCharacterName {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	$messageSender->sendGetCharacterName(pack("V", $args));
}

sub cmdGmb {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	return unless ($char);
	my ($cmd, $message) = @_;
	my ($msg, $switch);

	if ($message eq '') {
		error TF("Usage: %s <MESSAGE>\n", $cmd);
		return;
	} elsif ($cmd =~ /^gml/) {
		$switch = hex('019C');
	} else {
		$switch = hex('0099');
	}

	if ($cmd eq 'gmb' || $cmd eq 'gmlb') {
		$message = stringToBytes("$char->{name}: $message");
	} elsif ($cmd eq 'gmbb' || $cmd eq 'gmlbb') {
		$message = stringToBytes("blue$message");
	} elsif ($cmd eq 'gmnb' || $cmd eq 'gmlnb') {
		$message = stringToBytes($message);
	}
	$msg = pack('v2 Z*', $switch, length($message) + 5, $message);
	$messageSender->sendToServer($msg);
}

sub cmdGmmapmove {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;

	my ($map_name) = $args =~ /(\S+)/;
	# this will pack as 0 if it fails to match
	my ($x, $y) = $args =~ /\w+ (\d+) (\d+)/;

	if ($map_name eq '') {
		error T("Usage: gmmapmove <FIELD>\n" .
				"FIELD is a field name including .gat extension, like: gef_fild01.gat\n");
		return;
	}

	my $packet = pack("C*", 0x40, 0x01) . pack("a16", $map_name) . pack("v1 v1", $x, $y);
	$messageSender->sendToServer($packet);
}

sub cmdGmsummon {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;

	if ($args eq '') {
		error T("Usage: gmsummon <player name>\n" .
			"Summon a player.\n");
	} else {
		$messageSender->sendGMSummon($args);
	}
}

sub cmdGmdc {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;

	if ($args !~ /^\d+$/) {
		error T("Usage: gmdc <player_AID>\n");
		return;
	}

	my $packet = pack("C*", 0xCC, 0x00).pack("V1", $args);
	$messageSender->sendToServer($packet);
}

sub cmdGmkillall {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $packet = pack("C*", 0xCE, 0x00);
	$messageSender->sendToServer($packet);
}

sub cmdGmcreate {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;

	if ($args eq '') {
		error T("Usage: gmcreate (<MONSTER_NAME> || <Item_Name>) \n");
		return;
	}

	my $packet = pack("C*", 0x3F, 0x01).pack("a24", $args);
	$messageSender->sendToServer($packet);
}

sub cmdGmhide {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $packet = pack("C*", 0x9D, 0x01, 0x40, 0x00, 0x00, 0x00);
	$messageSender->sendToServer($packet);
}

sub cmdGmresetstate {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $packet = pack("C1 C1 v1", 0x97, 0x01, 0);
	$messageSender->sendToServer($packet);
}

sub cmdGmresetskill {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $packet = pack("C1 C1 v1", 0x97, 0x01, 1);
	$messageSender->sendToServer($packet);
}

sub cmdGmmute {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($ID, $time) = $args =~ /^(\d+) (\d+)/;
	if (!$ID) {
		error T("Usage: gmmute <ID> <minutes>\n");
		return;
	}
	my $packet = pack("C1 C1 V1 C1 v1", 0x49, 0x01, $ID, 1, $time);
	$messageSender->sendToServer($packet);
}

sub cmdGmunmute {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($ID, $time) = $args =~ /^(\d+) (\d+)/;
	if (!$ID) {
		error T("Usage: gmunmute <ID> <minutes>\n");
		return;
	}
	my $packet = pack("C1 C1 V1 C1 v1", 0x49, 0x01, $ID, 0, $time);
	$messageSender->sendToServer($packet);
}

sub cmdGmwarpto {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;

	if ($args eq '') {
		error T("Usage: gmwarpto <Player Name>\n");
		return;
	}

	my $packet = pack("C*", 0xBB, 0x01).pack("a24", $args);
	$messageSender->sendToServer($packet);
}

sub cmdGmrecall {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;

	if ($args eq '') {
		error T("Usage: gmrecall [<Character Name> | <User Name>]\n");
		return;
	}

	my $packet = pack("C*", 0xBC, 0x01).pack("a24", $args);
	$messageSender->sendToServer($packet);
}

sub cmdGmremove {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;

	if ($args eq '') {
		error T("Usage: gmremove [<Character Name> | <User Name>]\n");
		return;
	}

	my $packet = pack("C*", 0xBA, 0x01).pack("a24", $args);
	$messageSender->sendToServer($packet);
}

sub cmdGuild {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = split(' ', $args, 2);

	if ($arg1 eq "" || (!%guild && ($arg1 eq "info" || $arg1 eq "member" || $arg1 eq "kick"))) {
		if (!$net || $net->getState() != Network::IN_GAME) {
			if ($arg1 eq "") {
				error T("You must be logged in the game to request guild information\n");
			} else {
				error T("Guild information is not yet available. You must login to the game and use the 'guild' command first\n");
			}
			return;
		}
		message	T("Requesting guild information...\n"), "info";
		$messageSender->sendGuildMasterMemberCheck();

		# Replies 01B6 (Guild Info) and 014C (Guild Ally/Enemy List)
		$messageSender->sendGuildRequestInfo(0);

		# Replies 0166 (Guild Member Titles List) and 0154 (Guild Members List)
		$messageSender->sendGuildRequestInfo(1);

		# Replies 0166 (Guild Member Titles List) and 0160 (Guild Member Titles Info List)
		$messageSender->sendGuildRequestInfo(2);

		# Replies 0162 (Guild Skill Info List)
		$messageSender->sendGuildRequestInfo(3);

		# Replies 015C (Guild Expulsion List)
		$messageSender->sendGuildRequestInfo(4);

		if ($arg1 eq "") {
			message T("Enter command to view guild information: guild <info | member | request | join | leave | kick | ally | create | break>\n"), "info";
		} else {
			message	TF("Type 'guild %s' again to view the information.\n", $args), "info";
		}

	} elsif ($arg1 eq "info") {
		my $msg = center(T(" Guild Information "), 40, '-') ."\n" .
			TF("Name    : %s\n" .
				"Lv      : %d\n" .
				"Exp     : %d/%d\n" .
				"Master  : %s\n" .
				"Connect : %d/%d\n",
			$guild{name}, $guild{lv}, $guild{exp}, $guild{exp_next}, $guild{master},
			$guild{conMember}, $guild{maxMember});
		for my $ally (keys %{$guild{ally}}) {
			# Translation Comment: List of allies. Keep the same spaces of the - Guild Information - tag.
			$msg .= TF("Ally    : %s (%s)\n", $guild{ally}{$ally}, $ally);
		}
		for my $ally (keys %{$guild{enemy}}) {
			# Translation Comment: List of enemies. Keep the same spaces of the - Guild Information - tag.
			$msg .= TF("Enemy   : %s (%s)\n", $guild{enemy}{$ally}, $ally);
		}
		$msg .= ('-'x40) . "\n";
		message $msg, "info";

	} elsif ($arg1 eq "member") {
		if (!$guild{member}) {
			error T("No guild member information available.\n");
			return;
		}

		my $msg = center(T(" Guild  Member "), 79, '-') ."\n".
			T("#  Name                       Job           Lv  Title                    Online\n");

		my ($i, $name, $job, $lvl, $title, $online, $ID, $charID);
		my $count = @{$guild{member}};
		for ($i = 0; $i < $count; $i++) {
			$name  = $guild{member}[$i]{name};
			next if (!defined $name);

			$job   = $jobs_lut{$guild{member}[$i]{jobID}};
			$lvl   = $guild{member}[$i]{lv};
			$title = $guild{member}[$i]{title};
 			# Translation Comment: Guild member online
			$online = $guild{member}[$i]{online} ? T("Yes") : T("No");
			$ID = unpack("V",$guild{member}[$i]{ID});
			$charID = unpack("V",$guild{member}[$i]{charID});

			$msg .= swrite("@< @<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<< @<<<<<<<<<<<<<<<<<<<<<<< @<<",
					[$i, $name, $job, $lvl, $title, $online, $ID, $charID]);
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";

	} elsif (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'guild ' .$arg1);
		return;

	} elsif ($arg1 eq "join") {
		if ($arg2 ne "1" && $arg2 ne "0") {
			error T("Syntax Error in function 'guild join' (Accept/Deny Guild Join Request)\n" .
				"Usage: guild join <flag>\n");
			return;
		} elsif ($incomingGuild{'ID'} eq "") {
			error T("Error in function 'guild join' (Join/Request to Join Guild)\n" .
				"Can't accept/deny guild request - no incoming request.\n");
			return;
		}

		$messageSender->sendGuildJoin($incomingGuild{ID}, $arg2);
		undef %incomingGuild;
		if ($arg2) {
			message T("You accepted the guild join request.\n"), "success";
		} else {
			message T("You denied the guild join request.\n"), "info";
		}

	} elsif ($arg1 eq "create") {
		if (!$arg2) {
			error T("Syntax Error in function 'guild create' (Create Guild)\n" .
				"Usage: guild create <name>\n");
		} else {
			$messageSender->sendGuildCreate($arg2);
		}

	} elsif (!defined $char->{guild}) {
		error T("You are not in a guild.\n");

	} elsif ($arg1 eq "request") {
		my $player = Match::player($arg2);
		if (!$player) {
			error TF("Player %s does not exist.\n", $arg2);
		} else {
			$messageSender->sendGuildJoinRequest($player->{ID});
			message TF("Sent guild join request to %s\n", $player->{name});
		}

	} elsif ($arg1 eq "ally") {
		if (!$guild{master}) {
			error T("No guild information available. Type guild to refresh and then try again.\n");
			return;
		}
		my $player = Match::player($arg2);
		if (!$player) {
			error TF("Player %s does not exist.\n", $arg2);
		} elsif (!$char->{name} eq $guild{master}) {
			error T("You must be guildmaster to set an alliance\n");
			return;
		} else {
			$messageSender->sendGuildSetAlly($net,$player->{ID},$accountID,$charID);
			message TF("Sent guild alliance request to %s\n", $player->{name});
		}

	} elsif ($arg1 eq "leave") {
		$messageSender->sendGuildLeave($arg2);
		message TF("Sending guild leave: %s\n", $arg2);

	} elsif ($arg1 eq "break") {
		if (!$arg2) {
			error T("Syntax Error in function 'guild break' (Break Guild)\n" .
				"Usage: guild break <guild name>\n");
		} else {
			$messageSender->sendGuildBreak($arg2);
			message TF("Sending guild break: %s\n", $arg2);
		}

	} elsif ($arg1 eq "kick") {
		if (!$guild{member}) {
			error T("No guild member information available.\n");
			return;
		}
		my @params = split(' ', $arg2, 2);
		if ($params[0] =~ /^\d+$/) {
			if ($guild{'member'}[$params[0]]) {
				$messageSender->sendGuildMemberKick($char->{guildID},
					$guild{member}[$params[0]]{ID},
					$guild{member}[$params[0]]{charID},
					$params[1]);
			} else {
				error TF("Error in function 'guild kick' (Kick Guild Member)\n" .
					"Invalid guild member '%s' specified.\n", $params[0]);
			}
		} else {
			error T("Syntax Error in function 'guild kick' (Kick Guild Member)\n" .
				"Usage: guild kick <number> <reason>\n");
		}
	}
}

sub cmdHelp {
	# Display help message
	my (undef, $args) = @_;
	my @commands_req = split(/ +/, $args);
	my @unknown;
	my @found;

	my @commands = (@commands_req)? @commands_req : (sort keys %descriptions, grep { $customCommands{$_}->{desc} } keys %customCommands);

#	my ($message,$cmd);

	my $msg = center(T(" Available commands "), 79, '=') ."\n" unless @commands_req;
	foreach my $switch (@commands) {
		if ($descriptions{$switch}) {
			if (ref($descriptions{$switch}) eq 'ARRAY') {
				if (@commands_req) {
					helpIndent($switch,$descriptions{$switch});
				} else {
					$msg .= sprintf("%-11s  %s\n",$switch, $descriptions{$switch}->[0]);
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
					$msg .= sprintf("%-11s  %s\n",$switch, $customCommands{$switch}{desc}->[0]);
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
			error TF("The command \"%s\" doesn't exist.\n", $unknown[0]);
		} else {
			error TF("These commands don't exist: %s\n", join(', ', @unknown));
		}
		error T("Type 'help' to see a list of all available commands.\n");
	}
	$msg .= ('='x79) . "\n" unless @commands_req;
	message $msg, "list" if $msg;
}

sub helpIndent {
	my $cmd = shift;
	my $desc = shift;
	my @tmp = @{$desc};
	my $message;
	my $messageTmp;
	my @words;
	my $length = 0;

	$message = center(TF(" Help for '%s' ", $cmd), 79, "=")."\n";
	$message .= shift(@tmp) . "\n";

	foreach (@tmp) {
		$length = length($_->[0]) if length($_->[0]) > $length;
	}
	my $pattern = "$cmd %-${length}s    %s\n";
	my $padsize = length($cmd) + $length + 5;
	my $pad = sprintf("%-${padsize}s", '');

	foreach (@tmp) {
		if ($padsize + length($_->[1]) > 79) {
			@words = split(/ /, $_->[1]);
			$message .= sprintf("$cmd %-${length}s    ", $_->[0]);
			$messageTmp = '';
			foreach my $word (@words) {
				if ($padsize + length($messageTmp) + length($word) + 1 > 79) {
					$message .= $messageTmp . "\n$pad";
					$messageTmp = "$word ";
				} else {
					$messageTmp .= "$word ";
				}
			}
			$message .= $messageTmp."\n";
		}
		else {
			$message .= sprintf($pattern, $_->[0], $_->[1]);
		}
	}
	$message .= "=" x 79 . "\n";
	message $message, "list";
}

sub cmdIdentify {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $arg1) = @_;
	if ($arg1 eq "" && @identifyID) {
		my $msg = center(T(" Identify List "), 50, '-') ."\n";
		for (my $i = 0; $i < @identifyID; $i++) {
			next if ($identifyID[$i] eq "");
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $char->inventory->get($identifyID[$i])->{name}]);
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";
	} elsif (!@identifyID) {
		error T("The identify list is empty, please use the identify skill or a magnifier first.\n");
	} elsif ($arg1 =~ /^\d+$/) {
		if ($identifyID[$arg1] eq "") {
			error TF("Error in function 'identify' (Identify Item)\n" .
				"Identify Item %s does not exist\n", $arg1);
		} else {
			$messageSender->sendIdentify($char->inventory->get($identifyID[$arg1])->{index});
		}

	} else {
		error T("Syntax Error in function 'identify' (Identify Item)\n" .
			"Usage: identify [<identify #>]\n");
	}
}

sub cmdIgnore {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^(\d+) ([\s\S]*)/;
	if ($arg1 eq "" || $arg2 eq "" || ($arg1 ne "0" && $arg1 ne "1")) {
		error T("Syntax Error in function 'ignore' (Ignore Player/Everyone)\n" .
			"Usage: ignore <flag> <name | all>\n");
	} else {
		if ($arg2 eq "all") {
			$messageSender->sendIgnoreAll(!$arg1);
		} else {
			$messageSender->sendIgnore($arg2, !$arg1);
		}
	}
}

sub cmdIhist {
	# Display item history
	my (undef, $args) = @_;
	$args = 5 if ($args eq "");

	if (!($args =~ /^\d+$/)) {
		error T("Syntax Error in function 'ihist' (Show Item History)\n" .
			"Usage: ihist [<number of entries #>]\n");

	} elsif (open(ITEM, "<", $Settings::item_log_file)) {
		my @item = <ITEM>;
		close(ITEM);
		my $msg = center(T(" Item History "), 79, '-') ."\n";
		my $i = @item - $args;
		$i = 0 if ($i < 0);
		for (; $i < @item; $i++) {
			$msg .= $item[$i];
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";

	} else {
		error TF("Unable to open %s\n", $Settings::item_log_file);
	}
}


=pod
=head2 cmdInventory

Console command that displays a character's inventory contents
- With pretty text headers
- Items are displayed from lowest index to highest index, but, grouped
  in the following sub-categories:
  eq - Equipped Items (such as armour, shield, weapon in L/R/both hands)
  neq- Non-equipped equipment items
  nu - Non-usable items
  u - Usable (consumable) items

All items that are not identified will be suffixed with
"-- Not Identified" on the end.

Syntax: i [eq|neq|nu|u|desc <IndexNumber>]

Invalid arguments to this command will display an error message to 
inform and correct the user.

All text strings for headers, and to indicate Non-identified or pending
sale items should be translatable.

=cut
sub cmdInventory {
	# Display inventory items
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (.+)/;
	
	if (!$char || !$char->inventory->isReady()) {
		error "Inventory is not available\n";
		return;
	}
	
	if ($char->inventory->size() == 0) {
		error T("Inventory is empty\n");
		return;
	}

	if ($arg1 eq "" || $arg1 eq "eq" || $arg1 eq "neq" || $arg1 eq "u" || $arg1 eq "nu") {
		my @useable;
		my @equipment;
		my @uequipment;
		my @non_useable;
		my ($i, $display, $index, $sell);

		foreach my $item (@{$char->inventory->getItems()}) {
			if ($item->usable) {
				push @useable, $item->{invIndex};
			} elsif ($item->equippable && $item->{type_equip} != 0) {
				my %eqp;
				$eqp{index} = $item->{index};
				$eqp{binID} = $item->{invIndex};
				$eqp{name} = $item->{name};
				$eqp{amount} = $item->{amount};
				$eqp{equipped} = ($item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19) ? $item->{amount} . " left" : $equipTypes_lut{$item->{equipped}};
				$eqp{type} = $itemTypes_lut{$item->{type}};
				$eqp{equipped} .= " ($item->{equipped})";
				# Translation Comment: Mark to tell item not identified
				$eqp{identified} = " -- " . T("Not Identified") if !$item->{identified};
				if ($item->{equipped}) {
					push @equipment, \%eqp;
				} else {
					push @uequipment, \%eqp;
				}
			} else {
				push @non_useable, $item->{invIndex};
			}
		}
		# Start header -- Note: Title is translatable.
		my $msg = center(T(" Inventory "), 50, '-') ."\n";

		if ($arg1 eq "" || $arg1 eq "eq") {
			# Translation Comment: List of equipment items worn by character
			$msg .= T("-- Equipment (Equipped) --\n");
			foreach my $item (@equipment) {
				$sell = defined(findIndex(\@sellList, "invIndex", $item->{binID})) ? T("Will be sold") : "";
				$display = sprintf("%-3d  %s -- %s", $item->{binID}, $item->{name}, $item->{equipped});
				$msg .= sprintf("%-57s %s\n", $display, $sell);
			}
		}

		if ($arg1 eq "" || $arg1 eq "neq") {
			# Translation Comment: List of equipment items NOT worn
			$msg .= T("-- Equipment (Not Equipped) --\n");
			foreach my $item (@uequipment) {
				$sell = defined(findIndex(\@sellList, "invIndex", $item->{binID})) ? T("Will be sold") : "";
				$display = sprintf("%-3d  %s (%s)", $item->{binID}, $item->{name}, $item->{type});
				$display .= " x $item->{amount}" if $item->{amount} > 1;
				$display .= $item->{identified};
				$msg .= sprintf("%-57s %s\n", $display, $sell);
			}
		}

		if ($arg1 eq "" || $arg1 eq "nu") {
			# Translation Comment: List of non-usable items
			$msg .= T("-- Non-Usable --\n");
			for ($i = 0; $i < @non_useable; $i++) {
				$index = $non_useable[$i];
				my $item = $char->inventory->get($index);
				$display = $item->{name};
				$display .= " x $item->{amount}";
				# Translation Comment: Tell if the item is marked to be sold
				$sell = defined(findIndex(\@sellList, "invIndex", $index)) ? T("Will be sold") : "";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<",
					[$index, $display, $sell]);
			}
		}

		if ($arg1 eq "" || $arg1 eq "u") {
			# Translation Comment: List of usable items
			$msg .= T("-- Usable --\n");
			for ($i = 0; $i < @useable; $i++) {
				$index = $useable[$i];
				my $item = $char->inventory->get($index);
				$display = $item->{name};
				$display .= " x $item->{amount}";
				$sell = defined(findIndex(\@sellList, "invIndex", $index)) ? T("Will be sold") : "";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<",
					[$index, $display, $sell]);
			}
		}

		$msg .= ('-'x50) . "\n"; #Add footer onto end of list.
		message $msg, "list";

	} elsif ($arg1 eq "desc" && $arg2 ne "") {
		cmdInventory_desc($arg2);

	} else {
		error T("Syntax Error in function 'i' (Inventory List)\n" .
			"Usage: i [<u|eq|neq|nu|desc>] [<inventory item>]\n");
	}
}

sub cmdInventory_desc {
	my ($name) = @_;

	my $item = Match::inventoryItem($name);
	if (!$item) {
		error TF("Error in function 'i' (Inventory Item Description)\n" .
			"Inventory Item %s does not exist\n", $name);
		return;
	}

	printItemDesc($item->{nameID});
}

sub cmdItemList {
	my $msg = center(T(" Item List "), 46, '-') ."\n".
		T("   # Name                           Coord\n");
	for (my $i = 0; $i < @itemsID; $i++) {
		next if ($itemsID[$i] eq "");
		my $item = $items{$itemsID[$i]};
		my $display = "$item->{name} x $item->{amount}";
		$msg .= sprintf("%4d %-30s (%3d, %3d)\n",
			$i, $display, $item->{pos}{x}, $item->{pos}{y});
	}
	$msg .= ('-'x46) . "\n";
	message $msg, "list";
}

sub cmdItemLogClear {
	itemLog_clear();
	message T("Item log cleared.\n"), "success";
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
#		$messageSender->sendAlignment($playersID[$arg1], $arg2);
#	}
#}

sub cmdKill {
	my (undef, $ID) = @_;

	my $target = $playersID[$ID];
	unless ($target) {
		error TF("Player %s does not exist.\n", $ID);
		return;
	}

	attack($target);
}

sub cmdLook {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)$/;
	if ($arg1 eq "") {
		error T("Syntax Error in function 'look' (Look a Direction)\n" .
			"Usage: look <body dir> [<head dir>]\n");
	} else {
		look($arg1, $arg2);
	}
}

sub cmdLookPlayer {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error T("Syntax Error in function 'lookp' (Look at Player)\n" .
			"Usage: lookp <player #>\n");
	} elsif (!$playersID[$arg1]) {
		error TF("Error in function 'lookp' (Look at Player)\n" .
			"'%s' is not a valid player number.\n", $arg1);
	} else {
		lookAtPosition($players{$playersID[$arg1]}{pos_to});
	}
}

sub cmdManualMove {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($switch, $steps) = @_;
	if (!$steps) {
		$steps = 5;
	} elsif ($steps !~ /^\d+$/) {
		error TF("Error in function '%s' (Manual Move)\n" .
			"Usage: %s [distance]\n", $switch, $switch);
		return;
	}
	if ($switch eq "east") {
		manualMove($steps, 0);
	} elsif ($switch eq "west") {
		manualMove(-$steps, 0);
	} elsif ($switch eq "north") {
		manualMove(0, $steps);
	} elsif ($switch eq "south") {
		manualMove(0, -$steps);
	} elsif ($switch eq "northeast") {
		manualMove($steps, $steps);
	} elsif ($switch eq "southwest") {
		manualMove(-$steps, -$steps);
	} elsif ($switch eq "northwest") {
		manualMove(-$steps, $steps);
	} elsif ($switch eq "southeast") {
		manualMove($steps, -$steps);
	}
}

sub cmdMemo {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	$messageSender->sendMemo();
}

sub cmdMonsterList {
	my (undef, $args) = @_;
	if ($args =~ /^\d+$/) {
		if (my $monster = $monstersList->get($args)) {
			my $msg = center(T(" Monster Info "), 50, '-') ."\n".
				TF("%s (%d)\n" .
				"Walk speed: %s secs per block\n",
			$monster->name, $monster->{binID},
			$monster->{walk_speed});
			$msg .= TF("Statuses: %s \n", $monster->statusesString);
			$msg .= '-' x 50 . "\n";
			message $msg, "info";
		} else {
			error TF("Monster \"%s\" does not exist.\n", $args);
		}
	} else {
		my ($dmgTo, $dmgFrom, $dist, $pos, $name, $monsters);
		my $msg = center(T(" Monster List "), 79, '-') ."\n".
			T("#   Name                        ID      DmgTo DmgFrom  Distance    Coordinates\n");
		$monsters = $monstersList->getItems() if ($monstersList);
		foreach my $monster (@{$monsters}) {
			$dmgTo = ($monster->{dmgTo} ne "")
				? $monster->{dmgTo}
				: 0;
			$dmgFrom = ($monster->{dmgFrom} ne "")
				? $monster->{dmgFrom}
				: 0;
			$dist = distance($char->{pos_to}, $monster->{pos_to});
			$dist = sprintf("%.1f", $dist) if (index($dist, '.') > -1);
			$pos = '(' . $monster->{pos_to}{x} . ', ' . $monster->{pos_to}{y} . ')';
			$name = $monster->name;
			if ($name ne $monster->{name_given}) {
				$name .= '[' . $monster->{name_given} . ']';
			}
			$msg .= swrite(
				"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<< @<<<< @<<<<    @<<<<<      @<<<<<<<<<<",
				[$monster->{binID}, $name, $monster->{binType}, $dmgTo, $dmgFrom, $dist, $pos]);
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";
	}
}

sub cmdMove {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my @args_split = split(/\s+/, $args);

	my ($map_or_portal, $x, $y, $dist);
	if (($args_split[0] =~ /^\d+$/) && ($args_split[1] =~ /^\d+$/) && ($args_split[2] =~ /^\S+$/)) {
		# coordinates and map
		$map_or_portal = $args_split[2];
		$x = $args_split[0];
		$y = $args_split[1];
	} elsif (($args_split[0] =~ /^\S+$/) && ($args_split[1] =~ /^\d+$/) && ($args_split[2] =~ /^\d+$/)) {
		# map and coordinates
		$map_or_portal = $args_split[0];
		$x = $args_split[1];
		$y = $args_split[2];
	} elsif (($args_split[0] =~ /^\S+$/) && !$args_split[1]) {
		# map only
		$map_or_portal = $args_split[0];
	} elsif (($args_split[0] =~ /^\d+$/) && ($args_split[1] =~ /^\d+$/) && !$args_split[2]) {
		# coordinates only
		$map_or_portal = $field->baseName;
		$x = $args_split[0];
		$y = $args_split[1];
	} else {
		error T("Syntax Error in function 'move' (Move Player)\n" .
			"Usage: move <x> <y> [<map> [<distance from coordinates>]]\n" .
			"       move <map> [<x> <y> [<distance from coordinates>]]\n" .
			"       move <portal#>\n");
	}

	# if (($args_split[0] =~ /^\d+$/) && ($args_split[1] =~ /^\d+$/) && ($args_split[2] =~ /^\d+$/)) {
		# # distance from x, y
		# $dist = $args_split[2];
	# } elsif {
	if ($args_split[3] =~ /^\d+$/) {
		# distance from map x, y
		$dist = $args_split[3];
	}


	if ($map_or_portal eq "stop") {
		AI::clear(qw/move route mapRoute/);
		message T("Stopped all movement\n"), "success";
	} else {
		AI::clear(qw/move route mapRoute/);
		if ($currentChatRoom ne "") {
			error T("Error in function 'move' (Move Player)\n" .
				"Unable to walk while inside a chat room!\n" .
				"Use the command: chat leave\n");
		} elsif ($shopstarted) {
			error T("Error in function 'move' (Move Player)\n" .
				"Unable to walk while the shop is open!\n" .
				"Use the command: closeshop\n");
		} else {
			if ($map_or_portal =~ /^\d+$/) {
				if ($portalsID[$map_or_portal]) {
					message TF("Move into portal number %s (%s,%s)\n",
						$map_or_portal, $portals{$portalsID[$map_or_portal]}{'pos'}{'x'}, $portals{$portalsID[$map_or_portal]}{'pos'}{'y'});
					main::ai_route($field->baseName, $portals{$portalsID[$map_or_portal]}{'pos'}{'x'}, $portals{$portalsID[$map_or_portal]}{'pos'}{'y'}, attackOnRoute => 1, noSitAuto => 1);
				} else {
					error T("No portals exist.\n");
				}
			} else {
				# map
				$map_or_portal =~ s/^(\w{3})?(\d@.*)/$2/; # remove instance. is it possible to move to an instance? if not, we could throw an error here
				# TODO: implement Field::sourceName function here once they are implemented there - 2013.11.26
				my $file = $map_or_portal.'.fld';
				$file = File::Spec->catfile($Settings::fields_folder, $file) if ($Settings::fields_folder);
				$file .= ".gz" if (! -f $file); # compressed file
				if ($maps_lut{"${map_or_portal}.rsw"}) {
					if ($dist) {
						message TF("Calculating route to: %s(%s): %s, %s (Distance: %s)\n",
							$maps_lut{$map_or_portal.'.rsw'}, $map_or_portal, $x, $y, $dist), "route";
					} elsif ($x ne "") {
						message TF("Calculating route to: %s(%s): %s, %s\n",
							$maps_lut{$map_or_portal.'.rsw'}, $map_or_portal, $x, $y), "route";
					} else {
						message TF("Calculating route to: %s(%s)\n",
							$maps_lut{$map_or_portal.'.rsw'}, $map_or_portal), "route";
					}
					main::ai_route($map_or_portal, $x, $y,
						attackOnRoute => 1,
						noSitAuto => 1,
						notifyUponArrival => 1,
						distFromGoal => $dist);
				} elsif (-f $file) {
					# valid map
					my $map_name = $maps_lut{"${map_or_portal}.rsw"}?$maps_lut{"${map_or_portal}.rsw"}:
						T('Unknown Map');
					if ($dist) {
						message TF("Calculating route to: %s(%s): %s, %s (Distance: %s)\n",
							$map_name, $map_or_portal, $x, $y, $dist), "route";
					} elsif ($x ne "") {
						message TF("Calculating route to: %s(%s): %s, %s\n",
							$map_name, $map_or_portal, $x, $y), "route";
					} else {
						message TF("Calculating route to: %s(%s)\n",
							$map_name, $map_or_portal), "route";
					}
					main::ai_route($map_or_portal, $x, $y,
					attackOnRoute => 1,
					noSitAuto => 1,
					notifyUponArrival => 1,
					distFromGoal => $dist);
				} else {
					error TF("Map %s does not exist\n", $map_or_portal);
				}
			}
		}
	}
}

sub cmdNPCList {
	my (undef, $args) = @_;
	my @arg = parseArgs($args);
	my $msg = center(T(" NPC List "), 57, '-') ."\n".
		T("#    Name                         Coordinates   ID\n");
	if ($npcsList) {
		if ($arg[0] =~ /^\d+$/) {
			my $i = $arg[0];
			if (my $npc = $npcsList->get($i)) {
				my $pos = "($npc->{pos_to}{x}, $npc->{pos_to}{y})";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<   @<<<<<<<<",
					[$i, $npc->name, $pos, $npc->{nameID}]);
				$msg .= ('-'x57) . "\n";
				message $msg, "list";

			} else {
				error T("Syntax Error in function 'nl' (List NPCs)\n" .
					"Usage: nl [<npc #>]\n");
			}
			return;
		}

		my $npcs = $npcsList->getItems();
		foreach my $npc (@{$npcs}) {
			my $pos = "($npc->{pos}{x}, $npc->{pos}{y})";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<   @<<<<<<<<",
				[$npc->{binID}, $npc->name, $pos, $npc->{nameID}]);
		}
	}
	$msg .= ('-'x57) . "\n";
	message $msg, "list";
}

sub cmdOpenShop {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if ($config{'shop_useSkill'}) {
		# This method is responsible to NOT uses a bug in which openkore opens the shop,
		# using a vending skill and then open the shop
		my $skill = new Skill(auto => "MC_VENDING");

		require Task::UseSkill;
		my $skillTask = new Task::UseSkill(
			actor => $skill->getOwner,
			skill => $skill,
			priority => Task::USER_PRIORITY
		);
		my $task = new Task::Chained(
			name => 'openShop',
			tasks => [
				new Task::ErrorReport(task => $skillTask),
				Task::Timeout->new(
					function => sub {main::openShop()},
					seconds => $timeout{ai_shop_useskill_delay}{timeout} ? $timeout{ai_shop_useskill_delay}{timeout} : 5,
				)
			]
		);
		$taskManager->add($task);
	} else {
		# This method is responsible to uses a bug in which openkore opens the shop
		# without using a vending skill

		main::openShop();
	}
}

sub cmdParty {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = $args =~ /^(\w*)(?: (.+))?$/;
=pod
	my ($arg1) = $args =~ /^(\w*)/;
	my ($arg2) = $args =~ /^\w* (\S+)\b/;
=cut

	if ($arg1 eq "" && (!$char || !$char->{'party'} || !%{$char->{'party'}} )) {
		error T("Error in function 'party' (Party Functions)\n" .
			"Can't list party - you're not in a party.\n");
	} elsif ($arg1 eq "") {
		my $msg = center(T(" Party Information "), 79, '-') ."\n".
			TF("Party name: %s\n\n" .
			"#    Name                   Map           Coord     Online  HP\n",
			$char->{'party'}{'name'});
		for (my $i = 0; $i < @partyUsersID; $i++) {
			next if ($partyUsersID[$i] eq "");
			my $coord_string = "";
			my $hp_string = "";
			my $name_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'name'};
			my $admin_string = ($char->{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) ? "A" : "";
			my $online_string;
			my $map_string;

			if ($partyUsersID[$i] eq $accountID) {
				# Translation Comment: Is the party user on list online?
				$online_string = T("Yes");
				($map_string) = $field->name;
				$coord_string = $char->{'pos'}{'x'}. ", ".$char->{'pos'}{'y'};
				$hp_string = $char->{'hp'}."/".$char->{'hp_max'}
						." (".int($char->{'hp'}/$char->{'hp_max'} * 100)
						."%)";
			} else {
				$online_string = ($char->{'party'}{'users'}{$partyUsersID[$i]}{'online'}) ? T("Yes") : T("No");
				($map_string) = $char->{'party'}{'users'}{$partyUsersID[$i]}{'map'} =~ /([\s\S]*)\.gat/;
				$coord_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'}
					. ", ".$char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'y'}
					if ($char->{'party'}{'users'}{$partyUsersID[$i]}{'pos'}{'x'} ne ""
						&& $char->{'party'}{'users'}{$partyUsersID[$i]}{'online'});
				$hp_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'hp'}."/".$char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'}
					." (".int($char->{'party'}{'users'}{$partyUsersID[$i]}{'hp'}/$char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} * 100)
					."%)" if ($char->{'party'}{'users'}{$partyUsersID[$i]}{'hp_max'} && $char->{'party'}{'users'}{$partyUsersID[$i]}{'online'});
			}
			$msg .= swrite(
				"@< @ @<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<<  @<<     @<<<<<<<<<<<<<<<<<<",
				[$i, $admin_string, $name_string, $map_string, $coord_string, $online_string, $hp_string]);
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";

	} elsif (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'party ' .$arg1);
		return;

	} elsif ($arg1 eq "create") {
#		my ($arg2) = $args =~ /^\w* ([\s\S]*)/;
		if ($arg2 eq "") {
			error T("Syntax Error in function 'party create' (Organize Party)\n" .
				"Usage: party create <party name>\n");
		} else {
			$messageSender->sendPartyOrganize($arg2);
		}

	} elsif ($arg1 eq "join" && $arg2 ne "1" && $arg2 ne "0") {
		error T("Syntax Error in function 'party join' (Accept/Deny Party Join Request)\n" .
			"Usage: party join <flag>\n");
	} elsif ($arg1 eq "join" && $incomingParty{ID} eq "") {
		error T("Error in function 'party join' (Join/Request to Join Party)\n" .
			"Can't accept/deny party request - no incoming request.\n");
	} elsif ($arg1 eq "join") {
		if ($incomingParty{ACK} eq '02C7') {
			$messageSender->sendPartyJoinRequestByNameReply($incomingParty{ID}, $arg2);
		} else {
			$messageSender->sendPartyJoin($incomingParty{ID}, $arg2);
		}
		undef %incomingParty;
	} elsif ($arg1 eq "leave" && (!$char->{'party'} || !%{$char->{'party'}} ) ) {
		error T("Error in function 'party leave' (Leave Party)\n" .
			"Can't leave party - you're not in a party.\n");
	} elsif ($arg1 eq "leave") {
		$messageSender->sendPartyLeave();
	} elsif ($arg1 eq "request" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
		error T("Error in function 'party request' (Request to Join Party)\n" .
			"Can't request a join - you're not in a party.\n");
	} elsif ($arg1 eq "request") {
		unless ($arg2 =~ /\D/) {
			if ($playersID[$arg2] eq "") {
				error TF("Error in function 'party request' (Request to Join Party)\n" .
					"Can't request to join party - player %s does not exist.\n", $arg2);
			} else {
				$messageSender->sendPartyJoinRequest($playersID[$arg2]);
			}
		} else {
			message TF("Requesting player %s to join your party.\n", $arg2);
			$messageSender->sendPartyJoinRequestByName ($arg2);
		}
	# party leader specific commands
	} elsif ($arg1 eq "share" || $arg1 eq "shareitem" || $arg1 eq "sharediv" || $arg1 eq "kick" || $arg1 eq "leader") {
		my $party_admin;
		# check if we are the party leader before using leader specific commands.
		for (my $i = 0; $i < @partyUsersID; $i++) {
			if (($char->{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) && ($char->{'party'}{'users'}{$partyUsersID[$i]}{'name'} eq $char->name)){
				message T("You are the party leader.\n"), "info";
				$party_admin = 1;
			}
		}
		if (!$party_admin) {
			error TF("Error in function 'party %s'\n" .
			"You must be the party leader in order to use this !\n", $arg1);
			return;
		} elsif ($arg1 eq "share" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
			error T("Error in function 'party share' (Set Party Share EXP)\n" .
				"Can't set share - you're not in a party.\n");
		} elsif ($arg1 eq "share" && $arg2 ne "1" && $arg2 ne "0") {
			error T("Syntax Error in function 'party share' (Set Party Share EXP)\n" .
				"Usage: party share <flag>\n");
		} elsif ($arg1 eq "share") {
			$messageSender->sendPartyOption($arg2, $config{partyAutoShareItem}, $config{partyAutoShareItemDiv});

		} elsif ($arg1 eq "shareitem" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
			error T("Error in function 'party shareitem' (Set Party Share Item)\n" .
				"Can't set share - you're not in a party.\n");
		} elsif ($arg1 eq "shareitem" && $arg2 ne "1" && $arg2 ne "0") {
			error T("Syntax Error in function 'party shareitem' (Set Party Share Item)\n" .
				"Usage: party shareitem <flag>\n");
		} elsif ($arg1 eq "shareitem") {
			$messageSender->sendPartyOption($config{partyAutoShare}, $arg2, $config{partyAutoShareItemDiv});

		} elsif ($arg1 eq "sharediv" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
			error T("Error in function 'party share' (Set Party Share EXP)\n" .
				"Can't set share - you're not in a party.\n");
		} elsif ($arg1 eq "sharediv" && $arg2 ne "1" && $arg2 ne "0") {
			error T("Syntax Error in function 'party share' (Set Party Share EXP)\n" .
				"Usage: party share <flag>\n");
		} elsif ($arg1 eq "sharediv") {
			$messageSender->sendPartyOption($config{partyAutoShare}, $config{partyAutoShareItem}, $arg2);


		} elsif ($arg1 eq "kick" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
			error T("Error in function 'party kick' (Kick Party Member)\n" .
				"Can't kick member - you're not in a party.\n");
		} elsif ($arg1 eq "kick" && $arg2 eq "") {
			error T("Syntax Error in function 'party kick' (Kick Party Member)\n" .
				"Usage: party kick <party member #>\n");
		} elsif ($arg1 eq "kick" && $partyUsersID[$arg2] eq "") {
			error TF("Error in function 'party kick' (Kick Party Member)\n" .
				"Can't kick member - member %s doesn't exist.\n", $arg2);
		} elsif ($arg1 eq "kick") {
			$messageSender->sendPartyKick($partyUsersID[$arg2]
					,$char->{'party'}{'users'}{$partyUsersID[$arg2]}{'name'});

		} elsif ($arg1 eq "leader" && ( !$char->{'party'} || !%{$char->{'party'}} )) {
			error T("Error in function 'party leader' (Change Party Leader)\n" .
				"Can't change party leader - you're not in a party.\n");
		} elsif ($arg1 eq "leader" && ($arg2 eq "" || $arg2 !~ /\d/)) {
			error T("Syntax Error in function 'party leader' (Change Party Leader)\n" .
				"Usage: party leader <party member #>\n");
			} elsif ($arg1 eq "leader" && $partyUsersID[$arg2] eq "") {
			error TF("Error in function 'party leader' (Change Party Leader)\n" .
				"Can't change party leader - member %s doesn't exist.\n", $arg2);
		} elsif ($arg1 eq "leader") {
			$messageSender->sendPartyLeader($partyUsersID[$arg2]);
		}
	} else {
		error T("Syntax Error in function 'party' (Party Management)\n" .
			"Usage: party [<create|join|request|leave|share|shareitem|sharediv|kick|leader>]\n");
	}
}

sub cmdPecopeco {
	my (undef, $arg1) = @_;

	my $hasPecopeco = $char && $char->statusActive('EFFECTSTATE_CHICKEN');
	if ($arg1 eq "") {
		if ($hasPecopeco) {
			message T("Your Pecopeco is active\n");
		} else {
			message T("Your Pecopeco is inactive\n");
		}
	} elsif ($arg1 eq "release") {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", 'pecopeco release');
			return;
		}
		if (!$hasPecopeco) {
			error T("Error in function 'pecopeco release' (Remove Pecopeco Status)\n" .
				"You don't possess a Pecopeco.\n");
		} else {
			$messageSender->sendCompanionRelease();
		}
	}
}

sub cmdPet {
	my (undef, $args_string) = @_;
	my @args = parseArgs($args_string, 2);

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'pet ' .$args[0]);

	} elsif ($args[0] eq "c" || $args[0] eq "capture") {
		# todo: maybe make a match function for monsters?
		if ($args[1] =~ /^\d+$/) {
			if ($monstersID[$args[1]] eq "") {
				error TF("Error in function 'pet capture|c' (Capture Pet)\n" .
					"Monster %s does not exist.\n", $args[1]);
			} else {
				$messageSender->sendPetCapture($monstersID[$args[1]]);
			}
		} else {
			error TF("Error in function 'pet [capture|c]' (Capture Pet)\n" .
				"%s must be a monster index.\n", $args[1]);
		}

	} elsif ($args[0] eq "h" || $args[0] eq "hatch") {
		if(my $item = Match::inventoryItem($args[1])) {
			# beware, you must first use the item "Pet Incubator", else you will get disconnected
			$messageSender->sendPetHatch($item->{index});
		} else {
			error TF("Error in function 'pet [hatch|h] #' (Hatch Pet)\n" .
				"Egg: %s could not be found.\n", $args[1]);
		}

	} elsif ((!%pet||!$pet{hungry}) && defined $args[0]) {
		error T("Error in function 'pet' (Pet Management)\n" .
			"You don't have a pet.\n");

	} elsif ($args[0] eq "s" || $args[0] eq "status") {
		message center(T(" Pet Status "), 46, '-') ."\n".
			TF("Name: %-24s Renameable: %s\n",$pet{name}, ($pet{renameflag}?T("Yes"):T("No"))).
			TF("Type: %-24s Level: %s\n", monsterName($pet{type}), $pet{level}).
			TF("Accessory: %-19s Hungry: %s\n", itemNameSimple($pet{accessory}), $pet{hungry}).
			TF("                               Friendly: %s\n", $pet{friendly}).
			('-'x46) . "\n", "list";
	} elsif ($args[0] eq "i" || $args[0] eq "info") {
		$messageSender->sendPetMenu(0);

	} elsif ($args[0] eq "f" || $args[0] eq "feed") {
		$messageSender->sendPetMenu(1);

	} elsif ($args[0] eq "p" || $args[0] eq "performance") {
		$messageSender->sendPetMenu(2);

	} elsif ($args[0] eq "r" || $args[0] eq "return") {
		$messageSender->sendPetMenu(3);
		undef %pet; # todo: instead undef %pet when the actor (our pet) dissapears, this is safer (xkore)

	} elsif ($args[0] eq "u" || $args[0] eq "unequip") {
		$messageSender->sendPetMenu(4);

	} elsif (($args[0] eq "n" || $args[0] eq "name") && $args[1]) {
		$messageSender->sendPetName($args[1]);

	} else {
		message T("Usage: pet [capture|hatch|status|info|feed|performance|return|unequip|name <name>]\n"), "info";
	}
}

sub cmdPetList {
	my ($dist, $pos, $name, $pets);
	my $msg = center(T(" Pet List "), 68, '-') ."\n".
		T("#   Name                      Type             Distance  Coordinates\n");

	$pets = $petsList->getItems() if ($petsList);
	foreach my $pet (@{$pets}) {
		$dist = distance($char->{pos_to}, $pet->{pos_to});
		$dist = sprintf("%.1f", $dist) if (index($dist, '.') > -1);
		$pos = '(' . $pet->{pos_to}{x} . ', ' . $pet->{pos_to}{y} . ')';
		$name = $pet->name;

		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<<<<<<  @<<<<<    @<<<<<<<<<<",
			[$pet->{binID}, $name, monsterName($pet->{type}), $dist, $pos]);
	}
	$msg .= ('-'x68) . "\n";
	message $msg, "list";
}

sub cmdPlayerList {
	my (undef, $args) = @_;
	my $msg;

	if ($args eq "g") {
		my $maxpl;
		my $maxplg;
		$msg = center(T(" Guild Player List "), 79, '-') ."\n".
			T("#    Name                                Sex   Lv   Job         Dist Coord\n");
		if ($playersList) {
			foreach my $player (@{$playersList->getItems()}) {
				my ($name, $dist, $pos);
				$name = $player->name;

				if ($char->{guild}{name} eq ($player->{guild}{name})) {

					if ($player->{guild} && %{$player->{guild}}) {
						$name .= " [$player->{guild}{name}]";
					}
					$dist = distance($char->{pos_to}, $player->{pos_to});
					$dist = sprintf("%.1f", $dist) if (index ($dist, '.') > -1);
					$pos = '(' . $player->{pos_to}{x} . ', ' . $player->{pos_to}{y} . ')';

					$maxplg++;

					$msg .= swrite(
						"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<< @<<<<<<<<<< @<<< @<<<<<<<<<",
						[$player->{binID}, $name, $sex_lut{$player->{sex}}, $player->{lv}, $player->job, $dist, $pos]);
				}
				$maxpl = @{$playersList->getItems()};
			}
		}
		$msg .= TF("Total guild players: %s\n",$maxplg) if $maxplg;
		if ($maxpl ne "") {
			$msg .= TF("Total players: %s \n",$maxpl);
		} else {
			$msg .= T("There are no players near you.\n");
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";
		return;
	}

	if ($args eq "p") {
		my $maxpl;
		my $maxplp;
		$msg = center(T(" Party Player List "), 79, '-') ."\n".
			T("#    Name                                Sex   Lv   Job         Dist Coord\n");
		if ($playersList) {
			foreach my $player (@{$playersList->getItems()}) {
				my ($name, $dist, $pos);
				$name = $player->name;

				if ($char->{party}{name} eq ($player->{party}{name})) {

					if ($player->{guild} && %{$player->{guild}}) {
						$name .= " [$player->{guild}{name}]";
					}
					$dist = distance($char->{pos_to}, $player->{pos_to});
					$dist = sprintf("%.1f", $dist) if (index ($dist, '.') > -1);
					$pos = '(' . $player->{pos_to}{x} . ', ' . $player->{pos_to}{y} . ')';

					$maxplp++;

					$msg .= swrite(
						"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<< @<<<<<<<<<< @<<< @<<<<<<<<<",
						[$player->{binID}, $name, $sex_lut{$player->{sex}}, $player->{lv}, $player->job, $dist, $pos]);
				}
				$maxpl = @{$playersList->getItems()};
			}
		}
		$msg .= TF("Total party players: %s \n",$maxplp)  if $maxplp;
		if ($maxpl ne "") {
			$msg .= TF("Total players: %s \n",$maxpl);
		} else {
			$msg .= T("There are no players near you.\n");
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";
		return;
	}

	if ($args ne "") {
		my Actor::Player $player = Match::player($args) if ($playersList);
		if (!$player) {
			error TF("Player \"%s\" does not exist.\n", $args);
			return;
		}

		my $ID = $player->{ID};
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
		my $headTop = headgearName($player->{headgear}{top});
		my $headMid = headgearName($player->{headgear}{mid});
		my $headLow = headgearName($player->{headgear}{low});

		$msg = center(T(" Player Info "), 67, '-') ."\n" .
			$player->name . " (" . $player->{binID} . ")\n" .
		TF("Account ID: %s (Hex: %s)\n" .
			"Party: %s\n" .
			"Guild: %s\n" .
			"Guild title: %s\n" .
			"Position: %s, %s (%s of you: %s degrees)\n" .
			"Level: %-7d Distance: %-17s\n" .
			"Sex: %-6s    Class: %s\n\n" .
			"Body direction: %-19s Head direction:  %-19s\n" .
			"Weapon: %s\n" .
			"Shield: %s\n" .
			"Upper headgear: %-19s Middle headgear: %-19s\n" .
			"Lower headgear: %-19s Hair color:      %-19s\n" .
			"Walk speed: %s secs per block\n",
		$player->{nameID}, $hex,
		($player->{party} && $player->{party}{name} ne '') ? $player->{party}{name} : '',
		($player->{guild}) ? $player->{guild}{name} : '',
		($player->{guild}) ? $player->{guild}{title} : '',
		$pos->{x}, $pos->{y}, $directions_lut{$youToPlayer}, int($degYouToPlayer),
		$player->{lv}, $dist, $sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}},
		"$directions_lut{$body} ($body)", "$directions_lut{$head} ($head)",
		itemName({nameID => $player->{weapon}}),
		itemName({nameID => $player->{shield}}),
		$headTop, $headMid,
			  $headLow, "$haircolors{$player->{hair_color}} ($player->{hair_color})",
			  $player->{walk_speed});
		if ($player->{dead}) {
			$msg .= T("Player is dead.\n");
		} elsif ($player->{sitting}) {
			$msg .= T("Player is sitting.\n");
		}

		if ($degPlayerToYou >= $head * 45 - 29 && $degPlayerToYou <= $head * 45 + 29) {
			$msg .= T("Player is facing towards you.\n");
		}
		$msg .= TF("\nStatuses: %s \n", $player->statusesString);
		$msg .= '-' x 67 . "\n";
		message $msg, "info";
		return;
	}

	{
		my $maxpl;
		$msg = center(T(" Player List "), 79, '-') ."\n".
		T("#    Name                                Sex   Lv   Job         Dist Coord\n");
		if ($playersList) {
			foreach my $player (@{$playersList->getItems()}) {
				my ($name, $dist, $pos);
				$name = $player->name;
				if ($player->{guild} && %{$player->{guild}}) {
					$name .= " [$player->{guild}{name}]";
				}
				$dist = distance($char->{pos_to}, $player->{pos_to});
				$dist = sprintf("%.1f", $dist) if (index ($dist, '.') > -1);
				$pos = '(' . $player->{pos_to}{x} . ', ' . $player->{pos_to}{y} . ')';
				$maxpl = @{$playersList->getItems()};
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<< @<<<<<<<<<< @<<< @<<<<<<<<<",
					[$player->{binID}, $name, $sex_lut{$player->{sex}}, $player->{lv}, $player->job, $dist, $pos]);
			}
		}
		if ($maxpl ne "") {
			$msg .= TF("Total players: %s \n",$maxpl);
		} else	{$msg .= T("There are no players near you.\n");}
		$msg .= '-' x 79 . "\n";
		message $msg, "list";
	}
}

sub cmdPlugin {
	return if ($Settings::lockdown);
	my (undef, $input) = @_;
	my @args = split(/ +/, $input, 2);

	if (@args == 0) {
		my $msg = center(T(" Currently loaded plugins "), 79, '-') ."\n".
				T("#   Name                 Description\n");
		my $i = -1;
		foreach my $plugin (@Plugins::plugins) {
			$i++;
			next unless $plugin;
			$msg .= swrite(
				"@<< @<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $plugin->{name}, $plugin->{description}]);
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";

	} elsif ($args[0] eq 'reload') {
		my @names;

		if ($args[1] =~ /^\d+$/) {
			push @names, $Plugins::plugins[$args[1]]{name};

		} elsif ($args[1] eq '') {
			error T("Syntax Error in function 'plugin reload' (Reload Plugin)\n" .
				"Usage: plugin reload <plugin name|plugin number#|\"all\">\n");
			return;

		} elsif ($args[1] eq 'all') {
			foreach my $plugin (@Plugins::plugins) {
				next unless $plugin;
				push @names, $plugin->{name};
			}

		} else {
			foreach my $plugin (@Plugins::plugins) {
				next unless $plugin;
				if ($plugin->{name} =~ /$args[1]/i) {
					push @names, $plugin->{name};
				}
			}
			if (!@names) {
				error T("Error in function 'plugin reload' (Reload Plugin)\n" .
					"The specified plugin names do not exist.\n");
				return;
			}
		}

		foreach (my $i = 0; $i < @names; $i++) {
			Plugins::reload($names[$i]);
		}

	} elsif ($args[0] eq 'load') {
		if ($args[1] eq '') {
			error T("Syntax Error in function 'plugin load' (Load Plugin)\n" .
				"Usage: plugin load <filename|\"all\">\n");
			return;
		} elsif ($args[1] eq 'all') {
			Plugins::loadAll();
		} else {
			if (-e $args[1]) {
			# then search inside plugins folder !
				Plugins::load($args[1]);
			} elsif (-e $Plugins::current_plugin_folder."\\".$args[1]) {
				Plugins::load($Plugins::current_plugin_folder."\\".$args[1]);
			} elsif (-e $Plugins::current_plugin_folder."\\".$args[1].".pl") {
				# we'll try to add .pl ....
				Plugins::load($Plugins::current_plugin_folder."\\".$args[1].".pl");
			}
		}

	} elsif ($args[0] eq 'unload') {
		if ($args[1] =~ /^\d+$/) {
			if ($Plugins::plugins[$args[1]]) {
				my $name = $Plugins::plugins[$args[1]]{name};
				Plugins::unload($name);
				message TF("Plugin %s unloaded.\n", $name), "system";
			} else {
				error TF("'%s' is not a valid plugin number.\n", $args[1]);
			}

		} elsif ($args[1] eq '') {
			error T("Syntax Error in function 'plugin unload' (Unload Plugin)\n" .
				"Usage: plugin unload <plugin name|plugin number#|\"all\">\n");
			return;

		} elsif ($args[1] eq 'all') {
			Plugins::unloadAll();

		} else {
			foreach my $plugin (@Plugins::plugins) {
				next unless $plugin;
				if ($plugin->{name} =~ /$args[1]/i) {
					my $name = $plugin->{name};
					Plugins::unload($name);
					message TF("Plugin %s unloaded.\n", $name), "system";
				}
			}
		}

	} else {
		my $msg = center(T(" Plugin command syntax "), 79, '-') ."\n" .
			T("Command:                                              Description:\n" .
			" plugin                                                List loaded plugins\n" .
			" plugin load <filename>                                Load a plugin\n" .
			" plugin unload <plugin name|plugin number#|\"all\">      Unload a loaded plugin\n" .
			" plugin reload <plugin name|plugin number#|\"all\">      Reload a loaded plugin\n") .
			('-'x79) . "\n";
		if ($args[0] eq 'help') {
			message $msg, "info";
		} else {
			error T("Syntax Error in function 'plugin' (Control Plugins)\n");
			error $msg;
		}
	}
}

sub cmdPMList {
	my $msg = center(T(" PM List "), 30, '-') ."\n";
	for (my $i = 1; $i <= @privMsgUsers; $i++) {
		$msg .= swrite(
			"@<<< @<<<<<<<<<<<<<<<<<<<<<<<",
			[$i, $privMsgUsers[$i - 1]]);
	}
	$msg .= ('-'x30) . "\n";
	message $msg, "list";
}

sub cmdPortalList {
	my (undef, $args) = @_;
	my ($arg) = parseArgs($args,1);
	if ($arg eq '') {
		my $msg = center(T(" Portal List "), 52, '-') ."\n".
			T("#    Name                                Coordinates\n");
		for (my $i = 0; $i < @portalsID; $i++) {
			next if $portalsID[$i] eq "";
			my $portal = $portals{$portalsID[$i]};
			my $coords = "($portal->{pos}{x}, $portal->{pos}{y})";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<",
				[$i, $portal->{name}, $coords]);
		}
		$msg .= ('-'x52) . "\n";
		message $msg, "list";
	} elsif ($arg eq 'recompile') {
		Settings::loadByRegexp(qr/portals/);
		Misc::compilePortals() if Misc::compilePortals_check();
	} elsif ($arg =~ /^add (.*)$/) { #Manual adding portals
		#Command: portals add mora 56 25 bif_fild02 176 162
		#Command: portals add y_airport 143 43 y_airport 148 51 0 c r0 c r0
		debug "Input: $args\n";
		my ($srcMap, $srcX, $srcY, $dstMap, $dstX, $dstY, $seq) = $args =~ /^add ([a-zA-Z\_\-0-9]*) (\d{1,3}) (\d{1,3}) ([a-zA-Z\_\-0-9]*) (\d{1,3}) (\d{1,3})(.*)$/; #CHECKING
		my $srcfile = $srcMap.'.fld';
		$srcfile = File::Spec->catfile($Settings::fields_folder, $srcfile) if ($Settings::fields_folder);
		$srcfile .= ".gz" if (! -f $srcfile); # compressed file
		my $dstfile = $dstMap.'.fld';
		$dstfile = File::Spec->catfile($Settings::fields_folder, $dstfile) if ($Settings::fields_folder);
		$dstfile .= ".gz" if (! -f $dstfile); # compressed file
		error TF("Files '%s' or '%s' does not exist.\n", $srcfile, $dstfile) if (! -f $srcfile || ! -f $dstfile);
		if ($srcX > 0 && $srcY > 0 && $dstX > 0 && $dstY > 0
			&& -f $srcfile && -f $dstfile) { #found map and valid corrdinates	
			if ($seq) {
				message TF("Recorded new portal (destination): %s (%s, %s) -> %s (%s, %s) [%s]\n", $srcMap, $srcX, $srcY, $dstMap, $dstX, $dstY, $seq), "portalRecord";
				
				FileParsers::updatePortalLUT2(Settings::getTableFilename("portals.txt"),
					$srcMap, $srcX, $srcY,
					$dstMap, $dstX, $dstY,
					$seq);		
			} else {
				message TF("Recorded new portal (destination): %s (%s, %s) -> %s (%s, %s)\n", $srcMap, $srcX, $srcY, $dstMap, $dstX, $dstY), "portalRecord";
				
				FileParsers::updatePortalLUT(Settings::getTableFilename("portals.txt"),
					$srcMap, $srcX, $srcY,
					$dstMap, $dstX, $dstY);		
			}
		}
	}
}

sub cmdPrivateMessage {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($switch, $args) = @_;
	my ($user, $msg) = parseArgs($args, 2);

	if ($user eq "" || $msg eq "") {
		error T("Syntax Error in function 'pm' (Private Message)\n" .
			"Usage: pm (username) (message)\n       pm (<#>) (message)\n");
		return;

	} elsif ($user =~ /^\d+$/) {
		if ($user - 1 >= @privMsgUsers) {
			error TF("Error in function 'pm' (Private Message)\n" .
				"Quick look-up %s does not exist\n", $user);
		} elsif (!@privMsgUsers) {
			error T("Error in function 'pm' (Private Message)\n" .
				"You have not pm-ed anyone before\n");
		} else {
			$lastpm{msg} = $msg;
			$lastpm{user} = $privMsgUsers[$user - 1];
			sendMessage($messageSender, "pm", $msg, $privMsgUsers[$user - 1]);
		}

	} else {
		if (!defined binFind(\@privMsgUsers, $user)) {
			push @privMsgUsers, $user;
		}
		$lastpm{msg} = $msg;
		$lastpm{user} = $user;
		sendMessage($messageSender, "pm", $msg, $user);
	}
}

sub cmdQuit {
	quit();
}

sub cmdReload {
	my (undef, $args) = @_;
	if ($args eq '') {
		error T("Syntax Error in function 'reload' (Reload Configuration Files)\n" .
			"Usage: reload <name|\"all\">\n");
	} else {
		parseReload($args);
	}
}

sub cmdReloadCode {
	my (undef, $args) = @_;
	if ($args ne "") {
		Modules::addToReloadQueue(parseArgs($args));
	} else {
		Modules::reloadFile("$FindBin::RealBin/src/functions.pl");
	}
}

sub cmdReloadCode2 {
	my (undef, $args) = @_;
	if ($args ne "") {
		($args =~ /\.pm$/)?Modules::addToReloadQueue2($args):Modules::addToReloadQueue2($args.".pm");
	} else {
		Modules::reloadFile("$FindBin::RealBin/src/functions.pl");
	}
}

sub cmdRelog {
	my (undef, $arg) = @_;
	if (!$arg || $arg =~ /^\d+$/) {
		@cmdQueueList = ();
		$cmdQueue = 0;
		relog($arg);
	} elsif ($arg =~ /^\d+\.\.\d+$/) {
		# range support
		my @numbers = split(/\.\./, $arg);
		if ($numbers[0] > $numbers[1]) {
			error T("Invalid range in function 'relog'\n");
		} else {
			@cmdQueueList = ();
			$cmdQueue = 0;
			relog(rand($numbers[1] - $numbers[0])+$numbers[0]);
		}
	} else {
		error T("Syntax Error in function 'relog' (Log out then log in.)\n" .
			"Usage: relog [delay]\n");
	}
}

sub cmdRepair {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $listID) = @_;
	if ($listID =~ /^\d+$/) {
		if ($repairList->[$listID]) {
			$messageSender->sendRepairItem($repairList->[$listID]);
			my $name = itemNameSimple($repairList->[$listID]);
			message TF("Attempting to repair item: %s\n", $name);
		} else {
			error TF("Item with index: %s does either not exist in the 'Repair List' or the list is empty.\n", $listID);
		}
	} else {
		error T("Syntax Error in function 'repair' (Repair player's items.)\n" .
			"Usage: repair [Repair List index]\n");
	}
}

sub cmdRespawn {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	if ($char->{dead}) {
		$messageSender->sendRestart(0);
	} else {
		main::useTeleport(2);
	}
}

sub cmdSell {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my @args = parseArgs($_[1]);

	if ($args[0] eq "" && $talk{buyOrSell}) {
		$messageSender->sendNPCBuySellList($talk{ID}, 1);

	} elsif ($args[0] eq "list") {
		if (@sellList == 0) {
			message T("Your sell list is empty.\n"), "info";
		} else {
			my $msg = center(T(" Sell List "), 41, '-') ."\n".
				T("#   Item                           Amount\n");
			foreach my $item (@sellList) {
				$msg .= sprintf("%-3d %-30s %d\n", $item->{invIndex}, $item->{name}, $item->{amount});
			}
			$msg .= ('-'x41) . "\n";
			message $msg, "list";
		}

	} elsif ($args[0] eq "done") {
		if (@sellList == 0) {
			message T("Your sell list is empty.\n"), "info";
		} else {
			$messageSender->sendSellBulk(\@sellList);
			message TF("Sold %s items.\n", @sellList.""), "success";
			@sellList = ();
		}
	} elsif ($args[0] eq "cancel") {
		@sellList = ();
		message T("Sell list has been cleared.\n"), "info";

	} elsif ($args[0] eq "" || ($args[0] !~ /^\d+$/ && $args[0] !~ /[,\-]/)) {
		error T("Syntax Error in function 'sell' (Sell Inventory Item)\n" .
			"Usage: sell <inventory item index #> [<amount>]\n" .
			"       sell list\n" .
			"       sell done\n" .
			"       sell cancel\n");

	} else {
		my @items = Actor::Item::getMultiple($args[0]);
		if (@items > 0) {
			foreach my $item (@items) {
				my %obj;

				if (defined(findIndex(\@sellList, "invIndex", $item->{invIndex}))) {
					error TF("%s (%s) is already in the sell list.\n", $item->nameString, $item->{invIndex});
					next;
				}

				$obj{name} = $item->nameString();
				$obj{index} = $item->{index};
				$obj{invIndex} = $item->{invIndex};
				if (!$args[1] || $args[1] > $item->{amount}) {
					$obj{amount} = $item->{amount};
				} else {
					$obj{amount} = $args[1];
				}
				push @sellList, \%obj;
				message TF("Added to sell list: %s (%s) x %s\n", $obj{name}, $obj{invIndex}, $obj{amount}), "info";
			}
			message T("Type 'sell done' to sell everything in your sell list.\n"), "info";

		} else {
			error TF("Error in function 'sell' (Sell Inventory Item)\n" .
				"'%s' is not a valid item index #; no item has been added to the sell list.\n",
				$args[0]);
		}
	}
}

sub cmdSendRaw {
	if (!$net || $net->getState() == Network::NOT_CONNECTED) {
		error TF("You must be connected to the server to use this command (%s)\n", shift);
		return;
	}
	my (undef, $args) = @_;
	$messageSender->sendRaw($args);
}

sub cmdShopInfoSelf {
	if (!$shopstarted) {
		error T("You do not have a shop open.\n");
		return;
	}
	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	my $msg = center(" $shop{title} ", 79, '-') ."\n".
		T("#  Name                               Type            Amount        Price  Sold\n");
	my $priceAfterSale=0;
	my $i = 1;
	for my $item (@articles) {
		next unless $item;
		$msg .= swrite(
		   "@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<< @<<<< @>>>>>>>>>>>z @>>>>",
			[$i++, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{quantity}, formatNumber($item->{price}), $item->{sold}]);
		$priceAfterSale += ($item->{quantity} * $item->{price});
	}
	$msg .= "\n" .
		TF("You have earned: %sz.\n" .
		"Current zeny:    %sz.\n" .
		"Maximum earned:  %sz.\n" .
		"Maximum zeny:    %sz.\n",
		formatNumber($shopEarned), formatNumber($char->{zeny}),
		formatNumber($priceAfterSale), formatNumber($priceAfterSale + $char->{zeny})) .
		('-'x79) . "\n";
	message $msg, "list";
}

sub cmdBuyShopInfoSelf {
	if (!@selfBuyerItemList) {
		error T("You do not have a buying shop open.\n");
		return;
	}
	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	my $msg = center(" Buyer Shop ", 72, '-') ."\n".
		T("#   Name                               Type           Amount       Price\n");
	my $index = 0;
	for my $item (@selfBuyerItemList) {
		next unless $item;
		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>>>z",
			[$index, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{amount}, formatNumber($item->{price})]);
	}
	$msg .= ('-'x72) . "\n";
	message $msg, "list";
}

sub cmdSit {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	$ai_v{sitAuto_forcedBySitCommand} = 1;
	AI::clear("move", "route", "mapRoute");
	AI::clear("attack") unless ai_getAggressives();
	require Task::SitStand;
	my $task = new Task::ErrorReport(
		task => new Task::SitStand(
			actor => $char,
			mode => 'sit',
			priority => Task::USER_PRIORITY
		)
	);
	$taskManager->add($task);
	$ai_v{sitAuto_forceStop} = 0;
}

sub cmdSkills {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;
	if ($arg1 eq "") {
		if (!$char || !$char->{skills}) {
			error T("Syntax Error in function 'skills' (Skills Functions)\n" .
			"Skills list is not ready yet.\n");
			return;
		}
		my $msg = center(T(" Skill List "), 51, '-') ."\n".
			T("   # Skill Name                          Lv      SP\n");
		for my $handle (@skillsID) {
			my $skill = new Skill(handle => $handle);
			my $sp = $char->{skills}{$handle}{sp} || '';
			$msg .= swrite(
				"@>>> @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>    @>>>",
				[$skill->getIDN(), $skill->getName(), $char->getSkillLevel($skill), $sp]);
		}
		$msg .= TF("\nSkill Points: %d\n", $char->{points_skill});
		$msg .= ('-'x51) . "\n";
		message $msg, "list";

	} elsif ($arg1 eq "add" && $arg2 =~ /\d+/) {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", 'skills add');
			return;
		}
		my $skill = new Skill(idn => $arg2);
		if (!$skill->getIDN() || !$char->{skills}{$skill->getHandle()}) {
			error TF("Error in function 'skills add' (Add Skill Point)\n" .
				"Skill %s does not exist.\n", $arg2);
		} elsif ($char->{points_skill} < 1) {
			error TF("Error in function 'skills add' (Add Skill Point)\n" .
				"Not enough skill points to increase %s\n", $skill->getName());
		} elsif ($char->{skills}{$skill->getHandle()}{up} == 0) {
			error TF("Error in function 'skills add' (Add Skill Point)\n" .
				"Skill %s reached its maximum level or prerequisite not reached\n", $skill->getName());
		} else {
			$messageSender->sendAddSkillPoint($skill->getIDN());
		}

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		my $skill = new Skill(idn => $arg2);
		if (!$skill->getIDN()) {
			error TF("Error in function 'skills desc' (Skill Description)\n" .
				"Skill %s does not exist.\n", $arg2);
		} else {
			my $description = $skillsDesc_lut{$skill->getHandle()} || T("Error: No description available.\n");
			my $msg = center(T(" Skill Description "), 79, '=') ."\n".
						TF("Skill: %s\n\n", $skill->getName());
			$msg .= $description;
			$msg .= ('='x79) . "\n";
		message $msg, "info";
		}
	} else {
		error T("Syntax Error in function 'skills' (Skills Functions)\n" .
			"Usage: skills [<add | desc>] [<skill #>]\n");
	}
}

sub cmdSlaveList {
	my ($dist, $pos, $name, $slaves);
	my $msg = center(T(" Slave List "), 79, '-') ."\n".
		T("#   Name                                   Type         Distance    Coordinates\n");
	$slaves = $slavesList->getItems() if ($slavesList);
	foreach my $slave (@{$slaves}) {
		$dist = distance($char->{pos_to}, $slave->{pos_to});
		$dist = sprintf("%.1f", $dist) if (index($dist, '.') > -1);
		$pos = '(' . $slave->{pos_to}{x} . ', ' . $slave->{pos_to}{y} . ')';
		$name = $slave->name;
		if ($name ne $jobs_lut{$slave->{type}}) {
			$name .= ' [' . $jobs_lut{$slave->{type}} . ']';
		}

		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<< @<<<<<      @<<<<<<<<<<",
			[$slave->{binID}, $name, $slave->{actorType}, $dist, $pos]);
	}
	$msg .= ('-'x79) . "\n";
	message $msg, "list";
}

sub cmdSpells {
	my $msg = center(T(" Area Effects List "), 55, '-') ."\n".
			T("  # Type                 Source                   X   Y\n");
	for my $ID (@spellsID) {
		my $spell = $spells{$ID};
		next unless $spell;

		$msg .=  sprintf("%3d %-20s %-20s   %3d %3d\n", 
				$spell->{binID}, getSpellName($spell->{type}), main::getActorName($spell->{sourceID}), $spell->{pos}{x}, $spell->{pos}{y});
	}
	$msg .= ('-'x55) . "\n";
	message $msg, "list";
}

sub cmdStand {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	delete $ai_v{sitAuto_forcedBySitCommand};
	$ai_v{sitAuto_forceStop} = 1;
	require Task::SitStand;
	my $task = new Task::ErrorReport(
		task => new Task::SitStand(
			actor => $char,
			mode => 'stand',
			priority => Task::USER_PRIORITY
		)
	);
	$taskManager->add($task);
}

sub cmdStatAdd {
	# Add status point
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $arg) = @_;
	if ($arg ne "str" && $arg ne "agi" && $arg ne "vit" && $arg ne "int"
	 && $arg ne "dex" && $arg ne "luk") {
		error T("Syntax Error in function 'stat_add' (Add Status Point)\n" .
			"Usage: stat_add <str | agi | vit | int | dex | luk>\n");

	} elsif ($char->{'$arg'} >= 99 && !$config{statsAdd_over_99}) {
		error T("Error in function 'stat_add' (Add Status Point)\n" .
			"You cannot add more stat points than 99\n");

	} elsif ($char->{"points_$arg"} > $char->{'points_free'}) {
		error TF("Error in function 'stat_add' (Add Status Point)\n" .
			"Not enough status points to increase %s\n", $arg);

	} else {
		my $ID;
		if ($arg eq "str") {
			$ID = STATUS_STR;
		} elsif ($arg eq "agi") {
			$ID = STATUS_AGI;
		} elsif ($arg eq "vit") {
			$ID = STATUS_VIT;
		} elsif ($arg eq "int") {
			$ID = STATUS_INT;
		} elsif ($arg eq "dex") {
			$ID = STATUS_DEX;
		} elsif ($arg eq "luk") {
			$ID = STATUS_LUK;
		}

		$char->{$arg} += 1;
		$messageSender->sendAddStatusPoint($ID);
	}
}

sub cmdStats {
	if (!$char) {
		error T("Character stats information not yet available.\n");
		return;
	}
	my $guildName = $char->{guild} ? $char->{guild}{name} : T("None");
	my $msg = center(T(" Char Stats "), 44, '-') ."\n".
		swrite(TF(
		"Str: \@<<+\@<< #\@< Atk:  \@<<+\@<< Def:  \@<<+\@<<\n" .
		"Agi: \@<<+\@<< #\@< Matk: \@<<\@\@<< Mdef: \@<<+\@<<\n" .
		"Vit: \@<<+\@<< #\@< Hit:  \@<<     Flee: \@<<+\@<<\n" .
		"Int: \@<<+\@<< #\@< Critical: \@<< Aspd: \@<<\n" .
		"Dex: \@<<+\@<< #\@< Status Points: \@<<<\n" .
		"Luk: \@<<+\@<< #\@< Guild: \@<<<<<<<<<<<<<<<<<<<<<<<\n\n" .
		"Hair color: \@<<<<<<<<<<<<<<<<<\n" .
		"Walk speed: %.2f secs per block", $char->{walk_speed}),
		[$char->{'str'}, $char->{'str_bonus'}, $char->{'points_str'}, $char->{'attack'}, $char->{'attack_bonus'}, $char->{'def'}, $char->{'def_bonus'},
		$char->{'agi'}, $char->{'agi_bonus'}, $char->{'points_agi'}, $char->{'attack_magic_min'}, '~', $char->{'attack_magic_max'}, $char->{'def_magic'}, $char->{'def_magic_bonus'},
		$char->{'vit'}, $char->{'vit_bonus'}, $char->{'points_vit'}, $char->{'hit'}, $char->{'flee'}, $char->{'flee_bonus'},
		$char->{'int'}, $char->{'int_bonus'}, $char->{'points_int'}, $char->{'critical'}, $char->{'attack_speed'},
		$char->{'dex'}, $char->{'dex_bonus'}, $char->{'points_dex'}, $char->{'points_free'},
		$char->{'luk'}, $char->{'luk_bonus'}, $char->{'points_luk'}, $guildName,
		"$haircolors{$char->{hair_color}} ($char->{hair_color})"]);

	$msg .= T("You are sitting.\n") if $char->{sitting};
	$msg .= ('-'x44) . "\n";
	message $msg, "info";
}

sub cmdStatus {
	# Display character status
	my ($baseEXPKill, $jobEXPKill);

	if (!$char) {
		error T("Character status information not yet available.\n");
		return;
	}

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
	$job_name_string = "$jobs_lut{$char->{'jobID'}} ($sex_lut{$char->{'sex'}})";
	$zeny_string = formatNumber($char->{'zeny'}) if (defined($char->{'zeny'}));

	my $dmgpsec_string = sprintf("%.2f", $dmgpsec);
	my $totalelasped_string = sprintf("%.2f", $totalelasped);
	my $elasped_string = sprintf("%.2f", $elasped);

	my $msg = center(T(" Status "), 56, '-') ."\n" .
		swrite(
		TF("\@<<<<<<<<<<<<<<<<<<<<<<<         HP: \@>>>>>>>>>>>>>>>>>>\n" .
		"\@<<<<<<<<<<<<<<<<<<<<<<<         SP: \@>>>>>>>>>>>>>>>>>>\n" .
		"Base: \@<<    \@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n" .
		"Job : \@<<    \@>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n" .
		"Zeny: \@<<<<<<<<<<<<<<<<<     Weight: \@>>>>>>>>>>>>>>>>>>\n" .
		"Statuses: %s\n" .
		"Spirits/Coins/Amulets: %s\n\n" .
		"Total Damage: \@<<<<<<<<<<<<< Dmg/sec: \@<<<<<<<<<<<<<<\n" .
		"Total Time spent (sec): \@>>>>>>>>\n" .
		"Last Monster took (sec): \@>>>>>>>",
		$char->statusesString, (exists $char->{spirits} && $char->{spirits} != 0 ? ($char->{amuletType} ? $char->{spirits} . "\tType: " . $char->{amuletType} : $char->{spirits}) : 0)),
		[$char->{'name'}, $hp_string, $job_name_string, $sp_string,
		$char->{'lv'}, $base_string, $char->{'lv_job'}, $job_string, $zeny_string, $weight_string,
		$totaldmg, $dmgpsec_string, $totalelasped_string, $elasped_string]).
		('-'x56) . "\n";

	message $msg, "info";
}

sub cmdStorage {
	if ($char->storage->isOpenedThisSession()) {
		my (undef, $args) = @_;

		my ($switch, $items) = split(' ', $args, 2);
		if (!$switch || $switch eq 'eq' || $switch eq 'u' || $switch eq 'nu') {
			cmdStorage_list($switch);
		} elsif ($switch eq 'log') {
			cmdStorage_log();
		} elsif ($switch eq 'desc') {
			cmdStorage_desc($items);
		} elsif ($switch eq 'add' || $switch eq 'addfromcart' || $switch eq 'get' || $switch eq 'gettocart' || $switch eq 'close') {
			if ($char->storage->isOpened()) {
				if ($switch eq 'add') {
					cmdStorage_add($items);
				} elsif ($switch eq 'addfromcart') {
					cmdStorage_addfromcart($items);
				} elsif ($switch eq 'get') {
					cmdStorage_get($items);
				} elsif ($switch eq 'gettocart') {
					cmdStorage_gettocart($items);
				} elsif ($switch eq 'close') {
					cmdStorage_close();
				}
			} else {
				error T("Cannot get/add/close storage because storage is not opened\n");
			}
		} else {
			error T("Syntax Error in function 'storage' (Storage Functions)\n" .
				"Usage: storage [<eq|u|nu>]\n" .
				"       storage close\n" .
				"       storage add <inventory_item> [<amount>]\n" .
				"       storage addfromcart <cart_item> [<amount>]\n" .
				"       storage get <storage_item> [<amount>]\n" .
				"       storage gettocart <storage_item> [<amount>]\n" .
				"       storage desc <storage_item_#>\n".
				"       storage log\n");
		}
	} else {
		error T("No information about storage; it has not been opened before in this session\n");
	}
}

sub cmdStorage_add {
	my $items = shift;

	my ($name, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my $item = Match::inventoryItem($name);
	if (!$item) {
		error TF("Inventory Item '%s' does not exist.\n", $name);
		return;
	}

	if ($item->{equipped}) {
		error TF("Inventory Item '%s' is equipped.\n", $name);
		return;
	}

	if (!defined($amount) || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	$messageSender->sendStorageAdd($item->{index}, $amount);
}

sub cmdStorage_addfromcart {
	my $items = shift;

	my ($name, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my $item = Match::cartItem($name);
	if (!$item) {
		error TF("Cart Item '%s' does not exist.\n", $name);
		return;
	}

	if (!defined($amount) || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	$messageSender->sendStorageAddFromCart($item->{index}, $amount);
}

sub cmdStorage_get {
	my $items = shift;

	my ($names, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my @names = split(',', $names);
	my @items;

	for my $name (@names) {
		if ($name =~ /^(\d+)\-(\d+)$/) {
			for my $i ($1..$2) {
				my $item = $char->storage->get($i);
				#push @items, $item->{index} if ($item);
				push @items, $item if ($item);
			}

		} else {
			my $item = Match::storageItem($name);
			if (!$item) {
				error TF("Storage Item '%s' does not exist.\n", $name);
				next;
			}
			#push @items, $item->{index};
			push @items, $item;
		}
	}

	storageGet(\@items, $amount) if @items;
}

sub cmdStorage_gettocart {
	my $items = shift;

	my ($name, $amount) = $items =~ /^(.*?)(?: (\d+))?$/;
	my $item = Match::storageItem($name);
	if (!$item) {
		error TF("Storage Item '%s' does not exist.\n", $name);
		return;
	}

	if (!defined($amount) || $amount > $item->{amount}) {
		$amount = $item->{amount};
	}
	
	if (!$char->cartActive) {
		error T("Error in function 'storage_gettocart' (Cart Management)\n" .
			"You do not have a cart.\n");
		return;
	}
	$messageSender->sendStorageGetToCart($item->{index}, $amount);
}

sub cmdStorage_close {
	$messageSender->sendStorageClose();
}

sub cmdStorage_log {
	writeStorageLog(1);
}

sub cmdStorage_desc {
	my $items = shift;
	my $item = Match::storageItem($items);
	if (!$item) {
		error TF("Error in function 'storage desc' (Show Storage Item Description)\n" .
			"Storage Item %s does not exist.\n", $items);
	} else {
		printItemDesc($item->{nameID});
	}
}

sub cmdStore {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 eq "" && !$talk{'buyOrSell'}) {
		my $msg = center(TF(" Store List (%s) ", $storeList[0]{npcName}), 54, '-') ."\n".
			T("#  Name                    Type                  Price\n");
		my $display;
		for (my $i = 0; $i < @storeList; $i++) {
			$display = $storeList[$i]{'name'};
			$msg .= swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<  @>>>>>>>>>z",
				[$i, $display, $itemTypes_lut{$storeList[$i]{'type'}}, $storeList[$i]{'price'}]);
		}
	$msg .= "Store list is empty.\n" if !$display;
	$msg .= ('-'x54) . "\n";
	message $msg, "list";

	} elsif ($arg1 eq "" && $talk{'buyOrSell'}
	 && ($net && $net->getState() == Network::IN_GAME)) {
		$messageSender->sendNPCBuySellList($talk{'ID'}, 0);

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && !$storeList[$arg2]) {
		error TF("Error in function 'store desc' (Store Item Description)\n" .
			"Store item %s does not exist\n", $arg2);
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		printItemDesc($storeList[$arg2]{nameID});

	} else {
		error T("Syntax Error in function 'store' (Store Functions)\n" .
			"Usage: store [<desc>] [<store item #>]\n");
	}
}

sub cmdSwitchConf {
	my (undef, $filename) = @_;
	if (!defined $filename) {
		error T("Syntax Error in function 'switchconf' (Switch Configuration File)\n" .
			"Usage: switchconf <filename>\n");
	} elsif (! -f $filename) {
		error TF("Syntax Error in function 'switchconf' (Switch Configuration File)\n" .
			"File %s does not exist.\n", $filename);
	} else {
		switchConfigFile($filename);
		message TF("Switched config file to \"%s\".\n", $filename), "system";
	}
}

sub cmdTake {
	my (undef, $arg1) = @_;
	if ($arg1 eq "") {
		error T("Syntax Error in function 'take' (Take Item)\n" .
			"Usage: take <item #>\n");
	} elsif ($arg1 eq "first" && scalar(keys(%items)) == 0) {
		error T("Error in function 'take first' (Take Item)\n" .
			"There are no items near.\n");
	} elsif ($arg1 eq "first") {
		my @keys = keys %items;
		AI::take($keys[0]);
	} elsif (!$itemsID[$arg1]) {
		error TF("Error in function 'take' (Take Item)\n" .
			"Item %s does not exist.\n", $arg1);
	} else {
		main::take($itemsID[$arg1]);
	}
}

sub cmdTalk {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	$args =~ s/^\w+\s+//;
	my $arg2;
	if ($args =~ /^(-?\d+)/) {
		$arg2 = $1;
	} else {
		($arg2) = $args =~ /^(\/.*?\/\w?)$/;
	}
	if ($arg1 =~ /^\d+$/ && $npcsID[$arg1] eq "") {
		error TF("Error in function 'talk' (Talk to NPC)\n" .
			"NPC %s does not exist\n", $arg1);
	} elsif ($arg1 =~ /^\d+$/) {
		AI::clear("route");
		$messageSender->sendTalk($npcsID[$arg1]);

	} elsif (($arg1 eq "resp" || $arg1 eq "num" || $arg1 eq "text") && !%talk) {
		error TF("Error in function 'talk %s' (Respond to NPC)\n" .
			"You are not talking to any NPC.\n", $arg1);

	} elsif ($arg1 eq "resp" && $arg2 eq "") {
		if (!$talk{'responses'}) {
		error T("Error in function 'talk resp' (Respond to NPC)\n" .
			"No NPC response list available.\n");
			return;
		}
		my $msg = center(T(" Responses (").getNPCName($talk{ID}).") ", 40, '-') ."\n" .
			TF("#  Response\n");
		for (my $i = 0; $i < @{$talk{'responses'}}; $i++) {
			$msg .= swrite(
			"@< @*",
			[$i, $talk{responses}[$i]]);
		}
		$msg .= ('-'x40) . "\n";
		message $msg, "list";
	} elsif ($arg1 eq "resp" && $arg2 =~ /^\/(.*?)\/(\w?)$/) {
		my $regex = $1;
		my $postCondition = $2;
		my $index = 1;
		foreach my $testResponse (@{$talk{'responses'}}) {
			if ($testResponse =~ /$regex/ || ($postCondition eq 'i' && $testResponse =~ /$regex/i)) {
				$messageSender->sendTalkResponse($talk{'ID'}, $index);
				return;
			}
		} continue {
			$index++;
		}
		error TF("Error in function 'talk resp' (Respond to NPC)\n" .
			"No match was found on responses with regex %s .\n", $regex);
	} elsif ($arg1 eq "resp" && $arg2 ne "" && $talk{'responses'}[$arg2] eq "") {
		error TF("Error in function 'talk resp' (Respond to NPC)\n" .
			"Response %s does not exist.\n", $arg2);

	} elsif ($arg1 eq "resp" && $arg2 ne "") {
		if ($talk{'responses'}[$arg2] eq T("Cancel Chat")) {
			$arg2 = 255;
		} else {
			$arg2 += 1;
		}
		$messageSender->sendTalkResponse($talk{'ID'}, $arg2);

	} elsif ($arg1 eq "num" && $arg2 eq "") {
		error T("Error in function 'talk num' (Respond to NPC)\n" .
			"You must specify a number.\n");

	} elsif ($arg1 eq "num" && !($arg2 =~ /^-?\d+$/)) {
		error TF("Error in function 'talk num' (Respond to NPC)\n" .
			"%s is not a valid number.\n", $arg2);

	} elsif ($arg1 eq "num" && $arg2 =~ /^-?\d+$/) {
		$messageSender->sendTalkNumber($talk{'ID'}, $arg2);

	} elsif ($arg1 eq "text") {
		if ($args eq "") {
			error T("Error in function 'talk text' (Respond to NPC)\n" .
				"You must specify a string.\n");
		} else {
			$messageSender->sendTalkText($talk{'ID'}, $args);
		}

	} elsif ($arg1 eq "cont" && !%talk) {
		error T("Error in function 'talk cont' (Continue Talking to NPC)\n" .
			"You are not talking to any NPC.\n");

	} elsif ($arg1 eq "cont") {
		$messageSender->sendTalkContinue($talk{'ID'});

	} elsif ($arg1 eq "no") {
		if (!%talk) {
			error T("You are not talking to any NPC.\n");
		} elsif ($ai_v{npc_talk}{talk} eq 'select') {
			$messageSender->sendTalkResponse($talk{ID}, 255);
		} elsif (!$talk{canceled}) {
			$messageSender->sendTalkCancel($talk{ID});
			$talk{canceled} = 1;
		}

	} else {
		error T("Syntax Error in function 'talk' (Talk to NPC)\n" .
			"Usage: talk <NPC # | cont | resp | num | text | no> [<response #>|<number #>]\n");
	}
}

sub cmdTalkNPC {
	my (undef, $args) = @_;

	my ($x, $y, $sequence) = $args =~ /^(\d+) (\d+) (.+)$/;
	unless (defined $x) {
		error T("Syntax Error in function 'talknpc' (Talk to an NPC)\n" .
			"Usage: talknpc <x> <y> <sequence>\n");
		return;
	}

	message TF("Talking to NPC at (%d, %d) using sequence: %s\n", $x, $y, $sequence);
	main::ai_talkNPC($x, $y, $sequence);
}

sub cmdTank {
	my (undef, $arg) = @_;
	$arg =~ s/ .*//;

	if ($arg eq "") {
		error T("Syntax Error in function 'tank' (Tank for a Player/Slave)\n" .
			"Usage: tank <player #|player name|\@homunculus|\@mercenary>\n");

	} elsif ($arg eq "stop") {
		configModify("tankMode", 0);

	} elsif ($arg =~ /^\d+$/) {
		if (!$playersID[$arg]) {
			error TF("Error in function 'tank' (Tank for a Player)\n" .
				"Player %s does not exist.\n", $arg);
		} else {
			configModify("tankMode", 1);
			configModify("tankModeTarget", $players{$playersID[$arg]}{name});
		}

	} else {
		my $name;
		for (@{$playersList->getItems}, @{$slavesList->getItems}) {
			if (lc $_->{name} eq lc $arg) {
				$name = $_->{name};
				last;
			} elsif($char->{homunculus} && $_->{ID} eq $char->{homunculus}{ID} && $arg eq '@homunculus' ||
					$char->{mercenary} && $_->{ID} eq $char->{mercenary}{ID} && $arg eq '@mercenary') {
					$name = $arg;
				last;
			}
		}

		if ($name) {
			configModify("tankMode", 1);
			configModify("tankModeTarget", $name);
		} else {
			error TF("Error in function 'tank' (Tank for a Player/Slave)\n" .
				"Player/Slave %s does not exist.\n", $arg);
		}
	}
}

sub cmdTeleport {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d)/;
	$arg1 = 1 unless $arg1;
	main::useTeleport($arg1);
}

sub cmdTestShop {
	my @items = main::makeShop();
	return unless @items;
	my @shopnames = split(/;;/, $shop{title_line});
	$shop{title} = $shopnames[int rand($#shopnames + 1)];
	$shop{title} = ($config{shopTitleOversize}) ? $shop{title} : substr($shop{title},0,36);

	my $msg = center(" $shop{title} ", 69, '-') ."\n".
			T("Name                                           Amount           Price\n");
	for my $item (@items) {
		$msg .= swrite("@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<  @>>>>>>>>>>>>z",
			[$item->{name}, $item->{amount}, formatNumber($item->{price})]);
	}
	$msg .= "\n" . TF("Total of %d items to sell.\n", binSize(\@items)) .
			('-'x69) . "\n";
	message $msg, "list";
}

sub cmdTimeout {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+\s+([\s\S]+)\s*$/;
	if ($arg1 eq "") {
		error T("Syntax Error in function 'timeout' (set a timeout)\n" .
			"Usage: timeout <type> [<seconds>]\n");
	} elsif ($timeout{$arg1} eq "") {
		error TF("Error in function 'timeout' (set a timeout)\n" .
			"Timeout %s doesn't exist\n", $arg1);
	} elsif ($arg2 eq "") {
		message TF("Timeout '%s' is %s\n",
			$arg1, $timeout{$arg1}{timeout}), "info";
	} else {
		setTimeout($arg1, $arg2);
	}
}

sub cmdTop10 {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args;

	if ($arg1 eq "") {
		message T("Function 'top10' (Show Top 10 Lists)\n" .
			"Usage: top10 <b|a|t|p> | <black|alche|tk|pk> | <blacksmith|alchemist|taekwon|pvp>\n");
	} elsif ($arg1 eq "a" || $arg1 eq "alche" || $arg1 eq "alchemist") {
		$messageSender->sendTop10Alchemist();
	} elsif ($arg1 eq "b" || $arg1 eq "black" || $arg1 eq "blacksmith") {
		$messageSender->sendTop10Blacksmith();
	} elsif ($arg1 eq "p" || $arg1 eq "pk" || $arg1 eq "pvp") {
		$messageSender->sendTop10PK();
	} elsif ($arg1 eq "t" || $arg1 eq "tk" || $arg1 eq "taekwon") {
		$messageSender->sendTop10Taekwon();
	} else {
		error T("Syntax Error in function 'top10' (Show Top 10 Lists)\n" .
			"Usage: top10 <b|a|t|p> |\n" .
			"             <black|alche|tk|pk> |\n".
			"             <blacksmith|alchemist|taekwon|pvp>\n");
	}
}

sub cmdUnequip {

	# unequip an item
	my (undef, $args) = @_;
	my ($arg1,$arg2) = $args =~ /^(\S+)\s*(.*)/;
	my $slot;
	my $item;

	if ($arg1 eq "") {
		cmdEquip_list();
		return;
	}

	if ($arg1 eq "slots") {
		# Translation Comment: List of equiped items on each slot
		message T("Slots:\n") . join("\n", @Actor::Item::slots). "\n", "list";
		return;
	}

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'eq ' .$args);
		return;
	}

	if ($equipSlot_rlut{$arg1}) {
		$slot = $arg1;
	} else {
		$arg1 .= " $arg2" if $arg2;
	}

	$item = Actor::Item::get(defined $slot ? $arg2 : $arg1, undef, 0);

	if (!$item) {
		$args =~ s/^($slot)\s//g if ($slot);
		$slot = T("undefined") unless ($slot);
		error TF("No such equipped Inventory Item: %s in slot: %s\n", $args, $slot);
		return;
	}

	if (!$item->{type_equip} && $item->{type} != 10 && $item->{type} != 16 && $item->{type} != 17) {
		error TF("Inventory Item %s (%s) can't be unequipped.\n",
			$item->{name}, $item->{invIndex});
		return;
	}
	if ($slot) {
		$item->unequipFromSlot($slot);
	} else {
		$item->unequip();
	}
}

sub cmdUseItemOnMonster {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;

	if ($arg1 eq "" || $arg2 eq "") {
		error T("Syntax Error in function 'im' (Use Item on Monster)\n" .
			"Usage: im <item #> <monster #>\n");
	} elsif (!$char->inventory->get($arg1)) {
		error TF("Error in function 'im' (Use Item on Monster)\n" .
			"Inventory Item %s does not exist.\n", $arg1);
	} elsif ($monstersID[$arg2] eq "") {
		error TF("Error in function 'im' (Use Item on Monster)\n" .
			"Monster %s does not exist.\n", $arg2);
	} else {
		$char->inventory->get($arg1)->use($monstersID[$arg2]);
	}
}

sub cmdUseItemOnPlayer {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;
	if ($arg1 eq "" || $arg2 eq "") {
		error T("Syntax Error in function 'ip' (Use Item on Player)\n" .
			"Usage: ip <item #> <player #>\n");
	} elsif (!$char->inventory->get($arg1)) {
		error TF("Error in function 'ip' (Use Item on Player)\n" .
			"Inventory Item %s does not exist.\n", $arg1);
	} elsif ($playersID[$arg2] eq "") {
		error TF("Error in function 'ip' (Use Item on Player)\n" .
			"Player %s does not exist.\n", $arg2);
	} else {
		$char->inventory->get($arg1)->use($playersID[$arg2]);
	}
}

sub cmdUseItemOnSelf {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	if ($args eq "") {
		error T("Syntax Error in function 'is' (Use Item on Yourself)\n" .
			"Usage: is <item>\n");
		return;
	}
	my $item = Actor::Item::get($args);
	if (!$item) {
		error TF("Error in function 'is' (Use Item on Yourself)\n" .
			"Inventory Item %s does not exist.\n", $args);
		return;
	}
	$item->use;
}

sub cmdUseSkill {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $args_string) = @_;
	my ($target, $actorList, $skill, $level) = @_;
	my @args = parseArgs($args_string);

	if ($cmd eq 'sl') {
		my $x = $args[1];
		my $y = $args[2];
		if (@args < 3 || @args > 4) {
			error T("Syntax error in function 'sl' (Use Skill on Location)\n" .
				"Usage: sl <skill #> <x> <y> [level]\n");
			return;
		} elsif ($x !~ /^\d+$/ || $y !~ /^\d+/) {
			error T("Error in function 'sl' (Use Skill on Location)\n" .
				"Invalid coordinates given.\n");
			return;
		} else {
			$target = { x => $x, y => $y };
			$level = $args[3];
		}
		# This was the code for choosing a random location when x and y are not given:
		# my $pos = calcPosition($char);
		# my @positions = calcRectArea($pos->{x}, $pos->{y}, int(rand 2) + 2);
		# $pos = $positions[rand(@positions)];
		# ($x, $y) = ($pos->{x}, $pos->{y});

	} elsif ($cmd eq 'ss') {
		if (@args < 1 || @args > 2) {
			error T("Syntax error in function 'ss' (Use Skill on Self)\n" .
				"Usage: ss <skill #> [level]\n");
			return;
		} else {
			$target = $char;
			$level = $args[1];
		}

	} elsif ($cmd eq 'sp') {
		if (@args < 2 || @args > 3) {
			error T("Syntax error in function 'sp' (Use Skill on Player)\n" .
				"Usage: sp <skill #> <player #> [level]\n");
			return;
		} else {
			$target = Match::player($args[1], 1);
			if (!$target) {
				error TF("Error in function 'sp' (Use Skill on Player)\n" .
					"Player '%s' does not exist.\n", $args[1]);
				return;
			}
			$actorList = $playersList;
			$level = $args[2];
		}

	} elsif ($cmd eq 'sm') {
		if (@args < 2 || @args > 3) {
			error T("Syntax error in function 'sm' (Use Skill on Monster)\n" .
				"Usage: sm <skill #> <monster #> [level]\n");
			return;
		} else {
			$target = $monstersList->get($args[1]);
			if (!$target) {
				error TF("Error in function 'sm' (Use Skill on Monster)\n" .
					"Monster %d does not exist.\n", $args[1]);
				return;
			}
			$actorList = $monstersList;
			$level = $args[2];
		}

	} elsif ($cmd eq 'ssl') {
		if (@args < 2 || @args > 3) {
			error T("Syntax error in function 'ssl' (Use Skill on Slave)\n" .
				"Usage: ssl <skill #> <slave #> [level]\n");
			return;
		} else {
			$target = $slavesList->get($args[1]);
			if (!$target) {
				error TF("Error in function 'ssl' (Use Skill on Slave)\n" .
					"Slave %d does not exist.\n", $args[1]);
				return;
			}
			$actorList = $slavesList;
			$level = $args[2];
		}

	} elsif ($cmd eq 'ssp') {
		if (@args < 2 || @args > 3) {
			error T("Syntax error in function 'ssp' (Use Skill on Area Spell Location)\n" .
				"Usage: ssp <skill #> <spell #> [level]\n");
			return;
		}
		my $targetID = $spellsID[$args[1]];
		if (!$targetID) {
			error TF("Spell %d does not exist.\n", $args[1]);
			return;
		}
		my $pos = $spells{$targetID}{pos_to};
		$target = { %{$pos} };
	}

	$skill = new Skill(auto => $args[0], level => $level);

	require Task::UseSkill;
	my $skillTask = new Task::UseSkill(
		actor => $skill->getOwner,
		target => $target,
		actorList => $actorList,
		skill => $skill,
		priority => Task::USER_PRIORITY
	);
	my $task = new Task::ErrorReport(task => $skillTask);
	$taskManager->add($task);
}

sub cmdVender {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\d\w]+)/;
	my ($arg2) = $args =~ /^[\d\w]+ (\d+)/;
	my ($arg3) = $args =~ /^[\d\w]+ \d+ (\d+)/;
	if ($arg1 eq "") {
		error T("Syntax error in function 'vender' (Vender Shop)\n" .
			"Usage: vender <vender # | end> [<item #> <amount>]\n");
	} elsif ($arg1 eq "end") {
		undef @venderItemList;
		undef $venderID;
		undef $venderCID;
	} elsif ($venderListsID[$arg1] eq "") {
		error TF("Error in function 'vender' (Vender Shop)\n" .
			"Vender %s does not exist.\n", $arg1);
	} elsif ($arg2 eq "") {
		$messageSender->sendEnteringVender($venderListsID[$arg1]);
	} elsif ($venderListsID[$arg1] ne $venderID) {
		error T("Error in function 'vender' (Vender Shop)\n" .
			"Vender ID is wrong.\n");
	} else {
		if ($arg3 <= 0) {
			$arg3 = 1;
		}
		$messageSender->sendBuyBulkVender($venderID, [{itemIndex  => $arg2, amount => $arg3}], $venderCID);
	}
}

sub cmdVenderList {
	my $msg = center(T(" Vender List "), 75, '-') ."\n".
		T("#    Title                                 Coords      Owner\n");
	for (my $i = 0; $i < @venderListsID; $i++) {
		next if ($venderListsID[$i] eq "");
		my $player = Actor::get($venderListsID[$i]);
		# autovivifies $obj->{pos_to} but it doesnt matter
		$msg .= sprintf(
			"%-3d  %-36s  (%3s, %3s)  %-20s\n",
			$i, $venderLists{$venderListsID[$i]}{'title'},
			$player->{pos_to}{x} || '?', $player->{pos_to}{y} || '?', $player->name);
	}
	$msg .= ('-'x75) . "\n";
	message $msg, "list";
}

sub cmdBuyerList {
	my $msg = center(T(" Buyer List "), 75, '-') ."\n".
		T("#    Title                                 Coords      Owner\n");
	for (my $i = 0; $i < @buyerListsID; $i++) {
		next if ($buyerListsID[$i] eq "");
		my $player = Actor::get($buyerListsID[$i]);
		# autovivifies $obj->{pos_to} but it doesnt matter
		$msg .= sprintf(
			"%-3d  %-36s  (%3s, %3s)  %-20s\n",
			$i, $buyerLists{$buyerListsID[$i]}{'title'},
			$player->{pos_to}{x} || '?', $player->{pos_to}{y} || '?', $player->name);
	}
	$msg .= ('-'x75) . "\n";
	message $msg, "list";
}

sub cmdBooking {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;

	if ($arg1 eq "search") {
		$args =~ /^\w+\s([0-9]+)\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?/;
		# $1 -> level
		# $2 -> MapID
		# $3 -> job
		# $4 -> ResultCount
		# $5 -> LastIndex

		$messageSender->sendPartyBookingReqSearch($1, $2, $3, $4, $5);
	} elsif ($arg1 eq "recruit") {
		$args =~ /^\w+\s([0-9]+)\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?/;
		# $1      -> level
		# $2      -> MapID
		# $3 ~ $8 -> jobs

		if (!$3) {
			error T("Syntax Error in function 'booking recruit' (Booking recruit)\n" .
				"Usage: booking recruit \"<level>\" \"<MapID>\" \"<job 1 ~ 6x>\"\n");
			return;
		}

		# job null = 65535
		my @jobList = (65535) x 6;
		$jobList[0] = $3;
		$jobList[1] = $4 if ($4);
		$jobList[2] = $5 if ($5);
		$jobList[3] = $6 if ($6);
		$jobList[4] = $7 if ($7);
		$jobList[5] = $8 if ($8);

		$messageSender->sendPartyBookingRegister($1, $2, @jobList);
	} elsif ($arg1 eq "update") {
		$args =~ /^\w+\s([0-9]+)\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?\s?([0-9]+)?/;

		# job null = 65535
		my @jobList = (65535) x 6;
		$jobList[0] = $1;
		$jobList[1] = $2 if ($2);
		$jobList[2] = $3 if ($3);
		$jobList[3] = $4 if ($4);
		$jobList[4] = $5 if ($5);
		$jobList[5] = $6 if ($6);

		$messageSender->sendPartyBookingUpdate(@jobList);
	} elsif ($arg1 eq "delete") {
		$messageSender->sendPartyBookingDelete();
	} else {
		error T("Syntax error in function 'booking'\n" .
			"Usage: booking [<search | recruit | update | delete>]\n");
	}
}

sub cmdBuyer {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^([\d\w]+)/;
	my ($arg2) = $args =~ /^[\d\w]+ (\d+)/;
	my ($arg3) = $args =~ /^[\d\w]+ \d+ (\d+)/;
	if ($arg1 eq "") {
		error T("Syntax error in function 'buyer' (Buyer Shop)\n" .
			"Usage: buyer <buyer # | end> [<item #> <amount>]\n");
	} elsif ($arg1 eq "end") {
		undef @buyerItemList;
		undef $buyerID;
		undef $buyingStoreID;
	} elsif ($buyerListsID[$arg1] eq "") {
		error TF("Error in function 'buyer' (Buyer Shop)\n" .
			"buyer %s does not exist.\n", $arg1);
	} elsif ($arg2 eq "") {
		# FIXME not implemented
		undef @buyerItemList;
		undef $buyerID;
		undef $buyingStoreID;
		$messageSender->sendEnteringBuyer($buyerListsID[$arg1]);
	} elsif ($buyerListsID[$arg1] ne $buyerID) {
		error T("Error in function 'buyer' (Buyer Shop)\n" .
			"Buyer ID is wrong.\n");
	} else {
		if ($arg3 <= 0) {
			$arg3 = 1;
		}
		$messageSender->sendBuyBulkBuyer($buyerID, [{itemIndex => $arg2, itemID => $buyerItemList[$arg2]->{nameID}, amount => $arg3}], $buyingStoreID);
	}
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
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $map) = @_;

	if ($map eq '') {
		error T("Error in function 'warp' (Open/List Warp Portal)\n" .
			"Usage: warp <map name | map number# | list | cancel>\n");

	} elsif ($map =~ /^\d+$/) {
		if (!$char->{warp}{memo} || !@{$char->{warp}{memo}}) {
			error T("You didn't cast warp portal.\n");
			return;
		}

		if ($map < 0 || $map > @{$char->{warp}{memo}}) {
			error TF("Invalid map number %s.\n", $map);
		} else {
			my $name = $char->{warp}{memo}[$map];
			my $rsw = "$name.rsw";
			message TF("Attempting to open a warp portal to %s (%s)\n",
				$maps_lut{$rsw}, $name), "info";
			$messageSender->sendWarpTele(27,"$name.gat");
		}

	} elsif ($map eq 'list') {
		if (!$char->{warp}{memo} || !@{$char->{warp}{memo}}) {
			error T("You didn't cast warp portal.\n");
			return;
		}

		my $msg = center(T(" Warp Portal "), 50, '-') ."\n".
			T("#  Place                           Map\n");
		for (my $i = 0; $i < @{$char->{warp}{memo}}; $i++) {
			$msg .= swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<",
				[$i, $maps_lut{$char->{warp}{memo}[$i].'.rsw'}, $char->{warp}{memo}[$i]]);
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";

	} elsif ($map eq 'cancel') {
		message T("Attempting to cancel the warp portal\n"), 'info';
		$messageSender->sendWarpTele(27, 'cancel');

	} elsif (!defined $maps_lut{$map.'.rsw'}) {
		error TF("Map '%s' does not exist.\n", $map);

	} else {
		my $rsw = "$map.rsw";
		message TF("Attempting to open a warp portal to %s (%s)\n",
			$maps_lut{$rsw}, $map), "info";
		$messageSender->sendWarpTele(27,"$map.gat");
	}
}

sub cmdWeight {
	if (!$char) {
		error T("Character weight information not yet available.\n");
		return;
	}
	my (undef, $itemWeight) = @_;

	$itemWeight ||= 1;

	if ($itemWeight !~ /^\d+(\.\d+)?$/) {
		error T("Syntax error in function 'weight' (Inventory Weight Info)\n" .
			"Usage: weight [item weight]\n");
		return;
	}

	my $itemString = $itemWeight == 1 ? '' : "*$itemWeight";
	message TF("Weight: %s/%s (%s\%)\n", $char->{weight}, $char->{weight_max}, sprintf("%.02f", $char->weight_percent)), "list";
	if ($char->weight_percent < 90) {
		if ($char->weight_percent < 50) {
			my $weight_50 = int((int($char->{weight_max}*0.5) - $char->{weight}) / $itemWeight);
			message TF("You can carry %s%s before %s overweight.\n",
				$weight_50, $itemString, '50%'), "list";
		} else {
			message TF("You are %s overweight.\n", '50%'), "list";
		}
		my $weight_90 = int((int($char->{weight_max}*0.9) - $char->{weight}) / $itemWeight);
		message TF("You can carry %s%s before %s overweight.\n",
			$weight_90, $itemString, '90%'), "list";
	} else {
		message TF("You are %s overweight.\n", '90%');
	}
}

sub cmdWhere {
	if (!$char) {
		error T("Location not yet available.\n");
		return;
	}
	my $pos = calcPosition($char);
	message TF("Location: %s : (baseName: %s) : %d, %d\n", $field->descString(), $field->baseName(), $pos->{x}, $pos->{y}), "info";
}

sub cmdWho {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	$messageSender->sendWho();
}

sub cmdWhoAmI {
	if (!$char) {
		error T("Character information not yet available.\n");
		return;
	}
	my $GID = unpack("V1", $charID);
	my $AID = unpack("V1", $accountID);
	message TF("Name:    %s (Level %s %s %s)\n" .
		"Char ID: %s\n" .
		"Acct ID: %s\n",
		$char->{name}, $char->{lv}, $sex_lut{$char->{sex}}, $jobs_lut{$char->{jobID}},
		$GID, $AID), "list";
}

sub cmdMail {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args_string) = @_;
	my @args = parseArgs($args_string, 4);

	# mail send
	if ($cmd eq 'ms') {
		unless ($args[0] && $args[1] && $args[2]) {
			message T("Usage: ms <receiver> <title> <message>\n"), "info";
		} else {
			my ($receiver, $title, $msg) = ($args[0], $args[1], $args[2]);
			$messageSender->sendMailSend($receiver, $title, $msg);
		}

	# mail open
	} elsif ($cmd eq 'mo') {

		unless ($args[0] =~ /^\d+$/) {
			message T("Usage: mo <mail #>\n"), "info";
		} elsif (!$mailList->[$args[0]]) {
			if (@{$mailList}) {
				message TF("No mail found with index: %s. (might need to re-open mailbox)\n", $args[0]), "info";
			} else {
				message T("Mailbox has not been opened or is empty.\n"), "info";
			}
		} else {
			$messageSender->sendMailRead($mailList->[$args[0]]->{mailID});
		}

	# mail inbox => set on begin as standard?
	} elsif ($cmd eq 'mi') {
		# if mail not already opened needed?
		$messageSender->sendMailboxOpen();

	# mail window (almost useless?)
	} elsif ($cmd eq 'mw') {
		unless (defined $args[0]) {
			message T("Usage: mw [0|1|2] (0:write, 1:take item back, 2:zeny input ok)\n"), "info";
		} elsif ($args[0] =~ /^[0-2]$/) {
			$messageSender->sendMailOperateWindow($args[0]);
		} else {
			error T("Syntax error in function 'mw' (mailbox window)\n" .
			"Usage: mw [0|1|2] (0:write, 1:take item back, 2:zeny input ok)\n");
		}

	# mail attachment control
	} elsif ($cmd eq 'ma') {
		if ($args[0] eq "get" && $args[1] =~ /^\d+$/) {
			unless ($mailList->[$args[1]]->{mailID}) {
				if (@{$mailList}) {
					message TF("No mail found with index: %s. (might need to re-open mailbox)\n", $args[1]), "info";
				} else {
					message T("Mailbox has not been opened or is empty.\n"), "info";
				}
			} else {
				$messageSender->sendMailGetAttach($mailList->[$args[1]]->{mailID});
			}
		} elsif ($args[0] eq "add") {
			unless ($args[2] =~ /^\d+$/) {
				message T("Usage: ma add [zeny <amount>]|[item <amount> (<item #>|<item name>)]\n"), "info";
			} elsif ($args[1] eq "zeny") {
				$messageSender->sendMailSetAttach($args[2], undef);
			} elsif ($args[1] eq "item" && defined $args[3]) {
				my $item = Actor::Item::get($args[3]);
				if ($item) {
					my $serverIndex = $item->{index};
					$messageSender->sendMailSetAttach($args[2], $serverIndex);
				} else {
					message TF("Item with index or name: %s does not exist in inventory.\n", $args[3]), "info";
				}
			} else {
				error T("Syntax error in function 'ma' (mail attachment control)\n" .
				"Usage: ma add [zeny <amount>]|[item <amount> (<item #>|<item name>)]\n");
			}
		} else {
			message T("Usage: ma (get <mail #>)|(add [zeny <amount>]|[item <amount> (<item #>|<item name>)])\n"), "info";
		}

	# mail delete (can't delete mail without removing attachment/zeny first)
	} elsif ($cmd eq 'md') {
		unless ($args[0] =~ /^\d+$/) {
			message T("Usage: md <mail #>\n"), "info";
		} elsif (!$mailList->[$args[0]]) {
			if (@{$mailList}) {
				message TF("No mail found with index: %s. (might need to re-open mailbox)\n", $args[0]), "info";
			} else {
				message T("Mailbox has not been opened or is empty.\n"), "info";
			}
		} else {
			$messageSender->sendMailDelete($mailList->[$args[0]]->{mailID});
		}

	# mail return
	} elsif ($cmd eq 'mr') {
		unless ($args[0] =~ /^\d+$/) {
			message T("Usage: mr <mail #>\n"), "info";
		} elsif (!$mailList->[$args[0]]) {
			if (@{$mailList}) {
				message TF("No mail found with index: %s. (might need to re-open mailbox)\n", $args[1]), "info";
			} else {
				message T("Mailbox has not been opened or is empty.\n"), "info";
			}
		} else {
			$messageSender->sendMailReturn($mailList->[$args[0]]->{mailID}, $mailList->[$args[0]]->{sender});
		}

	# with command mail, list of possebilities: $cmd eq 'm'
	} else {
		message T("Mail commands: ms, mi, mo, md, mw, mr, ma\n"), "info";
	}
}

sub cmdAuction {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args_string) = @_;
	my @args = parseArgs($args_string, 4);

	# auction add item
	# TODO: it doesn't seem possible to add more than 1 item?
	if ($cmd eq 'aua') {
		unless (defined $args[0] && $args[1] =~ /^\d+$/) {
			message T("Usage: aua (<item #>|<item name>) <amount>\n"), "info";
		} elsif (my $item = Actor::Item::get($args[0])) {
			my $serverIndex = $item->{index};
			$messageSender->sendAuctionAddItem($serverIndex, $args[1]);
		}
	# auction remove item
	} elsif ($cmd eq 'aur') {
			$messageSender->sendAuctionAddItemCancel();
	# auction create (add item first)
	} elsif ($cmd eq 'auc') {
		unless ($args[0] && $args[1] && $args[2]) {
			message T("Usage: auc <current price> <instant buy price> <hours>\n"), "info";
		} else {
			my ($price, $buynow, $hours) = ($args[0], $args[1], $args[2]);
			$messageSender->sendAuctionCreate($price, $buynow, $hours);
		}
		# auction create (add item first)
	} elsif ($cmd eq 'aub') {
		unless (defined $args[0] && $args[1] =~ /^\d+$/) {
			message T("Usage: aub <id> <price>\n"), "info";
		} else {
			unless ($auctionList->[$args[0]]->{ID}) {
				if (@{$auctionList}) {
						message TF("No auction item found with index: %s. (might need to re-open auction window)\n", $args[0]), "info";
				} else {
						message T("Auction window has not been opened or is empty.\n"), "info";
				}
			} else {
				$messageSender->sendAuctionBuy($auctionList->[$args[0]]->{ID}, $args[1]);
			}
		}
	# auction info (my)
	} elsif ($cmd eq 'aui') {
		# funny thing is, we can access this info trough 'aus' aswell
		unless ($args[0] eq "selling" || $args[0] eq "buying") {
			message T("Usage: aui (selling|buying)\n"), "info";
		} else {
			$args[0] = ($args[0] eq "selling") ? 0 : 1;
			$messageSender->sendAuctionReqMyInfo($args[0]);
		}
	# auction delete
	} elsif ($cmd eq 'aud') {
		unless ($args[0] =~ /^\d+$/) {
			message T("Usage: aud <index>\n"), "info";
		} else {
			unless ($auctionList->[$args[0]]->{ID}) {
				if (@{$auctionList}) {
					message TF("No auction item found with index: %s. (might need to re-open auction window)\n", $args[0]), "info";
				} else {
					message T("Auction window has not been opened or is empty.\n"), "info";
				}
			} else {
				$messageSender->sendAuctionCancel($auctionList->[$args[0]]->{ID});
			}
		}
	# auction end (item gets sold to highest bidder?)
	} elsif ($cmd eq 'aue') {
		unless ($args[0] =~ /^\d+$/) {
			message T("Usage: aue <index>\n"), "info";
		} else {
			unless ($auctionList->[$args[0]]->{ID}) {
				if (@{$auctionList}) {
					message TF("No auction item found with index: %s. (might need to re-open auction window)\n", $args[0]), "info";
				} else {
					message T("Auction window has not been opened or is empty.\n"), "info";
				}
			} else {
				$messageSender->sendAuctionMySellStop($auctionList->[$args[0]]->{ID});
			}
		}
	# auction search
	} elsif ($cmd eq 'aus') {
		# TODO: can you in official servers do a query on both a category AND price/text? (eA doesn't allow you to)
		unless (defined $args[0]) {
			message T("Usage: aus <type> [<price>|<text>]\n" .
			"      types (0:Armor 1:Weapon 2:Card 3:Misc 4:By Text 5:By Price 6:Sell 7:Buy)\n"), "info";
		# armor, weapon, card, misc, sell, buy
		} elsif ($args[0] =~ /^[0-3]$/ || $args[0] =~ /^[6-7]$/) {
			$messageSender->sendAuctionItemSearch($args[0]);
		# by text
		} elsif ($args[0] == 5) {
			unless (defined $args[1]) {
				message T("Usage: aus 5 <text>\n"), "info";
			} else {
				$messageSender->sendAuctionItemSearch($args[0], undef, $args[1]);
			}
		# by price
		} elsif ($args[0] == 6) {
			unless ($args[1] =~ /^\d+$/) {
				message T("Usage: aus 6 <price>\n"), "info";
			} else {
				$messageSender->sendAuctionItemSearch($args[0], $args[1]);
			}
		} else {
			error T("Possible value's for the <type> parameter are:\n" .
					"(0:Armor 1:Weapon 2:Card 3:Misc 4:By Text 5:By Price 6:Sell 7:Buy)\n");
		}
	# with command auction, list of possebilities: $cmd eq 'au'
	} else {
		message T("Auction commands: aua, aur, auc, aub, aui, aud, aue, aus\n"), "info";
	}
}

sub cmdQuest {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $args_string) = @_;
	my @args = parseArgs($args_string, 3);
	if ($args[0] eq 'set') {
		if ($args[1] =~ /^\d+/) {
			# note: we need the questID here now, might be better if we could make it so you only have to insert some questIndex
			$messageSender->sendQuestState($args[1], ($args[2] eq 'on'));
		} else {
			message T("Usage: quest set <questID> <on|off>\n"), "info";
		}
	} elsif ($args[0] eq 'list') {
		my $k = 0;
		my $msg .= center(" " . T("Quest List") . " ", 79, '-') . "\n";
		foreach my $questID (keys %{$questList}) {
			my $quest = $questList->{$questID};
			$msg .= swrite(sprintf("\@%s \@%s \@%s \@%s \@%s", ('>'x2), ('<'x4), ('<'x30), ('<'x10), ('<'x24)),
				[$k, $questID, $quests_lut{$questID} ? $quests_lut{$questID}{title} : '', $quest->{active} ? T("active") : T("inactive"), $quest->{time} ? scalar localtime $quest->{time} : '']);
			foreach my $mobID (keys %{$quest->{missions}}) {
				my $mission = $quest->{missions}->{$mobID};
				$msg .= swrite(sprintf("\@%s \@%s \@%s", ('>'x2), ('<'x30), ('<'x30)),
					[" -", $mission->{mobName}, sprintf(defined $mission->{goal} ? '%d/%d' : '%d', @{$mission}{qw(count goal)})]);
			}
			$k++;
		}
		$msg .= sprintf("%s\n", ('-'x79));
		message $msg, "list";
	} elsif ($args[0] eq 'info') {
		if ($args[1] =~ /^\d+/) {
			# note: we need the questID here now, might be better if we could make it so you only have to insert some questIndex
			if ($quests_lut{$args[1]}) {
				my $msg = center (' ' . ($quests_lut{$args[1]}{title} || T('Quest Info')) . ' ', 79, '-') . "\n";
				$msg .= "$quests_lut{$args[1]}{summary}\n" if $quests_lut{$args[1]}{summary};
				$msg .= TF("Objective: %s\n", $quests_lut{$args[1]}{objective}) if $quests_lut{$args[1]}{objective};
				message $msg;
			} else {
				message T("Unknown quest\n"), "info";
			}
		} else {
			message T("Usage: quest info <questID>\n"), "info";
		}
	} else {
		message T("Quest commands: set, list, info\n"), "info";
	}
}

sub cmdShowEquip {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $args_string) = @_;
	my @args = parseArgs($args_string, 2);
	if ($args[0] eq 'p') {
		if (my $actor = Match::player($args[1], 1)) {
			$messageSender->sendShowEquipPlayer($actor->{ID});
			message TF("Requesting equipment information for: %s\n", $actor->name), "info";
		} elsif ($args[1]) {
			message TF("No player found with specified information: %s\n", $args[1]), "info";
		} else {
			message T("Usage: showeq p <index|name|partialname>\n");
		}
	} elsif ($args[0] eq 'me') {
		$messageSender->sendShowEquipTickbox($args[1] eq 'on');
	} else {
		message T("Usage: showeq [p <index|name|partialname>] | [me <on|off>]\n"), "info";
	}
}

sub cmdCooking {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $arg) = @_;
	if ($arg =~ /^\d+/ && defined $cookingList->[$arg]) { # viewID/nameID can be 0
		$messageSender->sendCooking(1, $cookingList->[$arg]); # type 1 is for cooking
	} else {
		message TF("Item with 'Cooking List' index: %s not found.\n", $arg), "info";
	}
}

sub cmdWeaponRefine {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $arg) = @_;
	if(my $item = Match::inventoryItem($arg)) {
		$messageSender->sendWeaponRefine($item->{index});
	} else {
		message TF("Item with name or id: %s not found.\n", $arg), "info";
	}
}

sub cmdAnswerCaptcha {
	$messageSender->sendCaptchaAnswer($_[1]);
}

### CATEGORY: Private functions

##
# void cmdStorage_list(String list_type)
# list_type: ''|eq|nu|u
#
# Displays the contents of storage, or a subset indicated by switches.
#
# Called by: cmdStorage (not called directly).
sub cmdStorage_list {
	my $type = shift;
	message "$type\n";

	my @useable;
	my @equipment;
	my @non_useable;
	my ($i, $display, $index);
	
	foreach my $item (@{$char->storage->getItems()}) {
		if ($item->usable) {
			push @useable, $item->{invIndex};
		} elsif ($item->equippable) {
			my %eqp;
			$eqp{index} = $item->{index};
			$eqp{binID} = $item->{invIndex};
			$eqp{name} = $item->{name};
			$eqp{amount} = $item->{amount};
			$eqp{identified} = " -- " . T("Not Identified") if !$item->{identified};
			$eqp{type} = $itemTypes_lut{$item->{type}};
			push @equipment, \%eqp;
		} else {
			push @non_useable, $item->{invIndex};
		}
	}

	my $msg = center(defined $storageTitle ? $storageTitle : T(' Storage '), 50, '-') . "\n";

	if (!$type || $type eq 'u') {
		$msg .= T("-- Usable --\n");
		for (my $i = 0; $i < @useable; $i++) {
			$index = $useable[$i];
			my $item = $char->storage->get($index);
			$display = $item->{name};
			$display .= " x $item->{amount}";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$index, $display]);
		}
	}

	if (!$type || $type eq 'eq') {
		$msg .= T("\n-- Equipment --\n");
		foreach my $item (@equipment) {
			## altered to allow for Arrows/Ammo which will are stackable equip.
			$display = sprintf("%-3d  %s (%s)", $item->{binID}, $item->{name}, $item->{type});
			$display .= " x $item->{amount}" if $item->{amount} > 1;
			$display .= $item->{identified};
			$msg .= sprintf("%-57s\n", $display);
		}
	}

	if (!$type || $type eq 'nu') {
		$msg .= T("\n-- Non-Usable --\n");
		for (my $i = 0; $i < @non_useable; $i++) {
			$index = $non_useable[$i];
			my $item = $char->storage->get($index);
			$display = $item->{name};
			$display .= " x $item->{amount}";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$index, $display]);
		}
	}

	$msg .= TF("\nCapacity: %d/%d\n", $char->storage->items, $char->storage->items_max) .
			('-'x50) . "\n";
	message $msg, "list";
}

sub cmdDeadTime {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my $msg;
	if (@deadTime) {
		$msg = center(T(" Dead Time Record "), 50, '-') ."\n";
		my $i = 1;
		foreach my $dead (@deadTime) {
			$msg .= "[".$i."] ". $dead."\n";
		}
		$msg .= ('-'x50) . "\n";
	} else {
		$msg = T("You have not died yet.\n");
	}
	message $msg, "list";
}

1;
