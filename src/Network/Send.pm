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
# Please also read <a href="https://openkore.com/wiki/Network_subsystem">the
# network subsystem overview.</a>
package Network::Send;

use strict;
use Time::HiRes qw(time);
use Network::PacketParser; # import
use base qw(Network::PacketParser);
use utf8;
use Carp::Assert;
use Digest::MD5;
use Math::BigInt;

# TODO: remove 'use Globals' from here, instead pass vars on
use Globals qw(%config $bytesSent %packetDescriptions $enc_val1 $enc_val2 $char $masterServer $syncSync $accountID %timeout %talk $skillExchangeItem $net $rodexList $rodexWrite %universalCatalog %rpackets $mergeItemList $repairList %cashShop);

use I18N qw(bytesToString stringToBytes);
use Utils qw(existsInList getHex getTickCount getCoordString makeCoordsDir);
use Misc;
use Log qw(debug);

sub new {
	my ( $class ) = @_;
	my $self = $class->SUPER::new( @_ );

	my $cryptKeys = $masterServer->{sendCryptKeys};
	if ( $cryptKeys && $cryptKeys =~ /^(0x[0-9A-Fa-f]{8})\s*,\s*(0x[0-9A-Fa-f]{8})\s*,\s*(0x[0-9A-Fa-f]{8})$/ ) {
		$self->cryptKeys( hex $1, hex $2, hex $3 );
	}

	return $self;
}

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

### CATEGORY: Methods

##
# void $messageSender->encryptMessageID(r_message)
sub encryptMessageID {
	my ($self, $r_message) = @_;
	my $messageID = unpack("v", $$r_message);
	my $messageID2 = uc(unpack("H2", substr($$r_message, 1, 1))) . uc(unpack("H2", substr($$r_message, 0, 1)));

	if ($self->{encryption}->{crypt_key_3}) {
		if (sprintf("%04X",$messageID) eq $self->{packet_lut}{map_login}) {
			$self->{encryption}->{crypt_key} = $self->{encryption}->{crypt_key_1};
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
			debug (sprintf("Encrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $messageID, $oldKey, ($self->{encryption}->{crypt_key} >> 16) & 0x7FFF), "sendPacket", 0) if ($config{debugPacket_sent} || ($config{'debugPacket_include_dumpMethod'} && !existsInList($config{debugPacket_exclude}, $messageID2) && existsInList($config{'debugPacket_include'}, $messageID2)));
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

	# Packet Prefix Encryption Support
	#$self->encryptMessageID(\$msg);

	$msg = pack("C*", 0x09, 0x01) . pack("v*", length($name) + length($message) + 12) . pack("C*",0,0,0,0) . $msg;
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
		if ($config{debugPacket_include_dumpMethod} == 2) {
			Misc::visualDump($msg, ">> Sent packet: $messageID  $label");
		} elsif ($config{debugPacket_include_dumpMethod} == 3 && existsInList($config{'debugPacket_include'}, $messageID)) {
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
	unless (exists $args->{mac}) {
	    $args->{mac} = $config{macAddress} || '111111111111'; # gibberish
	    $args->{mac} = uc($args->{mac});
	    $args->{mac_hyphen_separated} = join '-', $args->{mac} =~ /(..)/g;
	}
	$args->{isGravityID} = 0 unless exists $args->{isGravityID};

	if (exists $args->{password}) {
		for (Digest::MD5->new) {
			$_->add($args->{password});
			$args->{password_md5} = $_->clone->digest;
			$args->{password_md5_hex} = $_->hexdigest;
		}

		my $key = pack('C24', (6, 169, 33, 64, 54, 184, 161, 91, 81, 46, 3, 213, 52, 18, 0, 6, 61, 175, 186, 66, 157, 158, 180, 48));
		my $chain = pack('C24', (61, 175, 186, 66, 157, 158, 180, 48, 180, 34, 218, 128, 44, 159, 172, 65, 1, 2, 4, 8, 16, 32, 128));
		my $in = pack('a24', $args->{password});
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 24, 24);
		$args->{password_rijndael} = $rijndael->Encrypt($in, undef, 24, 0);
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
			game_code => '0011', # kRO Ragnarok game code
			flag => 'G000', # Maybe this say that we are connecting from client
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

	if (exists $args->{mac}) {
		my $key = pack('C16', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06));
		my $chain = pack('C16', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41));
		my $mac = $config{macAddress} || "F2ADCC03771E";
		$mac = uc($mac);
		my $in = pack('a16', $mac);

		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 16, 16);
		$args->{mac} = $rijndael->Encrypt($in, undef, 16, 0);
	}
}

# TODO: $masterServer->{gameLogin_packet}?
sub sendGameLogin {
	my ($self, $accountID, $sessionID, $sessionID2, $sex) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'game_login',
		accountID => $accountID,
		sessionID => $sessionID,
		sessionID2 => $sessionID2,
		mac => '111111111111',
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

	if ($self->{serverType} == 0 || $self->{serverType} == 17 || $self->{serverType} == 18 || $self->{serverType} == 19 ||
		$self->{serverType} == 20 || $self->{serverType} == 21 || $self->{serverType} == 22) {

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

	$args->{no_padding} = exists $args->{no_padding} ? $args->{no_padding} : $masterServer->{serverType} == 0;

	$args->{coords} = getCoordString(@{$args}{qw(x y)}, $args->{no_padding});
}

sub sendMove {
	my ($self, $x, $y) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'character_move',
		x => $x,
		y => $y
	}));

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
	delete $talk{msg};
	delete $talk{image};
	$self->sendToServer($self->reconstruct({switch => 'npc_talk', ID => $ID, type => 1}));
	debug "Sent talk: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendTalkCancel {
	my ($self, $ID) = @_;
	undef %talk;
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
	delete $talk{msg};
	delete $talk{image};
	$self->sendToServer($self->reconstruct({switch => 'npc_talk_response', ID => $ID, response => $response}));
	debug "Sent talk respond: ".getHex($ID).", $response\n", "sendPacket", 2;
}

sub sendTalkNumber {
	my ($self, $ID, $number) = @_;
	delete $talk{msg};
	delete $talk{image};
	$self->sendToServer($self->reconstruct({switch => 'npc_talk_number', ID => $ID, value => $number}));
	debug "Sent talk number: ".getHex($ID).", $number\n", "sendPacket", 2;
}

