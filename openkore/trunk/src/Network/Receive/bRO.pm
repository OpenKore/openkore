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


# Sync_Ex algorithm developed by Fr3DBr

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
	);
	
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
		'0872', '0934', '0946', '0968', '0895', '094D', '088F', '0899', '02C4', '0940', 
		'086C', '0943', '0436', '0882', '093C', '08A4', '0925', '0877', '0881', '092A', 
		'093B', '0952', '0897', '0863', '091E', '085A', '092B', '0366', '093D', '0883', 
		'0893', '088D', '087F', '0938', '035F', '089F', '0958', '08A8', '0862', '0935', 
		'0948', '0890', '0361', '085F', '0927', '087B', '0961', '0802', '0892', '0954', 
		'085C', '095B', '091F', '08A6', '0926', '0281', '095C', '0866', '0922', '0917', 
		'0962', '0437', '091A', '0870', '085E', '0860', '022D', '0861', '091B', '0965', 
		'0953', '091D', '0936', '0367', '08A1', '092D', '0202', '087A', '0945', '0951', 
		'087E', '094F', '08AA', '0876', '093E', '0967', '0930', '0896', '086F', '0360', 
		'0947', '0817', '088C', '0949', '0363', '0955', '08AC', '0864', '0939', '0887', 
		'0933', '0888', '08A2', '094B', '0884', '0364', '0950', '088B', '0921', '0963', 
		'0871', '0964', '0924', '0969', '086A', '089D', '095F', '087C', '0932', '0874', 
		'092F', '023B', '094C', '07E4', '0929', '0956', '087D', '0819', '089E', '0875', 
		'0928', '0811', '095E', '0941', '0942', '0838', '08A0', '0891', '094E', '0918', 
		'088E', '0937', '095D', '0868', '092E', '0959', '0966', '085D', '089C', '08A9', 
		'08A5', '085B', '0368', '0438', '093F', '086B', '0865', '0919', '08A7', '086D', 
		'0886', '094A', '095A', '0873', '0944', '0960', '0867', '0365'
	};
	
	foreach my $key (keys %{$self->{sync_ex_reply}}) { $packets{$key} = ['sync_request_ex']; }
	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }
	
	return $self;
}

sub items_nonstackable {
	my ($self, $args) = @_;

	my $items = $self->{nested}->{items_nonstackable};

	if($args->{switch} eq '00A4' || $args->{switch} eq '00A6' || $args->{switch} eq '0122') {
		return $items->{type4};
	} elsif ($args->{switch} eq '0295' || $args->{switch} eq '0296' || $args->{switch} eq '0297') {
		return $items->{type4};
	} elsif ($args->{switch} eq '02D0' || $args->{switch} eq '02D1' || $args->{switch} eq '02D2') {
		return  $items->{type4};
	} else {
		warning("items_nonstackable: unsupported packet ($args->{switch})!\n");
	}
}

*parse_quest_update_mission_hunt = *Network::Receive::ServerType0::parse_quest_update_mission_hunt_v2;
*reconstruct_quest_update_mission_hunt = *Network::Receive::ServerType0::reconstruct_quest_update_mission_hunt_v2;

1;