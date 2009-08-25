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

package Network::Send::kRO::Sakexe_2005_05_30a;

use strict;
use Network::Send::kRO::Sakexe_2005_05_23a;
use base qw(Network::Send::kRO::Sakexe_2005_05_23a);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0237,2,rankingpk,0
sub sendTop10PK {
	my $self = shift;
	my $msg = pack('v', 0x0237);
	$self->sendToServer($msg);
	debug "Sent Top 10 PK request\n", "sendPacket", 2;	
}

=pod
//2005-05-30aSakexe
0x022e,71
0x0235,-1
0x0236,10
0x0237,2,rankingpk,0
0x0238,282
=cut

1;