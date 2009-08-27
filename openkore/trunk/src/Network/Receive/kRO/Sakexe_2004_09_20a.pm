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

package Network::Receive::kRO::Sakexe_2004_09_20a;

use strict;
use Network::Receive::kRO::Sakexe_2004_09_06a;
use base qw(Network::Receive::kRO::Sakexe_2004_09_06a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2004-09-20aSakexe
packet_ver: 11
0x0072,18,useitem,10:14
0x007e,25,movetokafra,6:21
0x0085,9,actionrequest,3:8
0x0089,14,walktoxy,11
0x008c,109,useskilltoposinfo,16:20:23:27:29
0x0094,19,dropitem,12:17
0x009b,10,getcharnamerequest,6
0x00a2,10,solvecharname,6
0x00a7,29,useskilltopos,6:20:23:27
0x00f3,18,changedir,8:17
0x00f5,32,wanttoconnection,10:17:23:27:31
0x0113,14,takeitem,10
0x0116,14,ticksend,10
0x0190,14,useskilltoid,4:7:10
0x0193,12,movefromkafra,4:8
=cut

1;