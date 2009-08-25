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

package Network::Send::kRO::Sakexe_2005_11_07a;

use strict;
use Network::Send::kRO::Sakexe_2005_10_24a;
use base qw(Network::Send::kRO::Sakexe_2005_10_24a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}
# 0x024e,6,auctioncancel,0
sub sendAuctionCancel {
	my ($self, $id) = @_;
	my $msg = pack('v V', 0x024E, $id);
	$self->sendToServer($msg);
	debug "Sent Auction Cancel.\n", "sendPacket", 2;
}

# 0x0251,34,auctionsearch,0
sub sendAuctionItemSearch {
	my ($self, $type, $price, $text, $page) = @_;
	$page = (defined $page) ? $page : 1;
	my $msg = pack('v2 V Z24 v', 0x0251, $type, $price, stringToBytes($text), $page);
	$self->sendToServer($msg);
	debug "Sent Auction Item Search.\n", "sendPacket", 2;
}

=pod
//2005-11-07aSakexe
0x024e,6,auctioncancel,0
0x0251,34,auctionsearch,0
=cut

1;