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
	'0367', '093D', '0363', '0897', '085B', '0918', '085C', '0835', '085D', '0953', '085E', '0888', '085F', '0889', '0860', '088A', '0861', '088B', '0862', '088C', '0863', '088D', '023B', '088E', '0865', '088F', '0365', '0890', '0867', '0891', '07E4', '0362', '0869', '0893', '086A', '0894', '086B', '0895', '086C', '0896', '086D', '0885', '086E', '0898', '086F', '0899', '0436', '089A', '0871', '089B', '0872', '0802', '0873', '089D', '0874', '089E', '0875', '089F', '0876', '08A0', '0877', '08A1', '0878', '08A2', '0879', '08A3', '087A', '08A4', '02C4', '08A5', '0361', '08A6', '087D', '08A7', '087E', '08A8', '087F', '08A9', '0880', '08AA', '0881', '08AB', '0882', '08AC', '0883', '08AD', '0917', '0941', '0886', '0942', '0919', '0943', '091A', '0944', '091B', '0945', '091C', '0946', '091D', '0947', '091E', '0948', '091F', '0949', '0920', '0364', '0921', '094B', '0922', '094C', '0923', '094D', '0924', '094E', '0925', '094F', '0926', '0950', '0927', '0951', '0928', '0940', '0929', '0952', '092A', '0954', '092B', '0955', '092C', '0956', '092D', '0957', '092E', '0958', '092F', '0959', '0930', '095A', '0931', '095B', '0932', '095C', '0933', '095D', '0934', '095E', '0935', '0202', '0936', '0960', '0937', '0961', '0938', '022D', '0939', '0963', '093A', '0964', '093B', '0965', '093C', '0966', '0884', '0967', '093E', '0968', '093F', '0969'
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