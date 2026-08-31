package LastROActivity::Rules;

use strict;
use warnings;
use utf8;

my %NUMERIC_FIELDS = map { $_ => 1 } qw(
	enabled
	lead_seconds
	entry_x
	entry_y
	entry_item_id
	duration_seconds
	timeout_seconds
	max_rounds
	resurrection_wait_seconds
	leave_x
	leave_y
);

my %MAP_SOURCES = map { $_ => 1 } qw(static dynamic announcement);

my %ALLOWED_FIELDS = map { $_ => 1 } qw(
	enabled
	announce_regex
	start_regex
	finish_regex
	lead_seconds
	map_source
	entry_type
	entry_map
	entry_x
	entry_y
	entry_item_id
	entry_npc
	entry_npc_name
	entry_npc_trusted
	entry_npc_evidence
	entry_dialog_mode
	round_start_regex
	round_id_regex
	round_success_regex
	max_rounds
	resurrection_wait_seconds
	leave_npc
	leave_npc_trusted
	leave_npc_evidence
	leave_x
	leave_y
	duration_seconds
	timeout_seconds
	entry_macro
	finish_macro
	return_policy
	search_targets
	priority
);

my %ENTRY_TYPES = map { $_ => 1 } qw(
	tt
	airship
	privateairship
	npc
	macro
);

sub parse_text {
	my ($text) = @_;
	$text = '' if !defined $text;

	my %rules;
	my @errors;
	my ($current, $current_id, $discard_current);

	my $finish_current = sub {
		return if !defined $current;

		_build_phases($current);
		if (!$discard_current) {
			my $rule_errors = validate_rule($current);
			my $parse_errors = delete $current->{_parse_errors} || [];
			my @all_errors = (@$parse_errors, @$rule_errors);
			$current->{validation_errors} = \@all_errors;
			if (@all_errors) {
				$current->{enabled} = 0;
				push @errors, map { "$current_id: $_" } @all_errors;
			}
			$rules{$current_id} = $current;
		}

		$current = undef;
		$current_id = undef;
		$discard_current = 0;
	};

	my $line_number = 0;
	for my $line (split /\n/, $text, -1) {
		$line_number++;
		$line =~ s/\r\z//;
		$line =~ s/^\x{FEFF}// if $line_number == 1;

		next if $line =~ /^\s*$/;
		next if $line =~ /^\s*[#;]/;

		if ($line =~ /^\s*\[([^\]]+)\]\s*$/) {
			$finish_current->();

			$current_id = _trim($1);
			if ($current_id eq '') {
				push @errors, "line $line_number: empty event_id";
				$current = undef;
				$current_id = undef;
				$discard_current = 1;
				next;
			}

			if (exists $rules{$current_id}) {
				my $message = "duplicate event_id $current_id";
				push @{$rules{$current_id}{validation_errors}}, $message;
				$rules{$current_id}{enabled} = 0;
				push @errors, "$current_id: $message";
				$discard_current = 1;
			} else {
				$discard_current = 0;
			}
			$current = _new_rule($current_id);
			next;
		}

		if ($discard_current) {
			next;
		}
		if (!defined $current) {
			push @errors, "line $line_number: setting outside an event section";
			next;
		}

		my ($key, $value) = split /=/, $line, 2;
		if (!defined $value) {
			push @{$current->{_parse_errors}}, "malformed setting on line $line_number";
			next;
		}

		$key = _trim($key);
		$value = _trim($value);
		if ($key eq '') {
			push @{$current->{_parse_errors}}, "empty setting name on line $line_number";
			next;
		}

		if (_is_reserved_key($key)) {
			push @{$current->{_parse_errors}}, "reserved key $key";
			next;
		}

		if ($key =~ /^phase\.(\d+)\.([A-Za-z0-9_]+)$/) {
			my ($index, $field) = ($1, $2);
			$current->{_phase_data}{$index}{$field} = _normalize_value($field, $value);
		} elsif ($key eq 'search_targets') {
			$current->{search_targets} = [
				grep { length $_ } map { _trim($_) } split /,/, $value, -1
			];
		} elsif (!$ALLOWED_FIELDS{$key}) {
			push @{$current->{_parse_errors}}, "unsupported key $key";
		} else {
			$current->{$key} = _normalize_value($key, $value);
		}
	}

	$finish_current->();
	return (\%rules, \@errors);
}

