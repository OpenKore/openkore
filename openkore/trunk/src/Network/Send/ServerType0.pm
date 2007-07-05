#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# June 21 2007, this is the server type for:
# pRO (Philippines), except Sakray and Thor
# And many other servers.
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType0;

use strict;
use Time::HiRes qw(time);
use Digest::MD5;

use Network::Send ();
use base qw(Network::Send);
use Plugins;
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils;
use Utils::Exceptions;


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendAddSkillPoint {
	my ($self, $skillID) = @_;
	my $msg = pack("C*", 0x12, 0x01) . pack("v*", $skillID);
	$self->sendToServer($msg);
}

sub sendAddStatusPoint {
	my ($self, $statusID) = @_;
	my $msg = pack("C*", 0xBB, 0) . pack("v*", $statusID) . pack("C*", 0x01);
	$self->sendToServer($msg);
}

sub sendAlignment {
	my ($self, $ID, $alignment) = @_;
	my $msg = pack("C*", 0x49, 0x01) . $ID . pack("C*", $alignment);
	$self->sendToServer($msg);
	debug "Sent Alignment: ".getHex($ID).", $alignment\n", "sendPacket", 2;
}

sub sendArrowCraft {
	my ($self, $index) = @_;
	my $msg = pack("C*", 0xAE, 0x01) . pack("v*", $index);
	$self->sendToServer($msg);
	debug "Sent Arrowmake: $index\n", "sendPacket", 2;
}

sub sendAttack {
	my ($self, $monID, $flag) = @_;
	my $msg;

	$msg = pack("C*", 0x89, 0x00) .
		$monID .
		pack("C*", $flag);

	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendAttackStop {
	my $self = shift;
	#my $msg = pack("C*", 0x18, 0x01);
	# Apparently this packet is wrong. The server disconnects us if we do this.
	# Sending a move command to the current position seems to be able to emulate
	# what this function is supposed to do.

	# Don't use this function, use Misc::stopAttack() instead!
	#sendMove ($char->{'pos_to'}{'x'}, $char->{'pos_to'}{'y'});
	#debug "Sent stop attack\n", "sendPacket";
}

sub sendAutoSpell {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xce, 0x01, $ID, 0x00, 0x00, 0x00);
	$self->sendToServer($msg);
}

sub sendBanCheck {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x87, 0x01) . $ID;
	$self->sendToServer($msg);
	debug "Sent Account Ban Check Request : " . getHex($ID) . "\n", "sendPacket", 2;
}

sub sendBuy {
	my ($self, $ID, $amount) = @_;
	my $msg = pack("C*", 0xC8, 0x00, 0x08, 0x00) . pack("v*", $amount, $ID);
	$self->sendToServer($msg);
	debug "Sent buy: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendBuyVender {
	my ($self, $venderID, $ID, $amount) = @_;
	my $msg = pack("C*", 0x34, 0x01, 0x0C, 0x00) . $venderID . pack("v*", $amount, $ID);
	$self->sendToServer($msg);
	debug "Sent Vender Buy: ".getHex($ID)."\n", "sendPacket";
}

sub sendCardMerge {
	my ($self, $card_index, $item_index) = @_;
	my $msg = pack("C*", 0x7C, 0x01) . pack("v*", $card_index, $item_index);
	$self->sendToServer($msg);
	debug "Sent Card Merge: $card_index, $item_index\n", "sendPacket";
}

sub sendCardMergeRequest {
	my ($self, $card_index) = @_;
	my $msg = pack("C*", 0x7A, 0x01) . pack("v*", $card_index);
	$self->sendToServer($msg);
	debug "Sent Card Merge Request: $card_index\n", "sendPacket";
}

sub sendCartAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0x26, 0x01) . pack("v*", $index) . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Cart Add: $index x $amount\n", "sendPacket", 2;
}

sub sendCartGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0x27, 0x01) . pack("v*", $index) . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Cart Get: $index x $amount\n", "sendPacket", 2;
}

sub sendCharCreate {
	my ($self, $slot, $name,
	    $str, $agi, $vit, $int, $dex, $luk,
		$hair_style, $hair_color) = @_;
	$hair_color ||= 1;
	$hair_style ||= 0;

	my $msg = pack("C*", 0x67, 0x00) .
		pack("a24", stringToBytes($name)) .
		pack("C*", $str, $agi, $vit, $int, $dex, $luk, $slot) .
		pack("v*", $hair_style, $hair_color);
	$self->sendToServer($msg);
}

sub sendCharDelete {
	my ($self, $charID, $email) = @_;
	my $msg = pack("C*", 0x68, 0x00) .
			$charID . pack("a40", stringToBytes($email));
	$self->sendToServer($msg);
}

sub sendCharLogin {
	my ($self, $char) = @_;
	my $msg = pack("C*", 0x66,0) . pack("C*",$char);
	$self->sendToServer($msg);
}

sub sendChat {
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});

	$data = pack("C*", 0x8C, 0x00) .
		pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
		
	$self->sendToServer($data);
}

