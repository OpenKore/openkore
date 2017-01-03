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
	'08A6', '091C', '0939', '0958', '0898', '0367', '085E', '0838', '088E', '092B', '0868', '0889', '0969', '0802', '08A8', '0959', '0928', '085C', '0955', '086E', '094E', '085B', '023B', '0946', '0936', '092F', '085A', '0364', '0962', '0940', '08AA', '089F', '087E', '0202', '0927', '035F', '0925', '0877', '02C4', '0882', '0872', '0963', '0883', '096A', '0817', '094A', '0885', '088A', '095B', '094F', '0860', '0897', '0945', '0921', '086C', '0890', '0944', '0961', '0360', '093B', '0920', '0281', '08AD', '0436', '0917', '089C', '091B', '07E4', '0924', '092D', '0863', '0948', '0892', '0861', '0864', '0956', '0941', '086D', '0886', '0952', '088F', '086A', '091F', '0918', '085F', '0835', '0363', '0887', '0819', '0369', '093A', '0947', '0881', '0938', '08A2', '0953', '0943', '0932', '088D', '0866', '094B', '094D', '0926', '08AC', '08A4', '095C', '089D', '0878', '091D', '0875', '0919', '092A', '0862', '0896', '085D', '087A', '0894', '095F', '0874', '0967', '093C', '0895', '0811', '07EC', '08AB', '087D', '0930', '086B', '0865', '0968', '0931', '08A5', '0438', '0366', '086F', '087F', '087B', '083C', '0950', '092C', '088C', '0923', '0965', '0899', '095D', '0957', '0964', '094C', '089E', '0966', '092E', '0954', '0869', '0934', '0815', '093D', '0942', '0922', '089A', '0884', '091A', '08A0', '08A7', '0867', '0361', '0929', '0951', '0891'
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