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

package Network::Send::kRO::Sakexe_2005_01_10b;

use strict;
use Network::Send::kRO::Sakexe_2004_12_13a;
use base qw(Network::Send::kRO::Sakexe_2004_12_13a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char %config);

sub version {
	return 15;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,26,useskilltoid,8:16:22
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

	$msg = pack('v x7 V x4 v x4 a4', 0x0072, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x007e,114,useskilltoposinfo,10:18:22:32:34
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x8 v x6 v x2 v x8 v Z80', 0x007E, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0085,23,changedir,12:22
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x10 C x9 C', 0x0085, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x0089,9,ticksend,5
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x4 V', 0x0089, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x008c,8,getcharnamerequest,4
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x3 a4', 0x008c, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x0094,20,movetokafra,10:16
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x8 v x4 V', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x009b,32,wanttoconnection,3:12:23:27:31
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x a4 x5 a4 x7 a4 V C', 0x009B, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x009f,17,useitem,5:13
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x3 v x6 a4', 0x009F, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x00a2,11,solvecharname,7
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x5 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,13,walktoxy,10
sub sendMove {
	my ($self, $x, $y) = @_;
	my $msg = pack('v x8 a3', 0x00A7, getCoordString(int $x, int $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x00f3,-1,globalmessage,2:4
sub sendChat {
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});

	$data = pack('v2 Z*', 0x00F3, length($charName) + length($message) + 8, $charName . " : " . $message);

	$self->sendToServer($data);
}

# 0x00f5,9,takeitem,5
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x7 a4', 0x00F5, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x00f7,21,movefromkafra,11:17
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x9 v x4 V', 0x00F7, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x0113,34,useskilltopos,10:18:22:32
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x8 v x6 v x2 v x8 v', 0x0113, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0116,20,dropitem,15:18
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x13 v x v', 0x0116, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x0190,20,actionrequest,9:19
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

	my $msg = pack('v x7 a4 x6 C', 0x0190, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

# 0x0193,2,closekafra,0
sub sendStorageClose {
	$_[0]->sendToServer(pack('v', 0x0193));
	debug "Sent Storage Done\n", "sendPacket", 2;
}

=pod
//2005-01-10bSakexe
packet_ver: 15
0x0072,26,useskilltoid,8:16:22
0x007e,114,useskilltoposinfo,10:18:22:32:34
0x0085,23,changedir,12:22
0x0089,9,ticksend,5
0x008c,8,getcharnamerequest,4
0x0094,20,movetokafra,10:16
0x009b,32,wanttoconnection,3:12:23:27:31
0x009f,17,useitem,5:13
0x00a2,11,solvecharname,7
0x00a7,13,walktoxy,10
0x00f3,-1,globalmessage,2:4
0x00f5,9,takeitem,5
0x00f7,21,movefromkafra,11:17
0x0113,34,useskilltopos,10:18:22:32
0x0116,20,dropitem,15:18
0x0190,20,actionrequest,9:19
0x0193,2,closekafra,0
=cut

1;