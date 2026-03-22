package newFunctionBenchmark;

use strict;
use warnings;

use Commands;
use File::Basename qw(dirname);
use File::Spec;
use Log qw(message warning error);
use Plugins;
use Time::HiRes qw(time);

use constant {
	PLUGIN_NAME       => 'newFunctionBenchmark',
	COMMAND_HANDLE    => 'ben',
	DEFAULT_BENCHMARK => 'inQueue',
};

my $plugin_folder = dirname(__FILE__);
my $functions_folder = File::Spec->catdir($plugin_folder, 'functions');
my $results_file = File::Spec->catfile($plugin_folder, 'results.txt');
my $command_id;

Plugins::register(PLUGIN_NAME, 'Generic benchmark runner for legacy and new function implementations', \&on_unload);
$command_id = Commands::register(
	[COMMAND_HANDLE, 'Run a benchmark: ben [benchmark_name] [total_calls_per_row]', \&on_command]
);

sub on_unload {
	Commands::unregister($command_id) if $command_id;
	$command_id = undef;
}

sub on_command {
	my (undef, $args) = @_;
	my ($benchmark_name, $iterations) = parse_command_args($args);
	my $benchmark = load_benchmark($benchmark_name);
	return unless $benchmark;

	$iterations = $benchmark->default_iterations() if !defined $iterations;
	run_benchmark($benchmark, $iterations);
}

