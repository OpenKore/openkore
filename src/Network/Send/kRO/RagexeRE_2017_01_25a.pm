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

package Network::Send::kRO::RagexeRE_2017_01_25a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_12_28a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0438' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0965' => ['actor_info_request', 'a4', [qw(ID)]],
		'0881' => ['actor_look_at', 'v C', [qw(head body)]],
		'0898' => ['actor_name_request', 'a4', [qw(ID)]],
		'087D' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'091D' => ['buy_bulk_closeShop'],			
		'08A5' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'091B' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0930' => ['character_move', 'a3', [qw(coordString)]],
		'0920' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0876' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0877' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0895' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'087B' => ['item_take', 'a4', [qw(ID)]],
		'0811' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'086E' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0879' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'092B' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'091C' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'095C' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0893' => ['storage_password'],
		'0943' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0438
		actor_info_request 0965
		actor_look_at 0881
		actor_name_request 0898
		buy_bulk_buyer 087D
		buy_bulk_closeShop 091D
		buy_bulk_openShop 08A5
		buy_bulk_request 091B
		character_move 0930
		friend_request 0920
		homunculus_command 0876
		item_drop 0877
		item_list_res 0895
		item_take 087B
		map_login 0811
		party_join_request_by_name 086E
		skill_use 0879
		skill_use_location 092B
		storage_item_add 091C
		storage_item_remove 095C
		storage_password 0893
		sync 0943
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
# 	elif PACKETVER == 20170125 // 2017-01-25aRagexeRE
#	packet_keys(0x066E04FE,0x3004224A,0x04FF0458);
#	use $key1 $key3 $key2
#	$self->cryptKeys(0x066E04FE,0x04FF0458,0x3004224A);


	return $self;
}

1;
