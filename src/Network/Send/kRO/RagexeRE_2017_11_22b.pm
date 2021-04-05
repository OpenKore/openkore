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
package Network::Send::kRO::RagexeRE_2017_11_22b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_11_15a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'089E' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'085B' => ['actor_info_request', 'a4', [qw(ID)]],
		'0897' => ['actor_look_at', 'v C', [qw(head body)]],
		'0281' => ['actor_name_request', 'a4', [qw(ID)]],
		'0877' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0920' => ['buy_bulk_closeShop'],
		'0968' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'08A9' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0947' => ['character_move', 'a3', [qw(coordString)]],
		'0946' => ['friend_request', 'a*', [qw(username)]],# len 26
		'083C' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0898' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0862' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0891' => ['item_take', 'a4', [qw(ID)]],
		'0867' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0962' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'093B' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'091E' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0838' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'089A' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0934' => ['storage_password'],
		'0890' => ['sync', 'V', [qw(time)]],
		'02C4' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0945' => ['search_store_request_next_page'],
		'0893' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 089E
		actor_info_request 085B
		actor_look_at 0897
		actor_name_request 0281
		buy_bulk_buyer 0877
		buy_bulk_closeShop 0920
		buy_bulk_openShop 0968
		buy_bulk_request 08A9
		character_move 0947
		friend_request 0946
		homunculus_command 083C
		item_drop 0898
		item_list_window_selected 0862
		item_take 0891
		map_login 0867
		party_join_request_by_name 0962
		skill_use 093B
		skill_use_location 091E
		storage_item_add 0838
		storage_item_remove 089A
		storage_password 0934
		sync 0890
		search_store_info 02C4
		search_store_request_next_page 0945
		search_store_select 0893
	);


	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;