package PluginTest;

use strict;
use warnings;
use utf8;

use FindBin qw($RealBin);
use File::Spec;
use File::Temp qw(tempfile);
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
	sub import { return 1; }
	sub register { push @registrations, [@_]; return 1; }
	sub addHooks {
		push @hooks, map { $_->[0] } @_;
		return bless { hooks => [@_] }, 'Plugins::TestHookHandle';
	}
	sub delHooks { return 1; }

	$INC{'Commands.pm'} = __FILE__;
	package Commands;
	our %commands;
	our @run_calls;
	sub import { return 1; }
	sub register {
		for my $command (@_) {
			$commands{$command->[0]} = $command->[2];
		}
		return [map { $_->[0] } @_];
	}
	sub unregister { return 1; }
	sub run { push @run_calls, $_[0]; return 1; }

	$INC{'Settings.pm'} = __FILE__;
	package Settings;
	our @add_calls;
	our %handles;
	our $load_path;
	my $next_handle = 1;
	sub import { return 1; }
	sub addControlFile {
		my ($name, %options) = @_;
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
		if (ref($loader) eq 'ARRAY') {
			my @loader = @$loader;
			my $callback = shift @loader;
			$callback->($load_path || $entry->{name}, @loader);
		} else {
			$loader->($load_path || $entry->{name});
		}
		return 1;
	}
	sub removeFile { return 1; }
	sub getControlFilename { return undef; }
	sub getControlFolders { return ('control'); }

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

sub _load_plugin {
	my $plugin = File::Spec->catfile($RealBin, '..', 'LastROActivity.pl');
	my $result = do $plugin;
	die "Unable to load LastROActivity.pl: $@ $!" if !defined $result;
}

sub start {
	my $fixture = _write_fixture();
	$Settings::load_path = $fixture;
	%Globals::config = ();
	@Plugins::registrations = ();
	@Plugins::hooks = ();
	%Commands::commands = ();
	@Commands::run_calls = ();
	@Log::messages = ();
	@Log::warnings = ();
	@Log::errors = ();

	_load_plugin();

	subtest 'registers the plugin hooks and command' => sub {
		is($Plugins::registrations[0][0], 'LastROActivity', 'registers LastROActivity');
		is_deeply(
			[sort @Plugins::hooks],
			[sort qw(packet_sysMsg packet_pubMsg mainLoop_pre packet_mapChange lastro_airship_result AI_state_change)],
			'registers all activity hooks',
		);
		ok(exists $Commands::commands{lastroactivity}, 'registers lastroactivity command');
		is(LastROActivity::enabled(), 1, 'missing enabled config defaults to on');
		is(LastROActivity::lead_seconds(), 10, 'missing lead config defaults to ten seconds');
		is(LastROActivity::teleport_idle(), 1, 'missing teleport idle config defaults to one');
		is($Settings::add_calls[0][0], 'lastro_activity.txt', 'missing rules path uses active control filename');
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

	done_testing();
}

1;
