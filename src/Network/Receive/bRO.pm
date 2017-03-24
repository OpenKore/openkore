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
	'07E4', '0941', '0939', '0959', '091D', '094A', '0873', '093A', '023B', '087A', '0931', '094D', '0802', '0892', '0899', '0862', '08A0', '08A9', '087E', '0883', '0897', '0969', '089B', '085E', '086D', '089D', '0838', '0868', '0281', '095F', '0874', '086A', '086E', '0890', '0878', '0951', '08A3', '0880', '0369', '0364', '088D', '092E', '0917', '08A8', '091E', '0881', '08AB', '0960', '092A', '0933', '0946', '095A', '0945', '0863', '0861', '0866', '091F', '0361', '0884', '0948', '094C', '093F', '0922', '094F', '0958', '095E', '08A2', '0944', '0936', '087F', '0950', '0957', '092D', '0437', '0367', '0921', '0362', '0961', '085A', '0835', '092C', '0898', '096A', '095D', '0935', '0366', '08AD', '0811', '093C', '0436', '08AC', '0889', '089A', '088B', '091A', '0877', '0943', '093E', '0923', '0962', '0360', '0815', '0888', '0876', '0947', '0963', '08A5', '0953', '0365', '035F', '087D', '0949', '089F', '085D', '085C', '0869', '092B', '085B', '0887', '0942', '0965', '093B', '087C', '0919', '0817', '095B', '089C', '08AA', '0967', '095C', '08A4', '087B', '0928', '0438', '0968', '083C', '0924', '0940', '094E', '0956', '0893', '0930', '0879', '02C4', '092F', '0964', '088C', '08A6', '0872', '0202', '0954', '0864', '0927', '0886', '0920', '0891', '0819', '0870', '0926', '088F', '0894', '091B', '0885', '088A', '0865', '091C', '086F', '07EC'
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