# Unit test for dynamic portal groups and Eden portal sync.
package DynamicPortalGroupsTest;
use strict;

use Test::More;
use FindBin qw($RealBin);

use FileParsers;
use Globals;
use Settings;
use Misc qw(
	refreshDynamicPortalGroups
	refreshDynamicPortalStates
	applyDynamicPortalStates
	getDynamicPortalDestinations
	suspendRouteSource
	restoreSuspendedRouteSource
);
use Task::CalcMapRoute;

{
	package DynamicPortalGroupsTest::FakeTalkNPC;

	sub new {
		return bless {}, shift;
	}

	sub isa {
		my ($self, $class) = @_;
		return 1 if $class eq 'Task::TalkNPC';
		return UNIVERSAL::isa($self, $class);
	}
}

{
	package DynamicPortalGroupsTest::FakeMapRoute;

	sub new {
		my ($class, %args) = @_;
		return bless \%args, $class;
	}

	sub getSubtask {
		return $_[0]{subtask};
	}

	sub isa {
		my ($self, $class) = @_;
		return 1 if $class eq 'Task::MapRoute';
		return UNIVERSAL::isa($self, $class);
	}
}

sub start {
	print "### Starting DynamicPortalGroupsTest\n";

	subtest 'dynamic portal groups' => sub {
		_with_saved_globals(sub {
			%Globals::portals_lut = ();
			%Globals::dynamicPortalGroups = ();
			%Globals::config = ();

			parsePortals(_test_file('dynamic_portals.txt'), \%Globals::portals_lut);

			ok(
				($Globals::portals_lut{'moc_para01 30 10'}{dest}{'prontera 116 72'}{dynamicPortalGroup} || '') eq 'EdenPortalExit',
				'parsePortals keeps dynamic portal markers'
			);
			ok(
				($Globals::portals_lut{'geffen 132 66'}{dest}{'moc_para01 31 14'}{dynamicPortalGroupBlock} || '') eq 'EdenPortalExit',
				'parsePortals keeps dynamic portal block markers'
			);
			ok(
				defined $Globals::portals_lut{'moc_para01 50 50'}{dest}{'morocc 160 97'}{steps},
				'stepped portal is parsed as a non-simple portal'
			);

			refreshDynamicPortalGroups();

			ok(exists $Globals::dynamicPortalGroups{EdenPortalExit}, 'dynamic group is generated from portal markers');
			ok(
				exists $Globals::dynamicPortalGroups{EdenPortalExit}{sources}{'moc_para01 30 10'}{destinations}{'prontera 116 72'},
				'first source keeps its own destinations'
			);
			ok(
				exists $Globals::dynamicPortalGroups{EdenPortalExit}{sources}{'moc_para01 40 20'}{destinations}{'geffen 120 39'},
				'second source keeps its own destinations'
			);
			ok(
				!exists $Globals::dynamicPortalGroups{EdenPortalExit}{sources}{'moc_para01 50 50'},
				'stepped portals are ignored when building dynamic groups'
			);

			is_deeply(
				getDynamicPortalDestinations('EdenPortalExit'),
				{
					'prontera 116 72' => 1,
					'payon 161 58' => 1,
					'geffen 120 39' => 1,
					'alberta 117 56' => 1,
				},
				'flattened destination list stays available to callers'
			);

			$Globals::config{EdenPortalExit} = 'payon';
			applyDynamicPortalStates();
			ok($Globals::portals_lut{'moc_para01 30 10'}{dest}{'payon 161 58'}{enabled}, 'matching destination stays enabled');
			ok(!$Globals::portals_lut{'moc_para01 30 10'}{dest}{'prontera 116 72'}{enabled}, 'other destinations from same source are disabled');
			ok(!$Globals::portals_lut{'moc_para01 40 20'}{dest}{'geffen 120 39'}{enabled}, 'unmatched destinations from other sources are disabled');
			ok(!$Globals::portals_lut{'moc_para01 40 20'}{dest}{'alberta 117 56'}{enabled}, 'all other-source destinations remain disabled');

			$Globals::config{EdenPortalExit} = 'geffen';
			applyDynamicPortalStates();
			ok($Globals::portals_lut{'moc_para01 40 20'}{dest}{'geffen 120 39'}{enabled}, 'selection can enable a different source cluster');
			ok(!$Globals::portals_lut{'moc_para01 30 10'}{dest}{'payon 161 58'}{enabled}, 'previously enabled destination is disabled after selection changes');

			$Globals::config{EdenPortalExit} = 'alberta';
			parsePortals(_test_file('dynamic_portals.txt'), \%Globals::portals_lut);
			refreshDynamicPortalStates();
			ok($Globals::portals_lut{'moc_para01 40 20'}{dest}{'alberta 117 56'}{enabled}, 'refresh after portal reload restores the selected destination');
			ok(!$Globals::portals_lut{'moc_para01 30 10'}{dest}{'payon 161 58'}{enabled}, 'refresh after portal reload disables stale destinations again');
		});

		done_testing();
	};

	subtest 'eden portal exit sync plugin' => sub {
		_with_saved_globals(sub {
			%Globals::portals_lut = ();
			%Globals::dynamicPortalGroups = ();
			%Globals::config = ();
			$Globals::char = undef;

			parsePortals(_test_file('dynamic_portals.txt'), \%Globals::portals_lut);
			refreshDynamicPortalGroups();

			_loadEdenPlugin();

			my @config_updates;
			no warnings 'redefine';
			local *edenPortalExitSync::configModify = sub {
				my ($key, $value) = @_;
				$Globals::config{$key} = $value;
				push @config_updates, [$key, $value];
			};
			local *edenPortalExitSync::warning = sub {};

			my $task = DynamicPortalGroupsTest::FakeMapRoute->new(
				subtask => DynamicPortalGroupsTest::FakeTalkNPC->new(),
				mapSolution => [{
					portal => 'prontera 120 70=moc_para01 30 10',
					steps  => 'c r0 n',
				}],
			);
			local *AI::findAction = sub {
				my ($action) = @_;
				return 0 if $action eq 'route';
				return;
			};
			local *AI::args = sub {
				return $task;
			};

			edenPortalExitSync::_updateFromEdenArrival('prontera');
			is($Globals::config{EdenPortalExit}, 'prontera', 'arrival into Eden stores the source city as exit');
			is_deeply(\@config_updates, [['EdenPortalExit', 'prontera']], 'arrival updates the config once');

			@config_updates = ();
			$Globals::config{EdenPortalExit} = 'geffen';
			$Globals::char = {
				pos => {x => 161, y => 58},
			};

			edenPortalExitSync::_updateFromEdenExit('payon');
			is($Globals::config{EdenPortalExit}, 'payon', 'leaving Eden rewrites the exit when the actual destination differs');
			is_deeply(\@config_updates, [['EdenPortalExit', 'payon']], 'exit updates the config once');

			@config_updates = ();
			$Globals::config{EdenPortalExit} = 'geffen';
			$Globals::char = {
				pos => {x => 10, y => 10},
			};

			edenPortalExitSync::_updateFromEdenExit('payon');
			is($Globals::config{EdenPortalExit}, 'geffen', 'non-portal exits from Eden do not rewrite the configured destination');
			is_deeply(\@config_updates, [], 'non-portal exits do not write config changes');

			@config_updates = ();
			$Globals::char = {
				pos => {x => 162, y => 58},
			};

			edenPortalExitSync::_updateFromEdenExit('payon');
			is($Globals::config{EdenPortalExit}, 'payon', 'small landing offsets still resolve to the expected Eden exit destination');
			is_deeply(\@config_updates, [['EdenPortalExit', 'payon']], 'nearby portal landing still updates config once');
		});

		done_testing();
	};

	subtest 'calc map route blocks tagged dynamic exits after blocker portal' => sub {
		_with_saved_globals(sub {
			($Settings::fields_folder) = grep -d, "$RealBin/../../../../fieldpack/trunk/fields", "$RealBin/../../fields";

			%Globals::portals_lut = ();
			%Globals::portals_los = ();
			%Globals::dynamicPortalGroups = ();
			%Globals::config = (
				EdenPortalExit => 'prontera',
			);
			%Globals::routeWeights = (
				PORTAL => 1,
				NPC => 5,
				AIRSHIP => 20,
				COMMAND => 20,
			);
			$Globals::char = {
				zeny => 0,
			};

			$Globals::portals_lut{'rachel 125 144'} = {
				source => { map => 'rachel', x => 125, y => 144 },
				dest => {
					'moc_para01 31 14' => {
						map => 'moc_para01', x => 31, y => 14,
						enabled => 1, cost => 0, allow_ticket => 0, steps => 'c c r0',
						dynamicPortalGroupBlock => 'EdenPortalExit',
					},
				},
			};
			$Globals::portals_lut{'moc_para01 30 10'} = {
				source => { map => 'moc_para01', x => 30, y => 10 },
				dest => {
					'prontera 116 72' => {
						map => 'prontera', x => 116, y => 72,
						enabled => 1, cost => 0, allow_ticket => 0, steps => '',
						dynamicPortalGroup => 'EdenPortalExit',
					},
					'rachel 115 125' => {
						map => 'rachel', x => 115, y => 125,
						enabled => 1, cost => 0, allow_ticket => 0, steps => '',
						dynamicPortalGroup => 'EdenPortalExit',
					},
				},
			};

			$Globals::portals_los{'moc_para01 31 14'} = {
				'moc_para01 30 10' => 1,
			};
			$Globals::portals_los{'rachel 115 125'} = {};
			$Globals::portals_los{'prontera 116 72'} = {};

			refreshDynamicPortalGroups();
			applyDynamicPortalStates();

			ok($Globals::portals_lut{'moc_para01 30 10'}{dest}{'prontera 116 72'}{enabled}, 'configured Eden exit starts enabled');
			ok(!$Globals::portals_lut{'moc_para01 30 10'}{dest}{'rachel 115 125'}{enabled}, 'non-configured Eden exit starts disabled');

			no warnings 'redefine';
			local *Task::Route::getRoute = sub {
				my ($solution, undef, $from, $to) = @_;
				my $distance = abs(($from->{x} || 0) - ($to->{x} || 0)) + abs(($from->{y} || 0) - ($to->{y} || 0));
				@{$solution} = (1) x ($distance || 1) if ref($solution) eq 'ARRAY';
				return 1;
			};

			my $fromRachel = Task::CalcMapRoute->new(
				sourceMap => 'rachel',
				sourceX => 125,
				sourceY => 144,
				map => 'prontera',
				x => 116,
				y => 72,
				noGoCommand => 1,
				noTeleSpawn => 1,
				noWarpItem => 1,
				noAirship => 1,
				maxTime => 1,
				suppressDebug => 1,
			);
			$fromRachel->activate();
			$fromRachel->iterate() while ($fromRachel->getStatus() != Task::DONE);

			ok($fromRachel->getError(), 'route from Rachel to Prontera cannot use Eden exits after blocker portal');

			my $fromInsideEden = Task::CalcMapRoute->new(
				sourceMap => 'moc_para01',
				sourceX => 31,
				sourceY => 14,
				map => 'prontera',
				x => 116,
				y => 72,
				noGoCommand => 1,
				noTeleSpawn => 1,
				noWarpItem => 1,
				noAirship => 1,
				maxTime => 1,
				suppressDebug => 1,
			);
			$fromInsideEden->activate();
			$fromInsideEden->iterate() while ($fromInsideEden->getStatus() != Task::DONE);

			ok(!$fromInsideEden->getError(), 'route starting inside Eden can still use Eden exits');
			is($fromInsideEden->getRoute->[0]{portal}, 'moc_para01 30 10=prontera 116 72', 'Eden exit remains available when no blocker portal was used');
		});

		done_testing();
	};

	subtest 'calc map route keeps blocker state through internal eden nodes' => sub {
		_with_saved_globals(sub {
			%Globals::portals_lut = ();
			%Globals::portals_los = ();
			%Globals::dynamicPortalGroups = ();
			%Globals::config = (
				EdenPortalExit => 'prontera',
			);
			%Globals::routeWeights = (
				PORTAL => 1,
				NPC => 5,
				AIRSHIP => 20,
				COMMAND => 20,
			);
			$Globals::char = {
				zeny => 0,
			};

			$Globals::portals_lut{'rachel 125 144'} = {
				source => { map => 'rachel', x => 125, y => 144 },
				dest => {
					'moc_para01 47 39' => {
						map => 'moc_para01', x => 47, y => 39,
						enabled => 1, cost => 0, allow_ticket => 0, steps => 'c c r0',
						dynamicPortalGroupBlock => 'EdenPortalExit',
					},
				},
			};
			$Globals::portals_lut{'moc_para01 30 10'} = {
				source => { map => 'moc_para01', x => 30, y => 10 },
				dest => {
					'prontera 116 72' => {
						map => 'prontera', x => 116, y => 72,
						enabled => 1, cost => 0, allow_ticket => 0, steps => '',
						dynamicPortalGroup => 'EdenPortalExit',
					},
					'rachel 115 125' => {
						map => 'rachel', x => 115, y => 125,
						enabled => 1, cost => 0, allow_ticket => 0, steps => '',
						dynamicPortalGroup => 'EdenPortalExit',
					},
				},
			};

			$Globals::portals_los{'moc_para01 47 39'} = {
				'moc_para01 30 10' => 1,
			};
			$Globals::portals_los{'rachel 115 125'} = {};
			$Globals::portals_los{'prontera 116 72'} = {};

			refreshDynamicPortalGroups();
			applyDynamicPortalStates();

			no warnings 'redefine';
			local *Task::Route::getRoute = sub {
				my ($solution, undef, $from, $to) = @_;
				my $distance = abs(($from->{x} || 0) - ($to->{x} || 0)) + abs(($from->{y} || 0) - ($to->{y} || 0));
				@{$solution} = (1) x ($distance || 1) if ref($solution) eq 'ARRAY';
				return 1;
			};

			my $task = Task::CalcMapRoute->new(
				sourceMap => 'rachel',
				sourceX => 125,
				sourceY => 144,
				map => 'prontera',
				x => 116,
				y => 72,
				noGoCommand => 1,
				noTeleSpawn => 1,
				noWarpItem => 1,
				noAirship => 1,
				maxTime => 1,
				suppressDebug => 1,
			);
			$task->activate();
			$task->iterate() while ($task->getStatus() != Task::DONE);

			ok($task->getError(), 'route through internal Eden nodes keeps blocking Eden exits after blocker portal');
		});

		done_testing();
	};

	subtest 'calc map route blocks tagged dynamic exits after Eden warp item' => sub {
		_with_saved_globals(sub {
			($Settings::fields_folder) = grep -d, "$RealBin/../../../../fieldpack/trunk/fields", "$RealBin/../../fields";

			%Globals::portals_lut = ();
			%Globals::portals_los = ();
			%Globals::dynamicPortalGroups = ();
			%Globals::teleport_items = ();
			%Globals::config = (
				EdenPortalExit => 'prontera',
				route_warpByItem => 1,
				route_warpByItem_minDistance => 0,
			);
			%Globals::routeWeights = (
				PORTAL => 1,
				NPC => 5,
				AIRSHIP => 20,
				COMMAND => 20,
				WARPITEM => 80,
			);
			$Globals::char = {
				lv => 100,
				zeny => 0,
			};

			$Globals::portals_lut{'moc_para01 30 10'} = {
				source => { map => 'moc_para01', x => 30, y => 10 },
				dest => {
					'prontera 116 72' => {
						map => 'prontera', x => 116, y => 72,
						enabled => 1, cost => 0, allow_ticket => 0, steps => '',
						dynamicPortalGroup => 'EdenPortalExit',
					},
				},
			};

			$Globals::portals_los{'moc_para01 171 115'} = {
				'moc_para01 30 10' => 1,
			};
			$Globals::portals_los{'prontera 116 72'} = {};

			$Globals::teleport_items{list} = [{
				itemID => 22508,
				mode => 'warp',
				destMap => 'moc_para01',
				destX => 171,
				destY => 115,
				minLevel => 1,
				maxLevel => 0,
				timeoutSec => 1200,
				dynamicPortalGroupBlock => 'EdenPortalExit',
			}];

			refreshDynamicPortalGroups();
			applyDynamicPortalStates();

			no warnings 'redefine';
			local *Task::Route::getRoute = sub {
				my ($solution, undef, $from, $to) = @_;
				my $distance = abs(($from->{x} || 0) - ($to->{x} || 0)) + abs(($from->{y} || 0) - ($to->{y} || 0));
				@{$solution} = (1) x ($distance || 1) if ref($solution) eq 'ARRAY';
				return 1;
			};
			local *Task::CalcMapRoute::getWarpItemCandidates = sub {
				return @{$Globals::teleport_items{list}};
			};

			my $task = Task::CalcMapRoute->new(
				sourceMap => 'aldebaran',
				sourceX => 143,
				sourceY => 109,
				map => 'prontera',
				x => 116,
				y => 72,
				noGoCommand => 1,
				noTeleSpawn => 1,
				noAirship => 1,
				maxTime => 1,
				suppressDebug => 1,
			);
			$task->activate();
			$task->iterate() while ($task->getStatus() != Task::DONE);

			ok($task->getError(), 'route cannot use Eden exits after Eden warp item adds blocker state');
		});

		done_testing();
	};

	subtest 'route source suppression marks entries removed and restores them later' => sub {
		_with_saved_globals(sub {
			%Globals::portals_lut = ();
			%Globals::portals_los = ();
			@Globals::portals_lut_missed = ();

			$Globals::portals_lut{'prontera 10 20'} = {
				source => { map => 'prontera', x => 10, y => 20 },
				dest => {
					'izlude 30 40' => {
						map => 'izlude', x => 30, y => 40,
						enabled => 1, cost => 0, allow_ticket => 0, steps => '',
					},
				},
			};
			$Globals::portals_los{'izlude 30 40'} = {
				'prontera 10 20' => 7,
			};
			$Globals::portals_los{'geffen 50 60'} = {
				'prontera 10 20' => 12,
			};

			my $record = suspendRouteSource('prontera 10 20');
			ok($record, 'route source is queued for restoration');
			ok($Globals::portals_lut{'prontera 10 20'}{removed}, 'route source is marked removed in portals_lut');
			is($Globals::portals_los{'izlude 30 40'}{'prontera 10 20'}, 7, 'first portals_los edge stays intact while source is suspended');
			is($Globals::portals_los{'geffen 50 60'}{'prontera 10 20'}, 12, 'second portals_los edge stays intact while source is suspended');
			is(scalar @Globals::portals_lut_missed, 1, 'removed route source is queued for later restoration');
			ok(!Misc::portalExists('prontera', { x => 10, y => 20 }), 'portalExists ignores suspended route sources');
			ok(!Misc::portalExists2('prontera', { x => 10, y => 20 }, 'izlude', { x => 30, y => 40 }), 'portalExists2 ignores suspended route sources');

			restoreSuspendedRouteSource($record);
			ok(exists $Globals::portals_lut{'prontera 10 20'}, 'route source is restored to portals_lut');
			ok(!$Globals::portals_lut{'prontera 10 20'}{removed}, 'removed flag is cleared on restore');
			is($Globals::portals_los{'izlude 30 40'}{'prontera 10 20'}, 7, 'first portals_los edge is restored');
			is($Globals::portals_los{'geffen 50 60'}{'prontera 10 20'}, 12, 'second portals_los edge is restored');

			ok(Misc::portalExists2('prontera', { x => 10, y => 20 }, 'izlude', { x => 30, y => 40 }), 'portalExists2 still matches the restored portal');
			ok(!grep { $_ eq 'pos' } keys %{$Globals::portals_lut{'prontera 10 20'}{source}}, 'portalExists2 does not autovivify source pos');
		});

		done_testing();
	};
}

