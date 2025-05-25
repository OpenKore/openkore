#########################################################################
#  OpenKore - Networking subsystem
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#
#  $Revision: 7069 $
#  $Id: Network.pm 7069 2010-01-16 02:23:00Z klabmouse $
#
#########################################################################
##
# MODULE DESCRIPTION: Connection handling
#
# The Network module handles connections to the Ragnarok Online server.
# This module only handles connection issues, and nothing else. It doesn't do
# anything with the actual data. Network data handling is performed by
# the @MODULE(Network::Receive) and Network::Receive::ServerTypeX classes.
#
# The submodule @MODULE(Network::Send) contains functions for sending all
# kinds of messages to the RO server.
#
# Please also read <a href="https://openkore.com/wiki/Network_subsystem">the
# network subsystem overview.</a>
#
# This implementation establishes a direct connection to the RO server.
# Note that there are alternative implementations for this interface: @MODULE(Network::XKore),
# @MODULE(Network::XKore2) and @MODULE(Network::XKoreProxy)

package Network::DirectConnection;

use strict;
use Modules 'register';
use Exporter;
use base qw(Exporter);
use Time::HiRes qw(time);
use IO::Socket::INET;
use utf8;
use Scalar::Util;
use File::Spec;

use Globals;
use Log qw(message warning error);
use Misc qw(chatLog);
use Network;
use Network::Send ();
use Plugins;
use Settings;
use Interface;
use Utils qw(dataWaiting timeOut);
use Utils::Exceptions;
use Translation;

##
# Network::DirectConnection->new([wrapper])
# wrapper: If this object is to be wrapped by another object which is interface-compatible
#          with the Network::DirectConnection class, then specify the wrapper object here. The message
#          sender will use this wrapper to send socket data. Internally, the reference to the wrapper
#          will be stored as a weak reference.
#
# Create a new Network::DirectConnection object. The connection is not yet established.
sub new {
	my ($class, $wrapper) = @_;
	my %self;

	$self{remote_socket} = new IO::Socket::INET;
	if ($wrapper) {
		$self{wrapper} = $wrapper;
		Scalar::Util::weaken($self{wrapper});
	}

	return bless \%self, $class;
}

##
# int $net->version()
#
# Returns the implementation number this object.
sub version {
	return 0;
}

sub DESTROY {
	my $self = shift;

	$self->serverDisconnect();
}


######################
## Server Functions ##
######################

##
# boolean $net->serverAliveServer()
#
# Check whether the connection to the server is alive.
sub serverAlive {
	return $_[0]->{remote_socket} && $_[0]->{remote_socket}->connected();
}

##
# String $net->serverPeerHost()
#
# If the connection to the server is alive, returns the host name of the server.
# Otherwise, returns undef.
sub serverPeerHost {
	return $_[0]->{remote_socket}->peerhost if ($_[0]->serverAlive);
	return undef;
}

##
# int $net->serverPeerPort()
#
# If the connection to the server is alive, returns the port number of the server.
# Otherwise, returns undef.
sub serverPeerPort {
	return $_[0]->{remote_socket}->peerport if ($_[0]->serverAlive);
	return undef;
}

##
# $net->serverConnect(String host, int port)
# host: the host name/IP of the RO server to connect to.
# port: the port number of the RO server to connect to.
#
# Establish a connection to a Ragnarok Online server.
#
# This function is used internally by $net->checkConnection() and should not be used directly.
sub serverConnect {
	my $self = shift;
	my $host = shift;
	my $port = shift;
	my $return = 0;

	Plugins::callHook('Network::connectTo', {
		socket => \$self->{remote_socket},
		return => \$return,
		host => $host,
		port => $port
	});
	return if ($return);

	message TF("Connecting (%s:%s)... ", $host, $port), "connection";
	$self->{remote_socket} = new IO::Socket::INET(
			LocalAddr	=> $config{bindIp} || undef,
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp',
			Timeout		=> 4);
	($self->{remote_socket} && inet_aton($self->{remote_socket}->peerhost()) eq inet_aton($host)) ?
		message T("connected\n"), "connection" :
		error(TF("couldn't connect: %s (error code %d)\n", "$!", int($!)), "connection");
	if ($self->getState() != Network::NOT_CONNECTED) {
		$incomingMessages->nextMessageMightBeAccountID();
	}
}

