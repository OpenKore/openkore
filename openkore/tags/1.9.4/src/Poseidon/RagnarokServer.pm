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
use Utils qw(binSize getCoordString timeOut getHex);

my %clientdata;

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
	print "Ragnarok Online client ($index) disconnected.\n";
}

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
	my $sessionID2 = pack("C4", 0xff);
	my $npcID1 = pack("a4", "npc1");
	my $npcID0 = pack("a4", "npc2");
	my $monsterID = pack("a4", "mon1");
	my $itemID = pack("a4", "itm1");

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	my $packed_switch = quotemeta substr($msg, 0, 2);

	# Note:
	# The switch packets are pRO specific and assumes the use of secureLogin 1. It may or may not work with other
	# countries' clients (except probably oRO). The best way to support other clients would be: use a barebones
	# eAthena or Freya as the emulator, or figure out the correct packet switches and include them in the
	# if..elsif..else blocks.
	if (($switch eq '01DB') || ($switch eq '0204')) { # client sends login packet 0204 packet thanks to elhazard

		# '01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		my $data = pack("C*", 0xdc, 0x01, 0x14) . pack("x17");
		$client->send($data);

		# save servers.txt info
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

	} elsif (($switch eq '01DD') || ($switch eq '01FA') || ($switch eq '0064') || ($switch eq '0060') || ($switch eq '0277')) { # 0064 packet thanks to abt123

		my $sex = 1;
		my $serverName = pack("a20", "Poseidon server"); # server name should be less than or equal to 20 characters
		my $serverUsers = pack("V", @{$self->clients()} - 1);
		# '0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*',
		# 			[qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		my $data = pack("C*", 0x69, 0x00, 0x4f, 0x00) . 
			$sessionID . $accountID . $sessionID2 . 
			pack("x30") . pack("C1", $sex) .
			pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
			$port .	$serverName . $serverUsers . pack("x2");

		$client->send($data);

		# save servers.txt info
		$clientdata{$index}{version} = unpack("V", substr($msg, 2, 4));
		$clientdata{$index}{master_version} = unpack("C", substr($msg, length($msg) - 1, 1));
		if ($switch eq '01DD') {
			$clientdata{$index}{secureLogin} = 1;
			undef $clientdata{$index}{secureLogin_account};
		} elsif ($switch eq '01FA') {
			$clientdata{$index}{secureLogin} = 3;
			$clientdata{$index}{secureLogin_account} = unpack("C", substr($msg, 47, 1));
		} else {
			undef $clientdata{$index}{secureLogin};
			undef $clientdata{$index}{secureLogin_type};
			undef $clientdata{$index}{secureLogin_account};
			undef $clientdata{$index}{secureLogin_requestCode};
		}
		if (($switch ne '01DD') && ($switch ne '01FA') && ($switch ne '0064')) {
			$clientdata{$index}{masterLogin_packet} = $switch;
		} else {
			undef $clientdata{$index}{masterLogin_packet};
		}

	} elsif (($switch eq '0065') || ($msg =~ /^$packed_switch$accountID$sessionID$sessionID2\x0\x0.$/)) { # client sends server choice packet

		my $exp = pack("V", 0);
		my $zeny = pack("V", 0);
		my $exp_job = pack("V", 0);
		my $lvl_job = pack("v", 70);
		my $hp = pack("v", 0x0fff);
		my $hp_max = $hp;
		my $sp = pack("v", 0x0fff);
		my $sp_max = $sp;
		my $job_id1 = pack("v", 0);
		my $job_id2 = pack("v", 23);
		my $hairStyle = pack("v", 16);
		my $level = pack("v", 99);
		my $head_low = pack("v", 0);
		my $head_top = pack("v", 5016);
		my $head_mid = pack("v", 0);
		my $hairColor = pack("v", 6);
		my $charName1 = pack("a24", "Poseidon");
		my $charName2 = pack("a24", "Poseidon Dev");
		my ($str, $agi, $vit, $int, $dex, $luk) = (99, 99, 99, 99, 99, 99);
		my $charStats = pack("C*", $str, $agi, $vit, $int, $dex, $luk);
		my $data = $accountID .
			pack("v2 x20", 0x6b, 0xEC) .
			$charID . $exp . $zeny . $exp_job . $lvl_job .
			pack("x24") . $hp . $hp_max . $sp . $sp_max .
			pack("x2") . $job_id1 . $hairStyle .
			pack("x2") . $level .
			#pack("x2") . $head_low . pack("x2") . $head_top . $head_mid . $hairColor .
			pack("C*", 0x01, 0x00, 0x38, 0x00, 0x00, 0x00, 0xA0, 0x00, 0x9E, 0x00, 0x06, 0x00) .
			#pack("C*", 0x01, 0x00, 0x38, 0x00, 0x00, 0x00, 0x46, 0x00, 0x03, 0x00, 0x06, 0x00) .
			pack("x2") . $charName1 . $charStats . pack("v1", 0) .
			$charID . $exp . $zeny . $exp_job . $lvl_job .
			pack("x24") . $hp . $hp_max . $sp . $sp_max .
			pack("x2") . $job_id2 . $hairStyle .
			pack("x2") . $level .
			#pack("x2") . $head_low . pack("x2") . $head_top . $head_mid . $hairColor .
			pack("C*", 0x01, 0x00, 0x39, 0x00, 0x00, 0x00, 0x9F, 0x00, 0x98, 0x00, 0x06, 0x00) .
			pack("x2") . $charName2 . $charStats . pack("v1", 1);
		# NOTE: ideally, all character slots are filled with the same character, for idiot-proofing
		# NOTE: also, the character's appearance may be made to be modifiable
		$client->send($data);

		# save servers.txt info
		if ($switch ne '0065') {
			$clientdata{$index}{gameLogin_packet} = $switch;
		} else {
			undef $clientdata{$index}{gameLogin_packet};
		}

	} elsif ($switch eq '0066') { # client sends character choice packet

		$clientdata{$index}{mode} = unpack('C1', substr($msg, 2, 1));

		# '0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		my $mapName = pack("a16", "new_1-1.gat");
		my $data = pack("C*", 0x71, 0x00) . $charID . $mapName . 
			pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) . $port;
		$client->send($data);

	} elsif ($switch eq '0072' &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 0;

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 12, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 3;

	} elsif ($switch eq '00F5' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 4;

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 5;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 10, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 6;

	} elsif ($switch eq '0072' &&
		(length($msg) == 34) &&
		(substr($msg, 7, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 25, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 7;

	} elsif ($switch eq '009B' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 8;

	} elsif ($switch eq '009B' &&
		(length($msg) == 37) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 21, 4) eq $charID) &&
		(substr($msg, 28, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 9;

	} elsif ($switch eq '0072' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 10;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 11;

	} elsif ($switch eq '0094' &&
		(length($msg) == 30) &&
		(substr($msg, 12, 4) eq $accountID) &&
		(substr($msg, 2, 4) eq $charID) &&
		(substr($msg, 6, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 12;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = "1 or 2";

	} elsif ($msg =~ /^$packed_switch/
		&& $msg =~ /$accountID/
		&& $msg =~ /$charID/
		&& $msg =~ /$sessionID/) { # client sends the maplogin packet (unknown)

		print "Received unsupported map login packet $switch.\n";
		visualDump($msg, "$switch");

		mapLogin($self, $client, $msg, $index);
		# save servers.txt info
		undef $clientdata{$index}{serverType};
		#$clientdata{$index}{sendMapLogin} = $msg;

	} elsif ($switch eq '007D') { # client sends the map loaded packet
		my $data;

		# Make Poseidon look to front
		$data .= pack('v1 a4 C1 x1 C1', 0x9C, $accountID, 0, 4);
		
		# Let's not wait for the client to ask for the unit info
		# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		$data .= pack("v1 a4 a24", 0x95, $accountID, 'Poseidon' . (($clientdata{$index}{mode} ? ' Dev' : '')));

		# '009A' => ['system_chat', 'x2 Z*', [qw(message)]],
		$data .= pack("v2 a32", 0x9A, 36, "Welcome to the Poseidon Server!");

		# Show an NPC
		# '0078' => ['actor_display', 'a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],	
		$data .= pack("v1 a4 v1 x6 v1 x30", 0x78, $npcID0, 300, 86) . getCoordString($posX + 3, $posY + 4, 1) . pack("C2 x3", 0x05, 0x05);
		$data .= pack('v1 a4 C1 x1 C1', 0x9C, $npcID0, 0, 3);

		# Let's not wait for the client to ask for the unit info
		# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		$data .= pack("v1 a4 a24", 0x95, $npcID0, "Server Details Guide");

		if ($clientdata{$index}{mode}) {
			# Show some items in inventory
			# '01EE' => ['item_inventory_stackable', 'v4', [qw(index ID type amount)]]
			$data .= pack("C2 v1", 0xEE, 0x01, 40) .
				pack("v2 C2 v1 x10", 3, 501, 0, 1, 16) .
				pack("v2 C2 v1 x10", 4, 909, 3, 1, 144);

			# Show a kafra NPC
			# '0078' => ['actor_display', 'a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],	
			$data .= pack("v1 a4 v1 x6 v1 x30", 0x78, $npcID1, 300, 114) . getCoordString($posX + 5, $posY + 3, 1) . pack("C2 x3", 0x05, 0x05);
			$data .= pack('v1 a4 C1 x1 C1', 0x9C, $npcID1, 0, 3);
			
			# Show a monster
			# '0078' => ['actor_display', 'a4 v14 a4 x7 C1 a3 x2 C1 v1', [qw(ID walk_speed param1 param2 param3 type hair_style weapon lowhead shield tophead midhead hair_color clothes_color head_dir guildID sex coords act lv)]],	
			$data .= pack("v1 a4 v1 x6 v1 x30", 0x78, $monsterID, 1000, 1002) . getCoordString($posX - 2, $posY - 1, 1) . pack("x3 v1", 3);
			$data .= pack('v1 a4 C1 x1 C1', 0x9C, $monsterID, 0, 5);

			# Show an item on ground
			# '009D' => ['item_exists', 'a4 v1 x1 v3', [qw(ID type x y amount)]]
			$data .= pack("v1 a4 v1 x1 v3 x2", 0x9D, $itemID, 512, $posX + 1, $posY - 1, 1);

			# Let's not wait for the client to ask for the unit info
			# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
			$data .= pack("v1 a4 a24", 0x95, $monsterID, "Poring");
		}

		$client->send($data);

	} elsif (
		(($switch eq '007E') && (($clientdata{$index}{serverType} == 0) || ($clientdata{$index}{serverType} == 1) || ($clientdata{$index}{serverType} == 2) || ($clientdata{$index}{serverType} == 6) || ($clientdata{$index}{serverType} == 7) || ($clientdata{$index}{serverType} == 10) || ($clientdata{$index}{serverType} == 11))) ||
		(($switch eq '0089') && (($clientdata{$index}{serverType} == 3) || ($clientdata{$index}{serverType} == 5) || ($clientdata{$index}{serverType} == 8) || ($clientdata{$index}{serverType} == 9))) ||
		(($switch eq '0116') && ($clientdata{$index}{serverType} == 4)) ||
		(($switch eq '00A7') && ($clientdata{$index}{serverType} == 12))
		) { # client sends sync packet
		my $data = pack("C*", 0x7F, 0x00, 0x00, 0x00, 0x00, 0x00);
		$client->send($data);

		### Check if packet 0228 got tangled up with the sync packet
		if (uc(unpack("H2", substr($msg, 7, 1))) . uc(unpack("H2", substr($msg, 6, 1))) eq '0228') {
			# queue the response (thanks abt123)
			$self->{response} = substr($msg, 6, 18);
			$self->{state} = 'requested';
		}

	} elsif ($switch eq '00B2') { # quit to character select screen
		if (unpack("C1", substr($msg, 2, 1)) == 1) {
			my $data = pack("C*", 0xB3, 0x00, 0x01);
			$client->send($data);
		}

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

	} else {
		if ($switch eq '0090' || ($msg =~ /\x90\x0($npcID1|$npcID0)/)) { # npc talk
			undef $clientdata{$index}{npc_talk_code};
			if ($msg =~ /\x90\x0$npcID1/) {
				# Show the kafra image
				# '01B3' => ['npc_image', 'Z63 C1', [qw(npc_image type)]],
				my $data = pack("C2 a64 C1", 0xB3, 0x01, "kafra_04.bmp", 0x02);
				$client->send($data);
				# Show the messages
				$data = pack("v2 a4 a8", 0xB4, 16, $npcID1, "[Kafra]");
				$data .= pack("v2 a4 a62", 0xB4, 70, $npcID1, "Welcome to Kafra Corp. We will stay with you wherever you go.");
				$data .= pack("v1 a4", 0xB5, $npcID1);
				$client->send($data);
			} else {
				my $data = pack("v2 a4 a9", 0xB4, 17, $npcID0, "[Hakore]");
				$data .= pack("v2 a4 a93", 0xB4, 101, $npcID0, "Hello! I was examining your RO client's login packets while you were connecting to Poseidon.");
				$data .= pack("v1 a4", 0xB5, $npcID0);
				$client->send($data);
			}

		} elsif ($switch eq '00B8') { # npc talk response

			my $npcID = substr($msg, 2, 4);
			my $response = unpack("C1", substr($msg, 6, 1));
			if ($npcID eq $npcID0) {
				if ($response == 1) {
					# Check server info
					my $data = pack("v2 a4 a9", 0xB4, 17, $npcID, "[Hakore]");
					$data .= pack("v2 a4 a50", 0xB4, 58, $npcID, "Your RO client uses the following server details:");
					$data .= pack("v2 a4 a27", 0xB4, 35, $npcID, "^2222DDversion: $clientdata{$index}{version}");
					$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "master_version: $clientdata{$index}{master_version}");
					$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "serverType: " . ((defined $clientdata{$index}{serverType}) ? $clientdata{$index}{serverType} : 'Unknown'));
					if ($clientdata{$index}{secureLogin}) {
						$data .= pack("v2 a4 a15", 0xB4, 23, $npcID, "secureLogin: $clientdata{$index}{secureLogin}");
						if ($clientdata{$index}{secureLogin_requestCode}) {
							$data .= pack("v2 a4 a" . (length($clientdata{$index}{secureLogin_requestCode}) + 26), 0xB4, (length($clientdata{$index}{secureLogin_requestCode}) + 34), $npcID, "secureLogin_requestCode: $clientdata{$index}{secureLogin_requestCode}");
						} elsif (defined $clientdata{$index}{secureLogin_type}) {
							$data .= pack("v2 a4 a20", 0xB4, 28, $npcID, "secureLogin_type: $clientdata{$index}{secureLogin_type}");
						}
						if ($clientdata{$index}{secureLogin_account}) {
							$data .= pack("v2 a4 a25", 0xB4, 33, $npcID, "secureLogin_account: $clientdata{$index}{secureLogin_account}");
						}
					}
					if ($clientdata{$index}{masterLogin_packet}) {
						$data .= pack("v2 a4 a25", 0xB4, 33, $npcID, "masterLogin_packet: $clientdata{$index}{masterLogin_packet}");
					}
					if ($clientdata{$index}{gameLogin_packet}) {
						$data .= pack("v2 a4 a23", 0xB4, 31, $npcID, "gameLogin_packet: $clientdata{$index}{gameLogin_packet}");
					}
					$data .= pack("v1 a4", 0xB5, $npcID);
					$client->send($data);
					if (defined $clientdata{$index}{serverType}) {
						$clientdata{$index}{npc_talk_code} = 3;
					} else {
						$clientdata{$index}{npc_talk_code} = 2.5;
					}

				} elsif ($response == 2) {
					# Use storage
					my $data;
					$data = pack("v2 a4 a8", 0xB4, 16, $npcID, "[Hakore]");
					$data .= pack("v2 a4 a42", 0xB4, 50, $npcID, "Thank you for the visit. Go and multiply!");
					$data .= pack("v1 a4", 0xB6, $npcID);
					$client->send($data);
				}

			} elsif ($npcID eq $npcID1) {
				if ($response == 1) {
					# Use storage
					my $data;
					$data .= pack("C2 v1", 0xF0, 0x01, 40) .
						pack("v2 C2 v1 x10", 3, 501, 0, 1, 16) .
						pack("v2 C2 v1 x10", 4, 909, 3, 1, 144);
					$data .= pack("v3", 0xF2, 2, 300);
					$data .= pack("C2 a64 C1", 0xB3, 0x01, "kafra_04.bmp", 0xFF);
					$data .= pack("v1 a4", 0xB6, $npcID);
					$client->send($data);

				} elsif ($response == 2) {
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
			my $npcID = substr($msg, 2, 4);
			if ($npcID eq $npcID0) {
				if ($clientdata{$index}{npc_talk_code} == 2) {
					# Show NPC response list
					my $data = pack("v2 a4 a24", 0xB7, 32, $npcID, "Yes, please:No, thanks:");
					$client->send($data);
					$clientdata{$index}{npc_talk_code} = 3;

				} else {
					my $data = pack("v2 a4 a9", 0xB4, 17, $npcID, "[Hakore]");
					if (!$clientdata{$index}{npc_talk_code}) {
						if (!defined $clientdata{$index}{serverType}) {
							$data .= pack("v2 a4 a71", 0xB4, 79, $npcID, "However, I regret that Openkore may not currently support your server.");
						} elsif ($clientdata{$index}{serverType} == 7 || $clientdata{$index}{serverType} == 12) {
							$data .= pack("v2 a4 a82", 0xB4, 90, $npcID, "However, I regret that Openkore does not yet fully support your server this time.");
						} else {
							$data .= pack("v2 a4 a64", 0xB4, 72, $npcID, "Based on my examination, I think Openkore supports your server.");
							$data .= pack("v2 a4 a99", 0xB4, 107, $npcID, "I can tell you the possible server details you can use to make Openkore to connect to your server.");
						}
						$data .= pack("v1 a4", 0xB5, $npcID);
						$clientdata{$index}{npc_talk_code} = 1;

					} elsif ($clientdata{$index}{npc_talk_code} == 1) {
						if ((!defined $clientdata{$index}{serverType}) || ($clientdata{$index}{serverType} == 7)) {
							$data .= pack("v2 a4 a42", 0xB4, 50, $npcID, "Would you still like to hear the details?");
						} else {
							$data .= pack("v2 a4 a36", 0xB4, 44, $npcID, "Would you like to hear the details?");
						}
						$data .= pack("v1 a4", 0xB5, $npcID);
						$clientdata{$index}{npc_talk_code} = 2;
				
					} elsif ($clientdata{$index}{npc_talk_code} == 2.5) {
						if (!defined $clientdata{$index}{serverType}) {
							$data .= pack("v2 a4 a68", 0xB4, 76, $npcID, "As you can see, I can't find a matching serverType for your server.");
							$data .= pack("v2 a4 a119", 0xB4, 127, $npcID, "Please make a trial-and-error using all available serverTypes, one of them might be able to work.");
						} elsif ($clientdata{$index}{serverType} == 7 || $clientdata{$index}{serverType} == 12) {
							$data .= pack("v2 a4 a65", 0xB4, 73, $npcID, "Like I said, your server is not yet fully supported by Openkore.");
							$data .= pack("v2 a4 a105", 0xB4, 113, $npcID, "You can login to the server and do most basic tasks, but you cannot attack, sit or stand, or use skills.");
						}
						$data .= pack("v1 a4", 0xB5, $npcID);
						$clientdata{$index}{npc_talk_code} = 4;

					} elsif ($clientdata{$index}{npc_talk_code} == 3) {
						$data .= pack("v2 a4 a103", 0xB4, 111, $npcID, "The values of ^2222DDip^000000 and ^2222DDport^000000 can be found on your client's (s)clientinfo.xml.");
						$data .= pack("v1 a4", 0xB5, $npcID);
						$clientdata{$index}{npc_talk_code} = 4;

					} elsif ($clientdata{$index}{npc_talk_code} == 4) {
						if (!defined $clientdata{$index}{serverType}) {
							$data .= pack("v2 a4 a135", 0xB4, 143, $npcID, "If none of the serverTypes work, please inform the developers about this so we can support your server in future releases of Openkore.");
							$data .= pack("v2 a4 a55", 0xB4, 63, $npcID, "Please visit ^2222DDhttp://forums.openkore.com/^000000");
							$data .= pack("v2 a4 a28", 0xB4, 36, $npcID, "Thank you.");
						} else {
							if (($clientdata{$index}{serverType} == 7)
								|| ($clientdata{$index}{serverType} == 8)
								|| ($clientdata{$index}{serverType} == 9)
								|| ($clientdata{$index}{serverType} == 10)
								|| ($clientdata{$index}{serverType} == 11)
								|| ($clientdata{$index}{serverType} == 12)
								|| ($clientdata{$index}{masterLogin_packet})
								|| ($clientdata{$index}{gameLogin_packet})
							) {
								$data .= pack("v2 a4 a73", 0xB4, 81, $npcID, "Please note that you can only connect to your server using Openkore SVN.");
							} else {
								$data .= pack("v2 a4 a52", 0xB4, 60, $npcID, "Openkore v.1.6.6 or later will work on your server.");
							}
							$data .= pack("v2 a4 a67", 0xB4, 75, $npcID, "For more info, please visit ^2222DDhttp://www.openkore.com/^000000");
							$data .= pack("v2 a4 a11", 0xB4, 19, $npcID, "Good luck!");
						}
						$data .= pack("v1 a4", 0xB6, $npcID);
					}
					$client->send($data);
				}

			} elsif ($npcID eq $npcID1) {
				# Show kafra response list
				my $data = pack("v2 a4 a20", 0xB7, 28, $npcID, "Use Storage:Cancel:");
				$client->send($data);
			}

		} elsif ($switch eq '0146') { # talk cancel
			my $npcID = substr($msg, 2, 4);
			if ($npcID eq $npcID1) {
				my $data = pack("C2 a64 C1", 0xB3, 0x01, "kafra_04.bmp", 0xFF);
				$client->send($data);
			}

		} elsif ($clientdata{$index}{mode}) {

			if (($switch eq '00F7' || $switch eq '0193') && (length($msg) == 2)) { # storage close
				my $data = pack("v1", 0xF8);
				$client->send($data);

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
				my $ID = substr($msg, length($msg) - 4, 4);
				if ($ID eq $npcID0) {
					$data .= pack("v1 a4 a24", 0x95, $npcID0, "Server Details Guide");
				} elsif ($ID eq $npcID1) {
					$data .= pack("v1 a4 a24", 0x95, $npcID1, "Kafra");
				}

				$client->send($data);
			}
		}
	}
}

sub mapLogin {
	my ($self, $client, $msg, $index) = @_;

	# '0073' => ['map_loaded','x4 a3',[qw(coords)]]
	my $data = $accountID .
		pack("C*", 0x73, 0x00, 0x31, 0x63, 0xe9, 0x02) .
		getCoordString($posX, $posY, 1) .
		pack("C*", 0x05, 0x05);
		
	if ($clientdata{$index}{mode}) {
		$data .= pack("C2 v1", 0x0F, 0x01, 226) .
			# skillID targetType level sp range skillName
			pack("v2 x2 v3 a24 C1", 1, 0, 9, 0, 1, "NV_BASIC" . chr(0) . "GetMapInfo" . chr(0x0A), 0) .
			pack("v2 x2 v3 a24 C1", 24, 4, 1, 10, 10, "AL_RUWACH", 0) . # self skill test
			pack("v2 x2 v3 a24 C1", 25, 2, 1, 10, 9, "AL_PNEUMA", 0) . # location skill test
			pack("v2 x2 v3 a24 C1", 26, 4, 2, 9, 1, "AL_TELEPORT", 0) . # self skill test
			pack("v2 x2 v3 a24 C1", 27, 2, 4, 26, 9, "AL_WARP", 0) . # location skill test
			pack("v2 x2 v3 a24 C1", 28, 16, 10, 40, 9, "AL_HEAL", 0); # target skill test
	}
	$client->send($data);
}

1;
