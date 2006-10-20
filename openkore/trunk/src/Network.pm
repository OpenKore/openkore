#########################################################################
#  OpenKore - Network - XKore Disabled
#  This module contains functions for sending packets to the server.
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
# MODULE DESCRIPTION: Connection handling
#
# The Network module handles connections to the Ragnarok Online server.
# The submodule Network::Send contains functions for sending all kinds of
# packets to the RO server.
#
# This module only handles connection issues, and nothing else. It doesn't do
# anything with the actual data. Network data is handled by another module.

package Network;

use strict;

use base qw(Exporter);
use Exporter;
use Time::HiRes qw(time);
use IO::Socket::INET;
use encoding 'utf8';

use Globals;
use Log qw(message error);
use Network::Send;
use Plugins;
use Settings;
use Utils qw(dataWaiting timeOut);
use Misc qw(chatLog);
use Translation;

##
# Network->new()
#
# Create a new network object to send and receive data from both the RO
# server and RO client.
sub new {
	my $class = shift;
	my %self;
	
	$self{remote_socket} = new IO::Socket::INET;

	bless \%self, $class;
	return \%self;
}

##
# $net->version()
# Returns: XKore mode
#
sub version {
	return 0;
}

##
# $net->DESTROY()
#
# Shutdown function. Turn everything off.
sub DESTROY {
	my $self = shift;
	
	$self->serverDisconnect();
}

######################
## Server Functions ##
######################

##
# $net->serverAliveServer()
#
sub serverAlive {
	return $_[0]->{remote_socket} && $_[0]->{remote_socket}->connected();
}

##
# $net->serverPeerHost()
#
sub serverPeerHost {
	return $_[0]->{remote_socket}->peerhost if ($_[0]->serverAlive);
	return undef;
}

##
# $net->serverPeerPort()
#
sub serverPeerPort {
	return $_[0]->{remote_socket}->peerport if ($_[0]->serverAlive);
	return undef;
}

##
# $net->serverConnect(host, port)
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
}

##
# $net->serverSend()
#
#
sub serverSend {
	my $self = shift;
	my $msg = shift;
	$self->{remote_socket}->send($msg) if ($self->serverAlive);
}

##
# $net->serverRecv()
# Returns: 
#
sub serverRecv {
	my $self = shift;
	my $msg;
	
	return undef unless (dataWaiting(\$self->{remote_socket}));
	
	$self->{remote_socket}->recv($msg, $Settings::MAX_READ);
	if ($msg eq '') {
		# Connection from server closed
		close($self->{remote_socket});
		return undef;
	}
	return $msg;
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
		$self->sendQuit() if ($conState == 5);

		message TF("Disconnecting (%s:%s)...", $self->{remote_socket}->peerhost(), 
			$self->{remote_socket}->peerport()), "connection";
		close($self->{remote_socket});
		!$self->serverAlive() ?
			message T("disconnected\n"), "connection" :
			error T("couldn't disconnect\n"), "connection";
	}
}

######################
## Client Functions ##
######################

##
# $net->clientAlive()
#
sub clientAlive {
	return undef;
}

##
# $net->clientPeerHost()
#
sub clientPeerHost {
	return undef;
}

##
# $net->clientPeerPort()
#
sub clientPeerPort {
	return undef;
}

##
# $net->clientConnect()
#
sub clientConnect {
	return undef;
}

##
# $net->clientSend()
#
# Blank function: there is no client.
sub clientSend {
	return undef;
}

##
# $net->clientRecv()
# Returns: Nothing.
#
# There is never going to be a connection with the client using Kore Mode 0
sub clientRecv {
	return undef;
}

##
# $net->clientDisconnect()
#
#
sub clientDisconnect {
	return undef;
}

#######################
## Utility Functions ##
#######################

#######################################
#######################################
#Check Connection
#######################################
#######################################

