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

package Network::Send::kRO::Sakexe_2009_04_08a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2009_03_30a);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x044a,6
# not used yet
sub sendClientVersion {
	my ($self, $version) = @_;
	my $msg = pack('v V', 0x044a, $version);
	$self->sendToServer($msg);
}

=pod
//2009-04-08aSakexe
0x02a6,-1
0x02a7,-1
0x044a,6
=cut

1;