package testNewMeeting;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);
use Data::Dumper;

use Utils::PathFinding;
use Time::HiRes qw(time usleep);

$Data::Dumper::Sortkeys = 1;

Plugins::register('testNewMeeting', 'Enables smart pathing using the dynamic aspect of A* Lite pathfinding', \&onUnload);

my $chooks = Commands::register(
	['od', 'obstacles dump', \&use_od],
	['meet', 'obstacles dump', \&testmeet],
	['testmeet', 'obstacles dump', \&testScenarios],
);

sub onUnload {
	Commands::unregister($chooks);
}

sub use_od {
	my $width  = 10;
	my $height = 10;

	# Build a fully walkable weight map.
	# Walkable cells must NOT be -1.
	my $raw = chr(0) x ($width * $height);

	my $pf = PathFinding->new();

	my @result;
	$pf->floodfill_reset(
		\$raw,   # weight_map
		$width,
		$height,
		0,       # startx
		0,       # starty
		1000,    # max_distance (cost budget)
		10,      # orthogonal_cost
		14,      # diagonal_cost
		0,       # min_x
		$width - 1,
		0,       # min_y
		$height - 1,
	);

	my $count = $pf->floodfill_run(\@result);
	print "floodfill reachable count: $count\n";

	my @tests = (
		{ x => 0, y => 0, expected => 0  },
		{ x => 1, y => 0, expected => 10 },
		{ x => 0, y => 1, expected => 10 },
		{ x => 1, y => 1, expected => 14 },
		{ x => 2, y => 1, expected => 24 },
		{ x => 2, y => 2, expected => 28 },
		{ x => 2, y => 5, expected => 58 },
		{ x => 5, y => 2, expected => 58 },
		{ x => 3, y => 7, expected => 82 }, # 3 diagonals + 4 orthogonals = 42 + 40
	);

	my $ok = 1;

	foreach my $t (@tests) {
		my $dist = $pf->floodfill_getdist($t->{x}, $t->{y});
		my $pass = ($dist == $t->{expected}) ? 'OK' : 'FAIL';

		print sprintf(
			"(%d,%d) => got=%d expected=%d [%s]\n",
			$t->{x}, $t->{y}, $dist, $t->{expected}, $pass
		);

		$ok = 0 if $dist != $t->{expected};
	}

	# Optional unreachable test: put a wall and retest
	sub make_wall {
		my ($raw_ref, $w, $x, $y) = @_;
		substr($$raw_ref, $y * $w + $x, 1) = chr(255); # -1 in signed char contexts
	}

	my $raw_blocked = chr(0) x ($width * $height);

	# Block both orthogonal supports so diagonal to (1,1) is illegal from (0,0)
	make_wall(\$raw_blocked, $width, 1, 0);
	make_wall(\$raw_blocked, $width, 0, 1);

	$pf->floodfill_reset(
		\$raw_blocked,
		$width,
		$height,
		0,
		0,
		1000,
		10,
		14,
		0,
		$width - 1,
		0,
		$height - 1,
	);

	@result = ();
	$pf->floodfill_run(\@result);

	my $reachable_11 = $pf->floodfill_isreachable(1, 1);
	my $dist_11      = $pf->floodfill_getdist(1, 1);

	print "(1,1) with blocked corner => reachable=$reachable_11 dist=$dist_11 ";
	if (!$reachable_11 && $dist_11 == -1) {
		print "[OK]\n";
	} else {
		print "[FAIL]\n";
		$ok = 0;
	}

	print $ok ? "All floodfill tests passed.\n" : "Some floodfill tests failed.\n";
	return $ok;
}

