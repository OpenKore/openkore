#########################################################################
#  calcPosFromPathfindingCompare plugin for OpenKore
#
#  Compares `calcPosFromPathfinding_old` and `calcPosFromPathfinding`
#  against the next position received in `character_moves`, and also
#  compares both predictors at the exact moment Task::Route decides to
#  send a movement packet.
#
#  For `route_setMove`, it also benchmarks a third prediction that pushes
#  the new predictor forward by the measured average time between
#  `setMove` and the matching `character_moves` reply.
#########################################################################

package calcPosFromPathfindingCompare;

use strict;
use Time::HiRes qw(time);
use Plugins;
use Globals qw($char $field);
use Log qw(message warning);
use Utils qw(calcPosFromPathfinding calcPosFromPathfinding_old blockDistance adjustedBlockDistance);
use File::Spec;
use Settings;

use constant {
	PLUGIN_NAME => 'calcPosFromPathfindingCompare',
	SUMMARY_INTERVAL => 100,
};

Plugins::register(PLUGIN_NAME, 'Compares old and new calcPosFromPathfinding predictions', \&on_unload, \&on_reload);

my $hooks = Plugins::addHooks(
	['start3', \&on_start, undef],
	['packet_pre/character_moves', \&on_character_moves_pre, undef],
	['packet/character_moves', \&on_character_moves_post, undef],
	['route_setMove', \&on_route_set_move, undef],
	['packet/map_changed', \&on_map_changed, undef],
);

my %contexts = (
	character_moves => new_context('Character Moves', 0),
	route_setMove => new_context('Route SetMove', 1),
);

my $pending_character_moves_sample;
my $pending_route_sample;
my $log_file = File::Spec->catfile($Settings::logs_folder, 'calcPosFromPathfinding_compare.txt');

sub new_context {
	my ($title, $has_latency_adjusted) = @_;
	return {
		title => $title,
		has_latency_adjusted => $has_latency_adjusted || 0,
		total => 0,
		old_exact => 0,
		new_exact => 0,
		latency_adjusted_exact => 0,
		both_exact => 0,
		both_wrong => 0,
		old_only_exact => 0,
		new_only_exact => 0,
		latency_adjusted_only_exact => 0,
		old_block_closer => 0,
		new_block_closer => 0,
		latency_adjusted_block_closer => 0,
		block_tied_distance => 0,
		old_block_total_dist => 0,
		new_block_total_dist => 0,
		latency_adjusted_block_total_dist => 0,
		old_adjusted_closer => 0,
		new_adjusted_closer => 0,
		latency_adjusted_adjusted_closer => 0,
		adjusted_tied_distance => 0,
		old_adjusted_total_dist => 0,
		new_adjusted_total_dist => 0,
		latency_adjusted_adjusted_total_dist => 0,
		walk_speed_total => 0,
		response_time_total => 0,
		response_time_count => 0,
		last_event => {},
	};
}

sub on_reload {
	Plugins::delHooks($hooks) if $hooks;
}

sub on_unload {
	emit_summary('final (not written to file)', 0) if has_data();
	message "[" . PLUGIN_NAME . "] unloading. Results file is updated only on summary intervals: $log_file\n", 'system';
	Plugins::delHooks($hooks) if $hooks;
}

sub on_start {
	message "[" . PLUGIN_NAME . "] enabled. Summary interval: " . SUMMARY_INTERVAL . " events. Results file: $log_file\n", 'system';
}

sub on_map_changed {
	my (undef, $args) = @_;
	my $map = ($field && $field->baseName) || ($args && $args->{field} && $args->{field}{name}) || 'unknown';
	undef $pending_character_moves_sample;
	undef $pending_route_sample;
	message "[" . PLUGIN_NAME . "] map changed to $map\n", 'system';
}

