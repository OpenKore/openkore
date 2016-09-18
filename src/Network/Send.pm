#########################################################################
#  OpenKore - Message sending
#  This module contains functions for sending messages to the RO server.
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
# MODULE DESCRIPTION: Sending messages to RO server
#
# This class contains convenience methods for sending messages to the RO
# server.
#
# Please also read <a href="http://wiki.openkore.com/index.php/Network_subsystem">the
# network subsystem overview.</a>
package Network::Send;

use strict;
use Network::PacketParser; # import
use base qw(Network::PacketParser);
use utf8;
use Carp::Assert;
use Digest::MD5;
use Math::BigInt;

use Globals qw(%config $encryptVal $bytesSent $conState %packetDescriptions $enc_val1 $enc_val2 $char $masterServer $syncSync $accountID %timeout %talk);
use I18N qw(bytesToString stringToBytes);
use Utils qw(existsInList getHex getTickCount getCoordString makeCoordsDir);
use Misc;
use Log qw(debug);

sub import {
	# This code is for backward compatibility reasons, so that you can still
	# write:
	#  sendFoo(\$remote_socket, args);

	my ($package) = caller;
	# This is necessary for some weird reason.
	return if ($package =~ /^Network::Send/);

	package Network::Send::Compatibility;
	require Exporter;
	our @ISA = qw(Exporter);
	require Network::Send::ServerType0;
	no strict 'refs';

	our @EXPORT_OK;
	@EXPORT_OK = ();

	my $class = shift;
	if (@_) {
		@EXPORT_OK = @_;
	} else {
		@EXPORT_OK = grep {/^send/} keys(%{Network::Send::ServerType0::});
	}

	foreach my $symbol (@EXPORT_OK) {
		*{$symbol} = sub {
			my $remote_socket = shift;
			my $func = $Globals::messageSender->can($symbol);
			if (!$func) {
				die "No such function: $symbol";
			} else {
				return $func->($Globals::messageSender, @_);
			}
		};
	}
	Network::Send::Compatibility->export_to_level(1, undef, @EXPORT_OK);
}

### CATEGORY: Class methods

##
# void Network::Send::encrypt(r_msg, themsg)
#
# This is an old method used back in the iRO beta 2 days when iRO had encrypted packets.
# At the moment (December 20 2006) there are no servers that still use encrypted packets.
sub encrypt {
	use bytes;
	my $r_msg = shift;
	my $themsg = shift;
	my @mask;
	my $newmsg;
	my ($in, $out);
	my $temp;
	my $i;

	if ($config{encrypt} == 1 && $conState >= 5) {
		$out = 0;
		for ($i = 0; $i < 13;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 1391);
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 1397;
		}
		$temp = ~(~($temp));
		$temp = $temp % 13;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 13]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("v2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} elsif ($config{encrypt} >= 2 && $conState >= 5) {
		$out = 0;
		for ($i = 0; $i < 17;$i++) {
			$mask[$i] = 0;
		}
		{
			use integer;
			$temp = ($encryptVal * $encryptVal * 34953);
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		{
			use integer;
			$temp = $encryptVal * 2341;
		}
		$temp = ~(~($temp));
		$temp = $temp % 17;
		$mask[$temp] = 1;
		for($in = 0; $in < length($themsg); $in++) {
			if ($mask[$out % 17]) {
				$newmsg .= pack("C1", int(rand() * 255) & 0xFF);
				$out++;
			}
			$newmsg .= substr($themsg, $in, 1);
			$out++;
		}
		$out += 4;
		$newmsg = pack("v2", $out, $encryptVal) . $newmsg;
		while ((length($newmsg) - 4) % 8 != 0) {
			$newmsg .= pack("C1", (rand() * 255) & 0xFF);
		}
	} else {
		$newmsg = $themsg;
	}

	$$r_msg = $newmsg;
}

### CATEGORY: Methods

