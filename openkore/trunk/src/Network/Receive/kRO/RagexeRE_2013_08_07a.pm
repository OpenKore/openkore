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

package Network::Receive::kRO::RagexeRE_2013_08_07a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2013_03_20);

1;

=pod
0x369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x437,5,walktoxy,2
0x035F,6,ticksend,2
0x202,5,changedir,2:4
0x70000,6,takeitem,2
0x362,6,dropitem,2:4
0x07EC,8,movetokafra,2:4
0x364,8,movefromkafra,2:4
0x438,10,useskilltopos,2:4:6:8
0x366,90,useskilltoposinfo,2:4:6:8:10
0x096A,6,getcharnamerequest,2
0x368,6,solvecharname,2
0x838,12,searchstoreinfolistitemclick,2:6:10
0x835,2,searchstoreinfonextpage,0
0x819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x811,-1,reqtradebuyingstore,2:4:8:12
0x360,6,reqclickbuyingstore,2
0x817,2,reqclosebuyingstore,0
0x815,-1,reqopenbuyingstore,2:4:8:9:89
0x365,18,bookingregreq,2:4:6
// 0x363,8 CZ_JOIN_BATTLE_FIELD
0x281,-1,itemlistwindowselected,2:4:8:12
0x022D,19,wanttoconnection,2:6:10:14:18
0x802,26,partyinvite2,2
// 0x436,4 CZ_GANGSI_RANK
0x023B,26,friendslistadd,2
0x361,5,hommenu,2:4
0x887,36,storagepassword,2:4:20
=cut