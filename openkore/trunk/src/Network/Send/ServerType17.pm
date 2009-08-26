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
# tRO (Thai) for 2007-05-22bRagexe by kLabMouse (thanks to abt123, championrpg and penz for support)
# latest updaes will go here. Please don't use this ServerType for other servers except tRO.
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType17;

use strict;
use Globals;
use Network::Send::ServerType0;
use Network::PaddedPackets;
use base qw(Network::Send::ServerType0);
use Log qw(error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendAction {
	my ($self, $monID, $flag) = @_;
	$self->sendToServer(Network::PaddedPackets::generateAtk($monID, $flag));
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}
=pod
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
=cut

sub sendGameLogin { # 0275
	my ($self, $accountID, $sessionID, $sessionID2, $sex) = @_;
	my ($serv) = $masterServer->{ip} =~ /\d+\.\d+\.\d+\.(\d+)/;
	my $msg = pack("C2", 0x75, 0x02) . $accountID . $sessionID . $sessionID2 . pack("C*", 0, 0, $sex) . pack("x16 C1 x3", $serv);
	$self->sendToServer($msg);
	debug "Sent sendGameLogin\n", "sendPacket", 2;
}

sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	$self->sendToServer(Network::PaddedPackets::generateSkillUse($ID, $lv,  $targetID));
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

sub sendChat { # 00F3
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});
	$data = pack("C*", 0xF3, 0x00) .
		pack("v*", length($charName) + length($message) + 8) .
		$charName . " : " . $message . chr(0);
	$self->sendToServer($data);
}

sub sendDrop { # 009B
	my ($self, $index, $amount) = @_;
	my $msg = pack("C2 v1 v1", 0x9B, 0x00, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo { # 0190
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x90, 0x01) . $ID. pack("x1") ;

	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendGetCharacterName { # 00F5
        my ($self, $ID) = @_;
        my $msg = pack("S a4 x5", 0x00F5, $ID);
        $self->sendToServer($msg);
        debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse { # 0113
	my ($self, $ID, $targetID) = @_;
	my $msg = pack("C2", 0x13, 0x01) . $targetID. pack("v1", $ID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook { # 0072
	my ($self, $body, $head) = @_;
	my $msg = pack("C3 x1 C1", 0x72, 0x00, $head, $body);

	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin { # 008C
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack("C*", 0x8C, 0x00) .
			pack("x3") .
			$accountID .
			$charID .
			pack("x1") .
			$sessionID .
			pack("x4") .
			pack("V", getTickCount()) .
			pack("C*", $sex) .
			pack ("x2");
	$self->sendToServer($msg);
}

sub sendMove { # 00F7
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C2 x11", 0xF7, 0x00) . getCoordString($x, $y, 1);
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSkillUseLoc { # 009F
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack("v1 v1 x3 v1 v1 v1", 0x9F, $y, $lv, $ID, $x);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd { # 00A7
	my $self= shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C2 V1 x1 v1", 0xA7, 0x00, $amount, $index);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet { # 0094
	my ($self, $index, $amount) = @_;
	my $msg = pack("C2 v1 V1 x6", 0x94, 0x00, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageClose { # 0085
	my ($self) = @_;
	my $msg = pack("C*", 0x85, 0x00);
	$self->sendToServer($msg);
	debug "Sent Storage Done\n", "sendPacket", 2;
}

sub sendSync { # 007E
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$syncSync = pack("V", getTickCount());
	$msg = pack("C2 x1", 0x7E, 0x00) . $syncSync . pack("x5");

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake { # 0116
	my $self = shift;
	my $itemID = shift; # $itemID = long
	my $msg = pack("C2", 0x16, 0x01) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;
