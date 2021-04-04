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
package Network::Send::kRO::RagexeRE_2017_06_14b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_06_07c);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'083C' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0936' => ['actor_info_request', 'a4', [qw(ID)]],
		'087E' => ['actor_look_at', 'v C', [qw(head body)]],
		'087D' => ['actor_name_request', 'a4', [qw(ID)]],
		'092F' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'086B' => ['buy_bulk_closeShop'],
		'08A2' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0860' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0361' => ['character_move', 'a3', [qw(coordString)]],
		'0867' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0364' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0367' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'089D' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'08AD' => ['item_take', 'a4', [qw(ID)]],
		'0944' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0899' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'091B' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0838' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0879' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'023B' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0437' => ['storage_password'],
		'0866' => ['sync', 'V', [qw(time)]],
		'086C' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0928' => ['search_store_request_next_page'],
		'0963' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 083C
		actor_info_request 0936
		actor_look_at 087E
		actor_name_request 087D
		buy_bulk_buyer 092F
		buy_bulk_closeShop 086B
		buy_bulk_openShop 08A2
		buy_bulk_request 0860
		character_move 0361
		friend_request 0867
		homunculus_command 0364
		item_drop 0367
		item_list_window_selected 089D
		item_take 08AD
		map_login 0944
		party_join_request_by_name 0899
		skill_use 091B
		skill_use_location 0838
		storage_item_add 0879
		storage_item_remove 023B
		storage_password 0437
		sync 0866
		search_store_info 086C
		search_store_request_next_page 0928
		search_store_select 0963
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#		#elif PACKETVER == 20170614 // 2017-06-14bRagexeRE
#		packet_keys(0x5ED10A48,0x667F4301,0x2E5D761F);
#		use = $key1 $key3 $key2
#	$self->cryptKeys(0x5ED10A48,0x667F4301,0x2E5D761F);


	return $self;
}

1;