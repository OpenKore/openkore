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
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::ServerType0;

use strict;
use Time::HiRes qw(time);

use Misc qw(stripLanguageCode);
use Network::Send ();
use base qw(Network::Send);
use Plugins;
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync);
use Log qw(debug);
use Translation qw(T TF);
use I18N qw(bytesToString stringToBytes);
use Utils;
use Utils::Exceptions;
use Utils::Rijndael;

# to test zealotus bug
#use Data::Dumper;


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]],
		'0065' => ['game_login', 'a4 a4 a4 v C', [qw(accountID sessionID sessionID2 userLevel accountSex)]],
		'0066' => ['char_login', 'C', [qw(slot)]],
		'0067' => ['char_create'], # TODO
		'0068' => ['char_delete'], # TODO
		'0072' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'007D' => ['map_loaded'], # len 2
		'007E' => ['sync', 'V', [qw(time)]],
		'0085' => ['character_move', 'a3', [qw(coords)]],
		'0089' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'008C' => ['public_chat', 'x2 Z*', [qw(message)]],
		'0090' => ['npc_talk', 'a4 C', [qw(ID type)]],
		'0094' => ['actor_info_request', 'a4', [qw(ID)]],
		'0096' => ['private_message', 'x2 Z24 Z*', [qw(privMsgUser privMsg)]],
		'009B' => ['actor_look_at', 'v C', [qw(head body)]],
		'009F' => ['item_take', 'a4', [qw(ID)]],
		'00A2' => ['item_drop', 'v2', [qw(index amount)]],
		'00A9' => ['send_equip', 'v2', [qw(index type)]],#6
		'00B2' => ['restart', 'C', [qw(type)]],
		'00B8' => ['npc_talk_response', 'a4 C', [qw(ID response)]],
		'00B9' => ['npc_talk_continue', 'a4', [qw(ID)]],
		#'00F3' => ['map_login', '', [qw()]],
		'00F3' => ['storage_item_add', 'v V', [qw(index amount)]],
		'00F5' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0102' => ['party_setting', 'V', [qw(exp)]],
		'0108' => ['party_chat', 'x2 Z*', [qw(message)]],
		'0113' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0116' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0134' => ['buy_bulk_vender', 'x2 a4 a*', [qw(venderID itemInfo)]],
		'0143' => ['npc_talk_number', 'a4 V', [qw(ID value)]],
		'0146' => ['npc_talk_cancel', 'a4', [qw(ID)]],
		'0149' => ['alignment', 'a4 C v', [qw(targetID type point)]],
		'014D' => ['guild_check'], # len 2
		'014F' => ['guild_info_request', 'V', [qw(type)]],
		'0151' => ['guild_emblem_request', 'a4', [qw(guildID)]],
		'017E' => ['guild_chat', 'x2 Z*', [qw(message)]],
		'0187' => ['ban_check', 'a4', [qw(accountID)]],
		'018A' => ['quit_request', 'v', [qw(type)]],
		'0193' => ['actor_name_request', 'a4', [qw(ID)]],
		'01B2' => ['shop_open'], # TODO
		'012E' => ['shop_close'], # len 2
		'01D5' => ['npc_talk_text', 'v a4 Z*', [qw(len ID text)]],
		'01DB' => ['secure_login_key_request'], # len 2
		'01DD' => ['master_login', 'V Z24 a16 C', [qw(version username password_salted_md5 master_version)]],
		'01FA' => ['master_login', 'V Z24 a16 C C', [qw(version username password_salted_md5 master_version clientInfo)]],
		'0202' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0204' => ['client_hash', 'a16', [qw(hash)]],
		'0208' => ['friend_response', 'a4 a4 V', [qw(friendAccountID friendCharID type)]],
		'021D' => ['less_effect'], # TODO
		'022D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0232' => ['actor_move', 'a4 a3', [qw(ID coords)]], # should be called slave_move...
		'0233' => ['slave_attack', 'a4 a4 C', [qw(slaveID targetID flag)]],
		'0234' => ['slave_move_to_master', 'a4', [qw(slaveID)]],
		'023B' => ['storage_password'],
		'0275' => ['game_login', 'a4 a4 a4 v C x16 v', [qw(accountID sessionID sessionID2 userLevel accountSex iAccountSID)]],
		'02B0' => ['master_login', 'V Z24 a24 C Z16 Z14 C', [qw(version username password_rijndael master_version ip mac isGravityID)]],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'02D6' => ['view_player_equip_request', 'a4', [qw(ID)]],
		'02D8' => ['equip_window_tick', 'V2', [qw(type value)]],
		'035F' => ['character_move', 'a3', [qw(coords)]],
		'0360' => ['sync', 'V', [qw(time)]],
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['item_take', 'a4', [qw(ID)]],
		'0363' => ['item_drop', 'v2', [qw(index amount)]],
		'0364' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0365' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0368' => ['actor_info_request', 'a4', [qw(ID)]],
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],
		'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0437' => ['character_move','a3', [qw(coords)]],
		'0443' => ['skill_select', 'V v', [qw(why skillID)]],
		'07D7' => ['party_setting', 'V C2', [qw(exp itemPickup itemDivision)]],
		'0801' => ['buy_bulk_vender', 'x2 a4 a4 a*', [qw(venderID venderCID itemInfo)]], #Selling store
		'0802' => ['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]],
		'0804' => ['booking_search', 'v3 V s', [qw(level MapID job LastIndex ResultCount)]],
		'0806' => ['booking_delete'],
		'0808' => ['booking_update', 'v6', [qw(job0 job1 job2 job3 job4 job5)]],
		'0811' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0815' => ['buy_bulk_closeShop'],
		'0817' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0819' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0827' => ['char_delete2', 'a4', [qw(charID)]], # 6
		'0829' => ['char_delete2_accept', 'a4 a6', [qw(charID code)]], # 12
		'082B' => ['char_delete2_cancel', 'a4', [qw(charID)]], # 6
		'0844' => ['cash_shop_open'],#2
		'0848' => ['cash_shop_buy_items', 's s V V s', [qw(len count item_id item_amount tab_code)]], #item_id, item_amount and tab_code could be repeated in order to buy multiple itens at once
		'084A' => ['cash_shop_close'],#2
		'08B8' => ['send_pin_password','a4 Z*', [qw(accountID pin)]],
		'08BA' => ['new_pin_password','a4 Z*', [qw(accountID pin)]],
		'08C9' => ['request_cashitems'],#2
		'0987' => ['master_login', 'V Z24 a32 C', [qw(version username password_md5_hex master_version)]],
		'0998' => ['send_equip', 'v V', [qw(index type)]],#8
		'09A1' => ['sync_received_characters'],
		'09D0' => ['gameguard_reply'],
		#'08BE' => ['change_pin_password','a*', [qw(accountID oldPin newPin)]], # TODO: PIN change system/command?
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	# # it would automatically use the first available if not set
	# my %handlers = qw(
	# 	master_login 0064
	# 	game_login 0065
	# 	map_login 0072
	# 	character_move 0085
	# 	buy_bulk_vender 0134
	# );
	# $self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub version {
	return $masterServer->{version} || 1;
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
	$self->sendToServer($self->reconstruct({
		switch => 'alignment',
		targetID => $ID,
		type => $alignment,
	}));
	debug "Sent Alignment: ".getHex($ID).", $alignment\n", "sendPacket", 2;
}