sub load_file {
	my ($path) = @_;
	if (!defined $path || $path eq '') {
		return ({}, ['rules file path is required']);
	}

	open my $fh, '<:encoding(UTF-8)', $path
		or return ({}, ["unable to read $path: $!"]);
	local $/;
	my $text = <$fh>;
	close $fh;
	return parse_text($text);
}

sub validate_rule {
	my ($rule) = @_;
	$rule ||= {};
	my @errors;

	if ($rule->{enabled} && !_has_value($rule->{announce_regex})) {
		push @errors, 'announce_regex required when enabled';
	} elsif ($rule->{enabled} && !_valid_pattern($rule->{announce_regex})) {
		push @errors, 'announce_regex is invalid';
	}
	if ($rule->{enabled} && !_has_value($rule->{start_regex})) {
		push @errors, 'start_regex required when enabled';
	} elsif ($rule->{enabled} && !_valid_pattern($rule->{start_regex})) {
		push @errors, 'start_regex is invalid';
	}
	if (defined $rule->{enabled} && $rule->{enabled} !~ /^(?:0|1)$/) {
		push @errors, 'enabled must be 0 or 1';
	}

	# A return policy is an assertion about the only supported cleanup route.
	# Missing policy remains a legacy/default value, but an explicit override must
	# be the canonical tt transfer to prontera.  The old private-airship spelling
	# remains a compatibility alias for existing rule files.
	if ($rule->{enabled} && defined $rule->{return_policy}
		&& _trim($rule->{return_policy}) !~ /^(?:tt|privateairship):prontera$/i) {
		push @errors, 'return_policy must be tt:prontera';
	}

	if (_has_value($rule->{map_source})
		&& !$MAP_SOURCES{lc(_trim($rule->{map_source}))}) {
		push @errors, 'map_source must be static, dynamic, or announcement';
	}

	if (_has_value($rule->{entry_type}) && !$ENTRY_TYPES{$rule->{entry_type}}) {
		push @errors, "invalid entry_type $rule->{entry_type}";
	}

	my $dialog_mode = _has_value($rule->{entry_dialog_mode})
		? lc(_trim($rule->{entry_dialog_mode})) : '';
	if ($dialog_mode ne '' && $dialog_mode ne 'repeat_first_until_finish') {
		push @errors, 'entry_dialog_mode must be repeat_first_until_finish';
	}
	if ($rule->{enabled} && $dialog_mode eq 'repeat_first_until_finish') {
		unless (_has_value($rule->{finish_regex})) {
			push @errors, 'finish_regex is required for repeating NPC dialog';
		} elsif (!_valid_pattern($rule->{finish_regex})) {
			push @errors, 'finish_regex is invalid';
		}
	}

	# An explicitly typed entry is an assertion that the corresponding
	# server-backed route has been confirmed.  Keep this parser check limited to
	# presence/shape evidence; shared-control resolution belongs to the runtime
	# validator where Globals is available.  Rules without an entry_type remain
	# compatible with the scheduler-only fixtures and use the legacy defaults.
	if ($rule->{enabled} && _has_value($rule->{entry_type})
		&& $ENTRY_TYPES{$rule->{entry_type}}) {
		my $entry_type = lc(_trim($rule->{entry_type}));
		if ($entry_type eq 'tt' || $entry_type eq 'airship' || $entry_type eq 'privateairship') {
			unless (_has_search_targets($rule)) {
				push @errors, 'search_targets evidence is required for shared search mode';
			}
		} elsif ($entry_type eq 'npc') {
			if ($dialog_mode eq 'repeat_first_until_finish') {
				unless (defined $rule->{entry_npc_name}
					&& _trim($rule->{entry_npc_name}) ne '') {
					push @errors, 'entry_npc_name is required for repeating NPC dialog';
				}
				for my $field (qw(entry_x entry_y)) {
					unless (defined $rule->{$field} && "$rule->{$field}" =~ /^\d+$/) {
						push @errors, "$field is required for NPC entry";
					}
				}
			} else {
				unless (defined $rule->{entry_npc_trusted}
					&& "$rule->{entry_npc_trusted}" =~ /^\s*1\s*$/) {
					push @errors, 'entry_npc_trusted=1 is required for NPC entry';
				}
				unless (defined $rule->{entry_npc_evidence}
					&& _trim($rule->{entry_npc_evidence}) ne '') {
					push @errors, 'entry_npc_evidence is required for NPC entry';
				}
			}
		}
	}

	if (defined $rule->{duration_seconds}) {
		if ($rule->{duration_seconds} !~ /^[-+]?\d+$/) {
			push @errors, 'duration_seconds must be an integer';
		} elsif ($rule->{duration_seconds} <= 0) {
			push @errors, 'duration_seconds must be positive';
		}
	}

	if (defined $rule->{lead_seconds}) {
		if ($rule->{lead_seconds} !~ /^[-+]?\d+$/) {
			push @errors, 'lead_seconds must be an integer';
		} elsif ($rule->{lead_seconds} < 0) {
			push @errors, 'lead_seconds must be non-negative';
		}
	}

	if (defined $rule->{timeout_seconds}) {
		if ($rule->{timeout_seconds} !~ /^\d+(?:\.\d+)?$/) {
			push @errors, 'timeout_seconds must be a positive number';
		} elsif ($rule->{timeout_seconds} <= 0) {
			push @errors, 'timeout_seconds must be positive';
		}
	}

	if (defined $rule->{max_rounds}) {
		if ($rule->{max_rounds} !~ /^\d+$/) {
			push @errors, 'max_rounds must be an integer';
		} elsif ($rule->{max_rounds} <= 0) {
			push @errors, 'max_rounds must be positive';
		}
	}

	if (defined $rule->{resurrection_wait_seconds}) {
		if ($rule->{resurrection_wait_seconds} !~ /^\d+$/) {
			push @errors, 'resurrection_wait_seconds must be an integer';
		} elsif ($rule->{resurrection_wait_seconds} <= 0) {
			push @errors, 'resurrection_wait_seconds must be positive';
		}
	}

	for my $field (qw(round_start_regex round_success_regex)) {
		if (defined $rule->{$field} && !_valid_pattern($rule->{$field})) {
			push @errors, "$field is invalid";
		}
	}
	if (defined $rule->{round_id_regex}
		&& (_has_value($rule->{round_id_regex}) || ref($rule->{round_id_regex}))
		&& !_valid_pattern($rule->{round_id_regex})) {
		push @errors, 'round_id_regex is invalid';
	}
	if ($dialog_mode ne 'repeat_first_until_finish'
		&& defined $rule->{finish_regex}
		&& (_has_value($rule->{finish_regex}) || ref($rule->{finish_regex}))
		&& !_valid_pattern($rule->{finish_regex})) {
		push @errors, 'finish_regex is invalid';
	}

	# Phase conditions are runtime message patterns too. Validate every supported
	# alias here so malformed direct or parsed rules fail before scheduling.
	if (defined $rule->{phases}) {
		if (ref($rule->{phases}) ne 'ARRAY') {
			push @errors, 'phases must be an array';
		} else {
			my @phase_pattern_fields = qw(
				finish_regex condition_regex phase_regex message_regex regex
				complete_regex condition finish
			);
			for my $index (0 .. $#{$rule->{phases}}) {
				my $phase = $rule->{phases}[$index];
				next unless ref($phase) eq 'HASH';
				for my $field (@phase_pattern_fields) {
					next unless exists $phase->{$field} && defined $phase->{$field};
					next if !ref($phase->{$field}) && _trim($phase->{$field}) eq '';
				unless (_valid_pattern($phase->{$field})) {
					push @errors, 'phase ' . ($index + 1) . " $field is invalid";
				}
			}
			}
		}
	}
	if ($rule->{enabled}
		&& ((_has_value($rule->{round_start_regex}) && !_has_value($rule->{round_success_regex}))
			|| (_has_value($rule->{round_success_regex}) && !_has_value($rule->{round_start_regex})))) {
		push @errors, 'round_start_regex and round_success_regex must be configured together';
	}

	if (defined $rule->{leave_npc_trusted}
		&& $rule->{leave_npc_trusted} !~ /^(?:0|1)$/) {
		push @errors, 'leave_npc_trusted must be 0 or 1';
	}

	my $has_leave = 0;
	for my $field (qw(leave_npc leave_npc_trusted leave_npc_evidence leave_x leave_y)) {
		$has_leave = 1 if defined $rule->{$field} && _has_value($rule->{$field});
	}
	if ($has_leave) {
		push @errors, 'leave_npc is required when leave metadata is configured'
			unless _has_value($rule->{leave_npc});
		push @errors, 'leave_npc_trusted=1 is required for leave NPC'
			unless defined $rule->{leave_npc_trusted}
				&& "$rule->{leave_npc_trusted}" =~ /^\s*1\s*$/;
		push @errors, 'leave_npc_evidence is required for leave NPC'
			unless _has_value($rule->{leave_npc_evidence});
		for my $field (qw(leave_x leave_y)) {
			push @errors, "$field is required for leave NPC"
				unless defined $rule->{$field} && $rule->{$field} =~ /^\d+$/;
		}
	}

	if (defined $rule->{entry_item_id}) {
		if ($rule->{entry_item_id} !~ /^\d+$/) {
			push @errors, 'entry_item_id must be an integer';
		} elsif ($rule->{entry_item_id} <= 0) {
			push @errors, 'entry_item_id must be positive';
		}
	}

	return \@errors;
}

