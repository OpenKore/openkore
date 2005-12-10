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
package XKore2;

use strict;
use Exporter;
use base qw(Exporter);
use IO::Socket::INET;

use Globals;
use Log qw(message error);
use Utils qw(dataWaiting vocalString timeOut shiftPack unShiftPack);

use Network::Send;

##
# XKore2->new()
#
# Initialize XKore Mode 2. If an error occurs, this function will return undef,
# and set the error message in $@.
sub new {
	my $class = shift;
	my %self;

	$@ = "Kore Mode 2 not implemented yet.";
	#return undef;

	# Reuse code from Network to keep the connection to the server
	require Network;
	Modules::register("Network");
	$self{server} = new Network;

	return undef unless $self{server};

	$self{tracker_state} = 0;
	$self{tracker_name} = $config{xkore_ID} || vocalString(8);

	$self{client_state} = 0;
	$self{client_listenPort} = $config{xkore_listenPort} ||
		($config{xkore_tracker}?6902+int(rand(98)) : 6900);

	bless \%self, $class;
	return \%self;
}

##
# $net->version
# Returns: XKore mode
#
sub version {
	return 2;
}

##
# $net->DESTROY()
#
# Shutdown function. Turn everything off.
sub DESTROY {
	my $self = shift;

	$self->serverDisconnect;
	$self->clientDisconnect if ($self->clientAlive);
	close($self->{client_listen}) unless ($self->clientAlive);
	close($self->{tracker}) if ($self->trackerAlive);
	undef $self->{server};
}

######################
## Server Functions ##
######################

##
# $net->serverAlive()
# Returns: a boolean.
#
#
sub serverAlive {
	my $self = shift;
	return $self->{server}->serverAlive;
}

##
# $net->serverConnect(host,port)
#
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
	return $self->{server}->serverPeerPort if ($self->serverAlive);
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
# Just reuses KoreNet's code.
sub serverDisconnect {
	my $self = shift;
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
	return $_[0]->clientAlmostAlive && $_[0]->{client_state} == 5;
}

##
# $net->clientAlmostAlive
# Returns: a boolean
#
# Checks to see if the client is connected. Used internally only.
sub clientAlmostAlive {
	return $_[0]->{client} && $_[0]->{client}->connected;
}

##
# $net->clientPeerHost
#
sub clientPeerHost {
	return $_[0]->{client}->peerhost if ($_[0]->clientAlmostAlive);
	return undef;
}

##
# $net->clientPeerPort
#
sub clientPeerPort {
	return $_[0]->{client}->peerport if ($_[0]->clientAlmostAlive);
	return undef;
}

##
# $net->clientConnect
#
sub clientConnect {
	return undef;
}

##
# $net->clientSend
#
sub clientSend {
	my $self = shift;
	my $msg = shift;
	my $dontMod = shift;

	$msg = $self->modifyPacketIn($msg) unless ($dontMod);
	$self->{client}->send($msg) if (($self->clientAlmostAlive && $dontMod) || $self->clientAlive);
}

##
# $net->clientRecv
# Returns: A scalar.
#
# Returns undef unless the client is fully logged in.
sub clientRecv {
	my $self = shift;
	my $msg;

	return undef unless ($self->clientAlive);

	return $self->modifyPacketOut($self->realClientRecv);
}

