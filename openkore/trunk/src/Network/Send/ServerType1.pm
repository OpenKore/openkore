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
# oRO (Oceania/Australia), as of February 2006.
package Network::Send::ServerType1;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendAttack {
	my ($self, $monID, $flag) = @_;
	my $msg;

	my %args;
	$args{monID} = $monID;
	$args{flag} = $flag;
	Plugins::callHook('packet_pre/sendAttack', \%args);
	
	$msg = pack("C*", 0x89, 0x00, 0x00, 0x00).
		$monID .
		pack("C*", 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, $flag);
	
	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}
	
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA2, 0x00) .
			pack("C*", 0xFF, 0xFF, 0x08, 0x10) .
			pack("v*", $index) .
			pack("C*", 0xD2, 0x9B) .
			pack("v*", $amount);
			
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}
	
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x94, 0x00) . pack("C*", 0x12, 0x00, 150, 75) . $ID;
	
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}
	
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA7, 0x00, 0x9A, 0x12, 0x1C).pack("v*", $ID, 0).$targetID;
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}
	
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
		$msg = pack("C*", 0x9B, 0x00, 0xF2, 0x04, 0xC0, 0xBD, $head,
					0x00, 0xA0, 0x71, 0x75, 0x12, 0x88, 0xC1, $body);	
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

	sub sendMapLogin {	
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;

	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	$key = pack("C*", 0xFC, 0x2B, 0x8B, 0x01, 0x00);
	#	0xFA,0x12,0x00,0xE0,0x5D
	#	0xFA,0x12,0x00,0xD0,0x7B
	$msg = pack("C*", 0x72, 0, 0, 0, 0) . $accountID . $key . $charID .	pack("C*", 0xFF, 0xFF) .
				$sessionID . pack("V", getTickCount()) . pack("C", $sex);
	$self->sendToServer($msg);
}

sub sendSit {
	my $self = shift;
	my $msg;

	my %args;
	$args{flag} = 2;
	Plugins::callHook('packet_pre/sendSit', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
		
	$msg = pack("C*", 0x89, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00,0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x02);
	
	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
}
	
sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my $msg;
	
	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
}
	
	$msg = pack("v*", 0x0113, 0x0000, $lv) .
			pack("V", 0) .
			pack("v*", $ID, 0) .
			pack("V*", 0, 0) . $targetID;
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}
	
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	$msg = pack("v*", 0x0116, 0x0000, 0x0000, $lv) .
			chr(0) . pack("v*", $ID) .
			pack("V*", 0, 0, 0) .
			pack("v*", $x) . chr(0) . pack("v*", $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}
	
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xF3, 0x00) . pack("C*", 0x12, 0x00, 0x40, 0x73) .
		pack("v", $index) .
		pack("C", 0xFF) .
		pack("V", $amount);	
		
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}
	
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;
	$msg = pack("v*", 0x00F5, 0, 0, 0, 0, 0, $index, 0, 0) . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;	
}
	
sub sendStand {
	my $self = shift;
	my $msg;

	my %args;
	$args{flag} = 3;
	Plugins::callHook('packet_pre/sendStand', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
	
	$msg = pack("C*", 0x89, 0x00, 0x00, 0xFF, 0x00, 0x00, 0x00, 0x00,
				0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x03);
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
	$msg .= pack("C*", 0x30, 0x00, 0x40) if ($initialSync);
	$msg .= pack("C*", 0x00, 0x00, 0x1F) if (!$initialSync);
	$msg .= $syncSync;	
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0x9F, 0x00, 0x00, 0x00, 0x68) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;	
}
1;