sub on_character_moves_pre {
	my (undef, $args) = @_;
	return unless $char && $field;
	return unless $char->{pos} && $char->{pos_to};

	my $old_prediction = calcPosFromPathfinding_old($field, $char);
	my $new_prediction = calcPosFromPathfinding($field, $char);
	return unless $old_prediction && $new_prediction;

	$pending_character_moves_sample = {
		map => $field->baseName,
		old_char_pos => { %{$char->{pos}} },
		old_char_pos_to => { %{$char->{pos_to}} },
		old_prediction => { %{$old_prediction} },
		new_prediction => { %{$new_prediction} },
		server_move_start_tick => unpack('V', $args->{move_start_time}),
		walk_speed => $char->{walk_speed},
	};
}

sub on_route_set_move {
	my (undef, $args) = @_;
	return unless $char && $field;
	return unless $args->{actor} && UNIVERSAL::isa($args->{actor}, 'Actor::You');
	return unless $args->{current_calc_pos} && $args->{current_calc_pos_old};

	my $avg_route_response_time = $contexts{route_setMove}{response_time_count}
		? ($contexts{route_setMove}{response_time_total} / $contexts{route_setMove}{response_time_count})
		: 0;
	my $latency_adjusted_prediction = calcPosFromPathfinding($field, $char, $avg_route_response_time);
	return unless $latency_adjusted_prediction;

	$pending_route_sample = {
		map => $field->baseName,
		old_char_pos => $args->{current_pos} ? { %{$args->{current_pos}} } : undef,
		old_char_pos_to => $args->{current_pos_to} ? { %{$args->{current_pos_to}} } : undef,
		old_prediction => { %{$args->{current_calc_pos_old}} },
		new_prediction => { %{$args->{current_calc_pos}} },
		latency_adjusted_prediction => { %{$latency_adjusted_prediction} },
		avg_route_response_time_used => $avg_route_response_time,
		next_pos => $args->{next_pos} ? { %{$args->{next_pos}} } : undef,
		move_step_index => $args->{move_step_index},
		stepsleft => $args->{stepsleft},
		walk_speed => $args->{actor}{walk_speed},
		setmove_time => time,
	};
}

sub on_character_moves_post {
	my (undef, $args) = @_;
	return unless $char;
	my $now = time;
	my $actual_pos = $char->{pos} ? { %{$char->{pos}} } : undef;
	my $actual_pos_to = $char->{pos_to} ? { %{$char->{pos_to}} } : undef;
	return unless $actual_pos && $actual_pos_to;

	if ($pending_character_moves_sample) {
		score_sample($contexts{character_moves}, $pending_character_moves_sample, $actual_pos, $actual_pos_to);
		undef $pending_character_moves_sample;
	}

	if ($pending_route_sample) {
		$pending_route_sample->{response_time} = $now - $pending_route_sample->{setmove_time}
			if defined $pending_route_sample->{setmove_time};
		score_sample($contexts{route_setMove}, $pending_route_sample, $actual_pos, $actual_pos_to);
		undef $pending_route_sample;
	}

	emit_summary('interval', 1) if summary_due();
}

