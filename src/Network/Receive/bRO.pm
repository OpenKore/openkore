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
	'0878', '08A2', '0811', '088A', '0868', '0948', '087D', '094C', '0365', '02C4', '086D', '0936', '0817', '0364', '093A', '0870', '0958', '0935', '0944', '089B', '0934', '0819', '0949', '0922', '089C', '0895', '0933', '07EC', '089A', '093B', '093E', '0894', '0881', '0802', '0882', '0368', '0923', '0361', '086B', '0886', '085C', '08A5', '0874', '092D', '096A', '0940', '091D', '0863', '0926', '086E', '0964', '0896', '0897', '092F', '0861', '091E', '092E', '0438', '0921', '022D', '0883', '088C', '0880', '087E', '0937', '0869', '095C', '089E', '095E', '0939', '091C', '095A', '0871', '0888', '0956', '08AD', '0360', '0889', '091F', '0281', '0951', '023B', '0860', '095F', '08A7', '0890', '0369', '086F', '087A', '088F', '0865', '0866', '0898', '0437', '0967', '085E', '0943', '0968', '0955', '0925', '08AB', '093D', '0366', '087B', '0893', '0945', '0947', '0961', '089D', '0367', '0887', '0885', '08A8', '0879', '086C', '035F', '0864', '0873', '094A', '093C', '085B', '0942', '0436', '091A', '0872', '0959', '0202', '0884', '0920', '0953', '0927', '08A9', '0960', '0917', '0862', '0931', '092A', '086A', '0919', '087C', '0957', '088E', '08A1', '08A3', '091B', '08A4', '085D', '0962', '0946', '0838', '085A', '083C', '094E', '0969', '095B', '0867', '0941', '092C', '0362', '0938', '08AC', '088B', '0929', '0899', '0835', '093F', '0892', '08AA'
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