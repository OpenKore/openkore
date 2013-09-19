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
package Network::Send::kRO::RagexeRE_2011_10_05a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_08_16a);

use Log qw(debug);

sub version { 27 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0202' => undef,
		'022D' => undef,
		'023B' => ['item_drop', 'v2', [qw(index amount)]],#6
		'02C4' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10 
		'035F' => undef,
		'0361' => undef,
		'0362' => undef,
		'0364' => undef,
		'0367' => ['sync', 'V', [qw(time)]],#6
		'0369' => undef,
		'0436' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19 
		'07E4' => undef,
		'07EC' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'0802' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'08A7' => ['item_take', 'a4', [qw(ID)]],#6
		'0815' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0835' => ['friend_request', 'a*', [qw(username)]],#26
		'083C' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0885' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'0887' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'08A4' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'08AD' => undef,
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 07EC
		actor_info_request 0887
		actor_look_at 0815
		friend_request 0835
		homunculus_command 0885
		item_drop 023B
		item_take 08A7
		map_login 0436
		party_join_request_by_name 083C
		skill_use 02C4
		storage_item_add 08A4
		storage_item_remove 0802
		sync 0367
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x0366,90,useskilltoposinfo,2:4:6:8:10
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x0366, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;

=cut
//2011-10-05aRagexeRE
0x01FD,15,repairitem,2
+0x0835,26,friendslistadd,2
+0x0885,5,hommenu,2:4
0x089B,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
+0x083C,26,partyinvite2,2
+0x0436,19,wanttoconnection,2:6:10:14:18
+0x07EC,7,actionrequest,2:6
+0x02C4,10,useskilltoid,2:4:6
+0x0439,8,useitem,2:4
0x0889,-1,itemlistwindowselected,2:4:8
0x0361,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
0x0365,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x035F,6,reqclickbuyingstore,2
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0202,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
+0x0437,5,walktoxy,2
+0x0367,6,ticksend,2
+0x0815,5,changedir,2:4
+0x08A7,6,takeitem,2
+0x023B,6,dropitem,2:4
+0x08A4,8,movetokafra,2:4
+0x0802,8,movefromkafra,2:4
+0x0438,10,useskilltopos,2:4:6:8
+0x0366,90,useskilltoposinfo,2:4:6:8:10
+0x0887,6,getcharnamerequest,2
+0x0368,6,solvecharname,2
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=pod