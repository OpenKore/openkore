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
# tRO (Thai) for 2008-09-16Ragexe12_Th
# Servertype overview: http://openkore.com/index.php/ServerType
package Network::Send::rRO;

use strict;
use base 'Network::Send::ServerType0';
use Log qw(debug);
use Utils qw(getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'00A7' => ['sendItemUse'],
		'00AB' => ['sendUnequip'],
		'00BB' => ['sendAddStatusPoint'],
		'00F7' => ['sendStorageClose'],
		'0112' => ['sendAddSkillPoint'],
		'0130' => ['sendEnteringVender'],
		'0907' => ['item_to_favorite', 'v C', [qw(index flag)]],#5 TODO where 'flag'=0|1 (0 - move item to favorite tab, 1 - move back) 
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_info_request 0368
		actor_look_at 0361
		actor_name_request 0369
		character_move 035F
		item_drop 0363
		item_take 0362
		party_setting 07D7
		send_equip 0998
		skill_use 0113
		skill_use_location 0366
		storage_item_add 0364
		storage_item_remove 0365
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	return $self;
}

1;