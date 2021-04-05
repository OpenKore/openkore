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
package Network::Send::kRO::RagexeRE_2017_09_20b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_09_13b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'089B' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0889' => ['actor_info_request', 'a4', [qw(ID)]],
		'0939' => ['actor_look_at', 'v C', [qw(head body)]],
		'0921' => ['actor_name_request', 'a4', [qw(ID)]],
		'092E' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0874' => ['buy_bulk_closeShop'],
		'0865' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0961' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'085A' => ['character_move', 'a3', [qw(coordString)]],
		'0861' => ['friend_request', 'a*', [qw(username)]],# len 26
		'095D' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'086C' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0436' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0369' => ['item_take', 'a4', [qw(ID)]],
		'0923' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'086A' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0862' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0919' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0926' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'07EC' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0864' => ['storage_password'],
		'088E' => ['sync', 'V', [qw(time)]],
		'094C' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'096A' => ['search_store_request_next_page'],
		'0937' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 089B
		actor_info_request 0889
		actor_look_at 0939
		actor_name_request 0921
		buy_bulk_buyer 092E
		buy_bulk_closeShop 0874
		buy_bulk_openShop 0865
		buy_bulk_request 0961
		character_move 085A
		friend_request 0861
		homunculus_command 095D
		item_drop 086C
		item_list_window_selected 0436
		item_take 0369
		map_login 0923
		party_join_request_by_name 086A
		skill_use 0862
		skill_use_location 0919
		storage_item_add 0926
		storage_item_remove 07EC
		storage_password 0864
		sync 088E
		search_store_info 094C
		search_store_request_next_page 096A
		search_store_select 0937
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#		#if PACKETVER == 20170920 //
#		packetKeys(0x53024DA5,0x04EC212D,0x0BF87CD4);
#		use = $key1 $key3 $key2
#	$self->cryptKeys(0x53024DA5,0x0BF87CD4,0x04EC212D);


	return $self;
}

1;