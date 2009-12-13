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
########################################################################
#  kRO Client 2009-02-25b (eA packet version 23)
# Servertype overview: http://www.openkore.com/wiki/index.php/ServerType
package Network::Send::ServerType8_4;

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

=pod
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

	my $msg = pack('v x7 a4 x9 C', 0x0190, $monID, $flag);
	$self->sendToServer($msg);
	debug "Sent attack: ".getHex($monID)."\n", "sendPacket", 2;
}
=cut


# version 24
sub sendMapLogin {
	my ($self, $accountID, $charID, $sessionID, $sex) = @_;
	$sex = 0 if ($sex > 1 || $sex < 0); # Sex can only be 0 (female) or 1 (male)
	my $msg = pack('v a4 a4 a4 V C', 0x0436, $accountID, $charID, $sessionID, getTickCount(), $sex);
	$self->sendToServer($msg);
}


=pod
//2008-08-27aRagexeRE
packet_ver: 23
0x0072,22,useskilltoid,9:15:18
0x007c,44
0x007e,105,useskilltoposinfo,10:14:18:23:25	//Test
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

//2008-09-10aRagexeRE
packet_ver: 24
0x0436,19,wanttoconnection,2:6:10:14:18
0x0437,7,actionrequest,2:6
0x0438,10,useskilltoid,2:4:6
0x0439,8,useitem,2:4

//2008-11-12aRagexeRE
0x043d,8
//0x043e,-1
0x043f,8

//2008-12-17aRagexeRE
0x01a2,37
//0x0440,10
//0x0441,4
//0x0442,8
//0x0443,8

//2008-12-17bRagexeRE


0x006d,114

//2009-01-21aRagexeRE
0x043f,25
//0x0444,-1

//0X0445,10

//2009-02-18aRagexeRE
//0x0446,14

//2009-02-26cRagexeRE
//0x0448,-1

//2009-03-25dRagexeRE

//0x2a6,404
//0x2a7,404

//2009-04-01aRagexeRE
//0x0449,4

//2009-04-08aRagexeRE
//0x02a6,-1
//0x02a7,-1
0x044a,6

//2009-05-14aRagexeRE
//0x044b,2

//2009-05-20aRagexeRE
//0x07d0,6
//0x07d1,2
//0x07d2,-1
//0x07d3,4
//0x07d4,4
//0x07d5,4
//0x07d6,4
//0x0447,2

//2009-06-03aRagexeRE
0x07d7,8,partychangeoption,2:6
0x07d8,8
0x07d9,254
0x07da,6,partychangeleader,2
=cut
1;