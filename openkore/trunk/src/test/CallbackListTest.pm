# A unit test for CallbackList.
package CallbackListTest;

use strict;
use Test::More;
use Utils::CallbackList;

{
	# A class that does nothing. Only used to test
	# CallbackList.
	package CallbackListTest::Object;
	sub new {
		return bless {}, $_[0];
	}
}

use constant EVENT_NAME => "onEvent";
my $self = new CallbackListTest::Object;
my $list;

sub start {
	print "### Starting CallbackListTest\n";
	testAddAndCall();
	testParams();
	testRemove();
}

sub init {
	$list = new CallbackList(EVENT_NAME);
	is($list->size(), 0);
	is($list->getName(), EVENT_NAME);
}

# Test whether add() and call() correctly work together
sub testAddAndCall {
	my $sub;
	my $sub1CallCount = 0;
	my $sub2CallCount = 0;

	init();

	$sub = sub {
		$sub1CallCount++;
	};
	$list->add(undef, $sub);
	$list->checkValidity();
	is($list->size(), 1);

	$list->call($self);
	$list->checkValidity();
	is($sub1CallCount, 1);
	$list->call($self);
	$list->checkValidity();
	is($sub1CallCount, 2);

	$sub = sub {
		$sub2CallCount++;
	};
	$list->add(undef, $sub);
	is($list->size(), 2);
	$list->checkValidity();
	$list->call($self);
	$list->checkValidity();
	is($sub1CallCount, 3);
	is($sub2CallCount, 1);

	$list->call($self);
	$list->checkValidity();
	is($sub1CallCount, 4);
	is($sub2CallCount, 2);
	is($list->size(), 2);
}

# Test whether parameters given to add() and call() are correctly
# passed to the callback function.
sub testParams {
	my $sub;
	my $count = 0;
	my ($object, $source, $arg, $userData);

	init();

	$sub = sub {
		($object, $source, $arg, $userData) = @_;
		$count++;
	};
	$list->add($self, $sub);
	$list->checkValidity();
	$list->call($self, 123);
	$list->checkValidity();
	is($count, 1);
	is($object, $self);
	is($source, $self);
	is($arg, 123);
	ok(!defined($userData));

	# We don't remove the last added callback because
	# this one is supposed to be called after the last one.
	$list->add($self, $sub, "my user data");
	$list->checkValidity();
	$list->call(undef, "abc");
	$list->checkValidity();
	is($count, 3);
	is($object, $self);
	ok(!defined $source);
	is($arg, "abc");
	is($userData, "my user data");

	$list->add(undef, $sub, 456);
	$list->checkValidity();
	$list->call($self);
	$list->checkValidity();
	is($count, 6);
	ok(!defined $object);
	ok($source == $self);
	ok(!defined($arg));
	is($userData, 456);
}

# Test remove()
sub testRemove {
	my ($sub, $ID1, $ID2, $ID3, $ID4, $ID5);
	my $count = 0;

	init();

	$sub = sub {
		$count++;
	};
	$ID1 = $list->add(undef, $sub);
	$ID2 = $list->add(undef, $sub);
	is($list->size(), 2);
	$list->call($self);
	is($count, 2);

	$list->remove($ID1);
	is($list->size(), 1);
	$list->checkValidity();
	$list->call(undef, $self);
	is($count, 3);
	ok(!defined $$ID1);

	$list->remove($ID1);
	is($list->size(), 1);
	$list->checkValidity();
	ok(!defined $$ID1);

	$list->call(undef, $self);
	$list->checkValidity();
	is($count, 4);

	$list->remove($ID2);
	is($list->size(), 0);
	$list->checkValidity();
	$list->call(undef, $self);
	is($count, 4);

	$count = 0;
	$ID1 = $list->add(undef, $sub);
	$ID2 = $list->add(undef, $sub);
	$ID3 = $list->add(undef, $sub);
	$ID4 = $list->add(undef, $sub);
	$ID5 = $list->add(undef, $sub);
	is($list->size(), 5);
	$list->checkValidity();
	$list->call(undef, $self);
	is($count, 5);

	$list->remove($ID3);
	is($list->size(), 4);
	$list->checkValidity();
	is($$ID1, 0);
	is($$ID2, 1);
	ok(!defined $$ID3);
	is($$ID4, 2);
	is($$ID5, 3);

	$list->call(undef, $self);
	is($count, 9);
	$list->checkValidity();
}

1;
