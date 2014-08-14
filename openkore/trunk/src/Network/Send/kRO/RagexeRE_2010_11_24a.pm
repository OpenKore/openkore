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
package Network::Send::kRO::RagexeRE_2010_11_24a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2010_08_03a);

use Log qw(debug);

sub version { 26 }

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0085' => undef,
		'0089' => undef,
		'008C' => undef,
		'0094' => undef,
		'00A2' => undef,
		'00A7' => undef,
		'00F5' => undef,
		'00F7' => undef,
		'0113' => undef,
		'0116' => undef,
		'035F' => ['character_move', 'a3', [qw(coords)]],#5
		'0360' => ['sync', 'V', [qw(time)]],#6
		'0361' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0362' => ['item_take', 'a4', [qw(ID)]],#6
		'0363' => ['item_drop', 'v2', [qw(index amount)]],#6
		'0364' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0365' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0366' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0368' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'0811' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]],#-1
		'0815' => ['buy_bulk_closeShop'],#2
		'0817' => ['buy_bulk_request', 'a4', [qw(ID)]],#6
		);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_info_request 0368
		actor_look_at 0361
		actor_name_request 0369
		buy_bulk_closeShop 0815
		buy_bulk_openShop 0811
		buy_bulk_request 0817
		character_move 035F
		item_drop 0363
		item_take 0362
		skill_use_location 0366
		storage_item_add 0364
		storage_item_remove 0365
		sync 0360
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

# 0x0367,90,useskilltoposinfo,2:4:6:8:10
sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x0367, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;

=cut
//2010-11-24aRagexeRE
0x01FD,15,repairitem,2
+0x0202,26,friendslistadd,2
+0x022D,5,hommenu,2:4
0x023B,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
0x02C4,26,partyinvite2,2
+0x0436,19,wanttoconnection,2:6:10:14:18
+0x0437,7,actionrequest,2:6
+0x0438,10,useskilltoid,2:4:6
+0x0439,8,useitem,2:4
0x07E4,-1,itemlistwindowselected,2:4:8
0x0802,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
+0x0811,-1,reqopenbuyingstore,2:4:8:9:89
+0x0815,2,reqclosebuyingstore,0
+0x0817,6,reqclickbuyingstore,2
0x0819,-1,reqtradebuyingstore,2:4:8:12
0x0835,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0838,2,searchstoreinfonextpage,0
0x083C,12,searchstoreinfolistitemclick,2:6:10
+0x035F,5,walktoxy,2
+0x0360,6,ticksend,2
+0x0361,5,changedir,2:4
+0x0362,6,takeitem,2
+0x0363,6,dropitem,2:4
+0x0364,8,movetokafra,2:4
+0x0365,8,movefromkafra,2:4
+0x0366,10,useskilltopos,2:4:6:8
+0x0367,90,useskilltoposinfo,2:4:6:8:10
+0x0368,6,getcharnamerequest,2
+0x0369,6,solvecharname,2
=pod