sub sendChatRoomBestow {
	my ($self, $name) = @_;

	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName .= chr(0) x (24 - length($binName));

	my $msg = pack("C*", 0xE0, 0x00, 0x00, 0x00, 0x00, 0x00) . $binName;
	$self->sendToServer($msg);
	debug "Sent Chat Room Bestow: $name\n", "sendPacket", 2;
}

sub sendChatRoomChange {
	my ($self, $title, $limit, $public, $password) = @_;

	my $titleBytes = stringToBytes($title);
	my $passwordBytes = stringToBytes($password);
	$passwordBytes = substr($passwordBytes, 0, 8) if (length($passwordBytes) > 8);
	$passwordBytes = $passwordBytes . chr(0) x (8 - length($passwordBytes));

	my $msg = pack("C*", 0xDE, 0x00).pack("v*", length($titleBytes) + 15, $limit).pack("C*",$public).$passwordBytes.$titleBytes;
	$self->sendToServer($msg);
	debug "Sent Change Chat Room: $title, $limit, $public, $password\n", "sendPacket", 2;
}

sub sendChatRoomCreate {
	my ($self, $title, $limit, $public, $password) = @_;

	my $passwordBytes = stringToBytes($password);
	$passwordBytes = substr($passwordBytes, 0, 8) if (length($passwordBytes) > 8);
	$passwordBytes = $passwordBytes . chr(0) x (8 - length($passwordBytes));
	my $binTitle = stringToBytes($title);

	my $msg = pack("C*", 0xD5, 0x00) .
		pack("v*", length($binTitle) + 15, $limit) .
		pack("C*", $public) . $passwordBytes . $binTitle;
	$self->sendToServer($msg);
	debug "Sent Create Chat Room: $title, $limit, $public, $password\n", "sendPacket", 2;
}

sub sendChatRoomJoin {
	my ($self, $ID, $password) = @_;

	my $passwordBytes = stringToBytes($password);
	$passwordBytes = substr($passwordBytes, 0, 8) if (length($passwordBytes) > 8);
	$passwordBytes = $passwordBytes . chr(0) x (8 - length($passwordBytes));
	my $msg = pack("C*", 0xD9, 0x00).$ID.$passwordBytes;
	$self->sendToServer($msg);
	debug "Sent Join Chat Room: ".getHex($ID)." $password\n", "sendPacket", 2;
}

sub sendChatRoomKick {
	my ($self, $name) = @_;

	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName .= chr(0) x (24 - length($binName));
	my $msg = pack("C*", 0xE2, 0x00) . $binName;
	$self->sendToServer($msg);
	debug "Sent Chat Room Kick: $name\n", "sendPacket", 2;
}

sub sendChatRoomLeave {
	my $self = shift;
	my $msg = pack("C*", 0xE3, 0x00);
	$self->sendToServer($msg);
	debug "Sent Leave Chat Room\n", "sendPacket", 2;
}

sub sendCloseShop {
	my $self = shift;
	my $msg = pack("C*", 0x2E, 0x01);
	$self->sendToServer($msg);
	debug "Shop Closed\n", "sendPacket", 2;
}

sub sendCompanionRelease {
	my $msg = pack("C*", 0x2A, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent Companion Release (Cart, Falcon or Pecopeco)\n", "sendPacket", 2;
}

sub sendCurrentDealCancel {
	my $msg = pack("C*", 0xED, 0x00);
	$_[0]->sendToServer($msg);
	debug "Sent Cancel Current Deal\n", "sendPacket", 2;
}

sub sendDeal {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xE4, 0x00) . $ID;
	$_[0]->sendToServer($msg);
	debug "Sent Initiate Deal: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendDealAccept {
	my $msg = pack("C*", 0xE6, 0x00, 0x03);
	$_[0]->sendToServer($msg);
	debug "Sent Accept Deal\n", "sendPacket", 2;
}

sub sendDealAddItem {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0xE8, 0x00) . pack("v*", $index) . pack("V*",$amount);
	$_[0]->sendToServer($msg);
	debug "Sent Deal Add Item: $index, $amount\n", "sendPacket", 2;
}

sub sendDealCancel {
	my $msg = pack("C*", 0xE6, 0x00, 0x04);
	$_[0]->sendToServer($msg);
	debug "Sent Cancel Deal\n", "sendPacket", 2;
}

sub sendDealFinalize {
	my $msg = pack("C*", 0xEB, 0x00);
	$_[0]->sendToServer($msg);
	debug "Sent Deal OK\n", "sendPacket", 2;
}

sub sendDealOK {
	my $msg = pack("C*", 0xEB, 0x00);
	$_[0]->sendToServer($msg);
	debug "Sent Deal OK\n", "sendPacket", 2;
}

sub sendDealTrade {
	my $msg = pack("C*", 0xEF, 0x00);
	$_[0]->sendToServer($msg);
	debug "Sent Deal Trade\n", "sendPacket", 2;
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xA2, 0x00) . pack("v*", $index, $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendEmotion {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xBF, 0x00).pack("C1",$ID);
	$self->sendToServer($msg);
	debug "Sent Emotion\n", "sendPacket", 2;
}

