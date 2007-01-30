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
# vRO (Vietnam)
package Network::Send::ServerType10;

use strict;
use Network::Send::ServerType0;
use base qw(Network::Send::ServerType0);

use Plugins;
use Log qw(debug);
use Utils qw(getTickCount getCoordString getHex);

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
	$msg = pack("C2 x3", 0x89, 0x00, 0x00, 0x00, 0x00). $monID. pack("x9 C1", $flag);

	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C2 v1 v1", 0x89, 0x00, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack("C*", 0xF5, 0x00) . $ID . pack("C*", 0x00, 0x00, 0x00); 
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	my $msg = pack("C*",0x9b, 0x00, 0x00) .
		$accountID .
		$charID .
		$sessionID .
		pack("C*",0x35, 0x32, 0x61, 0x00) .
		pack("V", getTickCount()) .
		pack("C*",0x35, 0x00) .
		pack("C*", $sex) .
		pack("C*", 0x35, 0x36, 0x00);
	$self->sendToServer($msg);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;

	my $msg = pack("C*", 0x13, 0x01, 0x61, 0x38, 0x39, 0x34, 0x00) .
		getCoordString($x, $y, 1) . pack("C*", 0x39, 0x32, 0x00);

	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack("C*", 0xA7, 0x00) . pack("v", $lv) . pack("v*", $ID) . pack("v*", $x) . pack("x4") . pack("v*", $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0x7E, 0x00) . pack("v", $index) . pack("C*", 0x00) . pack("V", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack("C*", 0xF7, 0x00) . pack("v", $index) . pack("x12") . pack("V*", $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

sub sendSync {
	my ($self, $initialSync) = @_;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	my $msg = pack("C*", 0xF3, 0x00, 0x00);
	$msg .= pack("V", getTickCount());
	$msg .= pack("C*", 0x39, 0x63, 0x62, 0x00);

	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

sub sendTake {
	my $self = shift;
	my $itemID = shift; # $itemID = long
	my $msg = pack("C*", 0x16, 0x01) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;
