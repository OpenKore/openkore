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
package Network::Receive::kRO::RagexeRE_2017_04_19b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_04_12a);


1;
=pod
// 20170419
if (packetVersion == 20170419)
{
    packet(CMSG_PLAYER_CHANGE_DIR,        0x0811,   5, clif->pChangeDir);
    packet(CMSG_SEARCHSTORE_CLICK,        0x0819,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_NAME_REQUEST,             0x0838,   6, clif->pGetCharNameRequest);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x085a,   7, clif->pActionRequest);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x085e,   5, clif->pWalkToXY);
    packet(CMSG_PARTY_INVITE2,            0x0862,  26, clif->pPartyInvite2);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x0868,  -1, clif->pSearchStoreInfo);
    packet(CMSG_BOOKING_REGISTER_REQ,     0x086a,  18, clif->pPartyBookingRegisterReq);
//  packet(UNKNOWN,                       0x0872,   8, clif->pDull);
    packet(CMSG_STORAGE_PASSWORD,         0x0881,  36, clif->pStoragePassword);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x088d,  -1, clif->pItemListWindowSelected);
    packet(CMSG_HOMUNCULUS_MENU,          0x088f,   5, clif->pHomMenu);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0897,   6, clif->pDropItem);
    packet(CMSG_MAP_PING,                 0x0898,   6, clif->pTickSend);
    packet(CMSG_BUYINGSTORE_CREATE,       0x089d,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_MOVE_TO_STORAGE,          0x08aa,   8, clif->pMoveToKafra);
    packet(CMSG_SOLVE_CHAR_NAME,          0x091b,   6, clif->pSolveCharName);
    packet(CMSG_SKILL_USE_BEING,          0x0920,  10, clif->pUseSkillToId);
    packet(CMSG_MAP_SERVER_CONNECT,       0x0922,  19, clif->pWantToConnection);
    packet(CMSG_MOVE_FROM_STORAGE,        0x0930,   8, clif->pMoveFromKafra);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x0931,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x0935,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x093a,  26, clif->pFriendsListAdd);
    packet(CMSG_SKILL_USE_POSITION,       0x093f,  10, clif->pUseSkillToPos);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0942,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_ITEM_PICKUP,              0x095c,   6, clif->pTakeItem);
    packet(CMSG_BUYINGSTORE_SELL,         0x095d,  -1, clif->pReqTradeBuyingStore);
//  packet(UNKNOWN,                       0x0963,   4, clif->pDull);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0965,   6, clif->pReqClickBuyingStore);
=cut	
