package PluginTest;

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use File::Temp qw(tempfile tempdir);
use Test::More;

# Keep this test independent of OpenKore's native extensions.  The plugin only
# needs the small portions of these packages that are exercised below.
BEGIN {
	$INC{'Globals.pm'} = __FILE__;
	package Globals;
	our %config;
	our ($net, $char, $field);
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::config"} = \%config;
		*{"${caller}::net"} = \$net;
		*{"${caller}::char"} = \$char;
		*{"${caller}::field"} = \$field;
	}

	$INC{'Plugins.pm'} = __FILE__;
	package Plugins;
	our $current_plugin_folder;
	our @registrations;
	our @hooks;
	our %hook_callbacks;
	sub import { return 1; }
	sub register { push @registrations, [@_]; return 1; }
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
	sub import { return 1; }
	sub register {
		for my $command (@_) {
			$commands{$command->[0]} = $command->[2];
			$descriptors{$command->[0]} = $command->[1];
		}
		return [map { $_->[0] } @_];
	}
	sub unregister { return 1; }
	sub run { push @run_calls, $_[0]; return 1; }

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
	sub import { return 1; }
	sub clear { return 1; }

	$INC{'Network.pm'} = __FILE__;
	package Network;
	sub IN_GAME () { 5; }

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
	@Plugins::registrations = ();
	@Plugins::hooks = ();
	%Commands::commands = ();
	@Commands::run_calls = ();
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

	done_testing();
}

1;
