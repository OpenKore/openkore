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

package Network::Receive::kRO::Sakexe_2007_01_08a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2007_01_02a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2007-01-08aSakexe
packet_ver: 21
0x0072,30,useskilltoid,10:14:26
0x007e,120,useskilltoposinfo,10:19:23:38:40
0x0085,14,changedir,10:13
0x0089,11,ticksend,7
0x008c,17,getcharnamerequest,13
0x0094,17,movetokafra,4:13
0x009b,35,wanttoconnection,7:21:26:30:34
0x009f,21,useitem,7:17
0x00a2,10,solvecharname,6
0x00a7,8,walktoxy,5
0x00f5,11,takeitem,7
0x00f7,15,movefromkafra,3:11
0x0113,40,useskilltopos,10:19:23:38
0x0116,19,dropitem,11:17
0x0190,10,actionrequest,4:9
=cut

1;