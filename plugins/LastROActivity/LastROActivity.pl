package LastROActivity;

use strict;
use warnings;
use utf8;

use Time::HiRes qw(time);
use File::Basename qw(dirname);
use File::Spec;
use Scalar::Util ();

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
our $init_failure_signature;
our $rule_load_context;
our ($active_event, $armed_event, $last_failure, $active_snapshot, $activity_lock);
our (@pending_due, @pending_manual);
our ($hooks, $commands, $rules_preload_hook);
our $macro_error_hook;
our ($pending_destination, $pending_destination_kind, $pending_destination_deadline);
our ($pending_airship_result, $pending_macro, $pending_macro_stage);
our ($pending_macro_seen, $pending_macro_deadline, $pending_macro_error);
our $pending_macro_root_name;
our $pending_leave_npc;
our $return_pending;
our $entry_map_confirmed;
our $entry_transfer_accepted;
our ($activity_started_at, $activity_entry_started_at);
our ($activity_phase_index, $activity_phase_started_at);
our ($activity_round_count, $activity_round_started_at);
our $activity_self_dead_at;
our $airship_failure_count;
our $cleanup_in_progress;
our $clock = sub { time };

$rules = {};
$rules_file = undef;
$rules_requested = undef;
$rules_file_handle = undef;
$initialized = 0;
$init_failure_signature = undef;
$rule_load_context = undef;
$state = LastROActivity::State->new;
$last_failure = undef;
$active_event = undef;
$armed_event = undef;
$active_snapshot = undef;
$activity_lock = 0;
@pending_due = ();
@pending_manual = ();
$pending_destination = undef;
$pending_destination_kind = undef;
$pending_destination_deadline = undef;
$pending_airship_result = undef;
$pending_macro = undef;
$pending_macro_stage = undef;
$pending_macro_seen = 0;
$pending_macro_deadline = undef;
$pending_macro_error = undef;
$pending_macro_root_name = undef;
$pending_leave_npc = undef;
$return_pending = 0;
$entry_map_confirmed = 0;
$entry_transfer_accepted = 0;
$activity_started_at = undef;
$activity_entry_started_at = undef;
$activity_phase_index = undef;
$activity_phase_started_at = undef;
$activity_round_count = 0;
$activity_round_started_at = undef;
$activity_self_dead_at = undef;
$airship_failure_count = 0;
$cleanup_in_progress = 0;

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
$rules_preload_hook = Plugins::addHook(
	'pre_load_lastro_activity_rules',
	\&onRulesPreLoad,
	undef,
) if defined &Plugins::addHook;
$macro_error_hook = Plugins::addHook(
	'macro/error',
	\&onMacroError,
	undef,
) if defined &Plugins::addHook;

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
	return _initialize_from_config(1);
}

sub _config_ready {
	# An empty config hash is the observable state while OpenKore is still
	# loading its control files.  Runtime hooks must wait for start3 or a
	# populated config rather than freezing defaults too early.
	return scalar(keys %Globals::config) > 0;
}

sub _config_signature {
	my @keys = qw(
		lastroActivity_enabled
		lastroActivity_rulesFile
		lastroActivity_leadSeconds
		lastroActivity_teleportIdle
	);
	return join "\x1E", map {
		my $encoded;
		if (!exists $Globals::config{$_}) {
			$encoded = "M$_";
		} elsif (!defined $Globals::config{$_}) {
			$encoded = "U$_";
		} else {
			my $value = "$Globals::config{$_}";
			$encoded = "D$_:" . length($value) . ":$value";
		}
		$encoded;
	} @keys;
}

sub _ensure_initialized {
	my ($force) = @_;
	return 1 if $initialized;
	return 0 if !$force && !_config_ready();
	my $signature = _config_signature();
	return 0 if !$force
		&& defined $init_failure_signature
		&& $init_failure_signature eq $signature;
	return _initialize_from_config($force);
}

