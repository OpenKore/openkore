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
# euRO (Europe) as of December 20 2006
package Network::Send::ServerType16;

use strict;
use Globals qw($char $syncSync $net);
use Network::Send::ServerType11;
use base qw(Network::Send::ServerType11);
use Log qw(error debug);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0xA2, 0x00, 0x4B, 0x00, 0x98) .
		pack("v1", $index) .
		pack("C*", 0x03) .
	pack("v1", $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0x94, 0x00) . pack("C*", 0x12, 0x05, 0x0C, 0x7B, 0x12) . $ID;

	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack("C*", 0xA7, 0x00, 0x81, 0x06) .
		pack("v*", $ID) .
		pack("C*", 0x12, 0x00, 0x68, 0xF7) .
		$targetID;
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack("C*", 0x9B, 0x00, 0x01, 0x02, 0x98, 0x35, 0x5D, $head, 0x00, 0xE8, $body);

	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack("C*", 0x72, 0, 0, 0) .
			$accountID .
			pack("C*", 0x50) .
			$charID .
			pack("C*", 0xFF, 0xFF, 0xFF, 0xCC) .
			$sessionID .
			pack("V", getTickCount()) .
			pack("C*", $sex);
	$self->sendToServer($msg);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C*", 0x85, 0x00, 0x5D, 0x03) . getCoordString($x, $y);
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack("C*", 0x16, 0x01, 0x2C, 0x00, 0x1F) .
			pack("v", $lv) .
			pack("C*", 0x00, 0x98) .
			pack("v*", $ID) .
			pack("C*", 0x03) .
			pack("v*", $x) .
			pack("C*", 0x69, 0x03, 0xC0, 0x44, 0xAA, 0x76) .
			pack("v*", $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my $self= shift;
	my $index = shift;
	my $amount = shift;
	my $msg = pack("C*", 0xF3, 0x00, 0x6E, 0x05, 0x78, 0xD1, 0x00) .
			pack("v", $index) .
			pack("C*", 0xE5) .
			pack("V", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0xF5, 0x00, 0x00, 0x00, 0x10, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00) .
			pack("v*", $index) .
			pack("C*", 0x21, 0x7E) .
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
	$msg = pack("C*", 0x7E, 0x00)
		. pack("C*", 0x00, 0x00)
		. $syncSync;

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my $self = shift;
	my $itemID = shift; # $itemID = long
	my $msg = pack("C*", 0x9F, 0x00, 0x5D, 0x03) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;
