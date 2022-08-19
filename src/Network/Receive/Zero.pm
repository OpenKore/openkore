#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO) # by alisonrag / sctnightcore
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::Zero;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type )]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
		account_server_info 0AC4
		received_character_ID_and_Map 0AC5
		map_changed 0AC7
		actor_exists 09FF
		inventory_item_added 0A37
		character_status 0229
		actor_status_active 0984
		hotkeys 0A00
		item_appeared 0ADD
		account_id 0283
		map_loaded 02EB
		actor_action 08C8
		inventory_items_nonstackable 0A0D
		cart_items_nonstackable 0A0F
		storage_items_nonstackable 0A10
		inventory_items_stackable 0991
		cart_items_stackable 0993
		storage_items_stackable 0995
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25';
	$self->{npc_store_info_pack} = "V V C V";
	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack} = "V4";
	$self->{rodex_read_mail_item_pack} = "v V C3 a16 a4 C a4 a25";
	$self->{npc_market_info_pack} = "V C V2 v";

	return $self;
}

1;