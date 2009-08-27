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

package Network::Receive::kRO::Sakexe_2005_05_30a;

use strict;
use Network::Receive::kRO::Sakexe_2005_05_23a;
use base qw(Network::Receive::kRO::Sakexe_2005_05_23a);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'022E' => ['homunculus_stats', 'Z24 C v16 V2 v2', [qw(name state lv hunger intimacy accessory atk matk hit critical def mdef flee aspd hp hp_max sp sp_max exp exp_max points_skill unknown)]], # 71
		'0235' => ['skills_list'], # -1 # homunculus skills
		# 0x0236,10
		'0238' => ['top10_pk_rank'], #  282
	);
	
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

=pod
//2005-05-30aSakexe
0x022e,71
0x0235,-1
0x0236,10
0x0237,2,rankingpk,0
0x0238,282
=cut

1;