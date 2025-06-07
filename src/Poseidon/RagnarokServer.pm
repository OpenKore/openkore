###########################################################
# Poseidon server - Ragnarok Online server emulator
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Copyright (c) 2005-2025 OpenKore Development Team
###########################################################
# This class emulates a Ragnarok Online server.
# The RO client connects to this server. This server
# periodically sends a GameGuard query to the RO client,
# and saves the RO client's response.
###########################################################

# TODO:
# 1) make use of unpack strings to pack our packets depending on serverType
# 2) make plugin like connection algorithms for each serverType or 1 main algo on which serverTypes have hooks

package Poseidon::RagnarokServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use Misc;
use Utils qw(binSize getCoordString timeOut getHex getTickCount);
use Utils::DataStructures qw(existsInList);
use Poseidon::Config;
use FileParsers;
use Math::BigInt;
use Log qw(message);
use I18N qw(bytesToString stringToBytes);

my $clientdata;

# Decryption Keys
my $enc_val1 = 0;
my $enc_val2 = 0;
my $enc_val3 = 0;
my $state    = 0;

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

	# added serverTypes support
	if (-e 'ServerTypes.txt') {
		parseSectionedFile('ServerTypes.txt', \%{$self->{type}});
	} else {
		parseSectionedFile('src/Poseidon/ServerTypes.txt', \%{$self->{type}});
	}

	if (!$self->{type}->{$config{serverType}}) {
		die "Invalid serverType specified. Please check your poseidon config file.\n";
	} else {
		print "Building Poseidon RO Server with serverType $config{serverType} ...\n";
	}

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
			if ($clients->[$i]{connectedToMap}) {
                		$clients->[$i]->send($packet);
                		$self->{state} = 'requesting';
                		return;
			}
		}
	}

	print "[Poseinon RO server] Error: no Ragnarok Online client connected.\n";
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

	if ( $state == 0 ) {
		# Initialize Decryption
		$enc_val1 = 0;
		$enc_val2 = 0;
		$enc_val3 = 0;
	} else { $state = 0; }

	$self->{challengeNum} = 0;

	print "[Poseinon RO server] <- RO client ($index) connected.\n";
}

sub onClientExit {
	my ($self, $client, $index) = @_;

	$self->{challengeNum} = 0;

	print "[Poseinon RO server] -> RO client ($index) disconnected.\n";
}

## constants
my $accountID = pack("V", "2000001");
my $posX = 53;
my $posY = 113;

## Globals
my $charID = pack("V", "100001");
my $sessionID = pack("V", "3000000000");
my $sessionID2 = pack("V", 0xFF);
my $npcID0 = pack("V", "110000002");
my $npcID1 = pack("V", "110000001");
my $monsterID = pack("V", "110000003");
my $itemID = pack("V", "50001");
my $developMode = 0;

