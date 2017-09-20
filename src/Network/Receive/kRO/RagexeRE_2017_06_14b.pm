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
package Network::Receive::kRO::RagexeRE_2017_06_14b;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_06_07c);


1;
=pod
// 2017-06-14bRagexeRE
#elif PACKETVER == 20170614
	parseable_packet(0x023B,8,clif_parse_MoveFromKafra,2,4);
	parseable_packet(0x0361,5,clif_parse_WalkToXY,2);
	parseable_packet(0x0364,5,clif_parse_HomMenu,2,4);
	parseable_packet(0x0367,6,clif_parse_DropItem,2,4);
	parseable_packet(0x0437,36,clif_parse_StoragePassword,0);
	parseable_packet(0x0838,10,clif_parse_UseSkillToPos,2,4,6,8);
	parseable_packet(0x083C,7,clif_parse_ActionRequest,2,6);
	parseable_packet(0x0860,6,clif_parse_ReqClickBuyingStore,2);
	//parseable_packet(0x0865,4,NULL,0); // CZ_GANGSI_RANK
	parseable_packet(0x0866,6,clif_parse_TickSend,2);
	parseable_packet(0x0867,26,clif_parse_FriendsListAdd,2);
	parseable_packet(0x086B,2,clif_parse_ReqCloseBuyingStore,0);
	parseable_packet(0x086C,-1,clif_parse_SearchStoreInfo,2,4,5,9,13,14,15);
	parseable_packet(0x0877,18,clif_parse_PartyBookingRegisterReq,2,4);
	parseable_packet(0x0879,8,clif_parse_MoveToKafra,2,4);
	parseable_packet(0x087D,6,clif_parse_SolveCharName,2);
	parseable_packet(0x087E,5,clif_parse_ChangeDir,2,4);
	parseable_packet(0x0889,90,clif_parse_UseSkillToPosMoreInfo,2,4,6,8,10);
	parseable_packet(0x0899,26,clif_parse_PartyInvite2,2);
	parseable_packet(0x089D,-1,clif_parse_ItemListWindowSelected,2,4,8,12);
	parseable_packet(0x08A2,-1,clif_parse_ReqOpenBuyingStore,2,4,8,9,89);
	parseable_packet(0x08AD,6,clif_parse_TakeItem,2);
	parseable_packet(0x091B,10,clif_parse_UseSkillToId,2,4,6);
	parseable_packet(0x0928,2,clif_parse_SearchStoreInfoNextPage,0);
	parseable_packet(0x092F,-1,clif_parse_ReqTradeBuyingStore,2,4,8,12);
	parseable_packet(0x0936,6,clif_parse_GetCharNameRequest,2);
	parseable_packet(0x0944,19,clif_parse_WantToConnection,2,6,10,14,18);
	//parseable_packet(0x0957,8,NULL,0); // CZ_JOIN_BATTLE_FIELD
	parseable_packet(0x0963,12,clif_parse_SearchStoreInfoListItemClick,2,6,10);
=cut
