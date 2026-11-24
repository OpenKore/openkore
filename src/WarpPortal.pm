#########################################################################
# OpenKore - Warp Portal memo configuration and runtime observations
#########################################################################
package WarpPortal;

use strict;
use Exporter 'import';
use Time::HiRes qw(time);
use Globals qw(%config %maps_lut $char $masterServer);

our @EXPORT_OK = qw(
	parseMemoEntry normalizeWarpMap normalizeWarpMapName beginCharacterSession noteWarpCast
	noteMemoRequest memoAcknowledged updateServerMemos recordArrival
	availableWarpMaps warpMapIndex memoCoordinateForMap clearPendingTraversal noteWarpSelection
	warpMapStatus confirmPortalArrival memoRejected selectWarpPortalCastLevel
);

# Pick the least expensive learned AL_WARP level that still covers the server
# menu slot and the character's current SP. Unknown costs retain the historic
# minimum-level behavior only when that minimum's cost is also unknown.
sub selectWarpPortalCastLevel {
	my ($skill, $minimum_level, $learned_level, $available_sp) = @_;
	return unless $skill && defined($minimum_level) && defined($learned_level)
		&& $minimum_level >= 1 && $learned_level >= $minimum_level;
	$learned_level = 4 if $learned_level > 4;
	$available_sp = 0 unless defined $available_sp;
	my @affordable;
	for my $level ($minimum_level .. $learned_level) {
		my $cost = $skill->getSP($level);
		if (!defined $cost) {
			push @affordable, [$level, undef] if $level == $minimum_level;
		} elsif ($available_sp >= $cost) {
			push @affordable, [$level, $cost];
		}
	}
	return unless @affordable;
	@affordable = sort {
		(defined($a->[1]) ? $a->[1] : 9e99) <=> (defined($b->[1]) ? $b->[1] : 9e99)
			|| $a->[0] <=> $b->[0]
	} @affordable;
	return $affordable[0][0];
}

sub normalizeWarpMapName {
	my ($map) = @_;
	return '' unless defined $map;
	$map =~ s/\.gat\z//i;
	return '' unless $map =~ /^[a-zA-Z0-9_]+\z/;
	return lc $map;
}

sub normalizeWarpMap { return normalizeWarpMapName($_[0]); }

sub parseMemoEntry {
	my ($value) = @_;
	$value = '' unless defined $value;
	$value =~ s/^\s+|\s+$//g;
	return { map => '', valid => 1, has_coords => 0 } if $value eq '';
	return { map => '', valid => 0, has_coords => 0 }
		unless $value =~ /^([a-zA-Z0-9_]+)(?:\s+(\d+)\s+(\d+))?\z/;
	my ($raw_map, $x, $y) = ($1, $2, $3);
	my $map = normalizeWarpMap($raw_map);
	return { map => '', valid => 0, has_coords => 0 } unless $map;
	return { map => $map, valid => 1, has_coords => 0 } unless defined $x && defined $y;
	return { map => '', valid => 0, has_coords => 0 } if $x > 65535 || $y > 65535;
	return { map => $map, x => 0 + $x, y => 0 + $y, valid => 1, has_coords => 1 };
}

