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

package Network::Send::kRO::RagexeRE_2017_04_12a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_02_08b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'08A1' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'095B' => ['actor_info_request', 'a4', [qw(ID)]],
		'091A' => ['actor_look_at', 'v C', [qw(head body)]],
		'0898' => ['actor_name_request', 'a4', [qw(ID)]],
		'0863' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0952' => ['buy_bulk_closeShop'],
		'0893' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0365' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0878' => ['character_move', 'a3', [qw(coordString)]],
		'0942' => ['friend_request', 'a*', [qw(username)]],# len 26
		'089A' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'089C' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0890' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0959' => ['item_take', 'a4', [qw(ID)]],
		'091E' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'094F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'087B' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0938' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0945' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'086D' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'095D' => ['storage_password'],
		'0929' => ['sync', 'V', [qw(time)]],
		'088B' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0949' => ['search_store_request_next_page'],
		'095C' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 08A1
		actor_info_request 095B
		actor_look_at 091A
		actor_name_request 0898
		buy_bulk_buyer 0863
		buy_bulk_closeShop 0952
		buy_bulk_openShop 0893
		buy_bulk_request 0365
		character_move 0878
		friend_request 0942
		homunculus_command 089A
		item_drop 089C
		item_list_window_selected 0890
		item_take 0959
		map_login 091E
		party_join_request_by_name 094F
		skill_use 087B
		skill_use_location 0938
		storage_item_add 0945
		storage_item_remove 086D
		storage_password 095D
		sync 0929
		search_store_info 088B
		search_store_request_next_page 0949
		search_store_select 095C
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	#elif PACKETVER == 20170412 // 2017-04-12aRagexeRE
#	packet_keys(0x39223393,0x5C847779,0x10217985);
#	use $key1 $key3 $key2
#	$self->cryptKeys(0x39223393,0x10217985,0x5C847779);


	return $self;
}

1;
