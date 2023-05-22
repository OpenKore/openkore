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
use Network::PacketParser qw(STATUS_STR STATUS_AGI STATUS_VIT STATUS_INT STATUS_DEX STATUS_LUK);

our (%commands, %completions);
my $needsInit = 1;

undef %commands;
undef %completions;

sub initHandlers {
	register(
		['a', [
			T("Attack a monster."),
			[ T("<monster #>"), T("attack the specified monster") ],
			], \&cmdAttack],
		['achieve', [
			T("Achievement management"),
			[ "list", T("shows all current achievements") ],
			[ "info <achievementID>", T("shows information about the achievement") ],
			[ "reward <achievementID>", T("request reward for the achievement of achievementID") ],
			], \&cmdAchieve],
		['ai', [
			T("Enable/disable AI."),
			["", T("toggles AI on/manual/off")],
			["on", T("enables AI")],
			["off", T("disables AI")],
			["manual", T("makes AI manual")],
			["ai_v", T("displays the contents of the %ai_v hash, for debugging purposes")],
			["clear", T("clears AI sequences")],
			["print", T("displays detailed info about current AI sequence")]
			], \&cmdAI],
		['aiv', T("Display current AI sequences."), \&cmdAIv],
		['al', T("Display the status of your vending shop."), \&cmdShopInfoSelf],
		['arrowcraft', [
			T("Create Arrows."),
			["", T("lists available arrow-crafting items")],
			["use", T("use the Archer's Arrow Craft skill")],
			[T("<arrowcraft #>"), T("create arrows using an item from the 'arrowcraft' list")],
			[T("forceuse <inventory item #>"), T("craft arrows immediately from an item without using the skill")]
			], \&cmdArrowCraft],
		['as', T("Stop attacking a monster."), \&cmdAttackStop],
		['attendance', [
			T("Attendance System."),
			["open", T("Attendance System")],
			["request", T("Request the Current Day Reward")],
			], \&cmdAttendance],
		['autobuy', T("Initiate auto-buy AI sequence."), \&cmdAutoBuy],
		['autosell', [
			T("Auto-sell AI sequence."),
			["", T("Initiate auto-sell AI sequence")],
			["test", T("Simulate list of items to sell (synonym: 'simulate' or 'debug')")]
			], \&cmdAutoSell],
		['autostorage', T("Initiate auto-storage AI sequence."), \&cmdAutoStorage],
		['auth', [
			T("(Un)authorize a user for using Kore chat commands."),
			[T("<player name> 0"), T("unauthorize <player name>")],
			[T("<player name> 1"), T("authorize <player name>")]
			], \&cmdAuthorize],
		['bangbang', T("Does a bangbang body turn."), \&cmdBangBang],
		['bingbing', T("Does a bingbing body turn."), \&cmdBingBing],
		['bank', [
			T("Banking management."),
			["open", T("Open Banking Interface")],
			["deposit", T("Deposit Zeny in Banking")],
			["withdraw", T("Withdraw Zeny from Banking")],
			], \&cmdBank],
		['bg', [
			T("Send a message in the battlegrounds chat."),
			[T("<message>"), T("send <message> in the battlegrounds chat")]
			], \&cmdChat],
		['bl', undef, \&cmdBuyerList],
		['booking', T("Interact with a group booking"), \&cmdBooking],
		['buy', [
			T("Buy an item from the current NPC shop"),
			[T("<store item #> [<amount>]"), T("buy <amount> items from the 'store' list")]
			], \&cmdBuy],
		['buyer', undef, \&cmdBuyer],
		['bs', undef, \&cmdBuyShopInfoSelf],
		['c', [
			T("Chat in the public chat."),
			[T("<message>"), T("send <message> to public chat")]
			], \&cmdChat],
		['canceltransaction', undef, \&cmdCancelTransaction],
		['card', [
			T("Card compounding."),
			["list", T("lists cards in the inventory")],
			["use <card #>", T("initiate card compounding using the specified card")],
			["mergelist", T("lists items to merge card with")],
			["mergecancel", T("cancel a card merge request")],
			["merge <card merge #>", T("merge card with item and finalize card compounding")],
			["forceuse <card #> <inventory item #>", T("instantly merge the card with an item")]
			], \&cmdCard],
		['cart', [
			T("Cart management"),
			["", T("lists items in cart.")],
			["add <inventory item #> [<amount>]", T("add <amount> items from inventory to cart")],
			["get <cart item #> [<amount>]", T("get <amount> items from cart to inventory")],
			["desc <cart item #> [<amount>]", T("displays cart item description")]
			], \&cmdCart],
		['cash', [
			T("Cash shop management"),
			["open", T("open Cash shop")],
			["close", T("close Cash shop")],
			[T("buy <item> [<amount>] [<kafra shop points>]"), T("buy items from Cash shop")],
			["points", T("show the number of available Cash shop points")],
			["list", T("lists the Cash shop items")],
			], \&cmdCash],
		['cashbuy', [
			T("Buy Cash item"),
			["<kafra_points> <item #> [<amount>][, <item #> [<amount>]]...", T("buy items from cash dealer")],
			], \&cmdCashShopBuy],
		['charselect', T("Ask server to exit to the character selection screen."), \&cmdCharSelect],
		['chat', [
			T("Chat room management."),
			["list", T("lists chat rooms on screen")],
			[T("join <chat room #>"), T("join a chat room")],
			["info", T("displays info about the current chat room")],
			["leave", T("leave the current chat room")],
			[T("create \"<title>\" [<limit #> <public flag> <password>]"), T("create a chat room")],
			[T("modify \"<title>\" [<limit #> <public flag> <password>]"), T("modify the current chat room")],
			[T("bestow <user #>"), T("bestow admin to chat room user")],
			[T("kick <user #>"), T("kick a chat room user")]
			], \&cmdChatRoom],
		['chist', [
			T("Display last few entries from the chat log."),
			["", T("display last 5 entries")],
			[T("<number>"), T("display last <number> entries")]
			], \&cmdChist],
		['cil', T("Clear the item log."), \&cmdItemLogClear],
		['cln', undef, \&cmdChat],
		['clearlog', T("Clear the chat log."), \&cmdChatLogClear],
		['closeshop', T("Close your vending shop."), \&cmdCloseShop],
		['closebuyshop', undef, \&cmdCloseBuyShop],
		['closebuyershop', undef, \&cmdCloseBuyerShop],
		['conf', [
			T("Change a configuration key"),
			[T("<key>"), T("displays value of <key>")],
			[T("<key> <value>"), T("sets value of <key> to <value>")],
			[T("<key> none"), T("unsets <key>")],
			[T("<label>.<attribute>"), T("displays value of the specified configuration key through label")],
			[T("<label>.<attribute> <value>"), T("set a new value for the specified configuration key through label")],
			[T("<label>.<attribute> none"), T("unset the specified configuration key through label")],
			[T("<label>.block"), T("display the current value of the specified block")],
			[T("<label>.block <value>"), T("set a new value for the specified block through <label>")],
			[T("<label>block none"), T("unset the specified block through <label>")]
			], \&cmdConf],
		['connect', undef, \&cmdConnect],
		['create', undef, \&cmdCreate],
		['damage', [
			T("Damage taken report"),
			["", T("displays the damage taken report")],
			["reset", T("resets the damage taken report")]
			], \&cmdDamage],
		['dead', undef, \&cmdDeadTime],
		['deal', [
			T("Trade items with another player."),
			["", T("accept an incoming deal/finalize the current deal/trade")],
			[T("<player #> | <player_name>"), T("request a deal with player")],
			[T("add <inventory item #> [<amount>]"), T("add items to current deal")],
			[T("add z [<amount>]"), T("add zenny to current deal")],
			["no", T("deny an incoming deal/cancel the current deal")]
			], \&cmdDeal],
		['debug', [
			T("Toggle debug on/off."),
			[T("<level>"), T("sets debug level to <level>")],
			["info", T("displays debug information")]
			], \&cmdDebug],
		['dl', T("List items in the current deal."), \&cmdDealList],
		['doridori', T("Does a doridori head turn."), \&cmdDoriDori],
		['drop', [
			T("Drop an item from the inventory."),
			[T("<inventory_item_list> [<amount>]"), T("drop an item from inventory")]
			], \&cmdDrop],
		['dump', T("Dump the current packet receive buffer and quit."), \&cmdDump],
		['dumpnow', T("Dump the current packet receive buffer without quitting."), \&cmdDumpNow],
		['e', [
			T("Show emotion."),
			[T("<emotion>"), T("show specified emotion (see tables/emotions.txt)")]
			], \&cmdEmotion],
		['eq', [
			T("Equip an item."),
			[T("<inventory item #>"), T("equips the specified item")],
			[T("<slotname> <inventory item #>"), T("equips the specified item on the specified slot")],
			["slots", T("lists slot names")]
			], \&cmdEquip],
		['eqsw', [
			T("Equip an switch item."),
			[T("<inventory item #>"), T("equips the specified item")],
			[T("<slotname> <inventory item #>"), T("equips the specified item on the specified slot")],
			["slots", T("lists slot names")]
			], \&cmdEquipSwitch],
		['elemental', undef, \&cmdElemental],
		['eval', [
			T("Evaluate a Perl expression."),
			[T("<expression>"), T("evaluate a Perl expression")]
			], \&cmdEval],
		['exp', [
			T("Experience report."),
			["", T("displays the experience report")],
			["monster", T("display report on monsters killed")],
			["item", T("display report on inventory changes")],
			["report", T("display detailed report on experience gained, monsters killed and items gained")],
			["reset", T("resets the experience report")],
			["output", T("output the experience report in file 'exp.txt'")]
			], \&cmdExp],
		['falcon', [
			T("Falcon status."),
			["", T("displays falcon status")],
			["release", T("releases your falcon")]
			], \&cmdFalcon],
		['follow', [
			T("Follow another player."),
			[T("<player name|player #>"), T("follow the specified player")],
			["stop", T("stop following")]
			], \&cmdFollow],
		['friend', [
			T("Friend management."),
			["", T("lists friends")],
			[T("request <player name|player #>"), T("requests player to be your friend")],
			["accept", T("accepts a friend request")],
			["reject", T("rejects a friend request")],
			[T("pm <friend #>"), T("pm a friend")],
			[T("remove <friend #>"), T("remove a friend from friends list")],
			], \&cmdFriend],
		['homun', [
			T("Interact with homunculus."),
			["s", T("display homunculus status")],
			["status", T("display homunculus status")],
			["feed", T("feed your homunculus. (Food needed)")],
			["rename", T("rename your homunculus")],
			["fire", T("delete your homunculus")],
			["delete", T("delete your homunculus")],
			["move <x> <y>", T("moves your homunculus")],
			["standby ", T("makes your homunculus standby")],
			["aiv ", T("display current homunculus AI ")],
			["ai", T("toggles AI on, off or manual ")],
			["on ", T("turns homunculus AI on")],
			["auto", T("turns homunculus AI on")],
			["manual", T("turns homunculus AI to manual")],
			["off", T("turns homunculus AI off")],
			["clear", T("clears homunculus AI")],
			["print", T("prints homunculus AI")],
			["skills", T("displays homunculus skills")],
			[T("skills add <skill #>"), T("add a skill point to the current homunculus skill")],
			[T("desc <skill #>"), T("display a description of the specified homunculus skill")]
			], \&cmdSlave],
		['misc_conf', [
			T("Send to Server Misc Configuration."),
			["show_eq (on|off)", T("Allow / Disable Show Equipment Window")],
			["call (on|off)", T("Allow / Disable being Summoned by Urgent Call or Marriage skills")],
			["pet_feed (on|off)", T("Enable / Disable Pet Auto-Feed")],
			["homun_feed (on|off)", T("Enable / Disable Homunculus Auto-Feed")],
			], \&cmdMiscConf],
		['merc', [
			T("Interact with Mercenary."),
			["s", T("display mercenary status")],
			["status", T("display mercenary status")],
			["fire", T("fires your mercenary")],
			["move <x> <y>", T("moves your mercenary")],
			["standby", T("makes your mercenary standby")],
			["aiv", T("display current mercenary AI")],
			["ai", T("toggles AI on, off or manual")],
			["on", T("turns mercenary AI on")],
			["auto", T("turns mercenary AI on")],
			["manual", T("turns mercenary AI to manual")],
			["off", T("turns mercenary AI off")],
			["clear", T("clears mercenary AI")],
			["print", T("prints mercenary AI")],
			["skills", T("displays mercenary skills")],
			[T("skills add <skill #>"), T("add a skill point to the current mercenary skill")],
			[T("desc <skill #>"), T("display a description of the specified mercenary skill")]
			], \&cmdSlave],
		['g', [
			T("Chat in the guild chat."),
			["<message>", T("send <message> to guild chat")]
			], \&cmdChat],
		['getplayerinfo', [
			T("Get the name of the player with specified ID"),
			["<player ID>", T("show the name of the specified ID (needs debug 2)")]
			], \&cmdGetPlayerInfo],
		['getcharname', undef, \&cmdGetCharacterName],
		# GM Commands - Start
		['gmb', undef, \&cmdGmb],
		['gmbb', undef, \&cmdGmb],
		['gmnb', undef, \&cmdGmb],
		['gmlb', undef, \&cmdGmb],
		['gmlbb', undef, \&cmdGmb],
		['gmlnb', undef, \&cmdGmb],
		['gmmapmove', undef, \&cmdGmmapmove],
		['gmcreate', undef, \&cmdGmcreate],
		['gmhide', undef, \&cmdGmhide],
		['gmwarpto', undef, \&cmdGmwarpto],
		['gmsummon', undef, \&cmdGmsummon],
		['gmrecall', undef, \&cmdGmrecall],
		['gmremove', undef, \&cmdGmremove],
		['gmdc', undef, \&cmdGmdc],
		['gmresetskill', undef, \&cmdGmresetskill],
		['gmresetstate', undef, \&cmdGmresetstate],
		['gmmute', undef, \&cmdGmmute],
		['gmunmute', undef, \&cmdGmunmute],
		['gmkickall', undef, \&cmdGmkickall],
		# GM Commands - End
		['guild', [
			T("Guild management."),
			["", T("request guild info")],
			["info", T("displays guild info")],
			["members", T("displays guild member info")],
			[T("create <guild name>"), T("create a guild")],
			[T("request <player name|player #>"), T("request player to join your guild")],
			[T("join <flag>"), T("accepts a guild join request if <flag> is 1, deny if 0")],
			[T("ally <player name|player #>"), T("request alliance to another guild")],
			["leave", T("leave the guild")],
			[T("kick <guild member #> <reason>"), T("kick a guild member out of the guild")],
			[T("break  <guild name>"), T("disband your guild")]
			], \&cmdGuild],
		['help', [
			T("Help displays commands"),
			["", T("lists available commands")],
			[T("<command>"), T("displays detailed information about a command")]
			], \&cmdHelp],
		['i', [
			T("Display inventory items."),
			["", T("display all inventory items.")],
			["eq", T("lists equipped items")],
			["neq", T("lists unequipped items")],
			["nu", T("lists non-usable items")],
			["u", T("lists usable items")],
			[T("desc <inventory item #>"), T("displays inventory item description")]
			], \&cmdInventory],
		['identify', [
			T("Identify an unindentified item."),
			["", T("lists items to be identified")],
			[T("<identify #>"), T("identify an item")]
			], \&cmdIdentify],
		['ignore', [
			T("Ignore a user (block their messages)."),
			[T("<flag> <player name>"), T("ignores a player if <flag> is 1, unignore if 0")],
			[T("<flag> all"), T("ignores all players if <flag> is 1, unignore if 0")]
			], \&cmdIgnore],
		['ihist', [
			T("Displays last few entries of the item log."),
			["", T("display last 5 entries")],
			[T("<number>"), T("display last <number> entries")]
			], \&cmdIhist],
		['il', T("Display items on the ground."), \&cmdItemList],
		['im', [
			T("Use item on monster."),
			[T("<inventory item #> <monster #>"), T("use item on monster")]
			], \&cmdUseItemOnMonster],
		['ip', [
			T("Use item on player."),
			[T("<inventory item #> <player #>"), T("use item on player")]
			], \&cmdUseItemOnPlayer],
		['is', [
			T("Use item on yourself."),
			[T("<inventory item #>"), T("use item on yourself")]
			], \&cmdUseItemOnSelf],
		['kill', [
			T("Attack another player (PVP/GVG only)."),
			[T("<player #>"), T("attack the specified player")]
			], \&cmdKill],
		['look', [
			T("Look in a certain direction."),
			[T("<body dir> [<head dir>]"), T("look at <body dir> (0-7) with head at <head dir> (0-2)")]
			], \&cmdLook],
		['lookp', [
			T("Look at a certain player."),
			[T("<player #>"), T("look at player")]
			], \&cmdLookPlayer],
		['memo', T("Save current position for warp portal."), \&cmdMemo],
		['ml', T("List monsters that are on screen."), \&cmdMonsterList],
		['move', [
			T("Move your character."),
			[T("<x> <y> [<map name>]"), T("move to the coordinates on a map")],
			[T("<map name>"), T("move to map")],
			[T("<portal #>"), T("move to nearby portal")],
			["stop", T("stop all movement")]
			], \&cmdMove],
		['nl', T("List NPCs that are on screen."), \&cmdNPCList],
		['openbuyershop', undef, \&cmdOpenBuyerShop],
		['openshop', T("Open your vending shop."), \&cmdOpenShop],
		['p', [
			T("Chat in the party chat."),
			[T("<message>"), T("send <message> to party chat")]
			], \&cmdChat],
		['party', [
			T("Party management."),
			["", T("displays party member info")],
			[T("create \"<party name>\""), T("organize a party")],
			[T("share <flag>"), T("sets party EXP sharing to even if flag is 1, individual take if 0")],
			[T("shareitem <flag>"), T("sets party ITEM sharing to even if flag is 1, individual take if 0")],
			[T("sharediv  <flag>"), T("sets party ITEM  PICKUP sharing to even if flag is 1, individual take if 0")],
			[T("shareauto"), T("set party EXP sharing auto by AI")],
			[T("request <player #>"), T("request player to join your party")],
			[T("join <flag>"), T("accept a party join request if <flag> is 1, deny if 0")],
			[T("kick <party member #>"), T("kick party member from party")],
			["leave", T("leave the party")]
			], \&cmdParty],
		['pecopeco', [
			T("Pecopeco status."),
			["", T("display pecopeco status")],
			["release", T("release your pecopeco")]
			], \&cmdPecopeco],
		['pet', [
			T("Pet management."),
			["s", T("displays pet status")],
			["status", T("displays pet status")],
			[T("c <monster #>"), T("captures a monster")],
			[T("capture <monster #>"), T("captures a monster")],
			[T("hatch <egg #>"), T("hatches a pet egg, but first you should use the item Pet Incubator")],
			["info", T("sends pet menu")],
			["feed", T("feeds your pet")],
			["performance", T("plays with your pet")],
			["return", T("sends your pet back to the egg")],
			["unequip", T("unequips your pet")],
			[T("name <name>"), T("changes the name of the pet")]
			], \&cmdPet],
		['petl', T("List pets that are on screen."), \&cmdPetList],
		['pl', [
			T("List players that are on screen."),
			["", T("lists players on screen")],
			[T("<player #>"), T("displays detailed info about a player")],
			["p", T("lists party players on screen")],
			["g", T("lists guild players on screen")]
			], \&cmdPlayerList],
		['plugin', [
			T("Control plugins."),
			["", T("lists loaded plugins")],
			[T("load <filename>"), T("loads a plugin file")],
			[T("reload <plugin name|plugin #>"), T("reloads a loaded plugin")],
			[T("unload <plugin name|plugin #>"), T("unloads a loaded plugin")],
			["help", T("displays plugin help")]
			], \&cmdPlugin],
		['pm', [
			T("Send a private message."),
			[T("<player name|PM list #> <message>"), T("send <message> to player through PM")]
			], \&cmdPrivateMessage],
		['pml', T("Quick PM list."), \&cmdPMList],
		['poison', [
			T("Apply Poison in Weapon."),
			["", T("lists available Poisons")],
			["use", T("use the Guillotine Cross Poisonous Weapon Skill")],
			[T("<poison #>"), T("Apply poison using an item from the 'poison' list")],
			], \&cmdPoison],
		['portals', [
			T("List portals that are on screen."),
			["", T("list portals that are on screen")],
			["recompile", T("recompile portals")],
			["add", T("add new portals: <map1> <x> <y> <map2> <x> <y>")],
			], \&cmdPortalList],
		['quit', [
			T("Exit this program."),
			["", T("exit this program")],
			["2", T("send a special package 'quit_request' to the server, then exit this program")],
			], \&cmdQuit],
		['rc', [
			T("Reload source code files."),
			["", T("reload functions.pl")],
			[T("<module names>"), T("reload module files in the space-separated <module names>")]
			], \&cmdReloadCode],
		['rc2', undef, \&cmdReloadCode2],
		['reload', [
			T("Reload configuration files."),
			["all", T("reload all control and table files")],
			[T("<names>"), T("reload control files in the list of <names>")],
			[T("all except <names>"), T("reload all files except those in the list of <names>")]
			], \&cmdReload],
		['relog', [
			T("Log out then log in again."),
			["", T("logout and login after 5 seconds")],
			[T("<seconds>"), T("logout and login after <seconds>")],
			[T("<min>..<max>"), T("logout and login after random seconds")]
			], \&cmdRelog],
		['repair', [
			T("Repair player's items."),
			["", T("list of items available for repair")],
			[T("<item #>"), T("repair the specified player's item")],
			[T("cancel"), T("cancel repair item")],
			], \&cmdRepair],
		['reputation', T("Show the Reputation Status"), \&cmdReputation],
		['respawn', T("Respawn back to the save point."), \&cmdRespawn],
		['revive', [
			T("Use of the 'Token Of Siegfried' to self-revive."),
			["", T("use of the 'Token Of Siegfried' to self-revive")],
			["force", T("trying to self-revive using")],
			["\"<item_name>\"", T("check <item_name> availability, then trying to self-revive")],
			["<item_ID>", T("check <item_ID> availability, then trying to self-revive")],
			], \&cmdRevive],
		['rodex', [
			T("rodex use (Ragnarok Online Delivery Express)"),
			["open", T("open rodex mailbox")],
			["open <0 | 1 | 2>", T("open rodex mailbox with a specific type")],
			["close", T("close rodex mailbox")],
			["list", T("list your first page of rodex mail")],
			["nextpage", T("request and get the next page of rodex mail")],
			["maillist", T("show ALL messages from ALL pages of rodex mail")],
			["refresh", T("send request to refresh and update rodex mailbox")],
			["read <mail_# | mail_id>", T("open the selected Rodex mail")],
			["getitems", T("get items of current rodex mail")],
			["getitems <mail_# | mail_id>", T("get items of rodex mail")],
			["getzeny", T("get zeny of current rodex mail")],
			["getzeny <mail_# | mail_id>", T("get zeny of rodex mail")],
			["write", T("open a box to start write a rodex mail")],
			["write <player_name | self>", T("open a box to start write a rodex mail to the specified player")],
			["settarget <player_name|self>", T("set target of rodex mail")],
			["itemslist", T("show current list of items in mail box that you are writting")],
			["settitle <title>", T("set rodex mail title")],
			["setbody <body>", T("set rodex mail body")],
			["setzeny <zeny_amount>", T("set zeny amount in rodex mail")],
			["add <item #> <amount>", T("add a item from inventory in rodex mail box")],
			["remove <item #> <amount>", T("remove a item or amount of item from rodex mail")],
			["draft", T("show draft rodex mail before sending")],
			["send", T("send finished rodex mail")],
			["cancel", T("close rodex mail write box")],
			["delete <mail_# | mail_id>", T("delete selected rodex mail")]
			], \&cmdRodex],
		['roulette', [
			T("Roulette System."),
			["open", T("Open Roulette System")],
			["info", T("Send Roulette System Info Request")],
			["close", T("Close Roulette System")],
			["start", T("Start Roulette System")],
			["claim", T("Claim Reward in Roulette System")],
			], \&cmdRoulette],
		['s', T("Display character status."), \&cmdStatus],
		['sell', [
			T("Sell items to an NPC."),
			[T("<inventory item #> [<amount>]"), T("put inventory items in sell list")],
			["list", T("show items in the sell list")],
			["done", T("sell everything in the sell list")],
			["cancel", T("clear the sell list")]
			], \&cmdSell],
		['send', [
			T("Send a raw packet to the server."),
			[T("<hex string>"), T("sends a raw packet to connected server")]
			], \&cmdSendRaw],
		['sit', T("Sit down."), \&cmdSit],
		['skills', [
			T("Skills management."),
			["", T("Lists available skills.")],
			[T("add <skill #>"), T("add a skill point")],
			[T("desc <skill #>"), T("displays skill description")]
			], \&cmdSkills],
		['sll', T("Display a list of slaves in your immediate area."), \&cmdSlaveList],
		['spells', T("List area effect spells on screen."), \&cmdSpells],
		['starplace', [
			T("Starplace Agree"),
			["sun", T("select sun as starplace")],
			["moon", T("select mon as starplace")],
			["star", T("select star as starplace")],
			], \&cmdStarplace],
		['storage', [
			T("Handle items in Kafra storage."),
			["", T("lists items in storage")],
			["eq", T("lists equipments in storage")],
			["nu", T("lists non-usable items in storage")],
			["u", T("lists usable items in storage")],
			[T("add <inventory item #> [<amount>]"), T("adds inventory item to storage")],
			[T("addfromcart <cart item #> [<amount>]"), T("adds cart item to storage")],
			[T("get <storage item #> [<amount>]"), T("gets item from storage to inventory")],
			[T("gettocart <storage item #> [<amount>]"), T("gets item from storage to cart")],
			["close", T("close storage")],
			["log", T("logs storage items to logs/storage.txt")]
			], \&cmdStorage],
		['store', [
			T("Display shop items from NPC."),
			["", T("lists available shop items from NPC")],
			[T("desc <store item #>"), T("displays store item description")]
			], \&cmdStore],
		['sl', [
			T("Use skill on location."),
			[T("<skill #> <x> <y> [<level>]"), T("use skill on location")]
			], \&cmdUseSkill],
		['sm', [
			T("Use skill on monster."),
			[T("<skill #> <monster #> [<level>]"), T("use skill on monster")]
			], \&cmdUseSkill],
		['sp', [
			T("Use skill on player."),
			[T("<skill #> <player #> [<level>]"), T("use skill on player")]
			], \&cmdUseSkill],
		['ss', [
			T("Use skill on self."),
			[T("<skill #> [<level>]"), T("use skill on self")],
			[T("start <skill #> [<level>]"), T("start use skill on self")],
			[T("stop"), T("stop use skill on self")]
			], \&cmdUseSkill],
		['ssl', [
			T("Use skill on slave."),
			[T("<skill #> <target #> <skill level>"), T("use skill on slave")]
			], \&cmdUseSkill],
		['ssp', [
			T("Use skill on ground spell."),
			[T("<skill #> <target #> [<skill level>]"), T("use skill on ground spell")]
			], \&cmdUseSkill],
		['st', T("Display stats."), \&cmdStats],
		['stand', T("Stand up."), \&cmdStand],
		['stat_add', [
			T("Add status point."),
			["str|agi|int|vit|dex|luk", T("add status points to a stat")]
			], \&cmdStatAdd],
		['switchconf', [
			T("Switch configuration file."),
			[T("<filename>"), T("switches configuration file to <filename>")]
			], \&cmdSwitchConf],
		['switch_equips', T("Switch Equips"), \&cmdSwitchEquips],
		['take', [
			T("Take an item from the ground."),
			[T("<item #>"), T("take an item from the ground")],
			["first", T("take the first item on the ground")]
			], \&cmdTake],
		['talk', [
			T("Manually talk to an NPC."),
			[T("<NPC #>"), T("talk to an NPC")],
			["cont", T("continue talking to NPC")],
			["resp", T("lists response options to NPC")],
			[T("resp <response #>"), T("select a response to NPC")],
			[T("num <number>"), T("send a number to NPC")],
			[T("text <string>"), T("send text to NPC")],
			["no", T("ends/cancels conversation with NPC")]
			], \&cmdTalk],
		['talknpc', [
			T("Send a sequence of responses to an NPC."),
			[T("<x> <y> <NPC talk codes>"), T("talk to the NPC standing at <x> <y> and use <NPC talk codes>")]
			], \&cmdTalkNPC],
		['tank', [
			T("Tank for a player."),
			[T("<player name|player #>"), T("starts tank mode with player as tankModeTarget")],
			["stop", T("stops tank mode")]
			], \&cmdTank],
		['tele', T("Teleport to a random location."), \&cmdTeleport],
		['testshop', T("Show what your vending shop would sell."), \&cmdTestShop],
		['timeout', [
			T("Set a timeout."),
			[T("<type>"), T("displays value of <type>")],
			[T("<type> <second>"), T("sets value of <type> to <seconds>")]
			], \&cmdTimeout],
		['top10', [
			T("Displays top10 ranking."),
			["top10 (a | alche | alchemist)", T("displays Alchemist's top10 ranking")],
			["top10 (b | black | blacksmith)", T("displays Blackmith's top10 ranking")],
			["top10 (p | pk | pvp)", T("displays PVP top10 ranking")],
			["top10 (t | tk | taekwon)", T("displays Taekwon's top10 ranking")]
			], \&cmdTop10],
		['uneq', [
			T("Unequp an item."),
			[T("<inventory item #>"), T("unequips the specified item")]
			], \&cmdUnequip],
		['uneqsw', [
			T("Unequp an switch item."),
			[T("<inventory item #>"), T("unequips the specified item")]
			], \&cmdUnequipSwitch],
		['vender', [
			T("Buy items from vending shops."),
			[T("<vender #>"), T("enter vender shop")],
			[T("<vender #> <vender_item #> [<amount>]"), T("buy items from vender shop")],
			["end", T("leave current vender shop")]
			], \&cmdVender],
		['verbose', T("Toggle verbose on/off."), \&cmdVerbose],
		['version', T("Display the version of openkore."), \&cmdVersion],
		['vl', T("List nearby vending shops."), \&cmdVenderList],
		['vs', T("Display the status of your vending shop."), \&cmdShopInfoSelf],
		['warp', [
			T("Open warp portal."),
			["list", T("lists available warp portals to open")],
			[T("<warp portal #|map name>"), T("opens a warp portal to a map")]
			], \&cmdWarp],
		['weight', [
			T("Gives a report about your inventory weight."),
			["", T("displays info about current weight")],
			[T("<item weight>"), T("calculates how much more items of specified weight can be carried")]
			], \&cmdWeight],
		['where', T("Shows your current location."), \&cmdWhere],
		['who', T("Display the number of people on the current server."), \&cmdWho],
		['whoami', T("Display your character and account ID."), \&cmdWhoAmI],
		['mail', [
			T("Mailbox use (not Rodex)"),
			["open", T("open Mailbox")], # mi
			["list", T("list your Mailbox")],
			["refresh", T("refresh Mailbox")], # new
			[T("read <mail #>"), T("read the selected mail")], # mo
			[T("get <mail #>"), T("take attachments from mail")], # ma get
			[T("setzeny <amount|none>"), T("attach zeny to mail or return it back")], # ma add zeny, mw 2
			[T("add <item #|none> <amount>"), T("attach item to mail or return it back")], # ma add item, mw 1
			[T("send <receiver> <title> <body>"), T("send mail to <receiver>")], # ms
			[T("delete <mail #>"), T("delete selected mail")], #md
			["write", T("start writing a mail")], #mw 0
			["return <mail #>", T("returns the mail to the sender")] #mr
		], \&cmdMail],
		['au', T("Display possible commands for auction."), \&cmdAuction],	# see commands
		['aua', [
			T("Adds an item to the auction."),
			[T("<inventory item> <amount>"), T("adds an item to the auction")]
			], \&cmdAuction],	# add item
		['aur', T("Removes item from auction."), \&cmdAuction],	# remove item
		['auc', [
			T("Creates an auction."),
			[T("<current price> <instant buy price> <hours>"), T("creates an auction")]
			], \&cmdAuction],	# create auction
		['aue', [
			T("Ends an auction."),
			[T("<index>"), T("ends an auction")]
			], \&cmdAuction],	# auction end
		['aus', [
			T("Search for an auction according to the criteria."),
			[T("<type> <price> <text>"), T("Item's search criteria. Type: 1 Armor, 2 Weapon, 3 Card, 4 Misc, 5 By Text, 6 By Price, 7 Sell, 8 Buy")]
			], \&cmdAuction],	# search auction
		['aub', [
			T("Bids an auction."),
			[T("<id> <price>"), T("bids an auction")]
			], \&cmdAuction],	# make bid
		['aui', [
			T("Displays your auction info."),
			["selling", T("display selling info")],
			["buying", T("display buying info")]
			], \&cmdAuction],	# info on buy/sell
		['aud', [
			T("Deletes an auction."),
			[T("<index>"), T("deletes an auction")]
			], \&cmdAuction],	# delete auction

		['quest', [
			T("Quest management."),
			["", T("displays possible commands for quest")],
			["set <questID> on", T("enable quest")],
			["set <questID> off", T("disable quest")],
			["list", T("displays a list of your quests")],
			["info <questID>", T("displays quest description")]
			], \&cmdQuest],
		['showeq', [
			T("Equipment showing."),
			[T("p <index|name|partialname>"), T("request equipment information for player")],
			["me on", T("enables equipment showing")],
			["me off", T("disables equipment showing")]
			], \&cmdShowEquip],
		['cook', [
			T("Attempt to create a food item."),
			[T("<cook list #>"), T("attempt to create a food item")]
			], \&cmdCooking],
		['refine', [
			T("Refine an item (using the whitesmith skill)"),
			[T("(<item name>|<item index>)"), T("Refine an item (using the whitesmith skill)")]
			], \&cmdWeaponRefine],

		['north', T("Move 5 steps north."), \&cmdManualMove],
		['south', T("Move 5 steps south."), \&cmdManualMove],
		['east', T("Move 5 steps east."), \&cmdManualMove],
		['west', T("Move 5 steps west."), \&cmdManualMove],
		['northeast', T("Move 5 steps northeast."), \&cmdManualMove],
		['northwest', T("Move 5 steps northwest."), \&cmdManualMove],
		['southeast', T("Move 5 steps southeast."), \&cmdManualMove],
		['southwest', T("Move 5 steps southwest."), \&cmdManualMove],
		['captcha', T("Answer captcha"), \&cmdAnswerCaptcha],
		['refineui', undef, \&cmdRefineUI],
		['clan', undef, \&cmdClan],
		['merge', undef, \&cmdMergeItem],

		# Skill Exchange Item
		['cm', undef, \&cmdExchangeItem],
		['analysis', undef, \&cmdExchangeItem],

		['searchstore', [
			T("Universal catalog command"),
			["close", T("Closes search store catalog")],
			["next", T("Requests catalog next page")],
			["view <page #>", T("Shows catalog page # (0-indexed)")],
			["search [match|exact] ...", T("Searches for an item")],
			["select <page #> <store #>", T("Selects a store")],
			["buy [view|end|<item #> [<amount>]]", T("Buys from a store using Universal Catalog Gold")],
			], \&cmdSearchStore],
		['pause', [
			T("Delay the next console commands."),
			["", T("delay the next console commands for 1 second")],
			[T("<seconds>"), T("delay the next console commands by a specified number of seconds")]
			], undef],
	);

	# Built-in aliases
	register(
		['cl', $commands{'chat'}{desc}, $commands{'chat'}{callback}],
	);

	$needsInit = 0;
}