sub _new_rule {
	my ($event_id) = @_;
	return {
		event_id => $event_id,
		enabled => 0,
		announce_regex => undef,
		start_regex => undef,
		finish_regex => undef,
		lead_seconds => 10,
		map_source => undef,
		entry_type => undef,
		entry_map => undef,
		entry_x => undef,
		entry_y => undef,
		entry_item_id => undef,
		entry_npc => undef,
		entry_npc_name => undef,
		entry_npc_trusted => undef,
		entry_npc_evidence => undef,
		entry_dialog_mode => undef,
		round_start_regex => undef,
		round_id_regex => undef,
		round_success_regex => undef,
		max_rounds => 3,
		resurrection_wait_seconds => 30,
		leave_npc => undef,
		leave_npc_trusted => undef,
		leave_npc_evidence => undef,
		leave_x => undef,
		leave_y => undef,
		duration_seconds => undef,
		timeout_seconds => undef,
		entry_macro => undef,
		finish_macro => undef,
		return_policy => undef,
		search_targets => [],
		phases => [],
		validation_errors => [],
		_phase_data => {},
		_parse_errors => [],
	};
}

sub _build_phases {
	my ($rule) = @_;
	my $phase_data = delete $rule->{_phase_data} || {};
	$rule->{phases} = [
		map { $phase_data->{$_} }
		sort { $a <=> $b } keys %$phase_data
	];
}

