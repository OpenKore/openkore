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

package Network::Send::kRO::Sakexe_2008_08_20a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2008_05_27a);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

=pod
//2008-08-20aSakexe
0x040c,-1
0x040d,-1
0x040e,-1
0x040f,-1
0x0410,-1
0x0411,-1
0x0412,-1
0x0413,-1
0x0414,-1
0x0415,-1
0x0416,-1
0x0417,-1
0x0418,-1
0x0419,-1
0x041a,-1
0x041b,-1
0x041c,-1
0x041d,-1
0x041e,-1
0x041f,-1
0x0420,-1
0x0421,-1
0x0422,-1
0x0423,-1
0x0424,-1
0x0425,-1
0x0426,-1
0x0427,-1
0x0428,-1
0x0429,-1
0x042a,-1
0x042b,-1
0x042c,-1
0x042d,-1
0x042e,-1
0x042f,-1
0x0430,-1
0x0431,-1
0x0432,-1
0x0433,-1
0x0434,-1
0x0435,-1
=cut

1;