sub sendTalkText {
	my ($self, $ID, $input) = @_;
	delete $talk{msg};
	delete $talk{image};
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

sub sendPrivateMsg {
	my ($self, $user, $message) = @_;
	$self->sendToServer($self->reconstruct({ switch => 'private_message', privMsg => $message, privMsgUser => $user, }));
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
	my ($self, $ID, $amount) = @_;
	$self->sendToServer($self->reconstruct({switch => 'item_drop', ID => $ID, amount => $amount}));
	debug sprintf("Sent drop: %s x $amount\n", unpack('v', $ID)), "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'item_use', ID => $ID, targetID => $targetID}));
	debug sprintf("Item Use: %s\n", unpack('v', $ID)), "sendPacket", 2;
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
	my ($self, $ID, $amount) = @_;
	if ($config{storageAuto_type} == 1) {
		$self->sendToServer($self->reconstruct({switch => 'guild_storage_item_add', ID => $ID, amount => $amount}));
	} else {
		$self->sendToServer($self->reconstruct({switch => 'storage_item_add', ID => $ID, amount => $amount}));
	}
	debug sprintf("Sent Storage Add: %s x $amount\n", unpack('v', $ID)), "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $ID, $amount) = @_;
	if ($config{storageAuto_type} == 1) {
		$self->sendToServer($self->reconstruct({switch => 'guild_storage_item_remove', ID => $ID, amount => $amount}));
	} else {
		$self->sendToServer($self->reconstruct({switch => 'storage_item_remove', ID => $ID, amount => $amount}));
	}
	debug sprintf("Sent Storage Get: %s x $amount\n", unpack('v', $ID)), "sendPacket", 2;
}

sub sendStoragePassword {
	my ($self, $pass, $type) = @_;

	# $pass -> 16 byte packed hex data

	$self->sendToServer($self->reconstruct({
		switch => 'storage_password',
		type => $type,
		pass => $pass,
	}));
}

sub reconstruct_storage_password {
	my ($self, $args) = @_;

	my $aux = pack "H*", "EC62E539BB6BBC811A60C06FACCB7EC8";

	# $type == 2 -> change password
	# $type == 3 -> check password

	if ($args->{type} == 3) {
		$args->{data} = pack '(a*)*', $args->{pass}, $aux;
	} elsif ($args->{type} == 2) {
		$args->{data} = pack '(a*)*', $aux, $args->{pass};
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($args->{type}).");
	}
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

sub reconstruct_buy_bulk_buyer {
    my ($self, $args) = @_;
	my $packet_size = $self->{buy_bulk_buyer_size} || '(a6)*';
	my $packet_unpack = $self->{buy_bulk_buyer_size_unpack} || 'a2 v2';
	$args->{itemInfo} = pack($packet_size, map { pack $packet_unpack, @{$_}{qw(ID itemID amount)} } @{$args->{items}});
}

sub sendBuyBulkBuyer {
    my ($self, $buyerID, $r_array, $buyingStoreID) = @_;
	
	my $len = 12 + (scalar @{$r_array} * 8);
	
    $self->sendToServer($self->reconstruct({
        switch => 'buy_bulk_buyer',
		len => $len,
        buyerID => $buyerID,
        buyingStoreID => $buyingStoreID,
        items => $r_array,
    }));
}

sub sendEnteringBuyer {
	my ($self, $ID) = @_;
	$self->sendToServer($self->reconstruct({switch => 'buy_bulk_request', ID => $ID}));
	debug "Sent Entering Buyer: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendBuyBulkOpenShop {
	my ($self, $limitZeny, $result, $storeName, @items) = @_;

	my $len = 89 + (($#items + 1) * 8);

	$self->sendToServer($self->reconstruct({
		switch => 'buy_bulk_openShop',
		len => $len,
		limitZeny => $limitZeny,
		result => $result,
		storeName => $storeName,
		items => @items,
	}));

	debug "Sent Buyer openShop Request\n", "sendPacket", 2;
}

sub reconstruct_buy_bulk_openShop {
	my ($self, $args) = @_;
	my $packet_size = $self->{buy_bulk_openShop_size} || '(a8)*';
	my $packet_unpack = $self->{buy_bulk_openShop_size_unpack} || 'v2 V';
	$args->{itemInfo} = pack $packet_size, map { pack $packet_unpack, @{$_}{qw(nameID amount price)} } @{$args->{items}};
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

# 0x0102,6,partychangeoption,2:4
# 0x07D7
# note: item share changing seems disabled in newest clients
sub sendPartyOption {
	my ($self, $exp, $itemPickup, $itemDivision) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'party_setting',
		exp => $exp,
		itemPickup => $itemPickup,
		itemDivision => $itemDivision,
	}));
	debug "Sent Party Option\n", "sendPacket", 2;
}

# 0x7DA
sub sendPartyLeader {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'party_leader',
		accountID => $ID,
	}));

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
	debug "Sent sendCharDelete2Accept. CharID: $args->{charID}, Code: $args->{code}\n", "sendPacket", 2;
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

	$args->{no_padding} = exists $args->{no_padding} ? $args->{no_padding} : !($masterServer->{serverType} > 0);

	$args->{coords} = getCoordString(@{$args}{qw(x y)}, $args->{no_padding});
}

sub sendSlaveMove {
	my ($self, $ID, $x, $y) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'actor_move',
		ID => $ID,
		x => $x,
		y => $y,
	}));

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

sub sendReplySyncRequestEx {
	my ($self, $SyncID) = @_;
	# Packing New Message and Dispatching

	$self->sendToServer(pack("v", $SyncID));
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
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({switch => 'cash_shop_open'}));
	debug "Requesting sendCashShopOpen\n", "sendPacket", 2;
}

sub sendCashShopClose {
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({switch => 'cash_shop_close'}));
	undef $cashShop{points};
	debug "Requesting sendCashShopClose\n", "sendPacket", 2;
}

sub sendCashBuy {
	my ($self, $kafra_points, $items) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'cash_shop_buy',
		kafra_points => $kafra_points,
		count => scalar @{$items},
		items => $items,
	}));

	debug "Requesting cash shop buy\n", "sendPacket", 2;
}

sub reconstruct_cash_shop_buy {
	my ($self, $args) = @_;

	$args->{buy_info} = pack '(a*)*', map { pack 'V V v', $_->{nameID}, $_->{amount}, $_->{tab} } @{$args->{items}};
	# Some older clients (prior to 2013, I don't know the exact date) use 'v3' instead of 'V2 v' - lututui
	# $args->{buy_info} = pack '(a*)*', map { pack 'v v v', $_->{nameID}, $_->{amount}, $_->{tab} } @{$args->{items}};
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

# Send configurations (CZ_CONFIG).
# 02D8 <type>.L <value>.L
# type:
#     0 = show equip windows to other players
#     1 = being summoned by skills: Urgent Call, Romantic Rendezvous, Come to me, honey~ & Let's Go, Family!
#     2 = pet autofeeding
#     3 = homunculus autofeeding
#     value:
#         0 = disabled
#         1 = enabled
sub sendMiscConfigSet {
	my ($self, $type, $flag) = @_;

	$self->sendToServer($self->reconstruct({
				switch => 'misc_config_set',
				type => $type,
				flag => $flag
			}
		)
	);

	debug sprintf("Sent Misc Config Type: %s Flag: %s.\n", $type, $flag), "sendPacket", 2;
}

sub sendSlaveAttack {
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

sub sendSlaveStandBy {
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

# Request to equip an item
# 00A9 <index>.W <position>.W (CZ_REQ_WEAR_EQUIP).
# 0998 <index>.W <position>.L (CZ_REQ_WEAR_EQUIP_V5)
sub sendEquip {
	my ($self, $ID, $type) = @_;
	$self->sendToServer($self->reconstruct({
				switch => 'send_equip',
				ID => $ID,
				type => $type
			}
		)
	);
	debug sprintf("Sent Equip: %s Type: $type\n", unpack('v', $ID)), 2;
}

# Request to add an equip to the equip switch window
# 0A97 <index>.W <position>.L
sub sendEquipSwitchAdd {
	my ($self, $ID, $position) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'equip_switch_add',
		ID => $ID,
		position => $position,
	}));

	debug sprintf("Sent Equip Switch Add Item: %s\n", unpack('v', $ID)), "sendPacket", 2;
}

# Request to remove an equip from the equip switch window
# 0A99 <index>.W <position>.L <= 20170502
# 0A99 <index>.W
sub sendEquipSwitchRemove {
	my ($self, $ID, $position) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'equip_switch_remove',
		ID => $ID,
		position =>  $position,
	}));

	debug sprintf("Sent Equip Switch Remove Item: %s\n", unpack('v', $ID)), "sendPacket", 2;
}

# Request to do a full equip switch
# 0A9C
sub sendEquipSwitchRun {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'equip_switch_run'
	}));

	debug "Sent Equip Switch All\n", "sendPacket", 2;
}

# Request to do a single equip switch
# 0ACE <index>.W
sub sendEquipSwitchSingle {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'equip_switch_single',
		ID => $ID
	}));

	debug sprintf("Sent Equip Switch Single Item: %s\n", unpack('v', $ID)), "sendPacket", 2;
}

sub sendProgress {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'notify_progress_bar_complete'}));

	debug "Sent Progress Bar Finish\n", "sendPacket", 2;
}

sub sendDealAddItem {
	my ($self, $ID, $amount) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'deal_item_add',
		ID => $ID,
		amount => $amount
	}));
	debug sprintf("Sent Deal Add Item: %s, $amount\n", unpack('v', $ID)), "sendPacket", 2;
}