##
# void $messageSender->encryptMessageID(r_message)
sub encryptMessageID {
	my ($self, $r_message) = @_;
	my $messageID = unpack("v", $$r_message);
	
	if ($self->{encryption}->{crypt_key_3}) {
		if (sprintf("%04X",$messageID) eq $self->{packet_lut}{map_login}) {
			#$self->{encryption}->{crypt_key} = $self->{encryption}->{crypt_key_1};
		} elsif ($self->{net}->getState() != Network::IN_GAME) {
			# Turn off keys
			$self->{encryption}->{crypt_key} = 0; return;
		}
			
		# Checking if Encryption is Activated
		if ($self->{encryption}->{crypt_key} > 0) {
			# Saving Last Informations for Debug Log
			my $oldMID = $messageID;
			my $oldKey = ($self->{encryption}->{crypt_key} >> 16) & 0x7FFF;
			
			# Calculating the Encryption Key
			$self->{encryption}->{crypt_key} = ($self->{encryption}->{crypt_key} * $self->{encryption}->{crypt_key_3} + $self->{encryption}->{crypt_key_2}) & 0xFFFFFFFF;
		
			# Xoring the Message ID
			$messageID = ($messageID ^ (($self->{encryption}->{crypt_key} >> 16) & 0x7FFF)) & 0xFFFF;
			$$r_message = pack("v", $messageID) . substr($$r_message, 2);

			# Debug Log	
			debug (sprintf("Encrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $messageID, $oldKey, ($self->{encryption}->{crypt_key} >> 16) & 0x7FFF), "sendPacket", 0) if $config{debugPacket_sent};
		}
	} else {
		use bytes;
		if ($self->{net}->getState() != Network::IN_GAME) {
			$enc_val1 = 0;
			$enc_val2 = 0;
			return;
		}

		my $messageID = unpack("v", $$r_message);
		if ($enc_val1 != 0 && $enc_val2 != 0) {
			# Prepare encryption
			$enc_val1 = ((0x000343FD * $enc_val1) + $enc_val2)& 0xFFFFFFFF;
			debug (sprintf("enc_val1 = %x", $enc_val1) . "\n", "sendPacket", 2);
			# Encrypt message ID
			$messageID = ($messageID ^ (($enc_val1 >> 16) & 0x7FFF)) & 0xFFFF;
			$$r_message = pack("v", $messageID) . substr($$r_message, 2);
		}
	}
}

sub cryptKeys {
	my $self = shift;
	$self->{encryption} = {
		'crypt_key_1' => Math::BigInt->new(shift),
		'crypt_key_2' => Math::BigInt->new(shift),
		'crypt_key_3' => Math::BigInt->new(shift),
	};
}

##
# void $messageSender->injectMessage(String message)
#
# Send text message to the connected client's party chat.
sub injectMessage {
	my ($self, $message) = @_;
	my $name = stringToBytes("|");
	my $msg .= $name . stringToBytes(" : $message") . chr(0);
	# encrypt(\$msg, $msg);

	# Packet Prefix Encryption Support
	#$self->encryptMessageID(\$msg);

	$msg = pack("C*", 0x09, 0x01) . pack("v*", length($name) + length($message) + 12) . pack("C*",0,0,0,0) . $msg;
	## encrypt(\$msg, $msg);
	$self->{net}->clientSend($msg);
}

##
# void $messageSender->injectAdminMessage(String message)
#
# Send text message to the connected client's system chat.
sub injectAdminMessage {
	my ($self, $message) = @_;
	$message = stringToBytes($message);
	$message = pack("C*",0x9A, 0x00) . pack("v*", length($message)+5) . $message .chr(0);
	# encrypt(\$message, $message);

	# Packet Prefix Encryption Support
	#$self->encryptMessageID(\$message);
	$self->{net}->clientSend($message);
}

##
# String pinEncode(int seed, int pin)
# pin: the PIN code
# key: the encryption seed/key
#
# Another version of the PIN Encode Function, used to hide the real PIN code, using seed/key.
sub pinEncode {
	# randomizePin function/algorithm by Kurama, ever_boy_, kLabMouse and Iniro. cleanups by Revok
	my ($seed, $pin) = @_;

	$seed = Math::BigInt->new($seed);
	my $mulfactor = 0x3498;
	my $addfactor = 0x881234;
	my @keypad_keys_order = ('0'..'9');

	# calculate keys order (they are randomized based on seed value)
	if (@keypad_keys_order >= 1) {
		my $k = 2;
		for (my $pos = 1; $pos < @keypad_keys_order; $pos++) {
			$seed = $addfactor + $seed * $mulfactor & 0xFFFFFFFF; # calculate next seed value
			my $replace_pos = $seed % $k;
			if ($pos != $replace_pos) {
				my $old_value = $keypad_keys_order[$pos];
				$keypad_keys_order[$pos] = $keypad_keys_order[$replace_pos];
				$keypad_keys_order[$replace_pos] = $old_value;
			}
			$k++;
		}
	}
	# associate keys values with their position using a hash
	my %keypad;
	for (my $pos = 0; $pos < @keypad_keys_order; $pos++) { $keypad{@keypad_keys_order[$pos]} = $pos; }
	my $pin_reply = '';
	my @pin_numbers = split('',$pin);
	foreach (@pin_numbers) { $pin_reply .= $keypad{$_}; }
	return $pin_reply;
}

##
# void $messageSender->sendToServer(Bytes msg)
#
# Send a raw data to the server.
sub sendToServer {
	my ($self, $msg) = @_;
	my $net = $self->{net};

	shouldnt(length($msg), 0);
	return unless ($net->serverAlive);

	my $messageID = uc(unpack("H2", substr($msg, 1, 1))) . uc(unpack("H2", substr($msg, 0, 1)));

	my $hookName = "packet_send/$messageID";
	if (Plugins::hasHook($hookName)) {
		my %args = (
			switch => $messageID,
			data => $msg
		);
		Plugins::callHook($hookName, \%args);
		return if ($args{return});
	}

	# encrypt(\$msg, $msg);

	# Packet Prefix Encryption Support
	$self->encryptMessageID(\$msg);
	
	$net->serverSend($msg);
	$bytesSent += length($msg);
	
	if ($config{debugPacket_sent} && !existsInList($config{debugPacket_exclude}, $messageID) && $config{debugPacket_include_dumpMethod} < 3) {
		my $label = $packetDescriptions{Send}{$messageID} ?
			"[$packetDescriptions{Send}{$messageID}]" : '';
		if ($config{debugPacket_sent} == 1) {
			debug(sprintf("Sent packet    : %-4s    [%2d bytes]  %s\n", $messageID, length($msg), $label), "sendPacket", 0);
		} else {
			Misc::visualDump($msg, ">> Sent packet: $messageID  $label");
		}
	}
	
	if ($config{'debugPacket_include_dumpMethod'} && !existsInList($config{debugPacket_exclude}, $messageID) && existsInList($config{'debugPacket_include'}, $messageID)) {
		my $label = $packetDescriptions{Send}{$messageID} ?
			"[$packetDescriptions{Send}{$messageID}]" : '';
		if ($config{debugPacket_include_dumpMethod} == 3 && existsInList($config{'debugPacket_include'}, $messageID)) {
			#Security concern: Dump only when you included the header in config
			Misc::dumpData($msg, 1, 1);
		} elsif ($config{debugPacket_include_dumpMethod} == 4) {
			open my $dump, '>>', 'DUMP_LINE.txt';
			print $dump unpack('H*', $msg) . "\n";
		} elsif ($config{debugPacket_include_dumpMethod} == 5 && existsInList($config{'debugPacket_include'}, $messageID)) {
			#Security concern: Dump only when you included the header in config
			open my $dump, '>>', 'DUMP_HEAD.txt';
			print $dump sprintf("%-4s %2d %s%s\n", $messageID, length($msg), 'Send', $label);
		}
	}
}

##
# void $messageSender->sendRaw(String raw)
# raw: space-delimited list of hex byte values
#
# Send a raw data to the server.
sub sendRaw {
	my ($self, $raw) = @_;
	my $msg;
	my @raw = split / /, $raw;
	foreach (@raw) {
		$msg .= pack("C", hex($_));
	}
	$self->sendToServer($msg);
	debug "Sent Raw Packet: @raw\n", "sendPacket", 2;
}

# parse/reconstruct callbacks and send* subs left for compatibility

sub parse_master_login {
	my ($self, $args) = @_;
	
	if (exists $args->{password_md5_hex}) {
		$args->{password_md5} = pack 'H*', $args->{password_md5_hex};
	}

	if (exists $args->{password_rijndael}) {
		my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
		my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
		my $in = pack('a24', $args->{password_rijndael});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 24, 24);
		$args->{password} = unpack("Z24", $rijndael->Decrypt($in, undef, 24, 0));
	}
}

sub reconstruct_master_login {
	my ($self, $args) = @_;
	
	$args->{ip} = '192.168.0.2' unless exists $args->{ip}; # gibberish
	$args->{mac} = '111111111111' unless exists $args->{mac}; # gibberish
	$args->{mac_hyphen_separated} = join '-', $args->{mac} =~ /(..)/g;
	$args->{isGravityID} = 0 unless exists $args->{isGravityID};
	
	if (exists $args->{password}) {
		for (Digest::MD5->new) {
			$_->add($args->{password});
			$args->{password_md5} = $_->clone->digest;
			$args->{password_md5_hex} = $_->hexdigest;
		}

		my $key = pack('C32', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06));
		my $chain = pack('C32', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41));
		my $in = pack('a32', $args->{password});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 32, 32);
		$args->{password_rijndael} = $rijndael->Encrypt($in, undef, 32, 0);
	}
}

