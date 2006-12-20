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
package XKoreProxy;

use strict;
use base qw(Exporter);
use Exporter;
use IO::Socket::INET;
use Time::HiRes qw(time usleep);
use encoding 'utf8';

use Globals;
use Log qw(message warning error debug);
use Utils qw(dataWaiting timeOut makeIP encodeIP swrite existsInList);
use Misc qw(configModify visualDump);
use Translation;
use I18N qw(bytesToString);
use Network::Send ();

my $clientBuffer;
my %flushTimer;

##
# XKoreProxy->new()
#
# Initialize X-Kore-Proxy mode.
sub new {
	my $class = shift;
	my $ip = $config{XKore_listenIp} || '0.0.0.0';
	my $port = $config{XKore_listenPort} || 6901;
	my %self;

	# Reuse code from Network to connect to the server
	require Network;
	Modules::register("Network");
	$self{server} = new Network;

	$self{client_state} = 0;
	$self{nextIp} = undef;
	$self{nextPort} = undef;
	$self{charServerIp} = undef;
	$self{charServerPort} = undef;
	$self{gotError} = 0;
	$self{packetPending} = '';
	$self{waitingClient} = 1;
	$clientBuffer = '';

	message T("X-Kore mode intialized.\n"), "startup";

	if (defined($config{gameGuard}) && $config{gameGuard} ne '2') {
		require Poseidon::EmbedServer;
		Modules::register("Poseidon::EmbedServer");
		$self{poseidon} = new Poseidon::EmbedServer;
	}

	return bless \%self, $class;
}

##
# $net->version
# Returns: XKore mode
#
sub version {
	return 1;
}

##
# $net->DESTROY()
#
# Shutdown function. Turn everything off.
sub DESTROY {
	my $self = shift;

	close($self->{server});
	close($self->{proxy_listen});	
	close($self->{proxy});
}

######################
## Server Functions ##
######################

##
# $net->serverAlive()
# Returns: a boolean.
#
# Check whether the connection with the server is still alive.
sub serverAlive {
	my $self = shift;
	return $self->{server}->serverAlive;
}

##
# $net->serverConnect
#
sub serverConnect {
	my $self = shift;
	my $host = shift;
	my $port = shift;

	return $self->{server}->serverConnect($host, $port);
}

##
# $net->serverPeerHost
#
sub serverPeerHost {
	my $self = shift;
	return $self->{server}->serverPeerHost if ($self->serverAlive);
	return undef;
}

##
# $net->serverPeerPort
#
sub serverPeerPort {
	my $self = shift;
	return $self->{server}->serverPeerPort if ($self->serverAlive);
	return undef;
}

##
# $net->serverRecv()
# Returns: the messages sent from the server, or undef if there are no pending messages.
#
# This just uses KoreNet.pm
sub serverRecv {
	my $self = shift;
	
	return $self->{server}->serverRecv();
}

##
# $net->serverSend(msg)
# msg: A scalar to send to the RO server
#
# This just reuses KoreNet.pm's code
sub serverSend {
	my $self = shift;
	my $msg = shift;
	
	$self->{server}->serverSend($msg);
}

##
# $net->serverDisconnect
#
# Disconnects the server and client if necessary. 
# preserveClient should never be used outside XKoreProxy
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


######################
## Client Functions ##
######################

##
# $net->clientAlive
# Returns: a boolean.
#
# Check to see if the client is fully connected and logged in.
sub clientAlive {
	my $self = shift;
	return $self->proxyAlive();
}

##
# $net->proxyAlive
# Returns: a boolean
#
# Checks to see if the client is connected. Used internally only.
sub proxyAlive {
	my $self = shift;
	return $self->{proxy} && $self->{proxy}->connected;
}

##
# $net->clientPeerHost
#
sub clientPeerHost {
	my $self = shift;
	return $self->{proxy}->peerhost if ($self->proxyAlive);
	return undef;
}

##
# $net->clientPeePort
#
sub clientPeerPort {
	my $self = shift;
	return $self->{proxy}->peerport if ($self->proxyAlive);
	return undef;
}

##
# $net->clientSend
#
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

##
# $net->clientFlush
#
sub clientFlush {
	my $self = shift;
	
	return unless (length($clientBuffer));
	
	$self->{proxy}->send($clientBuffer);	
	debug "Client network buffer flushed out\n";
	$clientBuffer = '';
}


##
# $net->clientRecv
# Returns: A scalar.
#
# Returns undef unless the client is logged in.
sub clientRecv {
	my $self = shift;
	my $msg;

	return undef unless ($self->proxyAlive && dataWaiting(\$self->{proxy}));

	$self->{proxy}->recv($msg, $Settings::MAX_READ);
	if ($msg eq '') {
		# Connection from client closed
		close($self->{proxy});
		return undef;
	}

	# return $self->realClientRecv;
	return $self->modifyPacketOut($msg);
}





##
# $net->checkConnection()
#
sub checkConnection {
	my $self = shift;

	# Check connection to the client
	$self->checkProxy();

	# Check server connection
	$self->checkServer();
	
	# Check the Poseidon Embed Server
	$self->{poseidon}->iterate($self) if ($self->clientAlive() && ($conState == 5) && defined($config{gameGuard})
		&& $config{gameGuard} ne '2');
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
			$conState = 1 if ($conState == 5);
			$self->{waitingClient} = 1;
			$self->serverDisconnect();
		}

		close($self->{proxy});
		$self->{waitClientDC} = undef;
		debug "Removing pending packet from queue\n" if (defined $self->{packetPending});
		$self->{packetPending} = '';
		
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
			"You can only run one X-Kore session at the same time.\n" .
			"And make sure no other servers are running on port $port." unless $self->{proxy_listen};

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
			$packetParser = Network::Receive->create($config{serverType}) if (!$packetParser);
			$messageSender = Network::Send->create($self, $config{serverType}) if (!$messageSender);
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
# $net->checkPacketReplay()
#
# Internal use only
#
# Setup a timer to repeat the received logon/server change packet to the client
# in case it didn't responded in an appropriate time.

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

	# packet replay check: reset status for every different packet received
	if ($self->{packetPending} && ($self->{packetPending} ne $msg)) {
		debug "Removing pending packet from queue\n";
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
				debug " next server to connect ($self->{nextIp}:$self->{nextPort})\n";
				
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

	return undef if (length($msg) < 1);

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if (($switch eq "007E" && (
			$config{serverType} == 0 ||
			$config{serverType} == 1 ||
			$config{serverType} == 2 ||
			$config{serverType} == 6 )) ||
		($switch eq "0089" && (
			$config{serverType} == 3 ||
			$config{serverType} == 5 )) ||
		($switch eq "0116" &&
			$config{serverType} == 4 )) {
		# Intercept the RO client's sync
	
		$msg = "";
		#$self->sendSync();	
		
	} if ($switch eq "0228" && $conState == 5 && $config{gameGuard} eq '2') {
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
		my $choice = $interface->showMenu("Master servers",
			"Please choose a master server to connect to: ",
			\@servers);
		if ($choice == -1) {
			exit;
		} else {
			configModify('master', $servers[$choice], 1);
		}
	}
}

return 1;