sub sendEnteringVender {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x30, 0x01) . $ID;
	$self->sendToServer($msg);
	debug "Sent Entering Vender: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendEquip {
	my ($self, $index, $type) = @_;
	my $msg = pack("C*", 0xA9, 0x00) . pack("v*", $index) .  pack("v*", $type);
	$self->sendToServer($msg);
	debug "Sent Equip: $index Type: $type\n" , 2;
}

sub sendFriendAccept {
	my ($self, $accountID, $charID) = @_;
	my $msg = pack("C*", 0x08, 0x02) . $accountID . $charID . pack("C*", 0x01, 0x00, 0x00, 0x00);
	$self->sendToServer($msg);
	debug "Sent Accept friend request\n", "sendPacket";
}

sub sendFriendReject {
	my ($self, $accountID, $charID) = @_;
	my $msg = pack("C*", 0x08, 0x02) . $accountID . $charID . pack("C*", 0x00, 0x00, 0x00, 0x00);
	$self->sendToServer($msg);
	debug "Sent Reject friend request\n", "sendPacket";
}

sub sendFriendRequest {
	my ($self, $name) = @_;

	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName = $binName . chr(0) x (24 - length($binName));
	my $msg = pack("C*", 0x02, 0x02) . $binName;

	$self->sendToServer($msg);
	debug "Sent Request to be a friend: $name\n", "sendPacket";
}

sub sendFriendRemove {
	my ($self, $accountID, $charID) = @_;
	my $msg = pack("C*", 0x03, 0x02) . $accountID . $charID;
	$self->sendToServer($msg);
	debug "Sent Remove a friend\n", "sendPacket";
}

sub sendForgeItem {
	my ($self, $ID,
		# nameIDs for added items such as Star Crumb or Flame Heart
		$item1, $item2, $item3) = @_;

	my $msg = pack("C*", 0x8E, 0x01) . pack("v1 v1 v1 v1", $ID, $item1, $item2, $item3);
	$self->sendToServer($msg);
	debug "Sent Forge Item: $ID\n" , 2;
}

sub sendGameLogin {
	my ($self, $accountID, $sessionID, $sessionID2, $sex) = @_;
	my $msg = pack("v1", hex($masterServer->{gameLogin_packet}) || 0x65) . $accountID . $sessionID . $sessionID2 . pack("C*", 0, 0, $sex);
	if (hex($masterServer->{gameLogin_packet}) == 0x0273) {
		my ($serv) = $masterServer->{ip} =~ /\d+\.\d+\.\d+\.(\d+)/;
		$msg .= pack("x16 C1 x3", $serv);
	}
	$self->sendToServer($msg);
	debug "Sent sendGameLogin\n", "sendPacket", 2;
}

sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x93, 0x01) . $ID;
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x94, 0x00) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetStoreList {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xC5, 0x00) . $ID . pack("C*",0x00);
	$self->sendToServer($msg);
	debug "Sent get store list: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetSellList {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xC5, 0x00) . $ID . pack("C*",0x01);
	$self->sendToServer($msg);
	debug "Sent sell to NPC: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGmSummon {
	my ($self, $playerName) = @_;
	my $packet = pack("C*", 0xBD, 0x01) . pack("a24", stringToBytes($playerName));
	$self->sendToServer($packet);
}

sub sendGuildAlly {
	my ($self, $ID, $flag) = @_;
	my $msg = pack("C*", 0x72, 0x01).$ID.pack("V1", $flag);
	$self->sendToServer($msg);
	debug "Sent Ally Guild : ".getHex($ID).", $flag\n", "sendPacket", 2;
}

sub sendGuildBreak {
	my ($self, $guildName) = @_;
	my $msg = pack("C C a40", 0x5D, 0x01, stringToBytes($guildName));
	$self->sendToServer($msg);
	debug "Sent Guild Break: $guildName\n", "sendPacket", 2;
}

sub sendGuildChat {
	my ($self, $message) = @_;

	my ($charName);
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");
	$message = stringToBytes($message);
	$charName = stringToBytes($char->{name});

	my $data = pack("C*",0x7E, 0x01) .
		pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
	$self->sendToServer($data);
}

sub sendGuildCreate {
	my ($self, $name) = @_;
	my $msg = pack("C*", 0x65, 0x01, 0x4D, 0x8B, 0x01, 0x00) .
		pack("a24", stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Guild Create: $name\n", "sendPacket", 2;
}

sub sendGuildInfoRequest {
	my $self = shift;
	my $msg = pack("C*", 0x4d, 0x01);
	$self->sendToServer($msg);
	debug "Sent Guild Information Request\n", "sendPacket";
}

sub sendGuildJoin {
	my ($self, $ID, $flag) = @_;
	my $msg = pack("C*", 0x6B, 0x01).$ID.pack("V1", $flag);
	$self->sendToServer($msg);
	debug "Sent Join Guild : ".getHex($ID).", $flag\n", "sendPacket";
}

sub sendGuildJoinRequest {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x68, 0x01).$ID.$accountID.$charID;
	$self->sendToServer($msg);
	debug "Sent Request Join Guild: ".getHex($ID)."\n", "sendPacket";
}

