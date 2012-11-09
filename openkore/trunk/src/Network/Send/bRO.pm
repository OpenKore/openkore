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
		'035F' => ['sync', 'V', [qw(time)]],
		'0108' => ['party_chat', 'x2 Z*', [qw(message)]],
		'0890' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'0932' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'012E' => ['shop_close'],
		'0892' => ['actor_look_at', 'v C', [qw(head body)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'07E4' => ['item_take', 'a4', [qw(ID)]],
		'09CB' => ['private_message', 'x2 Z24 Z*', [qw(privMsgUser privMsg)]],
		'0443' => ['skill_select', 'V v', [qw(why skillID)]],
		'017E' => ['guild_chat', 'x2 Z*', [qw(message)]],
		'0364' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0437' => ['character_move','a3', [qw(coords)]],
		'008C' => ['public_chat', 'x2 Z*', [qw(message)]],
		'0362' => ['item_drop', 'v2', [qw(index amount)]],
		'0802' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'07EC' => ['storage_item_add', 'v V', [qw(index amount)]],
		'07D7' => ['party_setting', 'V C2', [qw(exp itemPickup itemDivision)]],
		'01B2' => ['shop_open'],

	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;	
	
	my %handlers = qw(
		skill_use_location 0438
		public_chat 008C
		guild_chat 017E
		private_message 09CB
		storage_item_add 07EC
		actor_look_at 0892
		homunculus_command 0932
		party_setting 07D7
		buy_bulk_vender 0801
		actor_action 0369
		sync 035F
		actor_info_request 096A
		shop_open 01B2
		item_take 07E4
		item_drop 0362
		shop_close 012E
		skill_select 0443
		party_join_request_by_name 0802
		party_chat 0108
		character_move 0437
		master_login 02B0
		storage_item_remove 0364
		map_login 0890

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
		$msg = pack("v v", 0x368, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack("v v", 0x368, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
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
	$enc_val1 = Math::BigInt->new('0x350F3DF0');
	# M
	$enc_val3 = Math::BigInt->new('0x46237A85');
	# A
	$enc_val2 = Math::BigInt->new('0x443C7060');
}

1;