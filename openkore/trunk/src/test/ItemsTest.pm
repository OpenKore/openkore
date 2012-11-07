package ItemsTest;

use strict;
use Test::More;
use Globals;
use Actor::You;
use Actor::Item;

sub start {
	note('Starting ' . __PACKAGE__);
	__PACKAGE__->new->run;
}

sub new {
	$char = new Actor::You;
	$char->{equipment} = {};

	$char->inventory->add(Actor::Item->new);
	
	return bless {}, $_[0];
}

sub run {
	my ($self) = @_;

	$self->testBulkEquipVivification;
}

sub testBulkEquipVivification {
	local *Actor::Item::equipInSlot = sub {};

	Actor::Item::bulkEquip({ rightHand => 0 });

	ok(
		!$char->{equipment}{rightHand} || UNIVERSAL::isa($char->{equipment}{rightHand}, 'Actor::Item'),
		'Autovivification in Actor::Item::bulkEquip'
	);
}

1;
