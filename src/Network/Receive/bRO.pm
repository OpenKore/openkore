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
	'0202', '0886', '0860', '089F', '096A', '0927', '0874', '094A', '0894', '0926', '0919', '0367', '092F', '0966', '0884', '093D', '0835', '0364', '091E', '0929', '0879', '095C', '0963', '08A1', '0952', '0932', '0933', '094F', '0869', '0867', '0949', '0943', '0953', '08A3', '0362', '0877', '093C', '0930', '0956', '08A6', '088D', '0958', '07EC', '0281', '0918', '0361', '0950', '0960', '0936', '0888', '091F', '07E4', '0870', '086D', '094D', '0959', '095B', '0868', '085B', '086A', '091A', '0937', '08A5', '094B', '095F', '0895', '0947', '0892', '092B', '0366', '0897', '089B', '088E', '0887', '0940', '0923', '0941', '0921', '0875', '0802', '085E', '08A9', '0954', '0889', '093E', '0817', '0964', '0896', '095E', '0861', '088B', '0838', '0819', '0967', '0363', '0955', '08A0', '0882', '0917', '093B', '0890', '094E', '092C', '0436', '0863', '0920', '088F', '0898', '092E', '086E', '0961', '0899', '089D', '0878', '08A4', '02C4', '0864', '0939', '0438', '0935', '08AD', '087B', '0365', '085A', '083C', '0368', '0883', '0942', '0815', '089A', '093F', '0931', '091C', '0862', '095A', '0876', '08AC', '0369', '08AA', '0880', '093A', '0925', '023B', '086F', '088C', '095D', '0885', '0437', '08A7', '0934', '085C', '086C', '0871', '0811', '0946', '092A', '0968', '0945', '0872', '0891', '08AB', '035F', '0866', '087A', '0951', '0873', '089C', '0965'
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