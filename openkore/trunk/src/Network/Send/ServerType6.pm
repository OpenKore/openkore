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
package Network::Send::ServerType6;

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
	
	$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x25) .
		$monID .
		pack("C*", 0x03, 0x04, 0x01, 0xb7, 0x39, 0x03, 0x00, $flag);
		
 	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xA2, 0x00, 0, 0) .
		pack("v*", $index) .
		pack("C*", 0x7f, 0x03, 0xD2, 0xf2) .
		pack("v*", $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x94, 0x00, 0x54, 0x00, 0x44, 0xc1, 0x4b, 0x02, 0x44) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA7, 0x00, 0x49).pack("v*", $ID).
		pack("C*", 0xfa, 0x12, 0x00, 0xdc, 0xf9, 0x12).$targetID;
			
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	$msg = pack("C*",0x72, 0x00, 0x00) .
		$accountID .
		pack("C*", 0x00, 0xe8, 0xfa) .
		$charID .
		pack ("C*", 0x65, 0x00, 0xff, 0xff, 0xff, 0xff) .
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
	
	$msg = pack("C*", 0x85, 0x00, 0x4b) . getCoordString($x, $y);
	
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSit {
	my $self = shift;
	my $msg;

	$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) .
		pack("C*", 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02);

	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;
	
	$msg = pack("v*", 0x0113, 0x0000, 0x0045, 0x00, $lv) .
		pack("v", 0) .
		pack("v*", $ID, 0) .
		pack("v", 0x0060) . $targetID;
	
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	
	$msg = pack("v*", 0x0116, 0x0000, $lv) .
		pack("v*", $ID, 0x1508) .
		pack("V*", 0, 0, 0) .
		pack("v*", $x, 0x1ad8, 0x76b4, $y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStand {
	my $self = shift;
	my $msg;
	
	$msg = pack("C*", 0x89, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) .
		pack("C*", 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03);
	
	$self->sendToServer($msg);
	debug "Standing\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	
	$msg = pack("C*", 0x7E, 0x00);
	$msg .= pack("C*", 0x30) if ($initialSync);
	$msg .= pack("C*", 0x94) if (!$initialSync);
	$msg .= $syncSync;

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0x9F, 0x00, 0x7f,) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;