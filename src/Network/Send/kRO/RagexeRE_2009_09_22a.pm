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

package Network::Send::kRO::RagexeRE_2009_09_22a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2009_08_25a);

use Globals qw($accountID);

use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x07e5,8
# TODO: what is 0x12?
sub sendCaptchaInitiate {
	my ($self) = @_;
	my $msg = pack('v2 a4', 0x07E5, 0x12, $accountID);
	$self->sendToServer($msg);
	debug "Sending Captcha Initiate\n";
}

#0x07e7,32
# TODO: what is 0x20?
sub sendCaptchaAnswer {
	my ($self, $answer) = @_;
	my $msg = pack('v2 a4 a24', 0x07E7, 0x20, $accountID, $answer);
	$self->sendToServer($msg);
}

=pod
//2009-09-22aRagexeRE
0x07e5,8
//0x07e6,8
0x07e7,32
0x07e8,-1
0x07e9,5
=cut

1;