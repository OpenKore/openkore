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
		'0893' => ['storage_item_add', 'v V', [qw(index amount)]],
		'008C' => ['public_chat', 'x2 Z*', [qw(message)]],
		'0866' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'01B2' => ['shop_open'],
		'0202' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'0443' => ['skill_select', 'V v', [qw(why skillID)]],
		'0944' => ['actor_look_at', 'v C', [qw(head body)]],
		'086D' => ['sync', 'V', [qw(time)]],
		'089D' => ['item_take', 'a4', [qw(ID)]],
		'087A' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'02C4' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0108' => ['party_chat', 'x2 Z*', [qw(message)]],
		'0096' => ['private_message', 'x2 Z24 Z*', [qw(privMsgUser privMsg)]],
		'085B' => ['actor_info_request', 'a4', [qw(ID)]],
		'012E' => ['shop_close'],
		'0888' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'017E' => ['guild_chat', 'x2 Z*', [qw(message)]],
		'087D' => ['item_drop', 'v2', [qw(index amount)]],
		'094E' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0946' => ['character_move','a3', [qw(coords)]],
		'07D7' => ['party_setting', 'V C2', [qw(exp itemPickup itemDivision)]],

	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(
		guild_chat 017E
		map_login 02C4
		item_take 089D
		storage_item_remove 0888
		party_setting 07D7
		actor_action 0866
		sync 086D
		item_drop 087D
		private_message 0096
		public_chat 008C
		shop_open 01B2
		party_join_request_by_name 087A
		buy_bulk_vender 0801
		skill_select 0443
		homunculus_command 094E
		party_chat 0108
		actor_look_at 0944
		actor_info_request 085B
		character_move 0946
		shop_close 012E
		storage_item_add 0893
		skill_use_location 0202
		master_login 02B0

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
	if ($map_login)	{ $map_login = 0; } if ($enc_val1 != 0 && $enc_val2 != 0) 
	{
		my $oldMID = $MID;
		my $oldKey = ($enc_val1 >> 8 >> 8) & 0x7FFF;
		$enc_val1 = $enc_val1->bmul($enc_val3)->badd($enc_val2) & 0xFFFFFFFF;
		$MID = ($MID << 2) if (($MID << 2 << 3 << 6) == 0x04B000); $MID = ($MID ^ (($enc_val1 >>8 >> 8) & 0x7FFF)) &
		0xFFFF; $$r_message = pack("v", $MID) . substr($$r_message, 2);
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
		$msg = pack("v v", 0x956, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", 0x956, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
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
	$enc_val1 = Math::BigInt->new('0x1DE40099');
	# M
	$enc_val3 = Math::BigInt->new('0x5E6878E9');
	# A
	$enc_val2 = Math::BigInt->new('0x779357C0');
}

1;