##
# sendItemListWindowSelected
# @param num Number of items
# @param type 0: Change Material
#             1: Elemental Analysis (Level 1: Pure to Rough)
#             2: Elemental Analysis (Level 1: Rough to Pure)
# @param act 0: Cancel
#            1: Process
# @param items List of items [itemIndex,amount,itemName]
# @author [Cydh]
##
sub sendItemListWindowSelected {
	my ($self, $num, $type, $act, $items) = @_;
	my $len = ($num * 4) + 12;
	$self->sendToServer($self->reconstruct({
		switch => 'item_list_window_selected',
		len => $len,
		type => $type,
		act => $act,
		items => $items,
	}));
	if ($act == 1) {
		debug "Selected ".(scalar @{$items})." items: ".(join ', ', map {"".$_->{amount}." x ".$_->{itemName}." (binID:".$_->{itemIndex}.")"} @{$items})."\n", "sendPacket";
	} else {
		debug "Selected items were canceled.\n", "sendPacket";
	}
	undef $skillExchangeItem;
}

sub reconstruct_item_list_window_selected {
	my ($self, $args) = @_;
	$args->{itemInfo} = pack '(a4)*', map { pack 'v2', @{$_}{qw(itemIndex amount)} } @{$args->{items}};
}

# Select equip for refining
# '0AA1' => ['refineui_select', 'a2' ,[qw(index)]],
# @param itemIndex OpenKore's Inventory Item Index
# @author [Cydh]
sub sendRefineUISelect {
	my ($self, $itemIndex) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'refineui_select',
		index => $itemIndex,
	}));
	debug "Checking item for RefineUI\n", "sendPacket";
}

# Continue to refine equip
# '0AA3' => ['refineui_refine', 'a2 v C' ,[qw(index catalyst bless)]],
# @param itemIndex OpenKore's Inventory Item Index
# @param materialNameIDMaterial's NameID
# @param useCatalyst Catalyst (Blacksmith Blessing) toggle. 0 = Not using, 1 = Use catalyst
# @author [Cydh]
sub sendRefineUIRefine {
	my ($self, $itemIndex, $materialNameID, $useCatalyst) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'refineui_refine',
		index => $itemIndex,
		catalyst => $materialNameID,
		bless => $useCatalyst,
	}));
	debug "Refining using RefineUI\n", "sendPacket";
}

# Cancel RefineUI usage
# '0AA4' => ['refineui_close', '' ,[qw()]],
# @author [Cydh]
sub sendRefineUIClose {
	my $self = shift;
	$self->sendToServer($self->reconstruct({switch => 'refineui_close'}));
	debug "Closing RefineUI\n", "sendPacket";
}

sub sendTokenToServer {
	my ($self, $username, $password, $master_version, $version, $token, $length, $otp_ip, $otp_port) = @_;
	my $len =  $length + 92;

	my $password_rijndael = $self->encrypt_password($password);
	my $ip = '192.168.0.14';
	my $mac = '20CF3095572A';
	my $mac_hyphen_separated = join '-', $mac =~ /(..)/g;

	$net->serverDisconnect();
	$net->serverConnect($otp_ip, $otp_port);# OTP - One Time Password

	my $msg = $self->reconstruct({
		switch => 'token_login',
		len => $len, # size of packet
		version => $version || $self->version,
		master_version => $master_version,
		username => $username,
		password => $password,
		password_rijndael => $password_rijndael,
		mac => $mac_hyphen_separated,
		ip => $ip,
		token => $token,
	});

	$self->sendToServer($msg);

	debug "Sent sendTokenLogin\n", "sendPacket", 2;
}

# encrypt password kRO/cRO version 2017-2018
sub encrypt_password {
	my ($self, $password) = @_;
	my $password_rijndael;
	if (defined $password) {
		my $key = pack('C32', (0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06, 0x06, 0xA9, 0x21, 0x40, 0x36, 0xB8, 0xA1, 0x5B, 0x51, 0x2E, 0x03, 0xD5, 0x34, 0x12, 0x00, 0x06));
		my $chain = pack('C32', (0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41, 0x3D, 0xAF, 0xBA, 0x42, 0x9D, 0x9E, 0xB4, 0x30, 0xB4, 0x22, 0xDA, 0x80, 0x2C, 0x9F, 0xAC, 0x41));
		my $in = pack('a32', $password);
		my $rijndael = Utils::Rijndael->new;
		$rijndael->MakeKey($key, $chain, 32, 32);
		$password_rijndael = unpack("Z32", $rijndael->Encrypt($in, undef, 32, 0));
		return $password_rijndael;
	} else {
		error("Password is not configured");
	}
}

sub sendReqRemainTime {
	my ($self) = @_;

	my $msg = $self->reconstruct({
		switch => 'request_remain_time',
	});

	$self->sendToServer($msg);
}

sub sendBlockingPlayerCancel {
	my ($self) = @_;
	# XKore mode 1 / 3.
	return if ($self->{net}->version == 1);
	my $msg = $self->reconstruct({
		switch => 'blocking_play_cancel',
	});

	$self->sendToServer($msg);
}


sub rodex_delete_mail {
	my ($self, $type, $mailID1, $mailID2) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_delete_mail',
		type => $type,
		mailID1 => $mailID1,
		mailID2 => $mailID2,
	}));
}

sub rodex_request_zeny {
	my ($self, $mailID1, $mailID2, $type) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_request_zeny',
		mailID1 => $mailID1,
		mailID2 => $mailID2,
		type => $type,
	}));
}

sub rodex_request_items {
	my ($self, $mailID1, $mailID2, $type) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_request_items',
		mailID1 => $mailID1,
		mailID2 => $mailID2,
		type => $type,
	}));
}

sub rodex_cancel_write_mail {
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_cancel_write_mail',
	}));
	undef $rodexWrite;
}

sub rodex_add_item {
	my ($self, $ID, $amount) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_add_item',
		ID => $ID,
		amount => $amount,
	}));
}

sub rodex_remove_item {
	my ($self, $ID, $amount) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_remove_item',
		ID => $ID,
		amount => $amount,
	}));
}

sub rodex_open_write_mail {
	my ($self, $name) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_open_write_mail',
		name => stringToBytes($name),
	}));
}

sub rodex_checkname {
	my ($self, $name) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_checkname',
		name => stringToBytes($name),
	}));
}

#note !
#merge sub of 0A6E / 09EC ? [sctnightcore]
sub rodex_send_mail {
	my ($self) = @_;

	my $title = stringToBytes($rodexWrite->{title}) . chr(0);
	my $body = stringToBytes($rodexWrite->{body}) . chr(0);
	my $pack = $self->reconstruct({
		switch => 'rodex_send_mail',
		receiver => $rodexWrite->{target}{name},
		sender => stringToBytes($char->{name}),
		zeny1 => $rodexWrite->{zeny},
		zeny2 => 0,
		title_len => length $title,
		body_len => length $body,
		char_id => $rodexWrite->{target}{char_id},
		title => $title,
		body => $body,
	});

	$self->sendToServer($pack);
}

sub rodex_refresh_maillist {
	my ($self, $type, $mailID1, $mailID2) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_refresh_maillist',
		type => $type,
		mailID1 => $mailID1,
		mailID2 => $mailID2,
		# seems that is not current used by client/server 2019-09-16
		mailReturnID1 => 0,
		mailReturnID2 => 0,
		mailAccountID1 => 0,
		mailAccountID2 => 0,
	}));
}

sub rodex_read_mail {
	my ($self, $type, $mailID1, $mailID2) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_read_mail',
		type => $type,
		mailID1 => $mailID1,
		mailID2 => $mailID2,
	}));
}

sub rodex_next_maillist {
	my ($self, $type, $mailID1, $mailID2) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_next_maillist',
		type => $type,
		mailID1 => $mailID1,
		mailID2 => $mailID2,
	}));
}

sub rodex_open_mailbox {
	my ($self, $type, $mailID1, $mailID2) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_open_mailbox',
		type => $type,
		mailID1 => $mailID1,
		mailID2 => $mailID2,
		# seems that is not current used by client/server 2019-09-16
		mailReturnID1 => 0,
		mailReturnID2 => 0,
		mailAccountID1 => 0,
		mailAccountID2 => 0,
	}));
}

sub rodex_close_mailbox {
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'rodex_close_mailbox',
	}));
	undef $rodexList;
}

sub sendEnteringVender {
    my ($self, $accountID) = @_;
    $self->sendToServer($self->reconstruct({
        switch => 'send_entering_vending',
        accountID => $accountID,
    }));
}

