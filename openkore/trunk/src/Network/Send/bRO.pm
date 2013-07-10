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
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0885' => ['character_move','a3', [qw(coords)]],
		'035F' => ['sync', 'V', [qw(time)]],
		'0367' => ['actor_look_at', 'v C', [qw(head body)]],
		'087C' => ['item_take', 'a4', [qw(ID)]],
		'0968' => ['item_drop', 'v2', [qw(index amount)]],
		'088D' => ['storage_item_add', 'v V', [qw(index amount)]],
		'094A' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'086D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'093A' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'08AB' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(
		actor_action 0369
		character_move 0885
		sync 035F
		actor_look_at 0367
		item_take 087C
		item_drop 0968
		storage_item_add 088D
		storage_item_remove 094A
		skill_use_location 0438
		actor_info_request 096A
		map_login 086D
		party_join_request_by_name 093A
		homunculus_command 08AB
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
		my $oldKey = ($enc_val1 >> 16) & 0x7FFF;
		
		# Calculating the Encryption Key
		$enc_val1 = $enc_val1->bmul($enc_val2)->badd($enc_val3) & 0xFFFFFFFF;
	
		# Xoring the Message ID
		$MID = ($MID ^ (($enc_val1 >> 16) & 0x7FFF));
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
		$msg = pack("v v", 0x0887, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", 0x0887, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
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
		$enc_val1 = Math::BigInt->new('0x25526870');
		# M
		$enc_val2 = Math::BigInt->new('0x19f63a87');
		# A
		$enc_val3 = Math::BigInt->new('0x28936257');
}

1;