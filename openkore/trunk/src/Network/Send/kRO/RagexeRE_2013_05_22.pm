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
package Network::Send::kRO::RagexeRE_2013_05_22;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2013_05_15a);
use Log qw(debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
#		'0369' => undef,
		'08A2' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
		'083C' => undef,
		'095C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
		'0437' => undef,
		'0360' => ['character_move','a3', [qw(coordString)]],#5
		'035F' => undef,
		'07EC' => ['sync', 'V', [qw(time)]],#6
#		'0362' => undef,
		'0925' => ['actor_look_at', 'v C', [qw(head body)]],#5
		'08A1' => undef,
		'095E' => ['item_take', 'a4', [qw(ID)]],#6
		'0944' => undef,
		'089C' => ['item_drop', 'v2', [qw(index amount)]],#6
		'0887' => undef,
		'08A3' => ['storage_item_add', 'v V', [qw(index amount)]],#8
		'08AC' => undef,
		'087E' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
		'0438' => undef,
		'0811' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
		'096A' => undef,
		'08A6' => ['actor_info_request', 'a4', [qw(ID)]],#6
		'0368' => undef,
		'0369' => ['actor_name_request', 'a4', [qw(ID)]],#6
		'0943' => undef,
		'08A9' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
		'0947' => undef,
		'0950' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
		'0962' => undef,
		'0362' => ['friend_request', 'a*', [qw(username)]],#26
		'0931' => undef,
		'0926' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
	);
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;
	
	my %handlers = qw(
		actor_action 08A2
		actor_info_request 08A6
		actor_look_at 0925
		actor_name_request 0369
		character_move 0360
		friend_request 0362
		homunculus_command 0926
		item_drop 089C
		item_take 095E
		map_login 08A9
		party_join_request_by_name 0950
		skill_use 095C
		skill_use_location 0811
		storage_item_add 08A3
		storage_item_remove 087E
		sync 07EC
	);
	$self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#	$self->cryptKeys(1766327563, 1918717425, 105979293);

	$self;
}

1;
=pod
//2013-05-22 Ragexe (Yommy)
//packet_ver: 36
+0x08A2,7,actionrequest,2:6
+0x095C,10,useskilltoid,2:4:6
+0x0360,5,walktoxy,2
+0x07EC,6,ticksend,2
+0x0925,5,changedir,2:4
+0x095E,6,takeitem,2
+0x089C,6,dropitem,2:4
+0x08a3,8,movetokafra,2:4
+0x087E,8,movefromkafra,2:4
+0x0811,10,useskilltopos,2:4:6:8
0x0964,90,useskilltoposinfo,2:4:6:8:10
+0x08a6,6,getcharnamerequest,2
+0x0369,6,solvecharname,2
0x093e,12,searchstoreinfolistitemclick,2:6:10
0x08aa,2,searchstoreinfonextpage,0
0x095b,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0952,-1,reqtradebuyingstore,2:4:8:12
0x0368,6,reqclickbuyingstore,2
0x086E,2,reqclosebuyingstore,0
0x0874,-1,reqopenbuyingstore,2:4:8:9:89
0x089B,18,bookingregreq,2:4:6
//0x0965,8 CZ_JOIN_BATTLE_FIELD
0x086A,-1,itemlistwindowselected,2:4:8:12
+0x08A9,19,wanttoconnection,2:6:10:14:18
+0x0950,26,partyinvite2,2
//0x08AC,4 CZ_GANGSI_RANK
+0x0362,26,friendslistadd,2
+0x0926,5,hommenu,2:4
0x088e,36,storagepassword,2:4:20
=cut