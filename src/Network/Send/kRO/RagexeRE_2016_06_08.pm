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

package Network::Send::kRO::RagexeRE_2016_06_08;

use strict;
use base 'Network::Send::kRO::RagexeRE_2016_04_20';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'07EC' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0889' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],			
		'0815' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0360' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0436' => ['character_move', 'a3', [qw(coordString)]],
		'0969' => ['friend_request', 'a*', [qw(username)]],# len 26
		'089B' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'094D' => ['item_drop', 'v2', [qw(index amount)]],
		'022D' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0899' => ['item_take', 'a4', [qw(ID)]],
		'0437' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'035F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0885' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'095B' => ['storage_item_add', 'v V', [qw(index amount)]],
		'08A6' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0958' => ['storage_password'],
		'0802' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 07EC
		actor_name_request 0368
		buy_bulk_buyer 0889
		buy_bulk_closeShop 0817
		buy_bulk_openShop 0815
		buy_bulk_request 0360
		character_move 0436
		friend_request 0969
		homunculus_command 089B
		item_drop 094D
		item_list_res 022D
		item_take 0899
		map_login 0437
		party_join_request_by_name 035F
		skill_use 083C
		skill_use_location 0885
		storage_item_add 095B
		storage_item_remove 08A6
		storage_password 0958
		sync 0802
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(, , );


	return $self;
}

1;
