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
package Network::Receive::kRO::RagexeRE_2017_09_20b;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_09_13b);


1;
=pod
// Hercules version: 20170920
// 2017-09-20bRagexeRE
#if PACKETVER == 20170920
// shuffle packets
	packet(0x0369,6,clif->pTakeItem,2); // added in same version  // CZ_ITEM_PICKUP
	packet(0x0436,-1,clif->pItemListWindowSelected,2,4,8); // added in same version  // CZ_ITEMLISTWIN_RES
	packet(0x07ec,8,clif->pMoveFromKafra,2,4); // added in same version  // CZ_MOVE_ITEM_FROM_STORE_TO_BODY
	packet(0x085a,5,clif->pWalkToXY,2); // added in same version  // CZ_REQUEST_MOVE
	packet(0x0861,26,clif->pFriendsListAdd,2); // added in same version  // CZ_ADD_FRIENDS
	packet(0x0862,10,clif->pUseSkillToId,2,4,6); // added in same version  // CZ_USE_SKILL
	packet(0x0864,36,clif->pStoragePassword,0); // added in same version  // CZ_ACK_STORE_PASSWORD
	packet(0x0865,-1,clif->pReqOpenBuyingStore,2,4,8,9,89); // added in same version  // CZ_REQ_OPEN_BUYING_STORE
	packet(0x086a,26,clif->pPartyInvite2,2); // added in same version  // CZ_PARTY_JOIN_REQ
	packet(0x086c,6,clif->pDropItem,2,4); // added in same version  // CZ_ITEM_THROW
	packet(0x0874,2,clif->pReqCloseBuyingStore,0); // added in 2017-08-01aRagexeRE // CZ_REQ_CLOSE_BUYING_STORE
	packet(0x0875,4,clif->pDull/*,XXX*/); // added in same version  // CZ_GANGSI_RANK
	packet(0x0889,6,clif->pGetCharNameRequest,2); // added in same version  // CZ_REQNAME
	packet(0x088e,6,clif->pTickSend,2); // added in same version  // CZ_REQUEST_TIME
	packet(0x089b,7,clif->pActionRequest,2,6); // added in same version  // CZ_REQUEST_ACT
	packet(0x0919,10,clif->pUseSkillToPos,2,4,6,8); // added in same version  // CZ_USE_SKILL_TOGROUND
	packet(0x091e,8,clif->pDull/*,XXX*/); // added in 2017-09-13bRagexeRE // CZ_JOIN_BATTLE_FIELD
	packet(0x0921,6,clif->pSolveCharName,2); // added in same version  // CZ_REQNAME_BYGID
	packet(0x0923,19,clif->pWantToConnection,2,6,10,14,18); // added in same version  // CZ_ENTER
	packet(0x0926,8,clif->pMoveToKafra,2,4); // added in same version  // CZ_MOVE_ITEM_FROM_BODY_TO_STORE
	packet(0x092e,-1,clif->pReqTradeBuyingStore,2,4,8,12); // added in same version  // CZ_REQ_TRADE_BUYING_STORE
	packet(0x0937,12,clif->pSearchStoreInfoListItemClick,2,6,10); // added in same version  // CZ_SSILIST_ITEM_CLICK
	packet(0x0939,5,clif->pChangeDir,2,4); // added in same version  // CZ_CHANGE_DIRECTION
	packet(0x0945,18,clif->pPartyBookingRegisterReq,2,4); // added in same version  // CZ_PARTY_BOOKING_REQ_REGISTER
	packet(0x094c,-1,clif->pSearchStoreInfo,2,4,5,9,13,14,15); // added in same version  // CZ_SEARCH_STORE_INFO
	packet(0x095d,5,clif->pHomMenu,2,4); // added in same version  // CZ_COMMAND_MER
	packet(0x0961,6,clif->pReqClickBuyingStore,2); // added in same version  // CZ_REQ_CLICK_TO_BUYING_STORE
	packet(0x0966,90,clif->pUseSkillToPosMoreInfo,2,4,6,8,10); // added in same version  // CZ_USE_SKILL_TOGROUND_WITHTALKBOX
	packet(0x096a,2,clif->pSearchStoreInfoNextPage,0); // added in 2017-09-13bRagexeRE // CZ_SEARCH_STORE_INFO_NEXT_PAGE
#endif
#if PACKETVER >= 20170920
// new packets
	packet(0x0ade,6);
	packet(0x0adf,58);
// changed packet sizes
#endif

#if PACKETVER == 20170920
	packetKeys(0x53024DA5,0x04EC212D,0x0BF87CD4);
#endif

=cut
