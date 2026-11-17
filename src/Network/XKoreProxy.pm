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
use Network::MessageTokenizer;

my $clientBuffer;
my $currentClientKey = 0;

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

	$self->{tokenizer} = new Network::MessageTokenizer($self->getRecvPackets());
	$self->{publicIP} = $config{XKore_publicIp} || undef;
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

	eval {
		$clientPacketHandler = Network::ClientReceive->new;
		$packetParser = Network::Receive->create($self, $masterServer->{serverType});
		$messageSender = Network::Send->create($self, $masterServer->{serverType});
	};
	if (my $e = caught('Exception::Class::Base')) {
		$interface->errorDialog($e->message());
		$quit = 1;
		return;
	}

	message T("X-Kore mode intialized.\n"), "startup";

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

	if (!defined $msg || length($msg) >= 2) {
		# Get packet switch
		my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
		# Handle 'master_login'
		if ($switch eq "0C26" && $config{username} && $config{password}) {
			# Log master login packet
			warning "Modifying packet 'master_login'...\n", "xkoreProxy";
			# Parse master login packet
			my ($game_code, $username, $password_rijndael, $flag) = unpack('a4 Z51 a32 a5', substr($msg, 2));
			# Rebuild master login packet
			$msg = $messageSender->reconstruct({
				switch => 'master_login',
				game_code => $game_code,
				username => $config{username},
				password => $config{password},
				flag => $flag,
			});
		}
		# Handle 'token_login'
		elsif ($switch eq "0825" && $config{username} && $config{password}) {
			# Log token login packet
			warning "Modifying packet 'token_login'...\n", "xkoreProxy";
			# Parse token login packet
			my ($len, $version, $master_version, $username, $mac_hyphen_separated, $ip, $token) = unpack('v V C Z51 a17 a15 a*', substr($msg, 2));
			# Rebuild token login packet
			$msg = $messageSender->reconstruct({
				switch => "token_login",
				len => $len,
				version => $version,
				master_version => $master_version,
				username => $config{username},
				mac_hyphen_separated => $mac_hyphen_separated,
				ip => inet_aton($self->{publicIP} || $self->{proxy}->sockhost),
				token => $token,
			});
		}
	}

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

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if ($switch eq "08B9") { # login_pin_code_request
		my $seed = unpack("V", substr($msg,  2, 4));
		my $accountID = unpack("a4", substr($msg, 6, 4));
		my $flag = unpack("v", substr($msg, 10, 2));

		if ($flag == 1 and $config{loginPinCode}) {
			$messageSender->sendLoginPinCode($seed, 0);
		}
	}

	$msg = $self->modifyPacketIn($msg, $switch) unless ($dontMod);
	if ($config{debugPacket_ro_received}) {
		debug "Modified packet sent to client\n", "xkoreProxy";
		visualDump($msg, 'sendToClient');
	}

	# queue message instead of sending directly
	$clientBuffer .= $msg;
}

sub clientFlush {
	my $self = shift;

	return unless (length($clientBuffer));

	$self->{proxy}->send($clientBuffer);
	debug "Client network buffer flushed out\n", "xkoreProxy";
	$clientBuffer = '';
}

sub clientRecv {
	my ($self, $msg) = @_;

	return undef unless ($self->proxyAlive && dataWaiting(\$self->{proxy}));

	$self->{proxy}->recv($msg, 1024 * 32);
	if (length($msg) == 0) {
		# Connection from client closed
		close($self->{proxy});
		return undef;
	}

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	$msg = $self->modifyPacketOut($msg, $switch);

	if($self->getState() eq Network::IN_GAME || $self->getState() eq Network::CONNECTED_TO_CHAR_SERVER) {
		$self->onClientData($msg);
		return undef;
	}

	return $msg;
}

sub onClientData {
	my ($self, $msg) = @_;
	my $additional_data;
	my $type;

	while (my $message = $self->{tokenizer}->readNext(\$type)) {
		$msg .= $message;
	}
	$self->decryptMessageID(\$msg);


	$self->{tokenizer}->add($msg, 1);

	$messageSender->sendToServer($_) for $messageSender->process(
		$self->{tokenizer}, $clientPacketHandler
	);

	$self->{tokenizer}->clear();

	if($additional_data) {
		$self->onClientData($additional_data);
	}
}

