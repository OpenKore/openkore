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
	'0897', '0366', '0964', '086F', '0957', '088A', '089C', '086D', '08AA', '0951', '0888', '0883', '0943', '091B', '085D', '035F', '0945', '0939', '0437', '087E', '08AD', '085A', '0966', '0886', '0889', '0894', '0360', '0963', '093F', '08A9', '092B', '0864', '0922', '08A4', '0926', '0918', '0868', '087B', '094E', '091D', '07E4', '086A', '0929', '0815', '083C', '0931', '093B', '0887', '0362', '094A', '093E', '0947', '0872', '0953', '0952', '091C', '0955', '0865', '087D', '0954', '085F', '0438', '091A', '08A7', '094C', '0896', '094F', '092C', '0881', '0880', '0877', '0811', '089B', '0862', '093C', '0863', '095F', '0959', '0867', '089D', '08AC', '0364', '0919', '0436', '0860', '08A8', '0946', '08A0', '089E', '0874', '0936', '0281', '08A2', '089F', '091E', '0941', '086B', '0365', '0940', '0960', '022D', '092F', '0873', '0930', '0875', '0969', '08A6', '0368', '0895', '023B', '094B', '0937', '08A1', '0956', '087F', '0893', '07EC', '0917', '0950', '0924', '0882', '095A', '0363', '0948', '0920', '0885', '0869', '0932', '095E', '0942', '0961', '095D', '0944', '0968', '095C', '085B', '08A3', '0861', '0866', '092D', '096A', '0938', '0202', '0879', '0369', '0965', '02C4', '0802', '08AB', '0925', '088F', '0884', '0361', '088B', '0934', '088C', '089A', '087A', '093D', '0835', '0927', '0891', '0958', '0935', '0817', '086E', '094D', '0921'
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