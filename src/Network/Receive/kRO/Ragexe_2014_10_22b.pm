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
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::Ragexe_2014_10_22b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2013_08_07a);

sub new {
   my ($class) = @_;
   my $self = $class->SUPER::new(@_);
   my %packets = (
       '0A18' => ['map_loaded', 'V a3 C2 v C', [qw(syncMapSync coords xSize ySize font sex)]], # 13
       '0984' => ['actor_status_active', 'a4 v V5', [qw(ID type tick unknown1 unknown2 unknown3 unknown4)]], # 28
       '097A' => ['quest_all_list2', 'v3 a*', [qw(len count unknown message)]],
       '09DB' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
       '09DC' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
       '09DD' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font opt4 name)]],
       '09DE' => ['private_message', 'v V Z25 Z*', [qw(len charID privMsgUser privMsg)]],
       '09DF' => ['private_message_sent', 'C V', [qw(type charID)]],
       '0A00' => ['hotkeys'],
	   '08C8' => ['actor_action', 'a4 a4 a4 V3 C v C V', [qw(sourceID targetID tick src_speed dst_speed damage sp_damage div type dual_wield_damage)]],
       );
  
   foreach my $switch (keys %packets) {
       $self->{packet_list}{$switch} = $packets{$switch};
   }

   return $self;
}

1;