sub checkConnection {
	my $self = shift;

	# Check connection to the client
	$self->checkProxy();

	# Check server connection
	$self->checkServer();
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
		debug "Removing pending packet from queue\n", "xkoreProxy" if (defined $self->{packetPending});
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
		# if no next server was defined by received packets, setup a primary server.
		my $master = $masterServer = $masterServers{$config{'master'}};

		# Setup the next server to connect.
		if (!$self->{nextIp} || !$self->{nextPort}) {
			if ($master->{OTP_ip} && $master->{OTP_port}) {
				$self->{nextIp} = $master->{OTP_ip};
				$self->{nextPort} = $master->{OTP_port};
			} else {
				$self->{nextIp} = $master->{ip};
				$self->{nextPort} = $master->{port};
			}
			message TF("Proxying to [%s]\n", $config{master}), "connection" unless ($self->{gotError});
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
				"Trying to replay the packet for %s of 3 times\n", $self->{packetReplayTrial}++), "connection";
			$self->clientSend($self->{packetPending});
			$self->{replayTimeout}{time} = time;
			$self->{replayTimeout}{timeout} = 2.5;
		} else {
			error T("Client did not respond. Forcing disconnection\n"), "connection";
			close($self->{proxy});
			return;
		}

	} elsif (!$self->{replayTimeout}{time}) {
		$self->{replayTimeout}{time} = time;
		$self->{replayTimeout}{timeout} = 2.5;
	}
}