sub sendMasterLogin {
	my ($self, $username, $password, $master_version, $version) = @_;
	my $msg;

	if (
		$masterServer->{masterLogin_packet} eq ''
		# TODO a way to select any packet, handled globally, something like "packet_<handler> <switch>"?
		or $self->{packet_list}{$masterServer->{masterLogin_packet}}
		&& $self->{packet_list}{$masterServer->{masterLogin_packet}}[0] eq 'master_login'
		&& ($self->{packet_lut}{master_login} = $masterServer->{masterLogin_packet})
	) {
		$self->sendClientMD5Hash() unless $masterServer->{clientHash} eq ''; # this is a hack, just for testing purposes, it should be moved to the login algo later on
		
		$msg = $self->reconstruct({
			switch => 'master_login',
			version => $version || $self->version,
			master_version => $master_version,
			username => $username,
			password => $password,
		});
	} else {
		$msg = pack("v1 V", hex($masterServer->{masterLogin_packet}) || 0x64, $version || $self->version) .
			pack("a24", $username) .
			pack("a24", $password) .
			pack("C*", $master_version);
	}
	$self->sendToServer($msg);
	debug "Sent sendMasterLogin\n", "sendPacket", 2;
}

sub secureLoginHash {
	my ($self, $password, $salt, $type) = @_;
	my $md5 = Digest::MD5->new;
	
	$password = stringToBytes($password);
	if ($type % 2) {
		$salt = $salt . $password;
	} else {
		$salt = $password . $salt;
	}
	$md5->add($salt);
	
	$md5->digest
}

sub sendMasterSecureLogin {
	my ($self, $username, $password, $salt, $version, $master_version, $type, $account) = @_;

	$self->{packet_lut}{master_login} ||= $type < 3 ? '01DD' : '01FA';
	
	$self->sendToServer($self->reconstruct({
		switch => 'master_login',
		version => $version || $self->version,
		master_version => $master_version,
		username => $username,
		password_salted_md5 => $self->secureLoginHash($password, $salt, $type),
		clientInfo => $account > 0 ? $account - 1 : 0,
	}));
}

sub reconstruct_game_login {
	my ($self, $args) = @_;
	$args->{userLevel} = 0 unless exists $args->{userLevel};
	($args->{iAccountSID}) = $masterServer->{ip} =~ /\d+\.\d+\.\d+\.(\d+)/ unless exists $args->{iAccountSID};
}

# TODO: $masterServer->{gameLogin_packet}?
sub sendGameLogin {
	my ($self, $accountID, $sessionID, $sessionID2, $sex) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'game_login',
		accountID => $accountID,
		sessionID => $sessionID,
		sessionID2 => $sessionID2,
		accountSex => $sex,
	}));
	debug "Sent sendGameLogin\n", "sendPacket", 2;
}

sub sendCharLogin {
	my ($self, $char) = @_;
	$self->sendToServer($self->reconstruct({switch => 'char_login', slot => $char}));
	debug "Sent sendCharLogin\n", "sendPacket", 2;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	if ($self->{serverType} == 0 || $self->{serverType} == 21 || $self->{serverType} == 22) {
		$msg = $self->reconstruct({
			switch => 'map_login',
			accountID => $accountID,
			charID => $charID,
			sessionID => $sessionID,
			tick => getTickCount,
			sex => $sex,
		});

	} else { #oRO and pRO
		my $key;

		$key = pack("C*", 0xFA, 0x12, 0, 0x50, 0x83);
		$msg = pack("C*", 0x72, 0, 0, 0, 0) .
			$accountID .
			$key .
			$charID .
			pack("C*", 0xFF, 0xFF) .
			$sessionID .
			pack("V", getTickCount()) .
			pack("C", $sex);
	}

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

sub sendMapLoaded {
	my $self = shift;
	$syncSync = pack("V", getTickCount());
	debug "Sending Map Loaded\n", "sendPacket";
	$self->sendToServer($self->reconstruct({switch => 'map_loaded'}));
	Plugins::callHook('packet/sendMapLoaded');
}

sub reconstruct_sync {
	my ($self, $args) = @_;
	$args->{time} = getTickCount;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);
	
	$self->sendToServer($self->reconstruct({switch => 'sync'}));
	
	debug "Sent Sync\n", "sendPacket", 2;
}

sub parse_character_move {
	my ($self, $args) = @_;
	makeCoordsDir($args, $args->{coords});
}

sub reconstruct_character_move {
	my ($self, $args) = @_;
	$args->{coords} = getCoordString(@{$args}{qw(x y)}, $masterServer->{serverType} == 0);
}

