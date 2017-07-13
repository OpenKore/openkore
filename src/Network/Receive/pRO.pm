#################################################################################################
#  OpenKore - Network subsystem									#
#  This module contains functions for sending messages to the server.				#
#												#
#  This software is open source, licensed under the GNU General Public				#
#  License, version 2.										#
#  Basically, this means that you're allowed to modify and distribute				#
#  this software. However, if you distribute modified versions, you MUST			#
#  also distribute the source code.								#
#  See http://www.gnu.org/licenses/gpl.html for the full license.				#
#################################################################################################
# pRO (Philippines)
# Servertype overview: http://wiki.openkore.com/index.php/ServerType
package Network::Receive::pRO;
use strict;
use Time::HiRes;

use Globals;
use base qw(Network::Receive::ServerType0);
use Log qw(message debug warning);
use Network::MessageTokenizer;
use Misc;
use Utils;
use Translation;
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'0276' => ['account_server_info', 'x2 a4 a4 a4 a4 a26 C a4 a*', [qw(sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex iAccountSID serverInfo)]],
		'0A7B' => ['gameguard_request', 'v a*', [qw(len data)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	my %handlers = qw(
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

sub gameguard_request {
	my ($self, $args) = @_;

	message T ("Receive Gameguard!\n");
	my $msg = pack('v*', length($args->{data}) + 4, 0xA7B, $args->{len}) . $args->{data};
	$self->{net}->{xkore_socket}->send($msg);
	my $msg2;
	$self->{net}->{xkore_socket}->recv($msg2, 2);
	my $newSize = unpack('v', $msg2);
	$self->{net}->{xkore_socket}->recv($msg2, $newSize);

	$messageSender->sendToServer($msg2);
}

1;
