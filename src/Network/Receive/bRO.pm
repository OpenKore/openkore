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
	'08AA', '035F', '0894', '087B', '0862', '0364', '0968', '089F', '093B', '0863', '0871', '089B', '0802', '0933', '0868', '095B', '0883', '092A', '094B', '085E', '0875', '0817', '0955', '087D', '0925', '0919', '08A1', '0953', '091B', '0935', '08A8', '023B', '092B', '087C', '0932', '095D', '0946', '08A7', '093C', '0937', '08A5', '0940', '08A9', '0931', '08AC', '08A3', '0954', '0918', '0882', '08AB', '086D', '0967', '0861', '0962', '094F', '085C', '0896', '093F', '089A', '0893', '0926', '08A4', '0876', '0891', '0947', '0930', '088D', '0948', '08A2', '096A', '093E', '08A6', '087E', '0811', '0864', '0960', '088A', '0879', '0202', '0934', '0924', '0884', '0969', '085F', '086C', '095C', '088B', '093A', '0927', '08A0', '0899', '0835', '0873', '0886', '0367', '0941', '07E4', '095A', '091A', '092E', '0878', '091E', '0819', '0872', '0281', '0815', '0365', '0363', '0942', '08AD', '0838', '0361', '0890', '087A', '0885', '094D', '0963', '0966', '094A', '0958', '0949', '0945', '088E', '089C', '0869', '0897', '0360', '091F', '094C', '0920', '0944', '0928', '0362', '0938', '0368', '0860', '0437', '0877', '0870', '0950', '0917', '0436', '0438', '0965', '095E', '0874', '0939', '093D', '083C', '0898', '0952', '094E', '0892', '0922', '02C4', '0881', '092C', '0921', '0889', '086A', '0865', '092D', '0866', '085A', '087F', '0369', '088F', '0943'
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