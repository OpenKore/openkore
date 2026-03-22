package newFunctionBenchmark::functions::canMove;

use strict;
use warnings;

use Field;
use Globals qw($char $field %config);
use Time::HiRes qw(time);
use Utils qw(blockDistance);

use constant {
	DEFAULT_ITERATIONS   => 6000,
	SAMPLES_PER_SCENARIO => 1,
	TOKEN_LENGTH         => 0,
	MIN_TARGET_DISTANCE  => 0,
};

sub benchmark_name { 'Field::canMove' }
sub original_name { 'Field::canMove_perl' }
sub candidate_name { 'Field::canMove' }
sub default_iterations { DEFAULT_ITERATIONS }
sub samples_per_scenario { SAMPLES_PER_SCENARIO }
sub token_length { TOKEN_LENGTH }

sub rows {
	return ({ mode => 'live_map_random_targets' });
}

sub row_headers {
	return ('Mode');
}

sub row_values {
	my (undef, $row) = @_;
	return ($row->{mode});
}

sub row_progress_label {
	my (undef, $row) = @_;
	return $row->{mode};
}

sub scenario_order {
	return ('random_targets');
}

sub applicable_scenarios {
	return ('random_targets');
}

sub original_callback {
	return resolve_field_method('canMove_perl');
}

sub candidate_callback {
	return resolve_field_method('canMove');
}

sub snapshot_state {
	return {
		char_defined       => defined $char ? 1 : 0,
		field_defined      => defined $field ? 1 : 0,
		char_pos_to        => (defined $char && defined $char->{pos_to}) ? { %{$char->{pos_to}} } : undef,
		field_ref          => $field,
		has_max_walk_path => exists $config{maxWalkPathDistance},
		max_walk_path     => $config{maxWalkPathDistance},
	};
}

sub restore_state {
	my (undef, $snapshot) = @_;

	if ($snapshot->{has_max_walk_path}) {
		$config{maxWalkPathDistance} = $snapshot->{max_walk_path};
	} else {
		delete $config{maxWalkPathDistance};
	}
}

sub apply_case {
	return 1;
}

sub build_case {
	my (undef, undef, $scenario, $sample_iterations) = @_;
	my $live_field = current_field();
	my $from = current_from();
	my $max_walk_path = max_walk_path_distance();
	my @targets;

	for (1 .. $sample_iterations) {
		push @targets, random_target_within_distance($live_field, $from, $max_walk_path);
	}

	return {
		field           => $live_field,
		from            => $from,
		targets         => \@targets,
		arguments       => [],
		scenario        => $scenario,
		expected_result => undef,
	};
}

sub measure_case_pair {
	my (undef, $original_sub, $candidate_sub, $case, undef, $start_with_candidate) = @_;
	my $live_field = $case->{field};
	my $from = $case->{from};
	my $targets_ref = $case->{targets};
	my ($elapsed_original, $elapsed_candidate) = (0, 0);

	validate_methods_match($original_sub, $candidate_sub, $live_field, $from, $targets_ref);

	if ($start_with_candidate) {
		$elapsed_candidate = measure_method_over_targets($candidate_sub, $live_field, $from, $targets_ref);
		$elapsed_original = measure_method_over_targets($original_sub, $live_field, $from, $targets_ref);
	} else {
		$elapsed_original = measure_method_over_targets($original_sub, $live_field, $from, $targets_ref);
		$elapsed_candidate = measure_method_over_targets($candidate_sub, $live_field, $from, $targets_ref);
	}

	return ($elapsed_original, $elapsed_candidate, scalar @{$targets_ref});
}

sub current_field {
	die "canMove benchmark requires a loaded field.\n" if !defined $field;
	return $field;
}

sub resolve_field_method {
	my ($method_name) = @_;
	return if !$method_name;

	my $field_method = Field->can($method_name);
	return $field_method if $field_method;

	if (defined $field) {
		my $object_method = $field->can($method_name);
		return $object_method if $object_method;
	}

	no strict 'refs';
	return *{"Field::$method_name"}{CODE};
}

sub current_from {
	die "canMove benchmark requires an online character with pos_to.\n"
		if !defined $char || !defined $char->{pos_to} || !defined $char->{pos_to}{x} || !defined $char->{pos_to}{y};

	return {
		x => $char->{pos_to}{x},
		y => $char->{pos_to}{y},
	};
}

sub max_walk_path_distance {
	return $config{maxWalkPathDistance} || 17;
}

