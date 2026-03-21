package inQueueBenchmark;

use strict;
use warnings;

use AI;
use Commands;
use File::Basename qw(dirname);
use File::Spec;
use List::Util qw(shuffle);
use Log qw(message warning error);
use Plugins;
use Time::HiRes qw(time);

use constant {
	PLUGIN_NAME    => 'inQueueBenchmark',
	COMMAND_HANDLE => 'ben',
	MAX_ARGUMENTS  => 15,
	MAX_QUEUE_SIZE => 5,
	ITERATIONS     => 10000,
	SAMPLES_PER_SCENARIO => 20,
	TOKEN_LENGTH => 12,
};

my $plugin_folder = dirname(__FILE__);
my $results_file = File::Spec->catfile($plugin_folder, 'results.txt');
my $command_id;
my $random_token_counter = 0;
my @scenario_order = qw(no_match early_match middle_match late_match multiple_matches);

Plugins::register(PLUGIN_NAME, 'Benchmarks AI::inQueue across queue and argument sizes', \&on_unload);
$command_id = Commands::register(
	[COMMAND_HANDLE, 'Run the AI::inQueue benchmark and write results.txt', \&on_command]
);

sub on_unload {
	Commands::unregister($command_id) if $command_id;
	$command_id = undef;
}

sub on_command {
	my (undef, $args) = @_;
	my $iterations = parse_iterations($args);
	return unless defined $iterations;

	run_benchmark($iterations);
}

sub parse_iterations {
	my ($args) = @_;
	$args =~ s/^\s+|\s+$//g if defined $args;
	return ITERATIONS if !defined $args || $args eq '';

	if ($args =~ /^(\d+)$/ && $1 > 0) {
		return $1;
	}

	error sprintf(
		"[%s] Syntax: %s [positive_iteration_count]\n",
		PLUGIN_NAME,
		COMMAND_HANDLE,
	);
	return;
}

sub run_benchmark {
	my ($iterations) = @_;
	my @original_ai_seq = @AI::ai_seq;
	my @original_ai_seq_args = @AI::ai_seq_args;
	my @rows;
	my %scenario_stats;
	my $test_number = 0;
	my $total_tests = MAX_ARGUMENTS * MAX_QUEUE_SIZE;
	my $original_sub = AI->can('inQueue');
	my $new_sub = AI->can('inQueueNew');
	my $seed = int(time * 1_000_000) ^ $$;
	my $measurement_order_counter = 0;

	srand($seed);

	if (!$original_sub || !$new_sub) {
		restore_ai_state(\@original_ai_seq, \@original_ai_seq_args);
		error sprintf(
			"[%s] Missing benchmark target(s): inQueue=%s inQueueNew=%s\n",
			PLUGIN_NAME,
			($original_sub ? 'yes' : 'no'),
			($new_sub ? 'yes' : 'no'),
		);
		return;
	}

	eval {
		for my $args_count (1 .. MAX_ARGUMENTS) {
			for my $queue_size (1 .. MAX_QUEUE_SIZE) {
				$test_number++;
				warning sprintf(
					"[%s] Running test %d/%d (args=%d, ai_seq=%d, iterations=%d)\n",
					PLUGIN_NAME,
					$test_number,
					$total_tests,
					$args_count,
					$queue_size,
					$iterations,
				);

				my @applicable_scenarios = get_applicable_scenarios($args_count, $queue_size);
				my $total_samples = scalar(@applicable_scenarios) * SAMPLES_PER_SCENARIO;
				die sprintf(
					"Not enough iterations (%d) for args=%d queue=%d. Need at least %d to distribute across %d samples.\n",
					$iterations,
					$args_count,
					$queue_size,
					$total_samples,
					$total_samples,
				) if $iterations < $total_samples;

				my @iterations_per_sample = distribute_iterations($iterations, $total_samples);
				my $sample_slot = 0;
				my %row = (
					args_count                    => $args_count,
					queue_size                    => $queue_size,
					iterations                    => $iterations,
					applicable_scenarios          => scalar @applicable_scenarios,
					scenario_list                 => join(', ', @applicable_scenarios),
					sample_count                  => $total_samples,
					inqueue_total_seconds         => 0,
					inqueue_new_total_seconds     => 0,
					inqueue_result                => 1,
					inqueue_new_result            => 1,
				);

				foreach my $scenario (@applicable_scenarios) {
					for (1 .. SAMPLES_PER_SCENARIO) {
						my $case = build_random_case($args_count, $queue_size, $scenario);
						my $sample_iterations = $iterations_per_sample[$sample_slot++];
						my $start_with_new = ($measurement_order_counter++ % 2) ? 1 : 0;
						my ($elapsed_original, $elapsed_new, $result_original, $result_new)
							= measure_case_pair($original_sub, $new_sub, $case, $sample_iterations, $start_with_new);

						$row{inqueue_total_seconds} += $elapsed_original;
						$row{inqueue_new_total_seconds} += $elapsed_new;
						$row{inqueue_result} &&= ($result_original == $case->{expected_result});
						$row{inqueue_new_result} &&= ($result_new == $case->{expected_result});

						update_scenario_stats(
							\%scenario_stats,
							$scenario,
							$sample_iterations,
							$elapsed_original,
							$elapsed_new,
						);
					}
				}

				$row{inqueue_mean_seconds} = $row{inqueue_total_seconds} / $iterations;
				$row{inqueue_new_mean_seconds} = $row{inqueue_new_total_seconds} / $iterations;
				$row{inqueue_mean_microseconds} = $row{inqueue_mean_seconds} * 1_000_000;
				$row{inqueue_new_mean_microseconds} = $row{inqueue_new_mean_seconds} * 1_000_000;

				die sprintf(
					"Aggregated inQueue validation failed for args=%d queue=%d.\n",
					$args_count,
					$queue_size,
				) unless $row{inqueue_result};
				die sprintf(
					"Aggregated inQueueNew validation failed for args=%d queue=%d.\n",
					$args_count,
					$queue_size,
				) unless $row{inqueue_new_result};

				push @rows, \%row;
			}
		}

		my @lines = format_results(\@rows, \%scenario_stats, $iterations, $seed);
		write_results_file(\@lines);
		1;
	} or do {
		my $err = $@ || 'Unknown benchmark failure';
		restore_ai_state(\@original_ai_seq, \@original_ai_seq_args);
		error sprintf("[%s] Benchmark failed: %s", PLUGIN_NAME, $err);
		return;
	};

	restore_ai_state(\@original_ai_seq, \@original_ai_seq_args);
	warning sprintf("[%s] Benchmark finished. Results written to %s\n", PLUGIN_NAME, $results_file);
	message sprintf("[%s] Benchmark complete. See %s\n", PLUGIN_NAME, $results_file), 'success';
}

