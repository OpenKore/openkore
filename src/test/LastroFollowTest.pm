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
			$RealBin, 'plugins', 'LastroFollow', 'LastroFollow.pl'
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
		$receiver->lastro_loadinfo({startAutofollow => 0});

		Commands::run('autofollow on');
		is_deeply($Globals::messageSender->{actions}, [1],
			'autofollow on sends the browser toggle action when the server reports off');

		$receiver->lastro_reload_info({id => 37, value => 1});
		Commands::run('autofollow on');
		is_deeply($Globals::messageSender->{actions}, [1],
			'autofollow on is a no-op after the server reports it enabled');

		Commands::run('autofollow off');
		is_deeply($Globals::messageSender->{actions}, [1, 1],
			'autofollow off uses the same browser toggle action when the server reports on');

		$receiver->lastro_reload_info({id => 37, value => 0});
		Commands::run('autofollow off');
		is_deeply($Globals::messageSender->{actions}, [1, 1],
			'autofollow off is a no-op after the server reports it disabled');

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
