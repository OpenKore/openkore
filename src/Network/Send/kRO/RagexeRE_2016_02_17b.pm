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

package Network::Send::kRO::RagexeRE_2016_02_17b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_02_03a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0920' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0966' => ['actor_info_request', 'a4', [qw(ID)]],
		'0362' => ['actor_look_at', 'v C', [qw(head body)]],
		'0967' => ['actor_name_request', 'a4', [qw(ID)]],
		'0202' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'023B' => ['buy_bulk_closeShop'],
		'0969' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'088D' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'091D' => ['character_move', 'a3', [qw(coordString)]],
		'0870' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0873' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'088F' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'093B' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0941' => ['item_take', 'a4', [qw(ID)]],
		'087A' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'08A9' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0926' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'094A' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0864' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'08A0' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'095E' => ['storage_password'],
		'0888' => ['sync', 'V', [qw(time)]],
		'093E' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'08AD' => ['search_store_request_next_page'],
		'0365' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0920
		actor_info_request 0966
		actor_look_at 0362
		actor_name_request 0967
		buy_bulk_buyer 0202
		buy_bulk_closeShop 023B
		buy_bulk_openShop 0969
		buy_bulk_request 088D
		character_move 091D
		friend_request 0870
		homunculus_command 0873
		item_drop 088F
		item_list_window_selected 093B
		item_take 0941
		map_login 087A
		party_join_request_by_name 08A9
		skill_use 0926
		skill_use_location 094A
		storage_item_add 0864
		storage_item_remove 08A0
		storage_password 095E
		sync 0888
		search_store_info 093E
		search_store_request_next_page 08AD
		search_store_select 0365
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	elif PACKETVER == 20160217 // 2016-02-17cRagexeRE
#		packet_keys(0x25895A8E,0x09421C19,0x763A2D7A);

#	$self->cryptKeys(0x25895A8E,0x763A2D7A ,0x09421C19);


	return $self;
}

1;
