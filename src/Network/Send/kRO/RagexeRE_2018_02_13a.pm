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
package Network::Send::kRO::RagexeRE_2018_02_13a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2018_02_07b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0933' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'093C' => ['actor_info_request', 'a4', [qw(ID)]],
		'0878' => ['actor_look_at', 'v C', [qw(head body)]],
		'08AD' => ['actor_name_request', 'a4', [qw(ID)]],
		'0898' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'08A9' => ['buy_bulk_closeShop'],
		'08A5' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'087B' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0922' => ['character_move', 'a3', [qw(coordString)]],
		'0917' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0962' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0802' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'095A' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0892' => ['item_take', 'a4', [qw(ID)]],
		'08A3' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'086F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0882' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0924' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0955' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0875' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0369' => ['storage_password'],
		'0874' => ['sync', 'V', [qw(time)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0933
		actor_info_request 093C
		actor_look_at 0878
		actor_name_request 08AD
		buy_bulk_buyer 0898
		buy_bulk_closeShop 08A9
		buy_bulk_openShop 08A5
		buy_bulk_request 087B
		character_move 0922
		friend_request 0917
		homunculus_command 0962
		item_drop 0802
		item_list_window_selected 095A
		item_take 0892
		map_login 08A3
		party_join_request_by_name 086F
		skill_use 0882
		skill_use_location 0924
		storage_item_add 0955
		storage_item_remove 0875
		storage_password 0369
		sync 0874
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;


	return $self;
}

1;