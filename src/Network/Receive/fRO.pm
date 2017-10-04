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
# fRO (France)
# 2010-06-17aRagexe
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::fRO;

use strict;
use base 'Network::Receive::ServerType0';

use Globals qw( $messageSender );

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0915' => ['actor_exists', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 a9 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font opt4 name)]],
		'090F' => ['actor_connected', 'C a4 v14 C2 a3 C2', [qw(object_type ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords unknown1 unknown2)]], # 42 # spawning
		'0097' => ['private_message', 'v Z24 V Z*', [qw(len privMsgUser flag privMsg)]], # -1
		'0914' => ['actor_moved', 'v C a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 a9 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

1;
