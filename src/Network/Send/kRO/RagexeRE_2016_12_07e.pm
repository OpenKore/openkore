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
package Network::Send::kRO::RagexeRE_2016_12_07e;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_02_03a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'08A1' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0811' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],			
		'0815' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0360' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0437' => ['character_move', 'a3', [qw(coordString)]],
		'0867' => ['friend_request', 'a*', [qw(username)]],# len 26
		'023B' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'08AD' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'087E' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'08A2' => ['item_take', 'a4', [qw(ID)]],
		'0361' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0965' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0875' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'091D' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'095D' => ['storage_password'],
		'035F' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 08A1
		actor_name_request 0368
		buy_bulk_buyer 0811
		buy_bulk_closeShop 0817
		buy_bulk_openShop 0815
		buy_bulk_request 0360
		character_move 0437
		friend_request 0867
		homunculus_command 023B
		item_drop 08AD
		item_list_res 087E
		item_take 08A2
		map_login 0361
		party_join_request_by_name 0965
		skill_use 083C
		skill_use_location 0438
		storage_item_add 0875
		storage_item_remove 091D
		storage_password 095D
		sync 035F
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
# 		#elif PACKETVER == 20161207 // 2016-12-07eRagexeRE
#		packet_keys(0x52D267AA,0x4FE42156,0x1292153E);
#		use $key1 $key3 $key2
#	$self->cryptKeys(0x52D267AA,0x1292153E,0x4FE42156);


	return $self;
}

1;