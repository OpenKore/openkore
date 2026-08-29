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
	sub delHooks { return 1; }

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
		my $path = $load_path;
		if (!defined $path && $entry->{autoSearch}) {
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
	sub removeFile { return 1; }
	sub getControlFilename {
		my ($name) = @_;
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

	done_testing();
}

1;
