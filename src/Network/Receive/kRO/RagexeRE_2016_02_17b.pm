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
package Network::Receive::kRO::RagexeRE_2016_02_17b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_02_03a);

1;
=pod
// 20160217
if (packetVersion == 20160217)
{
    packet(CMSG_BUYINGSTORE_SELL,         0x0202,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x023b,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x0362,   5, clif->pChangeDir);
    packet(CMSG_SEARCHSTORE_CLICK,        0x0365,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_MOVE_TO_STORAGE,          0x0864,   8, clif->pMoveToKafra);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0870,  26, clif->pFriendsListAdd);
    packet(CMSG_HOMUNCULUS_MENU,          0x0873,   5, clif->pHomMenu);
    packet(CMSG_MAP_SERVER_CONNECT,       0x087a,  19, clif->pWantToConnection);
    packet(CMSG_MAP_PING,                 0x0888,   6, clif->pTickSend);
    packet(CMSG_BUYINGSTORE_OPEN,         0x088d,   6, clif->pReqClickBuyingStore);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x088f,   6, clif->pDropItem);
//  packet(UNKNOWN,                       0x0899,   4, clif->pDull);
    packet(CMSG_MOVE_FROM_STORAGE,        0x08a0,   8, clif->pMoveFromKafra);
    packet(CMSG_PARTY_INVITE2,            0x08a9,  26, clif->pPartyInvite2);
//  packet(UNKNOWN,                       0x08ac,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x08ad,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x091d,   5, clif->pWalkToXY);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x0920,   7, clif->pActionRequest);
    packet(CMSG_SKILL_USE_BEING,          0x0926,  10, clif->pUseSkillToId);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x092e,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x093b,  -1, clif->pItemListWindowSelected);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x093e,  -1, clif->pSearchStoreInfo);
    packet(CMSG_ITEM_PICKUP,              0x0941,   6, clif->pTakeItem);
    packet(CMSG_SKILL_USE_POSITION,       0x094a,  10, clif->pUseSkillToPos);
//  packet(UNKNOWN,                       0x094f,   8, clif->pDull);
    packet(CMSG_STORAGE_PASSWORD,         0x095e,  36, clif->pStoragePassword);
    packet(CMSG_NAME_REQUEST,             0x0966,   6, clif->pGetCharNameRequest);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0967,   6, clif->pSolveCharName);
    packet(CMSG_BUYINGSTORE_CREATE,       0x0969,  -1, clif->pReqOpenBuyingStore);
}

=cut