sub sendGuildLeave {
	my ($self, $reason) = @_;
	my $mess = pack("Z40", stringToBytes($reason));
	my $msg = pack("C*", 0x59, 0x01).$guild{ID}.$accountID.$charID.$mess;
	$self->sendToServer($msg);
	debug "Sent Guild Leave: $reason (".getHex($msg).")\n", "sendPacket";
}

sub sendGuildMemberKick {
	my ($self, $guildID, $accountID, $charID, $cause) = @_;
	my $msg = pack("C*", 0x5B, 0x01).$guildID.$accountID.$charID.pack("a40", stringToBytes($cause));
	$self->sendToServer($msg);
	debug "Sent Guild Kick: ".getHex($charID)."\n", "sendPacket";
}

sub sendGuildMemberTitleSelect {
	# set the title for a member
	my ($self, $accountID, $charID, $index) = @_;

	my $msg = pack("C*", 0x55, 0x01).pack("v1",16).$accountID.$charID.pack("V1",$index);
	$self->sendToServer($msg);
	debug "Sent Change Guild title: ".getHex($charID)." $index\n", "sendPacket", 2;
}

sub sendGuildNotice {
	# sets the notice/announcement for the guild
	my ($self, $guildID, $name, $notice) = @_;
	my $msg = pack("C*", 0x6E, 0x01) . $guildID .
		pack("a60 a120", stringToBytes($name), stringToBytes($notice));
	$self->sendToServer($msg);
	debug "Sent Change Guild Notice: $notice\n", "sendPacket", 2;
}

sub sendGuildRankChange {
	# change the title for a certain index
	# i would  guess 0 is the top rank, but i dont know
	my ($self, $index, $permissions, $tax, $title) = @_;

	my $msg = pack("C*", 0x61, 0x01) .
		pack("v1", 44) . # packet length, we can actually send multiple titles in the same packet if we wanted to
		pack("V1", $index) . # index of this rank in the list
		pack("V1", $permissions) . # this is their abilities, not sure what format
		pack("V1", $index) . # isnt even used on emulators, but leave in case Aegis wants this
		pack("V1", $tax) . # guild tax amount, not sure what format
		pack("a24", $title);
	$self->sendToServer($msg);
	debug "Sent Set Guild title: $index $title\n", "sendPacket", 2;
}

sub sendGuildRequest {
	my ($self, $page) = @_;
	my $msg = pack("C*", 0x4f, 0x01).pack("V1", $page);
	$self->sendToServer($msg);
	debug "Sent Guild Request Page : ".$page."\n", "sendPacket";
}

sub sendGuildSetAlly {
	# this packet is for guildmaster asking to set alliance with another guildmaster
	# the other sub for sendGuildAlly are responses to this sub
	# kept the parameters open, but everything except $targetAID could be replaced with Global variables
	# unless you plan to mess around with the alliance packet, no exploits though, I tried ;-)
	# -zdivpsa
	my ($self, $targetAID, $myAID, $charID) = @_;	# remote socket, $net
	my $msg =	pack("C*", 0x70, 0x01) .
			$targetAID .
			$myAID .
			$charID;
	$self->sendToServer($msg);

}

sub sendHomunculusFeed {
	my $self = shift;
	my $msg = pack("C*", 0x2D, 0x02, 0x00, 0x00, 0x01);
	$self->sendToServer($msg);
	debug "Sent Feed Homunculus\n", "sendPacket", 2;
}

sub sendHomunculusGetStats {
	my $self = shift;
	my $msg = pack("C*", 0x2D, 0x02, 0x00, 0x00, 0x00);
	$self->sendToServer($msg);
	debug "Sent Get Homunculus Stats\n", "sendPacket", 2;
}

sub sendHomunculusMove {
	my $self = shift;
	my $homunID = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C*", 0x32, 0x02) . $homunID . getCoordString($x, $y);
	$self->sendToServer($msg);
	debug "Sent Homunculus move to: $x, $y\n", "sendPacket", 2;
}

sub sendHomunculusAttack {
	my $self = shift;
	my $homunID = shift;
	my $targetID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x33, 0x02) . $homunID . $targetID . pack("C1", $flag);
	$self->sendToServer($msg);
	debug "Sent Homunculus attack: ".getHex($targetID)."\n", "sendPacket", 2;
}

sub sendHomunculusStandBy {
	my $self = shift;
	my $homunID = shift;
	my $msg = pack("C*", 0x34, 0x02) . $homunID;
	$self->sendToServer($msg);
	debug "Sent Homunculus standby\n", "sendPacket", 2;
}

sub sendIdentify {
	my $self = shift;
	my $index = shift;
	my $msg = pack("C*", 0x78, 0x01) . pack("v*", $index);
	$self->sendToServer($msg);
	debug "Sent Identify: $index\n", "sendPacket", 2;
}

