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
		'0931' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0923' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0928' => ['character_move','a3', [qw(coords)]],
		'0878' => ['sync', 'V', [qw(time)]],
		'091E' => ['actor_look_at', 'v C', [qw(head body)]],
		'0958' => ['item_take', 'a4', [qw(ID)]],
		'0918' => ['item_drop', 'v2', [qw(index amount)]],
		'088B' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0894' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0959' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		#PACKET_CZ_USE_SKILL_TOGROUND_WITHTALKBOX2'0868'''''
		'0202' => ['actor_info_request', 'a4', [qw(ID)]],
		'0921' => ['actor_name_request', 'a4', [qw(ID)]],
		#PACKET_CZ_SSILIST_ITEM_CLICK'0363'''''
		#PACKET_CZ_SEARCH_STORE_INFO_NEXT_PAGE'0920'''''
		#PACKET_CZ_SEARCH_STORE_INFO'08A0'''''
		'092F' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]],
		'0949' => ['buy_bulk_request', 'a4', [qw(ID)]],
		'0899' => ['buy_bulk_closeShop'],
		'0968' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]],
		'0945' => ['booking_register', 'v8', [qw(level MapID job0 job1 job2 job3 job4 job5)]],
		#PACKET_CZ_JOIN_BATTLE_FIELD'086B'''''
		#PACKET_CZ_ITEMLISTWIN_RES'0893'''''
		'0950' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'083C' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		#PACKET_CZ_GANGSI_RANK'0935'''''
		'087D' => ['friend_request', 'a*', [qw(username)]],
		'0932' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0941' => ['storage_password'],
		#'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0970' => ['char_create', 'a24 C v2', [qw(name, slot, hair_style, hair_color)]],
		'07D7' => ['party_setting', 'V C2', [qw(exp itemPickup itemDivision)]],
		'0801' => ['buy_bulk_vender', 'x2 a4 a4 a*', [qw(venderID venderCID itemInfo)]],
		'0998' => ['send_equip', 'v V', [qw(index type)]],
		'0064' => ['master_login', 'V Z24 a24 C', [qw(version username password_rijndael master_version)]]
		);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	
	my %handlers = qw(
	
		actor_action 0931
		skill_use 0923
		character_move 0928
		sync 0878
		actor_look_at 091E
		item_take 0958
		item_drop 0918
		storage_item_add 088B
		storage_item_remove 0894
		skill_use_location 0959
		actor_info_request 0202
		actor_name_request 0921
		buy_bulk_buyer 092F
		buy_bulk_request 0949
		buy_bulk_closeShop 0899
		buy_bulk_openShop 0968
		booking_register 0945
		map_login 0950
		party_join_request_by_name 083C
		friend_request 087D
		homunculus_command 0932
		storage_password 0941
		#actor_name_request 0368
		char_create 0970
		party_setting 07D7
		buy_bulk_vender 0801
		send_equip 0998
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->cryptKeys(0x5BC32DA8,0x26B433CF,0x3FD01956);

	$self->{sell_mode} = 0;
	return $self;
}
sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$self->sendToServer($self->reconstruct({switch => 'sync'}));
	debug "Sent Sync\n", "sendPacket", 2;
	
	if ($ai_v{temp}{gameguard} && (time - $timeout{gameguard_request}{time} > 120)) {
		undef $ai_v{temp}{gameguard};
		$messageSender->sendRestart(1);
	}
}
sub sendMove {
	my $self = shift;

	# The server won't let us move until we send the sell complete packet.
	$self->sendSellComplete if $self->{sell_mode};

	$self->SUPER::sendMove(@_);
}
sub sendSellComplete {
	my ($self) = @_;
	$self->sendToServer(pack 'C*', 0xD4, 0x09);
	$self->{sell_mode} = 0;
}
sub sendCharCreate {
	my ($self, $slot, $name, $hair_style, $hair_color) = @_;

	my $msg = pack('C2 a24 C v2', 0x70, 0x09, stringToBytes($name), $slot, $hair_color, $hair_style);
	$self->sendToServer($msg);
	debug "Sent sendCharCreate\n", "sendPacket", 2;
}

1;