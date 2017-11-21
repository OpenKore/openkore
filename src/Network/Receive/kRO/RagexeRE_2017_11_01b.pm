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
package Network::Receive::kRO::RagexeRE_2017_11_01b;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_10_25b);


1;
=pod
// 20171101
if (packetVersion == 20171101)
{
    packet(CMSG_STORAGE_PASSWORD,         022d,  36, clif->pStoragePassword);
    packet(CMSG_MAP_SERVER_CONNECT,       0368,  19, clif->pWantToConnection);
    packet(CMSG_SEARCHSTORE_SEARCH,       0369,  -1, clif->pSearchStoreInfo);
    packet(CMSG_MAP_PING,                 0438,   6, clif->pTickSend);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0835,   6, clif->pDropItem);
    packet(CMSG_HOMUNCULUS_MENU,          085b,   5, clif->pHomMenu);
    packet(CMSG_NAME_REQUEST,             0860,   6, clif->pGetCharNameRequest);
    packet(CMSG_SKILL_USE_BEING,          086c,  10, clif->pUseSkillToId);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0872,  26, clif->pFriendsListAdd);
    packet(CMSG_PLAYER_CHANGE_DIR,        0876,   5, clif->pChangeDir);
//  packet(UNKNOWN,                       0886,   8, clif->pDull);
    packet(CMSG_BUYINGSTORE_OPEN,         088e,   6, clif->pReqClickBuyingStore);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0890,   2, clif->pSearchStoreInfoNextPage);
//  packet(UNKNOWN,                       0895,   4, clif->pDull);
    packet(CMSG_PARTY_INVITE2,            0899,  26, clif->pPartyInvite2);
    packet(CMSG_BUYINGSTORE_CREATE,       089b,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_BOOKING_REGISTER_REQ,     089c,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_MOVE_FROM_STORAGE,        08a0,   8, clif->pMoveFromKafra);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  08ab,  -1, clif->pItemListWindowSelected);
    packet(CMSG_SEARCHSTORE_CLICK,        08ad,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_MOVE_TO_STORAGE,          091b,   8, clif->pMoveToKafra);
    packet(CMSG_PLAYER_CHANGE_DEST,       0939,   5, clif->pWalkToXY);
    packet(CMSG_BUYINGSTORE_CLOSE,        094a,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_SOLVE_CHAR_NAME,          094d,   6, clif->pSolveCharName);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0952,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_PLAYER_CHANGE_ACT,        0957,   7, clif->pActionRequest);
    packet(CMSG_BUYINGSTORE_SELL,         095a,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_ITEM_PICKUP,              0962,   6, clif->pTakeItem);
    packet(CMSG_SKILL_USE_POSITION,       0966,  10, clif->pUseSkillToPos);

#	elif PACKETVER == 20171101 // 2017-11-01bRagexeRE
#	packet_keys(0x7056317F,0x7EEE0589,0x02672373);
=cut
