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

package Network::Send::kRO::Sakexe_2006_01_09a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2005_11_07a);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2006-01-09aSakexe
0x0261,11
0x0262,11
0x0263,11
0x0264,20
0x0265,20
0x0266,30
0x0267,4
0x0268,4
0x0269,4
0x026a,4
0x026b,4
0x026c,4
0x026d,4
0x026f,2
0x0270,2
0x0271,38
0x0272,44
=cut

1;