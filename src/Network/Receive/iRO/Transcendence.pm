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
# Servertype overview: https://openkore.com/wiki/ServerType
package Network::Receive::iRO::Transcendence;

use strict;
use base qw(Network::Receive::iRO);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0131' => ['vender_found', 'a4 Z40 x40', [qw(ID title)]], # x40 = garbage?
		'0814' => ['buying_store_found', 'a4 Z40 x40', [qw(ID title)]], # x40 = garbage?
		'082D' => ['received_characters_info', 'v C x2 C2 x20', [qw(len total_slot premium_start_slot premium_end_slot)]],
		'0A05' => ['rodex_add_item', 'C a2 v V C4 a16 a25 v a5', [qw(fail ID amount nameID type identified broken upgrade cards options weight unknow)]],
		'0A09' => ['deal_add_other', 'V C V C3 a16 a25', [qw(nameID type amount identified broken upgrade cards options)]],
		'0A0A' => ['storage_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A0B' => ['cart_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],
		'0A8D' => ['offline_vender_items_list', 'a*', [qw(info)]], # -1
		'0A91' => ['offline_buying_store_items_list', 'a*', [qw(info)]], # -1
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		account_server_info 0AC4
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{npc_store_info_pack} = "V V C V";
	$self->{makable_item_list_pack} = "V4";

	return $self;
}

sub offline_vender_items_list { return; }
sub offline_buying_store_items_list { return; }

1;
