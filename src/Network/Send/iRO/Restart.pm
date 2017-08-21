#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Send::iRO::Restart;

use strict;
use base qw(Network::Send::iRO);

sub new {
	my ( $class ) = @_;
	my $self = $class->SUPER::new( @_ );

	my %packets = (
		'0090' => ['rodex_send_mail', 'v Z24 Z24 V2 v v V a* a*', [qw(len receiver sender zeny1 zeny2 title_len body_len char_id title body)]],
		'0281' => ['guild_check'],
		'0361' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0369' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'07E4' => ['npc_talk', 'a4 C', [qw(ID type)]],
		'085A' => ['storage_password'],
		'0862' => ['actor_name_request', 'a4', [qw(ID)]],
		'0873' => ['actor_info_request', 'a4', [qw(ID)]],
		'0887' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0888' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0890' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'089C' => ['item_take', 'a4', [qw(ID)]],
		'089D' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'08A1' => ['map_connected'],
		'0927' => ['guild_info_request', 'V', [qw(type)]],
		'092A' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'092B' => ['map_loaded'],
		'092F' => ['actor_look_at', 'v C', [qw(head body)]],
		'093C' => ['character_move','a3', [qw(coords)]],
		'0949' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0951' => ['npc_talk_response', 'a4 C', [qw(ID response)]],
		'0953' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0958' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0A5C' => ['sync', 'V', [qw(time)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw();
	while ( my ( $k, $v ) = each %packets ) { $handlers{ $v->[0] } = $k }
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub sendMapConnected {
	my $self = shift;
	$self->sendToServer( $self->reconstruct( { switch => 'map_connected' } ) );
}

1;
