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

package Network::Send::kRO::RagexeRE_2017_04_19b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_04_12a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'085A' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0838' => ['actor_info_request', 'a4', [qw(ID)]],
		'0811' => ['actor_look_at', 'v C', [qw(head body)]],
		'091B' => ['actor_name_request', 'a4', [qw(ID)]],
		'095D' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0931' => ['buy_bulk_closeShop'],
		'089D' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0965' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'085E' => ['character_move', 'a3', [qw(coordString)]],
		'093A' => ['friend_request', 'a*', [qw(username)]],# len 26
		'088F' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0897' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'088D' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'095C' => ['item_take', 'a4', [qw(ID)]],
		'0922' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0862' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0920' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'093F' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'08AA' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0930' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0881' => ['storage_password'],
		'0898' => ['sync', 'V', [qw(time)]],
		'0868' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0942' => ['search_store_request_next_page'],
		'0819' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 085A
		actor_info_request 0838
		actor_look_at 0811
		actor_name_request 091B
		buy_bulk_buyer 095D
		buy_bulk_closeShop 0952
		buy_bulk_openShop 0931
		buy_bulk_request 0965
		character_move 085E
		friend_request 093A
		homunculus_command 088F
		item_drop 0897
		item_list_window_selected 088D
		item_take 095C
		map_login 0922
		party_join_request_by_name 0862
		skill_use 0920
		skill_use_location 093F
		storage_item_add 08AA
		storage_item_remove 0930
		storage_password 0881
		sync 0898
		search_store_info 0868
		search_store_request_next_page 0942
		search_store_select 0819
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	elif PACKETVER == 20170419 // 2017-04-19bRagexeRE
#	packet_keys(0x1F8F4B3F,0x2E481F03,0x39ED4178);
#	use $key1 $key3 $key2
#	$self->cryptKeys(0x1F8F4B3F,0x39ED4178,0x2E481F03);


	return $self;
}

1;