sub DecryptMessageID {
	my ($MID) = @_;

	# Checking if Decryption is Activated
	if ($enc_val1 != 0 && $enc_val2 != 0 && $enc_val3 != 0) {
		# Saving Last Informations for Debug Log
		my $oldMID = $MID;
		my $oldKey = ($enc_val1 >> 16) & 0x7FFF;

		# Calculating the Next Decryption Key
		$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;

		# Xoring the Message ID [657BE2h] [0x6E0A]
		$MID = ($MID ^ (($enc_val1 >> 16) & 0x7FFF));

		# Debug Log
		printf("Decrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $MID, $oldKey, ($enc_val1 >> 16) & 0x7FFF) if ($config{debug});
	}

	return $MID;
}

sub onClientData {
	my ($self, $client, $msg, $index) = @_;

	my $packet_id = DecryptMessageID(unpack("v",$msg));
	my $switch = sprintf("%04X", $packet_id);

	# Parsing Packet
	ParsePacket($self, $client, $msg, $index, $packet_id, $switch);
}

sub SendData {
	my ($client, $data) = @_;

	if($config{debug}) {
		my $packet_id = unpack("v", $data);
		my $switch = sprintf("%04X", $packet_id);

		unless (existsInList($config{debugPacket_exclude}, $switch)) {
			print "\nSent packet $switch:\n";
			visualDump($data, "$switch");
		}
	}

	$client->send($data);
}

sub ParsePacket {
	my ($self, $client, $msg, $index, $packet_id, $switch) = @_;

	#my $packed_switch = quotemeta substr($msg, 0, 2);
	my $packed_switch = $packet_id;

	### These variables control the account information ###
	my $host = $self->getHost();
	my $port = pack("v", $self->getPort());
	$host = '127.0.0.1' if ($host eq 'localhost');
	my @ipElements = split /\./, $host;

	if ($config{debug} and !existsInList($config{debugPacket_exclude}, $switch)) {
		print "\nReceived packet $switch:\n";
		visualDump($msg, "$switch");
	}

	# Note:
	# The switch packets are pRO specific and assumes the use of secureLogin 1. It may or may not work with other
	# countries' clients (except probably oRO). The best way to support other clients would be: use a barebones
	# eAthena or Freya as the emulator, or figure out the correct packet switches and include them in the
	# if..elsif..else blocks.
	# still used in idRO 2021-07-15
	if ($switch eq '01DB' || $switch eq '0204') { # Secure Login

		# '01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		my $data = pack("v2", 0x01DC, 0x14) . pack("x17");
		SendData($client, $data);

		# save servers.txt info
		my $code = substr($msg, 2);
		if (length($msg) == 2) {
			$clientdata->{$index}{secureLogin_type} = 0;
		} elsif (length($msg) == 20) {
			if ($code eq pack("C*", 0x04, 0x02, 0x7B, 0x8A, 0xA8, 0x90, 0x2F, 0xD8, 0xE8, 0x30, 0xF8, 0xA5, 0x25, 0x7A, 0x0D, 0x3B, 0xCE, 0x52)) {
				$clientdata->{$index}{secureLogin_type} = 1;
			} elsif ($code eq pack("C*", 0x04, 0x02, 0x27, 0x6A, 0x2C, 0xCE, 0xAF, 0x88, 0x01, 0x87, 0xCB, 0xB1, 0xFC, 0xD5, 0x90, 0xC4, 0xED, 0xD2)) {
				$clientdata->{$index}{secureLogin_type} = 2;
			} elsif ($code eq pack("C*", 0x04, 0x02, 0x42, 0x00, 0xB0, 0xCA, 0x10, 0x49, 0x3D, 0x89, 0x49, 0x42, 0x82, 0x57, 0xB1, 0x68, 0x5B, 0x85)) {
				$clientdata->{$index}{secureLogin_type} = 3;
			} elsif ($code eq ("C*", 0x04, 0x02, 0x22, 0x37, 0xD7, 0xFC, 0x8E, 0x9B, 0x05, 0x79, 0x60, 0xAE, 0x02, 0x33, 0x6D, 0x0D, 0x82, 0xC6)) {
				$clientdata->{$index}{secureLogin_type} = 4;
			} elsif ($code eq pack("C*", 0x04, 0x02, 0xc7, 0x0A, 0x94, 0xC2, 0x7A, 0xCC, 0x38, 0x9A, 0x47, 0xF5, 0x54, 0x39, 0x7C, 0xA4, 0xD0, 0x39)) {
				$clientdata->{$index}{secureLogin_type} = 5;
			}
		} else {
			$clientdata->{$index}{secureLogin_requestCode} = getHex($code);
		}

	} elsif ($switch eq '0ACF') { # Token Request
			my $data;
			# send Token
			$data = pack("v", 0x0AE3) . # header
					pack("v", 0x2F) . # length
					pack("l", "0") . # login_type
					pack("Z20","S1000") . # flag
					pack("Z*", "OpenkoreClientToken"); # login_token
			SendData($client, $data);

	} elsif (($switch eq '0064') || ($switch eq '01DD') || ($switch eq '01FA') || ($switch eq '0277') || ($switch eq '027C') || ($switch eq '02B0') || ($switch eq '0825') || ($switch eq '0987') || ($switch eq '0A76') || ($switch eq '0AAC') || ($switch eq '0B04')) { # master_login
		# send account_server_info
		my $sex = 1;
		my $serverName = pack("a20", "Poseidon RO server"); # server name should be less than or equal to 20 characters
		my $serverUsers = pack("V", @{$self->clients()} - 1);

		my $data;
		if ($switch eq '01FA') { # Secure Master Login
			$data = pack("v", 0x0069) . # header
				pack("v", 0x53) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x30") . pack("C1", $sex) . pack("x4") .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .	$serverName . $serverUsers . pack("x2");
		} elsif ($switch eq '0AAC' || $self->{type}->{$config{serverType}}->{account_server_info} eq '0AC9') {
		$data = pack("v", 0x0AC9) . # header
				pack("v", 0xCF) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x4") . # lastloginip
				pack("a26", time) . # lastLoginTime
				pack("C1", $sex) . # accountSex
				pack("x6") . # unknown
				$serverName . # serverName
				$serverUsers . # users
				pack("C*", 0x80, 0x32) . # ??
				pack("a*", $host.":".$self->getPort()) . # ip:port
				pack("x114"); # fill with 00
		} elsif($switch eq '0B04' || $self->{type}->{$config{serverType}}->{account_server_info} eq '0B07') {
			$data = pack("v", 0x0B07) . # header
				pack("v", 0xCF) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x4") . # lastloginip
				pack("a26", time) . # lastLoginTime
				pack("C", $sex) . # accountSex
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .
				$serverName .
				$serverUsers .
				pack("x130");
		} elsif ($self->{type}->{$config{serverType}}->{account_server_info} eq '0B60') { # received twRO
			$serverUsers = pack("v", @{$self->clients()} - 1);
			$data = pack("v", 0x0B60) . # header
				pack("v", 0xE4) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x4") .  # lastloginip
				pack("a26", time) . # lastLoginTime
				pack("C", $sex) . # accountSex
				pack("x17") . # unknown
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .
				$serverName .
				pack("x2") . # state
				$serverUsers.
				pack("v", 0x6985) . # property
				pack("x128").# ip_port
				pack("x4"); # unknown
		} elsif ($switch eq '0825' || $self->{type}->{$config{serverType}}->{account_server_info} eq '0AC4') { # received kRO Zero Token
			$data = pack("v", 0x0AC4) . # header
				pack("v", 0xE0) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x4") . # lastloginip
				pack("a26", time) . # lastLoginTime
				pack("C1", $sex) . # accountSex
				pack("x17") . # unknown
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .
				$serverName .
				$serverUsers .
				pack("x130");
		} elsif($switch eq '0A76' || $self->{type}->{$config{serverType}}->{account_server_info} eq '0276') { # tRO
			$data = pack("v", 0x0276) . # header
				pack("v", 0x63) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x30") . pack("C1", $sex) .
				pack("x4") .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .	$serverName . pack("x2") . $serverUsers . pack("x6");
		} else {
			$data = pack("v", 0x0069) . # header
				pack("v", 0x4F) . # length
				$sessionID . $accountID . $sessionID2 .
				pack("x30") . pack("C1", $sex) .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .	$serverName . $serverUsers . pack("x2");
		}

		SendData($client, $data);

		# save servers.txt info
		$clientdata->{$index}{masterLogin_packet} = $switch;

		if (($switch eq '0064') || ($switch eq '01DD') || ($switch eq '0987') || ($switch eq '0AAC')) {
			# '0064' => ['master_login', 'V Z24 Z24 C', [qw(version username password master_version)]]
			# '01DD' => ['master_login', 'V Z24 a16 C', [qw(version username password_salted_md5 master_version)]],
			# '0987' => ['master_login', 'V Z24 a32 C', [qw(version username password_md5_hex master_version)]]
			# '0AAC' => ['master_login', 'V Z30 a32 C', [qw(version username password_hex master_version)]]
			$clientdata->{$index}{version} = unpack("V", substr($msg, 2, 4));
			$clientdata->{$index}{master_version} = unpack("C", substr($msg, length($msg) - 1, 1));
		} elsif ($switch eq '01FA') {
			# '01FA' => ['master_login', 'V Z24 a16 C C', [qw(version username password_salted_md5 master_version clientInfo)]],
			$clientdata->{$index}{version} = unpack("V", substr($msg, 2, 4));
			$clientdata->{$index}{master_version} = unpack("C", substr($msg, length($msg) - 2, 1));
		} elsif ($switch eq '0825') {
			# '0825' => ['token_login', 'v v x v Z24 a27 Z17 Z15 a*', [qw(len version master_version username password_rijndael mac ip token)]]
			$clientdata->{$index}{version} = unpack("v", substr($msg, 4, 2));
			$clientdata->{$index}{master_version} = unpack("v", substr($msg, 7, 2));
		} elsif ( ($switch eq '0A76') || ($switch eq '0B04') ) {
			# '0A76' => ['master_login', 'V Z40 a32 v', [qw(version username password_rijndael master_version)]]
			# '0B04' => ['master_login', 'V Z30 Z52 Z100 v', [qw(version username accessToken billingAccessToken master_version)]]
			$clientdata->{$index}{version} = unpack("V", substr($msg, 2, 4));
			$clientdata->{$index}{master_version} = unpack("v", substr($msg, length($msg) - 2, 2));
		} elsif ($switch eq '02B0') {
			# '02B0' => ['master_login', 'V Z24 a24 C Z16 Z14 C', [qw(version username password_rijndael master_version ip mac isGravityID)]],
			$clientdata->{$index}{version} = unpack("V", substr($msg, 2, 4));
			$clientdata->{$index}{master_version} = unpack("C", substr($msg, 53, 1));
		} else {
			# '0277' => ??
			# unknown packet, cant get version/master version, should we use defaults?
			$clientdata->{$index}{version} = 55;
			$clientdata->{$index}{master_version} = 1;
		}

		$clientdata->{$index}{masterLogin_packet} = $switch;

		if ($switch eq '01DD') {
			$clientdata->{$index}{secureLogin} = 1;
			undef $clientdata->{$index}{secureLogin_account};
		} elsif ($switch eq '01FA') {
			$clientdata->{$index}{secureLogin} = 3;
			$clientdata->{$index}{secureLogin_account} = unpack("C", substr($msg, 47, 1));
		} else {
			undef $clientdata->{$index}{secureLogin};
			undef $clientdata->{$index}{secureLogin_type};
			undef $clientdata->{$index}{secureLogin_account};
			undef $clientdata->{$index}{secureLogin_requestCode};
		}

	#	send characters_info
	} elsif (($switch eq '0065') || ($switch eq '0275') || ($msg =~ /^$packed_switch$accountID$sessionID$sessionID2\x0\x0.$/)) { # client sends server choice packet
		if ($self->{type}->{$config{serverType}}->{received_characters} eq '099D' || $self->{type}->{$config{serverType}}->{received_characters} eq '0B72') {
			my $data;
			$data = $accountID;
			SendData($client, $data);

			$data = pack("v2 C5", 0x082D, 0x1D, 0x02, 0x00, 0x00, 0x02, 0x02) .
				pack("x20");
			SendData($client, $data);

			$data = pack("v V", 0x09A0, 0x01);
			SendData($client, $data);

			return;
		}
		# Character List
		SendCharacterList($self, $client, $msg, $index);

		# save servers.txt info
		$clientdata->{$index}{gameLogin_packet} = $switch;

	} elsif ($switch eq '09A1') {
		SendCharacterList($self, $client, $msg, $index);

	} elsif ($switch eq '0066') { # client sends character choice packet

		# If Using Packet Encrypted Client
		if ( $self->{type}->{$config{serverType}}->{sendCryptKeys} ) {
			# Enable Decryption
			my @enc_values = split(/\s+/, $self->{type}->{$config{serverType}}->{sendCryptKeys});
			($enc_val1, $enc_val2, $enc_val3) = (Math::BigInt->new(@enc_values[0]), Math::BigInt->new(@enc_values[1]), Math::BigInt->new(@enc_values[2]));
		}

		# State
		$state = 1;

		$developMode = unpack('C1', substr($msg, 2, 1));

		if ($developMode) {
			print "You are using DEVELOPER mode!\n";
		} else {
			print "You are using NORMAL mode.\n";
		}

		if ($self->{type}->{$config{serverType}}->{received_character_ID_and_Map} eq '0AC5') {
			# '0AC5' => ['received_character_ID_and_Map', 'a4 Z16 a4 v a128', [qw(charID mapName mapIP mapPort mapUrl)]],
			my $mapName = pack("a16", "new_1-1.gat");
			my $data = pack("v", 0x0AC5) . $charID . $mapName .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) . $port .
				pack("x128"); # mapUrl
			SendData($client, $data);

		} else {
			# '0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
			my $mapName = pack("a16", "new_1-1.gat");
			my $data = pack("v", 0x0071) . $charID . $mapName .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) . $port;
			SendData($client, $data);
		}

	} elsif ($switch eq  $self->{type}->{$config{serverType}}->{map_login} &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 0;

	} elsif ($switch eq '0072' &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 0;

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 12, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 3;

	} elsif ($switch eq '00F5' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 4;

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 5;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 10, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 6;

	} elsif ($switch eq '0072' &&
		(length($msg) == 34) &&
		(substr($msg, 7, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 25, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 7;

	} elsif ($switch eq '009B' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 8;

	} elsif ($switch eq '009B' &&
		(length($msg) == 37) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 21, 4) eq $charID) &&
		(substr($msg, 28, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 9;

	} elsif ($switch eq '0072' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 10;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 11;

	} elsif ($switch eq '0094' &&
		(length($msg) == 30) &&
		(substr($msg, 12, 4) eq $accountID) &&
		(substr($msg, 2, 4) eq $charID) &&
		(substr($msg, 6, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = 12;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata->{$index}{serverType} = "1 or 2";

	} elsif (($switch eq '0436' || $switch eq '022D' || $switch eq $self->{type}->{$config{serverType}}->{map_login}) &&
		(length($msg) == 19 || length($msg) == 23) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet
		$clientdata->{$index}{serverType} = 0;

		SendMapLogin($self, $client, $msg, $index);

		$client->{connectedToMap} = 1;

	} elsif ($msg =~ /^$packed_switch/
		&& $msg =~ /$accountID/
		&& $msg =~ /$charID/
		&& $msg =~ /$sessionID/) { # client sends the maplogin packet (unknown)

		print "Received unsupported map login packet $switch.\n";
		visualDump($msg, "$switch") unless $config{debug};

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		undef $clientdata->{$index}{serverType};
		#$clientdata->{$index}{sendMapLogin} = $msg;

	} elsif ($switch eq '007D') { # client sends the map_loaded packet
		my $data;

		# Temporary Hack to Initialized Crypted Client
		if ( $self->{type}->{$config{serverType}}->{sendCryptKeys} ) {
			for ( my $i = 0 ; $i < 64 ; $i++ ) {
				$data = pack("C C", 0x70, 0x08);
				SendData($client, $data);

				# Forcedly Calculating the Next Decryption Key
				$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;
			}
		}
	} elsif (
		( ( ($switch eq '007E') || ($switch eq '035F') ) && (($clientdata->{$index}{serverType} == 0) || ($clientdata->{$index}{serverType} == 1) || ($clientdata->{$index}{serverType} == 2) || ($clientdata->{$index}{serverType} == 6) || ($clientdata->{$index}{serverType} == 7) || ($clientdata->{$index}{serverType} == 10) || ($clientdata->{$index}{serverType} == 11))) ||
		(($switch eq '0089') && (($clientdata->{$index}{serverType} == 3) || ($clientdata->{$index}{serverType} == 5) || ($clientdata->{$index}{serverType} == 8) || ($clientdata->{$index}{serverType} == 9))) ||
		(($switch eq '0116') && ($clientdata->{$index}{serverType} == 4)) ||
		(($switch eq '00A7') && ($clientdata->{$index}{serverType} == 12)) ||
		($switch eq '0360')
		) { # client sends sync packet
		my $data = pack("v", 0x007F) . pack("V", getTickCount);
		SendData($client, $data);

		### Check if packet 0228 got tangled up with the sync packet
		if (uc(unpack("H2", substr($msg, 7, 1))) . uc(unpack("H2", substr($msg, 6, 1))) eq '0228') {
			$self->{response} = pack("v", $packet_id) . substr($msg, 8, length($msg)-2);
			$self->{state} = 'requested';
		}

	} elsif ($switch eq '00B2') { # quit to character select screen

		SendGoToCharSelection($self, $client, $msg, $index);

		# Disable Decryption
		$enc_val1 = 0;
		$enc_val2 = 0;
		$enc_val3 = 0;

	} elsif ($switch eq '0187') { # accountid sync (what does this do anyway?)
		SendData($client, $msg);

	} elsif ($switch eq '018A') { # client sends quit packet

		SendQuitGame($self, $client, $msg, $index);
	} elsif ($switch eq '09D0' || $switch eq '0228') { # client sends game guard sync
		# Queue the response
		# Don't allow other packet's (like Sync) to get to RO server.
		my $length = unpack("v",substr($msg,2,2));
		if ($length > 0) {
			$self->{response} = pack("v", $packet_id) . substr($msg,2,$length);
		} else {
			$self->{response} = pack("v", $packet_id);
		};
		$self->{state} = 'requested';

	} elsif ($switch eq '02A7') { # client sends hShield response
		# Queue the response
		$self->{response} = $msg;
		$self->{state} = 'requested';

	} elsif ($switch eq '0258') { # client sent gameguard's challenge request
		# Reply with "gameguard_grant" instead of a 0227 packet. Normally, the server would
		# send a 0227 gameguard challenge to the client, then the client will send the
		# proper 0228 response. Only after that will the server send 0259 to allow the
		# client to continue the login sequence. Since this is just a fake server,
		# there is no need to go through all that and we can do a shortcut.
		my $data;
		if ($self->{challengeNum} == 0) {
			print "Received GameGuard sync request. Client allowed to login account server.\n";
			$data = pack("v C", 0x0259, 0x01);
			SendData($client, $data);
		} else {
			print "Received GameGuard sync request. Client allowed to login char/map server.\n";
			$data = pack("v C", 0x0259, 0x02);
			SendData($client, $data);
		}
		$self->{challengeNum}++;
	} else {
		if ($switch eq '0090' || ($msg =~ /\x90\x0($npcID1|$npcID0)/)) { # npc talk
			undef $clientdata->{$index}{npc_talk_code};
			if ($msg =~ /\x90\x0$npcID1/) {
				# Show the kafra image
				SendNpcImageShow($self, $client, $msg, $index, "kafra_04.bmp", 0x02);
				# Show the messages
				SendNPCTalk($self, $client, $msg, $index, $npcID1, "[Kafra]");
				SendNPCTalk($self, $client, $msg, $index, $npcID1, "Welcome to Kafra Corp. We will stay with you wherever you go.");
				SendNPCTalkContinue($self, $client, $msg, $index, $npcID1);
			} elsif (!$developMode) {
				SendNPCTalk($self, $client, $msg, $index, $npcID0, "[Hakore]");
				SendNPCTalk($self, $client, $msg, $index, $npcID0, "Hello! Poseidon server is ready. You can run OpenKore.");
				SendNpcTalkClose($self, $client, $msg, $index, $npcID0);
			} else {
				SendNPCTalk($self, $client, $msg, $index, $npcID0, "[Hakore]");
				SendNPCTalk($self, $client, $msg, $index, $npcID0, "Hello! I was examining your RO client's login packets while you were connecting to Poseidon.");
				SendNPCTalkContinue($self, $client, $msg, $index, $npcID0);
			}

		} elsif ($switch eq '00B8') { # npc talk response

			my $npcID = substr($msg, 2, 4);
			my $response = unpack("C1", substr($msg, 6, 1));
			if ($npcID eq $npcID0) {
				if ($response == 1) {
					# Check server info
					SendNPCTalk($self, $client, $msg, $index, $npcID, "[Hakore]");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "Your RO client uses the following server details:^2222DD");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "version: $clientdata->{$index}{version}");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "master_version: $clientdata->{$index}{master_version}");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin_requestCode: $clientdata->{$index}{secureLogin_requestCode}") if ($clientdata->{$index}{secureLogin_requestCode});
					SendNPCTalk($self, $client, $msg, $index, $npcID, "serverType: " . ((defined $clientdata->{$index}{serverType}) ? $clientdata->{$index}{serverType} : 'Unknown'));
					if ($clientdata->{$index}{secureLogin}) {
						SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin: $clientdata->{$index}{secureLogin}");
						if ($clientdata->{$index}{secureLogin_requestCode}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, $npcID, "secureLogin_requestCode: $clientdata->{$index}{secureLogin_requestCode}");
						} elsif (defined $clientdata->{$index}{secureLogin_type}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin_type: $clientdata->{$index}{secureLogin_type}");
						}
						SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin_account: $clientdata->{$index}{secureLogin_account}") if ($clientdata->{$index}{secureLogin_account});
					}
					SendNPCTalk($self, $client, $msg, $index, $npcID, "masterLogin_packet: $clientdata->{$index}{masterLogin_packet}") if ($clientdata->{$index}{masterLogin_packet});
					SendNPCTalk($self, $client, $msg, $index, $npcID, "gameLogin_packet: $clientdata->{$index}{gameLogin_packet}") if ($clientdata->{$index}{gameLogin_packet});
					SendNPCTalkContinue($self, $client, $msg, $index, $npcID);

					if (defined $clientdata->{$index}{serverType}) {
						$clientdata->{$index}{npc_talk_code} = 3;
					} else {
						$clientdata->{$index}{npc_talk_code} = 2.5;
					}

				} elsif ($response == 2) {
					# Use storage
					SendNPCTalk($self, $client, $msg, $index, $npcID, "[Hakore]");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "Thank you for the visit. Go and multiply!");
					SendNpcTalkClose($self, $client, $msg, $index, $npcID);
				}

			} elsif ($npcID eq $npcID1) {
				if ($response == 1) {
					# Use storage
					my $data;
					$data .= pack("C2 v1", 0xF0, 0x01, 40) .
						pack("v2 C2 v1 x10", 3, 501, 0, 1, 16) .
						pack("v2 C2 v1 x10", 4, 909, 3, 1, 144);
					$data .= pack("v3", 0xF2, 2, 300);
					SendNpcImageShow($self, $client, $msg, $index, "kafra_04.bmp", 0xFF);
					SendNpcTalkClose($self, $client, $msg, $index, $npcID);
					SendData($client, $data);

				} elsif ($response == 2) {
					# Use storage
					SendNPCTalk($self, $client, $msg, $index, $npcID, "[Kafra]");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "We Kafra Corp. always try to serve you the best.");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "Please come again.");
					SendNpcTalkClose($self, $client, $msg, $index, $npcID);
				}
			}

		} elsif ($switch eq '00B9') { # npc talk continue
			my $npcID = substr($msg, 2, 4);
			if ($npcID eq $npcID0) {
				if ($clientdata->{$index}{npc_talk_code} == 2) {
					# Show NPC response list
					SendNpcTalkResponses($self, $client, $msg, $index, $npcID, "Yes, please:No, thanks:");
					$clientdata->{$index}{npc_talk_code} = 3;

				} else {
					SendNPCTalk($self, $client, $msg, $index, $npcID, "[Hakore]");
					if (!$clientdata->{$index}{npc_talk_code}) {
						if (!defined $clientdata->{$index}{serverType}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "However, I regret that OpenKore may not currently support your server.");
						} elsif ($clientdata->{$index}{serverType} == 7 || $clientdata->{$index}{serverType} == 12) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "However, I regret that OpenKore does not yet fully support your server this time.");
						} else {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Based on my examination, I think OpenKore supports your server.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "I can tell you the possible server details you can use to make OpenKore to connect to your server.");
						}
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata->{$index}{npc_talk_code} = 1;

					} elsif ($clientdata->{$index}{npc_talk_code} == 1) {
						if ((!defined $clientdata->{$index}{serverType}) || ($clientdata->{$index}{serverType} == 7)) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Would you still like to hear the details?");
						} else {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Would you like to hear the details?");
						}
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata->{$index}{npc_talk_code} = 2;

					} elsif ($clientdata->{$index}{npc_talk_code} == 2.5) {
						if (!defined $clientdata->{$index}{serverType}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "As you can see, I can't find a matching serverType for your server.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Please make a trial-and-error using all available serverTypes, one of them might be able to work.");
						} elsif ($clientdata->{$index}{serverType} == 7 || $clientdata->{$index}{serverType} == 12) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Like I said, your server is not yet fully supported by OpenKore.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "You can login to the server and do most basic tasks, but you cannot attack, sit or stand, or use skills.");
						}
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata->{$index}{npc_talk_code} = 4;

					} elsif ($clientdata->{$index}{npc_talk_code} == 3) {
						SendNPCTalk($self, $client, $msg, $index, $npcID, "The values of ^2222DDip^000000 and ^2222DDport^000000 can be found on your client's (s)clientinfo.xml.");
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata->{$index}{npc_talk_code} = 4;

					} elsif ($clientdata->{$index}{npc_talk_code} == 4) {
						if (!defined $clientdata->{$index}{serverType}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "If none of the serverTypes work, please inform the developers about this so we can support your server in future releases of OpenKore.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Please visit ^2222DDhttps://forums.openkore.com/^000000");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Thank you.");
						} else {
							if (($clientdata->{$index}{serverType} == 7)
								|| ($clientdata->{$index}{serverType} == 8)
								|| ($clientdata->{$index}{serverType} == 9)
								|| ($clientdata->{$index}{serverType} == 10)
								|| ($clientdata->{$index}{serverType} == 11)
								|| ($clientdata->{$index}{serverType} == 12)
								|| ($clientdata->{$index}{masterLogin_packet})
								|| ($clientdata->{$index}{gameLogin_packet})
							) {
								SendNPCTalk($self, $client, $msg, $index, $npcID, "Please note that you can only connect to your server using OpenKore GIT.");
							} else {
								SendNPCTalk($self, $client, $msg, $index, $npcID, "OpenKore v.1.6.6 or later will work on your server.");
							}
							SendNPCTalk($self, $client, $msg, $index, $npcID, "For more info, please visit ^2222DDhttps://openkore.com/^000000");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Good luck!");
						}
						SendNpcTalkClose($self, $client, $msg, $index, $npcID);
					}
				}

			} elsif ($npcID eq $npcID1) {
				# Show kafra response list
				SendNpcTalkResponses($self, $client, $msg, $index, $npcID, "Use Storage:Cancel:");
			}

		} elsif ($switch eq '0146') { # talk cancel
			my $npcID = substr($msg, 2, 4);
			if ($npcID eq $npcID1) {
				SendNpcImageShow($self, $client, $msg, $index, "kafra_04.bmp", 0xFF);
			}

		} elsif ($switch eq '0B1C') { # pong packet (keep-alive)
			SendData($client, pack("v", 0x0B1D));
		} elsif ($switch eq '01C0') { # Remaining time??
			# SendData($client, pack("v V3", 0x01C0, 0xFF, 0xFF, 0xFF));
		} elsif ($developMode) {

			if (($switch eq '00F7' || $switch eq '0193') && (length($msg) == 2)) { # storage close
				my $data = pack("v1", 0xF8);
				SendData($client, $data);

			} elsif ($switch eq '00BF') { # emoticon
				my ($client, $code) = @_;
				my $data = pack("v1 a4", 0xC0, $accountID) . substr($msg, 2, 1);
				$clientdata->{$index}{emoticonTime} = time;
				SendData($client, $data);

			} else {
				unless ($config{debug}) {
					print "\nReceived packet $switch:\n";
					visualDump($msg, "$switch");
				}

				# Just provide feedback in the RO Client about the unhandled packet
				# '008E' => ['self_chat', 'x2 Z*', [qw(message)]],
				my $data = pack("v2 a31", 0x008E, 35, "Sent packet $switch (" . length($msg) . " bytes).");
				if (timeOut($clientdata->{$index}{emoticonTime}, 1.8)) {
					$clientdata->{$index}{emoticonTime} = time;
					$data .= pack("v a4 C", 0x00C0, $accountID, 1);
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
					$data .= pack("v a4 a24", 0x0095, $npcID0, "Server Details Guide");
				} elsif ($ID eq $npcID1) {
					$data .= pack("v a4 a24", 0x0095, $npcID1, "Kafra");
				}

				SendData($client, $data);
			}
		}
	}
}