sub score_sample {
	my ($context, $sample, $actual_pos, $actual_pos_to) = @_;
	return unless $context && $sample && $actual_pos;

	$context->{total}++;

	my $old_block_dist = blockDistance($sample->{old_prediction}, $actual_pos);
	my $new_block_dist = blockDistance($sample->{new_prediction}, $actual_pos);
	my $old_adjusted_dist = adjustedBlockDistance($sample->{old_prediction}, $actual_pos);
	my $new_adjusted_dist = adjustedBlockDistance($sample->{new_prediction}, $actual_pos);
	my $old_exact = ($old_block_dist == 0) ? 1 : 0;
	my $new_exact = ($new_block_dist == 0) ? 1 : 0;

	my $latency_adjusted_exact = 0;
	my $latency_adjusted_block_dist;
	my $latency_adjusted_adjusted_dist;
	if ($context->{has_latency_adjusted} && $sample->{latency_adjusted_prediction}) {
		$latency_adjusted_block_dist = blockDistance($sample->{latency_adjusted_prediction}, $actual_pos);
		$latency_adjusted_adjusted_dist = adjustedBlockDistance($sample->{latency_adjusted_prediction}, $actual_pos);
		$latency_adjusted_exact = ($latency_adjusted_block_dist == 0) ? 1 : 0;
	}

	$context->{old_exact}++ if $old_exact;
	$context->{new_exact}++ if $new_exact;
	$context->{latency_adjusted_exact}++ if $latency_adjusted_exact;
	$context->{old_block_total_dist} += $old_block_dist;
	$context->{new_block_total_dist} += $new_block_dist;
	$context->{old_adjusted_total_dist} += $old_adjusted_dist;
	$context->{new_adjusted_total_dist} += $new_adjusted_dist;
	$context->{walk_speed_total} += ($sample->{walk_speed} || 0);
	if (defined $sample->{response_time}) {
		$context->{response_time_total} += $sample->{response_time};
		$context->{response_time_count}++;
	}

	if (defined $latency_adjusted_block_dist) {
		$context->{latency_adjusted_block_total_dist} += $latency_adjusted_block_dist;
		$context->{latency_adjusted_adjusted_total_dist} += $latency_adjusted_adjusted_dist;

		$context->{both_exact}++ if $old_exact && $new_exact && $latency_adjusted_exact;
		$context->{both_wrong}++ if !$old_exact && !$new_exact && !$latency_adjusted_exact;
		$context->{old_only_exact}++ if $old_exact && !$new_exact && !$latency_adjusted_exact;
		$context->{new_only_exact}++ if $new_exact && !$old_exact && !$latency_adjusted_exact;
		$context->{latency_adjusted_only_exact}++ if $latency_adjusted_exact && !$old_exact && !$new_exact;

		if ($old_block_dist < $new_block_dist && $old_block_dist < $latency_adjusted_block_dist) {
			$context->{old_block_closer}++;
		} elsif ($new_block_dist < $old_block_dist && $new_block_dist < $latency_adjusted_block_dist) {
			$context->{new_block_closer}++;
		} elsif ($latency_adjusted_block_dist < $old_block_dist && $latency_adjusted_block_dist < $new_block_dist) {
			$context->{latency_adjusted_block_closer}++;
		} else {
			$context->{block_tied_distance}++;
		}

		if ($old_adjusted_dist < $new_adjusted_dist && $old_adjusted_dist < $latency_adjusted_adjusted_dist) {
			$context->{old_adjusted_closer}++;
		} elsif ($new_adjusted_dist < $old_adjusted_dist && $new_adjusted_dist < $latency_adjusted_adjusted_dist) {
			$context->{new_adjusted_closer}++;
		} elsif ($latency_adjusted_adjusted_dist < $old_adjusted_dist && $latency_adjusted_adjusted_dist < $new_adjusted_dist) {
			$context->{latency_adjusted_adjusted_closer}++;
		} else {
			$context->{adjusted_tied_distance}++;
		}
	} else {
		$context->{both_exact}++ if $old_exact && $new_exact;
		$context->{both_wrong}++ if !$old_exact && !$new_exact;
		$context->{old_only_exact}++ if $old_exact && !$new_exact;
		$context->{new_only_exact}++ if $new_exact && !$old_exact;

		if ($old_block_dist < $new_block_dist) {
			$context->{old_block_closer}++;
		} elsif ($new_block_dist < $old_block_dist) {
			$context->{new_block_closer}++;
		} else {
			$context->{block_tied_distance}++;
		}

		if ($old_adjusted_dist < $new_adjusted_dist) {
			$context->{old_adjusted_closer}++;
		} elsif ($new_adjusted_dist < $old_adjusted_dist) {
			$context->{new_adjusted_closer}++;
		} else {
			$context->{adjusted_tied_distance}++;
		}
	}

	my $winner = build_winner($old_exact, $new_exact, $old_block_dist, $new_block_dist,
		$latency_adjusted_exact, $latency_adjusted_block_dist);

	$context->{last_event} = {
		sequence => $context->{total},
		map => $sample->{map},
		old_char_pos => $sample->{old_char_pos},
		old_char_pos_to => $sample->{old_char_pos_to},
		actual_pos => $actual_pos,
		actual_pos_to => $actual_pos_to,
		old_prediction => $sample->{old_prediction},
		new_prediction => $sample->{new_prediction},
		latency_adjusted_prediction => $sample->{latency_adjusted_prediction},
		old_block_dist => $old_block_dist,
		new_block_dist => $new_block_dist,
		latency_adjusted_block_dist => $latency_adjusted_block_dist,
		old_adjusted_dist => $old_adjusted_dist,
		new_adjusted_dist => $new_adjusted_dist,
		latency_adjusted_adjusted_dist => $latency_adjusted_adjusted_dist,
		server_move_start_tick => $sample->{server_move_start_tick},
		avg_route_response_time_used => $sample->{avg_route_response_time_used},
		next_pos => $sample->{next_pos},
		move_step_index => $sample->{move_step_index},
		stepsleft => $sample->{stepsleft},
		walk_speed => $sample->{walk_speed},
		response_time => $sample->{response_time},
		winner => $winner,
	};
}

