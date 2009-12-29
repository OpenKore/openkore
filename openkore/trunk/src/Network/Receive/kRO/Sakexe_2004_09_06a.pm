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

package Network::Receive::kRO::Sakexe_2004_09_06a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2004_08_17a);

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
//2004-09-06aSakexe
packet_ver: 10
0x0072,20,useitem,9:20
0x007e,19,movetokafra,3:15
0x0085,23,actionrequest,9:22
0x0089,9,walktoxy,6
0x008c,105,useskilltoposinfo,10:14:18:23:25
0x0094,17,dropitem,6:15
0x009b,14,getcharnamerequest,10
0x009f,-1,globalmessage,2:4
0x00a2,14,solvecharname,10
0x00a7,25,useskilltopos,10:14:18:23
0x00f3,10,changedir,4:9
0x00f5,34,wanttoconnection,7:15:25:29:33
0x00f7,2,closekafra,0
0x0113,11,takeitem,7
0x0116,11,ticksend,7
0x0190,22,useskilltoid,9:15:18
0x0193,17,movefromkafra,3:13
=cut

1;