my $meet_case_index = 0;
our @TACTICAL_MEET_SCENARIOS = (
    {
        name => 'open_h_1',
        actor => { x => 2, y => 2 },
        target_start => { x => 10, y => 2 },
        target_end => { x => 20, y => 2 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'open_h_2',
        actor => { x => 22, y => 2 },
        target_start => { x => 10, y => 3 },
        target_end => { x => 20, y => 3 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'diag_open_1',
        actor => { x => 3, y => 18 },
        target_start => { x => 10, y => 10 },
        target_end => { x => 17, y => 17 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'diag_open_2',
        actor => { x => 28, y => 18 },
        target_start => { x => 20, y => 10 },
        target_end => { x => 27, y => 17 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'corner_box_left',
        actor => { x => 13, y => 24 },
        target_start => { x => 27, y => 24 },
        target_end => { x => 27, y => 24 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'corner_box_diag',
        actor => { x => 19, y => 21 },
        target_start => { x => 27, y => 27 },
        target_end => { x => 27, y => 27 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'snipe_band_1_no',
        actor => { x => 6, y => 28 },
        target_start => { x => 6, y => 36 },
        target_end => { x => 18, y => 36 },
        attack_range => 9,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'snipe_band_1_yes',
        actor => { x => 6, y => 28 },
        target_start => { x => 6, y => 36 },
        target_end => { x => 18, y => 36 },
        attack_range => 9,
        attackCanSnipe => 1,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'snipe_band_2_no',
        actor => { x => 20, y => 28 },
        target_start => { x => 10, y => 36 },
        target_end => { x => 22, y => 36 },
        attack_range => 9,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'snipe_band_2_yes',
        actor => { x => 20, y => 28 },
        target_start => { x => 10, y => 36 },
        target_end => { x => 22, y => 36 },
        attack_range => 9,
        attackCanSnipe => 1,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'runtrap_inside_1',
        actor => { x => 33, y => 39 },
        target_start => { x => 37, y => 39 },
        target_end => { x => 32, y => 39 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 1,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'runtrap_inside_2',
        actor => { x => 35, y => 38 },
        target_start => { x => 37, y => 39 },
        target_end => { x => 36, y => 38 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 1,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'runtrap_outside',
        actor => { x => 30, y => 39 },
        target_start => { x => 38, y => 39 },
        target_end => { x => 36, y => 38 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 1,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'diag_column_1',
        actor => { x => 14, y => 6 },
        target_start => { x => 22, y => 6 },
        target_end => { x => 22, y => 12 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'diag_column_2',
        actor => { x => 14, y => 16 },
        target_start => { x => 22, y => 16 },
        target_end => { x => 22, y => 12 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'snipe_lane_right',
        actor => { x => 31, y => 9 },
        target_start => { x => 39, y => 13 },
        target_end => { x => 39, y => 13 },
        attack_range => 9,
        attackCanSnipe => 1,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'snipe_lane_left',
        actor => { x => 39, y => 9 },
        target_start => { x => 31, y => 13 },
        target_end => { x => 31, y => 13 },
        attack_range => 9,
        attackCanSnipe => 1,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'bottom_open_1',
        actor => { x => 40, y => 27 },
        target_start => { x => 47, y => 33 },
        target_end => { x => 47, y => 29 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'bottom_open_2',
        actor => { x => 47, y => 27 },
        target_start => { x => 40, y => 33 },
        target_end => { x => 46, y => 35 },
        attack_range => 3,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
    {
        name => 'melee_bottom',
        actor => { x => 5, y => 45 },
        target_start => { x => 12, y => 45 },
        target_end => { x => 20, y => 45 },
        attack_range => 1,
        attackCanSnipe => 0,
        runFromTargetActive => 0,
        actorType => 1,
        walk_speed => 1.0,
    },
);


sub get_tactical_meet_scenario {
	my ($index) = @_;

	return unless @TACTICAL_MEET_SCENARIOS;

	$index ||= 0;
	$index = 0 if $index < 0;
	$index = $index % scalar(@TACTICAL_MEET_SCENARIOS);

	return $TACTICAL_MEET_SCENARIOS[$index];
}

sub find_first_walkable {
	my ($field, $min_x, $min_y, $max_x, $max_y) = @_;

	for my $y ($min_y .. $max_y) {
		for my $x ($min_x .. $max_x) {
			return { x => $x, y => $y } if $field->isWalkable($x, $y);
		}
	}

	return;
}

sub find_next_walkable_far {
	my ($field, $origin, $min_dist) = @_;

	for my $y (0 .. $field->height - 1) {
		for my $x (0 .. $field->width - 1) {
			next unless $field->isWalkable($x, $y);

			my $candidate = { x => $x, y => $y };
			next if blockDistance($origin, $candidate) < $min_dist;

			return $candidate;
		}
	}

	return;
}

sub collect_walkable_spots {
	my ($field) = @_;
	my @spots;

	for my $y (0 .. $field->height - 1) {
		for my $x (0 .. $field->width - 1) {
			push @spots, { x => $x, y => $y } if $field->isWalkable($x, $y);
		}
	}

	return \@spots;
}

sub choose_varied_meet_case {
	my ($field, $case_index) = @_;

	my $spots = collect_walkable_spots($field);
	return unless @$spots;

	# Deterministic variation between runs
	my $count = scalar @$spots;
	my $start_index = ($case_index * 17) % $count;

	for my $ai (0 .. $count - 1) {
		my $actor_pos = $spots->[($start_index + $ai) % $count];

		for my $tsi (0 .. $count - 1) {
			my $target_start = $spots->[($start_index + $ai + 7 + $tsi) % $count];
			next if blockDistance($actor_pos, $target_start) < 5;

			for my $tei (0 .. $count - 1) {
				my $target_end = $spots->[($start_index + $ai + 13 + $tsi + $tei) % $count];
				next if blockDistance($target_start, $target_end) < 4;
				next if ($target_end->{x} == $target_start->{x} && $target_end->{y} == $target_start->{y});

				my $target_solution = get_solution($field, $target_start, $target_end);
				next unless ($target_solution && @{$target_solution});

				return ($actor_pos, $target_start, $target_end);
			}
		}
	}

	return;
}

sub testScenarios {
	my $start_index = 0;

	$field = new Field(name => 'test_tactical_50x50_corrected');

	return unless @TACTICAL_MEET_SCENARIOS;

	my $count = scalar @TACTICAL_MEET_SCENARIOS;

	for my $offset (0 .. $count - 1) {
		my $s = $TACTICAL_MEET_SCENARIOS[$offset] or return;

		for my $k (qw(actor target_start target_end)) {
			my $p = $s->{$k};
			my $ok = $field->isWalkable($p->{x}, $p->{y}) ? 'walkable' : 'BLOCKED';
			message sprintf(
				"[scenario %d] %s = (%d,%d) => %s\n",
				$offset, $k, $p->{x}, $p->{y}, $ok
			);
		}
	}

	return;
}

sub testmeet {
	my ($command, $args) = @_;

	my $scenario_index;
	if (defined $args && $args =~ /^\d+$/) {
		$scenario_index = $args;
	} else {
		$scenario_index = $meet_case_index++;
	}

	my $scenario = get_tactical_meet_scenario($scenario_index);
	unless ($scenario) {
		message "meetingPosition test: FAIL - no scenario found\n";
		return 0;
	}

	#$field = new Field(name => 'test_meeting_20x20');
	$field = new Field(name => 'test_tactical_50x50_corrected');

	$config{attackRouteMaxPathDistance}    = 13;
	$config{runFromTarget_maxPathDistance} = 13;
	$config{runFromTarget}                 = 0;
	$config{runFromTarget_dist}            = 5;
	$config{runFromTarget_minStep}         = 1;
	$config{follow}                        = 0;
	$config{followDistanceMax}             = 20;
	$config{attackMinPortalDistance}       = 0;
	$config{clientSight}                   = 20;

	$timeout{'meetingPosition_extra_time_actor'}{'timeout'}  = 0.150;
	$timeout{'meetingPosition_extra_time_target'}{'timeout'} = 0.150;

	my $now = time;

	my $test_walk_speed = defined $scenario->{walk_speed} ? $scenario->{walk_speed} : 1.0;

	my $actor_pos   = $scenario->{actor};
	my $target_pos  = $scenario->{target_start};
	my $target_to   = $scenario->{target_end};

	my $attack_range       = defined $scenario->{attack_range} ? $scenario->{attack_range} : 3;
	my $attack_can_snipe   = defined $scenario->{attackCanSnipe} ? $scenario->{attackCanSnipe} : 0;
	my $runFromTargetActive = $scenario->{runFromTargetActive} || 0;
	my $actorType          = $scenario->{actorType} || 1;

	$config{attackCanSnipe} = $attack_can_snipe;

	# Keep actor and $char consistent because actorType == 1 uses $char->{solution}
	$char = Actor::You->new;
	$char->{pos}            = { %$actor_pos };
	$char->{pos_to}         = { %$actor_pos };
	$char->{time_move}      = $now;
	$char->{walk_speed}     = $test_walk_speed;
	$char->{solution}       = [ { x => $actor_pos->{x}, y => $actor_pos->{y}, g => 0 } ];
	$char->{time_move_calc} = 0;

	my $actor = {
		pos          => { %$actor_pos },
		pos_to       => { %$actor_pos },
		time_move    => $now,
		walk_speed   => $test_walk_speed,
		configPrefix => '',
	};

	my $target = {
		pos        => { %$target_pos },
		pos_to     => { %$target_to },
		time_move  => $now,
		walk_speed => $test_walk_speed,
	};

	message sprintf(
		"[scenario %d%s] setup: actor=(%d,%d) target=(%d,%d)->(%d,%d) range=%d snipe=%d run=%d\n",
		$scenario_index,
		defined $scenario->{name} ? " $scenario->{name}" : "",
		$actor->{pos}{x}, $actor->{pos}{y},
		$target->{pos}{x}, $target->{pos}{y},
		$target->{pos_to}{x}, $target->{pos_to}{y},
		$attack_range,
		$attack_can_snipe,
		$runFromTargetActive,
	);

	my $spot = meetingPosition($actor, $actorType, $target, $attack_range, $runFromTargetActive);

	if (!$spot) {
		message sprintf("[scenario %d] FAIL - no spot returned\n", $scenario_index);
		return 0;
	}

	message sprintf("[scenario %d] returned: (%d,%d)\n", $scenario_index, $spot->{x}, $spot->{y});

	my $pf_actor = build_dijkstra_map($actor->{pos_to}, 14 * 60);
	my $cost = $pf_actor->floodfill_getdist($spot->{x}, $spot->{y});
	my $time_actor = calcTimeFromFloodCost($cost, $actor->{walk_speed});

	my $target_solution = get_solution($field, $target->{pos}, $target->{pos_to});
	unless ($target_solution && @$target_solution) {
		message sprintf("[scenario %d] FAIL - target solution could not be built\n", $scenario_index);
		return 0;
	}

	my $extra_time_target = defined $timeout{'meetingPosition_extra_time_target'}{'timeout'}
		? $timeout{'meetingPosition_extra_time_target'}{'timeout'}
		: 0.2;

	my $time_since_target_moved = time - $target->{time_move} + $extra_time_target;
	my $time_target_finish = calcTimeFromSolution($target_solution, $target->{walk_speed});
	my $total_time = $time_since_target_moved + $time_actor;

	my $target_pos_now;
	if ($total_time >= $time_target_finish) {
		$target_pos_now = $target->{pos_to};
	} else {
		my $target_step = calcStepsWalkedFromTimeAndSolution($target_solution, $target->{walk_speed}, $total_time);
		$target_step = 0 if $target_step < 0;
		$target_step = $#$target_solution if $target_step > $#$target_solution;
		$target_pos_now = $target_solution->[$target_step];
	}

	my $client_dist = getClientDist($spot, $target_pos_now);
	my $block_dist  = blockDistance($spot, $target_pos_now);
	my $attack_ok   = canAttack($field, $spot, $target_pos_now, $attack_can_snipe, $attack_range, $config{clientSight});

	my $ok = 1;

	if ($cost < 0) {
		message sprintf("[scenario %d] FAIL - chosen spot not reachable by Dijkstra\n", $scenario_index);
		$ok = 0;
	}

	if ($attack_ok != 1) {
		message sprintf(
			"[scenario %d] FAIL - canAttack rejected chosen spot (%d,%d) vs target (%d,%d)\n",
			$scenario_index, $spot->{x}, $spot->{y}, $target_pos_now->{x}, $target_pos_now->{y}
		);
		$ok = 0;
	}

	if ($runFromTargetActive) {
		my $pf_target = build_dijkstra_map($target->{pos}, 14 * 60);
		my $target_cost = $pf_target->floodfill_getdist($spot->{x}, $spot->{y});
		if ($target_cost >= 0) {
			my $target_time = calcTimeFromFloodCost($target_cost, $target->{walk_speed});
			message sprintf(
				"[scenario %d] timing: actor=%.3f target=%.3f\n",
				$scenario_index, $time_actor, $target_time
			);
		}
	}

	if ($ok) {
		message sprintf(
			"[scenario %d] OK - spot=(%d,%d), actor_cost=%d, actor_time=%.3f, target_at=(%d,%d), clientDist=%d, blockDist=%d\n",
			$scenario_index,
			$spot->{x}, $spot->{y},
			$cost, $time_actor,
			$target_pos_now->{x}, $target_pos_now->{y},
			$client_dist, $block_dist,
		);
	}

	return $ok;
}