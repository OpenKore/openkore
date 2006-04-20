###########################################################
# Poseidon server - Ragnarok Online server emulator
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation; either version 2 
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2006 OpenKore Development Team
###########################################################
# This class emulates a Ragnarok Online server.
# The RO client connects to this server. This server
# periodically sends a GameGuard query to the RO client,
# and saves the RO client's response.
###########################################################
package Poseidon::RagnarokServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use Misc;
use Utils qw(binSize getCoordString timeOut);

sub new {
	my ($class, @args) = @_;
	my $self = $class->SUPER::new(@args);

	# int challengeNum
	#
	# The number of times that the RO client has sent a
	# GameGuard challenge packet.
	#
	# Invariant: challengeNum >= 0
	$self->{challengeNum} = 0;

	# boolean willReconnect
	#
	# Whether the RO client temporarily disconnected, but
	# will reconnect later. This happens when the RO client
	# disconnects from the login server and connects to the
	# map server.
	#
	# UPDATE: this description isn't right. What is this?
	$self->{willReconnect} = 0;

	# Bytes response
	#
	# A response for the last GameGuard query.
	$self->{response} = undef;

	# Invariant: state ne ''
	$self->{state} = 'ready';

	return $self;
}

##
# $RagnarokServer->query(Bytes packet)
# packet: The raw GameGuard query packet.
# Require: defined($packet) && $self->getState() eq 'ready'
# Ensure: $self->getState() eq 'requesting'
#
# Send a GameGuard query to the RO client.
sub query {
	my ($self, $packet) = @_;
	my $clients = $self->clients();

	for (my $i = 0; $i < @{$clients}; $i++) {
		if ($clients->[$i]) {
			$clients->[$i]->send($packet);
			$self->{state} = 'requesting';
			return;
		}
	}
	print "Error: no Ragnarok Online client connected.\n";
}

##
# String $RagnarokServer->getState()
#
# Get the state of this RagnarokServer object.
# The result can be one of:
# 'ready' - The RO client is ready to handle another GameGuard query.
# 'requesting' - The query has been sent to the RO client, but it hasn't responded yet.
# 'requested' - The RO client has responded to the last GameGuard query.
# 'not connected' - The RO client hasn't connected to this server yet.
sub getState {
	my ($self) = @_;
	my $clients = $self->clients();

	if ($self->{state} eq 'requested') {
		return 'requested';
	} elsif (binSize($clients) == 0) {
		return 'not connected';
	} else {
		return $self->{state};
	}
}

##
# Bytes $RagnarokServer->readResponse()
# Require: $self->getState() eq 'requested'
# Ensure: defined(result) && $self->getState() eq 'ready'
#
# Read the response for the last GameGuard query.
sub readResponse {
	my $resp = $_[0]->{response};
	$_[0]->{response} = undef;
	$_[0]->{state} = 'ready';
	return $resp;
}


#####################################################


sub onClientNew {
	my ($self, $client, $index) = @_;
	print "Ragnarok Online client ($index) connected.\n";
	$self->{state} = 'ready';
}

sub onClientExit {
	my ($self, $client, $index) = @_;
	if ($self->{willReconnect}) {
		print "Ragnarok Online client ($index) disconnected.\n";
	} else {
		print "Ragnarok Online client ($index) disconnected, but will reconnect later.\n";
		$self->{challengeNum} = 0;
	}
}

my %clientdata;

## constants
my $accountID = pack("a4", "acct");
my $posX = 53;
my $posY = 111;

