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
use base qw(Network::Send::kRO::Sakexe_2004_11_15a);

use Log qw(debug);
use Utils qw(getHex);

sub version {
	return 14;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['skill_use', 'v x6 V v x2 a4', [qw(lv skillID targetID)]],#22
		'007E' => ['skill_use_location', 'x2 v x3 v x11 v x4 v', [qw(lv skillID x y)]],
		'0085' => ['public_chat', 'x2 Z*', [qw(message)]],
		'0089' => ['sync', 'x V', [qw(time)]],
		'008C' => ['actor_info_request', 'x7 a4', [qw(ID)]],
		'0094' => ['storage_item_add', 'x2 v x4 V', [qw(index amount)]],
		'009B' => undef,
		'009F' => ['actor_action', 'x4 a4 x7 C', [qw(targetID type)]],
		'00A2' => ['item_take', 'x a4', [qw(ID)]],
		'00A7' => ['character_move', 'x2 a3', [qw(coords)]],
		'00F3' => ['actor_look_at', 'x C x3 C', [qw(head body)]],
		'00F5' => ['map_login', 'x a4 x3 a4 x6 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0113' => undef,
		'0116' => ['item_drop', 'x2 v x4 v', [qw(index amount)]],
		'0193' => ['storage_item_remove', 'x2 v x11 V', [qw(index amount)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		sync 0089
		character_move 00A7
		actor_action 009F
		public_chat 0085
		actor_info_request 008C
		item_take 00A2
		item_drop 0116
		storage_item_add 0094
		skill_use 0072
		skill_use_location 007E
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

sub sendStorageClose {
	$_[0]->sendToServer(pack('v', 0x009B));
	debug "Sent Storage Done\n", "sendPacket", 2;
}

sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x8 a4', 0x00F7, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x2 v x3 v x11 v x4 v Z80', 0x0113, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x v x6 a4', 0x0190, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendWeaponRefine {
	my ($self, $index) = @_;
	my $msg = pack('v V', 0x0222, $index);
	$self->sendToServer($msg);
	debug "Sent Weapon Refine.\n", "sendPacket", 2;
}

1;

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