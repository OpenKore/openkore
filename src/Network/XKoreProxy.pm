#########################################################################
#  OpenKore - X-Kore
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
# Note: the difference between XKore2 and XKoreProxy is that XKore2 can
# work headless (it handles all server messages by itself), while
# XKoreProxy lets the RO client handle many server messages.
package Network::XKoreProxy;

# FIXME: $syncSync is not set correctly (required for ropp)

use strict;
use base qw(Exporter);
use Exporter;
use IO::Socket::INET;
use Time::HiRes qw(time usleep);
use utf8;

use Modules 'register';
use Globals;
use Log qw(message warning error debug);
use Utils qw(dataWaiting timeOut makeIP encodeIP swrite existsInList);
use Misc qw(configModify visualDump);
use Translation qw(T TF);
use I18N qw(bytesToString);
use Interface;
use Network;
use Network::Send ();
use Utils::Exceptions;

my $clientBuffer;
my %flushTimer;

# Members:
#
# Socket proxy_listen
#    A server socket which accepts new connections from the RO client.
#    This is only defined when the RO client hasn't already connected
#    to XKoreProxy.
#
# Socket proxy
#    A client socket, which connects XKoreProxy with the RO client.
#    This is only defined when the RO client has connected to XKoreProxy.

##
# Network::XKoreProxy->new()
#
# Initialize X-Kore-Proxy mode.
sub new {
	my $class = shift;
	my $ip = $config{XKore_listenIp} || '0.0.0.0';
	my $port = $config{XKore_listenPort} || 6901;
	my $self = bless {}, $class;

	# Reuse code from Network::DirectConnection to connect to the server
	require Network::DirectConnection;
	$self->{server} = new Network::DirectConnection($self);

	$self->{client_state} = 0;
	$self->{nextIp} = undef;
	$self->{nextPort} = undef;
	$self->{charServerIp} = undef;
	$self->{charServerPort} = undef;
	$self->{gotError} = 0;
	$self->{waitingClient} = 1;
	{
		no encoding 'utf8';
		$self->{packetPending} = '';
		$clientBuffer = '';
	}

	message T("X-Kore mode intialized.\n"), "startup";

	if (defined($config{gameGuard}) && $config{gameGuard} ne '2') {
		require Poseidon::EmbedServer;
		Modules::register("Poseidon::EmbedServer");
		$self->{poseidon} = new Poseidon::EmbedServer;
	}

	return $self;
}

sub version {
	return 1;
}

sub DESTROY {
	my $self = shift;

	close($self->{proxy_listen});	
	close($self->{proxy});
}


######################
## Server Functions ##
######################

sub serverAlive {
	my $self = shift;
	return $self->{server}->serverAlive;
}

sub serverConnect {
	my $self = shift;
	my $host = shift;
	my $port = shift;

	return $self->{server}->serverConnect($host, $port);
}

sub serverPeerHost {
	my $self = shift;
	return $self->{server}->serverPeerHost if ($self->serverAlive);
	return undef;
}

sub serverPeerPort {
	my $self = shift;
	return $self->{server}->serverPeerPort if ($self->serverAlive);
	return undef;
}

sub serverRecv {
	my $self = shift;
	return $self->{server}->serverRecv();
}

sub serverSend {
	my $self = shift;
	my $msg = shift;

	$self->{server}->serverSend($msg);
}

sub serverDisconnect {
	my $self = shift;
	my $preserveClient = shift;

	return unless ($self->serverAlive);
	
	close($self->{proxy}) unless $preserveClient;
	$self->{waitClientDC} = 1 if $preserveClient;

	# user has played with relog command.
	if ($timeout_ex{'master'}{'time'}) {
		undef $timeout_ex{'master'}{'time'};
		$self->{waitingClient} = 1;
	}
	return $self->{server}->serverDisconnect();
}

sub serverAddress {
	my ($self) = @_;
	return $self->{server}->serverAddress();
}

sub getState {
	my ($self) = @_;
	return $self->{server}->getState();
}

sub setState {
	my ($self, $state) = @_;
	$self->{server}->setState($state);
}


######################
## Client Functions ##
######################

sub clientAlive {
	my $self = shift;
	return $self->proxyAlive();
}