sub onClientData {
	my ($self, $client, $msg, $index) = @_;

	### These variables control the account information ###
	my $host = $self->getHost();
	my $port = pack("v", $self->getPort());
	$host = '127.0.0.1' if ($host eq 'localhost');
	my @ipElements = split /\./, $host;

	my $charID = pack("a4", "char");
	my $sessionID = pack("a4", "sess");
	my $npcID = pack("a4", "npc1");
	my $npcID2 = pack("a4", "npc2");
	my $monsterID = pack("a4", "mon1");
	my $itemID = pack("a4", "itm1");

	my $talkSwitch = pack("v1", 0x90);
	
	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	$self->{willReconnect} = 0;

	# Note:
	# The switch packets are pRO specific and assumes the use of secureLogin 1. It may or may not work with other
	# countries' clients (except probably oRO). The best way to support other clients would be: use a barebones
	# eAthena or Freya as the emulator, or figure out the correct packet switches and include them in the
	# if..elsif..else blocks.
	if (($switch eq '01DB') || ($switch eq '0204')) { # client sends login packet 0204 packet thanks to elhazard
		my $data = pack("C*", 0xdc, 0x01, 0x14) . pack("x17");
		# '01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		$client->send($data);
		my $code = substr($msg, 2);
		if (length($msg) == 2) {
			$clientdata{$index}{secureLogin_type} = 0;
		} elsif (length($msg) == 20) {
			if ($code eq pack("C*", 0x04, 0x02, 0x7B, 0x8A, 0xA8, 0x90, 0x2F, 0xD8, 0xE8, 0x30, 0xF8, 0xA5, 0x25, 0x7A, 0x0D, 0x3B, 0xCE, 0x52)) {
				$clientdata{$index}{secureLogin_type} = 1;
			} elsif ($code eq pack("C*", 0x04, 0x02, 0x27, 0x6A, 0x2C, 0xCE, 0xAF, 0x88, 0x01, 0x87, 0xCB, 0xB1, 0xFC, 0xD5, 0x90, 0xC4, 0xED, 0xD2)) {
				$clientdata{$index}{secureLogin_type} = 2;
			} elsif ($code eq pack("C*", 0x04, 0x02, 0x42, 0x00, 0xB0, 0xCA, 0x10, 0x49, 0x3D, 0x89, 0x49, 0x42, 0x82, 0x57, 0xB1, 0x68, 0x5B, 0x85)) {
				$clientdata{$index}{secureLogin_type} = 3;
			} elsif ($code eq ("C*", 0x04, 0x02, 0x22, 0x37, 0xD7, 0xFC, 0x8E, 0x9B, 0x05, 0x79, 0x60, 0xAE, 0x02, 0x33, 0x6D, 0x0D, 0x82, 0xC6)) {
				$clientdata{$index}{secureLogin_type} = 4;
			} elsif ($code eq pack("C*", 0x04, 0x02, 0xc7, 0x0A, 0x94, 0xC2, 0x7A, 0xCC, 0x38, 0x9A, 0x47, 0xF5, 0x54, 0x39, 0x7C, 0xA4, 0xD0, 0x39)) {
				$clientdata{$index}{secureLogin_type} = 5;
			}
		} else {
			$clientdata{$index}{secureLogin_requestCode} = getHex($code);
		}

	} elsif (($switch eq '01DD') || ($switch eq '0064')) { # 0064 packet thanks to abt123
		$clientdata{$index}{version} = unpack("V", substr($msg, 2, 4));
		$clientdata{$index}{master_version} = unpack("C", substr($msg, length($msg) - 1, 1));
		$clientdata{$index}{secureLogin} = 1 if ($switch eq '01DD');
		my $sessionID2 = pack("C4", 0xff);
		my $sex = 1;
		my $serverName = pack("a20", "Poseidon server"); # server name should be less than or equal to 20 characters
		my $serverUsers = pack("V", 0);
		my $data = pack("C*", 0x69, 0x00, 0x4f, 0x00) . 
			$sessionID . $accountID . $sessionID2 . 
			pack("x30") . pack("C1", $sex) .
			pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
			$port .	$serverName . $serverUsers . pack("x2");
		# '0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*',
		# 			[qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '0065') { # client sends server choice packet
		my $exp = pack("V", 0);
		my $zeny = pack("V", 0);
		my $exp_job = pack("V", 0);
		my $lvl_job = pack("v", 70);
		my $hp = pack("v", 0x0fff);
		my $hp_max = $hp;
		my $sp = pack("v", 0x0fff);
		my $sp_max = $sp;
		my $job_id = pack("v", 23);
		my $hairStyle = pack("v", 1);
		my $level = pack("v", 99);
		my $head_low = pack("v", 0);
		my $head_top = pack("v", 5016);
		my $head_mid = pack("v", 0);
		my $hairColor = pack("v", 6);
		my $charName = pack("a24", "Poseidon");
		my ($str, $agi, $vit, $int, $dex, $luk) = (99, 99, 99, 99, 99, 99);
		my $charStats = pack("C*", $str, $agi, $vit, $int, $dex, $luk);
		my $data = $accountID .
			pack("v2 x20", 0x6b, 0x82) . $charID . $exp . $zeny . $exp_job . $lvl_job .
			pack("x24") . $hp . $hp_max . $sp . $sp_max .
			pack("x2") . $job_id . $hairStyle .
			pack("x2") . $level .
			#pack("x2") . $head_low .
			#pack("x2") . $head_top . $head_mid . $hairColor .
			pack("C*", 0x01, 0x00, 0x38, 0x00, 0x00, 0x00, 0x66, 0x00, 0x0C, 0x00, 0x06, 0x00) .
			pack("x2") . $charName . $charStats . pack("x2");
		# NOTE: ideally, all character slots are filled with the same character, for idiot-proofing
		# NOTE: also, the character's appearance may be made to be modifiable
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '0066') { # client sends character choice packet
		my $mapName = pack("a16", "new_1-1.gat");
		my $data = pack("C*", 0x71, 0x00) . $charID . $mapName . 
			pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) . $port;
		# '0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '0072' &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 0;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 12, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 3;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '00F5' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 4;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 5;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 10, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 6;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '0072' &&
		(length($msg) == 34) &&
		(substr($msg, 7, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 25, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 7;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '009B' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 8;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '009B' &&
		(length($msg) == 37) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 21, 4) eq $charID) &&
		(substr($msg, 28, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = 9;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$clientdata{$index}{serverType} = "1 or 2";
		onClientSendMapLogin($self, $client);

	} elsif (($switch eq '0072' || $switch eq '009B' || $switch eq '00F5') &&
		($msg =~ /$accountID/) &&
		($msg =~ /$charID/) &&
		($msg =~ /$sessionID/)
		) { # client sends the maplogin packet (unknown)

		print "Received unsupported map login packet $switch.\n";
		visualDump($msg, "$switch");
		$clientdata{$index}{serverType} = -1;
		onClientSendMapLogin($self, $client);

	} elsif ($switch eq '007D') { # client sends the map loaded packet
		my $data;

		# Show some items in inventory
		# '01EE' => ['item_inventory_stackable', 'v4', [qw(index ID type amount)]]
		$data .= pack("C2 v1", 0xEE, 0x01, 40) .
			pack("v2 C2 v1 x10", 3, 501, 0, 1, 16) .
			pack("v2 C2 v1 x10", 4, 909, 3, 1, 144);

		# Make Poseidon look to front
		$data .= pack('v1 a4 C1 x1 C1', 0x9C, $accountID, 0, 4);
		
		# Show a kafra NPC
		# '0078' => ['actor_display', 'a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],	
		$data .= pack("v1 a4 v1 x6 v1 x30", 0x78, $npcID, 300, 114) . getCoordString($posX + 5, $posY + 3, 1) . pack("C2 x3", 0x05, 0x05);
		$data .= pack('v1 a4 C1 x1 C1', 0x9C, $npcID, 0, 3);
		
		# Show a kafra NPC 2
		# '0078' => ['actor_display', 'a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],	
		$data .= pack("v1 a4 v1 x6 v1 x30", 0x78, $npcID2, 300, 86) . getCoordString($posX + 3, $posY + 4, 1) . pack("C2 x3", 0x05, 0x05);
		$data .= pack('v1 a4 C1 x1 C1', 0x9C, $npcID2, 0, 3);

		# Show a monster
		# '0078' => ['actor_display', 'a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],	
		$data .= pack("v1 a4 v1 x6 v1 x30", 0x78, $monsterID, 1000, 1002) . getCoordString($posX - 2, $posY - 1, 1) . pack("x3 v1", 3);
		$data .= pack('v1 a4 C1 x1 C1', 0x9C, $monsterID, 0, 5);

		# Show an item on ground
		# '009D' => ['item_exists', 'a4 v1 x1 v3', [qw(ID type x y amount)]]
		$data .= pack("v1 a4 v1 x1 v3 x2", 0x9D, $itemID, 512, $posX + 1, $posY - 1, 1);

		# Let's not wait for the client to ask for the unit info
		# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		$data .= pack("v1 a4 a24", 0x95, $accountID, "Poseidon");
		$data .= pack("v1 a4 a24", 0x95, $npcID, "Kafra");
		$data .= pack("v1 a4 a24", 0x95, $monsterID, "Poring");

		# '009A' => ['system_chat', 'x2 Z*', [qw(message)]],
		$data .= pack("v2 a32", 0x9A, 36, "Welcome to the Poseidon Server!");
		
		$client->send($data);

	} elsif (
		(($switch eq '007E') && (($clientdata{$index}{serverType} == 0) || ($clientdata{$index}{serverType} == 1) || ($clientdata{$index}{serverType} == 6) || ($clientdata{$index}{serverType} == 7))) ||
		(($switch eq '0089') && (($clientdata{$index}{serverType} == 3) || ($clientdata{$index}{serverType} == 5) || ($clientdata{$index}{serverType} == 8) || ($clientdata{$index}{serverType} == 9))) ||
		(($switch eq '0116') && ($clientdata{$index}{serverType} == 4))
		) { # client sends sync packet
		my $data = pack("C*", 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00);
		$client->send($data);

		### Check if packet 0228 got tangled up with the sync packet
		if (uc(unpack("H2", substr($msg, 7, 1))) . uc(unpack("H2", substr($msg, 6, 1))) eq '0228') {
			# queue the response (thanks abt123)
			$self->{response} = substr($msg, 6, 18);
			$self->{state} = 'requested';
		}

	} elsif ($switch eq '0090' || ($msg =~ /$talkSwitch($npcID|$npcID2)/)) { # npc talk
		$clientdata{$index}{npcTalkChoice} = 0;
		if ($msg =~ /$talkSwitch$npcID/) {
			# Show the kafra image
			# '01B3' => ['npc_image', 'Z63 C1', [qw(npc_image type)]],
			my $data = pack("C2 a64 C1", 0xB3, 0x01, "kafra_04.bmp", 0x02);
			$client->send($data);
			# Show the messages
			$data = pack("v2 a4 a8", 0xB4, 16, $npcID, "[Kafra]");
			$data .= pack("v2 a4 a62", 0xB4, 70, $npcID, "Welcome to Kafra Corp. We will stay with you wherever you go.");
			$data .= pack("v1 a4", 0xB5, $npcID);
			$client->send($data);
		} else {
			my $data = pack("v2 a4 a8", 0xB4, 16, $npcID2, "[Usher]");
			$data .= pack("v2 a4 a32", 0xB4, 40, $npcID2, "Welcome to the Poseidon Server.");
			$data .= pack("v1 a4", 0xB6, $npcID2);
			$client->send($data);
		}

	} elsif ($switch eq '00B2') { # quit to character select screen
		if (unpack("C1", substr($msg, 2, 1)) == 1) {
			my $data = pack("C*", 0xB3, 0x00, 0x01);
			$client->send($data);
		}

	} elsif ($switch eq '00B8') { # npc talk response
		if (substr($msg, 2, 4) eq $npcID) {
			my $response = unpack("C1", substr($msg, 6, 1));
			print "Response is: $response\n";
			if ($response == 1) {
				# Check server info
				$clientdata{$index}{npcTalkChoice} = 1;
				my $data = pack("v2 a4 a8", 0xB4, 16, $npcID, "[Kafra]");
				if ($clientdata{$index}{serverType} == -1) {
					$data .= pack("v2 a4 a74", 0xB4, 82, $npcID, "Oh, it seems Openkore does not currently support the type of your server!");
				} else {
					$data .= pack("v2 a4 a50", 0xB4, 58, $npcID, "Your RO client uses the following server details:");
					$data .= pack("v2 a4 a27", 0xB4, 35, $npcID, "^0000ffversion: $clientdata{$index}{version}");
					$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "master_version: $clientdata{$index}{master_version}");
					$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "serverType: $clientdata{$index}{serverType}");
					if ($clientdata{$index}{secureLogin}) {
						$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "secureLogin: $clientdata{$index}{secureLogin}");
						if ($clientdata{$index}{secureLogin_requestCode}) {
							$data .= pack("v2 a4 a" . (length($clientdata{$index}{secureLogin_requestCode}) + 26), 0xB4, (length($clientdata{$index}{secureLogin_requestCode}) + 34), $npcID, "secureLogin_requestCode: $clientdata{$index}{secureLogin_requestCode}");
						} elsif ($clientdata{$index}{secureLogin_type}) {
							$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "secureLogin_type: $clientdata{$index}{secureLogin_type}");
						}
					}
				}
				$data .= pack("v1 a4", 0xB5, $npcID);
				$client->send($data);

			} elsif ($response == 2) {
				# Use storage
				my $data;
				$data .= pack("C2 v1", 0xF0, 0x01, 40) .
					pack("v2 C2 v1 x10", 3, 501, 0, 1, 16) .
					pack("v2 C2 v1 x10", 4, 909, 3, 1, 144);
				$data .= pack("v3", 0xF2, 2, 300);
				$data .= pack("C2 a64 C1", 0xB3, 0x01, "kafra_04.bmp", 0xFF);
				$data .= pack("v1 a4", 0xB6, $npcID);
				$client->send($data);

			} elsif ($response == 3) {
				# Use storage
				my $data;
				$data = pack("v2 a4 a8", 0xB4, 16, $npcID, "[Kafra]");
				$data .= pack("v2 a4 a49", 0xB4, 57, $npcID, "We Kafra Corp. always try to serve you the best.");
				$data .= pack("v2 a4 a19", 0xB4, 27, $npcID, "Please come again.");
				$data .= pack("v1 a4", 0xB6, $npcID);
				$client->send($data);
			}
		}

	} elsif ($switch eq '00B9') { # npc talk continue
		if (substr($msg, 2, 4) eq $npcID) {
			if ($clientdata{$index}{npcTalkChoice} == 0) {
				# Show kafra response list
				my $data = pack("v2 a4 a39", 0xB7, 47, $npcID, "Check Server Info:Test Storage:Cancel:");
				$client->send($data);

			} elsif ($clientdata{$index}{npcTalkChoice} == 1) {
				my $data = pack("v2 a4 a8", 0xB4, 16, $npcID, "[Kafra]");
				if ($clientdata{$index}{serverType} == -1) {
					$data .= pack("v2 a4 a101", 0xB4, 109, $npcID, "Please inform the developers about this so we can support you server in future releases of Openkore.");
					$data .= pack("v2 a4 a48", 0xB4, 56, $npcID, "Please visit ^0000ffhttp://forums.openkore.com/");
				} else {
					$data .= pack("v2 a4 a101", 0xB4, 109, $npcID, "The ^0000ffip^000000 and ^0000ffport^000000 details can be found on your client's (s)clientinfo.xml.");
					$data .= pack("v2 a4 a60", 0xB4, 68, $npcID, "For more info, please visit ^0000ffhttp://www.openkore.com/");
				}
				$data .= pack("v2 a4 a28", 0xB4, 36, $npcID, "^000000Thank you very much.");
				$data .= pack("v1 a4", 0xB6, $npcID);
				$client->send($data);
			}
		}

	} elsif (($switch eq '00F7' || $switch eq '0193') && (length($msg) == 2)) { # storage close
		my $data = pack("v1", 0xF8);
		$client->send($data);

	} elsif ($switch eq '0146') { # talk cancel
		my $data = pack("C2 a64 C1", 0xB3, 0x01, "kafra_04.bmp", 0xFF);
		$client->send($data);

	} elsif ($switch eq '0187') { # accountid sync (what does this do anyway?)
		$client->send($msg);

	} elsif ($switch eq '018A') { # client sends quit packet
		$self->{challengeNum} = 0;
		$client->send(pack("C*", 0x8B, 0x01, 0x00, 0x00));

	} elsif ($switch eq '0228') { # client sends game guard sync
		# Queue the response
		$self->{response} = $msg;
		$self->{state} = 'requested';

	} elsif ($switch eq '0258') { # client sent gameguard's challenge request
		# Reply with "gameguard_grant" instead of a 0227 packet. Normally, the server would
		# send a 0227 gameguard challenge to the client, then the client will send the
		# proper 0228 response. Only after that will the server send 0259 to allow the
		# client to continue the login sequence. Since this is just a fake server,
		# there is no need to go through all that and we can do a shortcut.
		if ($self->{challengeNum} == 0) {
			print "Received GameGuard sync request. Client allowed to login account server.\n";
			$client->send(pack("C*", 0x59, 0x02, 0x01));
		} else {
			print "Received GameGuard sync request. Client allowed to login char/map server.\n";
			$client->send(pack("C*", 0x59, 0x02, 0x02));
		}
		$self->{challengeNum}++;
		
	#} elsif ($switch eq '0085') { # sendMove
	#	print "Received packet $switch: sendMove.\n";
	#	visualDump($msg, "$switch");

	#} elsif ($switch eq '0089') { # sendAttack
	#	print "Received packet $switch: sendAttack.\n";
	#	visualDump($msg, "$switch");

	#} elsif ($switch eq '008C') { # public chat
	#	print "Received packet $switch: public chat.\n";

	#} elsif ($switch eq '0094') { # getPlayerInfo
	#	print "Received packet $switch: getPlayerInfo.\n";

	} elsif ($switch eq '00BF') { # emoticon
		my ($client, $code) = @_;
		my $data = pack("v1 a4", 0xC0, $accountID) . substr($msg, 2, 1);
		$clientdata{$index}{emoticonTime} = time;
		$client->send($data);

	} else {
		print "\nReceived packet $switch:\n";
		visualDump($msg, "$switch");

		# Just provide feedback in the RO Client about the unhandled packet
		# '008E' => ['self_chat', 'x2 Z*', [qw(message)]],
		my $data = pack("v2 a31", 0x8E, 35, "Sent packet $switch (" . length($msg) . " bytes).");
		if (timeOut($clientdata{$index}{emoticonTime}, 1.8)) {
			$clientdata{$index}{emoticonTime} = time;
			$data .= pack("v1 a4 C1", 0xC0, $accountID, 1);
		}

		# These following packets should reset the item inventory.
		# If you drop something from your inventory and the server didn't respond,
		# you will not be able to drop the item for the second test
		# This, however, does not cover item_use. YOu would have to relog
		# to test another item_use packet.
		#$data .= pack("v3", 0xAF, 3, 0);
		#$data .= pack("v3", 0xAF, 4, 0);

		# There are no other send packet that contains NPC ids as the last four byte
		# other than the talk and sendGetPlayerInfo packets.
		# Since most possible talk packets are handled above, we can assume that this is
		# a sendGetPlayerInfo packet.
		# Note that we have an NPC that is not named initially to allow a
		# sendGetPlayerInfo packet to be captured.)
		# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		if (substr($msg, length($msg) - 4, 4) eq $npcID2) {
			$data .= pack("v1 a4 a24", 0x95, $npcID2, "Usher");
		}

		$client->send($data);
	}
}