##
# void $net->serverSend(Bytes data)
#
# If the connection to the server is alive, send data to the server.
# Otherwise, this method does nothing.
sub serverSend {
	my $self = shift;
	my $msg = shift;
	if ($self->serverAlive) {
		if (Plugins::hasHook('Network::serverSend/pre')) {
			Plugins::callHook('Network::serverSend/pre', {msg => \$msg});
		}
		if (defined $msg) {
			$self->{remote_socket}->send($msg);
			if (Plugins::hasHook('Network::serverSend')) {
				Plugins::callHook('Network::serverSend', {msg => $msg});
			}
		}
	}
}

##
# Bytes $net->serverRecv()
#
# Receive data from the RO server.
sub serverRecv {
	my $self = shift;
	my $msg;

	return undef unless (dataWaiting(\$self->{remote_socket}));

	$self->{remote_socket}->recv($msg, 1024 * 32);
	if (Plugins::hasHook('Network::serverRecv')) {
		Plugins::callHook('Network::serverRecv', {msg => \$msg});
	}
	if (!defined($msg) || length($msg) == 0) {
		# Connection from server closed.
		close($self->{remote_socket});
		return undef;
	}
	return $msg;
}

##
# Bytes $net->serverAddress()
#
# Return the server's raw address.
sub serverAddress {
	my ($self) = @_;
	return $self->{remote_socket}->sockaddr();
}

##
# $net->serverDisconnect()
#
# Disconnect from the current Ragnarok Online server.
#
# This function is used internally by $net->checkConnection() and should not be used directly.
sub serverDisconnect {
	my $self = shift;

	if ($self->serverAlive) {
		if ($incomingMessages && length(my $incoming = $incomingMessages->getBuffer)) {
				warning TF("Incoming data left in the buffer:\n");
				Misc::visualDump($incoming);

				if (defined(my $rplen = $incomingMessages->{rpackets}{my $switch = Network::MessageTokenizer::getMessageID($incoming)})) {
					my $inlen = do { no encoding 'utf8'; use bytes; length $incoming };
					if (($rplen->{length} > $inlen) || ($rplen->{minLength} > $inlen)) { # check for minLength too, if defined
						warning TF("Only %d bytes in the buffer, when %s's packet length is supposed to be %d (wrong recvpackets?)\n", $inlen, $switch, $rplen);
					}
				}
		}

		$messageSender->sendQuit() if ($self->getState() == Network::IN_GAME);

		message TF("Disconnecting (%s:%s)...", $self->{remote_socket}->peerhost(),
			$self->{remote_socket}->peerport()), "connection";
		close($self->{remote_socket});

		if ($self->serverAlive()) {
			error T("couldn't disconnect\n"), "connection";
			Plugins::callHook('serverDisconnect/fail');
		} else {
			message T("disconnected\n"), "connection";
			Plugins::callHook('serverDisconnect/success');
		}
	}
}

sub getState {
	return $conState;
}

sub setState {
	my ($self, $state) = @_;
	$conState = $state;
	Plugins::callHook('Network::stateChanged');
}


######################
## Client Functions ##
######################

##
# boolean $net->clientAlive()
#
# Check whether there are one or more clients connected to Kore.
sub clientAlive {
	my %args = (net => $_[0]);
	Plugins::callHook('Network::clientAlive', \%args);
	return $args{return};
}

##
# $net->clientSend(Bytes data)
#
# Make the RO client think that it has received $data.
sub clientSend {
	my ($self) = @_;
	if ($self->clientAlive && Plugins::hasHook('Network::clientSend')) {
		my %args = (net => $self, data => $_[1]);
		Plugins::callHook('Network::clientSend', \%args);
		return $args{return};
	} else {
		return undef;
	}
}

##
# Bytes $net->clientRecv()
#
# Receive data that the RO client wants to send to the RO server.
sub clientRecv {
	my ($self) = @_;
	if ($self->clientAlive) {
		my %args = (net => $_[0]);
		Plugins::callHook('Network::clientRecv', \%args);
		return $args{return};
	} else {
		return undef;
	}
}


#######################
## Utility Functions ##
#######################

#######################################
#######################################
# Check Connection
#######################################
#######################################

