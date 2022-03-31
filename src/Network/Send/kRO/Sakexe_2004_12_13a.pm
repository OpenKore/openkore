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

package Network::Send::kRO::Sakexe_2004_12_13a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2004_11_29a);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2004-12-13aSakexe
//skipped: many packets being set to -1
0x0066,3
0x0070,3
0x01ca,3
0x021e,6
0x021f,66
0x0220,10
=cut

1;