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
package Network::Receive::kRO::RagexeRE_2015_09_23d;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_09_16);


1;
=pod
// 20150923
if (packetVersion == 20150923)
{
//  packet(UNKNOWN,                       0x0361,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x0366,  -1, clif->pSearchStoreInfo);
    packet(CMSG_STORAGE_PASSWORD,         0x07e4,  36, clif->pStoragePassword);
    packet(CMSG_BUYINGSTORE_SELL,         0x0817,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_SOLVE_CHAR_NAME,          0x085c,   6, clif->pSolveCharName);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x085d,  26, clif->pFriendsListAdd);
    packet(CMSG_HOMUNCULUS_MENU,          0x0864,   5, clif->pHomMenu);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x086e,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_SKILL_USE_BEING,          0x086f,  10, clif->pUseSkillToId);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x0870,   5, clif->pChangeDir);
    packet(CMSG_MOVE_FROM_STORAGE,        0x0879,   8, clif->pMoveFromKafra);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x087f,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x0886,   5, clif->pWalkToXY);
    packet(CMSG_BUYINGSTORE_OPEN,         0x088e,   6, clif->pReqClickBuyingStore);
    packet(CMSG_BUYINGSTORE_CREATE,       0x0892,  -1, clif->pReqOpenBuyingStore);
//  packet(UNKNOWN,                       0x0895,   4, clif->pDull);
    packet(CMSG_SKILL_USE_POSITION,       0x089b,  10, clif->pUseSkillToPos);
    packet(CMSG_MOVE_TO_STORAGE,          0x089f,   8, clif->pMoveToKafra);
    packet(CMSG_MAP_PING,                 0x08a0,   6, clif->pTickSend);
    packet(CMSG_MAP_SERVER_CONNECT,       0x08a2,  19, clif->pWantToConnection);
    packet(CMSG_NAME_REQUEST,             0x08a5,   6, clif->pGetCharNameRequest);
    packet(CMSG_SEARCHSTORE_CLICK,        0x08a6,  12, clif->pSearchStoreInfoListItemClick);
//  packet(UNKNOWN,                       0x091e,   8, clif->pDull);
    packet(CMSG_ITEM_PICKUP,              0x092b,   6, clif->pTakeItem);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0930,   6, clif->pDropItem);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x0936,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_PARTY_INVITE2,            0x093b,  26, clif->pPartyInvite2);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x0951,   7, clif->pActionRequest);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0961,  -1, clif->pItemListWindowSelected);
}
=cut	
