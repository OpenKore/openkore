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
	'07EC', '08AA', '0867', '0872', '0950', '0949', '0871', '085C', '0896', '093C', '08AD', '0961', '0890', '0947', '0935', '092F', '086D', '0360', '0937', '0887', '0946', '083C', '0886', '087C', '0954', '092D', '089D', '096A', '091A', '0969', '0202', '094C', '086A', '0861', '0966', '08A5', '0802', '089B', '0363', '0864', '08A0', '0924', '091B', '088E', '0925', '094B', '0880', '091D', '0898', '0869', '0883', '0928', '0964', '085D', '0368', '0882', '0892', '086F', '0956', '0930', '0893', '0942', '093D', '093B', '0888', '088C', '0953', '022D', '0917', '0951', '0437', '0919', '0860', '0933', '0948', '0940', '0943', '0874', '0895', '0884', '093F', '0873', '093A', '08A3', '0897', '0929', '0361', '0965', '0862', '0438', '095A', '0936', '0920', '0932', '0941', '08AB', '08A7', '091F', '092B', '0364', '095E', '0939', '0868', '089E', '0962', '085A', '0863', '0365', '0952', '0918', '088B', '095B', '088F', '0875', '0865', '0889', '086C', '0922', '087F', '0366', '02C4', '0815', '0927', '091E', '0891', '0945', '07E4', '0362', '092A', '08A2', '0967', '0959', '08A4', '087E', '0968', '092E', '0944', '0811', '0436', '0866', '08AC', '089C', '0369', '095D', '085E', '0931', '088A', '094D', '0958', '0878', '086B', '0881', '0877', '094E', '094A', '0870', '088D', '0835', '093E', '095C', '0921', '089F', '085B', '091C', '0957', '08A8', '0934', '0876', 
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