sub sendUnequip {
    my ($self, $ID) = @_;
    $self->sendToServer($self->reconstruct({
        switch => 'send_unequip_item',
        ID => $ID,
    }));
}

sub sendAddStatusPoint {
    my ($self, $ID,$Amount) = @_;
    $self->sendToServer($self->reconstruct({
        switch => 'send_add_status_point',
        statusID => $ID,
        Amount => '1',
    }));
}

sub sendAddSkillPoint {
    my ($self, $skillID) = @_;
    $self->sendToServer($self->reconstruct({
        switch => 'send_add_skill_point',
        skillID => $skillID,
    }));
}

sub sendHotKeyChange {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'hotkey_change',
		idx => $args->{idx},
		type => $args->{type},
		id => $args->{id},
		lvl => $args->{lvl},
	}));
}

sub sendQuestState {
    my ($self, $questID,$state) = @_;
    $self->sendToServer($self->reconstruct({
        switch => 'send_quest_state',
        questID => $questID,
        state => $state, #TODO:[active=0x00],[inactive=0x01]
    }));
	debug "Sent Quest State.\n", "sendPacket", 2;
}

sub sendClanChat {
    my ($self, $message) = @_;
	$message = $char->{name}." : ".$message;
    $self->sendToServer($self->reconstruct({switch => 'clan_chat', len => length($message) + 4,message => $message}));
}

sub sendchangetitle {
    my ($self, $title_id) = @_;
    $self->sendToServer($self->reconstruct({
        switch => 'send_change_title',
        ID => $title_id,
    }));
	debug "Sent Change Title.\n", "sendPacket", 2;
}

sub sendRecallSso {
	my ($self, $accountID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'recall_sso',
		ID => $accountID,
	}));
}

sub sendRemoveAidSso {
	my ($self, $accountID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'remove_aid_sso',
		ID => $accountID,
	}));
}

sub sendMacroStart {
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'macro_start',
	}));
}

sub sendMacroStop {
	my ($self) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'macro_stop',
	}));
}

sub sendReqCashTabCode {
	my ($self, $tabID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'req_cash_tabcode',
		ID => $tabID,
	}));
}

sub parse_pet_evolution {
	my ($self, $args) = @_;
	@{$args->{items}} = map {{ itemIndex => unpack('v', $_), amount => unpack('x2 v', $_) }} unpack '(a4)*', $args->{itemInfo};
}

sub reconstruct_pet_evolution {
	my ($self, $args) = @_;
	$args->{itemInfo} = pack '(a4)*', map { pack 'v2', @{$_}{qw(itemIndex amount)} } @{$args->{items}};
}

sub sendPetEvolution {
	my ($self, $peteggid, $r_array) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'pet_evolution',
		ID => $peteggid,
		items => $r_array,
	}));
}

sub sendWeaponRefine {
	my ($self, $ID) = @_;

	my $msg = $self->reconstruct({
		switch => 'refine_item',
		ID => $ID,
	});

	$self->sendToServer($msg);

	debug "Sent Weapon Refine.\n", "sendPacket", 2;
}

sub sendCooking {
	my ($self, $type, $nameID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'cook_request',
		nameID => $nameID,
		type => $type,
	}));
	debug "Sent Cooking.\n", "sendPacket", 2;
}

sub sendMakeItemRequest {
	my ($self, $nameID, $material_nameID1, $material_nameID2, $material_nameID3) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'make_item_request',
		nameID => $nameID,
		material_nameID1 => $material_nameID1,
		material_nameID2 => $material_nameID2,
		material_nameID3 => $material_nameID3,
	}));
  debug "Sent Make Item Request.\n", "sendPacket", 2;
}

sub sendSearchStoreClose {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({switch => 'search_store_close'}));

	$universalCatalog{open} = 0;

	debug "Sent search store close\n", "sendPacket", 2;
}

sub sendSearchStoreSearch {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'search_store_info',
		type => $args->{type},
		max_price => $args->{max_price},
		min_price => $args->{min_price},
		item_list => \@{$args->{item_list}},
		card_list => \@{$args->{card_list}},
	}));

	debug "Sent search store search\n", "sendPacket", 2;
}

sub reconstruct_search_store_info {
	my ($self, $args) = @_;

	$args->{item_count} = scalar(@{$args->{item_list}});
	$args->{card_count} = scalar(@{$args->{card_list}});

	my @id_list = (@{$args->{item_list}}, @{$args->{card_list}});

	$args->{item_card_list} = pack "(a*)*", map { pack "v", $_ } @id_list;
}

sub sendSearchStoreRequestNextPage {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({switch => 'search_store_request_next_page'}));

	debug "Sent search store next page request\n", "sendPacket", 2;
}

sub sendSearchStoreSelect {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'search_store_select',
		accountID => $args->{accountID},
		storeID => $args->{storeID},
		nameID => $args->{nameID},
	}));

	debug "Sent search store select request\n", "sendPacket", 2;
}

sub sendNoviceDoriDori {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({switch => 'novice_dori_dori'}));

	debug "Sent Novice Dori Dori\n", "sendPacket", 2;
}

sub sendChangeDress {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({switch => 'change_dress'}));

	debug "Sent Change Dress\n", "sendPacket", 2;
}

sub sendFriendRemove {
	my ($self, $accountID, $charID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'friend_remove',
		accountID => $accountID,
		charID => $charID,
	}));

	debug "Sent Remove a friend\n", "sendPacket";
}

sub sendRepairItem {
	my ($self, $args) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'repair_item',
		index => $args->{index},
		nameID => $args->{nameID},
		upgrade => $args->{upgrade},
		cards => $args->{cards},
	}));
	debug ("Sent repair item index: ".$args->{index}."\n", "sendPacket", 2);
}

sub sendAdoptRequest {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'adopt_request',
		ID => $ID,
	}));

	debug "Sent Adoption Request.\n", "sendPacket", 2;
}

sub sendAdoptReply {
	my ($self, $parentID1, $parentID2, $result) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'adopt_reply_request',
		parentID1 => $parentID1,
		parentID2 => $parentID2,
		result => $result
	}));

	debug "Sent Adoption Reply.\n", "sendPacket", 2;
}

sub sendPrivateAirshipRequest {
	my ($self, $map_name, $nameID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'private_airship_request',
		map_name => stringToBytes($map_name),
		nameID => $nameID,
	}));
}

sub sendNoviceExplosionSpirits {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'novice_explosion_spirits'}));

	debug "Sent Novice Explosion Spirits\n", "sendPacket", 2;
}

sub sendBanCheck {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'ban_check',
		accountID => $ID,
	}));

	debug "Sent Account Ban Check Request : " . getHex($ID) . "\n", "sendPacket", 2;
}

sub sendChangeCart {
	my ($self, $lvl) = @_;

	# lvl: 1..5
	$self->sendToServer($self->reconstruct({
		switch => 'change_cart',
		lvl => $lvl,
	}));

	debug "Sent Cart Change to : $lvl\n", "sendPacket", 2;
}

sub sendArrowCraft {
	my ($self, $nameID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'make_arrow',
		nameID => $nameID,
	}));

	debug "Sent Arrowmake: $nameID\n", "sendPacket", 2;
}

sub sendAutoSpell {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auto_spell',
		ID => $ID,
	}));
}

sub sendEmotion {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'send_emotion',
		ID => $ID,
	}));

	debug "Sent Emotion\n", "sendPacket", 2;
}

sub sendWho {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'request_user_count'}));
	debug "Sent Who (User Count)\n", "sendPacket", 2;
}

sub sendNPCBuySellList {
	my ($self, $ID, $type) = @_;

	# type: 0 get store list
	# type: 1 get sell list
	$self->sendToServer($self->reconstruct({
		switch => 'request_buy_sell_list',
		ID => $ID,
		type => $type,
	}));

	debug "Sent get ".($type ? "buy" : "sell")." list to NPC: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendIgnore {
	my ($self, $name, $flag) = @_;

	my $nameToBytes = stringToBytes($name);

	$self->sendToServer($self->reconstruct({
		switch => 'ignore_player',
		name => $nameToBytes,
		flag => $flag,
	}));

	debug "Sent Ignore: $name, $flag\n", "sendPacket", 2;
}

