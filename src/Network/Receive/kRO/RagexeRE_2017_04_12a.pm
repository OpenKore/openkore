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
use base qw(Network::Receive::kRO::RagexeRE_2017_02_08b);

sub new {
	my ($class) = @_;
	return $class->SUPER::new(@_);
}

1;
=pod
// 20170412
if (packetVersion == 20170412)
{
    packet(CMSG_SKILL_USE_POSITION,       0x023b,  10, clif->pUseSkillToPos);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0365,   6, clif->pReqClickBuyingStore);
    packet(CMSG_BUYINGSTORE_SELL,         0x0863,  -1, clif->pReqTradeBuyingStore);
//  packet(UNKNOWN,                       0x0869,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_MOVE_FROM_STORAGE,        0x086d,   8, clif->pMoveFromKafra);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x0878,   5, clif->pWalkToXY);
//  packet(UNKNOWN,                       0x0879,   4, clif->pDull);
    packet(CMSG_SKILL_USE_BEING,          0x087b,  10, clif->pUseSkillToId);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x088b,  -1, clif->pSearchStoreInfo);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0890,  -1, clif->pItemListWindowSelected);
    packet(CMSG_BUYINGSTORE_CREATE,       0x0893,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0898,   6, clif->pSolveCharName);
    packet(CMSG_HOMUNCULUS_MENU,          0x089a,   5, clif->pHomMenu);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x089c,   6, clif->pDropItem);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x08a1,   7, clif->pActionRequest);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x091a,   5, clif->pChangeDir);
    packet(CMSG_MAP_SERVER_CONNECT,       0x091e,  19, clif->pWantToConnection);
    packet(CMSG_MAP_PING,                 0x0929,   6, clif->pTickSend);
//  packet(UNKNOWN,                       0x092e,   8, clif->pDull);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x0938,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0942,  26, clif->pFriendsListAdd);
    packet(CMSG_MOVE_TO_STORAGE,          0x0945,   8, clif->pMoveToKafra);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0949,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_PARTY_INVITE2,            0x094f,  26, clif->pPartyInvite2);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x0952,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_ITEM_PICKUP,              0x0959,   6, clif->pTakeItem);
    packet(CMSG_NAME_REQUEST,             0x095b,   6, clif->pGetCharNameRequest);
    packet(CMSG_SEARCHSTORE_CLICK,        0x095c,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_STORAGE_PASSWORD,         0x095d,  36, clif->pStoragePassword);
}
=cut	
