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
########################################################################
#  by alisonrag
package Network::Send::kRO::RagexeRE_2020_07_23;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2020_04_01b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	return $self;
}

1;
