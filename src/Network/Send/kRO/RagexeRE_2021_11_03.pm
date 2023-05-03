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
#  by alisonrag
package Network::Send::kRO::RagexeRE_2021_11_03;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2020_07_23);
use Log qw(debug);
use Utils qw(getTickCount);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0436' => ['map_login', 'a4 a4 a4 V2 C', [qw(accountID charID sessionID unknown tick sex)]],#23
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	return $self;
}

# 0x0436,23
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)

	$msg = $self->reconstruct({
		switch => 'map_login',
		accountID => $accountID,
		charID => $charID,
		sessionID => $sessionID,
		unknown => 0,# 00 00 00 00
		tick => getTickCount,
		sex => $sex,
	});

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

1;
