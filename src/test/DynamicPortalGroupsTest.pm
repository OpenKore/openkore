# Unit test for dynamic portal groups and Eden portal sync.
package DynamicPortalGroupsTest;
use strict;

use Test::More;
use FindBin qw($RealBin);

use FileParsers;
use Globals;
use Misc qw(
	refreshDynamicPortalGroups
	refreshDynamicPortalStates
	applyDynamicPortalStates
	getDynamicPortalDestinations
);

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
	my %saved_dynamicPortalGroups = %Globals::dynamicPortalGroups;
	my %saved_config = %Globals::config;
	my $saved_char = $Globals::char;

	my $ok = eval { $code->(); 1 };
	my $error = $@;

	%Globals::portals_lut = %saved_portals_lut;
	%Globals::dynamicPortalGroups = %saved_dynamicPortalGroups;
	%Globals::config = %saved_config;
	$Globals::char = $saved_char;

	die $error unless $ok;
}

1;
