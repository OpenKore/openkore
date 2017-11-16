#########################################################################
#  OpenKore - Network subsystem
#  Copyright (c) 2006 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# idRO (Indonesia)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::idRORenewal;

use strict;
use Network::Receive::ServerType0;

use base qw(Network::Receive::ServerType0);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'006D' => ['character_creation_successful', 'a4 V9 v V2 v14 Z24 C6 v2', [qw(charID exp zeny exp_job lv_job opt1 opt2 option stance manner points_free hp hp_max sp sp_max walk_speed type hair_style weapon lv points_skill lowhead shield tophead midhead hair_color clothes_color name str agi vit int dex luk slot renameflag)]],
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'099D' => ['received_characters', 'x2 a*', [qw(charInfo)]],
	);
	my %handlers = qw(
		actor_exists 0915
		actor_connected 090F
		actor_moved 0914
		npc_talk 00B4
		actor_status_active 043F
		actor_action 08C8
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	# Sync Ex Reply Array 
	$self->{sync_ex_reply} = {
		'085A', '0884', '085B', '0885', '085C', '0886', '085D', '0887', '085E', '0888', '085F', '0889', '0860', '088A', '0861', '088B', '0862', '088C', '0863',
		'088D', '0864', '088E', '0865', '088F', '0866', '0890', '0867', '0891', '0868', '0892', '0869', '0893', '086A', '0894', '086B', '0895', '086C', '0896', 
		'086D', '0897', '086E', '0898', '086F', '0899', '0870', '089A', '0871', '089B', '0872', '089C', '0873', '089D', '0874', '089E', '0875', '089F', '0876', 
		'08A0', '0877', '08A1', '0878', '08A2', '0879', '08A3', '087A', '08A4', '087B', '08A5', '087C', '08A6', '087D', '08A7', '087E', '08A8', '087F', '08A9', 
		'0880', '08AA', '0881', '08AB', '0882', '08AC', '0883', '08AD', '0917', '0941', '0918', '0942', '0919', '0943', '091A', '0944', '091B', '0945', '091C', 
		'0946', '091D', '0947', '091E', '0948', '091F', '0949', '0920', '094A', '0921', '094B', '0922', '094C', '0923', '094D', '0924', '094E', '0925', '094F', 
		'0926', '0950', '0927', '0951', '0928', '0952', '0929', '0953', '092A', '0954', '092B', '0955', '092C', '0956', '092D', '0957', '092E', '0958', '092F', 
		'0959', '0930', '095A', '0931', '095B', '0932', '095C', '0933', '095D', '0934', '095E', '0935', '095F', '0936', '0960', '0937', '0961', '0938', '0962', 
		'0939', '0963', '093A', '0964', '093B', '0965', '093C', '0966', '093D', '0967', '093E', '0968', '093F', '0969', '0940', '096A',
	};
	
	foreach my $key (keys %{$self->{sync_ex_reply}}) { $packets{$key} = ['sync_request_ex']; }
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

1;
