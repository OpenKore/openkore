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
package Network::Send::ServerType7;

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
	
	my %args;
	$args{monID} = $monID;
	$args{flag} = $flag;
	Plugins::callHook('packet_pre/sendAttack', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
	
	if (AI::action() eq "NPC") {
		error "Failed to talk to monster NPC.\n";
		AI::dequeue();
	} elsif (AI::action() eq "attack") {
		error "Failed to attack target.\n";
		AI::dequeue();
	}
}

sub sendSit {
	my $self = shift;

	my %args;
	$args{flag} = 2;
	Plugins::callHook('packet_pre/sendSit', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
	
	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "sitting") {
		error "Failed to sit.\n";
		AI::dequeue();
	}
}

sub sendStand {
	my $self = shift;

	my %args;
	$args{flag} = 3;
	Plugins::callHook('packet_pre/sendStand', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}	
	
	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq "standing") {
		error "Failed to stand.\n";
		AI::dequeue();
	}
}

sub sendSkillUse {
	my $self = shift;
	my $ID = shift;
	my $lv = shift;
	my $targetID = shift;
	
	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	error "Your server is not supported because it uses padded packets.\n";
	if (AI::action() eq 'teleport') {
		error "Failed to use teleport skill.\n";
		AI::dequeue();
	} elsif (AI::action() ne "skill_use") {
		error "Failed to use skill.\n";
		AI::dequeue();
	}
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xA2, 0x00) .
		pack("C*", 0x4B, 0x00, 0xB8, 0x00) .
		pack("v*", $index) .
		pack("C*", 0xC8, 0xFE, 0xB2, 0x07, 0x63, 0x01, 0x00) .
		pack("v*", $amount);

	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg;
	$msg = pack("C*", 0x94, 0x00) . pack("C*", 0x5B, 0x04, 0x0C, 0xF9, 0x12, 0x00, 0x36, 0xAE) . $ID;
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg;
	
	$msg = pack("C*", 0xA7, 0x00, 0x12, 0x00, 0xB0, 0x5A, 0x61) .
		pack("v*", $ID) .
		pack("C*", 0xFA, 0x12, 0x00, 0xDA, 0xF9, 0x12, 0x00) .
		$targetID;
			
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg;
	
	$msg = pack("C*", 0x9B, 0x00, 0x67, 0x00, $head,
		0x00, 0x5B, 0x04, 0xE2, $body);
	
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	
	$msg = pack("C*", 0x72, 0, 0, 0, 0, 0, 0) .
		$accountID .
		pack("C*", 0x00, 0x10, 0xEE, 0x65) .
		$charID .
		pack("C*", 0xFF, 0xCC, 0xFA, 0x12, 0x00, 0x61) .
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
	
	$msg = pack("C*", 0x85, 0x00, 0xA8, 0x07, 0xE8) . getCoordString($x, $y);
	
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg;
	
	$msg = pack("C*", 0x16, 0x01, 0x7F, 0x00, 0x04, 0xFA, 0x12, 0x00, 0xAF, 0x41) .
		pack("v", $lv) .
		pack("C*", 0x20, 0x09) .
		pack("v*", $ID) .
		pack("C*", 0xA8, 0xBE) .
		pack("v*", $x) . 
		pack("C*", 0x5B, 0x4E, 0xB4) .
		pack("v*", $y);
	
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg;
	
	$msg = pack("C*", 0xF3, 0x00, 0x1B) .
		pack("v", $index) .
		pack("C*", 0x88, 0xC5, 0x07, 0x00, 0x00, 0x00, 0x00, 0x7F, 0x0C, 0x7F) .
		pack("V", $amount);
	
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg;

	$msg = pack("C*", 0xF5, 0x00, 0x00) .
		pack("v*", $index) .
		pack("C*", 0x00, 0x00, 0x00, 0x60, 0xF7, 0x12, 0x00, 0xB8) .
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
	$msg .= pack("C*", 0x30, 0x00, 0x80, 0x02, 0x00) if ($initialSync);
	$msg .= pack("C*", 0x00, 0x00, 0xD0, 0x4F, 0x74) if (!$initialSync);
	$msg .= $syncSync;
	
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg;
	$msg = pack("C*", 0x9F, 0x00, 0x00, 0x00, 0xE8, 0x3C, 0x5B) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;
