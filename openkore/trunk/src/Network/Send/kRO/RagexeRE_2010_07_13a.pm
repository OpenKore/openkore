#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http:#//www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Send::kRO::RagexeRE_2010_07_13a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2010_07_01a);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}
=pod
//2010-07-13aRagexeRE
//0x0827,6
//0x0828,14
//0x0829,6
//0x082A,10
//0x082B,6
//0x082C,14
//0x0840,-1
//0x0841,19
=cut

1;