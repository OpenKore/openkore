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
package Network::Send::kRO::RagexeRE_2015_11_18a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2015_11_04a);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		#'08A2' => undef,
		#'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0437' => undef,
		'0437' => ['character_move','a3', [qw(coordString)]],#5
		'022D' => ['sync', 'V', [qw(time)]],#6
		'092E' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0943' => ['item_take', 'a4', [qw(ID)]],#6
		'093C' => ['item_drop', 'v2', [qw(index amount)]],#6
		'086B' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'08AB' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],#6
		#'0368' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0925' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0365' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0921' => ['friend_request', 'a*', [qw(username)]],#26
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 092E
		actor_name_request 0368
		character_move 0437
		friend_request 0921
		item_drop 093C
		item_take 0943
		map_login 0925
		party_join_request_by_name 0365
		skill_use 083C
		skill_use_location 0366
		storage_item_add 086B
		storage_item_remove 08AB
		sync 022D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	$self->cryptKeys(2116296160, 1031830912, 1585468800);

	$self;
}

1;
