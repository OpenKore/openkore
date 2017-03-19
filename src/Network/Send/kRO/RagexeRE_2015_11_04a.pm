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

package Network::Send::kRO::RagexeRE_2015_11_04a_;

use strict;
use base 'Network::Send::kRO::RagexeRE_2015_05_13a';

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],
		'0363' => undef, #old map_login
		'0363' => ['character_move','a3', [qw(coords)]],
		'0886' => ['sync', 'V', [qw(time)]],
		'0928' => ['actor_look_at', 'v C', [qw(head body)]],
		'0964' => ['item_take', 'a4', [qw(ID)]],
		'0437' => ['item_drop', 'v2', [qw(index amount)]],
		'088B' => ['storage_item_add', 'v V', [qw(index amount)]],
		'0364' => ['storage_item_remove', 'v V', [qw(index amount)]],
		'0887' => ['actor_info_request', 'a4', [qw(ID)]],
		'0336' => ['actor_name_request', 'a4', [qw(ID)]],
		'093A' => ['item_list_res', 'v V2 a*', [qw(len type action itemInfo)]],
		'0360' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],
		'07EC' => ['party_join_request_by_name', 'Z24', [qw(partyName)]], #f
		'088D' => ['homunculus_command', 'v C', [qw(commandType, commandID)]], #f
		'0951' => ['storage_password'],
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		master_login 02B0
		buy_bulk_vender 0801
		party_setting 07D7
	);
	
	while (my ($k, $v) = each %packets) { $handlers{$v->[0]} = $k}
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	return $self;
}

1;
=cut
//2015-11-04aRagexe packet_ver: 55 packet_keys:
0x4C17382A,0x7ED174C9,0x29961E4F // [Winnie] 
0x0369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x0363,5,walktoxy,2
0x0886,6,ticksend,2
0x0928,5,changedir,2:4
0x0964,6,takeitem,2
0x0437,6,dropitem,2:4
0x088B,8,movetokafra,2:4
0x0364,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x0887,6,getcharnamerequest,2
0x0368,6,solvecharname,2
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0835,2,searchstoreinfonextpage,0
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0815,-1,reqtradebuyingstore,2:4:8:12
0x0436,6,reqclickbuyingstore,2
0x0817,2,reqclosebuyingstore,0
0x023B,-1,reqopenbuyingstore,2:4:8:9:89
0x0811,18,bookingregreq,2:4:6 //0x0939,8 CZ_JOIN_BATTLE_FIELD
0x093A,-1,itemlistwindowselected,2:4:8:12
0x0360,19,wanttoconnection,2:6:10:14:18
0x08A5,26,partyinvite2,2 //0x08A3,4 CZ_GANGSI_RANK
0x07EC,26,friendslistadd,2
0x088D,5,hommenu,2:4
0x0940,36,storagepassword,2:4:20
=cut
