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

package Network::Receive::kRO::RagexeRE_2011_12_20b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2011_11_22a);

1;

=pod
//2011-12-20bRagexeRE
0x01FD,15,repairitem,2
0x0892,26,friendslistadd,2
0x0362,5,hommenu,2:4
0x0897,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x0802,26,partyinvite2,2
0x08A4,19,wanttoconnection,2:6:10:14:18
0x0369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
0x0281,-1,itemlistwindowselected,2:4:8
0x0365,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x0360,6,reqclickbuyingstore,2
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0437,5,walktoxy,2
0x035F,6,ticksend,2
0x0891,5,changedir,2:4
0x07E4,6,takeitem,2
0x022D,6,dropitem,2:4
0x07EC,8,movetokafra,2:4
0x0364,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x08AD,6,getcharnamerequest,2
0x0368,6,solvecharname,2
0x0907,5,moveitem,2:4
0x0908,5
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=cut