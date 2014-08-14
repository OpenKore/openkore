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
package Network::Send::kRO::RagexeRE_2013_05_15a;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2013_03_20);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'086D' => undef,
		'0962' => ['friend_request', 'a*', [qw(username)]],#26
		'0897' => undef,
		'0931' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
		'086F' => undef,
		'0947' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0888' => undef,
		'0943' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'088E' => undef,
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'089B' => undef,
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0881' => undef,
		'0437' => ['character_move','a3', [qw(coordString)]],#5
		'0363' => undef,
		'035F' => ['sync', 'V', [qw(time)]],#6
		'093F' => undef,
		'0362' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0933' => undef,
		'08A1' => ['item_take', 'a4', [qw(ID)]],#6
#		'0438' => undef,
		'0944' => ['item_drop', 'v2', [qw(index amount)]],#6
#		'08AC' => undef,
		'0887' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0874' => undef,
		'08AC' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0959' => undef,
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'0898' => undef,
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'094C' => undef,
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0938' => undef,
		'0815' => ['buy_bulk_openShop', 'a4 c a*', [qw(limitZeny result itemInfo)]],#-1
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 0362
		actor_name_request 0368
		buy_bulk_openShop 0815
		character_move 0437
		friend_request 0962
		homunculus_command 0931
		item_drop 0944
		item_take 08A1
		map_login 0943
		party_join_request_by_name 0947
		skill_use 083C
		skill_use_location 0438
		storage_item_add 0887
		storage_item_remove 08AC
		sync 035F
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

	$self;
}

sub sendSkillUseLocInfo {
	my ($self, $ID, $lv, $x, $y, $moreinfo) = @_;
	$self->sendToServer(pack('v5 Z80', 0x0366, $lv, $ID, $x, $y, $moreinfo));
	debug "Skill Use on Location: $ID, ($x, $y)\n", "sendPacket", 2;
}

1;
=pod
//2013-05-15a Ragexe (Yommy)
//packet_ver: 35
+0x0962,26,friendslistadd,2
+0x0931,5,hommenu,2:4
0x093e,36,storagepassword,2:4:20
+0x0947,26,partyinvite2,2
+0x0943,19,wanttoconnection,2:6:10:14:18
+0x0369,7,actionrequest,2:6
+0x083C,10,useskilltoid,2:4:6
+0x0437,5,walktoxy,2
+0x035F,6,ticksend,2
+0x0362,5,changedir,2:4
+0x08A1,6,takeitem,2
+0x0944,6,dropitem,2:4
+0x0887,8,movetokafra,2:4
+0x08AC,8,movefromkafra,2:4
+0x0438,10,useskilltopos,2:4:6:8
+0x0366,90,useskilltoposinfo,2:4:6:8:10
+0x096A,6,getcharnamerequest,2
+0x0368,6,solvecharname,2
+0x0815,-1,reqopenbuyingstore,2:4:8:9:89
+0x0817,2,reqclosebuyingstore,0
+0x0360,6,reqclickbuyingstore,2
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,2,searchstoreinfonextpage,0
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x092D,18,bookingregreq,2:4:6
//0x08AA,8 CZ_JOIN_BATTLE_FIELD
0x0963,-1,itemlistwindowselected,2:4:8:12
//0x0862,4 CZ_GANGSI_RANK
=cut