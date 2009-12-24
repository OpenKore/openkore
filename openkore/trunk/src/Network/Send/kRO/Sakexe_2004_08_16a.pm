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

package Network::Send::kRO::Sakexe_2004_08_16a;

use strict;
use Network::Send::kRO::Sakexe_2004_08_09a;
use base qw(Network::Send::kRO::Sakexe_2004_08_09a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0212,26,rc,2
sub sendGMGiveMannerByName {
	my ($self, $playerName) = @_;
	my $packet = pack('v a24', 0x0212, stringToBytes($playerName));
	$self->sendToServer($packet);
}

# 0x0213,26,check,2
sub sendGMRequestStatus {
	my ($self, $playerName) = @_;
	my $packet = pack('v a24', 0x0213, stringToBytes($playerName));
	$self->sendToServer($packet);
}
=pod
//2004-08-16aSakexe
0x0212,26,rc,2
0x0213,26,check,2
=cut

1;