sub proxyAlive {
	my $self = shift;
	return $self->{proxy} && $self->{proxy}->connected;
}

sub clientPeerHost {
	my $self = shift;
	return $self->{proxy}->peerhost if ($self->proxyAlive);
	return undef;
}

sub clientPeerPort {
	my $self = shift;
	return $self->{proxy}->peerport if ($self->proxyAlive);
	return undef;
}

sub clientSend {
	my $self = shift;
	my $msg = shift;
	my $dontMod = shift;

	return unless ($self->proxyAlive);

	$msg = $self->modifyPacketIn($msg) unless ($dontMod);
	if ($config{debugPacket_ro_received}) {
		debug "Modified packet sent to client\n";
		visualDump($msg, 'clientSend');
	}

	# queue message instead of sending directly
	$clientBuffer .= $msg;
}

sub clientFlush {
	my $self = shift;
	
	return unless (length($clientBuffer));
	
	$self->{proxy}->send($clientBuffer);	
	debug "Client network buffer flushed out\n";
	$clientBuffer = '';
}

sub clientRecv {
	my $self = shift;
	my $msg;

	return undef unless ($self->proxyAlive && dataWaiting(\$self->{proxy}));

	$self->{proxy}->recv($msg, 1024 * 32);
	if (length($msg) == 0) {
		# Connection from client closed
		close($self->{proxy});
		return undef;
	}

	# return $self->realClientRecv;
	return $self->modifyPacketOut($msg);
}



sub checkConnection {
	my $self = shift;

	# Check connection to the client
	$self->checkProxy();

	# Check server connection
	$self->checkServer();
	
	# Check the Poseidon Embed Server
	if ($self->clientAlive() && $self->getState() == Network::IN_GAME
	 && defined($config{gameGuard}) && $config{gameGuard} ne '2') {
		$self->{poseidon}->iterate($self);
	}
}

sub checkProxy {
	my $self = shift;
	
	if (defined $self->{proxy_listen}) {
		# Listening for a client
		if (dataWaiting($self->{proxy_listen})) {
			# Client is connecting...
			$self->{proxy} = $self->{proxy_listen}->accept;

			# Tell 'em about the new client
			my $host = $self->clientPeerHost;
			my $port = $self->clientPeerPort;
			debug "XKore Proxy: RO Client connected ($host:$port).\n", "connection";

			# Stop listening and clear errors.
			close($self->{proxy_listen});
			undef $self->{proxy_listen};
			$self->{gotError} = 0;
		}
		#return;
		
	} elsif (!$self->proxyAlive) {
		# Client disconnected... (or never existed)
		if ($self->serverAlive()) {
			message T("Client disconnected\n"), "connection";
			$self->setState(Network::NOT_CONNECTED) if ($self->getState() == Network::IN_GAME);
			$self->{waitingClient} = 1;
			$self->serverDisconnect();
		}

		close $self->{proxy} if $self->{proxy};
		$self->{waitClientDC} = undef;
		debug "Removing pending packet from queue\n" if (defined $self->{packetPending});
		$self->{packetPending} = '';

		# FIXME: there's a racing condition here. If the RO client tries to connect
		# to the listening port before we've set it up (this happens if sleepTime is
		# sufficiently high), then the client will freeze.
		
		# (Re)start listening...
		my $ip = $config{XKore_listenIp} || '127.0.0.1';
		my $port = $config{XKore_listenPort} || 6901;
		$self->{proxy_listen} = new IO::Socket::INET(
			LocalAddr	=> $ip,
			LocalPort	=> $port,
			Listen		=> 5,
			Proto		=> 'tcp',
			ReuseAddr   => 1);
		die "Unable to start the X-Kore proxy ($ip:$port): $@\n" . 
			"Make sure no other servers are running on port $port." unless $self->{proxy_listen};

		# setup master server if necessary
		getMainServer();

		message TF("Waiting Ragnarok Client to connect on (%s:%s)\n", ($ip eq '127.0.0.1' ? 'localhost' : $ip), $port), "startup" if ($self->{waitingClient} == 1);
		$self->{waitingClient} = 0;
		return;
	}
	
	if ($self->proxyAlive() && defined($self->{packetPending})) {
		checkPacketReplay();
	}
}

