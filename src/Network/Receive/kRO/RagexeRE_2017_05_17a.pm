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
package Network::Receive::kRO::RagexeRE_2017_05_17a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_01_25a);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0AC4' => ['account_server_info', 'x2 a4 a4 a4 a4 a26 C x17 a*', [qw(sessionID accountID sessionID2 lastLoginIP lastLoginTime accountSex serverInfo)]],
		'0087' => ['character_moves', 'a4 a6', [qw(move_start_time coords)]], # 12
		'0A37' => ['inventory_item_added', 'a2 v2 C3 a8 V C2 a4 v a25', [qw(ID amount nameID identified broken upgrade cards type_equip type fail expire unknown options)]],
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	return $self;
}
1;
=pod
// 2017-05-17aRagexeRE
#elif PACKETVER == 20170517
	//parseable_packet(0x0364,8,NULL,0); // CZ_JOIN_BATTLE_FIELD
	parseable_packet(0x0367,-1,clif_parse_ReqOpenBuyingStore,2,4,8,9,89);
	parseable_packet(0x0437,7,clif_parse_ActionRequest,2,6);
	parseable_packet(0x0802,18,clif_parse_PartyBookingRegisterReq,2,4);
	parseable_packet(0x0815,10,clif_parse_UseSkillToId,2,4,6);
	parseable_packet(0x0817,10,clif_parse_UseSkillToPos,2,4,6,8);
	parseable_packet(0x0868,90,clif_parse_UseSkillToPosMoreInfo,2,4,6,8,10);
	parseable_packet(0x0875,2,clif_parse_SearchStoreInfoNextPage,0);
	parseable_packet(0x087b,6,clif_parse_SolveCharName,2);
	parseable_packet(0x087d,-1,clif_parse_SearchStoreInfo,2,4,5,9,13,14,15);
	parseable_packet(0x088c,8,clif_parse_MoveFromKafra,2,4);
	parseable_packet(0x088d,5,clif_parse_ChangeDir,2,4);
	parseable_packet(0x0894,6,clif_parse_GetCharNameRequest,2);
	parseable_packet(0x0896,12,clif_parse_SearchStoreInfoListItemClick,2,6,10);
	parseable_packet(0x0899,26,clif_parse_PartyInvite2,2);
	//parseable_packet(0x089e,4,NULL,0); // CZ_GANGSI_RANK
	parseable_packet(0x089f,2,clif_parse_ReqCloseBuyingStore,0);
	parseable_packet(0x08a2,6,clif_parse_TickSend,2);
	parseable_packet(0x08a8,5,clif_parse_WalkToXY,2);
	parseable_packet(0x08aa,8,clif_parse_MoveToKafra,2,4);
	parseable_packet(0x091b,-1,clif_parse_ReqTradeBuyingStore,2,4,8,12);
	parseable_packet(0x0923,19,clif_parse_WantToConnection,2,6,10,14,18);
	parseable_packet(0x093b,6,clif_parse_DropItem,2,4);
	parseable_packet(0x0945,-1,clif_parse_ItemListWindowSelected,2,4,8,12);
	parseable_packet(0x0946,6,clif_parse_ReqClickBuyingStore,2);
	parseable_packet(0x0947,36,clif_parse_StoragePassword,0);
	parseable_packet(0x0958,5,clif_parse_HomMenu,2,4);
	parseable_packet(0x0960,26,clif_parse_FriendsListAdd,2);
	parseable_packet(0x0964,6,clif_parse_TakeItem,2);
=cut
