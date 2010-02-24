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

package Network::Receive::kRO::Sakexe_2008_01_02a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2007_11_27a);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'02E8' => ['inventory_items_stackable'], # -1
		'02E9' => ['cart_items_stackable'], # -1
		'02EA' => ['storage_items_stackable'], # -1
		'02EB' => ['map_loaded', 'V a3 x2 v', [qw(syncMapSync coords unknown)]], # 13
		'02EC' => ['actor_display', 'C a4 v3 V v5 V v5 a4 a4 V C2 a6 C2 v2',	[qw(object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 karma sex coords xSize ySize lv font)]], # 67 # Moving # TODO: C struct is different
		'02ED' => ['actor_display', 'a4 v3 V v10 a4 a4 V C2 a3 C2 v2',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 karma sex coords xSize ySize lv font)]], # 59 # Spawning
		'02EE' => ['actor_display', 'a4 v3 V v10 a4 a4 V C2 a3 C3 v2',			[qw(ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir guildID emblemID opt3 karma sex coords xSize ySize act lv font)]], # 60 # Standing
		'02EF' => ['font', 'a4 v', [qw(ID fontID)]], # 8
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}


=pod
//2008-01-02aSakexe
0x01df,6,gmreqaccname,2
0x02e8,-1
0x02e9,-1
0x02ea,-1
0x02eb,13
0x02ec,67
0x02ed,59
0x02ee,60
0x02ef,8
=cut

1;