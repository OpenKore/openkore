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
		'0945', '0364', '0882', '085A', '0935', '0862', '0961', '091E', '0956', '0872', 
		'086C', '08A7', '0866', '0940', '093D', '0891', '0202', '08AC', '0887', '0883', 
		'0875', '0962', '0874', '0886', '0947', '094B', '0943', '0879', '0869', '093B', 
		'089E', '0930', '087E', '093F', '0369', '095C', '087B', '086F', '0362', '0931', 
		'0969', '0932', '091A', '088C', '0963', '0928', '092B', '0868', '0890', '086B', 
		'0863', '08A2', '07E4', '0958', '0877', '094A', '0933', '0941', '0365', '022D', 
		'08AA', '089C', '0936', '0368', '088B', '0881', '0888', '0838', '0946', '08A8', 
		'0861', '08A6', '096A', '0960', '095A', '0967', '0938', '0867', '0920', '093C', 
		'092D', '0366', '0898', '0944', '0894', '0889', '0897', '085F', '088D', '0819', 
		'0925', '0438', '0811', '0922', '0360', '0942', '094F', '0965', '0934', '0964', 
		'0955', '093A', '086E', '0949', '0880', '0948', '095B', '0921', '087A', '0952', 
		'0927', '095D', '0860', '083C', '089F', '0871', '088F', '0817', '0953', '08AD', 
		'0873', '0926', '0937', '094D', '092C', '0281', '0363', '092A', '0951', '08A9', 
		'087C', '091D', '094E', '0884', '08A3', '092F', '091C', '0436', '0924', '086A', 
		'0367', '088A', '091B', '085C', '08A5', '0919', '095F', '0968', '0950', '089D', 
		'087F', '0893', '0865', '0966', '0876', '0361', '08AB', '0899', '035F', '0939', 
		'02C4', '0954', '0815', '086D', '0802', '085E', '092E', '0878'
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