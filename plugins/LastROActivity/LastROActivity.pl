package LastROActivity;

use strict;
use warnings;
use utf8;

use Time::HiRes qw(time);
use File::Basename qw(dirname);
use File::Spec;

# Plugins are evaluated with do(), so add the sibling module directory without
# assuming that an optional test harness has populated current_plugin_folder.
BEGIN {
	my $folder = eval { $Plugins::current_plugin_folder };
	if (!defined $folder || $folder eq '') {
		require File::Basename;
		$folder = File::Basename::dirname(__FILE__);
	}
	unshift @INC, $folder if defined $folder && $folder ne '';
}

use AI ();
use Commands ();
use Globals ();
use LastROActivity::Rules;
use LastROActivity::Scheduler;
use LastROActivity::State;
use Log qw(debug error message warning);
use Plugins;
use Settings;

our ($scheduler, $state, $enabled, $lead_seconds, $teleport_idle);
our ($rules, $rules_file, $rules_requested, $rules_file_handle);
our $initialized;
our ($active_event, $armed_event, $last_failure, $active_snapshot);
our (@pending_due, @pending_manual);
our ($hooks, $commands);
our $clock = sub { time };

$rules = {};
$rules_file = undef;
$rules_requested = undef;
$rules_file_handle = undef;
$initialized = 0;
$state = LastROActivity::State->new;
$last_failure = undef;
$active_event = undef;
$armed_event = undef;
$active_snapshot = undef;
@pending_due = ();
@pending_manual = ();

$enabled = 1;
$lead_seconds = 10;
$teleport_idle = 1;
$scheduler = LastROActivity::Scheduler->new(
	lead_seconds => $lead_seconds,
	clock => sub { _now() },
);

Plugins::register(
	'LastROActivity',
	'Schedules confirmed LastRO activities from server announcements',
	\&onUnload,
	\&onReload,
);

$hooks = Plugins::addHooks(
	['packet_sysMsg',          \&onSystemMessage, undef],
	['packet_pubMsg',          \&onPublicMessage, undef],
	['mainLoop_pre',           \&onMainLoopPre, undef],
	['packet_mapChange',       \&onMapChange, undef],
	['lastro_airship_result',  \&onAirshipResult, undef],
	['AI_state_change',        \&onAIStateChange, undef],
	['start3',                 \&onStart3, undef],
);

$commands = Commands::register(
	['lastroactivity', [
		'LastROActivity activity scheduling',
		['status', 'show LastRO activity state'],
		['on', 'enable LastRO activity scheduling'],
		['off', 'disable LastRO activity scheduling'],
		['run <event_id>', 'queue a LastRO activity'],
		['stop', 'stop the active LastRO activity'],
		['reload', 'reload LastRO activity rules'],
	], \&commandHandler],
);

sub _config_bool {
	my ($key, $default) = @_;
	return $default unless exists $Globals::config{$key};
	return $Globals::config{$key} =~ /^\s*1\s*\z/ ? 1 : 0
		if defined $Globals::config{$key};
	return $default;
}

sub _config_nonnegative {
	my ($key, $default) = @_;
	my $value = $Globals::config{$key};
	return $default unless defined $value && $value =~ /^\s*\d+(?:\.\d+)?\s*\z/;
	return 0 + $value;
}

sub onStart3 {
	return _initialize_from_config();
}

sub _initialize_from_config {
	return 1 if $initialized;
	$initialized = 1;

	$enabled = _config_bool('lastroActivity_enabled', 1);
	$lead_seconds = _config_nonnegative('lastroActivity_leadSeconds', 10);
	$teleport_idle = _config_nonnegative('lastroActivity_teleportIdle', 1);
	$scheduler = LastROActivity::Scheduler->new(
		lead_seconds => $lead_seconds,
		clock => sub { _now() },
	);
	_register_rule_file();
	return 1;
}

