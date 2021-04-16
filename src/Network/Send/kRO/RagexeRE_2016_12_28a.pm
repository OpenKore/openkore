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

package Network::Send::kRO::RagexeRE_2016_12_28a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_07_06c);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'093D' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'085A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0871' => ['actor_look_at', 'v C', [qw(head body)]],
		'08AC' => ['actor_name_request', 'a4', [qw(ID)]],
		'0362' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0875' => ['buy_bulk_closeShop'],
		'086A' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'08A3' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0886' => ['character_move', 'a3', [qw(coordString)]],
		'091C' => ['friend_request', 'a*', [qw(username)]],# len 26
		'085E' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0893' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0889' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'086C' => ['item_take', 'a4', [qw(ID)]],
		'086D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0934' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'08A2' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0929' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'089F' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'08AB' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'08AD' => ['storage_password'],
		'0944' => ['sync', 'V', [qw(time)]],
		'0870' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'092C' => ['search_store_request_next_page'],
		'087F' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 093D
		actor_info_request 085A
		actor_look_at 0871
		actor_name_request 08AC
		buy_bulk_buyer 0362
		buy_bulk_closeShop 0875
		buy_bulk_openShop 086A
		buy_bulk_request 08A3
		character_move 0886
		friend_request 091C
		homunculus_command 085E
		item_drop 0893
		item_list_window_selected 0889
		item_take 086C
		map_login 086D
		party_join_request_by_name 0934
		skill_use 08A2
		skill_use_location 0929
		storage_item_add 089F
		storage_item_remove 08AB
		storage_password 08AD
		sync 0944
		search_store_info 0870
		search_store_request_next_page 092C
		search_store_select 087F
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
# packet_keys(0x09366971,0x005672F1,0x6F3712AE);
# $key1 $key3 $key2
#	$self->cryptKeys(0x09366971,0x6F3712AE ,0x005672F1 );


	return $self;
}

1;