sub get_applicable_scenarios {
	my ($args_count, $queue_size) = @_;
	my $max_matches = min_value($args_count, $queue_size);
	my @scenarios = ('no_match');

	if ($max_matches >= 1) {
		push @scenarios, qw(early_match middle_match late_match);
	}
	if ($max_matches >= 2) {
		push @scenarios, 'multiple_matches';
	}

	return @scenarios;
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

sub build_random_case {
	my ($args_count, $queue_size, $scenario) = @_;
	my %used;
	my @queue = map { generate_random_token(\%used) } 1 .. $queue_size;
	my @needles = map { generate_random_token(\%used) } 1 .. $args_count;
	my $match_count = 0;
	my $middle_queue = int($queue_size / 2);
	my $middle_args = int($args_count / 2);

	if ($scenario eq 'early_match') {
		$needles[0] = $queue[0];
		$match_count = 1;
	} elsif ($scenario eq 'middle_match') {
		$needles[$middle_args] = $queue[$middle_queue];
		$match_count = 1;
	} elsif ($scenario eq 'late_match') {
		$needles[$#needles] = $queue[$#queue];
		$match_count = 1;
	} elsif ($scenario eq 'multiple_matches') {
		my $max_matches = min_value($args_count, $queue_size);
		$match_count = 2 + int(rand($max_matches - 1));
		my @queue_indexes = shuffle(0 .. $#queue);
		my @needle_indexes = shuffle(0 .. $#needles);
		for my $i (0 .. $match_count - 1) {
			$needles[$needle_indexes[$i]] = $queue[$queue_indexes[$i]];
		}
	}

	return {
		queue           => \@queue,
		needles         => \@needles,
		match_count     => $match_count,
		scenario        => $scenario,
		expected_result => ($match_count > 0 ? 1 : 0),
	};
}

sub measure_case_pair {
	my ($original_sub, $new_sub, $case, $iterations, $start_with_new) = @_;
	my ($result_original, $result_new);
	my ($elapsed_original, $elapsed_new) = (0, 0);
	my @previous_ai_seq = @AI::ai_seq;
	my @previous_ai_seq_args = @AI::ai_seq_args;
	my $queue_ref = $case->{queue};
	my $needles_ref = $case->{needles};
	my $expected_result = $case->{expected_result};

	@AI::ai_seq = @{$queue_ref};
	@AI::ai_seq_args = map { {} } @{$queue_ref};

	$result_original = $original_sub->(@{$needles_ref});
	$result_new = $new_sub->(@{$needles_ref});
	if ($result_original != $expected_result || $result_new != $expected_result) {
		@AI::ai_seq = @previous_ai_seq;
		@AI::ai_seq_args = @previous_ai_seq_args;
		die sprintf(
			"Sanity check failed. scenario=%s expected=%d old=%d new=%d queue=[%s] needles=[%s]\n",
			$case->{scenario},
			$expected_result,
			$result_original,
			$result_new,
			join(', ', @{$queue_ref}),
			join(', ', @{$needles_ref}),
		);
	}

	if ($start_with_new) {
		($elapsed_new, $result_new) = measure_callback($new_sub, $needles_ref, $iterations);
		($elapsed_original, $result_original) = measure_callback($original_sub, $needles_ref, $iterations);
	} else {
		($elapsed_original, $result_original) = measure_callback($original_sub, $needles_ref, $iterations);
		($elapsed_new, $result_new) = measure_callback($new_sub, $needles_ref, $iterations);
	}

	@AI::ai_seq = @previous_ai_seq;
	@AI::ai_seq_args = @previous_ai_seq_args;

	return ($elapsed_original, $elapsed_new, $result_original, $result_new);
}

sub measure_callback {
	my ($callback, $needles_ref, $iterations) = @_;
	my $result;
	my $start = time;

	for (1 .. $iterations) {
		$result = $callback->(@{$needles_ref});
	}

	return (time - $start, $result);
}

sub update_scenario_stats {
	my ($stats_ref, $scenario, $iterations, $elapsed_original, $elapsed_new) = @_;
	my $stats = $stats_ref->{$scenario} ||= {
		samples => 0,
		total_calls => 0,
		inqueue_total_seconds => 0,
		inqueue_new_total_seconds => 0,
		inqueue_wins => 0,
		inqueue_new_wins => 0,
		ties => 0,
	};

	$stats->{samples}++;
	$stats->{total_calls} += $iterations;
	$stats->{inqueue_total_seconds} += $elapsed_original;
	$stats->{inqueue_new_total_seconds} += $elapsed_new;

	if ($elapsed_original < $elapsed_new) {
		$stats->{inqueue_wins}++;
	} elsif ($elapsed_new < $elapsed_original) {
		$stats->{inqueue_new_wins}++;
	} else {
		$stats->{ties}++;
	}
}

sub format_results {
	my ($rows_ref, $scenario_stats_ref, $iterations, $seed) = @_;
	my @lines;
	my ($sum_old, $sum_new, $old_wins, $new_wins, $ties) = (0, 0, 0, 0, 0);
	my ($best_row, $worst_row, $best_advantage, $worst_advantage);

	foreach my $row (@{$rows_ref}) {
		$sum_old += $row->{inqueue_total_seconds};
		$sum_new += $row->{inqueue_new_total_seconds};

		my ($winner, $advantage) = winner_and_advantage($row);
		$row->{winner} = $winner;
		$row->{advantage} = $advantage;

		if ($winner eq 'inQueue') {
			$old_wins++;
		} elsif ($winner eq 'inQueueNew') {
			$new_wins++;
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

	my $case_count = scalar @{$rows_ref} || 1;
	my $overall_ratio = $sum_new > 0 ? ($sum_old / $sum_new) : 0;
	my $old_mean_us = $sum_old / $case_count / $iterations * 1_000_000;
	my $new_mean_us = $sum_new / $case_count / $iterations * 1_000_000;

	push @lines, "AI::inQueue benchmark results";
	push @lines, sprintf("Generated at: %s", scalar localtime());
	push @lines, sprintf("Total calls per args/queue cell: %d", $iterations);
	push @lines, sprintf("Cases tested: %d (%d argument counts x %d queue sizes)", $case_count, MAX_ARGUMENTS, MAX_QUEUE_SIZE);
	push @lines, sprintf("Random seed: %d", $seed);
	push @lines, sprintf("Samples per scenario: %d", SAMPLES_PER_SCENARIO);
	push @lines, sprintf("Fixed token length: %d characters", TOKEN_LENGTH);
	push @lines, "Scenario mix: no_match, early_match, middle_match, late_match, multiple_matches (when possible).";
	push @lines, "Fairness notes: each cell uses many random samples, function timing order alternates per sample, and per-cell calls are distributed evenly across all samples.";
	push @lines, "";
	push @lines, "Summary";
	push @lines, "-------";
	push @lines, sprintf("Average inQueue time:    %.6f us/call", $old_mean_us);
	push @lines, sprintf("Average inQueueNew time: %.6f us/call", $new_mean_us);
	push @lines, sprintf("Overall ratio (inQueue / inQueueNew): %.6f", $overall_ratio);
	push @lines, sprintf("Winner counts: inQueue=%d, inQueueNew=%d, ties=%d", $old_wins, $new_wins, $ties);
	push @lines, sprintf(
		"Biggest win: %s",
		format_highlight_row($best_row),
	) if $best_row;
	push @lines, sprintf(
		"Smallest gap: %s",
		format_highlight_row($worst_row),
	) if $worst_row;
	push @lines, "";
	push @lines, "Scenario Summary";
	push @lines, "----------------";
	push @lines, sprintf(
		"%-18s %-10s %-10s %-16s %-16s",
		"Scenario", "Samples", "Calls", "inQueue (us)", "inQueueNew (us)"
	);
	push @lines, sprintf(
		"%-18s %-10s %-10s %-16s %-16s",
		"--------", "-------", "-----", "------------", "---------------"
	);
	foreach my $scenario (@scenario_order) {
		next if !$scenario_stats_ref->{$scenario};
		my $stats = $scenario_stats_ref->{$scenario};
		my $old_mean = $stats->{total_calls} ? $stats->{inqueue_total_seconds} / $stats->{total_calls} * 1_000_000 : 0;
		my $new_mean = $stats->{total_calls} ? $stats->{inqueue_new_total_seconds} / $stats->{total_calls} * 1_000_000 : 0;
		push @lines, sprintf(
			"%-18s %-10d %-10d %-16.6f %-16.6f",
			$scenario,
			$stats->{samples},
			$stats->{total_calls},
			$old_mean,
			$new_mean,
		);
	}
	push @lines, "";
	push @lines, "Detailed results";
	push @lines, "--------------";
	push @lines, sprintf(
		"%-4s %-5s %-6s %-7s %-10s %-16s %-16s %-10s %-10s",
		"Args", "Queue", "Scen", "Samples", "Calls", "inQueue (us)", "inQueueNew (us)", "Winner", "FasterBy"
	);
	push @lines, sprintf(
		"%-4s %-5s %-6s %-7s %-10s %-16s %-16s %-10s %-10s",
		"----", "-----", "----", "-------", "-----", "------------", "---------------", "------", "--------"
	);

	foreach my $row (@{$rows_ref}) {
		push @lines, sprintf(
			"%-4d %-5d %-6d %-7d %-10d %-16.6f %-16.6f %-10s %-10.3fx",
			$row->{args_count},
			$row->{queue_size},
			$row->{applicable_scenarios},
			$row->{sample_count},
			$row->{iterations},
			$row->{inqueue_mean_microseconds},
			$row->{inqueue_new_mean_microseconds},
			$row->{winner},
			$row->{advantage},
		);
	}

	push @lines, "";
	push @lines, "Legend";
	push @lines, "------";
	push @lines, "Scen: number of scenario types included for that args/queue cell.";
	push @lines, "Samples: number of random samples used for that cell.";
	push @lines, "Calls: total timed calls per function for that cell, distributed across all samples.";
	push @lines, "Winner: which function had the lower mean time for that case.";
	push @lines, "FasterBy: how many times the winner was faster than the loser.";

	return @lines;
}

sub winner_and_advantage {
	my ($row) = @_;
	my $old = $row->{inqueue_mean_microseconds};
	my $new = $row->{inqueue_new_mean_microseconds};

	if ($old < $new) {
		return ('inQueue', safe_ratio($new, $old));
	} elsif ($new < $old) {
		return ('inQueueNew', safe_ratio($old, $new));
	}

	return ('tie', 1);
}

sub safe_ratio {
	my ($numerator, $denominator) = @_;
	return 0 if !$denominator;
	return $numerator / $denominator;
}

sub format_highlight_row {
	my ($row) = @_;
	return '' if !$row;

	return sprintf(
		"args=%d, queue=%d, winner=%s, inQueue=%.6f us, inQueueNew=%.6f us, fasterBy=%.3fx",
		$row->{args_count},
		$row->{queue_size},
		$row->{winner},
		$row->{inqueue_mean_microseconds},
		$row->{inqueue_new_mean_microseconds},
		$row->{advantage},
	);
}

sub generate_random_token {
	my ($used_ref) = @_;
	my @chars = ('A' .. 'Z', 'a' .. 'z', 0 .. 9);

	while (1) {
		my $token = '';
		$random_token_counter++;
		for (1 .. TOKEN_LENGTH) {
			$token .= $chars[int(rand(@chars))];
		}
		next if $used_ref->{$token};
		$used_ref->{$token} = 1;
		return $token;
	}
}

sub min_value {
	my ($left, $right) = @_;
	return $left < $right ? $left : $right;
}

sub write_results_file {
	my ($lines_ref) = @_;

	open(my $fh, '>:utf8', $results_file)
		or die sprintf("Unable to write '%s': %s\n", $results_file, $!);
	print {$fh} join("\n", @{$lines_ref}), "\n";
	close($fh)
		or die sprintf("Unable to close '%s': %s\n", $results_file, $!);
}

sub restore_ai_state {
	my ($ai_seq_ref, $ai_seq_args_ref) = @_;

	@AI::ai_seq = @{$ai_seq_ref};
	@AI::ai_seq_args = @{$ai_seq_args_ref};
}

1;
