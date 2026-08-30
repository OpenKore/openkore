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
	our @ai_seq;
	our @ai_seq_args;
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
	our @ai_seq;
	our @ai_seq_args;
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

	package macro;
	our $queue;

	package PluginTest::MacroQueue;
	sub new {
		my ($class, $name, $finished) = @_;
		bless {name => $name, finished => $finished ? 1 : 0}, $class;
	}
	sub name { return $_[0]->{name}; }
	sub finished { return $_[0]->{finished}; }

	package PluginTest::NpcTask;
	sub new {
		my ($class, $status, $error) = @_;
		bless {status => $status, error => $error}, $class;
	}
	sub getStatus { return $_[0]->{status}; }
	sub getError { return $_[0]->{error}; }

	package PluginTest::SkillActor;
	sub new {
		my ($class, %args) = @_;
		bless \%args, $class;
	}
	sub getSkillLevelByHandle { return 0; }
	sub getSkillLevel { return 0; }
	sub job { return $_[0]->{job_result} // $_[0]->{job}; }

	$INC{'Log.pm'} = __FILE__;
	package Log;
	our (@messages, @warnings, @errors, @debug, @hooks);
	sub import {
		my $caller = caller;
		no strict 'refs';
		for my $name (qw(message warning error debug)) {
			*{"${caller}::${name}"} = \&{$name};
		}
	}
	sub addHook {
		my ($callback, $user_data) = @_;
		push @hooks, [$callback, $user_data];
		return $#hooks;
	}
	sub delHook {
		my ($id) = @_;
		$hooks[$id] = undef if defined $id && $id >= 0;
		return 1;
	}
	sub _emit {
		my ($type, $message) = @_;
		for my $hook (@hooks) {
			next unless ref($hook) eq 'ARRAY' && ref($hook->[0]) eq 'CODE';
			$hook->[0]->($type, 'test', 1, 1, $message, $hook->[1]);
		}
	}
	sub message { push @messages, $_[0]; _emit('message', $_[0]); return 1; }
	sub warning { push @warnings, $_[0]; _emit('warning', $_[0]); return 1; }
	sub error { push @errors, $_[0]; _emit('error', $_[0]); return 1; }
	sub debug { push @debug, $_[0]; _emit('debug', $_[0]); return 1; }
}

