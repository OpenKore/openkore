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

package Network::Send::kRO::Sakexe_2004_08_09a;

use strict;
use Network::Send::kRO::Sakexe_2004_07_26a;
use base qw(Network::Send::kRO::Sakexe_2004_07_26a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,17,dropitem,8:15
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x6 v x5 v', 0x0072, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x007e,37,wanttoconnection,9:21:28:32:36
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x7 a4 x8 a4 x3 a4 V C', 0x007E, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x0085,26,useskilltoid,11:18:22
sub sendSkillUse {
	my ($self, $ID, $lv, $targetID) = @_;
	my %args;
	$args{ID} = $ID;
	$args{lv} = $lv;
	$args{targetID} = $targetID;
	Plugins::callHook('packet_pre/sendSkillUse', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}
	my $msg = pack('v x9 V x3 v x2 a4', 0x0085, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0089,12,getcharnamerequest,8
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x6 a4', 0x008c, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x008c,40,useskilltopos,5:15:29:38
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x3 v x8 v x12 v x7 v', 0x008C, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0094,13,takeitem,9
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x7 a4', 0x0094, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x009b,15,walktoxy,12
sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack('v x10 a3', 0x009B, getCoordString($x, $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x009f,12,changedir,7:11
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x5 C x3 C', 0x009F, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x00a2,120,useskilltoposinfo,5:15:29:38:40
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x3 v x8 v x12 v x7 v Z80', 0x00A2, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x00a7,11,solvecharname,7
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x5 a4', 0x00a7, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00f5,24,useitem,9:20
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x7 v x9 a4', 0x00F5, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x00f7,13,ticksend,9
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x7 V', 0x00F7, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x0113,23,movetokafra,5:19
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x3 v x12 V', 0x0113, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x0190,26,movefromkafra,11:22
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x9 v x9 V', 0x0190, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x0193,18,actionrequest,7:17
sub sendAttack {
	my ($self, $monID, $flag) = @_;
	my %args;

	$args{monID} = $monID;
	$args{flag} = $flag;
	Plugins::callHook('packet_pre/sendAttack', \%args);
	if ($args{return}) {
		$self->sendToServer($args{msg});
		return;
	}

	my $msg = pack('v x5 a4 x6 C', 0x0193, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}

=pod
//2004-08-09aSakexe
packet_ver: 9
0x0072,17,dropitem,8:15
0x007e,37,wanttoconnection,9:21:28:32:36
0x0085,26,useskilltoid,11:18:22
0x0089,12,getcharnamerequest,8
0x008c,40,useskilltopos,5:15:29:38
0x0094,13,takeitem,9
0x009b,15,walktoxy,12
0x009f,12,changedir,7:11
0x00a2,120,useskilltoposinfo,5:15:29:38:40
0x00a7,11,solvecharname,7
0x00f5,24,useitem,9:20
0x00f7,13,ticksend,9
0x0113,23,movetokafra,5:19
0x0190,26,movefromkafra,11:22
0x0193,18,actionrequest,7:17
=cut

1;