sub random_target_within_distance {
	my ($live_field, $from, $max_distance) = @_;
	my $attempts = 0;

	while ($attempts++ < 500) {
		my $dx = int(rand($max_distance * 2 + 1)) - $max_distance;
		my $dy = int(rand($max_distance * 2 + 1)) - $max_distance;
		my $to = {
			x => $from->{x} + $dx,
			y => $from->{y} + $dy,
		};

		#next if $live_field->isOffMap($to->{x}, $to->{y});
		next if blockDistance($from, $to) < MIN_TARGET_DISTANCE;
		next if blockDistance($from, $to) > $max_distance;
		return $to;
	}

	die sprintf(
		"Unable to find a random target within distance %d from (%d,%d) on map %s.\n",
		$max_distance,
		$from->{x},
		$from->{y},
		($live_field->can('name') ? $live_field->name() : 'unknown'),
	);
}

sub measure_method_over_targets {
	my ($method, $live_field, $from, $targets_ref) = @_;
	my $start = time;

	foreach my $to (@{$targets_ref}) {
		$method->($live_field, $from, $to);
	}

	return (time - $start);
}

sub validate_methods_match {
	my ($original_sub, $candidate_sub, $live_field, $from, $targets_ref) = @_;
	my $index = 0;

	foreach my $to (@{$targets_ref}) {
		my $original = $original_sub->($live_field, $from, $to) ? 1 : 0;
		my $candidate = $candidate_sub->($live_field, $from, $to) ? 1 : 0;
		if ($original != $candidate) {
			debugall($live_field, $from, $to);
			die sprintf(
				"canMove benchmark mismatch at target %d on map %s. from=(%d,%d) to=(%d,%d) perl=%d candidate=%d\n",
				$index,
				($live_field->can('name') ? $live_field->name() : 'unknown'),
				$from->{x},
				$from->{y},
				$to->{x},
				$to->{y},
				$original,
				$candidate,
			);
		}
		$index++;
	}
}

sub debugall {
	my ($self, $from, $to) = @_;
	Log::warning "[debugall] start from [$from->{x} $from->{y}] to [$to->{x} $to->{y}]\n";
	

	unless ($self->isWalkable($from->{x}, $from->{y})) {
		Log::error "[debugall] Failed at isWalkable from\n";
		return 0;
	}
	unless ($self->isWalkable($to->{x}, $to->{y})) {
		Log::error "[debugall] Failed at isWalkable to\n";
		return 0;
	}

	my $dist = blockDistance($from, $to);

	# This value is actually set at
	# hercules conf\map\battle\client.conf max_walk_path (which is by default 17, can be higher)
	my $maxUnobstructed = $config{maxWalkPathDistance_Unobstructed} || 17;
	my $maxObstructed = $config{maxWalkPathDistance_Obstructed} || 14;

	Log::warning "[debugall] dist $dist\n";
	Log::warning "[debugall] maxUnobstructed $maxUnobstructed\n";
	Log::warning "[debugall] maxObstructed $maxObstructed\n";

	if ($dist > $maxUnobstructed) {
		Log::error "[debugall] Failed at maxUnobstructed (dist > maxUnobstructed)\n";
		return 0;
	}

	# Actually uses CheckLos at rathena - TODO: check which is better, both work
	# If there are no obstacles return success
	if ($self->checkPathFree($from, $to)) {
		Log::error "[debugall] passed checkPathFree\n";
		return 1;
	} else {
		Log::warning "[debugall] did not pass checkPathFree, so we are obstructed\n";
	}
	
	# If there are obstacles and the path is walkable the max solution dist acceptable is 14 (double check to save time)
	if ($dist > $maxObstructed) {
		Log::error "[debugall] Failed at maxObstructed (dist > maxObstructed)\n";
		return 0;
	}

	# Rathena: // Official number of walkable cells is 14 if and only if there is an obstacle between.
	# If there are obstacles and OFFICIAL_WALKPATH is defined (which is by default) then calculate a client pathfinding
	my $solution = Utils::get_client_solution($self, $from, $to);
	my $dist_path = scalar @{$solution};
	Log::warning "[debugall] dist_path $dist_path\n";

	if ($dist_path == 0) {
		Log::error "[debugall] Failed at dist_path (dist_path is 0)\n";
		return 0;
	}

	# As stated above max walk path for obstructed paths is 14
	# Pathfinding always returns the original cell in the solution, so remove 1 from it (or compare to 15 (14+1))
	$dist_path -= 1;
	Log::warning "[debugall] dist_path after reduction $dist_path\n";
	if ($dist_path > $maxObstructed) {
		Log::error "[debugall] Failed at dist_path (dist_path > maxObstructed) printing solution\n";
		Log::warning Data::Dumper::Dumper $solution;
		return 0;
	}

	Log::warning "[debugall] passed\n";
	return 1;
}

1;
