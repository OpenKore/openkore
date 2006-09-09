package ActorListTest;

# TODO: write test for deepCopy()

use strict;
use Test::More;
use ActorList;
use Actor::Player;
use ObjectListTest;
use base qw(ObjectListTest);

sub start {
	print "### Starting ActorListTest\n";
	ActorListTest->new()->run();
}

#########################

my $count = 0;

sub run {
	my ($self) = @_;
	$self->SUPER::run();
	$self->testGetAndRemoveByID();
}

# overloaded
sub init {
	my ($self) = @_;
	$self->{list} = new ActorList('Actor::Player');
	for (my $i = 1; $i <= 6; $i++) {
		$self->{"item$i"} = $self->createTestObject();
	}
	is($self->{list}->size(), 0);
	$self->{list}->checkValidity();
}

# overloaded
sub createTestObject {
	my $actor = new Actor::Player();
	$count++;
	$actor->{ID} = pack("V", $count);
	return $actor;
}

# overloaded
sub testDuplicate {
	# Do nothing; ActorList doesn't allow duplicates.
}

sub testGetAndRemoveByID {
	my ($self) = @_;
	$self->init();
	my $list = $self->{list};

	$list->add($self->{item1});
	$list->add($self->{item2});
	$list->add($self->{item3});
	is($list->size(), 3);
	ok($list->getByID($self->{item1}{ID}) == $self->{item1});
	ok($list->getByID($self->{item2}{ID}) == $self->{item2});
	ok($list->getByID($self->{item3}{ID}) == $self->{item3});
	ok(!defined $list->getByID($self->{item4}{ID}));
	ok(!defined $list->getByID($self->{item5}{ID}));
	ok(!defined $list->getByID($self->{item6}{ID}));
	$list->checkValidity();

	my $result = $list->removeByID($self->{item2}{ID});
	ok($result);
	is($list->size(), 2);
	ok($list->getByID($self->{item1}{ID}) == $self->{item1});
	ok(!defined $list->getByID($self->{item2}{ID}));
	ok($list->getByID($self->{item3}{ID}) == $self->{item3});
	ok(!defined $list->getByID($self->{item4}{ID}));
	ok(!defined $list->getByID($self->{item5}{ID}));
	ok(!defined $list->getByID($self->{item6}{ID}));
	$list->checkValidity();

	my $result = $list->removeByID($self->{item2}{ID});
	ok(!$result);
	is($list->size(), 2);
	ok($list->getByID($self->{item1}{ID}) == $self->{item1});
	ok(!defined $list->getByID($self->{item2}{ID}));
	ok($list->getByID($self->{item3}{ID}) == $self->{item3});
	ok(!defined $list->getByID($self->{item4}{ID}));
	ok(!defined $list->getByID($self->{item5}{ID}));
	ok(!defined $list->getByID($self->{item6}{ID}));
	$list->checkValidity();

	my $result = $list->removeByID($self->{item4}{ID});
	ok(!$result);
	is($list->size(), 2);
	ok($list->getByID($self->{item1}{ID}) == $self->{item1});
	ok(!defined $list->getByID($self->{item2}{ID}));
	ok($list->getByID($self->{item3}{ID}) == $self->{item3});
	ok(!defined $list->getByID($self->{item4}{ID}));
	ok(!defined $list->getByID($self->{item5}{ID}));
	ok(!defined $list->getByID($self->{item6}{ID}));
	$list->checkValidity();
}

1;
