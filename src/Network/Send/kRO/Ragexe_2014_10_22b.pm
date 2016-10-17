package Network::Send::kRO::Ragexe_2014_10_22b;

use strict;
use base qw(Network::Send::kRO::RagexeRE_2013_08_07a);

sub new {
   my ($class) = @_;
   my $self = $class->SUPER::new(@_);
  
   my %packets = (
       '08A2' => undef,
       '0369' => ['actor_action', 'a4 C', [qw(targetID type)]],#7
       '095C' => undef,
       '083C' => ['skill_use', 'v2 a4', [qw(lv skillID targetID)]],#10
       '0360' => undef,
       '0437' => ['character_move','a3', [qw(coordString)]],#5
#      '07EC' => undef,
       '035F' => ['sync', 'V', [qw(time)]],#6
       '0925' => undef,
       '08AD' => ['actor_look_at', 'v C', [qw(head body)]],#5
       '095E' => undef,
       '094E' => ['item_take', 'a4', [qw(ID)]],#6
       '089C' => undef,
       '087D' => ['item_drop', 'v2', [qw(index amount)]],#6
       '08A3' => undef,
       '0878' => ['storage_item_add', 'v V', [qw(index amount)]],#8
       '087E' => undef,
       '08AA' => ['storage_item_remove', 'v V', [qw(index amount)]],#8
       '0811' => undef,
       '023B' => ['skill_use_location', 'v4', [qw(lv skillID x y)]],#10
       '08A6' => undef,
       '096A' => ['actor_info_request', 'a4', [qw(ID)]],#6
#      '0369' => undef,
       '0368' => ['actor_name_request', 'a4', [qw(ID)]],#6
       '08A9' => undef,
       '093B' => ['map_login', 'a4 a4 a4 V C', [qw(accountID charID sessionID tick sex)]],#19
       '0950' => undef,
       '0896' => ['party_join_request_by_name', 'Z24', [qw(partyName)]],#26
#      '0362' => undef,
       '091A' => ['friend_request', 'a*', [qw(username)]],#26
       '0926' => undef,
       '0899' => ['homunculus_command', 'v C', [qw(commandType, commandID)]],#5
   );
   $self->{packet_list}{$_} = $packets{$_} for keys %packets;

   my %handlers = qw(
       actor_action 0369
       actor_info_request 096A
       actor_look_at 08AD
       actor_name_request 0368
       character_move 0437
       friend_request 091A
       homunculus_command 0899
       item_drop 087D
       item_take 094E
       map_login 093B
       party_join_request_by_name 0896
       skill_use 083C
       skill_use_location 023B
       storage_item_add 0878
       storage_item_remove 08AA
       sync 035F
   );
   $self->{packet_lut}{$_} = $handlers{$_} for keys %handlers;

#  $self->cryptKeys(688214506, 731196533, 761751195);

   $self;
}

1;

=pod
//2014-10-22bRagexe
packet_ver: 51
packet_keys: 0x290551EA,0x2B952C75,0x2D67669B // [YomRawr]
0x006d,149
0x023b,10,useskilltopos,2:4:6:8
0x0281,-1,itemlistwindowselected,2:4:8:12
0x035f,6,ticksend,2
0x0360,6,reqclickbuyingstore,2
0x0366,90,useskilltoposinfo,2:4:6:8:10
0x0368,6,solvecharname,2
0x0369,7,actionrequest,2:6
0x0437,5,walktoxy,2
0x0438,36,storagepassword,2:4:20
0x0811,-1,reqtradebuyingstore,2:4:8:12
0x0815,-1,reqopenbuyingstore,2:4:8:9:89
0x0817,2,reqclosebuyingstore,0
0x0819,-1,searchstoreinfo,2:4:5:9:13:14:15
0x0835,12,searchstoreinfolistitemclick,2:6:10
0x083c,10,useskilltoid,2:4:6
0x0878,8,movetokafra,2:4
0x087d,6,dropitem,2:4
0x0896,26,partyinvite2,2
0x0899,5,hommenu,2:4
0x08aa,8,movefromkafra,2:4
//0x08ab,4 // CZ_GANGSI_RANK
0x08ad,5,changedir,2:4
0x08e3,149
0x091a,26,friendslistadd,2
//0x092b,8 // CZ_JOIN_BATTLE_FIELD
0x093b,19,wanttoconnection,2:6:10:14:18
0x0940,2,searchstoreinfonextpage,0
0x094e,6,takeitem,2
0x0955,18,bookingregreq,2:4:6
0x096a,6,getcharnamerequest,2

#  packet(0x0369,7,clif->pActionRequest,2,6);
#  packet(0x083C,10,clif->pUseSkillToId,2,4,6);
#  packet(0x0437,5,clif->pWalkToXY,2);
#  packet(0x035F,6,clif->pTickSend,2);
#  packet(0x08AD,5,clif->pChangeDir,2,4);
#  packet(0x094E,6,clif->pTakeItem,2);
#  packet(0x087D,6,clif->pDropItem,2,4);
#  packet(0x0878,8,clif->pMoveToKafra,2,4);
#  packet(0x08AA,8,clif->pMoveFromKafra,2,4);
#  packet(0x023B,10,clif->pUseSkillToPos,2,4,6,8);
   packet(0x0366,90,clif->pUseSkillToPosMoreInfo,2,4,6,8,10);
#  packet(0x096A,6,clif->pGetCharNameRequest,2);
#  packet(0x0368,6,clif->pSolveCharName,2);
   packet(0x0835,12,clif->pSearchStoreInfoListItemClick,2,6,10);
   packet(0x0940,2,clif->pSearchStoreInfoNextPage,0);
   packet(0x0819,-1,clif->pSearchStoreInfo,2,4,5,9,13,14,15);
   packet(0x0811,-1,clif->pReqTradeBuyingStore,2,4,8,12);
   packet(0x0360,6,clif->pReqClickBuyingStore,2);
   packet(0x0817,2,clif->pReqCloseBuyingStore,0);
   packet(0x0815,-1,clif->pReqOpenBuyingStore,2,4,8,9,89);
   packet(0x0955,18,clif->pPartyBookingRegisterReq,2,4);
   // packet(0x092B,8); // CZ_JOIN_BATTLE_FIELD
   packet(0x0281,-1,clif->pItemListWindowSelected,2,4,8);
#  packet(0x093B,19,clif->pWantToConnection,2,6,10,14,18);
#  packet(0x0896,26,clif->pPartyInvite2,2);
   // packet(0x08AB,4); // CZ_GANGSI_RANK
#  packet(0x091A,26,clif->pFriendsListAdd,2);
#  packet(0x0899,5,clif->pHomMenu,2,4);
   packet(0x0438,36,clif->pStoragePassword,0);
   packet(0x0A01,3,clif->pHotkeyRowShift,2);

=cut