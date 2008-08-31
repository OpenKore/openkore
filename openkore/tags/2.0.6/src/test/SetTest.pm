# A unit test for Set.
package SetTest;

use strict;
use Test::More;
use Utils::Set;

sub start {
	print "### Starting SetTest\n";

	my $set = new Set();
	$set->add("hello");
	$set->add("world");
	$set->add("hello");   # Has no effect. "hello" is already in the set.
	ok($set->size() == 2, "Has no duplicates.");
	is_deeply(\@{$set}, ["hello", "world"], "Set contains {hello, world}");

	ok($set->[0] eq "hello", "First element is 'hello'.");
	ok($set->get(0) eq "hello", , "First element is 'hello'.");
	ok($set->has("hello"), "'hello' is in set.");
	ok(!$set->has("foo"), "'foo' is not in set.");

	$set->remove("hello");
	ok(!$set->has("hello"), "'hello' is not in set.");
	is_deeply(\@{$set}, ["world"], "Set contains {world}");
	ok($set->size() == 1, "Set has 1 element.");

	$set->remove("hello");
	ok(!$set->has("hello"), "Duplicate removal does nothing.");
	is_deeply(\@{$set}, ["world"], "Set contains {world}");
	ok($set->size() == 1, "Set has 1 element.");

	$set->clear();
	ok($set->size() == 0, "clear() works.");
	is_deeply(\@{$set}, [], "Set is empty.");

	$set = new Set("a", "b", "c");
	is_deeply(\@{$set}, ["a", "b", "c"], "Set contains {a,b,c}");
	is($set->size(), 3, "Set has 3 elements.");
	ok($set->has("a"));
	ok($set->has("b"));
	ok($set->has("c"));
}

1;