sub sendIgnoreAll {
	my ($self, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'ignore_all',
		flag => $flag,
	}));

	debug "Sent Ignore All: $flag\n", "sendPacket", 2;
}

sub sendGetIgnoreList {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'get_ignore_list'}));

	debug "Sent get Ignore List.\n", "sendPacket", 2;
}

sub sendChatRoomCreate {
	my ($self, $title, $limit, $public, $password) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'chat_room_create',
		limit => $limit,
		public => $public,
		password => stringToBytes($password),
		title => stringToBytes($title),
	}));

	debug "Sent Create Chat Room: $title, $limit, $public, $password\n", "sendPacket", 2;
}

sub sendChatRoomJoin {
	my ($self, $ID, $password) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'chat_room_join',
		ID => $ID,
		password => stringToBytes($password),
	}));

	debug "Sent Join Chat Room: ".getHex($ID).", $password\n", "sendPacket", 2;
}

sub sendChatRoomChange {
	my ($self, $title, $limit, $public, $password) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'chat_room_change',
		limit => $limit,
		public => $public,
		password => stringToBytes($password),
		title => stringToBytes($title),
	}));

	debug "Sent Change Chat Room: $title, $limit, $public, $password\n", "sendPacket", 2;
}

sub sendChatRoomBestow {
	my ($self, $name) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'chat_room_bestow',
		name => stringToBytes($name),

		# There are two roles:
		# 	0 means 'admin'
		# 	1 means 'normal (not-admin)'
		#
		# Weirdly, you can only bestow the chat window if you are admin (role 0),
		# and in the official client you cannot try to bestow the chat window UNLESS
		# you're admin - so it always sends role 0
		# In rA and Hercules, this info is not used at all, instead it's checked whether
		# you're actually the chat window admin or not. This might be exploitable in
		# official servers (by lying that you're admin when you're not) but I never cared
		# enough to test - lututui, Aug 2018
		role => 0,
	}));

	debug "Sent Chat Room Bestow: $name\n", "sendPacket", 2;
}

sub sendChatRoomKick {
	my ($self, $name) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'chat_room_kick',
		name => stringToBytes($name),
	}));

	debug "Sent Chat Room Kick: $name\n", "sendPacket", 2;
}

sub sendChatRoomLeave {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'chat_room_leave'}));

	debug "Sent Leave Chat Room\n", "sendPacket", 2;
}

sub sendDeal {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'deal_initiate',
		ID => $ID,
	}));

	debug "Sent Initiate Deal: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendDealReply {
	my ($self, $action) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'deal_reply',

		# Action values:
		# 0: Char is too far
		# 1: Character does not exist
		# 2: Trade failed
		# 3: Accept
		# 4: Cancel
		#
		# Weird enough, the client should only send 3/4
		# and the server is the one that can reply 0~2 - technologyguild, Dec 2009
		action => $action,
	}));

	debug "Sent Deal Reply (Action: $action)\n", "sendPacket", 2;
}

sub sendDealFinalize {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'deal_finalize'}));

	debug "Sent Deal Finalize\n", "sendPacket", 2;
}

sub sendCurrentDealCancel {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'deal_cancel'}));

	debug "Sent Cancel Current Deal\n", "sendPacket", 2;
}

sub sendDealTrade {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'deal_trade'}));

	debug "Sent Deal Trade\n", "sendPacket", 2;
}

sub sendStorageClose {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'storage_close'}));

	debug "Sent Storage Close\n", "sendPacket", 2;
}

sub sendPartyJoinRequest {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'party_join_request',
		ID => $ID,
	}));

	debug "Sent Party Request Join: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendPartyJoin {
	my ($self, $ID, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'party_join',
		ID => $ID,
		flag => $flag,
	}));

	debug "Sent Party Join: ".getHex($ID).", $flag\n", "sendPacket", 2;
}

sub sendPartyLeave {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'party_leave'}));

	debug "Sent Party Leave\n", "sendPacket", 2;
}

sub sendPartyKick {
	my ($self, $ID, $name) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'party_kick',
		ID => $ID,
		name => stringToBytes($name),
	}));

	debug "Sent Party Kick: ".getHex($ID).", $name\n", "sendPacket", 2;
}

sub sendMemo {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'memo_request'}));

	debug "Sent Memo\n", "sendPacket", 2;
}

sub sendCompanionRelease {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'companion_release'}));

	debug "Sent Companion Release (Cart, Falcon or Pecopeco)\n", "sendPacket", 2;
}

sub sendCartAdd {
	my ($self, $ID, $amount) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'cart_add',
		ID => $ID,
		amount => $amount,
	}));

	debug "Sent Cart Add: " . getHex($ID) . " x $amount\n", "sendPacket", 2;
}

sub sendCartGet {
	my ($self, $ID, $amount) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'cart_get',
		ID => $ID,
		amount => $amount,
	}));

	debug "Sent Cart Get: " . getHex($ID) . " x $amount\n", "sendPacket", 2;
}

sub sendIdentify {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'identify',
		ID => $ID,
	}));

	debug "Sent Identify: ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendCardMergeRequest {
	my ($self, $cardID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'card_merge_request',
		cardID => $cardID,
	}));

	debug "Sent Card Merge Request: " . getHex($cardID) . "\n", "sendPacket", 2;
}

sub sendCardMerge {
	my ($self, $cardID, $itemID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'card_merge',
		cardID => $cardID,
		itemID => $itemID,
	}));

	debug "Sent Card Merge: " . getHex($cardID) . ", " . getHex($itemID) . "\n", "sendPacket", 2;
}

sub sendCharCreate {
	my $self = shift;
	my ($slot, $name, $str, $agi, $vit, $int, $dex, $luk, $hair_style, $hair_color, $job_id, $sex);

	if ($self->{packet_lut}{char_create} eq '0067') {
		($slot, $name, $str, $agi, $vit, $int, $dex, $luk, $hair_style, $hair_color) = @_;
	} elsif ($self->{packet_lut}{char_create} eq '0970') {
		($slot, $name, $hair_style, $hair_color) = @_;
	} elsif ($self->{packet_lut}{char_create} eq '0A39') {
		($slot, $name, $hair_style, $hair_color, $job_id, $sex) = @_;
		$job_id     ||= 0;    # novice
		$sex        ||= 0;    # female
	}
	$hair_color ||= 1;
	$hair_style ||= 0;

	$self->sendToServer($self->reconstruct({
		switch => 'char_create',
		name => stringToBytes($name),
		str => $str,
		agi => $agi,
		vit => $vit,
		int => $int,
		dex => $dex,
		luk => $luk,
		slot => $slot,
		hair_color => $hair_color,
		hair_style => $hair_style,
		job_id => $job_id,
		sex => $sex
	}));

	debug "Sent Char Create\n", "sendPacket", 2;
}

sub sendCharDelete {
	my ($self, $charID, $email) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'char_delete',
		charID => $charID,
		email => stringToBytes($email),
	}));

	debug "Sent Char Delete\n", "sendPacket", 2;
}

sub sendGuildAlly {
	my ($self, $ID, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_alliance_reply',
		ID => $ID,
		flag => $flag,
	}));

	debug "Sent Ally Guild : ".getHex($ID).", $flag\n", "sendPacket", 2;
}

sub sendGuildRequestEmblem {
	my ($self, $guildID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_emblem_request',
		guildID => $guildID,
	}));

	debug "Sent Guild Request Emblem.\n", "sendPacket";
}

sub sendGuildBreak {
	my ($self, $guildName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_break',
		guildName => stringToBytes($guildName),
	}));

	debug "Sent Guild Break: $guildName\n", "sendPacket", 2;
}

sub sendWarpTele {
	my ($self, $skillID, $map) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'warp_select',
		# skillID:
		# 26 => Teleport (Respawn/Random)
		# 27 => Open Warp
		skillID => $skillID,
		mapName => stringToBytes($map),
	}));

	debug "Sent ". ($skillID == 26 ? "Teleport" : "Open Warp") . "\n", "sendPacket", 2
}

