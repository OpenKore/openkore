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

package Network::Send::kRO::Sakexe_2005_07_18a;

use strict;
use Network::Send::kRO::Sakexe_2005_06_28a;
use base qw(Network::Send::kRO::Sakexe_2005_06_28a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);


sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,19,useskilltoid,5:11:15
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

	$msg = pack('v x3 V x2 v x2 a4', 0x0072, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x007e,110,useskilltoposinfo,9:15:23:28:30
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x7 v x4 v x6 v x3 v Z80', 0x007E, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0085,11,changedir,6:10
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x4 C x3 C', 0x0085, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x0089,7,ticksend,3
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x V', 0x0089, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x008c,11,getcharnamerequest,7
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x5 a4', 0x008C, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x0094,21,movetokafra,12:17
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x10 v x3 V', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x009b,31,wanttoconnection,3:13:22:26:30
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x a4 x6 a4 x5 a4 V C', 0x009B, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x009f,12,useitem,3:8
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x v x3 a4', 0x009F, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x00a2,18,solvecharname,14
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x12 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,15,walktoxy,12
sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack('v x10 a3', 0x00A7, getCoordString($x, $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x00f5,7,takeitem,3
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x a4', 0x00F5, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x00f7,13,movefromkafra,5:9
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x3 v x2 V', 0x00F7, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x0113,30,useskilltopos,9:15:23:28
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x7 v x4 v x6 v x3 v', 0x0113, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0116,12,dropitem,6:10
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x4 v x2 v', 0x0113, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x0190,21,actionrequest,5:20
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

	my $msg = pack('v x3 a4 x11 C', 0x0190, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

# 0x023f,2,mailrefresh,0
sub sendMailboxOpen {
	$_[0]->sendToServer(pack('v', 0x023F));
	debug "Sent mailbox open.\n", "sendPacket", 2;
}

# 0x0241,6,mailread,2
sub sendMailRead {
	my ($self, $mailID) = @_;
	my $msg = pack('v V', 0x0241, $mailID);
	$self->sendToServer($msg);
	debug "Sent read mail.\n", "sendPacket", 2;
}

# 0x0243,6,maildelete,2
sub sendMailDelete {
	my ($self, $mailID) = @_;
	my $msg = pack('v V', 0x0243, $mailID);
	$self->sendToServer($msg);
	debug "Sent delete mail.\n", "sendPacket", 2;
}

# 0x0244,6,mailgetattach,2
sub sendMailGetAttach {
	my ($self, $mailID) = @_;
	my $msg = pack('v V', 0x0244, $mailID);
	$self->sendToServer($msg);
	debug "Sent mail get attachment.\n", "sendPacket", 2;
}

# 0x0246,4,mailwinopen,2
sub sendMailOperateWindow {
	my ($self, $window) = @_;
	my $msg = pack('v C x', 0x0246, $window);
	$self->sendToServer($msg);
	debug "Sent mail window.\n", "sendPacket", 2;
}

# 0x0247,8,mailsetattach,2:4
sub sendMailSetAttach {
	my $self = $_[0];
	my $amount = $_[1];
	my $index = (defined $_[2]) ? $_[2] : 0;	# 0 for zeny
	my $msg = pack('v2 V', 0x0247, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent mail set attachment.\n", "sendPacket", 2;
}

# 0x024b,4,auctioncancelreg,0
sub sendMailSend {
	my ($self, $receiver, $title, $message) = @_;
	my $msg = pack('v2 Z24 a40 C Z*', 0x0248, length($message)+70 , stringToBytes($receiver), stringToBytes($title), length($message), stringToBytes($message));
	$self->sendToServer($msg);
	debug "Sent mail send.\n", "sendPacket", 2;
}

# 0x024c,8,auctionsetitem,0
sub sendAuctionAddItem {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v2 V', 0x024C, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Auction Add Item.\n", "sendPacket", 2;
}

# 0x024e,6,auctioncancel,0
sub sendAuctionCancel {
	my ($self, $id) = @_;
	my $msg = pack('v V', 0x024E, $id);
	$self->sendToServer($msg);
	debug "Sent Auction Cancel.\n", "sendPacket", 2;
}

# 0x024f,10,auctionbid,0
sub sendAuctionBuy {
	my ($self, $id, $bid) = @_;
	my $msg = pack('v V2', 0x024F, $id, $bid);
	$self->sendToServer($msg);
	debug "Sent Auction Buy.\n", "sendPacket", 2;
}

=pod
//2005-07-18aSakexe
packet_ver: 18
0x0072,19,useskilltoid,5:11:15
0x007e,110,useskilltoposinfo,9:15:23:28:30
0x0085,11,changedir,6:10
0x0089,7,ticksend,3
0x008c,11,getcharnamerequest,7
0x0094,21,movetokafra,12:17
0x009b,31,wanttoconnection,3:13:22:26:30
0x009f,12,useitem,3:8
0x00a2,18,solvecharname,14
0x00a7,15,walktoxy,12
0x00f5,7,takeitem,3
0x00f7,13,movefromkafra,5:9
0x0113,30,useskilltopos,9:15:23:28
0x0116,12,dropitem,6:10
0x0190,21,actionrequest,5:20
0x0216,6
0x023f,2,mailrefresh,0
0x0240,8
0x0241,6,mailread,2
0x0242,-1
0x0243,6,maildelete,2
0x0244,6,mailgetattach,2
0x0245,7
0x0246,4,mailwinopen,2
0x0247,8,mailsetattach,2:4
0x0248,68
0x0249,3
0x024a,70
0x024b,4,auctioncancelreg,0
0x024c,8,auctionsetitem,0
0x024d,14
0x024e,6,auctioncancel,0
0x024f,10,auctionbid,0
0x0250,3
0x0251,2
0x0252,-1
=cut

1;