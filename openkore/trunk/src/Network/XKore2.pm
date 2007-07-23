#########################################################################
#  OpenKore - X-Kore Mode 2
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
package Network::XKore2;

use strict;
use Exporter;
use base qw(Exporter);
use IO::Socket::INET;

use Modules 'register';
use Globals;
use Log qw(message debug error);
use Utils qw(dataWaiting timeOut shiftPack unShiftPack);
use Misc;
use Translation;
use Network;
use Network::Send ();

sub new {
	my $class = shift;
	my $self = bless {}, $class;

	# Reuse code from Network::DirectConnection to keep the connection to the server
	require Network::DirectConnection;
	$self->{server} = new Network::DirectConnection($self);

	return undef unless $self->{server};

	$self->{tracker_state} = 0;
	$self->{tracker_name} = $config{XKore_ID} || "XKore2";

	$self->{client_state} = 0;
	$self->{client_listenPort} = $config{XKore_listenPort} ||
		($config{XKore_tracker}?6902+int(rand(98)) : 6900);

	# int challengeNum
	#
	# The number of times that the RO client has sent a
	# GameGuard challenge packet.
	# Taken from Poseidon/RagnarokServer.pm
	#
	# Invariant: challengeNum >= 0

	$self->{challengeNum} = 0;

	return $self;
}

sub version {
	return 2;
}

sub DESTROY {
	my $self = shift;

	$self->serverDisconnect;
	if ($self->clientAlmostAlive) {
		$self->clientSend(pack('C3', 0x81, 0, 1));
		$self->clientDisconnect;
	} else {
		close($self->{client_listen});
	}
	close($self->{tracker}) if ($self->trackerAlive);
	undef $self->{server};
}

######################
## Server Functions ##
######################

sub serverAlive {
	my ($self) = @_;
	return $self->{server}->serverAlive;
}

sub serverConnect {
	my ($self, $host, $port) = @_;
	return $self->{server}->serverConnect($host, $port);
}

sub serverPeerHost {
	my ($self) = @_;
	return $self->{server}->serverPeerHost();
}

sub serverPeerPort {
	my ($self) = @_;
	return $self->{server}->serverPeerPort();
}

sub serverRecv {
	my ($self) = @_;
	return $self->{server}->serverRecv();
}

sub serverSend {
	my ($self, $msg) = @_;
	return $self->{server}->serverSend($msg);
}

sub serverDisconnect {
	my ($self) = @_;
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
	return $_[0]->clientAlmostAlive && $_[0]->{client_state} == 5;
}

sub clientAlmostAlive {
	return $_[0]->{client} && $_[0]->{client}->connected;
}

sub clientPeerHost {
	return $_[0]->{client}->peerhost if ($_[0]->clientAlmostAlive);
	return undef;
}

sub clientPeerPort {
	return $_[0]->{client}->peerport if ($_[0]->clientAlmostAlive);
	return undef;
}

sub clientSend {
	use bytes;
	no encoding 'utf8';
	my $self = shift;
	my $msg = shift;
	my $dontMod = shift;

	$msg = $self->modifyPacketIn($msg) unless ($dontMod || $self->{client_saved}{plugin_packet_in});
	if ($config{debugPacket_ro_received}) {
		visualDump($msg, 'clientSend');
	}
	$self->{client}->send($msg) if (($self->clientAlmostAlive && $dontMod) || $self->clientAlive);
}

sub clientRecv {
	use bytes;
	no encoding 'utf8';
	my $self = shift;
	my $msg;

	return undef unless ($self->clientAlive);

	return $self->modifyPacketOut($self->realClientRecv);
}

##
# Bytes $net->realClientRecv
#
# Returns data coming from the client. Used internally until client is fully
# logged in. Should only be used internally.
sub realClientRecv {
	use bytes;
	no encoding 'utf8';
	my $self = shift;
	my $msg;

	return undef unless (dataWaiting(\$self->{client}));

	$self->{client}->recv($msg, $Settings::MAX_READ);
	if ($msg eq '') {
		# Connection from server closed
		close($self->{client});
		return undef;
	}
	return $msg;
}

sub clientDisconnect {
	my $self = shift;
	if ($self->clientAlmostAlive) {
		debug("Disconnecting RO client (".$self->{client}->peerhost().":".$self->{client}->peerport().
			")... ", "connection");
		close($self->{client});
		!$self->clientAlive() ?
			debug("disconnected\n", "connection") :
			debug("couldn't disconnect\n", "connection");
	}
}

#######################
## Utility Functions ##
#######################

sub trackerAlive {
	return $_[0]->{tracker} && $_[0]->{tracker}->connected;
}

sub checkConnection {
	my $self = shift;

	# Check connection to the client
	$self->checkClient();

	# Check server connection
	$self->{server}->checkConnection();

	# Check connection to the tracker/emulated master server
	$self->checkTracker() if ($config{XKore_tracker});
}

