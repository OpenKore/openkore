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
use Utils qw(binSize);

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
			$clients->[0]->send($packet);
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

sub onClientData {
	my ($self, $client, $msg, $index) = @_;

	### These variables control the account information ###
	my $host = $self->getHost();
	my $port = pack("v", $self->getPort());
	$host = '127.0.0.1' if ($host eq 'localhost');

	my $sessionID = pack("C4",0xff);
	my $accountID = pack("C4",0xff);
	my $accountID2 = pack("C4",0xff);
	my $charID = pack("C4", 0xff,0xff,0xff,0xff);
	my $mapName = pack("a16", "new_1-1.gat");
	my $sex = 1;
	my $serverName = pack("a20", "Poseidon server"); # server name should be less than or equal to 20 characters
	my $serverUsers = pack("V", 0);
	my $charName = pack("a24", "Poseidon server");
	my ($str, $agi, $vit, $int, $dex, $luk) = (99, 99, 99, 99, 99, 99);
	my $hairColor = pack("v", 0x00);
	my $hairStyle = pack("v", 0x00);
	my $exp = pack("V", 0x0fffffff);
	my $exp_job = pack("V", 0x0fffffff);
	my $lvl_job = pack("V", 0x0fffffff);
	my $zeny = pack("V", 0x0fffffff);
	my $level = pack("v", 99);
	my $hp = pack("v", 0x0fff);
	my $hp_max = $hp;
	my $sp = pack("v", 0x0fff);
	my $sp_max = $sp;
	my $head_low = pack("v", 0x01);
	my $head_top = pack("v", 0x01);
	my $head_mid = pack("v", 0x01);
	my $job_id = pack("v", 0x00);

	my @ipElements = split /\./, $host;
	my $charStats = pack("C*", $str, $agi, $vit, $int, $dex, $luk);

	my $switch = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));
	#visualDump($msg, "$switch");

	$self->{willReconnect} = 0;

	# Note:
	# The switch packets are pRO specific and assumes the use of secureLogin 1. It may or may not work with other
	# countries' clients (except probably oRO). The best way to support other clients would be: use a barebones
	# eAthena or Freya as the emulator, or figure out the correct packet switches and include them in the
	# if..elsif..else blocks.
	if (($switch eq '01DB') || ($switch eq '0204')) { # client sends login packet 0204 packet thanks to elhazard
		my $data = pack("C*", 0xdc, 0x01, 0x14) . pack("C17", 0x00);
		# '01DC' => ['secure_login_key', 'x2 a*', [qw(secure_key)]],
		$client->send($data);

	} elsif (($switch eq '01DD') || ($switch eq '0064')) { # 0064 packet thanks to abt123
		my $data = pack("C*",0x69,0x00,0x4f,0x00) . 
			$sessionID . $accountID . $accountID2 . 
			pack("C30",0x00) . pack("C1",$sex) .
			pack("C*",$ipElements[0],$ipElements[1],$ipElements[2],$ipElements[3]) .
			$port .	$serverName . $serverUsers . pack("C2",0x00);
		# '0069' => ['account_server_info', 'x2 a4 a4 a4 x30 C1 a*',
		# 			[qw(sessionID accountID sessionID2 accountSex serverInfo)]],
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '0065') { # client sends server choice packet
		my $data = $accountID .
			pack("C*",0x6b,0x00,0x6e,0x00) . $charID . $exp . $zeny . $exp_job . $lvl_job .
			pack("C*",0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00) .
			$hp . $hp_max . $sp . $sp_max . $job_id .
			pack("C*",0x00,0x00) . $hairStyle . pack("C*",0x00,0x00) . $level .
			pack("C*",0x00,0x00,0x00,0x00) . $head_low . $head_top . $head_mid . $hairColor . pack("C*",0x00,0x00) .
			$charName . $charStats . pack("C*", 0x00,0x00);
		# NOTE: ideally, all character slots are filled with the same character, for idiot-proofing
		# NOTE: also, the character's appearance may be made to be modifiable
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '0066') { # client sends character choice packet
		my $data = pack("C*",	0x71,0x00) . $charID . $mapName . 
			pack("C*",$ipElements[0],$ipElements[1],$ipElements[2],$ipElements[3]) . $port;
		# '0071' => ['received_character_ID_and_Map', 'a4 Z16 a4 v1', [qw(charID mapName mapIP mapPort)]],
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '0072') { # client sends the maplogin packet
		my $data = $accountID .
			pack("C*", 0x73,0x00,0x31,0x63,0xe9,0x02,0x0d,0x46,0xf0,0x05,0x05);
		# '0073' => ['map_loaded','x4 a3',[qw(coords)]],
		$client->send($data);
		$self->{willReconnect} = 1;

	} elsif ($switch eq '007D') { # client sends the map loaded packet
		my $data = pack("C*",0x2C,0x02,0x3F,0xE9,0x00,0x00,0xC8,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00) .
			pack("C*",0x19,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xF0,0x82,0x52,0x44,0x00,0x00) .
			pack("C*",0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00) .
			pack("C*",0x00,0x00,0x00,0x00,0x00,0x00,0x0e,0x47,0xf1,0x90,0xBF,0x28,0x00,0x00,0x03,0x00);
		#'022C' => ['actor_display', 'a4 v4 x2 v5 V1 v3 x4 a4 a4 v x2 C2 a5 x3 v', [qw(ID walk_speed param1 param2 param3 type hair_style weapon shield lowhead timestamp tophead midhead hair_color guildID guildEmblem visual_effects stance sex coords lv)]],
		$client->send($data);

	} elsif ($switch eq '007E') { # client sends sync packet
		my $data = pack("C*",0x7F,0x00,0x00,0x00,0x00,0x00);
		$client->send($data);

		### Check if packet 0228 got tangled up with the sync packet
		if (uc(unpack("H2", substr($msg, 7, 1))) . uc(unpack("H2", substr($msg, 6, 1))) eq '0228') {
			# queue the response (thanks abt123)
			$self->{response} = substr($msg, 6, 18);
			$self->{state} = 'requested';
		}

	} elsif ($switch eq '0187') { # accountid sync (what does this do anyway?)
		$client->send($msg);

	} elsif ($switch eq '018A') { # client sends quit packet
		$self->{challengeNum} = 0;
		$client->send(pack("C*",0x8B,0x01,0x00,0x00));

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
			$client->send(pack("C*", 0x59,0x02,0x01));
		} else {
			print "Received GameGuard sync request. Client allowed to login char/map server.\n";
			$client->send(pack("C*", 0x59,0x02,0x02));
		}
		$self->{challengeNum}++;
		
	} elsif ($switch eq '0085') { # sendMove
		print "Received packet $switch: sendMove.\n";

	} elsif ($switch eq '0089') { # sendAttack
		print "Received packet $switch: sendAttack.\n";

	} elsif ($switch eq '008C') { # public chat
		print "Received packet $switch: public chat.\n";

	} elsif ($switch eq '0094') { # getPlayerInfo
		print "Received packet $switch: getPlayerInfo.\n";
	
	} else {
		print "Caught unhandled packet $switch\n";
	}
}

1;
