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
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType3;

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
	my $msg = pack("C*", 0xa2, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) . $ID;
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendAttack {
	my ($self, $monID, $flag) = @_;
	my $msg;
	
	$msg = pack("C*", 0x90, 0x01, 0xc7, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) .
		$monID .
		pack("C*", 0x00, 0x00, 0x21, 0x00, 0x00, 0x00, $flag);
		
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

	$msg = pack("C*", 0x16, 0x01) .
		pack("C*", 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00) .
		pack("C*", 0xc7, 0x00, 0x98, 0xe5, 0x12) .
		pack("v*", $index) .
		pack("C*", 0x00) .
		pack("v*", $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x8c, 0x00, 0x12, 0x00) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0x9f, 0x00, 0x12, 0x00, 0x00) .
		pack("v*", $ID) .
		pack("C*", 0x20, 0x60, 0xfb, 0x12, 0x00, 0x1c) .
		$targetID;
		
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
	
	$msg = pack("C*", 0x85, 0x00, 0xff, 0xff, 0x9c, 0xfb, 0x12, 0x00, 0xc1, 0x12, 0x60, 0x00) .
		pack("C*", $head, 0x00, 0x72, 0x21, 0x3d, 0x33, 0x52, 0x00, 0x00, 0x00) .
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
	
	$msg = pack("C*", 0x9b, 0, 0) .
		$accountID .
		pack("C*", 0, 0, 0, 0, 0) .
		$charID .
		pack("C*", 0x50, 0x92, 0x61, 0x00) . #not sure what this is yet (maybe $key?)
		pack("C*", 0xff, 0xff, 0xff) .
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
	
	$msg = pack("C*", 0xA7, 0x00, 0x60, 0x00, 0x00, 0x00) .
		pack("C*", 0xC7, 0x00, 0x00, 0x00) .
		getCoordString($x, $y);
	
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSit {
	my $self = shift;
	my $msg;

	$msg = pack("C*", 0x90, 0x01, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00,
  	0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00,
		0x00, 0x00, 0x00, 0x02);

	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0x72, 0x00, 0x83, 0x7C, 0xD8, 0xFE, 0x80, 0x7C) .
		pack("v*", $lv) .
		pack("C*", 0xFF, 0xFF, 0xCF, 0xFE, 0x80, 0x7C) .
		pack("v*", $ID) .
		pack("C*", 0x6A, 0x0F, 0x00, 0x00) .
		$targetID;
	
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	
	$msg = pack("C*", 0x13, 0x01, 0xbe, 0x44, 0x00, 0x00, 0xa0, 0xc0, 0x00, 0x00) .
		pack("v*", $lv) .
		pack("C*", 0x00, 0x00, 0xa0, 0x40, 0x00, 0x00) .
		pack("v*", $ID) .
		pack("C*", 0x00, 0x00) .
		pack("v*", $x) .
		pack("C*", 0x00, 0x00, 0xa0, 0x40, 0xe0, 0x80, 0x09, 0xc2) .
		pack("v*", $y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0x94, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00) .
		pack("v*", $index) .
		pack("C*", 0x00, 0x00, 0x00, 0x00) .
		pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0xf7, 0x00, 0x00, 0x00) .
		pack("V*", getTickCount()) .
		pack("C*", 0x00, 0x00, 0x00) .
		pack("v*", $index) .
		pack("C*", 0x00, 0x00, 0x00, 0x00) .
		pack("V*", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStand {
	my $self = shift;
	my $msg;
	
	$msg = pack("C*", 0x90, 0x01, 0x00, 0x00, 0x00, 0x00 ,0x00 ,0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x03);
	
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
	$msg .= pack("C*", 0x30, 0x00, 0x40) if ($initialSync);
	$msg .= pack("C*", 0x00, 0x00, 0x1F) if (!$initialSync);
	$msg .= $syncSync;

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0xf5, 0x00, 0x00, 0x00, 0xb8) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;