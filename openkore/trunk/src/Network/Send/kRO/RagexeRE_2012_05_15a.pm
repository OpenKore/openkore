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
########################################################################
package Network::Send::kRO::RagexeRE_2012_05_15a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2012_04_18a);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0364' => ['item_drop', 'v2', [qw(index amount)]],#6
		'0369' => ['friend_request', 'a*', [qw(username)]],#26
		'0437' => undef,
		'0438' => undef,
		'083C' => undef,
		'07EC' => undef,
		'022D' => undef,
		'085A' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0869' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0202' => undef,
		'087C' => ['character_move','a3', [qw(coordString)]],#5
		'087D' => ['sync', 'V', [qw(time)]],#6
		'0368' => undef,
		'0361' => undef,
		'035F' => undef,
		'096A' => undef,
		'0362' => undef,
		'023B' => undef,
		'08A5' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'08A8' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'08AC' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'08AD' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'0802' => undef,
		'091F' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0923' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'07E4' => undef,
		'0947' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'094B' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'0957' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0964' => ['item_take', 'a4', [qw(ID)]],#6
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0923
		actor_info_request 08A5
		actor_look_at 08AC
		actor_name_request 0957
		character_move 087C
		friend_request 0369
		homunculus_command 094B
		item_drop 0364
		item_take 0964
		map_login 08A8
		skill_use 0947
		skill_use_location 08AD
		storage_item_add 085A
		storage_item_remove 0869
		sync 087D
		party_join_request_by_name 091F
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

#0x08A2,90,useskilltoposinfo,2:4:6:8:10
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x08A2, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

#0x089A,36,storagepassword,0
sub sendStoragePassword {
	my $self = shift;
	# 16 byte packed hex data
	my $pass = shift;
	# 2 = set password ?
	# 3 = give password ?
	my $type = shift;
	my $msg;
	if ($type == 3) {
		$msg = pack('v2', 0x089A, $type).$pass.pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8");
	} elsif ($type == 2) {
		$msg = pack('v2', 0x089A, $type).pack("H*", "EC62E539BB6BBC811A60C06FACCB7EC8").$pass;
	} else {
		ArgumentException->throw("The 'type' argument has invalid value ($type).");
	}
	$self->sendToServer($msg);
}

1;

=cut
//2012-05-15aRagexeRE
0x01FD,15,repairitem,2
+0x0369,26,friendslistadd,2
+0x094B,5,hommenu,2:4
0x089A,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
+0x091F,26,partyinvite2,2
+0x08A8,19,wanttoconnection,2:6:10:14:18
+0x0923,7,actionrequest,2:6
+0x0947,10,useskilltoid,2:4:6
+0x0439,8,useitem,2:4
0x0366,-1,itemlistwindowselected,2:4:8
0x0891,-1,reqopenbuyingstore,2:4:8:9:89
0x092C,2,reqclosebuyingstore,0
0x091A,6,reqclickbuyingstore,2
0x096A,-1,reqtradebuyingstore,2:4:8:12
0x0817,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0367,2,searchstoreinfonextpage,0
0x087E,12,searchstoreinfolistitemclick,2:6:10
+0x087C,5,walktoxy,2
+0x087D,6,ticksend,2
+0x08AC,5,changedir,2:4
+0x0964,6,takeitem,2
+0x0364,6,dropitem,2:4
+0x085A,8,movetokafra,2:4
+0x0869,8,movefromkafra,2:4
+0x08AD,10,useskilltopos,2:4:6:8
+0x08A2,90,useskilltoposinfo,2:4:6:8:10
+0x08A5,6,getcharnamerequest,2
+0x0957,6,solvecharname,2
0x08E5,41,bookingregreq,2:4	//Added to prevent disconnections
0x08E6,4
0x08E7,10,bookingsearchreq,2
0x08E8,-1
0x08E9,2,bookingdelreq,2
0x08EA,4
0x08EB,39,bookingupdatereq,2
0x08EC,73
0x08ED,43
0x08EE,6
0x08EF,6,bookingignorereq,2
0x08F0,6
0x08F1,6,bookingjoinpartyreq,2
0x08F2,36
0x08F3,-1
0x08F4,6
0x08F5,-1,bookingsummonmember,2:4
0x08F6,22
0x08F7,3
0x08F8,7
0x08F9,6
0x08FA,6
0x08FB,6,bookingcanceljoinparty,2
0x0907,5,moveitem,2:4
0x0908,5
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=pod