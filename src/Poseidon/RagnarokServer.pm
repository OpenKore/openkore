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

# TODO:
# 1) make use of unpack strings to pack our packets depending on serverType
# 2) make plugin like connection algorithms for each serverType or 1 main algo on which serverTypes have hooks

package Poseidon::RagnarokServer;

use strict;
use Base::Server;
use base qw(Base::Server);
use Misc;
use Utils qw(binSize getCoordString timeOut getHex getTickCount);
use Poseidon::Config;
use FileParsers;
use Math::BigInt;

my %clientdata;

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
	
	# added servertypes support
	if (-e 'servertypes.txt') {
		parseSectionedFile('servertypes.txt', \%{$self->{type}});
	} else {
		parseSectionedFile('src/Poseidon/servertypes.txt', \%{$self->{type}});
	}
	
	if (!$self->{type}->{$config{server_type}}) {
		die "Invalid serverType specified. Please check your poseidon config file.\n";
	} else {
		print "Building RagnarokServer with serverType $config{server_type}...\n";
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
sub query 
{
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
	
	print "[RagnarokServer]-> Error: no Ragnarok Online client connected.\n";
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

sub onClientNew 
{
	my ($self, $client, $index) = @_;

	if ( $state == 0 )
	{
		# Initialize Decryption
		$enc_val1 = 0;
		$enc_val2 = 0;
		$enc_val3 = 0;
	} else { $state = 0; }
	
	$self->{challengeNum} = 0;
	
	print "[RagnarokServer]-> Ragnarok Online client ($index) connected.\n";	
}

sub onClientExit 
{
	my ($self, $client, $index) = @_;
	
	$self->{challengeNum} = 0;
	
	print "[RagnarokServer]-> Ragnarok Online client ($index) disconnected.\n";
}

## constants
my $accountID = pack("a4", "acct");
my $posX = 53;
my $posY = 113;

## Globals
my $charID = pack("a4", "char");
my $sessionID = pack("a4", "sess");
my $sessionID2 = pack("C4", 0xff);
my $npcID1 = pack("a4", "npc1");
my $npcID0 = pack("a4", "npc2");
my $monsterID = pack("a4", "mon1");
my $itemID = pack("a4", "itm1");

sub DecryptMessageID 
{
	my ($MID) = @_;
	
	# Checking if Decryption is Activated
	if ($enc_val1 != 0 && $enc_val2 != 0 && $enc_val3 != 0) 
	{
		# Saving Last Informations for Debug Log
		my $oldMID = $MID;
		my $oldKey = ($enc_val1 >> 16) & 0x7FFF;
		
		# Calculating the Next Decryption Key
		$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;
	
		# Xoring the Message ID [657BE2h] [0x6E0A]
		$MID = ($MID ^ (($enc_val1 >> 16) & 0x7FFF));

		# Debug Log
		# print sprintf("Decrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $MID, $oldKey, ($enc_val1 >> 16) & 0x7FFF);
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

sub ParsePacket
{
	my ($self, $client, $msg, $index, $packet_id, $switch) = @_;

	#my $packed_switch = quotemeta substr($msg, 0, 2);
	my $packed_switch = $packet_id;
	
	### These variables control the account information ###
	my $host = $self->getHost();
	my $port = pack("v", $self->getPort());
	$host = '127.0.0.1' if ($host eq 'localhost');
	my @ipElements = split /\./, $host;
	
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

	} elsif (($switch eq '01DD') || ($switch eq '01FA') || ($switch eq '0064') || ($switch eq '0060') || ($switch eq '0277') || ($switch eq '02B0')) { # 0064 packet thanks to abt123

#		my $data = pack("C*", 0xAD, 0x02, 0x00, 0x00, 0x1E, 0x0A, 0x00, 0x00);
#		$client->send($data);
		my $sex = 1;
		my $serverName = pack("a20", "Poseidon server"); # server name should be less than or equal to 20 characters
		my $serverUsers = pack("V", @{$self->clients()} - 1);
		# '0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*',
		# 			[qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		my $data;
		if ($switch eq '01FA') {
			$data = pack("C*", 0x69, 0x00, 0x53, 0x00) . 
				$sessionID . $accountID . $sessionID2 . 
				pack("x30") . pack("C1", $sex) . pack("x4") .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .	$serverName . $serverUsers . pack("x2");
		} else {
			$data = pack("C*", 0x69, 0x00, 0x4F, 0x00) . 
				$sessionID . $accountID . $sessionID2 . 
				pack("x30") . pack("C1", $sex) .
				pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) .
				$port .	$serverName . $serverUsers . pack("x2");
		}

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

		if($switch eq '02B0') {	# kRO uses 02B2 as masterLogin packet when we have <langtype>0</langtype> in the clientinfo.xml
								# if other servers do use this packet too that will be a problem.
			$clientdata{$index}{kRO} = 1;
		}

	} elsif (($switch eq '0065') || ($switch eq '0275') || ($msg =~ /^$packed_switch$accountID$sessionID$sessionID2\x0\x0.$/)) { # client sends server choice packet

		# Character List
		SendCharacterList($self, $client, $msg, $index);

		# save servers.txt info
		if ($switch ne '0065') {
			$clientdata{$index}{gameLogin_packet} = $switch;
		} else {
			undef $clientdata{$index}{gameLogin_packet};
		}

	} elsif ($switch eq '0066') { # client sends character choice packet

		# If Using Packet Encrypted Client
		if ( $self->{type}->{$config{server_type}}->{decrypt_mid_keys} )
		{
			# Enable Decryption
			my @enc_values = split(/\s+/, $self->{type}->{$config{server_type}}->{decrypt_mid_keys});
			($enc_val1, $enc_val2, $enc_val3) = (Math::BigInt->new(@enc_values[0]), Math::BigInt->new(@enc_values[1]), Math::BigInt->new(@enc_values[2]));
		}
		
		# State
		$state = 1;

		$clientdata{$index}{mode} = unpack('C1', substr($msg, 2, 1));

		# '0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		my $mapName = pack("a16", "moc_prydb1.gat");
		my $data = pack("C*", 0x71, 0x00) . $charID . $mapName . 
			pack("C*", $ipElements[0], $ipElements[1], $ipElements[2], $ipElements[3]) . $port;
		
		$client->send($data);
		
	} elsif ($switch eq  $self->{type}->{$config{server_type}}->{maploginPacket} &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 0;

	} elsif ($switch eq '0072' &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 0;

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 12, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 3;

	} elsif ($switch eq '00F5' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 4;

	} elsif ($switch eq '009B' &&
		(length($msg) == 32) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 23, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 5;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 3, 4) eq $accountID) &&
		(substr($msg, 10, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 6;

	} elsif ($switch eq '0072' &&
		(length($msg) == 34) &&
		(substr($msg, 7, 4) eq $accountID) &&
		(substr($msg, 15, 4) eq $charID) &&
		(substr($msg, 25, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 7;

	} elsif ($switch eq '009B' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 8;

	} elsif ($switch eq '009B' &&
		(length($msg) == 37) &&
		(substr($msg, 9, 4) eq $accountID) &&
		(substr($msg, 21, 4) eq $charID) &&
		(substr($msg, 28, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 9;

	} elsif ($switch eq '0072' &&
		(length($msg) == 26) &&
		(substr($msg, 4, 4) eq $accountID) &&
		(substr($msg, 9, 4) eq $charID) &&
		(substr($msg, 17, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 10;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 11;

	} elsif ($switch eq '0094' &&
		(length($msg) == 30) &&
		(substr($msg, 12, 4) eq $accountID) &&
		(substr($msg, 2, 4) eq $charID) &&
		(substr($msg, 6, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = 12;

	} elsif ($switch eq '0072' &&
		(length($msg) == 29) &&
		(substr($msg, 5, 4) eq $accountID) &&
		(substr($msg, 14, 4) eq $charID) &&
		(substr($msg, 20, 4) eq $sessionID)
		) { # client sends the maplogin packet

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		$clientdata{$index}{serverType} = "1 or 2";

	} elsif (($switch eq '0436' || $switch eq '022D') &&
		(length($msg) == 19) &&
		(substr($msg, 2, 4) eq $accountID) &&
		(substr($msg, 6, 4) eq $charID) &&
		(substr($msg, 10, 4) eq $sessionID)
		) { # client sends the maplogin packet

		$client->send(pack("v a4", 0x0283, $accountID));
		# mapLogin packet
		$client->send(pack("v", 0x2EB) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x05, 0x05) .  pack("C*", 0x05, 0x05));
		$client->{connectedToMap} = 1;

	} elsif ($msg =~ /^$packed_switch/
		&& $msg =~ /$accountID/
		&& $msg =~ /$charID/
		&& $msg =~ /$sessionID/) { # client sends the maplogin packet (unknown)

		print "Received unsupported map login packet $switch.\n";
		visualDump($msg, "$switch");

		SendMapLogin($self, $client, $msg, $index);
		# save servers.txt info
		undef $clientdata{$index}{serverType};
		#$clientdata{$index}{sendMapLogin} = $msg;

	} elsif ($switch eq '007D') { # client sends the map loaded packet
		my $data;

		# Temporary Hack to Initialized Crypted Client
		if ( $self->{type}->{$config{server_type}}->{decrypt_mid_keys} )
		{
			for ( my $i = 0 ; $i < 64 ; $i++ ) 
			{
				$client->send(pack("C C", 0x70, 0x08));
				
				# Forcedly Calculating the Next Decryption Key
				$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;	
			}
		}		
		
		PerformMapLoadedTasks($self, $client, $msg, $index);
	} elsif (
		( ( ($switch eq '007E') || ($switch eq '035F') ) && (($clientdata{$index}{serverType} == 0) || ($clientdata{$index}{serverType} == 1) || ($clientdata{$index}{serverType} == 2) || ($clientdata{$index}{serverType} == 6) || ($clientdata{$index}{serverType} == 7) || ($clientdata{$index}{serverType} == 10) || ($clientdata{$index}{serverType} == 11))) ||
		(($switch eq '0089') && (($clientdata{$index}{serverType} == 3) || ($clientdata{$index}{serverType} == 5) || ($clientdata{$index}{serverType} == 8) || ($clientdata{$index}{serverType} == 9))) ||
		(($switch eq '0116') && ($clientdata{$index}{serverType} == 4)) ||
		(($switch eq '00A7') && ($clientdata{$index}{serverType} == 12))
		) { # client sends sync packet
		my $data = pack("C*", 0x7F, 0x00) . pack("V", getTickCount);
		$client->send($data);

		### Check if packet 0228 got tangled up with the sync packet
		if (uc(unpack("H2", substr($msg, 7, 1))) . uc(unpack("H2", substr($msg, 6, 1))) eq '0228') {
			# queue the response (thanks abt123)
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
		$client->send($msg);

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
		if ($self->{challengeNum} == 0) {
			print "Received GameGuard sync request. Client allowed to login account server.\n";
			$client->send(pack("C*", 0x59, 0x02, 0x01));
		} else {
			print "Received GameGuard sync request. Client allowed to login char/map server.\n";
			$client->send(pack("C*", 0x59, 0x02, 0x02));
		}
		$self->{challengeNum}++;
	} else {
		if ($switch eq '0090' || ($msg =~ /\x90\x0($npcID1|$npcID0)/)) { # npc talk
			undef $clientdata{$index}{npc_talk_code};
			if ($msg =~ /\x90\x0$npcID1/) {
				# Show the kafra image
				SendNpcImageShow($self, $client, $msg, $index, "kafra_04.bmp", 0x02);
				# Show the messages
				SendNPCTalk($self, $client, $msg, $index, $npcID1, "[Kafra]");
				SendNPCTalk($self, $client, $msg, $index, $npcID1, "Welcome to Kafra Corp. We will stay with you wherever you go.");
				SendNPCTalkContinue($self, $client, $msg, $index, $npcID1);
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
					SendNPCTalk($self, $client, $msg, $index, $npcID, "Your RO client uses the following server details:");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "^2222DDversion: $clientdata{$index}{version}");
					SendNPCTalk($self, $client, $msg, $index, $npcID, "master_version: $clientdata{$index}{master_version}");
					SendNPCTalk($self, $client, $msg, $index, "serverType: " . ((defined $clientdata{$index}{serverType}) ? $clientdata{$index}{serverType} : 'Unknown'));
					if ($clientdata{$index}{secureLogin}) {
						SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin: $clientdata{$index}{secureLogin}");
						if ($clientdata{$index}{secureLogin_requestCode}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, $npcID, "secureLogin_requestCode: $clientdata{$index}{secureLogin_requestCode}");
						} elsif (defined $clientdata{$index}{secureLogin_type}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin_type: $clientdata{$index}{secureLogin_type}");
						}
						if ($clientdata{$index}{secureLogin_account}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "secureLogin_account: $clientdata{$index}{secureLogin_account}");
						}
					}
					if ($clientdata{$index}{masterLogin_packet}) {
						SendNPCTalk($self, $client, $msg, $index, $npcID, "masterLogin_packet: $clientdata{$index}{masterLogin_packet}");
					}
					if ($clientdata{$index}{gameLogin_packet}) {
						SendNPCTalk($self, $client, $msg, $index, $npcID, "gameLogin_packet: $clientdata{$index}{gameLogin_packet}");
					}
					SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
					
					if (defined $clientdata{$index}{serverType}) {
						$clientdata{$index}{npc_talk_code} = 3;
					} else {
						$clientdata{$index}{npc_talk_code} = 2.5;
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
					$client->send($data);

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
				if ($clientdata{$index}{npc_talk_code} == 2) {
					# Show NPC response list
					SendNpcTalkResponses($self, $client, $msg, $index, $npcID, "Yes, please:No, thanks:");
					$clientdata{$index}{npc_talk_code} = 3;

				} else {
					SendNPCTalk($self, $client, $msg, $index, $npcID, "[Hakore]");
					if (!$clientdata{$index}{npc_talk_code}) {
						if (!defined $clientdata{$index}{serverType}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "However, I regret that Openkore may not currently support your server.");
						} elsif ($clientdata{$index}{serverType} == 7 || $clientdata{$index}{serverType} == 12) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "However, I regret that Openkore does not yet fully support your server this time.");
						} else {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Based on my examination, I think Openkore supports your server.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "I can tell you the possible server details you can use to make Openkore to connect to your server.");
						}
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata{$index}{npc_talk_code} = 1;

					} elsif ($clientdata{$index}{npc_talk_code} == 1) {
						if ((!defined $clientdata{$index}{serverType}) || ($clientdata{$index}{serverType} == 7)) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Would you still like to hear the details?");
						} else {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Would you like to hear the details?");
						}
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata{$index}{npc_talk_code} = 2;
				
					} elsif ($clientdata{$index}{npc_talk_code} == 2.5) {
						if (!defined $clientdata{$index}{serverType}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "As you can see, I can't find a matching serverType for your server.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Please make a trial-and-error using all available serverTypes, one of them might be able to work.");
						} elsif ($clientdata{$index}{serverType} == 7 || $clientdata{$index}{serverType} == 12) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Like I said, your server is not yet fully supported by Openkore.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "You can login to the server and do most basic tasks, but you cannot attack, sit or stand, or use skills.");
						}
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata{$index}{npc_talk_code} = 4;

					} elsif ($clientdata{$index}{npc_talk_code} == 3) {
						SendNPCTalk($self, $client, $msg, $index, $npcID, "The values of ^2222DDip^000000 and ^2222DDport^000000 can be found on your client's (s)clientinfo.xml.");
						SendNPCTalkContinue($self, $client, $msg, $index, $npcID);
						$clientdata{$index}{npc_talk_code} = 4;

					} elsif ($clientdata{$index}{npc_talk_code} == 4) {
						if (!defined $clientdata{$index}{serverType}) {
							SendNPCTalk($self, $client, $msg, $index, $npcID, "If none of the serverTypes work, please inform the developers about this so we can support your server in future releases of Openkore.");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Please visit ^2222DDhttp://forums.openkore.com/^000000");
							SendNPCTalk($self, $client, $msg, $index, $npcID, "Thank you.");
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
								SendNPCTalk($self, $client, $msg, $index, $npcID, "Please note that you can only connect to your server using Openkore SVN.");
							} else {
								SendNPCTalk($self, $client, $msg, $index, $npcID, "Openkore v.1.6.6 or later will work on your server.");
							}
							SendNPCTalk($self, $client, $msg, $index, $npcID, "For more info, please visit ^2222DDhttp://www.openkore.com/^000000");
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

# PACKET SENDING S->C

sub SendCharacterList
{
	my ($self, $client, $msg, $index) = @_;
	
	# Log
	print "Requested Char List (Standard)\n";
	
	# Wanted Block Size
	my $blocksize = $self->{type}->{$config{server_type}}->{charBlockSize} || 116; #defaults to 116

	# Packet Len, Total Characters and Total Slots
	my $totalchars = 2;
	my $totalslots = 12;
	my $len = $blocksize * $totalchars;
	
	# Character Block Pack String
	my $packstring = '';

	$packstring = 'a4 V9 v V2 v4 V v9 Z24 C8 v Z16 V x4 x4 x4 x1' if $blocksize == 147;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4 x4' if $blocksize == 144;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4 x4' if $blocksize == 140;
	$packstring = 'a4 V9 v V2 v14 Z24 C8 v Z16 V x4' if $blocksize == 136;
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
	my($cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename) = 0;

	# Preparing Begin of Character List Packet
	my $data;
	if ($self->{type}->{$config{server_type}}->{charListPacket} eq '0x82d') {
		$data = $accountID . pack("v2 C5 a20", 0x82d, $len + 29,$totalchars,0,0,0,$totalchars,-0); # 29 = v2 C5 a20 size for bRO
	} else {
		$data = $accountID . pack("v v C3", 0x6b, $len + 7, $totalslots, -1, -1);
	}
	
	# Character Block
	my $block;
	
	# Filling Character 1 Block
	$cID = $charID;	$hp = 10000; $maxHp = 10000; $sp = 10000; $maxSp = 10000; $hairstyle = 1; $level = 99; $headTop = 0; $hairColor = 6;
	$name = "Poseidon"; $str = 1; $agi = 1; $vit = 1; $int = 1; $dex = 1; $luk = 1;	$exp = 1; $zeny = 1; $jobExp = 1; $jobLevel = 50; $slot = 0; $rename = 0;
	
	# Preparing Character 1 Block
	$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename);

	# Attaching Block
	$data .= $block;
	
	# Filling Character 2 Block
	$cID = $charID;	$hp = 10000; $maxHp = 10000; $sp = 10000; $maxSp = 10000; $hairstyle = 1; $level = 99; $headTop = 0; $hairColor = 6;
	$name = "Poseidon Dev"; $str = 1; $agi = 1; $vit = 1; $int = 1; $dex = 1; $luk = 1;	$exp = 1; $zeny = 1; $jobExp = 1; $jobLevel = 50; $slot = 1; $rename = 0;
	
	# Preparing Character 2 Block
	$block = pack($packstring,$cID,$exp,$zeny,$jobExp,$jobLevel,$opt1,$opt2,$option,$stance,$manner,$statpt,$hp,$maxHp,$sp,$maxSp,$walkspeed,$jobId,$hairstyle,$weapon,$level,$skillpt,$headLow,$shield,$headTop,$headMid,$hairColor,$clothesColor,$name,$str,$agi,$vit,$int,$dex,$luk,$slot,$rename);		
	
	# Attaching Block
	$data .= $block;		
	
	# Measuring Size of Block
	print "Wanted CharBlockSize : $blocksize\n";		
	print "Built CharBlockSize : " . length($block) . "\n";

	$client->send($data);
}

sub SendMapLogin {
	my ($self, $client, $msg, $index) = @_;

	# '0073' => ['map_loaded','x4 a3',[qw(coords)]]
	my $data;
	
	if ( $config{server_type} !~ /^bRO/ ) { $data .= $accountID; } #<- This is Server Type Based !!
	$data .= pack("C*", 0x73, 0x00) . pack("V", getTickCount) . getCoordString($posX, $posY, 1) . pack("C*", 0x05, 0x05);

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
	
	$client->{connectedToMap} = 1;	
}

sub SendGoToCharSelection
{
	my ($self, $client, $msg, $index) = @_;
	
	# Log	
	print "Requested Char Selection Screen\n";	
	
	$client->send(pack("v v", 0xB3, 1));
}

sub SendQuitGame
{
	my ($self, $client, $msg, $index) = @_;
	
	# Log
	print "Requested Quit Game...\n";
	
	$client->send(pack("v v", 0x18B, 0));	
}

sub SendLookTo
{
	my ($self, $client, $msg, $index, $ID, $to) = @_;
	
	# Make Poseidon look to front
	$client->send(pack('v1 a4 C1 x1 C1', 0x9C, $ID, 0, $to));
}

sub SendUnitInfo		
{
	my ($self, $client, $msg, $index, $ID, $name) = @_;
	
	# Let's not wait for the client to ask for the unit info
	# '0095' => ['actor_info', 'a4 Z24', [qw(ID name)]],
	$client->send(pack("v1 a4 a24", 0x95, $ID, $name));
}

sub SendSystemChatMessage
{
	my ($self, $client, $msg, $index, $message) = @_;
	
	# '009A' => ['system_chat', 'v Z*', [qw(len message)]],
	$client->send(pack("v2 a32", 0x9A, 36, $message));
}

sub SendShowNPC
{
	my ($self, $client, $msg, $index, $obj_type, $GID, $SpriteID, $X, $Y, $MobName) = @_;
	
	# Packet Structure
	my ($object_type,$NPCID,$walk_speed,$opt1,$opt2,$option,$type,$hair_style,$weapon,$lowhead,$shield,$tophead,$midhead,$hair_color,$clothes_color,$head_dir,$guildID,$emblemID,$manner,$opt3,$stance,$sex,$xSize,$ySize,$lv,$font,$name) = 0;

	# Building NPC Data
	$object_type = $obj_type;
	$NPCID = $GID;
	$walk_speed = 0x1BD;
	$type = $SpriteID;
	$lv = 1;
	$name = $MobName;
	
	# '0856' => ['actor_exists', 'v C a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 Z*', [qw(len object_type ID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font name)]], # -1 # spawning provided by try71023
	my $dbuf;
	if ( $config{server_type} !~ /^bRO/ ) { $dbuf .= pack("C", $object_type); } #<- This is Server Type Based !!
	$dbuf .= pack("a4 v3 V v11 a4 a2 v V C2",$NPCID,$walk_speed,$opt1,$opt2,$option,$type,$hair_style,$weapon,$lowhead,$shield,$tophead,$midhead,$hair_color,$clothes_color,$head_dir,$guildID,$emblemID,$manner,$opt3,$stance,$sex);
	$dbuf .= getCoordString($X, $Y, 1);
	$dbuf .= pack("C2 v2",$xSize,$ySize,$lv,$font);
	$dbuf .= pack("Z" . length($name),$name);
	my $opcode;
	if ( $config{server_type} !~ /^bRO/ ) { $opcode = 0x858; } #<- This is Server Type Based !!
	$client->send(pack("v v",$opcode,length($dbuf) + 4) . $dbuf);
}

sub SendShowItemOnGround
{
	my ($self, $client, $msg, $index, $ID, $SpriteID, $X, $Y) = @_;
	
	# '009D' => ['item_exists', 'a4 v1 x1 v3', [qw(ID type x y amount)]]
	$client->send(pack("v1 a4 v1 x1 v3 x2", 0x9D, $ID, $SpriteID, $posX + 1, $posY - 1, 1));	
}

sub SendNPCTalk
{
	my ($self, $client, $msg, $index, $npcID, $message) = @_;
	
	# '00B4' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]]
	my $dbuf = pack("a" . length($message), $message);
	$client->send(pack("v2 a4", 0xB4, (length($dbuf) + 8), $npcID) . $dbuf);
}

sub SendNPCTalkContinue
{
	my ($self, $client, $msg, $index, $npcID) = @_;
	
	# '00B5' => ['npc_talk_continue', 'a4', [qw(ID)]]
	$client->send(pack("v a4", 0xB5, $npcID));
}

sub SendNpcTalkClose
{
	my ($self, $client, $msg, $index, $npcID) = @_;
	
	# '00B6' => ['npc_talk_close', 'a4', [qw(ID)]]
	$client->send(pack("v a4", 0xB6, $npcID));	
}

sub SendNpcTalkResponses
{
	my ($self, $client, $msg, $index, $npcID, $message) = @_;
	
	# '00B7' => ['npc_talk', 'v a4 Z*', [qw(len ID msg)]]
	my $dbuf = pack("a" . length($message), $message);
	$client->send(pack("v2 a4", 0xB7, (length($dbuf) + 8), $npcID) . $dbuf);	
}

sub SendNpcImageShow
{
	my ($self, $client, $msg, $index, $image, $type) = @_;

	# Type = 0xFF = Hide Image
	# Type = 0x02 = Show Image
	# '01B3' => ['npc_image', 'Z64 C', [qw(npc_image type)]]
	$client->send(pack("v a64 C1", 0x1B3, $image, $type));
}

# SERVER TASKS

sub PerformMapLoadedTasks
{
	my ($self, $client, $msg, $index) = @_;
	
	# Looking to Front
	SendLookTo($self, $client, $msg, $index, $accountID, 4);
	
	# Let's not wait for the client to ask for the unit info
	SendUnitInfo($self, $client, $msg, $index, $accountID, 'Poseidon' . (($clientdata{$index}{mode} ? ' Dev' : '')));
	
	# Global Announce
	SendSystemChatMessage($self, $client, $msg, $index, "Welcome to the Poseidon Server !");

	# Show an NPC
	SendShowNPC($self, $client, $msg, $index, 1, $npcID0, 86, $posX + 3, $posY + 4, "Server Details Guide");
	SendLookTo($self, $client, $msg, $index, $npcID0, 3);
	SendUnitInfo($self, $client, $msg, $index, $npcID0, "Server Details Guide");

	# Dev Mode (Char Slot 1)
	if ($clientdata{$index}{mode}) 
	{
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
	}
}

1;