sub checkServer {
	my $self = shift;
	
	# Do nothing until the client has (re)connected to us
	return if (!$self->proxyAlive() || $self->{waitClientDC});
	
	# Connect to the next server for proxying the packets
	if (!$self->serverAlive()) {
	
		# Setup the next server to connect.
		if (!$self->{nextIp} || !$self->{nextPort}) {
			# if no next server was defined by received packets, setup a primary server.
			my $master = $masterServer = $masterServers{$config{'master'}};

			$self->{nextIp} = $master->{ip};
			$self->{nextPort} = $master->{port};
			message TF("Proxying to [%s]\n", $config{master}), "connection" unless ($self->{gotError});
			eval {
				$packetParser = Network::Receive->create($self, $masterServer->{serverType});
				$messageSender = Network::Send->create($self, $masterServer->{serverType});
			};
			if (my $e = caught('Exception::Class::Base')) {
				$interface->errorDialog($e->message());
				$quit = 1;
				return;
			}
		}

		$self->serverConnect($self->{nextIp}, $self->{nextPort}) unless ($self->{gotError});
		if (!$self->serverAlive()) {
			$self->{charServerIp} = undef;
			$self->{charServerPort} = undef;
			close($self->{proxy});
			error T("Invalid server specified or server does not exist...\n"), "connection" if (!$self->{gotError});
			$self->{gotError} = 1;
		}
		
		# clean Next Server uppon connection
		$self->{nextIp} = undef;
		$self->{nextPort} = undef;
	}
}

##
# $Network_XKoreProxy->checkPacketReplay()
#
# Setup a timer to repeat the received logon/server change packet to the client
# in case it didn't responded in an appropriate time.
#
# This is an internal function.
sub checkPacketReplay {
	my $self = shift;
	
	#message "Pending packet check\n";
	
	if ($self->{replayTimeout}{time} && timeOut($self->{replayTimeout})) {
		if ($self->{packetReplayTrial} < 3) {
			warning TF("Client did not respond in time.\n" . 
				"Trying to replay the packet for %s of 3 times\n", $self->{packetReplayTrial}++);
			$self->clientSend($self->{packetPending});
			$self->{replayTimeout}{time} = time;
			$self->{replayTimeout}{timeout} = 2.5;
		} else {
			error T("Client did not respond. Forcing disconnection\n");
			close($self->{proxy});
			return;
		}
		
	} elsif (!$self->{replayTimeout}{time}) {
		$self->{replayTimeout}{time} = time;
		$self->{replayTimeout}{timeout} = 2.5;
	} 
}