##
# $net->realClientRecv
# Returns: A scalar.
#
# Returns data coming from the client. Used internally until client is fully
# logged in. Should only be used internally.
sub realClientRecv {
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

##
# $net->clientDisconnect
#
#
sub clientDisconnect {
	my $self = shift;
	if ($self->clientAlmostAlive) {
		message("Disconnecting RO client (".$self->{client}->peerhost().":".$self->{client}->peerport().
			")... ", "connection");
		close($self->{client});
		!$self->clientAlive() ?
			message("disconnected\n", "connection") :
			error("couldn't disconnect\n", "connection");
	}
}

#######################
## Utility Functions ##
#######################

##
# $net->trackerAlive
#
sub trackerAlive {
	return $_[0]->{tracker} && $_[0]->{tracker}->connected;
}

##
# $net->checkConnection()
#
sub checkConnection {
	my $self = shift;

	# Check connection to the client
	$self->checkClient();

	# Check server connection
	$self->{server}->checkConnection();

	# Check connection to the tracker/emulated master server
	$self->checkTracker() if ($config{'xkore_tracker'});
}

##
# $net->checkTracker()
#
# This should be used internally only
sub checkTracker {
	my $self = shift;
	my $t_state = \$self->{tracker_state};
	my $host = $config{xkore_trackerIp} || 'localhost';
	my $port = $config{xkore_trackerPort} || 6901;

	return unless (defined $self->{client_listen} && $self->serverAlive && $conState == 5);

	if ($$t_state == 0 && timeOut($timeout{'xkore-tracker'})) {
		message("Connecting to XKore2 master ($host:$port)... ", "connection");
		# Make a connection to the tracker/master server
		$self->{tracker} = new IO::Socket::INET(
			PeerAddr	=> $host,
			PeerPort	=> $port,
			Proto		=> 'tcp',
			Timeout		=> 4);

		if ($self->{tracker} && inet_aton($self->{tracker}->peerhost()) eq inet_aton($host)) {
			message("connected\n", "connection");
			$$t_state = 1;
		} else {
			error("couldn't connect: $!\n", "connection");
		}
		$timeout{'xkore-tracker'}{'time'} = time;
	} elsif ($$t_state == 1 && $self->trackerAlive) {
		# Send kore ID/name
		$self->{tracker}->send("N".pack('v',length($self->{tracker_name})).$self->{tracker_name});

		# Send listening address
		if ($config{xkore_listenIp}) {
			$self->{tracker}->send("A".pack('v',length($config{xkore_listenIp})).$config{xkore_listenIp});
		}

		# Send listening port
		$self->{tracker}->send("P".pack('v', $self->{server}->sockport));

		$timeout{'injectSync'}{'time'} = time;
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
				$self->{client_fakeInfo}{'accountID'} = substr($msg,3,$len);
			} elsif ($switch eq "S") {
				$self->{client_fakeInfo}{'sessionID'} = substr($msg,3,$len);
			} elsif ($switch eq "G") {
				$self->{client_fakeInfo}{'sex'} = substr($msg,3,$len);
			} elsif ($switch eq "T") {
				$self->{client_fakeInfo}{'sessionID2'} = substr($msg,3,$len);
			}

			$timeout{'xkore-tracker'}{'time'} = time;
		}
		if ($self->trackerAlive && timeOut($timeout{'xkore-tracker'})) {
			$self->{tracker}->send("K".pack('v',0));
		}
	} elsif (!$self->trackerAlive && timeOut($timeout{'xkore-tracker'})) {
		message "Lost connection to XKore2 master, reconnecting...\n", "connection";
		$timeout{'xkore-tracker'}{'time'} = time;
		$$t_state = 0;
	}
}

