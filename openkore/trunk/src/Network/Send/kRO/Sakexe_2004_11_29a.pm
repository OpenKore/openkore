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

package Network::Send::kRO::Sakexe_2004_11_29a;

use strict;
use Network::Send::kRO::Sakexe_2004_11_15a;
use base qw(Network::Send::kRO::Sakexe_2004_11_15a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char %config);

sub version {
	return 14;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x072,22,useskilltoid,8:12:18
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

	$msg = pack('v x6 V v x2 a4', 0x0072, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x07e,30,useskilltopos,4:9:22:28
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;

	my $msg = pack('v x2 v x3 v x11 v x4 v', 0x007E, $lv, $ID, $x, $y);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x085,-1,globalmessage,2:4
sub sendChat {
	my ($self, $message) = @_;
	$message = "|00$message" if ($config{chatLangCode} && $config{chatLangCode} ne "none");

	my ($data, $charName); # Type: Bytes
	$message = stringToBytes($message); # Type: Bytes
	$charName = stringToBytes($char->{name});

	$data = pack('v2 Z*', 0x0085, length($charName) + length($message) + 8, $charName . " : " . $message);

	$self->sendToServer($data);
}

# 0x089,7,ticksend,3
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x V', 0x0089, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x08c,13,getcharnamerequest,9
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x7 a4', 0x008C, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x094,14,movetokafra,4:10
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x2 v x4 V', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x09b,2,closekafra,0
sub sendStorageClose {
	$_[0]->sendToServer(pack('v', 0x009B));
	debug "Sent Storage Done\n", "sendPacket", 2;
}

# 0x09f,18,actionrequest,6:17
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

	my $msg = pack('v x4 a4 x7 C', 0x009F, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}

# 0x0a2,7,takeitem,3
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x a4', 0x00A2, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x0a7,7,walktoxy,4
sub sendMove {
	my ($self, $x, $y) = @_;
	my $msg = pack('v x2 a3', 0x00A7, getCoordString(int $x, int $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x0f3,8,changedir,3:7
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x C x3 C', 0x00F3, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x0f5,29,wanttoconnection,3:10:20:24:28
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x a4 x3 a4 x6 a4 V C', 0x00F5, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x0f7,14,solvecharname,10
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x8 a4', 0x00F7, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x113,110,useskilltoposinfo,4:9:22:28:30
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x2 v x3 v x11 v x4 v Z80', 0x0113, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x116,12,dropitem,4:10
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x2 v x4 v', 0x0116, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x190,15,useitem,3:11
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x v x6 a4', 0x0190, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x193,21,movefromkafra,4:17
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x2 v x11 V', 0x0193, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x222,6,weaponrefine,2
sub sendWeaponRefine {
	my ($self, $index) = @_;
	my $msg = pack('v V', 0x0222, $index);
	$self->sendToServer($msg);
	debug "Sent Weapon Refine.\n", "sendPacket", 2;
}

=pod
//2004-11-29aSakexe
packet_ver: 14
0x0072,22,useskilltoid,8:12:18
0x007e,30,useskilltopos,4:9:22:28
0x0085,-1,globalmessage,2:4
0x0089,7,ticksend,3
0x008c,13,getcharnamerequest,9
0x0094,14,movetokafra,4:10
0x009b,2,closekafra,0
0x009f,18,actionrequest,6:17
0x00a2,7,takeitem,3
0x00a7,7,walktoxy,4
0x00f3,8,changedir,3:7
0x00f5,29,wanttoconnection,3:10:20:24:28
0x00f7,14,solvecharname,10
0x0113,110,useskilltoposinfo,4:9:22:28:30
0x0116,12,dropitem,4:10
0x0190,15,useitem,3:11
0x0193,21,movefromkafra,4:17
0x0221,-1
0x0222,6,weaponrefine,2
0x0223,8
=cut

1;