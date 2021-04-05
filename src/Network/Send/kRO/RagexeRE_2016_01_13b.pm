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
package Network::Send::kRO::RagexeRE_2016_01_13b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_01_06a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'089A' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'091B' => ['actor_info_request', 'a4', [qw(ID)]],
		'085B' => ['actor_look_at', 'v C', [qw(head body)]],
		'0930' => ['actor_name_request', 'a4', [qw(ID)]],
		'0893' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'088C' => ['buy_bulk_closeShop'],
		'0967' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0864' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'023B' => ['character_move', 'a3', [qw(coordString)]],
		'0899' => ['friend_request', 'a*', [qw(username)]],# len 26
		'086D' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0924' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0941' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'08A6' => ['item_take', 'a4', [qw(ID)]],
		'094D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'088B' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0892' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0888' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0932' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'093C' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0815' => ['storage_password'],
		'08A0' => ['sync', 'V', [qw(time)]],
		'08AA' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0875' => ['search_store_request_next_page'],
		'0919' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 089A
		actor_info_request 091B
		actor_look_at 085B
		actor_name_request 0930
		buy_bulk_buyer 0893
		buy_bulk_closeShop 088C
		buy_bulk_openShop 0967
		buy_bulk_request 0864
		character_move 023B
		friend_request 0899
		homunculus_command 086D
		item_drop 0924
		item_list_window_selected 0941
		item_take 08A6
		map_login 094D
		party_join_request_by_name 088B
		skill_use 0892
		skill_use_location 0888
		storage_item_add 0932
		storage_item_remove 093C
		storage_password 0815
		sync 08A0
		search_store_info 08AA
		search_store_request_next_page 0875
		search_store_select 0919
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	elif PACKETVER == 20160113 // 2016-01-13cRagexeRE
#		packet_keys(0x18005C4B,0x19A94A72,0x73F678EC);
#		use $key1 $key3 $key2
#	$self->cryptKeys(0x18005C4B,0x73F678EC,0x19A94A72);


	return $self;
}

1;