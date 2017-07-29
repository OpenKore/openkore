package ShopTest;

use strict;
use Test::More;
use Globals qw($char %shop);
use Misc qw(makeShop);
use Actor::You;
use Actor::Item;

our %cart;

use constant {
	SWORD_NAME => 'Sword',
	SWORD_PRICE => '1000',
	POTION_NAME => 'Potion',
	POTION_PRICE => '100',
	POTION_AMOUNT => 50,
	LOOT_NAME => 'Loot',
};

sub start {
	note('Starting ' . __PACKAGE__);
	__PACKAGE__->new->run;
}

sub new {
	return bless {}, $_[0];
}

sub addToCart {
	my ($self, $item) = @_;

	if ($char->can('cart')) {
		$char->cart->add($item);
	} else {
		$cart{inventory}[$item->{ID}] = $item;
	}
}

sub run {
	my ($self) = @_;

	$char = Actor::You->new;
	unless ($char->can('cart')) {
		*cart = \%Globals::cart;
		%cart = (inventory => []);
	}

	for (1..2) {
		my $sword = Actor::Item->new;
		$sword->{name} = SWORD_NAME;
		$sword->{ID} = $_;
		$sword->{amount} = 1;
		$sword->{identified} = 1;
		$self->addToCart($sword);
	}
	my $potion = Actor::Item->new;
	$potion->{name} = POTION_NAME;
	$potion->{ID} = 0;
	$potion->{amount} = POTION_AMOUNT + 100;
	$potion->{identified} = 1;
	$self->addToCart($potion);

	my $other = Actor::Item->new;
	$other->{name} = LOOT_NAME;
	$other->{ID} = 9;
	$other->{amount} = 1;
	$other->{identified} = 1;

	$char->{skills}{MC_VENDING} = {
		ID => 0,
		targetType => 0,
		lv => 1,
		sp => 0,
		range => 0,
		up => 0,
	};

	%shop = (
		title_line => 'Title',
		items => [
			{name => 'Nonexistant Item', price => 1, amount => 1},
			{name => SWORD_NAME, price => SWORD_PRICE, amount => 1},
			# second sword should be a different sword
			{name => SWORD_NAME, price => SWORD_PRICE, amount => 1},
			# try to open a shop with more swords than we have
			{name => SWORD_NAME, price => SWORD_PRICE, amount => 1},
			{name => POTION_NAME, price => POTION_PRICE, amount => POTION_AMOUNT},
			# should not be vended since lv 1 Vending skill only allows 3 items
			{name => LOOT_NAME, price => 1, amount => 1},
		],
	);

	$self->testNonstackableItems;
}

sub testNonstackableItems {
	local *Actor::You::cartActive = sub { 1 };
	my @items = makeShop;
	is_deeply(\@items, [
		{index => 1, name => SWORD_NAME, price => SWORD_PRICE, amount => 1},
		{index => 2, name => SWORD_NAME, price => SWORD_PRICE, amount => 1},
		{index => 0, name => POTION_NAME, price => POTION_PRICE, amount => POTION_AMOUNT},
	], 'Shop with two identical nonstackable items.');
}

1;
