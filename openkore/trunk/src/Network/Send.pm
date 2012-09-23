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
use encoding 'utf8';
use Carp::Assert;
use Digest::MD5;

use Globals qw(%config $encryptVal $bytesSent $conState %packetDescriptions $enc_val1 $enc_val2 $char $masterServer $syncSync @lastpm %lastpm @privMsgUsers);
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
	use bytes;
	my ($self, $r_message) = @_;

	if ($self->{net}->getState() != Network::IN_GAME) {
		$enc_val1 = 0;
		$enc_val2 = 0;
		return;
	}

	my $messageID = unpack("v", $$r_message);
	if ($enc_val1 != 0 && $enc_val2 != 0) {
		# Prepare encryption
		$enc_val1 = (0x000343FD * $enc_val1) + $enc_val2;
		$enc_val1 = $enc_val1 % 2 ** 32;
		debug (sprintf("enc_val1 = %x", $enc_val1) . "\n", "sendPacket", 2);
		# Encrypt message ID
		$messageID = $messageID ^ (($enc_val1 >> 16) & 0x7FFF);
		$messageID &= 0xFFFF;
		$$r_message = pack("v", $messageID) . substr($$r_message, 2);
	}
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
	$self->encryptMessageID(\$msg, unpack("v", $msg));

	$net->serverSend($msg);
	$bytesSent += length($msg);

	if ($config{debugPacket_sent} && !existsInList($config{debugPacket_exclude}, $messageID)) {
		my $label = $packetDescriptions{Send}{$messageID} ?
			"[$packetDescriptions{Send}{$messageID}]" : '';
		if ($config{debugPacket_sent} == 1) {
			debug(sprintf("Sent packet    : %-4s    [%2d bytes]  %s\n", $messageID, length($msg), $label), "sendPacket", 0);
		} else {
			Misc::visualDump($msg, ">> Sent packet: $messageID  $label");
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
		password_md5 => $self->secureLoginHash($password, $salt, $type),
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

# Small Necessary Control
my $cl_players = {};
my $cl_timer = 0;

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
	$args->{coords} = getCoordString(@{$args}{qw(x y)}, $config{serverType} == 0);
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

sub parse_private_message {
	my ($self, $args) = @_;
	$args->{privMsg} = bytesToString($args->{privMsg});
	Misc::stripLanguageCode(\$args->{privMsg});
	$args->{privMsgUser} = bytesToString($args->{privMsgUser});
}

sub reconstruct_private_message {
	my ($self, $args) = @_;
	$args->{privMsg} = '|00' . $args->{privMsg} if $config{chatLangCode} && $config{chatLangCode} ne 'none';
	$args->{privMsg} = stringToBytes($args->{privMsg});
	$args->{privMsgUser} = stringToBytes($args->{privMsgUser});
}

sub sendPrivateMsg
{
	my ($self, $user, $message) = @_;

	if ( !$cl_players->{$user} ) { $cl_players->{$user} = 0; }
	my $size =  keys(%$cl_players);
	if ( $size > (3+3) && $cl_timer == 0 ) { $cl_timer = time; }
	if ( $cl_timer != 0 && (time - $cl_timer) > (30+30) ) { $cl_timer = 0; $cl_players = {}; }

	if ( $cl_timer == 0 ) 
	{
		$self->sendToServer($self->reconstruct({
			switch => 'private_message',
			privMsg => $message,
			privMsgUser => $user,
		}));	
	}
	else { shift @lastpm; }
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

sub sendBuyBulkbuyer {
	my ($self, $buyerID, $r_array, $buyingStoreID) = @_;
	$self->sendToServer($self->reconstruct({
		switch => 'buy_bulk_buyer',
		buyerID => $buyerID,
		buyingStoreID => $buyingStoreID,
		items => $r_array,
	}));
	debug "Sent bulk buy buyer: ".(join ', ', map {"$_->{itemIndex} x $_->{amount}"} @$r_array)."\n", "sendPacket";
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
	$args->{coords} = getCoordString(@{$args}{qw(x y)}, !($config{serverType} > 0));
}

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

1;
