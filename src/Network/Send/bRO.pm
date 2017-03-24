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
		'086B' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0860' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0952' => ['character_move','a3', [qw(coords)]],
		'0925' => ['sync', 'V', [qw(time)]],
		'0955' => ['actor_look_at', 'v C', [qw(head body)]],
		'0938' => ['item_take', 'a4', [qw(ID)]],
		'0896' => ['item_drop', 'v2', [qw(index amount)]],
		'0918' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0937' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0363' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'094B' => ['actor_info_request', 'a4', [qw(ID)]],
		'0929' => ['actor_name_request', 'a4', [qw(ID)]],
		'022D' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'08A7' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0368' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'0966' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0867' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	$self->cryptKeys(154430592, 1115323424, 1294928560);

	return $self;
}

1;