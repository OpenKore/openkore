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

package Network::Receive::kRO::Sakexe_2005_09_12b;

use strict;
use Network::Receive::kRO::Sakexe_2005_08_29a;
use base qw(Network::Receive::kRO::Sakexe_2005_08_29a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		'0256' => ['auction_add_item', 'v C', [qw(index fail)]], # 5
		# 0x0258,2
		'0259' => ['gameguard_grant', 'C', [qw(server)]], # 3
	};
	return $self;
}

=pod
//2005-09-12bSakexe
0x0256,5
0x0258,2
0x0259,3
=cut

1;