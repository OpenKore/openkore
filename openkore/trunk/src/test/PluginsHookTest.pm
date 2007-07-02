package PluginsHookTest;

use strict;
use Test::More;
use Plugins;

sub start {
	print "### Starting PluginsHookTest\n";
	testAddHook();
	testAddHooks();
	testLegacyAPI();
}

sub testAddHook {
	my $value;

	ok(!Plugins::hasHook('hook1'));
	ok(!Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));

	my $handle1 = Plugins::addHook('hook1', sub { $value = 1; });
	ok(Plugins::hasHook('hook1'));
	ok(!Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));
	Plugins::callHook('hook2');
	ok(!defined($value));
	Plugins::callHook('hook1');
	is($value, 1);

	my $handle2 = Plugins::addHook('hook2', sub { $value = 2; });
	ok(Plugins::hasHook('hook1'));
	ok(Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));
	Plugins::callHook('hook1');
	is($value, 1);
	Plugins::callHook('hook2');
	is($value, 2);
	Plugins::callHook('hook3');
	is($value, 2);
	
	my $handle3 = Plugins::addHook('hook1', sub { $value = 3; });
	ok(Plugins::hasHook('hook1'));
	ok(Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));
	Plugins::callHook('hook1');
	is($value, 3);
	Plugins::callHook('hook2');
	is($value, 2);

	Plugins::delHook($handle1);
	ok(Plugins::hasHook('hook1'));
	ok(Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));
	Plugins::callHook('hook2');
	is($value, 2);
	Plugins::callHook('hook1');
	is($value, 3);

	Plugins::delHook($handle3);
	ok(!Plugins::hasHook('hook1'));
	ok(Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));
	Plugins::callHook('hook2');
	is($value, 2);
	Plugins::callHook('hook1');
	is($value, 2);

	Plugins::delHook($handle2);
	ok(!Plugins::hasHook('hook1'));
	ok(!Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	ok(!Plugins::hasHook('foo hook'));
}

sub testAddHooks {
	my $value;
	
	my $handle = Plugins::addHooks(
		['hook1', sub { $value = 1; }],
		['hook2', sub { $value = 2; }]
	);
	ok(Plugins::hasHook('hook1'));
	ok(Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	Plugins::callHook('hook1');
	is($value, 1);
	Plugins::callHook('hook2');
	is($value, 2);

	Plugins::delHook($handle);
	ok(!Plugins::hasHook('hook1'));
	ok(!Plugins::hasHook('hook2'));
	ok(!Plugins::hasHook('hook3'));
	Plugins::callHook('hook1');
	is($value, 2);
}

sub testLegacyAPI {
	my $handle = Plugins::addHook('hook1', sub {});
	ok(Plugins::hasHook('hook1'));
	Plugins::delHook('hook1', $handle);
	ok(!Plugins::hasHook('hook1'));
}

1;