sub sendMove {
	my ($self, $x, $y) = @_;
	$self->sendToServer($self->reconstruct({switch => 'character_move', x => $x, y => $y}));
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendAction { # flag: 0 attack (once), 7 attack (continuous), 2 sit, 3 stand
	my ($self, $monID, $flag) = @_;

	my %args;
	$args{monID} = $monID;
	$args{flag} = $flag;
	# eventually we'll trow this hooking out so...
	Plugins::callHook('packet_pre/sendAttack', \%args) if $flag == ACTION_ATTACK || $flag == ACTION_ATTACK_REPEAT;
	Plugins::callHook('packet_pre/sendSit', \%args) if $flag == ACTION_SIT || $flag == ACTION_STAND;
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	$self->sendToServer($self->reconstruct({switch => 'actor_action', targetID => $monID, type => $flag}));
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

sub parse_public_chat {
	my ($self, $args) = @_;
	$self->parseChat($args);
}

sub reconstruct_public_chat {
	my ($self, $args) = @_;
	$self->reconstructChat($args);
}

sub sendChat {
	my ($self, $message) = @_;
	$self->sendToServer($self->reconstruct({switch => 'public_chat', message => $message}));
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'actor_info_request', ID => $ID}));
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetCharacterName {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'actor_name_request', ID => $ID}));
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalk {
	my ($self, $ID) = @_;
	$talk{msg} = $talk{image} = '';
	$self->sendToServer($self->reconstruct({switch => 'npc_talk', ID => $ID, type => 1}));
	debug "Sent talk: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkCancel {
	my ($self, $ID) = @_;
	$talk{msg} = $talk{image} = '';
	$self->sendToServer($self->reconstruct({switch => 'npc_talk_cancel', ID => $ID}));
	debug "Sent talk cancel: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkContinue {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'npc_talk_continue', ID => $ID}));
	debug "Sent talk continue: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkResponse {
	my ($self, $ID, $response) = @_;
	$talk{msg} = $talk{image} = '';
	$self->sendToServer($self->reconstruct({switch => 'npc_talk_response', ID => $ID, response => $response}));
	debug "Sent talk respond: ".getHex($ID).", $response\n", "sendPacket", 2;
}

sub sendTalkNumber {
	my ($self, $ID, $number) = @_;
	$talk{msg} = $talk{image} = '';
	$self->sendToServer($self->reconstruct({switch => 'npc_talk_number', ID => $ID, value => $number}));
	debug "Sent talk number: ".getHex($ID).", $number\n", "sendPacket", 2;
}

sub sendTalkText {
	my ($self, $ID, $input) = @_;
	$talk{msg} = $talk{image} = '';
	$input = stringToBytes($input);
	$self->sendToServer($self->reconstruct({
		switch => 'npc_talk_text',
		len => length($input)+length($ID)+5,
		ID => $ID,
		text => $input
	}));
	debug "Sent talk text: ".getHex($ID).", $input\n", "sendPacket", 2;
}

sub parse_private_message {
	my ($self, $args) = @_;
	$args->{privMsg} = bytesToString($args->{privMsg});
	Misc::stripLanguageCode(\$args->{privMsg});
	$args->{privMsgUser} = bytesToString($args->{privMsgUser});
}

sub reconstruct_private_message {
	my ($self, $args) = @_;
	$args->{privMsg} = '|00' . $args->{privMsg} if $masterServer->{chatLangCode};
	$args->{privMsg} = stringToBytes($args->{privMsg});
	$args->{privMsgUser} = stringToBytes($args->{privMsgUser});
}

sub sendPrivateMsg
{
	my ($self, $user, $message) = @_;
	Misc::validate($user)?$self->sendToServer($self->reconstruct({ switch => 'private_message', privMsg => $message, privMsgUser => $user, })):return;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	$self->sendToServer($self->reconstruct({switch => 'actor_look_at', body => $body, head => $head}));
	debug "Sent look: $body $head\n", "sendPacket", 2;
	@{$char->{look}}{qw(body head)} = ($body, $head);
}

sub sendTake {
	my ($self, $itemID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'item_take', ID => $itemID}));
	debug "Sent take\n", "sendPacket", 2;
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	$self->sendToServer($self->reconstruct({switch => 'item_drop', index => $index, amount => $amount}));
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $index, $targetID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'item_use', index => $index, targetID => $targetID}));
	debug "Item Use: $index\n", "sendPacket", 2;
}

# for old plugin compatibility, use sendRestart instead!
sub sendRespawn { $_[0]->sendRestart(0) }

# for old plugin compatibility, use sendRestart instead!
sub sendQuitToCharSelect { $_[0]->sendRestart(1) }

# 0x00b2,3,restart,2
# type: 0=respawn ; 1=return to char select
sub sendRestart {
	my ($self, $type) = @_;
	$self->sendToServer($self->reconstruct({switch => 'restart', type => $type}));
	debug "Sent Restart: " . ($type ? 'Quit To Char Selection' : 'Respawn') . "\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	$self->sendToServer($self->reconstruct({switch => 'storage_item_add', index => $index, amount => $amount}));
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	$self->sendToServer($self->reconstruct({switch => 'storage_item_remove', index => $index, amount => $amount}));
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	my $mid = hex($self->{packet_lut}{storage_password});
	if ($type == 3) {
		$msg = pack("v v", $mid, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", $mid, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
}

sub parse_party_chat {
	my ($self, $args) = @_;
	$self->parseChat($args);
}

sub reconstruct_party_chat {
	my ($self, $args) = @_;
	$self->reconstructChat($args);
}

sub sendPartyChat {
	my ($self, $message) = @_;
	$self->sendToServer($self->reconstruct({switch => 'party_chat', message => $message}));
}


sub parse_buy_bulk_vender {
	my ($self, $args) = @_;
	@{$args->{items}} = map {{ amount => unpack('v', $_), itemIndex => unpack('x2 v', $_) }} unpack '(a4)*', $args->{itemInfo};
}

sub reconstruct_buy_bulk_vender {
	my ($self, $args) = @_;
	# ITEM index. There were any other indexes expected to be in item buying packet?
	$args->{itemInfo} = pack '(a4)*', map { pack 'v2', @{$_}{qw(amount itemIndex)} } @{$args->{items}};
}

# not "buy", it sells items!
sub sendBuyBulkVender {
	my ($self, $venderID, $r_array, $venderCID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'buy_bulk_vender',
		venderID => $venderID,
		venderCID => $venderCID,
		items => $r_array,
	}));
	debug "Sent bulk buy vender: ".(join ', ', map {"$_->{itemIndex} x $_->{amount}"} @$r_array)."\n", "sendPacket";
}

