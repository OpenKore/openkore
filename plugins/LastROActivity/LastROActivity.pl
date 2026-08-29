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
our $return_pending;
our $entry_map_confirmed;
our $entry_transfer_accepted;
our $activity_started_at;
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
$return_pending = 0;
$entry_map_confirmed = 0;
$entry_transfer_accepted = 0;
$activity_started_at = undef;

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
	if (ref($scheduler) && $scheduler->can('clear')) {
		eval { $scheduler->clear(); 1 } or warning "[LastROActivity] Unable to clear scheduled activities: $@\n";
	}
	@pending_due = ();
	@pending_manual = ();
	$armed_event = undef;
	$state = LastROActivity::State->new unless defined $active_event;
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

sub _message_matches {
	my ($message, $pattern) = @_;
	return 0 unless defined $message && defined $pattern && $pattern ne '';
	my $matched = eval {
		ref($pattern) eq 'Regexp' ? $message =~ $pattern : $message =~ /$pattern/;
	};
	return (!$@ && $matched) ? 1 : 0;
}

sub _check_finish_message {
	my ($message) = @_;
	return 0 unless defined $active_event && ref($active_event->{rule}) eq 'HASH';
	return 0 unless ref($state) eq 'LastROActivity::State';
	return 0 unless $state->state eq 'RUNNING';
	my $pattern = $active_event->{rule}{finish_regex};
	return 0 unless _message_matches($message, $pattern);
	finish_activity('finish announcement matched');
	return 1;
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
	_check_finish_message($message);
	return _observe_message($message);
}

