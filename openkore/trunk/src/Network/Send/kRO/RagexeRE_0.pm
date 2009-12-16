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

# this is an experimental class
# this serverType is used for kRO Sakray RE
# basically when we don't know where to put a new packet, we put it here and move it to the right class later

package Network::Send::kRO::RagexeRE_0;

use strict;
use Network::Send::kRO::RagexeRE_2009_10_27a;
use base qw(Network::Send::kRO::RagexeRE_2009_10_27a);

use Log qw(message warning error debug);
use Utils::Rijndael qw(normal_rijndael);
use Globals qw($accountID $incomingMessages $masterServer);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub version {
	return $masterServer->{version} || 29;
}

# TODO: move to the right location
# 0x00204
sub sendClientMD5Hash {
	my ($self) = @_;
	#my $msg = pack('v H32', 0x0204, "82d12c914f5ad48fd96fcf7ef4cc492d"); -> kRO sakray, but not kRO main
	my $msg = pack('v H32', 0x0204, $masterServer->{clientHash});
	$self->sendToServer($msg);
}

# TODO: move to the right location
# 0x002B0
sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	$self->sendClientMD5Hash() if ($masterServer->{clientHash} != ''); 						# this is a hack, just for testing purposes, it should be moved to the login algo later on
	my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
	my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
	my $in = pack('a24', $password);
	my $rijndael = Utils::Rijndael->new();
	$rijndael->MakeKey($key, $chain, 24, 24);
	$password = $rijndael->Encrypt($in, undef, 24, 0);
	my $ip = "3139322e3136382e322e3400685f4c40";		# gibberish, ofcourse ;-)
	my $mac = "31313131313131313131313100";				# gibberish
	my $isGravityID = 0;
	my $msg = pack('v V a24 a24 C H32 H26 C', 0x02B0, version(), $username, $password, $master_version, $ip, $mac, $isGravityID);
	$self->sendToServer($msg);
}

sub sendGameLogin { # we hack on the sendGameLogin and add the nextMessageMightBeAccountID after it
	my ($self) = shift;
	$self->SUPER::sendGameLogin(@_);
	$incomingMessages->nextMessageMightBeAccountID();
}

=pod
0402
82d12c914f5ad48fd96fcf7ef4cc492d

b002													 2
1d000000												 4
4b75736f6f00000000000000000000000000000000000000		24
0779633c7c7080c6b4f443e9130b06c8c66bc0bab9700daf		24
02														 1
3139322e3136382e322e3400695f4c40						16
31313131313131313131313100								13
00														 1
														85
=cut

1;