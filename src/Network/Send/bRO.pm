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
		'0868' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0891' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0899' => ['character_move','a3', [qw(coords)]],
		'093A' => ['sync', 'V', [qw(time)]],
		'0819' => ['actor_look_at', 'v C', [qw(head body)]],
		'0437' => ['item_take', 'a4', [qw(ID)]],
		'093F' => ['item_drop', 'v2', [qw(index amount)]],
		'086A' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0958' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'085F' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0838' => ['actor_info_request', 'a4', [qw(ID)]],
		'07E4' => ['actor_name_request', 'a4', [qw(ID)]],
		'035F' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0930' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'086D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'095C' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0878' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
		send_equip 0998
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->cryptKeys(1048645105, 177363321, 1496851738);

	return $self;
}

1;