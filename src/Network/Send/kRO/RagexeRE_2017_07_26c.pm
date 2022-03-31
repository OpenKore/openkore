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
#bysctnightcore
package Network::Send::kRO::RagexeRE_2017_07_26c;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_06_14b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0878' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'08AA' => ['actor_info_request', 'a4', [qw(ID)]],
		'0952' => ['actor_look_at', 'v C', [qw(head body)]],
		'0921' => ['actor_name_request', 'a4', [qw(ID)]],
		'0923' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0838' => ['buy_bulk_closeShop'],
		'0363' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0873' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'088E' => ['character_move', 'a3', [qw(coordString)]],
		'091D' => ['friend_request', 'a*', [qw(username)]],# len 26
		'091F' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0943' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0874' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'08AB' => ['item_take', 'a4', [qw(ID)]],
		'0366' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0438' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0369' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'095A' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0364' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'094F' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'08A7' => ['storage_password'],
		'08AC' => ['sync', 'V', [qw(time)]],
		'0963' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0888' => ['search_store_request_next_page'],
		'091E' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0878
		actor_info_request 08AA
		actor_look_at 0952
		actor_name_request 0921
		buy_bulk_buyer 0923
		buy_bulk_closeShop 0838
		buy_bulk_openShop 0363
		buy_bulk_request 0873
		character_move 088E
		friend_request 091D
		homunculus_command 091F
		item_drop 0943
		item_list_window_selected 0874
		item_take 08AB
		map_login 0366
		party_join_request_by_name 0438
		skill_use 0369
		skill_use_location 095A
		storage_item_add 0364
		storage_item_remove 094F
		storage_password 08A7
		sync 08AC
		search_store_info 0963
		search_store_request_next_page 0888
		search_store_select 091E
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#		#elif PACKETVER == 20170726 // 2017-07-26cRagexeRE
#		packet_keys(0x102F23DB,0x7E767751,0x3BC172EF);
#		use = $key1 $key3 $key2
#	$self->cryptKeys(0x102F23DB,0x3BC172EF,0x7E767751);

	return $self;
}

1;