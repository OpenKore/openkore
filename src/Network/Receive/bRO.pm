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
	'035F', '0928', '0918', '093A', '0872', '089F', '0939', '0366', '094A', '0964', '0941', '0926', '0835', '08AD', '092E', '08A9', '087A', '0965', '089A', '0917', '0882', '087C', '0361', '0838', '094C', '08A4', '08AC', '0869', '094D', '085E', '0281', '08A2', '092A', '0895', '0880', '0364', '094E', '0960', '092C', '0968', '095B', '088A', '093B', '0893', '089C', '0940', '0889', '0899', '0925', '091F', '0932', '02C4', '085B', '088D', '0817', '0863', '0962', '0871', '0886', '089D', '0438', '093C', '0861', '0367', '086C', '08A7', '08A0', '07E4', '0922', '0946', '0921', '091E', '0931', '0892', '0866', '0898', '0923', '0877', '088C', '0867', '091C', '088B', '086F', '0955', '0929', '088F', '093F', '0956', '0887', '0883', '085F', '0947', '0878', '0953', '0944', '0881', '0876', '095E', '091D', '0943', '0920', '0948', '0951', '096A', '0924', '0950', '0967', '0802', '0369', '0894', '092F', '095A', '087E', '0365', '093D', '0811', '089B', '0888', '0937', '0935', '0819', '0966', '0958', '087D', '0936', '08AA', '0896', '085D', '095D', '0885', '0969', '0934', '0963', '089E', '086B', '07EC', '0933', '08A8', '0874', '0952', '0879', '095C', '086E', '094B', '08A3', '0919', '0930', '0360', '0868', '091B', '0954', '0864', '0945', '0362', '087B', '093E', '091A', '0363', '08A6', '094F', '083C', '0875', '0437', '022D', '0865', '0860', '0436', '0891'
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