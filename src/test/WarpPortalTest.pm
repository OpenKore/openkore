package WarpPortalTest;

use strict;
use Test::More;
use Globals;
use Misc;
use WarpPortal qw(
	parseMemoEntry normalizeWarpMap beginCharacterSession noteWarpCast
	noteMemoRequest memoAcknowledged updateServerMemos recordArrival
	availableWarpMaps warpMapIndex warpMapStatus memoCoordinateForMap
	noteWarpSelection confirmPortalArrival
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
	ok(!parseMemoEntry('unknown_map')->{valid}, 'rejects maps absent from the map table');
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

	noteWarpSelection('geffen', 'prontera', 10, 10, 2, 'attempt-a');
	$Globals::char->{warpPortalPendingTraversal}{portal_seen_at} = time;
	$Globals::char->{warpPortalPendingTraversal}{portal_pos} = {x => 11, y => 10};
	my $before = $Globals::config{memo3};
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62, {x => 12, y => 10}),
		'a map change away from the observed portal tile is not a confirmed traversal');
	ok(!$Globals::char->{warpPortalPendingTraversal}, 'unrelated arrival clears the pending portal attempt');
	ok(!confirmPortalArrival('prontera', 'geffen', 120, 62, {x => 11, y => 10}),
		'cleared fallback state cannot be reused as a portal traversal');
	is($Globals::config{memo3}, $before, 'unrelated fallback arrival cannot update coordinates');

	noteWarpSelection('geffen', 'prontera', 10, 10, 2, 'attempt-b');
	$Globals::config{memo2} = 'geffen 100 100';
	$Globals::config{memo3} = '';
	$Globals::char->{warpPortalPendingTraversal}{portal_seen_at} = time;
	$Globals::char->{warpPortalPendingTraversal}{portal_pos} = {x => 11, y => 10};
	my $arrival = confirmPortalArrival('prontera', 'geffen', 120, 62, {x => 11, y => 10});
	ok($arrival && $arrival->{attempt_id} eq 'attempt-b', 'confirmed arrival is correlated to the live attempt');
		is($Globals::config{memo2}, 'geffen 120 62', 'arrival corrects coordinates on the uniquely matched map entry');

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
		['prontera', '', 'alberta', 'payon'],
		'unsupported map remains an unresolved slot in the authoritative list');
	is(warpMapIndex('alberta'), 2, 'a later known destination keeps its actual server index');
	is($Globals::config{memo2}, 'geffen 20 21',
		'unknown map does not overwrite a coordinate pair with a different destination');
	is($Globals::config{memo3}, 'alberta 30 31',
		'known map after an unresolved slot retains its own coordinates');
}

1;
