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

package Network::Receive::kRO::Sakexe_2005_03_28a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2005_01_10b);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0224' => ['taekwon_rank', 'V2', [qw(type rank)]], # 10 # TODO: test if this gives the right results
		# 0225 is sent packet
		'0226' => ['top10_taekwon_rank'], # 282 # TODO: check if len matches the unpacking
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2005-03-28aSakexe
0x0224,10
0x0225,2,taekwon,0
0x0226,282
=cut

1;