sub build_winner {
	my ($old_exact, $new_exact, $old_block_dist, $new_block_dist, $latency_adjusted_exact, $latency_adjusted_block_dist) = @_;

	if (defined $latency_adjusted_block_dist) {
		my @exact_winners;
		push @exact_winners, 'old' if $old_exact;
		push @exact_winners, 'new' if $new_exact;
		push @exact_winners, 'latency-adjusted' if $latency_adjusted_exact;
		return 'all exact' if @exact_winners == 3;
		return join(' + ', @exact_winners) . ' exact' if @exact_winners == 2;
		return $exact_winners[0] . ' exact' if @exact_winners == 1;

		if ($old_block_dist < $new_block_dist && $old_block_dist < $latency_adjusted_block_dist) {
			return 'old closer';
		} elsif ($new_block_dist < $old_block_dist && $new_block_dist < $latency_adjusted_block_dist) {
			return 'new closer';
		} elsif ($latency_adjusted_block_dist < $old_block_dist && $latency_adjusted_block_dist < $new_block_dist) {
			return 'latency-adjusted closer';
		}
		return 'tie';
	}

	return 'both exact' if $old_exact && $new_exact;
	return 'old exact' if $old_exact;
	return 'new exact' if $new_exact;
	return 'old closer' if $old_block_dist < $new_block_dist;
	return 'new closer' if $new_block_dist < $old_block_dist;
	return 'tie';
}

sub has_data {
	return 1 if $contexts{character_moves}{total};
	return 1 if $contexts{route_setMove}{total};
	return 0;
}

sub summary_due {
	return 0 unless has_data();
	return 1 if $contexts{character_moves}{total} && $contexts{character_moves}{total} % SUMMARY_INTERVAL == 0;
	return 1 if $contexts{route_setMove}{total} && $contexts{route_setMove}{total} % SUMMARY_INTERVAL == 0;
	return 0;
}

sub emit_summary {
	my ($label, $write_file) = @_;
	return unless has_data();

	my @lines = build_summary_lines($label);
	message join("\n", @lines) . "\n", 'system';
	write_results_file(\@lines) if $write_file;
}

sub build_summary_lines {
	my ($label) = @_;
	my @lines;

	push @lines, sprintf("%s results", PLUGIN_NAME);
	push @lines, sprintf("Generated at: %s", scalar localtime());
	push @lines, sprintf("Summary type: %s", $label);
	push @lines, sprintf("Summary interval: %d", SUMMARY_INTERVAL);
	push @lines, sprintf("Results file updates only on interval summaries: %s", $log_file);
	push @lines, '';
	push @lines, build_context_lines($contexts{character_moves});
	push @lines, '';
	push @lines, '=' x 72;
	push @lines, ' ';
	push @lines, '=' x 72;
	push @lines, '';
	push @lines, build_context_lines($contexts{route_setMove});

	return @lines;
}

