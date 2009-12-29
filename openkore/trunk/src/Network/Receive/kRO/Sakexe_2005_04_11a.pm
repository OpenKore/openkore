#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
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

package Network::Receive::kRO::Sakexe_2005_04_11a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2005_04_04a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0229' => ['character_status', 'a4 v2 V C', [qw(ID opt1 opt2 option karma)]], # 15
		'022A' => ['actor_display', 'a4 v3 V v10 a4 a2 v V C2 a3 C3 v',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], # 58 # standing
		'022B' => ['actor_display', 'a4 v3 V v10 a4 a2 v V C2 a3 C2 v',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # 57 # spawning
		'022C' => ['actor_display', 'a4 v3 V v5 V v5 a4 a2 v V C2 a5 x C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # 64 # walking
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2005-04-11aSakexe
0x0229,15
0x022a,58
0x022b,57
0x022c,64
=cut

1;