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
	'0367', '085A', '085B', '085C', '085D', '085E', '085F', '0860', '0861', '0862', '0863', '0864', '0865', '0866', '0867', '0868', '0869', '086A', '086B', '086C', '086D', '086E', '086F', '0870', '0871', '0872', '0873', '0874', '0875', '0876', '0877', '0878', '0879', '087A', '087B', '087C', '087D', '087E', '087F', '0880', '0881', '0882', '0883', '0917', '0918', '0919', '091A', '091B', '091C', '091D', '091E', '091F', '0920', '0921', '0922', '0923', '0924', '0925', '0926', '0927', '0928', '0929', '092A', '092B', '092C', '092D', '092E', '092F', '0930', '0931', '0932', '0933', '0934', '0935', '0936', '0937', '0938', '0939', '093A', '093B', '093C', '093D', '093E', '093F', '02C4', '0884', '0885', '0886', '0887', '0888', '0889', '088A', '088B', '088C', '088D', '088E', '088F', '0890', '0891', '0892', '0893', '0894', '0895', '0896', '0897', '0898', '0899', '089A', '089B', '089C', '089D', '089E', '089F', '08A0', '08A1', '08A2', '08A3', '08A4', '08A5', '08A6', '08A7', '08A8', '08A9', '08AA', '08AB', '08AC', '08AD', '0941', '0942', '0943', '0944', '0945', '0946', '0947', '0948', '0949', '094A', '094B', '094C', '094D', '094E', '094F', '0950', '0951', '0952', '0953', '0954', '0955', '0956', '0957', '0958', '0959', '095A', '095B', '095C', '095D', '095E', '095F', '0960', '0961', '0962', '0963', '0964', '0965', '0966', '0967', '0968', '0969', 
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