sub sendIgnore {
	my $self = shift;
	my $name = shift;
	my $flag = shift;

	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName = $binName . chr(0) x (24 - length($binName));
	my $msg = pack("C*", 0xCF, 0x00) . $binName . pack("C*", $flag);

	$self->sendToServer($msg);
	debug "Sent Ignore: $name, $flag\n", "sendPacket", 2;
}

sub sendIgnoreAll {
	my $self = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xD0, 0x00).pack("C*", $flag);
	$self->sendToServer($msg);
	debug "Sent Ignore All: $flag\n", "sendPacket", 2;
}

sub sendIgnoreListGet {
	my $self = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xD3, 0x00);
	$self->sendToServer($msg);
	debug "Sent get Ignore List: $flag\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA7, 0x00).pack("v*",$ID) .
		$targetID;

	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
	$msg = pack("C*", 0x9B, 0x00, $head, 0x00, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLoaded {
	my $self = shift;
	my $msg;
	$syncSync = pack("V", getTickCount());
	$msg = pack("C*", 0x7D,0x00);
	debug "Sending Map Loaded\n", "sendPacket";
	$self->sendToServer($msg);
	Plugins::callHook('packet/sendMapLoaded');
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	if ($self->{serverType} == 0) {
		$msg = pack("C*", 0x72,0) .
			$accountID .
			$charID .
			$sessionID .
			pack("V1", getTickCount()) .
			pack("C*",$sex);

	} else { #oRO and pRO and idRO
		my $key;

		$key = pack("C*", 0xFA, 0x12, 0, 0x50, 0x83);
		$msg = pack("C*", 0x72, 0, 0, 0, 0) .
			$accountID .
			$key .
			$charID .
			pack("C*", 0xFF, 0xFF) .
			$sessionID .
			pack("V", getTickCount()) .
			pack("C", $sex);
	}

	$self->sendToServer($msg);
}

sub sendMasterCodeRequest {
	my $self = shift;
	my $type = shift;
	my $code = shift;
	my $msg;

	if ($type eq 'code') {
		$msg = '';
		foreach (split(/ /, $code)) {
			$msg .= pack("C1",hex($_));
		}

	} else { # type eq 'type'
		if ($code == 1) {
			$msg = pack("C*", 0x04, 0x02, 0x7B, 0x8A, 0xA8, 0x90, 0x2F, 0xD8, 0xE8, 0x30, 0xF8, 0xA5, 0x25, 0x7A, 0x0D, 0x3B, 0xCE, 0x52);
		} elsif ($code == 2) {
			$msg = pack("C*", 0x04, 0x02, 0x27, 0x6A, 0x2C, 0xCE, 0xAF, 0x88, 0x01, 0x87, 0xCB, 0xB1, 0xFC, 0xD5, 0x90, 0xC4, 0xED, 0xD2);
		} elsif ($code == 3) {
			$msg = pack("C*", 0x04, 0x02, 0x42, 0x00, 0xB0, 0xCA, 0x10, 0x49, 0x3D, 0x89, 0x49, 0x42, 0x82, 0x57, 0xB1, 0x68, 0x5B, 0x85);
		} elsif ($code == 4) {
			$msg = pack("C*", 0x04, 0x02, 0x22, 0x37, 0xD7, 0xFC, 0x8E, 0x9B, 0x05, 0x79, 0x60, 0xAE, 0x02, 0x33, 0x6D, 0x0D, 0x82, 0xC6);
		} elsif ($code == 5) {
			$msg = pack("C*", 0x04, 0x02, 0xc7, 0x0A, 0x94, 0xC2, 0x7A, 0xCC, 0x38, 0x9A, 0x47, 0xF5, 0x54, 0x39, 0x7C, 0xA4, 0xD0, 0x39);
		}
	}
	$msg .= pack("C*", 0xDB, 0x01);
	$self->sendToServer($msg);
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;

	if ($self->{serverType} == 4) {
		# This is used on the RuRO private server.
		# A lot of packets are different so I gave up,
		# but I'll keep this code around in case anyone ever needs it.

		# I'm not sure if serverType 4 actually needs this whacko login

		$username = substr($username, 0, 23) if (length($username) > 23);
		$password = substr($password, 0, 23) if (length($password) > 23);

		my $tmp = pack("C*", 0x0D, 0xF0, 0xAD, 0xBA) x 6;
		substr($tmp, 0, length($username) + 1, $username . chr(0));
		$username = $tmp;

		$tmp = (pack("C*", 0x0D, 0xF0, 0xAD, 0xBA) x 3) .
			pack("C*", 0x00, 0xD0, 0xC2, 0xCF, 0xA2, 0xF9, 0xCA, 0xDF, 0x0E, 0xA6, 0xF1, 0x41);
		substr($tmp, 0, length($password) + 1, $password . chr(0));
		$password = $tmp;

		$msg = pack("v1 V", hex($masterServer->{masterLogin_packet}) || 0x64, $version) .
			$username . $password .
			pack("C*", $master_version);

	} else {
		$msg = pack("v1 V", hex($masterServer->{masterLogin_packet}) || 0x64, $version) .
			pack("a24", $username) .
			pack("a24", $password) .
			pack("C*", $master_version);
	}
	$self->sendToServer($msg);
}

sub sendMasterSecureLogin {
	my $self = shift;
	my $username = shift;
	my $password = shift;
	my $salt = shift;
	my $version = shift;
	my $master_version = shift;
	my $type =  shift;
	my $account = shift;
	my $md5 = Digest::MD5->new;
	my ($msg);

	$username = stringToBytes($username);
	$password = stringToBytes($password);
	if ($type % 2 == 1) {
		$salt = $salt . $password;
	} else {
		$salt = $password . $salt;
	}
	$md5->add($salt);
	if ($type < 3 ) {
		$msg = pack("C*", 0xDD, 0x01) . pack("V1", $version) . pack("a24", $username) .
					 $md5->digest . pack("C*", $master_version);
	}else{
		$account = ($account>0) ? $account -1 : 0;
		$msg = pack("C*", 0xFA, 0x01) . pack("V1", $version) . pack("a24", $username) .
					 $md5->digest . pack("C*", $master_version). pack("C1", $account);
	}
	$self->sendToServer($msg);
}

sub sendMemo {
	my $self = shift;
	my $msg = pack("C*", 0x1D, 0x01);
	$self->sendToServer($msg);
	debug "Sent Memo\n", "sendPacket", 2;
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg;

	$msg = pack("C*", 0x85, 0x00) . getCoordString($x, $y);

	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendOpenShop {
	my ($self, $title, $items) = @_;

	my $length = 0x55 + 0x08 * @{$items};
	my $msg = pack("C*", 0xB2, 0x01).
		pack("v*", $length).
		pack("a80", stringToBytes($title)).
		pack("C*", 0x01);

	foreach my $item (@{$items}) {
		$msg .= pack("v1", $item->{index}).
			pack("v1", $item->{amount}).
			pack("V1", $item->{price});
	}

	$self->sendToServer($msg);
}

sub sendOpenWarp {
	my ($self, $map) = @_;
	my $msg = pack("C*", 0x1b, 0x01, 0x1b, 0x00) . $map .
		chr(0) x (16 - length($map));
	$self->sendToServer($msg);
}

sub sendPartyChat {
	my $self = shift;
	my $message = shift;

	my $charName;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");
	$message = stringToBytes($message);
	$charName = stringToBytes($char->{name});

	my $msg = pack("C*",0x08, 0x01) . pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
	$self->sendToServer($msg);
}

sub sendPartyJoin {
	my $self = shift;
	my $ID = shift;
	my $flag = shift;
	my $msg = pack("C*", 0xFF, 0x00).$ID.pack("V", $flag);
	$self->sendToServer($msg);
	debug "Sent Join Party: ".getHex($ID).", $flag\n", "sendPacket", 2;
}

sub sendPartyJoinRequest {
	my $self = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xFC, 0x00).$ID;
	$self->sendToServer($msg);
	debug "Sent Request Join Party: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendPartyKick {
	my $self = shift;
	my $ID = shift;
	my $name = shift;

	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName .= chr(0) x (24 - length($binName));
	my $msg = pack("C*", 0x03, 0x01) . $ID . $binName;
	$self->sendToServer($msg);
	debug "Sent Kick Party: ".getHex($ID).", $name\n", "sendPacket", 2;
}

sub sendPartyLeave {
	my $self = shift;
	my $msg = pack("C*", 0x00, 0x01);
	$self->sendToServer($msg);
	debug "Sent Leave Party\n", "sendPacket", 2;
}

sub sendPartyOrganize {
	my $self = shift;
	my $name = shift;
	my $share1 = shift || 1;
	my $share2 = shift || 1;

	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName .= chr(0) x (24 - length($binName));
	#my $msg = pack("C*", 0xF9, 0x00) . $binName;
	# I think this is obsolete - which serverTypes still support this packet anyway?
	# FIXME: what are shared with $share1 and $share2? experience? item? vice-versa?
	
	my $msg = pack("C*", 0xE8, 0x01) . $binName . pack("C*", $share1, $share2);

	$self->sendToServer($msg);
	debug "Sent Organize Party: $name\n", "sendPacket", 2;
}

sub sendPartyShareEXP {
	my $self = shift;
	my $flag = shift;
	my $msg = pack("C*", 0x02, 0x01).pack("V", $flag);
	$self->sendToServer($msg);
	debug "Sent Party Share: $flag\n", "sendPacket", 2;
}

sub sendPetCapture {
	my $self = shift;
	my $monID = shift;
	my $msg = pack("C*", 0x9F, 0x01) . $monID . pack("C*", 0x00, 0x00);
	$self->sendToServer($msg);
	debug "Sent pet capture: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendPetFeed {
	my $self = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x01);
	$self->sendToServer($msg);
	debug "Sent Pet Feed\n", "sendPacket", 2;
}