sub checkTracker {
	my $self = shift;
	my $t_state = \$self->{tracker_state};
	my $host = $config{XKore_trackerIp} || 'localhost';
	my $port = $config{XKore_trackerPort} || 6901;

	return unless (defined $self->{client_listen} && $self->serverAlive && $self->getState() == Network::IN_GAME);

	if ($$t_state == 0 && timeOut($timeout{xkore_tracker})) {
		debug("Connecting to XKore2 master ($host:$port)... ", "connection");
		# Make a connection to the tracker/master server
		$self->{tracker} = new IO::Socket::INET(
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp',
			Timeout		=> 4);

		if ($self->{tracker} && inet_aton($self->{tracker}->peerhost()) eq inet_aton($host)) {
			debug("connected\n", "connection");
			$$t_state = 1;
		} else {
			error TF("couldn't connect: %s\n", $!), "connection";
		}
		$timeout{xkore_tracker}{time} = time;
	} elsif ($$t_state == 1 && $self->trackerAlive) {
		# Send kore ID/name
		$self->{tracker}->send("N".pack('v',length($self->{tracker_name})).$self->{tracker_name});

		# Send listening address
		if ($config{XKore_listenIp}) {
			$self->{tracker}->send("A".pack('v',length($config{XKore_listenIp})).$config{XKore_listenIp});
		}

		# Send listening port
		$self->{tracker}->send("P".pack('v', $self->{server}->sockport));

		$timeout{injectSync}{time} = time;
		$$t_state = 2;
	} elsif ($$t_state == 2 && $self->trackerAlive) {
		if (dataWaiting(\$self->{tracker})) {
			my $msg;
			$self->{tracker}->recv($msg, $Settings::MAX_READ);
			if ($msg eq '') {
				# Connection from tracker closed
				close($self->{tracker});
				$$t_state = 0;
				return;
			}

			my $switch = substr($msg,0,1);
			my $len = unpack('v',substr($msg,1,3));

			if ($switch eq "A") {
				$self->{client_fakeInfo}{accountID} = substr($msg,3,$len);
			} elsif ($switch eq "S") {
				$self->{client_fakeInfo}{sessionID} = substr($msg,3,$len);
			} elsif ($switch eq "G") {
				$self->{client_fakeInfo}{sex} = substr($msg,3,$len);
			} elsif ($switch eq "T") {
				$self->{client_fakeInfo}{sessionID2} = substr($msg,3,$len);
			}

			$timeout{xkore_tracker}{time} = time;
		}
		if ($self->trackerAlive && timeOut($timeout{'xkore_tracker'})) {
			$self->{tracker}->send("K".pack('v',0));
		}
	} elsif (!$self->trackerAlive && timeOut($timeout{xkore_tracker})) {
		debug "Lost connection to XKore2 master, reconnecting...\n", "connection";
		$timeout{'xkore_tracker'}{time} = time;
		$$t_state = 0;
	}
}

