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
package Network::Send::kRO::RagexeRE_2017_09_27b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_09_20b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0899' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'035F' => ['actor_info_request', 'a4', [qw(ID)]],
		'087E' => ['actor_look_at', 'v C', [qw(head body)]],
		'0873' => ['actor_name_request', 'a4', [qw(ID)]],
		'087D' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'08A3' => ['buy_bulk_closeShop'],
		'0362' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'091E' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0927' => ['character_move', 'a3', [qw(coordString)]],
		'094B' => ['friend_request', 'a*', [qw(username)]],# len 26
		'02C4' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0923' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'08A5' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'094D' => ['item_take', 'a4', [qw(ID)]],
		'0366' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0922' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'085C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'095A' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0959' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'089B' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'089A' => ['storage_password'],
		'0945' => ['sync', 'V', [qw(time)]],
		'08AD' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'088B' => ['search_store_request_next_page'],
		'0875' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0899
		actor_info_request 035F
		actor_look_at 087E
		actor_name_request 0873
		buy_bulk_buyer 087D
		buy_bulk_closeShop 08A3
		buy_bulk_openShop 0362
		buy_bulk_request 091E
		character_move 0927
		friend_request 094B
		homunculus_command 02C4
		item_drop 0923
		item_list_window_selected 08A5
		item_take 094D
		map_login 0366
		party_join_request_by_name 0922
		skill_use 085C
		skill_use_location 095A
		storage_item_add 0959
		storage_item_remove 089B
		storage_password 089A
		sync 0945
		search_store_info 08AD
		search_store_request_next_page 088B
		search_store_select 0875
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#elif PACKETVER == 20170927 // 2017-09-27bRagexeRE or 2017-09-27dRagexeRE
#	packet_keys(0x15624100,0x0CE1463E,0x0E5D6534);
#		use = $key1 $key3 $key2
#	$self->cryptKeys(0x15624100,0x0E5D6534,0x0CE1463E);


	return $self;
}

1;