sub parse_buy_bulk_buyer {
	my ($self, $args) = @_;
	@{$args->{items}} = map {{ amount => unpack('v', $_), itemIndex => unpack('x2 v', $_) }} unpack '(a4)*', $args->{itemInfo};
}

sub reconstruct_buy_bulk_buyer {
	my ($self, $args) = @_;
	# ITEM index. There were any other indexes expected to be in item buying packet?
	$args->{itemInfo} = pack '(a4)*', map { pack 'v2', @{$_}{qw(amount itemIndex)} } @{$args->{items}};
}

sub sendBuyBulkBuyer {
	#FIXME not working yet
	#field index still wrong and remain unknown
	my ($self, $buyerID, $r_array, $buyingStoreID) = @_;
	my $msg = pack('v2', 0x0819, 12+6*@{$r_array});
	$msg .= pack ('a4 a4', $buyerID, $buyingStoreID);
	for (my $i = 0; $i < @{$r_array}; $i++) {
		debug 'Send Buying Buyer Request: '.$r_array->[$i]{itemIndex}.' '.$r_array->[$i]{itemID}.' '.$r_array->[$i]{amount}."\n", "sendPacket", 2;
		$msg .= pack('v3', $r_array->[$i]{itemIndex}, $r_array->[$i]{itemID}, $r_array->[$i]{amount});
	}
	$self->sendToServer($msg);
}

sub sendEnteringBuyer {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'buy_bulk_request', ID => $ID}));
	debug "Sent Entering Buyer: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
### need to check Hook###
	my %args;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
##########################
	$self->sendToServer($self->reconstruct({switch => 'skill_use', lv => $lv, skillID => $ID, targetID => $targetID}));
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	$self->sendToServer($self->reconstruct({switch => 'skill_use_location', lv => $lv, skillID => $ID, x => $x, y => $y}));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendGuildMasterMemberCheck {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'guild_check'}));
	debug "Sent Guild Master/Member Check.\n", "sendPacket";
}

sub sendGuildRequestInfo {
	my ($self, $page) = @_; # page 0-4
	$self->sendToServer($self->reconstruct({
		switch => 'guild_info_request',
		type => $page,
	}));
	debug "Sent Guild Request Page : ".$page."\n", "sendPacket";
}

sub parse_guild_chat {
	my ($self, $args) = @_;
	$self->parseChat($args);
}

sub reconstruct_guild_chat {
	my ($self, $args) = @_;
	$self->reconstructChat($args);
}

sub sendGuildChat {
	my ($self, $message) = @_;
	$self->sendToServer($self->reconstruct({switch => 'guild_chat', message => $message}));
}

sub sendQuit {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'quit_request', type => 0}));
	debug "Sent Quit\n", "sendPacket", 2;
}

sub sendCloseShop {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'shop_close'}));
	debug "Shop Closed\n", "sendPacket", 2;
}

# 0x7DA
sub sendPartyLeader {
	my $self = shift;
	my $ID = shift;
	my $msg = pack("C*", 0xDA, 0x07).$ID;
	$self->sendToServer($msg);
	debug "Sent Change Party Leader ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x802
sub sendPartyBookingRegister {
	my ($self, $level, $MapID, @jobList) = @_;

	$self->sendToServer($self->reconstruct({switch => 'booking_register', level => $level, MapID => $MapID,
						job0 => @jobList[0], job1 => @jobList[1], job2 => @jobList[2],
						job3 => @jobList[3], job4 => @jobList[4], job5 => @jobList[5]}));

	debug "Sent Booking Register\n", "sendPacket", 2;
}

# 0x804
sub sendPartyBookingReqSearch {
	my ($self, $level, $MapID, $job, $LastIndex, $ResultCount) = @_;

	$job = "65535" if ($job == 0); # job null = 65535
	$ResultCount = "10" if ($ResultCount == 0); # ResultCount defaut = 10

	$self->sendToServer($self->reconstruct({switch => 'booking_search', level => $level, MapID => $MapID, job => $job, LastIndex => $LastIndex, ResultCount => $ResultCount}));
	debug "Sent Booking Search\n", "sendPacket", 2;
}

# 0x806
sub sendPartyBookingDelete {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'booking_delete'}));
	debug "Booking Deleted\n", "sendPacket", 2;
}

# 0x808
sub sendPartyBookingUpdate {
	my ($self, @jobList) = @_;

	$self->sendToServer($self->reconstruct({switch => 'booking_update', job0 => @jobList[0],
						job1 => @jobList[1], job2 => @jobList[2], job3 => @jobList[3],
						job4 => @jobList[4], job5 => @jobList[5]}));

	debug "Sent Booking Update\n", "sendPacket", 2;
}

# 0x0827,6
sub sendCharDelete2 {
	my ($self, $charID) = @_;

	$self->sendToServer($self->reconstruct({switch => 'char_delete2', charID => $charID}));
	debug "Sent sendCharDelete2\n", "sendPacket", 2;
}

##
# switch: 0x0829,12: '0829' => ['char_delete2_accept', 'a4 a6', [qw(charID code)]], # 12     -> kRO
# switch: 0x098F,-1: '098f' => ['char_delete2_accept', 'v a4 a*', [qw(length charID code)]], -> idRO, iRO Renewal
sub sendCharDelete2Accept {
	my ($self, $charID, $code) = @_;

	$self->sendToServer($self->reconstruct({switch => 'char_delete2_accept', charID => $charID, code => $code}));
}

sub reconstruct_char_delete2_accept {
	my ($self, $args) = @_;
	debug "Sent sendCharDelete2Accept. CharID: $args->{CharID}, Code: $args->{code}\n", "sendPacket", 2;
}

# 0x082B,6
sub sendCharDelete2Cancel {
	my ($self, $charID) = @_;

	$self->sendToServer($self->reconstruct({switch => 'char_delete2_cancel', charID => $charID}));
	debug "Sent sendCharDelete2Cancel\n", "sendPacket", 2;
}

