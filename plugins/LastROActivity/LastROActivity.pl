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
	return _observe_message(_message_from_args($args));
}

sub onPublicMessage {
	my $args = _hook_args(@_);
	return undef unless _ensure_initialized();
	return _observe_message(_message_from_args($args));
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
	if (ref($rule) eq 'HASH') {
		for my $key (qw(entry_item_id private_airship_item_id airship_item_id entry_item)) {
			my $value = $rule->{$key};
			return 0 + $value if defined $value && $value =~ /^\d+\z/;
		}
	}
	my $master = $Globals::masterServer;
	if (ref($master) eq 'HASH'
		&& defined $master->{privateAirshipItemID}
		&& $master->{privateAirshipItemID} =~ /^\d+\z/) {
		return 0 + $master->{privateAirshipItemID};
	}
	return ref($master) eq 'HASH' && $master->{lastroAirship} ? 14527 : 25464;
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

	my $item_id = _airship_item_id($rule);
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
	return (0, 'Private Airship item is unavailable')
		if ref($item) eq 'HASH'
		&& (!exists $item->{amount} || !defined $item->{amount} || $item->{amount} <= 0);
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

	return 'search_targets evidence is required for shared search mode'
		if _uses_search_mode($rule) && !_search_targets($rule);
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

sub enter_search_mode {
	my ($rule) = @_;
	return 0 unless ref($rule) eq 'HASH';
	return 1 unless _uses_search_mode($rule);
	unless (_search_targets($rule)) {
		warning "[LastROActivity] Event '$rule->{event_id}' has no search_targets evidence; refusing shared search mode.\n";
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
	my $map = _event_map($rule, $event || $active_event);
	return 0 unless defined $map;
	my $entry_type = lc(_trim($rule->{entry_type} || 'privateairship'));
	if ($entry_type eq 'airship' || $entry_type eq 'privateairship') {
		my $requested = eval { Commands::run("privateairship $map") };
		return 0 if $@ || (defined $requested && !$requested);
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

	_advance_state_machine_one_action();
}

sub _advance_state_machine_one_action {
	# Task 4 owns the loop boundary; later lifecycle tasks add one transition
	# here at a time.  Keeping this no-op makes early timers remain ARMED.
	return;
}

sub begin_activity {
	my ($rule, $scheduled_event) = @_;
	return 0 unless ref($scheduled_event) eq 'HASH';
	my $reason = _activity_entry_validation($rule, $scheduled_event);
	if (defined $reason) {
		$last_failure = $reason;
		warning "[LastROActivity] Event '$scheduled_event->{event_id}' cannot start: $reason.\n";
		$active_event = undef if defined $active_event
			&& (!defined $active_event->{event_id}
				|| $active_event->{event_id} eq ($scheduled_event->{event_id} || ''));
		$armed_event = undef if !defined $active_event;
		$state = LastROActivity::State->new
			if !defined $active_event && ref($state) eq 'LastROActivity::State';
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
		1;
	};
	if (!$ok) {
		my $failure = $@ || 'activity start failed';
		$last_failure = _trim($failure);
		warning "[LastROActivity] Event '$scheduled_event->{event_id}' failed to start: $failure";
		if (defined $active_snapshot) {
			eval { LastROActivity::State::restore_config(\%Globals::config, $active_snapshot) };
		}
		activity_lock(0);
		$active_snapshot = undef;
		$active_event = undef;
		$armed_event = undef;
		$state = LastROActivity::State->new;
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
	activity_lock(0);
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
		_remove_rule_handle($rules_file_handle);
		$rules_file_handle = undef;
	}
	eval { Commands::unregister($commands) } if defined $commands;
	eval { Plugins::delHooks($hooks) } if defined $hooks;
	eval { Plugins::delHook($rules_preload_hook) }
		if defined $rules_preload_hook && defined &Plugins::delHook;
	$rules_preload_hook = undef;
	$active_event = undef;
	$armed_event = undef;
	$active_snapshot = undef;
	$activity_lock = 0;
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
sub activity_locked { return $activity_lock ? 1 : 0; }
sub last_failure { return $last_failure; }
sub rules_file { return $rules_file || $rules_requested; }

1;