sub checkClient {
	my $self = shift;

	# Check if the client is active when the server is not.
	if ($self->getState() != Network::IN_GAME && $self->clientAlmostAlive && $self->{client_state} > 0) {
		# Kick the client if they haven't logged in before
		unless ($self->{client_state} == 5 && !$self->{client_saved}{custom}) {
			error "$self->{client_state}\n";
			# "Blocked from server until ______"
			$self->clientSend(pack('C3 Z20', 0x6A, 0, 6, "$Settings::NAME connects"),1);

			$self->{client_state} = 0;
			$self->{client_msgIn} = "";

			# Flush the buffer, so the client data doesn't get sent to server.
			$self->realClientRecv();

		} else {
			# Plunk the user down in a black hole, and give them a warning that we got disconnected

			# Allow the plugins to change the map
			my ($map, $x, $y) = ("$field{name}.gat", 500, 500);
			Plugins::callHook('XKore/map', {r_map => \$map, r_x => \$x, r_y => \$y});

			my $msg = pack('C2 Z16 v2', 0x91, 0, $map, $x, $y);
			$self->clientSend($msg,1);
			$self->{client_state} = -2;
		}

		return;
	}

	# Nothing to do if the client is working.
	return if ($self->clientAlive);
	
	if (defined $self->{client_listen}) {
		# Listening for a client
		if (dataWaiting($self->{client_listen})) {
			# Client is connecting...
			$self->{client} = $self->{client_listen}->accept;

			# Tell 'em about the new client
			my $host = $self->clientPeerHost;
			my $port = $self->clientPeerPort;
			debug "RO Client connection from ($host:$port).\n", "connection";

			# Determine the client state
			$self->{client_state} = 0 if ($self->{client_state} != 1
					&& $self->{client_state} != 3);

			# Stop listening.
			close($self->{client_listen});
			undef $self->{client_listen};

			# Shutdown the connection with the tracker.
			if ($config{XKore_tracker} && $self->trackerAlive) {
				$self->{client_state} = 1 if ($self->{client_state} == 0);
				close($self->{tracker});
				undef $self->{tracker};
			}
		}

		return;
	} elsif (!$self->clientAlmostAlive) {
		# Client disconnected... (or never existed)

		# Didn't give an error to the client yet...
		$self->{client_saved}{gave_error} = 0;
		$self->{client_saved}{bypass_inMod} = 0;

		undef $self->{client};
		# Begin listening...
		if (!$self->{client_listen}) {
			my $ip = $config{XKore_listenIp} || '0.0.0.0';
			$self->{client_listen} = new IO::Socket::INET(
				LocalAddr	=> $ip,
				LocalPort	=> $self->{client_listenPort},
				Listen		=> 1,
				Proto		=> 'tcp',
				ReuseAddr   => 1);
			die TF("Unable to listen on XKore2 port (%s:%s): %s", $ip, $self->{client_listenPort}, $@) unless $self->{client_listen};
		}

		debug "Client disconnected.\n", "connection";

		return;
	}

	my $host = $self->clientPeerHost;
	my $port = $self->clientPeerPort;

	# Client is logging in to XKore mode 2.
	my $msgIn = $self->realClientRecv();

	return unless ($msgIn);

	$self->{client_msgIn} .= $msgIn if ($self->{client_msgIn});
	$self->{client_msgIn} = $msgIn unless ($self->{client_msgIn});

	$msgIn = \$self->{client_msgIn};
	return if (length($$msgIn) < 3);
	my $c_state = \$self->{client_state};
	my $switch = uc(unpack("H2", substr($$msgIn, 1, 1))) . uc(unpack("H2", substr($$msgIn, 0, 1)));

	# Determine packet length using recvpackets.txt.
	my $msg_size;
	if ($rpackets{$switch} eq "-" || $switch eq "0070") {
		# Complete packet; the size of this packet is equal
		# to the size of the entire data
		$msg_size = length($$msgIn);

	} elsif ($rpackets{$switch} eq "0") {
		$msg_size = unpack("v1", substr($$msgIn, 2, 2));
		return if (length($$msgIn) < $msg_size);

	} elsif ($rpackets{$switch} > 1) {
		# Static length packet
		$msg_size = $rpackets{$switch};
		return if (length($$msgIn) < $msg_size);
	}

	my $msg = substr($$msgIn,0,$msg_size);

	debug "RO Client ($host:$port) -> ", "connection";

	# Allow the login packet for any of the connection states
	# 0 = waiting for connection to login "server"
	# 1 = waiting for connection to character "server"
	# 3 = waiting for connection to map "server"
	if (($$c_state == 0 || $$c_state == 1 || $$c_state == 3)
		&& $switch eq "0064") {
		# Client sent MasterLogin
		my ($version, $username, $password, $master_version) = unpack("x2 V Z24 Z24 C1", $msg);

		# Allow custom plugins to take over
		$self->{client_saved}{custom} = 0;
		Plugins::callHook('XKore/master_login', {version => $version,
			username => $username,
			password => $password,
			master_version => $master_version,
			r_customXKore => \$self->{client_saved}{custom}});

		# Check login information
		if (!$self->{client_saved}{custom} &&
			(($config{adminPassword} && $password ne $config{adminPassword}) ||
			lc($username) ne lc($config{username}))) {

			error T("XKore 2 failed login: Invalid Username and/or Password.\n"), "connection";
			$self->clientSend(pack('C3 x20', 0x6A, 00, 1),1);
		} else {
			# Determine public IP
			my $host = gethostbyname(($self->clientPeerHost eq '127.0.0.1')?
				'127.0.0.1' :
				($config{XKore_publicIp} || '127.0.0.1'));
			$host = inet_ntoa('127.0.0.1') unless (defined $host);

			# Send out the login packet
			$msg = pack('a4 a4 a4 x30 C1 a4 v Z20 v C1 x14', $sessionID, $accountID, $sessionID2, $accountSex2,
				# IP ->	Port --------------------->
				$host,	$self->{client_listenPort},
				# Name ---------------->	Number of Players -->	Display (5 = "don't show number of players")
				$self->{tracker_name},		0,			5);
			$msg = pack('C2 v', 0x69, 00, length($msg)+4) . $msg;
			$self->clientSend($msg,1);
			debug "Master Login.\n", "connection";

			$$c_state = 1;
		}

	} elsif ($switch eq '0258') { # client sent gameguard's challenge request
		# Reply with "gameguard_grant" instead of a 0227 packet. Normally, the server would
		# send a 0227 gameguard challenge to the client, then the client will send the
		# proper 0228 response. Only after that will the server send 0259 to allow the
		# client to continue the login sequence. Since this is just a fake server,
		# there is no need to go through all that and we can do a shortcut.
		if ($self->{challengeNum} == 0) {
			message T("Received GameGuard sync request. Client allowed to login account server.\n");
			$self->clientSend(pack("C*", 0x59,0x02,0x01));
		} else {
			message T("Received GameGuard sync request. Client allowed to login char/map server.\n");
			$self->clientSend(pack("C*", 0x59,0x02,0x02));
		}
		$self->{challengeNum}++;
	
	} elsif ($$c_state == 1 && $switch eq "0065") {
		# Client sent GameLogin
		#my $msg = pack("C*", 0x65,0) . $accountID . $sessionID . $sessionID2 . pack("C*", 0,0,$sex);

		# Send the account ID
		$self->clientSend($accountID,1);

		# Generate the character information
		my $charMsg = pack('x106');

		# ID, Base exp, zeny, job exp, job level
		substr($charMsg, 0, 18) = pack('a4 V3 v', $charID, $char->{exp}, $char->{zenny}, $char->{exp_job},
			$char->{lv_job});

		substr($charMsg, 42, 64) = pack('v7 x2 v x2 v x2 v4 Z24 C6 v', $char->{hp}, $char->{hp_max}, $char->{sp}, $char->{sp_max},
			$char->{walk_speed} * 1000, $char->{jobID}, $char->{hair_style}, $char->{lv}, $char->{headgear}{low},
			$char->{headgear}{top}, $char->{headgear}{mid}, $char->{hair_color}, $char->{clothes_color},
			$char->{name}, $char->{str}, $char->{agi}, $char->{vit}, $char->{int}, $char->{dex}, $char->{luk}, 0);

		# Send the character info packet
		$msg = pack('C2 v' .
			(($self->{client_saved}{char_info_padding})
				? ' x' . $self->{client_saved}{char_info_padding}
				: ''),
			0x6B, 0x00, length($charMsg) + 4 + $self->{client_saved}{char_info_padding})
			. $charMsg;

		# Give any custom plugins a chance to change the packet before we send it.
		Plugins::callHook('XKore/characters', {r_packet => \$msg});

		$self->clientSend($msg,1);

		debug "Game Login.\n", "connection";
		$$c_state = 2;

		# Bypass client_state 2, send the character and map info packet
		# WARNING: This doesn't work here? Character shows up as a novice with a name of random data.
		#$msg = pack('C2 a4 Z16 C4 v1', 0x71, 0, $charID, $self->{client_saved}{map},
		#		127, 0, 0, 1, $self->{client_listenPort});
		#$self->clientSend($msg,1);

		#$$c_state = 3;

	} elsif ($$c_state == 2 && $switch eq "0066") {
		# Client sent CharLogin

		# Determine public IP
		my $host = gethostbyname(($self->clientPeerHost eq '127.0.0.1')?
			'127.0.0.1' :
			($config{XKore_publicIp} || '127.0.0.1'));
		$host = inet_ntoa('127.0.0.1') unless (defined $host);

		my $map = $self->{client_saved}{map};
		Plugins::callHook('XKore/map', {r_map => \$map});

		# VCL: I think a race condition occurs here. It tries to create the socket
		# for the map server after the client has selected the character, but if
		# the client connects to the port faster than we can create it, then the
		# client will freeze. So I create it here.
		my $ip = $config{XKore_listenIp} || '0.0.0.0';
		$self->{client_listen} = new IO::Socket::INET(
			LocalAddr	=> $ip,
			LocalPort	=> $self->{client_listenPort},
			Listen		=> 1,
			Proto		=> 'tcp',
			ReuseAddr   => 1);
		die TF("Unable to listen on XKore2 port (%s:%s): %s", $ip, $self->{client_listenPort}, $@) unless $self->{client_listen};

		# Send character and map info packet
		$msg = pack('C2 a4 Z16 a4 v1', 0x71, 0, $charID, $map,
				$host, $self->{client_listenPort});
		$self->clientSend($msg, 1);

		debug "Selected character.\n", "connection";
		$$c_state = 3;

	} elsif ($$c_state == 2 && $switch eq "0067") {
		# Character Create

		# Deny it
		$msg = pack('C3', 0x6E, 0, 2);
		$self->clientSend($msg,1);

		debug "Attempted char create.\n", "connection";

	} elsif ($$c_state == 2 && $switch eq "0068") {
		# Character Delete

		# Deny it
		$msg = pack('C3', 0x70, 0, 1);
		$self->clientSend($msg,1);

		debug "Attempted char delete.\n", "connection";

	} elsif ($$c_state == 2 && $switch eq "0187") {
		# Ban Check/Sync

		# Do nothing...?
		# Seems to work.

		debug "Wanted to sync.\n", "connection";

	} elsif ($$c_state == 3 && (
		# Ignore invalid serverTypes
		($config{XKore_ignoreInvalidServerType} && (
			$switch eq "0072" ||
			$switch eq "009B" ||
			$switch eq "00F5" )) ||
		# serverType 0 - 2
		($switch eq "0072" && (
			$config{serverType} >= 0 &&
			$config{serverType} <= 2 )) ||
		# serverType 3, 5
		($switch eq "009B" && (
			$config{serverType} == 3 ||
			$config{serverType} == 5 )) ||
		# serverType 4
		($switch eq "00F5" &&
			$config{serverType} == 4 ) ||
		# serverType 18
		($switch eq "00F3" &&
			$config{serverType} == 18)
		)) {
		# Client sent MapLogin

		# Send account ID
		$self->clientSend($accountID,1);

		my $x = $char->{pos_to}{x};
		my $y = $char->{pos_to}{y};

		# Allow an XKore plugin to change the coords
		Plugins::callHook('XKore/map', {r_x => \$x, r_y => \$y});

		# Generate the coords info
		my $coords = "";
		shiftPack(\$coords, $x, 10);
		shiftPack(\$coords, $y, 10);
		shiftPack(\$coords, 0, 4);

		# Send map info
		#'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		$msg = pack('C2 V a3 x2', 0x73, 0, time, $coords);
		$self->clientSend($msg,1);

		debug "Map Login.\n", "connection";

		$$c_state = 4;

	} elsif ($$c_state == 3 && (
		$switch eq "0072" ||
		$switch eq "009B" ||
		$switch eq "00F5")) {
		# MapLogin for the wrong serverType

		$self->clientSend($accountID,1);

		# Generate the coords info
		my $coords = "";
		shiftPack(\$coords, $char->{pos_to}{x}, 10);
		shiftPack(\$coords, $char->{pos_to}{y}, 10);
		shiftPack(\$coords, 0, 4);

		# Send map info
		#'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		$msg = pack('C2 V a3 x2', 0x73, 0, time, $coords);
		$self->clientSend($msg,1);

		# Default to novice map
		my ($map, $x, $y) = ('new_1-1.gat', 53, 109);

		# Allow a custom plugin to change the map and coords
		Plugins::callHook('XKore/map', {r_map => \$map, r_x => \$x, r_y => \$y});

		# Redirect them to the map
		$msg = pack('C2 Z16 v2', 0x91, 0, $map, $x, $y);
		$self->clientSend($msg,1);

		# Set to a special client_state
		$$c_state = -1;

		debug "Map Login for wrong server type.\n", "connection";

	} elsif ($$c_state == 4 && $switch eq "021D") {
		# This does what?

		debug "Packet 021D.\n", "connection";

	} elsif ($$c_state == 4 && ($switch eq "014D" ||$switch eq "0181") ) {
		$msg = "";
		debug "Guild Info.\n", "connection";
	} elsif ($$c_state == 4 && ($switch eq "007D" || $switch eq "01C0")) {
		# Client sent MapLoaded
		debug "Client Finished Loaded.\n", "connection";
		# Save the original incoming message
		my $msgIn = $msg;

		$msg = "";

		# TODO: Character vending, character in chat, character in deal
		# TODO: Cart Items, Guild Notice
		#
		# TODO: Fix walking speed? Might that be part of the map login packet? Or 00BD?

		# Send player stats
		$msg .= pack('C2 v1 C12 v12 x4', 0xBD, 0x00,
			$char->{points_free}, $char->{str}, $char->{points_str}, $char->{agi}, $char->{points_agi},
			$char->{vit}, $char->{points_vit}, $char->{int}, $char->{points_int}, $char->{dex},
			$char->{points_dex}, $char->{luk}, $char->{points_luk}, $char->{attack}, $char->{attack_bonus},
			$char->{attack_magic_min}, $char->{attack_magic_max}, $char->{def}, $char->{def_bonus},
			$char->{def_magic}, $char->{def_magic_bonus}, $char->{hit}, $char->{flee}, $char->{flee_bonus},
			$char->{critical});

		# More stats
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 0, $char->{walk_speed}*1000);	# Walk speed
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 5, $char->{hp});			# Current HP
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 6, $char->{hp_max});		# Max HP
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 7, $char->{sp});			# Current SP
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 8, $char->{sp_max});		# Max SP
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 12, $char->{points_skill});	# Skill points left
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 24, $char->{weight}*10);		# Current weight
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 25, $char->{weight_max}*10);	# Max weight
		$msg .= pack('C2 v1 V1', 0xB0, 0x00, 53, $char->{attack_delay});	# Attack speed

		# Resend base stat info (str, agi, vit, int, dex, luk) this time with bonus
		$msg .= pack('C2 V3', 0x41, 0x01, 13, $char->{str}, $char->{str_bonus});
		$msg .= pack('C2 V3', 0x41, 0x01, 14, $char->{agi}, $char->{agi_bonus});
		$msg .= pack('C2 V3', 0x41, 0x01, 15, $char->{vit}, $char->{vit_bonus});
		$msg .= pack('C2 V3', 0x41, 0x01, 16, $char->{int}, $char->{int_bonus});
		$msg .= pack('C2 V3', 0x41, 0x01, 17, $char->{dex}, $char->{dex_bonus});
		$msg .= pack('C2 V3', 0x41, 0x01, 18, $char->{luk}, $char->{luk_bonus});

		# Send attack range
		$msg .= pack('C2 v', 0x3A, 0x01, $char->{attack_range});

		# Send weapon/shield appearance
		$msg .= pack('C2 a4 C v2', 0xD7, 0x01, $accountID, 2, $char->{weapon}, $char->{shield});

		# Send status info
		$msg .= pack('C2 a4 v3 x', 0x19, 0x01, $accountID, $char->{param1}, $char->{param2}, $char->{param3});

		# Send more status information
		# TODO: Find a faster/better way of doing this? This seems cumbersome.
		foreach my $ID (keys %{$char->{statuses}}) {
			while (my ($statusID, $statusName) = each %skillsStatus) {
				if ($ID eq $statusName) {
					$msg .= pack('C2 v a4 C', 0x96, 0x01, $statusID, $accountID, 1);
				}
			}
		}

		# Send spirit sphere information
		$msg .= pack('C2 a4 v', 0xD0, 0x01, $accountID, $char->{spirits}) if ($char->{spirits});

		# Send exp-required-to-level-up info
		$msg .= pack('C2 v V', 0xB1, 0x00, 22, $char->{exp_max}) .
			pack('C2 v V', 0xB1, 0x00, 23, $char->{exp_job_max});


		# Send skill information
		my $skillInfo = "";
		foreach my $ID (@skillsID) {
			$skillInfo .= pack('v2 x2 v3 a24 C',
				$char->{skills}{$ID}{ID}, $char->{skills}{$ID}{targetType},
				$char->{skills}{$ID}{lv}, $char->{skills}{$ID}{sp},
				$char->{skills}{$ID}{range}, $ID, $char->{skills}{$ID}{up});
		}
		$msg .= pack('C2 v', 0x0F, 0x01, length($skillInfo) + 4) . $skillInfo;
		undef $skillInfo;

		# Sort items into stackable and non-stackable
		my @stackable;
		my @nonstackable;
		foreach my $item (@{$char->inventory->getItems()}) {
			if ($item->{type} <= 3 || $item->{type} == 6 || $item->{type} == 10 || $item->{type} == 16) {
				push @stackable, $item;
			} else {
				push @nonstackable, $item;
			}
		}

		# Send stackable item information
		my $stackableInfo = "";
		foreach my $item (@stackable) {
			$stackableInfo .= pack('v2 C2 v1 x2', $item->{index}, $item->{nameID}, $item->{type}, 1, #(identified)
				$item->{amount});
		}
		$msg .= pack('C2 v1', 0xA3, 0x00, length($stackableInfo) + 4) . $stackableInfo;

		# Send non-stackable item (mostly equipment) information
		my $nonstackableInfo = "";
		foreach my $item (@nonstackable) {
			$nonstackableInfo .= pack('v2 C2 v2 C2 a8', $item->{index}, $item->{nameID}, $item->{type},
				$item->{identified}, $item->{type_equip}, $item->{equipped}, $item->{broken},
				$item->{upgrade}, $item->{cards});
		}
		$msg .= pack('C2 v', 0xA4, 0x00, length($nonstackableInfo) + 4) . $nonstackableInfo;

		# Send equipped arrow information
		$msg .= pack('C2 v', 0x3C, 0x01, $char->{arrow}) if ($char->{arrow});


		# Clear old variables
		#@stackable = ();
		#@nonstackable = ();
		#$stackableInfo = "";
		#$nonstackableInfo = "";

		# Do the cart items now
		#for (my $i = 0; $i < @{$cart{inventory}}; $i++) {
		#	my $item = $cart{inventory}[$i];
		#	next unless $item && %{$item};

			#if ($item->{
		#}

		# Send info about items on the ground
		foreach my $ID (@itemsID) {
			next if !defined $ID;
			$msg .= pack('C2 a4 v1 x1 v3 x2', 0x9D, 0x00, $ID, $items{$ID}{nameID},
				$items{$ID}{pos}{x}, $items{$ID}{pos}{y}, $items{$ID}{amount});
		}

		# Send all portal info
		foreach my $ID (@portalsID) {
			next if !defined $ID;
			my $coords = "";
			shiftPack(\$coords, $portals{$ID}{pos}{x}, 10);
			shiftPack(\$coords, $portals{$ID}{pos}{y}, 10);
			shiftPack(\$coords, 0, 4);

			$msg .= pack('C2 a4 x8 v1 x30 a3 x5', 0x78, 0x00, $ID, $portals{$ID}{type}, $coords);
		}

		# Send all NPC info
		foreach my $ID (@npcsID) {
			next if !defined $ID;
			my $coords = "";
			shiftPack(\$coords, $npcs{$ID}{pos}{x}, 10);
			shiftPack(\$coords, $npcs{$ID}{pos}{y}, 10);
			shiftPack(\$coords, $npcs{$ID}{look}{body}, 4);

			$msg .= pack('C2 a4 x2 v4 x30 a3 x5', 0x78, 0x00, $ID,
				$npcs{$ID}{param1}, $npcs{$ID}{param2}, $npcs{$ID}{param3},
				$npcs{$ID}{type}, $coords);
		}

		# Send all monster info
		foreach my $ID (@monstersID) {
			next if !defined $ID;
			my $coords = "";
			shiftPack(\$coords, $monsters{$ID}{pos_to}{x}, 10);
			shiftPack(\$coords, $monsters{$ID}{pos_to}{y}, 10);
			shiftPack(\$coords, $monsters{$ID}{look}{body}, 4);

			$msg .= pack('C2 a4 v5 x30 a3 x3 v1',
				0x78, 0x00, $ID, $monsters{$ID}{walk_speed} * 1000,
					$monsters{$ID}{param1}, $monsters{$ID}{param2}, $monsters{$ID}{param3},
					$monsters{$ID}{nameID}, $coords, $monsters{$ID}{lv});
		}

		# Send info about pets
		foreach my $ID (@petsID) {
			next if !defined $ID;
			my $coords = "";
			shiftPack(\$coords, $pets{$ID}{pos_to}{x}, 10);
			shiftPack(\$coords, $pets{$ID}{pos_to}{y}, 10);
			shiftPack(\$coords, $pets{$ID}{look}{body}, 4);

			$msg .= pack('C2 a4 v x6 v2 x28 a3 x3 v', 0x78, 0x00, $ID, $pets{$ID}{walk_speed} * 1000,
				$pets{$ID}{nameID}, $pets{$ID}{hair_style}, $coords, $pets{$ID}{lv});
		}

		# Send info about surrounding players
		foreach my $ID (@playersID) {
			next if !defined $ID;
			my $coords = "";
			shiftPack(\$coords, $players{$ID}{pos_to}{x}, 10);
			shiftPack(\$coords, $players{$ID}{pos_to}{y}, 10);
			shiftPack(\$coords, $players{$ID}{look}{body}, 4);

			$msg .= pack('C2 a4 v4 x2 v8 x2 v a4 a4 v x2 C2 a3 x2 C v', 0x2A, 0x02, $ID, $players{$ID}{walk_speed} * 1000,
				$players{$ID}{param1}, $players{$ID}{param2}, $players{$ID}{param3},
				$players{$ID}{jobID}, $players{$ID}{hair_style}, $players{$ID}{weapon}, $players{$ID}{shield},
				$players{$ID}{headgear}{low}, $players{$ID}{headgear}{top}, $players{$ID}{headgear}{mid},
				$players{$ID}{hair_color}, $players{$ID}{look}{head}, $players{$ID}{guildID}, $players{$ID}{guildEmblem},
				$players{$ID}{visual_effects}, $players{$ID}{stance}, $players{$ID}{sex}, $coords,
				($players{$ID}{dead}? 1 : ($players{$ID}{sitting}? 2 : 0)), $players{$ID}{lv});
		}

		# Send vendor list
		foreach my $ID (@venderListsID) {
			next if !defined $ID;
			$msg .= pack('C2 a4 a30 x50', 0x31, 0x01, $ID, $venderLists{$ID}{title});
		}

		# Send chatrooms
		foreach my $ID (@chatRoomsID) {
			next if !defined $ID;
			next if (! $chatRooms{$ID}{ownerID});

			# '00D7' => ['chat_info', 'x2 a4 a4 v1 v1 C1 a*', [qw(ownerID ID limit num_users public title)]],
			my $chatMsg = pack('a4 a4 v2 C1 a* x1', $chatRooms{$ID}{ownerID}, $ID, $chatRooms{$ID}{limit},
				$chatRooms{$ID}{num_users}, $chatRooms{$ID}{public}, $chatRooms{$ID}{title});

			$msg .= pack('C2 v', 0xD7, 0x00, length($chatMsg) + 4) . $chatMsg;
		}

		# Send active ground effect skills
		foreach my $ID (@skillsID) {
			next if !defined $ID;
			$msg .= pack('C2 a4 a4 v2 C2 x81', 0xC9, 0x01, $ID, $spells{$ID}{sourceID},
				$spells{$ID}{pos}{x}, $spells{$ID}{pos}{y}, $spells{$ID}{type},
				$spells{$ID}{fail});
		}

		# Send friend list
		my ($friendMsg, $friendOnlineMsg);
		foreach my $ID (@friendsID) {
			next if !defined $ID;
			$friendMsg .= pack('a4 a4 Z24', $friends{$ID}{accountID}, $friends{$ID}{charID}, $friends{$ID}{name});
			$friendOnlineMsg .= pack('C2 a4 a4 C', 0x06, 0x02, $friends{$ID}{accountID}, $friends{$ID}{charID},
				0) if ($friends{$ID}{online});
		}
		$msg .= pack('C2 v', 0x01, 0x02, length($friendMsg) + 4) . $friendMsg . $friendOnlineMsg;
		undef $friendMsg;
		undef $friendOnlineMsg;

		# Send party list
		if ($char->{party}) {
			my ($partyMsg, $num);
			foreach my $ID (@partyUsersID) {
			next if !defined $ID;
				$num++ unless ($char->{party}{users}{$ID}{admin});
				$partyMsg .= pack("a4 Z24 Z16 C2", $ID, $char->{party}{users}{$ID}{name}, $char->{party}{users}{$ID}{map},
					$char->{party}{users}{$ID}{admin}? 0 : $num, 1 - $char->{party}{users}{$ID}{online});
			}
			$msg .= pack('C2 v Z24', 0xFB, 0x00, length($partyMsg) + 28, $char->{party}{name}) . $partyMsg;
			undef $partyMsg;
			undef $num;
		}

		# Send pet information
		if (defined $pet{ID}) {
			$msg .= pack('C2 C a4 V', 0xA4, 0x01, 0, $pet{ID}, 0);
			$msg .= pack('C2 C a4 V', 0xA4, 0x01, 5, $pet{ID}, 0x64);
			$msg .= pack('C2 Z24 C v4', 0xA2, 0x01, $pet{name}, $pet{nameflag}, $pet{level}, $pet{hungry},
				$pet{friendly}, $pet{accessory});
		}

		# Send guild info
		if ($char->{guildID}) {
			$msg .= pack('C2 V3 x5 Z24', 0x6C, 0x01, $char->{guildID}, $char->{guild}{emblem}, $char->{guild}{mode},
				$char->{guild}{name});
		}

		# Send "sitting" if the char is sitting
		if ($char->{sitting}) {
			$msg .= pack('C2 a4 x20 C1 x2', 0x8A, 0x00, $accountID, 2);
		}

		# Make the character face the correct direction
		$msg .= pack('C2 a4 C1 x1 C1', 0x9C, 0x00, $accountID, $char->{look}{head}, $char->{look}{body});


          $self->clientSend($msg,1);

		debug "Map Loaded.\n", "connection";

		# Continue the packet on to a plugin
		Plugins::callHook('XKore/packet/out', {switch => $switch, r_packet => \$msgIn});

		$$c_state = 5;

	} elsif ($$c_state == 5) {
		# Done!
		# (this should never be reached)

	} elsif ($$c_state < 0) {
		# Error while logging in, or disconnected from server...

		# Save the msgIn for later use
		my $msgIn = $msg;

		$msg = "";

		if ($switch eq "007D" && !$self->{client_saved}{gave_error}) {
			# Client sent map login

			my $errMsg;
			if ($$c_state == -1) {
				# Inform the client that they are using an invalid serverType-ed client,
				# and how to remedy it.
				$errMsg = "Warning: You are using a version of the Ragnarok Online client that " .
					"does not match the serverType indicated by $Settings::NAME. " .
					"This is caused either by using the wrong RO client, or by using " .
					"an incorrect serverType value (found in tables/servers.txt and control/config.txt). " .
					"You may also set the config.txt option named \"XKore_ignoreInvalidServerType\" in order " .
					"to bypass this warning, but doing so may cause unexpected behavior. ".
					"Also, please note that some private servers allow more than one serverType, so " .
					"please try adjusting the serverType, exiting $Settings::NAME completely, and retrying ".
					"for each serverType before submitting a support request.";

			} elsif ($$c_state == -2) {
				# Inform the client that the connection to the server was lost
				$errMsg = T("blueConnection to server lost. Please wait while the connection is reestablished.");

			} else {
				$errMsg = T("Unknown error within XKore 2");
			}


			$msg = pack('C2 v Z'.(length($errMsg)+1).' x', 0x9A, 0x00, length($errMsg) + 6, $errMsg);

			$self->clientSend($msg,1);
			$self->{client_saved}{gave_error} = 1;

		} elsif ($switch eq "00B2") {
			# If they want to character select/respawn, kick them to the login screen
			# immediately (GM kick)
			$self->clientSend(pack('C3', 0x81, 0, 15),1);
			$self->{client_state} = 0;

		} elsif ($switch eq "018A") {
			# Client wants to quit...
			$msg = "";

			$self->clientSend(pack('C*', 0x8B, 0x01, 0, 0),1);
			$self->{challengeNum} = 0;
			$self->{client_state} = 0;
	
		} else {

			# Do state-specific checks
			if ($$c_state == -2) {
				# Check if we've reestablished the check with the server
				if ($self->getState() == Network::IN_GAME) {
					# Plunk the character back down in the regular map they're on, and
					# tell them that we've reconnected.
					$msg = T("blueConnection reestablished. Enjoy. =)");

					# Allow client to change map and coords
					my ($map, $x, $y) = ($self->{client_saved}{map}, $char->{pos_to}{x}, $char->{pos_to}{y});

					Plugins::callHook('XKore/map', {r_map => \$map, r_x => \$x, r_y => \$y});

					$msg = pack('C2 Z16 v2', 0x91, 0, $map, $x, $y) .
						pack('C2 v Z'.(length($msg)+1).' x', 0x9A, 0x00, length($msg) + 6, $msg);
					$self->clientSend($msg,1);
					$$c_state = 4;
					$self->{client_saved}{gave_error} = 0;
				} else {
					$msg = T("blueStill trying to connect...");
					$msg = pack('C2 v Z'.(length($msg)+1).' x', 0x9A, 0x00, length($msg) + 6, $msg);
					$self->clientSend($msg,1);
				}
			}

		}

		# Continue the packet on to a plugin
		Plugins::callHook('XKore/packet/out', {switch => $switch, r_packet => \$msgIn});

	} else {
		# Something wasn't right, kick the client
		error TF("Unknown/unexpected XKore 2 packet: %s (state: %s).\n", $switch, $$c_state), "connection";

		main::visualDump($msg);

		$self->clientSend(pack('C3 x20', 0x6A, 00, 3),1);
		$self->clientDisconnect();
		$$c_state = 0;
		$$msgIn = "";
	}

	$$msgIn = (length($$msgIn) < $msg_size)? substr($$msgIn,$msg_size) : "";
}

