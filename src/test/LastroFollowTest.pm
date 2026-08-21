package LastroFollowTest;

use strict;
use warnings;

use FindBin qw($RealBin);
use File::Spec;
use Test::More;

use Commands;
use Globals;
use Network;
use Network::Receive;
use Plugins;

sub start {
	subtest 'LastroFollow plugin command' => sub {
		my $plugin_file = File::Spec->catfile(
			$RealBin, '..', '..', 'plugins', 'LastroFollow', 'LastroFollow.pl'
		);
		local $Globals::masterServer = {lastroAutoFollow => 1};
		local $Globals::net = LastroFollowTest::FakeNet->new;
		local $Globals::messageSender = LastroFollowTest::FakeSender->new;

		eval { Plugins::load($plugin_file) };
		ok(!$@, 'loads LastroFollow plugin') or do {
			diag $@ if $@;
			return;
		};

		ok(Plugins::registered('LastroFollow'), 'registers LastroFollow plugin') or return;
		my $receiver = Network::Receive->create(
			undef, 'kRO_RagexeRE_2021_11_03'
		);

		Commands::run('autofollow on');
		is_deeply($Globals::messageSender->{actions}, [1],
			'autofollow on always sends the browser toggle action first');

		$receiver->lastro_reload_info({id => 37, value => 1});
		is_deeply($Globals::messageSender->{actions}, [1],
			'autofollow on stops after the first toggle reaches the requested state');

		Commands::run('autofollow on');
		is_deeply($Globals::messageSender->{actions}, [1, 1],
			'autofollow on sends the first toggle even when already enabled');

		$receiver->lastro_reload_info({id => 37, value => 0});
		is_deeply($Globals::messageSender->{actions}, [1, 1, 1],
			'autofollow on sends one follow-up toggle when the first response is off');
		$receiver->lastro_reload_info({id => 37, value => 1});

		Commands::run('autofollow off');
		is_deeply($Globals::messageSender->{actions}, [1, 1, 1, 1],
			'autofollow off always sends the browser toggle action first');

		$receiver->lastro_reload_info({id => 37, value => 0});
		is_deeply($Globals::messageSender->{actions}, [1, 1, 1, 1],
			'autofollow off stops after the first toggle reaches the requested state');

		Commands::run('autofollow off');
		is_deeply($Globals::messageSender->{actions}, [1, 1, 1, 1, 1],
			'autofollow off sends the first toggle even when already disabled');

		$receiver->lastro_reload_info({id => 37, value => 1});
		is_deeply($Globals::messageSender->{actions}, [1, 1, 1, 1, 1, 1],
			'autofollow off sends one follow-up toggle when the first response is on');
		$receiver->lastro_reload_info({id => 37, value => 0});

		ok(Plugins::unload('LastroFollow'), 'unloads LastroFollow plugin');
		done_testing();
	};
}

{
	package LastroFollowTest::FakeNet;

	sub new { bless {}, shift }
	sub getState { Network::IN_GAME }
}

{
	package LastroFollowTest::FakeSender;

	sub new { bless {actions => []}, shift }

	sub sendLastroAutoFollow {
		my ($self) = @_;
		push @{$self->{actions}}, 1;
	}
}

1;