sub sendArrowCraft {
	my ($self, $index) = @_;
	my $msg = pack("C*", 0xAE, 0x01) . pack("v*", $index);
	$self->sendToServer($msg);
	debug "Sent Arrowmake: $index\n", "sendPacket", 2;
}

# 0x0089,7,actionrequest,2:6

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
	$self->sendToServer($self->reconstruct({
		switch => 'ban_check',
		accountID => $ID,
	}));
	debug "Sent Account Ban Check Request : " . getHex($ID) . "\n", "sendPacket", 2;
}

=pod
sub sendBuy {
	my ($self, $ID, $amount) = @_;
	my $msg = pack("C*", 0xC8, 0x00, 0x08, 0x00) . pack("v*", $amount, $ID);
	$self->sendToServer($msg);
	debug "Sent buy: ".getHex($ID)."\n", "sendPacket", 2;
}
=cut
# 0x00c8,-1,npcbuylistsend,2:4
sub sendBuyBulk {
	my ($self, $r_array) = @_;
	my $msg = pack('v2', 0x00C8, 4+4*@{$r_array});
	for (my $i = 0; $i < @{$r_array}; $i++) {
		$msg .= pack('v2', $r_array->[$i]{amount}, $r_array->[$i]{itemID});
		debug "Sent bulk buy: $r_array->[$i]{itemID} x $r_array->[$i]{amount}\n", "d_sendPacket", 2;
	}
	$self->sendToServer($msg);
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
		pack("v*", $hair_color, $hair_style);
	$self->sendToServer($msg);
}

