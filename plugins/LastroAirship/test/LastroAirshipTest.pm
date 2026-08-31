package LastroAirshipTest;

use strict;
use warnings;

use File::Spec;
use FindBin qw($RealBin);
use Test::More;

our $sender_loaded;

# Load the real LastRO sender while replacing only its platform boundaries.
BEGIN {
	$INC{'Globals.pm'} = __FILE__;
	package Globals;
	our (%config, %maps_lut, %portals_lut, %timeout);
	our ($char, $field, $masterServer, $messageSender);
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::config"} = \%config;
		*{"${caller}::maps_lut"} = \%maps_lut;
		*{"${caller}::portals_lut"} = \%portals_lut;
		*{"${caller}::timeout"} = \%timeout;
		*{"${caller}::char"} = \$char;
		*{"${caller}::field"} = \$field;
		*{"${caller}::masterServer"} = \$masterServer;
		*{"${caller}::messageSender"} = \$messageSender;
	}

	$INC{'I18N.pm'} = __FILE__;
	package I18N;
	sub stringToBytes { return $_[0]; }
	sub import {
		my $caller = caller;
		no strict 'refs';
		*{"${caller}::stringToBytes"} = \&stringToBytes;
	}

	$INC{'Log.pm'} = __FILE__;
	package Log;
	our (@debug, @warnings, @messages, @errors);
	sub debug { push @debug, $_[0]; return 1; }
	sub warning { push @warnings, $_[0]; return 1; }
	sub message { push @messages, $_[0]; return 1; }
	sub error { push @errors, $_[0]; return 1; }
	sub import {
		my $caller = caller;
		no strict 'refs';
		for my $name (@_) {
			next unless __PACKAGE__->can($name);
			*{"${caller}::${name}"} = \&{$name};
		}
	}

	$INC{'Network/Send/kRO/RagexeRE_2020_07_23.pm'} = __FILE__;
	package Network::Send::kRO::RagexeRE_2020_07_23;
	sub sendToServer { push @{$_[0]{sent}}, $_[1]; }
	sub sendPrivateAirshipRequest { push @{$_[0]{legacy}}, [@_[1 .. $#_]]; }

	$INC{'AI.pm'} = __FILE__;
	package AI;
	sub import { return 1; }

	$INC{'Commands.pm'} = __FILE__;
	package Commands;
	our (%commands, @unregistered);
	sub import { return 1; }
	sub register {
		my @registered;
		for my $command (@_) {
			my ($name, $description, $callback) = @$command;
			$commands{$name} = {
				desc => ref($description) eq 'ARRAY' ? $description : [$description],
				callback => $callback,
			};
			push @registered, $name;
		}
		return \@registered;
	}
	sub unregister {
		my ($handle) = @_;
		push @unregistered, [@$handle] if $handle;
		delete $commands{$_} for @{$handle || []};
		return 1;
	}

	$INC{'Plugins.pm'} = __FILE__;
	package Plugins;
	our (@registrations, @hooks, @deleted_hooks);
	sub import { return 1; }
	sub register { push @registrations, [@_]; return 1; }
	sub addHooks { push @hooks, @_; return [@_]; }
	sub delHooks { push @deleted_hooks, $_[0]; return 1; }

	$INC{'Settings.pm'} = __FILE__;
	package Settings;
	sub import { return 1; }
	sub getTableFilename { return undef; }

	$INC{'Task/MapRoute.pm'} = __FILE__;
	package Task::MapRoute;
	sub initMapCalculator { return 1; }
}

sub _load_real_sender {
	return if $sender_loaded;

	my $path = File::Spec->catfile(
		$ENV{OPENKORE_DIR}, 'src', 'Network', 'Send', 'kRO', 'RagexeRE_2021_11_03.pm',
	);
	my $result = do $path;
	die "Unable to load $path: $@ $!" unless defined $result;
	$sender_loaded = 1;
}

our $plugin_loaded;

sub _load_plugin {
	return if $plugin_loaded;

	my $path = File::Spec->catfile($ENV{OPENKORE_DIR}, 'plugins', 'LastroAirship', 'LastroAirship.pl');
	my $result = do $path;
	die "Unable to load $path: $@ $!" unless defined $result;
	$plugin_loaded = 1;
}

sub _reset_plugin_state {
	%Globals::config = ();
	%Globals::maps_lut = ();
	%Globals::portals_lut = ();
	$Globals::char = undef;
	$Globals::field = undef;
	$Globals::masterServer = undef;
	$Globals::messageSender = undef;
	%Commands::commands = ();
	@Commands::unregistered = ();
	@Plugins::registrations = ();
	@Plugins::hooks = ();
	@Plugins::deleted_hooks = ();
	@Log::debug = ();
	@Log::warnings = ();
	@Log::messages = ();
	@Log::errors = ();
}

sub _tt_callback {
	my $entry = $Commands::commands{tt};
	return unless ref($entry) eq 'HASH';
	return $entry->{callback} if ref($entry->{callback}) eq 'CODE';
	return;
}

sub run_tt {
	my ($args) = @_;
	my $callback = _tt_callback();
	return unless $callback;
	return $callback->('tt', $args);
}

{
	package LastroAirshipTest::Sender;
	sub new { return bless {calls => []}, shift; }
	sub sendPrivateAirshipRequest { push @{$_[0]{calls}}, [@_[1 .. $#_]]; }

	package LastroAirshipTest::UnsupportedSender;
}

sub start {
	_load_real_sender();

	subtest 'focused LastRO sender packs coordinate airship requests' => sub {
		$Globals::masterServer = {lastroAirship => 1};
		my $sender = bless {sent => []}, 'Network::Send::kRO::RagexeRE_2021_11_03';

		$sender->sendPrivateAirshipRequest('prontera', 14527, 152, 133, 1);
		my $coordinate_packet = $sender->{sent}[0];
		is(length($coordinate_packet), 34, 'coordinate 0A49 remains 34 bytes');
		is(substr($coordinate_packet, 2, 16), "prontera\0" . "\0" x 7,
			'coordinate request packs the normalized map in Z16');
		is_deeply(
			[unpack('V4', substr($coordinate_packet, 18, 16))],
			[152, 133, 1, 14527],
			'coordinate request matches the web-client x/y/type/item layout',
		);

		$sender->sendPrivateAirshipRequest('prontera', 607, 10, 20, 1);
		is_deeply(
			[unpack('V4', substr($sender->{sent}[1], 18, 16))],
			[10, 20, 1, 607],
			'coordinate request preserves an explicit item ID',
		);
		done_testing();
	};

	_reset_plugin_state();
	_load_plugin();
	my $tt = _tt_callback();

	subtest 'registers the tt command' => sub {
		ok($tt, 'registers tt');
		is(
			$Commands::commands{tt}{desc}[0],
			'tt <map> [x y [item_id]] - LastRO coordinate teleport',
			'registers tt help text',
		) if $tt;
		done_testing();
	};

	if ($tt) {
		my $sender = LastroAirshipTest::Sender->new;
		$Globals::masterServer = {lastroAirship => 1};
		$Globals::messageSender = $sender;

		subtest 'tt sends valid LastRO transfer layouts' => sub {
			run_tt('prontera');
			is_deeply($sender->{calls}[-1], ['prontera', 14527, 0, 0, 0],
				'map-only tt uses type zero');

			run_tt('prontera 152 133');
			is_deeply($sender->{calls}[-1], ['prontera', 14527, 152, 133, 1],
				'coordinate tt uses type one');

			run_tt('prontera 152 133 607');
			is_deeply($sender->{calls}[-1], ['prontera', 607, 152, 133, 1],
				'tt accepts explicit item ID');
			done_testing();
		};

		subtest 'tt rejects malformed transfer requests' => sub {
			for my $case (
				{input => undef, label => 'empty input'},
				{input => 'prontera 152', label => 'incomplete coordinates'},
				{input => 'prontera 152 133 14527 extra', label => 'extra argument'},
				{input => 'prontera -1 133', label => 'negative x'},
				{input => 'prontera 65536 133', label => 'x above u16'},
				{input => 'prontera 152 nope', label => 'non-numeric y'},
				{input => 'prontera 152 133 0', label => 'zero item ID'},
				{input => 'abcdefghijklmnop', label => 'map fills Z16 payload'},
				{input => 'map_name_longer_than_sixteen_bytes', label => 'map above Z16'},
			) {
				@{$sender->{calls}} = ();
				@Log::errors = ();
				run_tt($case->{input});
				is(scalar @{$sender->{calls}}, 0, "$case->{label} sends nothing");
				ok(scalar @Log::errors, "$case->{label} logs an error");
			}
			done_testing();
		};

		subtest 'tt requires a LastRO profile and supported sender' => sub {
			@{$sender->{calls}} = ();
			@Log::errors = ();
			$Globals::masterServer = {lastroAirship => 0};
			run_tt('prontera');
			is(scalar @{$sender->{calls}}, 0, 'non-LastRO profile sends nothing');
			ok(scalar @Log::errors, 'non-LastRO profile logs an error');

			@Log::errors = ();
			$Globals::masterServer = {lastroAirship => 1};
			$Globals::messageSender = undef;
			run_tt('prontera');
			ok(scalar @Log::errors, 'missing sender logs an error');

			@Log::errors = ();
			$Globals::messageSender = bless {}, 'LastroAirshipTest::UnsupportedSender';
			run_tt('prontera');
			ok(scalar @Log::errors, 'unsupported sender logs an error');
			done_testing();
		};

		$Globals::messageSender = $sender;
		subtest 'unload unregisters tt' => sub {
			LastroAirship::onUnload();
			ok(!exists $Commands::commands{tt}, 'unregisters tt on unload');
			is_deeply($Commands::unregistered[-1], ['tt'], 'unregisters the tt command handle');
			done_testing();
		};
	}

	done_testing();
}

1;
