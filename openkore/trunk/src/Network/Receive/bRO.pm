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
		'08A0', '08A9', '094A', '08A2', '0927', '0880', '0881', '0863', '0945', '0961', 
		'0957', '0898', '092F', '0361', '093E', '0365', '0934', '088F', '096A', '0360', 
		'0964', '0939', '07EC', '0943', '094C', '0955', '0937', '0866', '088D', '0860', 
		'0819', '0838', '0882', '085A', '08AA', '0948', '0930', '08AC', '0883', '0952', 
		'093A', '0918', '0944', '0877', '083C', '0869', '0968', '0366', '08A6', '022D', 
		'0920', '0202', '0865', '0960', '0929', '0938', '08AB', '086B', '035F', '0884', 
		'091B', '089B', '093B', '0864', '08A8', '085E', '0888', '08AD', '07E4', '087A', 
		'093F', '08A5', '0917', '088C', '08A4', '095E', '0958', '094D', '0889', '0892', 
		'0886', '086E', '093C', '0956', '092E', '088E', '0923', '094B', '0963', '0885', 
		'087E', '085C', '0953', '0949', '0872', '091C', '0896', '095D', '08A3', '0940', 
		'0933', '023B', '086D', '0887', '092C', '02C4', '092B', '0924', '085B', '0947', 
		'0936', '08A7', '095F', '0959', '086F', '087B', '095B', '0802', '0867', '0969', 
		'0921', '0364', '0436', '094F', '0925', '0922', '0815', '0946', '0862', '091E', 
		'0967', '0891', '0438', '0894', '085F', '0932', '0874', '094E', '095C', '087D', 
		'0873', '085D', '0369', '0893', '0965', '0951', '0966', '091A', '0281', '089A', 
		'0835', '086A', '092A', '0875', '0895', '0899', '0861', '0890', '0437', '089D', 
		'0919', '08A1', '093D', '0935', '0926', '089E', '0871', '0942'
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