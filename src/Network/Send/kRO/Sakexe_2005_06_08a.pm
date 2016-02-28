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

package Network::Send::kRO::Sakexe_2005_06_08a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2005_05_31a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0217,2,blacksmith,0
sub sendTop10Blacksmith {
	$_[0]->sendToServer(pack('v', 0x0217));
	debug "Sent Top 10 Blacksmith request\n", "sendPacket", 2;
}	

# 0x0231,26,changehomunculusname,0
sub sendHomunculusName {
	my $self = shift;
	my $name = shift;
	my $msg = pack('v a24', 0x0231, stringToBytes($name));
	$self->sendToServer($msg);
	debug "Sent Homunculus Rename: $name\n", "sendPacket", 2;
}

# 0x023b,24,storagepassword,0
sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	if ($type == 3) {
		$msg = pack('v2', 0x023B, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack('v2', 0x023B, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
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