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
package Network::Receive::kRO::RagexeRE_2017_07_26c;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_06_14b);


1;
=pod
// 20170726
if (packetVersion == 20170726)
{
    packet(CMSG_BUYINGSTORE_CREATE,       0x0363,  -1, clif->pReqOpenBuyingStore);
	packet(CMSG_MOVE_TO_STORAGE,          0x0364,   8, clif->pMoveToKafra);
    packet(CMSG_MAP_SERVER_CONNECT,       0x0366,  19, clif->pWantToConnection);
    packet(CMSG_SKILL_USE_BEING,          0x0369,  10, clif->pUseSkillToId);
    packet(CMSG_PARTY_INVITE2,            0x0438,  26, clif->pPartyInvite2);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x0838,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0873,   6, clif->pReqClickBuyingStore);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0874,  -1, clif->pItemListWindowSelected);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x0878,   7, clif->pActionRequest);
//  packet(UNKNOWN,                       0x0881,   4, clif->pDull);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0888,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x088e,   5, clif->pWalkToXY);
//  packet(UNKNOWN,                       0x08a3,   8, clif->pDull);
    packet(CMSG_STORAGE_PASSWORD,         0x08a7,  36, clif->pStoragePassword);
    packet(CMSG_NAME_REQUEST,             0x08aa,   6, clif->pGetCharNameRequest);
    packet(CMSG_ITEM_PICKUP,              0x08ab,   6, clif->pTakeItem);
    packet(CMSG_MAP_PING,                 0x08ac,   6, clif->pTickSend);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x091d,  26, clif->pFriendsListAdd);
    packet(CMSG_SEARCHSTORE_CLICK,        0x091e,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_HOMUNCULUS_MENU,          0x091f,   5, clif->pHomMenu);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0921,   6, clif->pSolveCharName);
    packet(CMSG_BUYINGSTORE_SELL,         0x0923,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0943,   6, clif->pDropItem);
    packet(CMSG_MOVE_FROM_STORAGE,        0x094f,   8, clif->pMoveFromKafra);
    packet(CMSG_SKILL_USE_POSITION,       0x0950,  10, clif->pUseSkillToPos);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x0952,   5, clif->pChangeDir);
    packet(CMSG_BOOKING_REGISTER_REQ,     0x0954,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x095a,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x0963,  -1, clif->pSearchStoreInfo);
}

=cut