sub modifyPacketIn {
	my ($self, $msg, $switch) = @_;

	return undef if (length($msg) < 1);

	if ($switch eq "02AE") {
		$msg = "";
	}

	# packet replay check: reset status for every different packet received
	if ($self->{packetPending} && ($self->{packetPending} ne $msg)) {
		debug "Removing pending packet from queue\n", "connection";
		use bytes; no encoding 'utf8';
		delete $self->{replayTimeout};
		$self->{packetPending} = '';
		$self->{packetReplayTrial} = 0;
	} elsif ($self->{packetPending} && ($self->{packetPending} eq $msg)) {
		# avoid doubled 0259 message: could mess the character selection and hang up the client
		if ($switch eq "0259") {
			debug T("Logon-grant packet received twice! Avoiding bug in client.\n"), "connection";
			$self->{packetPending} = undef;
			return undef;
		}
	}

	# server list
	if ($switch eq "0069" || $switch eq "0276" || $switch eq "0A4D" || $switch eq "0AC4" || $switch eq "0AC9" || $switch eq "0B07" || $switch eq "0B60" || $switch eq "0C32") {
		use bytes; no encoding 'utf8';

		# queue the packet as requiring client's response in time
		$self->{packetPending} = $msg;

		# Show list of character servers.
		unless ($config{server} =~/\d+/) {
			my @menuServerList;
			foreach my $server (@servers) {
				push @menuServerList, $server->{name};
			}
			my $ret = $interface->showMenu(
					T("Please select your login server."),
					\@menuServerList,
					title => T("Select Login Server"));
			if ($ret == -1) {
				quit();
			} else {
				main::configModify('server', $ret, 1);
				undef $conState_tries;
			}
		}

		debug "Modifying Account Info packet...\n", "xkoreProxy";

		my $xKoreCharServer = $servers[$config{server}];

		$self->{nextIp} = $self->{charServerIp} = $xKoreCharServer->{ip};
		$self->{nextPort} = $self->{charServerPort} = $xKoreCharServer->{port};

		$xKoreCharServer->{ip} = $self->{publicIP} || $self->{proxy}->sockhost;
		$xKoreCharServer->{port} = $self->{proxy}->sockport;
		$xKoreCharServer->{ip_port} = "$xKoreCharServer->{ip}:$xKoreCharServer->{port}";

		my @serverList;
		push @serverList, $xKoreCharServer;

		$msg = $packetParser->reconstruct({
			switch => $switch,
			sessionID => $sessionID,
			accountID => $accountID,
			sessionID2 => $sessionID2,
			accountSex => $accountSex,
			servers => \@serverList,
		});

		message T("Closing connection to Account Server\n"), 'connection' if (!$self->{packetReplayTrial});
		$self->serverDisconnect(1);

	} elsif ($switch eq "0071" || $switch eq "0AC5") { # login in map-server
		my ($mapInfo, $server_info);

		# queue the packet as requiring client's response in time
		$self->{packetPending} = $msg;

		# Proxy the Logon to Map server
		debug "Modifying Map Logon packet...\n", "xkoreProxy";

		if ($switch eq '0AC5') { # cRO 2017
			$server_info = {
				types => 'a4 Z16 a4 v a128',
				keys => [qw(charID mapName mapIP mapPort mapUrl)],
			};

		} else {
			$server_info = {
				types => 'a4 Z16 a4 v',
				keys => [qw(charID mapName mapIP mapPort)],
			};
		}

		my $ip = $self->{publicIP} || $self->{proxy}->sockhost;

		@{$mapInfo}{@{$server_info->{keys}}} = unpack($server_info->{types}, substr($msg, 2));

		if (exists $mapInfo->{mapUrl} && $mapInfo->{'mapUrl'} =~ /.*\:\d+/) { # in cRO we have server.alias.com:port
			@{$mapInfo}{@{[qw(mapIP port)]}} = split (/\:/, $mapInfo->{'mapUrl'});
			$mapInfo->{mapIP} =~ s/^\s+|\s+$//g;
			$mapInfo->{port} =~ tr/0-9//cd;
		} else {
			$mapInfo->{mapIP} = inet_ntoa($mapInfo->{mapIP});
		}

		if($masterServer->{'private'}) {
			$mapInfo->{mapIP} = $masterServer->{ip};
		}

		$msg = $packetParser->reconstruct({
			switch => $switch,
			charID => $mapInfo->{'charID'},
			mapName => $mapInfo->{'mapName'},
			mapIP => inet_aton($ip),
			mapPort => $self->{proxy}->sockport,
			mapUrl => $ip.':'.$self->{proxy}->sockport,
		});

		$self->{nextIp} = $mapInfo->{'mapIP'};
		$self->{nextPort} = $mapInfo->{'mapPort'};
		debug " next server to connect ($self->{nextIp}:$self->{nextPort})\n", "connection";

		# reset key when change map-server
		if ($currentClientKey && $messageSender->{encryption}->{crypt_key}) {
			$currentClientKey = $messageSender->{encryption}->{crypt_key_1};
			$messageSender->{encryption}->{crypt_key} = $messageSender->{encryption}->{crypt_key_1};
		}

		if ($switch eq "0071" || $switch eq "0AC5") {
			message T("Closing connection to Character Server\n"), 'connection' if (!$self->{packetReplayTrial});
		} else {
			message T("Closing connection to Map Server\n"), "connection" if (!$self->{packetReplayTrial});
		}
		$self->serverDisconnect(1);

	} elsif($switch eq "0092" || $switch eq "0AC7" || $switch eq "0A4C") { # In Game Map-server changed
		my ($mapInfo, $server_info);

		if ($switch eq '0AC7') { # cRO 2017
			$server_info = {
				types => 'Z16 v2 a4 v a128',
				keys => [qw(map x y IP port url)],
			};

		} else {
			$server_info = {
				types => 'Z16 v2 a4 v',
				keys => [qw(map x y IP port)],
			};
		}

		my $ip = $self->{publicIP} || $self->{proxy}->sockhost;
		my $port = $self->{proxy}->sockport;

		@{$mapInfo}{@{$server_info->{keys}}} = unpack($server_info->{types}, substr($msg, 2));

		if (exists $mapInfo->{url} && $mapInfo->{'url'} =~ /.*\:\d+/) { # in cRO we have server.alias.com:port
			@{$mapInfo}{@{[qw(ip port)]}} = split (/\:/, $mapInfo->{'url'});
			$mapInfo->{ip} =~ s/^\s+|\s+$//g;
			$mapInfo->{port} =~ tr/0-9//cd;
		} else {
			$mapInfo->{ip} = inet_ntoa($mapInfo->{'IP'});
		}

		if($masterServer->{'private'}) {
			$mapInfo->{ip} = $masterServer->{ip};
		}

		$msg = $packetParser->reconstruct({
			switch => $switch,
			map => $mapInfo->{'map'},
			x => $mapInfo->{'x'},
			y => $mapInfo->{'y'},
			IP => inet_aton($ip),
			port => $port,
			url => $ip.':'.$port,
		});

		$self->{nextIp} = $mapInfo->{ip};
		$self->{nextPort} = $mapInfo->{'port'};
		debug " next server to connect ($self->{nextIp}:$self->{nextPort})\n", "connection";

		# reset key when change map-server
		if ($currentClientKey && $messageSender->{encryption}->{crypt_key}) {
			$currentClientKey = $messageSender->{encryption}->{crypt_key_1};
			$messageSender->{encryption}->{crypt_key} = $messageSender->{encryption}->{crypt_key_1};
		}

	} elsif ($switch eq "006A" || $switch eq "006C" || $switch eq "0081" || $switch eq "02CA" || $switch eq "083E" || $switch eq "0ACD" || $switch eq "0AE0") { # error while login in server
		# Show error message
		error T("Server reported an error, disconnecting...\n"), "connection";
		# An error occurred. Restart proxying
		$self->{gotError} = 1;
		$self->{nextIp} = undef;
		$self->{nextPort} = undef;
		$self->{charServerIp} = undef;
		$self->{charServerPort} = undef;
		$self->serverDisconnect();

	} elsif ($switch eq "00B3") {
		$self->{nextIp} = $self->{charServerIp};
		$self->{nextPort} = $self->{charServerPort};
		$self->serverDisconnect(1);

	} elsif ($switch eq "0259") {
		# queue the packet as requiring client's response in time
		$self->{packetPending} = $msg;
	} elsif ($switch eq "0AE3") { # If token was received, we need to connect to login server
        # Parse token response
        my ($len, $login_type, $flag, $login_token) = unpack('v l Z20 Z*', substr($msg, 2));
        # If token response contains a login token, we need to connect to the master server
        if (length($login_token)) {
            # Get master config
            my $master = $masterServer = $masterServers{$config{'master'}};
            # Set next server to connect
            $self->{nextIp} = $master->{ip};
            $self->{nextPort} = $master->{port};
        } else {
            error T("Authentication failed, token not received: $flag.\n"), "connection";
        }
        # Disconnect from token server
        message T("Closing connection to Token Server\n"), 'connection' if (!$self->{packetReplayTrial});
        $self->serverDisconnect(1);
    }

	return $msg;
}

