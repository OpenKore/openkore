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
# tRO (Thai) for 2008-09-16Ragexe12_Th
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::twRO;

use strict;
use Globals;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);
use Math::BigInt;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	$self->{char_create_version} = 1;

	my %packets = (
		'0064' => ['master_login', 'V Z24 a24 C', [qw(version username password_rijndael master_version)]],
		'0970' => ['char_create', 'a24 C v2', [qw(name, slot, hair_style, hair_color)]],

		'0964' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0934' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0958' => ['character_move','a3', [qw(coords)]],
		'095C' => ['sync', 'V', [qw(time)]],
		'08A8' => ['actor_look_at', 'v C', [qw(head body)]],
		'0886' => ['item_take', 'a4', [qw(ID)]],
		'094E' => ['item_drop', 'v2', [qw(index amount)]],
		'08A1' => ['storage_item_add', 'v V', [qw(index amount)]],
		'08A7' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'08A4' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		#PACKET_CZ_USE_SKILL_TOGROUND_WITHTALKBOX2
		'0888' => ['actor_info_request', 'a4', [qw(ID)]],
		'089E' => ['actor_name_request', 'a4', [qw(ID)]],
		#PACKET_CZ_SSILIST_ITEM_CLICK
		#PACKET_CZ_SEARCH_STORE_INFO_NEXT_PAGE
		#PACKET_CZ_SEARCH_STORE_INFO
		'0898' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]],
		'088E' => ['buy_bulk_request', 'a4', [qw(ID)]],
		'0928' => ['buy_bulk_closeShop'],
		'0861' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]],
		'0838' => ['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]],
		#PACKET_CZ_JOIN_BATTLE_FIELD
		#PACKET_CZ_ITEMLISTWIN_RES
		'0968' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0899' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		#PACKET_CZ_GANGSI_RANK
		'085D' => ['friend_request', 'a*', [qw(username)]],
		'0948' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0929' => ['storage_password'],
		);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		master_login 0064
		char_create 0970

		actor_action 0964
		skill_use 0934
		character_move 0958
		sync 095C
		actor_look_at 08A8
		item_take 0886
		item_drop 094E
		storage_item_add 08A1
		storage_item_remove 08A7
		skill_use_location 08A4
		actor_info_request 0888
		actor_name_request 089E
		buy_bulk_buyer 0898
		buy_bulk_request 088E
		buy_bulk_closeShop 0928
		buy_bulk_openShop 0861
		booking_register 0838
		map_login 0968
		party_join_request_by_name 0899
		friend_request 085D
		homunculus_command 0948
		storage_password 0929
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->cryptKeys(0x197A4209, 0x78FE1AA5, 0x31D8015F);

	return $self;
}

sub sell_result {
	my ($self, $args) = @_;

	$self->SUPER::sell_result($args);

	# The server won't let us move until we send the sell complete packet.
	$self->sendSellComplete;
}

sub sendSellComplete {
	my ($self) = @_;
	$messageSender->sendToServer(pack 'C*', 0xD4, 0x09);
}

sub sendCharCreate {
	my ($self, $slot, $name, $hair_style, $hair_color) = @_;

	my $msg = pack('C2 a24 C v2', 0x70, 0x09, stringToBytes($name), $slot, $hair_color, $hair_style);
	$self->sendToServer($msg);
	debug "Sent sendCharCreate\n", "sendPacket", 2;
}

1;