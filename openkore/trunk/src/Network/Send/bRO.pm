#############################################################################
#  OpenKore - Network subsystem												#
#  This module contains functions for sending messages to the server.		#
#																			#
#  This software is open source, licensed under the GNU General Public		#
#  License, version 2.														#
#  Basically, this means that you're allowed to modify and distribute		#
#  this software. However, if you distribute modified versions, you MUST	#
#  also distribute the source code.											#
#  See http://www.gnu.org/licenses/gpl.html for the full license.			#
#############################################################################
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
		'0940' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0369' => ['character_move','a3', [qw(coords)]],
		'035F' => ['sync', 'V', [qw(time)]],
		'07E4' => ['actor_look_at', 'v C', [qw(head body)]],
		'0934' => ['item_take', 'a4', [qw(ID)]],
		'0819' => ['item_drop', 'v2', [qw(index amount)]],
		'0860' => ['storage_item_add', 'v V', [qw(index amount)]],
		'085F' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0884' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0960' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0931' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'0873' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'092B' => ['storage_password_give', 'v H16 a16', [qw(type key encrypted_password)]],
		'092B' => ['storage_password_set', 'v a16 H16', [qw(type encrypted_password key)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(
		actor_action 0940
		character_move 0369
		sync 035F
		actor_look_at 07E4
		item_take 0934
		item_drop 0819
		storage_item_add 0860
		storage_item_remove 085F
		skill_use_location 0884
		actor_info_request 096A
		map_login 0960
		party_join_request_by_name 0931
		homunculus_command 0873
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
		storage_password_give 092B
		storage_password_set 092B
	);
	
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	return $self;
}

sub encryptMessageID {
	my ($self, $r_message, $MID) = @_;
	
	# Checking In-Game State
	if (($self->{net}->getState() != Network::IN_GAME) && (sprintf("%04X",$MID) ne $self->{packet_lut}{map_login})) {
		# turn off keys
		$self->{encryption}->{key_1} = 0; $self->{encryption}->{key_2} = 0; $self->{encryption}->{key_3} = 0;
		return;
	} elsif (!$self->{encryption}->{key_1}) {
		# K
		$self->{encryption}->{key_1} = Math::BigInt->new(498822262);
		# A
		$self->{encryption}->{key_2} = Math::BigInt->new(1768126699);
		# M
		$self->{encryption}->{key_3} = Math::BigInt->new(1868856914);
	}
		
	# Checking if Encryption is Activated
	if ($self->{encryption}->{key_1} != 0 && $self->{encryption}->{key_2} != 0) {
		# Saving Last Informations for Debug Log
		my $oldMID = $MID;
		my $oldKey = ($self->{encryption}->{key_1} >> 16) & 0x7FFF;
		
		# Calculating the Encryption Key
		$self->{encryption}->{key_1} = $self->{encryption}->{key_1}->bmul($self->{encryption}->{key_3})->badd($self->{encryption}->{key_2}) & 0xFFFFFFFF;
	
		# Xoring the Message ID
		$MID = ($MID ^ (($self->{encryption}->{key_1} >> 16) & 0x7FFF)) & 0xFFFF;
		$$r_message = pack("v", $MID) . substr($$r_message, 2);

		# Debug Log	
		debug(sprintf("Encrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $MID, $oldKey, ($self->{encryption}->{key_1} >> 16) & 0x7FFF), "sendPacket", 0) if ($config{debugPacket_sent});
	}
}

sub sendStoragePassword {
	my ($self, $pass, $type) = @_;
	my $storage_key = "EC62E539BB6BBC811A60C06FACCB7EC8"; 
	my $switch;
	# 2 = set password ?
	# 3 = give password ?
	if ($type == 3) { $switch = 'storage_password_give'; } elsif ($type == 2) { $switch = 'storage_password_set';
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	
	my $msg = $self->reconstruct({
		switch => $switch,
		key => 'EC62E539BB6BBC811A60C06FACCB7EC8',
		encrypted_password => $pass, # 16 byte packed hex data
		type => $type
	});
	
	$self->sendToServer($msg);
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

1;