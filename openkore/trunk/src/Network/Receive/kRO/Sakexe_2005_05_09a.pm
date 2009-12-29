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

package Network::Receive::kRO::Sakexe_2005_05_09a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2005_04_25a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2005-05-09aSakexe
packet_ver: 16
0x0072,25,useskilltoid,6:10:21
0x007e,102,useskilltoposinfo,5:9:12:20:22
0x0085,11,changedir,7:10
0x0089,8,ticksend,4
0x008c,11,getcharnamerequest,7
0x0094,14,movetokafra,7:10
0x009b,26,wanttoconnection,4:9:17:18:25
0x009f,14,useitem,4:10
0x00a2,15,solvecharname,11
0x00a7,8,walktoxy,5
0x00f5,8,takeitem,4
0x00f7,22,movefromkafra,14:18
0x0113,22,useskilltopos,5:9:12:20
0x0116,10,dropitem,5:8
0x0190,19,actionrequest,5:18
=cut

1;