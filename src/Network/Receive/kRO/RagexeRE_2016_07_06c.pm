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
package Network::Receive::kRO::RagexeRE_2016_07_06c;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_04_14b);


1;
=pod
// 20160706
if (packetVersion == 20160706)
{
packet(CMSG_SOLVE_CHAR_NAME,          0x0362,   6, clif->pSolveCharName);
packet(CMSG_BUYINGSTORE_OPEN,         0x0436,   6, clif->pReqClickBuyingStore);
packet(CMSG_PARTY_INVITE2,            0x085f,  26, clif->pPartyInvite2);
packet(CMSG_PLAYER_CHANGE_ACT,        0x0860,   7, clif->pActionRequest);
packet(CMSG_BUYINGSTORE_SELL,         0x0869,  -1, clif->pReqTradeBuyingStore);
packet(CMSG_BUYINGSTORE_CREATE,       0x086b,  -1, clif->pReqOpenBuyingStore);
packet(CMSG_FRIENDS_ADD_PLAYER,       0x0884,  26, clif->pFriendsListAdd);
//  packet(UNKNOWN,                       0x0886,   4, clif->pDull);
packet(CMSG_SEARCHSTORE_SEARCH,       0x0889,  -1, clif->pSearchStoreInfo);
packet(CMSG_HOMUNCULUS_MENU,          0x0892,   5, clif->pHomMenu);
packet(CMSG_SKILL_USE_BEING,          0x0899,  10, clif->pUseSkillToId);
packet(CMSG_BOOKING_REGISTER_REQ,     0x08a4,  18, clif->pPartyBookingRegisterReq);
packet(CMSG_MAP_SERVER_CONNECT,       0x08a5,  19, clif->pWantToConnection);
packet(CMSG_MAP_PING,                 0x08a8,   6, clif->pTickSend);
packet(CMSG_SKILL_USE_POSITION_MORE,  0x0918,  90, clif->pUseSkillToPosMoreInfo);
packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x091b,  -1, clif->pItemListWindowSelected);
packet(CMSG_SKILL_USE_POSITION,       0x0924,  10, clif->pUseSkillToPos);
packet(CMSG_PLAYER_CHANGE_DIR,        0x0926,   5, clif->pChangeDir);
packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0927,   2, clif->pSearchStoreInfoNextPage);
packet(CMSG_MOVE_FROM_STORAGE,        0x0929,   8, clif->pMoveFromKafra);
packet(CMSG_PLAYER_CHANGE_DEST,       0x092d,   5, clif->pWalkToXY);
packet(CMSG_MOVE_TO_STORAGE,          0x0939,   8, clif->pMoveToKafra);
packet(CMSG_PLAYER_INVENTORY_DROP,    0x093d,   6, clif->pDropItem);
//  packet(UNKNOWN,                       0x0944,   8, clif->pDull);
packet(CMSG_NAME_REQUEST,             0x0945,   6, clif->pGetCharNameRequest);
packet(CMSG_STORAGE_PASSWORD,         0x094c,  36, clif->pStoragePassword);
packet(CMSG_BUYINGSTORE_CLOSE,        0x0952,   2, clif->pReqCloseBuyingStore);
packet(CMSG_SEARCHSTORE_CLICK,        0x0957,  12, clif->pSearchStoreInfoListItemClick);
packet(CMSG_ITEM_PICKUP,              0x0958,   6, clif->pTakeItem);
}
=cut
