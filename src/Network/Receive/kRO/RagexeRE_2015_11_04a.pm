#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versions, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2015_11_04a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_10_01b);
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	my %packets = (
		'08C8' => ['actor_action', 'a4 a4 a4 V3 x v C V', [qw(sourceID targetID tick src_speed dst_speed damage div type dual_wield_damage)]],
		'09FF' => ['actor_exists', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C3 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize act lv font opt4 name)]],
		'09FE' => ['actor_connected', 'v C a4 a4 v3 V v11 a4 a2 v V C2 a3 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'09FD' => ['actor_moved', 'v C a4 a4 v3 V v5 a4 v6 a4 a2 v V C2 a6 C2 v2 a9 Z*', [qw(len object_type ID charID walk_speed opt1 opt2 option type hair_style weapon shield lowhead tick tophead midhead hair_color clothes_color head_dir costume guildID emblemID manner opt3 stance sex coords xSize ySize lv font opt4 name)]],
		'0A23' => ['achievement_list', 'v V V v V V', [qw(len ach_count total_points rank current_rank_points next_rank_points)]], # -1
		'0A24' => ['achievement_update', 'V v VVV C V10 V C', [qw(total_points rank current_rank_points next_rank_points ach_id completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)]], # 66
		'0A26' => ['achievement_reward_ack', 'C V', [qw(received ach_id)]], # 7
		'09F0' => ['rodex_mail_list', 'v C3', [qw(len type amount isEnd)]],   # -1
		'09F6' => ['rodex_delete', 'C V2', [qw(type mailID1 mailID2)]],   # 11
		'09ED' => ['rodex_write_result', 'C', [qw(fail)]],   # 3
		'09EB' => ['rodex_read_mail', 'v C V2 v V2 C', [qw(len type mailID1 mailID2 text_len zeny1 zeny2 itemCount)]],   # -1
		'09F2' => ['rodex_get_zeny', 'V2 C2', [qw(mailID1 mailID2 type fail)]],   # 12
		'09F4' => ['rodex_get_item', 'V2 C2', [qw(mailID1 mailID2 type fail)]],   # 12
		'0A12' => ['rodex_open_write', 'Z24 C', [qw(name result)]],   # 27
		'0A07' => ['rodex_remove_item', 'C a2 v2', [qw(result ID amount weight)]],   # 9
		'0A51' => ['rodex_check_player', 'V v2 Z24', [qw(char_id class base_level name)]],   # 34
		'09E7' => ['unread_rodex', 'C', [qw(show)]],   # 3
		'0A05' => ['rodex_add_item', 'C a2 v2 C4 a8 a25 v a5', [qw(fail ID amount nameID type identified broken upgrade cards options weight unknow)]],   # 53
		'0A7D' => ['rodex_mail_list', 'v C3', [qw(len type amount isEnd)]],   # -1		
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self;
}

1;

=pod
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