##
# $net->modifyPacketIn(msg)
# msg: A scalar being sent to the RO Client
#
sub modifyPacketIn {
	my ($self, $msg) = @_;

	return undef if (length($msg) < 1);

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if ($msg eq $accountID) {
		# Don't send the account ID
		$msg = "";

	} elsif ($switch eq "006A") {
		# Don't send disconnect signals to the RO client
		$msg = "";

	} elsif ($switch eq "006B") {
		# Catch the number of extra bytes on the packet
		$self->{client_saved}{char_info_padding} = (length($msg) - 4) % 106;

	} elsif ($switch eq "0071") {
		# Save the mapname for client login
		$self->{client_saved}{map} = substr($msg, 6, 16);

	} elsif ($switch eq "0073") {
		# Once we've connected to the new zone, send the mapchange packet to
		# the client.

		# Get the coordinates
		my $coords = substr($msg, 6, 3);
		my ($x, $y);
		unShiftPack(\$coords, undef, 4);
		unShiftPack(\$coords, \$y, 10);
		unShiftPack(\$coords, \$x, 10);

		# Allow a plugin to change the map information
		my $map = $self->{client_saved}{map};

		Plugins::callHook('XKore/map', {r_map => \$map, r_x => \$x, r_y => \$y});

		# Generate a map-change packet (rather than a zone-change)
		$msg = pack('C2 Z16 v2', 0x91, 0, $self->{client_saved}{map},
			$x, $y);

		# Don't send this packet to the plugins
		return $msg;

	} elsif ($switch eq "0081") {
		# Don't send ban signals to the client
		$msg = "";

	} elsif ($switch eq "0091") {
		# Grab map and coordinates
		my ($map, $x, $y) = unpack('x2 Z16 v2', $msg);

		# Save the map name for client login
		$self->{client_saved}{map} = $map;

		# Allow plugins to change the map information
		Plugins::callHook('XKore/map', {r_map => \$map, r_x => \$x, r_y => \$y});
		#simple hack to make client not crash by gm hiding the character before moving to the next map
          $msg = pack("C2",0x29,0x02).$accountID.pack("C9",0x00,0x00,0x00,0x00,0x40,0x00,0x00,0x00,0x00);
		# Generate the new map-change packet
		$msg .= pack('C2 Z16 v2', 0x91, 0, $map,
			$x, $y);

		# Don't send this packet to the plugin
		return $msg;

	} elsif ($switch eq "0092") {
		# Save the mapname, and drop the packet until we connect to new
		# zone server (to make mapchanges fluid for our connected client)
		$self->{client_saved}{map} = substr($msg, 2, 16);
		$msg = "";

	}

	# Continue the packet on to a plugin
	if (length($msg) > 0) {
		$self->{client_saved}{plugin_packet_in} = 1;
		Plugins::callHook('XKore/packet/in', {switch => $switch, r_packet => \$msg});
		$self->{client_saved}{plugin_packet_in} = 0;
	}

	return $msg;
}

##
# $net->modifyPacketOut(msg)
# msg: A scalar being sent to the RO server
#
sub modifyPacketOut {
	use bytes;
	no encoding 'utf8';
	my ($self, $msg) = @_;

	return undef if (length($msg) < 1);

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if ($switch eq "007D") {
		#client is loaded
		$msg = "";
		
	} elsif (($switch eq "007E" && (
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

	} elsif ($switch eq "00B2") {
		if (unpack('C1', substr($msg, 2, 1)) == 1) {
			# Client wants to switch characters, fake it.
			$msg = "";
			$self->clientSend(pack('C3', 0xB3, 0, 1),1);
			$self->{client_state} = 1;
		}

	} elsif ($switch eq "018A") {
		# Client wants to quit...
		$msg = "";

		$self->clientSend(pack('C*', 0x8B, 0x01, 0, 0));
	}

	# Continue the packet on to a plugin
	Plugins::callHook('XKore/packet/out', {switch => $switch, r_packet => \$msg})
		if (length($msg) > 0);

	return $msg;
}

return 1;
