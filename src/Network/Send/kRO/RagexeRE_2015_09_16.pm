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

package Network::Send::kRO::RagexeRE_2015_09_16;

use strict;
use base 'Network::Send::kRO::RagexeRE_2015_05_13a';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0869' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'095A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0936' => ['actor_look_at', 'v C', [qw(head body)]],
		'0942' => ['actor_name_request', 'a4', [qw(ID)]],
		'0877' => ['character_move', 'a3', [qw(coordString)]],
		'089E' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0960' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'092F' => ['item_drop', 'v2', [qw(index amount)]],
		'089C' => ['item_take', 'a4', [qw(ID)]],
		'0969' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0924' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'093E' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'022D' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#
		'0934' => ['storage_item_add', 'v V', [qw(index amount)]],
		'085E' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'08AC' => ['sync', 'V', [qw(time)]],
		'0961' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0941' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0869
		actor_info_request 095A
		actor_look_at 0936
		actor_name_request 0942
		character_move 0877
		friend_request 089E
		homunculus_command 0960
		item_drop 092F
		item_take 089C
		map_login 0969
		party_join_request_by_name 0924
		skill_use 093E
		skill_use_location 022D
		storage_item_add 0934
		storage_item_remove 085E
		sync 08AC
		storage_password 0941
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(0x17F83A19, 0x1CC541E9, 0x116944F4);	


	return $self;
}

1;