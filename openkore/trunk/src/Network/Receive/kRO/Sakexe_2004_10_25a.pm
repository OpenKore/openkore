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

package Network::Receive::kRO::Sakexe_2004_10_25a;

use strict;
use Network::Receive::kRO::Sakexe_2004_10_05a;
use base qw(Network::Receive::kRO::Sakexe_2004_10_05a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2004-10-25aSakexe
packet_ver: 13
0x0072,13,useitem,5:9
0x007e,13,movetokafra,6:9
0x0085,15,actionrequest,4:14
0x008c,108,useskilltoposinfo,6:9:23:26:28
0x0094,12,dropitem,6:10
0x009b,10,getcharnamerequest,6
0x00a2,16,solvecharname,12
0x00a7,28,useskilltopos,6:9:23:26
0x00f3,15,changedir,6:14
0x00f5,29,wanttoconnection,5:14:20:24:28
0x0113,9,takeitem,5
0x0116,9,ticksend,5
0x0190,26,useskilltoid,4:10:22
0x0193,22,movefromkafra,12:18
=cut

1;