sub initCompletions {
	%completions = ();
}

### CATEGORY: Functions

##
# Commands::run(input)
# input: a command.
#
# Processes $input. See also <a href="https://openkore.com/wiki/Category:Console_Command">the user documentation</a>
# for a list of commands.
#
# Example:
# # Same effect as typing 's' in the console. Displays character status
# Commands::run("s");
sub run {
	my $input = shift;
	initHandlers() if $needsInit;

	# Resolve command aliases
	my ($switch, $args) = split(/ +/, $input, 2);
	if (my $alias = $config{"alias_$switch"}) {
		$input = $alias;
		$input .= " $args" if defined $args;
	}

	# Remove trailing spaces from input
	$input =~ s/^\s+|\s+$//g;

	my @commands = split(';;', $input);
	# Loop through all of the commands...
	foreach my $command (@commands) {
		my ($switch, $args) = split(/ +/, $command, 2);
		my $handler;
		$handler = $commands{$switch}{callback} if (exists $commands{$switch} && $commands{$switch});

		if (($switch eq 'pause') && (!$cmdQueue) && AI::state == AI::AUTO && ($net->getState() == Network::IN_GAME)) {
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
		} elsif (($switch eq 'pause') && (AI::state != AI::AUTO || ($net->getState() != Network::IN_GAME))) {
			error T("Cannot use pause command now.\n");
		} elsif (($handler) && ($cmdQueue > 0) && (!defined binFind(\@cmdQueuePriority,$switch) && ($command ne 'cart') && ($command ne 'storage'))) {
			push(@cmdQueueList, $command);
		} elsif ($handler) {
			my %params;
			$params{switch} = $switch;
			$params{args} = $args;
			Plugins::callHook('Commands::run/pre', \%params);
			$handler->($switch, $args);
			Plugins::callHook('Commands::run/post', \%params);

		} else {
			my %params = ( switch => $switch, input => $command );
			Plugins::callHook('Command_post', \%params);
			if (!$params{return}) {
				error TF("Unknown command '%s'. Please read the documentation for a list of commands.\n"
						."http://openkore.com/wiki/Category:Console_Command\n", $switch);
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
		my $desc = (ref($cmd->[1]) eq 'ARRAY') ? $cmd->[1] : [$cmd->[1]];

		my %item = (
			desc => $desc,
			callback => $cmd->[2]
		);

		warning TF("Command '%s' will be overriden\n", $name) if exists $commands{$name} && $commands{$name};

		$commands{$name} = \%item;
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
		delete $commands{$name};
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
		if (AI::state == AI::AUTO) {
			message T("AI is already set to auto mode\n"), "success";
		} else {
			AI::state(AI::AUTO);
			message T("AI set to auto mode\n"), "success";
		}
	} elsif ($args eq 'manual') {
		# Set AI to manual mode
		if (AI::state == AI::MANUAL) {
			message T("AI is already set to manual mode\n"), "success";
		} else {
			AI::state(AI::MANUAL);
			message T("AI set to manual mode\n"), "success";
		}
	} elsif ($args eq 'off') {
		# Turn AI off
		if (AI::state == AI::OFF) {
			message T("AI is already off\n"), "success";
		} else {
			AI::state(AI::OFF);
			message T("AI turned off\n"), "success";
		}

	} elsif ($args eq '') {
		# Toggle AI
		if (AI::state == AI::AUTO) {
			AI::state(AI::OFF);
			message T("AI turned off\n"), "success";
		} elsif (AI::state == AI::OFF) {
			AI::state(AI::MANUAL);
			message T("AI set to manual mode\n"), "success";
		} elsif (AI::state == AI::MANUAL) {
			AI::state(AI::AUTO);
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
	if (AI::state == AI::OFF) {
		message TF("ai_seq (off) = %s\n", "@ai_seq"), "list";
	} elsif (AI::state == AI::MANUAL) {
		message TF("ai_seq (manual) = %s\n", "@ai_seq"), "list";
	} elsif (AI::state == AI::AUTO) {
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
	my ($command, $arg1) = parseArgs( $args );

	if ($command eq "") {
		if (@arrowCraftID) {
			my $msg = center(" ". T("Item To Craft") ." ", 50, '-') ."\n";
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
			 	"Type 'arrowcraft' to get list.\n");
		}
	} elsif ($command eq "use") {
		if (defined binFind(\@skillsID, 'AC_MAKINGARROW')) {
			main::ai_skillUse('AC_MAKINGARROW', 1, 0, 0, $accountID);
		} else {
			error T("Error in function 'arrowcraft use' (Create Arrows)\n" .
				"You don't have Arrow Making Skill.\n");
		}
	} elsif ($command eq "forceuse") {
		my $item = $char->inventory->get($arg1);
		if ($item) {
			$messageSender->sendArrowCraft($item->{nameID});
			$char->{selected_craft} = 1;
		} else {
			error TF("Error in function 'arrowcraft forceuse #' (Create Arrows)\n" .
				"You don't have item %s in your inventory.\n", $arg1);
		}
	} else {
		if ($arrowCraftID[$command] ne "") {
			$messageSender->sendArrowCraft($char->inventory->get($arrowCraftID[$command])->{nameID});
			$char->{selected_craft} = 1;
		} else {
			error T("Error in function 'arrowcraft' (Create Arrows)\n" .
				"Usage: arrowcraft [<identify #>]\n" .
				"Type 'arrowcraft use' to get list.\n");
		}
	}
}

sub cmdPoison {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($command) = parseArgs( $args );

	if ($command eq "") {
		if (@arrowCraftID) {
			my $msg = center(" ". T("Poison List") ." ", 50, '-') ."\n";
			for (my $i = 0; $i < @arrowCraftID; $i++) {
				next if ($arrowCraftID[$i] eq "");
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$i, $char->inventory->get($arrowCraftID[$i])->{name}]);
			}
			$msg .= ('-'x50) . "\n";
			message $msg, "list";
		} else {
			error T("Error in function 'poison' (Apply Poison)\n" .
			 	"Type 'poison' to get list.\n");
		}
		
	} elsif ($command eq "use") {
		if (defined binFind(\@skillsID, 'GC_POISONINGWEAPON')) {
			main::ai_skillUse('GC_POISONINGWEAPON', 5, 0, 0, $accountID);
		} else {
			error T("Error in function 'poison use' (Use Poison)\n" .
				"You don't have Poisonous Weapon Skill.\n");
		}
	} else {
		if ($arrowCraftID[$command] ne "") {
			$messageSender->sendArrowCraft($char->inventory->get($arrowCraftID[$command])->{nameID});
			$char->{selected_craft} = 1;
		} else {
			error T("Error in function 'poison' (Apply Poison)\n" .
				"Usage: poison [<poison #>]\n" .
				"Type 'poison' to get list.\n");
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

sub cmdAttendance {
	my (undef, $args) = @_;
	my ($command) = parseArgs( $args );

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if ( $command eq "open" ) {
		$messageSender->sendOpenUIRequest(5);
	} elsif ( $command eq "request" ) {
		$messageSender->sendAttendanceRewardRequest();
	} else {
		error T("Syntax Error in function 'attendance'\n" .
				"attendance <open|request>\n");
	}
}

sub cmdAutoBuy {
	message T("Initiating auto-buy.\n");
	AI::queue("buyAuto");
	Plugins::callHook('AI_buy_auto_queued');
}

sub cmdAutoSell {
	my (undef, $arg) = @_;
	if ($arg eq 'simulate' || $arg eq 'test' || $arg eq 'debug') {
		# Simulate list of items to sell
		my @sellItems;
		my $msg = center(T(" Items to sell (simulation) "), 50, '-') ."\n".
				T("Amount  Item Name\n");
		for my $item (@{$char->inventory}) {
			next if ($item->{unsellable});
			my $control = items_control($item->{name},$item->{nameID});
			if ($control->{'sell'} && $item->{'amount'} > $control->{keep}) {
				my %obj;
				$obj{index} = $item->{ID};
				$obj{amount} = $item->{amount} - $control->{keep};
				my $item_name = $item->{name};
				$item_name .= T(" (if unequipped)") if ($item->{equipped});
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
		Plugins::callHook('AI_sell_auto_queued');
	}
}

sub cmdAutoStorage {
	message T("Initiating auto-storage.\n");
	if (ai_canOpenStorage()) {
		AI::queue("storageAuto");
		Plugins::callHook('AI_storage_auto_queued');
	} else {
		error T("Error in function 'autostorage' (Automatic storage of items)\n" .
		"You cannot use the Storage Service. Very low level of basic skills or not enough zeny.\n");
	}
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

sub cmdBank {
	my (undef, $args) = @_;
	my ($command, $zeny) = parseArgs( $args );

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if ( $command eq "open" ) {
		$messageSender->sendBankingCheck($accountID);
	} elsif ( ( $command eq "deposit" || $command eq "withdraw" ) && !$bankingopened ) {
		error T("Bank: You have to open bank before try to use the commands.\n");
	} elsif ( $command eq "deposit" ) {
		if( $zeny =~ /\d+/ ) {
			if( $zeny <= $char->{zeny} ) {
				$messageSender->sendBankingDeposit($accountID, $zeny);
			} else {
				error T("Bank: You don't have that amount of zeny to DEPOSIT in Bank.\n");
			}
		} else {
			error T("Syntax Error in function 'bank' (Banking)\n" .
				"bank deposit <amount>\n");
		}
	} elsif ( $command eq "withdraw" ) {
		if( $zeny =~ /\d+/ ) {
			$messageSender->sendBankingWithdraw($accountID, $zeny);
		} else {
			error T("Syntax Error in function 'bank' (Banking)\n" .
				"bank withdraw <amount>\n");
		}
	} else {
		error T("Syntax Error in function 'bank' (Banking)\n" .
				"bank <open|deposit|withdraw>\n");
	}
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

		} elsif (!$storeList->get($index)) {
			error TF("Error in function 'buy' (Buy Store Item)\n" .
				"Store Item %s does not exist.\n", $index);
			return;

		} elsif ($amount eq "" || $amount <= 0) {
			$amount = 1;
		}

		my $itemID = $storeList->get($index)->{nameID};
		push (@bulkitemlist,{itemID  => $itemID, amount => $amount});
	}

	completeNpcBuy(\@bulkitemlist);
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
				$messageSender->sendCardMerge($char->inventory->get($cardMergeIndex)->{ID},
					$char->inventory->get($arg2)->{ID});
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
				$messageSender->sendCardMergeRequest($char->inventory->get($cardMergeIndex)->{ID});
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
		for my $item (@{$char->inventory}) {
			if ($item->mergeable) {
				my $display = "$item->{name} x $item->{amount}";
				$msg .= swrite(
					"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$item->{binID}, $display]);
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
			$messageSender->sendCardMerge($char->inventory->get($arg2)->{ID},
				$char->inventory->get($arg3)->{ID});
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
		if($arg2 ne "") {
			cmdCart_desc($arg2);
		} else {
			error T("Usage: cart desc <cart item #>\n");
		}
	} elsif (($arg1 eq "add" || $arg1 eq "get" || $arg1 eq "release" || $arg1 eq "change") && (!$net || $net->getState() != Network::IN_GAME)) {
		error TF("You must be logged in the game to use this command '%s'\n", 'cart ' .$arg1);
			return;

	} elsif ($arg1 eq "add") {
		if($arg2 ne "") {
			cmdCart_add($arg2);
		} else {
			error T("Usage: cart add <inventory item> <amount>\n");
		}
	} elsif ($arg1 eq "get") {
		if($arg2 ne "") {
			cmdCart_get($arg2);
		} else {
			error T("Usage: cart get <cart item> <amount>\n");
		}
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
			printItemDesc($item);
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

	for my $item (@{$char->cart}) {
		if ($item->usable) {
			push @useable, $item->{binID};
		} elsif ($item->equippable) {
			my %eqp;
			$eqp{index} = $item->{ID};
			$eqp{binID} = $item->{binID};
			$eqp{name} = $item->{name};
			$eqp{amount} = $item->{amount};
			$eqp{identified} = " -- " . T("Not Identified") if !$item->{identified};
			$eqp{type} = $itemTypes_lut{$item->{type}};
			push @equipment, \%eqp;
		} else {
			push @non_useable, $item->{binID};
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
			$char->cart->items, $char->cart->items_max, $char->cart->{weight}, $char->cart->{weight_max}).
			('-'x50) . "\n";
	message $msg, "list";
}

sub cmdCart_add {
	my $items = shift;

	my ( $name, $amount );
	if ( $items =~ /^[^"'].* .+$/ ) {
		# Backwards compatibility: "cart add Empty Bottle 1" still works.
		( $name, $amount ) = $items =~ /^(.*?)(?: (\d+))?$/;
	} else {
		( $name, $amount ) = parseArgs( $items );
	}
	my @items = $char->inventory->getMultiple( $name );
	if ( !@items ) {
		error TF( "Inventory item '%s' does not exist.\n", $name );
		return;
	}

	transferItems( \@items, $amount, 'inventory' => 'cart' );
}

sub cmdCart_get {
	my $items = shift;

	my ( $name, $amount );
	if ( $items =~ /^[^"'].* .+$/ ) {
		# Backwards compatibility: "cart get Empty Bottle 1" still works.
		( $name, $amount ) = $items =~ /^(.*?)(?: (\d+))?$/;
	} else {
		( $name, $amount ) = parseArgs( $items );
	}
	my @items = $char->cart->getMultiple( $name );
	if ( !@items ) {
		error TF( "Cart item '%s' does not exist.\n", $name );
		return;
	}

	transferItems( \@items, $amount, 'cart' => 'inventory' );
}

sub cmdCash {
	my (undef, $args) = @_;
	my (@args) = parseArgs($args);

	if ($args[0] eq 'open') {
		if (defined $cashShop{points}) {
			error T("Cash shop already opened this session\n");
			return;
		}

		$messageSender->sendCashShopOpen();
		return;
	}

	if ($args[0] eq 'close') {
		if (not defined $cashShop{points}) {
			error T("Cash shop is not open\n");
			return;
		}

		$messageSender->sendCashShopClose();
		return;
	}

	if ($args[0] eq 'list') {
		if (not defined $cashShop{list}) {
			error T("The list of items of Cash shop is not available\n");
			return;
		}
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

		return;
	}

	if (not defined $cashShop{points}) {
		error T("Cash shop is not open\n");
		error T("Please use 'cash open' first\n");
		return;
	}

	if ($args[0] eq 'buy') {
		if (scalar @args < 2 || !$args[1]) {
			error T("Syntax Error in function 'cash buy' (Cash shop)\n" .
				"Usage: cash buy <item> [<amount>] [<kafra shop points>]\n");
			return;
		}

		my ($amount, $item, $kafra_points);

		if ($args[1] !~ /^\d+$/) {
			$item = itemNameToID($args[1]);
			if (!$item) {
				error TF("Error in function 'cash buy': invalid item name '%s' or tables needs to be updated\n", $args[1]);
				return;
			}
		} else {
			$item = $args[1];
		}

		if (scalar @args < 3 || $args[2] !~ /^\d+$/) {
			$amount = 1;
		} else {
			$amount = $args[2];
		}

		if (scalar @args >= 4) {
			$kafra_points = $args[3];
		} else {
			$kafra_points = 0;
		}

		if ($kafra_points > $cashShop{points}->{kafra}) {
			error TF("You don't have that many kafra shop points (Requested: %d, Available: %d)", $kafra_points, $cashShop{points}->{kafra});
			return;
		}

		for (my $i = 0; $i < scalar @{$cashShop{list}}; ++$i) {
			foreach my $item_in_tab (@{$cashShop{list}[$i]}) {
				if ($item_in_tab->{item_id} == $item) {
					if ($item_in_tab->{price} * $amount > $cashShop{points}->{cash} + $kafra_points) {
						error TF("Not enough cash to buy item %s x %d (%sC), we have %sC\n",
							itemNameSimple($item_in_tab->{item_id}), $amount, formatNumber($item_in_tab->{price} * $amount),
							formatNumber($cashShop{points}->{cash} + $kafra_points)
						);
						return;
					}

					message TF("Buying %s from cash shop \n", itemNameSimple($item_in_tab->{item_id}));
					$messageSender->sendCashBuy($kafra_points, [{nameID => $item_in_tab->{item_id}, amount => $amount, tab => $i}]);
					return;
				}
			}
		}

		error TF("Error in function 'cash buy': item %s not found or shop list is not ready yet.", itemNameSimple($item));
		return;

	}

	if ($args[0] eq 'points') {
		message TF("Cash Points: %sC - Kafra Points: %sC\n", formatNumber($cashShop{points}->{cash}), formatNumber($cashShop{points}->{kafra}));
		return;
	}

	error T("Syntax Error in function 'cash' (Cash shop)\n" .
			"Usage: cash <open | close | buy | points | list>\n");
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

sub cmdCloseBuyerShop {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	main::closeBuyerShop();
}

sub cmdConf {
	my (undef, $args) = @_;
	my ( $force, $arg1, $arg2 ) = $args =~ /^(-f\s+)?(\S+)\s*(.*)$/;

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
		error T("Syntax Error in function 'conf' (Change a Configuration Key)\n");
		error T("Usage: conf [-f] <variable> [<value>|none]\n");
		error T("  -f  force variable to be set, even if it does not already exist in config.txt\n");

	} elsif ($arg1 =~ /\*/) {
		my $pat = $arg1;
		$pat =~ s/\*/.*/gso;
		my @keys = grep {/$pat/i} sort keys %config;
		error TF( "Config variables matching %s do not exist\n", $arg1 ) if !@keys;
		message TF( "Config '%s' is %s\n", $_, defined $config{$_} ? $config{$_} : 'not set' ), "info" foreach @keys;

	} elsif (!exists $config{$arg1} && !$force) {
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
		my ( $partner ) = grep { $_->name eq $arg[0] } @$playersList;
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
		$messageSender->sendDealAddItem(pack('v', 0), $currentDeal{'you_zeny'});
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
			dealAddItem( $item, min( $item->{amount}, $arg[2] || $item->{amount} ) );
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
		my $items = [ grep { $_ && lc( $_->{name} ) eq lc( $arg[1] ) && !$_->{equipped} } @$char->inventory ];
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

	if ($arg1 =~ /\d/) {
		configModify("debug", $arg1);
	} elsif ($arg1 eq "info") {
		my $connected = $net && "server=".($net->serverAlive ? "yes" : "no").
			",client=".($net->clientAlive ? "yes" : "no");
		my $time = $packetParser && sprintf("%.2f", time - $packetParser->{lastPacketTime});
		my $ai_timeout = sprintf("%.2f", time - $timeout{'ai'}{'time'});
		my $ai_time = sprintf("%.4f", time - $ai_v{'AI_last_finished'});

		message center(T(" Debug information "), 56, '-') ."\n".
			TF("ConState: %s\t\tConnected: %s\n" .
			"AI enabled: %s\n" .
			"\@ai_seq = %s\n" .
			"Last packet: %.2f secs ago\n" .
			"\$timeout{ai}: %.2f secs ago  (value should be >%s)\n" .
			"Last AI() call: %.2f secs ago\n" .
			('-'x56) . "\n",
		$conState, $connected, AI::state, "@ai_seq", $time, $ai_timeout,
		$timeout{'ai'}{'timeout'}, $ai_time), "list";
	} else {
		error "Syntax Error in function 'debug' (Toggle debug on/off)\n";
	}
}

sub cmdDoriDori {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my $headdir = ($char->{look}{head} == 2) ? 1 : 2;

	$messageSender->sendLook($char->{look}{body}, $headdir);
	$messageSender->sendNoviceDoriDori();
}

sub cmdDrop {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\d+[\d,-]*)/;
	my ($arg2) = $args =~ /^[\d,-]+ (\d+)$/;

	if ($arg1 eq "") {
		error T("Syntax Error in function 'drop' (Drop Inventory Item)\n" .
			"Usage: drop <inventory_item_list> [<amount>]\n");
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
			$item->{name}, $item->{binID});
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
	message TF("=====[Character Equip List]=====\n"), "info";
	for my $slot (@Actor::Item::slots) {
		my $item = $char->{equipment}{$slot};
		my $name = $item ? $item->{name} : '-';
		($item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19) ?
			message sprintf("%-15s: %s x %s\n", $slot, $name, $item->{amount}), "list" :
			message sprintf("%-15s: %s\n", $slot, $name), "list";
	}
	message "================================\n", "info";
}

sub cmdEquipSwitch {
	# Equip an item
	my (undef, $args) = @_;
	my ($arg1,$arg2) = $args =~ /^(\S+)\s*(.*)/;
	my $slot;
	my $item;

	if ($arg1 eq "") {
		cmdEquipsw_list();
		return;
	}

	if ($arg1 eq "slots") {
		# Translation Comment: List of equiped items on each slot
		message T("Slots:\n") . join("\n", @Actor::Item::slots). "\n", "list";
		return;
	}

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", 'eqsw ' .$args);
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
			$item->{name}, $item->{binID});
		return;
	}

	if ($slot) {
		$item->equip_switch_slot($slot);
	} else {
		$item->equip_switch();
	}
}

sub cmdEquipsw_list {
	if (!$char) {
		error T("Character equipment not yet ready\n");
		return;
	}
	message TF("=====[Equip Switch List]=====\n"), "info";
	for my $slot (@Actor::Item::slots) {
		my $item = $char->{eqswitch}{$slot};
		my $name = $item ? $item->{name} : '-';
		($item->{type} == 10 || $item->{type} == 16 || $item->{type} == 17 || $item->{type} == 19)
			? message sprintf("%-15s: %s x %s\n", $slot, $name, $item->{amount}), "list"
			: message sprintf("%-15s: %s\n", $slot, $name), "list";
	}
	message "=============================\n", "info";
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
			"Usage: exp [<report | monster | item | reset | output>]\n");
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
				$messageSender->sendFriendRequest($player->{name});
			}
		}

	} elsif ($arg1 eq "remove") {
		if ($arg2 !~ /^\d+$/ || $arg2 < 1 || $arg2 > @friendsID) {
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
		if ($arg2 !~ /^\d+$/ || $arg2 < 1 || $arg2 > @friendsID) {
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

	} elsif ($slave->isa("AI::Slave::Homunculus") && $slave->{vaporized}) {
			my $skill = new Skill(handle => 'AM_CALLHOMUN');
			error TF("Homunculus is in rest, use skills '%s' (ss %d).\n", $skill->getName, $skill->getIDN);

	} elsif ($slave->isa("AI::Slave::Homunculus") && $slave->{dead}) {
			my $skill = new Skill(handle => 'AM_RESURRECTHOMUN');
			error TF("Homunculus is dead, use skills '%s' (ss %d).\n", $skill->getName, $skill->getIDN);

	} elsif ($subcmd eq "s" || $subcmd eq "status") {
		my $hp_string = $slave->{hp}. '/' .$slave->{hp_max} . ' (' . sprintf("%.2f",$slave->hp_percent) . '%)';
		my $sp_string = $slave->{sp}."/".$slave->{sp_max}." (".sprintf("%.2f",$slave->sp_percent)."%)";
		my $exp_string = (
			defined $slave->{exp}
			? T("Exp: ") . formatNumber($slave->{exp})."/".formatNumber($slave->{exp_max})." (".sprintf("%.2f",$slave->exp_percent)."%)"
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
		$jobs_lut{$slave->{'jobID'}},
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
		if ($slave->isa("AI::Slave::Mercenary")) {
			$messageSender->sendMercenaryCommand (2);
		} elsif ($slave->isa("AI::Slave::Homunculus")) {
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
			$messageSender->sendSlaveMove($slave->{ID}, $args[1], $args[2]);
		}

	} elsif ($subcmd eq "standby") {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command '%s'\n", $cmd .' ' .$subcmd);
			return;
		}
		$messageSender->sendSlaveStandBy($slave->{ID});

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
		if ($char->{homunculus}{renameflag} == 0) {
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

sub cmdMiscConf {
	my (undef, $args) = @_;
	my ($command, $flag) = parseArgs( $args );

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my $check = ($flag eq 'on') ? 1 : 0;

	if ( $command eq "show_eq" ) {
		$messageSender->sendMiscConfigSet(0, $check);
	} elsif ( $command eq "call" ) {
		$messageSender->sendMiscConfigSet(1, $check);
	} elsif ( $command eq "pet_feed" ) {
		$messageSender->sendMiscConfigSet(2, $check);
	} elsif ( $command eq "homun_feed" ) {
		$messageSender->sendMiscConfigSet(3, $check);
	} else {
		error T("Syntax Error in function 'misc_conf' (Misc Configuration)\n" .
				"misc_conf <show_eq|call|pet_feed|homun_feed> <on|off>\n");
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

	if ($cmd eq 'gmb' || $cmd eq 'gmlb') {
		$message = "$char->{name}: $message";
	} elsif ($cmd eq 'gmbb' || $cmd eq 'gmlbb') {
		$message = "blue$message";
	} elsif ($cmd ne 'gmnb' && $cmd ne 'gmlnb') {
		error TF("Usage: %s <MESSAGE>\n", $cmd);
		return;
	}

	if ($cmd =~ /^gml/) {
		$messageSender->sendGMBroadcastLocal($message);
	} else {
		$messageSender->sendGMBroadcast($message);
	}
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

	$messageSender->sendGMMapMove($map_name, $x, $y);
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

	$messageSender->sendGMKick($args);
}

sub cmdGmkickall {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	$messageSender->sendGMKickAll();
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

	$messageSender->sendGMMonsterItem($args);
}

sub cmdGmhide {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	$messageSender->sendGMChangeEffectState(0);
}

sub cmdGmresetstate {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	$messageSender->sendGMResetStateSkill(0);
}

sub cmdGmresetskill {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	$messageSender->sendGMResetStateSkill(1);
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

	$messageSender->sendAlignment($ID, 1, $time);
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

	$messageSender->sendAlignment($ID, 0, $time);
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

	$messageSender->sendGMShift($args);
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

	$messageSender->sendGMRecall($args);
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

	$messageSender->sendGMRemove($args);
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
			$title = $guild{positions}[ $guild{member}[$i]{position} ]{title};

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
			$messageSender->sendGuildCreate($arg2, $charID);
		}

	} elsif (!defined $char->{guild}) {
		error T("You are not in a guild.\n");

	} elsif ($arg1 eq "request") {
		my $player = Match::player($arg2);
		if (!$player) {
			error TF("Player %s does not exist.\n", $arg2);
		} else {
			$messageSender->sendGuildJoinRequest($player->{ID}, $charID);
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
			$messageSender->sendGuildSetAlly($player->{ID}, $accountID, $charID);
			message TF("Sent guild alliance request to %s\n", $player->{name});
		}

	} elsif ($arg1 eq "leave") {
		$messageSender->sendGuildLeave($arg2, $guild{ID}, $charID);
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

	my $msg = center(T(" Available commands "), 79, '=') ."\n" unless @commands_req;

	my @commands = (@commands_req)? @commands_req : (sort keys %commands);

	foreach my $switch (@commands) {
		if ($commands{$switch}) {
			if (ref($commands{$switch}{desc}) eq 'ARRAY') {
				if (@commands_req) {
					helpIndent($switch,$commands{$switch}{desc});
				} else {
					$msg .= sprintf("%-11s  %s\n",$switch, $commands{$switch}{desc}->[0]);
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

	$message = center(TF(" Help for '%s' ", $cmd), 119, "=")."\n";
	$message .= shift(@tmp) . "\n";

	foreach (@tmp) {
		$length = length($_->[0]) if length($_->[0]) > $length;
	}
	my $pattern = "$cmd %-${length}s    %s\n";
	my $padsize = length($cmd) + $length + 5;
	my $pad = sprintf("%-${padsize}s", '');

	foreach (@tmp) {
		if ($padsize + length($_->[1]) > 120) {
			@words = split(/ /, $_->[1]);
			$message .= sprintf("$cmd %-${length}s    ", $_->[0]);
			$messageTmp = '';
			foreach my $word (@words) {
				if ($padsize + length($messageTmp) + length($word) + 1 > 119) {
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
	$message .= "=" x 119 . "\n";
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
			$messageSender->sendIdentify($char->inventory->get($identifyID[$arg1])->{ID});
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

		for my $item (@{$char->inventory}) {
			if ($item->usable) {
				push @useable, $item->{binID};
			} elsif ($item->equippable && $item->{type_equip} != 0) {
				my %eqp;
				$eqp{index} = $item->{ID};
				$eqp{binID} = $item->{binID};
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
				push @non_useable, $item->{binID};
			}
		}
		# Start header -- Note: Title is translatable.
		my $msg = center(T(" Inventory "), 50, '-') ."\n";

		if ($arg1 eq "" || $arg1 eq "eq") {
			# Translation Comment: List of equipment items worn by character
			$msg .= T("-- Equipment (Equipped) --\n");
			foreach my $item (@equipment) {
				$sell = defined(findIndex(\@sellList, "binID", $item->{binID})) ? T("Will be sold") : "";
				$display = sprintf("%-3d  %s -- %s", $item->{binID}, $item->{name}, $item->{equipped});
				$msg .= sprintf("%-57s %s\n", $display, $sell);
			}
		}

		if ($arg1 eq "" || $arg1 eq "neq") {
			# Translation Comment: List of equipment items NOT worn
			$msg .= T("-- Equipment (Not Equipped) --\n");
			foreach my $item (@uequipment) {
				$sell = defined(findIndex(\@sellList, "binID", $item->{binID})) ? T("Will be sold") : "";
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
				$sell = defined(findIndex(\@sellList, "binID", $index)) ? T("Will be sold") : "";
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
				$sell = defined(findIndex(\@sellList, "binID", $index)) ? T("Will be sold") : "";
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

	printItemDesc($item);
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
		for my $monster (@$monstersList) {
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
					main::ai_route($field->baseName, $portals{$portalsID[$map_or_portal]}{'pos'}{'x'}, $portals{$portalsID[$map_or_portal]}{'pos'}{'y'}, attackOnRoute => 2, noSitAuto => 1);
				} else {
					error T("No portals exist.\n");
				}
			} else {
				# map
				$map_or_portal =~ s/^(\w{3})?(\d@.*)/$2/; # remove instance. is it possible to move to an instance? if not, we could throw an error here
				# TODO: implement Field::sourceName function here once they are implemented there - 2013.11.26
				my $file = $map_or_portal.'.fld2';
				$file = File::Spec->catfile($Settings::fields_folder, $file) if ($Settings::fields_folder);
				$file .= ".gz" if (! -f $file); # compressed file
				if ($maps_lut{"${map_or_portal}.rsw"} || -f $file) {
					my $move_field = new Field(name => $map_or_portal);
					if (defined $x && defined $y) {
						if ($move_field->isOffMap($x, $y)) {
							error TF("Coordinates %s %s are off the map %s\n",$x, $y, $map_or_portal);
							return;
						}
						if (!$move_field->isWalkable($x, $y)) {
							error TF("Coordinates %s %s are not walkable on the map %s\n",$x, $y, $map_or_portal);
							return;
						}
					}
					my $map_name = $maps_lut{"${map_or_portal}.rsw"} ? $maps_lut{"${map_or_portal}.rsw"} : T('Unknown Map');
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
					attackOnRoute => 2,
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

		for my $npc (@$npcsList) {
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

sub cmdOpenBuyerShop {
	my (undef, $args) = @_;

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	main::openBuyerShop();

}

sub cmdParty {
	my (undef, $args) = @_;
	my ($arg1, $arg2) = parseArgs($args, 2);

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command\n");
	} elsif (!$char) {
		error T("Error in function 'party' (Party Functions)\n" .
			"Party info not available yet\n");
	} elsif (!$char->{party}{joined}) {
		if ($arg1 eq "create") {
			if ($arg2 eq "") {
				error T("Syntax Error in function 'party create' (Organize Party)\n" .
					"Usage: party create <party name>\n");
			} else {
				$messageSender->sendPartyOrganize($arg2);
			}
		} elsif ($arg1 eq "join") {
			if ($arg2 ne "1" && $arg2 ne "0") {
				error T("Syntax Error in function 'party join' (Accept/Deny Party Join Request)\n" .
					"Usage: party join <flag>\n");
			} elsif ($incomingParty{ID} eq "") {
				error T("Error in function 'party join' (Join/Request to Join Party)\n" .
					"Can't accept/deny party request - no incoming request.\n");
			} else {
				if ($incomingParty{ACK} eq '02C7') {
					$messageSender->sendPartyJoinRequestByNameReply($incomingParty{ID}, $arg2);
				} else {
					$messageSender->sendPartyJoin($incomingParty{ID}, $arg2);
				}
				undef %incomingParty;
			}
		} else {
			error T("Error in function 'party' (Party Functions)\n" .
				"You're not in a party.\n");
		}
	} elsif ($char->{party}{joined} && ($arg1 eq "create" || $arg1 eq "join")) {
		error T("Error in function 'party' (Party Functions)\n" .
			"You're already in a party.\n");
	} elsif ($arg1 eq "" || $arg1 eq "info") {
		my $msg = center(T(" Party Information "), 84, '-') ."\n".
			TF("Party name: %s\n" .
			"EXP Take: %s       Item Take: %s       Item Division: %s\n\n".
			"#    Name                   Map           Coord     Online  HP\n",
			$char->{'party'}{'name'},
			($char->{party}{share}) ? T("Even") : T("Individual"),
			($char->{party}{itemPickup}) ? T("Even") : T("Individual"),
			($char->{party}{itemDivision}) ? T("Even") : T("Individual"));
		for (my $i = 0; $i < @partyUsersID; $i++) {
			next if ($partyUsersID[$i] eq "");
			my $coord_string = "";
			my $hp_string = "";
			my $name_string = $char->{'party'}{'users'}{$partyUsersID[$i]}{'name'};
			my $admin_string = ($char->{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) ? T("A") : "";
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
				"@< @ @<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<< @<<<<<<<  @<<     @<<<<<<<<<<<<<<<<<<<<<<<",
				[$i, $admin_string, $name_string, $map_string, $coord_string, $online_string, $hp_string]);
		}
		$msg .= ('-'x84) . "\n";
		message $msg, "list";

	} elsif ($arg1 eq "leave") {
		$messageSender->sendPartyLeave();
	# party leader specific commands
	} elsif ($arg1 eq "share" || $arg1 eq "shareitem" || $arg1 eq "shareauto" || $arg1 eq "sharediv" || $arg1 eq "kick" || $arg1 eq "leader" || $arg1 eq "request") {
		if ($arg2 ne "") {
			my $party_admin;
			# check if we are the party leader before using leader specific commands.
			for (my $i = 0; $i < @partyUsersID; $i++) {
				if (($char->{'party'}{'users'}{$partyUsersID[$i]}{'admin'}) && ($char->{'party'}{'users'}{$partyUsersID[$i]}{'name'} eq $char->name)){
					debug T("You are the party leader.\n"), "info";
					$party_admin = 1;
					last;
				}
			}

			if (!$party_admin) {
				error TF("Error in function 'party %s'\n" .
					"You must be the party leader in order to use this !\n", $arg1);
				return;
			}
		}

		if ($arg1 eq "request") {
			if ($arg2 =~ /\D/ || $args =~ /".*"/) {
				message TF("Requesting player %s to join your party.\n", $arg2);
				$messageSender->sendPartyJoinRequestByName($arg2);
			} else {
				if ($playersID[$arg2] eq "") {
					error TF("Error in function 'party request' (Request to Join Party)\n" .
						"Can't request to join party - player %s does not exist.\n", $arg2);
				} else {
					$messageSender->sendPartyJoinRequest($playersID[$arg2]);
				}
			}
		} elsif ($arg1 eq "share"){
			if ($arg2 ne "1" && $arg2 ne "0") {
				if ($arg2 eq "") {
					message TF("Party EXP is set to '%s Take'\n", ($char->{party}{share}) ? T("Even") : T("Individual"));
				} else {
					error T("Syntax Error in function 'party share' (Set Party Share EXP)\n" .
						"Usage: party share <flag>\n");
				}
			} else {
				$messageSender->sendPartyOption($arg2, $char->{party}{itemPickup}, $char->{party}{itemDivision});
				$char->{party}{shareForcedByCommand} = 1;
			}
		} elsif ($arg1 eq "shareitem") {
			if ($arg2 ne "1" && $arg2 ne "0") {
				if ($arg2 eq "") {
					message TF("Party item is set to '%s Take'\n", ($char->{party}{itemPickup}) ? T("Even") : T("Individual"));
				} else {
					error T("Syntax Error in function 'party shareitem' (Set Party Share Item)\n" .
						"Usage: party shareitem <flag>\n");
				}
			} else {
				$messageSender->sendPartyOption($char->{party}{share}, $arg2, $char->{party}{itemDivision});
				$char->{party}{shareForcedByCommand} = 1;
			}
		} elsif ($arg1 eq "sharediv") {
			if ($arg2 ne "1" && $arg2 ne "0") {
				if ($arg2 eq "") {
					message TF("Party item division is set to '%s Take'\n", ($char->{party}{itemDivision}) ? T("Even") : T("Individual"));
				} else {
					error T("Syntax Error in function 'party sharediv' (Set Party Item Division)\n" .
						"Usage: party sharediv <flag>\n");
				}
			} else {
				$messageSender->sendPartyOption($char->{party}{share}, $char->{party}{itemPickup}, $arg2);
				$char->{party}{shareForcedByCommand} = 1;
			}
		} elsif ($arg1 eq "shareauto") {
			$messageSender->sendPartyOption($config{partyAutoShare}, $config{partyAutoShareItem}, $config{partyAutoShareItemDiv});
			$char->{party}{shareForcedByCommand} = undef;
		} elsif ($arg1 eq "kick") {
			if ($arg2 eq "") {
				error T("Syntax Error in function 'party kick' (Kick Party Member)\n" .
					"Usage: party kick <party member>\n");
			} elsif ($arg2 =~ /\D/ || $args =~ /".*"/) {
				my $found;
				foreach (@partyUsersID) {
					if ($char->{'party'}{'users'}{$_}{'name'} eq $arg2) {
						$messageSender->sendPartyKick($_, $arg2);
						$found = 1;
						last;
					}
				}

				if (!$found) {
					error TF("Error in function 'party kick' (Kick Party Member)\n" .
						"Can't kick member - member %s doesn't exist.\n", $arg2);
				}
			} else {
				if ($partyUsersID[$arg2] eq "") {
					error TF("Error in function 'party kick' (Kick Party Member)\n" .
						"Can't kick member - member %s doesn't exist.\n", $arg2);
				} else {
					$messageSender->sendPartyKick($partyUsersID[$arg2], $char->{'party'}{'users'}{$partyUsersID[$arg2]}{'name'});
				}
			}
		} elsif ($arg1 eq "leader") {
			my $found;
			if ($arg2 eq "") {
				error T("Syntax Error in function 'party leader' (Change Party Leader)\n" .
					"Usage: party leader <party member>\n");
			} elsif ($arg2 =~ /\D/ || $args =~ /".*"/) {
				foreach (@partyUsersID) {
					if ($char->{'party'}{'users'}{$_}{'name'} eq $arg2) {
						$found = $_;
						last;
					}
				}
				if (!$found) {
					error TF("Error in function 'party leader' (Change Party Leader)\n" .
						"Can't change party leader - member %s doesn't exist.\n", $arg2);
				}
			} else {
				if ($partyUsersID[$arg2] eq "") {
					error TF("Error in function 'party leader' (Change Party Leader)\n" .
						"Can't change party leader - member %s doesn't exist.\n", $arg2);
				} else {
					$found = $partyUsersID[$arg2];
				}
			}
			if ($found && $found eq $accountID) {
				warning T("Can't change party leader - you are already a party leader.\n");
			} else {
				$messageSender->sendPartyLeader($found);
			}
		}
	} else {
		error T("Syntax Error in function 'party' (Party Management)\n" .
			"Usage: party [<info|create|join|request|leave|share|shareitem|sharediv|shareauto|kick|leader>]\n");
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
				error TF("Error in function 'pet [capture|c]' (Capture Pet)\n" .
					"Monster %s does not exist.\n", $args[1]);
			} else {
				$messageSender->sendPetCapture($monstersID[$args[1]]);
			}
		} else {
			error TF("Error in function 'pet [capture|c]' (Capture Pet)\n" .
				"'%s' must be a monster index.\n", $args[1]);
		}

	} elsif ($args[0] eq "h" || $args[0] eq "hatch") {
		if(my $item = Match::inventoryItem($args[1])) {
			# beware, you must first use the item "Pet Incubator", else you will get disconnected
			$messageSender->sendPetHatch($item->{ID});
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

	} elsif (($args[0] eq "e" || $args[0] eq "emotion") && $args[1]) {
		if ($args[1] =~ /^\d+$/) {
		$messageSender->sendPetEmotion($args[1]);
		} else {
			error TF("Error in function 'pet [emotion|e] <number>' (Emotion Pet)\n" .
				"'%s' must be an integer.\n", $args[1]);
		}

	} else {
		message T("Usage: pet [capture <monster #> | hatch <item #> | status | info | feed | performance | return | unequip | name <name>] | emotion <number>\n"), "info";
	}
}

sub cmdPetList {
	my ($dist, $pos, $name, $pets);
	my $msg = center(T(" Pet List "), 68, '-') ."\n".
		T("#   Name                      Type             Distance  Coordinates\n");

	for my $pet (@$petsList) {
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
		my $maxplg;
		$msg = center(T(" Guild Player List "), 79, '-') ."\n".
			T("#    Name                                Sex   Lv   Job         Dist Coord\n");
		for my $player (@$playersList) {
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
		}
		$msg .= TF("Total guild players: %s\n",$maxplg) if $maxplg;
		if (my $totalPlayers = $playersList && $playersList->size) {
			$msg .= TF("Total players: %s \n", $totalPlayers);
		} else {
			$msg .= T("There are no players near you.\n");
		}
		$msg .= ('-'x79) . "\n";
		message $msg, "list";
		return;
	}

	if ($args eq "p") {
		my $maxplp;
		$msg = center(T(" Party Player List "), 79, '-') ."\n".
			T("#    Name                                Sex   Lv   Job         Dist Coord\n");
		for my $player (@$playersList) {
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
		}
		$msg .= TF("Total party players: %s \n",$maxplp)  if $maxplp;
		if (my $totalPlayers = $playersList && $playersList->size) {
			$msg .= TF("Total players: %s \n", $totalPlayers);
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
			"Title ID : %s\n" .
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
		$player->{nameID}, $hex, $player->{title}{ID} ? $player->{title}{ID}: 'N/A',
		($player->{party} && $player->{party}{name} ne '') ? $player->{party}{name} : '',
		($player->{guild}) ? $player->{guild}{name} : '',
		($player->{guild}) ? $player->{guild}{title} : '',
		$pos->{x}, $pos->{y}, $directions_lut{$youToPlayer}, int($degYouToPlayer),
		$player->{lv}, $dist, $sex_lut{$player->{sex}}, $jobs_lut{$player->{jobID}},
		"$directions_lut{$body} ($body)", "$directions_lut{$head} ($head)",
		itemName({nameID => $player->{weapon}}),
		itemName({nameID => $player->{shield}}),
		$headTop, $headMid,
			  $headLow, $haircolors{$player->hairColor()} . " (" . $player->hairColor() . ")",
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
		$msg = center(T(" Player List "), 79, '-') ."\n".
		T("#    Name                                Sex   Lv   Job         Dist Coord\n");
		for my $player (@$playersList) {
			my ($name, $dist, $pos);
			$name = $player->name;
			if ($player->{guild} && %{$player->{guild}}) {
				$name .= " [$player->{guild}{name}]";
			}
			$dist = distance($char->{pos_to}, $player->{pos_to});
			$dist = sprintf("%.1f", $dist) if (index ($dist, '.') > -1);
			$pos = '(' . $player->{pos_to}{x} . ', ' . $player->{pos_to}{y} . ')';
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<< @<<< @<<<<<<<<<< @<<< @<<<<<<<<<",
				[$player->{binID}, $name, $sex_lut{$player->{sex}}, $player->{lv}, $player->job, $dist, $pos]);
		}
		if (my $playersTotal = $playersList && $playersList->size) {
			$msg .= TF("Total players: %s \n", $playersTotal);
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
			Plugins::reloadPlugins([$Plugins::plugins[$args[1]]]);

		} elsif ($args[1] eq '') {
			error T("Syntax Error in function 'plugin reload' (Reload Plugin)\n" .
				"Usage: plugin reload <plugin name|plugin number#|\"all\">\n");
			return;

		} elsif ($args[1] eq 'all') {
			Plugins::reloadAll();

		} else {
			Plugins::reloadByRegexp($args[1]);
		}

	} elsif ($args[0] eq 'load') {
		if ($args[1] eq '') {
			error T("Syntax Error in function 'plugin load' (Load Plugin)\n" .
				"Usage: plugin load <filename|\"all\">\n");
			return;
		} elsif ($args[1] eq 'all') {
			Plugins::loadAll();
		} else {
			Plugins::loadByRegexp($args[1]);
		}

	} elsif ($args[0] eq 'unload') {
		if ($args[1] =~ /^\d+$/) {
			Plugins::unloadPlugins([$Plugins::plugins[$args[1]]]);

		} elsif ($args[1] eq '') {
			error T("Syntax Error in function 'plugin unload' (Unload Plugin)\n" .
				"Usage: plugin unload <plugin name|plugin number#|\"all\">\n");
			return;

		} elsif ($args[1] eq 'all') {
			Plugins::unloadAll();
			message T("All plugins have been unloaded.\n"), "system";
			return;

		} else {
			Plugins::unloadByRegexp($args[1]);
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
		my $srcfile = $srcMap.'.fld2';
		$srcfile = File::Spec->catfile($Settings::fields_folder, $srcfile) if ($Settings::fields_folder);
		$srcfile .= ".gz" if (! -f $srcfile); # compressed file
		my $dstfile = $dstMap.'.fld2';
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
	} else {
		error T("Syntax Error in function 'portals' (List portals)\n" .
			"Usage: portals or portals <recompile|add>\n");
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
	my (undef, $args) = @_;
	if ($args eq "2") {
		$messageSender->sendQuit();
	}
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
	#stay offline if arg is 0
	if (defined $arg && $arg == 0) {
		offlineMode();
	} elsif (!$arg || $arg =~ /^\d+$/) {
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
	my (undef, $binID) = @_;
	if (!$repairList) {
		error T("'Repair List' is empty.\n");

	} elsif ($binID eq "") {
		my $msg = center(T(" Repair List "), 80, '-') ."\n".
			T("   # Short name                     Full name\n");
		for (my $i = 0; $i < @{$repairList}; $i++) {
			next if ($repairList->[$i] eq "");
			my $shortName = itemNameSimple($repairList->[$i]{nameID});
			$msg .= sprintf("%4d %-30s %s\n", $i, $shortName, $repairList->[$i]->{name});
		}
		$msg .= ('-'x80) . "\n";
		message $msg, "list";

	} elsif ($binID =~ /^\d+$/) {
		if ($repairList->[$binID]) {
			my $shortName = itemNameSimple($repairList->[$binID]{nameID});
			message TF("Attempting to repair item: %s (%d)\n", $shortName, $binID);
			$messageSender->sendRepairItem($repairList->[$binID]);
		} else {
			error TF("Item with index: %s does either not exist in the 'Repair List'.\n", $binID);
		}

	} elsif ($binID eq "cancel") {
		message T("Cancel repair item.\n");
		my %cancel = (
			index => 65535, # 0xFFFF
		);
		$messageSender->sendRepairItem(\%cancel);

	} else {
		error T("Syntax Error in function 'repair' (Repair player's items)\n" .
			"Usage: repair\n" .
			"       repair <item #>\n" .
			"       repair cancel\n");
	}
}

sub cmdReputation {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
	} else {
		my $msg = center(" ". T("Reputation Status") ." ", 80, '-') ."\n";
		$msg .= swrite(
			"@<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<< @<<<<<<<<<",
			[T("Type"), T("Name"), T("Lvl"), T("Points")]
		);
		foreach my $reputation (@reputation_list) {
			$msg .= swrite(
				"@<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<< @<<<<<<<<<",
				[$reputation->{type}, $reputation_list_name[$reputation->{type} - 1], int($reputation->{points}/1000), $reputation->{points}%1000]
			);
		}
		$msg .= center("", 80, '-') ."\n";
		message $msg;
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
		ai_useTeleport(2);
	}
}

sub cmdSell {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my @args = parseArgs($_[1]);

	if ($args[0] eq "" && $ai_v{'npc_talk'}{'talk'} eq 'buy_or_sell') {
		$messageSender->sendNPCBuySellList($talk{ID}, 1);

	} elsif ($args[0] eq "list") {
		if (@sellList == 0) {
			message T("Your sell list is empty.\n"), "info";
		} else {
			my $msg = center(T(" Sell List "), 41, '-') ."\n".
				T("#   Item                           Amount\n");
			foreach my $item (@sellList) {
				$msg .= sprintf("%-3d %-30s %d\n", $item->{binID}, $item->{name}, $item->{amount});
			}
			$msg .= ('-'x41) . "\n";
			message $msg, "list";
		}

	} elsif ($args[0] eq "done") {
		completeNpcSell(\@sellList);
	} elsif ($args[0] eq "cancel") {
		@sellList = ();
		completeNpcSell(\@sellList);
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

				if (defined(findIndex(\@sellList, "binID", $item->{binID}))) {
					error TF("%s (%s) is already in the sell list.\n", $item->nameString, $item->{binID});
					next;
				}
				next if ($item->{equipped});

				$obj{name} = $item->nameString();
				$obj{ID} = $item->{ID};
				$obj{binID} = $item->{binID};
				if (!$args[1] || $args[1] > $item->{amount}) {
					$obj{amount} = $item->{amount};
				} else {
					$obj{amount} = $args[1];
				}
				push @sellList, \%obj;
				message TF("Added to sell list: %s (%s) x %s\n", $obj{name}, $obj{binID}, $obj{amount}), "info";
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
	my $msg = center(" $shop{title} ", 90, '-') ."\n".
		T("#  Name                                       Type                     Price Amount   Sold\n");
	my $priceAfterSale=0;
	my $i = 1;
	for my $item (@articles) {
		next unless $item;
		$msg .= swrite(
		   "@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<< @>>>>>>>>>>>>z @<<<<< @>>>>>",
			[$i++, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{price}), $item->{quantity}, formatNumber($item->{sold})]);
		$priceAfterSale += ($item->{quantity} * $item->{price});
	}
	$msg .= "\n" .
		TF("You have earned: %sz.\n" .
		"Current zeny:    %sz.\n" .
		"Maximum earned:  %sz.\n" .
		"Maximum zeny:    %sz.\n",
		formatNumber($shopEarned), formatNumber($char->{zeny}),
		formatNumber($priceAfterSale), formatNumber($priceAfterSale + $char->{zeny})) .
		('-'x90) . "\n";
	message $msg, "list";
}

sub cmdBuyShopInfoSelf {
	if (!@selfBuyerItemList) {
		error T("You do not have a buying shop open.\n");
		return;
	}
	# FIXME: Read the packet the server sends us to determine
	# the shop title instead of using $shop{title}.
	my $msg = center(" Buyer Shop ", 83, '-') ."\n".
		T("#  Name                                       Type                     Price Amount\n");
	my $index = 0;
	for my $item (@selfBuyerItemList) {
		next unless $item;
		$msg .= swrite(
			"@< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<< @>>>>>>>>>>>>z @<<<<<",
			[$index, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{price}), $item->{amount}]);
	}
	$msg .= ('-'x83) . "\n";
	message $msg, "list";
}

sub cmdSit {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	if ($char->{skills}{NV_BASIC}{lv} < 3 && $char->{skills}{SU_BASIC_SKILL}{lv} < 1) {
		error T("Basic Skill level 3 or New Basic Skill (Doram) is required in order to sit or stand.")."\n";
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
	for my $slave (@$slavesList) {
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
	my $msg = center(T(" Area Effects List "), 66, '-') ."\n".
			T("  # Type                 Source                   X   Y  Range lvl\n");
	for my $ID (@spellsID) {
		my $spell = $spells{$ID};
		next unless $spell;
		$msg .=  sprintf("%3d %-20s %-20s   %3d %3d    %3d  %2d\n",
				$spell->{binID}, getSpellName($spell->{type}), main::getActorName($spell->{sourceID}), $spell->{pos}{x}, $spell->{pos}{y}, $spell->{range}, $spell->{lvl});
	}
	$msg .= ('-'x66) . "\n";
	message $msg, "list";
}

sub cmdStarplace {
	my (undef, $args) = @_;
	my ($type) = parseArgs( $args );

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my $flag;
	if ($type eq "sun") {
		$flag = 0;
	} elsif ($type eq "moon") {
		$flag = 1;
	} elsif ($type eq "star") {
		$flag = 2;
	} else {
		error T("Syntax Error in function 'starplace' (starplace agree)\n" .
			"Usage: starplace [<sun | moon | star>]\n");
		return;
	}

	$messageSender->sendFeelSaveOk($flag);
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
	cmdStats("st", "add ".$_[1]);
}

sub cmdStats {
	if (!$char) {
		error T("Character stats information not yet available.\n");
		return;
	}

	my ($subcmd, $arg) = parseArgs($_[1], 2);

	if ($subcmd eq "add") {
		if (!$net || $net->getState() != Network::IN_GAME) {
			error TF("You must be logged in the game to use this command 'st add'\n");
			return;
		}

		if ($arg ne "str" && $arg ne "agi" && $arg ne "vit" && $arg ne "int" && $arg ne "dex" && $arg ne "luk") {
			error T("Syntax Error in function 'st add' (Add Status Point)\n" .
				"Usage: st add <str | agi | vit | int | dex | luk>\n");

		} elsif ($char->{$arg} >= 99 && !$config{statsAdd_over_99}) {
			error T("Error in function 'st add' (Add Status Point)\n" .
				"You cannot add more stat points than 99\n");

		} elsif ($char->{"points_$arg"} > $char->{'points_free'}) {
			error TF("Error in function 'st add' (Add Status Point)\n" .
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
	} else {
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
			$haircolors{$char->hairColor()} . " (" . $char->hairColor() . ")"]);
			if (exists $char->{need_pow}) {
				$msg .= center("", 44, '-') ."\n";
				$msg .= center(" ". T("Trait Stats") ." ", 44, '-') ."\n".
				swrite(TF(
				"Pow: \@<<<   #\@<< P.Atk:    \@<<<   Res:    \@<<<\n" .
				"Sta: \@<<<   #\@<< S.Matk:   \@<<<   Mres:   \@<<<\n" .
				"Wis: \@<<<   #\@<< H.Plus:   \@<<<\n" .
				"Spl: \@<<<   #\@<< C.Rate:   \@<<<\n" .
				"Con: \@<<<   #\@<< T.Status Points:          \@<<<\n" .
				"Crt: \@<<<   #\@<<" ),
				[$char->{'pow'} ? $char->{'pow'} : 0, $char->{'need_pow'}, $char->{'patk'}, $char->{'res'},
				$char->{'sta'} ? $char->{'sta'} : 0, $char->{'need_sta'}, $char->{'smatk'}, $char->{'mres'},
				$char->{'wis'} ? $char->{'wis'} : 0, $char->{'need_wis'}, $char->{'hplus'},
				$char->{'spl'} ? $char->{'spl'} : 0, $char->{'need_spl'}, $char->{'crate'},
				$char->{'con'} ? $char->{'con'} : 0, $char->{'need_con'}, $char->{'traitpoint'},
				$char->{'crt'} ? $char->{'crt'} : 0, $char->{'need_crt'}]);
			}

		$msg .= T("You are sitting.\n") if $char->{sitting};
		$msg .= ('-'x44) . "\n";
		message $msg, "info";
	}
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
	if ($char->storage->wasOpenedThisSession()) {
		my (undef, $args) = @_;

		my ($switch, $items) = split(' ', $args, 2);
		if (!$switch || $switch eq 'eq' || $switch eq 'u' || $switch eq 'nu') {
			cmdStorage_list($switch);
		} elsif ($switch eq 'log') {
			cmdStorage_log();
		} elsif ($switch eq 'desc') {
			cmdStorage_desc($items);
		} elsif (($switch =~ /^(add|addfromcart|get|gettocart)$/ && ($items || $args =~ /$switch 0/)) || $switch eq 'close') {
			if ($char->storage->isReady()) {
				my ( $name, $amount );
				if ( $items =~ /^[^"'].* .+$/ ) {
					# Backwards compatibility: "storage add Empty Bottle 1" still works.
					( $name, $amount ) = $items =~ /^(.*?)(?: (\d+))?$/;
				} else {
					( $name, $amount ) = parseArgs( $items );
				}
				if ($switch eq 'add') {
					cmdStorage_add($name, $amount);
				} elsif ($switch eq 'addfromcart') {
					cmdStorage_addfromcart($name, $amount);
				} elsif ($switch eq 'get') {
					cmdStorage_get($name, $amount);
				} elsif ($switch eq 'gettocart') {
					cmdStorage_gettocart($name, $amount);
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
	my ($name, $amount) = @_;

	my @items = $char->inventory->getMultiple( $name );
	if ( !@items ) {
		error TF( "Inventory item '%s' does not exist.\n", $name );
		return;
	}

	transferItems( \@items, $amount, 'inventory' => 'storage' );
}

sub cmdStorage_addfromcart {
	my ($name, $amount) = @_;

	if (!$char->cart->isReady) {
		error T("Error in function 'storage_gettocart' (Cart Management)\nYou do not have a cart.\n");
		return;
	}

	my @items = $char->cart->getMultiple( $name );
	if ( !@items ) {
		error TF( "Cart item '%s' does not exist.\n", $name );
		return;
	}

	transferItems( \@items, $amount, 'cart' => 'storage' );
}

sub cmdStorage_get {
	my ($name, $amount) = @_;

	my @items = $char->storage->getMultiple( $name );
	if ( !@items ) {
		error TF( "Storage item '%s' does not exist.\n", $name );
		return;
	}

	transferItems( \@items, $amount, 'storage' => 'inventory' );
}

sub cmdStorage_gettocart {
	my ($name, $amount) = @_;

	if ( !$char->cart->isReady ) {
		error T( "Error in function 'storage_gettocart' (Cart Management)\nYou do not have a cart.\n" );
		return;
	}

	my @items = $char->storage->getMultiple( $name );
	if ( !@items ) {
		error TF( "Storage item '%s' does not exist.\n", $name );
		return;
	}

	transferItems( \@items, $amount, 'storage' => 'cart' );
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
		printItemDesc($item);
	}
}

sub cmdStore {
	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+ (\d+)/;

	if ($arg1 eq "" && $ai_v{'npc_talk'}{'talk'} ne 'buy_or_sell') {
		my $msg = center(TF(" Store List (%s) ", $storeList->{npcName}), 68, '-') ."\n".
			  T("#  Name                    Type                       Price   Amount\n");
		foreach my $item (@$storeList) {
			$msg .= swrite(
				"@< @<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<<  @>>>>>>>>>z   @<<<<<",
				[$item->{binID}, $item->{name}, $itemTypes_lut{$item->{type}}, formatNumber($item->{price}), $item->{amount}]);
		}
		$msg .= "Store list is empty.\n" if !$storeList->size;
		$msg .= ('-'x68) . "\n";
		message $msg, "list";

	} elsif ($arg1 eq "" && $ai_v{'npc_talk'}{'talk'} eq 'buy_or_sell'
	 && ($net && $net->getState() == Network::IN_GAME)) {
		$messageSender->sendNPCBuySellList($talk{'ID'}, 0);

	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/ && !$storeList->get($arg2)) {
		error TF("Error in function 'store desc' (Store Item Description)\n" .
			"Store item %s does not exist\n", $arg2);
	} elsif ($arg1 eq "desc" && $arg2 =~ /\d+/) {
		printItemDesc($storeList->get($arg2));

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

sub cmdSwitchEquips {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	$messageSender->sendEquipSwitchRun();
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

	if ($args =~ /^resp$/) {
		if (!$talk{'responses'}) {
			error T("Error in function 'talk resp' (Respond to NPC)\n" .
				"No NPC response list available.\n");
			return;

		} else {
			my $msg = center(T(" Responses (").getNPCName($talk{ID}).") ", 40, '-') ."\n" .
				TF("#  Response\n");
			for (my $i = 0; $i < @{$talk{'responses'}}; $i++) {
				$msg .= swrite(
				"@< @*",
				[$i, $talk{responses}[$i]]);
			}
			$msg .= ('-'x40) . "\n";
			message $msg, "list";
			return;
		}
	}

	my @steps = split(/\s*,\s*/, $args);

	if (!@steps) {
		error T("Syntax Error in function 'talk' (Talk to NPC)\n" .
			"Usage: talk <NPC # | \"NPC name\" | cont | resp | num | text > [<response #>|<number #>]\n");
		return;
	}

	my $steps_string = "";
	my $nameID;
	foreach my $index (0..$#steps) {
		my $step = $steps[$index];
		my $type;
		my $arg;
		if ($step =~ /^(cont|text|num|resp|\d+|"[^"]+")\s+(\S.*)$/) {
			$type = $1;
			$arg = $2;
		} else {
			$type = $step;
		}

		my $current_step;

		if ($type =~ /^\d+|"([^"]+)"$/) {
			$type = $1 if $1;
			if (AI::is("NPC")) {
				error "Error in function 'talk' (Talk to NPC)\n" .
					"You are already talking with an npc\n";
				return;

			} elsif ($index != 0) {
				error "Error in function 'talk' (Talk to NPC)\n" .
					"You cannot start a conversation during one\n";
				return;

			} else {
				my $npc = $npcsList->get($type);
				if ($npc) {
					$nameID = $npc->{nameID};
				} else {
					error "Error in function 'talk' (Talk to NPC)\n" .
						"Given npc not found\n";
					return;
				}
			}

		} elsif (!AI::is("NPC") && !defined $nameID) {
			error "Error in function 'talk' (Talk to NPC)\n" .
				"You are not talkning to an npc\n";
			return;

		} elsif ($type eq "resp") {
			if ($arg =~ /^(\/(.*?)\/(\w?))$/) {
				$current_step = 'r~'.$1;

			} elsif ($arg =~ /^\d+$/) {
				$current_step = 'r'.$arg;

			} elsif (!$arg) {
				error T("Error in function 'talk resp' (Respond to NPC)\n" .
					"You must specify a response.\n");
				return;

			} else {
				error T("Error in function 'talk resp' (Respond to NPC)\n" .
					"Wrong talk resp sintax.\n");
				return;
			}

		} elsif ($type eq "num") {
			if ($arg eq "") {
				error T("Error in function 'talk num' (Respond to NPC)\n" .
					"You must specify a number.\n");
				return;

			} elsif ($arg !~ /^-?\d+$/) {
				error TF("Error in function 'talk num' (Respond to NPC)\n" .
					"%s is not a valid number.\n", $arg);
				return;

			} elsif ($arg =~ /^-?\d+$/) {
				$current_step = 'd'.$arg;
			}

		} elsif ($type eq "text") {
			if ($args eq "") {
				error T("Error in function 'talk text' (Respond to NPC)\n" .
					"You must specify a string.\n");
				return;

			} else {
				$current_step = 't='.$arg;
			}

		} elsif ($type eq "cont") {
			$current_step = 'c';

		} elsif ($type eq "no") {
			$current_step = 'n';
		}

		if (defined $current_step) {
			$steps_string .= $current_step;

		} elsif (!(defined $nameID && $index == 0)) {
			error T("Syntax Error in function 'talk' (Talk to NPC)\n" .
				"Usage: talk <NPC # | \"NPC name\" | cont | resp | num | text > [<response #>|<number #>]\n");
			return;
		}

		last if ($index == $#steps);

	} continue {
		$steps_string .= " " unless (defined $nameID && $index == 0);
	}
	if (defined $nameID) {
		AI::clear("route");
		AI::queue("NPC", new Task::TalkNPC(type => 'talk', nameID => $nameID, sequence => $steps_string));
	} else {
		my $task = $char->args;
		$task->addSteps($steps_string);
	}
}

sub cmdTalkNPC {
	my (undef, $args) = @_;

	my ($x, $y, $sequence) = $args =~ /^(\d+) (\d+)(?: (.+))?$/;
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
		for (@$playersList, @$slavesList) {
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
	ai_useTeleport($arg1);
}

sub cmdTestShop {
	my @items = main::makeShop();
	return unless @items;
	my @shopnames = split(/;;/, $shop{title_line});
	$shop{title} = $shopnames[int rand($#shopnames + 1)];
	$shop{title} = ($config{shopTitleOversize}) ? $shop{title} : substr($shop{title},0,36);

	my $msg = center(" $shop{title} ", 69, '-') ."\n".
			T("Name                                                    Price  Amount\n");
	for my $item (@items) {
		$msg .= swrite("@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>>>>>z  @<<<<<",
			[$item->{name}, formatNumber($item->{price}), $item->{amount}]);
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
			$item->{name}, $item->{binID});
		return;
	}
	if ($slot) {
		$item->unequipFromSlot($slot);
	} else {
		$item->unequip();
	}
}

sub cmdUnequipSwitch {

	# unequip an item
	my (undef, $args) = @_;
	my ($arg1,$arg2) = $args =~ /^(\S+)\s*(.*)/;
	my $slot;
	my $item;

	if ($arg1 eq "") {
		cmdEquipsw_list();
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
			$item->{name}, $item->{binID});
		return;
	}

	$item->unequip_switch();
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
	my $isStartUseSkill = 0;

	if ($cmd eq 'sl') {
		my ($x, $y);

		if (scalar @args < 3) {
			$x = $char->position->{x};
			$y = $char->position->{y};
			$level = $args[1];
		} else {
			$x = $args[1];
			$y = $args[2];
			$level = $args[3];
		}

		if (@args < 1 || @args > 4) {
			error T("Syntax error in function 'sl' (Use Skill on Location)\n" .
				"Usage: sl <skill #> [<x> <y>] [level]\n");
			return;
		} elsif ($x !~ /^\d+$/ || $y !~ /^\d+/) {
			error T("Error in function 'sl' (Use Skill on Location)\n" .
				"Invalid coordinates given.\n");
			return;
		} else {
			$target = { x => $x, y => $y };
		}
		# This was the code for choosing a random location when x and y are not given:
		# my $pos = calcPosition($char);
		# my @positions = calcRectArea($pos->{x}, $pos->{y}, int(rand 2) + 2, $field);
		# $pos = $positions[rand(@positions)];
		# ($x, $y) = ($pos->{x}, $pos->{y});

	} elsif ($cmd eq 'ss') {
		if (defined $args[0] && $args[0] eq 'start') {
			if (@args < 2 || @args > 3) {
				error T("Syntax error in function 'ss start' (Start Use Skill on Self)\n" .
				"Usage: ss start <skill #> [level]\n");
				return;
			}
			$isStartUseSkill = 1;
			$target = $char;
			$level = $args[2];
		} elsif (defined $args[0] && $args[0] eq 'stop') {
			if (!$char->{last_skill_used_is_continuous}) {
				error T("Skill Stop failed (continuous skills not detected)\n");
				return;
			}
			message T("Sending Skill Stop\n"), "skill";
			$messageSender->sendStopSkillUse($char->{last_continuous_skill_used});
			return;
		} elsif (@args < 1 || @args > 2) {
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

	my $skill_arg = $isStartUseSkill ? $args[1] : $args[0];
	$skill = new Skill(auto => $skill_arg, level => $level);

	if ($char->{skills}{$skill->getHandle()}{lv} == 0) {
		error TF("Skill '%s' cannot be used because you have no such skill.\n", $skill->getName());
		return;
	} elsif ($char->{skills}{$skill->getHandle()}{lv} < $level) {
		error TF("You are trying to use the skill '%s' level %d, but only level %d is available to you.\n", $skill->getName(), $level, $char->{skills}{$skill->getHandle()}{lv});
		return;
	}

	require Task::UseSkill;
	my $skillTask = new Task::UseSkill(
		actor => $skill->getOwner,
		target => $target,
		actorList => $actorList,
		skill => $skill,
		isStartUseSkill => $isStartUseSkill,
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

	if ($args eq "end") {
		$venderItemList->clear;
		undef $venderID;
		undef $venderCID;
		return;
	}

	my ($arg1) = $args =~ /^(\d+)/;
	my ($arg2) = $args =~ /^\d+ (\d+)/;
	my ($arg3) = $args =~ /^\d+ \d+ (\d+)/;
	if ($arg1 eq "") {
		error T("Syntax error in function 'vender' (Vender Shop)\n" .
			"Usage: vender <vender # | end> [<vender_item #> <amount>]\n");
	} elsif ($venderListsID[$arg1] eq "") {
		error TF("Error in function 'vender' (Vender Shop)\n" .
			"Vender %d does not exist.\n", $arg1);
	} elsif ($arg2 eq "") {
		$messageSender->sendEnteringVender($venderListsID[$arg1]);
	} elsif ($venderListsID[$arg1] ne $venderID) {
		error T("Error in function 'vender' (Vender Shop)\n" .
			"Vender ID is wrong.\n");
	} elsif (!$venderItemList->get( $arg2 )) {
		error TF("Error in function 'vender' (Vender Shop)\n" .
			"Item %d does not exist.\n", $arg2);
	} else {
		$arg3 = 1 if $arg3 <= 0;
		my $item = $venderItemList->get( $arg2 );
		$messageSender->sendBuyBulkVender( $venderID, [ { itemIndex => $item->{ID}, amount => $arg3 } ], $venderCID );
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
		undef $buyerPriceLimit;
		undef $buyerID;
		undef $buyingStoreID;
		$buyerItemList->clear;

	} elsif ($buyerListsID[$arg1] eq "") {
		error TF("Error in function 'buyer' (Buyer Shop)\n" .
			"buyer %s does not exist.\n", $arg1);

	} elsif ($arg2 eq "") {
		undef $buyerPriceLimit;
		undef $buyerID;
		undef $buyingStoreID;
		$buyerItemList->clear;
		$messageSender->sendEnteringBuyer($buyerListsID[$arg1]);

	} elsif (!$buyerItemList->get( $arg2 )) {
		error TF("Error in function 'buyer' (Buyer Shop)\n" .
			"item %s does not exist.\n", $arg2);

	} elsif ($buyerListsID[$arg1] ne $buyerID) {
		error T("Error in function 'buyer' (Buyer Shop)\n" .
			"Buyer ID is wrong.\n");

	} else {
		if ($arg3 <= 0) {
			$arg3 = 1;
		}

		my $l_item = $buyerItemList->get( $arg2 );

		if (!defined $l_item) {
			error T("Error in function 'buyer', shop item not defined.\n");
			return;
		}

		my $c_item = $char->inventory->getByNameID($l_item->{nameID});

		if (!defined $c_item) {
			error T("Error in function 'buyer', char item not defined.\n");
			return;
		}

		my $amount = $arg3;
		my $total_zeny = $amount * $l_item->{price};

		if ($total_zeny > $buyerPriceLimit) {
			error T("Error in function 'buyer', trying to sell aboce max price limit.\n");
			return;
		}

		$messageSender->sendBuyBulkBuyer($buyerID, [{ID => $c_item->{ID}, itemID => $c_item->{nameID}, amount => $amount}], $buyingStoreID);
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

	my (undef, $args_string) = @_;
	my @args = parseArgs($args_string, 3);

	if ($args[0] eq 'open') {
		if (defined $mailList) {
			error T("Your Mailbox is already opened.\n");
		} else {
			message T("Sending request to open Mailbox.\n");
			$messageSender->sendMailboxOpen();
		}

	} elsif ($args[0] eq 'refresh') {
		$messageSender->sendMailboxOpen();

	} elsif ($args[0] eq 'read') {
		unless ($args[1] =~ /^\d+$/) {
			error T("Syntax Error in function 'mail read' (Mailbox)\n" .
				"Usage: mail read <mail #>\n");
		} elsif (!defined $mailList) {
			warning T("Your Mailbox is not open. Use the command 'mail open'.\n");
		} elsif (!$mailList->[$args[1]]) {
				warning TF("No mail found with index: %s\n", $args[1]);
		} elsif ($mailList->[$args[1]]->{mailID}) {
			$messageSender->sendMailRead($mailList->[$args[1]]->{mailID});
		}

	} elsif ($args[0] eq 'get') {
		unless ($args[1] =~ /^\d+$/) {
			error T("Syntax Error in function 'mail get' (Mailbox)\n" .
				"Usage: mail get <mail #>\n");
		} elsif (!defined $mailList) {
			warning T("Your Mailbox is not open. Use the command 'mail open'.\n");
		} elsif (!$mailList->[$args[1]]) {
				warning TF("No mail found with index: %s\n", $args[1]);
		} elsif ($mailList->[$args[1]]->{mailID}) {
			$messageSender->sendMailGetAttach($mailList->[$args[1]]->{mailID});
		}

	} elsif ($args[0] eq 'setzeny') {
		if ($args[1] =~ /^\d+$/) {
			$messageSender->sendMailSetAttach($args[1], undef);
		} elsif ($args[1] eq 'none') {
			$messageSender->sendMailOperateWindow(2);
		} else {
			error T("Syntax Error in function 'mail setzeny' (Mailbox)\n" .
				"Usage: mail setzeny <amount|none>\n");
		}

	} elsif ($args[0] eq 'add') {
		unless (defined $args[1]) {
			error T("Syntax Error in function 'mail add' (Mailbox)\n" .
				"Usage: mail add <item #> <amount>\n");
		} elsif ($args[1] eq 'none') {
			$messageSender->sendMailOperateWindow(1);
		} else {
			my $item = Actor::Item::get($args[1]);
			if ($item) {
				my $amount = $args[2] ? $args[2] : $item->{amount};
				warning TF("Attention: Inventory Item '%s' is equipped.\n", $item->{name}) if ($item->{equipped});
				$messageSender->sendMailSetAttach($amount, $item->{ID});
			} else {
				warning TF("Inventory Item '%s' does not exist.\n", $args[2]);
			}
		}

	} elsif ($args[0] eq 'send') {
		unless ($args[1] && $args[2]) {
			error T("Syntax Error in function 'mail send' (Mailbox)\n" .
				"Usage: mail send <receiver> <title> <body>\n");
		} else {
			$messageSender->sendMailSend($args[1], $args[2], $args[3]);
		}

	# mail delete (can't delete mail without removing attachment/zeny first)
	} elsif ($args[0] eq 'delete') {
		unless ($args[1] =~ /^\d+$/) {
			error T("Syntax Error in function 'mail delete' (Mailbox)\n" .
				"Usage: mail delete <mail #>\n");
		} elsif (!$mailList->[$args[1]]) {
			if (@{$mailList}) {
				warning TF("No mail found with index: %d. (might need to re-open mailbox)\n", $args[1]);
			} else {
				warning T("Mailbox has not been opened or is empty.\n");
			}
		} else {
			$messageSender->sendMailDelete($mailList->[$args[1]]->{mailID});
			delete $mailList->[$args[1]];
		}

	# mail window (almost useless?)
	} elsif ($args[0] eq 'write') {
		$messageSender->sendMailOperateWindow(0);

	# mail return
	} elsif ($args[0] eq 'return') {
		unless ($args[1] =~ /^\d+$/) {
			error T("Syntax Error in function 'mail retutn' (Mailbox)\n" .
				"Usage: mail return <mail #>\n");
		} elsif (!$mailList->[$args[1]]) {
			if (@{$mailList}) {
				warning TF("No mail found with index: %s. (might need to re-open mailbox)\n", $args[1]);
			} else {
				warning T("Mailbox has not been opened or is empty.\n");
			}
		} else {
			$messageSender->sendMailReturn($mailList->[$args[1]]->{mailID}, $mailList->[$args[1]]->{sender});
		}

	} elsif ($args[0] eq 'list') {
		if (!defined $mailList) {
			error T("Your Mailbox is is closed.\n");
		} elsif (!$mailList) {
			message T("Your Mailbox is empty.\n");
		} else {
			my $msg = center(" " . T("Inbox") . " ", 86, '-') . "\n";
			# truncating the title from 39 to 34, the user will be able to read the full title when reading the mail
			# truncating the date with precision of minutes and leave year out
			$msg .= swrite(sprintf("\@> \@ \@%s \@%s \@%s", ('<'x34), ('<'x24), ('<'x19)),
					["#", T("R"), T("Title"), T("Sender"), T("Date")]);
			$msg .= sprintf("%s\n", ('-'x86));
			my $index = 0;
			foreach my $mail (@{$mailList}) {
				if ($mail) {
					$msg .= swrite(sprintf("\@> \@ \@%s \@%s \@%s", ('<'x34), ('<'x24), ('<'x19)),
						[$index, $mail->{read}, $mail->{title}, $mail->{sender}, getFormattedDate(int($mail->{timestamp}))]);
				} else {
					$msg .= swrite(sprintf("\@> \@%s", ('<'x83)), [$index, T("the mail was deleted")]);
				}
				$index++;
			}

			$msg .= sprintf("%s\n", ('-'x86));
			message $msg, "list";
		}

	} else {
		error T("Syntax Error in function 'mail' (Mailbox)\n" .
			"Usage: help mail\n");
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
			my $serverIndex = $item->{ID};
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
			$msg .= swrite(sprintf("\@%s \@%s \@%s \@%s \@%s", ('>'x2), ('<'x5), ('<'x30), ('<'x10), ('<'x24)),
				[$k, $questID, $quests_lut{$questID} ? $quests_lut{$questID}{title} : '', $quest->{active} ? T("active") : T("inactive"), $quest->{time_expire} ? scalar localtime $quest->{time_expire} : '']);
			foreach my $mobID (keys %{$quest->{missions}}) {
				my $mission = $quest->{missions}->{$mobID};
				$msg .= swrite(sprintf("\@%s \@%s \@%s", ('>'x2), ('<'x30), ('<'x30)),
					[" -", $mission->{mob_name}, sprintf(defined $mission->{mob_goal} ? '%d/%d' : '%d', @{$mission}{qw(mob_count mob_goal)})]);
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
		$messageSender->sendMiscConfigSet(0, $args[1] eq 'on');
	} else {
		message T("Usage: showeq [p <index|name|partialname>] | [me <on|off>]\n"), "info";
	}
}

# Answer to mixing item selection dialog (CZ_REQ_MAKINGITEM).
# 025b <mk type>.W <name id>.W
# mk type:
#     1 = cooking
#     2 = arrow
#     3 = elemental
#     4 = GN_MIX_COOKING
#     5 = GN_MAKEBOMB
#     6 = GN_S_PHARMACY
sub cmdCooking {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $arg) = @_;
	if ($arg =~ /^\d+/ && defined $cookingList->[$arg]) { # viewID/nameID can be 0
		my $type = 1;
		if(defined $currentCookingType && $currentCookingType > 0) {
			$type = $currentCookingType;
		}
		$messageSender->sendCooking($type, $cookingList->[$arg]); # type 1 is for cooking
	} elsif (!$arg) {
		message TF("Syntax error in function 'cook' (Cook food)\n" .
					"Usage: cook [<list index>]\n");
	} else {
		message TF("Item with 'Cooking List' index: %s not found.\n", $arg), "info";
	}
}

sub cmdWeaponRefine {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args) = @_;

	if ($args =~ /^\d+/ && defined $refineList->[$args]) {
		$messageSender->sendWeaponRefine($refineList->[$args]);
	} elsif($args =~ /^\d+/) {
		message TF("Item with 'refine' index: %s not found.\n", $args), "info";
	} else {
		error T("Error in function 'refine'\n".
			"Usage: refine <index number>\n");
	}
}

sub cmdAnswerCaptcha {
	if ($net->getState() == Network::IN_GAME()) {
		$messageSender->sendMacroDetectorAnswer($_[1]);
	} else {
		$messageSender->sendCaptchaAnswer($_[1]);
	}
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

	for my $item (@{$char->storage}) {
		if ($item->usable) {
			push @useable, $item->{binID};
		} elsif ($item->equippable) {
			my %eqp;
			$eqp{index} = $item->{ID};
			$eqp{binID} = $item->{binID};
			$eqp{name} = $item->{name};
			$eqp{amount} = $item->{amount};
			$eqp{identified} = " -- " . T("Not Identified") if !$item->{identified};
			$eqp{type} = $itemTypes_lut{$item->{type}};
			push @equipment, \%eqp;
		} else {
			push @non_useable, $item->{binID};
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

sub cmdAchieve {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $args_string) = @_;
	my @args = parseArgs($args_string, 3);
	if ($args[0] eq 'list') {
		if (!$achievementList) {
			error T("'Achievement List' is empty.\n");
			return;
		}

		my $msg = center(" " . T("Achievement List") . " ", 79, '-') . "\n";
		my $index = 0;
		foreach my $achievementID (keys %{$achievementList}) {
			my $achieve = $achievementList->{$achievementID};
			$msg .= swrite(sprintf("\@%s \@%s \@%s \@%s \@%s", ('>'x2), ('<'x7), ('<'x15), ('<'x15), ('<'x32)), [$index, $achievementID, $achieve->{completed} ? T("complete") : T("incomplete"), $achieve->{reward}  ? T("rewarded") : T("not rewarded"), $achievements{$achievementID}->{title}]);
			$index++;
		}
		$msg .= sprintf("%s\n", ('-'x79));
		message $msg, "list";

	} elsif ($args[0] eq 'reward') {
		if ($args[1] !~ /^\d+$/) {
			error T("Syntax Error in function 'achieve reward' (Receiving an award)\n" .
				"Usage: achieve reward <achievementID>\n");

		} elsif (!exists $achievementList->{$args[1]}) {
			error TF("You don't have the achievement %s.\n", $args[1]);

		} elsif ($achievementList->{$args[1]}{completed} != 1) {
			error TF("You haven't completed the achievement %s.\n", $args[1]);

		} elsif ($achievementList->{$args[1]}{reward} == 1) {
			error TF("You have already claimed the achievement %s reward.\n", $args[1]);

		} else {
			message TF("Sending request for reward of achievement %s.\n", $args[1]);
			$messageSender->sendAchievementGetReward($args[1]);
		}

	} elsif ($args[0] eq 'info' && $args[1] =~ /^\d+$/) {
		if(defined($achievements{$args[1]})) {
			# status
			my $msg;
			$msg .= center(" " . T("Achievement Info") . " ", 79, '-') . "\n";
			$msg .= TF("ID: %s - Title: %s\n", $achievements{$args[1]}->{ID}, $achievements{$args[1]}->{title});
			$msg .= TF("Group: %s\n", ($achievements{$args[1]}->{group}) ? $achievements{$args[1]}->{group} : T("N/A"));
			$msg .= TF("Summary: %s\n", ($achievements{$args[1]}->{summary}) ? $achievements{$args[1]}->{summary} : T("N/A"));
			$msg .= TF("Details: %s\n", ($achievements{$args[1]}->{details}) ? $achievements{$args[1]}->{details} : T("N/A"));
			$msg .= T("Rewards:\n");
			$msg .= TF("  Item: %s\n", ($achievements{$args[1]}->{rewards}->{item}) ? itemNameSimple($achievements{$args[1]}->{rewards}->{item}) : T("N/A"));
			$msg .= TF("  Buff: %s\n", ($achievements{$args[1]}->{rewards}->{buff}) ? $statusName{$statusHandle{$achievements{$args[1]}->{rewards}->{buff}}} : T("N/A"));
			$msg .= TF("  Title: %s\n", ($achievements{$args[1]}->{rewards}->{title}) ? $title_lut{$achievements{$args[1]}->{rewards}->{title}} : T("N/A"));
			$msg .= T("Status: ");
			if ( defined ( $achievementList->{$args[1]} ) ) {
				my $achieve = $achievementList->{$args[1]};
				$msg .= TF("%s %s\n", $achieve->{completed} ? T("complete") : T("incomplete"), $achieve->{reward}  ? T("rewarded") : T("not rewarded"));
			} else {
				$msg .= T("N/A\n");
			}
			$msg .= center("", 79, '-') . "\n";
			message $msg;
		} else {
			warning T("The achievement was not found. Update the 'achievement_list.txt' file\n");
		}
	} else {
		error T("Syntax Error in function 'achieve'\n" .
				"see 'help achieve'\n");
	}
}

sub cmdRodex {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my (undef, $args) = @_;
	my ($arg1) = $args =~ /^(\w+)/;
	my ($arg2) = $args =~ /^\w+\s+(\S.*)/;

	if ($arg1 eq 'open') {
		if (defined $rodexList) {
			error T("Your rodex mail box is already opened.\n");
			return;
		}
		my $type = 0;
		if($arg2 && $arg2=~/\d+/) {
			$type = $arg2;
			if($arg2 == 1) {
				message T("Sending request to open rodex account mailbox.\n");
			} elsif($arg2 == 2) {
				message T("Sending request to open rodex returned mailbox.\n");
			} else {
				message T("Sending request to open rodex normal mailbox.\n");
				$type = 0;
			}
		} else {
			message T("Sending request to open rodex normal mailbox.\n");
		}
		$rodexCurrentType = $type;
		$messageSender->rodex_open_mailbox($type,0,0);

	} elsif ($arg1 eq 'close') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;
		} elsif (defined $rodexWrite) {
			$messageSender->rodex_cancel_write_mail();#we must first close the letter if it is open
		}
		message T("Your rodex mail box has been closed.\n");
		$messageSender->rodex_close_mailbox();

	} elsif ($arg1 eq 'list') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!$rodexList) {
			message T("Your rodex mail box is empty.\n");
			return;
		}
		my $msg = center(" ". T("Rodex Mail List") ." ", 119, '-') . "\n" .
						T(" #  ID       From                    Att  New  Expire    Title\n");

		my @list;
		foreach my $mail_id (keys %{$rodexList->{mails}}) {
			my $mail = $rodexList->{mails}{$mail_id};
			$list[$mail->{page_index}] = swrite("@>  @<<<<<<< @<<<<<<<<<<<<<<<<<<<<<< @<<< @<<  @>>>>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [$mail->{page_index}, $mail->{mailID1}, $mail->{sender}, $mail->{attach} ? $mail->{attach} : "-", $mail->{isRead} ? T("No") : T("Yes"), $mail->{expireDay} ." ".T("Days"), $mail->{title}]);
		}
		foreach my $list (@list) {
			$msg .= $list;
		}
		$msg .= ('-'x119) . "\n";
		message $msg, "list";

	} elsif ($arg1 eq 'maillist') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;
		}

		my @pages;
		foreach my $mail_id (keys %{$rodexList->{mails}}) {
			my $mail = $rodexList->{mails}{$mail_id};

			my $index;
			if ($mail->{page} == 0) {
				$index = $mail->{page_index};
			} else {
				$index = (($mail->{page} * $rodexList->{mails_per_page}) + $mail->{page_index});
			}
			$pages[$mail->{page}][$mail->{page_index}] = swrite("@>  @<<<<<<< @<<<<<<<<<<<<<<<<<<<<<< @<<< @<<  @>>>>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [$index, $mail->{mailID1}, $mail->{sender}, $mail->{attach} ? $mail->{attach} : "-", $mail->{isRead} ? T("No") : T("Yes"), $mail->{expireDay} ." ".T("Days"), $mail->{title}]);

		}

		my $msg;
		foreach my $page_index (0..$#pages) {
			$msg .= center(" ". TF("Rodex Mail Page %d", $page_index) ." ", 119, '-') . "\n" .
							T(" #  ID       From                    Att  New  Expire    Title\n");

			foreach my $mail_msg (@{$pages[$page_index]}) {
				$msg .= $mail_msg;
			}
		}
		$msg .= ('-'x119) . "\n";
		message $msg, "list";

	} elsif ($arg1 eq 'refresh') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;
		}

		$messageSender->rodex_refresh_maillist($rodexCurrentType,0,0);

	} elsif ($arg1 eq 'read') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif ($arg2 eq "" || $arg2 !~ /^\d+$/) {
			error T("Syntax Error in function 'rodex read' (Read rodex mail)\n" .
				"Usage: rodex read <mail_# | mail_id>\n");
			return;

		} elsif ($arg2 =~/^\d{1,3}$/) {
			foreach my $mail_id (keys %{$rodexList->{mails}}) {
				my $page_index = $rodexList->{mails}{$mail_id}{page_index};
				if ($page_index == $arg2) {
					$arg2 = $mail_id;
					last;
				} else {
					next;
				}
			}
		}

		if (!exists $rodexList->{mails}{$arg2}) {
			error TF("The rodex mail of ID '%d' doesn't exist.\n", $arg2);
			return;
		}

		my $openType = $rodexList->{mails}{$arg2}{openType};
		$messageSender->rodex_read_mail($openType,$arg2,0);

	} elsif ($arg1 eq 'write') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (defined $rodexWrite) {
			error T("You are already writing a rodex mail.\n");
			return;

		} elsif ($arg2 eq "self") {
			debug "Send rodex mail to yourself\n";
			$arg2 = $char->{'name'};
		} else {
			message TF("Opening rodex mail write box. Recipient: %s\n", $arg2);
		}
		$messageSender->rodex_open_write_mail($arg2);

	} elsif ($arg1 eq 'cancel') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;
		}

		message T("Closing rodex mail write box.\n");
		$messageSender->rodex_cancel_write_mail();

	} elsif ($arg1 eq 'settarget') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif (exists $rodexWrite->{target}{name}) {
			error T("You have already set the mail target.\n");
			return;

		} elsif ($arg2 eq "") {
			error T("Syntax Error in function 'rodex settarget' (Set target of rodex mail)\n" .
				"Usage: rodex settarget <player_name|self>\n");
			return;
		} elsif ($arg2 eq "self") {
			debug "Send rodex mail to yourself\n";
			$arg2 = $char->{'name'};
		}

		message TF("Setting target of rodex mail to '%s'.\n", $arg2);
		$messageSender->rodex_checkname($arg2);

	} elsif ($arg1 eq 'itemslist') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		}

		my @useable;
		my @equipment;
		my @non_useable;
		my ($i, $display, $index);

		for my $item (@{$rodexWrite->{items}}) {
			if ($item->usable) {
				push @useable, $item->{binID};
			} elsif ($item->equippable) {
				my %eqp;
				$eqp{index} = $item->{ID};
				$eqp{binID} = $item->{binID};
				$eqp{name} = $item->{name};
				$eqp{amount} = $item->{amount};
				$eqp{identified} = " -- " . T("Not Identified") if !$item->{identified};
				$eqp{type} = $itemTypes_lut{$item->{type}};
				push @equipment, \%eqp;
			} else {
				push @non_useable, $item->{binID};
			}
		}

		my $msg = center( " " .T("Rodex mail item list") ." ", 50, '-') ."\n";

		$msg .= T("-- Usable --\n");
		for (my $i = 0; $i < @useable; $i++) {
			$index = $useable[$i];
			my $item = $rodexWrite->{items}->get($index);
			$display = $item->{name};
			$display .= " x $item->{amount}";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$index, $display]);
		}

		$msg .= T("\n-- Equipment --\n");
		foreach my $item (@equipment) {
			## altered to allow for Arrows/Ammo which will are stackable equip.
			$display = sprintf("%-3d  %s (%s)", $item->{binID}, $item->{name}, $item->{type});
			$display .= " x $item->{amount}" if $item->{amount} > 1;
			$display .= $item->{identified};
			$msg .= sprintf("%-57s\n", $display);
		}

		$msg .= T("\n-- Non-Usable --\n");
		for (my $i = 0; $i < @non_useable; $i++) {
			$index = $non_useable[$i];
			my $item = $rodexWrite->{items}->get($index);
			$display = $item->{name};
			$display .= " x $item->{amount}";
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
				[$index, $display]);
		}
		$msg .= sprintf("%s\n", ('-'x50));
		message $msg, "list";

	} elsif ($arg1 eq 'settitle') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif ($arg2 eq "") {
			error T("Syntax Error in function 'rodex settitle' (Set title of rodex mail)\n" .
				"Usage: rodex settitle <title>\n");
			return;
		} elsif (length($arg2) < 4) {
			error $msgTable[2597] ? $msgTable[2597] . "\n" : T("The title must be 4 to 24 characters long\n");
			return;
		}

		if (exists $rodexWrite->{title}) {
			message TF("Changed the rodex mail message title to '%s'.\n", $arg2);
		} else {
			message TF("Set the rodex mail message title to '%s'.\n", $arg2);
		}

		$rodexWrite->{title} = $arg2;

	} elsif ($arg1 eq 'setbody') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif ($arg2 eq "") {
			error T("Syntax Error in function 'rodex setbody' (Set body of rodex mail)\n" .
				"Usage: rodex setbody <body>\n");
			return;
		}

		if (exists $rodexWrite->{body}) {
			message TF("Changed the rodex mail message body to '%s'.\n", $arg2);
		} else {
			message TF("Set the rodex mail message body to '%s'.\n", $arg2);
		}

		$rodexWrite->{body} = $arg2;

	} elsif ($arg1 eq 'setzeny') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif ($arg2 eq "" || $arg2 !~ /^\d+$/) {
			error T("Syntax Error in function 'rodex setzeny' (Set zeny of rodex mail)\n" .
				"Usage: rodex setzeny <zeny_amount>\n");
			return;
		} elsif ($arg2 > $char->{zeny}) {
			error T("You can't add more zeny than you have to the rodex mail.\n");
			return;
		}

		if (exists $rodexWrite->{zeny}) {
			message TF("Changed the rodex mail message zeny to '%d'.\n", $arg2);
		} else {
			message TF("Set the rodex mail message zeny to '%d'.\n", $arg2);
		}

		$rodexWrite->{zeny} = $arg2;

	} elsif ($arg1 eq 'add') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif ($arg2 !~ /^\s*(\d+)\s*(\d*)\s*$/) {
			error T("Syntax Error in function 'rodex add' (Add item to rodex mail)\n" .
				"Usage: rodex add <item #> [<amount>]\n");
			return;
		}

		my $max_items = $config{rodexMaxItems} || 5;
		if ($rodexWrite->{items}->size >= $max_items) {
			error T("You can't add any more items to the rodex mail.\n");
			return;
		}

		my ($index, $amount) = parseArgs($arg2);
		$amount = defined $amount ? $amount : 1;
		my $rodex_item = $rodexWrite->{items}->get($index);
		my $item = $char->inventory->get($index);

		if (!$item) {
			error TF("Error in function 'rodex add' (Add item to rodex mail)\n" .
				"Inventory Item '%s' does not exist.\n", $index);
			return;
		} elsif ($item->{equipped}) {
			error TF("Inventory Item '%s' is equipped.\n", $item);
			return;
		} elsif ($rodex_item && $rodex_item->{amount} == $item->{amount}) {
			error TF("You can't add more of Item '%s' to rodex mail because you have already added all you have of it.\n", $item);
			return;
		} elsif ($rodex_item) {
			my $max_add = ($item->{amount} - $rodex_item->{amount});
			$amount = $max_add if ($amount > $max_add);
		} elsif ($amount > $item->{amount}) {
			$amount = $item->{amount};
		}

		message TF("Adding amount %d of item '%s' to rodex mail.\n", $amount, $item);
		$messageSender->rodex_add_item($item->{ID}, $amount);

	} elsif ($arg1 eq 'draft') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;
		}

		my $msg = center( " " .TF("Draft mail for %s", $rodexWrite->{target}{name}) ." ", 119, '-') ."\n";
		$msg .= swrite("@>>>>>>>>> @<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<< @<<<", [T("Recepient:"), $rodexWrite->{target}{name}, T("Base Level:"), $rodexWrite->{target}{base_level}]);
		$msg .= swrite("@>>>>>>>>> @<<<<<<<<<<<<<<<<<<<<<<< @<<<<< @<<<<<<<<<<<<<<<<<<<<", [T("Char ID:"), $rodexWrite->{target}{char_id}, T("Class:"), $jobs_lut{$rodexWrite->{target}{class}}]);
		$msg .= "------\n";
		$msg .= swrite("@<<<<<<<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<", [T("Title:"), $rodexWrite->{title}]);
		$msg .= T("Message:") ."    " .$rodexWrite->{body} ."\n";
		$msg .= swrite("@<<<<<<<<<< @<<<<<<<<<", [T("Zeny:"), $rodexWrite->{zeny}]) if ($rodexWrite->{zeny});
		$msg .= ('-'x119) . "\n";

		message $msg, "list";
		cmdRodex(undef, 'itemslist');

	} elsif ($arg1 eq 'remove') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif ($arg2 !~ /^\s*(\d+)\s*(\d*)\s*$/) {
			error T("Syntax Error in function 'rodex remove' (Remove item from rodex mail)\n" .
				"Usage: rodex remove <item #> [<amount>]\n");
			return;
		}

		my ($index, $amount) = parseArgs($arg2);

		my $item = $rodexWrite->{items}->get($index);
		if (!$item) {
			error TF("Error in function 'rodex remove' (Remove item from rodex mail)\n" .
				"Rodex mail Item '%s' does not exist.\n", $index);
			return;
		}
		if (!$amount || $amount > $item->{amount}) {
			$amount = $item->{amount};
		}

		message TF("Removing amount %d of item '%s' from rodex mail.\n", $amount, $item);
		$messageSender->rodex_remove_item($item->{ID}, $amount);

	} elsif ($arg1 eq 'send') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (!defined $rodexWrite) {
			error T("You are not writing a rodex mail.\n");
			return;

		} elsif (!exists $rodexWrite->{target}) {
			error T("Error in function 'rodex send' (Send finished rodex mail)\n" .
					"You must set target of rodex mail. Usage: rodex settarget <player_name|self>\n");
			return;
		}

		my $zeny_tax = int($rodexWrite->{zeny} / 50);
		my $items_tax = ($rodexWrite->{items}->size * 2500);
		my $tax = ($zeny_tax + $items_tax);

		if (($rodexWrite->{zeny} + $tax) > $char->{zeny}) {
			error TF("The current tax for this rodex mail is %dz, you don't have enough zeny to pay for it.\n", $tax);
			return;
		}

		message T("Sending rodex mail.\n");
		$messageSender->rodex_send_mail();

	} elsif ($arg1 eq 'getitems') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (defined $rodexWrite) {
			error T("You are writing a rodex mail.\n");
			return;

		} elsif ($arg2 eq "" and !exists $rodexList->{current_read}) {
			error T("You are not reading a rodex mail.\n");
			return;

		} elsif ($arg2 ne "" and $arg2 !~ /^\d+$/) {
			error T("Syntax Error in function 'rodex getitems' (Get items of rodex mail)\n" .
				"Usage: rodex getitems [<mail_# | mail_id>]\n");
			return;

		} elsif ($arg2 =~/^\d{1,3}$/) {
			foreach my $mail_id (keys %{$rodexList->{mails}}) {
				my $page_index = $rodexList->{mails}{$mail_id}{page_index};
				if ($page_index == $arg2) {
					$arg2 = $mail_id;
					last;
				} else {
					next;
				}
			}

		} else {
			$arg2 = $rodexList->{current_read} if ($rodexList->{current_read});
		}

		if (!exists $rodexList->{mails}{$arg2}) {
			error TF("The rodex mail of ID '%d' doesn't exist.\n", $arg2);
			return;
		} elsif ($rodexList->{mails}{$arg2}{attach} ne 'i' and $rodexList->{mails}{$arg2}{attach} ne 'z+i') {
			error TF("The rodex mail '%d' has no items.\n", $arg2);
			return;
		}

		my $openType = $rodexList->{mails}{$arg2}{openType};
		message TF("Requesting items of rodex mail '%d'.\n", $arg2);
		$messageSender->rodex_request_items($arg2, 0, $openType);

	} elsif ($arg1 eq 'getzeny') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (defined $rodexWrite) {
			error T("You are writing a rodex mail.\n");
			return;

		} elsif ($arg2 eq "" and !exists $rodexList->{current_read}) {
			error T("You are not reading a rodex mail.\n");
			return;

		} elsif ($arg2 ne "" and $arg2 !~ /^\d+$/) {
			error T("Syntax Error in function 'rodex getzeny' (Get zeny of rodex mail)\n" .
				"Usage: rodex getzeny [<mail_# | mail_id>]\n");
			return;

		} elsif ($arg2 =~/^\d{1,3}$/) {
			foreach my $mail_id (keys %{$rodexList->{mails}}) {
				my $page_index = $rodexList->{mails}{$mail_id}{page_index};
				if ($page_index == $arg2) {
					$arg2 = $mail_id;
					last;
				} else {
					next;
				}
			}

		} else {
			$arg2 = $rodexList->{current_read} if ($rodexList->{current_read});
		}

		if (!exists $rodexList->{mails}{$arg2}) {
			error TF("The rodex mail of ID '%d' doesn't exist.\n", $arg2);
			return;
		} elsif ($rodexList->{mails}{$arg2}{attach} ne 'z' and $rodexList->{mails}{$arg2}{attach} ne 'z+i') {
			error TF("The rodex mail '%d' has no zeny.\n", $arg2);
			return;
		}

		my $openType = $rodexList->{mails}{$arg2}{openType};
		message TF("Requesting zeny of rodex mail '%d'.\n", $arg2);
		$messageSender->rodex_request_zeny($arg2, 0, $openType);

	} elsif ($arg1 eq 'nextpage') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif (defined $rodexWrite) {
			error T("You are writing a rodex mail.\n");
			return;

		} elsif (exists $rodexList->{last_page}) {
			error T("You have already reached the last rodex mail page.\n");
			return;
		}

		message T("Requesting the next page of rodex mail.\n");
		$messageSender->rodex_next_maillist($rodexCurrentType, $rodexList->{current_page_last_mailID}, 0);

	} elsif ($arg1 eq 'delete') {
		if (!defined $rodexList) {
			error T("Your rodex mail box is closed.\n");
			return;

		} elsif ($arg2 eq "" || $arg2 !~ /^\d+$/) {
			error T("Syntax Error in function 'rodex delete' (Delete rodex mail)\n" .
				"Usage: rodex delete <mail_# | mail_id>\n");
			return;

		} elsif ($arg2 =~/^\d{1,3}$/) {
			foreach my $mail_id (keys %{$rodexList->{mails}}) {
				my $page_index = $rodexList->{mails}{$mail_id}{page_index};
				if ($page_index == $arg2) {
					$arg2 = $mail_id;
					last;
				} else {
					next;
				}
			}
		}

		if (!exists $rodexList->{mails}{$arg2}) {
			error TF("The rodex mail of ID '%d' doesn't exist.\n", $arg2);
			return;
		}

		my $openType = $rodexList->{mails}{$arg2}{openType};
		$messageSender->rodex_delete_mail($openType,$arg2,0);

	} else {
		error T("Syntax Error in function 'rodex' (rodex mail)\n" .
			"Usage: rodex [<open|close|list|refresh|nextpage|maillist|read|getitems|getzeny|delete|write|cancel|settarget|settitle|setbody|setzeny|add|remove|itemslist|draft|send>]\n");
	}
}

sub cmdRoulette {
	my (undef, $args) = @_;
	my ($command) = parseArgs( $args );

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if ( $command eq "open" ) {
		message T("Sending Roulette Open\n");
		$messageSender->sendRouletteWindowOpen();
		$messageSender->sendRouletteInfoRequest();
	} elsif ( $command eq "close" ) {
		message T("Roulette System Closed\n");
		$messageSender->sendRouletteClose();
		undef %roulette;
	} elsif ( ( $command eq "info" || $command eq "start" || $command eq "claim" ) && !defined($roulette{items}) ) {
		error TF("Roulette: Error in command '%s', you must need open Roulette first'\n", $command);
	} elsif ( $command eq "info" ) {
		message T("Requesting Roulette Info\n");
		$messageSender->sendRouletteInfoRequest();
	}   elsif ( $command eq "start" ) {
		message T("Sending Roulette Start (roll)\n");
		$messageSender->sendRouletteStart();
	} elsif ( $command eq "claim" ) {
		message T("Trying to Claim Roulette Reward\n");
		$messageSender->sendRouletteClaimPrize();
	} else {
		error T("Syntax Error in function 'roulette'\n" .
				"roulette <open|info|close|start|claim>\n");
	}
}

sub cmdCancelTransaction {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if ($ai_v{'npc_talk'}{'talk'} eq 'buy_or_sell' || $ai_v{'npc_talk'}{'talk'} eq 'store') {
		cancelNpcBuySell();
	} else {
		error T("You are not on a sell or store npc interaction.\n");
	}
}

##
# 'cm' for Change Material (Genetic)
# 'analysis' for Four Spirit Analysis (Sorcerer) [Untested yet]
# @author [Cydh]
##
sub cmdExchangeItem {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($switch, $args) = @_;
	my $type;
	my $typename;

	if ($switch eq "cm") {
		if ($skillExchangeItem != 1) { # Change Material (2494)
			error T("This command only available after using 'Change Material' skill!\n");
			return;
		}
		$typename = "Change Material";
	} elsif ($switch eq "analysis") {
		if ($skillExchangeItem != 2 && $skillExchangeItem != 3) { # Four Spirit Analysis (2462)
			error T("This command only available after using 'Four Spirit Analysis' skill!\n");
			return;
		}
		$typename = "Four Spirit Analysis";
	} else {
		error T("Invalid usage!\n");
		return;
	}

	if ($args eq "cancel" || $args eq "end" || $args eq "no") {
		my @items = ();
		message TF("Item Exchange %s is canceled.\n", $typename), "info";
		undef $skillExchangeItem;
		$messageSender->sendItemListWindowSelected(0, $type, 0, \@items); # Cancel: 0
		return;
	}
	$type = $skillExchangeItem-1;

	my ($item1, $amt1) = $args =~ /^(\d+) (\d+)/;

	if ($item1 >= 0 and $amt1 > 0) {
		my @list = split(/,/, $args);
		my @items = ();

		@list = grep(!/^$/, @list); # Remove empty entries
		foreach (@list) {
			my ($invIndex, $amt) = $_ =~ /^(\d+) (\d+)/;
			my $item = $char->inventory->get($invIndex);
			if ($item) {
				if ($item->{amount} < $amt) {
					warning TF("Invalid amount! Only have %dx %s (%d).\n", $item->{amount}, $item->{name}, $invIndex);
				} elsif ($item->{equipped} != 0) {
					warning TF("Equipped item was selected %s (%d)!\n", $item->{name}, $invIndex);
				} else {
					#message TF("Selected: %dx %s invIndex:%d binID:%d\n", $amt, $item->{name}, $invIndex, unpack 'v', (unpack 'v', $item->{ID}));
					push(@items,{itemIndex => (unpack 'v', $item->{ID}), amount => $amt, itemName => $item->{name}});
				}
			} else {
				warning TF("Item in index '%d' is not exists.\n", $invIndex);
			}
		}
		if (@items > 0) {
			my $num = scalar @items;
			message TF("Number of selected items for %s: %d\n", $typename, $num), "info";
			message T("======== Exchange Item List ========\n");
			map {message "$_->{itemName} $_->{amount}x\n"} @items;
			message "==============================\n";
			undef $skillExchangeItem;
			$messageSender->sendItemListWindowSelected($num, $type, 1, \@items); # Process: 1
			return;
		} else {
			error T("No item was selected.\n");
		}
	}

	error TF("Syntax Error in function '%s'. Usages:\n".
			"Single Item: %s <item #> <amount>\n".
			"Combination: %s <item #> <amount>,<item #> <amount>,<item #> <amount>\n", $switch, $switch, $switch);
}

##
# refineui select [item_index]
# refineui refine [item_index] [material_id] [catalyst_toggle]
# @author [Cydh]
##
sub cmdRefineUI {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}
	my ($cmd, $args_string) = @_;
	if (!defined $refineUI) {
		error T("Cannot use RefineUI yet.\n");
		return;
	}
	my @args = parseArgs($args_string, 4);

	# refineui close
	# End Refine UI state
	if ($args[0] eq "cancel" || $args[0] eq "end" || $args[0] eq "no") {
		message T("Closing Refine UI.\n"), "info";
		undef $refineUI;
		$messageSender->sendRefineUIClose();
		return;

	# refineui select [item_index]
	# Do refine
	} elsif ($args[0] eq "select") {
		#my ($invIndex) = $args =~ /^(\d+)/;
		my $invIndex = $args[1];

		# Check item
		my $item = $char->inventory->get($invIndex);
		if (!defined $item) {
			warning TF("Item in index '%d' is not exists.\n", $invIndex);
			return;
		} elsif ($item->{equipped} != 0) {
			warning TF("Cannot select equipped %s (%d) item!\n", $item->{name}, $invIndex);
			return;
		}
		$refineUI->{invIndex} = $invIndex;
		message TF("Request info for selected item to refine: %s (%d)\n", $item->{name}, $invIndex);
		$messageSender->sendRefineUISelect( $item->{ID});
		return;

	# refineui refine [item_index] [material_id] [catalyst_toggle]
	# Do refine
	} elsif ($args[0] eq "refine") {
		#my ($invIndex, $matInvIndex, $catalyst) = $args =~ /^(\d+) (\d+) (\d+|yes|no)/;
		my $invIndex = $args[1];
		my $matNameID = $args[2];
		my $catalyst = $args[3];

		# Check item
		my $item = $char->inventory->get($invIndex);
		if (!defined $item) {
			warning TF("Item in index '%d' is not exists.\n", $invIndex);
			return;
		} elsif ($item->{equipped} != 0) {
			warning TF("Cannot select equipped %s (%d) item!\n", $item->{name}, $invIndex);
			return;
		}

		# Check material
		my $material = $char->inventory->getByNameID($matNameID);
		if (!defined $material) {
			warning TF("You don't have enough '%s' (%d) as refine material.\n", itemNameSimple($matNameID), $matNameID);
			return;
		}
		# Check if the selected item is valid material
		my $valid = 0;
		foreach my $mat (@{$refineUI->{materials}}) {
			if ($mat->{nameid} == $matNameID) {
				$valid = 1;
			}
		}
		if ($valid != 1) {
			warning TF("'%s' (%d) is not valid refine material for '%s'.\n", itemNameSimple($matNameID), $matNameID, $item->{name});
			return;
		}

		# Check catalyst toggle
		my $useCatalyst = 0;
		#my $Blacksmith_Blessing = 6635; # 6635,Blacksmith_Blessing,Blacksmith Blessing
		my $blessName = itemNameSimple($Blacksmith_Blessing);
		if ($refineUI->{bless} > 0 && ($catalyst == 1 || $catalyst eq "yes")) {
			my $catalystItem = $char->inventory->getByNameID($Blacksmith_Blessing);
			if (!$catalystItem || $catalystItem->{amount} < $refineUI->{bless}) {
				warning TF("You don't have %s for RefineUI. Needed: %d!\n", $blessName, $refineUI->{bless});
				return;
			}
			$useCatalyst = 1;
		}

		my $matStr = $material->{name};
		if ($useCatalyst) {
			$matStr .= " and ".$refineUI->{bless}."x ".$blessName;
		}
		message TF("Refining item: %s with material %s.\n", $item->{name}, $matStr);
		$messageSender->sendRefineUIRefine($item->{ID}, $matNameID, $useCatalyst);
		return;
	} else {
		error T("Invalid usage!\n");
		return;
	}
}

sub cmdClan {
    my (undef, $args_string) = @_;
    my (@args) = parseArgs($args_string, 3);

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	} elsif(!$clan{clan_name}) {
		error TF("You must be in a Real Clan to use command '%s'\n", shift);
		return;
	}

	if ($args[0] eq "info" || $args[0] eq "") {
		my $msg = center(T(" Clan Information "), 40, '-') ."\n" .
			TF("ClanName : %s\n" .
				"Clan Master Name : %s\n" .
				"Number of Members : %s/%s\n".
				"Castles Owned : %s\n" .
				"Ally Clan Count : %s\n" .
				"Ally Clan Names: %s\n" .
				"Hostile Clan Count: %s\n" .
				"Hostile Clan Names: %s\n",
		$clan{clan_name}, $clan{clan_master}, $clan{onlineuser}, $clan{totalmembers}, $clan{clan_map}, $clan{alliance_count}, $clan{ally_names}, $clan{antagonist_count}, $clan{antagonist_names});
		$msg .= ('-'x40) . "\n";
		message $msg, "info";
	}
}

sub cmdElemental {
	my (undef, $args_string) = @_;
    my (@args) = parseArgs($args_string, 3);

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if ($args[0] eq "info" || $args[0] eq "") {
		if(!$char->{elemental}{ID}) {
			error TF("You don't have any elemental. Call an Elemental first.\n");
			return;
		}

		my $msg = center(T(" Elemental Information "), 50, '-') ."\n" .
				TF("ID: %s (%s)\n".
					"Name : %s \n".
					"HP: %s/%s (%s\%)\n".
					"SP: %s/%s (%s\%)\n".
					"Position: %s,%s\n",
				unpack('V',$char->{elemental}{ID}), getHex($char->{elemental}{ID}),
				$char->{elemental}{name},
				$char->{elemental}{hp}, $char->{elemental}{hp_max}, sprintf("%.2f",$char->{elemental}->hp_percent()),
				$char->{elemental}{sp}, $char->{elemental}{sp_max}, sprintf("%.2f",$char->{elemental}->sp_percent()),
				$char->{elemental}{'pos'}{'x'},$char->{elemental}{'pos'}{'y'},
			);
			$msg .= ('-'x50) . "\n";
			message $msg, "info";

	} elsif ($args[0] eq "list" && $args[1] =~ /\d+/) {
		my $elemental = $elementalsList->get($args[1]);
		if(!$elemental) {
			error TF("Elemental \"%s\" does not exist.\n", $args[1]);
		} else {
			my $pos = calcPosition($elemental);
			my $mypos = calcPosition($char);
			my $dist = sprintf("%.1f", distance($pos, $mypos));
			$dist =~ s/\.0$//;

			my $msg = center(T(" Elemental Info "), 67, '-') ."\n" .

			TF("%s (%s) \n".
				"ID: %s (Hex: %s)\n" .
				"Position: %s, %s  Distance: %-17s\n" .
				"Level: %-7d\n" .
				"Class: %s\n" .
				"Walk speed: %s secs per block\n",
			$elemental->{name}, $elemental->{binID},
			unpack('V',$char->{elemental}{ID}), getHex($char->{elemental}{ID}),
			$pos->{x}, $pos->{y}, $dist,
			$elemental->{lv},
			$jobs_lut{$elemental->{jobID}},
			$elemental->{walk_speed});

			$msg .= '-' x 67 . "\n";
			message $msg, "info";
			return;
		}
	} elsif ($args[0] eq "list") {
		my $msg = center(T(" Elemental List "), 79, '-') ."\n".
		T("#    Name                Lv   Dist  Coord\n");
		for my $elemental (@$elementalsList) {
			my ($name, $dist, $pos);
			$name = $jobs_lut{$elemental->{jobID}};
			my $elementalpos = calcPosition($elemental);
			my $mypos = calcPosition($char);
			$dist = sprintf("%.1f", distance($elementalpos, $mypos));
			$dist =~ s/\.0$//;
			$pos = '(' . $elemental->{pos}{x} . ', ' . $elemental->{pos}{y} . ')';
			$msg .= swrite(
				"@<<< @<<<<<<<<<<<<<<<<<< @<<< @<<   @<<<<<<<<<<",
				[$elemental->{binID}, $name, $elemental->{lv}, $dist, $pos]);
		}

		if (my $elementalsTotal = $elementalsList && $elementalsList->size) {
			$msg .= TF("Total elementals: %s \n", $elementalsTotal);
		} else	{$msg .= T("There are no elementals near you.\n");}

		$msg .= '-' x 79 . "\n";
		message $msg, "list";

	} else {
		error T("Error in function 'elemental'\n" .
			"Usage: elemental <info|list [<elemental index>]>\n
				info: show info from self elemental.\n
				list: list all elementals on screen.\n
				list <index number> show information about a specific elemental");
	}
}

sub cmdCreate {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	my ($cmd, $args) = @_;
	my @arg = parseArgs($args);

	if ($arg[0] =~ /^\d+/ && defined $makableList->[$arg[0]]) { # viewID/nameID can be 0
		$arg[1] = 0 if !defined $arg[1];
		$arg[2] = 0 if !defined $arg[2];
		$arg[3] = 0 if !defined $arg[3];
		$messageSender->sendMakeItemRequest($makableList->[$arg[0]], $arg[1], $arg[2], $arg[3]);
	} elsif($arg[0] =~ /^\d+/) {
		message TF("Item with 'create' index: %s not found.\n", $arg[0]), "info";
	} else {
		error T("Error in function 'create'\n" .
			"Usage: create <index number> <material 1 nameID> <material 2 nameID> <material 3 nameID>\n".
			"material # nameID: can be 0 or undefined.\n");
	}

	undef $makableList;
}

sub cmdSearchStore {
	my ($cmd, $args) = @_;

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", $cmd);
		return;
	}

	my @args = parseArgs($args);

	if (!$universalCatalog{open}) {
		error T("Error in function 'searchstore' (universal catalog)\n".
				"No catalog in use. You can't use this yet.\n");
		return;
	}

	if ($args[0] eq "close") {
		$messageSender->sendSearchStoreClose();
		message T("Closed search store catalog\n");
		return;
	}

	if ($args[0] eq "next") {
		if ($universalCatalog{has_next}) {
			$messageSender->sendSearchStoreRequestNextPage();
			message T("Requested next page of search store catalog\n");
			return;
		}
		error T("Error in function 'searchstore' (universal catalog)\n".
				"Already reached the end. There's no next page\n");
		return;
	}

	if ($args[0] eq "buy") {
		if ($universalCatalog{type} == 0) {
			error T("Error in function 'searchstore' (universal catalog)\n".
					"You cannot buy with the Silver Catalog.\n");
			return;
		}

		if ($venderItemList->size() == 0 || !defined $venderID || !defined $venderCID) {
			error T("Error in function 'searchstore' (universal catalog)\n".
					"No store selected. Please select a store with 'searchstore select' first\n");
			return;
		}

		if ($args[1] eq "end") {
			$venderItemList->clear;
			undef $venderID;
			undef $venderCID;

			return;
		}

		if ($args[1] eq "view") {
			$messageSender->sendEnteringVender($venderID);
			return;
		}

		if (scalar @args > 1) {
			my $item = $venderItemList->get($args[1]);

			if (!$item) {
				error TF("Error in function 'searchstore' (universal catalog)\n".
						"Item %s does not exist\n", $args[1]);
				return;
			}

			my $amount = (scalar @args > 2 && $args[2] >= 0) ? $args[2] : 1;

			$messageSender->sendBuyBulkVender( $venderID, [ { itemIndex => $item->{ID}, amount => $amount } ], $venderCID );

			return;
		}

		error T("Error in function 'searchstore buy' (Buy using a Gold Search Catalog\n".
				"Syntax: buy [view|end|<item #> [<amount>]]\n");
	}

	if ($args[0] eq "view") {
		if (!scalar(@{$universalCatalog{list}})) {
			error T("Error in function 'searchstore view' (store search view page)\n".
					"No info available yet\n");
			return;
		} elsif ($args[1] + 1 > scalar(@{$universalCatalog{list}})) {
			error TF("Error in function 'searchstore view' (store search view page)\n".
					"Page %d out of bounds (valid bounds: 0..%d)\n", $args[1], scalar(@{$universalCatalog{list}}) - 1);
			return;
		} else {
			Misc::searchStoreInfo($args[1]);
			return;
		}
	}

	if ($args[0] eq "search") {
		my $searchMethod;

		if ($args[1] eq "match") {
			$searchMethod = \&containsItemNameToIDList;
		} elsif ($args[1] eq "exact") {
			$searchMethod = \&itemNameToIDList;
		} else {
			error T("Error in function 'searchstore search' (store search)\n" .
					"Syntax: searchstore search [match|exact] \"<item name>\" [card <card name>] [price <min_price>..<max_price>] [sell|buy]\n");

			return;
		}

		my @ids = $searchMethod->($args[2]);
		my @cards;
		my @price;
		my $type = 0;

		if (!scalar(@ids)) {
			error TF("Error in function 'searchstore search' (store search)\n" .
					"Item '%s' not found\n", $args[2]);
			return;
		}

		if ($args[3] eq "card") {
			@cards = $searchMethod->($args[4]);

			if ($args[5] eq "price") {
				@price = split '..', $args[6];
			}
		} elsif ($args[3] eq "price") {
			@price = split '..', $args[4];

			if ($args[5] eq "card") {
				@cards = $searchMethod->($args[6]);
			}
		}

		if ($args[-1] eq "buy") {
			$type = 1;
		}

		# Limit search size
		# I'm not sure about the max size, this needs more testing or might be server-specific, but must exist - lututui
		if (scalar @ids + scalar @cards > 15) {
			error $msgTable[1785] . "\n";
			return;
		}

		$messageSender->sendSearchStoreSearch({
			item_list => \@ids,
			card_list => \@cards,
			min_price => $price[0],
			max_price => $price[1],
			type => $type
		});

		return;
	}

	if ($args[0] eq "select") {
		if (scalar @args > 2) {
			if ($args[1] > scalar(@{$universalCatalog{list}}) - 1) {
				error TF("Error in function 'searchstore select' (store search select store)\n".
					"Page %d out of bounds (valid bounds: [0,%d])\n", $args[1], scalar(@{$universalCatalog{list}}) - 1);
				return;
			}

			if ($args[2]> scalar(${$universalCatalog{list}}[$args[1]]) - 1) {
				error TF("Error in function 'searchstore select' (store search select store)\n".
					"Item %d out of bounds (valid bounds: [0,%d])\n", $args[1], scalar(${$universalCatalog{list}}[$args[1]]) - 1);
				return;
			}

			$messageSender->sendSearchStoreSelect({
				accountID => ${$universalCatalog{list}}[$args[1]][$args[2]]{accountID},
				storeID => ${$universalCatalog{list}}[$args[1]][$args[2]]{storeID},
				nameID => ${$universalCatalog{list}}[$args[1]][$args[2]]{nameID},
			});

			return;
		}

		error T("Error in function 'searchstore select' (select store)\n" .
				"Syntax: searchstore select <page #> <store #> \n");
		return;
	}

	error T("Syntax error in 'searchstore' command (Universal catalog command)\n" .
			"searchstore close : Closes search store catalog\n" .
			"searchstore next : Requests catalog next page\n" .
			"searchstore view <page #> : Shows catalog page # (0-indexed)\n" .
			"searchstore search [match|exact] \"<item name>\" [card \"<card name>\"] [price <min_price>..<max_price>] [sell|buy] : Searches for an item\n" .
			"searchstore select <page #> <store #> : Selects a store\n" .
			"searchstore buy [view|end|<item #> [<amount>]] : Buys from a store using Universal Catalog Gold\n");
}

sub cmdRevive {
	my ($cmd, $args) = @_;

	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", $cmd);
		return;
	}

	if (!$char->{dead}) {
		error TF("You must be dead to use this command '%s'\n", $cmd);
		return;
	}

	my @args = parseArgs($args);
	my $item;

	if (scalar @args == 1) {
		# User passed an item nameID
		if ($args[0] =~ /^\d+$/) {
			$item = $char->inventory->getByNameID($args[0]);
		}
		# User passed an item name
		elsif ($args[0] ne "force") {
			$item = $char->inventory->getByName($args[0]);
		}
	} elsif (scalar @args == 0) {
		# Try to find Token Of Siegfried
		$item = $char->inventory->getByNameID(7621);
	} else {
		error T("Error in 'revive' command (incorrect syntax)\n".
				"revive [force|\"<item_name>\"|<item_ID>]\n");
		return;
	}

	if (!$item && $args[0] ne "force") {
		error TF("Error in 'revive' command\n".
				"Cannot use item '%s' in attempt to revive: item not found in inventory\n", $args[0]);
		return;
	}

	if ($item && $args[0] ne "force") {
		message TF("Trying to use item '%s' to self-revive\n", $item->name());
	} else {
		message TF("Trying to self-revive using 'force'\n");
	}
	$messageSender->sendAutoRevive();
}

sub cmdCashShopBuy {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if (!$cashList || $cashList->size < 1) {
		error T("No cash shop info to buy\n");
		return;
	}

	my (undef, $args) = @_;
	my ($points, $items) = $args =~ /(\d+) (.*)/;
	my @buylist;
	my $cost_total = 0;
	foreach (split /\,/, $items) {
		my($index, $amount) = $_ =~ /^\s*(\d+)\s*(\d*)\s*$/;
		if ($index eq "") {
			error T("Syntax Error in function 'cashbuy' (Buy Cash Item)\n" .
				"Usage: cashbuy <kafra_points> <item #> [<amount>][, <item #> [<amount>]]...\n");
			return;

		} elsif ($amount eq "" || $amount <= 0) {
			$amount = 1;
		}
		my $item = $cashList->get($index);
		if (!$item) {
			error TF("Error in function 'cashbuy' (Buy Cash Item)\n" .
				"Cash Item at index %s does not exist.\n", $index);
			return;
		}
		$cost_total += $item->{price};
		push (@buylist,{itemID  => $item->{nameID}, amount => $amount});
	}

	if (!scalar @buylist) {
		error T("Syntax Error in function 'cashbuy' (Buy Cash Item)\n" .
			"Usage: cashbuy <kafra_points> <item #> [<amount>][, <item #> [<amount>]]...\n");
		return;
	}


	# TODO: Add check to ignore the cost for private servers
	#if (!$cashShop{points} || $cost_total > ($cashShop{points}->{cash} + $cashShop{points}->{kafra})) {
	#	error TF("You dont' have enough cash and points to buy the items. %d > %d + %d\n", $cost_total, $cashShop{points}->{cash}, $cashShop{points}->{kafra});
	#	return;
	#}

	message TF("Attempt to buy %d items from cash dealer\n", (scalar @buylist)), "info";
	debug "Buying cash ".(scalar @buylist)." items: ".(join ', ', map {"".$_->{amount}."x ".$_->{itemID}.""} @buylist)."\n", "sendPacket";
	$messageSender->sendCashShopBuy($points, \@buylist);
}


##
# 'merge' Merge Item
# @author [Cydh]
##
sub cmdMergeItem {
	if (!$net || $net->getState() != Network::IN_GAME) {
		error TF("You must be logged in the game to use this command '%s'\n", shift);
		return;
	}

	if (not defined $mergeItemList) {
		error T("You cannot use this command yet. Only available after talking with Mergician-like NPC!\n");
		return;
	}

	my ($switch, $args) = @_;
	my ($mode) = $args =~ /^(\w+)/;

	if ($mode eq "" || $mode eq "list") {
		my $title = TF("Available Items to merge");
		my $msg = center(' '. $title . ' ', 50, '-') ."\n".
					T ("#     Item Name\n");
		foreach my $itemid (keys %{$mergeItemList}) {
			$msg .= "-- ".$mergeItemList->{$itemid}->{name}." (".$itemid.") x ".scalar(@{$mergeItemList->{$itemid}->{list}})."\n";
			foreach my $item (@{$mergeItemList->{$itemid}->{list}}) {
				my $display = $item->{info}->{name}." x ".$item->{info}->{amount};
				$msg .= swrite(
					"@<<<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<",
					[$item->{info}->{binID}, $display]);
			}
		}
		$msg .= ('-'x50) . "\n";
		message $msg, "list";
		message T("To merge by item id: merge <itemid>\nOr one-by-one: merge <item #>,<item #>[,...]\n"), "info";
		return;

	} elsif ($mode eq "cancel") {
		$messageSender->sendMergeItemCancel();
		message TF("Merge Item is canceled.\n"), "info";
		return;
	}

	# Merging process
	my @list = split(/,/, $args);
	my @items = ();
	my $merge_itemid = 0;

	@list = grep(!/^$/, @list); # Remove empty entries
	foreach (@list) {
		my ($id) = $_ =~ /^(\d+)/;
		# Merge by item ID
		if ((scalar @list) == 1 && $char->inventory->getByNameID($id)) {
			debug "Merge item by item ID $id\n";
			foreach my $item (@{$mergeItemList->{$id}->{list}}) {
				push @items, $item;
			}
			last;
		}

		# User defined, however must be same item id
		my $found = 0;
		foreach my $itemid (keys %{$mergeItemList}) {
			foreach my $item (@{$mergeItemList->{$itemid}->{list}}) {
				if ($item->{info}->{binID} == $id) {
					if ($merge_itemid > 0 && $merge_itemid != $item->{info}->{nameID}) {
						error TF("Selected item is not same. Index:'%d' nameID:'%d' first selected:'%d'\n", $id, $item->{info}->{nameID}, $merge_itemid);
						return;
					} elsif ($merge_itemid == 0) {
						$merge_itemid = $item->{info}->{nameID};
					}
					push @items, $item;
					$found = 1;
					last;
				}
			}
			last if ($found == 1);
		}
		if ($found != 1) {
			warning TF("Cannot find item with id '%d'.\n", $id);
		}
	}

	if (@items > 1) {
		my $num = scalar @items;
		message T("======== Merge Item List ========\n");
		map { message unpack("v2", $_->{ID})." ".$_->{info}->{name}." (".$_->{info}->{binID}.") x ".$_->{info}->{amount}."\n" } @items;
		message "==============================\n";
		$mergeItemList = {};
		$messageSender->sendMergeItemRequest($num, \@items);
		return;
	}

	error T("No item was selected or at least need 2 same items.\n");
	error T("To merge by item id: merge <itemid>\nOr one-by-one: merge <item #>,<item #>[,...]\n"), "info";
}

1;
