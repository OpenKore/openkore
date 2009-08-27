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

package Network::Receive::kRO::Sakexe_2004_07_13a;

use strict;
use Network::Receive::kRO::Sakexe_2004_07_05a;
use base qw(Network::Receive::kRO::Sakexe_2004_07_05a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2004-07-13aSakexe
packet_ver: 7
0x0072,39,wanttoconnection,12:22:30:34:38
0x0085,9,walktoxy,6
0x009b,13,changedir,5:12
0x009f,10,takeitem,6
0x00a7,17,useitem,6:13
0x0113,19,useskilltoid,7:9:15
0x0116,19,useskilltopos,7:9:15:17
0x0190,99,useskilltoposinfo,7:9:15:17:19
=cut

1;