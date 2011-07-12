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

package Network::Send::kRO::Sakexe_2007_01_08a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2007_01_02a);

use Log qw(message warning error debug);
use I18N qw(stringToBytes);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 21;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0085' => ['actor_look_at', 'x8 C x2 C', [qw(head body)]],
		'0089' => ['sync'], # TODO
		'009B' => ['map_login', 'x5 a4 x10 a4 x a4 V C', [qw(accountID charID sessionID tick sex)]],
		'00F5' => ['item_take', 'x5 a4', [qw(ID)]],
		'0190' => ['actor_action', 'x2 a4 x C', [qw(targetID type)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

# 0x0072,30,useskilltoid,10:14:26
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

	$msg = pack('v x8 V v x10 a4', 0x0072, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x007e,120,useskilltoposinfo,10:19:23:38:40
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x8 v x7 v x2 v x13 v Z80', 0x007E, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0085,14,changedir,10:13

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

# 0x008c,17,getcharnamerequest,13
sub sendGetPlayerInfo {
	my ($self, $ID) = @_;
	my $msg = pack('v x11 a4', 0x008C, $ID);
	$self->sendToServer($msg);
	debug "Sent get player info: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x0094,17,movetokafra,4:13
sub sendStorageAdd {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x2 v x7 V', 0x0094, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Add: $index x $amount\n", "sendPacket", 2;
}

# 0x009b,35,wanttoconnection,7:21:26:30:34

# 0x009f,21,useitem,7:17
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x5 v x8 a4', 0x009F, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x00a2,10,solvecharname,6
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x4 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,8,walktoxy,5
sub sendMove {
	my ($self, $x, $y) = @_;
	my $msg = pack('v x3 a3', 0x00A7, getCoordString($x = int $x, $y = int $y, 1));
	$self->sendToServer($msg);
	debug "Sent move to: $x, $y\n", "sendPacket", 2;
}

# 0x00f5,11,takeitem,7

# 0x00f7,15,movefromkafra,3:11
sub sendStorageGet {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x v x6 V', 0x00F7, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent Storage Get: $index x $amount\n", "sendPacket", 2;
}

# 0x0113,40,useskilltopos,10:19:23:38
sub sendSkillUseLoc {
	my ($self, $ID, $lv, $x, $y) = @_;
	my $msg = pack('v x8 v x7 v x2 v x13 v', 0x0113, $lv, $ID, $x, $y);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

# 0x0116,19,dropitem,11:17
sub sendDrop {
	my ($self, $index, $amount) = @_;
	my $msg = pack('v x9 v x4 v', 0x0116, $index, $amount);
	$self->sendToServer($msg);
	debug "Sent drop: $index x $amount\n", "sendPacket", 2;
}

# 0x0190,10,actionrequest,4:9

=pod
//2007-01-08aSakexe
packet_ver: 21
0x0072,30,useskilltoid,10:14:26
0x007e,120,useskilltoposinfo,10:19:23:38:40
0x0085,14,changedir,10:13
0x0089,11,ticksend,7
0x008c,17,getcharnamerequest,13
0x0094,17,movetokafra,4:13
0x009b,35,wanttoconnection,7:21:26:30:34
0x009f,21,useitem,7:17
0x00a2,10,solvecharname,6
0x00a7,8,walktoxy,5
0x00f5,11,takeitem,7
0x00f7,15,movefromkafra,3:11
0x0113,40,useskilltopos,10:19:23:38
0x0116,19,dropitem,11:17
0x0190,10,actionrequest,4:9
=cut

1;