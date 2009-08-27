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

package Network::Receive::kRO::Sakexe_2005_06_08a;

use strict;
use Network::Receive::kRO::Sakexe_2005_05_31a;
use base qw(Network::Receive::kRO::Sakexe_2005_05_31a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new();
	$self->{packet_list} = {
		'0216' => ['adopt_reply', 'V', [qw(type)]], # 6
		'022F' => ['homunculus_food', 'C v', [qw(success foodID)]], # 5
		'023A' => ['storage_password_request', 'v', [qw(flag)]], # 4
		'023C' => ['storage_password_result', 'v2', [qw(type val)]], # 6
	};
	return $self;
}

=pod
//2005-06-08aSakexe
0x0216,6
0x0217,2,blacksmith,0
0x022f,5
0x0231,26,changehomunculusname,0
0x023a,4
0x023b,24,storagepassword,0
0x023c,6
=cut

1;