#########################################################################
#  OpenKore - Network subsystem
#  This module contains functions for sending messages to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Servertype overvie: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType11;

use strict;
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync $net);
use Network::Send::ServerType0;
use Network::PaddedPackets;
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
	$self->sendToServer(Network::PaddedPackets::generateAtk($monID, $flag));
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xA2, 0x00) .
		pack("C*", 0x00, 0x00, 0x08, 0xA2) .
		pack("v*", $index) .
		pack("C*", 0x02, 0x97) .
		pack("v*", $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x94, 0x00) . pack("C*", 0x30, 0x03, 0x44, 0xA1) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA7, 0x00, 0x32, 0x06, 0x1C) . 
		pack("v*", $ID) .
		pack("C*", 0x00, 0xD8) .
		$targetID;
			
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
	
	$msg = pack("C*", 0x9B, 0x00, 0x33, 0x06, 0x00, 0x00, $head,
		0x00, 0x08, 0xA0, 0x30, 0x03, 0x00, 0x00, $body);
	
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	$msg = pack("C*", 0x72,0, 0, 0, 0xE8) .
		$accountID .
		pack("C*", 0xC3, 0x66, 0x00, 0xFF, 0xFF) .
		$charID .
		pack("C*", 0x12, 0x00) .
		$sessionID .
		pack("V", getTickCount()) .
		pack("C*",$sex);
		
	$self->sendToServer($msg);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg;
	
	$msg = pack("C*", 0x85, 0x00) . getCoordString($x, $y);

	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	
	$msg = pack("C*", 0x16, 0x01, 0x7F, 0x00, 0x04, 0xFA) .
		pack("v", $lv) .
		pack("C*", 0xBF) .
		pack("v*", $ID) .
		pack("C*", 0x00, 0x38, 0xB8, 0x94, 0x02, 0x28, 0xC1, 0x97,
		0x02, 0xC0, 0x44, 0xAA) .
		pack("v*", $x) . 
		pack("C*", 0x00) .
		pack("v*", $y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0xF3, 0x00, 0xEA, 0x73, 0x50, 0xF8) .
		pack("v", $index) .
		pack("C*", 0x50) .
		pack("V", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xF5, 0x00, 0xCC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) .
		pack("v*", $index) .
		pack("C*", 0x00, 0x00, 0x00, 0x00) .
		pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	
	$msg = pack("C*", 0x7E, 0x00);
	$msg .= pack("C*", 0x30, 0x00, 0x80,) if ($initialSync);
	$msg .= pack("C*", 0x00, 0x00, 0x80) if (!$initialSync);
	$msg .= $syncSync;
	
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0x9F, 0x00, 0x00, 0x00, 0x08) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

sub sendSit {
	my ($self) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSitStand(1));
	debug "Sitting\n", "sendPacket", 2;
}

sub sendStand {
	my ($self) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSitStand(0));
	debug "Standing\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSkillUse($ID, $lv,  $targetID));
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

1;
