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

package Network::Receive::kRO::Sakexe_2007_01_29a;

use strict;
use base qw(Network::Receive::kRO::Sakexe_2007_01_22a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'029B' => ['homunculus_stats', 'a4 v8 Z24 v5 V v2', [qw(ID atk matk hit critical def mdef flee aspd name lv hp hp_max sp sp_max contract_end faith summons)]], # 72
		# 0x02a3,0
		# 0x02a4,0
		# 0x02a5 is sent packet
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}



=pod
//2007-01-29aSakexe
0x029b,72
0x02a3,0
0x02a4,0
0x02a5,8
=cut

1;