package PluginsHookTest;

use strict;
use Test::More;
use Plugins;

sub start {
	print "### Starting PluginsHookTest\n";
	testAddHook();
	testAddHooks();
	testAddDuringCall();
	testDelDuringCall();
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

sub testAddDuringCall {
	my @called;
	my @handle;

	# Add a hook which adds more hooks.
	@handle = ();
	push @handle, Plugins::addHook(
		add_during_call => sub {
			push @called, 0;
			if ( @handle < 3 ) {
				my $n = scalar @handle;
				push @handle, Plugins::addHook( add_during_call => sub { push @called, "1.$n" } );
			}
		}
	);

	# The first time through, only the original hook should be called.
	@called = ();
	Plugins::callHook( 'add_during_call' );
	is( "@called", '0' );

	# After the first call, there should be two handlers.
	@called = ();
	Plugins::callHook( 'add_during_call' );
	is( "@called", '0 1.1' );

	# Then three.
	@called = ();
	Plugins::callHook( 'add_during_call' );
	is( "@called", '0 1.1 1.2' );

	# And stop adding them.
	@called = ();
	Plugins::callHook( 'add_during_call' );
	is( "@called", '0 1.1 1.2' );
}

sub testDelDuringCall {
	my @called;
	my @handle;

	# Add some hooks.
	@handle = ();
	push @handle, Plugins::addHook( del_during_call => sub { push @called, 1 } );
	push @handle, Plugins::addHook( del_during_call => sub { push @called, 2 } );
	push @handle, Plugins::addHook( del_during_call => sub { push @called, 3;Plugins::delHook( shift @handle ) } );
	push @handle, Plugins::addHook( del_during_call => sub { push @called, 4 } );

	# The first time through, they should all trigger.
	@called = ();
	Plugins::callHook( 'del_during_call' );
	is( "@called", '1 2 3 4' );

	# The first handle should be deleted.
	@called = ();
	Plugins::callHook( 'del_during_call' );
	is( "@called", '2 3 4' );

	# Then the second.
	@called = ();
	Plugins::callHook( 'del_during_call' );
	is( "@called", '3 4' );

	# Then the third.
	@called = ();
	Plugins::callHook( 'del_during_call' );
	is( "@called", '4' );

	# No more changes since the one which was removing callbacks is gone.
	@called = ();
	Plugins::callHook( 'del_during_call' );
	is( "@called", '4' );
}

sub testLegacyAPI {
	my $handle = Plugins::addHook('hook1', sub {});
	ok(Plugins::hasHook('hook1'));
	Plugins::delHook('hook1', $handle);
	ok(!Plugins::hasHook('hook1'));
}

1;