sub sendCharDelete {
	my ($self, $charID, $email) = @_;
	my $msg = pack("C*", 0x68, 0x00) .
			$charID . pack("a40", stringToBytes($email));
	$self->sendToServer($msg);
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

sub sendDealReply {
	#Reply to a trade-request.
	# Type values:
	# 0: Char is too far
	# 1: Character does not exist
	# 2: Trade failed
	# 3: Accept
	# 4: Cancel
	# Weird enough, the client should only send 3/4
	# and the server is the one that can reply 0~2
	my ($self, $action) = @_;
	my $msg = pack('v C', 0x00E6, $action);
	$_[0]->sendToServer($msg);
	debug "Sent " . ($action == 3 ? "Accept": ($action == 4 ? "Cancel" : "action: " . $action)) . " Deal\n", "sendPacket", 2;
}

# TODO: legacy plugin support, remove later
sub sendDealAccept {
	$_[0]->sendDealReply(3);
	debug "Sent Cancel Deal\n", "sendPacket", 2;
}

# TODO: legacy plugin support, remove later
sub sendDealCancel {
	$_[0]->sendDealReply(4);
	debug "Sent Cancel Deal\n", "sendPacket", 2;
}

sub sendDealAddItem {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0xE8, 0x00) . pack("v*", $index) . pack("V*",$amount);
	$_[0]->sendToServer($msg);
	debug "Sent Deal Add Item: $index, $amount\n", "sendPacket", 2;
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

# 0x0208,11,friendslistreply,2:6:10
# Reject:0/Accept:1

sub sendFriendRemove {
	my ($self, $accountID, $charID) = @_;
	my $msg = pack("C*", 0x03, 0x02) . $accountID . $charID;
	$self->sendToServer($msg);
	debug "Sent Remove a friend\n", "sendPacket";
}

=pod
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x93, 0x01) . $ID;
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}
=cut

sub sendNPCBuySellList { # type:0 get store list, type:1 get sell list
	my ($self, $ID, $type) = @_;
	my $msg = pack('v a4 C', 0x00C5, $ID , $type);
	$self->sendToServer($msg);
	debug "Sent get ".($type ? "buy" : "sell")." list to NPC: ".getHex($ID)."\n", "sendPacket", 2;
}