sub _characterKey {
	return '' unless $char;
	my $charID = $char->{charID};
	$charID = unpack('H*', $charID) if defined($charID) && !ref($charID);
	return join(':',
		($masterServer && $masterServer->{ip} || ''),
		($masterServer && $masterServer->{port} || ''),
		($config{char} // ''),
		($charID // ''),
	);
}

sub _state {
	return unless $char;
	my $key = _characterKey();
	if (!$char->{warpPortalState} || ($char->{warpPortalState}{character_key} // '') ne $key) {
		$char->{warpPortalState} = {character_key => $key, session => 0};
	}
	return $char->{warpPortalState};
}

sub beginCharacterSession {
	my $state = _state() or return;
	my $key = _characterKey();
	$char->{warpPortalState} = {
		character_key => $key,
		session => ($state->{session} || 0) + 1,
		# A previous session's menu and arrival coordinates are not current
		# server evidence. Configuration coordinates remain historical hints.
	};
	delete $char->{warpPortalPendingTraversal};
}

sub noteWarpCast {
	my ($skill_id, $level, $x, $y) = @_;
	return unless $skill_id == 27 && $level && $level >= 1 && $level <= 4;
	my $state = _state() or return;
	$state->{pending_cast} = {
		level => 0 + $level, time => time, session => $state->{session},
		portal_pos => defined($x) && defined($y) ? {x => 0 + $x, y => 0 + $y} : undef,
	};
}

sub noteMemoRequest {
	my ($map, $x, $y) = @_;
	return unless $char && defined($x) && defined($y);
	my $state = _state() or return;
	if ($state->{pending_memo} && time - $state->{pending_memo}{time} > 30) {
		delete $state->{pending_memo};
		$state->{memo_ack_uncertain} = 1;
	}
	if ($state->{pending_memo}) {
		# The protocol has no request identifier. Multiple outstanding /memo
		# requests make the next acknowledgement impossible to correlate safely.
		delete $state->{pending_memo};
		$state->{memo_ack_uncertain} = 1;
		return;
	}
	$state->{pending_memo} = {
		map => normalizeWarpMapName($map), x => 0 + $x, y => 0 + $y,
		time => time, session => $state->{session},
	};
}

sub memoAcknowledged {
	my ($failed) = @_;
	my $state = _state() or return;
	my $pending = delete $state->{pending_memo};
	return if $failed || !$pending;
	if ($pending->{session} != $state->{session} || time - $pending->{time} > 30) {
		$state->{memo_ack_uncertain} = 1;
		return;
	}
	return if $state->{memo_ack_uncertain} || !$pending->{map};

	# rAthena's successful /memo operation moves the current map to the front,
	# removes an existing copy, shifts the other points, then drops the oldest.
	# Use the latest server order when available, then retain any additional
	# configured destinations as historical hints. The acknowledgement confirms
	# the insertion, while the next AL_WARP list remains authoritative for the
	# final order and availability.
	my @old = @{$state->{memo_maps} || []};
	my %seen;
	my @configured = map { parseMemoEntry($config{"memo$_"})->{map} } 2 .. 4;
	my @new = grep { $_ && $_ ne $pending->{map} && !$seen{$_}++ } (@old, @configured);
	@new = ($pending->{map}, @new);
	splice @new, 3 if @new > 3;
	$state->{memo_maps} = \@new;
	delete @{$state}{qw(available_maps available_map_counts available_map_index)};
	$state->{verified_coverage} = 0;
	$state->{list_stale} = 1;
	$state->{observed_coordinates}{$pending->{map}} = {
		x => $pending->{x}, y => $pending->{y}, source => 'memo_success_ack',
		time => time, session => $state->{session},
	};

	if ($config{warpPortal_autoUpdateMemo}) {
		my @entries = map { _entryForMap($_) } @new;
		for my $slot (2 .. 4) {
			my $value = $entries[$slot - 2] || '';
			_writeConfig("memo$slot", $value);
		}
	}
}

sub memoRejected {
	my $state = _state() or return;
	my $pending = delete $state->{pending_memo};
	# 0x0189 does not identify the /memo request it rejected. Even after clearing
	# the current request, a delayed 0x011E could still belong to it, so no later
	# acknowledgement is safe to associate until the server list reconciles state.
	$state->{memo_ack_uncertain} = 1 if $pending || $state->{memo_ack_uncertain};
}

sub _coordinatesByMap {
	my %coordinates;
	my %counts;
	my %candidate;
	for my $slot (1 .. 4) {
		my $entry = parseMemoEntry($config{"memo$slot"});
		$counts{$entry->{map}}++ if $entry->{valid} && $entry->{map};
		push @{$candidate{$entry->{map}}}, [$entry->{x}, $entry->{y}]
			if $entry->{valid} && $entry->{map} && $entry->{has_coords};
	}
	my $saveMap = normalizeWarpMap($config{saveMap});
	if ($saveMap && defined $config{saveMap_x} && defined $config{saveMap_y}
		&& $config{saveMap_x} =~ /^\d+$/ && $config{saveMap_y} =~ /^\d+$/) {
		push @{$candidate{$saveMap}}, [0 + $config{saveMap_x}, 0 + $config{saveMap_y}];
	}
	for my $map (keys %candidate) {
		next if ($counts{$map} || 0) > 1;
		my $first = $candidate{$map}[0];
		next if grep { $_->[0] != $first->[0] || $_->[1] != $first->[1] } @{$candidate{$map}};
		$coordinates{$map} = $first;
	}
	return \%coordinates;
}

sub _entryForMap {
	my ($map, $coordinates) = @_;
	return '' unless $map;
	$coordinates ||= _coordinatesByMap();
	my $observed = _state()->{observed_coordinates}{$map};
	if ($observed && $observed->{session} == _state()->{session}) {
		return "$map $observed->{x} $observed->{y}";
	}
	return $coordinates->{$map} ? "$map @{$coordinates->{$map}}" : $map;
}

sub _writeConfig {
	my ($key, $value) = @_;
	my $current = defined $config{$key} ? $config{$key} : '';
	return if $current eq $value;
	Misc::configModify($key, $value);
}

sub updateServerMemos {
	my ($args) = @_;
	return unless $char && $args && ($args->{type} || 0) == 27;
	my $state = _state() or return;
	my (@maps, %unresolved_slots);
	for my $slot (1 .. 4) {
		my $raw = $args->{"memo$slot"} // '';
		$raw =~ s/\.gat\z//i;
		my $map = normalizeWarpMapName($raw);
		push @maps, $map;
		$unresolved_slots{$slot} = 1 if $raw ne '' && (!$map
			|| !exists $maps_lut{lc($map) . '.rsw'} && !exists $maps_lut{$map . '.rsw'});
	}
	unless (grep { $_ ne '' } @maps) {
	delete @{$state}{qw(available_maps available_map_counts available_map_index cast_level verified_at)};
		$state->{verified_coverage} = 0;
		$state->{list_stale} = 1;
		$state->{list_provenance} = 'empty_or_invalid_server_list';
		return;
	}

	my $cast = $state->{pending_cast};
	my $cast_level = $cast && $cast->{session} == $state->{session}
		&& time - $cast->{time} <= 20 ? $cast->{level} : undef;
	if (defined $cast_level) {
		$state->{last_portal_cast} = {
			level => $cast_level,
			portal_pos => $cast->{portal_pos} ? {%{$cast->{portal_pos}}} : undef,
			time => $cast->{time}, session => $cast->{session},
		};
	}
	delete $state->{pending_cast};
	# Even if a proxy packet path did not expose the cast level, a valid AL_WARP
	# list always proves the save point. Higher memo coverage remains unknown.
	my $coverage = defined($cast_level) ? $cast_level : 1;
	my %count;
	$count{$_}++ for @maps;
	$state->{available_maps} = [@maps];
	$state->{available_map_counts} = \%count;
	$state->{available_map_index} = {map { $maps[$_] => $_ } grep { $maps[$_] ne '' } 0 .. $#maps};
	$state->{savepoint} = $maps[0];
	$state->{memo_maps} = [@maps[1 .. $#maps]];
	$state->{unresolved_slots} = \%unresolved_slots;
	$state->{cast_level} = $cast_level;
	$state->{verified_coverage} = $coverage;
	$state->{verified_at} = time;
	delete $state->{list_stale};
	$state->{list_provenance} = defined($cast_level) ? 'server_list_with_cast_level' : 'server_list_level_unknown';
	$state->{list_ambiguous} = scalar(grep { $count{$_} > 1 } keys %count) ? 1 : 0;
	delete $state->{memo_ack_order_pending};
	delete @{$state}{qw(memo_ack_uncertain pending_memo)};

	# Preserve the existing saveMap source used by other OpenKore features.
	# The packet has no save-point coordinates, so discard old coordinates only
	# when their associated map changes.
	if ($maps[0] && $maps[0] ne (normalizeWarpMap($config{saveMap}) || '')) {
		_writeConfig('saveMap', $maps[0]);
		_writeConfig('saveMap_x', '') if defined($config{saveMap_x}) && $config{saveMap_x} ne '';
		_writeConfig('saveMap_y', '') if defined($config{saveMap_y}) && $config{saveMap_y} ne '';
	}

	return unless $config{warpPortal_autoUpdateMemo};
	my $coordinates = _coordinatesByMap();
	my @canonical = ($maps[0], @maps[1 .. $#maps]);
	my $covered = $coverage > 0 ? $coverage : 0;
	$covered = 4 if $covered > 4;
	for my $slot (1 .. $covered) {
		# Keep the position of a syntactically present map that is missing from
		# the local map table. It is not routable, but compacting it here would
		# attach the following map's coordinates to the wrong destination.
		next if $unresolved_slots{$slot};
		my $map = $canonical[$slot - 1] || '';
		my $value = $map && $count{$map} == 1 ? _entryForMap($map, $coordinates) : $map;
		_writeConfig("memo$slot", $value);
	}
}

sub availableWarpMaps {
	my $state = _state() or return;
	return if $state->{list_stale};
	return unless $state->{available_maps} && @{$state->{available_maps}};
	return $state->{available_maps};
}

sub warpMapIndex {
	my ($map) = @_;
	$map = normalizeWarpMap($map);
	return unless $map;
	my $state = _state() or return;
	return if $state->{list_stale};
	return if ($state->{available_map_counts}{$map} || 0) != 1;
	return $state->{available_map_index}{$map};
}

sub warpMapStatus {
	my ($map, $config_slot) = @_;
	$map = normalizeWarpMap($map);
	return 'invalid' unless $map;
	my $state = _state() or return 'unknown';
	return 'ambiguous' if !$state->{list_stale} && ($state->{available_map_counts}{$map} || 0) > 1;
	my $index = warpMapIndex($map);
	return 'present' if defined $index;
	return 'unknown' if $state->{list_stale} || !$state->{verified_coverage};
	# A list only verifies the fields exposed by the level used for this cast.
	# It can disprove a destination within that coverage, but a lower-level list
	# says nothing about higher memo slots.
	return 'absent' if defined($config_slot) && $config_slot <= $state->{verified_coverage}
		&& !defined($index);
	return 'unknown';
}

sub memoCoordinateForMap {
	my ($map) = @_;
	$map = normalizeWarpMap($map);
	return unless $map;
	my $state = _state() or return;
	my $observed = $state->{observed_coordinates}{$map};
	return ($observed->{x}, $observed->{y}, $observed->{source})
		if $observed && $observed->{session} == $state->{session};
	my @entries = grep {
		$_->{valid} && $_->{map} eq $map && $_->{has_coords}
	} map { parseMemoEntry($config{"memo$_"}) } 1 .. 4;
	return if @entries != 1;
	return ($entries[0]{x}, $entries[0]{y}, 'configuration');
}

sub noteWarpSelection {
	my ($map, $source_map, $x, $y, $cast_level, $attempt_id, $portal_pos) = @_;
	return unless $char && defined $x && defined $y;
	$map = normalizeWarpMap($map);
	return unless $map;
	my $state = _state() or return;
	if (!defined($attempt_id) || $attempt_id eq '') {
		$attempt_id = join('-', 'manual', $state->{session}, ++$state->{manual_attempt_sequence});
	}
	$char->{warpPortalPendingTraversal} = {
		map => $map, source_map => $source_map, x => 0 + $x, y => 0 + $y,
		cast_level => $cast_level, attempt_id => $attempt_id,
		portal_expected_pos => $portal_pos ? {%$portal_pos} : undef,
		selected_at => time, session => $state->{session},
	};
}

sub clearPendingTraversal {
	my ($attempt_id) = @_;
	return unless $char && $char->{warpPortalPendingTraversal};
	return unless defined($attempt_id) && $attempt_id ne ''
		&& defined($char->{warpPortalPendingTraversal}{attempt_id})
		&& $attempt_id eq $char->{warpPortalPendingTraversal}{attempt_id};
	delete $char->{warpPortalPendingTraversal};
}

sub confirmPortalArrival {
	my ($old_map, $new_map, $x, $y, $entered_pos) = @_;
	return unless $char && defined($x) && defined($y);
	my $pending = $char->{warpPortalPendingTraversal} or return;
	my $state = _state() or return;
	if ($pending->{session} != $state->{session} || time - $pending->{selected_at} > 120) {
		clearPendingTraversal($pending->{attempt_id});
		return;
	}
	$new_map = normalizeWarpMap($new_map);
	my $is_traversal = $pending->{portal_seen_at}
		&& defined($old_map) && $old_map eq $pending->{source_map}
		&& $new_map && $new_map eq $pending->{map}
		&& $entered_pos && $pending->{portal_pos}
		&& $entered_pos->{x} == $pending->{portal_pos}{x}
		&& $entered_pos->{y} == $pending->{portal_pos}{y};
	unless ($is_traversal) {
		clearPendingTraversal($pending->{attempt_id});
		return;
	}
	# The protocol reports a map change and coordinates, not which warp caused it.
	# Keep the destination position server-observed while labeling portal entry as
	# inferred from the owned portal, exact entry tile, source map, and destination.
	recordArrival($new_map, $x, $y,
		'inferred_portal_entry_from_server_observed_tile_and_map_change', $pending->{attempt_id});
	$state->{last_traversal} = {
		source_map => $old_map, destination_map => $new_map,
		attempt_id => $pending->{attempt_id}, time => time,
		confidence => 'inferred', evidence => 'owned_portal_tile_and_server_map_change',
	};
	clearPendingTraversal($pending->{attempt_id});
	return $state->{last_traversal};
}

sub recordArrival {
	my ($map, $x, $y, $source, $attempt_id) = @_;
	return unless $char && defined $x && defined $y;
	$map = normalizeWarpMap($map);
	return unless $map;
	my $state = _state() or return;
	$state->{observed_coordinates}{$map} = {
		x => 0 + $x, y => 0 + $y, source => $source || 'confirmed_portal_traversal',
		time => time, session => $state->{session},
	};
	my @matching = grep {
		my $entry = parseMemoEntry($config{"memo$_"});
		$entry->{valid} && $entry->{map} eq $map;
	} 1 .. 4;
	return unless $config{warpPortal_autoUpdateMemo} && @matching == 1;
	my $key = "memo$matching[0]";
	my $entry = parseMemoEntry($config{$key});
	return unless $entry->{valid} && $entry->{map} eq $map;
	_writeConfig($key, "$map $x $y") if !$entry->{has_coords} || $entry->{x} != $x || $entry->{y} != $y;
}

1;
