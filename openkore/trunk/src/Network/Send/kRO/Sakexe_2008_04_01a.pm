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

package Network::Send::kRO::Sakexe_2008_04_01a;

use strict;
use Network::Send::kRO::Sakexe_2008_03_25b;
use base qw(Network::Send::kRO::Sakexe_2008_03_25b);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2008-04-01aSakexe
0x0301,-1
0x0302,-1
0x0303,-1
0x0304,-1
0x0305,-1
0x0306,-1
0x0307,-1
0x0308,-1
0x0309,-1
0x030a,-1
0x030b,-1
0x030c,-1
0x030d,-1
0x030e,-1
0x030f,-1
0x0310,-1
0x0311,-1
0x0312,-1
0x0313,-1
0x0314,-1
0x0315,-1
0x0316,-1
0x0317,-1
0x0318,-1
0x0319,-1
0x031a,-1
0x031b,-1
0x031c,-1
0x031d,-1
0x031e,-1
0x031f,-1
0x0320,-1
0x0321,-1
0x0322,-1
0x0323,-1
0x0324,-1
0x0325,-1
0x0326,-1
0x0327,-1
0x0328,-1
0x0329,-1
0x032a,-1
0x032b,-1
0x032c,-1
0x032d,-1
0x032e,-1
0x032f,-1
0x0330,-1
0x0331,-1
0x0332,-1
0x0333,-1
0x0334,-1
0x0335,-1
0x0336,-1
0x0337,-1
0x0338,-1
0x0339,-1
0x033a,-1
0x033b,-1
0x033c,-1
0x033d,-1
0x033e,-1
0x033f,-1
0x0340,-1
0x0341,-1
0x0342,-1
0x0343,-1
0x0344,-1
0x0345,-1
0x0346,-1
0x0347,-1
0x0348,-1
0x0349,-1
0x034a,-1
0x034b,-1
0x034c,-1
0x034d,-1
0x034e,-1
0x034f,-1
0x0350,-1
0x0351,-1
0x0352,-1
0x0353,-1
0x0354,-1
0x0355,-1
0x0356,-1
0x0357,-1
0x0358,-1
0x0359,-1
0x035a,-1
=cut

1;