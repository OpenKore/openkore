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

use Log qw(debug);

sub version {
	return 15;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['skill_use', 'x7 V x4 v x4 a4', [qw(lv skillID targetID)]],#26
		'007E' => undef,
		'0085' => ['actor_look_at', 'x10 C x9 C', [qw(head body)]],
		'0089' => ['sync', 'x3 V', [qw(time)]],
		'008C' => ['actor_info_request', 'x2 a4', [qw(ID)]],
		'0094' => ['storage_item_add', 'x8 v x4 V', [qw(index amount)]],
		'009B' => ['map_login', 'x a4 x5 a4 x7 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'009F' => ['item_use', 'x3 v x6 a4', [qw(index targetID)]],#17
		'00A2' => ['actor_name_request', 'x5 a4', [qw(ID)]],
		'00A7' => ['character_move', 'x8 a3', [qw(coords)]],
		'00F3' => ['public_chat', 'x2 Z*', [qw(message)]],
		'00F5' => ['item_take', 'x3 a4', [qw(ID)]],
		'00F7' => ['storage_item_remove', 'x9 v x4 V', [qw(index amount)]],
		'0113' => ['skill_use_location', 'x8 v x6 v x2 v x8 v', [qw(lv skillID x y)]],
		'0116' => ['item_drop', 'x13 v x v', [qw(index amount)]],
		'0190' => ['actor_action', 'x7 a4 x6 C', [qw(targetID type)]],
		'0193' => undef,
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0190
		actor_look_at 0085
		actor_name_request 00A2
		item_take 00F5
		item_use 009F
		map_login 009B
		public_chat 00F3
		skill_use 0072
		skill_use_location 0113
		storage_item_remove 00F7
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x8 v x6 v x2 v x8 v Z80', 0x007E, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendStorageClose {
	$_[0]->sendToServer(pack('v', 0x0193));
	debug "Sent Storage Done\n", "sendPacket", 2;
}

1;

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