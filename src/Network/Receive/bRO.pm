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
	'08A3', '07E4', '0918', '0871', '0937', '0926', '0928', '0969', '095A', '0883', '0931', '023B', '0938', '0942', '091A', '0940', '0873', '0952', '094D', '094F', '0893', '0872', '08A9', '095C', '092B', '0954', '091D', '088B', '0865', '088A', '087A', '0882', '0895', '0866', '0958', '0927', '087B', '035F', '0877', '095F', '085B', '0956', '0878', '0964', '092A', '0202', '096A', '0951', '08AB', '0817', '0894', '089A', '0922', '0921', '0835', '0881', '0899', '0862', '0944', '08A5', '0936', '0861', '0949', '0946', '0950', '0943', '0930', '092C', '087F', '0365', '0917', '0948', '085A', '08AD', '0953', '093E', '0879', '083C', '0885', '088C', '0888', '089C', '091F', '0811', '0955', '0889', '088F', '093F', '091E', '0869', '091C', '0961', '0898', '0815', '095E', '08A8', '0925', '08A4', '086F', '092D', '094C', '07EC', '0361', '0874', '0368', '0880', '088D', '092E', '08AA', '086C', '0941', '08A2', '0965', '0929', '0863', '0957', '0919', '0932', '0887', '0924', '094A', '0281', '092F', '0886', '0870', '095B', '022D', '087E', '0933', '0968', '0923', '093D', '0437', '085E', '085F', '0860', '08A7', '086B', '094B', '0864', '0364', '0947', '0963', '085D', '089E', '0896', '086A', '0897', '0960', '093A', '093B', '08A6', '0875', '0867', '095D', '0959', '0884', '0363', '0819', '02C4', '088E', '086E', '0367', '0802', '087C', '085C', '0360', '0967'
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