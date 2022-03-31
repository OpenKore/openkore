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
package Network::Send::kRO::RagexeRE_2018_03_07b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2018_02_21a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0969' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0941' => ['actor_info_request', 'a4', [qw(ID)]],
		'08AB' => ['actor_look_at', 'v C', [qw(head body)]],
		'0957' => ['actor_name_request', 'a4', [qw(ID)]],
		'0937' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'093D' => ['buy_bulk_closeShop'],
		'035F' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0862' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0877' => ['character_move', 'a3', [qw(coordString)]],
		'08AA' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0944' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0437' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0870' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0954' => ['item_take', 'a4', [qw(ID)]],
		'07E4' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0948' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0893' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0917' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0920' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'088D' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0939' => ['storage_password'],
		'086C' => ['sync', 'V', [qw(time)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0969
		actor_info_request 0941
		actor_look_at 08AB
		actor_name_request 0957
		buy_bulk_buyer 0937
		buy_bulk_closeShop 093D
		buy_bulk_openShop 035F
		buy_bulk_request 0862
		character_move 0877
		friend_request 08AA
		homunculus_command 0944
		item_drop 0437
		item_list_window_selected 0870
		item_take 0954
		map_login 07E4
		party_join_request_by_name 0948
		skill_use 0893
		skill_use_location 0917
		storage_item_add 0920
		storage_item_remove 088D
		storage_password 0939
		sync 086C
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;