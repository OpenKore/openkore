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

package Network::Receive::kRO::RagexeRE_2015_10_01b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_05_13a);

1;

=pod
//2015-10-01bRagexeRE
packet_ver: 54
packet_keys: 0x45B945B9,0x45B945B9,0x45B945B9	// [Dastgir]
0x035f,6,ticksend,2
0x07e4,6,takeitem,2
0x0362,6,dropitem,2:4
0x07ec,8,movetokafra,2:4
0x0364,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposmoreinfo,2:4:6:8:10
0x0368,6,solvecharname,2
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0835,2,searchstoreinfonextpage,0
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0360,6,reqclickbuyingstore,2
0x0817,2,reqclosebuyingstore,0
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0365,18,partybookingregisterreq,2:4:6
//0x0363,8 // CZ_JOIN_BATTLE_FIELD
0x0281,-1,itemlistwindowselected,2:4:8:12
0x022d,19,wanttoconnection,2:6:10:14:18
0x0802,26,partyinvite2,2
//0x0436,4 // CZ_GANGSI_RANK
0x023b,26,friendslistadd,2
0x0361,5,hommenu,2:4
0x0860,36,storagepassword,2:4:20
=cut