sub sendPetGetInfo {
	my $self = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x00);
	$self->sendToServer($msg);
	debug "Sent Pet Get Info\n", "sendPacket", 2;
}

sub sendPetHatch {
	my $self = shift;
	my $index = shift;
	my $msg = pack("C*", 0xA7, 0x01) . pack("v1", $index);
	$self->sendToServer($msg);
	debug "Sent Incubator hatch: $index\n", "sendPacket", 2;
}

sub sendPetName {
	my $self = shift;
	my $name = shift;
	my $msg = pack("C1 C1 a24", 0xA5, 0x01, stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Pet Rename: $name\n", "sendPacket", 2;
}

sub sendPetPerformance {
	my $self = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x02);
	$self->sendToServer($msg);
	debug "Sent Pet Performance\n", "sendPacket", 2;
}

sub sendPetReturnToEgg {
	my $self = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x03);
	$self->sendToServer($msg);
	debug "Sent Pet Return to Egg\n", "sendPacket", 2;
}

sub sendPetUnequipItem {
	my $self = shift;
	my $msg = pack("C*", 0xA1, 0x01, 0x04);
	$self->sendToServer($msg);
	debug "Sent Pet Unequip Item\n", "sendPacket", 2;
}

sub sendPreLoginCode {
	# no server actually needs this, but we might need it in the future?
	my $self = shift;
	my $type = shift;
	my $msg;
	if ($type == 1) {
		$msg = pack("C*", 0x04, 0x02, 0x82, 0xD1, 0x2C, 0x91, 0x4F, 0x5A, 0xD4, 0x8F, 0xD9, 0x6F, 0xCF, 0x7E, 0xF4, 0xCC, 0x49, 0x2D);
	}
	$self->sendToServer($msg);
	debug "Sent pre-login packet $type\n", "sendPacket", 2;
}

