package QuestReceiveTest;

use strict;
use Test::More;
use Network::Receive;
use Globals;

sub start {
	print "### Starting QuestReceiveTest\n";

	my $receiver = Network::Receive->create(undef, 0);
	ok($receiver, 'create receive instance');

	subtest '0AFE maps mission using hunt_id_cont synthetic identifier' => sub {
		$questList = {
			500 => {
				quest_id => 500,
				missions => {
					100 => { questID => 500, mob_id => 100, mission_index => 0, mob_goal => 10, mob_count => 0 },
					200 => { questID => 500, mob_id => 200, mission_index => 1, mob_goal => 10, mob_count => 0 },
				},
			},
		};

		$receiver->quest_update_mission_hunt({
			switch => '0AFE',
			mission_amount => 1,
			message => pack('V3 v2', 500, 500, 2, 10, 3),
		});

		is($questList->{500}{missions}{100}{mob_count}, 0, 'first mission unchanged');
		is($questList->{500}{missions}{200}{mob_count}, 3, 'second mission updated from hunt_id_cont');
		done_testing();
	};

	subtest 'recent kill fallback is consumed after one successful mapping' => sub {
		$questList = {
			600 => {
				quest_id => 600,
				missions => {
					300 => { questID => 600, mob_id => 300, mob_goal => 5, mob_count => 0 },
					301 => { questID => 600, mob_id => 301, mob_goal => 5, mob_count => 0 },
				},
			},
		};

		$receiver->{_last_killed_monster_nameID} = 300;
		$receiver->{_last_killed_monster_time} = time;

		my @debug_log;
		local *Network::Receive::debug = sub {
			push @debug_log, $_[0];
		};

		$receiver->quest_update_mission_hunt({
			switch => '09FA',
			mission_amount => 1,
			message => pack('V2 v2', 600, 600, 5, 1),
		});
		is($questList->{600}{missions}{300}{mob_count}, 1, 'first ambiguous packet used recent kill fallback');
		ok((grep { index($_, 'MobID: 300') >= 0 } @debug_log), 'debug line uses resolved mob_id');

		$receiver->quest_update_mission_hunt({
			switch => '09FA',
			mission_amount => 1,
			message => pack('V2 v2', 600, 600, 5, 2),
		});

		is($questList->{600}{missions}{300}{mob_count}, 1, 'recent kill signal was consumed after use');
		is($questList->{600}{missions}{301}{mob_count}, 0, 'second mission still unchanged');
		done_testing();
	};

	subtest 'logs unresolved update when no mapping can be determined' => sub {
		$questList = {
			700 => {
				quest_id => 700,
				missions => {
					400 => { questID => 700, mob_id => 400, mob_goal => 9, mob_count => 0 },
					401 => { questID => 700, mob_id => 401, mob_goal => 9, mob_count => 0 },
				},
			},
		};

		delete $receiver->{_last_killed_monster_nameID};
		delete $receiver->{_last_killed_monster_time};

		my @debug_log;
		local *Network::Receive::debug = sub {
			push @debug_log, $_[0];
		};

		$receiver->quest_update_mission_hunt({
			switch => '09FA',
			mission_amount => 1,
			message => pack('V2 v2', 700, 700, 9, 1),
		});

		is($questList->{700}{missions}{400}{mob_count}, 0, 'first mission unchanged after unresolved packet');
		is($questList->{700}{missions}{401}{mob_count}, 0, 'second mission unchanged after unresolved packet');
		ok((grep { index($_, 'Quest mission update unresolved') >= 0 } @debug_log), 'unresolved mapping log emitted');
		done_testing();
	};
}

1;
