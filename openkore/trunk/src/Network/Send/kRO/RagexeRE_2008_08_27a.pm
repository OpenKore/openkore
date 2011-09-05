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

package Network::Send::kRO::RagexeRE_2008_08_27a;

use strict;
use base qw(Network::Send::kRO::Sakexe_2008_09_10a); #looks weird, inheriting from a newer file... but this is what eA has and we want to be able to play on eA servers

use Log qw(message warning error debug);
use Utils qw(getTickCount getHex getCoordString);

# TODO: maybe we should try to not use globals in here at all but instead pass them on?
use Globals qw($char);

sub version {
	return 24;
}

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0085' => ['actor_look_at', 'x2 C x4 C', [qw(head body)]],
		'0089' => ['sync', 'x5 V', [qw(time)]], # TODO
		'008C' => ['actor_info_request', 'x8 a4', [qw(ID)]],
		'0094' => ['storage_item_add', 'x v x10 V', [qw(index amount)]],
		'009B' => ['map_login', 'x5 a4 x4 a4 x6 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'00A7' => ['character_move', 'x4 a3', [qw(coords)]],
		'00F5' => ['item_take', 'x5 a4', [qw(ID)]],
		'00F7' => ['storage_item_remove', 'x v x8 V', [qw(index amount)]],
		'0113' => ['skill_use_location', 'x8 v x2 v x2 v x3 v', [qw(lv skillID x y)]],
		'0116' => ['item_drop', 'x4 v x7 v', [qw(index amount)]],
		'0190' => ['actor_action', 'x7 a4 x9 C', [qw(targetID type)]],
		'0436' => undef,
		'0437' => undef,
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		map_login 009B
		actor_action 0190
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

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

# 0x0089,11,ticksend,7

# 0x008c,14,getcharnamerequest,10

# 0x0094,19,movetokafra,3:15

# 0x009b,34,wanttoconnection,7:15:25:29:33

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

# 0x00f5,11,takeitem,7

# 0x00f7,17,movefromkafra,3:13

# 0x0113,25,useskilltopos,10:14:18:23

# 0x0116,17,dropitem,6:15

# 0x0190,23,actionrequest,9:22


=pod
//2008-08-27aRagexeRE
packet_ver: 24
0x0072,22,useskilltoid,9:15:18
0x007c,44
0x007e,105,useskilltoposinfo,10:14:18:23:25
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
=cut

1;