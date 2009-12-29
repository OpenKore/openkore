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

package Network::Receive::kRO::RagexeRE_2008_09_10a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2008_08_27a);

use Log qw(message warning error debug);
use Utils qw(getTickCount);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		# 0x0436 is sent packet
		# 0x0437 is sent packet
		# 0x0438 is sent packet
		# 0x0439 is sent packet
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2008-09-10aRagexeRE
packet_ver: 24
0x0436,19,wanttoconnection,2:6:10:14:18
0x0437,7,actionrequest,2:6
0x0438,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4
=cut

1;