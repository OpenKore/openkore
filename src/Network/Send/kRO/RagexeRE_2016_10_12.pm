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

package Network::Send::kRO::RagexeRE_2016_10_12;

use strict;
use base 'Network::Send::kRO::RagexeRE_2016_08_31';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0863' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0936' => ['actor_info_request', 'a4', [qw(ID)]],
		'08A0' => ['actor_look_at', 'v C', [qw(head body)]],
		'092D' => ['actor_name_request', 'a4', [qw(ID)]],
		'0939' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'085E' => ['buy_bulk_closeShop'],			
		'07EC' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0937' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0966' => ['character_move', 'a3', [qw(coordString)]],
		'0819' => ['friend_request', 'a*', [qw(username)]],# len 26
		'095C' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0362' => ['item_drop', 'v2', [qw(index amount)]],
		'0364' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0868' => ['item_take', 'a4', [qw(ID)]],
		'086D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0369' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0962' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0951' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0893' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0944' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0967' => ['storage_password'],
		'0365' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0863
		actor_info_request 0936
		actor_look_at 08A0
		actor_name_request 092D
		buy_bulk_buyer 0939
		buy_bulk_closeShop 085E
		buy_bulk_openShop 07EC
		buy_bulk_request 0937
		character_move 0966
		friend_request 0819
		homunculus_command 095C
		item_drop 0362
		item_list_res 0364
		item_take 0868
		map_login 086D
		party_join_request_by_name 0369
		skill_use 0962
		skill_use_location 0951
		storage_item_add 0893
		storage_item_remove 0944
		storage_password 0967
		sync 0365
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(, , );


	return $self;
}

1;
