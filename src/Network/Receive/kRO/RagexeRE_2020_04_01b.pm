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
# Korea (kRO) # by ya4ept
# The majority of private servers use eAthena, this is a clone of kRO
package Network::Receive::kRO::RagexeRE_2020_04_01b;
use strict;
use base qw(Network::Receive::kRO::RagexeRE_2020_03_04a);

use Globals;
use Misc;
use Log qw(message warning error debug);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);

	my %packets = (
		'0836' => ['search_store_result', 'v C3 a*', [qw(len first_page has_next remaining storeInfo)]],
	);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	$self->{vender_items_list_item_pack} = 'V v2 C V C3 a16 a25 V v';
	$self->{npc_store_info_pack} = "V V C V";
	$self->{buying_store_items_list_pack} = "V v C V";
	$self->{makable_item_list_pack} = "V4";

	return $self;
}

=pod
/// Results for a store search request (ZC_SEARCH_STORE_INFO_ACK).
/// 0836 <packet len>.W <is first page>.B <is next page>.B <remaining uses>.B { <store id>.L <account id>.L <shop name>.80B <nameid>.W <item type>.B <price>.L <amount>.W <refine>.B <card1>.W <card2>.W <card3>.W <card4>.W }*
/// is first page:
///     0 = appends to existing results
///     1 = clears previous results before displaying this result set
/// is next page:
///     0 = no "next" label
///     1 = "next" label to retrieve more results

Header:
struct PACKET_ZC_SEARCH_STORE_INFO_ACK {
	int16 packetType;
	int16 packetLength;
	uint8 firstPage;
	uint8 nextPage;
	uint8 usesCount;
	struct PACKET_ZC_SEARCH_STORE_INFO_ACK_sub items[];
} __attribute__((packed));

storeInfo:
#if PACKETVER_MAIN_NUM >= 20200916 || PACKETVER_RE_NUM >= 20200723
struct PACKET_ZC_SEARCH_STORE_INFO_ACK_sub {
	uint32 storeId;
	uint32 AID;
	char shopName[MESSAGE_SIZE];
#if PACKETVER_MAIN_NUM >= 20181121 || PACKETVER_RE_NUM >= 20180704 || PACKETVER_ZERO_NUM >= 20181114
	uint32 itemId;
#else
	uint16 itemId;
#endif
	uint8 itemType;
	uint32 price;
	uint16 amount;
	struct EQUIPSLOTINFO slot;
	struct ItemOptions option_data[MAX_ITEM_OPTIONS];
	uint8 refine;
	uint8 grade;
} __attribute__((packed));

#elif PACKETVER_MAIN_NUM >= 20100817 || PACKETVER_RE_NUM >= 20100706 || defined(PACKETVER_ZERO)
struct PACKET_ZC_SEARCH_STORE_INFO_ACK_sub {
	uint32 storeId;
	uint32 AID;
	char shopName[MESSAGE_SIZE];
#if PACKETVER_MAIN_NUM >= 20181121 || PACKETVER_RE_NUM >= 20180704 || PACKETVER_ZERO_NUM >= 20181114
	uint32 itemId;
#else
	uint16 itemId;
#endif
	uint8 itemType;
	uint32 price;
	uint16 amount;
	uint8 refine;
	struct EQUIPSLOTINFO slot;
#if PACKETVER >= 20150226
	struct ItemOptions option_data[MAX_ITEM_OPTIONS];
#endif
} __attribute__((packed));

Extras:
struct EQUIPSLOTINFO {
#if PACKETVER_MAIN_NUM >= 20181121 || PACKETVER_RE_NUM >= 20180704 || PACKETVER_ZERO_NUM >= 20181114
	uint32 card[4];
#else
	uint16 card[4];
#endif
} __attribute__((packed));


struct ItemOptions {
	int16 index;
	int16 value;
	uint8 param;
} __attribute__((packed));


#define MAX_ITEM_OPTIONS 5
#define MESSAGE_SIZE (79 + 1)
=cut

sub search_store_result {
	my ($self, $args) = @_;

	@{$universalCatalog{list}} = () if $args->{first_page};
	$universalCatalog{has_next} = $args->{has_next};

	my @universalCatalogPage;
	
	
	my $unpackString = "a4 a4 a80 V C V v C";
	$unpackString .= " a16"; # cards[4] are uint32 now | 'V' * 4
	$unpackString .= " a25"; # ItemOptions[5] | 'v v C' * 5
	
	my $step = length pack $unpackString;
	
	my $sl = length $args->{storeInfo};
	debug "search_store_result: len $args->{len} | RAW_MSG_SIZE $args->{RAW_MSG_SIZE} | lenstoreInfo $sl | unpackStringL $step\n";

	for (my $i = 0; $i < $sl; $i+= $step) {
		my ($storeID, $accountID, $shopName, $nameID, $itemType, $price, $amount, $refine, $cards, $ItemOptions) = unpack($unpackString, substr($args->{storeInfo}, $i, $step));

		my @cards = unpack "V4", $cards;

		my $universalCatalogInfo = {
			storeID => $storeID,
			accountID => $accountID,
			shopName => $shopName,
			nameID => $nameID,
			itemType => $itemType,
			price => $price,
			amount => $amount,
			refine => $refine,
			cards_nameID => $cards,
			cards => \@cards,
			ItemOptions => $ItemOptions
		};

		push(@universalCatalogPage, $universalCatalogInfo);
		Plugins::callHook("search_store", $universalCatalogInfo);
	}

	return unless scalar @universalCatalogPage;

	push(@{$universalCatalog{list}}, \@universalCatalogPage);
	Misc::searchStoreInfo(scalar(@{$universalCatalog{list}}) - 1);
}

1;
