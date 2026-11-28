package WarpPortalTest;

use strict;
use Test::More;
use Globals;
use Misc;
use WarpPortal qw(
	parseMemoEntry normalizeWarpMap normalizeWarpMapName beginCharacterSession noteWarpCast
	noteMemoRequest memoAcknowledged updateServerMemos recordArrival
	availableWarpMaps warpMapIndex warpMapStatus memoCoordinateForMap
	noteWarpSelection confirmPortalArrival clearPendingTraversal memoRejected
	selectWarpPortalCastLevel
	noteWarpPortalUnitSeen noteWarpPortalMovement noteWarpPortalUnitDisappeared
	markCharacterMapTransfer clearCharacterMapTransfer
);

sub start {
	note('Starting ' . __PACKAGE__);
	__PACKAGE__->new->run;
}

sub new { return bless {}, $_[0] }

sub run {
	my ($self) = @_;
	my %old_maps_lut = %Globals::maps_lut;
	my %old_config = %Globals::config;
	my $old_char = $Globals::char;
	my $old_server = $Globals::masterServer;
	%Globals::maps_lut = (%old_maps_lut, map { ($_ . '.rsw') => 1 } qw(
		prontera geffen payon izlude moc_fild01 prt_fild08 alberta morocc stale_map
	));

	is(normalizeWarpMap('Geffen.gat'), 'geffen', 'normalizes a known server map');
	is(parseMemoEntry('geffen')->{map}, 'geffen', 'accepts a legacy map-only memo');
	ok(!parseMemoEntry('geffen')->{has_coords}, 'legacy memo coordinates remain unknown');
	is_deeply(parseMemoEntry('geffen 120 62'), {
		map => 'geffen', x => 120, y => 62, valid => 1, has_coords => 1,
	}, 'parses map and optional coordinates');
	ok(parseMemoEntry('unknown_map')->{valid}, 'accepts syntactically valid server map names without local map data');
	is(normalizeWarpMapName('Unknown_Map.gat'), 'unknown_map', 'normalizes unknown server map names syntactically');
	ok(!parseMemoEntry('geffen 12')->{valid}, 'rejects incomplete coordinate pairs');
	ok(!parseMemoEntry('geffen 70000 1')->{valid}, 'rejects coordinates outside protocol bounds');

	{
		no warnings 'redefine';
		local *Misc::configModify = sub {
			my ($key, $value) = @_;
			$Globals::config{$key} = $value;
		};
		$self->testSlotMovementAndDuplicateMemo;
		$self->testPartialCoverageAndStaleRemoval;
		$self->testCoordinateIdentityAndUnknowns;
		$self->testAuthoritativeOrderAndManualMode;
		$self->testMemoAcknowledgementAndTraversalCorrelation;
		$self->testCharacterSwitchAndAmbiguity;
		$self->testUnresolvedMapDoesNotCompactSlots;
		$self->testRejectedAndAmbiguousMemoAcknowledgements;
		$self->testUnknownSaveMapAndRouteCleanup;
		$self->testWarpPortalPlacement;
		$self->testCastLevelSelection;
		$self->testWarpPortalMenuCorrelation;
		$self->testXKoreWarpSelection;
		$self->testManualWarpSelectionSupersession;
		$self->testAggregatedAreaSpellWarpPortalObservation;
		$self->testWarpPortalActiveEntryTimeout;
		$self->testMapServerTransferKeepsPortalEvidence;
		$self->testWarpPortalFallbackClearsTransitionState;
		$self->testSameMapWarpPortalRouting;
		$self->testConfirmedArrivalWinsEntryTimeout;
		$self->testCalcMapRouteSearchRegression;
	}

	%Globals::maps_lut = %old_maps_lut;
	%Globals::config = %old_config;
	$Globals::char = $old_char;
	$Globals::masterServer = $old_server;
}

sub setupCharacter {
	%Globals::config = @_;
	$Globals::masterServer = {ip => '127.0.0.1', port => 6900};
	$Globals::char = {charID => "test-character"};
	beginCharacterSession();
}

sub captureWrites {
	my ($code) = @_;
	my @writes;
	{
		no warnings 'redefine';
		local *Misc::configModify = sub {
			my ($key, $value) = @_;
			push @writes, [$key, $value];
			$Globals::config{$key} = $value;
		};
		$code->();
	}
	return \@writes;
}

sub serverList {
	my ($level, @maps) = @_;
	noteWarpCast(27, $level);
	my %args = (type => 27);
	$args{"memo$_"} = $maps[$_ - 1] // '' for 1 .. 4;
	updateServerMemos(\%args);
}

sub testSlotMovementAndDuplicateMemo {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera 150 180', memo2 => 'geffen 120 62',
		memo3 => 'alberta 100 100', memo4 => 'payon 150 150',
	);
	my $writes = captureWrites(sub { serverList(4, qw(prontera geffen alberta payon)); });
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera 150 180', 'geffen 120 62', 'alberta 100 100', 'payon 150 150'],
		'level-four list preserves save point and memo coordinate pairs');
	is(scalar(@$writes), 0, 'unchanged authoritative list does not write configuration');

	$writes = captureWrites(sub {
		noteMemoRequest('morocc', 160, 90);
		memoAcknowledged(0);
	});
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera 150 180', 'morocc 160 90', 'geffen 120 62', 'alberta 100 100'],
		'successful /memo inserts a map-coordinate pair and drops the oldest point');
	serverList(4, qw(prontera morocc geffen alberta));

	$writes = captureWrites(sub {
		noteMemoRequest('geffen', 200, 40);
		memoAcknowledged(0);
	});
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera 150 180', 'geffen 200 40', 'morocc 160 90', 'alberta 100 100'],
		're-memorizing an existing map promotes it and updates its coordinates without duplication');
	serverList(4, qw(prontera geffen morocc alberta));
	is_deeply($Globals::char->{warpPortalState}{memo_maps}, [qw(geffen morocc alberta)],
		'next server list confirms the resulting order');
}

sub testPartialCoverageAndStaleRemoval {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'old_save 1 1', memo2 => 'geffen 2 2',
		memo3 => 'alberta 3 3', memo4 => 'payon 4 4',
	);
	updateServerMemos({type => 26, memo1 => 'random', memo2 => 'payon'});
	ok(!availableWarpMaps(), 'AL_TELEPORT menu is not treated as Warp Portal memo evidence');
	my %original = %Globals::config;
	serverList(1, 'prontera');
	is($Globals::config{memo1}, 'prontera', 'level one verifies and updates only save-point entry');
	is_deeply([@Globals::config{qw(memo2 memo3 memo4)}], [@original{qw(memo2 memo3 memo4)}],
		'level one does not invalidate unexposed memo slots');
	is(warpMapStatus('geffen', 2), 'unknown', 'unexposed higher slot remains unverified');
	serverList(2, qw(prontera geffen));
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera', 'geffen 2 2', $original{memo3}, $original{memo4}],
		'level two updates only its covered configuration fields');
	is(warpMapStatus('payon', 2), 'absent',
		'level-two list disproves a stale first memo destination within its coverage');
	is(warpMapStatus('payon', 4), 'unknown',
		'partial level-two list does not disprove a destination in a differently ordered higher slot');
	serverList(3, qw(prontera geffen alberta));
	is($Globals::config{memo3}, 'alberta 3 3', 'level three verifies second memo');
	serverList(4, qw(prontera geffen alberta));
	is($Globals::config{memo4}, '', 'complete level-four list clears confirmed empty third memo');
	is(warpMapStatus('payon', 4), 'absent', 'removed destination is not a route candidate');
	ok(!defined warpMapIndex('payon'), 'removed destination is absent from current runtime list');
}

sub testCoordinateIdentityAndUnknowns {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera 1 1', memo2 => 'geffen 20 21',
		memo3 => 'alberta 30 31', memo4 => 'payon 40 41',
	);
	serverList(4, qw(prontera payon geffen alberta));
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera 1 1', 'payon 40 41', 'geffen 20 21', 'alberta 30 31'],
		'coordinates follow unique map identities across server reordering');
	serverList(4, qw(prontera izlude geffen alberta));
	is($Globals::config{memo2}, 'izlude', 'newly discovered map remains map-only without fabricated coordinates');
	is(memoCoordinateForMap('izlude'), (), 'newly discovered map has no guessed coordinate');
	serverList(4, qw(prontera alberta geffen payon));
	is($Globals::config{memo2}, 'alberta 30 31', 'a later authoritative reorder reattaches trusted coordinates by map');
}

sub testAuthoritativeOrderAndManualMode {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'payon', memo3 => 'geffen', memo4 => 'alberta',
	);
	serverList(4, qw(prontera geffen alberta payon));
	is(warpMapIndex('payon'), 3, 'destination is found by map identity, independent of config order');
	is(warpMapIndex('geffen'), 1, 'server menu index identifies geffen by its actual name');

	setupCharacter(
		route_warpPortal => 0, warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'geffen 9 9', memo2 => 'payon 1 2', memo3 => 'geffen 3 4', memo4 => 'stale_map 7 8',
	);
	my @higher_before = @Globals::config{qw(memo2 memo3 memo4)};
	my $writes = captureWrites(sub { serverList(1, 'prontera'); });
	is($Globals::config{memo1}, 'prontera', 'level-one menu still synchronizes its authoritative memo name for a default-config user');
	is_deeply([@Globals::config{qw(memo2 memo3 memo4)}], \@higher_before,
		'level-one menu leaves unverified higher memo slots untouched');
	ok(@$writes, 'level-one menu writes only changed covered configuration entries');

	setupCharacter(
		route_warpPortal => 0, warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera 5 6', memo2 => 'payon 1 2', memo3 => 'geffen 3 4', memo4 => 'stale_map 7 8',
	);
	$writes = captureWrites(sub { serverList(4, qw(prontera geffen alberta payon)); });
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera 5 6', 'geffen 3 4', 'alberta', 'payon 1 2'],
		'level-four authoritative order synchronizes while manually configured coordinates follow unique maps');
	ok(@$writes, 'legacy memo-name synchronization remains active with route and coordinate auto-update disabled');
	is(warpMapIndex('payon'), 3, 'manual config order cannot select the wrong server destination');
	is(warpMapStatus('stale_map', 4), 'absent', 'stale manual map is not considered available');

	serverList(4, qw(prontera geffen alberta));
	is($Globals::config{memo4}, '', 'full-level empty memo slot clears a confirmed stale memo without auto coordinate persistence');
	serverList(4, qw(prontera izlude geffen alberta));
	is($Globals::config{memo2}, 'izlude', 'new server memo is synchronized as a map-only entry when coordinate learning is disabled');
	serverList(4, qw(prontera geffen geffen alberta));
	is_deeply([@Globals::config{qw(memo2 memo3)}], ['geffen', 'geffen'],
		'duplicate server destinations do not receive coordinates from a unique configured identity');

	setupCharacter(
		route_warpPortal => 0, warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'payon 1 2', memo3 => 'geffen 3 4', memo4 => 'alberta 5 6',
	);
	serverList(4, qw(prontera geffen alberta payon));
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}],
		['prontera', 'geffen 3 4', 'alberta 5 6', 'payon 1 2'],
		'coordinate auto-update enabled also preserves coordinates by unique map identity during reordering');
}

sub testMemoAcknowledgementAndTraversalCorrelation {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen 10 10', memo3 => 'alberta', memo4 => '',
	);
	my $writes = captureWrites(sub {
		noteMemoRequest('morocc', 160, 90);
		memoAcknowledged(1);
	});
	is(scalar(@$writes), 0, 'failed /memo acknowledgement does not rewrite configuration');
	$writes = captureWrites(sub {
		noteMemoRequest('morocc', 160, 90);
		memoAcknowledged(0);
	});
	is_deeply([@Globals::config{qw(memo2 memo3 memo4)}],
		['morocc 160 90', 'geffen 10 10', 'alberta'],
		'successful acknowledgement inserts the observed map and shifts configured map-coordinate pairs');

	$Globals::char->{ID} = 'test-character-id';
	$Globals::config{memo2} = 'geffen 10 10';
	$Globals::config{memo3} = '';
	my $unit;
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-first-use', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-first-use', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	ok(noteWarpPortalUnitSeen($unit, 'prontera'), 'first-use portal creation is observed with its owner and unit ID');
	ok(noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera'),
		'first-use movement reaches the exact portal tile');
	my $first_use = confirmPortalArrival('prontera', 'geffen', 120, 62);
	ok($first_use && $first_use->{attempt_id} eq 'attempt-first-use',
		'first-use traversal succeeds while the multi-use portal remains active');
	is($first_use->{confidence}, 'inferred', 'first-use cause remains explicitly inferred');
	is_deeply([memoCoordinateForMap('geffen')], [120, 62, 'inferred_portal_entry_from_owned_unit_movement_and_map_change'],
		'first-use memo learning uses only the server-reported map-change coordinates');
	is($Globals::config{memo2}, 'geffen 120 62', 'first-use arrival updates the unique memo map');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'successful first use clears only its matching attempt');
	$Globals::config{memo2} = 'geffen 100 100';
	$Globals::char->{warpPortalState}{observed_coordinates} = {};
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-wrong-tile', {x => 11, y => 10});
	ok(!noteWarpPortalUnitSeen({ID => 'wrong-tile-unit', sourceID => $Globals::char->{ID},
		type => 0x81, x => 12, y => 10}, 'prontera'), 'a portal at the wrong tile is not traversal evidence');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'a same-destination transition without the expected portal placement remains unattributed');
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-wrong-destination', {x => 11, y => 10});
	$unit = {ID => 'wrong-destination-unit', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	ok(!confirmPortalArrival('prontera', 'payon', 150, 150),
		'a valid portal attempt cannot be attached to the wrong destination map');
	is($Globals::config{memo2}, 'geffen 100 100', 'wrong-destination transition does not update memo coordinates');
	noteWarpSelection('geffen', 'prontera', 11, 10, 2, 'attempt-a', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-a', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	ok(noteWarpPortalUnitSeen($unit, 'prontera'), 'server-observed owned portal unit is tied to the active attempt');
	my $before = $Globals::config{memo3};
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'a map change without accepted movement is not attributed');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'unrelated arrival clears the pending portal attempt');
	is($Globals::config{memo3}, $before, 'unrelated arrival cannot update memo coordinates');

	# The movement packet is server evidence that the character is moving onto
	# the exact portal tile, even when the local current position is one step stale.
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-b', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-b', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	ok(noteWarpPortalUnitSeen($unit, 'prontera'), 'owned portal creation is observed before movement');
	ok(!noteWarpPortalUnitSeen({%$unit, ID => 'replacement-unit'}, 'prontera'),
		'a different portal unit at the same tile cannot replace the matched portal identity');
	is($Globals::char->{warpPortalPendingTraversal}{portal_unit_id}, $unit->{ID},
		'portal correlation retains the original observed unit ID');
	ok(noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera'),
		'server movement packet records exact movement onto the portal despite stale current position');
	ok(!noteWarpPortalUnitDisappeared({%$unit, ID => 'other-unit', pos => {x => 11, y => 10}}, 'prontera'),
		'disappearance of a different portal unit cannot complete the attempt');
	ok(noteWarpPortalUnitDisappeared({%$unit, pos => {x => 11, y => 10}}, 'prontera'),
		'disappearance of the same owned portal after movement completes traversal evidence');
	my $disappeared_at = $Globals::char->{warpPortalPendingTraversal}{portal_disappeared_at};
	ok(noteWarpPortalUnitDisappeared({%$unit, pos => {x => 11, y => 10}}, 'prontera'),
		'duplicate disappearance notifications are idempotent');
	is($Globals::char->{warpPortalPendingTraversal}{portal_disappeared_at}, $disappeared_at,
		'duplicate disappearance does not extend the correlation window');
	$Globals::config{memo2} = 'geffen 100 100';
	$Globals::config{memo3} = '';
	my $arrival = confirmPortalArrival('prontera', 'geffen', 120, 62);
	ok($arrival && $arrival->{attempt_id} eq 'attempt-b', 'arrival is correlated to the live attempt');
	is($arrival->{confidence}, 'inferred',
		'portal attribution remains inferred because map-change packets do not identify the warp source');
	is_deeply([memoCoordinateForMap('geffen')], [120, 62, 'inferred_portal_entry_from_owned_unit_movement_and_map_change'],
		'landing coordinates come from server map-change coordinates, not the stale source position');
	is($Globals::config{memo2}, 'geffen 120 62', 'inferred genuine arrival updates the uniquely matched memo');

	delete $Globals::char->{warpPortalState}{last_traversal};
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-c', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-c', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'same-destination map transition without movement onto the portal is not attributed');
	ok(!$Globals::char->{warpPortalState}{last_traversal}, 'ambiguous same-destination transition creates no traversal record');

	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-delayed-disappear', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-late', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	my $last_use = confirmPortalArrival('prontera', 'geffen', 120, 62);
	ok($last_use && $last_use->{attempt_id} eq 'attempt-delayed-disappear',
		'last-use traversal is accepted even when disappearance has not arrived yet');
	ok(!noteWarpPortalUnitDisappeared({%$unit, pos => {x => 11, y => 10}}, 'prontera'),
		'delayed disappearance after successful transition cannot reuse the cleared attempt');
	ok($Globals::char->{warpPortalState}{last_traversal}{attempt_id} eq 'attempt-delayed-disappear',
		'delayed disappearance cannot complete the same traversal twice');

	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-d', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-d', sourceID => 'another-character', type => 0x81, x => 11, y => 10};
	ok(!noteWarpPortalUnitSeen($unit, 'prontera'), 'portal created by another character is not owned evidence');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'same-destination change after an unrelated portal is not attributed');

	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-e', {x => 11, y => 10});
	$Globals::char->{warpPortalPendingTraversal}{selected_at} = time - 121;
	ok(!noteWarpPortalUnitSeen({ID => 'expired-unit', sourceID => $Globals::char->{ID},
		type => 0x81, x => 11, y => 10}, 'prontera'), 'expired attempts cannot acquire new portal evidence');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'expired traversal state is cleared before a later map change');

	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-f', {x => 11, y => 10});
	beginCharacterSession();
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'character-session changes clear pending portal correlation');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62), 'old-session evidence cannot confirm a new-session arrival');

	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-disconnect', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-disconnect', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	beginCharacterSession();
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'disconnect during traversal drops the prior session evidence');

	setupCharacter(
		warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen 10 10', memo3 => '', memo4 => '',
	);
	$writes = captureWrites(sub { recordArrival('geffen', 120, 62, 'test_arrival'); });
	is(scalar(@$writes), 0, 'disabled sync keeps manual coordinates unchanged');
	is_deeply([memoCoordinateForMap('geffen')], [120, 62, 'test_arrival'],
		'runtime arrival observation remains usable with config synchronization disabled');
}

