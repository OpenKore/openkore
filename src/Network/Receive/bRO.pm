#############################################################################
#  OpenKore - Network subsystem												#
#  This module contains functions for sending messages to the server.		#
#																			#
#  This software is open source, licensed under the GNU General Public		#
#  License, version 2.														#
#  Basically, this means that you're allowed to modify and distribute		#
#  this software. However, if you distribute modified versions, you MUST	#
#  also distribute the source code.											#
#  See http://www.gnu.org/licenses/gpl.html for the full license.			#
#############################################################################
# bRO (Brazil)
package Network::Receive::bRO;
use strict;
use Log qw(warning debug);
use base 'Network::Receive::ServerType0';
use Globals qw(%charSvrSet $messageSender $monstersList);
use Translation qw(TF);

# Sync_Ex algorithm developed by Fr3DBr
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'0A36' => ['monster_hp_info_tiny', 'a4 C', [qw(ID hp)]],
		'09CB' => ['skill_used_no_damage', 'v v x2 a4 a4 C', [qw(skillID amount targetID sourceID success)]],
	);
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
	'0963', '0436', '094B', '0953', '0930', '088B', '0918', '0438', '0950', '0897', '0935', '083C', '08A2', '0892', '0925', '085B', '08AA', '0886', '095A', '0960', '087A', '085E', '086B', '08A4', '0931', '0867', '095C', '0861', '0965', '092B', '0876', '0890', '0365', '0865', '08A7', '0871', '0894', '0944', '093F', '095D', '093A', '0889', '0869', '0838', '095E', '0361', '089E', '0362', '0875', '0864', '0923', '0281', '0928', '0835', '096A', '091A', '092A', '092F', '0968', '0934', '092D', '085F', '089D', '0815', '08A8', '022D', '087D', '0363', '0367', '0920', '0368', '0883', '0948', '093B', '0891', '0961', '0885', '0938', '089A', '0957', '0943', '0966', '0940', '086F', '08A0', '086D', '0898', '0952', '0862', '094E', '0364', '0817', '087B', '0895', '0879', '08A3', '0360', '0437', '0366', '0860', '0937', '0919', '07EC', '091B', '093E', '0962', '094A', '0933', '0874', '0954', '085A', '085D', '093C', '08A5', '0969', '0922', '0917', '086E', '0887', '0802', '0958', '0959', '0956', '0873', '0878', '0924', '08A9', '035F', '092C', '0936', '088F', '089C', '08A1', '0369', '0955', '0893', '0811', '087C', '0870', '0819', '08AD', '0967', '0880', '0884', '0946', '094D', '0899', '091F', '0964', '0202', '08A6', '0949', '094F', '0882', '089F', '094C', '0863', '0951', '086C', '088A', '088E', '087E', '02C4', '091E', '0926', '0947', '0942', '08AB'
	};
	
	foreach my $key (keys %{$self->{sync_ex_reply}}) { $packets{$key} = ['sync_request_ex']; }
	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }
	
	my %handlers = qw(
		received_characters 099D
		received_characters_info 082D
		sync_received_characters 09A0
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub sync_received_characters {
	my ($self, $args) = @_;

	$charSvrSet{sync_Count} = $args->{sync_Count} if (exists $args->{sync_Count});
	
	# When XKore 2 client is already connected and Kore gets disconnected, send sync_received_characters anyway.
	# In most servers, this should happen unless the client is alive
	# This behavior was observed in April 12th 2017, when Odin and Asgard were merged into Valhalla
	for (1..$args->{sync_Count}) {
		$messageSender->sendToServer($messageSender->reconstruct({switch => 'sync_received_characters'}));
	}
}

# 0A36
sub monster_hp_info_tiny {
	my ($self, $args) = @_;
	my $monster = $monstersList->getByID($args->{ID});
	if ($monster) {
		$monster->{hp} = $args->{hp};
		
		debug TF("Monster %s has about %d%% hp left
", $monster->name, $monster->{hp} * 4), "parseMsg_damage"; # FIXME: Probably inaccurate
	}
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;