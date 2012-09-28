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
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::rROrenewal;

use strict;
use base 'Network::Send::ServerType0';
use Log qw(debug);
use Utils qw(getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0090' => ['sendTalk'],
		'00A7' => ['sendItemUse'],
		'00A9' => ['sendEquip'],
		'00AB' => ['sendUnequip'],
		'00BB' => ['sendAddStatusPoint'],
		'00B8' => ['sendTalkResponse'],
		'00f7' => ['sendStorageClose'],
		'0112' => ['sendAddSkillPoint'],
		'0113' => ['sendSkillUse'],
		'0130' => ['sendEnteringVender'],
		'0146' => ['sendTalkCancel'],
		'0364' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0365' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'08B8' => ['security_code'],#10
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	

	my %handlers = qw(
		actor_info_request 0368
		actor_look_at 0361
		item_take 0362
		character_move 035F
		storage_item_add 0364
		storage_item_remove 0365
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	return $self;
}


1;