# PACKET SENDING S->C

sub SendCharacterList {
	my ($self, $client, $msg, $index) = @_;

	# Log
	print "Requested Char List (Standard)\n";

	# Wanted Block Size
	my $blocksize = $self->{type}->{$config{serverType}}->{charBlockSize} || 116; #defaults to 116

	# Packet Len, Total Characters and Total Slots
	my $totalchars = 2;
	my $totalslots = 12;
	my $len = $blocksize * $totalchars;

	# Character Block Pack String
	my $packstring = '';
	$packstring = 'a4 V2 V V2 V6 v V2 V2 V2 V2 v2 V v9 Z24 C8 v Z16 V4 C' if $blocksize == 175;
	$packstring = 'a4 Z8 V Z8 V6 v V2 v4 V v9 Z24 C8 v Z16 V4 C' if $blocksize == 155;
	$packstring = 'a4 V9 v V2 v4 V v9 Z24 C8 v Z16 V4 C' if $blocksize == 147;
	$packstring = 'a4 V9 v V2 v4 V v9 Z24 C8 v Z16 V4' if $blocksize == 146;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V4 C' if $blocksize == 145;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V4' if $blocksize == 144;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V3' if $blocksize == 140;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V2' if $blocksize == 136;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V' if $blocksize == 132;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16' if $blocksize == 128;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z12' if $blocksize == 124;
	$packstring = 'a4 V9 v V2 v14 Z24 C6 v2 x4' if $blocksize == 116;
	$packstring = 'a4 V9 v V2 v14 Z24 C6 v2' if $blocksize == 112;
	$packstring = 'a4 V9 v17 Z24 C6 v2' if $blocksize == 108;
	$packstring = 'a4 V9 v17 Z24 C6 v' if $blocksize == 106;

	# Unknown CharBlockSize
	if ( length($packstring) == 0 ) { print "Unknown CharBlockSize : $blocksize\n"; return; }

	# Character Block Format
	my($cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename,$robe,$slotAddon,$renameAddon) = 0;

	# Preparing Begin of Character List Packet
	my $data;
	if ($self->{type}->{$config{serverType}}->{received_characters} eq '082D') {
		$data = $accountID . pack("v2 C5 a20", 0x082d, $len + 29,$totalchars,0,0,0,$totalchars,-0); # 29 = v2 C5 a20 size for bRO
	} elsif ($self->{type}->{$config{serverType}}->{received_characters} eq '099D') {
		$data = pack("v", 0x099D) .
		pack("v", $len + 4);
	} elsif ($self->{type}->{$config{serverType}}->{received_characters} eq '0B72') {
		$data = pack("v", 0x0B72) .
		pack("v", $len + 4);
	} else {
		$data = $accountID . pack("v v C3", 0x006b, $len + 7, $totalslots, -1, -1);
	}

	# Character Block
	my $block;

	my $sex = 1;
	my $map = "new_1-1.gat";

	# Filling Character 1 Block
	$cID = $charID;	$hp = 10000; $maxHp = 10000; $sp = 10000; $maxSp = 10000; $hairstyle = 1; $level = 99; $headTop = 0; $hairColor = 6; $hairPallete = 0;
	$name = "Poseidon"; $str = 1; $agi = 1; $vit = 1; $int = 1; $dex = 1; $luk = 1;	$exp = 1; $zeny = 1; $jobExp = 1; $jobLevel = 50; $slot = 0; $rename = 0;

	# Preparing Character 1 Block
	if ($self->{type}->{$config{serverType}}->{received_characters} eq '0B72') {
		$block = pack($packstring,$cID,$exp,0,$zeny,$jobExp,0,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,0,$maxHp,0,$sp,0,$maxSp,0,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$clothesColor,stringToBytes($name),$str,$agi,$vit,$int,$dex,$luk,$slot,$hairColor,$rename,$map,"",$robe,$slotAddon,$renameAddon,$sex);
	} elsif ($self->{type}->{$config{serverType}}->{received_characters} eq '099D') {
		$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$clothesColor,stringToBytes($name),$str,$agi,$vit,$int,$dex,$luk,$slot,$hairColor,$rename,$map,"",$robe,$slotAddon,$renameAddon,$sex);
	} else {
		$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$hairColor,$rename);
	}

	# Attaching Block
	$data .= $block;

	# Filling Character 2 Block
	$cID = $charID;	$hp = 10000; $maxHp = 10000; $sp = 10000; $maxSp = 10000; $hairstyle = 1; $level = 99; $headTop = 0; $hairColor = 6;
	$name = "Poseidon Dev"; $str = 1; $agi = 1; $vit = 1; $int = 1; $dex = 1; $luk = 1;	$exp = 1; $zeny = 1; $jobExp = 1; $jobLevel = 50; $slot = 1; $rename = 0;

	# Preparing Character 2 Block
	if ($self->{type}->{$config{serverType}}->{received_characters} eq '0B72') {
		$block = pack($packstring,$cID,$exp,0,$zeny,$jobExp,0,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,0,$maxHp,0,$sp,0,$maxSp,0,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$clothesColor,stringToBytes($name),$str,$agi,$vit,$int,$dex,$luk,$slot,$hairColor,$rename,$map,"",$robe,$slotAddon,$renameAddon,$sex);
	} elsif ($self->{type}->{$config{serverType}}->{received_characters} eq '099D') {
		$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$clothesColor,stringToBytes($name),$str,$agi,$vit,$int,$dex,$luk,$slot,$hairColor,$rename,$map,"",$robe,$slotAddon,$renameAddon,$sex);
	} else {
		$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairPallete,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$hairColor,$rename);
	}

	# Attaching Block
	$data .= $block;

	# Measuring Size of Block
	print "Wanted CharBlockSize : $blocksize\n";
	print "Packstring size: ".length(pack($packstring))."\n";
	print "Built CharBlockSize : " . length($block) . "\n";
	SendData($client, $data);
}

