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
# twRO (Taiwan)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::twRO;

use strict;
use Time::HiRes;

use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message debug);
use Network::MessageTokenizer;
use Misc;
use Utils;
use Translation;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0097' => ['private_message', 'v Z28 Z*', [qw(len privMsgUser privMsg)]],
		'099B' => ['map_property3', 'v a4', [qw(type info_table)]],
		'099F' => ['area_spell_multiple2', 'v a*', [qw(len spellInfo)]], # -1
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
		actor_moved 0856
		actor_exists 0857
		actor_connected 0858
		account_id 0283
		received_characters 099D
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

*parse_quest_update_mission_hunt = *Network::Receive::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::reconstruct_quest_update_mission_hunt_v2;
1;