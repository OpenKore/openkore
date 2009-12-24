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

package Network::Send::kRO::Sakexe_2004_09_20a;

use strict;
use Network::Send::kRO::Sakexe_2004_09_06a;
use base qw(Network::Send::kRO::Sakexe_2004_09_06a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 11;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,18,useitem,10:14
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x8 v x2 a4', 0x0072, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x007e,25,movetokafra,6:21
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x4 v x13 V', 0x007E, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x0085,9,actionrequest,3:8
sub sendAction { # flag: 0 attack (once), 7 attack (continuous), 2 sit, 3 stand
	my ($self, $monID, $flag) = @_;

	my %args;
	$args{monID} = $monID;
	$args{flag} = $flag;
	# eventually we'll trow this hooking out so...
	Plugins::callHook('packet_pre/sendAttack', \%args) if ($flag == 0 || $flag == 7);
	Plugins::callHook('packet_pre/sendSit', \%args) if ($flag == 2 || $flag == 3);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	my $msg = pack('v x a4 x C', 0x0085, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

# 0x0089,14,walktoxy,11
sub sendMove {
	my ($self, $x, $y) = @_;
	my $msg = pack('v x9 a3', 0x0089, getCoordString(int $x, int $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x008c,109,useskilltoposinfo,16:20:23:27:29
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x14 v x2 v x v x2 v Z80', 0x008C, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0094,19,dropitem,12:17
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x10 v x5 v', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x009b,10,getcharnamerequest,6
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x4 a4', 0x008c, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a2,10,solvecharname,6
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x4 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,29,useskilltopos,6:20:23:27
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x14 v x2 v x v x2 v', 0x00A7, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x00f3,18,changedir,8:17
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x6 C x8 C', 0x00F3, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x00f5,32,wanttoconnection,10:17:23:27:31
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x8 a4 x3 a4 x2 a4 x V C', 0x00F5, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x0113,14,takeitem,10
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x8 a4', 0x0113, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x0116,14,ticksend,10
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x8 V', 0x0116, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x0190,14,useskilltoid,4:7:10
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

	$msg = pack('v x2 v x v x a4', 0x0190, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0193,12,movefromkafra,4:8
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x2 v x2 V', 0x0193, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

=pod
//2004-09-20aSakexe
packet_ver: 11
0x0072,18,useitem,10:14
0x007e,25,movetokafra,6:21
0x0085,9,actionrequest,3:8
0x0089,14,walktoxy,11
0x008c,109,useskilltoposinfo,16:20:23:27:29
0x0094,19,dropitem,12:17
0x009b,10,getcharnamerequest,6
0x00a2,10,solvecharname,6
0x00a7,29,useskilltopos,6:20:23:27
0x00f3,18,changedir,8:17
0x00f5,32,wanttoconnection,10:17:23:27:31
0x0113,14,takeitem,10
0x0116,14,ticksend,10
0x0190,14,useskilltoid,4:7:10
0x0193,12,movefromkafra,4:8
=cut

1;