sub SendMapLogin {
	my ($self, $client, $msg, $index) = @_;

	SendData($client, pack("v a4", 0x0283, $accountID));

	if ( $config{serverType} =~ /^kRO/ ) { # kRO
		SendData($client, pack("v", 0x0ADE) . pack("V", 0x00));
	}

	# mapLogin packet
	if ($self->{type}->{$config{serverType}}->{map_loaded} eq '0A18') {
		# '0A18' => ['map_loaded', 'V a3 C2 v C', [qw(syncMapSync coords xSize ySize font sex)]], # 14
		SendData($client, pack("v", 0x0A18) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x00, 0x00) .  pack("C*", 0x00, 0x00, 0x01));
	} elsif ($self->{type}->{$config{serverType}}->{map_loaded} eq '02EB') {
		# '02EB' => ['map_loaded', 'V a3 a a v', [qw(syncMapSync coords xSize ySize font)]], # 13
		SendData($client, pack("v", 0x02EB) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x00, 0x00) .  pack("C*", 0x00, 0x00));
	} else {
		# '0073' => ['map_loaded','x4 a3',[qw(coords)]]
		SendData($client, pack("v", 0x0073) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x00, 0x00));
	}

	my $data;
	if ($developMode) {
		if ($self->{type}->{$config{serverType}}->{map_loaded} eq '0B32') {
			$data = pack("v", 0x0B32) .
				pack("v", 94) . # len
				# skillID targetType level sp range upgradable lvl2
				pack("v V v3 C v", 1, 0, 9, 0, 1, 0, 0) .
				pack("v V v3 C v", 24, 4, 1, 10, 10, 0, 0) . # self skill test
				pack("v V v3 C v", 25, 2, 1, 10, 9, 0, 0) .  # location skill test
				pack("v V v3 C v", 26, 4, 2, 9, 1, 0, 0) .   # self skill test
				pack("v V v3 C v", 27, 2, 4, 26, 9, 0, 0) .  # location skill test
				pack("v V v3 C v", 28, 16, 10, 40, 9, 0, 0); # target skill test
				SendData($client, $data);
		} else {
			$data = pack("v", 0x010F) .
				pack("v", 226) . # len
				# skillID targetType level sp range skillName upgradable
				pack("v2 x2 v3 a24 C", 1, 0, 9, 0, 1, "NV_BASIC" . chr(0) . "GetMapInfo" . chr(0x0A), 0) .
				pack("v2 x2 v3 a24 C", 24, 4, 1, 10, 10, "AL_RUWACH", 0) . # self skill test
				pack("v2 x2 v3 a24 C", 25, 2, 1, 10, 9, "AL_PNEUMA", 0) .  # location skill test
				pack("v2 x2 v3 a24 C", 26, 4, 2, 9, 1, "AL_TELEPORT", 0) . # self skill test
				pack("v2 x2 v3 a24 C", 27, 2, 4, 26, 9, "AL_WARP", 0) .    # location skill test
				pack("v2 x2 v3 a24 C", 28, 16, 10, 40, 9, "AL_HEAL", 0);   # target skill test
				SendData($client, $data);
		}
	}

	# '013A' => ['attack_range', 'v', [qw(type)]],
	SendData($client, pack("v2", , 0x013A, 1));

	# '00BD' => ['stats_info', 'v C12 v14', [qw(points_free str points_str agi points_agi vit points_vit int points_int dex points_dex luk points_luk attack attack_bonus attack_magic_min attack_magic_max def def_bonus def_magic def_magic_bonus hit flee flee_bonus critical stance manner)]], # (stance manner) actually are (ASPD plusASPD)
	SendData($client, pack("v2 C12 v14", 0x00BD, 100, 99, 11, 99, 11, 99, 11, 99, 11, 99, 11, 99, 11, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 999, 100, 190, 3));

	if ($self->{type}->{$config{serverType}}->{send_load_confirm} == 1) {
		SendData($client, pack("v", 0x0B1B)); # load_confirm (unlock keyboard)
	}

	$client->{connectedToMap} = 1;

	# TODO: fixme, this should be made only after 007D, but for some reason some clients are not sending this packet
	PerformMapLoadedTasks($self, $client, $msg, $index);
}

