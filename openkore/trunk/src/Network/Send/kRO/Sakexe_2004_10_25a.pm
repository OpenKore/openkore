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

package Network::Send::kRO::Sakexe_2004_10_25a;

use strict;
use Network::Send::kRO::Sakexe_2004_10_05a;
use base qw(Network::Send::kRO::Sakexe_2004_10_05a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,13,useitem,5:9
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x3 v x2 a4', 0x0072, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x007e,13,movetokafra,6:9
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x4 v x V', 0x007E, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x0085,15,actionrequest,4:14
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

	my $msg = pack('v x2 a4 x6 C', 0x0085, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

# 0x008c,108,useskilltoposinfo,6:9:23:26:28
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x4 v x v x12 v x v Z80', 0x008C, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0094,12,dropitem,6:10
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x4 v x7 v', 0x0094, $index, $amount);
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

# 0x00a2,16,solvecharname,12
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x10 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,28,useskilltopos,6:9:23:26
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x4 v x v x12 v x v', 0x00A7, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x00f3,15,changedir,6:14
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x4 C x9 C', 0x00F3, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x00f5,29,wanttoconnection,5:14:20:24:28
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x4 a4 x5 a4 x a4 V C', 0x00F5, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x0113,9,takeitem,5
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x4 a4', 0x0113, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x0116,9,ticksend,5
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x4 V', 0x0116, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x0190,26,useskilltoid,4:10:22
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

	$msg = pack('v x3 V x2 v x10 a4', 0x0190, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0193,22,movefromkafra,12:18
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x10 v x4 V', 0x0193, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

=pod
//2004-10-25aSakexe
packet_ver: 13
0x0072,13,useitem,5:9
0x007e,13,movetokafra,6:9
0x0085,15,actionrequest,4:14
0x008c,108,useskilltoposinfo,6:9:23:26:28
0x0094,12,dropitem,6:10
0x009b,10,getcharnamerequest,6
0x00a2,16,solvecharname,12
0x00a7,28,useskilltopos,6:9:23:26
0x00f3,15,changedir,6:14
0x00f5,29,wanttoconnection,5:14:20:24:28
0x0113,9,takeitem,5
0x0116,9,ticksend,5
0x0190,26,useskilltoid,4:10:22
0x0193,22,movefromkafra,12:18
=cut

1;