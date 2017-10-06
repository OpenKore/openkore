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
package Network::Send::cRO;

use strict;
use base qw(Network::Send::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0AAC' => ['master_login'	 # todo ! 
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0438' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'035F' => ['character_move','a3', [qw(coords)]],
		'0360' => ['sync', 'V', [qw(time)]],
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],
		'0362' => ['item_take', 'a4', [qw(ID)]],
		'0363' => ['item_drop', 'v2', [qw(index amount)]],
		'0364' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0365' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0368' => ['actor_info_request', 'a4', [qw(ID)]],
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],
		'07E4' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'02C4' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'022D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'023B' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		master_login 0AAC #todo
		buy_bulk_vender 0801
		party_setting 07D7
		send_equip 0998
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	#$self->cryptKeys(, , );

	return $self;
}
1;
