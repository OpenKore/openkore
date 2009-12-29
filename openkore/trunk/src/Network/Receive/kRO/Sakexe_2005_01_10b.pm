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

package Network::Receive::kRO::Sakexe_2005_01_10b;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2004_12_13a);

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
//2005-01-10bSakexe
packet_ver: 15
0x0072,26,useskilltoid,8:16:22
0x007e,114,useskilltoposinfo,10:18:22:32:34
0x0085,23,changedir,12:22
0x0089,9,ticksend,5
0x008c,8,getcharnamerequest,4
0x0094,20,movetokafra,10:16
0x009b,32,wanttoconnection,3:12:23:27:31
0x009f,17,useitem,5:13
0x00a2,11,solvecharname,7
0x00a7,13,walktoxy,10
0x00f3,-1,globalmessage,2:4
0x00f5,9,takeitem,5
0x00f7,21,movefromkafra,11:17
0x0113,34,useskilltopos,10:18:22:32
0x0116,20,dropitem,15:18
0x0190,20,actionrequest,9:19
0x0193,2,closekafra,0
=cut

1;