package ProductionRulesTest;

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use Test::More;

use LastROActivity::Rules;

my @EVENT_IDS = qw(
	city_monster_party
	dungeon_monster_party
	dojo_challenge
	pool_challenge
	lottery
	sky_chest
);

sub _trim {
	my ($value) = @_;
	$value = '' unless defined $value;
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	return $value;
}

sub _has_value {
	my ($value) = @_;
	return defined $value && !ref($value) && _trim($value) ne '';
}

sub _truthy {
	my ($value) = @_;
	return defined $value && "$value" =~ /^\s*1\s*$/;
}

sub _positive_number {
	my ($value) = @_;
	return 0 unless defined $value && !ref($value);
	return 0 unless "$value" =~ /^\s*\d+(?:\.\d+)?\s*$/;
	return $value > 0 ? 1 : 0;
}

sub _valid_pattern {
	my ($pattern) = @_;
	return 0 unless defined $pattern;
	return 1 if ref($pattern) eq 'Regexp' || ref($pattern) eq 'CODE';
	return 0 if ref($pattern) || _trim($pattern) eq '';
	my $ok = eval {
		my $compiled = qr/$pattern/;
		defined $compiled;
	};
	return $ok ? 1 : 0;
}

sub _phase_finish_pattern {
	my ($phase) = @_;
	return undef unless ref($phase) eq 'HASH';
	for my $key (qw(finish_regex condition_regex phase_regex message_regex regex complete_regex condition finish)) {
		return $phase->{$key}
			if defined $phase->{$key} && _trim($phase->{$key}) ne '';
	}
	return undef;
}

