#########################################################################
#  OpenKore - Network subsystem
#  Message sending
#
#  Copyright (c) 2005,2006,2007 OpenKore Team
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
package Network::Send::ServerType9;

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

sub sendAttack {
	my ($self, $monID, $flag) = @_;
	my $msg;
	
	$msg = pack("C*", 0x90, 0x01) . pack("x5") .
		$monID .
		pack("x6") . pack("C", $flag);
		
 	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendChat {
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});
	
	$data = pack("C*", 0xf3, 0x00) .
		pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
	
	$self->sendToServer($data);
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0x16, 0x01) . pack("x6") .
		pack("v*", $index) .
		pack("x5") .
		pack("v*", $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x8c, 0x00) . pack("x6") . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0x9f, 0x00) . pack("x7") .
		pack("v*", $ID) .
		pack("x9") .
		$targetID;
			
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
	
	$msg = pack("C*", 0x85, 0x00) . pack("x5") .
		pack("C*", $head, 0x00) . pack("x2") .
		pack("C*", $body);
	
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	$msg = pack("C*", 0x9b, 0) .
		pack("x7") .
		$accountID .
		pack("x8") .
		$charID .
		pack("x3") .
		$sessionID .
		pack("V", getTickCount()) .
		pack("C*", $sex);
		
	$self->sendToServer($msg);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg;
	
	$msg = pack("C*", 0xa7, 0x00) . pack("x9") .
		getCoordString($x, $y);
		
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSit {
	my $self = shift;
	my $msg;

	$msg = pack("C2 x15 C1", 0x90, 0x01, 0x02);

	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0x72, 0x00) . pack("x9") .
		pack("v*", $lv) . pack("x5") .
		pack("v*", $ID) . pack("x2") .
		$targetID;
	
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	
	$msg = pack("C*", 0x13, 0x01) .
		pack("x3") .
		pack("v*", $lv) .
		pack("x8") .
		pack("v*", $ID) .
		pack("x12") .
		pack("v*", $x) .
		pack("C*", 0x3D, 0xF8, 0xFA, 0x12, 0x00, 0x18, 0xEE) .
		pack("v*", $y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0x94, 0x00) . pack("x3") .
		pack("v*", $index) .
		pack("x12") .
		pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xf7, 0x00) . pack("x9") .
		pack("v*", $index) . pack("x9") .
		pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStand {
	my $self = shift;
	my $msg;
	
	$msg = pack("C*", 0x90, 0x01) . pack("x5") . pack("x4") . pack("x6") . pack("C", 0x03);
	
	$self->sendToServer($msg);
	debug "Standing\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	
	$msg = pack("C*", 0x89, 0x00);
	$msg .= pack("C*", 0x00, 0x00, 0x40) if ($initialSync);
	$msg .= pack("C*", 0x00, 0x00, 0x1F) if (!$initialSync);
	$msg .= pack("C*", 0x00, 0x00, 0x00, 0x90);
	$msg .= $syncSync;
	
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0xf5, 0x00) . pack("x7") . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;
