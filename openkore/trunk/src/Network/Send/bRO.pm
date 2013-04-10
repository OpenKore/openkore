#################################################################################################
#  OpenKore - Network subsystem									#
#  This module contains functions for sending messages to the server.				#
#												#
#  This software is open source, licensed under the GNU General Public				#
#  License, version 2.										#
#  Basically, this means that you're allowed to modify and distribute				#
#  this software. However, if you distribute modified versions, you MUST			#
#  also distribute the source code.								#
#  See http://www.gnu.org/licenses/gpl.html for the full license.				#
#################################################################################################
# bRO (Brazil)
package Network::Send::bRO;
use strict;
use Globals;
use Log qw(message warning error debug);
use Utils qw(existsInList getHex getTickCount getCoordString);
use Math::BigInt;
use base 'Network::Send::ServerType0';
use I18N qw(stringToBytes);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (

		'0811' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'08AC' => ['character_move','a3', [qw(coords)]],		
		'0895' => ['sync', 'V', [qw(time)]],
		'0951' => ['actor_look_at', 'v C', [qw(head body)]],				
		'0965' => ['item_take', 'a4', [qw(ID)]],
		'08A8' => ['item_drop', 'v2', [qw(index amount)]],		
		'0935' => ['storage_item_add', 'v V', [qw(index amount)]],
		'089C' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'087F' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0954' => ['actor_info_request', 'a4', [qw(ID)]],	
		'094A' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],	
		'095D' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'08A3' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'08B8' => ['send_pin_password','a4 Z*', [qw(accountID pin)]],
		'08BA' => ['new_pin_password','a4 Z*', [qw(accountID pin)]],
		#'08BE' => ['change_pin_password','a*', [qw(accountID oldPin newPin)]], # TODO: PIN change system/command?
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(

		actor_action 0811
		character_move 08AC
		sync 0895
		actor_look_at 0951		
		item_take 0965
		item_drop 08A8
		storage_item_add 0935
		storage_item_remove 089C
		skill_use_location 087F
		actor_info_request 0954		
		map_login 094A
		party_join_request_by_name 095D
		homunculus_command 08A3
		master_login 02B0
		party_setting 07D7
		buy_bulk_vender 0801
		send_pin_password 08B8
		new_pin_password 08BA
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

# Local Servertype Globals
my $map_login = 0;
my $enc_val3 = 0;
		
sub encryptMessageID 
{
	my ($self, $r_message, $MID) = @_;
	
	# Checking In-Game State
	if ($self->{net}->getState() != Network::IN_GAME && !$map_login) { $enc_val1 = 0; $enc_val2 = 0; return; }
	
	# Turn Off Map Login Flag
	if ($map_login)	{ $map_login = 0; }
		
	# Checking if Encryption is Activated
	if ($enc_val1 != 0 && $enc_val2 != 0) 
	{
		# Saving Last Informations for Debug Log
		my $oldMID = $MID;
		my $oldKey = ($enc_val1 >> 8 >> 8) & 0x7FFF;
		
		# Calculating the Encryption Key
		$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;
	
		# Xoring the Message ID
		$MID = ($MID ^ (($enc_val1 >> 8 >> 8) & 0x7FFF)) & 0xFFFF;
		$$r_message = pack("v", $MID) . substr($$r_message, 2);

		# Debug Log
		if ($config{debugPacket_sent} == 1) 
		{		
			debug(sprintf("Encrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $MID, $oldKey, ($enc_val1 >> 8 >> 8) & 0x7FFF), "sendPacket", 0);
		}
	}
}

sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	if ($type == 3) {
		$msg = pack("v v", 0x0969, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", 0x0969, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
}

sub sendMapLogin 
{
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;

	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	if ( $map_login == 0 ) { PrepareKeys(); $map_login = 1; }

	# Reconstructing Packet 
	$msg = $self->reconstruct({
		switch => 'map_login',
		accountID => $accountID,
		charID => $charID,
		sessionID => $sessionID,
		tick => getTickCount,
		sex => $sex,
	});

	$self->sendToServer($msg);
	debug "Sent sendMapLogin\n", "sendPacket", 2;
}

sub sendHomunculusCommand 
{
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

sub PrepareKeys()
{
	# K
	$enc_val1 = Math::BigInt->new('0x28AB0A40');
	# M
	$enc_val3 = Math::BigInt->new('0x32A06D1A');
	# A
	$enc_val2 = Math::BigInt->new('0x0EE337E4');
}

sub sendLoginPinCode {
	my ($self, $seed, $type) = @_;
	
	my $pin = randomizePinCode($seed, $config{loginPinCode});
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

# randomizePin function/algorithm by Kurama, ever_boy_, kLabMouse and Iniro. cleanups by Revok
sub randomizePinCode {
	my ($seed, $pin) = @_;
	$seed =  Math::BigInt->new($seed);
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
	foreach (@pin_numbers) {
		$pin_reply .= $keypad{$_};
	}
	return $pin_reply;
}

1;