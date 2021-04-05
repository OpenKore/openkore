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
package Network::Send::kRO::RagexeRE_2013_06_18a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2013_05_22);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0889' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0944' => ['actor_info_request', 'a4', [qw(ID)]],
		'08A6' => ['actor_look_at', 'v C', [qw(head body)]],
		'0945' => ['actor_name_request', 'a4', [qw(ID)]],
		'0891' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'085A' => ['buy_bulk_closeShop'],
		'0932' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0862' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'088E' => ['character_move', 'a3', [qw(coordString)]],
		'0953' => ['friend_request', 'a*', [qw(username)]],# len 26
		'02C4' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0917' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0942' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0962' => ['item_take', 'a4', [qw(ID)]],
		'095B' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0887' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0951' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'096A' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0885' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0936' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0864' => ['storage_password'],
		'0930' => ['sync', 'V', [qw(time)]],
		'0281' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0363' => ['search_store_request_next_page'],
		'0890' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0889
		actor_info_request 0944
		actor_look_at 08A6
		actor_name_request 0945
		buy_bulk_buyer 0891
		buy_bulk_closeShop 085A
		buy_bulk_openShop 0932
		buy_bulk_request 0862
		character_move 088E
		friend_request 0953
		homunculus_command 02C4
		item_drop 0917
		item_list_window_selected 0942
		item_take 0962
		map_login 095B
		party_join_request_by_name 0887
		skill_use 0951
		skill_use_location 096A
		storage_item_add 0885
		storage_item_remove 0936
		storage_password 0864
		sync 0930
		search_store_info 0281
		search_store_request_next_page 0363
		search_store_select 0890
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	elif PACKETVER == 20130618 // 2013-06-18Ragexe
#		packet_keys(0x434115DE,0x34A10FE9,0x6791428E);
#	$self->cryptKeys(0x434115DE, 0x6791428E, 0x34A10FE9);

	return $self;
}

1;