sub reconstruct_client_hash {
	my ($self, $args) = @_;
	
	if (defined $args->{code}) {
		# FIXME there's packet switch in that code. How to handle it correctly?
		my $code = $args->{code};
		$code =~ s/^02 04 //;
		
		$args->{hash} = pack 'C*', map hex, split / /, $code;
		
	} elsif ($args->{type}) {
		if ($args->{type} == 1) {
			$args->{hash} = pack('C*', 0x7B, 0x8A, 0xA8, 0x90, 0x2F, 0xD8, 0xE8, 0x30, 0xF8, 0xA5, 0x25, 0x7A, 0x0D, 0x3B, 0xCE, 0x52);
		} elsif ($args->{type} == 2) {
			$args->{hash} = pack('C*', 0x27, 0x6A, 0x2C, 0xCE, 0xAF, 0x88, 0x01, 0x87, 0xCB, 0xB1, 0xFC, 0xD5, 0x90, 0xC4, 0xED, 0xD2);
		} elsif ($args->{type} == 3) {
			$args->{hash} = pack('C*', 0x42, 0x00, 0xB0, 0xCA, 0x10, 0x49, 0x3D, 0x89, 0x49, 0x42, 0x82, 0x57, 0xB1, 0x68, 0x5B, 0x85);
		} elsif ($args->{type} == 4) {
			$args->{hash} = pack('C*', 0x22, 0x37, 0xD7, 0xFC, 0x8E, 0x9B, 0x05, 0x79, 0x60, 0xAE, 0x02, 0x33, 0x6D, 0x0D, 0x82, 0xC6);
		} elsif ($args->{type} == 5) {
			$args->{hash} = pack('C*', 0xc7, 0x0A, 0x94, 0xC2, 0x7A, 0xCC, 0x38, 0x9A, 0x47, 0xF5, 0x54, 0x39, 0x7C, 0xA4, 0xD0, 0x39);
		}
	}
}

# TODO: clientHash and secureLogin_requestCode is almost the same, merge
sub sendClientMD5Hash {
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'client_hash',
		hash => pack('H32', $masterServer->{clientHash}), # ex 82d12c914f5ad48fd96fcf7ef4cc492d (kRO sakray != kRO main)
	}));
}

sub parse_actor_move {
	my ($self, $args) = @_;
	makeCoordsDir($args, $args->{coords});
}

sub reconstruct_actor_move {
	my ($self, $args) = @_;
	$args->{coords} = getCoordString(@{$args}{qw(x y)}, !($masterServer->{serverType} > 0));
}

# should be called sendSlaveMove...
sub sendHomunculusMove {
	my ($self, $ID, $x, $y) = @_;
	$self->sendToServer($self->reconstruct({switch => 'actor_move', ID => $ID, x => $x, y => $y}));
	debug sprintf("Sent %s move to: %d, %d\n", Actor::get($ID), $x, $y), "sendPacket", 2;
}

sub sendFriendListReply {
	my ($self, $accountID, $charID, $flag) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'friend_response',
		friendAccountID => $accountID,
		friendCharID => $charID,
		type => $flag,
	}));
	debug "Sent Reject friend request\n", "sendPacket";
}

sub sendFriendRequest {
	my ($self, $name) = @_;
	my $binName = stringToBytes($name);
	$binName = substr($binName, 0, 24) if (length($binName) > 24);
	$binName = $binName . chr(0) x (24 - length($binName));
	$self->sendToServer($self->reconstruct({
		switch => 'friend_request',
		username => $binName,

	}));
	debug "Sent Request to be a friend: $name\n", "sendPacket";
}

sub sendHomunculusCommand {
	my ($self, $command, $type) = @_; # $type is ignored, $command can be 0:get stats, 1:feed or 2:fire
	$self->sendToServer($self->reconstruct({
		switch => 'homunculus_command',
		commandType => $type,
		commandID => $command,
	}));
	debug "Sent Homunculus Command $command", "sendPacket", 2;
}

sub sendPartyJoinRequestByName 
{
	my ($self, $name) = @_;
	
	$self->sendToServer($self->reconstruct({
		switch => 'party_join_request_by_name',
		partyName => stringToBytes ($name),
	}));	
	
	debug "Sent Request Join Party (by name): $name\n", "sendPacket", 2;
}

sub sendSkillSelect {
	my ($self, $skillID, $why) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'skill_select',
		skillID => $skillID,
		why => $why,
	}));
	debug sprintf("Sent Skill Select (skillID: %d, why: %d)", $skillID, $why), 'sendPacket', 2;
}

sub sendReplySyncRequestEx 
{
	my ($self, $SyncID) = @_;
	# Packing New Message and Dispatching
	my $pid = sprintf("%04X", $SyncID);
	$self->sendToServer(pack("C C", hex(substr($pid, 2, 2)), hex(substr($pid, 0, 2))));
	# Debug Log
	# print "Dispatching Sync Ex Reply : 0x" . $pid . "\n";		
	# Debug Log
	debug "Sent Reply Sync Request Ex\n", "sendPacket", 2;
}

sub sendLoginPinCode {
	my ($self, $seed, $type) = @_;

	my $pin = pinEncode($seed, $config{loginPinCode});
	my $msg;
	if ($type == 0) {
		$msg = $self->reconstruct({
			switch => 'send_pin_password',
			accountID => $accountID,
			pin => $pin,
		});
	} elsif ($type == 1) {
		$msg = $self->reconstruct({
			switch => 'new_pin_password',
			accountID => $accountID,
			pin => $pin,
		});
	}
	$self->sendToServer($msg);
	$timeout{charlogin}{time} = time;
	debug "Sent loginPinCode\n", "sendPacket", 2;
}

sub sendCloseBuyShop {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'buy_bulk_closeShop'}));
	debug "Buying Shop Closed\n", "sendPacket", 2;
}

sub sendRequestCashItemsList {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'request_cashitems'}));
	debug "Requesting cashItemsList\n", "sendPacket", 2;
}

sub sendCashShopOpen {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'cash_shop_open'}));
	debug "Requesting sendCashShopOpen\n", "sendPacket", 2;
}