=pod
sub sendGetStoreList {
	my ($self, $ID, $type) = @_;
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
=cut

sub sendGMSummon {
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

sub sendGuildCreate {
	my ($self, $name) = @_;
	# By Default, the second param is our CharID. which indicate the Guild Master Char ID
	my $msg = pack('v a4 a24', 0x0165, $charID, stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Guild Create: $name\n", "sendPacket", 2;
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

=pod
sub sendGuildMemberTitleSelect {
	# set the title for a member
	my ($self, $accountID, $charID, $index) = @_;

	my $msg = pack("C*", 0x55, 0x01).pack("v1",16).$accountID.$charID.pack("V1",$index);
	$self->sendToServer($msg);
	debug "Sent Change Guild title: ".getHex($charID)." $index\n", "sendPacket", 2;
}
=cut
# 0x0155,-1,guildchangememberposition,2
sub sendGuildMemberPositions {
	my ($self, $r_array) = @_;
	my $msg = pack('v2', 0x0155, 4+12*@{$r_array});
	for (my $i = 0; $i < @{$r_array}; $i++) {
		$msg .= pack('a4 a4 V', $r_array->[$i]{accountID}, $r_array->[$i]{charID}, $r_array->[$i]{index});
		debug "Sent GuildChangeMemberPositions: $r_array->[$i]{accountID} $r_array->[$i]{charID} $r_array->[$i]{index}\n", "d_sendPacket", 2;
	}
	$self->sendToServer($msg);
}

sub sendGuildNotice {
	# sets the notice/announcement for the guild
	my ($self, $guildID, $name, $notice) = @_;
	my $msg = pack("C*", 0x6E, 0x01) . $guildID .
		pack("a60 a120", stringToBytes($name), stringToBytes($notice));
	$self->sendToServer($msg);
	debug "Sent Change Guild Notice: $notice\n", "sendPacket", 2;
}

=pod
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
=cut
# 0x0161,-1,guildchangepositioninfo,2
sub sendGuildPositionInfo {
	my ($self, $r_array) = @_;
	my $msg = pack('v2', 0x0161, 4+44*@{$r_array});
	for (my $i = 0; $i < @{$r_array}; $i++) {
		$msg .= pack('v2 V4 a24', $r_array->[$i]{index}, $r_array->[$i]{permissions}, $r_array->[$i]{index}, $r_array->[$i]{tax}, stringToBytes($r_array->[$i]{title}));
		debug "Sent GuildPositionInfo: $r_array->[$i]{index}, $r_array->[$i]{permissions}, $r_array->[$i]{index}, $r_array->[$i]{tax}, ".stringToBytes($r_array->[$i]{title})."\n", "d_sendPacket", 2;
	}
	$self->sendToServer($msg);
}

sub sendGuildRequestEmblem {
	my ($self, $guildID) = @_;
	my $msg = pack("v V", 0x0151, $guildID);
	$self->sendToServer($msg);
	debug "Sent Guild Request Emblem.\n", "sendPacket";
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

sub sendHomunculusName {
	my $self = shift;
	my $name = shift;
	my $msg = pack("v1 a24", 0x0231, stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Homunculus Rename: $name\n", "sendPacket", 2;
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
	my $msg = pack("C*", 0xA7, 0x00).pack("v*",$ID) .$targetID;
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendMemo {
	my $self = shift;
	my $msg = pack("C*", 0x1D, 0x01);
	$self->sendToServer($msg);
	debug "Sent Memo\n", "sendPacket", 2;
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

sub _binName {
	my $name = shift;
	
	$name = stringToBytes ($name);
	$name = substr ($name, 0, 24) if 24 < length $name;
	$name .= "\x00" x (24 - length $name);
	return $name;
}

sub sendPartyJoinRequestByNameReply {
	my ($self, $accountID, $flag) = @_;
	my $msg = pack('v a4 C', 0x02C7, $accountID, $flag);
	$self->sendToServer($msg);
	debug "Sent reply Party Invite.\n", "sendPacket", 2;
}

sub sendPartyKick {
	my $self = shift;
	my $ID = shift;
	my $name = shift;
	my $msg = pack("C*", 0x03, 0x01) . $ID . _binName ($name);
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

# legacy plugin support, remove later
sub sendPartyShareEXP {
	my ($self, $exp) = @_;
	$self->sendPartyOption($exp, 0);
}

# 0x0102,6,partychangeoption,2:4
# note: item share changing seems disabled in newest clients
sub sendPartyOption {
	my ($self, $exp, $itemPickup, $itemDivision) = @_;
	
	$self->sendToServer($self->reconstruct({
		switch => 'party_setting',
		exp => $exp,
		itemPickup => $itemPickup,
		itemDivision => $itemDivision,
	}));
	debug "Sent Party Option\n", "sendPacket", 2;
}

sub sendPetCapture {
	my ($self, $monID) = @_;
	my $msg = pack('v a4', 0x019F, $monID);
	$self->sendToServer($msg);
	debug "Sent pet capture: ".getHex($monID)."\n", "sendPacket", 2;
}

# 0x01a1,3,petmenu,2
sub sendPetMenu {
	my ($self, $type) = @_; # 0:info, 1:feed, 2:performance, 3:to egg, 4:uneq item
	my $msg = pack('v C', 0x01A1, $type);
	$self->sendToServer($msg);
	debug "Sent Pet Menu\n", "sendPacket", 2;
}

sub sendPetHatch {
	my ($self, $index) = @_;
	my $msg = pack('v2', 0x01A7, $index);
	$self->sendToServer($msg);
	debug "Sent Incubator hatch: $index\n", "sendPacket", 2;
}

sub sendPetName {
	my ($self, $name) = @_;
	my $msg = pack('v a24', 0x01A5, stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Pet Rename: $name\n", "sendPacket", 2;
}

# 0x01af,4,changecart,2
sub sendChangeCart { # lvl: 1, 2, 3, 4, 5
	my ($self, $lvl) = @_;
	my $msg = pack('v2', 0x01AF, $lvl);
	$self->sendToServer($msg);
	debug "Sent Cart Change to : $lvl\n", "sendPacket", 2;
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

sub sendRequestMakingHomunculus {
	# WARNING: If you don't really know, what are you doing - don't touch this
	my ($self, $make_homun) = @_;
	
	my $skill = new Skill (idn => 241);
	
	if (
		Actor::Item::get (997) && Actor::Item::get (998) && Actor::Item::get (999)
		&& ($char->getSkillLevel ($skill) > 0)
	) {
		my $msg = pack ('v C', 0x01CA, $make_homun);
		$self->sendToServer($msg);
		debug "Sent RequestMakingHomunculus\n", "sendPacket", 2;
	}
}

sub sendRemoveAttachments {
	# remove peco, falcon, cart
	my $msg = pack("C*", 0x2A, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent remove attachments\n", "sendPacket", 2;
}

sub sendRepairItem {
	my ($self, $args) = @_;
	my $msg = pack("C2 v2 V2 C1", 0xFD, 0x01, $args->{index}, $args->{nameID}, $args->{status}, $args->{status2}, $args->{listID});
	$self->sendToServer($msg);
	debug ("Sent repair item: ".$args->{index}."\n", "sendPacket", 2);
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

sub sendStorageGetToCart {
	my $self = shift;
	my $index = shift;
	my $amount = shift;
	my $msg;
	$msg = pack("C*", 0x28, 0x01) . pack("v*", $index) . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get From Cart: $index x $amount\n", "sendPacket", 2;
}

sub sendSuperNoviceDoriDori {
	my $msg = pack("C*", 0xE7, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent Super Novice dori dori\n", "sendPacket", 2;
}

# TODO: is this the sn mental ingame triggered trough the poem?
sub sendSuperNoviceExplosion {
	my $msg = pack("C*", 0xED, 0x01);
	$_[0]->sendToServer($msg);
	debug "Sent Super Novice Explosion\n", "sendPacket", 2;
}

# 0x011b,20,useskillmap,2:4
sub sendWarpTele { # type: 26=tele, 27=warp
	my ($self, $skillID, $map) = @_;
	my $msg = pack('v2 Z16', 0x011B, $skillID, stringToBytes($map));
	$self->sendToServer($msg);
	debug "Sent ". ($skillID == 26 ? "Teleport" : "Open Warp") . "\n", "sendPacket", 2
}
=pod
sub sendTeleport {
	my $self = shift;
	my $location = shift;
	$location = substr($location, 0, 16) if (length($location) > 16);
	$location .= chr(0) x (16 - length($location));
	my $msg = pack("C*", 0x1B, 0x01, 0x1A, 0x00) . $location;
	$self->sendToServer($msg);
	debug "Sent Teleport: $location\n", "sendPacket", 2;
}

sub sendOpenWarp {
	my ($self, $map) = @_;
	my $msg = pack("C*", 0x1b, 0x01, 0x1b, 0x00) . $map .
		chr(0) x (16 - length($map));
	$self->sendToServer($msg);
}
=cut

sub sendTop10Alchemist {
	my $self = shift;
	my $msg = pack("v", 0x0218);
	$self->sendToServer($msg);
	debug "Sent Top 10 Alchemist request\n", "sendPacket", 2;
}

sub sendTop10Blacksmith {
	my $self = shift;
	my $msg = pack("v", 0x0217);
	$self->sendToServer($msg);
	debug "Sent Top 10 Blacksmith request\n", "sendPacket", 2;
}	

sub sendTop10PK {
	my $self = shift;
	my $msg = pack("v", 0x0237);
	$self->sendToServer($msg);
	debug "Sent Top 10 PK request\n", "sendPacket", 2;	
}

sub sendTop10Taekwon {
	my $self = shift;
	my $msg = pack("v", 0x0225);
	$self->sendToServer($msg);
	debug "Sent Top 10 Taekwon request\n", "sendPacket", 2;
}

sub sendUnequip {
	my $self = shift;
	my $index = shift;
	my $msg = pack("v", 0x00AB) . pack("v*", $index);
	$self->sendToServer($msg);
	debug "Sent Unequip: $index\n", "sendPacket", 2;
}

sub sendWho {
	my $self = shift;
	my $msg = pack("v", 0x00C1);
	$self->sendToServer($msg);
	debug "Sent Who\n", "sendPacket", 2;
}

sub SendAdoptReply {
	my ($self, $parentID1, $parentID2, $result) = @_;
	my $msg = pack("v V3", 0x01F7, $parentID1, $parentID2, $result);
	$self->sendToServer($msg);
	debug "Sent Adoption Reply.\n", "sendPacket", 2;
}

sub SendAdoptRequest {
	my ($self, $ID) = @_;
	my $msg = pack("v V", 0x01F9, $ID);
	$self->sendToServer($msg);
	debug "Sent Adoption Request.\n", "sendPacket", 2;
}

# 0x0213 has no info on eA

sub sendMailboxOpen {
	my $self = $_[0];
	my $msg = pack("v", 0x023F);
	$self->sendToServer($msg);
	debug "Sent mailbox open.\n", "sendPacket", 2;
}

sub sendMailRead {
	my ($self, $mailID) = @_;
	my $msg = pack("v V", 0x0241, $mailID);
	$self->sendToServer($msg);
	debug "Sent read mail.\n", "sendPacket", 2;
}

sub sendMailDelete {
	my ($self, $mailID) = @_;
	my $msg = pack("v V", 0x0243, $mailID);
	$self->sendToServer($msg);
	debug "Sent delete mail.\n", "sendPacket", 2;
}

sub sendMailGetAttach {
	my ($self, $mailID) = @_;
	my $msg = pack("v V", 0x0244, $mailID);
	$self->sendToServer($msg);
	debug "Sent mail get attachment.\n", "sendPacket", 2;
}

sub sendMailOperateWindow {
	my ($self, $window) = @_;
	my $msg = pack("v C x", 0x0246, $window);
	$self->sendToServer($msg);
	debug "Sent mail window.\n", "sendPacket", 2;
}

sub sendMailSetAttach {
	my $self = $_[0];
	my $amount = $_[1];
	my $index = (defined $_[2]) ? $_[2] : 0;	# 0 for zeny
	my $msg = pack("v2 V", 0x0247, $index, $amount);

	#We must do it or we will lost attachment what was not send.
	if ($index) {
		$self->sendMailOperateWindow(1);
	} else {
		$self->sendMailOperateWindow(2);
	}	
	$AI::temp::mailAttachAmount = $amount;
	$self->sendToServer($msg);
	debug "Sent mail set attachment.\n", "sendPacket", 2;
}

sub sendMailSend {
	my ($self, $receiver, $title, $message) = @_;
	my $msg = pack("v2 Z24 a40 C Z*", 0x0248, length($message)+70 , stringToBytes($receiver), stringToBytes($title), length($message), stringToBytes($message));
	$self->sendToServer($msg);
	debug "Sent mail send.\n", "sendPacket", 2;
}

sub sendAuctionAddItemCancel {
	my ($self) = @_;
	my $msg = pack("v2", 0x024B, 1);
	$self->sendToServer($msg);
	debug "Sent Auction Add Item Cancel.\n", "sendPacket", 2;
}

sub sendAuctionAddItem {
	my ($self, $index, $amount) = @_;
	my $msg = pack("v2 V", 0x024C, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Auction Add Item.\n", "sendPacket", 2;
}

sub sendAuctionCreate {
	my ($self, $price, $buynow, $hours) = @_;
	my $msg = pack("v V2 v", 0x024D, $price, $buynow, $hours);
	$self->sendToServer($msg);
	debug "Sent Auction Create.\n", "sendPacket", 2;
}

sub sendAuctionCancel {
	my ($self, $id) = @_;
	my $msg = pack("v V", 0x024E, $id);
	$self->sendToServer($msg);
	debug "Sent Auction Cancel.\n", "sendPacket", 2;
}

sub sendAuctionBuy {
	my ($self, $id, $bid) = @_;
	my $msg = pack("v V2", 0x024F, $id, $bid);
	$self->sendToServer($msg);
	debug "Sent Auction Buy.\n", "sendPacket", 2;
}

sub sendAuctionItemSearch {
	my ($self, $type, $price, $text, $page) = @_;
	$page = (defined $page) ? $page : 1;
	my $msg = pack("v2 V Z24 v", 0x0251, $type, $price, stringToBytes($text), $page);
	$self->sendToServer($msg);
	debug "Sent Auction Item Search.\n", "sendPacket", 2;
}

sub sendAuctionReqMyInfo {
	my ($self, $type) = @_;
	my $msg = pack("v2", 0x025C, $type);
	$self->sendToServer($msg);
	debug "Sent Auction Request My Info.\n", "sendPacket", 2;
}

sub sendAuctionMySellStop {
	my ($self, $id) = @_;
	my $msg = pack("v V", 0x025D, $id);
	$self->sendToServer($msg);
	debug "Sent My Sell Stop.\n", "sendPacket", 2;
}

sub sendMailReturn {
	my ($self, $mailID, $sender) = @_;
	my $msg = pack("v V Z24", 0x0273, $mailID, stringToBytes($sender));
	$self->sendToServer($msg);
	debug "Sent return mail.\n", "sendPacket", 2;
}

sub sendCashShopBuy {
	my ($self, $ID, $amount, $points) = @_;
	my $msg = pack("v v2 V", 0x0288, $ID, $amount, $points);
	$self->sendToServer($msg);
	debug "Sent My Sell Stop.\n", "sendPacket", 2;
}

sub sendAutoRevive {
	my ($self, $ID, $amount, $points) = @_;
	my $msg = pack("v", 0x0292);
	$self->sendToServer($msg);
	debug "Sent Auto Revive.\n", "sendPacket", 2;
}

sub sendMercenaryCommand {
	my ($self, $command) = @_;
	
	# 0x0 => COMMAND_REQ_NONE
	# 0x1 => COMMAND_REQ_PROPERTY
	# 0x2 => COMMAND_REQ_DELETE
	
	my $msg = pack ('v C', 0x029F, $command);
	$self->sendToServer($msg);
	debug "Sent Mercenary Command $command", "sendPacket", 2;
}

sub sendMessageIDEncryptionInitialized {
	my $self = shift;
	my $msg = pack("v", 0x02AF);
	$self->sendToServer($msg);
	debug "Sent Message ID Encryption Initialized\n", "sendPacket", 2;
}

# has the same effects as rightclicking in quest window
sub sendQuestState {
	my ($self, $questID, $state) = @_;
	my $msg = pack("v V C", 0x02B6, $questID, $state);
	$self->sendToServer($msg);
	debug "Sent Quest State.\n", "sendPacket", 2;
}

sub sendBattlegroundChat {
	my ($self, $message) = @_;
	$message = "|00$message" if $masterServer->{chatLangCode};
	my $msg = pack("v2 Z*", 0x02DB, length($message)+4, stringToBytes($message));
	$self->sendToServer($msg);
	debug "Sent Battleground chat.\n", "sendPacket", 2;
}

sub sendCooking {
	my ($self, $type, $nameID) = @_;
	my $msg = pack("v3", 0x025B, $type, $nameID);
	$self->sendToServer($msg);
	debug "Sent Cooking.\n", "sendPacket", 2;
}

sub sendWeaponRefine {
	my ($self, $index) = @_;
	my $msg = pack("v V", 0x0222, $index);
	$self->sendToServer($msg);
	debug "Sent Weapon Refine.\n", "sendPacket", 2;
}

# this is different from kRO
sub sendCaptchaInitiate {
	my ($self) = @_;
	my $msg = pack('v2', 0x07E5, 0x0);
	$self->sendToServer($msg);
	debug "Sending Captcha Initiate\n";
}

# captcha packet from kRO::RagexeRE_2009_09_22a
#0x07e7,32
# TODO: what is 0x20?
sub sendCaptchaAnswer {
	my ($self, $answer) = @_;
	my $msg = pack('v2 a4 a24', 0x07E7, 0x20, $accountID, $answer);
	$self->sendToServer($msg);
}

# 0x0204,18

1;