sub _loadEdenPlugin {
	return if defined &edenPortalExitSync::onMapChanged;

	my $path = "$RealBin/../../plugins/edenPortalExitSync/edenPortalExitSync.pl";
	my $loaded = do $path;
	die "Could not load $path: $@" if $@;
	die "Could not load $path: $!" unless defined $loaded;
}

sub _test_file {
	my ($file) = @_;
	return "$RealBin/$file";
}

sub _with_saved_globals {
	my ($code) = @_;

	my %saved_portals_lut = %Globals::portals_lut;
	my %saved_portals_los = %Globals::portals_los;
	my %saved_dynamicPortalGroups = %Globals::dynamicPortalGroups;
	my %saved_teleport_items = %Globals::teleport_items;
	my %saved_config = %Globals::config;
	my %saved_routeWeights = %Globals::routeWeights;
	my @saved_portals_lut_missed = @Globals::portals_lut_missed;
	my $saved_char = $Globals::char;

	my $ok = eval { $code->(); 1 };
	my $error = $@;

	%Globals::portals_lut = %saved_portals_lut;
	%Globals::portals_los = %saved_portals_los;
	%Globals::dynamicPortalGroups = %saved_dynamicPortalGroups;
	%Globals::teleport_items = %saved_teleport_items;
	%Globals::config = %saved_config;
	%Globals::routeWeights = %saved_routeWeights;
	@Globals::portals_lut_missed = @saved_portals_lut_missed;
	$Globals::char = $saved_char;

	die $error unless $ok;
}

1;
