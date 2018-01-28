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
package Network::Receive::kRO::RagexeRE_2014_09_17c;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2014_03_05);

1;
=pod
// 20140917
if (packetVersion == 20140917)
{
    packet(CMSG_PARTY_INVITE2,            0x022d,  26, clif->pPartyInvite2);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0364,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_MOVE_TO_STORAGE,          0x0365,   8, clif->pMoveToKafra);
    packet(CMSG_MAP_SERVER_CONNECT,       0x0366,  19, clif->pWantToConnection);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x0367,  -1, clif->pSearchStoreInfo);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0369,   6, clif->pSolveCharName);
    packet(CMSG_BUYINGSTORE_CREATE,       0x0838,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_ITEM_PICKUP,              0x0864,   6, clif->pTakeItem);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x086d,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x0889,   7, clif->pActionRequest);
    packet(CMSG_HOMUNCULUS_MENU,          0x0895,   5, clif->pHomMenu);
    packet(CMSG_MAP_PING,                 0x0897,   6, clif->pTickSend);
    packet(CMSG_NAME_REQUEST,             0x0898,   6, clif->pGetCharNameRequest);
    packet(CMSG_BUYINGSTORE_OPEN,         0x089c,   6, clif->pReqClickBuyingStore);
    packet(CMSG_STORAGE_PASSWORD,         0x08a8,  36, clif->pStoragePassword);
    packet(CMSG_BUYINGSTORE_SELL,         0x0919,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x091e,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_SEARCHSTORE_CLICK,        0x092a,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_MOVE_FROM_STORAGE,        0x0930,   8, clif->pMoveFromKafra);
    packet(CMSG_SKILL_USE_BEING,          0x0949,  10, clif->pUseSkillToId);
    packet(CMSG_SKILL_USE_POSITION,       0x094f,  10, clif->pUseSkillToPos);
//  packet(UNKNOWN,                       0x0951,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0955,  26, clif->pFriendsListAdd);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0956,  -1, clif->pItemListWindowSelected);
//  packet(UNKNOWN,                       0x0957,   8, clif->pDull);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x095a,   6, clif->pDropItem);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x095c,   5, clif->pWalkToXY);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x095e,   5, clif->pChangeDir);
//  packet(UNKNOWN,                       0x0966,   4, clif->pDull);
=cut