sub SendGoToCharSelection {
	my ($self, $client, $msg, $index) = @_;

	# Log
	print "Requested Char Selection Screen\n";

	SendData($client, pack("v v", 0x00B3, 1));
}

sub SendQuitGame {
	my ($self, $client, $msg, $index) = @_;

	# Log
	print "Requested Quit Game...\n";

	SendData($client, pack("v v", 0x018B, 0));
}

sub SendLookTo {
	my ($self, $client, $msg, $index, $ID, $to) = @_;

	# Make Poseidon look to front
	SendData($client, pack('v1 a4 C1 x1 C1', 0x009C, $ID, 0, $to));
}

sub SendUnitInfo {
	my ($self, $client, $msg, $index, $ID, $name, $partyName, $guildName, $guildTitle, $titleID) = @_;

	# Let's not wait for the client to ask for the unit info
	if ($self->{type}->{$config{serverType}}->{actor_info} eq '0A30') {
		# '0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24 V', [qw(ID name partyName guildName guildTitle titleID)]],
		SendData($client, pack("v a4 Z24 Z24 Z24 Z24 V", 0x0A30, $ID, $name, $partyName, $guildName, $guildTitle, $titleID));
	} else {
		# '0195' => ['actor_info', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]],
		SendData($client, pack("v1 a4 Z24 Z24 Z24 Z24", 0x0195, $ID, $name, $partyName, $guildName, $guildTitle));
	}
}

