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
		warpPortal_autoUpdateMemo => 0, saveMap => 'prontera',
		memo1 => 'prontera 5 6', memo2 => 'payon 1 2', memo3 => 'geffen 3 4', memo4 => 'stale_map 7 8',
	);
	my @before = @Globals::config{qw(memo1 memo2 memo3 memo4)};
	my $writes = captureWrites(sub { serverList(4, qw(prontera geffen alberta payon)); });
	is(scalar(@$writes), 0, 'disabled synchronization makes no config writes when saveMap already matches');
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}], \@before,
		'manual entries stay byte-for-byte unchanged');
	is(warpMapIndex('payon'), 3, 'manual config order cannot select the wrong server destination');
	is(warpMapStatus('stale_map', 4), 'absent', 'manual stale map is not considered available');
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
	noteWarpSelection('geffen', 'prontera', 11, 10, 2, 'attempt-a', {x => 11, y => 10});
	my $unit = {ID => 'portal-unit-a', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	ok(noteWarpPortalUnitSeen($unit, 'prontera'), 'server-observed owned portal unit is tied to the active attempt');
	my $before = $Globals::config{memo3};
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'a map change without accepted movement and portal disappearance is not attributed');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'unrelated arrival clears the pending portal attempt');
	is($Globals::config{memo3}, $before, 'unrelated arrival cannot update memo coordinates');

	# The movement packet is server evidence that the character is moving onto
	# the exact portal tile, even when the local current position is one step stale.
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-b', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-b', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	ok(noteWarpPortalUnitSeen($unit, 'prontera'), 'owned portal creation is observed before movement');
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
	is_deeply([memoCoordinateForMap('geffen')], [120, 62, 'inferred_portal_entry_from_owned_unit_movement_disappearance_and_map_change'],
		'landing coordinates come from server map-change coordinates, not the stale source position');
	is($Globals::config{memo2}, 'geffen 120 62', 'inferred genuine arrival updates the uniquely matched memo');

	delete $Globals::char->{warpPortalState}{last_traversal};
	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-c', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-c', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	ok(noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera'), 'same-destination test has movement evidence');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'same-map transition without disappearance of the selected portal is not attributed');
	ok(!$Globals::char->{warpPortalState}{last_traversal}, 'ambiguous same-destination transition creates no traversal record');

	noteWarpSelection('geffen', 'prontera', 11, 10, 4, 'attempt-delayed-disappear', {x => 11, y => 10});
	$unit = {ID => 'portal-unit-late', sourceID => $Globals::char->{ID}, type => 0x81, x => 11, y => 10};
	noteWarpPortalUnitSeen($unit, 'prontera');
	noteWarpPortalMovement({x => 10, y => 10}, {x => 11, y => 10}, 'prontera');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62),
		'map change before portal disappearance remains unattributed');
	ok(!noteWarpPortalUnitDisappeared({%$unit, pos => {x => 11, y => 10}}, 'prontera'),
		'delayed disappearance cannot retroactively attribute an already cleared transition');
	ok(!$Globals::char->{warpPortalState}{last_traversal},
		'delayed packet ordering does not create confirmed traversal evidence');

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
	setupCharacter(
		warpPortal_autoUpdateMemo => 1, saveMap => 'prontera',
		memo1 => 'prontera', memo2 => 'geffen 20 21',
		memo3 => 'alberta 30 31', memo4 => 'payon 40 41',
	);
	serverList(4, 'prontera', 'custom_unknown_map', 'alberta', 'payon');
	is_deeply($Globals::char->{warpPortalState}{available_maps},
		['prontera', 'custom_unknown_map', 'alberta', 'payon'],
		'unsupported map remains an unresolved slot in the authoritative list');
	is(warpMapIndex('alberta'), 2, 'a later known destination keeps its actual server index');
	is($Globals::config{memo2}, 'geffen 20 21',
		'unknown map does not overwrite a coordinate pair with a different destination');
	is($Globals::config{memo3}, 'alberta 30 31',
		'known map after an unresolved slot retains its own coordinates');
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
	is_deeply([@Globals::config{qw(memo1 memo2 memo3 memo4)}], ['', '', '', ''],
		'runtime discovery does not require or modify configured memo hints');

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
		source => {map => 'prontera'}, targets => [], noWarpPortalMaps => {},
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
				$unknownLanding => {walk => 202, zeny => 0, is_warpPortal => 1},
				$knownLanding => {walk => 401, zeny => 0, is_warpPortal => 0},
			},
			openlist_heap => [[202, $unknownLanding], [401, $knownLanding]], closelist => {},
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

	# The server map change is authoritative for location, while missing portal
	# disappearance evidence leaves its cause unconfirmed. Continue routing from
	# that location without recording a traversal or blacklisting the source.
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

package WarpPortalTest::Field;
sub baseName { $_[0]{map} || 'prontera' }
sub width { 40 }
sub height { 40 }
sub isWalkable { return $_[1] >= 0 && $_[2] >= 0 && $_[1] < 40 && $_[2] < 40; }

package WarpPortalTest::LargeField;
sub width { 600 }
sub height { 800 }

package WarpPortalTest::MapField;
sub baseName { $_[0]{map} }

package WarpPortalTest::Net;
sub getState { Network::IN_GAME }

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
