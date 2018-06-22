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
package Network::Send::kRO::RagexeRE_2016_10_26b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2016_08_24a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'085F' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0930' => ['actor_info_request', 'a4', [qw(ID)]],
		'0962' => ['actor_look_at', 'v C', [qw(head body)]],
		'0926' => ['actor_name_request', 'a4', [qw(ID)]],
		'0861' => ['buy_bulk_buyer', 'a4 a4 a*', [qw(buyerID buyingStoreID itemInfo)]], #Buying store
		'092F' => ['buy_bulk_closeShop'],			
		'092C' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]], #Selling store
		'0891' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0438' => ['character_move', 'a3', [qw(coordString)]],
		'0898' => ['friend_request', 'a*', [qw(username)]],# len 26
		'092E' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0886' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'095C' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'091B' => ['item_take', 'a4', [qw(ID)]],
		'091A' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0953' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0894' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'095E' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'085A' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'094B' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0363' => ['storage_password'],
		'0862' => ['sync', 'V', [qw(time)]],		
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 085F
		actor_info_request 0930
		actor_look_at 0962
		actor_name_request 0926
		buy_bulk_buyer 0861
		buy_bulk_closeShop 092F
		buy_bulk_openShop 092C
		buy_bulk_request 0891
		character_move 0438
		friend_request 0898
		homunculus_command 092E
		item_drop 0886
		item_list_window_selected 095C
		item_take 091B
		map_login 091A
		party_join_request_by_name 0953
		skill_use 0894
		skill_use_location 095E
		storage_item_add 085A
		storage_item_remove 094B
		storage_password 0363
		sync 0862
	);
	
	
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
#if PACKETVER == 20160824
#	packetKeys(0x2FA92FA9,0x2FA92FA9,0x2FA92FA9);

#	$self->cryptKeys(0x2FA92FA9,0x2FA92FA9,0x2FA92FA9);


	return $self;
}

1;