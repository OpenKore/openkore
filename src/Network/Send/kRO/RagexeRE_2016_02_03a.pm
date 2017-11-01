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

package Network::Send::kRO::RagexeRE_2016_02_03a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_01_06a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0811' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0202' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],			
		'0815' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0360' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0940' => ['character_move', 'a3', [qw(coordString)]],
		'0361' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0872' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0947' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0835' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'095A' => ['item_take', 'a4', [qw(ID)]],
		'0819' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'093E' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'095D' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0954' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0873' => ['storage_password'],
		'0437' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 0811
		actor_name_request 0368
		buy_bulk_buyer 0202
		buy_bulk_closeShop 0817
		buy_bulk_openShop 0815
		buy_bulk_request 0360
		character_move 0940
		friend_request 0361
		homunculus_command 0872
		item_drop 0947
		item_list_res 0835
		item_take 095A
		map_login 0819
		party_join_request_by_name 093E
		skill_use 083C
		skill_use_location 0438
		storage_item_add 095D
		storage_item_remove 0954
		storage_password 0873
		sync 0437
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#packet_keys(0x3E1411AF,0x6C744497,0x7CFA1BDE);	
#openkore use with  key1,key3,key2
#hex to dec 1041502639,2096765918,1819559063 = key1,key3,key2
#	$self->cryptKeys(0x3E1411AF,0x7CFA1BDE ,0x6C744497);


	return $self;
}

1;