sub sendStorageGetToCart {
	my ($self, $ID, $amount) = @_;
	if ($config{storageAuto_type} == 1) {
			$self->sendToServer($self->reconstruct({
			switch => 'guild_storage_to_cart',
			ID => $ID,
			amount => $amount,
		}));
	} else {
		$self->sendToServer($self->reconstruct({
			switch => 'storage_to_cart',
			ID => $ID,
			amount => $amount,
		}));
	}

	debug "Sent Storage Get From Cart: " . getHex($ID) . " x $amount\n", "sendPacket", 2;
}

sub sendStorageAddFromCart {
	my ($self, $ID, $amount) = @_;
	if ($config{storageAuto_type} == 1) {
		$self->sendToServer($self->reconstruct({
			switch => 'cart_to_guild_storage',
			ID => $ID,
			amount => $amount,
		}));
	} else {
		$self->sendToServer($self->reconstruct({
			switch => 'cart_to_storage',
			ID => $ID,
			amount => $amount,
		}));
	}

	debug "Sent Storage Add From Cart: " . getHex($ID) . " x $amount\n", "sendPacket", 2;
}

sub sendHomunculusName {
	my ($self, $name) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'homunculus_name',
		name => stringToBytes($name),
	}));

	debug "Sent Homunculus Rename: $name\n", "sendPacket", 2;
}

sub sendGuildLeave {
	my ($self, $reason, $guildID, $charID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_leave',
		guildID => $guildID,
		accountID => $accountID,
		charID => $charID,
		reason => stringToBytes($reason),
	}));

	debug "Sent Guild Leave: $reason\n", "sendPacket";
}

sub sendGuildMemberKick {
	my ($self, $guildID, $accountID, $charID, $reason) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_kick',
		guildID => $guildID,
		charID => $charID,
		accountID => $accountID,
		reason => stringToBytes($reason),
	}));

	debug "Sent Guild Kick: ".getHex($charID)."\n", "sendPacket";
}

sub sendGuildCreate {
	my ($self, $name, $charID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_create',
		charID => $charID,
		guildName => stringToBytes($name),
	}));

	debug "Sent Guild Create: $name\n", "sendPacket", 2;
}

sub sendGuildJoin {
	my ($self, $ID, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_join',
		ID => $ID,
		flag => $flag,
	}));

	debug "Sent Join Guild : ".getHex($ID).", $flag\n", "sendPacket";
}

sub sendGuildJoinRequest {
	my ($self, $ID, $charID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_join_request',
		ID => $ID,
		accountID => $accountID,
		charID => $charID,
	}));

	debug "Sent Request Join Guild: ".getHex($ID)."\n", "sendPacket";
}

sub sendGuildNotice {
	my ($self, $guildID, $name, $notice) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'guild_notice',
		guildID => $guildID,
		name => stringToBytes($name),
		notice => stringToBytes($notice),
	}));

	debug "Sent Change Guild Notice: $notice\n", "sendPacket", 2;
}

sub sendGuildSetAlly {
	my ($self, $targetAID, $myAID, $charID) = @_;

	# this packet is for guildmaster asking to set alliance with another guildmaster
	# the other sub for sendGuildAlly are responses to this sub
	# kept the parameters open, but everything except $targetAID could be replaced with Global variables
	# unless you plan to mess around with the alliance packet, no exploits though, I tried ;-)
	# -zdivpsa

	$self->sendToServer($self->reconstruct({
		switch => 'guild_alliance_request',
		targetAccountID => $targetAID,
		accountID => $myAID,
		charID => $charID,
	}));

	debug "Sent Guild Alliance Request\n", "sendPacket", 2;
}

sub sendPetCapture {
	my ($self, $monID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'pet_capture',
		ID => $monID,
	}));
	debug "Sent pet capture: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendPetMenu {
	my ($self, $type) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'pet_menu',

		# Action
		# 0 => info
		# 1 => feed
		# 2 => performance
		# 3 => return to egg
		# 4 => unequip accessory
		action => $type,
	}));

	debug "Sent Pet Menu\n", "sendPacket", 2;
}

sub sendPetHatch {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'pet_hatch',
		ID => $ID,
	}));

	debug "Sent Incubator hatch: " . getHex($ID) . "\n", "sendPacket", 2;
}

sub sendPetName {
	my ($self, $name) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'pet_name',
		name => stringToBytes($name),
	}));

	debug "Sent Pet Rename: $name\n", "sendPacket", 2;
}

sub sendPetEmotion {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'pet_emotion',
		ID => $ID,
	}));

	debug "Sent Pet Emotion: $ID\n", "sendPacket", 2;
}


sub sendBuyBulk {
	my ($self, $r_array) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'buy_bulk',
		items => \@{$r_array},
	}));

	debug("Sent bulk buy: $_->{itemID} x $_->{amount}\n", "sendPacket", 2) foreach (@{$r_array});
}

sub reconstruct_buy_bulk {
	my ($self, $args) = @_;
	my $pack = $self->{send_buy_bulk_pack} || "v2";

	$args->{buyInfo} = pack "(a*)*", map { pack $pack, $_->{amount}, $_->{itemID} } @{$args->{items}};
}

sub sendSellBulk {
	my ($self, $r_array) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'sell_bulk',
		items => \@{$r_array},
	}));

	debug("Sent bulk sell: " . getHex($_->{ID}) . " x $_->{amount}\n", "sendPacket", 2) foreach (@{$r_array});
}

sub reconstruct_sell_bulk {
	my ($self, $args) = @_;

	$args->{sellInfo} = pack "(a*)*", map { pack "a2 v", $_->{ID}, $_->{amount} } @{$args->{items}};
}

sub sendAchievementGetReward {
	my ($self, $achievementID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'achievement_get_reward',
		achievementID => $achievementID,
	}));
}

sub sendTop10Alchemist {
	my ($self) = @_;

	if (!$masterServer->{rankingSystemType}) {
		$self->sendToServer($self->reconstruct({switch => 'rank_alchemist'}));
	} else {
		$self->sendTop10(1);
	}

	debug "Sent Top 10 Alchemist request\n", "sendPacket", 2;
}

sub sendTop10Blacksmith {
	my ($self) = @_;

	if (!$masterServer->{rankingSystemType}) {
		$self->sendToServer($self->reconstruct({switch => 'rank_blacksmith'}));
	} else {
		$self->sendTop10(0);
	}

	debug "Sent Top 10 Blacksmith request\n", "sendPacket", 2;
}

sub sendTop10PK {
	my ($self) = @_;

	if (!$masterServer->{rankingSystemType}) {
		$self->sendToServer($self->reconstruct({switch => 'rank_killer'}));
	} else {
		$self->sendTop10(3);
	}

	debug "Sent Top 10 PK request\n", "sendPacket", 2;
}

sub sendTop10Taekwon {
	my ($self) = @_;

	if (!$masterServer->{rankingSystemType}) {
		$self->sendToServer($self->reconstruct({switch => 'rank_taekwon'}));
	} else {
		$self->sendTop10(2);
	}

	debug "Sent Top 10 Taekwon request\n", "sendPacket", 2;
}

sub sendTop10 {
	my ($self, $type) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'rank_general',

		# Type:
		# 0 => Blacksmith
		# 1 => Alchemist
		# 2 => Taekwon
		# 3 => PK
		type => $type,
	}));
}

sub sendGMSummon {
	my ($self, $playerName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_summon_player',
		playerName => stringToBytes($playerName),
	}));
}

sub sendGMBroadcast {
	my ($self, $message) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_broadcast',

		# to colorize, add in front of message: micc | ssss | blue | tool ?
		message => stringToBytes($message),
	}));
}

sub sendGMKick {
	my ($self, $accountID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_kick',
		targetAccountID => $accountID,
	}));
}

sub sendGMKickAll {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'gm_kick_all'}));
}

sub sendGMMonsterItem {
	my ($self, $name) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_item_mob_create',
		name => stringToBytes($name),
	}));
}

sub sendGMMapMove {
	my ($self, $name, $x, $y) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_move_to_map',
		mapName => stringToBytes($name),
		x => $x,
		y => $y,
	}));
}

sub sendGMResetStateSkill {
	my ($self, $type) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_reset_state_skill',

		# type
		# 0 => status
		# 1 => skills
		type => $type,
	}));

	debug "Sent GM Reset State/Skill.\n", "sendPacket", 2;
}

