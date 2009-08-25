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

package Network::Send::kRO::Sakexe_2008_01_02a;

use strict;
use Network::Send::kRO::Sakexe_2007_11_27a;
use base qw(Network::Send::kRO::Sakexe_2007_11_27a);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x01df,6,gmreqaccname,2
sub sendGMReqAccName {
	my ($self, $targetID) = @_;
	my $msg = pack('v V', 0x01DF, $targetID);
	$self->sendToServer($msg);
	debug "Sent GM Request Account Name.\n", "sendPacket", 2;
}

=pod
//2008-01-02aSakexe
0x01df,6,gmreqaccname,2
0x02e8,-1
0x02e9,-1
0x02ea,-1
0x02eb,13
0x02ec,67
0x02ed,59
0x02ee,60
0x02ef,8
=cut

1;