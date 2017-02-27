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
	'0969', '0953', '0954', '0966', '0922', '0962', '0959', '085E', '0923', '088E', '0965', '0895', '0861', '089C', '0927', '0890', '0886', '0931', '096A', '0932', '0949', '0937', '083C', '0899', '08A0', '0948', '0880', '08A2', '0897', '0802', '088B', '0930', '092C', '0878', '0958', '0896', '0951', '089F', '092D', '08A1', '0875', '0437', '0819', '0950', '0898', '095E', '088F', '0364', '023B', '091F', '0946', '093D', '095D', '089A', '094A', '08A6', '088A', '0963', '0883', '0888', '0838', '088D', '0368', '0281', '0369', '086D', '093B', '086E', '0363', '0957', '091B', '0879', '0925', '0942', '095C', '035F', '0884', '0955', '093C', '0961', '0860', '0945', '0876', '087A', '0367', '0362', '0863', '022D', '0864', '0881', '0935', '02C4', '08AB', '088C', '0892', '07EC', '0202', '086C', '08A8', '087F', '0893', '085F', '092E', '085A', '08AA', '0870', '0968', '0835', '0891', '0921', '08A9', '0934', '087E', '0940', '092A', '08A7', '0867', '0956', '093F', '091E', '094F', '093A', '0952', '0865', '0438', '089D', '0811', '0941', '08AD', '0894', '0872', '08AC', '085C', '094B', '0924', '0889', '094C', '086A', '0936', '0866', '0873', '07E4', '089E', '095A', '095B', '092B', '0938', '087C', '0947', '0919', '08A4', '0868', '086B', '093E', '089B', '0869', '0944', '086F', '0964', '0920', '095F', '0871', '085D', '087D', '0918', '0815', '094E', '0929'
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