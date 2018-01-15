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
# Korea (kRO) #bysctnightcore
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2015_10_29a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_10_01b);


1;
=pod
// 20151029
if (packetVersion == 20151029)
{
packet(CMSG_PLAYER_CHANGE_DIR,        0x0202,   5, clif->pChangeDir);
packet(CMSG_MAP_SERVER_CONNECT,       0x022d,  19, clif->pWantToConnection);
packet(CMSG_FRIENDS_ADD_PLAYER,       0x023b,  26, clif->pFriendsListAdd);
packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0281,  -1, clif->pItemListWindowSelected);
packet(CMSG_MAP_PING,                 0x035f,   6, clif->pTickSend);
packet(CMSG_BUYINGSTORE_OPEN,         0x0360,   6, clif->pReqClickBuyingStore);
packet(CMSG_HOMUNCULUS_MENU,          0x0361,   5, clif->pHomMenu);
packet(CMSG_PLAYER_INVENTORY_DROP,    0x0362,   6, clif->pDropItem);
//  packet(UNKNOWN,                       0x0363,   8, clif->pDull);
packet(CMSG_MOVE_FROM_STORAGE,        0x0364,   8, clif->pMoveFromKafra);
//  packet(UNKNOWN,                       0x0365,  18, clif->pPartyBookingRegisterReq);
packet(CMSG_SKILL_USE_POSITION_MORE,  0x0366,  90, clif->pUseSkillToPosMoreInfo);
packet(CMSG_SOLVE_CHAR_NAME,          0x0368,   6, clif->pSolveCharName);
packet(CMSG_PLAYER_CHANGE_ACT,        0x0369,   7, clif->pActionRequest);
//  packet(UNKNOWN,                       0x0436,   4, clif->pDull);
packet(CMSG_PLAYER_CHANGE_DEST,       0x0437,   5, clif->pWalkToXY);
packet(CMSG_SKILL_USE_POSITION,       0x0438,  10, clif->pUseSkillToPos);
packet(CMSG_ITEM_PICKUP,              0x07e4,   6, clif->pTakeItem);
packet(CMSG_MOVE_TO_STORAGE,          0x07ec,   8, clif->pMoveToKafra);
packet(CMSG_PARTY_INVITE2,            0x0802,  26, clif->pPartyInvite2);
packet(CMSG_BUYINGSTORE_SELL,         0x0811,  -1, clif->pReqTradeBuyingStore);
packet(CMSG_BUYINGSTORE_CREATE,       0x0815,  -1, clif->pReqOpenBuyingStore);
packet(CMSG_BUYINGSTORE_CLOSE,        0x0817,   2, clif->pReqCloseBuyingStore);
packet(CMSG_SEARCHSTORE_SEARCH,       0x0819,  -1, clif->pSearchStoreInfo);
packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0835,   2, clif->pSearchStoreInfoNextPage);
packet(CMSG_SEARCHSTORE_CLICK,        0x0838,  12, clif->pSearchStoreInfoListItemClick);
packet(CMSG_SKILL_USE_BEING,          0x083c,  10, clif->pUseSkillToId);
packet(CMSG_STORAGE_PASSWORD,         0x0860,  36, clif->pStoragePassword);
packet(CMSG_NAME_REQUEST,             0x096a,   6, clif->pGetCharNameRequest);
}
=cut	