sub modifyPacketIn {
	my ($self, $msg) = @_;

	return undef if (length($msg) < 1);

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	if ($switch eq "02AE") {
		$msg = ""; 
	}

	# packet replay check: reset status for every different packet received
	if ($self->{packetPending} && ($self->{packetPending} ne $msg)) {
		debug "Removing pending packet from queue\n";
		use bytes; no encoding 'utf8';
		delete $self->{replayTimeout};
		$self->{packetPending} = '';
		$self->{packetReplayTrial} = 0;
	} elsif ($self->{packetPending} && ($self->{packetPending} eq $msg)) {
		# avoid doubled 0259 message: could mess the character selection and hang up the client
		if ($switch eq "0259") {
			debug T("Logon-grant packet received twice! Avoiding bug in client.\n");
			$self->{packetPending} = undef;
			return undef;
		}
	}

	if ($switch eq "0069") {
		use bytes; no encoding 'utf8';

		# queue the packet as requiring client's response in time
		$self->{packetPending} = $msg;
		
		# Modify the server config'ed on Kore to point to proxy
		my $accountInfo = substr($msg, 0, 47);
		my $serverInfo = substr($msg, 47, length($msg));
		my $newServers = '';
		my $serverCount = 0;
		
		my $msg_size = length($serverInfo);
		debug "Modifying Account Info packet...";
		
		for (my $i = 0; $i < $msg_size; $i+=32) {
			if ($config{'server'} == $serverCount++) {
				$self->{nextIp} = makeIP(substr($serverInfo, $i, 4));
				$self->{nextIp} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
				$self->{nextPort} = unpack("v1", substr($serverInfo, $i+4, 2));
				debug " next server to connect ($self->{nextIp}:$self->{nextPort})\n", "connection";
				
				$self->{charServerIp} = $self->{nextIp};
				$self->{charServerPort} = $self->{nextPort};

				my $newName = unpack("Z*", substr($serverInfo, $i + 6, 20));
				#$newName = "$newName (proxied)";
				$newServers .= encodeIP($self->{proxy}->sockhost) . pack("v*", $self->{proxy}->sockport) . 
					pack("Z20", $newName) . substr($serverInfo, $i + 26, 4) . pack("v1", 0);
				
			} else {
				$newServers .= substr($serverInfo, $i, 32);
			}
		}
		
		message T("Closing connection to Account Server\n"), 'connection' if (!$self->{packetReplayTrial});
		$self->serverDisconnect(1);
		$msg = $accountInfo . $newServers;
		
	} elsif ($switch eq "0071" || $switch eq "0092") {
		# queue the packet as requiring client's response in time
		$self->{packetPending} = $msg;
		
		# Proxy the Logon to Map server
		debug "Modifying Map Logon packet...", "connection";
		my $logonInfo = substr($msg, 0, 22);
		my @mapServer = unpack("x22 a4 v1", $msg);
		my $mapIP = $mapServer[0];
		my $mapPort = $mapServer[1];
		
		$self->{nextIp} = makeIP($mapIP);
		$self->{nextIp} = $masterServer->{ip} if ($masterServer && $masterServer->{private});
		$self->{nextPort} = $mapPort;
		debug " next server to connect ($self->{nextIp}:$self->{nextPort})\n", "connection";

		if ($switch eq "0071") {
			message T("Closing connection to Character Server\n"), 'connection' if (!$self->{packetReplayTrial});
		} else {
			message T("Closing connection to Map Server\n"), "connection" if (!$self->{packetReplayTrial});
		}
		$self->serverDisconnect(1);

		$msg = $logonInfo . encodeIP($self->{proxy}->sockhost) . pack("v*", $self->{proxy}->sockport);
		
	} elsif ($switch eq "006A" || $switch eq "006C" || $switch eq "0081") {
		# An error occurred. Restart proxying
		$self->{gotError} = 1;
		$self->{nextIp} = undef;
		$self->{nextPort} = undef;
		$self->{charServerIp} = undef;
		$self->{charServerPort} = undef;
		$self->serverDisconnect(1);
		
	} elsif ($switch eq "00B3") {
		$self->{nextIp} = $self->{charServerIp};
		$self->{nextPort} = $self->{charServerPort};		
		$self->serverDisconnect(1);
		
	} elsif ($switch eq "0259") {
		# queue the packet as requiring client's response in time
		$self->{packetPending} = $msg;
	}
	
	return $msg;
}

sub modifyPacketOut {
	my ($self, $msg) = @_;
	use bytes; no encoding 'utf8';

	return undef if (length($msg) < 1);

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if (($switch eq "007E" && (
			$masterServer->{serverType} == 0 ||
			$masterServer->{serverType} == 1 ||
			$masterServer->{serverType} == 2 ||
			$masterServer->{serverType} == 6 )) ||
		($switch eq "0089" && (
			$masterServer->{serverType} == 3 ||
			$masterServer->{serverType} == 5 )) ||
		($switch eq "0116" &&
			$masterServer->{serverType} == 4 ) ||
		($switch eq "00F3" &&
		  $masterServer->{serverType} == 10)) { #for vRO
		# Intercept the RO client's sync

		$msg = "";
		$messageSender->sendSync() if ($messageSender);
		
	} if ($switch eq "0228" && $self->getState() == Network::IN_GAME && $config{gameGuard} ne '2') {
		if ($self->{poseidon}->awaitingResponse) {
			$self->{poseidon}->setResponse($msg);
			$msg = '';
		}
	} 
	
	return $msg;
}



sub getMainServer {
	if ($config{'master'} eq "" || $config{'master'} =~ /^\d+$/ || !exists $masterServers{$config{'master'}}) {
		my @servers = sort { lc($a) cmp lc($b) } keys(%masterServers);
		my $choice = $interface->showMenu(
			T("Please choose a master server to connect to."),
			\@servers,
			title => T("Master servers"));
		if ($choice == -1) {
			exit;
		} else {
			configModify('master', $servers[$choice], 1);
		}
	}
}

return 1;
