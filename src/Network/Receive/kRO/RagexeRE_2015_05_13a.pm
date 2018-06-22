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

package Network::Receive::kRO::RagexeRE_2015_05_13a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2014_10_22b);
use Globals;
use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
		my %packets = (
		'0A3B' => ['hat_effect', 'v a4 C a*', [qw(len ID flag effect)]], # -1
		'09E7' => ['unread_rodex', 'C', [qw(show)]],   # 3
		'09EB' => ['rodex_read_mail', 'v C V2 v V2 C', [qw(len type mailID1 mailID2 text_len zeny1 zeny2 itemCount)]],   # -1
		'09ED' => ['rodex_write_result', 'C', [qw(fail)]],   # 3	
		'09F0' => ['rodex_mail_list', 'v C3', [qw(len type amount isEnd)]],   # -1
		'09F2' => ['rodex_get_zeny', 'V2 C2', [qw(mailID1 mailID2 type fail)]],   # 12
		'09F4' => ['rodex_get_item', 'V2 C2', [qw(mailID1 mailID2 type fail)]],   # 12
		'09F6' => ['rodex_delete', 'C V2', [qw(type mailID1 mailID2)]],   # 11
		'0A05' => ['rodex_add_item', 'C a2 v2 C4 a8 a25 v a5', [qw(fail ID amount nameID type identified broken upgrade cards options weight unknow)]],   # 53
		'0A07' => ['rodex_remove_item', 'C a2 v2', [qw(result ID amount weight)]],   # 9
		'0A12' => ['rodex_open_write', 'Z24 C', [qw(name result)]],   # 27
		'0A14' => ['receive_char', 'v a4 v2', [qw(len ID job lv)]],
		'0A23' => ['achievement_list', 'v V V v V V', [qw(len ach_count total_points rank current_rank_points next_rank_points)]], # -1
		'0A24' => ['achievement_update', 'V v VVV C V10 V C', [qw(total_points rank current_rank_points next_rank_points ach_id completed objective1 objective2 objective3 objective4 objective5 objective6 objective7 objective8 objective9 objective10 completed_at reward)]], # 66
		'0A26' => ['achievement_reward_ack', 'C V', [qw(received ach_id)]], # 7
		'0A2F' => ['change_title', 'C V', [qw(result title_id)]],
		'0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24 V', [qw(ID name partyName guildName guildTitle titleID)]],
		'09F8' => ['quest_all_list3', 'v3 a*', [qw(len count unknown message)]],
		'09F9' => ['quest_add', 'V C V2 v', [qw(questID active time_start time amount)]],
		'09FA' => ['quest_update_mission_hunt', 'v2 a*', [qw(len amount mobInfo)]],

		);
		
	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self; 
}	

sub receive_charname {
    my ($self, $args) = @_;

    my $player = $playersList->getByID($args->{ID});
    if ($player) {
        $player->{lv} = $args->{lv};
        $player->{job} = $args->{job};
    }
}

sub quest_all_list3 {
	my ( $self, $args ) = @_;

	# Long quest lists are split up over multiple packets. Only reset the quest list if we've switched maps.
	our $quest_generation      ||= 0;
	our $last_quest_generation ||= 0;
	if ( $last_quest_generation != $quest_generation ) {
		$last_quest_generation = $quest_generation;
		$questList             = {};
	}

	my $i = 0;
	while ( $i < $args->{RAW_MSG_SIZE} - 8 ) {
		my ( $questID, $active, $time_start, $time, $mission_amount ) = unpack( 'V C V2 v', substr( $args->{message}, $i, 15 ) );
		$i += 15;

		$questList->{$questID}->{active} = $active;
		debug "$questID $active\n", "info";

		my $quest = \%{ $questList->{$questID} };
		$quest->{time_start}     = $time_start;
		$quest->{time}           = $time;
		$quest->{mission_amount} = $mission_amount;
		debug "$questID $time_start $time $mission_amount\n", "info";

		if ( $mission_amount > 0 ) {
			for ( my $j = 0 ; $j < $mission_amount ; $j++ ) {
				my ( $conditionID, $mobID, $count, $goal, $mobName ) = unpack( 'V x4 V x4 v2 Z24', substr( $args->{message}, $i, 44 ) );
				$i += 44;
				my $mission = \%{ $quest->{missions}->{$conditionID} };
				$mission->{conditionID} = $conditionID;
				$mission->{mobID}       = $mobID;
				$mission->{count}       = $count;
				$mission->{goal}        = $goal;
				$mission->{mobName_org} = $mobName;
				$mission->{mobName}     = bytesToString( $mobName );
				debug "- $mobID $count / $goal $mobName\n", "info";
			}
		}
	}
}

