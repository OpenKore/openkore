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

package Network::Send::kRO::RagexeRE_2015_09_23d;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2015_09_16);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0951' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'08A5' => ['actor_info_request', 'a4', [qw(ID)]],
		'0870' => ['actor_look_at', 'v C', [qw(head body)]],
		'085C' => ['actor_name_request', 'a4', [qw(ID)]],
		'0817' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'086E' => ['buy_bulk_closeShop'],
		'0892' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'088E' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0886' => ['character_move', 'a3', [qw(coordString)]],
		'085D' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0864' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0930' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0961' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'092B' => ['item_take', 'a4', [qw(ID)]],
		'08A2' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'093B' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'086F' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0936' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'089F' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0879' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'07E4' => ['storage_password'],
		'08A0' => ['sync', 'V', [qw(time)]],
		'0366' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'087F' => ['search_store_request_next_page'],
		'08A6' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0951
		actor_info_request 08A5
		actor_look_at 0870
		actor_name_request 085C
		buy_bulk_buyer 0817
		buy_bulk_closeShop 086E
		buy_bulk_openShop 0892
		buy_bulk_request 088E
		character_move 0886
		friend_request 085D
		homunculus_command 0864
		item_drop 0930
		item_list_window_selected 0961
		item_take 092B
		map_login 08A2
		party_join_request_by_name 093B
		skill_use 086F
		skill_use_location 0936
		storage_item_add 089F
		storage_item_remove 0879
		storage_password 07E4
		sync 08A0
		search_store_info 0366
		search_store_request_next_page 087F
		search_store_select 08A6
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#if PACKETVER == 20150923
#	packetKeys(0x765742B9,0x22D61C2F,0x7DA94FB2);

#	$self->cryptKeys(0x765742B9,0x7DA94FB2 ,0x22D61C2F);


	return $self;
}

1;
