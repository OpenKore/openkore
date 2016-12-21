package autoBreakTimeTest;

use strict;
use warnings;

use Test::More;
use Time::Local;

use Globals qw( $net $conState %config %timeout_ex );
use Network::DirectConnection;

sub mock_login {
	$net ||= Network::DirectConnection->new;
	$conState = Network::IN_GAME_BUT_UNINITIALIZED;
}

sub mock_logout {
	$net ||= Network::DirectConnection->new;
	$conState = Network::NOT_CONNECTED;
}

sub setup {
	my ( $net_state, $now, $block, $startTime, $stopTime ) = @_;

	$net_state eq 'logged_in' ? mock_login() : mock_logout();

	my ( $hour, $min ) = split ':', $now;
	$Setup::mock_localtime = timelocal( 0, $min, $hour, 1, 0, 100 );
	$config{autoBreakTime_0}           = $block;
	$config{autoBreakTime_0_startTime} = $startTime;
	$config{autoBreakTime_0_stopTime}  = $stopTime;

	# Reset plugin's master timeout.
	$autoBreakTime::timeout = 0;

	# Reset relog time.
	$timeout_ex{master}{time}    = time;
	$timeout_ex{master}{timeout} = 0;

	# Silence the "Disconnecting due to break time" messages.
	$config{squelchDomains} = 'system';
}

sub start {
	subtest 'do nothing on the wrong day' => sub {
		my $i = 0;
		foreach ( qw( sun mon tue wed thu fri sat ) ) {
			setup( 'logged_in', '03:00', $_, '03:00', '03:30' );
			$Setup::mock_localtime += 43200 * ++$i;
			Plugins::callHook( 'mainLoop_pre' );
			is $timeout_ex{master}{timeout}, 0, $_;
		}
	};

	subtest 'log out on the right day, case insensitive' => sub {
		my $i = 0;
		foreach ( qw( sun MON Tue weD tHu fri sat ) ) {
			setup( 'logged_in', '03:00', $_, '03:00', '03:30' );
			$Setup::mock_localtime += 86400 * ++$i;
			Plugins::callHook( 'mainLoop_pre' );
			is $timeout_ex{master}{timeout}, 30 * 60, $_;
		}
	};

	subtest 'log out on every day for "all"' => sub {
		my $i = 0;
		foreach ( qw( sun mon tue wed thu fri sat ) ) {
			setup( 'logged_in', '03:00', 'all', '03:00', '03:30' );
			$Setup::mock_localtime += 86400 * ++$i;
			Plugins::callHook( 'mainLoop_pre' );
			is $timeout_ex{master}{timeout}, 30 * 60, "$_ = all";
		}
	};

	subtest 'do nothing when logged in before a break starts' => sub {
		setup( 'logged_in', '02:59', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 0;
	};

	subtest 'log out when logged in after a break starts' => sub {

		# At the beginning of a break.
		setup( 'logged_in', '03:00', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 30 * 60;

		# Near the end of a break.
		setup( 'logged_in', '03:29', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 60;
	};

	subtest 'do nothing when logged in after a break ends' => sub {
		setup( 'logged_in', '03:30', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 0;
	};

	subtest 'do nothing when logged out before a break starts' => sub {
		setup( 'logged_out', '02:59', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 0;
	};

	subtest 'extend login time when logged out after a break starts' => sub {

		# At the beginning of a break.
		setup( 'logged_out', '03:00', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 30 * 60;

		# Near the end of a break.
		setup( 'logged_out', '03:29', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 60;
	};

	subtest 'do not shorten login time longer than break time when logged out after a break starts' => sub {

		# At the beginning of a break.
		setup( 'logged_out', '03:00', 'all', '03:00', '03:30' );
		$timeout_ex{master}{timeout} = 30 * 60 + 1;
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 30 * 60 + 1;

		# Near the end of a break.
		setup( 'logged_out', '03:29', 'all', '03:00', '03:30' );
		$timeout_ex{master}{timeout} = 60 + 1;
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 60 + 1;
	};

	subtest 'do nothing when logged out after a break ends' => sub {
		setup( 'logged_out', '03:30', 'all', '03:00', '03:30' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 0;
	};

	subtest 'work outside of breaks which span midnight' => sub {
		setup( 'logged_in', '03:10', 'all', '03:30', '03:00' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 0;
	};

	subtest 'work during breaks which span midnight' => sub {
		setup( 'logged_in', '02:30', 'all', '03:30', '03:00' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 30 * 60;

		setup( 'logged_in', '23:59', 'all', '03:30', '03:00' );
		Plugins::callHook( 'mainLoop_pre' );
		is $timeout_ex{master}{timeout}, 3 * 3600 + 60;
	};
}

1;