sub sendGMChangeMapType {
	my ($self, $x, $y, $type) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_change_cell_type',
		x => $x,
		y => $y,

		# type
		# 0 => not walkable
		# 1 => walkable
		type => $type,
	}));

	debug "Sent GM Change Map Type.\n", "sendPacket", 2;
}

sub sendGMBroadcastLocal {
	my ($self, $message) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_broadcast_local',
		message => stringToBytes($message),
	}));
}

sub sendGMChangeEffectState {
	my ($self, $effect_state) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_change_effect_state',
		effect_state => $effect_state
	}));

	debug "Sent GM Hide.\n", "sendPacket", 2;
}

sub sendGMRemove {
	my ($self, $playerName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_remove',
		playerName => stringToBytes($playerName),
	}));
}

sub sendGMShift {
	my ($self, $playerName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_shift',
		playerName => stringToBytes($playerName),
	}));
}

sub sendGMRecall {
	my ($self, $playerName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_recall',
		playerName => stringToBytes($playerName),
	}));
}

sub sendAlignment {
	my ($self, $ID, $alignment, $point) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'alignment',
		targetID => $ID,
		type => $alignment,
		point => $point,
	}));

	debug "Sent Alignment: ".getHex($ID).", $alignment\n", "sendPacket", 2;
}

sub sendOpenShop {
	my ($self, $title, $items) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'shop_open',
		title => stringToBytes($title),
		result => 1,
		items => $items,
	}));
}

sub reconstruct_shop_open {
	my ($self, $args) = @_;

	$args->{vendingInfo} = pack "(a*)*", map { pack "a2 v V", $_->{ID}, $_->{amount}, $_->{price} } @{$args->{items}};
}

sub sendMailboxOpen {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'mailbox_open'}));

	debug "Sent mailbox open.\n", "sendPacket", 2;
}

sub sendMailRead {
	my ($self, $mailID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mail_read',
		mailID => $mailID,
	}));

	debug "Sent read mail.\n", "sendPacket", 2;
}

sub sendMailDelete {
	my ($self, $mailID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mail_delete',
		mailID => $mailID,
	}));

	debug "Sent delete mail.\n", "sendPacket", 2;
}

sub sendMailGetAttach {
	my ($self, $mailID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mail_attachment_get',
		mailID => $mailID,
	}));

	debug "Sent mail get attachment.\n", "sendPacket", 2;
}

sub sendMailOperateWindow {
	my ($self, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mail_remove',
		flag => $flag,
	}));

	debug "Sent mail remove item/zeny.\n", "sendPacket", 2;
}

sub sendMailSetAttach {
	my ($self, $amount, $ID) = @_;

	# Before setting an attachment, we must remove any zeny/item that was attached but the mail wasn't sent
	# Otherwise the attachment will be lost
	if ($ID) {
		$self->sendMailOperateWindow(1);
	} else {
		$self->sendMailOperateWindow(2);
	}

	$AI::temp::mailAttachAmount = $amount;
	$self->sendToServer($self->reconstruct({
		switch => 'mail_attachment_set',
		ID => $ID,
		amount => $amount,
	}));

	debug "Sent mail set attachment.\n", "sendPacket", 2;
}

sub sendMailSend {
	my ($self, $receiver, $title, $message) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mail_send',
		recipient => stringToBytes($receiver),
		title => stringToBytes($title),
		body_len => length $message > 255 ? 255 : length $message,
		body => $message,
	}));

	debug "Sent mail send.\n", "sendPacket", 2;
}

sub reconstruct_mail_send {
	my ($self, $args) = @_;

	$args->{body} = pack "Z" . $args->{body_len}, stringToBytes($args->{body});
}

sub sendMailReturn {
	my ($self, $mailID, $sender) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mail_return',
		mailID => $mailID,
		sender => $sender,
	}));

	debug "Sent return mail.\n", "sendPacket", 2;
}

sub sendAuctionAddItemCancel {
	my ($self, $flag) = @_;

	$flag ||= 1;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_add_item_cancel',
		flag => $flag,
	}));

	debug "Sent Auction Add Item Cancel.\n", "sendPacket", 2;
}

sub sendAuctionAddItem {
	my ($self, $ID, $amount) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_add_item',
		ID => $ID,
		amount => $amount,
	}));

	debug "Sent Auction Add Item.\n", "sendPacket", 2;
}

sub sendAuctionCreate {
	my ($self, $now_price, $max_price, $delete_time) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_create',
		now_price => $now_price,
		max_price => $max_price,
		delete_time => $delete_time,
	}));

	debug "Sent Auction Create.\n", "sendPacket", 2;
}

sub sendAuctionCancel {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_cancel',
		ID => $ID,
	}));

	debug "Sent Auction Cancel.\n", "sendPacket", 2;
}

sub sendAuctionBuy {
	my ($self, $ID, $price) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_buy',
		ID => $ID,
		price => $price,
	}));

	debug "Sent Auction Buy.\n", "sendPacket", 2;
}

sub sendAuctionItemSearch {
	my ($self, $type, $price, $search_string, $page) = @_;
	$page ||= 1;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_search',
		price => $price,
		search_string => stringToBytes($search_string),
		page => $page,

		# type
		# 0 => armor
		# 1 => weapon
		# 2 => card
		# 3 => misc
		# 4 => name
		# 5 => auction id
		type => $type,
	}));

	debug "Sent Auction Item Search.\n", "sendPacket", 2;
}

sub sendAuctionReqMyInfo {
	my ($self, $type) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_info_self',
		type => $type,
	}));

	debug "Sent Auction Request My Info.\n", "sendPacket", 2;
}

sub sendAuctionMySellStop {
	my ($self, $ID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'auction_sell_stop',
		ID => $ID,
	}));

	debug "Sent My Sell Stop.\n", "sendPacket", 2;
}

sub sendPartyJoinRequestByNameReply {
	my ($self, $accountID, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'party_join_request_by_name_reply',
		accountID => $accountID,
		flag => $flag,
	}));

	debug "Sent reply Party Invite.\n", "sendPacket", 2;
}

sub sendAutoRevive {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({switch => 'auto_revive'}));

	debug "Sent Auto Revive.\n", "sendPacket", 2;
}

sub sendBattlegroundChat {
	my ($self, $message) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'battleground_chat',
		message => ($masterServer->{chatLangCode}) ? stringToBytes("|00" . $message) : stringToBytes($message),
	}));

	debug "Sent Battleground chat.\n", "sendPacket", 2;
}

sub sendMercenaryCommand {
	my ($self, $command) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'mercenary_command',

		# 0x0 => COMMAND_REQ_NONE
		# 0x1 => COMMAND_REQ_PROPERTY
		# 0x2 => COMMAND_REQ_DELETE
		flag => $command
	}));

	debug "Sent Mercenary Command $command", "sendPacket", 2;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lvl, $x, $y, $moreinfo) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'skill_use_location_text',
		lvl => $lvl,
		ID => $ID,
		x => $x,
		y => $y,
		info => $moreinfo
	}));

	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendGMGiveMannerByName {
	my ($self, $playerName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'manner_by_name',
		playerName => stringToBytes($playerName),
	}));
}

sub sendGMRequestStatus {
	my ($self, $playerName) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_request_status',
		playerName => stringToBytes($playerName),
	}));
}

sub sendFeelSaveOk {
	my ($self, $flag) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'starplace_agree',
		flag => $flag,
	}));

	debug "Sent FeelSaveOk.\n", "sendPacket", 2;
}

sub sendGMReqAccName {
	my ($self, $targetID) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'gm_request_account_name',
		targetID => $targetID,
	}));

	debug "Sent GM Request Account Name.\n", "sendPacket", 2;
}

sub sendClientVersion {
	my ($self, $version) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'client_version',
		clientVersion => $version,
	}));
}

sub sendCaptchaAnswer {
	my ($self, $answer) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'captcha_answer',
		accountID => $accountID,
		answer => $answer,

		# Strangely, this packet has fixed length (dec 32, or hex 0x20) but has it padded into it - lututui
		len => (exists $rpackets{'07E7'}{length}) ? $rpackets{'07E7'}{length} : 32,
	}));
}

