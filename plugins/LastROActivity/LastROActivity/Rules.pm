package LastROActivity::Rules;

use strict;
use warnings;
use utf8;

my %NUMERIC_FIELDS = map { $_ => 1 } qw(
	enabled
	lead_seconds
	entry_x
	entry_y
	duration_seconds
	timeout_seconds
);

my %ENTRY_TYPES = map { $_ => 1 } qw(
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
			$current->{validation_errors} = [@$rule_errors];
			if (@$rule_errors) {
				$current->{enabled} = 0;
				push @errors, map { "$current_id: $_" } @$rule_errors;
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

		if (!defined $current || $discard_current) {
			push @errors, "line $line_number: setting outside an event section"
				if defined $current_id && !$discard_current;
			next;
		}

		my ($key, $value) = split /=/, $line, 2;
		if (!defined $value) {
			push @errors, "$current_id: malformed setting on line $line_number";
			next;
		}

		$key = _trim($key);
		$value = _trim($value);
		if ($key eq '') {
			push @errors, "$current_id: empty setting name on line $line_number";
			next;
		}

		if ($key =~ /^phase\.(\d+)\.([A-Za-z0-9_]+)$/) {
			my ($index, $field) = ($1, $2);
			$current->{_phase_data}{$index}{$field} = _normalize_value($field, $value);
		} elsif ($key eq 'search_targets') {
			$current->{search_targets} = [
				grep { length $_ } map { _trim($_) } split /,/, $value, -1
			];
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
	}

	if (_has_value($rule->{entry_type}) && !$ENTRY_TYPES{$rule->{entry_type}}) {
		push @errors, "invalid entry_type $rule->{entry_type}";
	}

	if (_has_value($rule->{duration_seconds})) {
		if ($rule->{duration_seconds} !~ /^[-+]?\d+$/) {
			push @errors, 'duration_seconds must be an integer';
		} elsif ($rule->{duration_seconds} <= 0) {
			push @errors, 'duration_seconds must be positive';
		}
	}

	if (_has_value($rule->{lead_seconds})) {
		if ($rule->{lead_seconds} !~ /^[-+]?\d+$/) {
			push @errors, 'lead_seconds must be an integer';
		} elsif ($rule->{lead_seconds} < 0) {
			push @errors, 'lead_seconds must be non-negative';
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
		entry_npc => undef,
		duration_seconds => undef,
		entry_macro => undef,
		finish_macro => undef,
		return_policy => undef,
		search_targets => [],
		phases => [],
		validation_errors => [],
		_phase_data => {},
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
	return 0 if $key eq 'enabled';
	return int($value) if $NUMERIC_FIELDS{$key} && $value =~ /^[-+]?\d+$/;
	return $value;
}

sub _has_value {
	my ($value) = @_;
	return defined $value && $value ne '';
}

sub _trim {
	my ($value) = @_;
	$value = '' if !defined $value;
	$value =~ s/^\s+//;
	$value =~ s/\s+\z//;
	return $value;
}

1;