sub SendUnitName {
	my ($self, $client, $msg, $index, $ID, $name, $charID, $prefix_name) = @_;

	if ($self->{type}->{$config{serverType}}->{actor_name} eq '0ADF') {
		# '0ADF' => ['actor_info', 'a4 a4 Z24 Z24', [qw(ID charID name prefix_name)]],
		SendData($client, pack("v1 a4 a24", 0x0ADF, $ID, $charID, $name, $prefix_name));
	} else {
		# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
		SendData($client, pack("v1 a4 a24", 0x0095, $ID, $name));
	}
}

sub SendSystemChatMessage {
	my ($self, $client, $msg, $index, $message) = @_;

	# '009A' => ['system_chat', 'v Z*', [qw(len message)]],
	SendData($client, pack("v2 a32", 0x009A, 36, $message));
}

sub SendShowNPC {
	my ($self, $client, $msg, $index, $obj_type, $GID, $SpriteID, $X, $Y, $MobName) = @_;

	# Packet Structure
	my ($object_type,$NPCID,$AID,$walk_speed,$opt1,$opt2,$option,$type,$hair_style,$weapon,$lowhead,$shield,$tophead,$midhead,$hair_color,$clothes_color,$head_dir,$guildID,$emblemID,$manner,$opt3,$stance,$sex,$xSize,$ySize,$lv,$font,$name,$costume,$opt4,$state) = 0;

	# Building NPC Data
	$object_type = $obj_type;
	$NPCID = $AID = $GID;
	$walk_speed = 0x1BD;
	$type = $SpriteID;
	$lv = 1;
	$name = $MobName;
	my $data;
	if ($self->{type}->{$config{serverType}}->{actor_exists} eq '0078') {
		$data = pack("v a4 v14 a4 a2 v2 C2 a3 C3 v", 0x0078, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv);
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '01D8') {
		$data = pack("v a4 v14 a4 a2 v2 C2 a3 C3 v", 0x01D8, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv);
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '022A') {
		$data = pack("v a4 v3 V v10 a4 a2 v V C2 a3 C3 v", 0x022A, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv);
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '02EE') {
		$data = pack("v a4 v3 V v10 a4 a2 v V C2 a3 C3 v2", 0x02EE, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv, $font);
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '07F9') {
		my $len = length(pack("v2 C a4 v3 V v10 a4 a2 v V C2 a3 C3 v2")) + length(stringToBytes($name));
		$data = pack("v2 C a4 v3 V v10 a4 a2 v V C2 a3 C3 v2 a*", 0x07F9, $len, $object_type, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv, $font, stringToBytes($name));
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '0857') {
		my $len = length(pack("v2 C a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2")) + length(stringToBytes($name));
		$data = pack("v2 C a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 a*", 0x0857, $len, $object_type, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $costume, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv, $font, stringToBytes($name));
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '0915') {
		my $len = length(pack("v2 C a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C")) + length(stringToBytes($name));
		$data = pack("v2 C a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C a*", 0x0915, $len, $object_type, $NPCID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $costume, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv, $font, 0xFFFFFFFF, 0xFFFFFFFF, 0, stringToBytes($name));
	} elsif ($self->{type}->{$config{serverType}}->{actor_exists} eq '09DD') {
		my $len = length(pack("v2 C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C")) + length(stringToBytes($name));
		$data = pack("v2 C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C a*", 0x09DD, $len, $object_type, $NPCID, $AID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $costume, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv, $font, 0xFFFFFFFF, 0xFFFFFFFF, 0, stringToBytes($name));
	} else {
		my $len = length(pack("v2 C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v")) + length(stringToBytes($name));
		$data = pack("v2 C a4 a4 v3 V v2 V2 v7 a4 a2 v V C2 a3 C3 v2 V2 C v a*", 0x09FF, $len, $object_type, $NPCID, $AID, $walk_speed, $opt1, $opt2, $option, $type, $hair_style, $weapon, $shield, $lowhead, $tophead, $midhead, $hair_color, $clothes_color, $head_dir, $costume, $guildID, $emblemID, $manner, $opt3, $stance, $sex, getCoordString($X, $Y, 1), $xSize, $ySize, $state, $lv, $font, 0xFFFFFFFF, 0xFFFFFFFF, 0, $opt4, stringToBytes($name));
	}

	SendData($client, $data);
}

