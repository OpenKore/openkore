#########################################################################
#  OpenKore - X-Kore Mode 2
#  Copyright (c) 2007 OpenKore developers
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
##
# MODULE DESCRIPTION: X-Kore 2.
package Network::XKore2;

use strict;
use Globals qw(%config %rpackets $masterServer $char);
use Utils qw(makeCoords calcPosition);
use Plugins;
use Base::Ragnarok::SessionStore;
use Network;
use Network::XKore2::AccountServer;
use Network::XKore2::CharServer;
use Network::XKore2::MapServer;
use Modules 'register';

our ($hooks, $sessionStore, $accountServer, $charServer, $mapServer ,$mapServerChange);

##
# void Network::XKore2::start()
#
# Start the X-Kore 2 subsystem.
sub start {
	my $publicIP = $config{XKore_publicIp} || '127.0.0.1';
	$sessionStore = new Base::Ragnarok::SessionStore();
	$mapServer = new Network::XKore2::MapServer(
		host => $publicIP,
		serverType => $config{serverType},
		rpackets => \%rpackets,
		sessionStore => $sessionStore
	);
	$charServer = new Network::XKore2::CharServer(
		host => $publicIP,
		serverType => $config{serverType},
		rpackets => \%rpackets,
		mapServer => $mapServer,
		sessionStore => $sessionStore,
		name => $config{XKore_ID}
	);
	$accountServer = new Network::XKore2::AccountServer(
		host => $publicIP,
		port => $config{XKore_listenPort} || 6900,
		serverType => $config{serverType},
		rpackets => \%rpackets,
		charServer => $charServer,
		sessionStore => $sessionStore
	);
	$hooks = Plugins::addHooks(
		['Network::setState', \&stateChanged],
		['Network::clientAlive', \&clientAlive],
		['Network::clientSend', \&clientSend],
		['Network::clientRecv', \&clientRecv],
		['mainLoop_pre', \&mainLoop]
	);
}

##
# void Network::XKore2::stop()
#
# Stop the X-Kore 2 subsystem.
sub stop {
	Plugins::delHooks($hooks);
}

sub stateChanged {
	$accountServer->setServerType($masterServer->{serverType});
	$charServer->setServerType($masterServer->{serverType});
	$mapServer->setServerType($masterServer->{serverType});
}

sub clientAlive {
	my (undef, $args) = @_;
	$args->{return} = @{$mapServer->clients} > 0;
}

sub clientSend {
	my (undef, $args) = @_;
	if ($args->{net}->getState() == Network::IN_GAME) {
		foreach my $client (@{$mapServer->clients}) {
			my $sendData = filterPacket($args->{data});
			$client->send($sendData) if (length($sendData) > 0);
		}
	}

}

sub clientRecv {
	no encoding 'utf8';
	use bytes;
	my (undef, $args) = @_;

	if ($args->{net}->getState() != Network::IN_GAME) {
		foreach my $client (@{$mapServer->clients}) {
			$client->{outbox}->clear() if ($client->{outbox});
		}
	} else {
		my $result = '';
		foreach my $client (@{$mapServer->clients}) {
			my $type;
			while (my $message = $client->{outbox}->readNext(\$type)) {
				$result .= $message;
			}
		}
		$args->{return} = $result if (length($result) > 0);
	}
}

sub filterPacket {
	my ($msg) = shift;
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($switch eq "0092"){
	    $mapServerChange = unpack('x2 Z16 x*', $msg);
		$mapServerChange =~ /([\s\S]*)\./;
		return "";
	} elsif ($switch eq "00B0" && $mapServerChange ne '') {
		my $pos = calcPosition($char);
		$msg = pack("C*",0x91,0). pack("a16", $mapServerChange) . pack("v1 v1", $pos->{x}, $pos->{y}).$msg;
		$mapServerChange = '';
	} elsif ($switch eq "02AE") {
		$msg = "";
	}
	return $msg;
}

sub mainLoop {
	if ($accountServer) {
		$accountServer->iterate();
		$charServer->iterate();
		$mapServer->iterate();
		$sessionStore->removeTimedOutSessions();
	}
}

1;