sub parse_command_args {
	my ($args) = @_;
	my @parts = grep { $_ ne '' } split /\s+/, ($args // '');
	my $benchmark_name = DEFAULT_BENCHMARK;
	my $iterations;

	if (@parts && $parts[0] !~ /^\d+$/) {
		$benchmark_name = shift @parts;
	}

	if (@parts) {
		if ($parts[0] =~ /^(\d+)$/ && $1 > 0) {
			$iterations = $1;
			shift @parts;
		} else {
			error sprintf("[%s] Invalid iteration count: %s\n", PLUGIN_NAME, $parts[0]);
			return;
		}
	}

	if (@parts) {
		error sprintf("[%s] Syntax: %s [benchmark_name] [positive_total_calls_per_row]\n", PLUGIN_NAME, COMMAND_HANDLE);
		return;
	}

	return ($benchmark_name, $iterations);
}

sub load_benchmark {
	my ($benchmark_name) = @_;
	my $file = File::Spec->catfile($functions_folder, "$benchmark_name.pm");
	my $package = "newFunctionBenchmark::functions::$benchmark_name";

	if (!-f $file) {
		error sprintf("[%s] Benchmark '%s' not found at %s\n", PLUGIN_NAME, $benchmark_name, $file);
		return;
	}

	eval { require $file; 1; } or do {
		error sprintf("[%s] Failed to load benchmark '%s': %s", PLUGIN_NAME, $benchmark_name, $@ || 'unknown error');
		return;
	};

	for my $method (qw(
		benchmark_name
		original_name
		candidate_name
		default_iterations
		samples_per_scenario
		token_length
		rows
		row_headers
		row_values
		row_progress_label
		scenario_order
		applicable_scenarios
		original_callback
		candidate_callback
		snapshot_state
		restore_state
		apply_case
		build_case
	)) {
		if (!$package->can($method)) {
			error sprintf("[%s] Benchmark '%s' is missing required method '%s'\n", PLUGIN_NAME, $benchmark_name, $method);
			return;
		}
	}

	return $package;
}

sub run_benchmark {
	my ($benchmark, $iterations) = @_;
	my $original_snapshot = $benchmark->snapshot_state();
	my @rows;
	my %scenario_stats;
	my @row_definitions = $benchmark->rows();
	my $total_rows = scalar @row_definitions;
	my $seed = int(time * 1_000_000) ^ $$;
	my $measurement_order_counter = 0;

	warning sprintf("[%s] Testing original callback: %s\n", PLUGIN_NAME, $benchmark->original_name());
	my $original_sub = $benchmark->original_callback();


	warning sprintf("[%s] Testing candidate callback: %s\n", PLUGIN_NAME, $benchmark->candidate_name());
	my $candidate_sub = $benchmark->candidate_callback();

	srand($seed);

	if (!$original_sub || !$candidate_sub) {
		$benchmark->restore_state($original_snapshot);
		error sprintf(
			"[%s] Missing benchmark target(s) for %s: %s=%s %s=%s\n",
			PLUGIN_NAME,
			$benchmark->benchmark_name(),
			$benchmark->original_name(),
			($original_sub ? 'yes' : 'no'),
			$benchmark->candidate_name(),
			($candidate_sub ? 'yes' : 'no'),
		);
		return;
	}

	eval {
		my $row_index = 0;
		foreach my $row_definition (@row_definitions) {
			$row_index++;
			warning sprintf(
				"[%s] Running %s test %d/%d (%s, calls=%d)\n",
				PLUGIN_NAME,
				$benchmark->benchmark_name(),
				$row_index,
				$total_rows,
				$benchmark->row_progress_label($row_definition),
				$iterations,
			);

			my @applicable_scenarios = $benchmark->applicable_scenarios($row_definition);
			my $samples_per_scenario = $benchmark->samples_per_scenario();
			my $total_samples = scalar(@applicable_scenarios) * $samples_per_scenario;

			die sprintf(
				"Not enough calls (%d) for %s row %s. Need at least %d to distribute across %d samples.\n",
				$iterations,
				$benchmark->benchmark_name(),
				$benchmark->row_progress_label($row_definition),
				$total_samples,
				$total_samples,
			) if $iterations < $total_samples;

			my @iterations_per_sample = distribute_iterations($iterations, $total_samples);
			my $sample_slot = 0;
			my %row = (
				row_definition             => $row_definition,
				applicable_scenarios       => scalar @applicable_scenarios,
				scenario_list              => join(', ', @applicable_scenarios),
				sample_count               => $total_samples,
				iterations                 => $iterations,
				total_calls                => 0,
				original_total_seconds     => 0,
				candidate_total_seconds    => 0,
			);

			foreach my $scenario (@applicable_scenarios) {
				for (1 .. $samples_per_scenario) {
					my $sample_iterations = $iterations_per_sample[$sample_slot++];
					my $case = $benchmark->build_case($row_definition, $scenario, $sample_iterations);
					my $start_with_candidate = ($measurement_order_counter++ % 2) ? 1 : 0;
					my ($elapsed_original, $elapsed_candidate, $calls_count)
						= ($benchmark->can('measure_case_pair'))
							? $benchmark->measure_case_pair(
								$original_sub,
								$candidate_sub,
								$case,
								$sample_iterations,
								$start_with_candidate,
							)
							: generic_measure_case_pair(
								$benchmark,
								$original_sub,
								$candidate_sub,
								$case,
								$sample_iterations,
								$start_with_candidate,
							);

					$row{original_total_seconds} += $elapsed_original;
					$row{candidate_total_seconds} += $elapsed_candidate;
					$row{total_calls} += $calls_count;

					update_scenario_stats(
						\%scenario_stats,
						$scenario,
						$calls_count,
						$elapsed_original,
						$elapsed_candidate,
					);
				}
			}

			$row{original_mean_seconds} = $row{total_calls} ? ($row{original_total_seconds} / $row{total_calls}) : 0;
			$row{candidate_mean_seconds} = $row{total_calls} ? ($row{candidate_total_seconds} / $row{total_calls}) : 0;
			$row{original_mean_microseconds} = $row{original_mean_seconds} * 1_000_000;
			$row{candidate_mean_microseconds} = $row{candidate_mean_seconds} * 1_000_000;
			push @rows, \%row;
		}

		my @lines = format_results($benchmark, \@rows, \%scenario_stats, $iterations, $seed);
		write_results_file(\@lines);
		1;
	} or do {
		my $err = $@ || 'Unknown benchmark failure';
		$benchmark->restore_state($original_snapshot);
		error sprintf("[%s] Benchmark failed: %s", PLUGIN_NAME, $err);
		return;
	};

	$benchmark->restore_state($original_snapshot);
	warning sprintf(
		"[%s] %s benchmark finished. Results written to %s\n",
		PLUGIN_NAME,
		$benchmark->benchmark_name(),
		$results_file,
	);
	message sprintf(
		"[%s] %s benchmark complete. See %s\n",
		PLUGIN_NAME,
		$benchmark->benchmark_name(),
		$results_file,
	), 'success';
}

sub distribute_iterations {
	my ($total_iterations, $sample_count) = @_;
	my @distribution;
	my $base = int($total_iterations / $sample_count);
	my $remainder = $total_iterations % $sample_count;

	for my $index (0 .. $sample_count - 1) {
		push @distribution, $base + ($index < $remainder ? 1 : 0);
	}

	return @distribution;
}

sub generic_measure_case_pair {
	my ($benchmark, $original_sub, $candidate_sub, $case, $iterations, $start_with_candidate) = @_;
	my $snapshot = $benchmark->snapshot_state();
	my $expected_result = $case->{expected_result};
	my ($result_original, $result_candidate);
	my ($elapsed_original, $elapsed_candidate) = (0, 0);

	$benchmark->apply_case($case);

	$result_original = $original_sub->(@{$case->{arguments}});
	$result_candidate = $candidate_sub->(@{$case->{arguments}});
	if ($result_original != $expected_result || $result_candidate != $expected_result) {
		$benchmark->restore_state($snapshot);
		die sprintf(
			"Sanity check failed. benchmark=%s scenario=%s expected=%d old=%d new=%d\n",
			$benchmark->benchmark_name(),
			($case->{scenario} || 'unknown'),
			$expected_result,
			$result_original,
			$result_candidate,
		);
	}

	if ($start_with_candidate) {
		($elapsed_candidate, $result_candidate) = measure_callback($candidate_sub, $case->{arguments}, $iterations);
		($elapsed_original, $result_original) = measure_callback($original_sub, $case->{arguments}, $iterations);
	} else {
		($elapsed_original, $result_original) = measure_callback($original_sub, $case->{arguments}, $iterations);
		($elapsed_candidate, $result_candidate) = measure_callback($candidate_sub, $case->{arguments}, $iterations);
	}

	if ($result_original != $expected_result || $result_candidate != $expected_result) {
		$benchmark->restore_state($snapshot);
		die sprintf(
			"Timed validation failed. benchmark=%s scenario=%s expected=%d old=%d new=%d\n",
			$benchmark->benchmark_name(),
			($case->{scenario} || 'unknown'),
			$expected_result,
			$result_original,
			$result_candidate,
		);
	}

	$benchmark->restore_state($snapshot);
	return ($elapsed_original, $elapsed_candidate, $iterations);
}

sub measure_callback {
	my ($callback, $arguments_ref, $iterations) = @_;
	my $result;
	my $start = time;

	for (1 .. $iterations) {
		$result = $callback->(@{$arguments_ref});
	}

	return (time - $start, $result);
}

sub update_scenario_stats {
	my ($stats_ref, $scenario, $iterations, $elapsed_original, $elapsed_candidate) = @_;
	my $stats = $stats_ref->{$scenario} ||= {
		samples => 0,
		total_calls => 0,
		original_total_seconds => 0,
		candidate_total_seconds => 0,
	};

	$stats->{samples}++;
	$stats->{total_calls} += $iterations;
	$stats->{original_total_seconds} += $elapsed_original;
	$stats->{candidate_total_seconds} += $elapsed_candidate;
}

sub format_results {
	my ($benchmark, $rows_ref, $scenario_stats_ref, $iterations, $seed) = @_;
	my @lines;
	my @row_headers = $benchmark->row_headers();
	my @base_widths = map { length($_) } @row_headers;
	my ($sum_original, $sum_candidate, $original_wins, $candidate_wins, $ties) = (0, 0, 0, 0, 0);
	my ($best_row, $worst_row, $best_advantage, $worst_advantage);
	my $sum_calls = 0;

	foreach my $row (@{$rows_ref}) {
		my @values = map { "$_" } $benchmark->row_values($row->{row_definition});
		for my $i (0 .. $#values) {
			$base_widths[$i] = length($values[$i]) if length($values[$i]) > $base_widths[$i];
		}

		$sum_original += $row->{original_total_seconds};
		$sum_candidate += $row->{candidate_total_seconds};
		$sum_calls += $row->{total_calls};

		my ($winner, $advantage) = winner_and_advantage($benchmark, $row);
		$row->{winner} = $winner;
		$row->{advantage} = $advantage;

		if ($winner eq $benchmark->original_name()) {
			$original_wins++;
		} elsif ($winner eq $benchmark->candidate_name()) {
			$candidate_wins++;
		} else {
			$ties++;
		}

		if (!defined $best_advantage || $advantage > $best_advantage) {
			$best_advantage = $advantage;
			$best_row = $row;
		}
		if (!defined $worst_advantage || $advantage < $worst_advantage) {
			$worst_advantage = $advantage;
			$worst_row = $row;
		}
	}

	my $row_count = scalar @{$rows_ref} || 1;
	my $overall_ratio = $sum_candidate > 0 ? ($sum_original / $sum_candidate) : 0;
	my $original_mean_us = $sum_calls ? ($sum_original / $sum_calls * 1_000_000) : 0;
	my $candidate_mean_us = $sum_calls ? ($sum_candidate / $sum_calls * 1_000_000) : 0;

	push @lines, sprintf("%s benchmark results", $benchmark->benchmark_name());
	push @lines, sprintf("Generated at: %s", scalar localtime());
	push @lines, sprintf("Compared functions: %s vs %s", $benchmark->original_name(), $benchmark->candidate_name());
	push @lines, sprintf("Requested calls per row: %d", $iterations);
	push @lines, sprintf("Rows tested: %d", $row_count);
	push @lines, sprintf("Random seed: %d", $seed);
	push @lines, sprintf("Samples per scenario: %d", $benchmark->samples_per_scenario());
	push @lines, sprintf("Fixed token length: %d", $benchmark->token_length());
	push @lines, sprintf("Scenario mix: %s", join(', ', $benchmark->scenario_order()));
	push @lines, "";
	push @lines, "Summary";
	push @lines, "-------";
	push @lines, sprintf("Average %s time: %0.6f us/call", $benchmark->original_name(), $original_mean_us);
	push @lines, sprintf("Average %s time: %0.6f us/call", $benchmark->candidate_name(), $candidate_mean_us);
	push @lines, sprintf("Overall ratio (%s / %s): %0.6f", $benchmark->original_name(), $benchmark->candidate_name(), $overall_ratio);
	push @lines, sprintf(
		"Winner counts: %s=%d, %s=%d, ties=%d",
		$benchmark->original_name(), $original_wins,
		$benchmark->candidate_name(), $candidate_wins,
		$ties,
	);
	push @lines, sprintf("Biggest win: %s", format_highlight_row($benchmark, $best_row)) if $best_row;
	push @lines, sprintf("Smallest gap: %s", format_highlight_row($benchmark, $worst_row)) if $worst_row;
	push @lines, "";
	push @lines, "Scenario Summary";
	push @lines, "----------------";
	push @lines, sprintf(
		"%-18s %-10s %-10s %-16s %-16s",
		"Scenario", "Samples", "Calls",
		$benchmark->original_name() . " (us)",
		$benchmark->candidate_name() . " (us)",
	);
	push @lines, sprintf(
		"%-18s %-10s %-10s %-16s %-16s",
		"--------", "-------", "-----", "------------", "---------------"
	);
	foreach my $scenario ($benchmark->scenario_order()) {
		next if !$scenario_stats_ref->{$scenario};
		my $stats = $scenario_stats_ref->{$scenario};
		my $original_mean = $stats->{total_calls} ? $stats->{original_total_seconds} / $stats->{total_calls} * 1_000_000 : 0;
		my $candidate_mean = $stats->{total_calls} ? $stats->{candidate_total_seconds} / $stats->{total_calls} * 1_000_000 : 0;
		push @lines, sprintf(
			"%-18s %-10d %-10d %-16.6f %-16.6f",
			$scenario,
			$stats->{samples},
			$stats->{total_calls},
			$original_mean,
			$candidate_mean,
		);
	}
	push @lines, "";
	push @lines, "Detailed results";
	push @lines, "--------------";

	my @headers = (@row_headers, 'Scen', 'Samples', 'Calls', $benchmark->original_name() . ' (us)', $benchmark->candidate_name() . ' (us)', 'Winner', 'FasterBy');
	my @widths = (@base_widths, 4, 7, 10, 16, 16, 10, 10);
	push @lines, format_table_row(\@widths, \@headers);
	push @lines, format_table_row(\@widths, [map { '-' x length($_) } @headers]);

	foreach my $row (@{$rows_ref}) {
		my @values = (
			map { "$_" } $benchmark->row_values($row->{row_definition}),
			$row->{applicable_scenarios},
			$row->{sample_count},
			$row->{total_calls},
			sprintf('%.6f', $row->{original_mean_microseconds}),
			sprintf('%.6f', $row->{candidate_mean_microseconds}),
			$row->{winner},
			sprintf('%.3fx', $row->{advantage}),
		);
		push @lines, format_table_row(\@widths, \@values);
	}

	return @lines;
}

sub format_table_row {
	my ($widths_ref, $values_ref) = @_;
	my @parts;

	for my $i (0 .. $#{$values_ref}) {
		push @parts, sprintf("%-*s", $widths_ref->[$i], $values_ref->[$i]);
	}

	return join(' ', @parts);
}

sub winner_and_advantage {
	my ($benchmark, $row) = @_;
	my $original = $row->{original_mean_microseconds};
	my $candidate = $row->{candidate_mean_microseconds};

	if ($original < $candidate) {
		return ($benchmark->original_name(), safe_ratio($candidate, $original));
	} elsif ($candidate < $original) {
		return ($benchmark->candidate_name(), safe_ratio($original, $candidate));
	}

	return ('tie', 1);
}

sub format_highlight_row {
	my ($benchmark, $row) = @_;
	return '' if !$row;

	return sprintf(
		"%s, winner=%s, %s=%.6f us, %s=%.6f us, fasterBy=%.3fx",
		$benchmark->row_progress_label($row->{row_definition}),
		$row->{winner},
		$benchmark->original_name(),
		$row->{original_mean_microseconds},
		$benchmark->candidate_name(),
		$row->{candidate_mean_microseconds},
		$row->{advantage},
	);
}

sub safe_ratio {
	my ($numerator, $denominator) = @_;
	return 0 if !$denominator;
	return $numerator / $denominator;
}

sub write_results_file {
	my ($lines_ref) = @_;

	open(my $fh, '>:utf8', $results_file)
		or die sprintf("Unable to write '%s': %s\n", $results_file, $!);
	print {$fh} join("\n", @{$lines_ref}), "\n";
	close($fh)
		or die sprintf("Unable to close '%s': %s\n", $results_file, $!);
}

1;
