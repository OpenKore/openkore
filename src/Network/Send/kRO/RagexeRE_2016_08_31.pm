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

package Network::Send::kRO::RagexeRE_2016_08_31;

use strict;
use base 'Network::Send::kRO::RagexeRE_2016_06_08';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0878' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'087C' => ['actor_info_request', 'a4', [qw(ID)]],
		'094A' => ['actor_look_at', 'v C', [qw(head body)]],
		'0946' => ['actor_name_request', 'a4', [qw(ID)]],
		'08A8' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'086D' => ['buy_bulk_closeShop'],			
		'0950' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'07EC' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0865' => ['character_move', 'a3', [qw(coordString)]],
		'092C' => ['friend_request', 'a*', [qw(username)]],# len 26
		'093A' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0366' => ['item_drop', 'v2', [qw(index amount)]],
		'0954' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0960' => ['item_take', 'a4', [qw(ID)]],
		'0835' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0874' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0967' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0964' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'094F' => ['storage_item_add', 'v V', [qw(index amount)]],
		'095E' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0917' => ['storage_password'],
		'08A9' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0878
		actor_info_request 087C
		actor_look_at 094A
		actor_name_request 0946
		buy_bulk_buyer 08A8
		buy_bulk_closeShop 086D
		buy_bulk_openShop 0950
		buy_bulk_request 07EC
		character_move 0865
		friend_request 092C
		homunculus_command 093A
		item_drop 0366
		item_list_res 0954
		item_take 0960
		map_login 0835
		party_join_request_by_name 0874
		skill_use 0967
		skill_use_location 0964
		storage_item_add 094F
		storage_item_remove 095E
		storage_password 0917
		sync 08A9
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(, , );


	return $self;
}

1;
