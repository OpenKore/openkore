package InventoryListTest;

# TODO: write test for deepCopy()

use strict;
use Test::More;
use InventoryList;
use Actor::Item;
use ObjectListTest;
use base qw(ObjectListTest);

sub start {
	print "### Starting InventoryListTest\n";
	InventoryListTest->new()->run();
}

#########################

my $count = 0;

sub run {
	my ($self) = @_;
	$self->SUPER::run();
	$self->testGetAndRemoveByName();
	$self->testNameChange();
}

# overloaded
sub init {
	my ($self) = @_;
	$count = 0;
	$self->{list} = new InventoryList();
	for (my $i = 1; $i <= 6; $i++) {
		$self->{"item$i"} = $self->createTestObject();
	}
	is($self->{list}->size(), 0);
	$self->{list}->checkValidity();
}

# overloaded
sub createTestObject {
	my $actor = new Actor::Item();
	$count++;
	$actor->{name} = "Item $count";
	return $actor;
}

# overloaded
sub testDuplicate {
	# Do nothing; InventoryList doesn't allow duplicates.
}

sub testGetAndRemoveByName {
	my ($self) = @_;
	$self->init();
	my $list = $self->{list};

	$list->add($self->{item1});
	$list->add($self->{item2});
	$list->add($self->{item3});
	is($list->size(), 3);
	ok($list->getByName($self->{item1}{name}) == $self->{item1});
	ok($list->getByName($self->{item2}{name}) == $self->{item2});
	ok($list->getByName($self->{item3}{name}) == $self->{item3});
	ok(!defined $list->getByName($self->{item4}{name}));
	ok(!defined $list->getByName($self->{item5}{name}));
	ok(!defined $list->getByName($self->{item6}{name}));
	$list->checkValidity();

	my $result = $list->removeByName($self->{item2}{name});
	ok($result);
	is($list->size(), 2);
	ok($list->getByName($self->{item1}{name}) == $self->{item1});
	ok(!defined $list->getByName($self->{item2}{name}));
	ok($list->getByName($self->{item3}{name}) == $self->{item3});
	ok(!defined $list->getByName($self->{item4}{name}));
	ok(!defined $list->getByName($self->{item5}{name}));
	ok(!defined $list->getByName($self->{item6}{name}));
	$list->checkValidity();

	my $result = $list->removeByName($self->{item2}{name});
	ok(!$result);
	is($list->size(), 2);
	ok($list->getByName($self->{item1}{name}) == $self->{item1});
	ok(!defined $list->getByName($self->{item2}{name}));
	ok($list->getByName($self->{item3}{name}) == $self->{item3});
	ok(!defined $list->getByName($self->{item4}{name}));
	ok(!defined $list->getByName($self->{item5}{name}));
	ok(!defined $list->getByName($self->{item6}{name}));
	$list->checkValidity();

	my $result = $list->removeByName($self->{item4}{name});
	ok(!$result);
	is($list->size(), 2);
	ok($list->getByName($self->{item1}{name}) == $self->{item1});
	ok(!defined $list->getByName($self->{item2}{name}));
	ok($list->getByName($self->{item3}{name}) == $self->{item3});
	ok(!defined $list->getByName($self->{item4}{name}));
	ok(!defined $list->getByName($self->{item5}{name}));
	ok(!defined $list->getByName($self->{item6}{name}));
	$list->checkValidity();
}

sub testNameChange {
	my ($self) = @_;
	$self->init();
	my $list = $self->{list};
	my $item1 = $self->{item1};
	my $item2 = $self->{item2};
	my $item3 = $self->{item3};

	$list->add($item1);
	$item1->setName("Jellopy");
	ok($list->getByName("Jellopy") == $item1);
	ok(!$list->getByName("Item 1"));
	$list->checkValidity();

	$list->add($item2);
	$list->add($item3);
	ok($list->getByName("Jellopy") == $item1);
	ok($list->getByName("Item 2") == $item2);
	ok($list->getByName("Item 3") == $item3);
	ok(!$list->getByName("Item 1"));
	$list->checkValidity();

	$item2->setName("Gold");
	ok($list->getByName("Jellopy") == $item1);
	ok($list->getByName("Gold") == $item2);
	ok($list->getByName("Item 3") == $item3);
	ok(!$list->getByName("Item 1"));
	ok(!$list->getByName("Item 2"));
	$list->checkValidity();
}

1;
