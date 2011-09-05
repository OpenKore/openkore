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

package Network::Send::kRO::Sakexe_2004_10_05a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2004_09_20a);

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 12;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'007E' => ['storage_item_add', 'x3 v x5 V', [qw(index amount)]],
		'0089' => ['character_move', 'x1 a3', [qw(coords)]],
		'0094' => ['item_drop', 'x3 v x5 v', [qw(index amount)]],
		'009B' => ['actor_info_request', 'x9 a4', [qw(ID)]],
		'00A7' => ['skill_use_location', 'x v x v x9 v x2 v', [qw(lv skillID x y)]],
		'00F3' => ['actor_look_at', 'x3 C x6 C', [qw(head body)]],
		'00F5' => ['map_login', 'x10 a4 x2 a4 x2 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0113' => ['item_take', 'x4 a4', [qw(ID)]],
		'0116' => ['sync', 'x4 V', [qw(time)]],
		'0193' => ['storage_item_remove', 'x8 v x10 V', [qw(index amount)]],
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	$self;
}

# 0x0072,17,useitem,6:13
sub sendItemUse {
	my ($self, $ID, $targetID) = @_;
	my $msg = pack('v x4 v x5 a4', 0x0072, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Item Use: $ID\n", "sendPacket", 2;
}

# 0x007e,16,movetokafra,5:12

# 0x0089,6,walktoxy,3

# 0x008c,103,useskilltoposinfo,2:6:17:21:23
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;

	my $msg = pack('v2 x2 v x9 v x2 v Z80', 0x008C, $lv, $ID, $x, $y, $moreinfo);

	$self->sendToServer($msg);
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}


# 0x0094,14,dropitem,5:12

# 0x009b,15,getcharnamerequest,11

# 0x00a2,12,solvecharname,8
sub sendGetCharacterName {
	my ($self, $ID) = @_;
	my $msg = pack('v x6 a4', 0x00a2, $ID);
	$self->sendToServer($msg);
	debug "Sent get character name: ID - ".getHex($ID)."\n", "sendPacket", 2;
}

# 0x00a7,23,useskilltopos,3:6:17:21

# 0x00f3,13,changedir,5:12

# 0x00f5,33,wanttoconnection,12:18:24:28:32

# 0x0113,10,takeitem,6

# 0x0116,10,ticksend,6

# 0x0190,20,useskilltoid,7:12:16
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

	$msg = pack('v x5 V x v x2 a4', 0x0190, $lv, $ID, $targetID);
	$self->sendToServer($msg);
	debug "Skill Use: $ID\n", "sendPacket", 2;
}

# 0x0193,26,movefromkafra,10:22

=pod
//2004-10-05aSakexe
packet_ver: 12
0x0072,17,useitem,6:13
0x007e,16,movetokafra,5:12
0x0089,6,walktoxy,3
0x008c,103,useskilltoposinfo,2:6:17:21:23
0x0094,14,dropitem,5:12
0x009b,15,getcharnamerequest,11
0x00a2,12,solvecharname,8
0x00a7,23,useskilltopos,3:6:17:21
0x00f3,13,changedir,5:12
0x00f5,33,wanttoconnection,12:18:24:28:32
0x0113,10,takeitem,6
0x0116,10,ticksend,6
0x0190,20,useskilltoid,7:12:16
0x0193,26,movefromkafra,10:22
=cut

1;