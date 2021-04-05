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
package Network::Send::kRO::RagexeRE_2016_03_02b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_02_17b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0968' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0945' => ['actor_info_request', 'a4', [qw(ID)]],
		'022D' => ['actor_look_at', 'v C', [qw(head body)]],
		'0967' => ['actor_name_request', 'a4', [qw(ID)]],
		'0867' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'08A6' => ['buy_bulk_closeShop'],
		'0864' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0367' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0819' => ['character_move', 'a3', [qw(coordString)]],
		'085B' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0868' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'091A' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0957' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0927' => ['item_take', 'a4', [qw(ID)]],
		'0802' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'087D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0883' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'092F' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0960' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'08A9' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'094E' => ['storage_password'],
		'095A' => ['sync', 'V', [qw(time)]],
		'0865' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0875' => ['search_store_request_next_page'],
		'0873' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0968
		actor_info_request 0945
		actor_look_at 022D
		actor_name_request 0967
		buy_bulk_buyer 0867
		buy_bulk_closeShop 08A6
		buy_bulk_openShop 0864
		buy_bulk_request 0367
		character_move 0819
		friend_request 085B
		homunculus_command 0868
		item_drop 091A
		item_list_window_selected 0957
		item_take 0927
		map_login 0802
		party_join_request_by_name 087D
		skill_use 0883
		skill_use_location 092F
		storage_item_add 0960
		storage_item_remove 08A9
		storage_password 094E
		sync 095A
		search_store_info 0865
		search_store_request_next_page 0875
		search_store_select 0873
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	elif PACKETVER == 20160302 // 2016-03-02bRagexeRE
#		packet_keys(0x7B4441B9,0x5BBC63AF,0x45DA0E71);
#	$self->cryptKeys(0x7B4441B9,0x45DA0E71 ,0x5BBC63AF);


	return $self;
}

1;
