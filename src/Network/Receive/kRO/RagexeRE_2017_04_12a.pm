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
package Network::Receive::kRO::RagexeRE_2017_04_12a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_01_25a);


1;
=pod
// 20170517
if (packetVersion == 20170517)
{
//  packet(UNKNOWN,                       0x0364,   8, clif->pDull);
packet(CMSG_BUYINGSTORE_CREATE,       0x0367,  -1, clif->pReqOpenBuyingStore);
packet(CMSG_PLAYER_CHANGE_ACT,        0x0437,   7, clif->pActionRequest);
packet(CMSG_BOOKING_REGISTER_REQ,     0x0802,  18, clif->pPartyBookingRegisterReq);
packet(CMSG_SKILL_USE_BEING,          0x0815,  10, clif->pUseSkillToId);
packet(CMSG_SKILL_USE_POSITION,       0x0817,  10, clif->pUseSkillToPos);
packet(CMSG_SKILL_USE_POSITION_MORE,  0x0868,  90, clif->pUseSkillToPosMoreInfo);
packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0875,   2, clif->pSearchStoreInfoNextPage);
packet(CMSG_SOLVE_CHAR_NAME,          0x087b,   6, clif->pSolveCharName);
packet(CMSG_SEARCHSTORE_SEARCH,       0x087d,  -1, clif->pSearchStoreInfo);
packet(CMSG_MOVE_FROM_STORAGE,        0x088c,   8, clif->pMoveFromKafra);
packet(CMSG_PLAYER_CHANGE_DIR,        0x088d,   5, clif->pChangeDir);
packet(CMSG_NAME_REQUEST,             0x0894,   6, clif->pGetCharNameRequest);
packet(CMSG_SEARCHSTORE_CLICK,        0x0896,  12, clif->pSearchStoreInfoListItemClick);
packet(CMSG_PARTY_INVITE2,            0x0899,  26, clif->pPartyInvite2);
//  packet(UNKNOWN,                       0x089e,   4, clif->pDull);
packet(CMSG_BUYINGSTORE_CLOSE,        0x089f,   2, clif->pReqCloseBuyingStore);
packet(CMSG_MAP_PING,                 0x08a2,   6, clif->pTickSend);
packet(CMSG_PLAYER_CHANGE_DEST,       0x08a8,   5, clif->pWalkToXY);
packet(CMSG_MOVE_TO_STORAGE,          0x08aa,   8, clif->pMoveToKafra);
packet(CMSG_BUYINGSTORE_SELL,         0x091b,  -1, clif->pReqTradeBuyingStore);
packet(CMSG_MAP_SERVER_CONNECT,       0x0923,  19, clif->pWantToConnection);
packet(CMSG_PLAYER_INVENTORY_DROP,    0x093b,   6, clif->pDropItem);
packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0945,  -1, clif->pItemListWindowSelected);
packet(CMSG_BUYINGSTORE_OPEN,         0x0946,   6, clif->pReqClickBuyingStore);
packet(CMSG_STORAGE_PASSWORD,         0x0947,  36, clif->pStoragePassword);
packet(CMSG_HOMUNCULUS_MENU,          0x0958,   5, clif->pHomMenu);
packet(CMSG_FRIENDS_ADD_PLAYER,       0x0960,  26, clif->pFriendsListAdd);
packet(CMSG_ITEM_PICKUP,              0x0964,   6, clif->pTakeItem);
}
=cut	
