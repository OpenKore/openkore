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
package Network::Send::kRO::RagexeRE_2015_05_13a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2014_10_22b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

		my %packets = (
		'0958' => ['item_take', 'a4', [qw(ID)]],
		'0885' => ['item_drop', 'v2', [qw(index amount)]],
		'0879' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0864' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0363' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0924' => ['actor_look_at', 'v C', [qw(head body)]],
		'022D' => undef,
		'022D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'08A8' => ['friend_request', 'a*', [qw(username)]],#26
		'0817' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0923' => ['storage_password'],
		);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		friend_request 08A8
		homunculus_command 0817
		item_drop 0885
		item_take 0958
		map_login 0363
		party_join_request_by_name 022D
		skill_use 083C
		skill_use_location 0438
		storage_item_add 0879
		storage_item_remove 0864
		storage_password 0923
	);
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
#	$self->cryptKeys(1657302281, 288101181, 1972653847);

	return $self;
}

1;
