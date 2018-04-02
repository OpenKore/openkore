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
package Network::Receive::idRO;

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

	return $self;
}
1;
