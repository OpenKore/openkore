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
package Network::Receive::kRO::RagexeRE_2016_06_22a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_04_14b);
use I18N qw(bytesToString);
use Globals;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
	'0A84' => ['guild_info', 'a4 V9 a4 Z24 Z16 V V', [qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name castles_string zeny master_id)]],
	
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	return $self;
	
}

sub guild_info {
	my ($self, $args) = @_;
	# Guild Info
	foreach (qw(ID lv conMember maxMember average exp exp_next tax tendency_left_right tendency_down_up emblemID name castles_string zeny master_id)) {
		$guild{$_} = $args->{$_};
	}
	$guild{name} = bytesToString($args->{name});
	$guild{master} = $args->{master_id}; #TODO get master name !
	$guild{members}++; # count ourselves in the guild members count
}

1;
=pod
// 20160622
if (packetVersion == 20160622)
{
    packet(CMSG_SKILL_USE_POSITION,       0x023b,  10, clif->pUseSkillToPos);
    packet(CMSG_MOVE_FROM_STORAGE,        0x035f,   8, clif->pMoveFromKafra);
    packet(CMSG_PARTY_INVITE2,            0x0361,  26, clif->pPartyInvite2);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x0366,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x0437,   5, clif->pWalkToXY);
    packet(CMSG_HOMUNCULUS_MENU,          0x07e4,   5, clif->pHomMenu);
    packet(CMSG_BUYINGSTORE_SELL,         0x0861,  -1, clif->pReqTradeBuyingStore);
//  packet(UNKNOWN,                       0x0865,   4, clif->pDull);
//  packet(UNKNOWN,                       0x0867,   8, clif->pDull);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x0880,  -1, clif->pSearchStoreInfo);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x0887,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0890,  26, clif->pFriendsListAdd);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0891,   6, clif->pReqClickBuyingStore);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x0892,   2, clif->pSearchStoreInfoNextPage);
//  packet(UNKNOWN,                       0x089a,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x089e,   7, clif->pActionRequest);
    packet(CMSG_SOLVE_CHAR_NAME,          0x08a2,   6, clif->pSolveCharName);
    packet(CMSG_STORAGE_PASSWORD,         0x08a8,  36, clif->pStoragePassword);
    packet(CMSG_ITEM_PICKUP,              0x091c,   6, clif->pTakeItem);
    packet(CMSG_MAP_PING,                 0x092d,   6, clif->pTickSend);
    packet(CMSG_SKILL_USE_BEING,          0x092f,  10, clif->pUseSkillToId);
    packet(CMSG_MAP_SERVER_CONNECT,       0x0936,  19, clif->pWantToConnection);
    packet(CMSG_SEARCHSTORE_CLICK,        0x0937,  12, clif->pSearchStoreInfoListItemClick);
    packet(CMSG_MOVE_TO_STORAGE,          0x093b,   8, clif->pMoveToKafra);
    packet(CMSG_BUYINGSTORE_CREATE,       0x093f,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x0946,  -1, clif->pItemListWindowSelected);
    packet(CMSG_NAME_REQUEST,             0x0959,   6, clif->pGetCharNameRequest);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x0965,   5, clif->pChangeDir);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0969,   6, clif->pDropItem);
}
=cut
