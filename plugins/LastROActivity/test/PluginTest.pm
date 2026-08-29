package PluginTest;

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Test::More;

our @trace;

# Keep this test independent of OpenKore's native extensions.  The plugin only
# needs the small portions of these packages that are exercised below.
BEGIN {
	$INC{'Globals.pm'} = __FILE__;
	package Globals;
	our %config;
	our %maps_lut;
	our %mon_control;
	our %monsters_lut;
	our ($net, $char, $field, $masterServer);
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::config"} = \%config;
		*{"${caller}::net"} = \$net;
		*{"${caller}::char"} = \$char;
		*{"${caller}::field"} = \$field;
		*{"${caller}::masterServer"} = \$masterServer;
	}

	$INC{'Plugins.pm'} = __FILE__;
	package Plugins;
	our $current_plugin_folder;
	our @registrations;
	our @hooks;
	our %hook_callbacks;
	our %registered_plugins;
	sub import { return 1; }
	sub register {
		push @registrations, [@_];
		$registered_plugins{$_[0]} = 1 if defined $_[0];
		return 1;
	}
	sub registered { return $registered_plugins{$_[0]} ? 1 : 0; }
	sub addHooks {
		push @hooks, map { $_->[0] } @_;
		$hook_callbacks{$_->[0]} = $_->[1] for @_;
		return bless { hooks => [@_] }, 'Plugins::TestHookHandle';
	}
	sub addHook {
		my ($name, $callback) = @_;
		$hook_callbacks{$name} = $callback;
		return bless {name => $name}, 'Plugins::TestSingleHookHandle';
	}
	sub delHook {
		my ($handle) = @_;
		delete $hook_callbacks{$handle->{name}}
			if ref($handle) eq 'Plugins::TestSingleHookHandle';
		return 1;
	}
	sub delHooks { return 1; }
	sub callHook {
		my ($name, $argument) = @_;
		my $callback = $hook_callbacks{$name};
		$callback->($name, $argument) if ref($callback) eq 'CODE';
		return 1;
	}

	$INC{'Commands.pm'} = __FILE__;
	package Commands;
	our %commands;
	our %descriptors;
	our @run_calls;
	our $run_failure;
	sub import { return 1; }
	sub register {
		for my $command (@_) {
			$commands{$command->[0]} = $command->[2];
			$descriptors{$command->[0]} = $command->[1];
		}
		return [map { $_->[0] } @_];
	}
	sub unregister { return 1; }
	sub run {
		my $command = $_[0];
		push @run_calls, $command;
		push @PluginTest::trace, $command;
		if (ref($run_failure) eq 'CODE') {
			return $run_failure->($command);
		}
		die $run_failure if defined $run_failure && $run_failure ne '';
		return 1;
	}

	$INC{'Settings.pm'} = __FILE__;
	package Settings;
	our @add_calls;
	our @remove_calls;
	our %handles;
	our @control_folders = ('control');
	our $load_path;
	my $next_handle = 1;
	sub import { return 1; }
	sub addControlFile {
		my ($name, %options) = @_;
		$options{autoSearch} = 1 unless exists $options{autoSearch};
		my $handle = $next_handle++;
		$handles{$handle} = {name => $name, %options};
		push @add_calls, [$name, \%options];
		return $handle;
	}
	sub loadByHandle {
		my ($handle) = @_;
		my $entry = $handles{$handle};
		my $loader = $entry && $entry->{loader};
		return unless $loader;
		my $internal = $entry->{internalName} || $entry->{name};
		my $pre_load = {internalFilename => $internal, filename => undef};
		Plugins::callHook("pre_load_$internal", $pre_load);
		my $path;
		if ($pre_load->{return}) {
			$path = $pre_load->{filename};
		} elsif (defined $load_path) {
			$path = $load_path;
		} elsif ($entry->{autoSearch}) {
			for my $folder (@control_folders) {
				my $candidate = File::Spec->catfile($folder, $entry->{name});
				if (-f $candidate) {
					$path = $candidate;
					last;
				}
			}
		}
		$path = $entry->{name} unless defined $path;
		return unless -f $path;
		if (ref($loader) eq 'ARRAY') {
			my @loader = @$loader;
			my $callback = shift @loader;
			$callback->($path, @loader);
		} else {
			$loader->($path);
		}
		return 1;
	}
	sub loadAll {
		loadByHandle($_) for sort { $a <=> $b } keys %handles;
		return 1;
	}
	sub removeFile {
		my ($handle) = @_;
		push @remove_calls, $handle if defined $handle;
		delete $handles{$handle} if defined $handle;
		return 1;
	}
	sub getControlFilename {
		my ($name) = @_;
		return $load_path if defined $load_path && -f $load_path;
		for my $folder (@control_folders) {
			my $candidate = File::Spec->catfile($folder, $name);
			return $candidate if -f $candidate;
		}
		return undef;
	}
	sub getControlFolders { return @control_folders; }

	$INC{'AI.pm'} = __FILE__;
	package AI;
	our @clear_calls;
	sub import { return 1; }
	sub clear {
		my $call = join(' ', 'AI::clear', @_);
		push @clear_calls, $call;
		push @PluginTest::trace, $call;
		return 1;
	}

	$INC{'Network.pm'} = __FILE__;
	package Network;
	sub IN_GAME () { 5; }

	package PluginTest::Net;
	sub new { bless {}, shift; }
	sub getState { return Network::IN_GAME; }

	package PluginTest::Inventory;
	sub new { my ($class, $items) = @_; bless {items => $items || {}}, $class; }
	sub getByNameID {
		my ($self, $item_id) = @_;
		return $self->{items}{$item_id};
	}

	package PluginTest::Char;
	sub new { my ($class, $inventory) = @_; bless {inventory => $inventory}, $class; }
	sub inventory { return $_[0]->{inventory}; }

	package PluginTest::Field;
	sub new { my ($class, $map) = @_; bless {map => $map}, $class; }
	sub baseName { return $_[0]->{map}; }

	$INC{'Log.pm'} = __FILE__;
	package Log;
	our (@messages, @warnings, @errors, @debug);
	sub import {
		my $caller = caller;
		no strict 'refs';
		for my $name (qw(message warning error debug)) {
			*{"${caller}::${name}"} = \&{$name};
		}
	}
	sub message { push @messages, $_[0]; return 1; }
	sub warning { push @warnings, $_[0]; return 1; }
	sub error { push @errors, $_[0]; return 1; }
	sub debug { push @debug, $_[0]; return 1; }
}

