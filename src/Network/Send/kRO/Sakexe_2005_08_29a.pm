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

package Network::Send::kRO::Sakexe_2005_08_29a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2005_08_17a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendMailSend {
	my ($self, $receiver, $title, $message) = @_;
	my $msg = pack('v2 Z24 a40 C Z*', 0x0248, length($message)+70 , stringToBytes($receiver), stringToBytes($title), length($message), stringToBytes($message));
	$self->sendToServer($msg);
	debug "Sent mail send.\n", "sendPacket", 2;
}

=pod
//2005-08-29aSakexe
0x0240,-1
0x0248,-1,mailsend,2:4:28:68
0x0255,5
0x0256,0
0x0257,8
=cut

1;