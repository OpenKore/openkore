#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2010_11_24a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_08_03a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0856' => ['actor_exists', 'v C a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # walking provided by try71023 TODO: costume
		'0857' => ['actor_connected', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font name)]], # -1 # spawning provided by try71023
		'0858' => ['actor_moved', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # standing provided by try71023
		# 0x0859,-1
	);
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}
	
	return $self;
}

1;

=cut
//2010-11-24aRagexeRE
0x01FD,15,repairitem,2
0x0202,26,friendslistadd,2
0x022D,5,hommenu,2:4
0x023B,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x02C4,26,partyinvite2,2
0x0436,19,wanttoconnection,2:6:10:14:18
0x0437,7,actionrequest,2:6
0x0438,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x07E4,-1,itemlistwindowselected,2:4:8
0x0802,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
0x0811,-1,reqopenbuyingstore,2:4:8:9:89
0x0815,2,reqclosebuyingstore,0
0x0817,6,reqclickbuyingstore,2
0x0819,-1,reqtradebuyingstore,2:4:8:12
0x0835,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0838,2,searchstoreinfonextpage,0
0x083C,12,searchstoreinfolistitemclick,2:6:10
0x035F,5,walktoxy,2
0x0360,6,ticksend,2
0x0361,5,changedir,2:4
0x0362,6,takeitem,2
0x0363,6,dropitem,2:4
0x0364,8,movetokafra,2:4
0x0365,8,movefromkafra,2:4
0x0366,10,useskilltopos,2:4:6:8
0x0367,90,useskilltoposinfo,2:4:6:8:10
0x0368,6,getcharnamerequest,2
0x0369,6,solvecharname,2
=pod