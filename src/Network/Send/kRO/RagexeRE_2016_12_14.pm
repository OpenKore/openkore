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

package Network::Send::kRO::RagexeRE_2016_12_14;

use strict;
use base 'Network::Send::kRO::RagexeRE_2016_10_12';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0436' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'093D' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0811' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],			
		'0815' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'022D' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0437' => ['character_move', 'a3', [qw(coordString)]],
		'0862' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0360' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0887' => ['item_drop', 'v2', [qw(index amount)]],
		'085A' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'092E' => ['item_take', 'a4', [qw(ID)]],
		'0369' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'086D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0364' => ['storage_item_add', 'v V', [qw(index amount)]],
		'02C4' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0899' => ['storage_password'],
		'035F' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0436
		actor_info_request 096A
		actor_look_at 093D
		actor_name_request 0368
		buy_bulk_buyer 0811
		buy_bulk_closeShop 0817
		buy_bulk_openShop 0815
		buy_bulk_request 022D
		character_move 0437
		friend_request 0862
		homunculus_command 0360
		item_drop 0887
		item_list_res 085A
		item_take 092E
		map_login 0369
		party_join_request_by_name 086D
		skill_use 083C
		skill_use_location 0438
		storage_item_add 0364
		storage_item_remove 02C4
		storage_password 0899
		sync 035F
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(, , );


	return $self;
}

1;
