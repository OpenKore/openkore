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
package Network::Receive::kRO::RagexeRE_2016_10_26b;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2016_08_24a);
use I18N qw(bytesToString);
use Globals;

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
	
	my %packets = (
		'0AA5' => ['guild_members_list'],	
	);
	
	$self->{packet_list}{$_} = $packets{$_} for keys %packets;

	return $self;
	
}

sub guild_members_list {
	my ($self, $args) = @_;

	my ($jobID);
	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $guild_pack = 'a4 V x6 v2 V v x2 V V';
	my $guild_len = length pack $guild_pack;
	my $c = 0;
	my $gtIndex;
	delete $guild{member};
	for (my $i = 4; $i < $msg_size; $i+=$guild_len){
		($guild{member}[$c]{ID},
		$guild{member}[$c]{charID},
		$guild{member}[$c]{jobID},
		$guild{member}[$c]{lv},
		$guild{member}[$c]{contribution},
		$guild{member}[$c]{online},
		$gtIndex,
		$guild{member}[$c]{lastlogin}) = unpack($guild_pack, substr($msg, $i, $guild_len)); # TODO: what are the unknown x's?

		# TODO: we shouldn't store the guildtitle of a guildmember both in $guild{positions} and $guild{member}, instead we should just store the rank index of the guildmember and get the title from the $guild{positions}
		$guild{member}[$c]{title} = $guild{positions}[$gtIndex]{title};
		$guild{member}[$c]{name} = $guild{member}[$c]{charID}; #TODO get member name !! 
		$c++;
	}

}


1;
=pod
// 20161026
if (packetVersion == 20161026)
{
    packet(CMSG_STORAGE_PASSWORD,         0x0363,  36, clif->pStoragePassword);
    packet(CMSG_PLAYER_CHANGE_DEST,       0x0438,   5, clif->pWalkToXY);
//  packet(UNKNOWN,                       0x0802,  18, clif->pPartyBookingRegisterReq);
    packet(CMSG_MOVE_TO_STORAGE,          0x085a,   8, clif->pMoveToKafra);
    packet(CMSG_PLAYER_CHANGE_ACT,        0x085f,   7, clif->pActionRequest);
    packet(CMSG_BUYINGSTORE_SELL,         0x0861,  -1, clif->pReqTradeBuyingStore);
    packet(CMSG_MAP_PING,                 0x0862,   6, clif->pTickSend);
    packet(CMSG_SEARCHSTORE_NEXT_PAGE,    0x086a,   2, clif->pSearchStoreInfoNextPage);
    packet(CMSG_SEARCHSTORE_CLICK,        0x086c,  12, clif->pSearchStoreInfoListItemClick);
//  packet(UNKNOWN,                       0x086e,   8, clif->pDull);
    packet(CMSG_SEARCHSTORE_SEARCH,       0x087a,  -1, clif->pSearchStoreInfo);
//  packet(UNKNOWN,                       0x087c,   4, clif->pDull);
    packet(CMSG_SKILL_USE_POSITION,       0x087f,  10, clif->pUseSkillToPos);
    packet(CMSG_PLAYER_INVENTORY_DROP,    0x0886,   6, clif->pDropItem);
    packet(CMSG_BUYINGSTORE_OPEN,         0x0891,   6, clif->pReqClickBuyingStore);
    packet(CMSG_SKILL_USE_BEING,          0x0894,  10, clif->pUseSkillToId);
    packet(CMSG_FRIENDS_ADD_PLAYER,       0x0898,  26, clif->pFriendsListAdd);
    packet(CMSG_MAP_SERVER_CONNECT,       0x091a,  19, clif->pWantToConnection);
    packet(CMSG_ITEM_PICKUP,              0x091b,   6, clif->pTakeItem);
    packet(CMSG_SOLVE_CHAR_NAME,          0x0926,   6, clif->pSolveCharName);
    packet(CMSG_BUYINGSTORE_CREATE,       0x092c,  -1, clif->pReqOpenBuyingStore);
    packet(CMSG_HOMUNCULUS_MENU,          0x092e,   5, clif->pHomMenu);
    packet(CMSG_BUYINGSTORE_CLOSE,        0x092f,   2, clif->pReqCloseBuyingStore);
    packet(CMSG_NAME_REQUEST,             0x0930,   6, clif->pGetCharNameRequest);
    packet(CMSG_MOVE_FROM_STORAGE,        0x094b,   8, clif->pMoveFromKafra);
    packet(CMSG_PARTY_INVITE2,            0x0953,  26, clif->pPartyInvite2);
    packet(CMSG_ITEM_LIST_WINDOW_SELECT,  0x095c,  -1, clif->pItemListWindowSelected);
    packet(CMSG_SKILL_USE_POSITION_MORE,  0x095e,  90, clif->pUseSkillToPosMoreInfo);
    packet(CMSG_PLAYER_CHANGE_DIR,        0x0962,   5, clif->pChangeDir);
}
=cut
