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

my %MAP_SOURCES = map { $_ => 1 } qw(static dynamic announcement);

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
	return 0 if $map =~ m{[\\/]};
	return 0 if $map =~ /\.\./;
	return 0 if $map =~ /:/;
	return 0 if $map =~ /[\x00-\x1F\x7F]/;
	return 0 if $map =~ /[\s;|&<>"'`]/;
	return 1;
}

sub _known_map {
	my ($map, $known_maps) = @_;
	return 0 unless _safe_map_name($map);
	return 0 unless ref($known_maps) eq 'HASH';
	$map = _trim($map);
	$map =~ s/\.(?:rsw|gat)$//i;
	return $known_maps->{lc($map)} ? 1 : 0;
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

sub _load_known_maps {
	my ($repo_root) = @_;
	my $path = File::Spec->catfile($repo_root, 'tables', 'Lastro-zh_CN', 'maps.txt');
	open my $fh, '<:encoding(UTF-8)', $path or return (undef, "unable to read $path: $!");
	my %maps;
	while (my $line = <$fh>) {
		$line =~ s/\r?\n$//;
		next if $line =~ /^\s*(?:#|\/\/)/ || _trim($line) eq '';
		my ($map) = split /#/, $line, 2;
		$map = _trim($map);
		$map =~ s/\.(?:rsw|gat)$//i;
		next unless $map ne '';
		$maps{lc($map)} = 1;
	}
	close $fh;
	return (\%maps, undef);
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
	return 0 if ref($rule) eq 'HASH' && defined $rule->{combat_mode}
		&& lc(_trim($rule->{combat_mode})) eq 'normal';
	return 0 if ref($rule) eq 'HASH' && exists $rule->{search_mode}
		&& !$rule->{search_mode};
	return 1;
}

sub _search_row_enabled {
	my ($shared_rows, $key) = @_;
	return 0 unless ref($shared_rows) eq 'HASH' && defined $key && $key ne '';
	my $fields = $shared_rows->{lc(_trim($key))};
	return 0 unless ref($fields) eq 'ARRAY' && defined $fields->[2];
	return "$fields->[2]" =~ /^\s*1\s*$/ ? 1 : 0;
}

sub _trusted_search_target {
	my ($target, $shared_rows) = @_;
	return 0 unless defined $target;
	$target = _trim($target);
	return 0 if $target eq '' || lc($target) eq 'all' || $target =~ /[\r\n]/;
	return 0 if $target =~ /^0+$/;

	# Production validation cannot assume that the runtime monster LUT contains
	# an ID/name alias. Require the exact declared target key to be present in the
	# shared control file, which is always a resolver path available at runtime.
	return _search_row_enabled($shared_rows, $target);
}

sub _production_errors {
	my ($rule, $shared_rows, $known_maps) = @_;
	return () unless ref($rule) eq 'HASH' && _truthy($rule->{enabled});
	my @errors;
	if (ref($rule->{validation_errors}) eq 'ARRAY' && @{$rule->{validation_errors}}) {
		push @errors, 'validation_errors are present on an enabled rule';
	}
	if (defined $rule->{combat_mode}) {
		my $combat_mode = ref($rule->{combat_mode}) ? '' : _trim($rule->{combat_mode});
		push @errors, 'combat_mode must be normal'
			if ref($rule->{combat_mode}) || lc($combat_mode) ne 'normal';
	}
	if (defined $rule->{random_walk}) {
		my $random_walk = ref($rule->{random_walk}) ? '' : _trim($rule->{random_walk});
		push @errors, 'random_walk must be 0 or 1'
			if ref($rule->{random_walk}) || $random_walk !~ /^(?:0|1)$/;
	}

	# The announcement is the start evidence. A countdown is optional, but the
	# rule must still identify the server line that is allowed to trigger it.
	push @errors, 'announce_regex (start evidence) is required or invalid'
		unless _valid_pattern($rule->{announce_regex});
	push @errors, 'start_regex (scheduler start evidence) is required or invalid'
		unless _valid_pattern($rule->{start_regex});

	my $finish_ok = 0;
	my $finish_defined = defined $rule->{finish_regex};
	my $finish_present = $finish_defined
		&& (ref($rule->{finish_regex}) || _trim($rule->{finish_regex}) ne '');
	if ($finish_present) {
		if (_valid_pattern($rule->{finish_regex})) {
			$finish_ok = 1;
		} else {
			push @errors, 'finish_regex is invalid';
		}
	}
	if (ref($rule->{phases}) eq 'ARRAY' && @{$rule->{phases}}) {
		my $phases_ok = 1;
		for my $phase (@{$rule->{phases}}) {
			my $pattern = _phase_finish_pattern($phase);
			unless (_valid_pattern($pattern)) {
				$phases_ok = 0;
				push @errors, 'phase finish evidence is missing or invalid';
			}
		}
		$finish_ok = 1 if $phases_ok;
	} elsif (defined $rule->{phases} && ref($rule->{phases}) ne 'ARRAY') {
		push @errors, 'phases must be an array';
	}
	$finish_ok = 1 if _positive_number($rule->{duration_seconds});
	push @errors, 'finish evidence or a positive duration is required'
		unless $finish_ok;

	my $source = _trim($rule->{map_source});
	my $entry_map = _trim($rule->{entry_map});
	my $source_key = lc($source);
	if ($source ne '' && !$MAP_SOURCES{$source_key}) {
		push @errors, "map_source '$source' is not documented";
	}
	if ($source eq '' && $entry_map eq '') {
		push @errors, 'map_source or entry_map is required';
	} elsif (lc($source) eq 'dynamic') {
		# Dynamic maps come from the matched announcement. If a static fallback is
		# supplied anyway, still reject unsafe or unknown values rather than trusting
		# stale configuration.
		if ($entry_map ne '' && (!_safe_map_name($entry_map)
			|| !_known_map($entry_map, $known_maps))) {
			push @errors, 'dynamic entry_map is unsafe or unknown';
		}
	} elsif (!_safe_map_name($entry_map)) {
		push @errors, 'a safe entry_map is required for a fixed map source';
	} elsif (!_known_map($entry_map, $known_maps)) {
		push @errors, "entry_map '$entry_map' is unknown";
	}

	my $return_policy = _trim($rule->{return_policy});
	push @errors, 'return_policy must be tt:prontera'
		unless $return_policy =~ /^tt\s*:\s*prontera$/i;
	for my $macro_field (qw(entry_macro finish_macro)) {
		if (defined $rule->{$macro_field} && _trim($rule->{$macro_field}) ne ''
			&& !_safe_macro_name($rule->{$macro_field})) {
			push @errors, "$macro_field is invalid";
		}
	}

	my $entry_type = lc(_trim($rule->{entry_type}));
	$entry_type = 'tt' if $entry_type eq '';
	if ($entry_type eq 'tt' || $entry_type eq 'airship' || $entry_type eq 'privateairship') {
		# tt supplies the default transport item (14527); production validation
		# only requires the shared search evidence for combat routes.
	} elsif ($entry_type eq 'npc') {
		push @errors, 'entry_map is required for NPC entry' unless _safe_map_name($entry_map);
		push @errors, 'entry_x is required for NPC entry'
			unless defined $rule->{entry_x} && "$rule->{entry_x}" =~ /^\d+$/;
		push @errors, 'entry_y is required for NPC entry'
			unless defined $rule->{entry_y} && "$rule->{entry_y}" =~ /^\d+$/;
		if (lc(_trim($rule->{entry_dialog_mode})) eq 'repeat_first_until_finish') {
			push @errors, 'entry_npc_name is required for repeating NPC dialog'
			unless _has_value($rule->{entry_npc_name});
		} else {
			push @errors, 'entry_npc is required for NPC entry'
				unless _safe_npc_sequence($rule->{entry_npc});
			push @errors, 'entry_npc_trusted=1 is required for NPC entry'
				unless _truthy($rule->{entry_npc_trusted});
			push @errors, 'entry_npc_evidence is required for NPC entry'
				unless _has_value($rule->{entry_npc_evidence});
		}
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
				if (!_trusted_search_target($target, $shared_rows)) {
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
	my ($known_maps, $map_error) = _load_known_maps($repo_root);

	subtest 'production fixture preserves evidence-backed routing flags and lifecycle fail-closed checks' => sub {
		ok(-f $rules_file, 'bundled production rules file exists');
		my ($rules, $errors) = LastROActivity::Rules::load_file($rules_file);
		ok(ref($rules) eq 'HASH', 'production rules load as a hash');
		is_deeply([sort keys %{$rules || {}}], [sort @EVENT_IDS],
			'fixture contains exactly the six first-phase event IDs');
		is_deeply(
			$errors,
			[
				'dungeon_monster_party: announce_regex required when enabled',
				'dungeon_monster_party: start_regex required when enabled',
				'dojo_challenge: search_targets evidence is required for shared search mode',
				'pool_challenge: search_targets evidence is required for shared search mode',
				'sky_chest: announce_regex required when enabled',
				'sky_chest: start_regex required when enabled',
			],
			'raw-enabled sections without announcement evidence fail closed during parsing',
		);
		ok(!defined $shared_error, 'shared mon_control.txt is readable')
			or diag($shared_error);
		ok(!defined $map_error, 'server map table is readable')
			or diag($map_error);

		open my $raw_fh, '<:encoding(UTF-8)', $rules_file
			or die "Unable to read $rules_file: $!";
		local $/;
		my $raw_text = <$raw_fh>;
		close $raw_fh;
		for my $id (@EVENT_IDS) {
			like($raw_text, qr/\[$id\][^\[]*?\benabled=1\b/s,
				"$id retains the requested raw enabled=1 flag");
		}

		my %expected_validation_errors = (
			city_monster_party => [],
			dungeon_monster_party => [
				'announce_regex required when enabled',
				'start_regex required when enabled',
			],
			dojo_challenge => [
				'search_targets evidence is required for shared search mode',
			],
			pool_challenge => [
				'search_targets evidence is required for shared search mode',
			],
			lottery => [],
			sky_chest => [
				'announce_regex required when enabled',
				'start_regex required when enabled',
			],
		);
		for my $id (@EVENT_IDS) {
			ok(exists $rules->{$id}, "$id rule exists");
			next unless exists $rules->{$id};
			my $expected_enabled = $id eq 'lottery' || $id eq 'city_monster_party' ? 1 : 0;
			is($rules->{$id}{enabled}, $expected_enabled,
				"$id has the expected effective enable state");
			is_deeply($rules->{$id}{validation_errors}, $expected_validation_errors{$id},
				"$id records the parser validation errors that forced effective disablement");
		}

		is($rules->{dojo_challenge}{map_source}, 'dynamic', 'morocc route declares dynamic map source');
		is($rules->{pool_challenge}{map_source}, 'dynamic', 'payon route declares dynamic map source');
		is($rules->{lottery}{map_source}, 'static', 'lottery route declares static map source');
		is($rules->{city_monster_party}{map_source}, 'dynamic', 'party route declares dynamic map source');
		is($rules->{city_monster_party}{combat_mode}, 'normal',
			'party route uses explicit normal combat mode');
		is($rules->{city_monster_party}{random_walk}, 1,
			'party route enables random walk in its rule metadata');
		is($rules->{lottery}{announce_regex},
			'(?=.*\[随机事件\])(?=.*抽奖活动)(?=.*开始啦)(?!.*下一次事件)',
			'lottery announcement pattern is exact');
		is($rules->{lottery}{start_regex},
			'(?=.*\[随机事件\])(?=.*抽奖活动)(?=.*[0-9]+\s*秒钟?后)(?=.*开始啦)(?!.*下一次事件)',
			'lottery countdown pattern is exact');
		is($rules->{lottery}{entry_map}, 'prontera', 'lottery retains confirmed capital entry map');
		is($rules->{lottery}{entry_x}, 152, 'lottery retains confirmed NPC x coordinate');
		is($rules->{lottery}{entry_y}, 133, 'lottery uses confirmed NPC Y');
		is($rules->{lottery}{entry_npc_name}, '活动负责人#iz',
			'NPC suffix remains part of the name');
		is($rules->{lottery}{entry_dialog_mode}, 'repeat_first_until_finish',
			'lottery repeats first-option dialog');
		ok($rules->{lottery}{enabled}, 'lottery is effectively enabled');
		is($rules->{lottery}{return_policy}, 'tt:prontera',
			'lottery returns through tt');
		ok(!defined $rules->{lottery}{entry_item_id},
			'lottery does not require an entry item ID');
		ok(!defined $rules->{lottery}{entry_npc},
			'lottery uses the exact NPC name instead of a TalkNPC sequence');
		is_deeply($rules->{lottery}{search_targets}, [],
			'lottery keeps an empty search_targets value');
		for my $id (qw(city_monster_party dojo_challenge pool_challenge)) {
			is($rules->{$id}{entry_type}, 'tt', "$id uses tt entry");
			is($rules->{$id}{return_policy}, 'tt:prontera', "$id uses tt return");
			ok(!defined $rules->{$id}{entry_item_id}, "$id uses tt default item");
		}
		done_testing();
	};

	subtest 'enabled rules fail closed for missing production evidence' => sub {
		my $complete = {
			enabled => 1,
			announce_regex => 'event ready',
			start_regex => 'event starts',
			finish_regex => 'event done',
			map_source => 'static',
			entry_map => 'prontera',
			entry_type => 'macro',
			entry_macro => 'enter_event',
			return_policy => 'tt:prontera',
		};
		is_deeply([_production_errors($complete, $shared_rows, $known_maps)], [],
			'a complete macro rule satisfies the production contract');

		my $normal_party_rule = {
			enabled => 1,
			announce_regex => 'event ready',
			start_regex => 'event starts',
			finish_regex => 'event done',
			map_source => 'dynamic',
			entry_type => 'tt',
			return_policy => 'tt:prontera',
			combat_mode => ' NORMAL ',
			random_walk => 1,
			search_targets => [],
		};
		is_deeply([_production_errors($normal_party_rule, $shared_rows, $known_maps)], [],
			'normal party mode accepts an empty search target list');

		my %missing_announcement = %$complete;
		delete $missing_announcement{announce_regex};
		like(join('; ', _production_errors(\%missing_announcement, $shared_rows, $known_maps)),
			qr/announce_regex/, 'missing announcement evidence is rejected');

		my %missing_start = %$complete;
		delete $missing_start{start_regex};
		like(join('; ', _production_errors(\%missing_start, $shared_rows, $known_maps)),
			qr/start_regex/, 'missing scheduler start evidence is rejected');

		my %missing_finish = %$complete;
		delete $missing_finish{finish_regex};
		like(join('; ', _production_errors(\%missing_finish, $shared_rows, $known_maps)),
			qr/finish evidence/, 'missing finish evidence is rejected');

		my %malformed_finish = %$complete;
		$malformed_finish{finish_regex} = '[';
		$malformed_finish{duration_seconds} = 900;
		like(join('; ', _production_errors(\%malformed_finish, $shared_rows, $known_maps)),
			qr/finish_regex.*invalid|invalid.*finish/, 'malformed finish evidence is rejected even with duration fallback');

		my %missing_map = %$complete;
		delete @missing_map{qw(map_source entry_map)};
		like(join('; ', _production_errors(\%missing_map, $shared_rows, $known_maps)),
			qr/map_source|entry_map/, 'missing map evidence is rejected');

		my %unknown_map = %$complete;
		$unknown_map{entry_map} = 'not_real';
		like(join('; ', _production_errors(\%unknown_map, $shared_rows, $known_maps)),
			qr/unknown|entry_map/, 'unknown map names are rejected');

		my %traversal_map = %$complete;
		$traversal_map{entry_map} = '../../x';
		like(join('; ', _production_errors(\%traversal_map, $shared_rows, $known_maps)),
			qr/unsafe|entry_map|map/, 'path traversal map names are rejected');

		my %bad_map_source = %$complete;
		$bad_map_source{map_source} = 'typo';
		like(join('; ', _production_errors(\%bad_map_source, $shared_rows, $known_maps)),
			qr/map_source/, 'undocumented map source values are rejected');

		my %bad_return = %$complete;
		$bad_return{return_policy} = 'prontera';
		like(join('; ', _production_errors(\%bad_return, $shared_rows, $known_maps)),
			qr/return_policy/, 'non-canonical return policy is rejected');

		my %bad_combat_mode = %$complete;
		$bad_combat_mode{combat_mode} = 'search';
		like(join('; ', _production_errors(\%bad_combat_mode, $shared_rows, $known_maps)),
			qr/combat_mode/, 'unsupported combat modes are rejected');

		my %bad_random_walk = %$complete;
		$bad_random_walk{random_walk} = 'maybe';
		like(join('; ', _production_errors(\%bad_random_walk, $shared_rows, $known_maps)),
			qr/random_walk/, 'invalid random_walk values are rejected');

		my %missing_entry = %$complete;
		delete $missing_entry{entry_macro};
		like(join('; ', _production_errors(\%missing_entry, $shared_rows, $known_maps)),
			qr/entry_macro/, 'missing entry macro is rejected');

		my $npc_rule = {
			enabled => 1,
			announce_regex => 'event ready',
			start_regex => 'event starts',
			finish_regex => 'event done',
			map_source => 'static',
			entry_map => 'prontera',
			entry_type => 'npc',
			entry_x => 152,
			entry_y => 129,
			entry_npc => 'Guide#c',
			entry_npc_trusted => 1,
			entry_npc_evidence => 'server dialog transcript',
			return_policy => 'tt:prontera',
		};
		is_deeply([_production_errors($npc_rule, $shared_rows, $known_maps)], [],
			'canonical trusted NPC metadata satisfies NPC entry validation');
		my $named_npc_rule = {
			enabled => 1,
			announce_regex => 'event ready',
			start_regex => 'event starts',
			finish_regex => 'event done',
			map_source => 'static',
			entry_map => 'prontera',
			entry_type => 'npc',
			entry_x => 152,
			entry_y => 133,
			entry_npc_name => '活动负责人#iz',
			entry_dialog_mode => 'repeat_first_until_finish',
			return_policy => 'tt:prontera',
		};
		is_deeply([_production_errors($named_npc_rule, $shared_rows, $known_maps)], [],
			'named repeating NPC metadata satisfies Lottery entry validation');
		my %untrusted_npc = %$npc_rule;
		delete $untrusted_npc{entry_npc_evidence};
		like(join('; ', _production_errors(\%untrusted_npc, $shared_rows, $known_maps)),
			qr/entry_npc_evidence/, 'NPC entry without canonical evidence is rejected');

		my $search_rule = {
			enabled => 1,
			announce_regex => 'event ready',
			start_regex => 'event starts',
			finish_regex => 'event done',
			map_source => 'static',
			entry_map => 'prontera',
			entry_type => 'tt',
			return_policy => 'tt:prontera',
			search_targets => ['missing-event-monster'],
		};
		like(join('; ', _production_errors($search_rule, $shared_rows, $known_maps)),
			qr/search target|shared mon_control/, 'untrusted search target is rejected');
		my %all_rows = %{defined $shared_rows ? $shared_rows : {}};
		$all_rows{all} = [1, 0, 1];
		my %all_target = %$search_rule;
		$all_target{search_targets} = ['all'];
		like(join('; ', _production_errors(\%all_target, \%all_rows, $known_maps)),
			qr/search target|shared mon_control/, 'the all sentinel is rejected as a search target');
		my %alias_rows = (scorpion => [1, 0, 1]);
		my %numeric_alias_target = %$search_rule;
		$numeric_alias_target{search_targets} = ['1001'];
		like(join('; ', _production_errors(\%numeric_alias_target, \%alias_rows, $known_maps)),
			qr/search target|shared mon_control/,
			'numeric targets require a direct shared row when the runtime LUT has no alias');
		my ($known_target) = grep {
			ref($shared_rows) eq 'HASH'
			&& ref($shared_rows->{$_}) eq 'ARRAY'
			&& defined $shared_rows->{$_}[2]
			&& "$shared_rows->{$_}[2]" eq '1'
		} keys %{defined $shared_rows ? $shared_rows : {}};
		ok(defined $known_target, 'shared fixture exposes a search=1 row for positive target validation');
		if (defined $known_target) {
			my %trusted_target = %$search_rule;
			$trusted_target{search_targets} = [$known_target];
			is_deeply([_production_errors(\%trusted_target, $shared_rows, $known_maps)], [],
				'a declared target resolves to a shared search=1 row');
			my %without_item = %trusted_target;
			delete $without_item{entry_item_id};
			is_deeply([_production_errors(\%without_item, $shared_rows, $known_maps)], [],
				'tt entry uses the default item without an entry_item_id');
		}
		done_testing();
	};

}

1;
