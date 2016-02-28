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
package Network::Send::kRO::RagexeRE_2011_10_25a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_10_05a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0887' => ['friend_request', 'a*', [qw(username)]],#26
		'0885' => undef,
		'023B' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'083C' => undef,
		'08A8' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0436' => undef,
		'0363' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'02C4' => undef,
		'07EC' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0894' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0360' => ['buy_bulk_request', 'a4', [qw(ID)]],#6
		'0367' => undef,
		'035F' => ['sync', 'V', [qw(time)]],#6
		'08A7' => undef,
		'0835' => ['item_take', 'a4', [qw(ID)]],#6
		'0893' => ['item_drop', 'v2', [qw(index amount)]],#6
		'08A4' => undef,
		'089B' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0802' => undef,
		'08A6' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0438' => undef,
		'0885' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'0887' => undef,
		'08AD' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'0365' => undef,
		'0815' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]],#-1
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0369
		actor_info_request 08AD
		actor_look_at 0894
		buy_bulk_openShop 0815
		buy_bulk_request 0360
		friend_request 0887
		homunculus_command 023B
		item_drop 0893
		item_take 0835
		map_login 0363
		party_join_request_by_name 08A8
		skill_use 07EC
		skill_use_location 0885
		storage_item_add 089B
		storage_item_remove 08A6
		sync 035F
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self;
}

1;
=pod
//2011-10-25aRagexeRE
0x01FD,15,repairitem,2
+0x0887,26,friendslistadd,2
+0x023B,5,hommenu,2:4
0x08AB,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
+0x08A8,26,partyinvite2,2
+0x0363,19,wanttoconnection,2:6:10:14:18
+0x0369,7,actionrequest,2:6
+0x07EC,10,useskilltoid,2:4:6
+0x0439,8,useitem,2:4
0x08A2,-1,itemlistwindowselected,2:4:8
0x0888,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
+0x0815,-1,reqopenbuyingstore,2:4:8:9:89
+0x0817,2,reqclosebuyingstore,0
+0x0360,6,reqclickbuyingstore,2
0x0281,-1,reqtradebuyingstore,2:4:8:12
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0362,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
+0x0437,5,walktoxy,2
+0x035F,6,ticksend,2
+0x0894,5,changedir,2:4
+0x0835,6,takeitem,2
+0x0893,6,dropitem,2:4
+0x089B,8,movetokafra,2:4
+0x08A6,8,movefromkafra,2:4
+0x0885,10,useskilltopos,2:4:6:8
+0x0366,90,useskilltoposinfo,2:4:6:8:10
+0x08AD,6,getcharnamerequest,2
+0x0368,6,solvecharname,2
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=cut