sub testCalcMapRouteSearchRegression {
	require Task::CalcMapRoute;
	my ($task, $sliced);
	{
		no warnings 'redefine';
		local *Field::new = sub {
			my ($class, %args) = @_;
			return bless {map => $args{name}}, 'WarpPortalTest::MapField';
		};
		$task = Task::CalcMapRoute->new(
			sourceMap => 'prontera', sourceX => 1, sourceY => 1,
			map => 'geffen', x => 120, y => 62,
			noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1, noAirship => 1,
		);
		$sliced = Task::CalcMapRoute->new(
			sourceMap => 'prontera', sourceX => 1, sourceY => 1,
			map => 'geffen', x => 120, y => 62,
			noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1, noAirship => 1,
			maxTime => 1,
		);
	}
	$task->{targets}[0]{field} = bless({}, 'WarpPortalTest::LargeField');
	# The real Prontera -> Payon fixture has two candidate paths to the same
	# reached-target key. The direct Kafra candidate costs 72 before the final
	# 500-step walk (572 total); the Alberta detour costs 476 + 500 (976).
	$task->{targets}[0] = {map => 'payon', x => 20, y => 20, field => bless({}, 'WarpPortalTest::LargeField')};
	my $cheap = 'prontera 146 89=payon 161 58';
	my $dear = 'alberta 117 56=payon 161 58';
	$task->{openlist} = {
		$cheap => {walk => 72, zeny => 0, portal_string => $cheap, blockedPortalGroups => {}},
		$dear => {walk => 476, zeny => 0, portal_string => $dear, blockedPortalGroups => {}},
	};
	$task->{openlist_heap} = [[72, $cheap], [476, $dear]];
	$task->{closelist} = {};
	$task->{solution} = [];
	$task->{budget} = '';
	$task->{noGoCommand} = 1;
	$task->{noTeleSpawn} = 1;
	$task->{noWarpItem} = 1;
	$task->{SyntheticPortals} = {};
	{
		no warnings 'redefine';
		local %Globals::portals_los = ();
		local *Task::CalcMapRoute::resolveRouteDestinationEntry = sub {
			return {map => 'payon', x => 161, y => 58};
		};
		local *Task::Route::getRoute = sub {
			my ($class, $solution) = @_;
			@{$solution} = (1) x 500;
			return 1;
		};
		$task->searchStep() while !$task->{done};
	}
	is($task->{mapSolution}[-1]{walk}, 572,
		'Prontera to Payon selects the 572-cost direct route over the 976-cost Alberta detour');
	is($task->{mapSolution}[0]{portal}, $cheap,
		'a more expensive candidate sharing the Payon target key cannot overwrite the best route');

	my $estimated_portal = 'prontera 10 10=geffen';
	my $unknown_landing = bless {
		openlist => {$estimated_portal => {walk => 842, zeny => 0, is_warpPortal => 1}},
		openlist_heap => [[842, $estimated_portal]], closelist => {},
		targets => [{map => 'geffen', x => 120, y => 62, field => bless({}, 'WarpPortalTest::LargeField')}],
		solution => [1, 2, 3], budget => '', noGoCommand => 1,
		noTeleSpawn => 1, noWarpItem => 1, SyntheticPortals => {},
	}, 'Task::CalcMapRoute';
	$unknown_landing->{SyntheticPortals}{tempWarpPortal}{geffen}{dest}{geffen} = {
		map => 'geffen', enabled => 1,
	};
	$unknown_landing->searchStep();
	is_deeply([map { $_->{walk} } @{$unknown_landing->{mapSolution}}], [842],
		'unknown-landing estimate is charged on the Warp Portal node exactly once');

	my $resumable;
	{
		no warnings 'redefine';
		local *Field::new = sub {
			my ($class, %args) = @_;
			return bless {map => $args{name}}, 'WarpPortalTest::MapField';
		};
		$resumable = Task::CalcMapRoute->new(
			sourceMap => 'prontera', sourceX => 1, sourceY => 1,
			map => 'geffen', x => 120, y => 62,
			noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1, noAirship => 1,
			maxTime => 1,
		);
	}
	$resumable->{stage} = 2;
	$resumable->{targets}[0]{field} = bless({}, 'WarpPortalTest::LargeField');
	my $intermediate = 'prontera 1 1=morocc 10 10';
	$resumable->{openlist} = {
		$intermediate => {walk => 100, zeny => 0, portal_string => $intermediate, blockedPortalGroups => {}},
		$dear => {walk => 110, zeny => 0, portal_string => $dear, blockedPortalGroups => {}},
	};
	$resumable->{openlist_heap} = [[100, $intermediate], [110, $dear]];
	$resumable->{closelist} = {};
	$resumable->{solution} = [];
	$resumable->{budget} = '';
	$resumable->{SyntheticPortals} = {};
	$resumable->activate();
	{
		no warnings 'redefine';
		my $timeout_checks = 0;
		local %Globals::portals_los = ();
		local *Task::CalcMapRoute::resolveRouteDestinationEntry = sub {
			my ($self, undef, $destination) = @_;
			return {map => $destination =~ /^morocc/ ? 'morocc' : 'geffen', x => 20, y => 20};
		};
		local *Task::Route::getRoute = sub {
			my ($class, $solution) = @_;
			@{$solution} = (1) x 50;
			return 1;
		};
		local *Task::CalcMapRoute::timeOut = sub { ++$timeout_checks >= 2 };
		$resumable->iterate();
	}
	is($resumable->getStatus(), Task::RUNNING,
		'a small maxTime slice with work remaining leaves the calculation resumable');
	ok(!@{$resumable->getRoute()}, 'an incomplete slice does not expose a false successful solution');
	{
		no warnings 'redefine';
		local %Globals::portals_los = ();
		local *Task::CalcMapRoute::resolveRouteDestinationEntry = sub {
			return {map => 'geffen', x => 20, y => 20};
		};
		local *Task::Route::getRoute = sub {
			my ($class, $solution) = @_;
			@{$solution} = (1) x 50;
			return 1;
		};
		local *Task::CalcMapRoute::timeOut = sub { 0 };
		$resumable->iterate();
	}
	is($resumable->getStatus(), Task::DONE, 'a later time slice resumes the remaining search safely');
	is($resumable->getRoute()->[-1]{walk}, 160, 'resumed route includes the final target walk exactly once');

	$sliced->{targets}[0]{field} = bless({}, 'WarpPortalTest::LargeField');
	$sliced->{stage} = 2;
	$sliced->{openlist} = {
		$cheap => {walk => 100, zeny => 0, portal_string => $cheap, blockedPortalGroups => {}},
	};
	$sliced->{openlist_heap} = [[100, $cheap]];
	$sliced->{closelist} = {};
	$sliced->{solution} = [];
	$sliced->{budget} = '';
	$sliced->{SyntheticPortals} = {};
	$sliced->activate();
	{
		no warnings 'redefine';
		my $timeout_checks = 0;
		local %Globals::portals_los = ();
		local *Task::CalcMapRoute::resolveRouteDestinationEntry = sub {
			return {map => 'geffen', x => 20, y => 20};
		};
		local *Task::Route::getRoute = sub {
			my ($class, $solution) = @_;
			@{$solution} = (1) x 50;
			return 1;
		};
		local *Task::CalcMapRoute::timeOut = sub { ++$timeout_checks >= 2 };
		$sliced->iterate();
	}
	is($sliced->getStatus(), Task::DONE, 'a one-step maxTime slice completes only after route reconstruction');
	ok(@{$sliced->getRoute()}, 'successful time-sliced calculations always contain the reconstructed solution');
	is($sliced->getRoute()->[-1]{walk}, 150, 'the interrupted-calculation resume preserves cumulative route cost');
}

sub testCharacterSwitchAndAmbiguity {
	setupCharacter(
		warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen', memo3 => 'alberta', memo4 => '',
	);
	serverList(4, qw(prontera geffen alberta));
	$Globals::char = {charID => "another-character"};
	beginCharacterSession();
	ok(!availableWarpMaps(), 'character switch clears prior character menu verification');
	serverList(4, qw(prontera geffen geffen));
	ok(!defined warpMapIndex('geffen'), 'duplicate server names are ambiguous for selection');
	is(warpMapStatus('geffen', 2), 'ambiguous', 'duplicate menu entries remain explicitly ambiguous');
	ok(!defined scalar memoCoordinateForMap('geffen'), 'duplicate local map names do not yield a guessed coordinate');
	ok($Globals::char->{warpPortalState}{list_ambiguous}, 'duplicate compact list is marked ambiguous');
}

