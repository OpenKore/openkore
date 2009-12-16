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

package Network::Send::kRO::RagexeRE_2008_08_27a;

use strict;
use Network::Send::kRO::Sakexe_2008_09_10a;
use base qw(Network::Send::kRO::Sakexe_2008_09_10a); #looks weird, inheriting from a newer file... but this is what eA has and we want to be able to play on eA servers

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 24;
}

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

# 0x0072,22,useskilltoid,9:15:18
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

	$msg = pack('v x7 V x2 v x a4', 0x0072, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x007e,105,useskilltoposinfo,10:14:18:23:25
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x8 v x2 v x2 v x3 v Z80', 0x007E, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0085,10,changedir,4:9
sub sendLook {
	my ($self, $body, $head) = @_;
	my $msg = pack('v x2 C x4 C', 0x0085, $head, $body);
	$self->sendToServer($msg);
	debug "Sent look: $body $head\n", "sendPacket", 2;
	$char->{look}{head} = $head;
	$char->{look}{body} = $body;
}

# 0x0089,11,ticksend,7
sub sendSync {
	my ($self, $initialSync) = @_;
	my $msg;
	# XKore mode 1 lets the client take care of syncing.
	return if ($self->{net}->version == 1);

	$msg = pack('v x5 V', 0x0089, getTickCount());
	$self->sendToServer($msg);
	debug "Sent Sync\n", "sendPacket", 2;
}

# 0x008c,14,getcharnamerequest,10
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x8 a4', 0x008C, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x0094,19,movetokafra,3:15
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x v x10 V', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x009b,34,wanttoconnection,7:15:25:29:33
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v x5 a4 x4 a4 x6 a4 V C', 0x009B, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}

# 0x009f,20,useitem,7:20 -> 20 has to be 16?
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x5 v x7 a4', 0x009F, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x00a2,14,solvecharname,10
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x8 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,9,walktoxy,6
sub sendMove {
	my $self = shift;
	my $x = int scalar shift;
	my $y = int scalar shift;
	my $msg = pack('v x4 a3', 0x00A7, getCoordString($x, $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x00f5,11,takeitem,7
sub sendTake {
	my ($self, $itemID) = @_;
	my $msg = pack('v x5 a4', 0x00F5, $itemID);
	$self->sendToServer($msg);
	debug "Sent take\n", "sendPacket", 2;
}

# 0x00f7,17,movefromkafra,3:13
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x v x8 V', 0x00F7, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x0113,25,useskilltopos,10:14:18:23
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x8 v x2 v x2 v x3 v', 0x0113, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0116,17,dropitem,6:15
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x4 v x7 v', 0x0116, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x0190,23,actionrequest,9:22
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

	my $msg = pack('v x7 a4 x9 C', 0x0190, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent Action: " .$flag. " on: " .getHex($monID)."\n", "sendPacket", 2;
}


=pod
//2008-08-27aRagexeRE
packet_ver: 24
0x0072,22,useskilltoid,9:15:18
0x007c,44
0x007e,105,useskilltoposinfo,10:14:18:23:25
0x0085,10,changedir,4:9
0x0089,11,ticksend,7
0x008c,14,getcharnamerequest,10
0x0094,19,movetokafra,3:15
0x009b,34,wanttoconnection,7:15:25:29:33
0x009f,20,useitem,7:20
0x00a2,14,solvecharname,10
0x00a7,9,walktoxy,6
0x00f5,11,takeitem,7
0x00f7,17,movefromkafra,3:13
0x0113,25,useskilltopos,10:14:18:23
0x0116,17,dropitem,6:15
0x0190,23,actionrequest,9:22
0x02e2,20
0x02e3,22
0x02e4,11
0x02e5,9
=cut

1;