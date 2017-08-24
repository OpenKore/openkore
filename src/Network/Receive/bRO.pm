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
use Globals qw(%charSvrSet $messageSender);
use Translation qw(TF);

# Sync_Ex algorithm developed by Fr3DBr
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'09CB' => ['skill_used_no_damage', 'v V a4 a4 C', [qw(skillID amount targetID sourceID success)]],
	);
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
		'0870', '0368', '0886', '0945', '0936', '0802', '0958', '086E', '0866', '089B', '091A', '0885', '087E', '0871', '0872', '0949', '0946', '0962', '0942', '0874', '0811', '086B', '0918', '0898', '0930', '08A8', '0935', '094B', '08A7', '088D', '0369', '096A', '093A', '0957', '086D', '0815', '0896', '08AA', '0890', '02C4', '0884', '035F', '092A', '091C', '089D', '0869', '0965', '094E', '0817', '089F', '08A5', '0919', '0959', '091D', '0937', '092B', '0943', '0927', '095B', '0967', '0931', '0924', '0202', '095F', '093B', '023B', '0969', '0964', '08A4', '0361', '0888', '095D', '086C', '0928', '089A', '0868', '0873', '0364', '092D', '0963', '0952', '08A9', '0362', '0881', '0960', '0934', '0968', '0867', '0366', '091F', '0920', '0939', '093F', '0953', '0926', '085F', '0929', '087B', '0891', '091E', '0899', '0956', '0938', '07EC', '088A', '08A3', '091B', '0360', '095A', '085C', '0923', '0819', '0922', '093E', '094F', '089C', '088F', '0864', '0941', '0883', '0436', '0917', '0879', '0895', '0940', '08AD', '0954', '0437', '0877', '0876', '0878', '088E', '095C', '0889', '0861', '092F', '0860', '088B', '092E', '094D', '095E', '0838', '08A0', '0365', '086F', '0921', '085E', '0887', '0875', '0835', '0961', '088C', '0438', '0865', '086A', '0955', '022D', '0892', '0944', '087D', '0863', '08A6', '087C', '0932', '08A1', '0947', '08AC', '093D'
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

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;