sub sendCashBuy {
	my $self = shift;
	my ($item_id, $item_amount, $tab_code) = @_;
	#"len count item_id item_amount tab_code"
	$self->sendToServer($self->reconstruct({
				switch => 'cash_shop_buy_items',
				len => 16, # always 16 for current implementation
				count => 1, # current _kore_ implementation only allow us to buy 1 item at time
				item_id => $item_id,
				item_amount => $item_amount,
				tab_code => $tab_code
			}
		)
	);
	debug "Requesting sendCashShopOpen\n", "sendPacket", 2;
}

sub sendShowEquipPlayer {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({
				switch => 'view_player_equip_request',
				ID => $ID
			}
		)
	);
	debug "Sent Show Equip Player.\n", "sendPacket", 2;
}

sub sendShowEquipTickbox {
	my ($self, $flag) = @_;
	$self->sendToServer($self->reconstruct({
				switch => 'equip_window_tick',
				type => 0, # is it always zero?
				value => $flag
			}
		)
	);
	debug "Sent Show Equip Tickbox: flag.\n", "sendPacket", 2;
}

# should be sendSlaveAttack...
sub sendHomunculusAttack {
	my $self = shift;
	my $slaveID = shift;
	my $targetID = shift;
	my $flag = shift;
	$self->sendToServer($self->reconstruct({
				switch => 'slave_attack',
				slaveID => $slaveID,
				targetID => $targetID,
				flag => $flag
			}
		)
	);
	debug "Sent Slave attack: ".getHex($targetID)."\n", "sendPacket", 2;
}

# should be sendSlaveStandBy...
sub sendHomunculusStandBy {
	my $self = shift;
	my $slaveID = shift;
	$self->sendToServer($self->reconstruct({
				switch => 'slave_move_to_master',
				slaveID => $slaveID
			}
		)
	);
	debug "Sent Slave standby\n", "sendPacket", 2;
}

sub sendEquip {
	my ($self, $index, $type) = @_;
	$self->sendToServer($self->reconstruct({
				switch => 'send_equip',
				index => $index,
				type => $type
			}
		)
	);
	debug "Sent Equip: $index Type: $type\n" , 2;
}

sub sendProgress {
	my ($self) = @_;
	my $msg = pack("C*", 0xf1, 0x02);
	$self->sendToServer($msg);
	debug "Sent Progress Bar Finish\n", "sendPacket", 2;
}

