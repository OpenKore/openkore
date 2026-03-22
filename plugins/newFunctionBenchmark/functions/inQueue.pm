package newFunctionBenchmark::functions::inQueue;

use strict;
use warnings;

use AI;
use List::Util qw(shuffle);

use constant {
	MAX_ARGUMENTS        => 15,
	MAX_QUEUE_SIZE       => 5,
	DEFAULT_ITERATIONS   => 10000,
	SAMPLES_PER_SCENARIO => 20,
	TOKEN_LENGTH         => 12,
};

my $random_token_counter = 0;

sub benchmark_name { 'inQueue' }
sub original_name { 'inQueue' }
sub candidate_name { 'inQueueNew' }
sub default_iterations { DEFAULT_ITERATIONS }
sub samples_per_scenario { SAMPLES_PER_SCENARIO }
sub token_length { TOKEN_LENGTH }

sub rows {
	my @rows;
	for my $args_count (1 .. MAX_ARGUMENTS) {
		for my $queue_size (1 .. MAX_QUEUE_SIZE) {
			push @rows, {
				args_count => $args_count,
				queue_size => $queue_size,
			};
		}
	}
	return @rows;
}

sub row_headers {
	return ('Args', 'Queue');
}

sub row_values {
	my (undef, $row) = @_;
	return ($row->{args_count}, $row->{queue_size});
}

sub row_progress_label {
	my (undef, $row) = @_;
	return sprintf('args=%d, ai_seq=%d', $row->{args_count}, $row->{queue_size});
}

sub scenario_order {
	return qw(no_match early_match middle_match late_match multiple_matches);
}

sub applicable_scenarios {
	my (undef, $row) = @_;
	my $max_matches = min_value($row->{args_count}, $row->{queue_size});
	my @scenarios = ('no_match');

	if ($max_matches >= 1) {
		push @scenarios, qw(early_match middle_match late_match);
	}
	if ($max_matches >= 2) {
		push @scenarios, 'multiple_matches';
	}

	return @scenarios;
}

sub original_callback {
	return AI->can('inQueue');
}

sub candidate_callback {
	return AI->can('inQueueNew');
}

sub snapshot_state {
	return {
		ai_seq => [@AI::ai_seq],
		ai_seq_args => [@AI::ai_seq_args],
	};
}

sub restore_state {
	my (undef, $snapshot) = @_;
	@AI::ai_seq = @{$snapshot->{ai_seq}};
	@AI::ai_seq_args = @{$snapshot->{ai_seq_args}};
}

sub apply_case {
	my (undef, $case) = @_;
	@AI::ai_seq = @{$case->{queue}};
	@AI::ai_seq_args = map { {} } @{$case->{queue}};
}

sub build_case {
	my (undef, $row, $scenario) = @_;
	my %used;
	my @queue = map { generate_random_token(\%used) } 1 .. $row->{queue_size};
	my @arguments = map { generate_random_token(\%used) } 1 .. $row->{args_count};
	my $match_count = 0;
	my $middle_queue = int($row->{queue_size} / 2);
	my $middle_args = int($row->{args_count} / 2);

	if ($scenario eq 'early_match') {
		$arguments[0] = $queue[0];
		$match_count = 1;
	} elsif ($scenario eq 'middle_match') {
		$arguments[$middle_args] = $queue[$middle_queue];
		$match_count = 1;
	} elsif ($scenario eq 'late_match') {
		$arguments[$#arguments] = $queue[$#queue];
		$match_count = 1;
	} elsif ($scenario eq 'multiple_matches') {
		my $max_matches = min_value($row->{args_count}, $row->{queue_size});
		$match_count = 2 + int(rand($max_matches - 1));
		my @queue_indexes = shuffle(0 .. $#queue);
		my @argument_indexes = shuffle(0 .. $#arguments);
		for my $i (0 .. $match_count - 1) {
			$arguments[$argument_indexes[$i]] = $queue[$queue_indexes[$i]];
		}
	}

	return {
		queue => \@queue,
		arguments => \@arguments,
		match_count => $match_count,
		scenario => $scenario,
		expected_result => ($match_count > 0 ? 1 : 0),
	};
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

1;
