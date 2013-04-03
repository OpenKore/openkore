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

package Network::Send::kRO::Sakexe_2004_10_25a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2004_10_05a);

use Log qw(debug);
use Utils qw(getHex);

sub version {
	return 13;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'007E' => ['storage_item_add', 'x4 v x V', [qw(index amount)]],
		'0085' => ['actor_action', 'x2 a4 x6 C', [qw(targetID type)]],
		'0094' => ['item_drop', 'x4 v x2 v', [qw(index amount)]],
		'009B' => ['actor_info_request', 'x4 a4', [qw(ID)]],
		'00A7' => ['skill_use_location', 'x4 v x v x12 v x v', [qw(lv skillID x y)]],
		'00F3' => ['actor_look_at', 'x4 v x6 C', [qw(head body)]],
		'00F5' => ['map_login', 'x3 a4 x5 a4 x2 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0113' => ['item_take', 'x3 a4', [qw(ID)]],
		'0116' => ['sync', 'x3 V', [qw(time)]],
		'0190' => ['skill_use', 'v x3 V x2 v x10 a4', [qw(lv skillID targetID)]],#26
		'0193' => ['storage_item_remove', 'x10 v x4 V', [qw(index amount)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x3 v x2 a4', 0x0072, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	my $msg = pack('v x4 v x v x12 v x v Z80', 0x008C, $lv, $ID, $x, $y, $moreinfo);
	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x10 a4', 0x00A2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

1;

=pod
//2004-10-25aSakexe
packet_ver: 13
0x0072,13,useitem,5:9
0x007e,13,movetokafra,6:9
0x0085,15,actionrequest,4:14
0x008c,108,useskilltoposinfo,6:9:23:26:28
0x0094,12,dropitem,6:10
0x009b,10,getcharnamerequest,6
0x00a2,16,solvecharname,12
0x00a7,28,useskilltopos,6:9:23:26
0x00f3,15,changedir,6:14
0x00f5,29,wanttoconnection,5:14:20:24:28
0x0113,9,takeitem,5
0x0116,9,ticksend,5
0x0190,26,useskilltoid,4:10:22
0x0193,22,movefromkafra,12:18
=cut