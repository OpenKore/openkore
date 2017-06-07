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
	'086A', '091B', '08AB', '02C4', '092A', '0954', '0438', '083C', '0938', '0882', '0888', '0949', '0872', '0944', '08A6', '0958', '086C', '08A8', '088D', '087A', '0893', '022D', '095F', '08A0', '08A5', '0817', '08AD', '0969', '0934', '092D', '085A', '089F', '0360', '0924', '088E', '0366', '0952', '0866', '0362', '0369', '092F', '0967', '0365', '08AC', '088A', '0947', '0920', '087E', '0871', '089B', '0897', '093E', '085D', '0926', '0281', '089D', '095A', '0957', '0892', '0838', '0874', '0946', '086F', '0202', '0941', '0861', '088C', '0953', '08A1', '087C', '095B', '07EC', '091C', '085B', '0878', '092C', '0930', '0886', '0865', '0885', '0950', '0864', '093F', '093B', '096A', '0867', '0927', '093D', '0939', '0896', '0928', '0965', '0883', '0880', '0894', '0364', '0929', '0960', '0895', '094D', '089C', '0962', '0922', '095C', '085F', '0921', '0917', '0955', '0959', '0948', '0870', '0868', '0937', '0862', '0881', '095D', '0436', '0860', '0437', '035F', '0943', '0877', '091E', '094B', '092E', '023B', '0361', '089A', '092B', '091A', '085C', '0925', '0956', '086B', '093C', '0919', '0873', '0918', '0936', '091D', '087D', '085E', '0923', '08A9', '0811', '0898', '0961', '0945', '0875', '0869', '08A3', '0963', '0363', '0966', '086E', '08A4', '0863', '08AA', '0889', '087F', '0819', '088B', '0367', '094E', '0879', '0815', '093A', '087B'
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