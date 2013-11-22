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
package Network::Send::kRO::RagexeRE_2011_11_22a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2011_11_02a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'022D' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'023B' => undef,
		'02C4' => undef,
		'035F' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0362' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0364' => undef,
		'0366' => undef,
		'0369' => undef,
		'0436' => ['item_drop', 'v2', [qw(index amount)]],#6
		'0815' => undef,
		'0817' => undef,
		'0835' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0838' => undef,
		'083C' => undef,
		'0885' => undef,
		'088A' => undef,
		'088D' => undef,
		'0891' => ['friend_request', 'a*', [qw(username)]],#26 
		'0892' => ['character_move', 'a3', [qw(coords)]],#5
		'0893' => ['item_take', 'a4', [qw(ID)]],#6
		'0895' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0896' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0897' => undef,
		'0898' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'0899' => ['sync', 'V', [qw(time)]],#6
		'089E' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'08A1' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'08A4' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'08AA' => undef,
		'08AD' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'0907' => ['item_to_favorite', 'v C', [qw(index flag)]],#5 TODO where 'flag'=0|1 (0 - move item to favorite tab, 1 - move back) 
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 022D
		actor_info_request 0898
		actor_look_at 0896
		actor_name_request 035F
		character_move 0892
		friend_request 0891
		homunculus_command 089E
		item_drop 0436
		item_take 0893
		map_login 0835
		party_join_request_by_name 0895
		skill_use 08A1
		skill_use_location 08AD
		storage_item_add 08A4
		storage_item_remove 0362
		sync 0899
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self;
}

1;

=cut
//2011-11-22aRagexeRE
0x01FD,15,repairitem,2
+0x0891,26,friendslistadd,2
+0x089E,5,hommenu,2:4
0x0364,36,storagepassword,0
0x0288,-1,cashshopbuy,4:8
+0x0895,26,partyinvite2,2
+0x0835,19,wanttoconnection,2:6:10:14:18
+0x022D,7,actionrequest,2:6
+0x08A1,10,useskilltoid,2:4:6
+0x0439,8,useitem,2:4
0x0369,-1,itemlistwindowselected,2:4:8
0x0202,18,bookingregreq,2:4:6
0x0803,4
0x0804,14,bookingsearchreq,2:4:6:8:12
0x0805,-1
0x0806,2,bookingdelreq,0
0x0807,4
0x0808,14,bookingupdatereq,2
0x0809,50
0x080A,18
0x080B,6
0x0887,-1,reqopenbuyingstore,2:4:8:9:89
0x08A9,2,reqclosebuyingstore,0
0x088C,6,reqclickbuyingstore,2
0x089D,-1,reqtradebuyingstore,2:4:8:12
0x07EC,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0815,2,searchstoreinfonextpage,0
0x0366,12,searchstoreinfolistitemclick,2:6:10
+0x0892,5,walktoxy,2
+0x0899,6,ticksend,2
+0x0896,5,changedir,2:4
+0x0893,6,takeitem,2
+0x0436,6,dropitem,2:4
+0x08A4,8,movetokafra,2:4
+0x0362,8,movefromkafra,2:4
+0x08AD,10,useskilltopos,2:4:6:8
0x0363,90,useskilltoposinfo,2:4:6:8:10
+0x0898,6,getcharnamerequest,2
+0x035F,6,solvecharname,2
0x0907,5,moveitem,2:4
0x0908,5
0x08D7,28,battlegroundreg,2:4 //Added to prevent disconnections
=pod