sub _safe_map_name {
	my ($map) = @_;
	return 0 unless _has_value($map);
	$map = _trim($map);
	$map =~ s/\.(?:rsw|gat)$//i;
	return 0 if length($map) > 16;
	return 0 if $map =~ /[\s;|&<>"'`\r\n]/;
	return 1;
}

sub _safe_macro_name {
	my ($name) = @_;
	return 0 unless _has_value($name);
	return _trim($name) =~ /^[A-Za-z0-9_.:-]+$/ ? 1 : 0;
}

sub _safe_npc_sequence {
	my ($npc) = @_;
	return 0 unless _has_value($npc);
	$npc = _trim($npc);
	return 0 if $npc =~ /[\r\n;|&<>"'`]/;
	return 1 if $npc =~ /^[^#]+#[A-Za-z0-9_,.:-]+$/;
	return 1 if $npc =~ /^[A-Za-z0-9_,.:-]+$/;
	return 0;
}

sub _load_shared_search_rows {
	my ($path) = @_;
	open my $fh, '<:encoding(UTF-8)', $path or return (undef, "unable to read $path: $!");
	my %rows;
	while (my $line = <$fh>) {
		$line =~ s/\r?\n$//;
		next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
		$line =~ s/\s*#.*$//;
		$line = _trim($line);
		next if $line eq '';

		my ($key, $args);
		if ($line =~ /\t/) {
			($key, $args) = split /\t+/, $line, 2;
		} else {
			($key, $args) = $line =~ /^(.+?)\s+(-?\d+(?:\s+.*)?)$/;
		}
		next unless defined $key && defined $args;
		$key = lc(_trim($key));
		my @fields = grep { $_ ne '' } split /\s+/, _trim($args);
		next unless @fields >= 3;
		$rows{$key} = \@fields;
	}
	close $fh;
	return (\%rows, undef);
}

sub _search_targets {
	my ($rule) = @_;
	return () unless ref($rule) eq 'HASH';
	my $targets = $rule->{search_targets};
	if (ref($targets) eq 'ARRAY') {
		return grep { defined $_ && _trim($_) ne '' } @$targets;
	}
	return (_trim($targets)) if defined $targets && _trim($targets) ne '';
	return ();
}

sub _uses_search_mode {
	my ($entry_type, $rule) = @_;
	return 0 if $entry_type eq 'npc' || $entry_type eq 'macro';
	return 0 if ref($rule) eq 'HASH' && exists $rule->{search_mode}
		&& !$rule->{search_mode};
	return 1;
}

sub _production_errors {
	my ($rule, $shared_rows) = @_;
	return () unless ref($rule) eq 'HASH' && _truthy($rule->{enabled});
	my @errors;
	if (ref($rule->{validation_errors}) eq 'ARRAY' && @{$rule->{validation_errors}}) {
		push @errors, 'validation_errors are present on an enabled rule';
	}

	# The announcement is the start evidence. A countdown is optional, but the
	# rule must still identify the server line that is allowed to trigger it.
	push @errors, 'announce_regex (start evidence) is required or invalid'
		unless _valid_pattern($rule->{announce_regex});
	if (defined $rule->{start_regex} && _trim($rule->{start_regex}) ne ''
		&& !_valid_pattern($rule->{start_regex})) {
		push @errors, 'start_regex is invalid';
	}

	my $finish_ok = _valid_pattern($rule->{finish_regex});
	if (ref($rule->{phases}) eq 'ARRAY' && @{$rule->{phases}}) {
		my $phases_ok = 1;
		for my $phase (@{$rule->{phases}}) {
			my $pattern = _phase_finish_pattern($phase);
			$phases_ok = 0 unless _valid_pattern($pattern);
		}
		$finish_ok = 1 if $phases_ok;
	}
	$finish_ok = 1 if _positive_number($rule->{duration_seconds});
	push @errors, 'finish evidence or a positive duration is required'
		unless $finish_ok;

	my $source = _trim($rule->{map_source});
	my $entry_map = _trim($rule->{entry_map});
	if ($source eq '' && $entry_map eq '') {
		push @errors, 'map_source or entry_map is required';
	} elsif (lc($source) eq 'dynamic') {
		# Dynamic maps come from the matched announcement and do not have a
		# statically known entry_map in the production fixture.
	} elsif (!_safe_map_name($entry_map)) {
		push @errors, 'a safe entry_map is required for a fixed map source';
	}

	my $return_policy = _trim($rule->{return_policy});
	push @errors, 'return_policy must be privateairship:prontera'
		unless $return_policy =~ /^privateairship\s*:\s*prontera$/i;
	for my $macro_field (qw(entry_macro finish_macro)) {
		if (defined $rule->{$macro_field} && _trim($rule->{$macro_field}) ne ''
			&& !_safe_macro_name($rule->{$macro_field})) {
			push @errors, "$macro_field is invalid";
		}
	}

	my $entry_type = lc(_trim($rule->{entry_type}));
	$entry_type = 'privateairship' if $entry_type eq '';
	if ($entry_type eq 'airship' || $entry_type eq 'privateairship') {
		push @errors, 'entry_item_id is required for airship entry'
			unless defined $rule->{entry_item_id}
			&& "$rule->{entry_item_id}" =~ /^\d+$/
			&& $rule->{entry_item_id} > 0;
	} elsif ($entry_type eq 'npc') {
		push @errors, 'entry_map is required for NPC entry' unless _safe_map_name($entry_map);
		push @errors, 'entry_x is required for NPC entry'
			unless defined $rule->{entry_x} && "$rule->{entry_x}" =~ /^\d+$/;
		push @errors, 'entry_y is required for NPC entry'
			unless defined $rule->{entry_y} && "$rule->{entry_y}" =~ /^\d+$/;
		push @errors, 'entry_npc is required for NPC entry'
			unless _safe_npc_sequence($rule->{entry_npc});
		push @errors, 'entry_npc_trusted=1 is required for NPC entry'
			unless _truthy($rule->{entry_npc_trusted});
		push @errors, 'entry_npc_evidence is required for NPC entry'
			unless _has_value($rule->{entry_npc_evidence});
	} elsif ($entry_type eq 'macro') {
		push @errors, 'entry_macro is required for macro entry'
			unless _safe_macro_name($rule->{entry_macro});
	} else {
		push @errors, "entry_type '$entry_type' is not usable";
	}

	if (_uses_search_mode($entry_type, $rule)) {
		my @targets = _search_targets($rule);
		if (!@targets) {
			push @errors, 'search_targets evidence is required for shared search mode';
		} elsif (!defined $shared_rows) {
			push @errors, 'shared mon_control.txt is unavailable';
		} else {
			my %seen;
			for my $target (@targets) {
				my $key = lc(_trim($target));
				next if $seen{$key}++;
				my $fields = $shared_rows->{$key};
				if (ref($fields) ne 'ARRAY' || !defined $fields->[2] || "$fields->[2]" ne '1') {
					push @errors, "search target '$target' is not present in shared mon_control with search=1";
				}
			}
		}
	}

	return @errors;
}

sub start {
	my $rules_file = File::Spec->catfile($RealBin, '..', 'control', 'lastro_activity.txt');
	my $repo_root = File::Spec->catdir($RealBin, '..', '..', '..');
	my $mon_control_file = File::Spec->catfile($repo_root, 'control', 'mon_control.txt');
	my ($shared_rows, $shared_error) = _load_shared_search_rows($mon_control_file);

	subtest 'production fixture contains only safe disabled rules' => sub {
		ok(-f $rules_file, 'bundled production rules file exists');
		my ($rules, $errors) = LastROActivity::Rules::load_file($rules_file);
		ok(ref($rules) eq 'HASH', 'production rules load as a hash');
		is_deeply([sort keys %{$rules || {}}], [sort @EVENT_IDS],
			'fixture contains exactly the six first-phase event IDs');
		is_deeply($errors, [], 'production fixture has no parser errors');
		ok(!defined $shared_error, 'shared mon_control.txt is readable')
			or diag($shared_error);

		for my $id (@EVENT_IDS) {
			ok(exists $rules->{$id}, "$id rule exists");
			next unless exists $rules->{$id};
			ok(!$rules->{$id}{enabled}, "$id remains disabled until evidence is complete");
			my @violations = _production_errors($rules->{$id}, $shared_rows);
			ok(!@violations, "$id has no enabled-rule contract violations")
				or diag(join('; ', @violations));
		}
		done_testing();
	};

	subtest 'enabled rules fail closed for missing production evidence' => sub {
		my $complete = {
			enabled => 1,
			announce_regex => 'event ready',
			finish_regex => 'event done',
			map_source => 'fixed',
			entry_map => 'prontera',
			entry_type => 'macro',
			entry_macro => 'enter_event',
			return_policy => 'privateairship:prontera',
		};
		is_deeply([_production_errors($complete, $shared_rows)], [],
			'a complete macro rule satisfies the production contract');

		my %missing_announcement = %$complete;
		delete $missing_announcement{announce_regex};
		like(join('; ', _production_errors(\%missing_announcement, $shared_rows)),
			qr/announce_regex/, 'missing announcement evidence is rejected');

		my %missing_finish = %$complete;
		delete $missing_finish{finish_regex};
		like(join('; ', _production_errors(\%missing_finish, $shared_rows)),
			qr/finish evidence/, 'missing finish evidence is rejected');

		my %missing_map = %$complete;
		delete @missing_map{qw(map_source entry_map)};
		like(join('; ', _production_errors(\%missing_map, $shared_rows)),
			qr/map_source|entry_map/, 'missing map evidence is rejected');

		my %bad_return = %$complete;
		$bad_return{return_policy} = 'prontera';
		like(join('; ', _production_errors(\%bad_return, $shared_rows)),
			qr/return_policy/, 'non-canonical return policy is rejected');

		my %missing_entry = %$complete;
		delete $missing_entry{entry_macro};
		like(join('; ', _production_errors(\%missing_entry, $shared_rows)),
			qr/entry_macro/, 'missing entry macro is rejected');

		my $npc_rule = {
			enabled => 1,
			announce_regex => 'event ready',
			finish_regex => 'event done',
			map_source => 'fixed',
			entry_map => 'prontera',
			entry_type => 'npc',
			entry_x => 152,
			entry_y => 129,
			entry_npc => 'Guide#c',
			entry_npc_trusted => 1,
			entry_npc_evidence => 'server dialog transcript',
			return_policy => 'privateairship:prontera',
		};
		is_deeply([_production_errors($npc_rule, $shared_rows)], [],
			'canonical trusted NPC metadata satisfies NPC entry validation');
		my %untrusted_npc = %$npc_rule;
		delete $untrusted_npc{entry_npc_evidence};
		like(join('; ', _production_errors(\%untrusted_npc, $shared_rows)),
			qr/entry_npc_evidence/, 'NPC entry without canonical evidence is rejected');

		my $search_rule = {
			enabled => 1,
			announce_regex => 'event ready',
			finish_regex => 'event done',
			map_source => 'fixed',
			entry_map => 'prontera',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			return_policy => 'privateairship:prontera',
			search_targets => ['missing-event-monster'],
		};
		like(join('; ', _production_errors($search_rule, $shared_rows)),
			qr/search target|shared mon_control/, 'untrusted search target is rejected');
		my %missing_item = %$search_rule;
		delete $missing_item{entry_item_id};
		like(join('; ', _production_errors(\%missing_item, $shared_rows)),
			qr/entry_item_id/, 'airship entry without a confirmed item ID is rejected');
		done_testing();
	};

}

1;