sub build_context_lines {
	my ($context) = @_;
	my @lines;

	push @lines, $context->{title};
	push @lines, '-' x length($context->{title});
	push @lines, sprintf("Events processed              %d", $context->{total});
	push @lines, sprintf("Avg walk speed               %s", avg($context->{walk_speed_total}, $context->{total}));
	push @lines, sprintf("Avg setMove->char_moves time %s", avg_optional($context->{response_time_total}, $context->{response_time_count}));
	return @lines unless $context->{total};

	push @lines, '';
	push @lines, 'Exact Match Summary';
	push @lines, '-------------------';
	push @lines, sprintf("%-30s %s", 'Old exact', pct($context->{old_exact}, $context->{total}));
	push @lines, sprintf("%-30s %s", 'New exact', pct($context->{new_exact}, $context->{total}));
	if ($context->{has_latency_adjusted}) {
		push @lines, sprintf("%-30s %s", 'Latency-adjusted exact', pct($context->{latency_adjusted_exact}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'All exact', pct($context->{both_exact}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'All wrong', pct($context->{both_wrong}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'Old exact only', pct($context->{old_only_exact}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'New exact only', pct($context->{new_only_exact}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'Latency-adjusted only', pct($context->{latency_adjusted_only_exact}, $context->{total}));
	} else {
		push @lines, sprintf("%-30s %s", 'Both exact', pct($context->{both_exact}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'Both wrong', pct($context->{both_wrong}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'Old exact only', pct($context->{old_only_exact}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'New exact only', pct($context->{new_only_exact}, $context->{total}));
	}

	push @lines, '';
	push @lines, 'Block Distance Summary';
	push @lines, '----------------------';
	push @lines, sprintf("%-30s %s", $context->{has_latency_adjusted} ? 'Old unique best' : 'Old closer', pct($context->{old_block_closer}, $context->{total}));
	push @lines, sprintf("%-30s %s", $context->{has_latency_adjusted} ? 'New unique best' : 'New closer', pct($context->{new_block_closer}, $context->{total}));
	if ($context->{has_latency_adjusted}) {
		push @lines, sprintf("%-30s %s", 'Latency-adjusted best', pct($context->{latency_adjusted_block_closer}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'Shared best', pct($context->{block_tied_distance}, $context->{total}));
	} else {
		push @lines, sprintf("%-30s %s", 'Equal distance', pct($context->{block_tied_distance}, $context->{total}));
	}
	push @lines, sprintf("%-30s %s", 'Avg old block distance', avg($context->{old_block_total_dist}, $context->{total}));
	push @lines, sprintf("%-30s %s", 'Avg new block distance', avg($context->{new_block_total_dist}, $context->{total}));
	push @lines, sprintf("%-30s %s", 'Avg latency-adjusted dist', avg($context->{latency_adjusted_block_total_dist}, $context->{total})) if $context->{has_latency_adjusted};

	push @lines, '';
	push @lines, 'Adjusted Block Distance Summary';
	push @lines, '-------------------------------';
	push @lines, sprintf("%-30s %s", $context->{has_latency_adjusted} ? 'Old unique best' : 'Old closer', pct($context->{old_adjusted_closer}, $context->{total}));
	push @lines, sprintf("%-30s %s", $context->{has_latency_adjusted} ? 'New unique best' : 'New closer', pct($context->{new_adjusted_closer}, $context->{total}));
	if ($context->{has_latency_adjusted}) {
		push @lines, sprintf("%-30s %s", 'Latency-adjusted best', pct($context->{latency_adjusted_adjusted_closer}, $context->{total}));
		push @lines, sprintf("%-30s %s", 'Shared best', pct($context->{adjusted_tied_distance}, $context->{total}));
	} else {
		push @lines, sprintf("%-30s %s", 'Equal distance', pct($context->{adjusted_tied_distance}, $context->{total}));
	}
	push @lines, sprintf("%-30s %s", 'Avg old adjusted distance', avg($context->{old_adjusted_total_dist}, $context->{total}));
	push @lines, sprintf("%-30s %s", 'Avg new adjusted distance', avg($context->{new_adjusted_total_dist}, $context->{total}));
	push @lines, sprintf("%-30s %s", 'Avg latency-adjusted dist', avg($context->{latency_adjusted_adjusted_total_dist}, $context->{total})) if $context->{has_latency_adjusted};

	my $last = $context->{last_event};
	if ($last && $last->{sequence}) {
		push @lines, '';
		push @lines, 'Last Compared Event';
		push @lines, '-------------------';
		push @lines, sprintf("%-30s #%d", 'Event number', $last->{sequence});
		push @lines, sprintf("%-30s %s", 'Map', $last->{map});
		push @lines, sprintf("%-30s %s", 'Previous char pos', pos_str($last->{old_char_pos}));
		push @lines, sprintf("%-30s %s", 'Previous char pos_to', pos_str($last->{old_char_pos_to}));
		push @lines, sprintf("%-30s %s", 'Actual new char pos', pos_str($last->{actual_pos}));
		push @lines, sprintf("%-30s %s", 'Actual new pos_to', pos_str($last->{actual_pos_to}));
		push @lines, sprintf("%-30s %s", 'Old prediction', pos_str($last->{old_prediction}) . " | block=$last->{old_block_dist} | adjusted=" . fmt_num($last->{old_adjusted_dist}));
		push @lines, sprintf("%-30s %s", 'New prediction', pos_str($last->{new_prediction}) . " | block=$last->{new_block_dist} | adjusted=" . fmt_num($last->{new_adjusted_dist}));
		if ($context->{has_latency_adjusted} && $last->{latency_adjusted_prediction}) {
			push @lines, sprintf("%-30s %s", 'Latency-adjusted pred', pos_str($last->{latency_adjusted_prediction}) . " | block=$last->{latency_adjusted_block_dist} | adjusted=" . fmt_num($last->{latency_adjusted_adjusted_dist}));
			push @lines, sprintf("%-30s %s", 'Latency offset used', fmt_num($last->{avg_route_response_time_used}));
		}
		push @lines, sprintf("%-30s %s", 'Server move tick', defined $last->{server_move_start_tick} ? $last->{server_move_start_tick} : '-');
		push @lines, sprintf("%-30s %s", 'Route next_pos', pos_str($last->{next_pos})) if $last->{next_pos};
		push @lines, sprintf("%-30s %s", 'Route move_step_index', defined $last->{move_step_index} ? $last->{move_step_index} : '-') if exists $last->{move_step_index};
		push @lines, sprintf("%-30s %s", 'Route stepsleft', defined $last->{stepsleft} ? $last->{stepsleft} : '-') if exists $last->{stepsleft};
		push @lines, sprintf("%-30s %s", 'Walk speed', fmt_num($last->{walk_speed}));
		push @lines, sprintf("%-30s %s", 'SetMove->char_moves time', fmt_num($last->{response_time}));
		push @lines, sprintf("%-30s %s", 'Winner', $last->{winner});
	}

	return @lines;
}

sub write_results_file {
	my ($lines_ref) = @_;
	if (open(my $fh, '>:utf8', $log_file)) {
		print $fh join("\n", @{$lines_ref}) . "\n";
		close $fh;
	} else {
		warning "[" . PLUGIN_NAME . "] failed to write log file $log_file: $!\n";
	}
}

sub pos_str {
	my ($pos) = @_;
	return '(?, ?)' unless $pos && defined $pos->{x} && defined $pos->{y};
	return '(' . $pos->{x} . ', ' . $pos->{y} . ')';
}

sub pct {
	my ($value, $total) = @_;
	return '0 (0.00%)' unless $total;
	return sprintf('%d (%.2f%%)', $value, ($value * 100 / $total));
}

sub avg {
	my ($value, $total) = @_;
	return '0.000' unless $total;
	return sprintf('%.3f', $value / $total);
}

sub avg_optional {
	my ($value, $total) = @_;
	return '-' unless $total;
	return sprintf('%.3f', $value / $total);
}

sub fmt_num {
	my ($value) = @_;
	return '-' unless defined $value;
	return sprintf('%.3f', $value);
}

1;
