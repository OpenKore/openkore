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
#
#  $Revision: 6687 $
#  $Id: kRO.pm 6687 2009-04-19 19:04:25Z technologyguild $
########################################################################
# Korea (kRO)
# The majority of private servers use eAthena, this is a clone of kRO

package Network::Receive::kRO::RagexeRE_2010_03_09a;

use strict;
use base qw(Network::Receive::kRO::RagexeRE_2010_03_03a);
use Globals qw(@articles $articles $buyerID @buyerItemList %buyerLists @buyerListsID $buyingStoreID %itemTypes_lut @selfBuyerItemList);
use Log qw(debug message);
use Misc qw(center itemName);
use Translation;
use Utils qw(formatNumber swrite);
use Utils::DataStructures qw(binRemove);

sub new {
	my ($class) = @_;
	my $self = $class->SUPER::new(@_);
		my %packets = (
		'0813' => ['open_buying_store_item_list', 'v a4 V', [qw(len AID zeny)]], #-1
		'0816' => ['buying_store_lost', 'a4', [qw(ID)]], #6
		'0818' => ['buying_store_items_list', 'v a4 a4 V', [qw(len buyerID buyingStoreID zeny)]], #-1
		);

	foreach my $switch (keys %packets) {
		$self->{packet_list}{$switch} = $packets{$switch};
	}

	return $self; 
}

sub open_buying_store_item_list {
	my ($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen = 12;

	undef @selfBuyerItemList;

	#started a shop.
	message TF("Buying Shop opened!\n"), "BuyShop";
# what is:
#	@articles = ();
#	$articles = 0;
	my $index = 0;

	for (my $i = $headerlen; $i < $msg_size; $i += 9) {
		my $item = {};

		($item->{price},
		$item->{amount},
		$item->{type},
		$item->{nameID})	= unpack('V v C v', substr($msg, $i, 9));

		$item->{name} = itemName($item);
		$selfBuyerItemList[$index] = $item;

		Plugins::callHook('packet_open_buying_store', {
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			type => $item->{type}
		});

		$index++;
	}
	Commands::run('bs');
}

sub buying_store_lost {
	my ($self, $args) = @_;

	my $ID = $args->{ID};
	binRemove(\@buyerListsID, $ID);
	delete $buyerLists{$ID};
}

sub buying_store_items_list {
	my($self, $args) = @_;

	my $msg = $args->{RAW_MSG};
	my $msg_size = $args->{RAW_MSG_SIZE};
	my $headerlen = 16;
	my $zeny = $args->{zeny};
	undef @buyerItemList;
	undef $buyerID;
	undef $buyingStoreID;
	$buyerID = $args->{buyerID};
	$buyingStoreID = $args->{buyingStoreID};
	my $player = Actor::get($buyerID);
	my $index = 0;

	my $msg = center(T(" Buyer: ") . $player->nameIdx . ' ', 79, '-') ."\n".
		T("#   Name                                      Type           Amount       Price\n");

	for (my $i = $headerlen; $i < $args->{RAW_MSG_SIZE}; $i+=9) {
		my $item = {};

		($item->{price},
		$item->{amount},
		$item->{type},
		$item->{nameID})	= unpack('V v C v', substr($args->{RAW_MSG}, $i, 9));

		$item->{name} = itemName($item);
		$buyerItemList[$index] = $item;

		debug "Item added to Buying Store: $item->{name} - $item->{price} z\n", "buying_store", 2;

		Plugins::callHook('packet_buying_store', {
			buyerID => $buyerID,
			number => $index,
			name => $item->{name},
			amount => $item->{amount},
			price => $item->{price},
			type => $item->{type}
		});

		$msg .= swrite(
			"@<< @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @>>>>> @>>>>>>>>>z",
			[$index, $item->{name}, $itemTypes_lut{$item->{type}}, $item->{amount}, formatNumber($item->{price})]);

		$index++;
	}
	$msg .= "\n" . TF("Price limit: %s Zeny\n", $zeny) . ('-'x79) . "\n";
	message $msg, "list";

	Plugins::callHook('packet_buying_store2', {
		venderID => $buyerID,
		itemList => \@buyerItemList
	});
}
=pod
//2010-03-09aRagexeRE
//0x0813,-1
//0x0814,2
//0x0815,6
//0x0816,6
//0x0818,-1
//0x0819,10
//0x081A,4
//0x081B,4
//0x081C,6
//0x081D,22
//0x081E,8
=cut

1;