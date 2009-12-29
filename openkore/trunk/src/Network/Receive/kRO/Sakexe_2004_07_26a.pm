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

package Network::Receive::kRO::Sakexe_2004_07_26a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2004_07_13a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char %config);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2004-07-26aSakexe
packet_ver: 8
0x0072,14,dropitem,5:12
0x007e,33,wanttoconnection,12:18:24:28:32
0x0085,20,useskilltoid,7:12:16
0x0089,15,getcharnamerequest,11
0x008c,23,useskilltopos,3:6:17:21
0x0094,10,takeitem,6
0x009b,6,walktoxy,3
0x009f,13,changedir,5:12
0x00a2,103,useskilltoposinfo,3:6:17:21:23
0x00a7,12,solvecharname,8
0x00f3,-1,globalmessage,2:4
0x00f5,17,useitem,6:12
0x00f7,10,ticksend,6
0x0113,16,movetokafra,5:12
0x0116,2,closekafra,0
0x0190,26,movefromkafra,10:22
0x0193,9,actionrequest,3:8
=cut

1;