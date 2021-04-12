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
package Network::Send::kRO::RagexeRE_2015_12_02;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2015_11_25d);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0437' => ['character_move','a3', [qw(coordString)]],#5
		'035F' => ['sync', 'V', [qw(time)]],#6
		'0202' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'07E4' => ['item_take', 'a4', [qw(ID)]],#6
		'0362' => ['item_drop', 'a2 v', [qw(ID amount)]],#6
		'07EC' => ['storage_item_add', 'a2 V', [qw(ID amount)]],#8
		'0364' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],#8
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'022D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0802' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'023B' => ['friend_request', 'a*', [qw(username)]],#26
		'0361' => ['homunculus_command', 'v C', [qw(commandType commandID)]],#5
		'0819' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0835' => ['search_store_request_next_page'],
		'0838' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 0202
		actor_name_request 0368
		character_move 0437
		friend_request 023B
		homunculus_command 0361
		item_drop 0362
		item_take 07E4
		map_login 022D
		party_join_request_by_name 0802
		skill_use 083C
		skill_use_location 0366
		storage_item_add 07EC
		storage_item_remove 0364
		sync 035F
		search_store_info 0819
		search_store_request_next_page 0835
		search_store_select 0838
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	$self->cryptKeys(, , );

	$self;
}

1;