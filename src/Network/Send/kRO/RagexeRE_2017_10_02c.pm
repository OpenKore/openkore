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
package Network::Send::kRO::RagexeRE_2017_10_02c;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_09_27b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0897' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0811' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],
		'0815' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0360' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0437' => ['character_move', 'a3', [qw(coordString)]],
		'0899' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0438' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'022D' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0928' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'093D' => ['item_take', 'a4', [qw(ID)]],
		'089D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0943' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0885' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'093B' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0934' => ['storage_password'],
		'035F' => ['sync', 'V', [qw(time)]],
		'0819' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0835' => ['search_store_request_next_page'],
		'0838' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 0897
		actor_name_request 0368
		buy_bulk_buyer 0811
		buy_bulk_closeShop 0817
		buy_bulk_openShop 0815
		buy_bulk_request 0360
		character_move 0437
		friend_request 0899
		homunculus_command 0438
		item_drop 022D
		item_list_window_selected 0928
		item_take 093D
		map_login 089D
		party_join_request_by_name 0943
		skill_use 083C
		skill_use_location 0366
		storage_item_add 0885
		storage_item_remove 093B
		storage_password 0934
		sync 035F
		search_store_info 0819
		search_store_request_next_page 0835
		search_store_select 0838
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	elif PACKETVER == 20171002 // 2017-10-02cRagexeRE
#	packet_keys(0x15E1716C,0x4E765B63,0x357D2370);
#		use = $key1 $key3 $key2
#	$self->cryptKeys(0x15E1716C,0x357D2370,0x4E765B63);

	return $self;
}

1;