sub modifyPacketOut {
	my ($self, $msg, $switch) = @_;

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

sub decryptMessageID {
	my ($self, $r_message) = @_;

	if(!$messageSender->{encryption}->{crypt_key} && $messageSender->{encryption}->{crypt_key_3}) {
		$currentClientKey = $messageSender->{encryption}->{crypt_key_1};
	} elsif(!$currentClientKey) {
		return;
	}

	my $messageID = unpack("v", $$r_message);

	# Saving Last Informations for Debug Log
	my $oldMID = $messageID;
	my $oldKey = ($currentClientKey >> 16) & 0x7FFF;

	# Calculating the Encryption Key
	$currentClientKey = ($currentClientKey * $messageSender->{encryption}->{crypt_key_3} + $messageSender->{encryption}->{crypt_key_2}) & 0xFFFFFFFF;

	# Xoring the Message ID
	$messageID = ($messageID ^ (($currentClientKey >> 16) & 0x7FFF)) & 0xFFFF;
	$$r_message = pack("v", $messageID) . substr($$r_message, 2);

	# Debug Log
	debug (sprintf("Decrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $messageID, $oldKey, ($currentClientKey >> 16) & 0x7FFF), "sendPacket", 0) if $config{debugPacket_sent};
}

sub getRecvPackets {
	return \%rpackets;
}

return 1;