sub _write_fixture {
	my ($fh, $path) = tempfile('lastro-activity-plugin-XXXXXX', UNLINK => 1);
	binmode $fh, ':encoding(UTF-8)';
	print {$fh} <<'RULES';
[far_event]
enabled=1
announce_regex=活动
lead_seconds=10
RULES
	close $fh;
	return $path;
}

sub _write_interruption_fixture {
	my ($fh, $path) = tempfile('lastro-activity-interrupt-XXXXXX', UNLINK => 1);
	binmode $fh, ':encoding(UTF-8)';
	print {$fh} <<'RULES';
[monster_event]
enabled=1
announce_regex=活动
lead_seconds=10
entry_type=privateairship
entry_item_id=14527
map_source=static
entry_map=event_map
search_targets=event_egg,event_mvp
RULES
	close $fh;
	return $path;
}

sub _write_active_fixture {
	my $folder = tempdir('lastro-activity-control-XXXXXX', CLEANUP => 1);
	my $path = File::Spec->catfile($folder, 'lastro_activity.txt');
	open my $fh, '>:encoding(UTF-8)', $path or die "Unable to write $path: $!";
	print {$fh} <<'RULES';
[active_event]
enabled=1
announce_regex=活动
lead_seconds=12
RULES
	close $fh;
	return ($folder, $path);
}

sub _write_overlap_fixture {
	my ($fh, $path) = tempfile('lastro-activity-overlap-XXXXXX', UNLINK => 1);
	binmode $fh, ':encoding(UTF-8)';
	print {$fh} <<'RULES';
[aaa_high]
enabled=1
announce_regex=活动
lead_seconds=10
priority=5

[zzz_low]
enabled=1
announce_regex=活动
lead_seconds=10
priority=1
RULES
	close $fh;
	return $path;
}

sub _write_multi_fixture {
	my ($fh, $path) = tempfile('lastro-activity-multi-XXXXXX', UNLINK => 1);
	binmode $fh, ':encoding(UTF-8)';
	print {$fh} <<'RULES';
[keep_event]
enabled=1
announce_regex=活动
lead_seconds=10

[drop_event]
enabled=1
announce_regex=活动
lead_seconds=10
RULES
	close $fh;
	return $path;
}

sub _write_keep_fixture {
	my ($fh, $path) = tempfile('lastro-activity-keep-XXXXXX', UNLINK => 1);

	binmode $fh, ':encoding(UTF-8)';
	print {$fh} <<'RULES';
[keep_event]
enabled=1
announce_regex=活动
lead_seconds=10
RULES
	close $fh;
	return $path;
}

sub _load_plugin {
	local $SIG{__WARN__} = sub {
		my $warning = shift;
		CORE::warn($warning) unless $warning =~ /^Subroutine .* redefined /;
	};
	my $plugin = File::Spec->catfile($RealBin, '..', 'LastROActivity.pl');
	my $result = do $plugin;
	die "Unable to load LastROActivity.pl: $@ $!" if !defined $result;
}