sub testUnresolvedMapDoesNotCompactSlots {
	for my $auto_update (0, 1) {
		setupCharacter(
			warpPortal_autoUpdateMemo => $auto_update, saveMap => 'prontera',
			memo1 => 'prontera', memo2 => 'geffen 20 21',
			memo3 => 'alberta 30 31', memo4 => 'payon 40 41',
		);
		serverList(4, 'prontera', 'custom_unknown_map', 'alberta', 'payon');
		is_deeply($Globals::char->{warpPortalState}{available_maps},
			['prontera', 'custom_unknown_map', 'alberta', 'payon'],
			"unsupported map remains in authoritative slot with auto-update $auto_update");
		is(warpMapIndex('alberta'), 2, 'a later known destination keeps its actual server index');
		is($Globals::config{memo2}, 'custom_unknown_map',
			"unknown valid server map replaces the stale configured name without auto-update $auto_update");
		ok(!parseMemoEntry($Globals::config{memo2})->{has_coords},
			'coordinates from the replaced known map are not attached to the unknown destination');
		is($Globals::config{memo3}, 'alberta 30 31',
			'known map after an unresolved slot retains its own coordinates');

		# A later level-one list does not cover memo2. Its old value must be the
		# unknown authoritative map, not Geffen, so historical hints cannot revive it.
		serverList(1, 'prontera');
		is($Globals::config{memo2}, 'custom_unknown_map',
			'uncovered higher memo retains the last authoritative unknown map name');
		is(warpMapStatus('geffen', 2), 'unknown',
			'lower-level menu leaves unverified destinations unknown without restoring the removed map');
		ok(!defined(memoCoordinateForMap('custom_unknown_map')),
			'unknown map has no coordinates inherited from the replaced destination');

		require Task::CalcMapRoute;
		$Globals::config{route_warpPortal} = 1;
		$Globals::char = bless {
			learned => 4, sp => 100,
			inventory => bless({amount => 1}, 'WarpPortalTest::Inventory'),
		}, 'WarpPortalTest::Character';
		$Globals::char->{ID} = 'unknown-memo-planner';
		my $planner = bless {
			source => {map => 'prontera'}, targets => [], noWarpPortalMaps => {},
			routeWeightCache => {WARPPORTAL => 200}, mapRouteWeightCache => {},
			SyntheticPortals => {},
		}, 'Task::CalcMapRoute';
		{
			no warnings 'redefine';
			local *Field::new = sub {
				my %args = @_[1 .. $#_];
				return if $args{name} eq 'custom_unknown_map';
				return bless({map => $args{name}}, 'WarpPortalTest::LargeField');
			};
			local *Task::CalcMapRoute::getMapRouteWeight = sub { 0 };
			local *Task::CalcMapRoute::getRouteWeight = sub { 0 };
			local *Task::CalcMapRoute::buildRouteStateKey = sub { $_[1] };
			local *Task::CalcMapRoute::canAddOpenListEntry = sub { 1 };
			local *Task::CalcMapRoute::cloneBlockedPortalGroups = sub { {} };
			local *Task::CalcMapRoute::buildRouteValue = sub { {} };
			local *Task::CalcMapRoute::registerSyntheticPortalDestination = sub { 1 };
			local *Task::CalcMapRoute::add_key_to_openList = sub {
				$_[0]{candidateKeys}{$_[1]} = 1;
			};
			local *Misc::_isTeleportSkillSuppressedByStatus = sub { 0 };
			$planner->populateOpenListWithWarpPortal('prontera 1 1',
				{walk => 0, zeny => 0, blockedPortalGroups => {}}, undef);
		}
		ok(!grep(/geffen/, keys %{$planner->{candidateKeys} || {}}),
			'planner cannot resurrect Geffen from config after authoritative removal');
		ok(!grep(/custom_unknown_map/, keys %{$planner->{candidateKeys} || {}}),
			'unknown map without local field data is not offered for pathfinding');
	}

	setupCharacter(warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen 20 21');
	serverList(4, 'prontera', 'bad/map', 'alberta', 'payon');
	is($Globals::config{memo2}, 'geffen 20 21',
		'malformed server map content is not treated as an authoritative replacement');
}

sub testRejectedAndAmbiguousMemoAcknowledgements {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen 10 10', memo3 => '', memo4 => '',
	);
	noteMemoRequest('moc_fild01', 10, 20);
	memoRejected();
	noteMemoRequest('geffen', 30, 40);
	memoAcknowledged(0);
	ok(!exists $Globals::char->{warpPortalState}{observed_coordinates}{geffen},
		'rejected /memo leaves a later acknowledgement unassociated until server reconciliation');
	ok(!exists $Globals::char->{warpPortalState}{observed_coordinates}{moc_fild01},
		'rejected memo map receives no inferred coordinates');
	serverList(4, 'prontera', 'geffen', 'alberta', 'payon');
	ok(!$Globals::char->{warpPortalState}{memo_ack_uncertain},
		'authoritative Warp Portal list reconciles rejected-request acknowledgement ambiguity');

	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '',
	);
	noteMemoRequest('geffen', 5, 6);
	noteMemoRequest('alberta', 7, 8);
	memoAcknowledged(0);
	ok(!exists $Globals::char->{warpPortalState}{observed_coordinates}{alberta},
		'repeated outstanding /memo requests make the next acknowledgement ambiguous');
	serverList(4, 'prontera', 'geffen', 'alberta', 'payon');
	noteMemoRequest('alberta', 7, 8);
	$Globals::char->{warpPortalState}{pending_memo}{time} = time - 31;
	memoAcknowledged(0);
	ok(!exists $Globals::char->{warpPortalState}{observed_coordinates}{alberta},
		'expired memo request cannot donate coordinates to a delayed acknowledgement');

	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '',
	);
	noteMemoRequest('geffen', 10, 10);
	$Globals::char->{warpPortalState}{pending_memo}{time} = time - 31;
	noteMemoRequest('alberta', 20, 20);
	memoAcknowledged(0);
	is($Globals::char->{warpPortalState}{observed_coordinates}{alberta}, undef,
		'a delayed acknowledgement after timeout is not attached to a later request');
	serverList(4, qw(prontera geffen alberta));
	ok(!$Globals::char->{warpPortalState}{memo_ack_uncertain},
		'authoritative server list clears uncertain memo acknowledgement state');

	setupCharacter(
		warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => '', memo2 => '', memo3 => '', memo4 => '',
	);
	serverList(4, qw(prontera geffen alberta payon));
	is(warpMapIndex('alberta'), 2,
		'verified runtime server destinations remain indexed when config sync is disabled and memo entries are empty');
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}], [qw(prontera geffen alberta payon)],
		'legacy config memo names synchronize from full coverage without requiring route or coordinate auto-update');

	noteWarpSelection('geffen', 'prontera', 10, 10, 2, 'owned-attempt');
	clearPendingTraversal(undef);
	ok($Globals::char->{warpPortalPendingTraversal},
		'undefined route owner cannot clear a pending traversal');
	clearPendingTraversal('unrelated-attempt');
	ok($Globals::char->{warpPortalPendingTraversal},
		'unrelated route owner cannot clear a pending traversal');
	clearPendingTraversal('owned-attempt');
	ok(!$Globals::char->{warpPortalPendingTraversal},
		'matching route owner can clear its pending traversal');

	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => '', memo2 => '', memo3 => '', memo4 => '');
	noteWarpCast(27, 4, 33, 44);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	is_deeply($Globals::char->{warpPortalState}{last_portal_cast}{portal_pos}, {x => 33, y => 44},
		'manual cast target survives the authoritative menu response for portal correlation');
	noteWarpSelection('geffen', 'prontera', 30, 40, 4, undef, {x => 33, y => 44});
	my $manualAttempt = $Globals::char->{warpPortalPendingTraversal}{attempt_id};
	ok($manualAttempt && $manualAttempt =~ /^manual-/,
		'manual portal selection receives an owner ID for safe cleanup');
	clearPendingTraversal($manualAttempt);
	ok(!$Globals::char->{warpPortalPendingTraversal},
		'manual traversal cleanup remains owner-aware');
}

sub testUnknownSaveMapAndRouteCleanup {
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera', saveMap_x => 150, saveMap_y => 180,
		memo1 => 'prontera 150 180', memo2 => 'geffen 20 21', memo3 => '', memo4 => '',
	);
	serverList(1, 'custom_unknown_map');
	is($Globals::config{saveMap}, 'custom_unknown_map',
		'authoritative unknown save-map name is retained without local field data');
	is_deeply([@Globals::config{qw(saveMap_x saveMap_y)}], ['', ''],
		'coordinates for a different prior save map are cleared');
	is($Globals::char->{warpPortalState}{unresolved_slots}{1}, 1,
		'unknown memo slot is marked unresolved and cannot shift neighboring coordinates');

	require Task::MapRoute;
	my $mapRoute = bless {noWarpPortalMaps => {prontera => time - 700}}, 'Task::MapRoute';
	Task::MapRoute::prunePerMapBlocks($mapRoute);
	ok(!exists $mapRoute->{noWarpPortalMaps}{prontera},
		'expired Warp Portal route blocks are pruned with other per-map failures');

	setupCharacter(
		warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '',
	);
	noteWarpSelection('geffen', 'prontera', 10, 10, 2, 'manual-attempt');
	my $unowned = bless {}, 'Task::MapRoute';
	$unowned->DESTROY();
	ok($Globals::char->{warpPortalPendingTraversal},
		'destroying an unrelated MapRoute with no attempt ID preserves another route traversal');
	my $otherRoute = bless {warpPortalAttemptID => 'other-attempt'}, 'Task::MapRoute';
	$otherRoute->DESTROY();
	ok($Globals::char->{warpPortalPendingTraversal},
		'destroying a MapRoute with a different attempt ID preserves the pending traversal');
	clearPendingTraversal('manual-attempt');
}

sub testWarpPortalPlacement {
	require Task::MapRoute;
	require Task::CalcMapRoute;
	my $calculator = bless {}, 'Task::CalcMapRoute';
	my $step = $calculator->buildMapSolutionStep('prontera 10 10=geffen 20 20', {
		portal_string => 'prontera 10 10=geffen 20 20', walk => 1, zeny => 0,
		amount_of_tickets_used => 0, is_warpPortal => 1, warpPortalMemoSlot => 2,
		warpPortalCastLevel => 3,
	});
	is($step->{warpPortalCastLevel}, 3,
		'planned minimum Warp Portal level survives serialization into the executable route step');
	is($step->{warpPortalMemoSlot}, 2,
		'planned server slot remains paired with its cast-level requirement');
	my $field = bless {}, 'WarpPortalTest::Field';
	my $actor = {pos => {x => 20, y => 20}, pos_to => {x => 19, y => 20}};
	my $route = bless {actor => $actor}, 'Task::MapRoute';
	local $Globals::field = $field;
	local @Globals::playersID = ('blocker');
	local %Globals::players = (blocker => {pos_to => {x => 19, y => 19}});
	local @Globals::monstersID = ();
	local %Globals::monsters = ();
	local @Globals::petsID = ();
	local %Globals::pets = ();
	local @Globals::slavesID = ();
	local %Globals::slaves = ();
	local @Globals::elementalsID = ();
	local %Globals::elementals = ();
	local @Globals::spellsID = ();
	local %Globals::spells = ();
	local $Task::MapRoute::field = $field;
	local $Task::MapRoute::char = $Globals::char;
	local @Task::MapRoute::playersID = ('blocker');
	local %Task::MapRoute::players = (blocker => {pos_to => {x => 19, y => 19}});
	local @Task::MapRoute::monstersID = ();
	local %Task::MapRoute::monsters = ();
	local @Task::MapRoute::petsID = ();
	local %Task::MapRoute::pets = ();
	local @Task::MapRoute::slavesID = ();
	local %Task::MapRoute::slaves = ();
	local @Task::MapRoute::elementalsID = ();
	local %Task::MapRoute::elementals = ();
	local @Task::MapRoute::spellsID = ();
	local %Task::MapRoute::spells = ();
	{
		no warnings 'redefine';
		local *Task::Route::getRoute = sub { return 1; };
		my $placement = $route->findWarpPortalPlacement(bless({}, 'WarpPortalTest::Skill'), 1);
		ok($placement && ($placement->{x} != $actor->{pos}{x} || $placement->{y} != $actor->{pos}{y}),
			'portal placement is a reachable target cell separate from the standing caster');
		ok($placement && ($placement->{x} != 19 || $placement->{y} != 19),
			'placement avoids a tile occupied by another character');
		ok($placement && ($placement->{x} != 19 || $placement->{y} != 20),
			'placement avoids the caster current movement target as well as observed occupancy');
	}
}