# kRO Client before 2010-08-03 only allow 1 item per transaction
# idRO_Renewal and iRO Chaos use this packet
#
# Since RagexeRE_2010_08_03a it's allowed for multiple items at once see Network/Send/kRO/RagexeRE_2010_08_03a.pm
sub sendCashShopBuy {
	my ($self, $points, $items) = @_;

	if (scalar @{$items}) {
		debug sprintf("Sent buying request from cashshop for %d items.\n", scalar @{$items}), "sendPacket", 2;
		foreach my $item (@{$items}) {
			$self->sendToServer($self->reconstruct({
				switch => 'cash_dealer_buy',
				itemid => $item->{itemID},
				amount => $item->{amount},
				kafra_points => $points,
			}));
		}
	}
}

sub sendStartSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	$char->{last_skill_used_is_continuous} = 1;
	$char->{last_continuous_skill_used} = $ID;
	$self->sendToServer($self->reconstruct({switch => 'start_skill_use', lv => $lv, skillID => $ID, targetID => $targetID}));
	debug "Start Skill Use: $ID\n", "sendPacket", 2;
}

sub sendStopSkillUse {
	my ($self, $ID) = @_;
	$char->{last_skill_used_is_continuous} = 0;
	$char->{last_continuous_skill_used} = 0;
	$self->sendToServer($self->reconstruct({switch => 'stop_skill_use',skillID => $ID}));
	debug "Stop Skill Use: $ID\n", "sendPacket", 2;
}

##
# Request to merge item
# 096E <size>.W { <index>.W }*
# @author [Cydh]
##
sub sendMergeItemRequest {
	my ($self, $num, $items) = @_;
	#my $len = ($num * 4) + 12;
	$self->sendToServer($self->reconstruct({
		switch => 'merge_item_request',
		#len => $len,
		items => $items,
	}));
	debug "Sent merge item request: ".(join ', ', map { $_->{info}->{binID}." x ".$_->{info}->{amount} } @$items)."\n", "sendPacket";
}

sub reconstruct_merge_item_request {
	my ($self, $args) = @_;
	$args->{itemList} = pack '(a2)*', map { $_->{ID} } @{$args->{items}};
}

##
# Request to cancel merge item
# 0974
# @author [Cydh]
##
sub sendMergeItemCancel {
	my ($self, $args) = @_;
	$self->sendToServer($self->reconstruct({ switch => 'merge_item_cancel' }));
	debug "Cancel Merge item\n", "sendPacket";
	$mergeItemList = {};
}

#sub reconstruct_merge_item_cancel {
#	my ($self, $args) = @_;
#}

sub sendStylistChange {
	my ($self, $hair_color, $hair_style, $cloth_color, $head_top, $head_mid, $head_bottom ) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'stylist_change',
		hair_color => $hair_color,
		hair_style => $hair_style,
		cloth_color => $cloth_color,
		head_top => $head_top,
		head_mid => $head_mid,
		head_bottom => $head_bottom
	}));
}

##
# UI System
##

# Request to open an UI window of the given type
# 0A68 <type>.B
sub sendOpenUIRequest {
	my ($self, $UIType) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'open_ui_request',
		UIType => $UIType,
	}));

	debug "Sent Open UI Request (".$UIType.")\n", "sendPacket";
}

##
# Attendance System
##

# Request from the client to retrieve today's attendance reward
# 0AEF

sub sendAttendanceRewardRequest {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'attendance_reward_request',
	}));

	debug "Sent Attendance Reward Request\n", "sendPacket";
}


##
# Banking System
##

# Requesting the data in bank
# 09AB <aid>L (PACKET_CZ_REQ_BANKING_CHECK)
sub sendBankingCheck {
	my ($self, $accountID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'banking_check_request',
		accountID => $accountID,
	}));
}

# Request Withdrawing some money from bank
# 09A9 <AID>L <Money>L (PACKET_CZ_REQ_BANKING_WITHDRAW)
sub sendBankingWithdraw {
	my ($self, $accountID , $zeny) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'banking_withdraw_request',
		accountID => $accountID,
		zeny => $zeny,
	}));
}

# Request saving some money in bank
# 09A7 <AID>L <Money>L (PACKET_CZ_REQ_BANKING_DEPOSIT)
sub sendBankingDeposit {
	my ($self, $accountID , $zeny) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'banking_deposit_request',
		accountID => $accountID,
		zeny => $zeny,
	}));
}

##
# Roulette System
##

# Request to open the roulette window
# 0A19 (CZ_REQ_OPEN_ROULETTE)
sub sendRouletteWindowOpen {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'roulette_window_open',
	}));

	debug "Sent Roulette Window Open\n", "sendPacket";
}

# Request the roulette reward data
# 0A1B (CZ_REQ_ROULETTE_INFO)
sub sendRouletteInfoRequest {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'roulette_info_request',
	}));

	debug "Sent Roulette Info Request\n", "sendPacket";
}

# Notification of the client that the roulette window was closed
# 0A1D (CZ_REQ_CLOSE_ROULETTE)
sub sendRouletteClose {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'roulette_close',
	}));

	debug "Sent Roulette Close\n", "sendPacket";
}

# Request to start the roulette
# 0A1F (CZ_REQ_GENERATE_ROULETTE)
sub sendRouletteStart {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'roulette_start',
	}));

	debug "Sent Roulette Start\n", "sendPacket";
}

# Request to claim a prize
# 0A21 (CZ_RECV_ROULETTE_ITEM)
sub sendRouletteClaimPrize {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'roulette_claim_prize',
	}));

	debug "Sent Roulette Claim Prize\n", "sendPacket";
}

##
# Market System
##

# Send to Server confirmation that we already close NPC shop
# 09D4
sub sendSellBuyComplete {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'sell_buy_complete',
	}));

	debug "Sent Sell/Buy Complete\n", "sendPacket";
}

# Buy item from Market
# 09D6
sub sendBuyBulkMarket {
	my ($self, $r_array) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'buy_bulk_market',
		items => \@{$r_array},
	}));

	debug("Sent bulk buy market: $_->{itemID} x $_->{amount}\n", "sendPacket", 2) foreach (@{$r_array});
}

sub reconstruct_buy_bulk_market {
	my ($self, $args) = @_;
	my $pack = $self->{send_buy_bulk_market_pack} || "v V";

	$args->{buyInfo} = pack "(a*)*", map { pack $pack, $_->{itemID}, $_->{amount} } @{$args->{items}};
}

# Request to close current Market
# 09D8
sub sendMarketClose {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'market_close',
	}));

	debug "Sent Market Close\n", "sendPacket";
}

# Request Inventory Expansion
# 0B14
sub sendInventoryExpansionRequest {
	my ($self, $args) = @_;
	$self->sendToServer($self->reconstruct({ switch => 'inventory_expansion_request' }));
}

# Reject Inventory Expansion
# 0B19
sub sendInventoryExpansionRejected {
	my ($self, $args) = @_;
	$self->sendToServer($self->reconstruct({ switch => 'inventory_expansion_rejected' }));
}

# 0B1C (PACKET_CZ_PING)
sub sendPing {
	my ($self, $args) = @_;
	$self->sendToServer($self->reconstruct({ switch => 'ping' }));
}

# 0A5A - PACKET_CZ_MACRO_DETECTOR_DOWNLOAD
# Let Server know that we already downloaded Captcha Image
sub sendMacroDetectorDownload {
	my ($self) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'macro_detector_download',
	}));
}

# 0A5C - PACKET_CZ_MACRO_DETECTOR_ANSWER
# Send Captcha Answer
sub sendMacroDetectorAnswer {
	my ($self, $answer) = @_;

	my $answer_bytes = stringToBytes($answer);

	$self->sendToServer($self->reconstruct({
		switch => 'macro_detector_answer',
		answer => $answer_bytes,
	}));
}

# 0A69 - PACKET_CZ_CAPTCHA_PREVIEW_REQUEST
# Request to preview a captcha (privilege is required)
sub sendCaptchaPreviewRequest {
	my ($self, $captcha_key) = @_;

	$self->sendToServer($self->reconstruct({
		switch => 'captcha_preview_request',
		captcha_key => $captcha_key,
	}));
}

1;