sub start {
	my $fixture = _write_fixture();
	%Globals::config = ();
	%Globals::maps_lut = ();
	%Globals::mon_control = ();
	%Globals::monsters_lut = ();
	$Globals::net = undef;
	$Globals::char = undef;
	$Globals::field = undef;
	$Globals::masterServer = undef;
	@Plugins::registrations = ();
	@Plugins::hooks = ();
	%Commands::commands = ();
	%Plugins::registered_plugins = ();
	@Commands::run_calls = ();
	$Commands::run_failure = undef;
	%Commands::descriptors = ();
	@Settings::add_calls = ();
	@Settings::control_folders = ('control');
	$Settings::load_path = undef;
	%Plugins::hook_callbacks = ();
	@Log::messages = ();
	@Log::warnings = ();
	@Log::errors = ();

	_load_plugin();
	my $start3 = $Plugins::hook_callbacks{start3};
	ok(ref($start3) eq 'CODE', 'defers config initialization to start3');
	$start3->(undef, {});

	subtest 'registers the plugin hooks and command' => sub {
		is($Plugins::registrations[0][0], 'LastROActivity', 'registers LastROActivity');
		is_deeply(
			[sort @Plugins::hooks],
			[sort qw(packet_sysMsg packet_pubMsg mainLoop_pre packet_mapChange lastro_airship_result AI_state_change start3)],
			'registers all activity hooks',
		);
		ok(exists $Commands::commands{lastroactivity}, 'registers lastroactivity command');
		is($Commands::descriptors{lastroactivity}[0], 'LastROActivity activity scheduling', 'command help has a top-level description');
		is($Commands::descriptors{lastroactivity}[1][0], 'status', 'command help retains the status subcommand');
		is(LastROActivity::enabled(), 1, 'missing enabled config defaults to on');
		is(LastROActivity::lead_seconds(), 10, 'missing lead config defaults to ten seconds');
		is(LastROActivity::teleport_idle(), 1, 'missing teleport idle config defaults to one');
		is($Settings::add_calls[0][0], 'lastro_activity.txt', 'missing rules path uses active control filename');
		is(
			File::Spec->rel2abs(LastROActivity::rules_file()),
			File::Spec->rel2abs(File::Spec->catfile($RealBin, '..', 'control', 'lastro_activity.txt')),
			'missing active rules file falls back to the bundled plugin fixture',
		);
		ok(exists LastROActivity::rules()->{lottery}, 'bundled fixture is loaded when no active override exists');
		done_testing();
	};

	subtest 'active control rules override the bundled fixture' => sub {
		my ($active_folder, $active_path) = _write_active_fixture();
		LastROActivity::onUnload();
		%Globals::config = ();
		$Settings::load_path = undef;
		@Settings::control_folders = ($active_folder);
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		is(File::Spec->rel2abs(LastROActivity::rules_file()), File::Spec->rel2abs($active_path), 'active control rules take precedence over bundled rules');
		ok(exists LastROActivity::rules()->{active_event}, 'active control rule is loaded');
		done_testing();
	};

	subtest 'uses values loaded before the deferred startup hook' => sub {
		LastROActivity::onUnload();
		%Globals::config = (
			lastroActivity_enabled => 1,
			lastroActivity_rulesFile => $fixture,
			lastroActivity_leadSeconds => 25,
			lastroActivity_teleportIdle => 3,
		);
		$Settings::load_path = $fixture;
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		@Commands::run_calls = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		ok(LastROActivity::lead_seconds() == 10, 'plugin keeps safe defaults before start3');
		$Plugins::hook_callbacks{start3}->(undef, {});
		is(LastROActivity::enabled(), 1, 'deferred startup reads enabled config');
		is(LastROActivity::lead_seconds(), 25, 'deferred startup reads lead config');
		is(LastROActivity::teleport_idle(), 3, 'deferred startup reads teleport idle config');
		is($Settings::add_calls[0][0], $fixture, 'deferred startup registers configured rules path');
		$LastROActivity::clock = sub { 1_000 };
		my $event = LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		is($event->{trigger_at}, 8_190, 'scheduler honors the rule-specific lead interval');
		$Plugins::hook_callbacks{start3}->(undef, {});
		is(scalar @Settings::add_calls, 1, 'repeated startup hook does not reinitialize state');
		done_testing();
	};

	subtest 'uses Msg and falls back to RawMsg when arming' => sub {
		$LastROActivity::clock = sub { 1_000 };
		my $event = LastROActivity::onSystemMessage(undef, {
			Msg => '活动将在2小时后开始',
			RawMsg => 'ignored raw text',
		});
		is($event->{event_id}, 'far_event', 'Msg is passed to the scheduler');
		is($event->{trigger_at}, 8_190, 'long countdown remains armed until its lead boundary');
		is(LastROActivity::state(), 'ARMED', 'long countdown enters ARMED state');

		my $raw_event = LastROActivity::onPublicMessage(undef, {
			RawMsg => '活动将在2小时后开始',
		});
		is($raw_event->{event_id}, 'far_event', 'RawMsg is used when Msg is absent');
		is($raw_event->{received_at}, 1_000, 'fallback uses the deterministic clock');
		done_testing();
	};

	subtest 'status and command validation have no unrelated side effects' => sub {
		my $command = $Commands::commands{lastroactivity};
		my %before = %Globals::config;
		@Log::messages = ();
		$command->('lastroactivity', 'status');
		like($Log::messages[-1], qr/state=ARMED/, 'status reports ARMED');
		like($Log::messages[-1], qr/armed=far_event/, 'status reports the armed event');
		like($Log::messages[-1], qr/trigger=8190/, 'status reports trigger time');

		@Commands::run_calls = ();
		$command->('lastroactivity', 'run unknown_event');
		is_deeply(\@Commands::run_calls, [], 'unknown run event does not issue a command');
		is_deeply(\%Globals::config, \%before, 'unknown run does not mutate config');
		$command->('lastroactivity', 'off');
		is(LastROActivity::enabled(), 0, 'off toggles only in-memory plugin state');
		is_deeply(\%Globals::config, \%before, 'off does not persist config');
		$command->('lastroactivity', 'on');
		is(LastROActivity::enabled(), 1, 'on re-enables the plugin');
		$command->('lastroactivity', 'not-a-command');
		ok(@Log::errors, 'unknown subcommand reports an error');
		done_testing();
	};

	subtest 'mainLoop_pre invokes the due start boundary exactly once' => sub {
		my $begin_calls = 0;
		{
			no warnings 'redefine';
			local *LastROActivity::begin_activity = sub {
				$begin_calls++;
				return 1;
			};
			LastROActivity::onMainLoopPre(undef, {now => 8_189});
			is($begin_calls, 0, 'future trigger does not start activity');
			LastROActivity::onMainLoopPre(undef, {now => 8_190});
			is($begin_calls, 1, 'due trigger calls interruption boundary once');
			LastROActivity::onMainLoopPre(undef, {now => 8_191});
			is($begin_calls, 1, 'dispatched due event is not started twice');
		}
		done_testing();
	};

	subtest 'due monster activity interrupts immediately and enters shared search mode' => sub {
		my $interrupt_fixture = _write_interruption_fixture();
		LastROActivity::onUnload();
		%Globals::config = (
			lastroActivity_rulesFile => $interrupt_fixture,
			lastroActivity_teleportIdle => 7,
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			lockMap_randX => 7,
			lockMap_randY => 8,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		$Settings::load_path = $interrupt_fixture;
		%Globals::maps_lut = ('event_map.rsw' => 1);
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		%Globals::mon_control = (
			event_egg => {teleport_search => 1},
			event_mvp => {teleport_search => 1},
		);
		%Globals::monsters_lut = (9001 => 'event_egg', 9002 => 'event_mvp');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Plugins::registered_plugins = (macro => 1);
		%Commands::commands = (macro => sub { 1 });
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		@Commands::run_calls = ();
		$Commands::run_failure = undef;
		@AI::clear_calls = ();
		@trace = ();
		my $repo_root = File::Spec->catdir($RealBin, '..', '..', '..');
		my $mon_control_file = File::Spec->catfile($repo_root, 'control', 'mon_control.txt');
		my $shared_control_dir = File::Spec->catdir($repo_root, 'control');
		opendir my $shared_control_before_dh, $shared_control_dir
			or die "Unable to read $shared_control_dir: $!";
		my %shared_control_before = map { $_ => 1 }
			grep { $_ ne '.' && $_ ne '..' } readdir $shared_control_before_dh;
		closedir $shared_control_before_dh;
		my $mon_control_before;
		if (-f $mon_control_file) {
			open my $mon_before_fh, '<:raw', $mon_control_file or die "Unable to read $mon_control_file: $!";
			local $/;
			$mon_control_before = <$mon_before_fh>;
			close $mon_before_fh;
		}
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };

		my %before = %Globals::config;
		my $armed = LastROActivity::onSystemMessage(undef, {
			Msg => '活动将在2小时后开始',
		});
		is($armed->{trigger_at}, 8_190, 'long countdown remains future');
		is(LastROActivity::state(), 'ARMED', 'future event is armed');
		LastROActivity::onMainLoopPre(undef, {now => 1_000});
		is_deeply(\@trace, [], 'future armed event has no interruption side effects');
		is_deeply(\%Globals::config, \%before, 'future armed event leaves config untouched');

		# A same-ID announcement replaces the future timer and makes it due now.
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在10秒后开始'});
		my $original_lock = \&LastROActivity::activity_lock;
		my $original_apply = \&LastROActivity::State::apply_activity_config;
		{
			no warnings 'redefine';
			local *LastROActivity::activity_lock = sub {
				push @trace, 'activity_lock:' . ($_[0] ? 'on' : 'off');
				return $original_lock->(@_);
			};
			local *LastROActivity::State::apply_activity_config = sub {
				push @trace, 'snapshot';
				my $snapshot = $original_apply->(@_);
				push @trace, 'config lockMap=' . $Globals::config{lockMap};
				push @trace, 'config teleportAuto_search=' . $Globals::config{teleportAuto_search};
				return $snapshot;
			};
			LastROActivity::onMainLoopPre(undef, {now => 1_000});
		}

		is_deeply(
			\@trace,
			[
				'activity_lock:on',
				'macro stop',
				'AI::clear attack move route mapRoute items_take items_gather take',
				'snapshot',
				'config lockMap=',
				'config teleportAuto_search=1',
				'privateairship event_map',
			],
			'trigger interrupts before departure',
		);
		is(LastROActivity::state(), 'DEPARTING', 'due event transitions to departing');
		is($Globals::config{lockMap}, '', 'activity clears lockMap in memory');
		is($Globals::config{teleportAuto_search}, 1, 'activity enables search gate in memory');
		is($Globals::config{teleportAuto_idle}, 7, 'activity applies configured idle interval');
		is($LastROActivity::active_event->{event_id}, 'monster_event', 'active event is retained');
		my $mon_control_after;
		if (-f $mon_control_file) {
			open my $mon_after_fh, '<:raw', $mon_control_file or die "Unable to read $mon_control_file: $!";
			local $/;
			$mon_control_after = <$mon_after_fh>;
			close $mon_after_fh;
		}
		ok(-f $mon_control_file, 'repository shared monster control file was inspected');
		is($mon_control_after, $mon_control_before,
			'activity leaves the shared monster control file unchanged');
		opendir my $shared_control_after_dh, $shared_control_dir
			or die "Unable to read $shared_control_dir: $!";
		my %shared_control_after = map { $_ => 1 }
			grep { $_ ne '.' && $_ ne '..' } readdir $shared_control_after_dh;
		closedir $shared_control_after_dh;
		is_deeply(\%shared_control_after, \%shared_control_before,
			'activity does not create shared control profiles');

		ok(LastROActivity::cleanup_and_restore('successful cleanup'), 'successful cleanup returns true');
		is_deeply(\%Globals::config, \%before, 'successful cleanup restores the exact config snapshot');
		is(LastROActivity::activity_locked(), 0, 'successful cleanup releases the activity lock');
		is(LastROActivity::active_event(), undef, 'successful cleanup clears the active event');
		done_testing();
	};

	subtest 'activity without search target evidence fails before mutation' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		@trace = ();
		@Log::warnings = ();
		my %before = %Globals::config;
		my $ok = LastROActivity::begin_activity(
			{
				event_id => 'no_targets',
				enabled => 1,
				announce_regex => '活动',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => [],
				validation_errors => [],
			},
			{event_id => 'no_targets', map => 'event_map'},
		);
		is($ok, 0, 'missing search evidence rejects the event');
		is_deeply(\@trace, [], 'missing search evidence has no side effects');
		is_deeply(\%Globals::config, \%before, 'missing search evidence leaves config untouched');
		is(LastROActivity::activity_locked(), 0, 'failed validation leaves activity unlocked');
		like(join('', @Log::warnings), qr/search_targets evidence/, 'missing search evidence is auditable');
		done_testing();
	};

	subtest 'untrusted search targets fail closed and are recorded' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		%Globals::maps_lut = ('event_map.rsw' => 1);
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Globals::monsters_lut = (9001 => 'event_egg');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		%Plugins::registered_plugins = (LastROActivity => 1);
		@trace = ();
		@Log::warnings = ();
		my $rule = {
			event_id => 'untrusted_target',
			enabled => 1,
			announce_regex => '活动',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			search_targets => ['not_in_shared_control'],
			validation_errors => [],
		};
		my %before = %Globals::config;
		my $ok = LastROActivity::begin_activity($rule, {
			event_id => 'untrusted_target',
			map => 'event_map',
		});
		is($ok, 0, 'untrusted search target rejects the event');
		ok(!$rule->{enabled}, 'untrusted search target disables the rule');
		like(join('', @{$rule->{validation_errors}}), qr/shared mon_control/, 'validation error is attached to the rule');
		is_deeply(\@trace, [], 'untrusted search target has no side effects');
		is_deeply(\%Globals::config, \%before, 'untrusted search target leaves config untouched');
		done_testing();
	};

	subtest 'macro registry controls macro stop while AI is always cleared' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		my $lastro_command = $Commands::commands{lastroactivity};
		%Commands::commands = (lastroactivity => $lastro_command, macro => sub { 1 });
		@trace = ();
		%Plugins::registered_plugins = (LastROActivity => 1);
		LastROActivity::clear_normal_ai();
		is_deeply(\@trace,
			['AI::clear attack move route mapRoute items_take items_gather take'],
			'unavailable macro plugin is not stopped');
		@trace = ();
		$Plugins::registered_plugins{macro} = 1;
		LastROActivity::clear_normal_ai();
		is_deeply(\@trace,
			['macro stop', 'AI::clear attack move route mapRoute items_take items_gather take'],
			'available macro plugin is stopped before AI clear');
		done_testing();
	};

	subtest 'command failure rolls back the activity snapshot' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		my $lastro_command = $Commands::commands{lastroactivity};
		%Globals::config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		my %before = %Globals::config;
		%Globals::maps_lut = ('event_map.rsw' => 1);
		%Globals::mon_control = (
			event_egg => {teleport_search => 1},
		);
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		%Plugins::registered_plugins = (LastROActivity => 1);
		%Commands::commands = (lastroactivity => $lastro_command);
		@trace = ();
		@Log::warnings = ();
		$Commands::run_failure = 'privateairship failed';
		my $ok = LastROActivity::begin_activity(
			{
				event_id => 'command_failure',
				enabled => 1,
				announce_regex => '活动',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => ['event_egg'],
				validation_errors => [],
			},
			{event_id => 'command_failure', map => 'event_map'},
		);
		$Commands::run_failure = undef;
		is($ok, 0, 'entry command failure rejects the activity');
		is_deeply(\%Globals::config, \%before, 'entry command failure restores the exact config');
		is(LastROActivity::activity_locked(), 0, 'entry command failure releases the lock');
		is(LastROActivity::state(), 'IDLE', 'entry command failure returns to idle');
		is(LastROActivity::active_event(), undef, 'entry command failure clears active event');
		like(join('', @Log::warnings), qr/privateairship failed/, 'entry command failure is logged');
		done_testing();
	};

	subtest 'missing strict airship metadata fails closed' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		my %before = %Globals::config;
		%Globals::maps_lut = ('event_map.rsw' => 1);
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1};
		@trace = ();
		@Log::warnings = ();
		my $ok = LastROActivity::begin_activity(
			{
				event_id => 'missing_server_item',
				enabled => 1,
				announce_regex => '活动',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => ['event_egg'],
				validation_errors => [],
			},
			{event_id => 'missing_server_item', map => 'event_map'},
		);
		is($ok, 0, 'missing server item metadata rejects the event');
		is_deeply(\@trace, [], 'missing server metadata has no side effects');
		is_deeply(\%Globals::config, \%before, 'missing server metadata leaves config untouched');
		like(join('', @Log::warnings), qr/server metadata/, 'missing server metadata is logged');
		done_testing();
	};

	subtest 'failed rule reloads do not retain stale rules' => sub {
		my $missing_fixture = _write_fixture();
		unlink $missing_fixture or die "Unable to remove $missing_fixture: $!";
		%Globals::config = (lastroActivity_rulesFile => $missing_fixture);
		$Settings::load_path = undef;
		@Settings::control_folders = ('control');
		my $command = $Commands::commands{lastroactivity};
		is($command->('lastroactivity', 'reload'), 0, 'changed missing rules path reports reload failure');
		is_deeply(LastROActivity::rules(), {}, 'changed missing rules path clears stale rules');
		is($command->('lastroactivity', 'reload'), 0, 'unchanged missing rules path still reports reload failure');
		is_deeply(LastROActivity::rules(), {}, 'unchanged missing rules path remains fail-closed');
		done_testing();
	};

	subtest 'overlapping announcements keep the scheduler winner armed' => sub {
		my $overlap_fixture = _write_overlap_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $overlap_fixture);
		$Settings::load_path = $overlap_fixture;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		is(LastROActivity::armed_event()->{event_id}, 'aaa_high', 'armed status follows scheduler priority ordering');
		my $due = LastROActivity::scheduler()->due(8_190);
		is($due->[0]{event_id}, 'aaa_high', 'scheduler dispatches the same highest-priority candidate first');
		done_testing();
	};

	subtest 'pre-start3 reload initializes only once' => sub {
		my $prestart_fixture = _write_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $prestart_fixture);
		$Settings::load_path = $prestart_fixture;
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		my $command = $Commands::commands{lastroactivity};
		is($command->('lastroactivity', 'reload'), 1, 'pre-start3 reload initializes successfully');
		is(scalar @Settings::add_calls, 1, 'pre-start3 reload registers one rules handle');
		$Plugins::hook_callbacks{start3}->(undef, {});
		is(scalar @Settings::add_calls, 1, 'start3 does not duplicate a pre-start3 reload handle');
		done_testing();
	};

	subtest 'failed initial load remains retryable' => sub {
		my $recovery_fixture = _write_fixture();
		unlink $recovery_fixture or die "Unable to remove $recovery_fixture: $!";
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $recovery_fixture);
		$Settings::load_path = undef;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		@Settings::remove_calls = ();
		_load_plugin();

		my $start3 = $Plugins::hook_callbacks{start3};
		is($start3->(undef, {}), 0, 'initial missing rules file reports failure');
		ok(!$LastROActivity::initialized, 'failed initial load does not mark plugin initialized');
		is_deeply(LastROActivity::rules(), {}, 'failed initial load has no rules');
		is(scalar keys %Settings::handles, 0, 'failed initial load removes its temporary Settings handle');

		open my $fh, '>:encoding(UTF-8)', $recovery_fixture
			or die "Unable to write $recovery_fixture: $!";
		print {$fh} <<'RULES';
