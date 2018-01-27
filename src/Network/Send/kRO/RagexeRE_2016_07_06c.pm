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
package Network::Send::kRO::RagexeRE_2016_07_06c;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_03_02b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0860' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0945' => ['actor_info_request', 'a4', [qw(ID)]],
		'0926' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['actor_name_request', 'a4', [qw(ID)]],
		'0869' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0952' => ['buy_bulk_closeShop'],			
		'086B' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0436' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'092D' => ['character_move', 'a3', [qw(coordString)]],
		'0884' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0892' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'093D' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'091B' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'0958' => ['item_take', 'a4', [qw(ID)]],
		'08A5' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'085F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0899' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0924' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0939' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0929' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'094C' => ['storage_password'],
		'08A8' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0860
		actor_info_request 0945
		actor_look_at 0926
		actor_name_request 0362
		buy_bulk_buyer 0869
		buy_bulk_closeShop 0952
		buy_bulk_openShop 086B
		buy_bulk_request 0436
		character_move 092D
		friend_request 0884
		homunculus_command 0892
		item_drop 093D
		item_list_window_selected 091B
		item_take 0958
		map_login 08A5
		party_join_request_by_name 085F
		skill_use 0899
		skill_use_location 0924
		storage_item_add 0939
		storage_item_remove 0929
		storage_password 094C
		sync 08A8
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
# 		#elif PACKETVER == 20160706 // 2016-07-06cRagexeRE
#		packet_keys(0x33A766D0,0x743F04F8,0x0FA0276C);
#		use $key1 $key3 $key2
#	$self->cryptKeys(0x33A766D0,0x0FA0276C,0x743F04F8);


	return $self;
}

1;