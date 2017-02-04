#############################################################################
#  OpenKore - Network subsystem												#
#  This module contains functions for sending messages to the server.		#
#																			#
#  This software is open source, licensed under the GNU General Public		#
#  License, version 2.														#
#  Basically, this means that you're allowed to modify and distribute		#
#  this software. However, if you distribute modified versions, you MUST	#
#  also distribute the source code.											#
#  See http://www.gnu.org/licenses/gpl.html for the full license.			#
#############################################################################
# bRO (Brazil)
package Network::Send::bRO;
use strict;
use base 'Network::Send::ServerType0';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'086C' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'085A' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0881' => ['character_move','a3', [qw(coords)]],
		'0802' => ['sync', 'V', [qw(time)]],
		'088B' => ['actor_look_at', 'v C', [qw(head body)]],
		'08AA' => ['item_take', 'a4', [qw(ID)]],
		'089C' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0366' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0926' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'0887' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'093E' => ['actor_info_request', 'a4', [qw(ID)]],
		'095D' => ['actor_name_request', 'a4', [qw(ID)]],
		'0879' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'085C' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0968' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'0937' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0436' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->cryptKeys(1910252973, 68815076, 419593696);

	return $self;
}

1;