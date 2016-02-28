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

package Network::Receive::kRO::RagexeRE_2013_05_22;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2013_05_15a);

1;
=pod
//2013-05-22 Ragexe (Yommy)
//packet_ver: 36
+0x08A2,7,actionrequest,2:6
+0x095C,10,useskilltoid,2:4:6
+0x0360,5,walktoxy,2
+0x07EC,6,ticksend,2
+0x0925,5,changedir,2:4
+0x095E,6,takeitem,2
+0x089C,6,dropitem,2:4
+0x08a3,8,movetokafra,2:4
+0x087E,8,movefromkafra,2:4
+0x0811,10,useskilltopos,2:4:6:8
0x0964,90,useskilltoposinfo,2:4:6:8:10
+0x08a6,6,getcharnamerequest,2
+0x0369,6,solvecharname,2
0x093e,12,searchstoreinfolistitemclick,2:6:10
0x08aa,2,searchstoreinfonextpage,0
0x095b,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0952,-1,reqtradebuyingstore,2:4:8:12
0x0368,6,reqclickbuyingstore,2
0x086E,2,reqclosebuyingstore,0
0x0874,-1,reqopenbuyingstore,2:4:8:9:89
0x089B,18,bookingregreq,2:4:6
//0x0965,8 CZ_JOIN_BATTLE_FIELD
0x086A,-1,itemlistwindowselected,2:4:8:12
+0x08A9,19,wanttoconnection,2:6:10:14:18
+0x0950,26,partyinvite2,2
//0x08AC,4 CZ_GANGSI_RANK
+0x0362,26,friendslistadd,2
+0x0926,5,hommenu,2:4
0x088e,36,storagepassword,2:4:20
=cut