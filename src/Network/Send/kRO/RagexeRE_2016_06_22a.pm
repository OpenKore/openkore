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
package Network::Send::kRO::RagexeRE_2016_06_22a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_04_14b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'089E' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0959' => ['actor_info_request', 'a4', [qw(ID)]],
		'0965' => ['actor_look_at', 'v C', [qw(head body)]],
		'08A2' => ['actor_name_request', 'a4', [qw(ID)]],
		'0861' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0887' => ['buy_bulk_closeShop'],			
		'093F' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0891' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0437' => ['character_move', 'a3', [qw(coordString)]],
		'0890' => ['friend_request', 'a*', [qw(username)]],# len 26
		'07E4' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0969' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0946' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'091C' => ['item_take', 'a4', [qw(ID)]],
		'0936' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0361' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'092F' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'093B' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'035F' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'08A8' => ['storage_password'],
		'092D' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 089E
		actor_info_request 0959
		actor_look_at 0965
		actor_name_request 08A2
		buy_bulk_buyer 0861
		buy_bulk_closeShop 0887
		buy_bulk_openShop 093F
		buy_bulk_request 0891
		character_move 0437
		friend_request 0890
		homunculus_command 07E4
		item_drop 0969
		item_list_window_selected 0946
		item_take 091C
		map_login 0936
		party_join_request_by_name 0361
		skill_use 092F
		skill_use_location 0366
		storage_item_add 093B
		storage_item_remove 035F
		storage_password 08A8
		sync 092D
	);
	
	
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#	elif PACKETVER == 20160414 // 2016-04-14bRagexeRE
#		packet_keys(0x31BD479A,0x40C61398,0x397C1A80);
#	$self->cryptKeys(0x31BD479A,0x397C1A80 ,0x40C61398);


	return $self;
}

1;
