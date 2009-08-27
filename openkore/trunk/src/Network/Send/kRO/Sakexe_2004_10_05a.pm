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
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Send::kRO::Sakexe_2004_10_05a;

use strict;
use Network::Send::kRO::Sakexe_2004_09_20a;
use base qw(Network::Send::kRO::Sakexe_2004_09_20a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 12;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,17,useitem,6:13
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x4 v x5 a4', 0x0072, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x007e,16,movetokafra,5:12
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x v x10 V', 0x007E, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x0089,6,walktoxy,3
sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack('v x2 a3', 0x0089, getCoordString($x, $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x008c,103,useskilltoposinfo,2:6:17:21:23
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v2 x2 v x9 v x2 v Z80', 0x008C, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}


# 0x0094,14,dropitem,5:12
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x3 v x5 v', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x009b,15,getcharnamerequest,11
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x9 a4', 0x008c, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a2,12,solvecharname,8
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x6 a4', 0x00a2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,23,useskilltopos,3:6:17:21
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;

	my $msg = pack('v x v x v x9 v x2 v', 0x008C, $lv, $ID, $x, $y);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x00f3,13,changedir,5:12
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x3 C x6 C', 0x00F3, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x00f5,33,wanttoconnection,12:18:24:28:32
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x10 a4 x2 a4 x2 a4 V C', 0x00F5, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x0113,10,takeitem,6
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x4 a4', 0x0113, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x0116,10,ticksend,6
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x4 V', 0x0116, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x0190,20,useskilltoid,7:12:16
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

	$msg = pack('v x5 V x v x2 a4', 0x0190, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0193,26,movefromkafra,10:22
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x8 v x10 V', 0x0193, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

=pod
//2004-10-05aSakexe
packet_ver: 12
0x0072,17,useitem,6:13
0x007e,16,movetokafra,5:12
0x0089,6,walktoxy,3
0x008c,103,useskilltoposinfo,2:6:17:21:23
0x0094,14,dropitem,5:12
0x009b,15,getcharnamerequest,11
0x00a2,12,solvecharname,8
0x00a7,23,useskilltopos,3:6:17:21
0x00f3,13,changedir,5:12
0x00f5,33,wanttoconnection,12:18:24:28:32
0x0113,10,takeitem,6
0x0116,10,ticksend,6
0x0190,20,useskilltoid,7:12:16
0x0193,26,movefromkafra,10:22
=cut

1;