sub testCastLevelSelection {
	require Task::UseSkill;
	require Skill;
	local %Skill::StaticInfo::ids = (27 => {handle => 'AL_WARP'});
	local %Skill::StaticInfo::handles = (AL_WARP => 27);
	local %Skill::StaticInfo::sps = (AL_WARP => [35, 32, 29, 26]);
	my $skill = Skill->new(idn => 27);
	is_deeply([map { $skill->getSP($_) } 1 .. 4], [35, 32, 29, 26],
		'Warp Portal level costs come from the existing Skill SP API');
	is(selectWarpPortalCastLevel($skill, 1, 4, 30), 4,
		'level-four character with 30 SP selects affordable level four for a level-one destination');
	is(selectWarpPortalCastLevel($skill, 3, 4, 28), 4,
		'selected cast level still covers the actual server menu slot');
	ok(!defined selectWarpPortalCastLevel($skill, 1, 4, 25),
		'route is excluded when every eligible level is unaffordable');
	ok(!defined selectWarpPortalCastLevel($skill, 3, 2, 100),
		'route is excluded when learned level cannot cover the destination slot');

	local %Skill::StaticInfo::sps = (AL_WARP => [28, 25, 12, 20]);
	is(selectWarpPortalCastLevel($skill, 1, 4, 15), 3,
		'custom server costs select the cheapest affordable learned level');
	local %Skill::StaticInfo::sps = (AL_WARP => [35, 32, 29, 26]);

	require Task::CalcMapRoute;
	setupCharacter(route_warpPortal => 1, warpPortal_autoUpdateMemo => 0,
		saveMap => 'prontera', memo1 => '', memo2 => '', memo3 => '', memo4 => '');
	$Globals::char = bless {
		charID => 'planner-char', learned => 4, sp => 30,
		inventory => bless({amount => 1}, 'WarpPortalTest::Inventory'),
	}, 'WarpPortalTest::Character';
	beginCharacterSession();
	serverList(4, qw(prontera geffen));
	my $planner = bless {
		source => {map => 'prontera'}, targets => [{map => 'geffen', x => 120, y => 62}], noWarpPortalMaps => {},
	}, 'Task::CalcMapRoute';
	my $base_cost = {walk => 0, zeny => 0, blockedPortalGroups => {}};
	{
		no warnings 'redefine';
		local *Field::new = sub { bless {}, 'WarpPortalTest::Field' };
		local *Task::CalcMapRoute::getMapRouteWeight = sub { 0 };
		local *Task::CalcMapRoute::getRouteWeight = sub { 0 };
		local *Task::CalcMapRoute::buildRouteStateKey = sub { 'warp-portal-test' };
		local *Task::CalcMapRoute::canAddOpenListEntry = sub { $_[0]{last_route_cost} = $_[2]; 1 };
		local *Task::CalcMapRoute::cloneBlockedPortalGroups = sub { {} };
		local *Task::CalcMapRoute::buildRouteValue = sub { {} };
		local *Task::CalcMapRoute::registerSyntheticPortalDestination = sub { 1 };
		local *Task::CalcMapRoute::add_key_to_openList = sub { $_[0]{candidate} = $_[2] };
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $base_cost, undef);
		is_deeply([@{$planner->{candidate}}{qw(warpPortalMinLevel warpPortalCastLevel warpPortalMemoSlot)}], [2, 4, 1],
			'route planner selects affordable level four for the level-two server slot and preserves its index');
		is($planner->{last_route_cost}, 42,
			'a server-confirmed destination without coordinates receives the bounded field-span estimate');
		$Globals::char->{sp} = 25;
		delete $planner->{candidate};
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $base_cost, undef);
		ok(!$planner->{candidate}, 'route planner omits Warp Portal when every eligible level exceeds available SP');

		setupCharacter(route_warpPortal => 1, warpPortal_autoUpdateMemo => 0,
			saveMap => 'prontera', memo1 => 'prontera 10 10', memo2 => 'geffen 20 21', memo3 => '', memo4 => '');
		$Globals::char = bless {
			charID => 'partial-menu-char', learned => 4, sp => 100,
			inventory => bless({amount => 1}, 'WarpPortalTest::Inventory'),
		}, 'WarpPortalTest::Character';
		beginCharacterSession();
		serverList(1, 'prontera');
		delete $planner->{candidate};
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $base_cost, undef);
		is_deeply([@{$planner->{candidate}}{qw(warpPortalMinLevel warpPortalCastLevel warpPortalMemoSlot)}],
			[2, 4, undef], 'a lower-level menu keeps a unique higher-level memo hint speculative and routable');
		is(warpMapStatus('geffen', 2), 'unknown',
			'the partial menu does not promote the higher memo hint to verified server state');
		is($Globals::config{memo2}, 'geffen 20 21',
			'runtime discovery remains usable when automatic memo synchronization is disabled');
		is($planner->{last_route_cost}, 2,
			'configured but unverified coordinates remain a route estimate without becoming authoritative');
		$Globals::config{memo3} = 'geffen 30 31';
		delete $planner->{candidate};
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $base_cost, undef);
		ok(!$planner->{candidate}, 'duplicate speculative memo names are excluded from route candidates');

		setupCharacter(route_warpPortal => 1, warpPortal_autoUpdateMemo => 0,
			saveMap => 'prontera', memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '');
		$Globals::char = bless {
			charID => 'unknown-coordinate-char', learned => 4, sp => 100,
			inventory => bless({amount => 1}, 'WarpPortalTest::Inventory'),
		}, 'WarpPortalTest::Character';
		beginCharacterSession();
		serverList(1, 'prontera');
		$planner->{targets} = [{map => 'geffen'}];
		delete @{$planner}{qw(candidate last_route_cost)};
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $base_cost, undef);
		is($planner->{last_route_cost}, 2,
			'map-only objectives do not pay a post-arrival walking estimate for unknown memo coordinates');

		my $map_only_node = 'prontera 156 190=alberta';
		my $map_only_search = bless {
			openlist => {$map_only_node => {walk => 2, zeny => 0, is_warpPortal => 1}},
			openlist_heap => [[2, $map_only_node]], closelist => {}, targets => [{map => 'alberta', pos => {}}],
			solution => [], budget => '', noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1,
			SyntheticPortals => {},
		}, 'Task::CalcMapRoute';
		$map_only_search->{SyntheticPortals}{tempWarpPortal}{alberta}{dest}{alberta} = {
			map => 'alberta', enabled => 1,
		};
		$map_only_search->searchStep() while !$map_only_search->{done};
		ok($map_only_search->{done} && $map_only_search->{found},
			'map-only Warp Portal destination resolves as a route to a map objective');
		ok($map_only_search->{mapSolution}[0]{is_warpPortal},
			'route search selects the speculative map-only Warp Portal step');

		my $unknownLanding = 'prontera 156 190=unknown_geffen';
		my $knownLanding = 'prontera 146 89=known_geffen';
		my $cost_search = bless {
			openlist => {
				$unknownLanding => {walk => 1002, zeny => 0, is_warpPortal => 1},
				$knownLanding => {walk => 401, zeny => 0, is_warpPortal => 0},
			},
			openlist_heap => [[401, $knownLanding], [1002, $unknownLanding]], closelist => {},
			targets => [{map => 'geffen', x => 120, y => 62, field => bless({}, 'WarpPortalTest::LargeField')}],
			solution => [], budget => '', noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1,
			SyntheticPortals => {},
		}, 'Task::CalcMapRoute';
		{
			no warnings 'redefine';
			local %Globals::portals_los = ();
			local *Task::CalcMapRoute::resolveRouteDestinationEntry = sub {
				my ($self, undef, $destination) = @_;
				return $destination eq 'unknown_geffen'
					? {map => 'geffen'} : {map => 'geffen', x => 120, y => 39};
			};
			local *Task::Route::getRoute = sub { return 1; };
			$cost_search->searchStep() while !$cost_search->{done};
		}
		ok(!grep($_->{is_warpPortal}, @{$cost_search->{mapSolution}}),
			'route search keeps the conventional path when its cost beats the unknown-landing Warp Portal estimate');

	}

	{
		no warnings 'redefine';
		local *Field::new = sub {
			my ($class, %args) = @_;
			return bless {map => $args{name}}, 'WarpPortalTest::MapField';
		};
		my $same_map_objective = Task::CalcMapRoute->new(
			sourceMap => 'alberta', sourceX => 192, sourceY => 183,
			map => 'alberta', suppressDebug => 1,
			noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1, noAirship => 1,
		);
		$same_map_objective->activate();
		$same_map_objective->iterate() while $same_map_objective->getStatus() != Task::DONE;
		ok(!$same_map_objective->getError(),
			'a map-only objective completes after arriving on its requested map');
		is_deeply($same_map_objective->getRoute(), [],
			'a reached map-only objective returns an empty remaining route');
	}

	is(Task::CalcMapRoute::_warpPortalUnknownLandingEstimate(bless({}, 'Task::CalcMapRoute'),
		bless({}, 'WarpPortalTest::LargeField')), 800,
		'unknown-coordinate estimate scales with map span rather than total map tile count');
	is(Task::CalcMapRoute::_warpPortalUnknownLandingEstimate(bless({}, 'Task::CalcMapRoute'),
		bless({}, 'WarpPortalTest::Field')), 40,
		'small destination maps receive a proportionally smaller unknown-landing estimate');
	is(Task::CalcMapRoute::_warpPortalUnknownLandingEstimate(bless({}, 'Task::CalcMapRoute'), undef), 0,
		'missing field data does not invent an unknown-coordinate estimate');

	my $calculator = bless {}, 'Task::CalcMapRoute';
	my $step = $calculator->buildMapSolutionStep('prontera 10 10=geffen 20 20', {
		portal_string => 'prontera 10 10=geffen 20 20', walk => 1, zeny => 0,
		amount_of_tickets_used => 0, is_warpPortal => 1, warpPortalMemoSlot => 0,
		warpPortalMinLevel => 1, warpPortalCastLevel => 4,
	});
	is($step->{warpPortalMinLevel}, 1, 'route step retains the destination minimum skill level');
	is($step->{warpPortalCastLevel}, 4, 'route step carries the affordable selected cast level');
	is($step->{warpPortalMemoSlot}, 0, 'cast-level choice does not alter the server menu slot');

	my $char = bless {ID => 'test-char', sp => 30, learned => 4,
		inventory => bless({amount => 1}, 'WarpPortalTest::Inventory')}, 'WarpPortalTest::Character';
	my $sender = bless {}, 'WarpPortalTest::Sender';
	local $Globals::char = $char;
	local $WarpPortal::char = $char;
	local $Task::UseSkill::char = $char;
	local $Task::UseSkill::messageSender = $sender;
	my $castSkill = bless {}, 'WarpPortalTest::Skill';
	my $useSkill = bless {
		actor => {ID => 'test-char'}, skill => $castSkill,
		target => {x => 12, y => 13}, validateWarpPortal => 1,
	}, 'WarpPortalTest::UseSkillTask';
	is($useSkill->validateWarpPortalResources(), undef,
		'route skill task confirms the planned level is still affordable before casting');
	$useSkill->castSkill();
	is_deeply($sender->{last_skill_location}, [27, 4, 12, 13],
		'Task::UseSkill sends the selected level and the distinct portal target');
	is($char->{warpPortalState}{pending_cast}{level}, 4,
		'native Task::UseSkill records the exact AL_WARP cast level');

	require AI::CoreLogic;
	AI::CoreLogic::noteLegacyWarpPortalCast(27, 2, 8, 9);
	is_deeply([$char->{warpPortalState}{pending_cast}{level}, @{$char->{warpPortalState}{pending_cast}{portal_pos}}{qw(x y)}],
		[2, 8, 9], 'legacy AI location-skill path records its AL_WARP level before protocol-specific sending');
	AI::CoreLogic::noteLegacyWarpPortalCast(28, 1, 3, 4);
	is($char->{warpPortalState}{pending_cast}{level}, 2,
		'legacy non-AL_WARP location skills do not replace Warp Portal cast evidence');
	require Network::ClientReceive;
	Network::ClientReceive::skill_use_location(undef, {skillID => 27, lv => 3, x => 15, y => 16});
	is_deeply([$char->{warpPortalState}{pending_cast}{level}, @{$char->{warpPortalState}{pending_cast}{portal_pos}}{qw(x y)}],
		[3, 15, 16], 'XKore packet observation records the server-client observed AL_WARP level and tile');
	Network::ClientReceive::skill_use_location(undef, {skillID => 27, lv => 3, x => 15, y => 16});
	is($char->{warpPortalState}{pending_cast}{level}, 3,
		'repeated observation retains one current cast record without conflicting level state');
	my $completed_task = bless {
		T_status => Task::DONE, state => Task::UseSkill::WAITING_FOR_CAST_TO_FINISH(),
		castingFinished => 1, skill => $castSkill, actor => $char,
	}, 'WarpPortalTest::CompletedUseSkill';
	local $Task::UseSkill::net = bless({}, 'WarpPortalTest::Net');
	my $repeat_completion = eval { $completed_task->iterate(); 1 };
	ok($repeat_completion && $completed_task->getStatus() == Task::DONE,
		'a cast completion callback cannot complete an already failed/done UseSkill subtask twice');
	$char->{sp} = 25;
	like($useSkill->validateWarpPortalResources(), qr/not enough SP/,
		'Task::UseSkill rejects the cast if SP falls below the selected level cost');
}

sub testWarpPortalMenuCorrelation {
	require Task::MapRoute;
	require Task::UseSkill;
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => '', memo2 => '', memo3 => '', memo4 => '');
	$Globals::char->{pos} = {x => 10, y => 10};
	my $sender = bless {}, 'WarpPortalTest::Sender';
	my $field = bless {}, 'WarpPortalTest::Field';
	local $Task::MapRoute::char = $Globals::char;
	local $Task::MapRoute::field = $field;
	local $Task::MapRoute::messageSender = $sender;
	my $cast_started_at = time;
	my $route = bless {
		mapSolution => [{is_warpPortal => 1}],
		warpPortalStage => 'casting', warpPortalDestination => 'geffen',
		warpPortalSourceMap => 'prontera', warpPortalCastLevel => 4,
		warpPortalMinLevel => 1, warpPortalAttemptID => 'route-menu-test',
		warpPortalPlacement => {x => 11, y => 10},
		warpPortalSession => $Globals::char->{warpPortalState}{session},
		warpPortalStarted => $cast_started_at, warpPortalCastRequestedAt => $cast_started_at,
		ST_subtask => bless({skill => bless({}, 'WarpPortalTest::Skill'), castTries => 1}, 'WarpPortalTest::UseSkillTask'),
	}, 'Task::MapRoute';
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	Task::MapRoute::warpPortalList(undef, {type => 27}, [$route]);
	is($sender->{last_warp_destination}, 'geffen.gat',
		'immediate same-second menu after an active AL_WARP cast selects by destination name');
	is($route->{warpPortalStage}, 'awaiting_portal', 'accepted menu advances the active route once');

	# A menu can arrive after Task::UseSkill completed; the active cast evidence
	# remains in the current character session and retains the sent cast level.
	delete $route->{ST_subtask};
	$route->{warpPortalStage} = 'awaiting_menu';
	$route->{warpPortalStarted} = time - 1;
	$route->{warpPortalCastRequestedAt} = time - 1;
	$route->{warpPortalAttemptID} = 'route-menu-completed';
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	$sender->{last_warp_destination} = undef;
	Task::MapRoute::warpPortalList(undef, {type => 27}, [$route]);
	is($sender->{last_warp_destination}, 'geffen.gat',
		'menu after Task::UseSkill completion remains eligible for its active cast');

	# A response recorded before this route's cast request is stale and ignored.
	$route->{warpPortalStage} = 'awaiting_menu';
	$route->{warpPortalStarted} = time - 1;
	$route->{warpPortalCastRequestedAt} = time + 1;
	$sender->{last_warp_destination} = undef;
	Task::MapRoute::warpPortalList(undef, {type => 27}, [$route]);
	ok(!defined $sender->{last_warp_destination}, 'stale menu evidence from an earlier cast is ignored');

	# Replaying an already consumed packet cannot select the destination twice.
	$route->{warpPortalStage} = 'awaiting_portal';
	$route->{warpPortalCastRequestedAt} = time - 1;
	$sender->{last_warp_destination} = undef;
	Task::MapRoute::warpPortalList(undef, {type => 27}, [$route]);
	ok(!defined $sender->{last_warp_destination}, 'duplicate menu is ignored after the route advances');

	# A speculative candidate must be checked against the fresh routing-cast list.
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '');
	$Globals::char->{pos} = {x => 10, y => 10};
	my $stale_route = bless {
		mapSolution => [{is_warpPortal => 1}], warpPortalStage => 'awaiting_menu',
		warpPortalDestination => 'geffen', warpPortalSourceMap => 'prontera',
		warpPortalCastLevel => 4, warpPortalAttemptID => 'stale-hint-route',
		warpPortalSession => $Globals::char->{warpPortalState}{session},
		warpPortalStarted => time - 1, warpPortalCastRequestedAt => time - 1,
	}, 'Task::MapRoute';
	local *Task::MapRoute::initMapCalculator = sub { $_[0]{recalculated}++ };
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'payon', memo3 => 'alberta'});
	$sender->{last_warp_destination} = undef;
	Task::MapRoute::warpPortalList(undef, {type => 27}, [$stale_route]);
	ok(!defined $sender->{last_warp_destination},
		'a stale speculative memo absent from the fresh menu is never selected');
	ok($stale_route->{recalculated} && $stale_route->{noWarpPortalMaps}{prontera},
		'a stale destination enters bounded fallback after authoritative menu rejection');

	# The server map change is authoritative for location. Without owned portal
	# placement and movement evidence, keep its cause unconfirmed and continue
	# routing from the server position without learning a memo or blacklisting.
	setupCharacter(warpPortal_autoUpdateMemo => 1, memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '');
	$Globals::char->{ID} = 'arrival-route-character';
	$Globals::char->{pos} = {x => 120, y => 62};
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'unconfirmed-route-attempt', {x => 11, y => 10});
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'map-only destination transition without portal evidence remains unconfirmed');
	my $arrival_route = bless {
		T_status => Task::RUNNING, mapBlockPruneTime => time,
		actor => {pos_to => {x => 120, y => 62}},
		mapSolution => [{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=geffen'}],
		warpPortalStage => 'entering_portal', warpPortalDestination => 'geffen',
		warpPortalSourceMap => 'prontera', warpPortalStarted => time - 1,
		warpPortalAttemptID => 'unconfirmed-route-attempt', noWarpPortalMaps => {},
	}, 'Task::MapRoute';
	local $Task::MapRoute::net = bless {}, 'WarpPortalTest::Net';
	local $Task::MapRoute::field = bless {map => 'geffen'}, 'WarpPortalTest::Field';
	local $Task::MapRoute::char = $Globals::char;
	local *Task::MapRoute::initMapCalculator = sub { $_[0]{recalculated}++ };
	Task::MapRoute::iterate($arrival_route);
	ok($arrival_route->{recalculated},
		'MapRoute recalculates from the server-reported destination after an unconfirmed-cause arrival');
	ok(!$arrival_route->{noWarpPortalMaps}{prontera} && !$arrival_route->{warpPortalFailureReason},
		'unconfirmed arrival does not create a Warp Portal failure block');
	ok(!$Globals::char->{warpPortalState}{last_traversal},
		'MapRoute recovery does not relabel the unconfirmed transition as portal traversal');
}

sub testXKoreWarpSelection {
	require Network::ClientReceive;
	require Network::Send::ServerType0;
	require Actor::You;
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'xkore-warp-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	my $source = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
	local $Network::ClientReceive::char = $Globals::char;
	local $Network::ClientReceive::field = $source;
	my $parser = Network::Send::ServerType0->new();
	$parser->{hook_prefix} = 'Network::ClientReceive';
	my $client = Network::ClientReceive->new();
	require Network::Send::kRO::Sakexe_0;
	my $kro_parser = Network::Send::kRO::Sakexe_0->new();
	is_deeply($kro_parser->{packet_list}{'011B'}, $parser->{packet_list}{'011B'},
		'ServerType0 and kRO Sakexe_0 expose the same 011B skillID/mapName selection fields');
	my $select = sub {
		my ($skill_id, $map) = @_;
		$parser->parse(pack('vvZ16', 0x011B, $skill_id, $map), $client);
	};

	# Model a native cast and authoritative server menu, then dispatch the
	# official client's outgoing 011B selection through production parsing.
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	$select->(27, 'Geffen.gat');
	my $pending = $Globals::char->{warpPortalPendingTraversal};
	ok($pending && $pending->{map} eq 'geffen'
		&& $pending->{source_map} eq 'prontera' && $pending->{cast_level} == 4
		&& $pending->{x} == 10 && $pending->{y} == 10
		&& $pending->{portal_expected_pos}{x} == 11 && $pending->{portal_expected_pos}{y} == 10,
		'XKore 011B packet records normalized destination, observed cast level and portal tile');
	my ($attempt_id, $selected_at) = @{$pending}{qw(attempt_id selected_at)};
	$select->(27, 'geffen');
	is($Globals::char->{warpPortalPendingTraversal}{attempt_id}, $attempt_id,
		'duplicate XKore selection preserves the original attempt');
	is($Globals::char->{warpPortalPendingTraversal}{selected_at}, $selected_at,
		'duplicate XKore selection does not extend attempt lifetime');

	my $portal = {ID => 'xkore-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($portal, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	my $traversal = confirmPortalArrival('prontera', 'geffen', 120, 62);
	ok($traversal && $traversal->{attempt_id} eq $attempt_id,
		'XKore-selected traversal correlates from owned portal and movement evidence');
	is_deeply([memoCoordinateForMap('geffen')],
		[120, 62, 'inferred_portal_entry_from_owned_unit_movement_and_map_change'],
		'XKore selection learns only the server-reported landing position');

	# Native OpenKore selection still uses the same tracking state.
	my $native_sender = Network::Send::ServerType0->new();
	local $Network::Send::char = $Globals::char;
	local $Network::Send::field = $source;
	{
		no warnings 'redefine';
		local *Network::Send::sendToServer = sub { };
		$native_sender->sendWarpTele(27, 'geffen.gat', 2);
	}
	ok($Globals::char->{warpPortalPendingTraversal}
		&& $Globals::char->{warpPortalPendingTraversal}{map} eq 'geffen',
		'native OpenKore selection still registers its selected destination');

	# A selected map from the preceding cast is not sufficient once a new
	# character session starts; this isolates the no-cast/no-menu case.
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'xkore-warp-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	$Network::ClientReceive::char = $Globals::char;
	$select->(27, 'geffen');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'selection without a fresh cast and menu is ignored');

	# Non-Warp Portal destination selections and invalid destinations are ignored.
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	delete $Globals::char->{warpPortalPendingTraversal};
	$select->(26, 'geffen');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'Teleport skill selection is not treated as AL_WARP');
	$select->(27, 'not_a_menu_destination');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'destination absent from the authoritative menu is ignored');

	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'xkore-warp-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	$Network::ClientReceive::char = $Globals::char;
	noteWarpCast(27, 1, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	$select->(27, 'geffen');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'memo beyond the observed cast level cannot be selected');

	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'xkore-warp-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	$Network::ClientReceive::char = $Globals::char;
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	$Globals::char->{warpPortalState}{last_portal_cast}{time} = time - 21;
	$Globals::char->{warpPortalState}{verified_at} = time - 21;
	$select->(27, 'geffen');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'expired cast and menu cannot create a traversal attempt');

	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'xkore-warp-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	$Network::ClientReceive::char = $Globals::char;
	noteWarpCast(27, 4, 11, 10);
	updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
	beginCharacterSession();
	$select->(27, 'geffen');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'new character session cannot reuse an old cast or menu');
}

