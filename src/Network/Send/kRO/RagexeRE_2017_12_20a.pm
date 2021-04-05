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
package Network::Send::kRO::RagexeRE_2017_12_20a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_12_13b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'093E' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0873' => ['actor_info_request', 'a4', [qw(ID)]],
		'0933' => ['actor_look_at', 'v C', [qw(head body)]],
		'091E' => ['actor_name_request', 'a4', [qw(ID)]],
		'0861' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'08A7' => ['buy_bulk_closeShop'],
		'085E' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0941' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'089E' => ['character_move', 'a3', [qw(coordString)]],
		'0957' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0951' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0929' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0885' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'091B' => ['item_take', 'a4', [qw(ID)]],
		'0281' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0964' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0872' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0960' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0924' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0366' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0899' => ['storage_password'],
		'0882' => ['sync', 'V', [qw(time)]],
		'0369' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0436' => ['search_store_request_next_page'],
		'0880' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 093E
		actor_info_request 0873
		actor_look_at 0933
		actor_name_request 091E
		buy_bulk_buyer 0861
		buy_bulk_closeShop 08A7
		buy_bulk_openShop 085E
		buy_bulk_request 0941
		character_move 089E
		friend_request 0957
		homunculus_command 0951
		item_drop 0929
		item_list_window_selected 0885
		item_take 091B
		map_login 0281
		party_join_request_by_name 0964
		skill_use 0872
		skill_use_location 0960
		storage_item_add 0924
		storage_item_remove 0366
		storage_password 0899
		sync 0882
		search_store_info 0369
		search_store_request_next_page 0436
		search_store_select 0880
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;