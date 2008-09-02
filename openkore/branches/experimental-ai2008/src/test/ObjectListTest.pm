package ObjectListTest;

use strict;
use Test::More;
use Utils::ObjectList;

{
	# A random class that's only used for testing ObjectList.
	package ObjectListTest::Object;
	sub new {
		return bless {}, $_[0];
	}
}

sub start {
	print "### Starting ObjectListTest\n";
	ObjectListTest->new()->run();
}

###################################

sub new {
	my ($class) = @_;
	return bless {}, $class;
}

# Run the test.
sub run {
	my ($self) = @_;
	$self->testAdd();
	$self->testClear();
	$self->testRemove();
	$self->testClear();
	$self->testDuplicate();
}

# Reset to the initial condition.
sub init {
	my ($self) = @_;
	$self->{list} = new ObjectList;
	for (my $i = 1; $i <= 6; $i++) {
		$self->{"item$i"} = $self->createTestObject();
	}
	is($self->{list}->size(), 0);
	$self->{list}->checkValidity();
}

sub createTestObject {
	return new ObjectListTest::Object;
}

sub testAdd {
	my ($self) = @_;
	$self->init();
	my %indices;
	my @items;
	my $addCalled = 0;

	my $sub = sub {
		my $arg = $_[2];
		ok($arg->[0] == $items[$#items]);
		$addCalled++;
	};
	my $ID = $self->{list}->onAdd()->add(undef, $sub);

	for (my $i = 0; $i < 10; $i++) {
		my $item = $self->createTestObject();
		push @items, $item;

		my $index = $self->{list}->add($item);
		is($self->{list}->size(), $i + 1);
		$self->{list}->checkValidity();

		# Test whether previous indices didn't change.
		for (my $j = 0; $j < $i; $j++) {
			ok($self->{list}->get($j) == $items[$j]);
		}

		# Test whether we don't get duplicate indices.
		ok(!exists $indices{$index});
		$indices{$index} = 1;
	}

	is_deeply($self->{list}->getItems(), \@items);
	$self->{list}->onAdd()->remove($ID);
}

sub testRemove {
	my ($self) = @_;
	$self->init();

	my $index1 = $self->{list}->add($self->{item1});
	my $index2 = $self->{list}->add($self->{item2});
	my $index3 = $self->{list}->add($self->{item3});
	my $index4 = $self->{list}->add($self->{item4});
	my $index5 = $self->{list}->add($self->{item5});
	my ($deletedItem, $deletedIndex);

	my $sub = sub {
		my $arg = $_[2];
		ok($arg->[0] == $deletedItem);
	};
	$self->{list}->onRemove()->add(undef, $sub);

	# Delete item 2
	$deletedItem = $self->{item2};
	$deletedIndex = $index2;
	$self->{list}->remove($deletedItem);
	is($self->{list}->size(), 4);
	ok($self->{list}->get($index1) == $self->{item1});
	ok(!defined $self->{list}->get($index2));
	ok($self->{list}->get($index3) == $self->{item3});
	ok($self->{list}->get($index4) == $self->{item4});
	ok($self->{list}->get($index5) == $self->{item5});
	is($self->{list}->find($self->{item1}), $index1);
	is($self->{list}->find($self->{item2}), -1);
	is($self->{list}->find($self->{item3}), $index3);
	is($self->{list}->find($self->{item4}), $index4);
	is($self->{list}->find($self->{item5}), $index5);
	is($self->{list}->find($self->{item6}), -1);
	is_deeply($self->{list}->getItems(), [$self->{item1}, $self->{item3}, $self->{item4}, $self->{item5}]);
	$self->{list}->checkValidity();

	# Delete item 4
	$deletedItem = $self->{item4};
	$deletedIndex = $index4;
	$self->{list}->remove($deletedItem);
	is($self->{list}->size(), 3);
	ok($self->{list}->get($index1) == $self->{item1});
	ok(!defined $self->{list}->get($index2));
	ok($self->{list}->get($index3) == $self->{item3});
	ok(!defined $self->{list}->get($index4));
	ok($self->{list}->get($index5) == $self->{item5});
	is($self->{list}->find($self->{item1}), $index1);
	is($self->{list}->find($self->{item2}), -1);
	is($self->{list}->find($self->{item3}), $index3);
	is($self->{list}->find($self->{item4}), -1);
	is($self->{list}->find($self->{item5}), $index5);
	is($self->{list}->find($self->{item6}), -1);
	is_deeply($self->{list}->getItems(), [$self->{item1}, $self->{item3}, $self->{item5}]);
	$self->{list}->checkValidity();

	# Put back item 2
	my $index = $self->{list}->add($self->{item2});
	is($index, $index2);
	is($self->{list}->size(), 4);
	ok($self->{list}->get($index1) == $self->{item1});
	ok($self->{list}->get($index2) == $self->{item2});
	ok($self->{list}->get($index3) == $self->{item3});
	ok(!defined $self->{list}->get($index4));
	ok($self->{list}->get($index5) == $self->{item5});
	is($self->{list}->find($self->{item1}), $index1);
	is($self->{list}->find($self->{item2}), $index2);
	is($self->{list}->find($self->{item3}), $index3);
	is($self->{list}->find($self->{item4}), -1);
	is($self->{list}->find($self->{item5}), $index5);
	is($self->{list}->find($self->{item6}), -1);
	is_deeply($self->{list}->getItems(), [$self->{item1}, $self->{item2}, $self->{item3}, $self->{item5}]);
	$self->{list}->checkValidity();

	# Remove nonexistant item
	ok(!$self->{list}->remove($self->{item6}));
	is($self->{list}->size(), 4);
	ok($self->{list}->get($index1) == $self->{item1});
	ok($self->{list}->get($index2) == $self->{item2});
	ok($self->{list}->get($index3) == $self->{item3});
	ok(!defined $self->{list}->get($index4));
	ok($self->{list}->get($index5) == $self->{item5});
	is($self->{list}->find($self->{item1}), $index1);
	is($self->{list}->find($self->{item2}), $index2);
	is($self->{list}->find($self->{item3}), $index3);
	is($self->{list}->find($self->{item4}), -1);
	is($self->{list}->find($self->{item5}), $index5);
	is($self->{list}->find($self->{item6}), -1);
	is_deeply($self->{list}->getItems(), [$self->{item1}, $self->{item2}, $self->{item3}, $self->{item5}]);
	$self->{list}->checkValidity();

	# Put back item 4
	$index = $self->{list}->add($self->{item4});
	is($index, $index4);
	is($self->{list}->size(), 5);
	ok($self->{list}->get($index1) == $self->{item1});
	ok($self->{list}->get($index2) == $self->{item2});
	ok($self->{list}->get($index3) == $self->{item3});
	ok($self->{list}->get($index4) == $self->{item4});
	ok($self->{list}->get($index5) == $self->{item5});
	is($self->{list}->find($self->{item1}), $index1);
	is($self->{list}->find($self->{item2}), $index2);
	is($self->{list}->find($self->{item3}), $index3);
	is($self->{list}->find($self->{item4}), $index4);
	is($self->{list}->find($self->{item5}), $index5);
	is($self->{list}->find($self->{item6}), -1);
	is_deeply($self->{list}->getItems(), [$self->{item1}, $self->{item2}, $self->{item3}, $self->{item4}, $self->{item5}]);
	$self->{list}->checkValidity();
}

sub testClear {
	my ($self) = @_;
	my $clearBeginCalled = 0;
	my $clearEndCalled = 0;
	my $oldSize;

	my $sub1 = sub {
		$clearBeginCalled++;
		is($self->{list}->size(), $oldSize);
	};
	my $sub2 = sub {
		$clearEndCalled++;
	};

	my $ID1 = $self->{list}->onClearBegin()->add(undef, $sub1);
	my $ID2 = $self->{list}->onClearBegin()->add(undef, $sub2);
	$oldSize = $self->{list}->size();
	$self->{list}->clear();
	$self->{list}->onClearBegin()->remove($ID1);
	$self->{list}->onClearBegin()->remove($ID2);

	is($clearBeginCalled, 1);
	is($clearEndCalled, 1);
	is($self->{list}->size(), 0);
	$self->{list}->checkValidity();
	for (my $i = 0; $i < 15; $i++) {
		ok(!defined $self->{list}->get($i));
	}
	is_deeply($self->{list}->getItems(), []);
}

# Test addition and removal of duplicate items.
sub testDuplicate {
	my ($self) = @_;

	$self->init();
	my $index1 = $self->{list}->add($self->{item1});
	my $index2 = $self->{list}->add($self->{item2});
	my $index3 = $self->{list}->add($self->{item1});
	my $index4 = $self->{list}->add($self->{item3});

	$self->{list}->remove($self->{item1});
	$self->{list}->remove($self->{item2});
	is($self->{list}->size(), 2);
	ok(!defined $self->{list}->get($index1));
	ok(!defined $self->{list}->get($index2));
	ok($self->{list}->get($index3) == $self->{item1});
	ok($self->{list}->get($index4) == $self->{item3});
	is_deeply($self->{list}->getItems(), [$self->{item1}, $self->{item3}]);
	$self->{list}->checkValidity();
}

1;