sub _write_fixture {
	my ($fh, $path) = tempfile('lastro-activity-plugin-XXXXXX', UNLINK => 1);
	binmode $fh, ':encoding(UTF-8)';
	print {$fh} <<'RULES';
[far_event]
enabled=1
announce_regex=活动
start_regex=活动
lead_seconds=10
duration_seconds=900
# Scheduler-only projection: keep this fixture out of shared-search routing.
entry_type=macro
entry_macro=scheduler_only
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
start_regex=活动
lead_seconds=10
entry_type=privateairship
entry_item_id=14527
map_source=static
entry_map=event_map
search_targets=event_egg,event_mvp
duration_seconds=900
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
start_regex=活动
lead_seconds=12
duration_seconds=900
# Scheduler-only projection: keep this fixture out of shared-search routing.
entry_type=macro
entry_macro=scheduler_only
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
start_regex=活动
lead_seconds=10
priority=5
duration_seconds=900
entry_type=macro
entry_macro=scheduler_only

[zzz_low]
enabled=1
announce_regex=活动
start_regex=活动
lead_seconds=10
priority=1
duration_seconds=900
entry_type=macro
entry_macro=scheduler_only
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
start_regex=活动
lead_seconds=10
duration_seconds=900
entry_type=macro
entry_macro=scheduler_only

[drop_event]
enabled=1
announce_regex=活动
start_regex=活动
lead_seconds=10
duration_seconds=900
entry_type=macro
entry_macro=scheduler_only
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
start_regex=活动
lead_seconds=10
duration_seconds=900
entry_type=macro
entry_macro=scheduler_only
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
	@Log::hooks = ();

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

	subtest 'bundled incomplete raw-enabled rules never arm before lifecycle validation' => sub {
		LastROActivity::scheduler()->clear();
		my @incomplete_ids = qw(
			city_monster_party
			dojo_challenge
			pool_challenge
			lottery
		);
		for my $event_id (@incomplete_ids) {
			ok(!$LastROActivity::rules->{$event_id}{enabled},
				"$event_id is effectively disabled before scheduling");
		}
		my $event = LastROActivity::onSystemMessage(undef, {
			Msg => '[随机事件] 抽奖活动10秒后开始啦 data-map="prontera#152#129"',
		});
		ok(!defined $event, 'announcement-only evidence cannot arm the incomplete lottery rule');
		is_deeply(LastROActivity::scheduler()->events(), {},
			'incomplete raw-enabled rules leave no scheduler timers');
		done_testing();
	};

	subtest 'typed search routes fail closed when shared control is unavailable' => sub {
		local %Globals::mon_control = ();
		my $rule = {
			event_id => 'empty_shared_control',
			enabled => 1,
			announce_regex => '活动',
			start_regex => '活动',
			finish_regex => '活动结束',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			search_targets => ['event_egg'],
			duration_seconds => 900,
			validation_errors => [],
		};
		my $previous_rules = $LastROActivity::rules;
		$LastROActivity::rules = {empty_shared_control => $rule};
		LastROActivity::scheduler()->clear();
		my $event = LastROActivity::_observe_message('活动', 1_000);
		ok(!defined $event,
			'empty shared control rejects a typed search route before announcement scheduling');
		ok(!$rule->{enabled}, 'empty shared control disables the typed search rule');
		like(join('; ', @{$rule->{validation_errors}}), qr/shared mon_control/,
			'empty shared control failure is attached to the rule');
		is_deeply(LastROActivity::scheduler()->events(), {},
			'empty shared control leaves no scheduler timer');
		my $direct_rule = { %$rule, enabled => 1, validation_errors => [] };
		ok(!LastROActivity::_validated_enabled_rule($direct_rule),
			'direct typed-rule validation also fails closed without shared control');
		my $airship_rule = {
			%$rule,
			event_id => 'empty_airship_control',
			entry_type => 'airship',
			enabled => 1,
			validation_errors => [],
		};
		ok(!LastROActivity::_validated_enabled_rule($airship_rule),
			'direct airship-rule validation also fails closed without shared control');
		ok(!$airship_rule->{enabled}, 'empty shared control disables the typed airship rule');
		like(join('; ', @{$airship_rule->{validation_errors}}), qr/shared mon_control/,
			'airship shared-control failure is attached to the rule');
		my $unmarked_direct_search = {
			event_id => 'unmarked_direct_search',
			enabled => 1,
			announce_regex => '活动',
			start_regex => '活动',
			duration_seconds => 900,
			search_targets => ['bogus'],
		};
		ok(!LastROActivity::_validated_enabled_rule($unmarked_direct_search),
			'unmarked direct search rule fails closed without shared control');
		ok(!$unmarked_direct_search->{enabled},
			'unmarked direct search rule is disabled after failed preflight');
		my $unmarked_errors = ref($unmarked_direct_search->{validation_errors}) eq 'ARRAY'
			? join('; ', @{$unmarked_direct_search->{validation_errors}}) : '';
		like($unmarked_errors, qr/shared mon_control/,
			'unmarked direct search failure is attached to the rule');
		my $marked_scheduler_only = {
			%$unmarked_direct_search,
			event_id => 'marked_scheduler_only',
			enabled => 1,
			scheduler_only => 1,
		};
		delete $marked_scheduler_only->{validation_errors};
		ok(LastROActivity::_validated_enabled_rule($marked_scheduler_only),
			'explicit scheduler_only marker preserves scheduler projection compatibility');
		my $scheduler_projection = {
			%$rule,
			event_id => 'scheduler_projection',
			enabled => 1,
			scheduler_only => 1,
		};
		delete $scheduler_projection->{entry_type};
		delete $scheduler_projection->{validation_errors};
		ok(LastROActivity::_validated_enabled_rule($scheduler_projection),
			'key-absent scheduler projection remains compatible with empty shared control');

		my ($implicit_rules, $implicit_errors) = LastROActivity::Rules::parse_text(<<'RULES');
[implicit_privateairship]
enabled=1
announce_regex=活动
start_regex=活动
finish_regex=活动结束
entry_item_id=14527
search_targets=event_egg
duration_seconds=900
RULES
	is_deeply($implicit_errors, [], 'implicit privateairship fixture parses without syntax errors');
	my $implicit_rule = $implicit_rules->{implicit_privateairship};
	ok(exists $implicit_rule->{entry_type} && !defined $implicit_rule->{entry_type},
		'parser keeps the omitted entry_type slot for its privateairship default');
	ok(LastROActivity::_uses_search_mode($implicit_rule),
		'omitted entry_type defaults to shared privateairship search mode');
	ok(!LastROActivity::_validated_enabled_rule($implicit_rule),
		'implicit privateairship route fails closed without shared control');
	ok(!$implicit_rule->{enabled}, 'implicit privateairship route is disabled after preflight');
	like(join('; ', @{$implicit_rule->{validation_errors}}), qr/shared mon_control/,
		'implicit privateairship failure is attached to the rule');
		$LastROActivity::rules = $previous_rules;
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

	subtest 'runtime rejects rules without start evidence or with unknown map sources' => sub {
		my $missing_start = {
			event_id => 'runtime_missing_start',
			enabled => 1,
			announce_regex => 'ready',
			finish_regex => 'done',
			duration_seconds => 30,
			entry_map => 'event_map',
			entry_type => 'macro',
			entry_macro => 'scheduler_only',
			validation_errors => [],
		};
		ok(!LastROActivity::_validated_enabled_rule($missing_start),
			'enabled runtime rule without start_regex is rejected');
		like(join('; ', @{$missing_start->{validation_errors}}), qr/start_regex/i,
			'missing start evidence is recorded on the runtime rule');

		my $unknown_source = {
			event_id => 'runtime_unknown_source',
			enabled => 1,
			announce_regex => 'ready',
			start_regex => 'starts',
			finish_regex => 'done',
			duration_seconds => 30,
			map_source => 'not_documented',
			entry_map => 'event_map',
			entry_type => 'macro',
			entry_macro => 'scheduler_only',
			validation_errors => [],
		};
		ok(!LastROActivity::_validated_enabled_rule($unknown_source),
			'enabled runtime rule with an unknown map source is rejected');
		like(join('; ', @{$unknown_source->{validation_errors}}), qr/map_source/i,
			'unknown map source is recorded on the runtime rule');
		done_testing();
	};

	subtest 'off cancels armed timers, pending queues, and every scheduler timer' => sub {
		LastROActivity::cleanup_and_restore('scheduled cancellation reset');
		$LastROActivity::enabled = 1;
		$LastROActivity::clock = sub { 1_000 };
		$LastROActivity::scheduler = LastROActivity::Scheduler->new(
			lead_seconds => 10,
			clock => sub { 1_000 },
		);
		my $rule_a = {
			event_id => 'off_armed',
			enabled => 1,
			announce_regex => 'off armed',
			start_regex => 'off armed starts',
			finish_regex => 'off armed done',
			duration_seconds => 30,
			map_source => 'static',
			entry_map => 'event_map',
			entry_type => 'macro',
			entry_macro => 'scheduler_only',
			validation_errors => [],
		};
		my $rule_b = { %$rule_a, event_id => 'off_other', announce_regex => 'off other' };
		$LastROActivity::rules = {$rule_a->{event_id} => $rule_a, $rule_b->{event_id} => $rule_b};
		my $event_a = LastROActivity::scheduler()->observe($rule_a, 'off armed starts将在2小时后开始', 1_000);
		my $event_b = LastROActivity::scheduler()->observe($rule_b, 'off other将在3小时后开始', 1_000);
		LastROActivity::_arm_event($event_a);
		push @LastROActivity::pending_due, $event_a;
		push @LastROActivity::pending_manual, $event_b;
		my $command = $Commands::commands{lastroactivity};
		$command->('lastroactivity', 'off');
		is(LastROActivity::enabled(), 0, 'off disables scheduling');
		is(LastROActivity::armed_event(), undef, 'off clears the armed event');
		is_deeply(LastROActivity::scheduler()->events(), {}, 'off clears every scheduler timer');
		is(scalar @LastROActivity::pending_due, 0, 'off clears pending due events');
		is(scalar @LastROActivity::pending_manual, 0, 'off clears pending manual events');
		is(LastROActivity::state(), 'IDLE', 'off leaves no armed lifecycle state');

		$command->('lastroactivity', 'on');
		LastROActivity::onMainLoopPre(undef, {now => 100_000});
		is(LastROActivity::active_event(), undef, 're-enabling cannot dispatch cancelled work');
		done_testing();
	};

	subtest 'mainLoop_pre invokes the due start boundary exactly once' => sub {
		$LastROActivity::clock = sub { 1_000 };
		my $due_rule = {
			event_id => 'due_event',
			enabled => 1,
			announce_regex => '活动',
			start_regex => '活动',
			lead_seconds => 10,
			duration_seconds => 30,
			entry_type => 'macro',
			entry_macro => 'scheduler_only',
			validation_errors => [],
		};
		$LastROActivity::rules = {due_event => $due_rule};
		my $due_event = LastROActivity::scheduler()->observe(
			$due_rule, '活动将在2小时后开始', 1_000,
		);
		LastROActivity::_arm_event($due_event);
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
		@AI::ai_seq = ();
		@AI::ai_seq_args = ();
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
				start_regex => '活动',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => [],
				duration_seconds => 900,
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
			start_regex => '活动',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			search_targets => ['not_in_shared_control'],
			duration_seconds => 900,
			validation_errors => [],
		};
		my %preflight_rule = %$rule;
		$preflight_rule{validation_errors} = [];
		ok(!LastROActivity::_validated_enabled_rule(\%preflight_rule),
			'untrusted search target is rejected before scheduling when shared control is available');
		ok(!$preflight_rule{enabled}, 'pre-schedule target validation disables the rule');
		like(join('; ', @{$preflight_rule{validation_errors}}), qr/shared mon_control/,
			'pre-schedule target failure is auditable');
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
				start_regex => '活动',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => ['event_egg'],
				duration_seconds => 900,
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
				start_regex => '活动',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => ['event_egg'],
				duration_seconds => 900,
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
start_regex=活动
lead_seconds=10
duration_seconds=900
entry_type=macro
entry_macro=scheduler_only
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

	subtest 'return flow restores the snapshot before clearing AI and releasing the lock' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			lockMap_randX => 7,
			lockMap_randY => 8,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		%Globals::maps_lut = (
			'event_map.rsw' => 1,
			'prontera.rsw' => 1,
		);
		$Globals::field = PluginTest::Field->new('event_map');
		$Globals::net = PluginTest::Net->new;
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		my $rule = {
			event_id => 'return_order',
			enabled => 1,
			announce_regex => '活动',
			start_regex => '活动',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			duration_seconds => 900,
			search_targets => [],
			validation_errors => [],
		};
		my $event = {event_id => 'return_order', rule => $rule, map => 'event_map'};
		$LastROActivity::active_event = $event;
		$LastROActivity::armed_event = $event;
		$LastROActivity::active_snapshot = LastROActivity::State::apply_activity_config(
			\%Globals::config, 7,
		);
		$LastROActivity::activity_lock = 1;
		$LastROActivity::state = LastROActivity::State->new;
		$LastROActivity::state->transition($_) for qw(arm trigger snapshot depart enter running finish);
		@trace = ();
		@Commands::run_calls = ();
		@AI::clear_calls = ();
		my $original_restore = \&LastROActivity::State::restore_config;
		my $original_lock = \&LastROActivity::activity_lock;
		{
			no warnings 'redefine';
			local *LastROActivity::clear_activity_ai = sub {
				push @trace, 'clear activity AI';
				return 1;
			};
			local *LastROActivity::State::restore_config = sub {
				push @trace, 'restore lockMap/pay_fild08';
				push @trace, 'restore teleport settings';
				return $original_restore->(@_);
			};
			local *LastROActivity::activity_lock = sub {
				push @trace, 'activity_lock:' . ($_[0] ? 'on' : 'off') if @_;
				return $original_lock->(@_);
			};
			is(LastROActivity::finish_activity('finish announcement'), 1,
				'finish announcement starts the return path');
			is_deeply(\@trace, ['clear activity AI', 'privateairship prontera'],
				'return request waits for the map confirmation hook');
			$Globals::field = PluginTest::Field->new('prontera');
			push @trace, 'map confirmed prontera';
			LastROActivity::onMapChange(undef, {});
		}
		is_deeply(
			\@trace,
			[
				'clear activity AI',
				'privateairship prontera',
				'map confirmed prontera',
				'restore lockMap/pay_fild08',
				'restore teleport settings',
				'AI::clear',
				'activity_lock:off',
			],
			'return flow restores lockMap before AI clear',
		);
		is_deeply(\%Globals::config, {
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			lockMap_randX => 7,
			lockMap_randY => 8,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		}, 'return restores the exact pre-activity config');
		is(LastROActivity::active_event(), undef, 'return clears the active event');
		is(LastROActivity::activity_locked(), 0, 'return releases the activity lock');
		done_testing();
	};

	subtest 'entry map confirmation starts an optional entry macro' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (macro => 1);
		%Commands::commands = (macro => sub { 1 });
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'macro_entry',
			enabled => 1,
			announce_regex => '活动',
			start_regex => '活动',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			duration_seconds => 900,
			entry_macro => 'enter_event',
			search_targets => ['event_egg'],
			validation_errors => [],
		};
		my $event = {event_id => 'macro_entry', rule => $rule, map => 'event_map'};
		my $entry_ok;
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			$entry_ok = LastROActivity::begin_activity($rule, $event);
		}
		is($entry_ok, 1, 'airship entry is requested');
		is_deeply(\@Commands::run_calls, ['privateairship event_map'],
			'macro is not launched before the destination map is confirmed');
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onAirshipResult(undef, {type => 0});
		LastROActivity::onMapChange(undef, {});
		is_deeply(\@Commands::run_calls,
			['privateairship event_map', 'macro enter_event -overrideAI -exclusive'],
			'entry macro starts only after map confirmation');
		is(LastROActivity::state(), 'ENTERING', 'entry macro keeps the activity in ENTERING');
		done_testing();
	};

	subtest 'completed entry macro is recognized when its queue disappears' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (macro => 1);
		$macro::queue = undef;
		%Commands::commands = (macro => sub { 1 });
		$Commands::run_failure = sub {
			my ($command) = @_;
			$macro::queue = PluginTest::MacroQueue->new('enter_event', 0)
				if $command eq 'macro enter_event -overrideAI -exclusive';
			return 1;
		};
		$LastROActivity::clock = sub { 1_000 };
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'macro_disappears', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, entry_macro => 'enter_event',
			search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'macro_disappears', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'entry macro owns the ENTERING state');
		$macro::queue = undef;
		LastROActivity::onMainLoopPre(undef, {now => 1_001});
		is(LastROActivity::state(), 'RUNNING', 'queue disappearance after launch marks the macro complete');
		is($LastROActivity::pending_macro, undef, 'completed macro marker is cleared');
		$Commands::run_failure = undef;
		$macro::queue = undef;
		done_testing();
	};

	subtest 'nonzero airship result fails the activity with a reason' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		%Globals::maps_lut = ('event_map.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		@Log::warnings = ();
		my $rule = {
			event_id => 'rejected_entry',
			enabled => 1,
			announce_regex => '活动',
			start_regex => '活动',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			duration_seconds => 900,
			search_targets => ['event_egg'],
			validation_errors => [],
		};
		my $event = {event_id => 'rejected_entry', rule => $rule, map => 'event_map'};
		is(LastROActivity::begin_activity($rule, $event), 1, 'entry request is accepted locally');
		LastROActivity::onAirshipResult(undef, {type => 2});
		is(LastROActivity::state(), 'DEPARTING', 'first server rejection retries entry while bounded');
		LastROActivity::onAirshipResult(undef, {type => 2});
		is(LastROActivity::state(), 'DEPARTING', 'second server rejection retries the final entry attempt');
		LastROActivity::onAirshipResult(undef, {type => 2});
		is(LastROActivity::state(), 'FAILED', 'exhausted server rejections transition the activity to FAILED');
		like(join('', @Log::warnings), qr/not have enough|insufficient/i,
			'airship rejection logs a human-readable reason');
		done_testing();
	};

	subtest 'map confirmation preserves ENTERING until the next lifecycle step' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		my $rule = {
			event_id => 'entering_state', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'entering_state', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'map packet confirms the ENTERING state');
		LastROActivity::onMainLoopPre(undef, {now => $LastROActivity::activity_started_at});
		is(LastROActivity::state(), 'RUNNING', 'main loop advances confirmed entry to RUNNING');
		done_testing();
	};

	subtest 'airship rejection after map confirmation still fails closed' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		my $rule = {
			event_id => 'late_rejection', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'late_rejection', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			LastROActivity::begin_activity($rule, $event);
		}
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		LastROActivity::onAirshipResult(undef, {type => 3});
		is(LastROActivity::state(), 'FAILED', 'late rejection transitions the activity to FAILED');
		like(LastROActivity::last_failure(), qr/destination map is invalid/i,
			'late rejection keeps its reason');
		done_testing();
	};

	subtest 'map-first entry waits for airship acceptance before running' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (macro => 1);
		%Commands::commands = (macro => sub { 1 });
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'map_first_entry', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, entry_macro => 'enter_event',
			search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'map_first_entry', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}

		# Some servers deliver map_changed before the private-airship result.
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'map arrival confirms entry but does not run yet');
		LastROActivity::onMainLoopPre(undef, {now => $LastROActivity::activity_started_at});
		is(LastROActivity::state(), 'ENTERING', 'main loop waits for the accepted airship result');
		is_deeply(\@Commands::run_calls, ['privateairship event_map'],
			'entry macro is not launched before airship acceptance');

		LastROActivity::onAirshipResult(undef, {type => 0});
		LastROActivity::onMapChange(undef, {});
		is_deeply(\@Commands::run_calls,
			['privateairship event_map', 'macro enter_event -overrideAI -exclusive'],
			'accepted map-first entry launches its macro exactly once');
		done_testing();
	};

	subtest 'airship results without a pending transfer are ignored' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		@Commands::run_calls = ();
		@Log::warnings = ();
		my $rule = {
			event_id => 'orphan_result', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'orphan_result', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'accepted transfer remains in the entry state until the main loop');
		my $failure_before = LastROActivity::last_failure();
		LastROActivity::onAirshipResult(undef, {type => 3});
		is(LastROActivity::state(), 'ENTERING', 'orphan result does not fail the active entry');
		is(LastROActivity::last_failure(), $failure_before, 'orphan result does not overwrite failure state');
		is_deeply(\@Commands::run_calls, ['privateairship event_map'],
			'orphan result does not trigger a return request');
		done_testing();
	};

	subtest 'map-first entry keeps a bounded airship handshake timeout' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (LastROActivity => 1);
		%Commands::commands = ();
		$LastROActivity::clock = sub { 1_000 };
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'map_first_timeout', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', timeout_seconds => 5, duration_seconds => 900,
			search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'map_first_timeout', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		LastROActivity::onMainLoopPre(undef, {now => 1_006});
		is(LastROActivity::state(), 'FAILED', 'missing airship acceptance fails after the handshake deadline');
		is_deeply(\@Commands::run_calls,
			['privateairship event_map', 'privateairship prontera'],
			'timeout starts the single fixed return request');
		done_testing();
	};

	subtest 'return rejection reason survives the bounded timeout cleanup' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (LastROActivity => 1);
		%Commands::commands = ();
		$LastROActivity::clock = sub { 1_000 };
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'return_rejection', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', timeout_seconds => 5, duration_seconds => 900,
			search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'return_rejection', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		LastROActivity::onMainLoopPre(undef, {now => 1_000});
		is(LastROActivity::state(), 'RUNNING', 'accepted entry reaches the activity state');
		is(LastROActivity::finish_activity('finished'), 1, 'finish starts the return request');
		LastROActivity::onAirshipResult(undef, {type => 3});
		is(LastROActivity::state(), 'FAILED', 'return rejection marks the activity failed');
		my $reason = LastROActivity::last_failure();
		like($reason, qr/destination map is invalid/i, 'return rejection records its specific reason');
		LastROActivity::onMainLoopPre(undef, {now => 1_006});
		is(LastROActivity::active_event(), undef, 'timeout completes the failed return cleanup');
		is(LastROActivity::last_failure(), $reason,
			'timeout does not overwrite the original return rejection reason');
		done_testing();
	};

	subtest 'nested entry macro errors are not mistaken for queue completion' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (macro => 1);
		$macro::queue = undef;
		%Commands::commands = (macro => sub { 1 });
		$Commands::run_failure = sub {
			my ($command) = @_;
			$macro::queue = PluginTest::MacroQueue->new('root_entry_macro', 0)
				if $command eq 'macro root_entry_macro -overrideAI -exclusive';
			return 1;
		};
		$LastROActivity::clock = sub { 1_000 };
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'nested_macro_error', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, entry_macro => 'root_entry_macro',
			search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'nested_macro_error', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'root entry macro is pending');

		# Macro::Utilities reports a nested child name and clears the queue after
		# dispatching this hook.  The activity must retain the failure reason.
		LastROActivity::onMacroError(undef, {
			name => 'nested_child_macro',
			error => 'nested child failed',
			message => '[macro] nested_child_macro error',
		});
		$macro::queue = undef;
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			LastROActivity::onMainLoopPre(undef, {now => 1_001});
		}
		is(LastROActivity::state(), 'FAILED', 'nested macro failure fails the activity');
		like(LastROActivity::last_failure(), qr/nested child failed/i,
			'nested macro failure is retained instead of reporting success');
		is_deeply(\@Commands::run_calls,
			['privateairship event_map', 'macro root_entry_macro -overrideAI -exclusive',
				'privateairship prontera'],
			'nested macro failure starts the fixed return exactly once');
		$Commands::run_failure = undef;
		$macro::queue = undef;
		done_testing();
	};

	subtest 'leaving the confirmed entry map cannot promote the activity to running' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = (
			'event_map.rsw' => 1,
			'other_map.rsw' => 1,
			'prontera.rsw' => 1,
		);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Commands::commands = ();
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'entry_map_departure', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, search_targets => ['event_egg'],
			validation_errors => [],
		};
		my $event = {event_id => 'entry_map_departure', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'target map was confirmed');

		$Globals::field = PluginTest::Field->new('other_map');
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			LastROActivity::onMainLoopPre(undef, {now => 1_001});
		}
		is(LastROActivity::state(), 'FAILED', 'map departure fails before running');
		is_deeply(\@Commands::run_calls,
			['privateairship event_map', 'privateairship prontera'],
			'map departure starts the fixed return exactly once');
		done_testing();
	};

	subtest 'completed entry macro cannot promote an off-map activity' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Globals::config = (lockMap => 'pay_fild08', teleportAuto_search => 0, teleportAuto_idle => 0);
		%Globals::maps_lut = (
			'event_map.rsw' => 1,
			'other_map.rsw' => 1,
			'prontera.rsw' => 1,
		);
		$Globals::field = PluginTest::Field->new('pay_fild08');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (macro => 1);
		$macro::queue = undef;
		%Commands::commands = (macro => sub { 1 });
		$Commands::run_failure = sub {
			my ($command) = @_;
			$macro::queue = PluginTest::MacroQueue->new('completed_entry_macro', 1)
				if $command eq 'macro completed_entry_macro -overrideAI -exclusive';
			return 1;
		};
		$LastROActivity::clock = sub { 1_000 };
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'off_map_macro_completion', enabled => 1, announce_regex => '活动', start_regex => '活动',
			entry_type => 'privateairship', entry_item_id => 14527,
			entry_map => 'event_map', duration_seconds => 900, entry_macro => 'completed_entry_macro',
			search_targets => ['event_egg'], validation_errors => [],
		};
		my $event = {event_id => 'off_map_macro_completion', rule => $rule, map => 'event_map'};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1, 'entry request starts');
		}
		LastROActivity::onAirshipResult(undef, {type => 0});
		$Globals::field = PluginTest::Field->new('event_map');
		LastROActivity::onMapChange(undef, {});
		is(LastROActivity::state(), 'ENTERING', 'finished entry macro is pending in ENTERING');

		$Globals::field = PluginTest::Field->new('other_map');
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			LastROActivity::onMainLoopPre(undef, {now => 1_001});
		}
		isnt(LastROActivity::state(), 'RUNNING', 'off-map macro completion cannot enter RUNNING');
		is(LastROActivity::state(), 'FAILED', 'off-map macro completion fails the activity');
		like(LastROActivity::last_failure(), qr/map/i, 'off-map completion records a map failure');
		is_deeply(\@Commands::run_calls,
			['privateairship event_map', 'macro completed_entry_macro -overrideAI -exclusive',
				'privateairship prontera'],
			'off-map macro completion starts the fixed return exactly once');
		$Commands::run_failure = undef;
		$macro::queue = undef;
		done_testing();
	};

	# Task 7 lifecycle fixtures keep each scenario focused on the public plugin
	# boundaries while preserving the real State/Rules/Scheduler implementations.
	my $task7_setup_running = sub {
		my ($event_id, $extra) = @_;
		$extra ||= {};
		LastROActivity::cleanup_and_restore('task 7 reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			lockMap_randX => 7,
			lockMap_randY => 8,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		%Globals::maps_lut = (
			'event_map.rsw' => 1,
			'other_map.rsw' => 1,
			'prontera.rsw' => 1,
		);
		$Globals::field = PluginTest::Field->new('event_map');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {
			lastroAirship => 1,
			privateAirshipItemID => 14527,
		};
		%Globals::mon_control = (
			event_egg => {teleport_search => 1},
			event_mvp => {teleport_search => 1},
		);
		%Globals::monsters_lut = (9001 => 'event_egg', 9002 => 'event_mvp');
		%Plugins::registered_plugins = (macro => 1);
		my $lastro_command = $Commands::commands{lastroactivity}
			|| \&LastROActivity::commandHandler;
		%Commands::commands = (lastroactivity => $lastro_command, macro => sub { 1 });
		$Commands::run_failure = undef;
		@Commands::run_calls = ();
		@AI::clear_calls = ();
		@Log::warnings = ();
		@trace = ();

		my $rule = {
			event_id => $event_id,
			enabled => 1,
			announce_regex => 'START',
			start_regex => 'START',
			finish_regex => 'DONE',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			search_targets => ['event_egg'],
			duration_seconds => 900,
			validation_errors => [],
			%$extra,
		};
		my $event = {event_id => $event_id, rule => $rule, map => 'event_map'};
		$LastROActivity::active_event = $event;
		$LastROActivity::armed_event = $event;
		$LastROActivity::active_snapshot = LastROActivity::State::snapshot_config(
			\%Globals::config,
		);
		LastROActivity::State::apply_activity_config(\%Globals::config, 7);
		$LastROActivity::activity_lock = 1;
		$LastROActivity::state = LastROActivity::State->new;
		$LastROActivity::state->transition($_)
			for qw(arm trigger snapshot depart enter running);
		$LastROActivity::activity_started_at = 100;
		$LastROActivity::activity_phase_started_at = 100;
		$LastROActivity::clock = sub { 100 };
		return ($rule, $event);
	};

	my $task7_confirm_return = sub {
		$Globals::field = PluginTest::Field->new('prontera');
		LastROActivity::onMapChange(undef, {});
	};
	my $task7_activity_message = sub {
		my ($message) = @_;
		return eval { LastROActivity::onActivityMessage($message) };
	};
	my $task7_timeout = sub {
		my ($now) = @_;
		return eval { LastROActivity::checkActivityTimeout($now) };
	};

	subtest 'dojo rounds stop at the limit and use a trusted leave NPC' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_rounds',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 3,
				leave_npc => 'Central Guide#ok,yes',
				leave_npc_trusted => 1,
				leave_npc_evidence => 'trusted server dialog transcript',
				leave_x => 12,
				leave_y => 34,
			},
		);
		@Commands::run_calls = ();
		is($event->{round_count} || 0, 0, 'dojo starts before its first round');
		ok(defined $task7_activity_message->('ROUND START'),
			'round start evidence is consumed');
		for my $round (1 .. 2) {
			ok(defined $task7_activity_message->('ROUND SUCCESS'),
				"round $round success is consumed");
			is($event->{round_count}, $round,
				"round $round increments the activity counter");
			is(LastROActivity::state(), 'RUNNING',
				"round $round keeps combat running");
			ok(defined $task7_activity_message->('ROUND START'),
				"round " . ($round + 1) . " start evidence is consumed")
				if $round < 2;
		}
		ok(defined $task7_activity_message->('ROUND START'),
			'round 3 start evidence is consumed');
		ok(defined $task7_activity_message->('ROUND SUCCESS'),
			'final round success is consumed');
		is($event->{round_count}, 3, 'third success reaches the configured limit');
		is(LastROActivity::state(), 'RETURNING',
			'round limit stops combat and starts the return lifecycle');
		is_deeply(\@Commands::run_calls,
			['macro stop', 'talknpc 12 34 ok,yes', 'privateairship prontera'],
			'round limit executes the trusted leave NPC before returning');
		$task7_confirm_return->();
		is(LastROActivity::active_event(), undef,
			'round-limit return cleans up after prontera confirmation');
		done_testing();
	};

	subtest 'dojo round success before a round start is ignored' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_success_before_start',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 1,
			},
		);
		my $result = $task7_activity_message->('ROUND SUCCESS');
		ok(!defined $result,
			'round success without matching start is not consumed');
		is($event->{round_count} || 0, 0,
			'round success without matching start does not increment the counter');
		is($event->{round_started} || 0, 0,
			'round remains unopened after an orphan success');
		is(LastROActivity::state(), 'RUNNING',
			'orphan success leaves the activity running');
		done_testing();
	};

	subtest 'duplicate dojo round success is ignored until the next round starts' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_duplicate_success',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 3,
			},
		);
		ok(defined $task7_activity_message->('ROUND START'),
			'first round start evidence is consumed');
		ok(defined $task7_activity_message->('ROUND SUCCESS'),
			'first round success is consumed');
		is($event->{round_count}, 1,
			'first success increments the activity counter once');
		my $duplicate = $task7_activity_message->('ROUND SUCCESS');
		ok(!defined $duplicate,
			'duplicate success without a new start is ignored');
		is($event->{round_count}, 1,
			'duplicate success does not increment the activity counter');
		ok(defined $task7_activity_message->('ROUND START'),
			'next round start evidence is consumed');
		ok(defined $task7_activity_message->('ROUND SUCCESS'),
			'next round success is consumed');
		is($event->{round_count}, 2,
			'counter resumes after the next explicit round start');
		done_testing();
	};

	subtest 'dojo leave waits for the TalkNPC queue before returning' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_leave_wait',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 1,
				leave_npc => 'Central Guide#ok,yes',
				leave_npc_trusted => 1,
				leave_npc_evidence => 'trusted server dialog transcript',
				leave_x => 12,
				leave_y => 34,
			},
		);
		my $npc_queue_active = 0;
		my $npc_task = PluginTest::NpcTask->new(1, undef);
		$Commands::run_failure = sub {
			my ($command) = @_;
			if ($command eq 'talknpc 12 34 ok,yes') {
				$npc_queue_active = 1;
				@AI::ai_seq = ('NPC');
				@AI::ai_seq_args = ($npc_task);
			}
			return 1;
		};
		@Commands::run_calls = ();
		{
			no warnings 'redefine';
			local *AI::inQueue = sub { return $npc_queue_active ? 1 : 0 };
			local *AI::findAction = sub {
				return 0 if $npc_queue_active && @AI::ai_seq
					&& $AI::ai_seq[0] eq 'NPC';
				return undef;
			};
			# AI::args returns an unblessed hash view in the real runtime;
			# the task object itself remains in Globals::@ai_seq_args.
			local *AI::args = sub {
				my ($index) = @_;
				return \%{$AI::ai_seq_args[$index]};
			};
			$task7_activity_message->('ROUND START');
			$task7_activity_message->('ROUND SUCCESS');
			is(LastROActivity::state(), 'FINISHING',
				'round limit remains in FINISHING while leave NPC is queued');
			ok(!grep { $_ eq 'privateairship prontera' } @Commands::run_calls,
				'leave queue prevents an immediate return command');
			LastROActivity::onMainLoopPre(undef, {now => 101});
			ok(!grep { $_ eq 'privateairship prontera' } @Commands::run_calls,
				'active leave queue still blocks return on the next loop');
			$npc_task->{status} = 4;
			$npc_queue_active = 0;
			@AI::ai_seq = ();
			@AI::ai_seq_args = ();
			LastROActivity::onMainLoopPre(undef, {now => 102});
			is(LastROActivity::state(), 'RETURNING',
				'queue disappearance advances the lifecycle to RETURNING');
			is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
				'return is issued once after leave queue completion');
			$task7_confirm_return->();
		}
		$Commands::run_failure = undef;
		done_testing();
	};

	subtest 'observable NPC queue without a task observer fails closed' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_leave_unobservable',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 1,
				leave_npc => 'Central Guide#ok,yes',
				leave_npc_trusted => 1,
				leave_npc_evidence => 'trusted server dialog transcript',
				leave_x => 12,
				leave_y => 34,
			},
		);
		my $npc_queue_active = 0;
		$Commands::run_failure = sub {
			my ($command) = @_;
			$npc_queue_active = 1 if $command eq 'talknpc 12 34 ok,yes';
			return 1;
		};
		@Commands::run_calls = ();
		{
			no warnings 'redefine';
			local *AI::inQueue = sub { return $npc_queue_active ? 1 : 0 };
			$task7_activity_message->('ROUND START');
			$task7_activity_message->('ROUND SUCCESS');
		}
		is(LastROActivity::state(), 'FAILED',
			'queue visibility without task identity fails the activity');
		like(LastROActivity::last_failure(), qr/(?:task|observer|NPC)/i,
			'unobservable leave task records a diagnostic');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'unobservable leave task requests one fixed return');
		$task7_confirm_return->();
		$Commands::run_failure = undef;
		done_testing();
	};

	subtest 'dojo leave task errors fail instead of treating queue disappearance as success' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_leave_task_error',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 1,
				leave_npc => 'Central Guide#ok,yes',
				leave_npc_trusted => 1,
				leave_npc_evidence => 'trusted server dialog transcript',
				leave_x => 12,
				leave_y => 34,
			},
		);
		my $npc_queue_active = 0;
		my $npc_task = PluginTest::NpcTask->new(1, undef);
		$Commands::run_failure = sub {
			my ($command) = @_;
			$npc_queue_active = 1 if $command eq 'talknpc 12 34 ok,yes';
			return 1;
		};
		@Commands::run_calls = ();
		{
			no warnings 'redefine';
			local *AI::inQueue = sub { return $npc_queue_active ? 1 : 0 };
			local *AI::findAction = sub { return $npc_queue_active ? 0 : undef };
			local *AI::args = sub { return $npc_task };
			$task7_activity_message->('ROUND START');
			$task7_activity_message->('ROUND SUCCESS');
			is(LastROActivity::state(), 'FINISHING',
				'leave task is pending before its result arrives');
			$npc_task->{status} = 4;
			$npc_task->{error} = {message => 'NPC rejected the leave dialog'};
			$npc_queue_active = 0;
			LastROActivity::onMainLoopPre(undef, {now => 102});
			is(LastROActivity::state(), 'FAILED',
				'completed leave task error fails the activity');
			like(LastROActivity::last_failure(), qr/NPC|leave|dialog/i,
				'leave task error is retained as a diagnostic');
			is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
				'failed leave task still requests one fixed return');
			$task7_confirm_return->();
		}
		$Commands::run_failure = undef;
		done_testing();
	};

	subtest 'dojo round limit fails closed without trusted leave evidence' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_dojo_no_leave_evidence',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
				max_rounds => 3,
			},
		);
		@Commands::run_calls = ();
		for (1 .. 3) {
			$task7_activity_message->('ROUND START');
			$task7_activity_message->('ROUND SUCCESS');
		}
		is(LastROActivity::state(), 'FAILED',
			'missing leave evidence fails the dojo at the round limit');
		like(LastROActivity::last_failure(), qr/leave.*(?:NPC|evidence)|evidence.*leave/i,
			'missing leave evidence is recorded');
		ok(!grep(/^talknpc /, @Commands::run_calls),
			'missing leave evidence never guesses a TalkNPC command');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'fail-closed round completion still requests the fixed return');
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'resurrection-capable party death abandons immediately' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_party_priest_death',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
			},
		);
		@Commands::run_calls = ();
		$Globals::jobs_lut{8} = 'Priest';
		$Globals::char->{party} = {
			users => {
				priest_member => {jobID => 8, dead => 1},
			},
		};
		LastROActivity::onMainLoopPre(undef, {now => 200});
		is(LastROActivity::state(), 'FAILED',
			'dead Priest causes an immediate failed return');
		like(LastROActivity::last_failure(), qr/(?:priest|resurrection|party).*(?:dead|died)/i,
			'party death keeps an actionable diagnostic');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'party death requests one return');
		$task7_confirm_return->();

		($rule, $event) = $task7_setup_running->(
			'task7_skill_priest_death',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
			},
		);
		@Commands::run_calls = ();
		$Globals::char->{party} = {
			users => {
				skill_member => {
					dead => 1,
					skills => {ALL_RESURRECTION => {lv => 1}},
				},
			},
		};
		LastROActivity::onMainLoopPre(undef, {now => 200});
		is(LastROActivity::state(), 'FAILED',
			'party member skill evidence also marks the activity failed');
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'non-dojo activity ignores resurrection-capable party death' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_non_dojo_party_death');
		$Globals::jobs_lut{8} = 'Priest';
		$Globals::char->{party} = {
			users => {
				priest_member => {jobID => 8, dead => 1},
			},
		};
		@Commands::run_calls = ();
		LastROActivity::onMainLoopPre(undef, {now => 200});
		is(LastROActivity::state(), 'RUNNING',
			'non-dojo activity remains running after party death');
		ok(!grep { $_ eq 'privateairship prontera' } @Commands::run_calls,
			'non-dojo party death does not request a return');
		done_testing();
	};

	subtest 'explicit zero Resurrection level overrides job capability fallback' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_zero_resurrection_skill',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
			},
		);
		$Globals::jobs_lut{8} = 'Priest';
		$Globals::char->{party} = {
			users => {
				priest_member => {
					jobID => 8,
					dead => 1,
					skills => {ALL_RESURRECTION => {lv => 0}},
				},
			},
		};
		@Commands::run_calls = ();
		LastROActivity::onMainLoopPre(undef, {now => 200});
		is(LastROActivity::state(), 'RUNNING',
			'zero explicit Resurrection level is treated as non-capable');
		ok(!grep { $_ eq 'privateairship prontera' } @Commands::run_calls,
			'zero explicit Resurrection level does not trigger a return');
		done_testing();
	};

	subtest 'blessed Priest method returning zero still uses job fallback' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_zero_method_resurrection_skill',
			{
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
			},
		);
		$Globals::char->{party} = {
			users => {
				priest_member => PluginTest::SkillActor->new(
					dead => 1,
					job_result => 'Priest',
				),
			},
		};
		@Commands::run_calls = ();
		LastROActivity::onMainLoopPre(undef, {now => 200});
		is(LastROActivity::state(), 'FAILED',
			'zero-valued skill lookup does not suppress Priest job fallback');
		like(LastROActivity::last_failure(), qr/(?:priest|resurrection|party).*(?:dead|died)/i,
			'blessed Priest fallback keeps an actionable diagnostic');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'blessed Priest fallback requests one return');
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'output character death waits for resurrection then abandons on timeout' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_self_death_wait',
			{
				resurrection_wait_seconds => 30,
				round_start_regex => 'ROUND START',
				round_success_regex => 'ROUND SUCCESS',
			},
		);
		@Commands::run_calls = ();
		$Globals::char->{dead} = 1;
		LastROActivity::onMainLoopPre(undef, {now => 200});
		is(LastROActivity::state(), 'RUNNING',
			'self death enters a bounded resurrection wait');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 0,
			'self death does not leave immediately');
		LastROActivity::onMainLoopPre(undef, {now => 229});
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 0,
			'self death remains pending before the wait deadline');
		$Globals::char->{dead} = 0;
		LastROActivity::onMainLoopPre(undef, {now => 229});
		is(LastROActivity::state(), 'RUNNING',
			'alive state clears the resurrection wait');
		$Globals::char->{dead} = 1;
		LastROActivity::onMainLoopPre(undef, {now => 300});
		LastROActivity::onMainLoopPre(undef, {now => 330});
		is(LastROActivity::state(), 'FAILED',
			'expired resurrection wait abandons the activity');
		like(LastROActivity::last_failure(), qr/resurrect|dead|wait/i,
			'expired wait records a diagnostic');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'expired wait requests one return');
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'active finish and phase messages are scoped and cleanup is idempotent' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_finish',
			{
				phases => [
					{name => 'eggs', finish_regex => 'EGGS CLEARED', timeout_seconds => 30},
					{name => 'mvp', finish_regex => 'MVP CLEARED', timeout_seconds => 30},
				],
			},
		);
		my %before = (
			lockMap => 'pay_fild08', lockMap_x => 55, lockMap_y => 66,
			lockMap_randX => 7, lockMap_randY => 8,
			teleportAuto_search => 0, teleportAuto_idle => 0,
		);
		my $cleanup_calls = 0;
		my $original_cleanup = \&LastROActivity::cleanup_and_restore;
		{
			no warnings 'redefine';
			local *LastROActivity::cleanup_and_restore = sub {
				$cleanup_calls++;
				return $original_cleanup->(@_);
			};
			is($task7_activity_message->('EGGS CLEARED'), 'phase',
				'eggs announcement advances only the active phase');
			is($LastROActivity::active_event->{phase_index}, 1,
				'phase advances from eggs to MVP');
			is($task7_activity_message->('UNRELATED DONE FROM ANOTHER EVENT'), undef,
				'unrelated finish text is ignored');
			is($task7_activity_message->('MVP CLEARED'), 'finish',
				'final MVP phase finishes the active event');
			$task7_confirm_return->();
			# A duplicate map packet and duplicate finish signal must not clean twice.
			$task7_activity_message->('MVP CLEARED');
			$task7_confirm_return->();
		}
		is($cleanup_calls, 1, 'finish path invokes cleanup exactly once');
		is_deeply(\%Globals::config, \%before, 'finish path restores the exact snapshot');
		is(LastROActivity::activity_locked(), 0, 'finish path releases the lock');
		done_testing();
	};

	subtest 'timeout API distinguishes entry failure from phase and overall finish' => sub {
		my ($rule, $event) = $task7_setup_running->(
			'task7_timeout',
			{phases => [{name => 'eggs', finish_regex => 'EGGS CLEARED', timeout_seconds => 10}]},
		);
		is($task7_timeout->(109), undef,
			'phase timeout is not reported before its deadline');
		is($task7_timeout->(110), 'finish',
			'phase timeout requests a finish');
		$task7_confirm_return->();

		($rule, $event) = $task7_setup_running->('task7_overall', {duration_seconds => 900});
		is($task7_timeout->(1000), 'finish',
			'overall duration timeout requests a finish');
		$task7_confirm_return->();

		($rule, $event) = $task7_setup_running->('task7_entry_timeout', {timeout_seconds => 5});
		$LastROActivity::state = LastROActivity::State->new;
		$LastROActivity::state->transition($_) for qw(arm trigger snapshot depart);
		$LastROActivity::pending_destination = 'event_map';
		$LastROActivity::pending_destination_kind = 'entry';
		$LastROActivity::pending_destination_deadline = 105;
		is($task7_timeout->(106), 'fail',
			'entry timeout fails rather than finishing the activity');
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'repeated airship failures and map kick-out use one return and one cleanup' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_airship_failures');
		$LastROActivity::state = LastROActivity::State->new;
		$LastROActivity::state->transition($_) for qw(arm trigger snapshot depart);
		$LastROActivity::pending_destination = 'event_map';
		$LastROActivity::pending_destination_kind = 'entry';
		$LastROActivity::pending_destination_deadline = 200;
		my $cleanup_calls = 0;
		my $original_cleanup = \&LastROActivity::cleanup_and_restore;
		{
			no warnings 'redefine';
			local *LastROActivity::cleanup_and_restore = sub {
				$cleanup_calls++;
				return $original_cleanup->(@_);
			};
			LastROActivity::onAirshipResult(undef, {type => 2});
			LastROActivity::onAirshipResult(undef, {type => 2});
			LastROActivity::onAirshipResult(undef, {type => 2});
			is_deeply(\@trace, ['privateairship event_map', 'privateairship event_map', 'macro stop',
				'AI::clear attack move route mapRoute items_take items_gather take',
				'AI::clear NPC teleport', 'privateairship prontera'],
				'three failures issue bounded entry retries and one return request');
			$task7_confirm_return->();
		}
		is($cleanup_calls, 1, 'repeated airship failures clean up once');
		is(LastROActivity::last_failure(), 'You do not have enough Private Airship items',
			'failure reason is retained');

		($rule, $event) = $task7_setup_running->('task7_kickout');
		my %before = (
			lockMap => 'pay_fild08', lockMap_x => 55, lockMap_y => 66,
			lockMap_randX => 7, lockMap_randY => 8,
			teleportAuto_search => 0, teleportAuto_idle => 0,
		);
		LastROActivity::onMapChange(undef, {map => 'other_map'});
		$task7_confirm_return->();
		is_deeply(\%Globals::config, \%before, 'map kick-out restores the snapshot');
		is(LastROActivity::activity_locked(), 0, 'map kick-out releases the lock');
		done_testing();
	};

	subtest 'running activity mutex ignores duplicate starts and manual stop/off stop macros' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_mutex');
		$LastROActivity::initialized = 1;
		$LastROActivity::rules = {task7_mutex => $rule};
		my $state_before = LastROActivity::state();
		is($task7_activity_message->('START'), undef,
			'duplicate start announcement is not a finish signal');
		is(LastROActivity::state(), $state_before, 'duplicate start does not interrupt RUNNING');
		is(LastROActivity::active_event()->{event_id}, 'task7_mutex',
			'active event remains the mutex owner');
		my $before_commands = scalar @Commands::run_calls;
		$Commands::commands{lastroactivity}->('lastroactivity', 'stop');
		ok(grep($_ eq 'macro stop', @Commands::run_calls), 'manual stop stops an active macro');
		ok(grep($_ eq 'privateairship prontera', @Commands::run_calls), 'manual stop uses the fixed return');
		$task7_confirm_return->();

		($rule, $event) = $task7_setup_running->('task7_off');
		$Commands::commands{lastroactivity}->('lastroactivity', 'off');
		ok(grep($_ eq 'privateairship prontera', @Commands::run_calls), 'off uses the fixed return for an active event');
		$task7_confirm_return->();
		$Commands::commands{lastroactivity}->('lastroactivity', 'on');
		done_testing();
	};

	subtest 'malformed macros fail closed and NPC/macro entries perform work' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_bad_macro', {
			entry_macro => 'bad macro name',
		});
		my %before = %Globals::config;
		$LastROActivity::active_event = undef;
		$LastROActivity::active_snapshot = undef;
		$LastROActivity::activity_lock = 0;
		my $ok = LastROActivity::begin_activity($rule, $event);
		is($ok, 0, 'malformed entry macro rejects the activity');
		is_deeply(\%Globals::config, \%before, 'malformed macro leaves config unchanged');
		like(join('', @Log::warnings), qr/macro/i, 'malformed macro is logged');

		@Commands::run_calls = ();
		my $macro_rule = {
			event_id => 'task7_macro_entry', enabled => 1, announce_regex => 'START', start_regex => 'START',
			entry_type => 'macro', entry_map => 'event_map', entry_macro => 'enter_event',
			validation_errors => [],
		};
		ok(LastROActivity::request_event_entry($macro_rule, {map => 'event_map'}),
			'macro entry is not a no-op');
		ok(grep($_ eq 'macro enter_event -overrideAI -exclusive', @Commands::run_calls),
			'macro entry launches the configured macro');

		@Commands::run_calls = ();
		my $npc_rule = {
			event_id => 'task7_npc_entry', enabled => 1, announce_regex => 'START', start_regex => 'START',
			entry_type => 'npc', entry_map => 'event_map', entry_x => 10, entry_y => 20,
			entry_npc => 'Guide#c', validation_errors => [],
		};
		ok(LastROActivity::request_event_entry($npc_rule, {map => 'event_map'}),
			'NPC entry is not a no-op');
		is($Commands::run_calls[0], 'talknpc 10 20 c', 'NPC entry issues a TalkNPC command');
		done_testing();
	};

	subtest 'activity cleanup clears NPC and teleport tasks' => sub {
		LastROActivity::cleanup_and_restore('test reset');
		%Plugins::registered_plugins = ();
		%Commands::commands = ();
		@AI::clear_calls = ();
		ok(LastROActivity::clear_activity_ai(), 'activity cleanup succeeds');
		is_deeply(
			\@AI::clear_calls,
			[
				'AI::clear attack move route mapRoute items_take items_gather take',
				'AI::clear NPC teleport',
			],
			'activity cleanup clears ordinary and activity-specific AI tasks',
		);
		done_testing();
	};

	subtest 'lifecycle validation fails closed with auditable completion and map errors' => sub {
		# Start from the same trusted runtime fixture used by the lifecycle cases,
		# then exercise validation before the snapshot/lock boundary.
		$task7_setup_running->('task7_validation_seed');
		LastROActivity::cleanup_and_restore('validation seed cleanup');
		@Commands::run_calls = ();
		my %before = %Globals::config;
		my $make_rule = sub {
			my ($id, $extra) = @_;
			$extra ||= {};
			return {
				event_id => $id,
				enabled => 1,
				announce_regex => 'START',
				start_regex => 'START',
				entry_type => 'privateairship',
				entry_item_id => 14527,
				entry_map => 'event_map',
				search_targets => ['event_egg'],
				validation_errors => [],
				%$extra,
			};
		};

		my $rule = $make_rule->('task7_no_completion');
		my $ok = LastROActivity::begin_activity($rule, {
			event_id => $rule->{event_id}, map => 'event_map', rule => $rule,
		});
		is($ok, 0, 'enabled rule without finish evidence is rejected');
		ok(!$rule->{enabled}, 'completion validation disables the rule');
		like(join('', @{$rule->{validation_errors}}), qr/finish|duration/i,
			'completion validation is attached to the rule');
		is_deeply(\@Commands::run_calls, [], 'completion validation has no entry side effect');
		is_deeply(\%Globals::config, \%before, 'completion validation leaves config untouched');

		LastROActivity::cleanup_and_restore('between completion validation cases');
		%Globals::config = %before;
		@Commands::run_calls = ();
		$rule = $make_rule->('task7_bad_finish', {
			finish_regex => '[', duration_seconds => 900,
		});
		$ok = LastROActivity::begin_activity($rule, {
			event_id => $rule->{event_id}, map => 'event_map', rule => $rule,
		});
		is($ok, 0, 'malformed finish pattern is rejected');
		ok(!$rule->{enabled}, 'malformed finish pattern disables the rule');
		like(join('', @{$rule->{validation_errors}}), qr/finish.*pattern|regex/i,
			'malformed finish error is attached');

		LastROActivity::cleanup_and_restore('between phase validation cases');
		%Globals::config = %before;
		@Commands::run_calls = ();
		$rule = $make_rule->('task7_named_phase', {
			phases => [{name => 'eggs'}], duration_seconds => 900,
		});
		$ok = LastROActivity::begin_activity($rule, {
			event_id => $rule->{event_id}, map => 'event_map', rule => $rule,
		});
		is($ok, 0, 'phase without an explicit finish condition is rejected');
		ok(!$rule->{enabled}, 'phase validation disables the rule');
		like(join('', @{$rule->{validation_errors}}), qr/phase.*finish|condition/i,
			'missing phase condition is attached');

		LastROActivity::cleanup_and_restore('between static map validation cases');
		%Globals::config = %before;
		@Commands::run_calls = ();
		$rule = $make_rule->('task7_unknown_static', {
			entry_map => 'not_a_real_map', finish_regex => 'DONE', duration_seconds => 900,
		});
		$ok = LastROActivity::begin_activity($rule, {
			event_id => $rule->{event_id}, map => 'not_a_real_map', rule => $rule,
		});
		is($ok, 0, 'unknown static map is rejected');
		ok(!$rule->{enabled}, 'unknown static map disables the rule');
		like(join('', @{$rule->{validation_errors}}), qr/unknown|map/i,
			'unknown static map error is attached');

		LastROActivity::cleanup_and_restore('between dynamic map validation cases');
		%Globals::config = %before;
		@Commands::run_calls = ();
		$rule = $make_rule->('task7_unknown_dynamic', {
			map_source => 'dynamic', finish_regex => 'DONE', duration_seconds => 900,
		});
		$ok = LastROActivity::begin_activity($rule, {
			event_id => $rule->{event_id}, map => 'event_map', rule => $rule,
		});
		is($ok, 0, 'dynamic map without announcement metadata is rejected');
		ok(!$rule->{enabled}, 'dynamic map error disables the rule');
		like(join('', @{$rule->{validation_errors}}), qr/map/i,
			'dynamic map error is attached');
		done_testing();
	};

	subtest 'NPC lifecycle entries require trusted dialog evidence' => sub {
		$task7_setup_running->('task7_npc_validation_seed');
		LastROActivity::cleanup_and_restore('NPC validation seed cleanup');
		@Commands::run_calls = ();
		my $rule = {
			event_id => 'task7_untrusted_npc', enabled => 1, announce_regex => 'START', start_regex => 'START',
			entry_type => 'npc', entry_map => 'event_map', entry_x => 10, entry_y => 20,
			entry_npc => 'Guide#c', duration_seconds => 120, validation_errors => [],
		};
		my $ok = LastROActivity::begin_activity($rule, {
			event_id => $rule->{event_id}, map => 'event_map', rule => $rule,
		});
		is($ok, 0, 'untrusted NPC lifecycle rule is rejected');
		ok(!$rule->{enabled}, 'untrusted NPC rule is disabled');
		like(join('', @{$rule->{validation_errors}}), qr/trusted|evidence|dialog/i,
			'NPC trust failure is attached');
		is_deeply(\@Commands::run_calls, [], 'unknown NPC dialog is never executed');

		LastROActivity::cleanup_and_restore('between NPC trust cases');
		$rule = {
			event_id => 'task7_trusted_npc', enabled => 1, announce_regex => 'START', start_regex => 'START',
			entry_type => 'npc', entry_map => 'event_map', entry_x => 10, entry_y => 20,
			entry_npc => 'Guide#c', duration_seconds => 120,
			entry_npc_trusted => 1, entry_npc_evidence => 'server dialog transcript',
			validation_errors => [],
		};
		@Commands::run_calls = ();
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			$ok = LastROActivity::begin_activity($rule, {
				event_id => $rule->{event_id}, map => 'event_map', rule => $rule,
			});
		}
		is($ok, 1, 'trusted NPC lifecycle rule may start');
		is($Commands::run_calls[0], 'talknpc 10 20 c', 'trusted NPC entry executes its sequence');
		done_testing();
	};

	subtest 'parsed trusted NPC evidence reaches the lifecycle validator' => sub {
		$task7_setup_running->('task7_parsed_npc_seed');
		LastROActivity::cleanup_and_restore('parsed NPC validation seed cleanup');
		my ($fh, $path) = tempfile('lastro-activity-parsed-npc-XXXXXX', UNLINK => 1);
		binmode $fh, ':encoding(UTF-8)';
		print {$fh} <<'RULES';
[parsed_trusted_npc]
enabled=1
announce_regex=START
start_regex=START
entry_type=npc
entry_map=event_map
entry_x=10
entry_y=20
entry_npc=Guide#c
duration_seconds=120
entry_npc_trusted=1
entry_npc_evidence=server dialog transcript
RULES
		close $fh;
		my ($parsed, $parse_errors) = LastROActivity::Rules::load_file($path);
		is_deeply($parse_errors, [], 'trusted NPC evidence is accepted by the rules parser');
		my $rule = $parsed->{parsed_trusted_npc};
		ok($rule->{enabled}, 'parsed trusted NPC rule remains enabled');
		is($rule->{entry_npc_trusted}, 1, 'trusted metadata reaches the plugin rule');
		is($rule->{entry_npc_evidence}, 'server dialog transcript', 'dialog evidence reaches the plugin rule');
		@Commands::run_calls = ();
		my $event = {
			event_id => $rule->{event_id},
			rule => $rule,
			map => 'event_map',
		};
		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			is(LastROActivity::begin_activity($rule, $event), 1,
				'parsed trusted NPC rule starts through the lifecycle path');
		}
		is($Commands::run_calls[0], 'talknpc 10 20 c',
			'parsed trusted NPC rule executes its TalkNPC sequence');
		LastROActivity::cleanup_and_restore('parsed NPC test cleanup');
		done_testing();
	};

	subtest 'entry airship failures retry at most three times before one return' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_retry_cap');
		$LastROActivity::state = LastROActivity::State->new;
		$LastROActivity::state->transition($_) for qw(arm trigger snapshot depart);
		$LastROActivity::pending_destination = 'event_map';
		$LastROActivity::pending_destination_kind = 'entry';
		$LastROActivity::pending_destination_deadline = 200;
		$LastROActivity::airship_failure_count = 0;
		@Commands::run_calls = ('privateairship event_map');

		{
			no warnings 'redefine';
			local *LastROActivity::clear_normal_ai = sub { return 1 };
			LastROActivity::onAirshipResult(undef, {type => 2});
			is($LastROActivity::airship_failure_count, 1, 'first rejection is counted');
			is($LastROActivity::pending_destination_kind, 'entry', 'first rejection schedules another entry attempt');
			LastROActivity::onAirshipResult(undef, {type => 2});
			is($LastROActivity::airship_failure_count, 2, 'second rejection is counted');
			is($LastROActivity::pending_destination_kind, 'entry', 'second rejection schedules the final entry attempt');
			LastROActivity::onAirshipResult(undef, {type => 2});
			is($LastROActivity::airship_failure_count, 3, 'third rejection reaches the cap');
			is(LastROActivity::state(), 'FAILED', 'exhausted entry retries fail the activity');
			is_deeply(\@Commands::run_calls,
				['privateairship event_map', 'privateairship event_map', 'privateairship event_map',
					'privateairship prontera'],
				'entry retries issue three bounded requests and one return');

			LastROActivity::onAirshipResult(undef, {type => 2});
			is_deeply(\@Commands::run_calls,
				['privateairship event_map', 'privateairship event_map', 'privateairship event_map',
					'privateairship prontera'],
				'late rejection after exhaustion cannot issue another return');
		}
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'running map kick-out is a failure and skips finish macro' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_running_kickout', {
			finish_macro => 'must_not_run',
		});
		@Commands::run_calls = ();
		LastROActivity::onMapChange(undef, {map => 'other_map'});
		is(LastROActivity::state(), 'FAILED', 'running map kick-out marks the activity failed');
		like(LastROActivity::last_failure(), qr/left activity map/i,
			'map kick-out keeps an actionable failure reason');
		ok(!grep($_ eq 'macro must_not_run -overrideAI -exclusive', @Commands::run_calls),
			'failure path does not launch the finish macro');
		is(scalar(grep($_ eq 'privateairship prontera', @Commands::run_calls)), 1,
			'failure path requests one return');
		$task7_confirm_return->();
		done_testing();
	};

	subtest 'cleanup finalizes and releases its lock when AI cleanup throws' => sub {
		$task7_setup_running->('task7_cleanup_exception');
		my $original_clear_activity = \&LastROActivity::clear_activity_ai;
		my $original_ai_clear = \&AI::clear;
		my $ok;
		{
			no warnings 'redefine';
			local *LastROActivity::clear_activity_ai = sub { die "activity AI exploded\n" };
			local *AI::clear = sub { die "final AI clear exploded\n" };
			$ok = eval { LastROActivity::cleanup_and_restore('exception cleanup') };
		}
		ok(!defined($@) || $@ eq '', 'cleanup does not leak an exception to its caller');
		is($ok, 0, 'cleanup surfaces an AI cleanup failure');
		is($LastROActivity::cleanup_in_progress, 0, 'cleanup mutex is reset after an exception');
		is(LastROActivity::activity_locked(), 0, 'cleanup releases the lock after an exception');
		is(LastROActivity::active_event(), undef, 'cleanup clears the active event after an exception');
		is($LastROActivity::active_snapshot, undef, 'cleanup clears the snapshot after an exception');
		is(LastROActivity::state(), 'IDLE', 'cleanup resets lifecycle state after an exception');
		like(LastROActivity::last_failure(), qr/AI|exploded|cleanup/i,
			'cleanup exposes the exception as a failure reason');
		done_testing();
	};

	subtest 'checked command failures fail entry and return without waiting for timeout' => sub {
		# Entry rejection is reported by the command handler through Log::error,
		# while Commands::run itself still returns success.
		LastROActivity::cleanup_and_restore('command rejection reset');
		%Globals::config = (
			lockMap => 'pay_fild08',
			lockMap_x => 55,
			lockMap_y => 66,
			teleportAuto_search => 0,
			teleportAuto_idle => 0,
		);
		%Globals::maps_lut = ('event_map.rsw' => 1, 'prontera.rsw' => 1);
		$Globals::field = PluginTest::Field->new('event_map');
		$Globals::net = PluginTest::Net->new;
		$Globals::char = PluginTest::Char->new(
			PluginTest::Inventory->new({14527 => {amount => 1}}),
		);
		$Globals::masterServer = {lastroAirship => 1, privateAirshipItemID => 14527};
		%Globals::mon_control = (event_egg => {teleport_search => 1});
		%Plugins::registered_plugins = (LastROActivity => 1);
		%Commands::commands = (lastroactivity => $Commands::commands{lastroactivity});
		@Commands::run_calls = ();
		@Log::errors = ();
		$Commands::run_failure = sub {
			my ($command) = @_;
			if ($command eq 'privateairship event_map') {
				Log::error('Destination map is invalid.');
			}
			return 1;
		};
		my $rule = {
			event_id => 'entry_command_rejected',
			enabled => 1,
			announce_regex => 'START',
			start_regex => 'START',
			finish_regex => 'DONE',
			entry_type => 'privateairship',
			entry_item_id => 14527,
			entry_map => 'event_map',
			search_targets => ['event_egg'],
			duration_seconds => 900,
			validation_errors => [],
		};
		my $event = {event_id => $rule->{event_id}, rule => $rule, map => 'event_map'};
		is(LastROActivity::begin_activity($rule, $event), 0,
			'entry command rejection fails the activity immediately');
		is(LastROActivity::state(), 'FAILED', 'entry rejection records a failed lifecycle');
		like(LastROActivity::last_failure(), qr/invalid|rejected|privateairship/i,
			'entry rejection keeps the command diagnostic');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'entry rejection requests one fixed return without waiting for timeout');
		$Commands::run_failure = undef;
		$task7_confirm_return->();

		# TalkNPC uses the same Commands::run masking behavior; a synchronous
		# handler error must be surfaced to the activity caller as well.
		@Commands::run_calls = ();
		$Commands::run_failure = sub {
			Log::error('Could not find an NPC.');
			return 1;
		};
		my $npc_rule = {
			event_id => 'npc_command_rejected',
			enabled => 1,
			announce_regex => 'START',
			start_regex => 'START',
			entry_type => 'npc',
			entry_map => 'event_map',
			entry_x => 10,
			entry_y => 20,
			entry_npc => 'Guide#c',
			entry_npc_trusted => 1,
			entry_npc_evidence => 'server dialog transcript',
			validation_errors => [],
		};
		my ($npc_ok, $npc_error);
		$npc_ok = eval { LastROActivity::request_event_entry($npc_rule, {map => 'event_map'}); 1 };
		$npc_error = $@;
		ok(!$npc_ok, 'TalkNPC command rejection is surfaced instead of accepted');
		like($npc_error, qr/NPC|rejected|failed/i, 'TalkNPC rejection exposes its diagnostic');
		$Commands::run_failure = undef;
		done_testing();
	};

	subtest 'failure cleanup continues through an activity AI clear exception' => sub {
		my ($rule, $event) = $task7_setup_running->('task7_clear_exception');
		@Commands::run_calls = ();
		my ($ok, $error);
		{
			no warnings 'redefine';
			local *LastROActivity::clear_activity_ai = sub { die "activity AI cleanup exploded\n" };
			$ok = eval { LastROActivity::_mark_activity_failed('forced failure'); 1 };
			$error = $@;
		}
		ok($ok, 'failure path contains an activity AI cleanup exception');
		is($error, '', 'activity AI cleanup exception does not escape the failure path');
		is(LastROActivity::state(), 'FAILED', 'failure state is retained after cleanup exception');
		is(scalar(grep { $_ eq 'privateairship prontera' } @Commands::run_calls), 1,
			'failure path still issues the fixed return after AI cleanup throws');
		$task7_confirm_return->();
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
