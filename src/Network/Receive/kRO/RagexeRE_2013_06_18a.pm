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
package Network::Receive::kRO::RagexeRE_2013_06_18a;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2013_05_22);

1;
=pod
// 20130618
if (packetVersion == 20130618)
{
    packet(CMSG_SEARCHSTORE_SEARCH,       0x0281,  -1, clif->pSearchStoreInfo);
    packet(CMSG_HOMUNCULUS_MENU,          0x02c4,   5, clif->pHomMenu);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0363,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x085a,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0862,   6, clif->pReqClickBuyingStore);
    packet(CMSG_STORAGE_PASSWORD,         0x0864,  36, clif->pStoragePassword);
//  packet(UNKNOWN,                       0x0878,   4, clif->pDull);
//  packet(UNKNOWN,                       0x087a,   8, clif->pDull);
    packet(CMSG_MOVE_TO_STORAGE,          0x0885,   8, clif->pMoveToKafra);
    packet(CMSG_PARTY_INVITE2,            0x0887,  26, clif->pPartyInvite2);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x0889,   7, clif->pActionRequest);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x088e,   5, clif->pWalkToXY);
    packet(CMSG_SEARCHSTORE_CLICK,        0x0890,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_BUYINGSTORE_SELL,         0x0891,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x08a6,   5, clif->pChangeDir);
//  packet(UNKNOWN,                       0x08a7,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0917,   6, clif->pDropItem);
    packet(CMSG_MAP_PING,                 0x0930,   6, clif->pTickSend);
    packet(CMSG_BUYINGSTORE_CREATE,       0x0932,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_MOVE_FROM_STORAGE,        0x0936,   8, clif->pMoveFromKafra);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0942,  -1, clif->pItemListWindowSelected);
    packet(CMSG_NAME_REQUEST,             0x0944,   6, clif->pGetCharNameRequest);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0945,   6, clif->pSolveCharName);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x094f,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_SKILL_USE_BEING,          0x0951,  10, clif->pUseSkillToId);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0953,  26, clif->pFriendsListAdd);
    packet(CMSG_MAP_SERVER_CONNECT,       0x095b,  19, clif->pWantToConnection);
    packet(CMSG_ITEM_PICKUP,              0x0962,   6, clif->pTakeItem);
    packet(CMSG_SKILL_USE_POSITION,       0x096a,  10, clif->pUseSkillToPos);
}
=cut
