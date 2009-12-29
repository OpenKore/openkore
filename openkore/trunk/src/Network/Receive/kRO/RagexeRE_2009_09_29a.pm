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

package Network::Receive::kRO::RagexeRE_2009_09_29a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2009_09_22a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# //0x07ea,2
		# //0x07eb,0
		# //0x07ec,6
		# //0x07ed,8
		# //0x07ee,6
		# //0x07ef,8
		# //0x07f0,4
		# //0x07f2,4
		# //0x07f3,3
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}


=pod
//2009-09-29aRagexeRE
//0x07ea,2
//0x07eb,0
//0x07ec,6
//0x07ed,8
//0x07ee,6
//0x07ef,8
//0x07f0,4
//0x07f2,4
//0x07f3,3
=cut

1;