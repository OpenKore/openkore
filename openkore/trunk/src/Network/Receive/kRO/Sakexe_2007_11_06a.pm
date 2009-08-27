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

package Network::Receive::kRO::Sakexe_2007_11_06a;

use strict;
use Network::Receive::kRO::Sakexe_2007_10_23a;
use base qw(Network::Receive::kRO::Sakexe_2007_10_23a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		'0078' => ['actor_display',	'x a4 v14 a4 a2 v2 C2 a3 C3 v',				[qw(ID walk_speed opt1 opt2 option type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 act lv)]], # 55 #standing
		'007C' => ['actor_display',	'x a4 v14 C2 a3 C2',						[qw(ID walk_speed opt1 opt2 option hair_style weapon lowhead type shield tophead midhead hair_color clothes_color head_dir karma sex coords unknown1 unknown2)]], #spawning (eA does not send this for players) # 42
		'022C' => ['actor_display', 'x a4 v3 V v5 V v5 a4 a2 v V C2 a5 x C2 v',	[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID manner opt3 karma sex coords unknown1 unknown2 lv)]], # walking # 65
		'029B' => ['homunculus_stats', 'a4 v8 Z24 v V5 v V2 v',	[qw(ID atk matk hit critical def mdef flee aspd name lv hp hp_max sp sp_max contract_end faith summons kills range)]], # 80
	};
	return $self;
}


=pod
//2007-11-06aSakexe
0x0078,55
0x007c,42
0x022c,65
0x029b,80
=cut

1;