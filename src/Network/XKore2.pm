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
use Utils qw(makeCoordsDir makeCoordsXY makeCoordsFromTo calcPosition);
use Utils::Exceptions;
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
	my $port = $config{XKore_listenPort} || 6900;
	$sessionStore = new Base::Ragnarok::SessionStore();
	$mapServer = new Network::XKore2::MapServer(
		host => $publicIP,
		port => $config{XKore_listenPort_map} || undef,
		serverType => $masterServer->{serverType},
		rpackets => \%rpackets,
		sessionStore => $sessionStore
	);
	$charServer = new Network::XKore2::CharServer(
		host => $publicIP,
		port => $config{XKore_listenPort_char} || undef,
		serverType => $masterServer->{serverType},
		rpackets => \%rpackets,
		mapServer => $mapServer,
		sessionStore => $sessionStore,
		name => $config{XKore_ID}
	);
	eval {
		$accountServer = new Network::XKore2::AccountServer(
			host         => $publicIP,
			port         => $port,
			serverType   => $masterServer->{serverType},
			rpackets     => \%rpackets,
			charServer   => $charServer,
			sessionStore => $sessionStore
		);
	};
	if ( my $e = caught( 'SocketException' ) ) {
		die "Unable to start the X-Kore proxy ($publicIP:$port): $@\n"
			. "Make sure no other servers are running on port $port.";
	} else {
		die $@ if $@;
	}
	$hooks = Plugins::addHooks(
		['packet_pre/sync_request_ex', \&sync_request_ex],
		['packet_pre/map_loaded', \&map_loaded],
		['packet_pre/map_changed', \&map_changed],
		['packet_pre/initialize_message_id_encryption', \&initialize_message_id_encryption],
		['Network::stateChanged', \&stateChanged],
		['Network::clientAlive', \&clientAlive],
		['Network::clientSend', \&clientSend],
		['Network::clientRecv', \&clientRecv],
		['mainLoop_pre', \&mainLoop],
		['disconnected', \&disconnectClients]
	);
}

##
# void Network::XKore2::stop()
#
# Stop the X-Kore 2 subsystem.
sub stop {
	Plugins::delHooks($hooks);
}

# let kore handle this.
sub sync_request_ex {
	my ($self, $args, $client) = @_;
	$args->{mangle} = 2;
}

sub map_loaded {
	my (undef, $args) = @_;
	
	$args->{mangle} = 2;
}

sub map_changed {
	my (undef, $args) = @_;
	
	$mapServerChange = Storable::dclone($args);
	
	$args->{mangle} = 2;
}

sub initialize_message_id_encryption {
	my (undef, $args) = @_;
	
	$args->{mangle} = 2;
}

sub stateChanged {
	$accountServer->setServerType($masterServer->{serverType});
	$charServer->setServerType($masterServer->{serverType});
	$mapServer->setServerType($masterServer->{serverType});
	
	if ($Globals::net->getState() == Network::IN_GAME && $mapServerChange ne '') {
		$Globals::net->clientSend($mapServer->{recvPacketParser}->reconstruct({
			%$mapServerChange,
			switch => 'map_change',
		}));
		
		$mapServerChange = undef;
	}
}

sub clientAlive {
	my (undef, $args) = @_;
	$args->{return} = @{$mapServer->clients} > 0;
}

sub clientSend {
	my (undef, $args) = @_;
	if ($args->{net}->getState() == Network::IN_GAME) {
		foreach my $client (@{$mapServer->clients}) {
			my $sendData = $args->{data};
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

sub mainLoop {
	if ($accountServer) {
		$accountServer->iterate();
		$charServer->iterate();
		$mapServer->iterate();
		$sessionStore->removeTimedOutSessions();
	}
}

sub disconnectClients {
	# DC clients here
}

1;