sub _trim {
	my ($value) = @_;
	$value = '' unless defined $value;
	$value =~ s/^\s+//;
	$value =~ s/\s+\z//;
	return $value;
}

sub _rules_name {
	my $configured = _trim($Globals::config{lastroActivity_rulesFile});
	return $configured ne '' ? $configured : 'lastro_activity.txt';
}

sub _plugin_folder {
	my $folder = eval { $Plugins::current_plugin_folder };
	return defined $folder && $folder ne '' ? $folder : dirname(__FILE__);
}

sub _bundled_rules_file {
	my ($name) = @_;
	return undef unless defined $name && $name eq 'lastro_activity.txt';

	my $path = File::Spec->catfile(_plugin_folder(), 'control', $name);
	return -f $path ? $path : undef;
}

sub _load_registered_rule_file {
	my ($name, $handle) = @_;
	$rules_file = undef;

	my $loaded = eval { Settings::loadByHandle($handle); 1 };
	warning "[LastROActivity] Unable to load rules file '$name': $@\n" if !$loaded && $@;
	return 1 if defined $rules_file;

	my $fallback = _bundled_rules_file($name);
	if (defined $fallback) {
		_load_rules_file($fallback);
		return 1;
	}

	$rules = {};
	return 0;
}

sub _register_rule_file {
	my $name = _rules_name();
	$rules_requested = $name;
	$rules = {};
	$rules_file = undef;

	my %options = (
		loader => [\&_load_rules_file],
		mustExist => 0,
	);
	$options{autoSearch} = 0
		if File::Spec->file_name_is_absolute($name) || $name =~ m{[\\/]};

	my $handle = eval { Settings::addControlFile($name, %options) };
	if (defined $handle && !$@) {
		$rules_file_handle = $handle;
		return _load_registered_rule_file($name, $handle);
	}

	# A stripped-down unit harness may not provide Settings.  Loading a real
	# configured path directly keeps the plugin safe in that environment.
	_load_rules_file($name) if -f $name;
	my $fallback = _bundled_rules_file($name);
	_load_rules_file($fallback) if !defined $rules_file && defined $fallback;
	return defined $rules_file ? 1 : 0;
}

sub _load_rules_file {
	my ($filename) = @_;
	return unless defined $filename && $filename ne '';

	my ($loaded, $errors) = LastROActivity::Rules::load_file($filename);
	$rules = ref($loaded) eq 'HASH' ? $loaded : {};
	$rules_file = $filename;
	$errors = [] unless ref($errors) eq 'ARRAY';
	for my $error (@$errors) {
		warning "[LastROActivity] $error\n";
	}
	return $rules;
}

sub reload_rules {
	return _initialize_from_config() unless $initialized;

	my $name = _rules_name();
	if (!defined $rules_file_handle || !defined $rules_requested || $name ne $rules_requested) {
		if (defined $rules_file_handle) {
			eval { Settings::removeFile($rules_file_handle) };
		}
		$rules_file_handle = undef;
		return _register_rule_file();
	}

	my $snapshot = $active_snapshot;
	return 0 unless _load_registered_rule_file($name, $rules_file_handle);
	# Rule reload must never rewrite a snapshot owned by an active event.
	$active_snapshot = $snapshot;
	return 1;
}

sub _now {
	my ($args) = @_;
	return $args->{now} if ref($args) eq 'HASH' && exists $args->{now};
	return $clock->() if ref($clock) eq 'CODE';
	return time;
}

sub _hook_args {
	my ($first, $second) = @_;
	return $second if ref($second) eq 'HASH';
	return $first if ref($first) eq 'HASH';
	return undef;
}

sub _message_from_args {
	my ($args) = @_;
	return undef unless ref($args) eq 'HASH';
	return $args->{Msg} if defined $args->{Msg};
	return $args->{RawMsg};
}

