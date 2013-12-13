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
use base qw(Network::Send::kRO::RagexeRE_2013_03_20);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'088E' => undef,
		'0369' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'089B' => undef,
		'083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0881' => undef,
		'0437' => ['character_move','a3', [qw(coordString)]],#5
		'0363' => undef,
		'035F' => ['sync', 'V', [qw(time)]],#6
		'093F' => undef,
		'0202' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'0933' => undef,
		'07E4' => ['item_take', 'a4', [qw(ID)]],#6
		'0362' => ['item_drop', 'v2', [qw(index amount)]],#6
		'08AC' => undef,
		'07EC' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'0874' => undef,
		'0364' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0959' => undef,
		'0438' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'0898' => undef,
		'096A' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'094C' => undef,
		'0368' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0888' => undef,
		'022D' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'086F' => undef,
		'0802' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'086D' => undef,
		'023B' => ['friend_request', 'a*', [qw(username)]],#26
		'0897' => undef,
		'0361' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 0369
		actor_info_request 096A
		actor_look_at 0202
		actor_name_request 0368
		character_move 0437
		friend_request 023B
		homunculus_command 0361
		item_drop 0362
		item_take 07E4
		map_login 022D
		party_join_request_by_name 0802
		skill_use 083C
		skill_use_location 0438
		storage_item_add 07EC
		storage_item_remove 0364
		sync 035F
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;
	
	$self;
}

1;
=pod
0x369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x437,5,walktoxy,2
0x035F,6,ticksend,2
0x202,5,changedir,2:4
0x70000,6,takeitem,2
0x362,6,dropitem,2:4
0x07EC,8,movetokafra,2:4
0x364,8,movefromkafra,2:4
0x438,10,useskilltopos,2:4:6:8
0x366,90,useskilltoposinfo,2:4:6:8:10
0x096A,6,getcharnamerequest,2
0x368,6,solvecharname,2
0x838,12,searchstoreinfolistitemclick,2:6:10
0x835,2,searchstoreinfonextpage,0
0x819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x811,-1,reqtradebuyingstore,2:4:8:12
0x360,6,reqclickbuyingstore,2
0x817,2,reqclosebuyingstore,0
0x815,-1,reqopenbuyingstore,2:4:8:9:89
0x365,18,bookingregreq,2:4:6
// 0x363,8 CZ_JOIN_BATTLE_FIELD
0x281,-1,itemlistwindowselected,2:4:8:12
0x022D,19,wanttoconnection,2:6:10:14:18
0x802,26,partyinvite2,2
// 0x436,4 CZ_GANGSI_RANK
0x023B,26,friendslistadd,2
0x361,5,hommenu,2:4
0x887,36,storagepassword,2:4:20
=cut