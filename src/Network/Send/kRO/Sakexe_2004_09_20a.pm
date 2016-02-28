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

package Network::Send::kRO::Sakexe_2004_09_20a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2004_09_06a);

use Log qw(debug);

sub version {
	return 11;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0072' => ['item_use', 'x8 v x2 a4', [qw(index targetID)]],#18
		'007E' => ['storage_item_add', 'x4 v x13 V', [qw(index amount)]],
		'0085' => ['actor_action', 'x a4 x C', [qw(targetID type)]],
		'0089' => ['character_move', 'x9 a3', [qw(coords)]],
		'0094' => ['item_drop', 'x10 v x3 v', [qw(index amount)]],
		'009B' => ['actor_info_request', 'x4 a4', [qw(ID)]],
		'00A2' => ['actor_name_request', 'x4 a4', [qw(ID)]],
		'00A7' => ['skill_use_location', 'x4 v x12 v x v x2 v', [qw(lv skillID x y)]],
		'00F3' => ['actor_look_at', 'x6 C x8 C', [qw(head body)]],
		'00F5' => ['map_login', 'x8 a4 x3 a4 x2 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0113' => ['item_take', 'x8 a4', [qw(ID)]],
		'0116' => ['sync', 'x8 V', [qw(time)]],
		'0190' => ['skill_use', 'x2 v x v x a4', [qw(lv skillID targetID)]],#14
		'0193' => ['storage_item_remove', 'x2 v x2 V', [qw(index amount)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x14 v x2 v x v x2 v Z80', 0x008C, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;

=pod
//2004-09-20aSakexe
packet_ver: 11
0x0072,18,useitem,10:14
0x007e,25,movetokafra,6:21
0x0085,9,actionrequest,3:8
0x0089,14,walktoxy,11
0x008c,109,useskilltoposinfo,16:20:23:27:29
0x0094,19,dropitem,12:17
0x009b,10,getcharnamerequest,6
0x00a2,10,solvecharname,6
0x00a7,29,useskilltopos,6:20:23:27
0x00f3,18,changedir,8:17
0x00f5,32,wanttoconnection,10:17:23:27:31
0x0113,14,takeitem,10
0x0116,14,ticksend,10
0x0190,14,useskilltoid,4:7:10
0x0193,12,movefromkafra,4:8
=cut