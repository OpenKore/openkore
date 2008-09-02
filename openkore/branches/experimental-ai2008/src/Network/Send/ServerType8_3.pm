#########################################################################
# OpenKore - Packet sending
# This module contains functions for sending packets to the server.
#
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#
# $Revision: 5761 $
# $Id: ServerType8.pm 5761 2007-06-26 12:25:48Z bibian $
# Modified by skseo, Jan-24-2007, Fixed bugs.
########################################################################
# legacyRO, after February 2008
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType8_3;

use strict;
use Globals qw($accountID $sessionID $sessionID2 $accountSex $char $charID %config %guild @chars $masterServer $syncSync $net);
use Network::Send::ServerType8;
use base qw(Network::Send::ServerType8);
use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack("C*", 0x14, 0x03, 0x00, 0x00) . getCoordString($x, $y);
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
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

	$msg = pack("C2 x16 C1", 0x11, 0x03, 0x02);
	$self->sendToServer($msg);
	debug "Sitting\n", "sendPacket", 2;
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

	$msg = pack("C*", 0x11, 0x03, 0x00, 0x00, 0x00) .
	$monID . pack("C*",0x00, 0x00, 0x00, 0x00, 0x37, 0x66, 0x61, 0x32, 0x00, $flag);
	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack("C*", 0x13, 0x03, 0x61, 0x62) .
	pack("v*", $ID) .
	pack("C*", 0x34, 0x35, 0x32, 0x61) .
	$targetID;
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
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

	$msg = pack("C2 x16 C1", 0x11, 0x03, 0x03);
	$self->sendToServer($msg);
	debug "Standing\n", "sendPacket", 2;
}

sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack("v1 x2", 0x12, 0x03) . $itemID;
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

1;