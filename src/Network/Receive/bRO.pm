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
	'0937', '0877', '0886', '088C', '0953', '0941', '087D', '08A6', '0369', '0893', '0892', '094F', '0365', '0969', '0368', '0929', '0366', '089C', '0895', '0917', '0938', '0949', '0926', '0956', '091F', '0364', '0943', '088A', '0362', '07EC', '08A3', '089D', '094A', '094C', '087B', '0363', '094E', '0202', '0948', '08A0', '091D', '0947', '0872', '092B', '0863', '0879', '094D', '0438', '0870', '08A2', '085B', '0883', '093E', '08AC', '0885', '08AB', '092D', '0962', '08A4', '08AD', '0436', '0896', '091E', '0873', '095A', '085D', '0890', '08A7', '0946', '092E', '089A', '091A', '0944', '089E', '0919', '086B', '0939', '0934', '0884', '087C', '08A8', '086C', '0922', '0957', '0876', '0894', '0965', '0817', '0942', '023B', '0898', '092A', '091B', '0931', '088D', '094B', '0920', '0866', '089B', '0964', '0923', '0963', '0869', '0880', '088E', '0871', '093C', '087F', '087A', '095B', '087E', '0950', '0360', '0967', '0945', '0966', '085A', '022D', '0811', '0935', '091C', '0815', '0955', '0936', '0864', '0887', '0835', '0281', '083C', '0927', '088F', '0924', '093B', '0367', '0875', '0928', '0951', '0921', '0918', '095E', '0802', '0961', '0881', '02C4', '08A5', '0889', '096A', '0897', '08AA', '0933', '086F', '093D', '092F', '092C', '0925', '095D', '0940', '0882', '0865', '0968', '0867', '0960', '086E', '08A9', '0959', '085E', '0888', '0861'
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