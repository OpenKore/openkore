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

package Network::Send::kRO::Sakexe_2005_08_17a;

use strict;
use Network::Send::kRO::Sakexe_2005_08_08a;
use base qw(Network::Send::kRO::Sakexe_2005_08_08a);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendFeelSaveOk {
	my ($self, $flag) = @_;
	my $msg = pack('v C', 0x0254, $flag);
	$self->sendToServer($msg);
	debug "Sent FeelSaveOk.\n", "sendPacket", 2;
}

=pod
0x0253,3
0x0254,3,feelsaveok,0
=cut

1;