sub SendShowItemOnGround {
	my ($self, $client, $msg, $index, $ID, $SpriteID, $X, $Y) = @_;

	if ($self->{type}->{$config{serverType}}->{expandedItemID} eq '1') {
		SendData($client, pack("v a4 V C v3 C2", 0x009D, $ID, $SpriteID, 1, $posX + 1, $posY - 1, 1, 0, 0));
	} else {
		SendData($client, pack("v a4 v C v3 C2", 0x009D, $ID, $SpriteID, 1, $posX + 1, $posY - 1, 1, 0, 0));
	}
}

sub SendNPCTalk {
	my ($self, $client, $msg, $index, $npcID, $message) = @_;

	# '00B4' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]]
	my $dbuf = pack("a" . length($message), $message);
	SendData($client, pack("v2 a4", 0x00B4, (length($dbuf) + 8), $npcID) . $dbuf);
}

sub SendNPCTalkContinue {
	my ($self, $client, $msg, $index, $npcID) = @_;

	# '00B5' => ['npc_talk_continue', 'a4', [qw(ID)]]
	SendData($client, pack("v a4", 0x00B5, $npcID));
}

sub SendNpcTalkClose {
	my ($self, $client, $msg, $index, $npcID) = @_;

	# '00B6' => ['npc_talk_close', 'a4', [qw(ID)]]
	SendData($client, pack("v a4", 0x00B6, $npcID));
}

