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

package Network::Send::kRO::Sakexe_2007_05_07a;

use strict;
use Network::Send::kRO::Sakexe_2007_02_12a;
use base qw(Network::Send::kRO::Sakexe_2007_02_12a);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x01fd,15,repairitem,2
sub sendRepairItem {
	my ($self, $args) = @_;
	my $msg = pack('v3 V2 C', 0x01FD, $args->{index}, $args->{nameID}, $args->{status}, $args->{status2}, $args->{listID});
	$self->sendToServer($msg);
	debug ("Sent repair item: ".$args->{index}."\n", "sendPacket", 2);
}

=pod
//2007-05-07aSakexe
0x01fd,15,repairitem,2
=cut

1;