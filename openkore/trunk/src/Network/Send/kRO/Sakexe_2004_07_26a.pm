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

package Network::Send::kRO::Sakexe_2004_07_26a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2004_07_13a);

use Log qw(debug);

sub version {
	return 8;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['item_drop', 'x3 v x5 v', [qw(index amount)]],
		'007E' => ['map_login', 'x10 a4 x2 a4 x2 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0085' => ['skill_use', 'x5 V x v x2 a4', [qw(lv skillID targetID)]],#20
		'0089' => ['actor_info_request', 'x9 a4', [qw(ID)]],
		'008C' => ['skill_use_location', 'x v x v x9 v x2 v', [qw(lv skillID x y)]],
		'0094' => ['item_take', 'x4 a4', [qw(ID)]],
		'009B' => ['character_move', 'x a3', [qw(coords)]],
		'009F' => ['actor_look_at', 'x3 C x6 C', [qw(head body)]],
		'00A2' => undef,
		'00A7' => ['actor_name_request', 'x6 a4', [qw(ID)]],
		'00F3' => ['public_chat', 'x2 Z*', [qw(message)]],
		'00F5' => undef,
		'00F7' => ['sync', 'x4 V', [qw(time)]],
		'0113' => ['storage_item_add', 'x3 v x5 V', [qw(index amount)]],
		'0116' => undef,
		'0190' => ['storage_item_remove', 'x8 v x10 V', [qw(index amount)]],
		'0193' => ['actor_action', 'x a4 x C', [qw(targetID type)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	# since there is only one available switch alternative per kRO ST,
	# this setup for $self->{packet_lut} is not really required
	my %handlers = qw(
		actor_action 0193
		actor_info_request 0089
		actor_look_at 009F
		actor_name_request 00A7
		character_move 009B
		item_take 0094
		item_drop 0072
		map_login 007E
		public_chat 00F3
		skill_use 0085
		skill_use_location 008C
		storage_item_add 0113
		storage_item_remove 0190
		sync 00F7
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v x v x v x9 v x2 v Z80', 0x007E, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x4 v x5 a4', 0x00F5, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendStorageClose {
	$_[0]->sendToServer(pack('v', 0x0116));
	debug "Sent Storage Done\n", "sendPacket", 2;
}

1;

=pod
//2004-07-26aSakexe
packet_ver: 8
0x0072,14,dropitem,5:12
0x007e,33,wanttoconnection,12:18:24:28:32
0x0085,20,useskilltoid,7:12:16
0x0089,15,getcharnamerequest,11
0x008c,23,useskilltopos,3:6:17:21
0x0094,10,takeitem,6
0x009b,6,walktoxy,3
0x009f,13,changedir,5:12
0x00a2,103,useskilltoposinfo,3:6:17:21:23
0x00a7,12,solvecharname,8
0x00f3,-1,globalmessage,2:4
0x00f5,17,useitem,6:12
0x00f7,10,ticksend,6
0x0113,16,movetokafra,5:12
0x0116,2,closekafra,0
0x0190,26,movefromkafra,10:22
0x0193,9,actionrequest,3:8
=cut