sub _validated_enabled_rule {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	return 0 unless defined $rule->{enabled} && $rule->{enabled} =~ /^\s*1\s*\z/;
	return 0 if ref($rule->{validation_errors}) eq 'ARRAY'
		&& @{$rule->{validation_errors}};
	return 0 if @{LastROActivity::Rules::validate_rule($rule)};
	return 0 unless defined $rule->{announce_regex} && $rule->{announce_regex} ne '';
	return 1;
}

sub _observe_message {
	my ($message, $received_at) = @_;
	return undef unless $enabled;
	return undef unless defined $message;
	$received_at = _now() unless defined $received_at;

	my $first_event;
	for my $event_id (sort keys %$rules) {
		my $rule = $rules->{$event_id};
		next unless _validated_enabled_rule($rule);
		my $event = eval {
			$scheduler->observe($rule, $message, $received_at);
		};
		if ($@) {
			warning "[LastROActivity] Could not observe '$event_id': $@\n";
			next;
		}
		next unless ref($event) eq 'HASH';
		_arm_event($event);
		$first_event ||= $event;
	}
	return $first_event;
}

sub _event_precedes {
	my ($candidate, $current) = @_;
	return 1 unless ref($current) eq 'HASH';
	return 1 if defined $candidate->{event_id}
		&& defined $current->{event_id}
		&& $candidate->{event_id} eq $current->{event_id};

	return 1 if $candidate->{start_at} < $current->{start_at};
	return 0 if $candidate->{start_at} > $current->{start_at};
	return 1 if $candidate->{priority} > $current->{priority};
	return 0 if $candidate->{priority} < $current->{priority};
	return 1 if $candidate->{event_id} lt $current->{event_id};
	return 0 if $candidate->{event_id} gt $current->{event_id};
	return $candidate->{revision} < $current->{revision};
}

sub _arm_event {
	my ($event) = @_;
	return 0 unless ref($event) eq 'HASH';
	return 0 unless ref($state) eq 'LastROActivity::State';

	if ($state->state eq 'RESUMED' || $state->state eq 'FAILED') {
		$state = LastROActivity::State->new;
		$armed_event = undef;
	}
	if ($state->state eq 'IDLE') {
		$state->transition('arm');
	}
	return 0 unless $state->state eq 'ARMED';

	$armed_event = $event if !defined $armed_event || _event_precedes($event, $armed_event);
	return 1;
}

sub onSystemMessage {
	my $args = _hook_args(@_);
	return _observe_message(_message_from_args($args));
}

sub onPublicMessage {
	my $args = _hook_args(@_);
	return _observe_message(_message_from_args($args));
}

sub _event_can_start {
	my ($event) = @_;
	return 0 unless ref($event) eq 'HASH';
	return 0 unless _validated_enabled_rule($event->{rule});
	return 0 unless defined $event->{event_id} && $event->{event_id} ne '';
	return 1;
}

sub _start_due_event {
	my ($event) = @_;
	return 0 unless _event_can_start($event);
	return 0 if defined $active_event;

	$active_event = $event;
	$armed_event = $event;
	return begin_activity($event->{rule}, $event);
}

sub onMainLoopPre {
	my $args = _hook_args(@_);
	return unless $enabled;

	my $now = _now($args);
	my $due = eval { $scheduler->due($now) };
	if ($@) {
		warning "[LastROActivity] Could not check due activities: $@\n";
		$due = [];
	}
	push @pending_due, @$due if ref($due) eq 'ARRAY';
	push @pending_due, splice(@pending_manual);

	# This is deliberately the only call site that starts a due event.  The
	# state-machine implementation is filled in by the interruption task.
	if (@pending_due && !defined $active_event) {
		my $event = shift @pending_due;
		_start_due_event($event);
	}

	_advance_state_machine_one_action();
}

sub _advance_state_machine_one_action {
	# Task 4 owns the loop boundary; later lifecycle tasks add one transition
	# here at a time.  Keeping this no-op makes early timers remain ARMED.
	return;
}