# $conState contains the connection state:
# 1: Not connected to anything		(next step -> connect to master server).
# 2: Connected to master server		(next step -> connect to login server)
# 3: Connected to login server		(next step -> connect to character server)
# 4: Connected to character server	(next step -> connect to map server)
# 5: Connected to map server; ready and functional.
#
# Special states:
# 1.2 (set by $config{gameGuard} == 2): Wait for the server response allowing us
#      to continue login
# 1.3 (set by parseMsg()): The server allowed us to continue logging in, continue
#      where we left off
# 1.5 (set by plugins): There is a special sequence for login servers and we must
#      wait the plugins to finalize before continuing
# 2.5 (set by parseMsg()): Just passed character selection; next 4 bytes will be
#      the account ID

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

	if ($conState == 1 && (!$self->{remote_socket} || !$self->{remote_socket}->connected) && timeOut($timeout_ex{'master'}) && !$conState_tries) {
		my $master = $masterServer = $masterServers{$config{'master'}};

		if ($master->{serverType} ne '' && $config{serverType} != $master->{serverType}) {
			main::configModify('serverType', $master->{serverType});
		}
		if ($master->{chatLangCode} ne '' && $config{chatLangCode} != $master->{chatLangCode}) {
			main::configModify('chatLangCode', $master->{chatLangCode});
		}
		if ($master->{storageEncryptKey} ne '' && $config{storageEncryptKey} ne $master->{storageEncryptKey}) {
			main::configModify('storageEncryptKey', $master->{storageEncryptKey});
		}
		if ($master->{serverEncoding} ne '' && $config{serverEncoding} ne $master->{serverEncoding}) {
			main::configModify('serverEncoding', $master->{serverEncoding});
		} elsif ($config{serverEncoding} eq '') {
			main::configModify('serverEncoding', 'Western');
		}
		if ($master->{gameGuard} ne '' && $config{gameGuard} != $master->{gameGuard}) {
			main::configModify('gameGuard', $master->{gameGuard});
		}

		message T("Connecting to Account Server...\n", "connection");
		$shopstarted = 1;
		$conState_tries++;
		$initSync = 1;
		undef $msg;
		$packetParser = Network::Receive->create($config{serverType});
		$self->serverConnect($master->{ip}, $master->{port});
		
		# call plugin's hook to determine if we can continue the work
		if ($self->serverAlive) {
			Plugins::callHook("Network::serverConnect/master");
			return if ($conState == 1.5);
		}

		# GameGuard support
		if ($self->serverAlive && $config{gameGuard} == 2) {
			my $msg = pack("C*", 0x58, 0x02);
			$net->serverSend($msg);
			message T("Requesting permission to logon on account server...\n");
			$conState = 1.2;
			return;
		}

		if ($self->serverAlive && $master->{secureLogin} >= 1) {
			my $code;

			message T("Secure Login...\n"), "connection";
			undef $secureLoginKey;

			if ($master->{secureLogin_requestCode} ne '') {
				$code = $master->{secureLogin_requestCode};
			} elsif ($config{secureLogin_requestCode} ne '') {
				$code = $config{secureLogin_requestCode};
			}

			if ($code ne '') {
				$self->sendMasterCodeRequest('code', $code);
			} else {
				$self->sendMasterCodeRequest('type', $master->{secureLogin_type});
			}

		} elsif ($self->serverAlive) {
			$self->sendPreLoginCode($master->{preLoginCode}) if ($master->{preLoginCode});
			$self->sendMasterLogin($config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;

	# we skipped some required connection operations while waiting for the server to allow as to login,
	# after we have successfully sent in the reply to the game guard challenge (using the poseidon server)
	# this conState will allow us to continue from where we left off.
	} elsif ($conState == 1.3) {
		$conState = 1;
		my $master = $masterServer = $masterServers{$config{'master'}};
		if ($master->{secureLogin} >= 1) {
			my $code;

			message T("Secure Login...\n"), "connection";
			undef $secureLoginKey;

			if ($master->{secureLogin_requestCode} ne '') {
				$code = $master->{secureLogin_requestCode};
			} elsif ($config{secureLogin_requestCode} ne '') {
 				$code = $config{secureLogin_requestCode};
			}

			if ($code ne '') {
				sendMasterCodeRequest(\$remote_socket, 'code', $code);
			} else {
				sendMasterCodeRequest(\$remote_socket, 'type', $master->{secureLogin_type});
			}

		} else {
			sendPreLoginCode(\$remote_socket, $master->{preLoginCode}) if ($master->{preLoginCode});
			sendMasterLogin(\$remote_socket, $config{'username'}, $config{'password'},
				$master->{master_version}, $master->{version});
		}

		$timeout{'master'}{'time'} = time;
		
	} elsif ($conState == 1 && $masterServer->{secureLogin} >= 1 && $secureLoginKey ne ""
	   && !timeOut($timeout{'master'}) && $conState_tries) {

		my $master = $masterServer;
		message T("Sending encoded password...\n"), "connection";
		$self->sendMasterSecureLogin($config{'username'}, $config{'password'}, $secureLoginKey,
				$master->{version}, $master->{master_version},
				$master->{secureLogin}, $master->{secureLogin_account});
		undef $secureLoginKey;

	} elsif ($conState == 1 && timeOut($timeout{'master'}) && timeOut($timeout_ex{'master'})) {
		error T("Timeout on Account Server, reconnecting...\n"), "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		$self->serverDisconnect;
		undef $conState_tries;

	} elsif ($conState == 1.5) {
		
		if (!$self->serverAlive) {
			$conState = 1;
			undef $conState_tries;
			return;
		}
		
		# on this special stage, the plugin will know what to do next.
		Plugins::callHook("Network::serverConnect/special");
		
	} elsif ($conState == 2 && !$self->serverAlive()
	  && ($config{'server'} ne "" || $masterServer->{charServer_ip})
	  && !$conState_tries) {
		message "Pausing for $config{pauseCharServer} second(s)...\n", "system";
		sleep $config{pauseCharServer} if ($config{pauseCharServer});
		my $master = $masterServer;
		message T("Connecting to Character Server...\n"), "connection";
		$conState_tries++;

		if ($master->{charServer_ip}) {
			$self->serverConnect($master->{charServer_ip}, $master->{charServer_port});
		} elsif ($servers[$config{'server'}]) {
			$self->serverConnect($servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});
		} else {
			error TF("Invalid server specified, server %s does not exist...\n", $config{server}), "connection";

			my @serverList;
			foreach my $server (@servers) {
				push @serverList, $server->{name};
			}
			my $ret = $interface->showMenu(T("Select Login Server"),
						       T("Please select your login server."),
						       \@serverList);
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
			Plugins::callHook("Network::serverConnect/char");
			return if ($conState == 1.5);
		}
		
		$self->sendGameLogin($accountID, $sessionID, $sessionID2, $accountSex);
		$timeout{'gamelogin'}{'time'} = time;

	} elsif ($conState == 2 && timeOut($timeout{'gamelogin'})
	  && ($config{'server'} ne "" || $masterServer->{'charServer_ip'})) {
		error T("Timeout on Character Server, reconnecting...\n"), "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		$self->serverDisconnect;
		undef $conState_tries;
		$conState = 1;

	} elsif ($conState == 3 && !$self->serverAlive() && $config{'char'} ne "" && !$conState_tries) {
		message T("Connecting to Character Select Server...\n"), "connection";
		$conState_tries++;
		$self->serverConnect($servers[$config{'server'}]{'ip'}, $servers[$config{'server'}]{'port'});

		# call plugin's hook to determine if we can continue the connection
		if ($self->serverAlive) {
			Plugins::callHook("Network::serverConnect/charselect");
			return if ($conState == 1.5);
		}
				
		$self->sendCharLogin($config{'char'});
		$timeout{'charlogin'}{'time'} = time;

	} elsif ($conState == 3 && timeOut($timeout{'charlogin'}) && $config{'char'} ne "") {
		error T("Timeout on Character Select Server, reconnecting...\n"), "connection";
		$timeout_ex{'master'}{'time'} = time;
		$timeout_ex{'master'}{'timeout'} = $timeout{'reconnect'}{'timeout'};
		$self->serverDisconnect;
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 4 && !$self->serverAlive() && !$conState_tries) {
		message "Pausing for $config{pauseMapServer} second(s)...\n", "system";
		sleep($config{pauseMapServer}) if ($config{pauseMapServer});
		message T("Connecting to Map Server...\n"), "connection";
		$conState_tries++;
		main::initConnectVars();
		my $master = $masterServer;
		if ($master->{private}) {
			$self->serverConnect($config{forceMapIP} || $master->{ip}, $map_port);
		} else {
			$self->serverConnect($config{forceMapIP} || $map_ip, $map_port);
		}

		# call plugin's hook to determine if we can continue the connection
		if ($self->serverAlive) {
			Plugins::callHook("Network::serverConnect/mapserver");
			return if ($conState == 1.5);
		}

		$self->sendMapLogin($accountID, $charID, $sessionID, $accountSex2);
		$timeout_ex{master}{time} = time;
		$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
		$timeout{maplogin}{time} = time;

	} elsif ($conState == 4 && timeOut($timeout{maplogin})) {
		message T("Timeout on Map Server, connecting to Account Server...\n"), "connection";
		$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
		$self->serverDisconnect;
		$conState = 1;
		undef $conState_tries;

	} elsif ($conState == 5 && !$self->serverAlive()) {
		Plugins::callHook('disconnected');
		if ($config{dcOnDisconnect}) {
			chatLog("k", T("*** You disconnected, auto quit! ***\n"));
			error T("Disconnected from Map Server, exiting...\n"), "connection";
			$quit = 1;
		} else {
			error TF("Disconnected from Map Server, connecting to Account Server in %s seconds...\n", $timeout{reconnect}{timeout}), "connection";
			$timeout_ex{master}{time} = time;
			$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
			$conState = 1;
			undef $conState_tries;
		}

	} elsif ($conState == 5 && timeOut($timeout{play})) {
		error T("Timeout on Map Server, "), "connection";
		Plugins::callHook('disconnected');
		if ($config{dcOnDisconnect}) {
			error T("exiting...\n"), "connection";
			$quit = 1;
		} else {
			error TF("connecting to Account Server in %s seconds...\n", $timeout{reconnect}{timeout}), "connection";
			$timeout_ex{master}{time} = time;
			$timeout_ex{master}{timeout} = $timeout{reconnect}{timeout};
			$self->serverDisconnect;
			$conState = 1;
			undef $conState_tries;
		}
	}
}

return 1;
