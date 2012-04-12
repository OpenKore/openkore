# bRO (Brazil)
package Network::Send::bRO;
use strict;
use Globals;
use Log qw(message warning error debug);
use Utils qw(existsInList getHex getTickCount getCoordString);
use Math::BigInt;
use base 'Network::Send::ServerType0';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (

		'023B' => ['item_take', 'a4', [qw(ID)]],											
		'02C4' => ['storage_item_add', 'v V', [qw(index amount)]],				
		'085F' => ['party_join_request_by_name', 'a24', [qw(partyName)]],																						
		'088A' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],						
		'08A1' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],																		
		'0923' => ['item_drop', 'v2', [qw(index amount)]],																				
		'0924' => ['actor_action', 'a4 C', [qw(targetID type)]],																
		'0925' => ['actor_look_at', 'v C', [qw(head body)]],					
		'0930' => ['storage_item_remove', 'v V', [qw(index amount)]],													
		'0934' => ['actor_info_request', 'a4', [qw(ID)]],												
		'094C' => ['sync', 'V', [qw(time)]],									
		'094D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],													
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(

		item_take 023B
		master_login 02B0		
		storage_item_add 02C4
		party_join_request_by_name 085F
		skill_use_location 088A
		map_login 08A1
		item_drop 0923
		actor_action 0924
		actor_look_at 0925
		character_move 092B
		storage_item_remove 0930		
		actor_info_request 0934		
		sync 094C
		homunculus_command 094D
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
		$msg = pack("v v", 0x366, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", 0x366, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
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
		partyName => _binName($name),
	}));	
	
	debug "Sent Request Join Party (by name): $name\n", "sendPacket", 2;
}

sub PrepareKeys()
{
	# K
	$enc_val1 = Math::BigInt->new('0x1464FD2FBC00')->bdec()->bxor(0xFFAABBFF)->brsft(16);
	# M
	$enc_val3 = Math::BigInt->new('0x699A8DC5BC00')->bdec()->bxor(0xFFAABBFF)->brsft(16);
	# A
	$enc_val2 = Math::BigInt->new('0x418EF8DFBC00')->bdec()->bxor(0xFFAABBFF)->brsft(16);
}

1;
