#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# idRO (Indonesia)
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Receive::idRO;

use strict;
use Network::Receive::ServerType0;

use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]],
		'009D' => ['item_exists', 'a4 V C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
		'01C8' => ['item_used', 'a2 V a4 v C', [qw(ID itemID actorID remaining success)]],
		'0A09' => ['deal_add_other', 'V C V C3 a16 a25', [qw(nameID type amount identified broken upgrade cards options)]],
		'0A0A' => ['storage_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A0B' => ['cart_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],
		'0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25 V v';
	$self->{buying_store_items_list_pack} = "V v C V";

	$self->{npc_store_info_pack} = "V V C V";
	$self->{makable_item_list_pack} = "V4";

	return $self;
}

1;