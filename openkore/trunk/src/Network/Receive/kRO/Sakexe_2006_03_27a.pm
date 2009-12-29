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

package Network::Receive::kRO::Sakexe_2006_03_27a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2006_03_13a);

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
//2006-03-27aSakexe
packet_ver: 20
0x0072,26,useskilltoid,11:18:22
0x007e,120,useskilltoposinfo,5:15:29:38:40
0x0085,12,changedir,7:11
//0x0089,13,ticksend,9
0x008c,12,getcharnamerequest,8
0x0094,23,movetokafra,5:19
0x009b,37,wanttoconnection,9:21:28:32:36
0x009f,24,useitem,9:20
0x00a2,11,solvecharname,7
0x00a7,15,walktoxy,12
0x00f5,13,takeitem,9
0x00f7,26,movefromkafra,11:22
0x0113,40,useskilltopos,5:15:29:38
0x0116,17,dropitem,8:15
0x0190,18,actionrequest,7:17
=cut

1;