##
# $net->checkConnection()
#
# Handles any connection issues. Based on the current situation, this function may
# re-connect to the RO server, disconnect, do nothing, etc.
#
# This function is meant to be run in the Kore main loop.
sub checkConnection {
	my $self = shift;

	return if ($Settings::no_connect);
	
	my %plugin_args = ( return => 0 );
	Plugins::callHook('checkConnection' => \%plugin_args);
	return if ($plugin_args{return});

	if ($self->getState() == Network::NOT_CONNECTED && (!$self->{remote_socket} || !$self->{remote_socket}->connected) && timeOut($timeout_ex{'master'}) && !$conState_tries) {
		my $master = $masterServer = $masterServers{$config{master}};

		message T("Connecting to Account Server...\n"), "connection";
		$shopstarted = 1;
		$conState_tries++;
		$initSync = 1;
		$incomingMessages->clear();

		eval {
			my $wrapper = ($self->{wrapper}) ? $self->{wrapper} : $self;
			$packetParser = Network::Receive->create($wrapper, $masterServer->{serverType});
			$messageSender = Network::Send->create($wrapper, $masterServer->{serverType});
		};
		if ($@) {
			$interface->errorDialog("$@");
			$quit = 1;
			return;
		}
		$reconnectCount++;
		$self->serverConnect($master->{ip}, $master->{port});

		# call plugin's hook to determine if we can continue the work
		if ($self->serverAlive) {
			Plugins::callHook('Network::serverConnect/master');
			return if ($conState == 1.5);
		}

		# GameGuard support
		if ($self->serverAlive && $masterServer->{gameGuard} == 2) {
			my $msg = pack("v", 0x0258);
			$net->serverSend($msg);
			message T("Requesting permission to logon on account server...\n");
			$conState = 1.2;

			# Saving Last Request Time (Logon) (GG/HS Query)
			$timeout{poseidon_wait_reply}{time} = time;

			return;
		}

		if ($self->serverAlive && $master->{secureLogin} >= 1) {
			my $code;

			message T("Secure Login...\n"), "connection";
			undef $secureLoginKey;

			if ($master->{secureLogin_requestCode} ne '') {
				$code = $master->{secureLogin_requestCode};
			}

			if ($code ne '') {
				$messageSender->sendToServer($messageSender->reconstruct({
					switch => 'client_hash',
					code => $code,
				}));
			} elsif ($master->{secureLogin_type}) {
				$messageSender->sendToServer($messageSender->reconstruct({
					switch => 'client_hash',
					type => $master->{secureLogin_type},
				}));
			}

			$messageSender->sendToServer($messageSender->reconstruct({
				switch => 'secure_login_key_request',
			}));

		} elsif ($self->serverAlive) {
			$messageSender->sendPreLoginCode($master->{preLoginCode}) if ($master->{preLoginCode});
			$messageSender->sendMasterLogin($config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;
	} elsif ($self->getState() == 1.2) {
	# Checking if we succesful received the Game Guard Confirmation (Should Happen Sooner)
		if ( time - $timeout{poseidon_wait_reply}{time} > ($timeout{poseidon_wait_reply}{timeout} || 15) )
		{
			message T("The Game Guard Authorization Request\n");
			message T("has timed out, please check your poseidon server !!\n");
			message TF("Address poseidon server: %s\n", $config{'poseidonServer'});
			message TF("Port poseidon: %s\n", $config{'poseidonPort'});
			$self->serverDisconnect;
			$self->setState(Network::NOT_CONNECTED);
		}
	# we skipped some required connection operations while waiting for the server to allow as to login,
	# after we have successfully sent in the reply to the game guard challenge (using the poseidon server)
	# this conState will allow us to continue from where we left off.
	} elsif ($self->getState() == 1.3) {
		$conState = 1;
		my $master = $masterServer = $masterServers{$config{'master'}};
		if ($master->{secureLogin} >= 1) {
			my $code;

			message T("Secure Login...\n"), "connection";
			undef $secureLoginKey;

			if ($master->{secureLogin_requestCode} ne '') {
				$code = $master->{secureLogin_requestCode};
			}

			if ($code ne '') {
				$messageSender->sendToServer($messageSender->reconstruct({
					switch => 'client_hash',
					code => $code,
				}));
			} elsif ($master->{secureLogin_type}) {
				$messageSender->sendToServer($messageSender->reconstruct({
					switch => 'client_hash',
					type => $master->{secureLogin_type},
				}));
			}

			$messageSender->sendToServer($messageSender->reconstruct({
				switch => 'secure_login_key_request',
			}));

		} else {
			$messageSender->sendPreLoginCode($master->{preLoginCode}) if ($master->{preLoginCode});
			$messageSender->sendMasterLogin($config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;

	} elsif ($self->getState() == Network::NOT_CONNECTED) {
		if($masterServer->{secureLogin} >= 1 && $secureLoginKey ne "" && !timeOut($timeout{'master'}) && $conState_tries) {
			my $master = $masterServer;
			message T("Sending encoded password...\n"), "connection";
			$messageSender->sendMasterSecureLogin($config{'username'}, $config{'password'}, $secureLoginKey,
					$master->{version}, $master->{master_version},
					$master->{secureLogin}, $master->{secureLogin_account});
			undef $secureLoginKey;

		} elsif (timeOut($timeout{'master'}) && timeOut($timeout_ex{'master'})) {
			if ($config{dcOnMaxReconnections} && $config{dcOnMaxReconnections} <= $reconnectCount) {
				error T("Auto disconnecting on MaxReconnections!\n");
				chatLog("k", T("*** Exceeded the maximum number attempts to reconnect, auto disconnect! ***\n"));
				$quit = 1;
				return;
			}
			message TF("Timeout on Account Server, reconnecting. Wait %s seconds...\n", $timeout{'reconnect'}{'timeout'}), "connection";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
			$self->serverDisconnect;
			undef $conState_tries;
		}
	} elsif ($self->getState() == 1.5) {
		if (!$self->serverAlive) {
			$self->setState(Network::NOT_CONNECTED);
			undef $conState_tries;
			return;
		}

		# on this special stage, the plugin will know what to do next.
		Plugins::callHook('Network::serverConnect/special');

	} elsif ($self->getState() == Network::CONNECTED_TO_MASTER_SERVER) {
		if(!$self->serverAlive() && ($config{'server'} ne "" || $masterServer->{charServer_ip}) && !$conState_tries) {
			if ($config{pauseCharServer}) {
				message "Pausing for $config{pauseCharServer} second(s)...\n", "system";
				sleep $config{pauseCharServer};
			}
			my $master = $masterServer;
			message T("Connecting to Character Server...\n"), "connection";
			$conState_tries++;
			$captcha_state = 0;

			if ($master->{charServer_ip}) {
				$self->serverConnect($master->{charServer_ip}, $master->{charServer_port});
			} elsif ($servers[$config{'server'}]) {
				message TF("Selected server: %s\n", $servers[$config{server}]->{name}), 'connection';
				$self->serverConnect($servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});
			} else {
				error TF("Invalid server specified, server %s does not exist...\n", $config{server}), "connection";

				my @serverList;
				foreach my $server (@servers) {
					push @serverList, $server->{name};
				}
				my $ret = $interface->showMenu(
						T("Please select your login server."),
						\@serverList,
						title => T("Select Login Server"));
				if ($ret == -1) {
					quit();
				} else {
					main::configModify('server', $ret, 1);
					undef $conState_tries;
				}
				return;
			}

			# call plugin's hook to determine if we can continue the connection
			if ($self->serverAlive) {
				Plugins::callHook('Network::serverConnect/char');
				$reconnectCount = 0;
				return if ($conState == 1.5);
			}
			# TODO: the connect code needs a major rewrite =/
			unless($masterServer->{captcha}) {
				$messageSender->sendGameLogin($accountID, $sessionID, $sessionID2, $accountSex);
				$timeout{'gamelogin'}{'time'} = time;
			}
		} elsif($self->serverAlive() && $masterServer->{captcha}) {
			if ($captcha_state == 0) { # send initiate once, then wait for servers captcha_answer packet
				$messageSender->sendCaptchaInitiate();
				$captcha_state = -1;
			} elsif ($captcha_state == 1) { # captcha answer was correct, sent sendGameLogin once, then wait for servers
				$messageSender->sendGameLogin($accountID, $sessionID, $sessionID2, $accountSex);
				$timeout{'gamelogin'}{'time'} = time;
				$captcha_state = -1;
			} else {
				return;
			}
		} elsif (timeOut($timeout{'gamelogin'}) && ($config{'server'} ne "" || $masterServer->{'charServer_ip'})) {
			error TF("Timeout on Character Server, reconnecting. Wait %s seconds...\n", $timeout{'reconnect'}{'timeout'}), "connection";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
			$self->serverDisconnect;
			undef $conState_tries;
			$self->setState(Network::NOT_CONNECTED);
		}
	} elsif ($self->getState() == Network::CONNECTED_TO_LOGIN_SERVER) {
		if(!$self->serverAlive() && $config{'char'} ne "" && !$conState_tries) {
			message T("Connecting to Character Select Server...\n"), "connection";
			$conState_tries++;
			$self->serverConnect($servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});

			# call plugin's hook to determine if we can continue the connection
			if ($self->serverAlive) {
				Plugins::callHook('Network::serverConnect/charselect');
				return if ($conState == 1.5);
			}

			$messageSender->sendCharLogin($config{'char'});
			$timeout{'charlogin'}{'time'} = time;

		} elsif (timeOut($timeout{'charlogin'}) && $config{'char'} ne "") {
			error T("Timeout on Character Select Server, reconnecting...\n"), "connection";
			$timeout_ex{'master'}{'time'} = time;
			$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
			$self->serverDisconnect;
			$self->setState(Network::NOT_CONNECTED);
			undef $conState_tries;
		}
	} elsif ($self->getState() == Network::CONNECTED_TO_CHAR_SERVER) {
		if(!$self->serverAlive() && !$conState_tries) {
			if ($config{pauseMapServer}) {
				return if($config{XKore} eq 1 || $config{XKore} eq 3);
				message "Pausing for $config{pauseMapServer} second(s)...\n", "system";
				sleep($config{pauseMapServer});
			}
			message T("Connecting to Map Server...\n"), "connection";
			$conState_tries++;
			main::initConnectVars();
			my $master = $masterServer;
			my ($ip, $port);
			if ($master->{private}) {
				$ip = $config{forceMapIP} || $master->{ip};
				$port = $map_port;
			} else {
				$ip = $master->{mapServer_ip} || $config{forceMapIP} || $map_ip;
				$port = $master->{mapServer_port} || $map_port;
			}
			$self->serverConnect($ip, $port);

			# call plugin's hook to determine if we can continue the connection
			if ($self->serverAlive) {
				Plugins::callHook('Network::serverConnect/mapserver');
				return if ($conState == 1.5);
			}

			$messageSender->sendMapLogin($accountID, $charID, $sessionID, $accountSex2);
			$timeout_ex{master}{time} = time;
			$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
			$timeout{maplogin}{time} = time;

		} elsif (timeOut($timeout{maplogin})) {
			message T("Timeout on Map Server, connecting to Account Server...\n"), "connection";
			$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
			$self->serverDisconnect;
			$self->setState(Network::NOT_CONNECTED);
			undef $conState_tries;
		}
	} elsif ($self->getState() == Network::IN_GAME) {
		if(!$self->serverAlive()) {
			Plugins::callHook('disconnected');
			if ($config{dcOnDisconnect}) {
				error T("Auto disconnecting on Disconnect!\n");
				chatLog("k", T("*** You disconnected, auto disconnect! ***\n"));
				$quit = 1;
			} else {
				message TF("Disconnected from Map Server, connecting to Account Server in %s seconds...\n", $timeout{reconnect}{timeout}), "connection";
				$timeout_ex{master}{time} = time;
				$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
				$self->setState(Network::NOT_CONNECTED);
				undef $conState_tries;
			}

		} elsif (timeOut($timeout{play})) {
			error T("Timeout on Map Server, "), "connection";
			Plugins::callHook('disconnected');
			if ($config{dcOnDisconnect}) {
				error T("Auto disconnecting on Disconnect!\n");
				chatLog("k", T("*** You disconnected, auto disconnect! ***\n"));
				$quit = 1;
			} else {
				error TF("connecting to Account Server in %s seconds...\n", $timeout{reconnect}{timeout}), "connection";
				$timeout_ex{master}{time} = time;
				$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
				$self->serverDisconnect;
				$self->setState(Network::NOT_CONNECTED);
				undef $conState_tries;
			}
		}
	}
}

return 1;
