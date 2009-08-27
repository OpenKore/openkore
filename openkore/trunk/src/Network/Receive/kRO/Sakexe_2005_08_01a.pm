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

package Network::Receive::kRO::Sakexe_2005_08_01a;

use strict;
use Network::Receive::kRO::Sakexe_2005_07_19b;
use base qw(Network::Receive::kRO::Sakexe_2005_07_19b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		'0245' => ['mail_getattachment', 'C', [qw(fail)]], # 3

		# 0x0251,4
	};
	return $self;
}

=pod
//2005-08-01aSakexe
0x0245,3
0x0251,4
=cut

1;