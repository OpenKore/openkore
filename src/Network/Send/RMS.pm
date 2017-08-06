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
package Network::Send::RMS;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2014_10_22b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	$self->cryptKeys(688214506, 761751195, 731196533);

	return $self;
}

1;