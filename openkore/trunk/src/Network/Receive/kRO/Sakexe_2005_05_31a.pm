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

package Network::Receive::kRO::Sakexe_2005_05_31a;

use strict;
use Network::Receive::kRO::Sakexe_2005_05_30a;
use base qw(Network::Receive::kRO::Sakexe_2005_05_30a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		# 0x0216,2
		'0239' => ['skill_update', 'v4 C', [qw(skillID lv sp range up)]], # 11 # range = skill range, up = this skill can be leveled up further
	};
	return $self;
}

=pod
//2005-05-31aSakexe
0x0216,2
0x0239,11
=cut

1;