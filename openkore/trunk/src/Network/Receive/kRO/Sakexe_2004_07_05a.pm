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

package Network::Receive::kRO::Sakexe_2004_07_05a;

use strict;
use Network::Receive::kRO::Sakexe_0;
use base qw(Network::Receive::kRO::Sakexe_0);

use Log qw(message warning error debug);
use Utils qw(getTickCount getCoordString);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		# 0x020e,24
	};
	return $self;
}

=pod
//2004-07-05aSakexe
packet_ver: 6
0x0072,22,wanttoconnection,5:9:13:17:21
0x0085,8,walktoxy,5
0x00a7,13,useitem,5:9
0x0113,15,useskilltoid,4:9:11
0x0116,15,useskilltopos,4:9:11:13
0x0190,95,useskilltoposinfo,4:9:11:13:15
0x0208,14,friendslistreply,2:6:10
0x020e,24
=cut

1;