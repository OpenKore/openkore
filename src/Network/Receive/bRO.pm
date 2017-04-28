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
use Log qw(warning);
use base 'Network::Receive::ServerType0';
use Globals qw(%charSvrSet $messageSender);

# Sync_Ex algorithm developed by Fr3DBr
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
	);
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
	'085E', '0899', '0951', '087A', '094E', '0889', '0917', '0948', '0962', '0963', '0924', '0368', '086A', '0868', '096A', '0965', '08A8', '092A', '0960', '095F', '0949', '091F', '08AD', '0361', '0964', '0968', '0922', '095E', '022D', '0934', '095A', '0876', '0436', '0896', '0932', '0437', '0940', '0956', '094A', '0920', '0202', '0895', '08A2', '0885', '093A', '089A', '087C', '0961', '0897', '0817', '089D', '0925', '0937', '093B', '085B', '0364', '0938', '08AA', '092D', '0890', '0281', '086E', '093E', '0945', '0944', '0867', '091E', '0815', '08A6', '0884', '0893', '0802', '093D', '091A', '087D', '0942', '0967', '0969', '0947', '0926', '08AC', '0881', '086B', '0875', '0921', '085C', '0952', '094D', '0365', '0369', '094B', '0861', '035F', '08A9', '0894', '0939', '0870', '095D', '0946', '0872', '08A7', '083C', '0878', '0866', '0936', '023B', '095C', '0863', '087E', '0877', '0871', '0362', '0862', '07E4', '089C', '092B', '0879', '092E', '0935', '0363', '0883', '0835', '095B', '0887', '0966', '0860', '08A1', '085D', '0886', '0927', '0888', '0955', '08A0', '0918', '0931', '0864', '092C', '086C', '086D', '088B', '0929', '092F', '0367', '08A3', '0933', '0819', '093F', '0953', '088A', '086F', '0873', '0919', '02C4', '0360', '0438', '0882', '0891', '0838', '0811', '08A4', '089F', '0880', '085F', '0958', '091B', '088C', '0869', '087F'
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