sub sendProduceMix {
	my ($self, $ID,
		# nameIDs for added items such as Star Crumb or Flame Heart
		$item1, $item2, $item3) = @_;

	my $msg = pack('v5', 0x018E, $ID, $item1, $item2, $item3);
	$self->sendToServer($msg);
	debug "Sent Forge, Produce Item: $ID\n" , 2;
}
sub SendEAC {
	my ($self) = @_;
	my $msg;
	my $msg2;
	my $mrand = int(rand(25));
	if ($mrand == 0){$msg2 = "7C0AC400C00000000100000074071107010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BE920BFC052ABA0D0791FE7D099F9D0F8E33CB45DA9F69714DB8DA7984A7E9D69FC3F471E46AEB0A5FA7A3EE5791B13F0C504122CC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841432B82E71AE46F3C685446C9176CBAE9";}
	elsif ($mrand == 1){$msg2 = "7C0AC400C00000000100000079E6B513010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BFE849A5ED26103D9189FE199672E22A89925BDF74C3A4C3663407AB1B2D9CAD9FC3F471E1FFEE2F7A9293EB4791911F5C1044C7BC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841A92A0B436674F3081CC79EECE6497090";}
	elsif ($mrand == 2){$msg2 = "7C0AC400C000000001000000C4BAF19D010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B6427592E17254D9B3CC12E74A25796A8CC04432E28D95D1100B2D0CA5857994CFC3F471E15F8BEFCF92B3DB5794B48A797044D7FC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841E88F2710F316975BB48439C0B56DE12E";}
	elsif ($mrand == 3){$msg2 = "7C0AC400C0000000010000002FD1DF6B010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BD9AED156F24392B50769D67F07882F55FDB006B9C934A8FC4330D73352E1F8A9FC3F471E44FEE3A6FD293DB1791341A4C104457BC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841100B2296AD8ACAE1B0467B9AFA16A361";}
	elsif ($mrand == 4){$msg2 = "7C0AC400C0000000010000001FD89A54010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B1A3EA580573868F46BC564161B5E72F71E9B2A72A7BA436295A13259E49870BBFC3F471E14FBB5A6F92E68E0794914A79504472AC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841814EC40355775D1A01C28AC83E139C1A";}
	elsif ($mrand == 5){$msg2 = "7C0AC400C000000001000000AFBE65BB010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B8AEC6E34F20A6897F0B68BBBCF23523BF4BBFB3E4A43788B844F41FB6D869B05FC3F471E44A9B3A7FF2E3EE1791C46A29404107FC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3A1DCC0CF92404344FA2E882CDA50328680BA21D808049A3490796A1F3BF14140882F072DBC8955CC874B184157A01885AA793B4D6157ED49D08D6E11";}
	elsif ($mrand == 6){$msg2 = "7C0AC400C000000001000000E3AE680E010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B86AB62EF5803C55136903D3383F3E13FC8299090C80611D0C5D96D17C80A890DFC3F471E15FDE6FCF57B3BB2794B45F8C704177BC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841DA17221E64D7F0F5EADCB8F4D9ADB554";}
	elsif ($mrand == 7){$msg2 = "7C0AC400C0000000010000006EF319B9010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B33662E5E7BB904264EE4692155137B598C791EFD8DAC4B72A7087F21C7E8EEB6FC3F471E14A9E2FCF97D3EE2791812A0CE044678C8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841785DA2223F9F547D46AF6D97E534BC8C";}
	elsif ($mrand == 8){$msg2 = "7C0AC400C00000000100000045050247010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BF6F6084C584759336530D7660A66A1C52C4D2218008B59CD7DF60D0FA26C06F3FC3F471E10F0E2F3AB2C3CE9794B12F79204457CC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B18418A97C05881B23C7E33CF6579E6BF8175";}
	elsif ($mrand == 9){$msg2 = "7C0AC400C00000000100000030C06E08010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B34C913F0203C515EC5DD1F293D47F3605E6E8FA1F8A14E773E634446D454BCA8FC3F471E42FBB0A5AC2E3EE7791944F2C3044D7CC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B18413AFDC943B85632A66E556097CDCE214F";}
	elsif ($mrand == 10){$msg2 = "7C0AC400C0000000010000004B695E75010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B69632BBF761A89B0F79556B33CF2818A104CC4AEF6D5ABE47C6F9C4AC1C14CD6FC3F471E1FFEBFA7AB2E67B5791344F3C2044728C8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841CFE33CE7D3EA10B4C62C5544CF8D8961";}
	elsif ($mrand == 11){$msg2 = "7C0AC400C000000001000000C4910461010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B776CCE7FE1C0D4F224EEB9472209024D1AA309C321CAF0E96A30C2E802C04035FC3F471E1FACE4A5AC7B6EB5791215F0CF04412AC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841AD09308E6C883457EE41DE84307F8538";}
	elsif ($mrand == 12){$msg2 = "7C0AC400C0000000010000000BE0FE84010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B6099A2D137112EA87A6B768DC509B2C4669A7D77B37215CBC20B867A3800F78BFC3F471E43AEB6F1F5263DE0791D11F5C704422FC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841100DE9225B63D49009C7D733809FFB28";}
	elsif ($mrand == 13){$msg2 = "7C0AC400C0000000010000009FF65FA4010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BE0642D70C735992DE2731CD123CCBAC29D218C7C66D3D955F19FA71ECCDDE45EFC3F471E1FF0B0FDAE2D67E1791E49F1C504162BC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B18417280EF662B368C609D87B130B0CE4BD3";}
	elsif ($mrand == 14){$msg2 = "7C0AC400C0000000010000000CD6BB02010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BB7C1EB82B9FA0B8F72FF30F14F79F5D73C111AD775C757AC39D8D95BE6C66041FC3F471E45ACE5A2A82F39B2794914F59504462AC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B184186CC59B71762F21C8520EA4422D8ECC4";}
	elsif ($mrand == 15){$msg2 = "7C0AC400C00000000100000047013D3E010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B0F2EAF2B6237D7F6C332969741FF4DE05708C764C6892410665DC1900D4C85C0FC3F471E43ADE6F3A92D6BE2791B16F392044328C8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B184193ED164C989ABA5E22A8AB7A09F054E8";}
	elsif ($mrand == 16){$msg2 = "7C0AC400C0000000010000000C0A2818010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B614817CA386D60BA8B93C7271BE13F181BD9891882629F712CA5D96F1B3F55F5FC3F471E44ACBEA7F52D3DE6794E46A3C104432FC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B18414F2877E83B0B2BEFEDAC989E3E374075";}
	elsif ($mrand == 17){$msg2 = "7C0AC400C000000001000000D7C2E2A7010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B2407DC71146F4AF156BE8943097DA094778415CBCF8889C3D3B4C1507EB53440FC3F471E43AAE1F7FD2E66E0791A43F09304427FC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B184112ADAB0031B77C84CCDB68DD6D5A6EB4";}
	elsif ($mrand == 18){$msg2 = "7C0AC400C00000000100000021890CB3010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B8828FC7818E94BE11F5BA75005F7E18080EE7661B5EF784B29FA74B2DE5304E3FC3F471E17F9B0F4FC293BB5794C41F9C404412BC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841A1D702A25AECCF89E349BF69E4539C09";}
	elsif ($mrand == 19){$msg2 = "7C0AC400C000000001000000EC6CE594010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B31DCDD0A0969150BC8B24841CBC5C9FAF188DE564DB5973A31FD37706DA10B2BFC3F471E42FFB4F6FB796BE3794B13F4C504177AC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B1841189B7244D8180DCA79F36C2F66917DD7";}
	elsif ($mrand == 20){$msg2 = "7C0AC400C0000000010000007AF96CA7010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B7F944674898ED40625932C96B5F9B2F2742AB0ABC1F77439D24CE296C3B2BA61FC3F471E17FDB5F5F52C3BE7791F43F2C0044128C8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B18416939694229A9EC1F93DE5C02C6B35954";}
	elsif ($mrand == 21){$msg2 = "7C0AC400C0000000010000006B15E522010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B5D8C97B259BE9CFC4D6FA4FD63445BFD9BF2BC64B9D3A4501C2663F935CDA14DFC3F471E13FCE3A6FB2E6EE4791313F593044671C8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3ABDE919397444412FA2E8825D9506584D0EA218E0C00C834C62D3A4D6EF71117D5735D2CBC8955CC874B18419AFF0BFA82FBC2803367EB5C0D3C610C";}
	elsif ($mrand == 22){$msg2 = "7C0AC400C000000001000000CD88F9CD010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738B19157622835AAF65B68B959B56643350C5B696B88F0AD734A950B4E93C7073ECFC3F471E41F0BEA2AC793CB2791B41A2C104442DC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3A788C5CFC4161017FA278E258E5034D182BF218C5D569B349228614A66A1131385235F77BC8955CC874B1841E4E7D469D4F6DB6FE9043CFAA64D3465";}
	elsif ($mrand == 23){$msg2 = "7C0AC400C0000000010000009F4D2ED5010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BBD03F5D0DCBCDB23BAC2EE151E9B04527C99622919DC21A1661B80CBF41BED75FC3F471E1EAAE1A6AB2D6DE1791B49F5C404467AC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3A788C5CFC4161017FA278E258E5034D182BF218C5D569B349228614A66A1131385235F77BC8955CC874B1841AA101775870230F4761DC3C347B05095";}
	elsif ($mrand == 24){$msg2 = "7C0AC400C00000000100000066B3824B010000000200000000000000530F8AFBC74536B9A963B4F1C4CB738BFF5DA03E5B25F7CC7178DC4E107A7BAEF516AFF82AE3B124E1866057467F9B6FFC3F471E1EFFB1A2AF2966E6791A47F4C304437AC8600450A827955BC02FBC61FDBB5407EACFA40BEB062E0099C5192BC01DD81A26D016F2AB48A6C3A788C5CFC4161017FA278E258E5034D182BF218C5D569B349228614A66A1131385235F77BC8955CC874B1841FB5289E2503D2AD2F5F0CF1E55C4EE04";}
	$msg = pack('H*', $msg2);
	$self->sendToServer($msg);
}
1;