sub onClientSendMapLogin {
	my ($self, $client) = @_;

	# '0073' => ['map_loaded','x4 a3',[qw(coords)]]
	my $data = $accountID .
		pack("C*", 0x73, 0x00, 0x31, 0x63, 0xe9, 0x02) .
		getCoordString($posX, $posY, 1) .
		pack("C*", 0x05, 0x05);
	$data .= pack("C2 v1", 0x0F, 0x01, 226) .
		# skillID targetType level sp range skillName
		pack("v2 x2 v3 a24 C1", 1, 0, 9, 0, 1, "NV_BASIC" . chr(0) . "GetMapInfo" . chr(0x0A), 0) .
		pack("v2 x2 v3 a24 C1", 24, 4, 1, 10, 10, "AL_RUWACH", 0) . # self skill test
		pack("v2 x2 v3 a24 C1", 25, 2, 1, 10, 9, "AL_PNEUMA", 0) . # location skill test
		pack("v2 x2 v3 a24 C1", 26, 4, 2, 9, 1, "AL_TELEPORT", 0) . # self skill test
		pack("v2 x2 v3 a24 C1", 27, 2, 4, 26, 9, "AL_WARP", 0) . # location skill test
		pack("v2 x2 v3 a24 C1", 28, 16, 10, 40, 9, "AL_HEAL", 0); # target skill test
	$client->send($data);
	$self->{willReconnect} = 1;
}

1;
