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
# International (iRO)

package Network::Send::iRO;

use strict;
use base qw(Network::Send::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %handlers = qw(
		actor_action 0437
		actor_info_request 0368
		actor_look_at 0361
		buy_bulk_vender 0801
		char_create 0A39
		char_delete2_accept 098F
		character_move 035F
		item_drop 0363
		item_take 0362
		map_login 0436
		party_setting 07D7
		send_equip 0998
		skill_use 0438
		skill_use_location 0366
		storage_item_add 0364
		storage_item_remove 0365
		sync 0360
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;
	$self->{send_sell_buy_complete} = 1;

	return $self;
}

1;
