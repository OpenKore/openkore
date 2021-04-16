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
package Network::Send::kRO::RagexeRE_2017_09_13b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_07_26c);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0817' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0281' => ['actor_info_request', 'a4', [qw(ID)]],
		'08AC' => ['actor_look_at', 'v C', [qw(head body)]],
		'095C' => ['actor_name_request', 'a4', [qw(ID)]],
		'0927' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'085A' => ['buy_bulk_closeShop'],
		'0866' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'08A6' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0923' => ['character_move', 'a3', [qw(coordString)]],
		'035F' => ['friend_request', 'a*', [qw(username)]],# len 26
		'088C' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'091D' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'08AD' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0860' => ['item_take', 'a4', [qw(ID)]],
		'0835' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0865' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'08AA' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'095A' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0891' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'07E4' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0892' => ['storage_password'],
		'091B' => ['sync', 'V', [qw(time)]],
		'0437' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0920' => ['search_store_request_next_page'],
		'0925' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0817
		actor_info_request 0281
		actor_look_at 08AC
		actor_name_request 095C
		buy_bulk_buyer 0927
		buy_bulk_closeShop 085A
		buy_bulk_openShop 0866
		buy_bulk_request 08A6
		character_move 0923
		friend_request 035F
		homunculus_command 088C
		item_drop 091D
		item_list_window_selected 08AD
		item_take 0860
		map_login 0835
		party_join_request_by_name 0865
		skill_use 08AA
		skill_use_location 095A
		storage_item_add 0891
		storage_item_remove 07E4
		storage_password 0892
		sync 091B
		search_store_info 0437
		search_store_request_next_page 0920
		search_store_select 0925
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#		#if PACKETVER == 20170913 //
#		packetKeys(0x7A645935,0x1DA05062,0x5A7A4C43);
#		use = $key1 $key3 $key2
#	$self->cryptKeys(0x7A645935,0x5A7A4C43,0x1DA05062);


	return $self;
}

1;