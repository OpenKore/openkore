#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::Sakexe_2007_11_06a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2007_10_23a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0078' => ['actor_exists', 'C a4 v14 a4 a2 v2 C2 a3 C3 v', [qw(object_type_not_used ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 act lv)]], # 55 # standing
		'007C' => ['actor_connected', 'C a4 v14 C2 a3 C2', [qw(object_type_not_used ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir stance sex coords unknown1 unknown2)]], # 42 # spawning
		'022C' => ['actor_moved', 'C a4 v3 V v5 V v5 a4 a2 v V C2 a6 C2 v',	[qw(object_type_not_used ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 stance sex coords unknown1 unknown2 lv)]], # 65 # walking
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

1;