sub SendNpcTalkResponses {
	my ($self, $client, $msg, $index, $npcID, $message) = @_;

	# '00B7' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]]
	my $dbuf = pack("a" . length($message), $message);
	SendData($client, pack("v2 a4", 0x00B7, (length($dbuf) + 8), $npcID) . $dbuf);
}

sub SendNpcImageShow {
	my ($self, $client, $msg, $index, $image, $type) = @_;

	# Type = 0xFF = Hide Image
	# Type = 0x02 = Show Image
	# '01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]]
	SendData($client, pack("v a64 C1", 0x01B3, $image, $type));
}

# SERVER TASKS

sub PerformMapLoadedTasks {
	my ($self, $client, $msg, $index) = @_;

	# Looking to Front
	SendLookTo($self, $client, $msg, $index, $accountID, 4);

	# Let's not wait for the client to ask for the unit info
	SendUnitInfo($self, $client, $msg, $index, $accountID, 'Poseidon' . (($developMode ? ' Dev' : '')));

	# Global Announce
	SendSystemChatMessage($self, $client, $msg, $index, "Welcome to the Poseidon Server !");

	# Show an NPC
	SendShowNPC($self, $client, $msg, $index, 1, $npcID0, 86, $posX + 3, $posY + 4, "Server Details Guide");
	SendLookTo($self, $client, $msg, $index, $npcID0, 3);
	SendUnitInfo($self, $client, $msg, $index, $npcID0, "Server Details Guide");

	# Dev Mode (Char Slot 1)
	if ($developMode) {
		# Show an NPC (Kafra)
		SendShowNPC($self, $client, $msg, $index, 1, $npcID1, 114, $posX + 5, $posY + 3, "Kafra NPC");
		SendLookTo($self, $client, $msg, $index, $npcID1, 4);
		SendUnitInfo($self, $client, $msg, $index, $npcID1, "Kafra NPC");

		# Show a monster
		SendShowNPC($self, $client, $msg, $index, 5, $monsterID, 1002, $posX - 2, $posY - 1, "Poring");
		SendLookTo($self, $client, $msg, $index, $monsterID, 3);
		SendUnitInfo($self, $client, $msg, $index, $monsterID, "Poring");

		# Show an item on ground
		SendShowItemOnGround($self, $client, $msg, $index, $itemID, 512, $posX + 1, $posY - 1);

		# Show an item in inventory
		if ($self->{type}->{$config{serverType}}->{items_stackable_type} eq '7') {
			SendShowItemInInventory($self, $client, $msg);
		}
	}
}

sub SendShowItemInInventory {
	my ($self, $client, $msg) = @_;

	# Send item_list_start
	SendData($client, pack("v2 C", 0x0B08, 5, ''));

	# Send item_list_stackable
	# itemInfo
	my $data = 	pack("v", 0x0B09) .
				pack("v", 73) . # len
				pack("C", 0) .  # type
				# type7: len = 34
				# a2 V C v V a16 l C
				# ID nameID type amount type_equip cards expire identified
				pack("a2 V C v V a16 l C", 0, 501, 0, 10, 0, '', '', 1). # 10x Red Potion
				pack("a2 V C v V a16 l C", 1, 909, 3, 10, 0, '', '', 1); # 10x Jellopy
	SendData($client, $data);

	if ($self->{type}->{$config{serverType}}->{items_nonstackable_type} eq '8') {
		# Send item_list_nonstackable
		# itemInfo
		$data = pack("v", 0x0B0A) .
				pack("v", 72) . # len
				pack("C", 0) .  # type
				# type8: len = 67
				# a2 V      C    V2                  C       a16   l      v2                        C           a25     C
				# ID nameID type type_equip equipped upgrade cards expire bindOnEquipType sprite_id num_options options identified
				pack("a2 V C V2 C a16 l v2 C a25 C", 2, 1243, 5, 2, 0, 5, '', 0, 0, 0, 0, '', 1); # +5 Novice Knife
		SendData($client, $data);
	}

	# Send item_list_end
	SendData($client, pack("v C2", 0x0B0B, 0, 0));
}

1;

# 0064 packet thanks to abt123
# 0204 packet thanks to elhazard
# queue the response (thanks abt123)
