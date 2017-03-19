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

package Network::Send::kRO::RagexeRE_2015_11_04a_;

use strict;
use base 'Network::Send::kRO::RagexeRE_2015_05_13a';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0363' => undef, #old map_login
		'0363' => ['character_move','a3', [qw(coords)]],
		'0886' => ['sync', 'V', [qw(time)]],
		'0928' => ['actor_look_at', 'v C', [qw(head body)]],
		'0964' => ['item_take', 'a4', [qw(ID)]],
		'0437' => ['item_drop', 'v2', [qw(index amount)]],
		'088B' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0364' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0887' => ['actor_info_request', 'a4', [qw(ID)]],
		'0336' => ['actor_name_request', 'a4', [qw(ID)]],
		'093A' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0360' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'07EC' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'088D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0951' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;
