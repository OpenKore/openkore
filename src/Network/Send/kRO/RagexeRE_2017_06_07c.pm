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
package Network::Send::kRO::RagexeRE_2017_06_07c;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_05_17a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0938' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0862' => ['actor_info_request', 'a4', [qw(ID)]],
		'085A' => ['actor_look_at', 'v C', [qw(head body)]],
		'0944' => ['actor_name_request', 'a4', [qw(ID)]],
		'0919' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'093D' => ['buy_bulk_closeShop'],
		'0949' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0863' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0934' => ['character_move', 'a3', [qw(coordString)]],
		'0885' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0942' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0864' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0361' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0897' => ['item_take', 'a4', [qw(ID)]],
		'0871' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0925' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'08A9' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0927' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'089D' => ['storage_item_add', 'v V', [qw(index amount)]],
		'088A' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0364' => ['storage_password'],
		'07E4' => ['sync', 'V', [qw(time)]],
		'085E' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0917' => ['search_store_request_next_page'],
		'0875' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0938
		actor_info_request 0862
		actor_look_at 085A
		actor_name_request 0944
		buy_bulk_buyer 0919
		buy_bulk_closeShop 093D
		buy_bulk_openShop 0949
		buy_bulk_request 0863
		character_move 0934
		friend_request 0885
		homunculus_command 0942
		item_drop 0864
		item_list_window_selected 0361
		item_take 0897
		map_login 0871
		party_join_request_by_name 0925
		skill_use 08A9
		skill_use_location 0927
		storage_item_add 089D
		storage_item_remove 088A
		storage_password 0364
		sync 07E4
		search_store_info 085E
		search_store_request_next_page 0917
		search_store_select 0875
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#		#elif PACKETVER == 20170607 // 2017-06-07cRagexeRE
#		packet_keys(0x50564ACD,0x79CA4E15,0x405F4894);
#	use with $key1 $key3 $key2
#	$self->cryptKeys(0x50564ACD,0x405F4894,0x79CA4E15);


	return $self;
}

1;