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
package Network::Receive::kRO::RagexeRE_2017_09_13b;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2017_06_14b);
sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0ACC' => ['exp', 'a4 V v2', [qw(ID val type flag)]],
		'0ACB' => ['stat_info', 'v V', [qw(type val)]],
	);

	foreach my $switch (keys %packets) { $self->{packet_list}{$switch} = $packets{$switch}; }

	return $self;
}

1;
=pod
// Hercules version: 20170913
// 2017-09-13bRagexeRE
#if PACKETVER == 20170913
// shuffle packets
	packet(0x0281,6,clif->pGetCharNameRequest,2); // added in same version  // CZ_REQNAME
	packet(0x035f,26,clif->pFriendsListAdd,2); // added in same version  // CZ_ADD_FRIENDS
	packet(0x0437,-1,clif->pSearchStoreInfo,2,4,5,9,13,14,15); // added in same version  // CZ_SEARCH_STORE_INFO
	packet(0x07e4,8,clif->pMoveFromKafra,2,4); // added in same version  // CZ_MOVE_ITEM_FROM_STORE_TO_BODY
	packet(0x0817,7,clif->pActionRequest,2,6); // added in same version  // CZ_REQUEST_ACT
	packet(0x0835,19,clif->pWantToConnection,2,6,10,14,18); // added in same version  // CZ_ENTER
	packet(0x085a,2,clif->pReqCloseBuyingStore,0); // added in 2017-08-23aRagexeRE // CZ_REQ_CLOSE_BUYING_STORE
	packet(0x0860,6,clif->pTakeItem,2); // added in 2017-09-06cRagexeRE // CZ_ITEM_PICKUP
	packet(0x0865,26,clif->pPartyInvite2,2); // added in same version  // CZ_PARTY_JOIN_REQ
	packet(0x0866,-1,clif->pReqOpenBuyingStore,2,4,8,9,89); // added in 2017-09-06cRagexeRE // CZ_REQ_OPEN_BUYING_STORE
	packet(0x088c,5,clif->pHomMenu,2,4); // added in same version  // CZ_COMMAND_MER
	packet(0x0890,90,clif->pUseSkillToPosMoreInfo,2,4,6,8,10); // added in same version  // CZ_USE_SKILL_TOGROUND_WITHTALKBOX
	packet(0x0891,8,clif->pMoveToKafra,2,4); // added in same version  // CZ_MOVE_ITEM_FROM_BODY_TO_STORE
	packet(0x0892,36,clif->pStoragePassword,0); // added in same version  // CZ_ACK_STORE_PASSWORD
	packet(0x08a6,6,clif->pReqClickBuyingStore,2); // added in same version  // CZ_REQ_CLICK_TO_BUYING_STORE
	packet(0x08a7,4,clif->pDull/*,XXX*/); // added in same version  // CZ_GANGSI_RANK
	packet(0x08aa,10,clif->pUseSkillToId,2,4,6); // added in same version  // CZ_USE_SKILL
	packet(0x08ab,18,clif->pPartyBookingRegisterReq,2,4); // added in same version  // CZ_PARTY_BOOKING_REQ_REGISTER
	packet(0x08ac,5,clif->pChangeDir,2,4); // added in same version  // CZ_CHANGE_DIRECTION
	packet(0x08ad,-1,clif->pItemListWindowSelected,2,4,8); // added in same version  // CZ_ITEMLISTWIN_RES
	packet(0x091b,6,clif->pTickSend,2); // added in same version  // CZ_REQUEST_TIME
	packet(0x091d,6,clif->pDropItem,2,4); // added in same version  // CZ_ITEM_THROW
	packet(0x091e,8,clif->pDull/*,XXX*/); // added in same version  // CZ_JOIN_BATTLE_FIELD
	packet(0x0920,2,clif->pSearchStoreInfoNextPage,0); // added in 2017-04-26dRagexeRE // CZ_SEARCH_STORE_INFO_NEXT_PAGE
	packet(0x0923,5,clif->pWalkToXY,2); // added in same version  // CZ_REQUEST_MOVE
	packet(0x0925,12,clif->pSearchStoreInfoListItemClick,2,6,10); // added in same version  // CZ_SSILIST_ITEM_CLICK
	packet(0x0927,-1,clif->pReqTradeBuyingStore,2,4,8,12); // added in same version  // CZ_REQ_TRADE_BUYING_STORE
	packet(0x095a,10,clif->pUseSkillToPos,2,4,6,8); // added in same version  // CZ_USE_SKILL_TOGROUND
	packet(0x095c,6,clif->pSolveCharName,2); // added in same version  // CZ_REQNAME_BYGID
#endif
#if PACKETVER >= 20170913
// new packets
	packet(0x0add,22);
// changed packet sizes
#endif

#if PACKETVER == 20170913
	packetKeys(0x7A645935,0x1DA05062,0x5A7A4C43);
#endif

=cut
