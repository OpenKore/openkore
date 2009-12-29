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

package Network::Receive::kRO::RagexeRE_2009_05_20a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2009_05_14a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# //0x07d0,6
		# //0x07d1,2
		# //0x07d2,-1
		# //0x07d3,4
		# //0x07d4,4
		# //0x07d5,4
		# //0x07d6,4
		# //0x0447,2
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}


=pod
//2009-05-20aRagexeRE
//0x07d0,6
//0x07d1,2
//0x07d2,-1
//0x07d3,4
//0x07d4,4
//0x07d5,4
//0x07d6,4
//0x0447,2
=cut

1;