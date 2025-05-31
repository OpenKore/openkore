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
package Network::Receive::cRO;

use strict;
use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]],
		'009D' => ['item_exists', 'a4 V C v3 C2', [qw(ID nameID identified x y amount subx suby)]],
		'01C8' => ['item_used', 'a2 V a4 v C', [qw(ID itemID actorID remaining success)]],
		'07FD' => ['special_item_obtain', 'v C V c/Z a*', [qw(len type nameID holder etc)]], # record "c/Z" (holder) means: if the first byte ('c') = 24(dec), then Z24, if 'c' = 18(dec), then Z18, еtc.
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v2 V2 v V v6 a4 a2 v V C2 a6 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C2 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font maxHP HP isBoss opt4 name)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font maxHP HP isBoss opt4 name)]],
		'0A05' => ['rodex_add_item', 'C a2 v V C4 a16 a25 v a5', [qw(fail ID amount nameID type identified broken upgrade cards options weight unknow)]],   # 63
		'0A09' => ['deal_add_other', 'V C V C3 a16 a25', [qw(nameID type amount identified broken upgrade cards options)]],
		'0A0A' => ['storage_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A0B' => ['cart_item_added', 'a2 V V C4 a16 a25', [qw(ID amount nameID type identified broken upgrade cards options)]],
		'0A37' => ['inventory_item_added', 'a2 v V C3 a16 V C2 a4 v a25 C v', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options favorite viewID)]],
		'0ADD' => ['item_appeared', 'a4 V v C v2 C2 v C v', [qw(ID nameID type identified x y subx suby amount show_effect effect_type)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		account_id 0283
		account_server_info 0AC9
		actor_connected 09FE
		actor_exists 09FF
		actor_moved 09FD
		area_spell_multiple2 099F
		character_creation_successful 006D
		inventory_item_added 0A0C
		inventory_items_nonstackable 0A0D
		item_appeared 0ADD
		login_error 0ACD
		map_changed 0AC7
		map_property3 099B
		private_message 0097
		quest_all_list 09F8
		received_character_ID_and_Map 0AC5
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack} = "V4";
	$self->{npc_store_info_pack} = "V V C V";
	$self->{rodex_read_mail_item_pack} = "v V C3 a16 a4 C a4 a25";
	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25';

	return $self;
}

1;