sub begin_activity {
	my ($rule, $scheduled_event) = @_;
	return 0 unless _validated_enabled_rule($rule);
	return 0 unless ref($scheduled_event) eq 'HASH';
	# This is the stable interruption boundary.  It intentionally performs no
	# AI, inventory, map, or config mutation until Task 5 supplies validation.
	return 1;
}

sub _manual_run {
	my ($event_id) = @_;
	return 0 unless defined $event_id && $event_id ne '';
	my $rule = $rules->{$event_id};
	unless (_event_can_start({event_id => $event_id, rule => $rule})) {
		error "[LastROActivity] Unknown or invalid event '$event_id'.\n";
		return 0;
	}

	my $now = _now();
	my $event = {
		event_id => $event_id,
		rule => $rule,
		message => undef,
		received_at => $now,
		countdown_seconds => 0,
		start_at => $now,
		trigger_at => $now,
		lead_seconds => 0,
		priority => 0,
		manual => 1,
	};
	_arm_event($event) or return 0;
	push @pending_manual, $event;
	return 1;
}

sub _usage {
	error "Usage: lastroactivity <status|on|off|run <event_id>|stop|reload>\n";
}

sub commandHandler {
	my (undef, $args) = @_;
	$args = '' unless defined $args;
	$args = _trim($args);
	my @parts = $args eq '' ? () : split /\s+/, $args;
	my $subcommand = lc(shift(@parts) || 'status');

	if ($subcommand eq 'status' && !@parts) {
		my $armed = $armed_event && $armed_event->{event_id};
		my $trigger = $armed_event && $armed_event->{trigger_at};
		$armed = 'none' unless defined $armed && $armed ne '';
		$trigger = 'none' unless defined $trigger;
		my $failure = defined $last_failure && $last_failure ne '' ? $last_failure : 'none';
		message sprintf(
			"[LastROActivity] state=%s armed=%s trigger=%s last_failure=%s\n",
			state(), $armed, $trigger, $failure,
		);
		return 1;
	}

	if (($subcommand eq 'on' || $subcommand eq 'off') && !@parts) {
		$enabled = $subcommand eq 'on' ? 1 : 0;
		message "[LastROActivity] scheduling " . ($enabled ? 'enabled' : 'disabled') . ".\n";
		return 1;
	}

	if ($subcommand eq 'run' && @parts == 1) {
		return _manual_run($parts[0]);
	}

	if ($subcommand eq 'stop' && !@parts) {
		return cleanup_and_restore('manual stop');
	}

	if ($subcommand eq 'reload' && !@parts) {
		return reload_rules();
	}

	_usage();
	return 0;
}

sub commandLastROActivity {
	return commandHandler(@_);
}

sub cleanup_and_restore {
	my ($reason) = @_;
	if (defined $armed_event && defined $armed_event->{event_id}) {
		eval { $scheduler->cancel($armed_event->{event_id}) };
	}
	@pending_due = ();
	@pending_manual = ();
	$active_event = undef;
	$armed_event = undef;
	$state = LastROActivity::State->new;
	return 1;
}

sub onMapChange {
	return;
}

sub onAirshipResult {
	return;
}

sub onAIStateChange {
	return;
}

sub onReload {
	onUnload();
}

sub onUnload {
	if (defined $rules_file_handle) {
		eval { Settings::removeFile($rules_file_handle) };
		$rules_file_handle = undef;
	}
	eval { Commands::unregister($commands) } if defined $commands;
	eval { Plugins::delHooks($hooks) } if defined $hooks;
	$active_event = undef;
	$armed_event = undef;
	$active_snapshot = undef;
	return 1;
}

sub enabled { return $enabled ? 1 : 0; }
sub lead_seconds { return $lead_seconds; }
sub teleport_idle { return $teleport_idle; }
sub state { return $state->state; }
sub scheduler { return $scheduler; }
sub rules { return $rules; }
sub active_event { return $active_event; }
sub armed_event { return $armed_event; }
sub last_failure { return $last_failure; }
sub rules_file { return $rules_file || $rules_requested; }

1;
