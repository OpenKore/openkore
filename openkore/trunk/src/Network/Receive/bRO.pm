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
		'0922' => ['sync_request_ex'],
		'0895' => ['sync_request_ex'],
		'0872' => ['sync_request_ex'],
		'0939' => ['sync_request_ex'],
		'0884' => ['sync_request_ex'],
		'0945' => ['sync_request_ex'],
		'094B' => ['sync_request_ex'],
		'087C' => ['sync_request_ex'],
		'0935' => ['sync_request_ex'],
		'083C' => ['sync_request_ex'],
		'0879' => ['sync_request_ex'],
		'095F' => ['sync_request_ex'],
		'089D' => ['sync_request_ex'],
		'0965' => ['sync_request_ex'],
		'088A' => ['sync_request_ex'],
		'08AC' => ['sync_request_ex'],
		'0877' => ['sync_request_ex'],
		'0888' => ['sync_request_ex'],
		'087A' => ['sync_request_ex'],
		'091C' => ['sync_request_ex'],
		'08AD' => ['sync_request_ex'],
		'0870' => ['sync_request_ex'],
		'091F' => ['sync_request_ex'],
		'08AB' => ['sync_request_ex'],
		'087E' => ['sync_request_ex'],
		'093D' => ['sync_request_ex'],
		'093C' => ['sync_request_ex'],
		'087B' => ['sync_request_ex'],
		'0437' => ['sync_request_ex'],
		'092E' => ['sync_request_ex'],
		'086F' => ['sync_request_ex'],
		'0932' => ['sync_request_ex'],
		'07EC' => ['sync_request_ex'],
		'089E' => ['sync_request_ex'],
		'086D' => ['sync_request_ex'],
		'0869' => ['sync_request_ex'],
		'094C' => ['sync_request_ex'],
		'0890' => ['sync_request_ex'],
		'088B' => ['sync_request_ex'],
		'088F' => ['sync_request_ex'],
		'0361' => ['sync_request_ex'],
		'0938' => ['sync_request_ex'],
		'0930' => ['sync_request_ex'],
		'0950' => ['sync_request_ex'],
		'0921' => ['sync_request_ex'],
		'0862' => ['sync_request_ex'],
		'0899' => ['sync_request_ex'],
		'093B' => ['sync_request_ex'],
		'0924' => ['sync_request_ex'],
		'08A2' => ['sync_request_ex'],
		'0882' => ['sync_request_ex'],
		'0898' => ['sync_request_ex'],
		'094E' => ['sync_request_ex'],
		'085F' => ['sync_request_ex'],
		'0963' => ['sync_request_ex'],
		'0951' => ['sync_request_ex'],
		'0948' => ['sync_request_ex'],
		'0896' => ['sync_request_ex'],
		'0873' => ['sync_request_ex'],
		'0362' => ['sync_request_ex'],
		'0968' => ['sync_request_ex'],
		'0861' => ['sync_request_ex'],
		'0893' => ['sync_request_ex'],
		'0947' => ['sync_request_ex'],
		'085D' => ['sync_request_ex'],
		'0878' => ['sync_request_ex'],
		'0920' => ['sync_request_ex'],
		'0368' => ['sync_request_ex'],
		'0967' => ['sync_request_ex'],
		'089B' => ['sync_request_ex'],
		'0438' => ['sync_request_ex'],
		'0969' => ['sync_request_ex'],
		'0960' => ['sync_request_ex'],
		'095C' => ['sync_request_ex'],
		'087F' => ['sync_request_ex'],
		'0897' => ['sync_request_ex'],
		'0881' => ['sync_request_ex'],
		'091A' => ['sync_request_ex'],
		'093F' => ['sync_request_ex'],
		'0946' => ['sync_request_ex'],
		'08A0' => ['sync_request_ex'],
		'0369' => ['sync_request_ex'],
		'0936' => ['sync_request_ex'],
		'0815' => ['sync_request_ex'],
	);
	
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
		'0922', '088C', '0895', '0949', '0872', '0961', '0939', '0281', '0884', '0880', 
		'0945', '0941', '094B', '091B', '087C', '092B', '0935', '0953', '083C', '0838', 
		'0879', '0918', '095F', '0929', '089D', '086B', '0965', '091D', '088A', '0927', 
		'08AC', '094A', '0877', '0955', '0888', '08A8', '087A', '08A9', '091C', '096A', 
		'08AD', '0875', '0870', '086C', '091F', '088E', '08AB', '092F', '087E', '0819', 
		'093D', '0871', '093C', '0817', '087B', '095A', '0437', '092A', '092E', '0886', 
		'086F', '0952', '0932', '095D', '07EC', '0366', '089E', '0889', '086D', '093A', 
		'0869', '085B', '094C', '08AA', '0890', '0865', '088B', '085C', '088F', '0940', 
		'0361', '0925', '0938', '086A', '0930', '0959', '0950', '08A3', '0921', '0944', 
		'0862', '088D', '0899', '0860', '093B', '0957', '0924', '0202', '08A2', '0937', 
		'0882', '0874', '0898', '0934', '094E', '0864', '085F', '035F', '0963', '094F', 
		'0951', '0892', '0948', '08A4', '0896', '095E', '0873', '02C4', '0362', '0866', 
		'0968', '0891', '0861', '0956', '0893', '08A7', '0947', '0933', '085D', '091E', 
		'0878', '0883', '0920', '0931', '0368', '0964', '0967', '0365', '089B', '0917', 
		'0438', '0436', '0969', '0835', '0960', '0367', '095C', '0863', '087F', '0867', 
		'0897', '0943', '0881', '0919', '091A', '0928', '093F', '0360', '0946', '089F', 
		'08A0', '023B', '0369', '022D', '0936', '0887', '0815', '092C'
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
