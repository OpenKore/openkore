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

		'08A1' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],
		'0948' => ['party_join_request_by_name', 'a24', [qw(partyName)]],
		'0917' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0936' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0925' => ['character_move','a3', [qw(coords)]],
		'088C' => ['sync', 'V', [qw(time)]],
		'023B' => ['actor_look_at', 'v C', [qw(head body)]],
		'0933' => ['item_take', 'a4', [qw(ID)]],
		'0864' => ['item_drop', 'v2', [qw(index amount)]],
		'08AA' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0952' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0964' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0893' => ['actor_info_request', 'a4', [qw(ID)]],	
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(

		homunculus_command 08A1
		master_login 02B0
		party_join_request_by_name 0948
		map_login 0917
		actor_action 0936
		buy_bulk_vender 0801
		character_move 0925
		sync 088C
		actor_look_at 023B
		item_take 0933
		item_drop 0864
		storage_item_add 08AA
		storage_item_remove 0952
		skill_use_location 0964
		actor_info_request 0893
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
		partyName => _binName($name),
	}));	
	
	debug "Sent Request Join Party (by name): $name\n", "sendPacket", 2;
}

sub PrepareKeys()
{
	# K
	$enc_val1 = Math::BigInt->new('0x2C353AE1');
	# M
	$enc_val3 = Math::BigInt->new('0x2DB26989');
	# A
	$enc_val2 = Math::BigInt->new('0x1D5B55FB');
}

1;