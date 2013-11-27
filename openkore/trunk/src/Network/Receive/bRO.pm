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
use Globals qw(%timeout);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'091D' => ['sync_request_ex'],  
		'0944' => ['sync_request_ex'],  
		'0860' => ['sync_request_ex'],  
		'087F' => ['sync_request_ex'],  
		'0932' => ['sync_request_ex'],  
		'0938' => ['sync_request_ex'],  
		'0954' => ['sync_request_ex'],  
		'095A' => ['sync_request_ex'],  
		'092D' => ['sync_request_ex'],  
		'0870' => ['sync_request_ex'],  
		'0950' => ['sync_request_ex'],  
		'0893' => ['sync_request_ex'],  
		'0963' => ['sync_request_ex'],  
		'08A9' => ['sync_request_ex'],  
		'0896' => ['sync_request_ex'],  
		'0925' => ['sync_request_ex'],  
		'0202' => ['sync_request_ex'],  
		'0943' => ['sync_request_ex'],  
		'095D' => ['sync_request_ex'],  
		'08AD' => ['sync_request_ex'],  
		'0926' => ['sync_request_ex'],  
		'094B' => ['sync_request_ex'],  
		'093C' => ['sync_request_ex'],  
		'0437' => ['sync_request_ex'],  
		'0947' => ['sync_request_ex'],  
		'0365' => ['sync_request_ex'],  
		'0956' => ['sync_request_ex'],  
		'086C' => ['sync_request_ex'],  
		'088F' => ['sync_request_ex'],  
		'08A3' => ['sync_request_ex'],  
		'08A1' => ['sync_request_ex'],  
		'0959' => ['sync_request_ex'],  
		'0876' => ['sync_request_ex'],  
		'0951' => ['sync_request_ex'],  
		'087B' => ['sync_request_ex'],  
		'0436' => ['sync_request_ex'],  
		'0875' => ['sync_request_ex'],  
		'0922' => ['sync_request_ex'],  
		'0952' => ['sync_request_ex'],  
		'0867' => ['sync_request_ex'],  
		'0879' => ['sync_request_ex'],  
		'0942' => ['sync_request_ex'],  
		'0817' => ['sync_request_ex'],  
		'091E' => ['sync_request_ex'],  
		'0924' => ['sync_request_ex'],  
		'086F' => ['sync_request_ex'],  
		'085D' => ['sync_request_ex'],  
		'085A' => ['sync_request_ex'],  
		'0877' => ['sync_request_ex'],  
		'0955' => ['sync_request_ex'],  
		'088B' => ['sync_request_ex'],  
		'0882' => ['sync_request_ex'],  
		'0865' => ['sync_request_ex'],  
		'094E' => ['sync_request_ex'],  
		'087C' => ['sync_request_ex'],  
		'08A4' => ['sync_request_ex'],  
		'0878' => ['sync_request_ex'],  
		'0966' => ['sync_request_ex'],  
		'093E' => ['sync_request_ex'],  
		'0927' => ['sync_request_ex'],  
		'095B' => ['sync_request_ex'],  
		'0891' => ['sync_request_ex'],  
		'0964' => ['sync_request_ex'],  
		'0869' => ['sync_request_ex'],  
		'086B' => ['sync_request_ex'],  
		'0897' => ['sync_request_ex'],  
		'0888' => ['sync_request_ex'],  
		'0935' => ['sync_request_ex'],  
		'08A6' => ['sync_request_ex'],  
		'0861' => ['sync_request_ex'],  
		'0886' => ['sync_request_ex'],  
		'088C' => ['sync_request_ex'],  
		'0281' => ['sync_request_ex'],  
		'0933' => ['sync_request_ex'],  
		'0945' => ['sync_request_ex'],  
		'093F' => ['sync_request_ex'],  
		'0919' => ['sync_request_ex'],  
		'0862' => ['sync_request_ex'],  
		'092A' => ['sync_request_ex'],  
		'0835' => ['sync_request_ex'],  
		'092E' => ['sync_request_ex'],  
		'0361' => ['sync_request_ex'],  
		'08A5' => ['sync_request_ex'],  
		'0930' => ['sync_request_ex'], 
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
		$self->{sync_ex_reply} = {
			'091D', '0873', '0944', '085C', '0860', '086D', '087F', '0360', '0932', '091F', 
			'0938', '08AA', '0954', '0923', '095A', '095C', '092D', '091B', '0870', '0890', 
			'0950', '0362', '0893', '0918', '0963', '091A', '08A9', '0960', '0896', '0363', 
			'0925', '0928', '0202', '0864', '0943', '0892', '095D', '0917', '08AD', '08AC', 
			'0926', '08AB', '094B', '0368', '093C', '0920', '0437', '095F', '0947', '0946', 
			'0365', '0895', '0956', '08A2', '086C', '086A', '088F', '0962', '08A3', '0958', 
			'08A1', '08A7', '0959', '083C', '0876', '0838', '0951', '0866', '087B', '0811', 
			'0436', '0872', '0875', '087D', '0922', '0940', '0952', '094C', '0867', '0366', 
			'0879', '0819', '0942', '089C', '0817', '0939', '091E', '093A', '0924', '0967', 
			'086F', '0802', '085D', '0871', '085A', '0936', '0877', '0934', '0955', '085B', 
			'088B', '094F', '0882', '0931', '0865', '085F', '094E', '0887', '087C', '0868', 
			'08A4', '0894', '0878', '093B', '0966', '093D', '093E', '08A8', '0927', '0815', 
			'095B', '087A', '0891', '087E', '0964', '096A', '0869', '0949', '086B', '091C', 
			'0897', '07EC', '0888', '095E', '0935', '088E', '08A6', '0953', '0861', '08A0', 
			'0886', '0921', '088C', '092C', '0281', '0881', '0933', '089B', '0945', '0969', 
			'093F', '0364', '0919', '086E', '0862', '0968', '092A', '089A', '0835', '0899', 
			'092E', '022D', '0361', '0874', '08A5', '088D', '0930', '0961'
		};
	
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