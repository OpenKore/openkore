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
	'07EC', '0965', '0929', '0923', '0817', '086B', '0939', '088B', '0867', '0937', '092A', '083C', '0369', '08A0', '0930', '08A9', '093B', '092C', '0872', '087D', '0969', '0920', '093D', '0875', '0897', '087C', '087E', '0363', '088C', '0895', '08AA', '0890', '0899', '094A', '0881', '08A2', '095E', '087A', '096A', '0952', '089D', '0882', '0957', '08A8', '0928', '0879', '0967', '089F', '0819', '0835', '085F', '0368', '0815', '0945', '0931', '0863', '0963', '022D', '089B', '0955', '0941', '0938', '086F', '092E', '086D', '092D', '0876', '08A1', '094E', '085C', '0956', '085B', '0922', '0948', '0944', '091B', '088A', '094C', '088E', '0366', '0888', '0873', '0954', '091C', '0878', '0811', '0946', '0860', '092B', '0202', '091D', '091A', '095D', '095F', '0951', '089A', '085A', '02C4', '0436', '0959', '0934', '0958', '0942', '093F', '087B', '0880', '08AB', '0886', '094F', '0892', '08A3', '092F', '0874', '088D', '035F', '086A', '0281', '095C', '094D', '0947', '0871', '0866', '08A4', '089C', '0932', '0865', '0925', '091E', '0891', '091F', '0919', '087F', '085D', '0949', '0877', '0362', '0868', '0918', '08A7', '0862', '0361', '0898', '0894', '0884', '088F', '0961', '0926', '085E', '086C', '0870', '0964', '0966', '0889', '0962', '0960', '0883', '0935', '0943', '0933', '0896', '0861', '086E', '094B', '0360', '093C', '0437', '093A', '0864'
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