[far_event]
enabled=1
announce_regex=活动
lead_seconds=10
RULES
		close $fh;
		$Settings::load_path = $recovery_fixture;

		is($start3->(undef, {}), 1, 'subsequent startup retries the rules load');
		ok($LastROActivity::initialized, 'successful retry marks plugin initialized');
		ok(exists LastROActivity::rules()->{far_event}, 'successful retry loads the recovered rules');
		is(scalar keys %Settings::handles, 1, 'successful retry leaves one active Settings handle');
		done_testing();
	};

	subtest 'failed lazy initialization is gated until explicit retry' => sub {
		my $missing_fixture = _write_fixture();
		unlink $missing_fixture or die "Unable to remove $missing_fixture: $!";
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $missing_fixture);
		$Settings::load_path = undef;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		@Settings::remove_calls = ();
		_load_plugin();

		LastROActivity::onMainLoopPre(undef, {now => 1_000});
		is(scalar @Settings::add_calls, 1, 'first lazy hook makes one initialization attempt');
		ok(!$LastROActivity::initialized, 'failed lazy attempt remains uninitialized');
		LastROActivity::onMainLoopPre(undef, {now => 1_001});
		is(scalar @Settings::add_calls, 1, 'repeated lazy hooks do not retry every frame');
		is(scalar @Settings::remove_calls, 1, 'repeated lazy hooks do not leak handles');

		my $command = $Commands::commands{lastroactivity};
		is($command->('lastroactivity', 'reload'), 0, 'explicit reload retries the failed initialization');
		is(scalar @Settings::add_calls, 2, 'explicit reload creates one new attempt');
		is(scalar @Settings::remove_calls, 2, 'explicit retry also cleans its failed handle');
		done_testing();
	};

	subtest 'lazy runtime hooks wait for loaded configuration' => sub {
		my $lazy_fixture = _write_fixture();
		LastROActivity::onUnload();
		%Globals::config = ();
		$Settings::load_path = $lazy_fixture;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();

		LastROActivity::onMainLoopPre(undef, {now => 1_000});
		ok(!$LastROActivity::initialized, 'main loop does not initialize against empty pre-config state');
		is(scalar @Settings::add_calls, 0, 'empty pre-config state does not register a rules file');
		is_deeply(LastROActivity::rules(), {}, 'empty pre-config state has no rules');

		%Globals::config = (lastroActivity_rulesFile => $lazy_fixture);
		LastROActivity::onMainLoopPre(undef, {now => 1_000});
		ok($LastROActivity::initialized, 'runtime hook initializes after configuration is available');
		ok(exists LastROActivity::rules()->{far_event}, 'runtime lazy initialization loads configured rules');
		is(scalar @Settings::add_calls, 1, 'runtime lazy initialization registers one rules file');
		done_testing();
	};

	subtest 'pre-start3 missing explicit reload fails closed' => sub {
		my $missing_fixture = _write_fixture();
		unlink $missing_fixture or die "Unable to remove $missing_fixture: $!";
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $missing_fixture);
		$Settings::load_path = undef;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		my $command = $Commands::commands{lastroactivity};
		is($command->('lastroactivity', 'reload'), 0, 'pre-start3 missing explicit path propagates failure');
		is_deeply(LastROActivity::rules(), {}, 'missing explicit path leaves no rules');
		is(LastROActivity::state(), 'IDLE', 'missing explicit path leaves an idle state');
		done_testing();
	};

	subtest 'plugin reload lazily reinitializes after start3' => sub {
		my $reload_fixture = _write_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $reload_fixture);
		$Settings::load_path = $reload_fixture;
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		my $initial_adds = scalar @Settings::add_calls;
		ok($LastROActivity::initialized, 'plugin is initialized before runtime reload');

		LastROActivity::onReload();
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		_load_plugin();
		ok(!$LastROActivity::initialized, 'reloaded plugin has not replayed start3 yet');
		is_deeply(LastROActivity::rules(), {}, 'reloaded plugin starts without loaded rules');
		is(scalar @Settings::add_calls, $initial_adds, 'reload does not register rules during file evaluation');

		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onMainLoopPre(undef, {now => 1_000});
		ok($LastROActivity::initialized, 'main loop lazily initializes the reloaded plugin');
		ok(exists LastROActivity::rules()->{far_event}, 'lazy initialization loads the configured rules');
		is(scalar @Settings::add_calls, $initial_adds + 1, 'lazy initialization registers one rules handle');
		my $event = LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		is($event->{event_id}, 'far_event', 'reloaded plugin observes announcements after lazy initialization');
		done_testing();
	};

	subtest 'successful rules reload preserves valid timers and prunes invalid ones' => sub {
		my $valid_fixture = _write_fixture();
		my ($other_folder, $other_fixture) = _write_active_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $valid_fixture);
		$Settings::load_path = $valid_fixture;
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		ok(defined LastROActivity::armed_event(), 'valid timer is armed before a successful reload');
		my $command = $Commands::commands{lastroactivity};
		is($command->('lastroactivity', 'reload'), 1, 'unchanged valid rules reload succeeds');
		ok(defined LastROActivity::armed_event(), 'successful reload preserves a valid armed timer');
		my $due = LastROActivity::scheduler()->due(8_190);
		is(scalar @$due, 1, 'preserved timer remains due at its original trigger');
		is($due->[0]{event_id}, 'far_event', 'preserved timer retains its event identity');

		%Globals::config = (lastroActivity_rulesFile => $other_fixture);
		$Settings::load_path = $other_fixture;
		is($command->('lastroactivity', 'reload'), 1, 'changed valid rules reload succeeds');
		ok(!defined LastROActivity::armed_event(), 'reload prunes an armed timer whose rule disappeared');
		is(scalar @{LastROActivity::scheduler()->due(8_190)}, 0, 'pruned timer cannot dispatch after rule replacement');
		done_testing();
	};

	subtest 'failed reload cancels stale timers and pending events' => sub {
		my $valid_fixture = _write_fixture();
		my $missing_fixture = _write_fixture();
		unlink $missing_fixture or die "Unable to remove $missing_fixture: $!";
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $valid_fixture);
		$Settings::load_path = $valid_fixture;
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		ok(defined LastROActivity::armed_event(), 'valid rules arm a scheduled event before reload');
		my $command = $Commands::commands{lastroactivity};
		is($command->('lastroactivity', 'run far_event'), 1, 'manual event is queued before reload');
		%Globals::config = (lastroActivity_rulesFile => $missing_fixture);
		$Settings::load_path = undef;
		is($command->('lastroactivity', 'reload'), 0, 'missing reload reports failure');
		ok(!defined LastROActivity::armed_event(), 'failed reload clears armed status');
		is_deeply(LastROActivity::rules(), {}, 'failed reload clears rules');
		is(scalar @LastROActivity::pending_due, 0, 'failed reload clears pending due events');
		is(scalar @LastROActivity::pending_manual, 0, 'failed reload clears pending manual events');
		is(LastROActivity::state(), 'IDLE', 'failed reload resets pre-active state to idle');
		my $begin_calls = 0;
		{
			no warnings 'redefine';
			local *LastROActivity::begin_activity = sub {
				$begin_calls++;
				return 1;
			};
			LastROActivity::onMainLoopPre(undef, {now => 8_190});
		}
		is($begin_calls, 0, 'old trigger cannot dispatch after failed reload');
		done_testing();
	};

	subtest 'changed rules reload preserves surviving timers only' => sub {
		my $multi_fixture = _write_multi_fixture();
		my $keep_fixture = _write_keep_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $multi_fixture);
		$Settings::load_path = $multi_fixture;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		is(LastROActivity::armed_event()->{event_id}, 'drop_event', 'initial scheduler winner is ordered by event ID');

		my $command = $Commands::commands{lastroactivity};
		%Globals::config = (lastroActivity_rulesFile => $keep_fixture);
		$Settings::load_path = $keep_fixture;
		is($command->('lastroactivity', 'reload'), 1, 'changed rules reload succeeds');
		my $armed = LastROActivity::armed_event();
		is($armed && $armed->{event_id}, 'keep_event', 'surviving timer becomes the armed candidate');
		my $due = LastROActivity::scheduler()->due(8_190);
		is(scalar @$due, 1, 'only the surviving timer remains scheduled');
		is($due->[0]{event_id}, 'keep_event', 'surviving timer retains its event identity');
		done_testing();
	};

	subtest 'loader exceptions fail safely and clear scheduled state' => sub {
		my $valid_fixture = _write_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $valid_fixture);
		$Settings::load_path = $valid_fixture;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		ok(defined LastROActivity::armed_event(), 'valid rules arm a timer before exception reload');

		my $command = $Commands::commands{lastroactivity};
		{
			no warnings 'redefine';
			local *Settings::loadByHandle = sub { die "synthetic loader failure\n" };
			is($command->('lastroactivity', 'reload'), 0, 'loader exception propagates reload failure');
		}
		is_deeply(LastROActivity::rules(), {}, 'loader exception clears rules');
		ok(!defined LastROActivity::armed_event(), 'loader exception clears armed status');
		is(scalar @{LastROActivity::scheduler()->due(8_190)}, 0, 'loader exception clears scheduler timers');
		like(join('', @Log::warnings), qr/synthetic loader failure/, 'loader exception is logged');
		done_testing();
	};

	subtest 'generic settings reload fail-closes a deleted rules file' => sub {
		my $rules_fixture = _write_fixture();
		LastROActivity::onUnload();
		%Globals::config = (lastroActivity_rulesFile => $rules_fixture);
		$Settings::load_path = $rules_fixture;
		@Settings::control_folders = ('control');
		@Plugins::registrations = ();
		@Plugins::hooks = ();
		%Plugins::hook_callbacks = ();
		%Commands::commands = ();
		%Commands::descriptors = ();
		@Settings::add_calls = ();
		@Settings::remove_calls = ();
		_load_plugin();
		$Plugins::hook_callbacks{start3}->(undef, {});
		$LastROActivity::clock = sub { 1_000 };
		LastROActivity::onSystemMessage(undef, {Msg => '活动将在2小时后开始'});
		ok(defined LastROActivity::armed_event(), 'valid rules arm a timer before generic reload');

		unlink $rules_fixture or die "Unable to remove $rules_fixture: $!";
		$Settings::load_path = undef;
		Settings::loadAll();
		is_deeply(LastROActivity::rules(), {}, 'generic reload clears deleted-file rules');
		ok(!defined LastROActivity::armed_event(), 'generic reload clears deleted-file armed state');
		is(scalar @{LastROActivity::scheduler()->due(8_190)}, 0, 'generic reload clears deleted-file timers');
		done_testing();
	};

	subtest 'cleanup surfaces config restoration failures' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		my $snapshot = LastROActivity::State::snapshot_config(\%Globals::config);
		LastROActivity::State::apply_activity_config(\%Globals::config, 7);
		$LastROActivity::active_snapshot = $snapshot;
		$LastROActivity::active_event = {event_id => 'restore_failure'};
		LastROActivity::activity_lock(1);
		@Log::warnings = ();
		my $ok;
		{
			no warnings 'redefine';
			local *LastROActivity::State::restore_config = sub {
				die "synthetic restore failure\n";
			};
			$ok = LastROActivity::cleanup_and_restore('restore failure');
		}
		is($ok, 0, 'cleanup reports a restoration failure');
		is(LastROActivity::activity_locked(), 0, 'cleanup releases the lock after restoration failure');
		is(LastROActivity::active_event(), undef, 'cleanup clears the active event after restoration failure');
		like(join('', @Log::warnings), qr/synthetic restore failure/, 'cleanup logs the restoration failure');
		like(LastROActivity::last_failure(), qr/synthetic restore failure/, 'cleanup exposes the restoration failure');
		$LastROActivity::active_snapshot = undef;
		done_testing();
	};

	# Keep unload last because it unregisters the command and hooks used by the
	# remaining integration cases.
	subtest 'plugin unload restores an active snapshot' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		my %before = %Globals::config;
		$LastROActivity::active_snapshot = LastROActivity::State::apply_activity_config(\%Globals::config, 7);
		$LastROActivity::active_event = {event_id => 'unload_event'};
		LastROActivity::activity_lock(1);
		LastROActivity::onUnload();
		is_deeply(\%Globals::config, \%before, 'plugin unload restores the exact config');
		is(LastROActivity::activity_locked(), 0, 'plugin unload releases the lock');
		is($LastROActivity::active_snapshot, undef, 'plugin unload clears the snapshot');
		done_testing();
	};

	done_testing();
}

1;
