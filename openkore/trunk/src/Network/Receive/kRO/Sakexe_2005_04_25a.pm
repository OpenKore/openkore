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

package Network::Receive::kRO::Sakexe_2005_04_25a;

use strict;
use Network::Receive::kRO::Sakexe_2005_04_11a;
use base qw(Network::Receive::kRO::Sakexe_2005_04_11a);

use Log qw(message warning error debug);
use Utils qw(getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2005-04-25aSakexe
0x022d,5,hommenu,4
0x0232,9,hommoveto,6
0x0233,11,homattack,0
0x0234,6,hommovetomaster,0
=cut

1;