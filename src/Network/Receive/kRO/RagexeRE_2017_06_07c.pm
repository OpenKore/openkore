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
package Network::Receive::kRO::RagexeRE_2017_06_07c;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_05_17a);

1;
=pod
// 2017-06-07cRagexeRE
#elif PACKETVER == 20170607
	parseable_packet(0x0361,-1,clif_parse_ItemListWindowSelected,2,4,8,12);
	parseable_packet(0x0364,36,clif_parse_StoragePassword,0);
	parseable_packet(0x07e4,6,clif_parse_TickSend,2);
	parseable_packet(0x085a,5,clif_parse_ChangeDir,2,4);
	parseable_packet(0x085e,-1,clif_parse_SearchStoreInfo,2,4,5,9,13,14,15);
	parseable_packet(0x0862,6,clif_parse_GetCharNameRequest,2);
	parseable_packet(0x0863,6,clif_parse_ReqClickBuyingStore,2);
	parseable_packet(0x0864,6,clif_parse_DropItem,2,4);
	parseable_packet(0x0871,19,clif_parse_WantToConnection,2,6,10,14,18);
	//parseable_packet(0x0873,8,NULL,0); // CZ_JOIN_BATTLE_FIELD
	parseable_packet(0x0875,12,clif_parse_SearchStoreInfoListItemClick,2,6,10);
	parseable_packet(0x0885,26,clif_parse_FriendsListAdd,2);
	parseable_packet(0x088a,8,clif_parse_MoveFromKafra,2,4);
	parseable_packet(0x0897,6,clif_parse_TakeItem,2);
	parseable_packet(0x089d,8,clif_parse_MoveToKafra,2,4);
	parseable_packet(0x08a9,10,clif_parse_UseSkillToId,2,4,6);
	parseable_packet(0x08ab,90,clif_parse_UseSkillToPosMoreInfo,2,4,6,8,10);
	parseable_packet(0x0917,2,clif_parse_SearchStoreInfoNextPage,0);
	parseable_packet(0x0918,18,clif_parse_PartyBookingRegisterReq,2,4);
	parseable_packet(0x0919,-1,clif_parse_ReqTradeBuyingStore,2,4,8,12);
	parseable_packet(0x0925,26,clif_parse_PartyInvite2,2);
	parseable_packet(0x0927,10,clif_parse_UseSkillToPos,2,4,6,8);
	//parseable_packet(0x0931,4,NULL,0); // CZ_GANGSI_RANK
	parseable_packet(0x0934,5,clif_parse_WalkToXY,2);
	parseable_packet(0x0938,7,clif_parse_ActionRequest,2,6);
	parseable_packet(0x093d,2,clif_parse_ReqCloseBuyingStore,0);
	parseable_packet(0x0942,5,clif_parse_HomMenu,2,4);
	parseable_packet(0x0944,6,clif_parse_SolveCharName,2);
	parseable_packet(0x0949,-1,clif_parse_ReqOpenBuyingStore,2,4,8,9,89);
=cut
