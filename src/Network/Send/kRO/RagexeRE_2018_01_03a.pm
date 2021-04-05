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
package Network::Send::kRO::RagexeRE_2018_01_03a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_12_27a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'091D' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'08AB' => ['actor_info_request', 'a4', [qw(ID)]],
		'08A9' => ['actor_look_at', 'v C', [qw(head body)]],
		'089F' => ['actor_name_request', 'a4', [qw(ID)]],
		'0879' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'088E' => ['buy_bulk_closeShop'],
		'094E' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0872' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0941' => ['character_move', 'a3', [qw(coordString)]],
		'0899' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0948' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'095F' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'08AC' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0935' => ['item_take', 'a4', [qw(ID)]],
		'0811' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0363' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0938' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0960' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'02C4' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'092C' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0946' => ['storage_password'],
		'0876' => ['sync', 'V', [qw(time)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 091D
		actor_info_request 08AB
		actor_look_at 08A9
		actor_name_request 089F
		buy_bulk_buyer 0879
		buy_bulk_closeShop 088E
		buy_bulk_openShop 094E
		buy_bulk_request 0872
		character_move 0941
		friend_request 0899
		homunculus_command 0948
		item_drop 095F
		item_list_window_selected 08AC
		item_take 0935
		map_login 0811
		party_join_request_by_name 0363
		skill_use 0938
		skill_use_location 0960
		storage_item_add 02C4
		storage_item_remove 092C
		storage_password 0946
		sync 0876
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;