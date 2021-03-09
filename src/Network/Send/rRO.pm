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
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Send::rRO;

use strict;

use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'098f' => ['char_delete2_accept', 'v a4 a*', [qw(length charID code)]],
		'0437' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0438' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		# master_login 0B01
		sync 0360
		character_move 035F
		actor_info_request 0368
		actor_look_at 0361
		item_take 0362
		item_drop 0363
		storage_item_add 0364
		storage_item_remove 0365
		skill_use_location 0366
		party_setting 07D7
		buy_bulk_vender 0801
		char_delete2_accept 098f
		send_equip 0998
		map_login 0436
		actor_action 0437
		skill_use 0438
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;

	return $self;
}

1;