sub testManualWarpSelectionSupersession {
	require Network::Send::ServerType0;
	require Actor::You;
	setupCharacter(route_warpPortal => 0, warpPortal_autoUpdateMemo => 1,
		saveMap => 'prontera', memo1 => 'prontera', memo2 => 'geffen',
		memo3 => 'payon', memo4 => 'alberta');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'manual-selection-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	my $source = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
	my $sender = Network::Send::ServerType0->new();
	local $Network::Send::char = $Globals::char;
	local $Network::Send::field = $source;
	my $sent = 0;
	{
		no warnings 'redefine';
		local *Network::Send::sendToServer = sub { $sent++ };
		my $menu = sub {
			my ($memo2) = @_;
			noteWarpCast(27, 4, 11, 10);
			updateServerMemos({type => 27, memo1 => 'prontera', memo2 => $memo2,
				memo3 => 'alberta', memo4 => 'izlude'});
		};

		# Reproduce two casts and authoritative menus without traversing the first portal.
		$menu->('geffen');
		$sender->sendWarpTele(27, 'geffen.gat');
		my $first = {%{$Globals::char->{warpPortalPendingTraversal}}};
		$menu->('payon');
		$sender->sendWarpTele(27, 'payon.gat');
		my $second = $Globals::char->{warpPortalPendingTraversal};
		ok($second && $second->{map} eq 'payon' && $second->{attempt_id} ne $first->{attempt_id},
			'a fresh manual cast and menu supersede the abandoned Geffen selection with Payon');
		is($sent, 2, 'both native manual selections are transmitted unchanged');

		my ($second_id, $selected_at) = @{$second}{qw(attempt_id selected_at)};
		$sender->sendWarpTele(27, 'payon.gat');
		is($Globals::char->{warpPortalPendingTraversal}{attempt_id}, $second_id,
			'duplicate native selection for one cast keeps its attempt identity');
		is($Globals::char->{warpPortalPendingTraversal}{selected_at}, $selected_at,
			'duplicate native selection does not extend the attempt lifetime');

		noteWarpPortalUnitSeen({ID => 'manual-payon-portal', sourceID => $Globals::char->{ID},
			type => 0x81, x => 11, y => 10}, 'prontera');
		noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
		my $traversal = confirmPortalArrival('prontera', 'payon', 123, 45);
		ok($traversal && $traversal->{attempt_id} eq $second_id,
			'subsequent portal movement is attributed to the second manual destination');
		is($Globals::config{memo2}, 'payon 123 45',
			'second manual traversal learns the server-observed Payon landing coordinates');

		# A new cast must also replace a selection after its 120-second lifetime.
		$menu->('geffen');
		$sender->sendWarpTele(27, 'geffen.gat');
		$Globals::char->{warpPortalPendingTraversal}{selected_at} = time - 121;
		$menu->('payon');
		$sender->sendWarpTele(27, 'payon.gat');
		ok($Globals::char->{warpPortalPendingTraversal}
			&& $Globals::char->{warpPortalPendingTraversal}{map} eq 'payon'
			&& $Globals::char->{warpPortalPendingTraversal}{selected_at} > time - 10,
			'expired manual attempt is cleared before the next valid cast is tracked');

		$sender->sendWarpTele(27, 'cancel');
		ok(!$Globals::char->{warpPortalPendingTraversal},
			'cancel clears an abandoned manual attempt and does not create a traversal');
		$menu->('geffen');
		$sender->sendWarpTele(27, 'geffen.gat');
		my $valid_id = $Globals::char->{warpPortalPendingTraversal}{attempt_id};
		$sender->sendWarpTele(27, 'not_a_menu_destination.gat');
		is($Globals::char->{warpPortalPendingTraversal}{attempt_id}, $valid_id,
			'invalid destination cannot replace a valid pending manual selection');

		# A native console selection must not take ownership from MapRoute.
		$menu->('payon');
		noteWarpSelection('payon', 'prontera', 10, 10, 4, 'automated-route-owned',
			{x => 11, y => 10}, 'route');
		$sender->sendWarpTele(27, 'geffen.gat');
		is($Globals::char->{warpPortalPendingTraversal}{attempt_id}, 'automated-route-owned',
			'manual command cannot replace an active automated MapRoute attempt');
		is($Globals::char->{warpPortalPendingTraversal}{map}, 'payon',
			'automated MapRoute retains its selected destination');
		$sender->sendWarpTele(27, 'cancel');
		is($Globals::char->{warpPortalPendingTraversal}{attempt_id}, 'automated-route-owned',
			'cancel does not clear a route-owned traversal');
	}

	# The real outgoing packet path must require a fresh menu after a new session.
	setupCharacter(route_warpPortal => 0, warpPortal_autoUpdateMemo => 0,
		saveMap => 'prontera', memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	$Globals::char->{ID} = 'manual-selection-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	$Network::Send::char = $Globals::char;
	$Network::Send::field = $source;
	{
		no warnings 'redefine';
		local *Network::Send::sendToServer = sub {};
		$sender->sendWarpTele(27, 'geffen.gat');
	}
	ok(!$Globals::char->{warpPortalPendingTraversal},
		'selection after a new character session needs a fresh cast and authoritative menu');
}

sub testAggregatedAreaSpellWarpPortalObservation {
	require Network::Receive::ServerType0;
	require Task::MapRoute;
	require Actor::You;
	setupCharacter(warpPortal_autoUpdateMemo => 1, route_warpPortal => 1,
		saveMap => 'prontera', memo1 => 'prontera', memo2 => 'geffen');
	bless $Globals::char, 'Actor::You';
	my $owner_id = pack('V', 0x10203040);
	$Globals::char->{ID} = $owner_id;
	$Globals::char->{pos} = {x => 10, y => 10};
	$Globals::char->{pos_to} = {x => 10, y => 10};
	my $source_field = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
	local $Globals::field = $source_field;
	local $Network::Receive::field = $source_field;
	local $Task::MapRoute::char = $Globals::char;
	local $Task::MapRoute::field = $source_field;
	local $Task::MapRoute::messageSender = bless({}, 'WarpPortalTest::Sender');
	local $Task::MapRoute::net = bless({}, 'WarpPortalTest::Net');
	local $Task::Route::net = $Task::MapRoute::net;
	local %Globals::spells = ();
	local @Globals::spellsID = ();
	my $receive = Network::Receive::ServerType0->new();
	$receive->{hook_prefix} = 'Network::Receive';
	my @public_events;
	my $public_hook = Plugins::addHook('packet_areaSpell', sub {
		my (undef, $spell) = @_;
		push @public_events, {%$spell};
	});
	my $begin_route = sub {
		clearPendingTraversal();
		beginCharacterSession();
		$Globals::char->{pos} = {x => 10, y => 10};
		$Globals::char->{pos_to} = {x => 10, y => 10};
		my $actor = bless({pos => {x => 10, y => 10}, pos_to => {x => 10, y => 10}}, 'WarpPortalTest::RouteActor');
		my $route = Task::MapRoute->new(actor => $actor, map => 'geffen', x => 20, y => 20);
		$route->{mapSolution} = [{is_warpPortal => 1, map => 'prontera',
			portal => 'prontera 11 10=geffen 20 20'}];
		$route->{warpPortalStage} = 'awaiting_menu';
		$route->{warpPortalDestination} = 'geffen';
		$route->{warpPortalSourceMap} = 'prontera';
		$route->{warpPortalPlacement} = {x => 11, y => 10};
		$route->{warpPortalCastLevel} = 2;
		$route->{warpPortalAttemptID} = join('-', 'aggregate-test', $Globals::char->{warpPortalState}{session});
		$route->{warpPortalSession} = $Globals::char->{warpPortalState}{session};
		$route->{warpPortalStarted} = time - 1;
		$route->{warpPortalCastRequestedAt} = time - 1;
		noteWarpCast(27, 2, 11, 10);
		updateServerMemos({type => 27, memo1 => 'prontera', memo2 => 'geffen'});
		Plugins::callHook('warp_portal_list', {type => 27});
		is($route->{warpPortalStage}, 'awaiting_portal',
			'production route menu processing selects the authoritative Warp Portal destination');
		return $route;
	};
	my $encode_record = sub {
		my ($format, $id, $source, $x, $y, $type) = @_;
		return $format eq '099F'
			? pack('a4 a4 v2 V C2', pack('V', $id), $source, $x, $y, $type, 2, 1)
			: pack('a4 a4 v2 V C3', pack('V', $id), $source, $x, $y, $type, 2, 1, 4);
	};
	my $dispatch = sub {
		my ($format, @records) = @_;
		my $payload = join('', @records);
		my $packet = $receive->reconstruct({
			switch => $format, len => 4 + length($payload), spellInfo => $payload,
		});
		is(length($packet), 4 + length($payload), "$format aggregate uses its production packet length and effect layout");
		$receive->parse($packet, $receive);
	};
	{
		no warnings 'redefine';
		local *Network::Receive::getActorName = sub { 'test caster' };
		local *Network::Receive::getSpellName = sub { 'test area effect' };

		for my $format (qw(099F 09CA)) {
			for my $position (qw(first intermediate final)) {
				my $route = $begin_route->();
				my @effects = (
					$encode_record->($format, 0x1001, $owner_id, 2, 2, 0x22),
					$encode_record->($format, 0x1002, $owner_id, 3, 3, 0x23),
					$encode_record->($format, 0x1003, $owner_id, 4, 4, 0x24),
				);
				my $portal = $encode_record->($format, 0xAABBCCDD, $owner_id, 11, 10, 0x81);
				if ($position eq 'first') { unshift @effects, $portal; }
				elsif ($position eq 'intermediate') { splice @effects, 1, 0, $portal; }
				else { push @effects, $portal; }
				@public_events = ();
				$dispatch->($format, @effects);
				my $pending = $Globals::char->{warpPortalPendingTraversal};
				is($pending->{portal_unit_id}, pack('V', 0xAABBCCDD),
					"$format $position owned portal is individually observed with its exact unit ID");
				is($pending->{portal_owner_id}, $owner_id,
					"$format $position portal retains its exact owner ID");
				is_deeply($pending->{portal_pos}, {x => 11, y => 10},
					"$format $position portal retains server coordinates and source map context");
				is($route->{warpPortalStage}, 'portal_ready',
					"$format $position portal notification advances MapRoute out of awaiting_portal");
				is(scalar @public_events, 1,
					"$format aggregate preserves the legacy single packet_areaSpell hook notification");
				is($public_events[0]{ID}, unpack('a4', $effects[-1]),
					"$format public hook still receives the legacy final packet entry");
				clearPendingTraversal();
				delete @{$Globals::char->{warpPortalState}}{qw(last_portal_cast available_maps available_map_counts available_map_index verified_at cast_level)};
			}
		}

		# Non-portal effects, other players' portals, and owned portals at a
		# different tile must not satisfy route ownership or placement correlation.
		for my $case (
			['non-portal effects', [
				$encode_record->('099F', 0x2001, $owner_id, 11, 10, 0x22),
				$encode_record->('099F', 0x2002, $owner_id, 11, 10, 0x23),
			]],
			['unrelated player portal', [
				$encode_record->('09CA', 0x2003, pack('V', 0x55667788), 11, 10, 0x81),
			]],
			['owned portal at an unexpected tile', [
				$encode_record->('099F', 0x2004, $owner_id, 12, 10, 0x81),
			]],
		) {
			my $route = $begin_route->();
			$dispatch->($case->[0] eq 'unrelated player portal' ? '09CA' : '099F', @{$case->[1]});
			ok(!$Globals::char->{warpPortalPendingTraversal}{portal_unit_id},
				"$case->[0] is not recorded as the owned route portal");
			is($route->{warpPortalStage}, 'awaiting_portal',
				"$case->[0] cannot advance MapRoute");
			clearPendingTraversal();
			delete @{$Globals::char->{warpPortalState}}{qw(last_portal_cast available_maps available_map_counts available_map_index verified_at cast_level)};
		}

		my $route = $begin_route->();
		Task::activate($route);
		my $portal = $encode_record->('099F', 0x3001, $owner_id, 11, 10, 0x81);
		my $trap = $encode_record->('099F', 0x3002, $owner_id, 9, 9, 0x22);
		$dispatch->('099F', $portal, $portal, $trap);
		is($Globals::char->{warpPortalPendingTraversal}{portal_unit_id}, pack('V', 0x3001),
			'duplicate and multiple portal entries keep the exact matching unit identity');
		is($route->{warpPortalStage}, 'portal_ready',
			'duplicate portal observations advance the route only once');
		{
			no warnings 'redefine';
			local *Task::Route::getRoute = sub { 1 };
			$route->iterateWarpPortalStep();
		}
		is($route->{warpPortalStage}, 'entering_portal',
			'MapRoute creates its real portal-entry Route after aggregated unit observation');
		ok($route->getSubtask() && $route->getSubtask()->isa('Task::Route'),
			'portal-entry movement is owned by a live Task::Route subtask');
		noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
		my $arrival = confirmPortalArrival('prontera', 'geffen', 121, 63);
		ok($arrival && $arrival->{attempt_id} eq $route->{warpPortalAttemptID},
			'server-reported destination transition correlates to the portal observed before the final effect');
		$Globals::char->{pos} = {x => 121, y => 63};
		$Globals::char->{pos_to} = {x => 121, y => 63};
		$route->{actor}{pos} = {x => 121, y => 63};
		$route->{actor}{pos_to} = {x => 121, y => 63};
		$Globals::field = bless({map => 'geffen'}, 'WarpPortalTest::RouteField');
		$Task::MapRoute::field = $Globals::field;
		$Task::Route::field = $Globals::field;
		Plugins::callHook('Network::Receive::map_changed', {oldMap => 'prontera'});
		my @recalculation_origin;
		local *Task::MapRoute::initMapCalculator = sub {
			push @recalculation_origin, [$_[0]{actor}{pos}{x}, $_[0]{actor}{pos}{y}];
			$_[0]{mapSolution} = [];
		};
		$route->iterate();
		is_deeply(\@recalculation_origin, [[121, 63]],
			'confirmed landing resumes MapRoute from the server-observed coordinates');
		ok(!$route->{warpPortalStage},
			'confirmed aggregated-packet traversal clears the completed portal routing stage');
	}
	Plugins::delHook($public_hook);
}

sub testWarpPortalActiveEntryTimeout {
	require Task::MapRoute;
	require Task::Route;
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'geffen', memo2 => '', memo3 => '', memo4 => '');
	$Globals::char->{ID} = 'timeout-character';
	my $field = bless {map => 'prontera'}, 'WarpPortalTest::RouteField';
	my $actor = bless {ID => 'timeout-character', pos => {x => 10, y => 10},
		pos_to => {x => 10, y => 10}}, 'WarpPortalTest::RouteActor';
	local $Task::MapRoute::net = bless {}, 'WarpPortalTest::Net';
	local $Task::MapRoute::field = $field;
	local $Task::Route::field = $field;
	local $Task::Route::net = $Task::MapRoute::net;
	local $Task::MapRoute::char = $Globals::char;
	local $Task::MapRoute::messageSender = bless({}, 'WarpPortalTest::Sender');
	local *Task::MapRoute::initMapCalculator = sub {
		my ($self) = @_;
		$self->{fallback_count}++;
		$self->setSubtask(WarpPortalTest::PendingCalc->new());
	};

	my $make_parent = sub {
		my ($deadline, $route_max_time) = @_;
		my $route = Task::Route->new(actor => $actor, field => $field, x => 11, y => 10,
			isPortalRoute => 1, (defined($route_max_time) ? (maxTime => $route_max_time) : ()));
		my $parent = Task::WithSubtask->new(
			autostop => 1, autofail => 0, mutexes => ['movement']);
		bless $parent, 'Task::MapRoute';
		@{$parent}{qw(actor dest mapSolution warpPortalStage warpPortalDestination
			warpPortalSourceMap warpPortalAttemptID warpPortalStarted warpPortalEntryDeadline noWarpPortalMaps)} = (
			$actor, {map => 'geffen', pos => {x => 10, y => 10}},
			[{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=geffen'}],
			'entering_portal', 'geffen', 'prontera', 'timeout-test', time - 1, $deadline, {},
		);
		Task::activate($parent);
		$parent->setSubtask($route);
		return ($parent, $route);
	};

	# A child walking deadline remains a real failure when no authoritative
	# arrival was recorded, even if the broader portal-entry deadline is live.
	my ($walking_timeout, $walking_route) = $make_parent->(time + 20, 1);
	$walking_route->{time_start} = time - 2;
	Task::MapRoute::iterate($walking_timeout);
	ok($walking_timeout->{fallback_count} == 1
		&& $walking_timeout->{noWarpPortalMaps}{prontera}
		&& !$Globals::char->{warpPortalState}{last_traversal},
		'expired child maxTime without a map change produces one bounded fallback');

	# The real Route task completes through Task::WithSubtask's DONE path before
	# the entry deadline. It must not be blacklisted or trigger fallback.
	my ($successful, $successful_route) = $make_parent->(time + 20);
	{
		no warnings 'redefine';
		local *Task::Route::iterate = sub { $_[0]->setDone() if $_[0]->getStatus() == Task::RUNNING };
		Task::MapRoute::iterate($successful);
	}
	ok($successful_route->getStatus() == Task::DONE && !$successful->{fallback_count}
		&& !$successful->{noWarpPortalMaps}{prontera},
		'portal-entry Route completion before its deadline keeps the Warp Portal route eligible');

	# Keep a real Route task active with a real nested Task child. MapRoute must
	# cancel it through WithSubtask::stop(), then start one fallback calculator.
	my ($stalled, $stalled_route) = $make_parent->(time - 1);
	my $movement = WarpPortalTest::PendingCalc->new();
	$stalled_route->setSubtask($movement);
	my $route_iterations = 0;
	{
		no warnings 'redefine';
		local *Task::Route::iterate = sub {
			$route_iterations++ if $_[0]->getStatus() == Task::RUNNING;
		};
		Task::MapRoute::iterate($stalled);
		is($route_iterations, 0, 'expired entry is canceled before another movement-task iteration');
	}
	is($stalled_route->getStatus(), Task::STOPPED, 'timed-out portal-entry Route is stopped');
	ok(!$stalled_route->getSubtask() && $movement->getStatus() == Task::STOPPED,
		'timeout detaches the route and stops its nested movement subtask');
	is($stalled->{fallback_count}, 1, 'timed-out entry starts exactly one fallback calculation');
	ok($stalled->{noWarpPortalMaps}{prontera}, 'timed-out method is excluded on the source map');
	ok($stalled->getStatus() == Task::RUNNING
		&& $stalled->getSubtask()->isa('WarpPortalTest::PendingCalc'),
		'fallback remains attached to the running MapRoute without nested completion');

	# The attempt has been cleared and the old Route is no longer attached, so a
	# late callback or portal-spawn event cannot revive the expired attempt.
	my $late_route = Task::Route->new(actor => $actor, field => $field, x => 11, y => 10);
	$late_route->{T_status} = Task::DONE;
	$stalled->subtaskDone($late_route);
	Task::MapRoute::warpPortalSpawned(undef, {portal => {
		ID => 'late-portal', type => 0x81, sourceID => $Globals::char->{ID},
		pos_to => {x => 11, y => 10},
	}}, [$stalled]);
	is($stalled->{fallback_count}, 1, 'late completion does not start duplicate fallback');
	ok(!$stalled->{warpPortalStage} && !$Globals::char->{warpPortalPendingTraversal},
		'late portal evidence cannot restore the expired stage or pending traversal');

	# Reproduce a map-change event that the parent has not processed before the
	# portal-entry deadline. The fallback calculation must start at the server
	# position and execute its first edge, not merely clear a boolean.
	my ($transitioned, $transition_route) = $make_parent->(time - 1);
	$field->{map} = 'alberta';
	$transitioned->{actor}{pos} = {x => 44, y => 55};
	$transitioned->{actor}{pos_to} = {x => 44, y => 55};
	Task::MapRoute::mapChanged(undef, {}, [$transitioned]);
	my @fallback_origin;
	{
		no warnings 'redefine';
		local *Task::MapRoute::initMapCalculator = sub {
			my ($self) = @_;
			$self->{fallback_count}++;
			@fallback_origin = ($Task::MapRoute::field->baseName, @{$self->{actor}{pos}}{qw(x y)});
			$self->{mapSolution} = [
				{map => 'alberta', pos => {x => 70, y => 70},
					portal => 'alberta 70 70=payon 100 100', type => 'portal_or_npc'},
				{map => 'payon', pos => {x => 110, y => 110},
					portal => 'payon 110 110=prontera 10 10', type => 'portal_or_npc'},
			];
		};
		local *Task::MapRoute::timeOut = sub { 1 };
		local *Task::Route::getRoute = sub { 1 };
		local %Task::MapRoute::portals_lut = (
			'alberta 70 70' => {source => {map => 'alberta'},
				dest => {'payon 100 100' => {enabled => 1, steps => ''}}},
			'payon 110 110' => {source => {map => 'payon'},
				dest => {'prontera 10 10' => {enabled => 1, steps => ''}}},
		);
		Task::MapRoute::iterate($transitioned);
		my $firstEdge = $transitioned->getSubtask();
		ok($firstEdge && $firstEdge->isa('Task::Route')
			&& $firstEdge->{dest}{pos}{x} == 70 && $firstEdge->{dest}{pos}{y} == 70,
			'first static portal edge of the fallback route starts its real movement task');
		$field = bless({map => 'payon'}, 'WarpPortalTest::RouteField');
		$Task::MapRoute::field = $field;
		$Task::Route::field = $field;
		$transitioned->{actor}{pos} = {x => 100, y => 100};
		$transitioned->{actor}{pos_to} = {x => 100, y => 100};
		Task::MapRoute::mapChanged(undef, {}, [$transitioned]);
		Task::Route::mapChanged(undef, undef, [$firstEdge]) if $firstEdge;
		Task::MapRoute::iterate($transitioned);
		is($firstEdge ? $firstEdge->getStatus() : undef, Task::DONE,
			'the first fallback movement subtask completes after its new route transition');
		is($transitioned->{mapSolution} && $transitioned->{mapSolution}[0]{map}, 'payon',
			'the fresh transition advances from the first fallback edge to the second portal edge');
	}
	is_deeply(\@fallback_origin, ['alberta', 44, 55],
		'timeout fallback calculates from the unexpected server map and coordinates');
	ok($transition_route->getStatus() == Task::STOPPED && $transitioned->{fallback_count} == 1,
		'unexpected transition timeout cancels the old Route and starts one fallback');
	$field->{map} = 'prontera';

	# An unrelated map route still waits normally on an active Route subtask.
	my ($ordinary, $ordinary_route) = $make_parent->(undef);
	delete @{$ordinary}{qw(warpPortalStage warpPortalDestination warpPortalSourceMap warpPortalAttemptID)};
	my $ordinary_iterations = 0;
	{
		no warnings 'redefine';
		local *Task::Route::iterate = sub { $ordinary_iterations++ };
		Task::MapRoute::iterate($ordinary);
	}
	ok($ordinary_route->getStatus() == Task::RUNNING && $ordinary_iterations == 1
		&& !$ordinary->{fallback_count},
		'unrelated MapRoute task lifecycle is unchanged without a Warp Portal entry deadline');

	my $ordinary_walk = Task::Route->new(actor => $actor, field => $field,
		x => 20, y => 20, maxTime => 1);
	Task::activate($ordinary_walk);
	$ordinary_walk->{time_start} = time - 2;
	Task::Route::iterate($ordinary_walk);
	is($ordinary_walk->getError()->{code}, Task::Route::TOO_MUCH_TIME(),
		'ordinary walking still reports its expired maxTime unchanged');
}

sub testMapServerTransferKeepsPortalEvidence {
	require Network::Receive;
	setupCharacter(char => 0, warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '');
	$Globals::char->{ID} = 'transfer-character';
	bless $Globals::char, 'WarpPortalTest::HandoffCharacter';
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'cross-server-attempt', {x => 11, y => 10});
	my $unit = {ID => 'transfer-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	my $logical_session = $Globals::char->{warpPortalState}{session};
	$Globals::char->{pos} = {x => 120, y => 62};
	require Network::Receive;
	{
		no warnings 'redefine';
		local $Network::Receive::net = bless({}, 'WarpPortalTest::HandoffNet');
		local $Network::Receive::char = $Globals::char;
		local $Network::Receive::field = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
		local $Network::Receive::masterServer = {serverType => 'kRO', private => 0};
		local $Network::Receive::map_ip = '127.0.0.1';
		local $Network::Receive::map_port = 5120;
		local $Network::Receive::config{char} = 0;
		local @Network::Receive::chars = ($Globals::char);
		local $Network::Receive::messageSender = bless({}, 'WarpPortalTest::HandoffSender');
		local @Network::Receive::ai_seq = ();
		local *Network::Receive::checkAllowedMap = sub { };
		local *Field::new = sub { my %args = @_[1 .. $#_]; bless({map => $args{name}}, 'WarpPortalTest::RouteField') };
		local *Network::Receive::changeToInGameState = sub { 1 };
		local *Network::Receive::message = sub { };
		local *Network::Receive::swrite = sub { '' };
	my ($loaded_x, $loaded_y) = (120, 62);
		local *Network::Receive::makeCoordsDir = sub { $_[0]{x} = $loaded_x; $_[0]{y} = $loaded_y; ${$_[2]} = 0; };
		local *Misc::clearTeleportItemPendingUse = sub { };
		local *Plugins::callHook = sub { };
		local *AI::SlaveManager::setMapChanged = sub { };
		local *AI::ai_setMapChanged = sub { };
		local *main::initMapChangeVars = sub { };
		local *Network::Receive::error = sub { };
		$Globals::char->{look} = {body => 0};
		Network::Receive::map_changed(undef, {
			map => 'geffen.gat', x => 120, y => 62,
			url => '127.0.0.2:5121', port => 5121,
		});
		ok($Globals::char->{warpPortalState}{last_traversal},
			'production cross-server packet handler confirms portal arrival before disconnect');
		is_deeply([@{$Globals::char->{warpPortalState}{pending_transfer_arrival}}{qw(map x y)}],
			['geffen', 120, 62], 'cross-server arrival coordinates remain provisional until destination acceptance');
		ok(!memoCoordinateForMap('geffen'),
			'provisional cross-server coordinates are not exposed as learned memo coordinates');
		$Network::Receive::net->{state} = 4;
		Network::Receive::map_loaded(undef, {syncMapSync => 0, coords => ''});
		ok($Globals::char->{warpPortalState}{last_traversal},
			'production destination map_loaded handler preserves traversal until MapRoute resumes');
		is($Globals::char->{warpPortalState}{session}, $logical_session,
			'map-server reconnect preserves the same logical character session generation');
		is_deeply([memoCoordinateForMap('geffen')], [120, 62, 'inferred_portal_entry_from_owned_unit_movement_and_map_change'],
			'production map_loaded path preserves auto-sync-off landing coordinates');
		ok(!$Globals::char->{warpPortalMapTransfer}, 'successful map_loaded consumes its one-shot transfer token');
		require Task::MapRoute;
		require Task::Route;
		my $source = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
		my $actor = bless({ID => $Globals::char->{ID}, pos => {x => 120, y => 62},
			pos_to => {x => 120, y => 62}}, 'WarpPortalTest::RouteActor');
		local $Task::MapRoute::net = $Network::Receive::net;
		local $Task::Route::net = $Network::Receive::net;
		local $Task::MapRoute::field = $Network::Receive::field;
		local $Task::Route::field = $Network::Receive::field;
		local $Task::MapRoute::char = $Globals::char;
		local *Task::MapRoute::initMapCalculator = sub {
			$_[0]{recalculations}++;
			$_[0]->setSubtask(WarpPortalTest::PendingCalc->new());
		};
		my $route = Task::Route->new(actor => $actor, field => $Network::Receive::field,
			x => 120, y => 62, isPortalRoute => 1);
		$route->{mapChanged} = 1;
		my $parent = Task::WithSubtask->new(autostop => 1, autofail => 0);
		bless $parent, 'Task::MapRoute';
		@{$parent}{qw(actor dest mapSolution warpPortalStage warpPortalDestination
			warpPortalSourceMap warpPortalAttemptID warpPortalStarted warpPortalEntryDeadline mapChanged noWarpPortalMaps)} = (
			$actor, {map => 'geffen', pos => {x => 120, y => 62}},
			[{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=geffen'}],
			'entering_portal', 'geffen', 'prontera', 'cross-server-attempt', time - 1, time + 20, 1, {},
		);
		Task::activate($parent);
		$parent->setSubtask($route);
		Task::MapRoute::iterate($parent);
		ok($route->getStatus() == Task::DONE && !$Globals::char->{warpPortalState}{last_traversal}
			&& $parent->getSubtask()->isa('WarpPortalTest::PendingCalc')
			&& !$parent->{noWarpPortalMaps}{prontera},
			'MapRoute resumes after map_loaded, consumes the transfer evidence, and recalculates without blacklisting');

		$Globals::config{warpPortal_autoUpdateMemo} = 1;
		$Globals::config{memo2} = 'payon';
		noteWarpSelection('payon', 'geffen', 121, 63, 4, 'cross-server-sync-packet', {x => 121, y => 63});
		$unit = {ID => 'sync-packet-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 121, y => 63};
		noteWarpPortalUnitSeen($unit, 'geffen');
		noteWarpPortalMovement({x => 120, y => 62}, {x => 121, y => 63}, 'geffen');
		$loaded_x = 42; $loaded_y = 43;
		my $transfer_writes = captureWrites(sub {
			Network::Receive::map_changed(undef, {
				map => 'payon.gat', x => 42, y => 43,
				url => '127.0.0.3:5122', port => 5122,
			});
		});
	is(scalar(@$transfer_writes), 0,
		'cross-server transfer packet keeps confirmed arrival provisional without persisting memo coordinates');
	is($Globals::config{memo2}, 'payon',
		'configuration remains unchanged until the destination map server accepts the character');
	$loaded_x = 43; $loaded_y = 44;
	$transfer_writes = captureWrites(sub {
		Network::Receive::map_loaded(undef, {syncMapSync => 0, coords => ''});
	});
	is($Globals::config{memo2}, 'payon 43 44',
		'accepted destination coordinates, including a server adjustment, are persisted');
	is(scalar(@$transfer_writes), 1, 'successful cross-server handoff writes the memo exactly once');
	is_deeply([memoCoordinateForMap('payon')], [43, 44, 'inferred_portal_entry_from_owned_unit_movement_and_map_change'],
			'production auto-sync-on map-loaded path retains learned landing coordinates');
		$transfer_writes = captureWrites(sub {
			Network::Receive::map_loaded(undef, {syncMapSync => 0, coords => ''});
		});
		is(scalar(@$transfer_writes), 0,
			'a repeated destination login packet cannot duplicate a confirmed memo update');
		is($Globals::config{memo2}, 'payon 43 44',
			'repeated destination login preserves the single accepted coordinate update');
		my $same_server_session = $Globals::char->{warpPortalState}{session};
		noteWarpSelection('geffen', 'payon', 43, 44, 4, 'same-server-attempt', {x => 43, y => 44});
		$unit = {ID => 'same-server-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 43, y => 44};
		noteWarpPortalUnitSeen($unit, 'payon');
		noteWarpPortalMovement({x => 42, y => 43}, {x => 43, y => 44}, 'payon');
		Network::Receive::map_change(undef, {map => 'geffen.gat', x => 51, y => 52});
		is($Globals::char->{warpPortalState}{session}, $same_server_session,
			'same-map-server transition does not start a new character session');
		is($Globals::char->{warpPortalState}{last_traversal}{attempt_id}, 'same-server-attempt',
			'same-map-server portal arrival remains immediately available to MapRoute');

		markCharacterMapTransfer('geffen', 120, 62, '127.0.0.2', 5121, undef);
		Network::Receive::map_load_error(undef, {error => 1});
		ok(!$Globals::char->{warpPortalMapTransfer}, 'failed destination reconnection clears transfer evidence');
		$Globals::config{memo3} = 'alberta';
		noteWarpSelection('alberta', 'geffen', 52, 53, 4, 'rejected-transfer-attempt', {x => 52, y => 53});
		$unit = {ID => 'rejected-transfer-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 52, y => 53};
		noteWarpPortalUnitSeen($unit, 'geffen');
		noteWarpPortalMovement({x => 51, y => 53}, {x => 52, y => 53}, 'geffen');
		$transfer_writes = captureWrites(sub {
			Network::Receive::map_changed(undef, {
				map => 'alberta.gat', x => 77, y => 88,
				url => '127.0.0.4:5124', port => 5124,
			});
		});
		is(scalar(@$transfer_writes), 0, 'rejected transfer remains provisional before map-server acceptance');
		Network::Receive::map_load_error(undef, {error => 1});
		is($Globals::config{memo3}, 'alberta',
			'destination map-server rejection never persists its unaccepted coordinates');
		ok(!$Globals::char->{warpPortalState}{pending_transfer_arrival}
			&& !$Globals::char->{warpPortalMapTransfer},
			'rejected transfer clears only its matching provisional arrival and handoff');
		noteWarpSelection('alberta', 'geffen', 60, 61, 4, 'expired-transfer-attempt', {x => 60, y => 61});
		noteWarpPortalUnitSeen({ID => 'expired-transfer-portal', sourceID => $Globals::char->{ID},
			type => 0x81, x => 60, y => 61}, 'geffen');
		noteWarpPortalMovement({x => 59, y => 61}, {x => 60, y => 61}, 'geffen');
		confirmPortalArrival('geffen', 'alberta', 80, 81, 1);
		markCharacterMapTransfer('alberta', 80, 81, '127.0.0.5', 5125, 'expired-transfer-attempt');
		$Globals::char->{warpPortalMapTransfer}{time} = time - 31;
		beginCharacterSession('alberta', '127.0.0.5', 5125, 80, 81);
		is($Globals::config{memo3}, 'alberta',
			'a timed-out transfer cannot persist provisional coordinates when a later session starts');
		ok(!$Globals::char->{warpPortalState}{pending_transfer_arrival},
			'expired provisional arrival is discarded with the timed-out transfer');
	}
	# A later genuine logical session and a character switch still discard it.
	beginCharacterSession();
	ok(!$Globals::char->{warpPortalState}{last_traversal}, 'genuine new session clears old traversal evidence');
	$Globals::char->{warpPortalState}{observed_coordinates}{geffen} = {
		x => 120, y => 62, source => 'inferred_portal_entry', session => $Globals::char->{warpPortalState}{session},
	};
	markCharacterMapTransfer('payon', 20, 30, '127.0.0.2', 5122, undef);
	$Globals::char->{pos} = {x => 20, y => 30};
	beginCharacterSession('payon', '127.0.0.2', 5122, 20, 30);
	ok(!exists($Globals::char->{warpPortalState}{last_traversal}),
		'ordinary server transfer preserves no stale portal traversal');
	is_deeply([memoCoordinateForMap('geffen')], [120, 62, 'inferred_portal_entry'],
		'ordinary map-server transfer keeps current-session learned coordinates with auto-sync disabled');
	markCharacterMapTransfer('payon', 20, 30, '127.0.0.2', 5122, undef);
	clearCharacterMapTransfer();
	beginCharacterSession('payon', '127.0.0.2', 5122, 20, 30);
	ok(!memoCoordinateForMap('geffen'), 'failed or interrupted handoff is discarded before a new logical session');
	setupCharacter(warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen', memo3 => '', memo4 => '');
	$Globals::char->{ID} = 'transfer-sync-character';
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'cross-server-sync-attempt', {x => 11, y => 10});
	$unit = {ID => 'sync-transfer-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	confirmPortalArrival('prontera', 'geffen', 121, 63, 1);
	markCharacterMapTransfer('geffen', 121, 63, '127.0.0.2', 5123, 'cross-server-sync-attempt');
	$Globals::char->{pos} = {x => 121, y => 63};
	beginCharacterSession('geffen', '127.0.0.2', 5123, 121, 63);
	is($Globals::config{memo2}, 'geffen 121 63', 'auto-sync-on transfer keeps the confirmed memo coordinate update');
	is_deeply([memoCoordinateForMap('geffen')], [121, 63, 'inferred_portal_entry_from_owned_unit_movement_and_map_change'],
		'auto-sync-on transfer also keeps runtime arrival evidence for the active route');
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	$Globals::char->{ID} = 'different-character';
	ok(!$Globals::char->{warpPortalState}{last_traversal}, 'character switch cannot inherit transfer evidence');
}

sub testWarpPortalFallbackClearsTransitionState {
	require Task::MapRoute;
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'payon');
	my $field = bless {map => 'geffen'}, 'WarpPortalTest::RouteField';
	my $actor = bless {ID => 'fallback-character', pos => {x => 100, y => 100},
		pos_to => {x => 100, y => 100}}, 'WarpPortalTest::RouteActor';
	local $Task::MapRoute::field = $field;
	local $Task::MapRoute::char = $Globals::char;
	local $Task::MapRoute::net = bless({state => Network::IN_GAME}, 'WarpPortalTest::HandoffNet');
	local *Task::MapRoute::initMapCalculator = sub { $_[0]{fallback_count}++ };
	my $parent = bless({actor => $actor, dest => {map => 'payon', pos => {x => 10, y => 10}},
		mapSolution => [{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=payon'}],
		warpPortalStage => 'entering_portal', warpPortalDestination => 'payon',
		warpPortalSourceMap => 'prontera', warpPortalAttemptID => 'fallback-transition',
		mapChanged => 1, teleportTime => time - 1, sentTeleport => 1}, 'Task::MapRoute');
	Task::activate($parent);
	$parent->failWarpPortalStep('unexpected map transition could not be correlated', 1);
	ok(!$parent->{mapChanged} && !$parent->{teleport} && !$parent->{teleportTime} && !$parent->{sentTeleport},
		'failed Warp Portal attempt clears only its already-handled transition and teleport state');
	$parent->{mapSolution} = [
		{map => 'geffen', portal => 'geffen 110 110=payon 20 20', type => 'portal_or_npc'},
		{map => 'payon', portal => 'payon 20 20=payon 10 10', type => 'portal_or_npc'},
	];
	my $first = $parent->{mapSolution}[0]{portal};
	{
		no warnings 'redefine';
		local *Task::MapRoute::setSubtask = sub { };
		Task::MapRoute::iterate($parent);
	}
	is($parent->{mapSolution}[0]{portal}, $first,
		'first route edge from the authoritative fallback position is not shifted by stale mapChanged state');
	my $unhandled = bless({actor => $actor, dest => $parent->{dest},
		mapSolution => [{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=payon'}],
		warpPortalSourceMap => 'prontera', mapChanged => 1}, 'Task::MapRoute');
	Task::activate($unhandled);
	$unhandled->failWarpPortalStep('entry timed out before processing transition');
	ok($unhandled->{mapChanged}, 'fallback without a handled map-change event preserves pending transition state');
}

sub testConfirmedArrivalWinsEntryTimeout {
	require Task::MapRoute;
	require Task::Route;
	setupCharacter(warpPortal_autoUpdateMemo => 0, memo1 => 'prontera', memo2 => 'geffen');
	$Globals::char->{ID} = 'deadline-arrival-character';
	$Globals::char->{pos} = {x => 10, y => 10};
	my $source = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
	my $destination = bless({map => 'geffen'}, 'WarpPortalTest::RouteField');
	my $actor = bless({ID => $Globals::char->{ID}, pos => {x => 120, y => 62},
		pos_to => {x => 120, y => 62}}, 'WarpPortalTest::RouteActor');
	local $Task::MapRoute::net = bless({state => Network::IN_GAME}, 'WarpPortalTest::HandoffNet');
	local $Task::Route::net = $Task::MapRoute::net;
	local $Task::MapRoute::field = $destination;
	local $Task::Route::field = $destination;
	local $Task::MapRoute::char = $Globals::char;
	local $Task::MapRoute::messageSender = bless({}, 'WarpPortalTest::Sender');
	local $Network::Receive::net = $Task::MapRoute::net;
	local $Network::Receive::char = $Globals::char;
	local $Network::Receive::field = $source;
	local $Network::Receive::masterServer = {serverType => 'kRO', private => 0};
	local $Network::Receive::messageSender = bless({}, 'WarpPortalTest::HandoffSender');
	local @Network::Receive::ai_seq = ();
	local *Network::Receive::checkAllowedMap = sub { };
	local *Network::Receive::changeToInGameState = sub { 1 };
	local *Network::Receive::message = sub { };
	local *Network::Receive::swrite = sub { '' };
	local *Field::new = sub { my %args = @_[1 .. $#_]; bless({map => $args{name}}, 'WarpPortalTest::RouteField') };
	local *Misc::clearTeleportItemPendingUse = sub { };
	local *Plugins::callHook = sub { };
	local *AI::SlaveManager::setMapChanged = sub { };
	local *AI::ai_setMapChanged = sub { };
	local *main::initMapChangeVars = sub { };
	local *Task::MapRoute::initMapCalculator = sub {
		$_[0]{fallback_count}++;
		$_[0]->setSubtask(WarpPortalTest::PendingCalc->new());
	};
	my $route = Task::Route->new(actor => $actor, field => $source, x => 120, y => 62,
		isPortalRoute => 1, maxTime => 1);
	my $parent = Task::WithSubtask->new(autostop => 1, autofail => 0, mutexes => ['movement']);
	bless $parent, 'Task::MapRoute';
	@{$parent}{qw(actor dest mapSolution warpPortalStage warpPortalDestination
		warpPortalSourceMap warpPortalAttemptID warpPortalStarted warpPortalEntryDeadline noWarpPortalMaps mapChanged)} = (
		$actor, {map => 'geffen', pos => {x => 120, y => 62}},
		[{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=geffen'}],
		'entering_portal', 'geffen', 'prontera', 'deadline-attempt', time - 21, time - 1, {}, 1,
	);
	Task::activate($parent);
	$parent->setSubtask($route);
	$route->{time_start} = time - 2;
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'deadline-attempt', {x => 11, y => 10});
	my $portal = {ID => 'deadline-portal', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($portal, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	Network::Receive::map_change(undef, {map => 'geffen.gat', x => 120, y => 62});
	Task::Route::mapChanged(undef, undef, [$route]);
	Task::MapRoute::mapChanged(undef, {}, [$parent]);
	ok($Globals::char->{warpPortalState}{last_traversal},
		'production map-change packet confirms arrival after deadline before MapRoute processes it');
	Task::MapRoute::iterate($parent);
	ok($route->getStatus() == Task::DONE && !$parent->{noWarpPortalMaps}{prontera}
		&& $parent->{fallback_count} == 1,
		'correlated arrival observed after deadline wins over timeout cancellation and blacklist');
	ok($parent->getSubtask()->isa('WarpPortalTest::PendingCalc')
		&& !$Globals::char->{warpPortalState}{last_traversal},
		'confirmed arrival starts one fresh calculation and consumes only the matching traversal');

	# A correctly correlated arrival before the child's own maxTime still passes
	# through the same task lifecycle without being canceled by the parent.
	$Network::Receive::field = $source;
	$Task::MapRoute::field = $destination;
	$Task::Route::field = $destination;
	$Globals::char->{pos} = {x => 10, y => 10};
	$actor->{pos} = {x => 120, y => 62};
	$actor->{pos_to} = {x => 120, y => 62};
	my $before_timeout_route = Task::Route->new(actor => $actor, field => $source,
		x => 120, y => 62, isPortalRoute => 1, maxTime => 60);
	my $before_timeout_parent = Task::WithSubtask->new(autostop => 1, autofail => 0);
	bless $before_timeout_parent, 'Task::MapRoute';
	@{$before_timeout_parent}{qw(actor dest mapSolution warpPortalStage warpPortalDestination
		warpPortalSourceMap warpPortalAttemptID warpPortalStarted warpPortalEntryDeadline noWarpPortalMaps)} = (
		$actor, {map => 'geffen', pos => {x => 120, y => 62}},
		[{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=geffen'}],
		'entering_portal', 'geffen', 'prontera', 'before-child-timeout', time - 1, time + 20, {},
	);
	Task::activate($before_timeout_parent);
	$before_timeout_parent->setSubtask($before_timeout_route);
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'before-child-timeout', {x => 11, y => 10});
	noteWarpPortalUnitSeen({ID => 'before-timeout-portal', sourceID => $Globals::char->{ID},
		type => 0x81, x => 11, y => 10}, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	Network::Receive::map_change(undef, {map => 'geffen.gat', x => 120, y => 62});
	Task::Route::mapChanged(undef, undef, [$before_timeout_route]);
	Task::MapRoute::mapChanged(undef, {}, [$before_timeout_parent]);
	Task::MapRoute::iterate($before_timeout_parent);
	ok($before_timeout_route->getStatus() == Task::DONE
		&& !$before_timeout_parent->{noWarpPortalMaps}{prontera}
		&& $before_timeout_parent->{fallback_count} == 1,
		'confirmed arrival before child maxTime completes and continues the parent route');

	my ($ambiguous, $ambiguous_route);
	my $make_ambiguous = sub {
		$ambiguous_route = Task::Route->new(actor => $actor, field => $source, x => 120, y => 62,
			isPortalRoute => 1, maxTime => 1);
		$ambiguous = Task::WithSubtask->new(autostop => 1, autofail => 0);
		bless $ambiguous, 'Task::MapRoute';
		@{$ambiguous}{qw(actor dest mapSolution warpPortalStage warpPortalDestination
			warpPortalSourceMap warpPortalAttemptID warpPortalStarted warpPortalEntryDeadline noWarpPortalMaps)} = (
			$actor, {map => 'geffen', pos => {x => 120, y => 62}},
			[{is_warpPortal => 1, map => 'prontera', portal => 'prontera 11 10=geffen'}],
			'entering_portal', 'geffen', 'prontera', 'ambiguous-deadline', time - 21, time + 20, {},
		);
		Task::activate($ambiguous);
		$ambiguous->setSubtask($ambiguous_route);
		$ambiguous_route->{time_start} = time - 2;
	};
	$make_ambiguous->();
	delete $Globals::char->{warpPortalState}{last_traversal};
	my @coordinates_before_ambiguous = memoCoordinateForMap('geffen');
	Network::Receive::map_change(undef, {map => 'geffen.gat', x => 120, y => 62});
	Task::Route::mapChanged(undef, undef, [$ambiguous_route]);
	Task::MapRoute::mapChanged(undef, {}, [$ambiguous]);
	Task::MapRoute::iterate($ambiguous);
	is($ambiguous->{fallback_count}, 1, 'same-destination arrival without correlation still triggers one child-timeout fallback');
	ok($ambiguous->{noWarpPortalMaps}{prontera} && !$Globals::char->{warpPortalState}{last_traversal},
		'ambiguous transition cannot override child timeout or create a portal blacklist bypass');
	is_deeply([memoCoordinateForMap('geffen')], \@coordinates_before_ambiguous,
		'ambiguous same-destination transition does not change learned memo coordinates');
}

sub testSameMapWarpPortalRouting {
	require Task::CalcMapRoute;
	require Task::MapRoute;
	require Task::Route;
	setupCharacter(route_warpPortal => 1, warpPortal_autoUpdateMemo => 0,
		saveMap => 'prontera', memo1 => 'prontera 20 21', memo2 => '', memo3 => '', memo4 => '');
	$Globals::char = bless {
		charID => 'same-map-planner', learned => 4, sp => 100,
		inventory => bless({amount => 1}, 'WarpPortalTest::Inventory'),
	}, 'WarpPortalTest::Character';
	$Globals::char->{ID} = 'same-map-character';
	beginCharacterSession();
	my $planner = bless {
		source => {map => 'prontera'}, targets => [{map => 'prontera', x => 30, y => 30}],
		noWarpPortalMaps => {}, routeWeightCache => {WARPPORTAL => 200}, mapRouteWeightCache => {},
	}, 'Task::CalcMapRoute';
	my $baseCost = {walk => 0, zeny => 0, blockedPortalGroups => {}};
	{
		no warnings 'redefine';
		local *Field::new = sub { bless({}, 'WarpPortalTest::Field') };
		local *Task::CalcMapRoute::getMapRouteWeight = sub { 0 };
		local *Task::CalcMapRoute::getRouteWeight = sub { 0 };
		local *Task::CalcMapRoute::buildRouteStateKey = sub { 'same-map-warp' };
		local *Task::CalcMapRoute::canAddOpenListEntry = sub { 1 };
		local *Task::CalcMapRoute::cloneBlockedPortalGroups = sub { {} };
		local *Task::CalcMapRoute::buildRouteValue = sub { {} };
		local *Task::CalcMapRoute::registerSyntheticPortalDestination = sub { 1 };
		local *Task::CalcMapRoute::add_key_to_openList = sub { $_[0]{candidate} = $_[2] };
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $baseCost, undef);
	}
	ok($planner->{candidate}{is_warpPortal},
		'planner supports a Warp Portal memo on the current map when landing coordinates differ');
	{
		no warnings 'redefine';
		local *Field::new = sub {
			my %args = @_[1 .. $#_];
			bless({map => $args{name}}, 'WarpPortalTest::Field');
		};
		local *Task::Route::getRoute = sub { 1 };
		my $walkable = Task::CalcMapRoute->new(
			sourceMap => 'prontera', sourceX => 10, sourceY => 10,
			map => 'prontera', x => 30, y => 30,
			noGoCommand => 1, noTeleSpawn => 1, noWarpItem => 1, noAirship => 1,
		);
		Task::activate($walkable);
		$walkable->iterate();
		ok($walkable->getStatus() == Task::DONE && @{$walkable->getRoute()} == 0,
			'a same-map destination reachable by walking keeps the ordinary direct route');
	}
	{
		no warnings 'redefine';
		local *Field::new = sub { bless({}, 'WarpPortalTest::Field') };
		local *Task::Route::getRoute = sub { 0 };
		local *Task::CalcMapRoute::buildRouteStateKey = sub { 'disconnected-same-map-warp' };
		local *Task::CalcMapRoute::canAddOpenListEntry = sub { 1 };
		local *Task::CalcMapRoute::cloneBlockedPortalGroups = sub { {} };
		local *Task::CalcMapRoute::buildRouteValue = sub { {} };
		local *Task::CalcMapRoute::registerSyntheticPortalDestination = sub { 1 };
		local *Task::CalcMapRoute::add_key_to_openList = sub { $_[0]{candidate} = $_[2] };
		delete $planner->{candidate};
		$planner->populateOpenListWithWarpPortal('prontera 10 10', $baseCost, undef);
		ok($planner->{candidate}{is_warpPortal},
			'a disconnected same-map region remains eligible for the planned Warp Portal alternative');
	}

	my $field = bless({map => 'prontera'}, 'WarpPortalTest::RouteField');
	my $actor = bless({ID => 'same-map-character', pos => {x => 10, y => 10},
		pos_to => {x => 10, y => 10}}, 'WarpPortalTest::RouteActor');
	local $Task::MapRoute::field = $field;
	local $Task::Route::field = $field;
	local $Task::MapRoute::char = $Globals::char;
	local $Task::MapRoute::net = bless({state => Network::IN_GAME}, 'WarpPortalTest::HandoffNet');
	local $Task::Route::net = $Task::MapRoute::net;
	local *Task::Route::getRoute = sub { 1 };
	my $parent = Task::WithSubtask->new(autostop => 1, autofail => 0);
	bless $parent, 'Task::MapRoute';
	@{$parent}{qw(actor dest mapSolution warpPortalStage warpPortalDestination warpPortalSourceMap
		warpPortalAttemptID warpPortalStarted warpPortalEntryDeadline noWarpPortalMaps)} = (
		$actor, {map => 'prontera', pos => {x => 30, y => 30}},
		[{is_warpPortal => 1, map => 'prontera', portal => 'prontera 20 20=prontera 20 21'}],
		'portal_ready', 'prontera', 'prontera', 'same-map-attempt', time - 1, time + 20, {},
	);
	$parent->{warpPortalActor} = {ID => 'same-map-portal', pos_to => {x => 20, y => 20}};
	my @recalculationOrigin;
	{
		no warnings 'redefine';
		local *Task::MapRoute::initMapCalculator = sub {
			my ($self) = @_;
			$self->{recalculations}++;
			@recalculationOrigin = ($Task::MapRoute::field->baseName, @{$self->{actor}{pos}}{qw(x y)});
			$self->setSubtask(WarpPortalTest::PendingCalc->new());
		};
		Task::activate($parent);
		Task::MapRoute::iterateWarpPortalStep($parent);
		my $entry = $parent->getSubtask();
		ok($entry && $entry->{stopWhenMapChanged},
			'same-map Warp Portal entry Route is configured to stop on an authoritative same-map teleport');
		$actor->{pos} = {x => 31, y => 32};
		$actor->{pos_to} = {x => 31, y => 32};
		noteWarpSelection('prontera', 'prontera', 20, 20, 1, 'same-map-attempt', {x => 20, y => 20});
		noteWarpPortalUnitSeen({ID => 'same-map-portal', sourceID => $Globals::char->{ID},
			type => 0x81, x => 20, y => 20}, 'prontera');
		noteWarpPortalMovement({x => 19, y => 20}, {x => 20, y => 20}, 'prontera');
		ok(confirmPortalArrival('prontera', 'prontera', 31, 32),
			'same-map Warp Portal movement and the server coordinate event form traversal evidence');
		ok(!confirmPortalArrival('prontera', 'prontera', 31, 32),
			'duplicate same-map arrival notification cannot confirm or learn the traversal twice');
		Task::Route::mapChanged(undef, undef, [$entry]);
		Task::MapRoute::mapChanged(undef, {}, [$parent]);
		Task::Route::mapChanged(undef, undef, [$entry]);
		Task::MapRoute::mapChanged(undef, {}, [$parent]);
		Task::MapRoute::iterate($parent);
		ok($entry->getStatus() == Task::DONE,
			'same-map teleport terminates the old portal-entry movement task');
		is_deeply(\@recalculationOrigin, ['prontera', 31, 32],
			'routing resumes from the server-reported same-map landing coordinates');
		ok($parent->{recalculations} == 1 && !$parent->{warpPortalStage}
			&& !$Globals::char->{warpPortalState}{last_traversal},
			'same-map arrival is consumed once and starts exactly one route recalculation');
	}

	# A normal same-map route has no stop-on-map-change flag and keeps its
	# existing replan behavior; a conventional same-map portal still opts in.
	my $normal = Task::Route->new(actor => $actor, field => $field, x => 35, y => 35);
	ok(!$normal->{stopWhenMapChanged}, 'ordinary same-map walking does not inherit Warp Portal termination');
	my $staticParent = Task::WithSubtask->new(autostop => 1, autofail => 0);
	bless $staticParent, 'Task::MapRoute';
	$staticParent->{actor} = $actor;
	$staticParent->{dest} = {map => 'payon', pos => {x => 10, y => 10}};
	$staticParent->{mapSolution} = [{map => 'prontera', pos => {x => 70, y => 70},
		portal => 'prontera 70 70=prontera 100 100', type => 'portal_or_npc'}];
	{
		no warnings 'redefine';
		local *Task::Route::getRoute = sub { 1 };
		local *Task::MapRoute::isRouteTeleportAllowedOnMap = sub { 0 };
		local %Task::MapRoute::portals_lut = (
			'prontera 70 70' => {source => {map => 'prontera'},
				dest => {'prontera 100 100' => {enabled => 1, steps => ''}}},
		);
		Task::activate($staticParent);
		Task::MapRoute::iterate($staticParent);
	}
	ok($staticParent->getSubtask()
		&& $staticParent->getSubtask()->{stopWhenMapChanged},
		'conventional same-map static portal retains its existing segment-stop behavior');
}

package WarpPortalTest::Field;
sub baseName { $_[0]{map} || 'prontera' }
sub width { 40 }
sub height { 40 }
sub isWalkable { return $_[1] >= 0 && $_[2] >= 0 && $_[1] < 40 && $_[2] < 40; }

package WarpPortalTest::RouteField;
our @ISA = ('Field');
sub baseName { $_[0]{map} }
sub name { $_[0]{map} }
sub width { 40 }
sub height { 40 }
sub isWalkable { 1 }

package WarpPortalTest::RouteActor;
our @ISA = ('Actor');

package WarpPortalTest::LargeField;
sub width { 600 }
sub height { 800 }
sub isWalkable { 1 }

package WarpPortalTest::MapField;
sub baseName { $_[0]{map} }

package WarpPortalTest::Net;
sub getState { Network::IN_GAME }

package WarpPortalTest::HandoffNet;
sub setState { $_[0]{state} = $_[1] }
sub getState { $_[0]{state} }
sub version { 2 }
sub serverDisconnect { $_[0]{disconnects}++ }

package WarpPortalTest::HandoffCharacter;
sub cartActive { 0 }

package WarpPortalTest::HandoffSender;
sub sendMapLoaded { }
sub sendSync { }
sub sendGuildRequestInfo { }

package WarpPortalTest::PendingCalc;
our @ISA = ('Task');
sub new { my $class = shift; return bless(Task->new(), $class); }
sub iterate { }

package WarpPortalTest::CompletedUseSkill;
our @ISA = ('Task::UseSkill');
sub DESTROY { }

package WarpPortalTest::Skill;
sub getRange { 9 }
sub getHandle { 'AL_WARP' }
sub getIDN { 27 }
sub getLevel { 4 }
sub getSP { $_[1] == 4 ? 26 : 35 }
sub getTargetType { Skill::TARGET_LOCATION() }

package WarpPortalTest::Character;
sub getSkillLevel { $_[0]{learned} }
sub inventory { $_[0]{inventory} }
sub statusActive { 0 }

package WarpPortalTest::Inventory;
sub getByNameID { return {amount => $_[0]{amount}} if $_[1] == 717; return; }

package WarpPortalTest::Sender;
sub sendSkillUseLoc { $_[0]{last_skill_location} = [@_[1 .. 4]]; }
sub sendWarpTele { $_[0]{last_warp_destination} = $_[2]; }

package WarpPortalTest::UseSkillTask;
our @ISA = ('Task::UseSkill');
sub DESTROY { }

package WarpPortalTest;

1;
