#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
package Network::Send::kRO::RagexeRE_2015_11_25d;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2015_11_18a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'089C' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'085E' => ['actor_info_request', 'a4', [qw(ID)]],
		'0883' => ['actor_look_at', 'v C', [qw(head body)]],
		'0920' => ['actor_name_request', 'a4', [qw(ID)]],
		'08AD' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0863' => ['buy_bulk_closeShop'],
		'0802' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0939' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0365' => ['character_move', 'a3', [qw(coordString)]],
		'0899' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0951' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'08A9' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0368' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0438' => ['item_take', 'a4', [qw(ID)]],
		'088D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0956' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'092A' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0959' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'085F' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0366' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0884' => ['storage_password'],
		'088C' => ['sync', 'V', [qw(time)]],
		'089F' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0361' => ['search_store_request_next_page'],
		'093E' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 089C
		actor_info_request 085E
		actor_look_at 0883
		actor_name_request 0920
		buy_bulk_buyer 08AD
		buy_bulk_closeShop 0863
		buy_bulk_openShop 0802
		buy_bulk_request 0939
		character_move 0365
		friend_request 0899
		homunculus_command 0951
		item_drop 08A9
		item_list_window_selected 0368
		item_take 0438
		map_login 088D
		party_join_request_by_name 0956
		skill_use 092A
		skill_use_location 0959
		storage_item_add 085F
		storage_item_remove 0366
		storage_password 0884
		sync 088C
		search_store_info 089F
		search_store_request_next_page 0361
		search_store_select 093E
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#elif PACKETVER == 20151125 // 2015-11-25dRagexeRE
#packet_keys(0x237446C0,0x5EFB343A,0x0EDF06C5);
#openkore use with  key1,key3,key2
#	$self->cryptKeys(0x237446C0,0x0EDF06C5 ,0x5EFB343A);


	return $self;
}

1;
