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

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0A09' => ['deal_add_other', 'v C V C3 a8 a25', [qw(nameID type amount identified broken upgrade cards options)]],
		'0A0A' => ['storage_item_added', 'v V v C4 a8 a25', [qw(index amount nameID type identified broken upgrade cards options)]],
		'0A0B' => ['cart_item_added', 'v V v C4 a8 a25', [qw(index amount nameID type identified broken upgrade cards options)]],
		'0A0C' => ['inventory_item_added', 'v3 C3 a8 V C2 a4 v a25', [qw(index amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],
		'0A0D' => ['inventory_items_nonstackable', 'v a*', [qw(len itemInfo)]],
		'0A0F' => ['cart_items_nonstackable', 'v a*', [qw(len itemInfo)]],
		'0A10' => ['storage_items_nonstackable', 'v Z24 a*', [qw(len title itemInfo)]],
		'0A2D' => ['character_equip', 'v Z24 x17 a*', [qw(len name itemInfo)]],
		'0A30' => ['actor_info', 'a4 Z24 Z24 Z24 Z24', [qw(ID name partyName guildName guildTitle)]], # 102! Must be working at 106 size
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	return $self;
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
