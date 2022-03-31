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
########################################################################
# by alisonrag / thanks to Asheraf
package Network::Send::Sakray;

use strict;
use base qw(Network::Send::ServerType0);
use Globals; 
use Network::Send::ServerType0;
use Log qw(error debug message);
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0825' => ['token_login', 'v V C Z24 a27 Z17 Z15 a*', [qw(len version master_version username password_rijndael mac ip token)]], # kRO 2017/2018 login
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		item_use 0439
		token_login 0825
		send_equip 0998
		master_login 0ACF
	);

	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self->{char_create_version} = 0x0A39;

	return $self;
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	error "You need to use SakrayAuth plugin";
	quit();	
}

1;