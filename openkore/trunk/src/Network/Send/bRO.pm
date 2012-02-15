# bRO (Brazil): Odin
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

		'0232' => ['homunculus_move','a4 a4', [qw(homumID coordString)]],					
		'02B0' => ['master_login', 'V Z24 a24 C Z16 Z14 C', [qw(version username password_rijndael master_version ip mac isGravityID)]],				
		'035F' => ['sync', 'V', [qw(time)]],						
		'0368' => ['actor_action', 'a4 C', [qw(targetID type)]],				
		'0437' => ['move','a4', [qw(coordString)]],							
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],									
		'0801' => ['buy_bulk_vender', 'x2 a4 a4 a*', [qw(venderID venderCID itemInfo)]],				
		'0802' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],						
		'0887' => ['storage_item_remove', 'v V', [qw(index amount)]],			
		'0888' => ['item_drop', 'v2', [qw(index amount)]],												
		'0899' => ['actor_look_at', 'v C', [qw(head body)]],											
		'08A5' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],								
		'08AB' => ['storage_item_add', 'v V', [qw(index amount)]],						
		'0957' => ['party_join_request_by_name', 'a24', [qw(partyName)]],										
		'0960' => ['item_take', 'a4', [qw(ID)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(

		homunculus_move 0232
		master_login 02B0
		sync 035F		
		actor_action 0368
		move 0437
		skill_use_location 0438
		buy_bulk_vender 0801
		map_login 0802
		storage_item_remove 0887
		item_drop 0888
		actor_look_at 0899
		homunculus_command 08A5
		storage_item_add 08AB
		party_join_request_by_name 0957
		item_take 0960
		actor_info_request 096A
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
	
	if ($self->{net}->getState() != Network::IN_GAME && !$map_login) { $enc_val1 = 0; $enc_val2 = 0; return; }
	if ($map_login) { $map_login = 0; }
	
	# Checking if Encryption is Activated
	if ($enc_val1 != 0 && $enc_val2 != 0) 
	{
		# Saving Last Informations for Debug Log
		my $oldMID = $MID;
		my $oldKey = ($enc_val1 >> 16) & 0x7FFF;
		
		# Calculating the Encryption Key
		$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;
	
		# Xoring the Message ID
		$MID = ($MID ^ (($enc_val1 >> 16) & 0x7FFF)) & 0xFFFF;
		$$r_message = pack("v", $MID) . substr($$r_message, 2);

		# Debug Log
		if ($config{debugPacket_sent} == 1) 
		{		
			debug(sprintf("Encrypted MID : [%04X]->[%04X] / KEY : [0x%04X]->[0x%04X]\n", $oldMID, $MID, $oldKey, ($enc_val1 >> 16) & 0x7FFF), "sendPacket", 0);
		}
	}
}

sub sendMapLogin 
{
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	# Initializing the Encryption Keys
	if ( $map_login == 0 )
	{
		$enc_val1 = Math::BigInt->new('0x3DC81D3F');
		$enc_val2 = Math::BigInt->new('0x52610BA4');
		$enc_val3 = Math::BigInt->new('0x31401E7C');
		$map_login = 1;
	}

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

sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	if ($type == 3) {
		$msg = pack("v v", 0x364, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", 0x364, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
}

sub sendMove 
{
	my ($self, $x, $y) = @_;
	
	$self->sendToServer($self->reconstruct({
		switch => 'move',
		coordString => getCoordString(int $x, int $y, 1),
	}));

	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendHomunculusMove 
{
	my ($self, $homunID, $x, $y) = @_;
	
	$self->sendToServer($self->reconstruct({
		switch => 'homunculus_move',
		homumID => $homunID,
		coordString => getCoordString(int $x, int $y, 1),
	}));

	debug "Sent Homunculus Move to: $x, $y\n", "sendPacket", 2;
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

1;
