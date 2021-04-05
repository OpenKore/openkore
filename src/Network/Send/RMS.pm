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
package Network::Send::RMS;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2014_10_22b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'023B' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0281' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'035F' => ['sync', 'V', [qw(time)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0437' => ['character_move','a3', [qw(coordString)]],
		'0438' => ['storage_password'],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0878' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'087D' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0896' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'0899' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'08AA' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'08AD' => ['actor_look_at', 'v C', [qw(head body)]],
		'093B' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'094E' => ['item_take', 'a4', [qw(ID)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0819' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0940' => ['search_store_request_next_page'],
		'0835' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		skill_use_location 023B
		item_list_window_selected 0281
		sync 035F
		actor_name_request 0368
		actor_action 0369
		character_move 0437
		storage_password 0438
		skill_use 083C
		storage_item_add 0878
		item_drop 087D
		party_join_request_by_name 0896
		homunculus_command 0899
		storage_item_remove 08AA
		actor_look_at 08AD
		map_login 093B
		item_take 094E
		actor_info_request 096A
		search_store_info 0819
		search_store_request_next_page 0940
		search_store_select 0835
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->cryptKeys(688214506, 761751195, 731196533);

	return $self;
}

1;