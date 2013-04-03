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

package Network::Send::kRO::Sakexe_2004_08_09a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2004_07_26a);

use Log qw(debug);
use Utils qw(getHex);

sub version {
	return 9;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['item_drop', 'x6 v x5 v', [qw(index amount)]],
		'007E' => ['map_login', 'x7 a4 x8 a4 x3 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0085' => ['skill_use', 'v x9 V x3 v x2 a4', [qw(lv skillID targetID)]],#26
		'0089' => ['actor_info_request', 'x6 a4', [qw(ID)]],
		'008C' => ['skill_use_location', 'x3 v x8 v x12 v x7 v', [qw(lv skillID x y)]],
		'0094' => ['item_take', 'x7 a4', [qw(ID)]],
		'009B' => ['character_move', 'x10 a3', [qw(coords)]],
		'009F' => ['actor_look_at', 'x5 C x3 C', [qw(head body)]],
		'00F7' => ['sync', 'x7 V', [qw(time)]],
		'0113' => ['storage_item_add', 'x3 v x12 V', [qw(index amount)]],
		'0190' => ['storage_item_remove', 'x9 v x9 V', [qw(index amount)]],
		'0193' => ['actor_action', 'x5 a4 x6 C', [qw(targetID type)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x3 v x8 v x12 v x7 v Z80', 0x00A2, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x5 a4', 0x00a7, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x7 v x9 a4', 0x00F5, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

1;

=pod
//2004-08-09aSakexe
packet_ver: 9
0x0072,17,dropitem,8:15
0x007e,37,wanttoconnection,9:21:28:32:36
0x0085,26,useskilltoid,11:18:22
0x0089,12,getcharnamerequest,8
0x008c,40,useskilltopos,5:15:29:38
0x0094,13,takeitem,9
0x009b,15,walktoxy,12
0x009f,12,changedir,7:11
0x00a2,120,useskilltoposinfo,5:15:29:38:40
0x00a7,11,solvecharname,7
0x00f5,24,useitem,9:20
0x00f7,13,ticksend,9
0x0113,23,movetokafra,5:19
0x0190,26,movefromkafra,11:22
0x0193,18,actionrequest,7:17
=cut