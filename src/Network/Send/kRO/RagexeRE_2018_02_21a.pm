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
package Network::Send::kRO::RagexeRE_2018_02_21a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2018_02_13a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'096A' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0957' => ['actor_info_request', 'a4', [qw(ID)]],
		'0838' => ['actor_look_at', 'v C', [qw(head body)]],
		'088F' => ['actor_name_request', 'a4', [qw(ID)]],
		'0883' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0929' => ['buy_bulk_closeShop'],
		'086F' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'086C' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'087D' => ['character_move', 'a3', [qw(coordString)]],
		'0436' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0876' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0871' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0880' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'094E' => ['item_take', 'a4', [qw(ID)]],
		'0897' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'093D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'094B' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'094D' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0879' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'091E' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0917' => ['storage_password'],
		'089D' => ['sync', 'V', [qw(time)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 096A
		actor_info_request 0957
		actor_look_at 0838
		actor_name_request 088F
		buy_bulk_buyer 0883
		buy_bulk_closeShop 0929
		buy_bulk_openShop 086F
		buy_bulk_request 086C
		character_move 087D
		friend_request 0436
		homunculus_command 0876
		item_drop 0871
		item_list_window_selected 0880
		item_take 094E
		map_login 0897
		party_join_request_by_name 093D
		skill_use 094B
		skill_use_location 094D
		storage_item_add 0879
		storage_item_remove 091E
		storage_password 0917
		sync 089D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;