sub _normalize_value {
	my ($key, $value) = @_;
	return int($value) if $key eq 'enabled' && $value =~ /^[-+]?\d+$/;
	return int($value) if $NUMERIC_FIELDS{$key} && $value =~ /^[-+]?\d+$/;
	return $value;
}

sub _is_reserved_key {
	my ($key) = @_;
	return 1 if $key =~ /^_/;
	return 1 if $key eq 'event_id' || $key eq 'phases' || $key eq 'validation_errors';
	return 0;
}

sub _has_value {
	my ($value) = @_;
	return defined $value && $value ne '';
}

sub _has_search_targets {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	my $targets = $rule->{search_targets};
	if (ref($targets) eq 'ARRAY') {
		return scalar grep { defined $_ && _trim($_) ne '' } @$targets;
	}
	return defined $targets && _trim($targets) ne '';
}

sub _valid_pattern {
	my ($pattern) = @_;
	return 0 unless _has_value($pattern);
	return 1 if ref($pattern) eq 'Regexp' || ref($pattern) eq 'CODE';
	return 0 if ref($pattern);
	my $text = _trim($pattern);
	return 0 if $text eq '' || $text =~ /[\r\n]/;
	my $compiled;
	my $ok = eval {
		$compiled = qr/$text/;
		1;
	};
	return $ok ? 1 : 0;
}

sub _trim {
	my ($value) = @_;
	$value = '' if !defined $value;
	$value =~ s/^\s+//;
	$value =~ s/\s+\z//;
	return $value;
}

1;
