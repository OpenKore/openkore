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
	'0281', '08A7', '0932', '08A2', '0950', '0897', '088C', '0890', '0815', '0922', '0931', '0896', '0946', '0935', '0925', '087D', '0959', '091F', '0867', '0895', '085B', '093F', '0817', '0884', '0952', '0963', '087E', '092C', '095F', '094C', '08A9', '094B', '0953', '086B', '087F', '0860', '0437', '0882', '0964', '0938', '0936', '07E4', '0369', '0868', '0954', '0893', '092A', '08A1', '0923', '0924', '092E', '086A', '087C', '0865', '088E', '022D', '0835', '094A', '0967', '0918', '089E', '085F', '0885', '095A', '0939', '0872', '0949', '086E', '0960', '089B', '093B', '091C', '0957', '0876', '0866', '094E', '087A', '0864', '08AB', '0899', '0819', '08A6', '08A3', '0367', '0969', '0942', '02C4', '0894', '088F', '093C', '08AD', '0368', '0202', '095E', '0362', '0889', '08A5', '091D', '088A', '094D', '0886', '0951', '087B', '092F', '092B', '0878', '0861', '0934', '0933', '035F', '0877', '07EC', '0956', '0948', '0365', '0863', '0438', '085E', '0361', '0883', '0961', '0871', '0862', '0962', '0919', '0965', '0928', '0943', '0888', '0880', '091B', '095B', '094F', '093A', '088D', '095C', '0898', '0873', '0891', '0811', '0927', '0955', '0966', '023B', '0920', '089D', '0944', '089F', '08A0', '0929', '0363', '0958', '0917', '0870', '089A', '091A', '0892', '0945', '0875', '0838', '083C', '0869', '0941', '096A', '08A4', '086F', '08AC', '0930'
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