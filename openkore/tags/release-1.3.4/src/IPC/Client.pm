#########################################################################
#  OpenKore - Inter-Process Communication system
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision$
#  $Id$
#
#########################################################################

package IPC::Client;

use strict;
use warnings;
no warnings 'redefine';
use Exporter;
use base qw(Exporter);
use IO::Socket::INET;

use IPC::Protocol;
use Utils;


sub new {
	my ($class, $host, $port) = @_;
	my %client;

	$client{sock} = new IO::Socket::INET(
			PeerHost => $host,
			PeerPort => $port,
			Proto => 'tcp',
		);
	return undef if (!$client{sock});

	$client{buffer} = '';
	bless \%client;
	return \%client;
}

sub sendData {
	my ($client, $ID, $hash) = @_;
	my $msg = IPC::Protocol::encode($ID, $hash);
	eval {
		$client->{sock}->send($msg, 0);
		$client->{sock}->flush;
	};
	return ($@) ? 0 : 1;
}

sub recvData {
	my ($client, $r_packets) = @_;
	my $msg;

	return 0 if (!dataWaiting($client->{sock}));

	eval {
		$client->{sock}->recv($msg, 1024 * 32, 0);
	};
	if ($@ || !defined $msg || length $msg == 0) {
		return -1;
	}

	$client->{buffer} .= $msg;

	my (@packets, $ID, %hash);
	while (($ID = IPC::Protocol::decode($client->{buffer}, \%hash, \$client->{buffer}))) {
		my %copy = %hash;
		push @packets, {ID => $ID, params => \%copy};
		undef %hash;
	}
	@{$r_packets} = @packets;
	return scalar @packets;
}

return 1;
