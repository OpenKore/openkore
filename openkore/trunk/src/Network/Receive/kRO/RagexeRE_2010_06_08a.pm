#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
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

package Network::Receive::kRO::RagexeRE_2010_06_08a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_06_01a);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}
=pod
//2010-06-08aRagexeRE
//0x0838,2
//0x0839,66
//0x083A,4      // Search Stalls Feature
//0x083B,2
//0x083C,12
//0x083D,6
=cut

1;