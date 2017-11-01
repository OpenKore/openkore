#########################################################################
#  OpenKore - Packet Receiveing
#  This module contains functions for Receiveing packets to the server.
#
#  This software is open source, licensed under the GNU General Public
#  License, version 2.
#  Basically, this means that you're allowed to modify and distribute
#  this software. However, if you distribute modified versiaons, you MUST
#  also distribute the source code.
#  See http://www.gnu.org/licenses/gpl.html for the full license.
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2016_12_28a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_12_07e);

1;
=pod
// 2016-12-28aRagexeRE
#elif PACKETVER == 20161228
	parseable_packet(0x0362,-1,clif_parse_ReqTradeBuyingStore,2,4,8,12);
	parseable_packet(0x085a,6,clif_parse_GetCharNameRequest,2);
	parseable_packet(0x085e,5,clif_parse_HomMenu,2,4);
	parseable_packet(0x0865,90,clif_parse_UseSkillToPosMoreInfo,2,4,6,8,10);
	parseable_packet(0x086a,-1,clif_parse_ReqOpenBuyingStore,2,4,8,9,89);
	parseable_packet(0x086c,6,clif_parse_TakeItem,2);
	parseable_packet(0x086d,19,clif_parse_WantToConnection,2,6,10,14,18);
	parseable_packet(0x0870,-1,clif_parse_SearchStoreInfo,2,4,5,9,13,14,15);
	parseable_packet(0x0871,5,clif_parse_ChangeDir,2,4);
	parseable_packet(0x0875,2,clif_parse_ReqCloseBuyingStore,0);
	parseable_packet(0x087f,12,clif_parse_SearchStoreInfoListItemClick,2,6,10);
	parseable_packet(0x0886,5,clif_parse_WalkToXY,2);
	parseable_packet(0x0889,-1,clif_parse_ItemListWindowSelected,2,4,8,12);
	parseable_packet(0x0893,6,clif_parse_DropItem,2,4);
	parseable_packet(0x089f,8,clif_parse_MoveToKafra,2,4);
	parseable_packet(0x08a2,10,clif_parse_UseSkillToId,2,4,6);
	parseable_packet(0x08a3,6,clif_parse_ReqClickBuyingStore,2);
	parseable_packet(0x08a5,18,clif_parse_PartyBookingRegisterReq,2,4);
	parseable_packet(0x08ab,8,clif_parse_MoveFromKafra,2,4);
	parseable_packet(0x08ac,6,clif_parse_SolveCharName,2);
	parseable_packet(0x08ad,36,clif_parse_StoragePassword,0);
	parseable_packet(0x091c,26,clif_parse_FriendsListAdd,2);
	parseable_packet(0x0929,10,clif_parse_UseSkillToPos,2,4,6,8);
	parseable_packet(0x092c,2,clif_parse_SearchStoreInfoNextPage,0);
	parseable_packet(0x0934,26,clif_parse_PartyInvite2,2);
	//parseable_packet(0x0935,8,NULL,0); // CZ_JOIN_BATTLE_FIELD
	//parseable_packet(0x0938,4,NULL,0); // CZ_GANGSI_RANK
	parseable_packet(0x093d,7,clif_parse_ActionRequest,2,6);
	parseable_packet(0x0944,6,clif_parse_TickSend,2);
=cut
