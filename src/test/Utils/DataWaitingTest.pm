package Utils::DataWaitingTest;

use strict;
use Test::More;
use IO::Socket::INET;

use Utils qw(dataWaiting);

sub start {
	subtest 'undefined handles return false' => sub {
		my $undefined;
		is(dataWaiting(undef), 0, 'missing handle reference returns false');
		is(dataWaiting(\$undefined), 0, 'undefined handle returns false');
		done_testing();
	};

	subtest 'closed sockets return false without dying' => sub {
		my $socket = IO::Socket::INET->new(
			LocalAddr => '127.0.0.1',
			LocalPort => 0,
			Proto     => 'tcp',
			Listen    => 1,
			Reuse     => 1,
		);
		ok($socket, 'created test socket') or do {
			done_testing();
			return;
		};
		close($socket);

		my ($result, $error);
		eval { $result = dataWaiting(\$socket); 1 } or $error = $@;
		is($error, undef, 'closed socket does not throw');
		is($result, 0, 'closed socket reports no pending data');
		done_testing();
	};

	subtest 'non-handle objects return false without dying' => sub {
		my $not_a_handle = bless {}, 'Utils::DataWaitingTest::FakeHandle';
		my ($result, $error);
		eval { $result = dataWaiting(\$not_a_handle); 1 } or $error = $@;
		is($error, undef, 'non-handle object does not throw');
		is($result, 0, 'non-handle object reports no pending data');
		done_testing();
	};
}

1;