sub checkClient {
	my $self = shift;

	# Check if the client is active, but the server is not.
	if ($conState < 4 && $self->clientAlmostAlive) {
		# Have we kicked the client?
		if ($self->{client_state} != -1) {
			# Kick them
			unless ($self->{client_state} == 5) {
				# "Blocked from server until ______"
				$self->clientSend(pack('C3 Z20', 0x6A, 0, 6, "OpenKore connects"),1);
			} else {
				# Kick the user to the login screen immediately (GM kick)
				$self->clientSend(pack('C3', 0x81, 0, 15));
			}
			$self->{client_state} = -1;
			$self->{client_msgIn} = "";
		} elsif (!$self->clientAlmostAlive) {
			# Flush the buffer, so the client data doesn't get sent to server.
			$self->realClientRecv();
			$self->{client_state} = 0;
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
			message "RO Client connection from ($host:$port).\n", "connection";

			# Determine the client state
			$self->{client_state} = 0 if ($self->{client_state} != 1
					&& $self->{client_state} != 3);

			# Stop listening.
			close($self->{client_listen});
			undef $self->{client_listen};

			# Shutdown the connection with the tracker.
			if ($config{'xkore_tracker'} && $self->trackerAlive) {
				$self->{client_state} = 1 if ($self->{client_state} == 0);
				close($self->{tracker});
				undef $self->{tracker};
			}
		}

		return;
	} elsif (!$self->clientAlmostAlive) {
		# Client disconnected... (or never existed)

		undef $self->{client};
		# Begin listening...
		$self->{client_listen} = new IO::Socket::INET(
			LocalAddr	=> $config{xkore_listenIp} || undef,
			LocalPort	=> $self->{client_listenPort},
			Listen		=> 1,
			Proto		=> 'tcp');

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

	message "RO Client ($host:$port) -> ", "connection";

	if ($$c_state == 0 && $switch eq "0064") {
		# Client sent MasterLogin
		my ($version, $username, $password, $master_version) = unpack("x2 V Z24 Z24 C1", $msg);

		# Check password against adminPassword
		if ($password ne $config{'adminPassword'}) {
			error "Bad Password.\n", "connection";
			$self->clientSend(pack('C3 x20', 0x6A, 00, 1),1);
		} else {
			# Send out the login packet
			#'0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*',
			#[qw(sessionID accountID sessionID2 accountSex serverInfo)]],
			$msg = pack('a4 a4 a4 x30 C1 C4 v Z20 C1 C1 x15', $sessionID, $accountID, $sessionID2, $accountSex2,
					127, 0, 0, 1, $self->{client_listenPort}, $self->{tracker_name}, 0, 0);
			$msg = pack('C2 v', 0x69, 00, length($msg)+4) . $msg;
			$self->clientSend($msg,1);
			message "Master Login.\n", "connection";

			$$c_state = 1;
		}
	} elsif ($$c_state == 1 && $switch eq "0065") {
		# Client sent GameLogin
		#my $msg = pack("C*", 0x65,0) . $accountID . $sessionID . $sessionID2 . pack("C*", 0,0,$sex);

		# Send the account ID
		$self->clientSend($accountID,1);

		# Send the characters packet.
		if ($config{serverType} == 0) {
			$msg = substr($self->{client_saved}{'chars'},4);
			for (my ($i, $j) = (0, 0); $i < (length($msg)/106); $i++) {
				$msg = substr($msg, $j+106) . pack('x104 C1 x', 255) unless (substr($msg, 0, 4) eq $charID);
				if (substr($msg, 0, 4) eq $charID) {
					$j = 106;
					$msg = substr($msg, 0, 106); #104) . pack ('C1 x', 0);
				}
			}
			$msg = pack('C2 v', 0x6B, 0, length($msg)+4) . $msg;
		} else {
			$msg = $self->{client_saved}{'chars'};
		}
		$self->clientSend($msg,1);

		message "Game Login.\n", "connection";
		$$c_state = 2;

	} elsif ($$c_state == 2 && $switch eq "0066") {
		# Client sent CharLogin

		# Send character and map info packet
		#'0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		$msg = pack('C2 a4 Z16 C4 v1', 0x71, 0, $charID, $self->{client_saved}{'map'},
				127, 0, 0, 1, $self->{client_listenPort});
		$self->clientSend($msg,1);

		message "Selected character.\n", "connection";
		$$c_state = 3;


	} elsif ($$c_state == 2 && $switch eq "0067") {
		# Character Create

		# Deny it
		$msg = pack('C3', 0x6E, 0, 2);
		$self->clientSend($msg,1);

		message "Attempted char create.\n", "connection";

	} elsif ($$c_state == 2 && $switch eq "0068") {
		# Character Delete

		# Deny it
		$msg = pack('C3', 0x70, 0, 1);
		$self->clientSend($msg,1);

		message "Attempted char delete.\n", "connection";

	} elsif ($$c_state == 2 && $switch eq "0187") {
		# Ban Check/Sync

		# Do nothing...?
		# Seems to work.

		message "Wanted to sync.\n", "connection";

	} elsif ($$c_state == 3 && (
		($switch eq "0072" && $config{serverType} == 0) ||
		($switch eq "0072" && $config{serverType} == 1) ||
		($switch eq "0072" && $config{serverType} == 2) ||
		($switch eq "009B" && $config{serverType} == 3) ||
		($switch eq "00F5" && $config{serverType} == 4) ||
		($switch eq "009B" && $config{serverType} == 5) ||
		($switch eq "0072" && $config{serverType} == 6))) {
		# Client sent MapLogin

		# Send account ID
		$self->clientSend($accountID,1);

		# Generate the coords info
		my $coords = "";
		shiftPack(\$coords, $char->{pos_to}{'x'}, 10);
		shiftPack(\$coords, $char->{pos_to}{'y'}, 10);
		shiftPack(\$coords, 0, 4);

		# Send map info
		#'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		$msg = pack('C2 V a3 x2', 0x73, 0, time, $coords);
		$self->clientSend($msg,1);

		message "Map Login.\n", "connection";

		$$c_state = 4;

	} elsif ($$c_state == 4 && $switch eq "021D") {
		# This does what?

		message "Packet 021D.\n", "connection";

	} elsif ($$c_state == 4 && $switch eq "007D") {
		# Client sent MapLoaded

		$msg = "";
		
		# TODO: Player/monster statuses, pets, character stats,
		# TODO: Inventory, dropped items, player genders, vendors
		
		# Show all the portals
		foreach my $ID (@portalsID) {
			my $coords = "";
			shiftPack(\$coords, $portals{$ID}{pos}{'x'}, 10);
			shiftPack(\$coords, $portals{$ID}{pos}{'y'}, 10);
			shiftPack(\$coords, 0, 4);

			my $actorMsg = pack('C2 a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
				0x78, 0x00, $ID, 0, 0, 0, 0, $portals{$ID}{type}, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, $coords, 0, 0);
			
			$msg = $msg . $actorMsg;
		}

		# Show all the NPCs
		foreach my $ID (@npcsID) {
			# '0078' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
			# [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead
			#     hair_color clothes_color head_dir guildID sex coords act lv)]],
			my $coords = "";
			shiftPack(\$coords, $npcs{$ID}{pos}{'x'}, 10);
			shiftPack(\$coords, $npcs{$ID}{pos}{'y'}, 10);
			shiftPack(\$coords, 0, 4);

			my $actorMsg = pack('C2 a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
				0x78, 0x00, $ID, 0, 0, 0, 0, $npcs{$ID}{type}, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, $coords, 0, 0);

			$msg = $msg . $actorMsg;
		}

		# Show all the monsters
		foreach my $ID (@monstersID) {
			# '0078' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
			# [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead
			#     hair_color clothes_color head_dir guildID sex coords act lv)]],
			my $coords = "";
			shiftPack(\$coords, $monsters{$ID}{pos_to}{'x'}, 10);
			shiftPack(\$coords, $monsters{$ID}{pos_to}{'y'}, 10);
			shiftPack(\$coords, 0, 4);

			my $actorMsg = pack('C2 a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
				0x78, 0x00, $ID, $monsters{$ID}{walk_speed} * 1000, 0, 0, 0, $monsters{$ID}{nameID}, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, $coords, 0, 0);

			$msg = $msg . $actorMsg;
		}
		
		# Show all the pets
		foreach my $ID (@petsID) {
			# '0078' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
			# [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead
			#     hair_color clothes_color head_dir guildID sex coords act lv)]],
			my $coords = "";
			shiftPack(\$coords, $pets{$ID}{pos_to}{'x'}, 10);
			shiftPack(\$coords, $pets{$ID}{pos_to}{'y'}, 10);
			shiftPack(\$coords, 0, 4);

			my $actorMsg = pack('C2 a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 x2 C1 v1',
				0x78, 0x00, $ID, $pets{$ID}{walk_speed} * 1000, 0, 0, 0, $pets{$ID}{nameID}, 1, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 0, $coords, 0, 0);

			$msg = $msg . $actorMsg;
		}

		# Show all the players
		foreach my $ID (@playersID) {
			# '0078' => ['actor_exists', 'a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 C1 x1 C1 v1',
			# [qw(ID walk_speed param1 param2 param3 type pet weapon lowhead shield tophead midhead
			#     hair_color clothes_color head_dir guildID sex coords act lv)]],
			my $coords = "";
			shiftPack(\$coords, $players{$ID}{pos_to}{'x'}, 10);
			shiftPack(\$coords, $players{$ID}{pos_to}{'y'}, 10);
			shiftPack(\$coords, 0, 4);

			my $actorMsg = pack('C2 a4 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 v1 V1 x7 C1 a3 C1 x1 C1 v1',
				0x78, 0x00, $ID, $players{$ID}{walk_speed} * 1000, 0, 0, 0, $players{$ID}{jobID}, 0, $players{$ID}{weapon},
				$players{$ID}{headgear}{low}, $players{$ID}{shield}, $players{$ID}{headgear}{top}, $players{$ID}{headgear}{mid},
				$players{$ID}{hair_color}, 0, $players{$ID}{look}{head}, $players{$ID}{guild}, 0, $coords, $players{$ID}{look}{body}, 
				($players{$ID}{dead}? 1 : ($players{$ID}{sitting}? 2 : 0)), $players{$ID}{lv});

			$msg = $msg . $actorMsg;			
		}

		$self->clientSend($msg,1);

		message "Map Loaded.\n", "connection";

		$$c_state = 5;

	} elsif ($$c_state == 5) {
		# Done!
		# (this should never be reached)
	} else {
		# Something wasn't right, kick the client
		error "Unknown/unexpected packet: $switch (state: $$c_state).\n", "connection";

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
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if ($switch eq "006B") {
		# Save the characters for client login
		$self->{client_saved}{'chars'} = $msg;

	} elsif ($switch eq "0071") {
		# Save the mapname for client login
		$self->{client_saved}{'map'} = substr($msg, 6, 16);

	} elsif ($switch eq "0073") {
		# Once we've connected to the new zone, send the mapchange packet to
		# the client.

		# Get the coordinates
		my $coords = substr($msg, 6, 3);
		my ($x, $y);
		unShiftPack(\$coords, undef, 4);
		unShiftPack(\$coords, \$y, 10);
		unShiftPack(\$coords, \$x, 10);

		# Generate a map-change packet (rather than a zone-change)
		$msg = pack('C2 Z16 v2', 0x91, 0, $self->{client_saved}{'map'},
			$x, $y);

	} elsif ($switch eq "0091") {
		# Save the mapname for client login
		$self->{client_saved}{'map'} = substr($msg, 2, 16);

	} elsif ($switch eq "0092") {
		# Save the mapname, and drop the packet until we connect to new
		# zone server (to make mapchanges fluid for our connected client)
		$self->{client_saved}{'map'} = substr($msg, 2, 16);
		$msg = "";

	}

	return $msg;
}

##
# $net->modifyPacketOut(msg)
# msg: A scalar being sent to the RO server
#
sub modifyPacketOut {
	my ($self, $msg) = @_;
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	if (($switch eq "0072" && $config{serverType} == 0) ||
		($switch eq "0072" && $config{serverType} == 1) ||
		($switch eq "0072" && $config{serverType} == 2) ||
		($switch eq "009B" && $config{serverType} == 3) ||
		($switch eq "00F5" && $config{serverType} == 4) ||
		($switch eq "009B" && $config{serverType} == 5) ||
		($switch eq "0072" && $config{serverType} == 6)) {
		# Fake the map login

		# Generate the coords info
		my $coords = "";
		shiftPack(\$coords, $char->{pos_to}{'x'}, 10);
		shiftPack(\$coords, $char->{pos_to}{'y'}, 10);
		shiftPack(\$coords, 0, 4);

		# Send map info
		#'0073' => ['map_loaded','x4 a3',[qw(coords)]],
		$msg = pack('C2 V a3 x2', 0x73, 0, time, $coords);
		$self->clientSend($msg,1);

		$msg = "";

	} elsif ($switch eq "007D") {
		#
		$msg = "";

	} elsif (($switch eq "007E" && $config{serverType} == 0) ||
		($switch eq "007E" && $config{serverType} == 1) ||
		($switch eq "007E" && $config{serverType} == 2) ||
		($switch eq "0089" && $config{serverType} == 3) ||
		($switch eq "0116" && $config{serverType} == 4) ||
		($switch eq "0089" && $config{serverType} == 5) ||
		($switch eq "007E" && $config{serverType} == 6)) {
		# Replace RO Client's Sync with our sync

		$msg = "";
		$self->sendSync();

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

	return $msg;
}

return 1;
