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

package Network::Send::kRO::RagexeRE_2015_11_04a;

use strict;
use base 'Network::Send::kRO::RagexeRE_2015_10_01b';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
#		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0887' => ['actor_info_request', 'a4', [qw(ID)]],
		'0928' => ['actor_look_at', 'v C', [qw(head body)]],
#		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0363' => ['character_move', 'a3', [qw(coordString)]],
		'07EC' => ['friend_request', 'a*', [qw(username)]],# len 26
		'088D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0437' => undef,
		'0437' => ['item_drop', 'v2', [qw(index amount)]],
		'0964' => ['item_take', 'a4', [qw(ID)]],
		'0360' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'08A5' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
#		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
#		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#
		'088B' => ['storage_item_add', 'v V', [qw(index amount)]],
#		'0364' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0886' => ['sync', 'V', [qw(time)]],
#		'093A' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0940' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 0887
		actor_look_at 0928
		actor_name_request 0338
		character_move 0363
		friend_request 07EC
		homunculus_command 088D
		item_drop 0437
		item_take 0964
		map_login 0360
		party_join_request_by_name 08A5
		skill_use 083C
		skill_use_location 0438
		storage_item_add 088B
		storage_item_remove 0364
		sync 0886
		storage_password 0940
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(0x4C17382A, 0x29961E4F, 0x7ED174C9);#				Rakki-RO
#	$self->cryptKeys(1051849561, 1257926206, 489582586);#				Ank-RO

	return $self;
}

1;
