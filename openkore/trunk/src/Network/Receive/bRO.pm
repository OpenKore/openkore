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
		'0363', '095E', '0960', '0964', '0940', '0943', '091A', '086A', '0867', '095D', 
		'086D', '0933', '0942', '0866', '0889', '0924', '0871', '0956', '0861', '0921', 
		'0951', '0362', '0864', '088F', '0928', '0815', '087F', '08A9', '0920', '088C', 
		'0952', '089E', '0865', '089F', '0941', '0919', '089C', '0281', '085C', '094F', 
		'094E', '086C', '0873', '0878', '086E', '0947', '089A', '0897', '092C', '083C', 
		'093B', '0887', '087E', '0958', '0876', '095B', '0888', '08A7', '0885', '094B', 
		'089B', '02C4', '0939', '088E', '0862', '0881', '0962', '092F', '0966', '0868', 
		'089D', '0202', '0925', '0877', '0931', '085A', '0360', '0930', '092A', '088B', 
		'0892', '0880', '0883', '023B', '0968', '091F', '091E', '092E', '0926', '0945', 
		'0895', '092D', '0957', '087D', '085B', '0922', '0819', '08AC', '0936', '022D', 
		'0927', '093C', '08AD', '0869', '086B', '08A4', '087A', '0965', '0929', '0438', 
		'0891', '0817', '0938', '0949', '0961', '0950', '093E', '0967', '08AA', '0365', 
		'0923', '0899', '0896', '0894', '0944', '0366', '0436', '0368', '0935', '094D', 
		'086F', '0364', '092B', '08AB', '091D', '0811', '091B', '095A', '0937', '094C', 
		'08A0', '087C', '085D', '0361', '0969', '085E', '0932', '0886', '08A6', '0367', 
		'0437', '091C', '094A', '035F', '0870', '088D', '095C', '0874', '0955', '0872', 
		'088A', '095F', '08A3', '0963', '093F', '093D', '0884', '085F'
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