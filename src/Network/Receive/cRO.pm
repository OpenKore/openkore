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
use Globals;


sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	# the following packets are already implemented in st0, but the struct in cRO is different
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2 Z*', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag mapname)]],
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	my %handlers = qw(
		received_characters 099D
		received_characters 082D
		sync_received_characters 09A0
		account_server_info 0AC9
		received_character_ID_and_Map 0AC5
		map_changed 0AC7
		login_error 0ACD
		character_creation_successful 006D
		private_message 0097
		map_property3 099B
		area_spell_multiple2 099F
		actor_moved 09FD
		actor_connected 09FE
		actor_exists 09FF
		inventory_item_added 0A0C
		inventory_items_nonstackable 0A0D
		account_id 0283
		quest_all_list3 09F8
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;