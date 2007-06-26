#########################################################################
#  OpenKore - Packet sending
#  This module contains functions for sending packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Servertype overvie: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType4;

use strict;
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync $net);
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xA2, 0x00, 0x39, 0x33, 0x68, 0x3B, 0x68, 0x3B, 0x6E, 0x0A, 0xE4, 0x16) .
			$ID;
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendAttack {
	my ($self, $monID, $flag) = @_;
	my $msg;
	
	$msg = pack("C*", 0x85, 0x00, 0x60, 0x60) .
		$monID .
		pack("C*", 0x64, 0x64, 0x3E, 0x63, 0x67, 0x37, $flag);
		
 	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendChat {
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});
	
	$data = pack("C*", 0x9F, 0x00) .
		pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
	
	$self->sendToServer($data);
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0x94, 0x00) .
		pack("C*", 0x61, 0x62, 0x34, 0x11) .
		pack("v*", $index) .
		pack("C*", 0x67, 0x64) .
		pack("v*", $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x9B, 0x00) . pack("C*", 0x66, 0x3C, 0x61, 0x62) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	$msg = pack("C*", 0x72, 0x00, 0x65, 0x36, 0x65).pack("v*", $ID).pack("C*", 0x64, 0x37).$targetID;
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
	
	$msg = pack("C*", 0xF3, 0x00, 0x62, 0x32, 0x31, 0x33, $head,
		0x00, 0x60, 0x30, 0x33, 0x31, 0x31, 0x31, $body);
	
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	$msg = pack("C*", 0xF5, 0x00, 0xFF, 0xFF, 0xFF) .
		$accountID .
		pack("C*", 0xFF, 0xFF, 0xFF, 0xFF, 0xFF) .
		$charID .
		pack("C*", 0xFF, 0xFF) .
		$sessionID .
		pack("V1", getTickCount()) .
		pack("C*", $sex);

	$self->sendToServer($msg);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg;
	
	$msg = pack("C*", 0x89, 0x00) . getCoordString($x, $y);
	
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSit {
	my $self = shift;
	my $msg;

	$msg = pack("C*", 0x85, 0x00, 0x61, 0x32, 0x00, 0x00, 0x00 ,0x00 ,0x65,
		0x36, 0x37, 0x34, 0x32, 0x35, 0x02);

	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0x90, 0x01, 0x64, 0x63) .
		pack("v*", $lv) .
		pack("C*", 0x62, 0x65, 0x66, 0x67) .
		pack("v*", $ID) .
		pack("C*", 0x6C, 0x6B, 0x68, 0x69, 0x3D, 0x6E, 0x3C, 0x0A, 0x95, 0xE3) .
		$targetID;
	
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA7, 0x00, 0x37, 0x65, 0x66, 0x60) . pack("v*", $lv) .
		pack("C*", 0x32) . pack("v*", $ID) .
		pack("C*", 0x3F, 0x6D, 0x6E, 0x68, 0x3D, 0x68, 0x6F, 0x0C, 0x0C, 0x93, 0xE5, 0x5C) .
		pack("v*", $x) . chr(0) . pack("v*", $y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0x7E, 0x00) . pack("C*", 0x35, 0x34, 0x3D, 0x65) .
		pack("v", $index) .
		pack("C", 0x30) .
		pack("V", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0x93, 0x01, 0x3B, 0x3A, 0x33, 0x69, 0x3B, 0x3B, 0x3E, 0x3A, 0x0A, 0x0A) .
		pack("v*", $index) .
		pack("C*", 0x35, 0x34, 0x3D, 0x67) .
		pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStand {
	my $self = shift;
	my $msg;
	
	$msg = pack("C*", 0x85, 0x00, 0x61, 0x32, 0x00, 0x00, 0x00, 0x00,
		0x65, 0x36, 0x30, 0x63, 0x35, 0x3F, 0x03);
	
	$self->sendToServer($msg);
	debug "Standing\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	
	$msg = pack("C*", 0x16, 0x01);
	$msg .= pack("C*", 0x61, 0x3A) if ($initialSync);
	$msg .= pack("C*", 0x61, 0x62) if (!$initialSync);
	$msg .= $syncSync;
	$msg .= pack("C*", 0x0B);
	
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0x13, 0x01, 0x61, 0x60, 0x3B) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;