sub onPublicMessage {
	my $args = _hook_args(@_);
	return undef unless _ensure_initialized();
	my $message = _message_from_args($args);
	_check_finish_message($message);
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

	my $map;
	if (defined $rule->{map_source}
		&& lc(_trim($rule->{map_source})) eq 'dynamic') {
		# A dynamic rule must be backed by map metadata from the matching
		# announcement; silently falling back to a stale configured map would
		# send the character to the wrong activity.
		$map = $event->{data_map}{map}
			if ref($event) eq 'HASH'
			&& ref($event->{data_map}) eq 'HASH';
		return undef unless defined $map && _trim($map) ne '';
	} else {
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
	return undef if $map eq '' || $map =~ /[\s;|&<>"'`]/;
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

sub _macro_name {
	my ($name) = @_;
	$name = _trim($name);
	return undef if $name eq '' || $name =~ /[^A-Za-z0-9_.:-]/;
	return $name;
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

sub _map_is_known {
	my ($map) = @_;
	return 0 unless defined $map && $map ne '';
	my $maps = \%Globals::maps_lut;
	return 1 if defined $maps->{"$map.rsw"};
	return 1 if defined $maps->{"$map.gat"};
	return 1 if defined $maps->{$map};
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

sub _search_row_enabled {
	my ($key) = @_;
	return 0 unless defined $key && $key ne '';
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

	if ($target =~ /^\d+\z/) {
		return 0 if $target == 0;
		my $id = 0 + $target;
		return 1 if _search_row_enabled("$id");
		my $name = $Globals::monsters_lut{"$id"};
		return 0 unless defined $name && !ref($name);
		return _search_row_enabled(lc(_trim($name)));
	}

	my $name_key = lc($target);
	return 1 if _search_row_enabled($name_key);
	my $monsters = \%Globals::monsters_lut;
	for my $id (keys %$monsters) {
		my $name = $monsters->{$id};
		next if !defined $name || ref($name);
		next unless lc(_trim($name)) eq $name_key;
		return 1 if _search_row_enabled("$id") || _search_row_enabled(lc(_trim($name)));
	}
	return 0;
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
	return 'rule is not enabled or validated'
		unless _validated_enabled_rule($rule);
	my ($search_ok, $search_reason) = _validate_search_targets($rule);
	return $search_reason unless $search_ok;
	return 'not connected in game' unless _in_game();

	my $map = _event_map($rule, $event);
	return 'event map is missing' unless defined $map;
	return 'event map name is too long' if length($map) > 16;
	return "event map '$map' is unknown" unless _map_is_known($map);

	my $entry_type = lc(_trim($rule->{entry_type} || 'privateairship'));
	if ($entry_type eq 'airship' || $entry_type eq 'privateairship') {
		my ($ok, $reason) = _inventory_has_airship_item($rule);
		return $reason unless $ok;
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
	my $entry_macro = ref($rule) eq 'HASH' ? _macro_name($rule->{entry_macro}) : undef;
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
	$name = _macro_name($name);
	return 0 unless defined $name;
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
			return 0 unless _confirm_entry_map_for_running();
			_transition_state('running');
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
	$last_failure = $reason;
	warning "[LastROActivity] $reason.\n";

	if (ref($state) eq 'LastROActivity::State'
		&& $state->state ne 'FAILED'
		&& $state->state ne 'IDLE'
		&& $state->state ne 'RESUMED') {
		_transition_state('fail');
	}
	_clear_pending_macro();
	if (defined $active_event && !$return_pending) {
		unless ($active_event->{activity_ai_cleared}) {
			$active_event->{activity_ai_cleared} = 1;
			clear_activity_ai();
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
		_set_pending_destination($map, 'entry', $rule)
			or die "invalid pending activity destination\n";
		my ($requested, $command_error);
		my $command_ok = eval {
			$requested = Commands::run("privateairship $map");
			1;
		};
		$command_error = _trim($@ || 'privateairship command failed') unless $command_ok;
		if (defined $command_error && $command_error ne '') {
			_clear_pending_destination();
			die "$command_error\n";
		}
		if (defined $requested && !$requested) {
			_clear_pending_destination();
			die "privateairship command returned failure\n";
		}
		return 1;
	}
	return 1 if $entry_type eq 'macro' || $entry_type eq 'npc';
	return 0;
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
	return unless _ensure_initialized();
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

	_advance_state_machine_one_action($now);
}

sub _advance_state_machine_one_action {
	my ($now) = @_;
	$now = _now() unless defined $now;

	if (defined $active_event
		&& $entry_map_confirmed
		&& _entry_transfer_ready()
		&& !defined $pending_macro
		&& ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'ENTERING') {
		# Confirmation flags can outlive a map packet.  Re-read the live field
		# before promoting the activity so a departure cannot become RUNNING
		# after the character has already left the event map.
		return unless _confirm_entry_map_for_running();
		_transition_state('running');
	}

	if (defined $pending_macro) {
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

	if (defined $pending_destination
		&& defined $pending_destination_deadline
		&& $now >= $pending_destination_deadline) {
		my $kind = $pending_destination_kind || '';
		if ($kind eq 'return') {
			my $already_failed = ref($state) eq 'LastROActivity::State'
				&& $state->state eq 'FAILED';
			_mark_activity_failed('return to prontera timed out')
				if defined $active_event && !$already_failed;
			_complete_return(1);
		} else {
			_clear_pending_destination();
			_mark_activity_failed('Private Airship entry timed out');
		}
	}

	if (defined $active_event && ref($active_event->{rule}) eq 'HASH'
		&& ref($state) eq 'LastROActivity::State'
		&& $state->state eq 'RUNNING'
		&& defined $activity_started_at
		&& defined $active_event->{rule}{duration_seconds}
		&& "$active_event->{rule}{duration_seconds}" =~ /^\s*\d+(?:\.\d+)?\s*\z/
		&& $active_event->{rule}{duration_seconds} > 0
		&& $now >= $activity_started_at + $active_event->{rule}{duration_seconds}) {
		finish_activity('activity duration expired');
	}
	return;
}

sub begin_activity {
	my ($rule, $scheduled_event) = @_;
	return 0 unless ref($scheduled_event) eq 'HASH';
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
		$activity_started_at = _now();
		1;
	};
	if (!$ok) {
		my $failure = _trim($@ || 'activity start failed');
		my $cleanup_ok = cleanup_and_restore("start failure for '$scheduled_event->{event_id}'");
		if ($cleanup_ok) {
			$last_failure = $failure;
		} else {
			my $restore_failure = $last_failure || 'config restoration failed';
			$last_failure = "$failure; $restore_failure";
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
		$enabled = $subcommand eq 'on' ? 1 : 0;
		message "[LastROActivity] scheduling " . ($enabled ? 'enabled' : 'disabled') . ".\n";
		return 1;
	}

	if ($subcommand eq 'run' && @parts == 1) {
		return 0 unless _ensure_initialized();
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

sub cleanup_and_restore {
	my ($reason) = @_;
	my $cleanup_ok = 1;
	if (defined $armed_event && defined $armed_event->{event_id}) {
		my $cancelled = eval { $scheduler->cancel($armed_event->{event_id}); 1 };
		if (!$cancelled) {
			my $failure = _trim($@ || 'unable to cancel scheduled activity');
			warning "[LastROActivity] Unable to cancel scheduled activity: $failure\n";
			$last_failure = $failure;
			$cleanup_ok = 0;
		}
	}
	$cleanup_ok = 0 unless _restore_active_snapshot();
	@pending_due = ();
	@pending_manual = ();
	_clear_pending_destination();
	_clear_pending_macro();
	$activity_started_at = undef;
	$active_event = undef;
	$armed_event = undef;
	$state = LastROActivity::State->new;
	activity_lock(0);
	return $cleanup_ok;
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
			clear_activity_ai();
		}

		my $rule = $active_event->{rule};
		my $finish_macro = ref($rule) eq 'HASH' ? _macro_name($rule->{finish_macro}) : undef;
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
			clear_activity_ai();
		}
		_transition_state('return');
	}

	_clear_pending_destination();
	_clear_pending_macro();
	my $rule = ref($active_event->{rule}) eq 'HASH' ? $active_event->{rule} : undef;
	_set_pending_destination('prontera', 'return', $rule)
		or return 0;

	my ($result, $error);
	my $ok = eval {
		$result = Commands::run('privateairship prontera');
		1;
	};
	$error = _trim($@ || 'privateairship return command failed') unless $ok;
	if (!$ok || (defined $result && !$result)) {
		$error = 'privateairship return command returned failure'
			if !defined $error || $error eq '';
		$last_failure = $error;
		warning "[LastROActivity] Unable to return to prontera: $error.\n";
		_complete_return(1);
		return 0;
	}
	return 1;
}

sub _complete_return {
	my ($forced) = @_;
	return 1 unless defined $active_event || defined $active_snapshot || $return_pending;

	my $restore_ok = _restore_active_snapshot();
	if (!$restore_ok) {
		# Do not leave a stale snapshot attached to an event that is no longer
		# active; the restoration failure is retained in last_failure.
		$active_snapshot = undef;
	}

	my $ai_ok = eval {
		AI::clear();
		1;
	};
	if (!$ai_ok) {
		my $failure = _trim($@ || 'AI clear failed');
		$last_failure = $failure;
		warning "[LastROActivity] Unable to clear AI after return: $failure\n";
	}

	if (ref($state) eq 'LastROActivity::State' && $state->state eq 'RETURNING') {
		_transition_state('resume');
	} elsif (ref($state) eq 'LastROActivity::State' && $state->state eq 'FAILED') {
		$state = LastROActivity::State->new;
	}

	my $finished_id = ref($active_event) eq 'HASH' ? $active_event->{event_id} : undef;
	_clear_pending_destination();
	_clear_pending_macro();
	$activity_started_at = undef;
	$active_event = undef;
	if (defined $armed_event
		&& (!defined $finished_id || $armed_event->{event_id} eq $finished_id)) {
		$armed_event = undef;
	}
	activity_lock(0);
	return ($restore_ok && $ai_ok) ? 1 : 0;
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
			finish_activity('left activity map');
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
	$pending_airship_result = $type;
	if (($pending_destination_kind || '') eq 'entry') {
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
	my $cleanup_ok = cleanup_and_restore('plugin unload');
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
