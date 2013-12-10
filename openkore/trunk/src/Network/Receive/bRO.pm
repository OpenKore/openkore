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

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
	);
	
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
		'0364', '0929', '0438', '086B', '0863', '0882', '086A', '0877', '0864', '0969', 
		'0862', '0922', '095D', '08A9', '094B', '087D', '0965', '0949', '093F', '091E', 
		'08AA', '092E', '086E', '0873', '0941', '022D', '094D', '089C', '08AD', '0835', 
		'0881', '0865', '0918', '091B', '0885', '08A4', '092C', '0958', '0938', '092F', 
		'0920', '0860', '0930', '0893', '0940', '089E', '088B', '0871', '0945', '091D', 
		'07E4', '093C', '08AB', '0819', '0879', '0367', '087F', '092D', '0937', '0436', 
		'0886', '0957', '08A6', '085E', '085B', '095B', '0947', '0202', '08A7', '093A', 
		'089B', '086C', '087B', '0368', '0281', '0966', '0868', '0948', '0951', '0962', 
		'0933', '0876', '0838', '0360', '087C', '095A', '0954', '0369', '0875', '08A2', 
		'089A', '0952', '096A', '0946', '089F', '0934', '0932', '0953', '0935', '0866', 
		'088C', '0880', '091C', '0939', '0366', '0917', '088D', '0890', '085D', '0878', 
		'0955', '0883', '0942', '0870', '0926', '0887', '0815', '0924', '0811', '0963', 
		'088E', '08A0', '088F', '0437', '093D', '094F', '08A5', '092A', '094A', '0950', 
		'0928', '0936', '023B', '0884', '0897', '0919', '087A', '07EC', '0923', '08A3', 
		'0861', '086D', '0931', '086F', '0362', '085F', '0898', '0874', '0964', '095F', 
		'0895', '08AC', '089D', '091A', '0872', '094C', '0899', '088A', '093B', '085A', 
		'0891', '091F', '0892', '02C4', '0894', '0361', '0869', '092B'
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