sub _initialize_from_config {
	my ($force) = @_;
	return 1 if $initialized;
	return 0 if !$force && !_config_ready();

	$enabled = _config_bool('lastroActivity_enabled', 1);
	$lead_seconds = _config_nonnegative('lastroActivity_leadSeconds', 10);
	$teleport_idle = _config_nonnegative('lastroActivity_teleportIdle', 1);
	$scheduler = LastROActivity::Scheduler->new(
		lead_seconds => $lead_seconds,
		clock => sub { _now() },
	);
	my $loaded = _register_rule_file();
	if (!$loaded) {
		# A failed first load must remain retryable.  Remove a handle that was
		# registered for the failed attempt so the next attempt cannot leak a
		# duplicate Settings entry.
		_remove_rule_handle($rules_file_handle);
		$rules_file_handle = undef;
		$initialized = 0;
		$init_failure_signature = _config_signature();
		return 0;
	}
	$initialized = 1;
	$init_failure_signature = undef;
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

sub _resolved_rules_path {
	my ($name) = @_;
	return undef unless defined $name && $name ne '';
	if ($name =~ m{[\\/]}) {
		return -f $name ? $name : undef;
	}
	if (defined &Settings::getControlFilename) {
		my $resolved = eval { Settings::getControlFilename($name) };
		return $resolved if defined $resolved && -f $resolved;
		return undef;
	}
	return -f $name ? $name : undef;
}

sub onRulesPreLoad {
	my ($hook_name, $args) = @_;
	return 1 unless ref($args) eq 'HASH';
	my $name = $rules_requested;
	return 1 unless defined $name && $name ne '';

	# Settings skips optional files without invoking their loader.  Resolve the
	# same path here so a generic `reload all` cannot leave stale rules/timers.
	return 1 if defined _resolved_rules_path($name);
	my $fallback = _bundled_rules_file($name);
	if (defined $fallback) {
		$args->{filename} = $fallback;
		$args->{return} = 1;
		return 1;
	}

	_fail_closed_rules("unable to load rules file '$name'");
	$args->{return} = 1;
	return 1;
}

sub _clear_scheduled_events {
	my $ok = 1;
	if (ref($scheduler) && $scheduler->can('clear')) {
		my $cleared = eval { $scheduler->clear(); 1 };
		unless ($cleared) {
			$ok = 0;
			warning "[LastROActivity] Unable to clear scheduled activities: $@\n";
		}
	}
	@pending_due = ();
	@pending_manual = ();
	$armed_event = undef;
	$state = LastROActivity::State->new unless defined $active_event;
	return $ok;
}

sub _disable_scheduling {
	$enabled = 0;
	my $ok = _clear_scheduled_events();
	if (defined $active_event) {
		my ($stopped, $error);
		my $stop_eval = eval {
			$stopped = _stop_active_activity('scheduling disabled');
			1;
		};
		unless ($stop_eval) {
			$error = _trim($@ || 'active activity stop failed');
			_record_cleanup_failure($error);
			$ok = 0;
		}
		$ok = 0 if $stop_eval && defined $stopped && !$stopped;
	}
	# A stop/return callback can enqueue work while it is unwinding.  Clear only
	# scheduler-owned future work once more, without touching an active return
	# handshake or its lifecycle state.
	$ok = 0 unless _clear_scheduled_events();
	return $ok;
}

sub _fail_closed_rules {
	my ($reason) = @_;
	$rules = {};
	$rules_file = undef;
	_clear_scheduled_events();
	$last_failure = _trim($reason) if defined $reason && _trim($reason) ne '';
	return 0;
}

sub _remove_rule_handle {
	my ($handle) = @_;
	return 1 unless defined $handle && defined &Settings::removeFile;
	my $ok = eval {
		Settings::removeFile($handle);
		1;
	};
	if (!$ok) {
		warning "[LastROActivity] Unable to remove rules file handle: $@\n";
		return 0;
	}
	return 1;
}

sub _load_candidate_file {
	my ($filename) = @_;
	return (0, undef, undef) unless defined $filename && $filename ne '' && -f $filename;

	my $context = {};
	my $ok = eval {
		local $rule_load_context = $context;
		_load_rules_file($filename);
		1;
	};
	if (!$ok) {
		my $exception = $@ || 'unknown loader exception';
		warning "[LastROActivity] Unable to load rules file '$filename': $exception\n";
		return (0, undef, undef);
	}
	return (0, undef, undef) unless $context->{loaded};
	return (1, $context->{rules}, $context->{file});
}

sub _load_registered_rule_file {
	my ($name, $handle) = @_;
	my $context = {};
	my $loaded = eval {
		local $rule_load_context = $context;
		Settings::loadByHandle($handle);
		1;
	};
	if (!$loaded) {
		my $exception = $@ || 'unknown loader exception';
		warning "[LastROActivity] Unable to reload rules file '$name': $exception\n";
		return (0, undef, undef);
	}
	return (1, $context->{rules}, $context->{file}) if $context->{loaded};
	return (0, undef, undef) if $context->{failed};

	my $fallback = _bundled_rules_file($name);
	return _load_candidate_file($fallback) if defined $fallback;
	return (0, undef, undef);
}

sub _register_rule_file {
	my $name = _rules_name();
	my $old_handle = $rules_file_handle;
	my $old_name = $rules_requested;
	if (defined $old_handle && (!defined $old_name || $old_name ne $name)) {
		_remove_rule_handle($old_handle);
		$rules_file_handle = undef;
		$old_handle = undef;
	}
	$rules_requested = $name;

	my %options = (
		loader => [\&_load_rules_file],
		mustExist => 0,
		internalName => 'lastro_activity_rules',
	);
	$options{autoSearch} = 0
		if File::Spec->file_name_is_absolute($name) || $name =~ m{[\\/]};

	my ($handle, $add_error);
	if (defined &Settings::addControlFile) {
		my $added = eval {
			$handle = Settings::addControlFile($name, %options);
			1;
		};
		$add_error = $@ unless $added;
	}
	if (defined $add_error && $add_error ne '') {
		warning "[LastROActivity] Unable to register rules file '$name': $add_error\n";
		$rules_file_handle = undef;
		return _fail_closed_rules($add_error);
	}
	if (defined $handle) {
		$rules_file_handle = $handle;
		my ($ok, $candidate, $resolved) = _load_registered_rule_file($name, $handle);
		return _commit_rules($candidate, $resolved) if $ok;
		return _fail_closed_rules("unable to load rules file '$name'");
	}

	# A stripped-down unit harness may not provide Settings.  Loading a real
	# configured path directly keeps the plugin safe in that environment.
	my ($ok, $candidate, $resolved) = _load_candidate_file($name);
	if (!$ok && !-f $name) {
		my $fallback = _bundled_rules_file($name);
		($ok, $candidate, $resolved) = _load_candidate_file($fallback) if defined $fallback;
	}
	return _commit_rules($candidate, $resolved) if $ok;
	return _fail_closed_rules("unable to load rules file '$name'");
}

sub _load_rules_file {
	my ($filename) = @_;
	return unless defined $filename && $filename ne '';

	my ($loaded, $errors);
	my $ok = eval {
		($loaded, $errors) = LastROActivity::Rules::load_file($filename);
		1;
	};
	if (!$ok) {
		my $exception = $@ || 'unknown parser exception';
		warning "[LastROActivity] Rules loader failed for '$filename': $exception\n";
		if (ref($rule_load_context) eq 'HASH') {
			$rule_load_context->{failed} = $exception;
		} else {
			_fail_closed_rules($exception);
		}
		return;
	}
	my $candidate = ref($loaded) eq 'HASH' ? $loaded : {};
	$errors = [] unless ref($errors) eq 'ARRAY';
	for my $error (@$errors) {
		warning "[LastROActivity] $error\n";
	}
	if (ref($rule_load_context) eq 'HASH') {
		$rule_load_context->{loaded} = 1;
		$rule_load_context->{rules} = $candidate;
		$rule_load_context->{file} = $filename;
		$rule_load_context->{errors} = $errors;
	} else {
		$rules = $candidate;
		$rules_file = $filename;
		_reconcile_scheduled_events($candidate) if $initialized;
	}
	return $candidate;
}

sub _commit_rules {
	my ($candidate, $resolved) = @_;
	return 0 unless ref($candidate) eq 'HASH' && defined $resolved;
	# Validate lifecycle completion evidence as soon as a candidate is loaded so
	# malformed enabled rules cannot sit armed until their first announcement.
	for my $rule (values %$candidate) {
		_next_rule_validation($rule);
	}
	$rules = $candidate;
	$rules_file = $resolved;
	my $reconciled = eval {
		_reconcile_scheduled_events($candidate);
		1;
	};
	if (!$reconciled) {
		my $exception = $@ || 'unknown scheduler reconciliation failure';
		warning "[LastROActivity] Unable to reconcile scheduled activities: $exception\n";
		return _fail_closed_rules($exception);
	}
	$last_failure = undef;
	return 1;
}

sub _next_rule_validation {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	return 1 unless defined $rule->{enabled}
		&& "$rule->{enabled}" =~ /^\s*1\s*\z/;
	return _validated_enabled_rule($rule) ? 1 : 0;
}

sub _reconcile_scheduled_events {
	my ($candidate) = @_;
	my %survivors;

	if (ref($scheduler) && $scheduler->can('events')) {
		my $events = eval { $scheduler->events() };
		if (ref($events) eq 'HASH') {
			for my $event_id (keys %$events) {
				my $event = $events->{$event_id};
				my $rule = $candidate->{$event_id};
				if (!_validated_enabled_rule($rule)) {
					eval { $scheduler->cancel($event_id) };
					next;
				}
				$event->{rule} = $rule if ref($event) eq 'HASH';
				$survivors{$event_id} = $event;
			}
		}
	}

	my $filter_queue = sub {
		my ($queue) = @_;
		my @kept;
		for my $event (@$queue) {
			next unless ref($event) eq 'HASH';
			my $rule = $candidate->{$event->{event_id}};
			next unless _validated_enabled_rule($rule);
			$event->{rule} = $rule;
			push @kept, $event;
		}
		@$queue = @kept;
	};
	$filter_queue->(\@pending_due);
	$filter_queue->(\@pending_manual);

	# Keep status aligned with the earliest/highest-priority not-yet-dispatched
	# candidate.  Active lifecycle state is owned by later tasks and is left
	# untouched while its event is running.
	my $winner;
	for my $event (values %survivors, @pending_due, @pending_manual) {
		next unless ref($event) eq 'HASH';
		next if $event->{dispatched};
		$winner = $event if !defined $winner || _event_precedes($event, $winner);
	}
	if (defined $active_event) {
		if (defined $armed_event && defined $active_event->{event_id}
			&& defined $armed_event->{event_id}
			&& $armed_event->{event_id} eq $active_event->{event_id}) {
			return 1;
		}
		$armed_event = $winner if defined $winner;
		return 1;
	}

	$armed_event = $winner;
	if (defined $armed_event) {
		if ($state->state eq 'IDLE') {
			eval { $state->transition('arm') };
		}
	} elsif ($state->state eq 'ARMED') {
		$state = LastROActivity::State->new;
	}
	return 1;
}

sub reload_rules {
	$init_failure_signature = undef unless $initialized;
	return 0 unless _ensure_initialized();

	my $name = _rules_name();
	if (!defined $rules_file_handle || !defined $rules_requested || $name ne $rules_requested) {
		_remove_rule_handle($rules_file_handle);
		$rules_file_handle = undef;
		return _register_rule_file();
	}

	my $snapshot = $active_snapshot;
	my ($ok, $candidate, $resolved) = _load_registered_rule_file($name, $rules_file_handle);
	return _fail_closed_rules("unable to reload rules file '$name'") unless $ok;
	return 0 unless _commit_rules($candidate, $resolved);
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
	my $rule_errors = LastROActivity::Rules::validate_rule($rule);
	if (ref($rule_errors) eq 'ARRAY' && @$rule_errors) {
		_append_rule_validation_error($rule, $_) for @$rule_errors;
		return 0;
	}
	my ($return_ok) = _validate_return_policy($rule);
	return 0 unless $return_ok;
	return 0 unless defined $rule->{announce_regex} && $rule->{announce_regex} ne '';
	# Resolve declared shared-search targets before scheduling.  Minimal scheduler
	# fixtures omit the entry_type key and intentionally do not load
	# Globals::mon_control; those retain their parser-compatible legacy behavior
	# and are checked at entry time.  Parser-created rules always materialize the
	# key (including an undef value), so an omitted configured type still uses the
	# privateairship default and is preflighted here.
	if (_runtime_search_validation_available($rule)) {
		my ($search_ok) = _validate_search_targets($rule);
		return 0 unless $search_ok;
	}
	my ($completion_ok) = _validate_completion_policy($rule);
	return 0 unless $completion_ok;
	if (_leave_npc_configured($rule)) {
		my ($leave_ok, $leave_reason) = _validate_leave_npc($rule);
		unless ($leave_ok) {
			_append_rule_validation_error($rule, $leave_reason);
			return 0;
		}
	}
	return 1;
}

sub _runtime_search_validation_available {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	return 1 if $rule->{search_mode} || $rule->{shared_search};
	# Non-search entry routes do not need shared monster-control resolution.
	# Scheduler-only parser fixtures use an explicit synthetic macro route so
	# their timing assertions stay independent of the live control table.
	if (exists $rule->{entry_type}) {
		my $entry_type = lc(_trim($rule->{entry_type}));
		return 0 if $entry_type eq 'npc' || $entry_type eq 'macro';
		# Rules parsed through LastROActivity::Rules always materialize this key,
		# including undef/empty values.  Those values default to privateairship and
		# therefore require shared-search preflight before scheduling.
		return 1;
	}
	# A parser-origin rule from a future/alternate parser may omit entry_type but
	# still carries validation_errors.  Keep that production route fail-closed.
	return 1 if exists $rule->{validation_errors};
	# Direct scheduler projections omit parser metadata and entry_type.  They must
	# opt into the legacy scheduler-only behavior explicitly; an unmarked direct
	# search hash defaults to privateairship and is preflighted fail-closed.
	return 0 if defined $rule->{scheduler_only}
		&& "$rule->{scheduler_only}" =~ /^\s*1\s*\z/;
	return 1;
}

sub _observe_message {
	my ($message, $received_at) = @_;
	return undef unless $enabled;
	return undef unless defined $message;
	# The active lifecycle owns the event mutex.  Finish/phase handling is done
	# by onActivityMessage; never arm or replace timers while it is running.
	return undef if defined $active_event;
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

sub _message_matches {
	my ($message, $pattern) = @_;
	return 0 unless defined $message && defined $pattern && $pattern ne '';
	my $matched = eval {
		ref($pattern) eq 'Regexp' ? $message =~ $pattern : $message =~ /$pattern/;
	};
	return (!$@ && $matched) ? 1 : 0;
}

sub _compile_activity_pattern {
	my ($pattern, $label) = @_;
	$label = 'activity pattern' unless defined $label && $label ne '';
	return (undef, "$label is required") unless defined $pattern;
	if (ref($pattern) eq 'CODE') {
		return ($pattern, undef);
	}
	if (ref($pattern) eq 'Regexp') {
		return ($pattern, undef);
	}
	return (undef, "$label must be a scalar, regexp, or code reference") if ref($pattern);
	my $text = _trim($pattern);
	return (undef, "$label is empty") if $text eq '';
	return (undef, "$label contains a line break") if $text =~ /[\r\n]/;
	my $compiled;
	my $ok = eval {
		$compiled = qr/$text/;
		1;
	};
	return (undef, "invalid $label '$text'") unless $ok;
	return ($compiled, undef);
}

sub _activity_pattern_matches {
	my ($message, $pattern) = @_;
	return 0 unless defined $message && defined $pattern;
	if (ref($pattern) eq 'CODE') {
		my $matched = eval { $pattern->($message) };
		return (!$@ && $matched) ? 1 : 0;
	}
	my ($compiled) = _compile_activity_pattern($pattern);
	return 0 unless defined $compiled;
	# Finish and phase announcements are whole messages by default.  A rule can
	# still use normal regexp operators (for example `DONE.*`) when it needs a
	# variable suffix; there is no metacharacter heuristic or implicit substring
	# matching.
	my $candidate = _trim($message);
	my $matched = eval { $candidate =~ /\A(?:$compiled)\z/ };
	return (!$@ && $matched) ? 1 : 0;
}

sub _phase_pattern {
	my ($phase) = @_;
	return undef unless ref($phase) eq 'HASH';
	for my $key (qw(finish_regex condition_regex phase_regex message_regex regex complete_regex condition finish)) {
		return $phase->{$key}
			if defined $phase->{$key} && _trim($phase->{$key}) ne '';
	}
	return undef;
}

sub _phase_label {
	my ($phase, $index) = @_;
	return _trim($phase->{name}) if ref($phase) eq 'HASH'
		&& defined $phase->{name} && _trim($phase->{name}) ne '';
	return "phase " . (defined $index ? $index + 1 : 1);
}

sub _phase_list {
	return () unless defined $active_event && ref($active_event->{rule}) eq 'HASH';
	my $phases = $active_event->{rule}{phases};
	return @$phases if ref($phases) eq 'ARRAY';
	return ();
}

sub _set_running_state {
	my ($now) = @_;
	return 0 unless defined $active_event;
	return 1 if ref($state) eq 'LastROActivity::State' && $state->state eq 'RUNNING';
	return 0 unless ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'ENTERING';
	$now = _now() unless defined $now;
	return 0 unless _confirm_entry_map_for_running();
	return 0 unless _transition_state('running');
	$activity_started_at = $now;
	$activity_entry_started_at = undef;
	$activity_round_count = 0;
	$activity_round_started_at = undef;
	$active_event->{round_count} = 0 if ref($active_event) eq 'HASH';
	$active_event->{round} = 0 if ref($active_event) eq 'HASH';
	$active_event->{round_started} = 0 if ref($active_event) eq 'HASH';
	$active_event->{round_success_seen} = 0 if ref($active_event) eq 'HASH';
	$active_event->{round_start_message} = undef if ref($active_event) eq 'HASH';
	$active_event->{round_start_at} = undef if ref($active_event) eq 'HASH';
	$active_event->{round_identity} = undef if ref($active_event) eq 'HASH';
	$active_event->{round_identities_seen} = {} if ref($active_event) eq 'HASH';
	$active_event->{round_identity_unknown_completed} = 0
		if ref($active_event) eq 'HASH';
	my @phases = _phase_list();
	if (@phases) {
		$activity_phase_index = 0;
		$activity_phase_started_at = $now;
		$active_event->{phase_index} = 0;
		$active_event->{phase} = _phase_label($phases[0], 0);
	} else {
		$activity_phase_index = undef;
		$activity_phase_started_at = undef;
		delete $active_event->{phase_index};
		delete $active_event->{phase};
	}
	return 1;
}

sub _check_finish_message {
	my ($message) = @_;
	return defined onActivityMessage($message) ? 1 : 0;
}

sub _round_mode {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	return 0 unless exists $rule->{round_success_regex}
		&& defined $rule->{round_success_regex}
		&& _trim($rule->{round_success_regex}) ne '';
	return 1;
}

sub _max_rounds {
	my ($rule) = @_;
	return 3 unless ref($rule) eq 'HASH';
	my $value = $rule->{max_rounds};
	return 3 unless defined $value && "$value" =~ /^\s*\d+\s*\z/ && $value > 0;
	return 0 + $value;
}

sub _canonical_round_identity {
	my ($identity) = @_;
	return undef unless defined $identity && !ref($identity);
	$identity = _trim($identity);
	return undef if $identity eq '' || $identity =~ /[\r\n]/;
	$identity =~ s/\s+/ /g;
	if ($identity =~ /^[-+]?\d+\z/) {
		$identity = 0 + $identity;
	}
	return lc($identity);
}

sub _regex_round_identity {
	my ($message, $pattern, $allow_full_match, $allow_code_result) = @_;
	return undef unless defined $message && defined $pattern;
	if (ref($pattern) eq 'CODE') {
		return undef unless $allow_code_result;
		my $identity = eval { $pattern->($message) };
		return _canonical_round_identity($identity)
			if !$@ && defined $identity && !ref($identity) && "$identity" ne '';
		return undef;
	}
	my ($compiled) = _compile_activity_pattern($pattern, 'round identity pattern');
	return undef unless defined $compiled;
	my ($matched, @captures);
	my $ok = eval {
		$matched = $message =~ $compiled;
		if ($matched) {
			for my $index (1 .. $#-) {
				next unless defined $-[$index] && defined $+[$index]
					&& $-[$index] >= 0 && $+[$index] >= $-[$index];
				push @captures, substr($message, $-[$index], $+[$index] - $-[$index]);
			}
		}
		1;
	};
	return undef unless $ok && $matched;
	for my $capture (@captures) {
		my $identity = _canonical_round_identity($capture);
		return $identity if defined $identity;
	}
	return $allow_full_match ? _canonical_round_identity($&) : undef;
}

sub _round_identity {
	my ($message, $rule) = @_;
	return undef unless defined $message && ref($rule) eq 'HASH';

	# A rule may provide a dedicated extractor when the server embeds a stable
	# token that is not part of the start pattern. Captures from the start regex
	# are the next strongest source of identity.
	for my $field (qw(round_id_regex round_identity_regex)) {
		if (exists $rule->{$field} && defined $rule->{$field}
			&& (!ref($rule->{$field}) && _trim($rule->{$field}) ne '' || ref($rule->{$field}))) {
			my $identity = _regex_round_identity($message, $rule->{$field}, 1, 1);
			return $identity if defined $identity;
		}
	}
	my $identity = _regex_round_identity($message, $rule->{round_start_regex}, 0, 0);
	return $identity if defined $identity;

	# Common human-readable round announcements carry an ordinal directly. Do
	# not treat an arbitrary timestamp or changing prose as a round identity.
	my $candidate = _trim($message);
	if ($candidate =~ /\b(round|rnd|stage|wave)\s*(?:number\s*)?(?:[#:=\-]\s*)?(\d+)\b/i) {
		return _canonical_round_identity(lc($1) . ':' . $2);
	}
	if ($candidate =~ /(?:\A|\s)第\s*(\d+)\s*(?:轮|回|階段|阶段)(?:\z|\s)/u) {
		return _canonical_round_identity('round:' . $1);
	}
	if ($candidate =~ /\b(?:round|stage|wave)\s*(?:id|seq(?:uence)?)\s*[:=#-]\s*([A-Za-z0-9_.-]+)/i) {
		return _canonical_round_identity('id:' . $1);
	}
	return undef;
}

sub _resurrection_wait_seconds {
	my ($rule) = @_;
	return 30 unless ref($rule) eq 'HASH';
	my $value = $rule->{resurrection_wait_seconds};
	return 30 unless defined $value && "$value" =~ /^\s*\d+\s*\z/ && $value > 0;
	return 0 + $value;
}

sub onActivityMessage {
	my ($message) = @_;
	return undef unless defined $message;
	return undef unless defined $active_event && ref($active_event->{rule}) eq 'HASH';
	return undef unless ref($state) eq 'LastROActivity::State';
	return undef unless $state->state eq 'RUNNING';

	my $rule = $active_event->{rule};
	if (_round_mode($rule)) {
		my $round_start = $rule->{round_start_regex};
		if (defined $round_start && _trim($round_start) ne ''
			&& _activity_pattern_matches($message, $round_start)) {
			my $now = _now();
			if ($active_event->{round_started}) {
				return 'round_start_duplicate';
			}
			my $identity = _round_identity($message, $rule);
			my $seen = $active_event->{round_identities_seen};
			$seen = {} unless ref($seen) eq 'HASH';
			if (defined $identity && $seen->{$identity}) {
				return 'round_start_duplicate';
			}
			# Once an unidentifiable round has completed, another unidentifiable
			# start cannot be proven new. Fail closed instead of using a time window
			# that would eventually admit a delayed replay.
			if (!defined $identity && ($active_event->{round_identity_unknown_completed}
				|| keys %$seen)) {
				return 'round_start_duplicate';
			}
			$activity_round_started_at = $now;
			$active_event->{round_started} = 1;
			$active_event->{round_started_at} = $activity_round_started_at;
			$active_event->{round_start_message} = $message;
			$active_event->{round_start_at} = $activity_round_started_at;
			$active_event->{round_identity} = $identity;
			$active_event->{round_success_seen} = 0;
			return 'round_start';
		}

		if (_activity_pattern_matches($message, $rule->{round_success_regex})) {
			return undef unless $active_event->{round_started};
			return undef if $active_event->{round_success_seen};
			$activity_round_count = 0 unless defined $activity_round_count;
			$activity_round_count++;
			$active_event->{round_count} = $activity_round_count;
			$active_event->{round} = $activity_round_count;
			$active_event->{round_started} = 0;
			$active_event->{round_success_seen} = 1;
			if (defined $active_event->{round_identity}) {
				$active_event->{round_identities_seen} = {}
					unless ref($active_event->{round_identities_seen}) eq 'HASH';
				$active_event->{round_identities_seen}
					{$active_event->{round_identity}} = 1;
			} else {
				$active_event->{round_identity_unknown_completed} = 1;
			}
			if ($activity_round_count >= _max_rounds($rule)) {
				_complete_round_limit('maximum dojo rounds completed');
				return 'finish';
			}
			return 'round';
		}
	}

	# Finish matching is deliberately scoped to the active rule.  Do not scan
	# every configured rule here: another event's announcement must not end the
	# activity currently holding the mutex.
	my $finish_pattern = $rule->{finish_regex};
	if (_activity_pattern_matches($message, $finish_pattern)) {
		finish_activity('finish announcement matched');
		return 'finish';
	}

	my @phases = _phase_list();
	if (@phases) {
		# A phased monster activity advances only from its current phase condition;
		# an out-of-order phase announcement is ignored.
		my $index = defined $activity_phase_index ? $activity_phase_index : 0;
		return undef if $index < 0 || $index > $#phases;
		my $pattern = _phase_pattern($phases[$index]);
		return undef unless _activity_pattern_matches($message, $pattern);

		my $label = _phase_label($phases[$index], $index);
		if ($index < $#phases) {
			$activity_phase_index = $index + 1;
			$activity_phase_started_at = _now();
			$active_event->{phase_index} = $activity_phase_index;
			$active_event->{phase} = _phase_label($phases[$activity_phase_index], $activity_phase_index);
			return 'phase';
		}

		finish_activity("$label completed");
		return 'finish';
	}

	return undef;
}

sub _positive_number {
	my ($value) = @_;
	return undef unless defined $value && "$value" =~ /^\s*\d+(?:\.\d+)?\s*\z/;
	return 0 + $value if $value > 0;
	return undef;
}

sub checkActivityTimeout {
	my ($now) = @_;
	$now = _now() unless defined $now;
	return undef unless defined $active_event && ref($active_event->{rule}) eq 'HASH';
	return undef unless ref($state) eq 'LastROActivity::State';
	my $state_name = $state->state;
	return undef if $state_name eq 'IDLE' || $state_name eq 'RESUMED';

	my $rule = $active_event->{rule};
	if (defined $pending_destination
		&& ($pending_destination_kind || '') eq 'return'
		&& defined $pending_destination_deadline
		&& $now >= $pending_destination_deadline) {
		_mark_activity_failed('return to prontera timed out')
			if $state_name ne 'FAILED';
		# A timeout is a failed observation, not proof of arrival. Keep the return
		# marker and snapshot alive until packet_mapChange confirms prontera.
		$pending_destination_deadline = undef;
		return 'fail';
	}
	if ($state_name ne 'RUNNING'
		&& $state_name ne 'FINISHING'
		&& $state_name ne 'RETURNING'
		&& $state_name ne 'FAILED') {
		my $deadline;
		my $reason = 'activity entry timed out';
		if (defined $pending_destination_deadline) {
			$deadline = $pending_destination_deadline;
			$reason = 'Private Airship entry timed out';
		} elsif (defined $pending_macro_deadline) {
			$deadline = $pending_macro_deadline;
			$reason = "macro '$pending_macro' timed out" if defined $pending_macro;
		} elsif (defined $activity_entry_started_at) {
			$deadline = $activity_entry_started_at + _transfer_timeout($rule);
		}
		if (defined $deadline && $now >= $deadline) {
			_mark_activity_failed($reason);
			return 'fail';
		}
		return undef;
	}
	return undef unless $state_name eq 'RUNNING';

	my @phases = _phase_list();
	if (@phases) {
		my $index = defined $activity_phase_index ? $activity_phase_index : 0;
		my $phase = $phases[$index];
		my $timeout = _positive_number($phase->{timeout_seconds})
			if ref($phase) eq 'HASH';
		my $started = $activity_phase_started_at;
		$started = $activity_started_at unless defined $started;
		if (defined $timeout && defined $started && $now >= $started + $timeout) {
			finish_activity(_phase_label($phase, $index) . ' timeout');
			return 'finish';
		}
	}

	my $duration = _positive_number($rule->{duration_seconds});
	if (defined $duration && defined $activity_started_at
		&& $now >= $activity_started_at + $duration) {
		finish_activity('activity duration expired');
		return 'finish';
	}
	return undef;
}

sub _event_precedes {
	my ($candidate, $current) = @_;
	return 1 unless ref($current) eq 'HASH';
	return 0 unless ref($candidate) eq 'HASH';
	return 1 if defined $candidate->{event_id}
		&& defined $current->{event_id}
		&& $candidate->{event_id} eq $current->{event_id};

	my $candidate_start = defined $candidate->{start_at} ? $candidate->{start_at} : 0;
	my $current_start = defined $current->{start_at} ? $current->{start_at} : 0;
	return 1 if $candidate_start < $current_start;
	return 0 if $candidate_start > $current_start;
	my $candidate_priority = defined $candidate->{priority} ? $candidate->{priority} : 0;
	my $current_priority = defined $current->{priority} ? $current->{priority} : 0;
	return 1 if $candidate_priority > $current_priority;
	return 0 if $candidate_priority < $current_priority;
	my $candidate_id = defined $candidate->{event_id} ? $candidate->{event_id} : '';
	my $current_id = defined $current->{event_id} ? $current->{event_id} : '';
	return 1 if $candidate_id lt $current_id;
	return 0 if $candidate_id gt $current_id;
	my $candidate_revision = defined $candidate->{revision} ? $candidate->{revision} : 0;
	my $current_revision = defined $current->{revision} ? $current->{revision} : 0;
	return $candidate_revision < $current_revision;
}

sub _arm_event {
	my ($event) = @_;
	return 0 unless ref($event) eq 'HASH';
	return 0 unless ref($state) eq 'LastROActivity::State';
	# An active lifecycle owns the single activity slot.  Keep scheduler
	# observations available for later reconciliation, but never let a new
	# announcement reset the state machine while this event is returning.
	return 0 if defined $active_event;

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
	return undef unless _ensure_initialized();
	my $message = _message_from_args($args);
	my $had_active = defined $active_event;
	my $activity_result = onActivityMessage($message);
	return $activity_result if $had_active;
	return _observe_message($message);
}

sub onPublicMessage {
	my $args = _hook_args(@_);
	return undef unless _ensure_initialized();
	my $message = _message_from_args($args);
	my $had_active = defined $active_event;
	my $activity_result = onActivityMessage($message);
	return $activity_result if $had_active;
	return _observe_message($message);
}

sub _event_can_start {
	my ($event) = @_;
	return 0 unless ref($event) eq 'HASH';
	return 0 unless _validated_enabled_rule($event->{rule});
	return 0 unless defined $event->{event_id} && $event->{event_id} ne '';
	return 1;
}

sub _event_map {
	my ($rule, $event) = @_;
	return undef unless ref($rule) eq 'HASH';

	my $source = lc(_trim($rule->{map_source}));
	# An explicitly supplied source is a contract, not an arbitrary label.  Do
	# not silently treat a typo as a fixed-map rule.
	return undef if $source ne ''
		&& $source ne 'static'
		&& $source ne 'dynamic'
		&& $source ne 'announcement';

	my $map;
	if ($source eq 'dynamic') {
		# A dynamic rule must be backed by map metadata from the matching
		# announcement; silently falling back to a stale configured map would
		# send the character to the wrong activity.
		$map = $event->{data_map}{map}
			if ref($event) eq 'HASH'
			&& ref($event->{data_map}) eq 'HASH';
		return undef unless defined $map && _trim($map) ne '';
	} elsif ($source eq 'static' || $source eq 'announcement') {
		# Both documented fixed sources intentionally use the configured map.  A
		# scheduler event's incidental map/data metadata is not a substitute for
		# that operator-confirmed value.
		$map = $rule->{entry_map};
	} else {
		# Rules written before map_source was introduced remain compatible, while
		# still requiring the normal map validation before any transfer.
		$map = $rule->{entry_map};
		$map = $event->{map} if (!defined $map || $map eq '')
			&& ref($event) eq 'HASH' && defined $event->{map};
		$map = $event->{data_map}{map}
			if (!defined $map || $map eq '')
			&& ref($event) eq 'HASH'
			&& ref($event->{data_map}) eq 'HASH';
	}
	return undef unless defined $map;

	$map = _trim($map);
	$map =~ s/\.(?:rsw|gat)\z//i;
	return undef if $map eq '' || $map =~ m{[\\/]}
		|| $map =~ /\.\./ || $map =~ /[\x00-\x1F\x7F]/
		|| $map =~ /[\s;|&<>"'`]/;
	return $map;
}

sub _normalize_map_name {
	my ($map) = @_;
	return undef unless defined $map;
	$map = _trim($map);
	$map =~ s/\.(?:rsw|gat)\z//i;
	return undef if $map eq '' || $map =~ /[\s;|&<>"'`\r\n]/;
	return $map;
}

sub _current_map {
	my ($args) = @_;
	my $map;
	if (ref($args) eq 'HASH') {
		for my $key (qw(map Map mapName map_name mapname name field)) {
			if (exists $args->{$key} && defined $args->{$key}) {
				$map = $args->{$key};
				last;
			}
		}
	}

	my $field = $Globals::field;
	if (ref($map) && ref($map) eq 'HASH') {
		my $map_hash = $map;
		$map = $map_hash->{map} if exists $map_hash->{map};
		$map = $map_hash->{name} if !defined $map && exists $map_hash->{name};
	}
	if (ref($map) && ref($map) ne 'HASH') {
		my $read = eval {
			$map->can('baseName') ? $map->baseName()
				: ($map->can('name') ? $map->name() : undef);
		};
		$map = $read unless $@;
	}
	if (!defined $map && ref($field) eq 'HASH') {
		$map = $field->{map} if exists $field->{map};
		$map = $field->{name} if !defined $map && exists $field->{name};
	}
	if (!defined $map && $field) {
		my $read = eval {
			$field->can('baseName') ? $field->baseName()
				: ($field->can('name') ? $field->name() : undef);
		};
		$map = $read unless $@;
	}
	return _normalize_map_name($map);
}

sub _map_matches {
	my ($left, $right) = @_;
	$left = _normalize_map_name($left);
	$right = _normalize_map_name($right);
	return 0 unless defined $left && defined $right;
	return lc($left) eq lc($right) ? 1 : 0;
}

sub _transfer_timeout {
	my ($rule) = @_;
	my $timeout = ref($rule) eq 'HASH' ? $rule->{timeout_seconds} : undef;
	return 15 unless defined $timeout && "$timeout" =~ /^\s*\d+(?:\.\d+)?\s*\z/ && $timeout > 0;
	return 0 + $timeout;
}

# Commands::run() deliberately reports that a command was dispatched, even
# when the command handler rejected it and only emitted a Log::error/warning.
# Activity transfers are safety-critical, so observe those synchronous log
# records while the command is running and turn them into a checked result.
sub _run_checked_command {
	my ($command, %options) = @_;
	my @diagnostics;
	my $log_hook;
	my $hook_installed = 0;
	if (defined &Log::addHook) {
		my $hook_ok = eval {
			$log_hook = Log::addHook(sub {
				my ($type, undef, undef, undef, $message) = @_;
				return unless defined $message && !ref($message);
				my $text = _trim($message);
				return if $text eq '';
				my $is_error = defined $type && $type eq 'error';
				my $is_airship_warning = defined $type && $type eq 'warning'
					&& $text =~ /(?:LastroAirship|Private\s+Airship|privateairship|airship\s+transfer|destination\s+map|source\s+map)/i;
				push @diagnostics, $text if $is_error || $is_airship_warning;
			}, undef);
			$hook_installed = 1;
			1;
		};
		# A host with a partial Log implementation should still be able to use
		# the ordinary return/exception checks below.
		$hook_installed = 0 if !$hook_ok;
	}

	my ($result, $exception);
	my $ok = eval {
		$result = Commands::run($command);
		1;
	};
	$exception = _trim($@ || 'command failed') unless $ok;

	if ($hook_installed) {
		eval { Log::delHook($log_hook); 1 };
	}

	if (!$ok) {
		return (0, $exception ne '' ? $exception : 'command failed');
	}
	if (defined $result && !$result) {
		return (0, 'command returned failure');
	}
	if (@diagnostics) {
		my %seen;
		@diagnostics = grep { !$seen{$_}++ } @diagnostics;
		return (0, join('; ', @diagnostics));
	}

	# The TalkNPC command queues work asynchronously.  When the real AI API is
	# available, a successful Commands::run() without an NPC queue means the
	# request was rejected or could not be scheduled.
	if ($options{verify_npc} && defined &AI::inQueue) {
		my ($queued, $queue_error);
		my $queue_ok = eval {
			$queued = AI::inQueue('NPC');
			1;
		};
		$queue_error = _trim($@ || 'unable to inspect TalkNPC queue') unless $queue_ok;
		return (0, $queue_error ne '' ? $queue_error : 'TalkNPC command did not queue an NPC task')
			if !$queue_ok || !$queued;
	}

	return (1, undef);
}

sub _observe_npc_queue {
	return (undef, 'NPC queue observer is unavailable')
		unless defined &AI::inQueue;

	my ($queued, $ok) = (0, 0);
	$ok = eval {
		$queued = AI::inQueue('NPC');
		1;
	};
	unless ($ok) {
		my $error = _trim($@ || 'unable to inspect NPC queue');
		return (undef, $error ne '' ? $error : 'unable to inspect NPC queue');
	}
	return ($queued ? 1 : 0, undef);
}

sub _npc_task_object {
	my ($candidate) = @_;
	return undef unless ref($candidate);
	my $is_task = eval {
		$candidate->can('getStatus') && $candidate->can('getError');
	};
	return $is_task ? $candidate : undef;
}

sub _npc_task_identity {
	my ($task) = @_;
	return undef unless ref($task);
	return eval { Scalar::Util::refaddr($task) };
}

sub _npc_queue_task {
	return wantarray ? (undef, undef) : undef
		unless defined &AI::findAction;

	my ($index, $index_ok) = (undef, 0);
	$index_ok = eval {
		$index = AI::findAction('NPC');
		1;
	};
	return wantarray ? (undef, undef) : undef
		unless $index_ok && defined $index && "$index" =~ /^\d+\z/;

	# AI::args() intentionally exposes a hash view of the queue entry.  Keep
	# the original blessed task from the backing arrays so status and identity
	# checks remain meaningful in the real OpenKore runtime.
	my @candidates;
	push @candidates, $AI::ai_seq_args[$index]
		if $index <= $#AI::ai_seq_args;

	if (defined &AI::args) {
		my ($args, $args_ok) = (undef, 0);
		$args_ok = eval {
			$args = AI::args($index);
			1;
		};
		if ($args_ok) {
			push @candidates, $args;
			push @candidates, $args->{task}
				if ref($args) eq 'HASH' && exists $args->{task};
		}
	}

	for my $candidate (@candidates) {
		my $task = _npc_task_object($candidate);
		return wantarray ? ($task, 0 + $index) : $task
			if defined $task;
	}
	return wantarray ? (undef, 0 + $index) : undef;
}

sub _npc_task_outcome {
	my ($task) = @_;
	return ('unknown', 'leave NPC task is unavailable') unless defined $task;

	my ($status, $status_ok) = (undef, 0);
	$status_ok = eval {
		$status = $task->getStatus();
		1;
	};
	return ('unknown', 'unable to inspect leave NPC task status') unless $status_ok;

	my $done_status;
	if (defined &Task::DONE) {
		$done_status = eval { Task::DONE() };
	}
	my $is_done = defined $status && (
		(defined $done_status && "$status" eq "$done_status")
		|| "$status" eq 'DONE'
		|| "$status" eq '4'
	);
	return ('pending', undef) unless $is_done;

	# Task::TalkNPC can mark itself DONE when a map change or disconnect
	# interrupts the conversation.  That is not evidence that the configured
	# leave sequence completed, so inspect the task markers before accepting
	# a successful result.  Test doubles and older task implementations may not
	# expose these fields; in that case the normal status/error contract applies.
	my $disconnected = _actor_value($task, 'disconnected');
	return ('failure', 'leave NPC task was interrupted by disconnect')
		if defined $disconnected && $disconnected;
	my $map_change = _actor_value($task, 'map_change');
	if (defined $map_change && $map_change) {
		my $steps = _actor_value($task, 'steps');
		return ('failure', 'leave NPC task was interrupted during map change')
			if ref($steps) eq 'ARRAY' && @$steps;
	}

	my ($error, $error_ok) = (undef, 0);
	$error_ok = eval {
		$error = $task->getError();
		1;
	};
	return ('failure', 'unable to inspect leave NPC task result') unless $error_ok;
	return ('success', undef) unless defined $error;

	my $message;
	if (ref($error) eq 'HASH') {
		for my $key (qw(message error code)) {
			next unless exists $error->{$key} && defined $error->{$key};
			my $value = _trim($error->{$key});
			next if $value eq '';
			$message = $value;
			last;
		}
	} elsif (!ref($error)) {
		$message = _trim($error);
	}
	$message = 'leave NPC task failed' unless defined $message && $message ne '';
	return ('failure', "leave NPC task failed: $message");
}

sub _macro_name {
	my ($name) = @_;
	return undef if ref($name);
	$name = _trim($name);
	return undef if $name eq '' || $name =~ /[^A-Za-z0-9_.:-]/;
	return $name;
}

sub _npc_sequence {
	my ($npc) = @_;
	return undef if ref($npc);
	$npc = _trim($npc);
	return undef if $npc eq '' || $npc =~ /[\r\n;|&<>"'`]/;
	if ($npc =~ /\A[^#]+#([A-Za-z0-9_,.:-]+)\z/) {
		return $1;
	}
	# A bare sequence is accepted for callers that already resolved the NPC;
	# names containing whitespace or shell syntax remain fail-closed.
	return $npc if $npc =~ /\A[A-Za-z0-9_,.:-]+\z/;
	return undef;
}

sub _configured_macro {
	my ($rule, $field) = @_;
	return (undef, undef) unless ref($rule) eq 'HASH';
	return (undef, undef) unless exists $rule->{$field};
	my $raw = _trim($rule->{$field});
	return (undef, undef) if $raw eq '';
	my $name = _macro_name($raw);
	return ($name, undef) if defined $name;
	return (undef, "invalid $field '$raw'");
}

sub _validate_macro_fields {
	my ($rule) = @_;
	return (1, undef) unless ref($rule) eq 'HASH';
	for my $field (qw(entry_macro finish_macro)) {
		my (undef, $error) = _configured_macro($rule, $field);
		next unless defined $error;
		_append_rule_validation_error($rule, $error);
		return (0, $error);
	}
	return (1, undef);
}

sub _macro_queue {
	no strict 'refs';
	my $queue = ${'macro::queue'};
	return $queue if defined $queue;
	return ${'Macro::Data::queue'};
}

sub _macro_queue_name {
	my ($queue) = @_;
	return undef unless defined $queue;
	if (ref($queue) eq 'HASH') {
		return $queue->{name} if defined $queue->{name};
	}
	my $name = eval { $queue->can('name') ? $queue->name() : undef };
	return $name unless $@;
	return undef;
}

sub _macro_queue_finished {
	my ($queue) = @_;
	return 0 unless defined $queue;
	if (ref($queue) eq 'HASH' && exists $queue->{finished}) {
		return $queue->{finished} ? 1 : 0;
	}
	my $finished = eval { $queue->can('finished') ? $queue->finished() : 0 };
	return (!$@ && $finished) ? 1 : 0;
}

sub _macro_error_belongs_to_pending {
	my ($name) = @_;
	return 0 unless defined $pending_macro;
	return 1 unless defined $name && $name ne '' && $name ne $pending_macro;

	# Macro::Utilities reports a child script's name while the package queue
	# still points at the root script.  Match that root before deciding an error
	# is unrelated.  If the queue has already disappeared, the pending marker is
	# the only ownership signal left and the activity's exclusive macro owns it.
	my $queue = _macro_queue();
	if (defined $queue) {
		my $queue_name = _macro_queue_name($queue);
		return 1 unless defined $queue_name && $queue_name ne '';
		return 1 if $queue_name eq $pending_macro;
		return 1 if defined $pending_macro_root_name
			&& $queue_name eq $pending_macro_root_name;
		return 0;
	}
	return 1;
}

sub _transition_state {
	my ($transition) = @_;
	return 0 unless ref($state) eq 'LastROActivity::State';
	my $ok = eval {
		$state->transition($transition);
		1;
	};
	return $ok ? 1 : 0;
}

sub _transition_to_finishing {
	return 0 unless ref($state) eq 'LastROActivity::State';
	my $current = $state->state;
	return 1 if $current eq 'FINISHING';
	return 0 if $current eq 'FAILED' || $current eq 'RESUMED' || $current eq 'IDLE';

	# A timeout can arrive while the transfer or entry hook is still pending.
	# Walk the documented lifecycle edges so every finish request still reaches
	# the common FINISHING -> RETURNING path.
	my %edges = (
		INTERRUPTING => [qw(snapshot depart enter running finish)],
		SNAPSHOTTED => [qw(depart enter running finish)],
		DEPARTING   => [qw(enter running finish)],
		ENTERING    => [qw(running finish)],
		RUNNING     => [qw(finish)],
	);
	for my $edge (@{$edges{$current} || []}) {
		return 0 unless _transition_state($edge);
	}
	return $state->state eq 'FINISHING' ? 1 : 0;
}

sub _clear_pending_macro {
	$pending_macro = undef;
	$pending_macro_stage = undef;
	$pending_macro_seen = 0;
	$pending_macro_deadline = undef;
	$pending_macro_error = undef;
	$pending_macro_root_name = undef;
}

sub _clear_pending_leave_npc {
	delete $active_event->{leave_npc_pending}
		if ref($active_event) eq 'HASH';
	$pending_leave_npc = undef;
}

sub _map_is_known {
	my ($map) = @_;
	return 0 unless defined $map && $map ne '';
	my $maps = \%Globals::maps_lut;
	my $wanted = lc("$map");
	$wanted =~ s/\.(?:rsw|gat)\z//;
	for my $key (keys %$maps) {
		next unless defined $key;
		my $candidate = lc("$key");
		$candidate =~ s/\.(?:rsw|gat)\z//;
		return 1 if $candidate eq $wanted && defined $maps->{$key};
	}
	return 0;
}

sub _in_game {
	my $net = $Globals::net;
	return 0 unless $net;
	my $state = eval {
		if (ref($net) eq 'HASH') {
			exists $net->{state}
				? $net->{state}
				: (exists $net->{conState} ? $net->{conState} : undef);
		} elsif ($net->can('getState')) {
			$net->getState();
		} else {
			undef;
		}
	};
	return 0 if $@ || !defined $state;
	my $in_game = 5;
	if (defined &Network::IN_GAME) {
		my $constant = eval { Network::IN_GAME() };
		$in_game = $constant if !$@ && defined $constant;
	}
	return $state == $in_game ? 1 : 0;
}

sub _airship_item_id {
	my ($rule) = @_;
	return (undef, 'airship entry rule is unavailable') unless ref($rule) eq 'HASH';
	my $rule_item_id = $rule->{entry_item_id};
	return (undef, 'entry_item_id is required for airship entry')
		unless defined $rule_item_id && $rule_item_id =~ /^\d+\z/ && $rule_item_id > 0;

	my $master = $Globals::masterServer;
	return (undef, 'LastRO server metadata is unavailable') unless ref($master) eq 'HASH';
	return (undef, 'LastRO server metadata does not advertise private airship')
		unless defined $master->{lastroAirship}
		&& "$master->{lastroAirship}" =~ /^\s*1\s*\z/;
	my $server_item_id = $master->{privateAirshipItemID};
	return (undef, 'LastRO server metadata has no private airship item ID')
		unless defined $server_item_id && $server_item_id =~ /^\d+\z/ && $server_item_id > 0;
	return (undef, 'entry_item_id does not match LastRO server metadata')
		if $rule_item_id != $server_item_id;

	return (0 + $rule_item_id, undef);
}

sub _inventory_has_airship_item {
	my ($rule) = @_;
	my $char = $Globals::char;
	return (0, 'character inventory is unavailable') unless $char;

	my $inventory = eval {
		if (ref($char) eq 'HASH') {
			$char->{inventory};
		} elsif ($char->can('inventory')) {
			$char->inventory;
		} else {
			undef;
		}
	};
	return (0, 'character inventory is unavailable') if $@ || !$inventory;

	my $inventory_can_ready = eval { $inventory->can('isReady') };
	if ($inventory_can_ready) {
		my $ready = eval { $inventory->isReady() };
		return (0, 'character inventory is not ready') if $@ || !$ready;
	}

	my ($item_id, $item_error) = _airship_item_id($rule);
	return (0, $item_error) unless defined $item_id;
	my $item = eval {
		if (ref($inventory) eq 'HASH') {
			exists $inventory->{$item_id}
				? $inventory->{$item_id}
				: (ref($inventory->{items}) eq 'HASH'
					&& exists $inventory->{items}{$item_id}
					? $inventory->{items}{$item_id}
					: undef);
		} elsif ($inventory->can('getByNameID')) {
			$inventory->getByNameID($item_id);
		} else {
			undef;
		}
	};
	return (0, 'Private Airship item is unavailable') if $@ || !$item;

	# Inventory entries are commonly blessed hashrefs.  Read amount through an
	# eval for both plain and blessed entries, and fail closed when its shape is
	# not one we can verify.
	my ($has_amount, $amount);
	my $amount_read = eval {
		if (eval { exists $item->{amount} }) {
			$has_amount = 1;
			$amount = $item->{amount};
		} elsif (eval { $item->can('amount') }) {
			$has_amount = 1;
			$amount = $item->amount();
		}
		1;
	};
	return (0, 'Private Airship item amount is unavailable') if !$amount_read || !$has_amount;
	return (0, 'Private Airship item is unavailable')
		unless defined $amount && "$amount" =~ /^\s*\d+(?:\.\d+)?\s*\z/ && $amount > 0;
	return (1, undef);
}

sub _search_targets {
	my ($rule) = @_;
	return () unless ref($rule) eq 'HASH';
	my $targets = $rule->{search_targets};
	return grep { defined $_ && _trim($_) ne '' } @$targets
		if ref($targets) eq 'ARRAY';
	return (_trim($targets)) if defined $targets && _trim($targets) ne '';
	return ();
}

sub _append_rule_validation_error {
	my ($rule, $error) = @_;
	return unless ref($rule) eq 'HASH' && defined $error && $error ne '';
	$rule->{validation_errors} = [] unless ref($rule->{validation_errors}) eq 'ARRAY';
	push @{$rule->{validation_errors}}, $error
		unless grep { defined $_ && $_ eq $error } @{$rule->{validation_errors}};
	$rule->{enabled} = 0;
}

sub _validate_return_policy {
	my ($rule) = @_;
	return (1, undef) unless ref($rule) eq 'HASH';
	# An omitted policy is the legacy form of the canonical default. An explicit
	# value, including an empty override, must name the one supported route.
	return (1, undef) unless exists $rule->{return_policy}
		&& defined $rule->{return_policy};
	my $policy = _trim($rule->{return_policy});
	return (1, undef) if $policy =~ /^privateairship:prontera$/i;
	my $error = 'return_policy must be privateairship:prontera';
	_append_rule_validation_error($rule, $error);
	return (0, $error);
}

sub _validate_completion_policy {
	my ($rule) = @_;
	return (0, 'rule is unavailable') unless ref($rule) eq 'HASH';
	my @errors;
	my $finish_valid = 0;
	if (exists $rule->{finish_regex} && defined $rule->{finish_regex}
		&& (!ref($rule->{finish_regex}) || ref($rule->{finish_regex}) eq 'Regexp'
			|| ref($rule->{finish_regex}) eq 'CODE')) {
		my $finish = ref($rule->{finish_regex}) ? 'pattern' : _trim($rule->{finish_regex});
		if ($finish ne '' || ref($rule->{finish_regex})) {
			my (undef, $error) = _compile_activity_pattern(
				$rule->{finish_regex}, 'finish pattern',
			);
			if (defined $error) {
				push @errors, $error;
			} else {
				$finish_valid = 1;
			}
		}
	}

	# Round-based activities have an explicit completion boundary even when the
	# server does not emit a separate final announcement.  Validate the success
	# pattern here so direct (non-parser) rules receive the same gate.
	my $round_success_valid = 0;
	if (exists $rule->{round_success_regex}
		&& defined $rule->{round_success_regex}) {
		my (undef, $error) = _compile_activity_pattern(
			$rule->{round_success_regex}, 'round success pattern',
		);
		if (defined $error) {
			push @errors, $error;
		} else {
			$round_success_valid = 1;
		}
	}
	if (exists $rule->{round_start_regex}
		&& defined $rule->{round_start_regex}) {
		my (undef, $error) = _compile_activity_pattern(
			$rule->{round_start_regex}, 'round start pattern',
		);
		push @errors, $error if defined $error;
	}
	if (exists $rule->{round_id_regex}
		&& defined $rule->{round_id_regex}
		&& (ref($rule->{round_id_regex}) || _trim($rule->{round_id_regex}) ne '')) {
		my (undef, $error) = _compile_activity_pattern(
			$rule->{round_id_regex}, 'round identity pattern',
		);
		push @errors, $error if defined $error;
	}

	my $phases = $rule->{phases};
	my $phases_valid = 0;
	if (defined $phases) {
		if (ref($phases) ne 'ARRAY') {
			push @errors, 'phases must be an array';
		} elsif (@$phases) {
			$phases_valid = 1;
			for my $index (0 .. $#$phases) {
				my $phase = $phases->[$index];
				unless (ref($phase) eq 'HASH') {
					push @errors, 'phase ' . ($index + 1) . ' must be a hash';
					$phases_valid = 0;
					next;
				}
				my $pattern = _phase_pattern($phase);
				unless (defined $pattern) {
					push @errors, 'phase ' . ($index + 1)
						. ' requires an explicit finish condition';
					$phases_valid = 0;
					next;
				}
				my (undef, $error) = _compile_activity_pattern(
					$pattern, 'phase ' . ($index + 1) . ' finish pattern',
				);
				if (defined $error) {
					push @errors, $error;
					$phases_valid = 0;
				}
			}
		}
	}

	my $duration_valid = 0;
	if (exists $rule->{duration_seconds} && defined $rule->{duration_seconds}) {
		$duration_valid = defined _positive_number($rule->{duration_seconds}) ? 1 : 0;
		push @errors, 'duration_seconds must be a positive number'
			unless $duration_valid;
	}

	# A lifecycle must have at least one observable completion boundary.  A
	# positive duration is the explicit fallback for activities whose server has
	# no finish announcement; finish macros alone are not completion evidence.
	unless ($finish_valid || $phases_valid || $duration_valid || $round_success_valid) {
		push @errors, 'finish evidence, phases, or a positive duration is required';
	}

	if (@errors) {
		_append_rule_validation_error($rule, $_) for @errors;
		return (0, $errors[0]);
	}
	return (1, undef);
}

sub _validate_npc_evidence {
	my ($rule) = @_;
	return (0, 'NPC dialog evidence is required') unless ref($rule) eq 'HASH';
	my $trusted = 0;
	for my $key (qw(entry_npc_trusted npc_trusted trusted_npc)) {
		if (exists $rule->{$key} && defined $rule->{$key}
			&& "$rule->{$key}" =~ /^\s*1\s*\z/) {
			$trusted = 1;
			last;
		}
	}
	my $evidence;
	for my $key (qw(entry_npc_evidence npc_evidence npc_dialog_evidence entry_npc_metadata npc_metadata)) {
		next unless exists $rule->{$key} && defined $rule->{$key};
		my $candidate = $rule->{$key};
		if (ref($candidate) eq 'HASH') {
			$trusted = 1 if defined $candidate->{trusted}
				&& "$candidate->{trusted}" =~ /^\s*1\s*\z/;
			$evidence = $candidate->{text} || $candidate->{source}
				|| $candidate->{message} || $candidate->{sequence};
		} elsif (!ref($candidate)) {
			$evidence = _trim($candidate);
		}
		last if defined $evidence && $evidence ne '';
	}
	return (0, 'trusted NPC dialog evidence is required')
		unless $trusted && defined $evidence && $evidence ne '';
	return (1, undef);
}

sub _validate_leave_npc {
	my ($rule) = @_;
	return (0, 'leave NPC rule is unavailable') unless ref($rule) eq 'HASH';
	my $sequence = _npc_sequence($rule->{leave_npc});
	return (0, 'leave_npc must include a safe TalkNPC sequence')
		unless defined $sequence;
	return (0, 'leave_x is required for leave NPC')
		unless defined $rule->{leave_x} && "$rule->{leave_x}" =~ /^\d+\z/;
	return (0, 'leave_y is required for leave NPC')
		unless defined $rule->{leave_y} && "$rule->{leave_y}" =~ /^\d+\z/;
	return (0, 'leave_npc_trusted=1 is required for leave NPC')
		unless defined $rule->{leave_npc_trusted}
			&& "$rule->{leave_npc_trusted}" =~ /^\s*1\s*\z/;

	my $evidence = $rule->{leave_npc_evidence};
	my $evidence_text;
	if (ref($evidence) eq 'HASH') {
		$evidence_text = $evidence->{text} || $evidence->{source}
			|| $evidence->{message} || $evidence->{sequence};
	} elsif (defined $evidence && !ref($evidence)) {
		$evidence_text = _trim($evidence);
	}
	return (0, 'trusted leave NPC dialog evidence is required')
		unless defined $evidence_text && _trim($evidence_text) ne '';
	return (1, undef);
}

sub _leave_npc_configured {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	for my $field (qw(leave_npc leave_npc_trusted leave_npc_evidence leave_x leave_y)) {
		return 1 if exists $rule->{$field}
			&& defined $rule->{$field}
			&& (!ref($rule->{$field}) ? _trim($rule->{$field}) ne '' : 1);
	}
	return 0;
}

sub _search_row_enabled {
	my ($key) = @_;
	return 0 unless defined $key;
	$key = lc(_trim($key));
	return 0 if $key eq '';
	my $row = $Globals::mon_control{$key};
	return 0 unless ref($row) eq 'HASH';
	my $search = $row->{teleport_search};
	return defined $search && "$search" =~ /^\s*1\s*\z/ ? 1 : 0;
}

sub _trusted_search_target {
	my ($target) = @_;
	return 0 unless defined $target;
	$target = _trim($target);
	return 0 if $target eq '' || lc($target) eq 'all' || $target =~ /[\r\n]/;
	return 0 if $target =~ /^0+\z/;

	# search_targets is evidence metadata, not a resolver input. Only the exact
	# declared key (after the same trim/lowercase normalization as mon_control)
	# may authorize a shared search row; monster LUT aliases are intentionally
	# ignored.
	return _search_row_enabled(lc($target));
}

sub _validate_search_targets {
	my ($rule) = @_;
	return (1, undef) unless _uses_search_mode($rule);
	my @targets = _search_targets($rule);
	unless (@targets) {
		my $error = 'search_targets evidence is required for shared search mode';
		_append_rule_validation_error($rule, $error);
		return (0, $error);
	}

	my %seen;
	my @invalid;
	for my $target (@targets) {
		my $display = _trim($target);
		my $key = lc($display);
		next if $seen{$key}++;
		push @invalid, $display unless _trusted_search_target($display);
	}
	return (1, undef) if @invalid == 0;

	my @errors = map {
		"search target '$_' is not present in shared mon_control with teleport_search=1"
	} @invalid;
	_append_rule_validation_error($rule, $_) for @errors;
	return (0, join('; ', @errors));
}

sub _uses_search_mode {
	my ($rule) = @_;
	return 1 unless ref($rule) eq 'HASH';
	return 1 if $rule->{search_mode} || $rule->{shared_search};
	my $entry_type = lc(_trim($rule->{entry_type} || 'privateairship'));
	return 0 if $entry_type eq 'npc' || $entry_type eq 'macro';
	return 1;
}

sub _activity_entry_validation {
	my ($rule, $event) = @_;
	unless (_validated_enabled_rule($rule)) {
		if (ref($rule) eq 'HASH' && ref($rule->{validation_errors}) eq 'ARRAY'
			&& @{$rule->{validation_errors}}) {
			return $rule->{validation_errors}[0];
		}
		return 'rule is not enabled or validated';
	}
	my ($completion_ok, $completion_reason) = _validate_completion_policy($rule);
	return $completion_reason unless $completion_ok;
	my ($macro_ok, $macro_reason) = _validate_macro_fields($rule);
	return $macro_reason unless $macro_ok;
	my ($search_ok, $search_reason) = _validate_search_targets($rule);
	return $search_reason unless $search_ok;
	return 'not connected in game' unless _in_game();

	my $map = _event_map($rule, $event);
	unless (defined $map) {
		my $reason = (defined $rule->{map_source}
			&& lc(_trim($rule->{map_source})) eq 'dynamic')
			? 'dynamic event map metadata is required'
			: 'event map is missing';
		_append_rule_validation_error($rule, $reason);
		return $reason;
	}
	if (length($map) > 16) {
		my $reason = 'event map name is too long';
		_append_rule_validation_error($rule, $reason);
		return $reason;
	}
	unless (_map_is_known($map)) {
		my $reason = "event map '$map' is unknown";
		_append_rule_validation_error($rule, $reason);
		return $reason;
	}

	my $entry_type = lc(_trim($rule->{entry_type} || 'privateairship'));
	if ($entry_type eq 'airship' || $entry_type eq 'privateairship') {
		my ($ok, $reason) = _inventory_has_airship_item($rule);
		return $reason unless $ok;
	} elsif ($entry_type eq 'macro') {
		my ($macro, $macro_error) = _configured_macro($rule, 'entry_macro');
		return $macro_error if defined $macro_error;
		return 'entry_macro is required for macro entry' unless defined $macro;
	} elsif ($entry_type eq 'npc') {
		my $sequence = _npc_sequence($rule->{entry_npc});
		unless (defined $sequence) {
			my $reason = 'entry_npc is required for NPC entry';
			_append_rule_validation_error($rule, $reason);
			return $reason;
		}
		unless (defined $rule->{entry_x} && "$rule->{entry_x}" =~ /^\d+\z/) {
			my $reason = 'entry_x is required for NPC entry';
			_append_rule_validation_error($rule, $reason);
			return $reason;
		}
		unless (defined $rule->{entry_y} && "$rule->{entry_y}" =~ /^\d+\z/) {
			my $reason = 'entry_y is required for NPC entry';
			_append_rule_validation_error($rule, $reason);
			return $reason;
		}
		my ($npc_ok, $npc_reason) = _validate_npc_evidence($rule);
		unless ($npc_ok) {
			_append_rule_validation_error($rule, $npc_reason);
			return $npc_reason;
		}
	} else {
		return "unsupported entry_type '$entry_type'";
	}

	return undef;
}

sub activity_lock {
	return $activity_lock ? 1 : 0 unless @_;
	my ($enabled_value) = @_;
	$activity_lock = $enabled_value ? 1 : 0;
	return $activity_lock;
}

sub _macro_available {
	if (defined &Plugins::registered) {
		my $registered = eval { Plugins::registered('macro') };
		return $registered ? 1 : 0 unless $@;
	}
	my $entry = $Commands::commands{macro};
	return 0 unless $entry;
	return ref($entry) eq 'HASH'
		? ref($entry->{callback}) eq 'CODE'
		: ref($entry) eq 'CODE';
}

sub clear_normal_ai {
	if (_macro_available()) {
		eval { Commands::run('macro stop'); 1 }
			or warning "[LastROActivity] Unable to stop the active macro: $@\n";
	}
	AI::clear(qw(attack move route mapRoute items_take items_gather take));
	return 1;
}

sub clear_activity_ai {
	# Keep the activity-specific cleanup separate from the final AI reset.  The
	# latter runs only after the return map has been confirmed and the snapshot
	# is back in place.
	my $ok = clear_normal_ai();
	# NPC dialog and teleport actions can survive the ordinary interruption list
	# and otherwise compete with the fixed return transfer or restored route.
	AI::clear(qw(NPC teleport));
	return $ok;
}

sub _try_clear_activity_ai {
	my ($context) = @_;
	$context = 'activity AI cleanup' unless defined $context && $context ne '';
	my ($result, $error);
	my $ok = eval {
		$result = clear_activity_ai();
		1;
	};
	if (!$ok) {
		$error = _trim($@ || "$context failed");
	} elsif (defined $result && !$result) {
		$error = "$context returned failure";
	}
	return 1 unless defined $error && $error ne '';
	_record_cleanup_failure($error);
	return 0;
}

sub _set_pending_destination {
	my ($destination, $kind, $rule) = @_;
	$pending_destination = _normalize_map_name($destination);
	$pending_destination_kind = $kind;
	$pending_destination_deadline = _now() + _transfer_timeout($rule);
	$pending_airship_result = undef;
	$return_pending = $kind eq 'return' ? 1 : 0;
	if ($kind eq 'entry') {
		$entry_map_confirmed = 0;
		$entry_transfer_accepted = 0;
	}
	return defined $pending_destination ? 1 : 0;
}

sub _clear_pending_destination {
	$pending_destination = undef;
	$pending_destination_kind = undef;
	$pending_destination_deadline = undef;
	$pending_airship_result = undef;
	$return_pending = 0;
	$entry_map_confirmed = 0;
	$entry_transfer_accepted = 0;
}

sub _clear_entry_transfer {
	# Once the server accepted an entry and the destination map was observed,
	# no later unrelated airship result should be attributed to this activity.
	# Keep entry_map_confirmed separate so duplicate map packets remain harmless.
	$entry_transfer_accepted = 1
		if defined $pending_airship_result && $pending_airship_result == 0;
	$pending_destination = undef;
	$pending_destination_kind = undef;
	$pending_destination_deadline = undef;
	$pending_airship_result = undef;
}

sub _entry_transfer_ready {
	return 0 unless defined $active_event;
	my $rule = $active_event->{rule};
	my $entry_type = ref($rule) eq 'HASH'
		? lc(_trim($rule->{entry_type} || 'privateairship'))
		: 'privateairship';
	return 1 unless $entry_type eq 'airship' || $entry_type eq 'privateairship';
	return $entry_transfer_accepted ? 1 : 0;
}

sub _maybe_start_entry_macro {
	return 1 unless defined $active_event && $entry_map_confirmed;
	return 0 unless _entry_transfer_ready();
	my $rule = $active_event->{rule};
	my ($entry_macro, $macro_error) = _configured_macro($rule, 'entry_macro');
	if (defined $macro_error) {
		_mark_activity_failed($macro_error);
		return 0;
	}
	return 1 unless defined $entry_macro;
	return 1 if $active_event->{entry_macro_started};
	$active_event->{entry_macro_started} = 1;
	unless (_launch_activity_macro($entry_macro, 'entry', $rule)) {
		_mark_activity_failed("entry macro '$entry_macro' could not start");
		return 0;
	}
	return 1;
}

sub _launch_activity_macro {
	my ($name, $stage, $rule) = @_;
	my $raw_name = $name;
	$name = _macro_name($name);
	unless (defined $name) {
		warning "[LastROActivity] Invalid macro name '" . _trim($raw_name) . "'.\n";
		return 0;
	}
	unless (_macro_available()) {
		warning "[LastROActivity] Macro plugin is unavailable for '$name'.\n";
		return 0;
	}

	my $command = "macro $name -overrideAI -exclusive";
	my ($result, $error);
	my $ok = eval {
		$result = Commands::run($command);
		1;
	};
	$error = _trim($@ || 'macro command failed') unless $ok;
	if (!$ok || (defined $result && !$result)) {
		$error = 'macro command returned failure' if !defined $error || $error eq '';
		warning "[LastROActivity] Unable to start macro '$name': $error.\n";
		return 0;
	}

	$pending_macro = $name;
	$pending_macro_stage = $stage;
	$pending_macro_seen = 0;
	$pending_macro_deadline = _now() + _transfer_timeout($rule);
	$pending_macro_error = undef;
	$pending_macro_root_name = undef;
	# The macro plugin's mainLoop_pre hook is normally registered before this
	# plugin.  It can therefore finish and undefine the queue before our next
	# hook invocation; record a matching queue that already exists now so that
	# disappearance is treated as completion rather than a timeout.
	my $queue = _macro_queue();
	if (defined $queue) {
		my $queue_name = _macro_queue_name($queue);
		$pending_macro_root_name = $queue_name if defined $queue_name && $queue_name ne '';
		$pending_macro_seen = 1
			if !defined $queue_name || $queue_name eq $name;
	}
	return 1;
}

sub _confirm_entry_map_for_running {
	return 0 unless defined $active_event;

	my $event_map = _event_map($active_event->{rule}, $active_event);
	my $current_map = _current_map(undef);
	if (!defined $event_map) {
		_mark_activity_failed('event map is unavailable before entry completed');
		return 0;
	}
	if (!defined $current_map) {
		_mark_activity_failed('current map is unavailable before entry completed');
		return 0;
	}
	if (!_map_matches($current_map, $event_map)) {
		_mark_activity_failed('left activity map before entry completed');
		return 0;
	}
	return 1;
}

sub _finish_entry_macro {
	my ($success, $reason) = @_;
	my $stage = $pending_macro_stage;
	if ($success && defined $pending_macro_error && $pending_macro_error ne '') {
		$success = 0;
		$reason = $pending_macro_error;
	}
	_clear_pending_macro();
	return 1 unless defined $stage;
	if (!$success) {
		_mark_activity_failed($reason || 'activity entry macro failed');
		return 0;
	}

	if ($stage eq 'entry') {
		if (ref($state) eq 'LastROActivity::State' && $state->state eq 'ENTERING') {
			return 0 unless _set_running_state(_now());
		}
		$active_event->{entry_macro_complete} = 1 if ref($active_event) eq 'HASH';
		return 1;
	}

	if ($stage eq 'finish') {
		return return_to_capital();
	}
	return 1;
}

sub _mark_activity_failed {
	my ($reason) = @_;
	$reason = _trim($reason || 'activity failed');
	my $had_pending_leave_npc = defined $pending_leave_npc;
	# Once a lifecycle is already failed, retain the first actionable reason.
	# Late duplicate packets are common during a rejected transfer and must not
	# replace the diagnostic that caused the return.
	if (ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'FAILED'
		&& defined $last_failure && $last_failure ne '') {
		return 0;
	}
	$last_failure = $reason;
	warning "[LastROActivity] $reason.\n";

	if (ref($state) eq 'LastROActivity::State'
		&& $state->state ne 'FAILED'
		&& $state->state ne 'IDLE'
		&& $state->state ne 'RESUMED') {
		_transition_state('fail');
	}
	_clear_pending_macro();
	_clear_pending_leave_npc();
	if (defined $active_event && !$return_pending) {
		if (!$active_event->{activity_ai_cleared} || $had_pending_leave_npc) {
			$active_event->{activity_ai_cleared} = 1;
			_try_clear_activity_ai('activity failure cleanup');
		}
		# A failed entry is still returned through the same one-shot capital
		# request.  The return deadline prevents a rejected request from being
		# retried forever.
		return_to_capital();
	}
	return 0;
}

sub enter_search_mode {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	my ($search_ok, $search_reason) = _validate_search_targets($rule);
	return 1 if !_uses_search_mode($rule);
	unless ($search_ok) {
		warning "[LastROActivity] Event '$rule->{event_id}' cannot enter shared search mode: $search_reason.\n";
		return 0;
	}

	my $snapshot = eval {
		LastROActivity::State::apply_activity_config(\%Globals::config, $teleport_idle);
	};
	if ($@ || ref($snapshot) ne 'HASH') {
		warning "[LastROActivity] Unable to snapshot activity config: " . ($@ || 'invalid snapshot') . "\n";
		return 0;
	}
	$active_snapshot = $snapshot;
	return 1;
}

sub request_event_entry {
	my ($rule, $event) = @_;
	return 0 unless ref($rule) eq 'HASH';
	my $map = _event_map($rule, $event || $active_event);
	return 0 unless defined $map;
	my $entry_type = lc(_trim($rule->{entry_type} || 'privateairship'));
	if ($entry_type eq 'airship' || $entry_type eq 'privateairship') {
		my (undef, $item_error) = _airship_item_id($rule);
		die "$item_error\n" if defined $item_error;
		$active_event->{airship_entry_attempts} =
			($active_event->{airship_entry_attempts} || 0) + 1
			if defined $active_event && ref($active_event) eq 'HASH';
		_set_pending_destination($map, 'entry', $rule)
			or die "invalid pending activity destination\n";
		my ($command_ok, $command_error) = _run_checked_command("privateairship $map");
		unless ($command_ok) {
			_clear_pending_destination();
			$command_error = 'privateairship command failed'
				unless defined $command_error && $command_error ne '';
			die "$command_error\n";
		}
		return 1;
	}
	if ($entry_type eq 'macro') {
		my ($macro, $macro_error) = _configured_macro($rule, 'entry_macro');
		die "$macro_error\n" if defined $macro_error;
		die "entry_macro is required for macro entry\n" unless defined $macro;
		my $has_active = defined $active_event;
		_launch_activity_macro($macro, 'entry', $rule)
			or die "entry macro '$macro' could not start\n";
		$active_event->{entry_macro_started} = 1 if $has_active
			&& ref($active_event) eq 'HASH';
		# Direct callers can use request_event_entry as a command-level API without
		# adopting a lifecycle marker.  A real begin_activity call keeps the
		# pending marker so mainLoop_pre can observe completion.
		_clear_pending_macro() unless $has_active;
		$entry_transfer_accepted = 1 if $has_active;
		return 1;
	}
	if ($entry_type eq 'npc') {
		my $sequence = _npc_sequence($rule->{entry_npc});
		die "entry_npc must include a safe TalkNPC sequence\n"
			unless defined $sequence;
		my $x = $rule->{entry_x};
		my $y = $rule->{entry_y};
		die "entry coordinates are invalid\n"
			unless defined $x && defined $y && "$x" =~ /^\d+\z/ && "$y" =~ /^\d+\z/;
		my ($ok, $error) = _run_checked_command(
			"talknpc $x $y $sequence",
			verify_npc => 1,
		);
		die (($error || 'talknpc command failed') . "\n") unless $ok;
		$entry_transfer_accepted = 1 if defined $active_event;
		return 1;
	}
	return 0;
}

sub _start_due_event {
	my ($event) = @_;
	return 0 unless _event_can_start($event);
	return 0 if defined $active_event;

	return begin_activity($event->{rule}, $event);
}

sub _actor_value {
	my ($actor, $key) = @_;
	return undef unless defined $actor && defined $key;
	my ($value, $found);
	my $read_ok = eval {
		if (ref($actor) && exists $actor->{$key}) {
			$value = $actor->{$key};
			$found = 1;
		}
		1;
	};
	return $value if $read_ok && $found;
	return undef;
}

sub _actor_is_dead {
	my ($actor) = @_;
	return 0 unless defined $actor;
	for my $key (qw(dead isDead)) {
		my $value = _actor_value($actor, $key);
		return 1 if defined $value && "$value" =~ /^\s*1\s*\z/;
	}
	if (ref($actor) ne 'HASH') {
		my ($value, $ok);
		$ok = eval {
			$value = $actor->isDead() if $actor->can('isDead');
			1;
		};
		return 1 if $ok && defined $value && $value;
	}
	return 0;
}

sub _actor_skill_level {
	my ($actor, $handle) = @_;
	return 0 unless defined $actor && defined $handle;
	my $skills = _actor_value($actor, 'skills');
	if (ref($skills) eq 'HASH') {
		for my $key (keys %$skills) {
			next unless defined $key && uc($key) eq uc($handle);
			my $entry = $skills->{$key};
			my $level = ref($entry) eq 'HASH' ? $entry->{lv} : $entry;
			return 0 + $level if defined $level && "$level" =~ /^\s*\d+(?:\.\d+)?\s*\z/ && $level > 0;
		}
	}
	if (ref($actor) ne 'HASH') {
		for my $method (qw(getSkillLevelByHandle getSkillLevel)) {
			my ($level, $ok) = (0, 0);
			$ok = eval {
				$level = $actor->$method($handle);
				1;
			};
			return 0 + $level if $ok && defined $level
				&& "$level" =~ /^\s*\d+(?:\.\d+)?\s*\z/ && $level > 0;
		}
	}
	return 0;
}

sub _actor_resurrection_skill {
	my ($actor) = @_;
	return (0, 0) unless defined $actor;

	my $skills = _actor_value($actor, 'skills');
	if (ref($skills) eq 'HASH') {
		for my $key (keys %$skills) {
			next unless defined $key && uc($key) eq 'ALL_RESURRECTION';
			my $entry = $skills->{$key};
			my $level = ref($entry) eq 'HASH' ? $entry->{lv} : $entry;
			return (1, 1)
				if defined $level
				&& "$level" =~ /^\s*\d+(?:\.\d+)?\s*\z/
				&& $level > 0;
			return (1, 0);
		}
	}

	if (ref($actor) ne 'HASH') {
		for my $method (qw(getSkillLevelByHandle getSkillLevel)) {
			my ($level, $ok) = (undef, 0);
			$ok = eval {
				$level = $actor->$method('ALL_RESURRECTION');
				1;
			};
			return (1, 1)
				if $ok && defined $level
				&& "$level" =~ /^\s*\d+(?:\.\d+)?\s*\z/
				&& $level > 0;
			# OpenKore's skill lookup returns zero for an absent skill as well
			# as an explicitly unlearned one. Only a positive lookup is enough
			# to override job metadata; zero must still allow Priest fallback.
		}
	}

	return (0, 0);
}

sub _actor_job_name {
	my ($actor) = @_;
	return undef unless defined $actor;
	for my $key (qw(job_name job class)) {
		my $value = _actor_value($actor, $key);
		return $value if defined $value && !ref($value) && _trim($value) ne '';
	}
	my $job_id = _actor_value($actor, 'jobID');
	if (defined $job_id && exists $Globals::jobs_lut{$job_id}) {
		return $Globals::jobs_lut{$job_id};
	}
	if (ref($actor) ne 'HASH') {
		my ($value, $ok);
		$ok = eval {
			$value = $actor->job() if $actor->can('job');
			1;
		};
		return $value if $ok && defined $value && !ref($value) && _trim($value) ne '';
	}
	return undef;
}

sub _actor_can_resurrect {
	my ($actor) = @_;
	return 0 unless defined $actor;
	my ($skill_present, $skill_capable) = _actor_resurrection_skill($actor);
	return $skill_capable if $skill_present;
	for my $key (qw(resurrection_capable can_resurrect)) {
		my $value = _actor_value($actor, $key);
		return 1 if defined $value && "$value" =~ /^\s*1\s*\z/;
	}
	my $job = _actor_job_name($actor);
	return 0 unless defined $job;
	# Acolyte is intentionally excluded: only jobs that are known to provide
	# Resurrection are treated as an immediate-abandon trigger.
	return 1 if $job =~ /(?:\b(?:high\s+)?priest\b|\b(?:baby|arc|arch)\s*bishop\b|\b(?:baby|arc|arch)bishop\b|\bcardinal\b|牧师|牧師|祭司|大主教|主教|神官|枢机|樞機)/i;
	return 0;
}

sub _party_members {
	my ($char) = @_;
	return () unless defined $char;
	my $party = _actor_value($char, 'party');
	return () unless ref($party) eq 'HASH';
	my $users = $party->{users};
	return () unless defined $users;
	return values %$users if ref($users) eq 'HASH';
	return @$users if ref($users) eq 'ARRAY';
	return ();
}

sub _poll_activity_death {
	my ($now) = @_;
	return undef unless defined $active_event && ref($active_event) eq 'HASH';
	return undef unless _round_mode($active_event->{rule});
	return undef if $return_pending;
	return undef unless ref($state) eq 'LastROActivity::State';
	my $state_name = $state->state;
	# Death records are meaningful only once the destination map has been
	# confirmed and combat is actually running. Polling during entry/finish can
	# mistake stale party state for a death in the current activity.
	return undef unless $state_name eq 'RUNNING';
	return undef unless defined $activity_started_at;
	$now = _now() unless defined $now;

	my $char = $Globals::char;
	return undef unless defined $char;
	for my $member (_party_members($char)) {
		my $online = _actor_value($member, 'online');
		next if defined $online && !$online;
		my $dead_time = _actor_value($member, 'dead_time');
		next if defined $activity_started_at
			&& defined $dead_time
			&& "$dead_time" =~ /^\s*\d+(?:\.\d+)?\s*\z/
			&& $dead_time < $activity_started_at;
		next unless defined $member && _actor_is_dead($member);
		if (_actor_can_resurrect($member)) {
			my $name = _actor_value($member, 'name') || 'resurrection-capable party member';
			_mark_activity_failed("$name died during activity");
			return 'fail';
		}
	}

	if (_actor_is_dead($char)) {
		if (_actor_can_resurrect($char)) {
			_mark_activity_failed('resurrection-capable output character died');
			return 'fail';
		}
		$activity_self_dead_at = $now unless defined $activity_self_dead_at;
		$active_event->{self_dead_at} = $activity_self_dead_at;
		my $wait_until = $activity_self_dead_at + _resurrection_wait_seconds($active_event->{rule});
		$active_event->{self_dead_wait_until} = $wait_until;
		if ($now >= $wait_until) {
			_mark_activity_failed('output character remained dead past resurrection wait');
			return 'fail';
		}
		return 'wait';
	}

	if (defined $activity_self_dead_at) {
		$activity_self_dead_at = undef;
		delete $active_event->{self_dead_at};
		delete $active_event->{self_dead_wait_until};
	}
	return undef;
}

sub onMainLoopPre {
	my $args = _hook_args(@_);
	return unless _ensure_initialized();

	my $now = _now($args);
	my $death_result = _poll_activity_death($now);
	return if defined $death_result;
	if ($enabled) {
		my $due = eval { $scheduler->due($now) };
		if ($@) {
			warning "[LastROActivity] Could not check due activities: $@\n";
			$due = [];
		}
		push @pending_due, @$due if ref($due) eq 'ARRAY';
		push @pending_due, splice(@pending_manual);
	}

	# This is deliberately the only call site that starts a due event.  The
	# state-machine implementation is filled in by the interruption task.
	if (@pending_due && !defined $active_event) {
		my $event = shift @pending_due;
		_start_due_event($event);
	}

	_advance_state_machine_one_action($now);
}

sub _advance_pending_leave_npc {
	my ($now) = @_;
	return 0 unless ref($pending_leave_npc) eq 'HASH';

	my ($queued, $error) = _observe_npc_queue();
	unless (defined $queued) {
		_clear_pending_leave_npc();
		_mark_activity_failed(
			$error && $error ne ''
				? "unable to observe leave NPC queue: $error"
				: 'unable to observe leave NPC queue',
		);
		return 1;
	}

	my ($task_outcome, $task_error) = ('unknown', undef);
	if (defined $pending_leave_npc->{task}) {
		($task_outcome, $task_error) = _npc_task_outcome($pending_leave_npc->{task});
		if ($task_outcome eq 'failure') {
			_clear_pending_leave_npc();
			_mark_activity_failed($task_error || 'leave NPC task failed');
			return 1;
		}
	}

	if ($queued) {
		my ($current_task, $current_index) = _npc_queue_task();
		unless (defined $current_task) {
			_clear_pending_leave_npc();
			_mark_activity_failed('leave NPC task disappeared while queued');
			return 1;
		}
		my $current_id = _npc_task_identity($current_task);
		unless (defined $current_id
			&& defined $pending_leave_npc->{task_id}
			&& "$current_id" eq "$pending_leave_npc->{task_id}") {
			_clear_pending_leave_npc();
			_mark_activity_failed('leave NPC task was replaced while queued');
			return 1;
		}
		if (defined $pending_leave_npc->{deadline}
			&& $now >= $pending_leave_npc->{deadline}) {
			_clear_pending_leave_npc();
			_mark_activity_failed('leave NPC dialog timed out');
			return 1;
		}
		return 1;
	}

	if (defined $pending_leave_npc->{task}) {
		unless ($task_outcome eq 'success') {
			_clear_pending_leave_npc();
			_mark_activity_failed(
				$task_error || 'leave NPC task completion was not observed',
			);
			return 1;
		}
	}

	unless ($pending_leave_npc->{seen}) {
		_clear_pending_leave_npc();
		_mark_activity_failed('leave NPC queue completion was not observed');
		return 1;
	}

	_clear_pending_leave_npc();
	$active_event->{leave_npc_complete} = 1
		if ref($active_event) eq 'HASH';
	return_to_capital();
	return 1;
}

sub _advance_state_machine_one_action {
	my ($now) = @_;
	$now = _now() unless defined $now;

	if (defined $pending_leave_npc) {
		_advance_pending_leave_npc($now);
		return;
	}

	if (defined $active_event
		&& $entry_map_confirmed
		&& _entry_transfer_ready()
		&& !defined $pending_macro
		&& ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'ENTERING') {
		# Confirmation flags can outlive a map packet.  Re-read the live field
		# before promoting the activity so a departure cannot become RUNNING
		# after the character has already left the event map.
		return unless _set_running_state($now);
	}

	if (defined $pending_macro) {
		if (defined $pending_macro_error && $pending_macro_error ne '') {
			_finish_entry_macro(0, $pending_macro_error);
		} else {
			my $queue = _macro_queue();
			if (defined $queue) {
				my $name = _macro_queue_name($queue);
				if (!defined $name || $name eq $pending_macro) {
					$pending_macro_seen = 1;
					_finish_entry_macro(1) if _macro_queue_finished($queue);
				}
			} elsif ($pending_macro_seen) {
				_finish_entry_macro(1);
			} elsif (defined $pending_macro_deadline && $now >= $pending_macro_deadline) {
				_finish_entry_macro(0, "macro '$pending_macro' timed out");
			}
		}
	}

	checkActivityTimeout($now);
	return;
}

sub begin_activity {
	my ($rule, $scheduled_event) = @_;
	return 0 unless ref($scheduled_event) eq 'HASH';
	if (defined $active_event) {
		my $active_id = ref($active_event) eq 'HASH' ? $active_event->{event_id} : undef;
		my $incoming_id = $scheduled_event->{event_id};
		return 1 if defined $active_id && defined $incoming_id && $active_id eq $incoming_id;
		return 0;
	}
	my $reason = _activity_entry_validation($rule, $scheduled_event);
	if (defined $reason) {
		my $cleanup_ok = cleanup_and_restore("validation failure for '$scheduled_event->{event_id}'");
		if ($cleanup_ok) {
			$last_failure = $reason;
		} else {
			my $restore_failure = $last_failure || 'config restoration failed';
			$last_failure = "$reason; $restore_failure";
		}
		warning "[LastROActivity] Event '$scheduled_event->{event_id}' cannot start: $reason.\n";
		return 0;
	}

	$active_event = $scheduled_event unless defined $active_event;
	$armed_event = $scheduled_event;
	$active_snapshot = undef;
	$activity_started_at = undef;
	$activity_entry_started_at = _now();
	$activity_phase_index = undef;
	$activity_phase_started_at = undef;
	$activity_round_count = 0;
	$activity_round_started_at = undef;
	$activity_self_dead_at = undef;
	$pending_leave_npc = undef;
	$airship_failure_count = 0;
	$scheduled_event->{round_count} = 0;
	$scheduled_event->{round} = 0;
	$scheduled_event->{round_started} = 0;
	$scheduled_event->{round_success_seen} = 0;
	$scheduled_event->{round_start_message} = undef;
	$scheduled_event->{round_start_at} = undef;
	$scheduled_event->{round_identity} = undef;
	$scheduled_event->{round_identities_seen} = {};
	$scheduled_event->{round_identity_unknown_completed} = 0;

	my $ok = eval {
		if ($state->state eq 'IDLE') {
			$state->transition('arm');
		} elsif ($state->state eq 'RESUMED' || $state->state eq 'FAILED') {
			$state = LastROActivity::State->new;
			$state->transition('arm');
		}
		$state->transition('trigger') if $state->state eq 'ARMED';
		die "invalid activity state " . $state->state . "\n"
			unless $state->state eq 'INTERRUPTING';
		activity_lock(1);
		clear_normal_ai();
		enter_search_mode($rule)
			or die "unable to enter shared search mode\n";
		$state->transition('snapshot');
		$state->transition('depart');
		request_event_entry($rule, $scheduled_event)
			or die "unable to request event entry\n";
		1;
	};
	if (!$ok) {
		my $failure = _trim($@ || 'activity start failed');
		my $had_activity = defined $active_event;
		if ($had_activity && $activity_lock) {
			# Once the snapshot/lock boundary has been crossed, every failure uses
			# the same return path as a runtime failure.  Validation failures above
			# occur before this boundary and can clean up synchronously.
			_mark_activity_failed($failure);
		} else {
			my $cleanup_ok = cleanup_and_restore("start failure for '$scheduled_event->{event_id}'");
			if ($cleanup_ok) {
				$last_failure = $failure;
			} else {
				my $restore_failure = $last_failure || 'config restoration failed';
				$last_failure = "$failure; $restore_failure";
			}
		}
		warning "[LastROActivity] Event '$scheduled_event->{event_id}' failed to start: $failure\n";
		return 0;
	}
	$last_failure = undef;
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
		_ensure_initialized();
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
		if ($subcommand eq 'off') {
			_disable_scheduling();
		} else {
			$enabled = 1;
		}
		message "[LastROActivity] scheduling " . ($enabled ? 'enabled' : 'disabled') . ".\n";
		return 1;
	}

	if ($subcommand eq 'run' && @parts == 1) {
		return 0 unless _ensure_initialized();
		return _manual_run($parts[0]);
	}

	if ($subcommand eq 'stop' && !@parts) {
		return _stop_active_activity('manual stop');
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

sub _restore_active_snapshot {
	return 1 unless defined $active_snapshot;

	my $snapshot = $active_snapshot;
	my $restored;
	my $ok = eval {
		$restored = LastROActivity::State::restore_config(\%Globals::config, $snapshot);
		1;
	};
	if ($ok && defined $restored) {
		$active_snapshot = undef;
		return 1;
	}

	my $failure = _trim($@ || 'config restoration failed');
	$last_failure = "config restoration failed: $failure";
	warning "[LastROActivity] Unable to restore activity config: $failure\n";
	return 0;
}

sub _record_cleanup_failure {
	my ($failure) = @_;
	$failure = _trim($failure);
	$failure = 'activity cleanup failed' if $failure eq '';
	if (!defined $last_failure || $last_failure eq '') {
		$last_failure = $failure;
	} elsif (index($last_failure, $failure) < 0) {
		$last_failure .= "; $failure";
	}
	warning "[LastROActivity] $failure\n";
	return 0;
}

sub cleanup_and_restore {
	my ($reason) = @_;
	# Cleanup can be reached from a command, a map hook, a timeout, and an
	# airship result in the same turn.  Once the first caller owns the finalizer,
	# every later caller is a harmless no-op.
	return 1 if $cleanup_in_progress;
	my $has_lifecycle = defined $active_event
		|| defined $active_snapshot
		|| $activity_lock
		|| $return_pending;
	my $has_scheduled = defined $armed_event || @pending_due || @pending_manual;
	return 1 unless $has_lifecycle || $has_scheduled;
	$cleanup_in_progress = 1;
	my $cleanup_ok = 1;

	# Each stage is isolated so a failing plugin callback cannot skip snapshot
	# restoration or the final lock release.  False return values are failures
	# too, while undef remains compatible with OpenKore APIs that signal success
	# by completing without a value.
	my $run_stage = sub {
		my ($label, $callback) = @_;
		my ($result, $exception);
		my $ok = eval {
			$result = $callback->();
			1;
		};
		$exception = _trim($@ || "$label failed") unless $ok;
		if (!$ok || (defined $result && !$result)) {
			$cleanup_ok = 0;
			_record_cleanup_failure($exception || "$label failed");
			return 0;
		}
		return 1;
	};

	if (defined $armed_event && defined $armed_event->{event_id}) {
		$run_stage->('unable to cancel scheduled activity', sub {
			# A due event has already been removed from the scheduler; cancellation
			# is therefore idempotent and a false return is not a cleanup failure.
			$scheduler->cancel($armed_event->{event_id});
			return 1;
		});
	}
	if ($has_lifecycle && defined $active_event
		&& !$active_event->{activity_ai_cleared}) {
		$active_event->{activity_ai_cleared} = 1;
		$run_stage->('activity AI cleanup failed', sub { return clear_activity_ai(); });
	}

	my $restore_ok;
	my $restore_exception;
	my $restore_eval = eval {
		$restore_ok = _restore_active_snapshot();
		1;
	};
	$restore_exception = _trim($@ || 'config restoration failed') unless $restore_eval;
	if (!$restore_eval || !$restore_ok) {
		$cleanup_ok = 0;
		_record_cleanup_failure($restore_exception || 'config restoration failed');
		# Restoration has been attempted and failed; discard the stale snapshot so
		# a duplicate cleanup cannot replay side effects indefinitely.
		$active_snapshot = undef;
	}

	# The final AI clear is intentionally after restoration.  It is independent
	# of the activity-specific clear above and must still run after any exception.
	if ($has_lifecycle) {
		$run_stage->('AI clear failed', sub { return AI::clear(); });
	}

	# These assignments are deliberately outside the guarded stages: they form
	# the exception-safe finalization boundary for every cleanup attempt.
	@pending_due = ();
	@pending_manual = ();
	my ($pending_exception, $pending_ok) = ('', 1);
	for my $clearer (
		['pending destination', \&_clear_pending_destination],
		['pending macro', \&_clear_pending_macro],
		['pending leave NPC', \&_clear_pending_leave_npc],
	) {
		my ($label, $callback) = @$clearer;
		my $ok = eval { $callback->(); 1 };
		unless ($ok) {
			$pending_ok = 0;
			$pending_exception = _trim($@ || "$label cleanup failed");
			_record_cleanup_failure($pending_exception);
		}
	}
	$cleanup_ok = 0 unless $pending_ok;
	$activity_started_at = undef;
	$activity_entry_started_at = undef;
	$activity_phase_index = undef;
	$activity_phase_started_at = undef;
	$activity_round_count = 0;
	$activity_round_started_at = undef;
	$activity_self_dead_at = undef;
	$pending_leave_npc = undef;
	$airship_failure_count = 0;
	$active_event = undef;
	$armed_event = undef;
	$state = LastROActivity::State->new;
	# This is the sole production release of the activity lock.  Fall back to a
	# direct assignment if a host callback has replaced activity_lock and throws.
	my $lock_ok = eval { activity_lock(0); 1 };
	unless ($lock_ok) {
		$cleanup_ok = 0;
		_record_cleanup_failure(_trim($@ || 'activity lock release failed'));
		$activity_lock = 0;
	}
	$cleanup_in_progress = 0;
	return $cleanup_ok;
}

sub _stop_active_activity {
	my ($reason) = @_;
	return cleanup_and_restore($reason) unless defined $active_event;
	$active_event->{finish_reason} = _trim($reason)
		if ref($active_event) eq 'HASH' && defined $reason;
	_clear_pending_macro();
	_clear_pending_leave_npc();
	unless ($active_event->{activity_ai_cleared}) {
		$active_event->{activity_ai_cleared} = 1;
		_try_clear_activity_ai('activity stop cleanup');
	}
	return return_to_capital();
}

sub _complete_round_limit {
	my ($reason) = @_;
	return 1 unless defined $active_event;
	return 1 if $return_pending;
	$reason = _trim($reason || 'maximum activity rounds completed');
	$active_event->{finish_reason} = $reason
		if ref($active_event) eq 'HASH';

	# Round completion owns a distinct leave path.  Stop combat before touching
	# the NPC so an attack task cannot race the reward dialog.
	_transition_to_finishing();
	if (ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'FINISHING'
		&& !$active_event->{activity_ai_cleared}) {
		$active_event->{activity_ai_cleared} = 1;
		_try_clear_activity_ai('round-limit activity cleanup');
	}

	my $rule = ref($active_event->{rule}) eq 'HASH' ? $active_event->{rule} : {};
	my ($leave_ok, $leave_error) = _validate_leave_npc($rule);
	unless ($leave_ok) {
		# Missing or untrusted evidence is a normal fail-closed outcome: return to
		# capital, but never synthesize a coordinate or dialog sequence.
		_mark_activity_failed($leave_error || 'trusted leave NPC evidence is required');
		return 0;
	}

	my $sequence = _npc_sequence($rule->{leave_npc});
	my ($command_ok, $command_error) = _run_checked_command(
		"talknpc $rule->{leave_x} $rule->{leave_y} $sequence",
		verify_npc => 1,
	);
	unless ($command_ok) {
		_mark_activity_failed($command_error || 'leave NPC command failed');
		return 0;
	}
	$active_event->{leave_npc_started} = 1;
	if (defined &AI::inQueue) {
		my ($queued, $queue_error) = _observe_npc_queue();
		unless (defined $queued && $queued) {
			_mark_activity_failed(
				$queue_error && $queue_error ne ''
					? "leave NPC queue was not confirmed: $queue_error"
					: 'leave NPC queue was not confirmed',
			);
			return 0;
		}
		my ($task, $task_index) = _npc_queue_task();
		unless (defined $task) {
			_mark_activity_failed('leave NPC task could not be observed');
			return 0;
		}
		my $task_id = _npc_task_identity($task);
		unless (defined $task_id) {
			_mark_activity_failed('leave NPC task identity could not be observed');
			return 0;
		}
		$pending_leave_npc = {
			seen => 1,
			task => $task,
			task_id => $task_id,
			task_index => $task_index,
			started_at => _now(),
			deadline => _now() + _transfer_timeout($rule),
		};
		$active_event->{leave_npc_pending} = 1;
		return 1;
	}
	# Hosts without AI::inQueue cannot expose asynchronous queue state.  Keep
	# the historical command-level fallback for those minimal integrations.
	return return_to_capital();
}

sub finish_activity {
	my ($reason) = @_;
	return 1 unless defined $active_event;
	return 1 if $return_pending;
	# A second finish signal must not bypass a configured finish macro that is
	# still running; its completion callback owns the return request.
	return 1 if defined $pending_macro
		&& ($pending_macro_stage || '') eq 'finish';

	$active_event->{finish_reason} = _trim($reason)
		if ref($active_event) eq 'HASH' && defined $reason;
	_transition_to_finishing();
	if (ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'FINISHING'
		&& !$active_event->{finish_started}) {
		$active_event->{finish_started} = 1;
		unless ($active_event->{activity_ai_cleared}) {
			$active_event->{activity_ai_cleared} = 1;
			_try_clear_activity_ai('activity finish cleanup');
		}

		my $rule = $active_event->{rule};
		my ($finish_macro, $macro_error) = _configured_macro($rule, 'finish_macro');
		if (defined $macro_error) {
			_mark_activity_failed($macro_error);
			return 0;
		}
		if (defined $finish_macro && !$active_event->{finish_macro_complete}) {
			unless (_launch_activity_macro($finish_macro, 'finish', $rule)) {
				_mark_activity_failed("finish macro '$finish_macro' could not start");
				return 0;
			}
			return 1;
		}
	}

	return return_to_capital();
}

sub return_to_capital {
	return 0 unless defined $active_event;
	return 1 if $return_pending;
	return 1 if defined $pending_macro
		&& ($pending_macro_stage || '') eq 'finish';

	_transition_to_finishing();
	if (ref($state) eq 'LastROActivity::State' && $state->state eq 'FINISHING') {
		unless ($active_event->{activity_ai_cleared}) {
			$active_event->{activity_ai_cleared} = 1;
			_try_clear_activity_ai('return preparation');
		}
		_transition_state('return');
	}

	_clear_pending_destination();
	_clear_pending_macro();
	_clear_pending_leave_npc();
	my $rule = ref($active_event->{rule}) eq 'HASH' ? $active_event->{rule} : undef;
	_set_pending_destination('prontera', 'return', $rule)
		or return 0;

	my ($ok, $error) = _run_checked_command('privateairship prontera');
	unless ($ok) {
		$error = 'privateairship return command failed'
			unless defined $error && $error ne '';
		# Keep the lifecycle in the return state even when the command is rejected.
		# A later map packet is the only ordinary proof that makes restoration safe.
		_mark_activity_failed($error);
		warning "[LastROActivity] Unable to return to prontera: $error.\n";
		return 0;
	}
	return 1;
}

sub _complete_return {
	return 1 unless defined $active_event || defined $active_snapshot || $return_pending;
	return cleanup_and_restore('return confirmed');
}

sub _confirm_entry_map {
	my ($map) = @_;
	return 0 unless defined $active_event;
	return 0 unless ref($state) eq 'LastROActivity::State';
	my $state_name = $state->state;
	return 0 unless $state_name eq 'DEPARTING' || $state_name eq 'ENTERING';

	my $event_map = _event_map($active_event->{rule}, $active_event);
	return 0 unless defined $event_map && _map_matches($map, $event_map);
	if (defined $pending_destination) {
		return 0 unless ($pending_destination_kind || '') eq 'entry';
		return 0 unless _map_matches($map, $pending_destination);
	}
	return 0 if defined $pending_airship_result && $pending_airship_result != 0;

	$active_event->{entry_confirmed} = 1 if ref($active_event) eq 'HASH';
	$entry_map_confirmed = 1;
	# The map packet is authoritative for arrival, but keep both the transfer
	# marker and its deadline until the server result is observed so a late
	# rejection (or a missing result) cannot silently turn into a running
	# activity.
	_transition_state('enter') if $state_name eq 'DEPARTING';

	return 0 unless _maybe_start_entry_macro();

	# If the result arrived before the map packet, both sides are now known and
	# the marker can be retired.  A nonzero result was rejected above.
	_clear_entry_transfer()
		if defined $pending_destination
		&& ($pending_destination_kind || '') eq 'entry'
		&& defined $pending_airship_result
		&& $pending_airship_result == 0;
	return 1;
}

sub onMapChange {
	my $args = _hook_args(@_);
	my $map = _current_map($args);
	return 0 unless defined $map;
	return 0 unless defined $active_event;

	if (($return_pending
			|| (ref($state) eq 'LastROActivity::State' && $state->state eq 'RETURNING'))
		&& _map_matches($map, 'prontera')) {
		return _complete_return();
	}

	if (_confirm_entry_map($map)) {
		return 1;
	}

	if (ref($state) eq 'LastROActivity::State'
		&& ($state->state eq 'DEPARTING' || $state->state eq 'ENTERING')) {
		my $event_map = _event_map($active_event->{rule}, $active_event);
		if (defined $event_map && !_map_matches($map, $event_map)) {
			_mark_activity_failed('left activity map before entry completed');
			return 1;
		}
	}

	if (ref($state) eq 'LastROActivity::State' && $state->state eq 'RUNNING') {
		my $event_map = _event_map($active_event->{rule}, $active_event);
		if (defined $event_map && !_map_matches($map, $event_map)) {
			# Leaving the event map is an operational failure, not a successful
			# completion.  Route through the failure path so finish macros cannot
			# run and the diagnostic survives the return cleanup.
			_mark_activity_failed('left activity map');
			return 1;
		}
	}
	return 0;
}

sub onAirshipResult {
	my $args = _hook_args(@_);
	return 0 unless ref($args) eq 'HASH' && defined $args->{type};
	return 0 unless defined $active_event;
	# Results are broadcast globally.  Only consume one while this plugin has
	# an outstanding transfer marker; an ENTERING/RETURNING state alone cannot
	# establish that the packet belongs to this activity.
	return 0 unless defined $pending_destination;
	my $type = $args->{type};
	return 0 unless "$type" =~ /^\s*\d+\s*\z/;
	$type = 0 + $type;
	if ($type == 0) {
		$pending_airship_result = 0;
		$entry_transfer_accepted = 1
			if ($pending_destination_kind || '') eq 'entry';
		if (($pending_destination_kind || '') eq 'entry' && $entry_map_confirmed) {
			return 0 unless _maybe_start_entry_macro();
		}
		_clear_entry_transfer()
			if defined $pending_destination
			&& ($pending_destination_kind || '') eq 'entry'
			&& $entry_map_confirmed;
		return 1;
	}

	my %reasons = (
		1 => 'Private Airship request was rejected; please try again',
		2 => 'You do not have enough Private Airship items',
		3 => 'destination map is invalid',
		4 => 'source map is invalid',
		5 => 'wrong item for Private Airship',
	);
	my $reason = $reasons{$type} || "unknown Private Airship result code $type";
	$airship_failure_count++ if $type != 0;
	$pending_airship_result = $type;
	my $destination_kind = $pending_destination_kind || '';
	if ($destination_kind eq 'entry') {
		my $entry_state = ref($state) eq 'LastROActivity::State'
			&& ($state->state eq 'DEPARTING' || $state->state eq 'ENTERING');
		my $can_retry = $entry_state
			&& !$entry_map_confirmed
			&& $airship_failure_count < 3;
		if ($can_retry) {
			# A rejected entry is retried in the same lifecycle slot.  Retrying is
			# deliberately bounded to three total attempts, and only applies while
			# the activity is still entering; late packets in RUNNING are failures.
			my $retry_map = $pending_destination;
			my $retry_rule = ref($active_event) eq 'HASH'
				? $active_event->{rule} : undef;
			_clear_pending_destination();
			$entry_map_confirmed = 0;
			$entry_transfer_accepted = 0;
			my ($retry_ok, $retry_error);
			$retry_ok = eval {
				request_event_entry($retry_rule, $active_event);
				1;
			};
			$retry_error = _trim($@ || 'entry retry failed') unless $retry_ok;
			if (!$retry_ok) {
				_mark_activity_failed($retry_error);
				return 0;
			}
			return 1;
		}
		_clear_pending_destination();
	}
	_mark_activity_failed($reason);
	return 0;
}

sub onMacroError {
	my $args = _hook_args(@_);
	return 0 unless defined $pending_macro;
	return 0 unless ref($args) eq 'HASH';
	my $name = $args->{name};
	return 0 unless _macro_error_belongs_to_pending($name);
	my $reason = $args->{error} || $args->{message} || "macro '$pending_macro' failed";
	$pending_macro_error = _trim($reason)
		if !defined $pending_macro_error || $pending_macro_error eq '';
	return 0;
}

sub onAIStateChange {
	return;
}

sub onReload {
	return onUnload();
}

sub onUnload {
	my $cleanup_ok;
	if (defined $active_event) {
		$cleanup_ok = _stop_active_activity('plugin unload');
		# Plugin teardown removes the map hook immediately, so an outstanding
		# return cannot be confirmed.  Record that exceptional condition and use
		# the common emergency finalizer to restore the snapshot and release the
		# lock.  This is explicitly a failed/unconfirmed unload, never a success.
		if ($return_pending || defined $active_event || defined $active_snapshot) {
			my $reason = 'plugin unload: return to prontera was not confirmed';
			$last_failure = $reason unless defined $last_failure && $last_failure ne '';
			warning "[LastROActivity] $reason; performing emergency cleanup.\n";
			my $emergency_ok = cleanup_and_restore('emergency plugin unload cleanup');
			$cleanup_ok = 0 unless $emergency_ok;
			$cleanup_ok = 0;
		}
	} else {
		$cleanup_ok = cleanup_and_restore('plugin unload');
	}
	if (defined $rules_file_handle) {
		_remove_rule_handle($rules_file_handle);
		$rules_file_handle = undef;
	}
	eval { Commands::unregister($commands) } if defined $commands;
	eval { Plugins::delHooks($hooks) } if defined $hooks;
	eval { Plugins::delHook($rules_preload_hook) }
		if defined $rules_preload_hook && defined &Plugins::delHook;
	$rules_preload_hook = undef;
	eval { Plugins::delHook($macro_error_hook) }
		if defined $macro_error_hook && defined &Plugins::delHook;
	$macro_error_hook = undef;
	return $cleanup_ok;
}

sub enabled { return $enabled ? 1 : 0; }
sub lead_seconds { return $lead_seconds; }
sub teleport_idle { return $teleport_idle; }
sub state { return $state->state; }
sub scheduler { return $scheduler; }
sub rules { return $rules; }
sub active_event { return $active_event; }
sub armed_event { return $armed_event; }
sub activity_locked { return $activity_lock ? 1 : 0; }
sub last_failure { return $last_failure; }
sub rules_file { return $rules_file || $rules_requested; }

1;
