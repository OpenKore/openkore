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

package Network::Receive::kRO::RagexeRE_2015_09_16;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_05_13a);

1;

=pod
//2015-09-16Ragexe
packet_ver: 53
packet_keys: 0x17F83A19,0x116944F4,0x1CC541E9 // [Napster]
0x0869,7,actionrequest,2:6
0x093E,10,useskilltoid,2:4:6
0x0877,5,walktoxy,2
0x08AC,6,ticksend,2
0x0936,5,changedir,2:4
0x089C,6,takeitem,2
0x092F,6,dropitem,2:4
0x0934,8,movetokafra,2:4
0x085E,8,movefromkafra,2:4
0x022D,10,useskilltopos,2:4:6:8
0x0873,90,useskilltoposinfo,2:4:6:8:10
0x095A,6,getcharnamerequest,2
0x0942,6,solvecharname,2
0x087F,12,searchstoreinfolistitemclick,2:6:10
0x0817,2,searchstoreinfonextpage,0
0x0920,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0881,-1,reqtradebuyingstore,2:4:8:12
0x0835,6,reqclickbuyingstore,2
0x092E,2,reqclosebuyingstore,0
0x0948,-1,reqopenbuyingstore,2:4:8:9:89
0x089B,18,bookingregreq,2:4:6
// 0x094F,8 CZ_JOIN_BATTLE_FIELD
0x0961,-1,itemlistwindowselected,2:4:8:12
0x0969,19,wanttoconnection,2:6:10:14:18
0x0924,26,partyinvite2,2
// 0x0938,4 CZ_GANGSI_RANK
0x089E,26,friendslistadd,2
0x0960,5,hommenu,2:4
0x0941,36,storagepassword,2:4:20

// New Packet
0x097F,-1		// ZC_SELECTCART
0x0980,7,selectcart,2:6	// CZ_SELECTCART


=cut