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

package Network::Receive::kRO::Sakexe_2007_10_23a;

use strict;
use Network::Receive::kRO::Sakexe_2007_10_02a;
use base qw(Network::Receive::kRO::Sakexe_2007_10_02a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		'02CB' => ['instance_window_start', 'Z61 v', [qw(name flag)]], # 65
		'02CD' => ['instance_window_join', 'Z61 V2', [qw(name time_remaining time_close)]], # 71
	};
	return $self;
}


=pod
//2007-10-23aSakexe
0x02cb,65
0x02cd,71
=cut

1;