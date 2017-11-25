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

package Network::Receive::kRO::RagexeRE_2015_11_18a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2015_11_04a);

1;

=pod
// 2015-11-18aRagexeRE
#elif PACKETVER == 20151118
	parseable_packet(0x022d,6,clif_parse_TickSend,2);
	parseable_packet(0x035f,5,clif_parse_HomMenu,2,4);
	parseable_packet(0x0360,6,clif_parse_ReqClickBuyingStore,2);
	parseable_packet(0x0365,26,clif_parse_PartyInvite2,2);
	parseable_packet(0x0366,90,clif_parse_UseSkillToPosMoreInfo,2,4,6,8,10);
	parseable_packet(0x0368,6,clif_parse_SolveCharName,2);
	parseable_packet(0x0369,7,clif_parse_ActionRequest,2,6);
	parseable_packet(0x0437,5,clif_parse_WalkToXY,2);
	parseable_packet(0x0438,10,clif_parse_UseSkillToPos,2,4,6,8);
	parseable_packet(0x0811,-1,clif_parse_ReqTradeBuyingStore,2,4,8,12);
	parseable_packet(0x0815,-1,clif_parse_ReqOpenBuyingStore,2,4,8,9,89);
	parseable_packet(0x0817,2,clif_parse_ReqCloseBuyingStore,0);
	parseable_packet(0x0819,-1,clif_parse_SearchStoreInfo,2,4,5,9,13,14,15);
	parseable_packet(0x0835,2,clif_parse_SearchStoreInfoNextPage,0);
	parseable_packet(0x0838,12,clif_parse_SearchStoreInfoListItemClick,2,6,10);
	parseable_packet(0x083c,10,clif_parse_UseSkillToId,2,4,6);
	parseable_packet(0x086b,8,clif_parse_MoveToKafra,2,4);
	parseable_packet(0x088b,36,clif_parse_StoragePassword,2,4,20);
	parseable_packet(0x08ab,8,clif_parse_MoveFromKafra,2,4);
	parseable_packet(0x0921,26,clif_parse_FriendsListAdd,2);
	parseable_packet(0x0925,19,clif_parse_WantToConnection,2,6,10,14,18);
	parseable_packet(0x092e,5,clif_parse_ChangeDir,2,4);
	//parseable_packet(0x092f,8,NULL,0); // CZ_JOIN_BATTLE_FIELD
	parseable_packet(0x093c,6,clif_parse_DropItem,2,4);
	parseable_packet(0x0943,6,clif_parse_TakeItem,2);
	parseable_packet(0x0946,-1,clif_parse_ItemListWindowSelected,2,4,8,12);
	//parseable_packet(0x0957,4,NULL,0); // CZ_GANGSI_RANK
	parseable_packet(0x095c,18,clif_parse_PartyBookingRegisterReq,2,4,6);
	parseable_packet(0x096a,6,clif_parse_GetCharNameRequest,2);
=cut
