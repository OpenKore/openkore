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
package Network::Receive::kRO::RagexeRE_2016_01_13b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_01_06a);

1;
=pod
/// 20160113
if (packetVersion == 20160113)
{
    packet(CMSG_SKILL_USE_POSITION,       0x022d,  10, clif->pUseSkillToPos);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x023b,   5, clif->pWalkToXY);
//  packet(UNKNOWN,                       0x035f,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_STORAGE_PASSWORD,         0x0815,  36, clif->pStoragePassword);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x085b,   5, clif->pChangeDir);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0864,   6, clif->pReqClickBuyingStore);
    packet(CMSG_HOMUNCULUS_MENU,          0x086d,   5, clif->pHomMenu);
//  packet(UNKNOWN,                       0x0873,   4, clif->pDull);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0875,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x0888,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_PARTY_INVITE2,            0x088b,  26, clif->pPartyInvite2);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x088c,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_SKILL_USE_BEING,          0x0892,  10, clif->pUseSkillToId);
    packet(CMSG_BUYINGSTORE_SELL,         0x0893,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0899,  26, clif->pFriendsListAdd);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x089a,   7, clif->pActionRequest);
    packet(CMSG_MAP_PING,                 0x08a0,   6, clif->pTickSend);
    packet(CMSG_ITEM_PICKUP,              0x08a6,   6, clif->pTakeItem);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x08aa,  -1, clif->pSearchStoreInfo);
    packet(CMSG_SEARCHSTORE_CLICK,        0x0919,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_NAME_REQUEST,             0x091b,   6, clif->pGetCharNameRequest);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0924,   6, clif->pDropItem);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0930,   6, clif->pSolveCharName);
    packet(CMSG_MOVE_TO_STORAGE,          0x0932,   8, clif->pMoveToKafra);
    packet(CMSG_MOVE_FROM_STORAGE,        0x093c,   8, clif->pMoveFromKafra);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0941,  -1, clif->pItemListWindowSelected);
    packet(CMSG_MAP_SERVER_CONNECT,       0x094d,  19, clif->pWantToConnection);
//  packet(UNKNOWN,                       0x094f,   8, clif->pDull);
    packet(CMSG_BUYINGSTORE_CREATE,       0x0967,  -1, clif->pReqOpenBuyingStore);
}
=cut
