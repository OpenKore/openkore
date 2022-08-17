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
#by sctnightcore
package Network::Send::kRO::RagexeRE_2014_09_17c;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2014_03_05);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0889' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0898' => ['actor_info_request', 'a4', [qw(ID)]],
		'095E' => ['actor_look_at', 'v C', [qw(head body)]],
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],
		'0919' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'091E' => ['buy_bulk_closeShop'],			
		'0838' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'089C' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'095C' => ['character_move', 'a3', [qw(coordString)]],
		'0955' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0895' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'095A' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0956' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0864' => ['item_take', 'a4', [qw(ID)]],
		'0366' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'022D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0949' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'094F' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0365' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0930' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'08A8' => ['storage_password'],
		'0897' => ['sync', 'V', [qw(time)]],	
		'0367' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0364' => ['search_store_request_next_page'],
		'092A' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0889
		actor_info_request 0898
		actor_look_at 095E
		actor_name_request 0369
		buy_bulk_buyer 0919
		buy_bulk_closeShop 091E
		buy_bulk_openShop 0838
		buy_bulk_request 089C
		character_move 095C
		friend_request 0955
		homunculus_command 0895
		item_drop 095A
		item_list_window_selected 0956
		item_take 0864
		map_login 0366
		party_join_request_by_name 022D
		skill_use 0949
		skill_use_location 094F
		storage_item_add 0365
		storage_item_remove 0930
		storage_password 08A8
		sync 0897
		search_store_info 0367
		search_store_request_next_page 0364
		search_store_select 092A
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#// 2014-09-17aRagexe, 2014-09-17cRagexeRE
#if PACKETVER == 20140917
#	packetKeys(0x180118EA,0x440134CF,0x3A99179D);
#	$self->cryptKeys(0x180118EA, 0x3A99179D, 0x440134CF);
	return $self;
}

1;