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

package Network::Receive::kRO::RagexeRE_2012_06_18a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2012_05_15a);

1;

=cut
0x01FD,15,repairitem,2
0x023B,26,friendslistadd,2
0x0361,5,hommenu,2:4
0x0819,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x0802,26,partyinvite2,2
0x022D,19,wanttoconnection,2:6:10:14:18
0x0369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x0281,-1,itemlistwindowselected,2:4:8
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x0360,6,reqclickbuyingstore,2
0x0940,-1,reqtradebuyingstore,2:4:8:12
0x0811,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0437,5,walktoxy,2
0x035F,6,ticksend,2
0x0202,5,changedir,2:4
0x07E4,6,takeitem,2
0x0362,6,dropitem,2:4
0x07EC,8,movetokafra,2:4
0x0364,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x096A,6,getcharnamerequest,2
0x0368,6,solvecharname,2
0x08E5,41,bookingregreq,2:4
0x08E6,4
0x08E7,10,bookingsearchreq,2
0x08E8,-1
0x08E9,2,bookingdelreq,2
0x08EA,4
0x08EB,39,bookingupdatereq,2
0x08EC,73
0x08ED,43
0x08EE,6
0x08EF,6,bookingignorereq,2
0x08F0,6
0x08F1,6,bookingjoinpartyreq,2
0x08F2,36
0x08F3,-1
0x08F4,6
0x08F5,-1,bookingsummonmember,2:4
0x08F6,22
0x08F7,3
0x08F8,7
0x08F9,6
0x08FA,6
0x08FB,6,bookingcanceljoinparty,2
0x0907,5,moveitem,2:4
0x0908,5
0x08D7,28,battlegroundreg,2:4
0x08CF,10
0x08d2,10
0x0977,14
0x0983,29
0x08c9,2
=pod