1;
=pod
//2015-05-13aRagexe
packet_ver: 52
packet_keys: 0x62C86D09,0x75944F17,0x112C133D // [YomRawr]
0x0369,7,actionrequest,2:6
0x083C,10,useskilltoid,2:4:6
0x0437,5,walktoxy,2
0x035F,6,ticksend,2
0x0924,5,changedir,2:4
0x0958,6,takeitem,2
0x0885,6,dropitem,2:4
0x0879,8,movetokafra,2:4
0x0864,8,movefromkafra,2:4
0x0438,10,useskilltopos,2:4:6:8
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x096A,6,getcharnamerequest,2
0x0368,6,solvecharname,2
0x0838,12,searchstoreinfolistitemclick,2:6:10
0x0835,2,searchstoreinfonextpage,0
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0360,6,reqclickbuyingstore,2
0x022D,2,reqclosebuyingstore,0
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0883,18,bookingregreq,2:4:6
// 0x02C4,8 CZ_JOIN_BATTLE_FIELD
0x0960,-1,itemlistwindowselected,2:4:8:12
0x0363,19,wanttoconnection,2:6:10:14:18
0x094A,26,partyinvite2,2
// 0x0927,4 CZ_GANGSI_RANK
0x08A8,26,friendslistadd,2
0x0817,5,hommenu,2:4
0x0923,36,storagepassword,2:4:20

// New Packets
0xA3B,-1      // ZC_HAT_EFFECT

// RODEX Mail system
0x09E7,3      // ZC_NOTIFY_UNREADMAIL
0x09E8,11,dull,0   // CZ_OPEN_MAILBOX
0x09E9,2,dull,0    // CZ_CLOSE_MAILBOX
0x09EA,11,dull,0   // CZ_REQ_READ_MAIL
0x09EB,-1      // ZC_ACK_READ_MAIL
0x09EC,-1,dull,0   // CZ_REQ_WRITE_MAIL
0x09ED,3      // ZC_ACK_WRITE_MAIL
0x09EE,11,dull,0   // CZ_REQ_NEXT_MAIL_LIST
0x09EF,11,dull,0    // CZ_REQ_REFRESH_MAIL_LIST
0x09F0,-1      // ZC_ACK_MAIL_LIST
0x09F1,11,dull,0   // CZ_REQ_ZENY_FROM_MAIL
0x09F2,12   // ZC_ACK_ZENY_FROM_MAIL
0x09F3,11,dull,0   // CZ_REQ_ITEM_FROM_MAIL
0x09F4,12   // ZC_ACK_ITEM_FROM_MAIL
0x09F5,11,dull,0   // CZ_REQ_DELETE_MAIL
0x09F6,11      // ZC_ACK_DELETE_MAIL
0x0A03,2,dull,0   // CZ_REQ_CANCEL_WRITE_MAIL
0x0A04,6,dull,0   // CZ_REQ_ADD_ITEM_TO_MAIL
0x0A05,53   // ZC_ACK_ADD_ITEM_TO_MAIL
0x0A06,6,dull,0   // CZ_REQ_REMOVE_ITEM_MAIL
0x0A07,9      // ZC_ACK_REMOVE_ITEM_MAIL
0x0A08,26,dull,0   // CZ_REQ_OPEN_WRITE_MAIL
0x0A12,27   // ZC_ACK_OPEN_WRITE_MAIL
0x0A32,2      // ZC_OPEN_RODEX_THROUGH_NPC_ONLY
0x0A13,26,dull,0   // CZ_CHECK_RECEIVE_CHARACTER_NAME
0x0A14,10      // ZC_CHECK_RECEIVE_CHARACTER_NAME

// New EquipPackets Support
0x0A09,45   // ZC_ADD_EXCHANGE_ITEM3
0x0A0A,47   // ZC_ADD_ITEM_TO_STORE3
0x0A0B,47   // ZC_ADD_ITEM_TO_CART3
0x0A0C,56   // ZC_ITEM_PICKUP_ACK_V6
0x0A0D,-1   // ZC_INVENTORY_ITEMLIST_EQUIP_V6
0x0A0F,-1      // ZC_CART_ITEMLIST_EQUIP_V6
0x0A10,-1      // ZC_STORE_ITEMLIST_EQUIP_V6
0x0A2D,-1   // ZC_EQUIPWIN_MICROSCOPE_V6

// OneClick Itemidentify
0x0A35,4,oneclick_itemidentify,2   // CZ_REQ_ONECLICK_ITEMIDENTIFY

// Achievement System
0x0A23,-1      // ZC_ALL_ACH_LIST
0x0A24,66   // ZC_ACH_UPDATE
0x0A25,6,dull,0   // CZ_REQ_ACH_REWARD
0x0A26,7      // ZC_REQ_ACH_REWARD_ACK

// Title System
0x0A2E,6,dull,0   // CZ_REQ_CHANGE_TITLE
0x0A2F,7      // ZC_ACK_CHANGE_TITLE
0x0A30,106   // ZC_ACK_REQNAMEALL2

// Pet Evolution System
0x09FB,-1,dull,0   // CZ_PET_EVOLUTION
0x09FC,6      // ZC_PET_EVOLUTION_RESULT
=cut