sub sendPrivateMsg {
	my ($self, $user, $message) = @_;

	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");
	$message = stringToBytes($message);
	$user = stringToBytes($user);

	my $msg = pack("C*", 0x96, 0x00) . pack("v*", length($message) + 29) . $user .
		chr(0) x (24 - length($user)) . $message . chr(0);
	$self->sendToServer($msg);
}

sub sendQuit {
	my $self = shift;
	my $msg = pack("C*", 0x8A, 0x01, 0x00, 0x00);
	$self->sendToServer($msg);
	debug "Sent Quit\n", "sendPacket", 2;
}

sub sendQuitToCharSelect {
	my $msg = pack("C*", 0xB2, 0x00, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent Quit To Char Selection\n", "sendPacket", 2;
}

sub sendRaw {
	my $self = shift;
	my $raw = shift;
	my @raw;
	my $msg;
	@raw = split / /, $raw;
	foreach (@raw) {
		$msg .= pack("C", hex($_));
	}
	$self->sendToServer($msg);
	debug "Sent Raw Packet: @raw\n", "sendPacket", 2;
}

sub sendRemoveAttachments {
	# remove peco, falcon, cart
	my $msg = pack("C*", 0x2A, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent remove attachments\n", "sendPacket", 2;
}

sub sendRepairItem {
	my $self = shift;
	my $index = shift;
	my $msg = pack("C*", 0xFD, 0x01) . pack("v1", $index);
	$self->sendToServer($msg);
	debug "Sent repair item: $index\n", "sendPacket", 2;
}

sub sendRespawn {
	my $self = shift;
	my $msg = pack("C*", 0xB2, 0x00, 0x00);
	$self->sendToServer($msg);
	debug "Sent Respawn\n", "sendPacket", 2;
}

sub sendSell {
	my $self = shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xC9, 0x00, 0x08, 0x00) . pack("v*", $index, $amount);
	$self->sendToServer($msg);
	debug "Sent sell: $index x $amount\n", "sendPacket", 2;
}

sub sendSellBulk {
	my $self = shift;
	my $r_array = shift;
	my $sellMsg = "";

	for (my $i = 0; $i < @{$r_array}; $i++) {
		$sellMsg .= pack("v*", $r_array->[$i]{index}, $r_array->[$i]{amount});
		debug "Sent bulk sell: $r_array->[$i]{index} x $r_array->[$i]{amount}\n", "d_sendPacket", 2;
	}

	my $msg = pack("C*", 0xC9, 0x00) . pack("v*", length($sellMsg) + 4) . $sellMsg;
	$self->sendToServer($msg);
}

sub sendSit {
	my $self = shift;
	my $msg;

	$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02);

	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;

	$msg = pack("C*", 0x13, 0x01).pack("v*",$lv,$ID).$targetID;

	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;

	$msg = pack("C*", 0x16, 0x01).pack("v*",$lv,$ID,$x,$y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xF3, 0x00) . pack("v*", $index) . pack("V*", $amount);

	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageAddFromCart {
	my $self = shift;
	my $index = shift;
	my $amount = shift;
	my $msg;
	$msg = pack("C*", 0x29, 0x01) . pack("v*", $index) . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add From Cart: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageClose {
	my ($self) = @_;
	my $msg;
	if (($self->{serverType} == 3) || ($self->{serverType} == 5) || ($self->{serverType} == 9) || ($self->{serverType} == 15)) {
		$msg = pack("C*", 0x93, 0x01);
	} elsif ($self->{serverType} == 12) {
		$msg = pack("C*", 0x72, 0x00);
	} elsif ($self->{serverType} == 14) {
		$msg = pack("C*", 0x16, 0x01);
	} else {
		$msg = pack("C*", 0xF7, 0x00);
	}

	$self->sendToServer($msg);
	debug "Sent Storage Done\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xF5, 0x00) . pack("v*", $index) . pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGetToCart {
	my $self = shift;
	my $index = shift;
	my $amount = shift;
	my $msg;
	$msg = pack("C*", 0x28, 0x01) . pack("v*", $index) . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get From Cart: $index x $amount\n", "sendPacket", 2;
}

sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	if ($type == 3) {
		$msg = pack("C C v", 0x3B, 0x02, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("C C v", 0x3B, 0x02, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
}

sub sendStand {
	my $self = shift;
	my $msg;

	$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03);

	$self->sendToServer($msg);
	debug "Standing\n", "sendPacket", 2;
}

sub sendSuperNoviceDoriDori {
	my $msg = pack("C*", 0xE7, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent Super Novice dori dori\n", "sendPacket", 2;
}

sub sendSuperNoviceExplosion {
	my $msg = pack("C*", 0xED, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent Super Novice Explosion\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);
	
	$syncSync = pack("V", getTickCount());
	$msg = pack("C*", 0x7E, 0x00) . $syncSync;

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0x9F, 0x00) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

sub sendTalk {
	my $self = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x90, 0x00) . $ID . pack("C*",0x01);
	$self->sendToServer($msg);
	debug "Sent talk: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkCancel {
	my $self = shift;
	my $ID = shift;
	my $msg = pack("C*", 0x46, 0x01) . $ID;
	$self->sendToServer($msg);
	debug "Sent talk cancel: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkContinue {
	my $self = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xB9, 0x00) . $ID;
	$self->sendToServer($msg);
	debug "Sent talk continue: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkResponse {
	my $self = shift;
	my $ID = shift;
	my $response = shift;
	my $msg = pack("C*", 0xB8, 0x00) . $ID. pack("C1",$response);
	$self->sendToServer($msg);
	debug "Sent talk respond: ".getHex($ID).", $response\n", "sendPacket", 2;
}

sub sendTalkNumber {
	my $self = shift;
	my $ID = shift;
	my $number = shift;
	my $msg = pack("C*", 0x43, 0x01) . $ID .
			pack("V1", $number);
	$self->sendToServer($msg);
	debug "Sent talk number: ".getHex($ID).", $number\n", "sendPacket", 2;
}

sub sendTalkText {
	my $self = shift;
	my $ID = shift;
	my $input = stringToBytes(shift);
	my $msg = pack("C*", 0xD5, 0x01) . pack("v*", length($input)+length($ID)+5) . $ID . $input . chr(0);
	$self->sendToServer($msg);
	debug "Sent talk text: ".getHex($ID).", $input\n", "sendPacket", 2;
}

sub sendTeleport {
	my $self = shift;
	my $location = shift;
	$location = substr($location, 0, 16) if (length($location) > 16);
	$location .= chr(0) x (16 - length($location));
	my $msg = pack("C*", 0x1B, 0x01, 0x1A, 0x00) . $location;
	$self->sendToServer($msg);
	debug "Sent Teleport: $location\n", "sendPacket", 2;
}

sub sendTop10Alchemist {
	my $self = shift;
	my $msg = pack("C*", 0x18, 0x02);
	$self->sendToServer($msg);
	debug "Sent Top 10 Alchemist request\n", "sendPacket", 2;
}

sub sendTop10Blacksmith {
	my $self = shift;
	my $msg = pack("C*", 0x17, 0x02);
	$self->sendToServer($msg);
	debug "Sent Top 10 Blacksmith request\n", "sendPacket", 2;
}	

sub sendTop10PK {
	my $self = shift;
	my $msg = pack("C*", 0x37, 0x02);
	$self->sendToServer($msg);
	debug "Sent Top 10 PK request\n", "sendPacket", 2;	
}

sub sendTop10Taekwon {
	my $self = shift;
	my $msg = pack("C*", 0x25, 0x02);
	$self->sendToServer($msg);
	debug "Sent Top 10 Taekwon request\n", "sendPacket", 2;
}

sub sendUnequip {
	my $self = shift;
	my $index = shift;
	my $msg = pack("C*", 0xAB, 0x00) . pack("v*", $index);
	$self->sendToServer($msg);
	debug "Sent Unequip: $index\n", "sendPacket", 2;
}

sub sendWho {
	my $self = shift;
	my $msg = pack("C*", 0xC1, 0x00);
	$self->sendToServer($msg);
	debug "Sent Who\n", "sendPacket", 2;
}

1;
