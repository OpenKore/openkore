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
package Network::Send::kRO::RagexeRE_2017_05_17a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2017_01_25a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0894' => ['actor_info_request', 'a4', [qw(ID)]],
		'088D' => ['actor_look_at', 'v C', [qw(head body)]],
		'087B' => ['actor_name_request', 'a4', [qw(ID)]],
		'091B' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'089F' => ['buy_bulk_closeShop'],			
		'0367' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0946' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'08A8' => ['character_move', 'a3', [qw(coordString)]],
		'0960' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0958' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'093B' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0945' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0964' => ['item_take', 'a4', [qw(ID)]],
		'0923' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0899' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0815' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0817' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'08AA' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'088C' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0947' => ['storage_password'],
		'08A2' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0437
		actor_info_request 0894
		actor_look_at 088D
		actor_name_request 087B
		buy_bulk_buyer 091B
		buy_bulk_closeShop 089F
		buy_bulk_openShop 0367
		buy_bulk_request 0946
		character_move 08A8
		friend_request 0960
		homunculus_command 0958
		item_drop 093B
		item_list_res 0945
		item_take 0964
		map_login 0923
		party_join_request_by_name 0899
		skill_use 0815
		skill_use_location 0817
		storage_item_add 08AA
		storage_item_remove 088C
		storage_password 0947
		sync 08A2
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	#elif PACKETVER == 20170517 // 2017-05-17aRagexeRE
#	packet_keys(0x2CC4749A,0x1FA954DC,0x72276857);
#	use $key1 $key3 $key2
#	$self->cryptKeys(0x2CC4749A,0x72276857,0x1FA954DC);


	return $self;
}

1;