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
	'0365', '0891', '0922', '0835', '0366', '0863', '0969', '0367', '0861', '0921', '0874', '0838', '0917', '088F', '0919', '08A4', '0884', '0941', '088A', '089F', '0965', '02C4', '087E', '0962', '0875', '0956', '096A', '08A2', '0942', '0882', '0363', '0930', '0926', '089C', '0925', '087D', '093B', '08A7', '08A0', '0938', '085E', '087A', '0963', '086F', '0879', '035F', '092C', '0817', '0281', '095A', '088D', '0936', '0953', '07EC', '089D', '0932', '0957', '086D', '0946', '0867', '092F', '0933', '0893', '08A5', '0866', '0889', '08AD', '094A', '0898', '0954', '0888', '0945', '091C', '0959', '095F', '0881', '0877', '0937', '091F', '0878', '0360', '094D', '094C', '0860', '0928', '089E', '094E', '0811', '0958', '093E', '086B', '0948', '0923', '0966', '0885', '0929', '0960', '0887', '085B', '0802', '0931', '094F', '0964', '0880', '08AB', '088E', '0894', '0968', '0944', '0899', '093F', '083C', '091B', '0437', '093C', '086A', '022D', '091A', '0362', '0950', '023B', '0920', '0886', '085D', '0890', '0819', '0896', '095E', '086E', '08A3', '0897', '085F', '0924', '0961', '091D', '0918', '0934', '091E', '087C', '0870', '08A9', '092D', '093D', '0369', '0869', '0943', '0951', '0871', '086C', '08AC', '094B', '0862', '0949', '092E', '0364', '085C', '0940', '08A1', '0873', '0368', '092A', '0939', '0967', '0947', '08A8', '0872', '0895', '087B'
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