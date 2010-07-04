#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# fRO (France)
# 2010-06-17aRagexe
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::fRO;
use strict;

use base 'Network::Send::ServerType0';

use Log qw(message warning error debug);
use Utils::Rijndael;
use Globals qw($masterServer);

sub new {
   my ($class) = @_;
   return $class->SUPER::new(@_);
}

sub version {
	return $masterServer->{version} || 1;
}

# 0x0204,18
sub sendClientMD5Hash {
	my ($self) = @_;
	my $msg = pack('v H32', 0x0204, $masterServer->{clientHash});
	$self->sendToServer($msg);
}

# 0x02b0,85
sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	# Little Hack by 'Technology'
	$self->sendClientMD5Hash() if ($masterServer->{clientHash} != '');
	my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
	my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
	my $in = pack('a24', $password);
	my $rijndael = Utils::Rijndael->new();
	$rijndael->MakeKey($key, $chain, 24, 24);
	$password = $rijndael->Encrypt($in, undef, 24, 0);
	# To get out local IP of our connection we need: $self->{net}->{remote_socket}->sockhost();
	my $ip = "3139322e3136382e322e3400685f4c40";
	# To get the MAC we need to use Net::ARPing or Net::Address::Ethernet or even Net::Ifconfig::Wrapper, that are not bundeled in Win Distro.
	my $mac = "31313131313131313131313100";				# May-be Get it from Network Connection?
	my $isGravityID = 0;
	my $msg = pack('v V a24 a24 C H32 H26 C', 0x02B0, version(), $username, $password, $master_version, $ip, $mac, $isGravityID);
	$self->sendToServer($msg);
}

1;
