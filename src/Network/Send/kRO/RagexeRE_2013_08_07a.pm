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
package Network::Send::kRO::RagexeRE_2013_08_07a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2013_06_26b);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],
		'0202' => ['actor_look_at', 'v C', [qw(head body)]],
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],
		'0811' => ['buy_bulk_buyer', 'v a4 a4 a*', [qw(len buyerID buyingStoreID itemInfo)]], #Buying store
		'0817' => ['buy_bulk_closeShop'],
		'0815' => ['buy_bulk_openShop', 'v V C Z80 a*', [qw(len limitZeny result storeName itemInfo)]], # Buying store
		'0360' => ['buy_bulk_request', 'a4', [qw(ID)]], #6
		'0437' => ['character_move', 'a3', [qw(coordString)]],
		'023B' => ['friend_request', 'a*', [qw(username)]],# len 26
		'0361' => ['homunculus_command', 'v C', [qw(commandType commandID)]],
		'0362' => ['item_drop', 'a2 v', [qw(ID amount)]],
		'0281' => ['item_list_window_selected', 'v V V a*', [qw(len type act itemInfo)]],
		'07E4' => ['item_take', 'a4', [qw(ID)]],
		'022D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'0802' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],
		'07EC' => ['storage_item_add', 'a2 V', [qw(ID amount)]],
		'0364' => ['storage_item_remove', 'a2 V', [qw(ID amount)]],
		'086D' => ['storage_password'],
		'035F' => ['sync', 'V', [qw(time)]],
		'0819' => ['search_store_info', 'v C V2 C2 a*', [qw(len type max_price min_price item_count card_count item_card_list)]],
		'0835' => ['search_store_request_next_page'],
		'0838' => ['search_store_select', 'a4 a4 v', [qw(accountID storeID nameID)]],
	);

	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 0202
		actor_name_request 0368
		buy_bulk_buyer 0811
		buy_bulk_closeShop 0817
		buy_bulk_openShop 0815
		buy_bulk_request 0360
		character_move 0437
		friend_request 023B
		homunculus_command 0361
		item_drop 0362
		item_list_window_selected 0281
		item_take 07E4
		map_login 022D
		party_join_request_by_name 0802
		skill_use 083C
		skill_use_location 0438
		storage_item_add 07EC
		storage_item_remove 0364
		storage_password 086D
		sync 035F
		search_store_info 0819
		search_store_request_next_page 0835
		search_store_select 0838
	);



	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	elif PACKETVER == 20130807 // 2013-08-07Ragexe
#		packet_keys(0x7E241DE0,0x5E805580,0x3D807D80);
#	$self->cryptKeys(0x7E241DE0, 0x3D807D80, 0x5E805580);

	return $self;
}

1;
=pod
//2013-08-07Ragexe (Shakto)
//packet_ver: 45
+0x0369,7,actionrequest,2:6
+0x083C,10,useskilltoid,2:4:6
+0x0437,5,walktoxy,2
+0x035F,6,ticksend,2
+0x0202,5,changedir,2:4
+0x07E4,6,takeitem,2
+0x0362,6,dropitem,2:4
+0x07EC,8,movetokafra,2:4
+0x0364,8,movefromkafra,2:4
+0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
+0x096A,6,getcharnamerequest,2
+0x0368,6,solvecharname,2
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0835,2,searchstoreinfonextpage,0
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0360,6,reqclickbuyingstore,2
0x0817,2,reqclosebuyingstore,0
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0365,18,bookingregreq,2:4:6
// 0x363,8 CZ_JOIN_BATTLE_FIELD
0x0281,-1,itemlistwindowselected,2:4:8:12
+0x022D,19,wanttoconnection,2:6:10:14:18
+0x0802,26,partyinvite2,2
// 0x0436,4 CZ_GANGSI_RANK
+0x023B,26,friendslistadd,2
+0x0361,5,hommenu,2:4
0x0887,36,storagepassword,2:4:20
=cut