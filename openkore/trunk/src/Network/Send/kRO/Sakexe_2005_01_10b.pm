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
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0085' => ['actor_look_at', 'x10 C x9 C', [qw(head body)]],
		'0089' => ['sync'], # TODO
		'009B' => ['map_login', 'x a4 x5 a4 x7 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'009F' => undef,
		'00A2' => undef,
		'00A7' => ['character_move', 'x8 a3', [qw(coords)]],
		'00F3' => ['public_chat', 'x2 Z*', [qw(message)]],
		'00F5' => ['item_take', 'x7 a4', [qw(ID)]],
		'0190' => ['actor_action', 'x7 a4 x6 C', [qw(targetID type)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		map_login 009B
		actor_action 0190
		public_chat 00F3
		actor_look_at 0085
		item_take 00F5
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
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

# 0x00f5,9,takeitem,5

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