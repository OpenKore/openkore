package AIVillageBridge::ConfigUpdater;

use strict;
use warnings;

use FileParsers qw(parseMonControl parseItemsControl);
use Globals qw(%config %mon_control %items_control);
use Log qw(message error warning debug);
use JSON::Tiny qw(from_json to_json);

# Whitelisted config key prefixes for the 'config' section.
# Only keys beginning with one of these prefixes may be modified.
my @CONFIG_KEY_PREFIXES = qw(
    attack
    sit
    teleport
    itemsTake
    route_
    useSelf_
);

##
# AIVillageBridge::ConfigUpdater->new(%args)
#
# Constructor. Arguments (as a hash):
#   control_dir          - directory for control files (default 'control/ai-village')
#   on_result            - coderef called with ($type, $id, $data); type is 'ack' or 'error'
#   on_ruleset_updated   - coderef called with ($ruleset_hashref) when ruleset changes
#   on_chat_resp_updated - coderef called with (\@patterns) when chat_resp changes
##
sub new {
    my ($class, %args) = @_;

    my $self = bless {
        control_dir          => $args{control_dir}          // 'control/ai-village',
        on_result            => $args{on_result}            // sub {},
        on_ruleset_updated   => $args{on_ruleset_updated}   // sub {},
        on_chat_resp_updated => $args{on_chat_resp_updated} // sub {},
    }, $class;

    return $self;
}

##
# $updater->apply_update($msg)
#
# Apply a config_update message.
# $msg = {type=>'config_update', id=>'cfg-456', section=>'mon_control', data=>[...]}
##
sub apply_update {
    my ($self, $msg) = @_;

    unless (defined $msg && ref($msg) eq 'HASH') {
        warning "[AIVillageBridge::ConfigUpdater] apply_update() called with non-hashref argument\n";
        return;
    }

    my $id      = $msg->{id}      // 'unknown';
    my $section = $msg->{section} // '';
    my $data    = $msg->{data};

    unless (length($section)) {
        $self->_send_error($id, 'INVALID_PARAMS', "config_update: 'section' field is required");
        return;
    }

    unless (defined $data) {
        $self->_send_error($id, 'INVALID_PARAMS', "config_update: 'data' field is required");
        return;
    }

    my %section_handlers = (
        mon_control  => \&_apply_mon_control,
        items_control => \&_apply_items_control,
        config       => \&_apply_config,
        ruleset      => \&_apply_ruleset,
        chat_resp    => \&_apply_chat_resp,
    );

    my $handler = $section_handlers{$section};
    unless ($handler) {
        $self->_send_error($id, 'INVALID_PARAMS', "config_update: unknown section '$section'");
        return;
    }

    eval { $handler->($self, $id, $data) };
    if ($@) {
        my $err = $@;
        $err =~ s/\n$//;
        warning "[AIVillageBridge::ConfigUpdater] Exception in section handler '$section' (id=$id): $err\n";
        $self->_send_error($id, 'INTERNAL_ERROR', $err);
    }
}

# ---------------------------------------------------------------------------
# Section handlers
# ---------------------------------------------------------------------------

##
# _apply_mon_control($self, $id, $data)
# data: [{monster=>'Poring', attack_auto=>1, teleport_auto=>0}, ...]
#
# Writes in OpenKore's 10-column mon_control format:
#   name attack teleport teleport_search skillcancel_auto lv joblv hp sp weight
# Fields not provided by the sidecar default to 0.
##
sub _apply_mon_control {
    my ($self, $id, $data) = @_;

    unless (ref($data) eq 'ARRAY') {
        $self->_send_error($id, 'INVALID_PARAMS', "mon_control: data must be an array");
        return;
    }

    my $content = '';
    my $count   = 0;
    for my $entry (@{$data}) {
        next unless ref($entry) eq 'HASH';
        my $monster       = $entry->{monster}       // '';
        my $attack_auto   = $entry->{attack_auto}   // 0;
        my $teleport_auto = $entry->{teleport_auto} // 0;
        next unless length($monster);
        # Full 10-column format; unspecified fields default to 0
        $content .= "$monster $attack_auto $teleport_auto 0 0 0 0 0 0 0\n";
        $count++;
    }

    $self->_write_file('mon_control.txt', $content) or do {
        $self->_send_error($id, 'INTERNAL_ERROR', "mon_control: failed to write control file");
        return;
    };

    # Reload into the live global hash using the correct parser
    my $path = "$self->{control_dir}/mon_control.txt";
    eval { parseMonControl($path, \%mon_control) };
    if ($@) {
        warning "[AIVillageBridge::ConfigUpdater] mon_control reload failed: $@\n";
        # Non-fatal: file was written, reload will retry on next restart
    }

    message "[AIVillageBridge::ConfigUpdater] Updated mon_control: $count entries\n";
    $self->_send_ack($id, "mon_control updated: $count entries");
}

##
# _apply_items_control($self, $id, $data)
# data: [{item=>'Red Potion', keep=>30, storage=>0, sell=>1}, ...]
#
# Writes in OpenKore's 6-column items_control format:
#   "item name" keep storage sell cart_add cart_get
# Item names containing spaces are double-quoted.
##
sub _apply_items_control {
    my ($self, $id, $data) = @_;

    unless (ref($data) eq 'ARRAY') {
        $self->_send_error($id, 'INVALID_PARAMS', "items_control: data must be an array");
        return;
    }

    my $content = '';
    my $count   = 0;
    for my $entry (@{$data}) {
        next unless ref($entry) eq 'HASH';
        my $item    = $entry->{item}    // '';
        my $keep    = $entry->{keep}    // 0;
        my $storage = $entry->{storage} // 0;
        my $sell    = $entry->{sell}    // 0;
        next unless length($item);
        # Quote item names that contain spaces
        my $quoted = ($item =~ /\s/) ? qq{"$item"} : $item;
        # Full 6-column format; cart_add and cart_get default to 0
        $content .= "$quoted $keep $storage $sell 0 0\n";
        $count++;
    }

    $self->_write_file('items_control.txt', $content) or do {
        $self->_send_error($id, 'INTERNAL_ERROR', "items_control: failed to write control file");
        return;
    };

    # Reload into the live global hash using the correct parser
    my $path = "$self->{control_dir}/items_control.txt";
    eval { parseItemsControl($path, \%items_control) };
    if ($@) {
        warning "[AIVillageBridge::ConfigUpdater] items_control reload failed: $@\n";
    }

    message "[AIVillageBridge::ConfigUpdater] Updated items_control: $count entries\n";
    $self->_send_ack($id, "items_control updated: $count entries");
}

##
# _apply_config($self, $id, $data)
# data: {attackAuto=>2, sitAuto_hp_lower=>40, ...}
# Only keys matching the whitelisted prefixes are applied.
##
sub _apply_config {
    my ($self, $id, $data) = @_;

    unless (ref($data) eq 'HASH') {
        $self->_send_error($id, 'INVALID_PARAMS', "config: data must be an object/hash");
        return;
    }

    my %allowed;
    my @rejected;

    for my $key (keys %{$data}) {
        if ($self->_config_key_allowed($key)) {
            $allowed{$key} = $data->{$key};
        } else {
            push @rejected, $key;
        }
    }

    if (@rejected) {
        warning "[AIVillageBridge::ConfigUpdater] config: rejected keys (not in whitelist): "
            . join(', ', @rejected) . "\n";
    }

    if (%allowed) {
        # Try Misc::bulkConfigModify first, fall back to main:: namespace
        eval { Misc::bulkConfigModify(\%allowed, 1) };
        if ($@) {
            eval { main::bulkConfigModify(\%allowed, 1) };
            if ($@) {
                # Last resort: modify %config directly and log a warning
                warning "[AIVillageBridge::ConfigUpdater] bulkConfigModify unavailable; writing config directly: $@\n";
                for my $k (keys %allowed) {
                    $config{$k} = $allowed{$k};
                }
            }
        }
        message "[AIVillageBridge::ConfigUpdater] Applied config keys: "
            . join(', ', sort keys %allowed) . "\n";
    }

    my $applied_count = scalar keys %allowed;
    my $rejected_count = scalar @rejected;
    $self->_send_ack($id, "config updated: $applied_count applied, $rejected_count rejected");
}

##
# _apply_ruleset($self, $id, $data)
# data: {version=>..., generated_at=>..., personality_hash=>..., rules=>[...]}
##
sub _apply_ruleset {
    my ($self, $id, $data) = @_;

    unless (ref($data) eq 'HASH') {
        $self->_send_error($id, 'INVALID_PARAMS', "ruleset: data must be an object/hash");
        return;
    }

    unless (defined $data->{rules} && ref($data->{rules}) eq 'ARRAY') {
        $self->_send_error($id, 'INVALID_PARAMS', "ruleset: data.rules must be an array");
        return;
    }

    # Persist to disk for restart recovery
    my $json_str;
    eval {
        # JSON::Tiny to_json doesn't support {pretty=>1}, so we use plain to_json
        $json_str = to_json($data);
    };
    if ($@) {
        warning "[AIVillageBridge::ConfigUpdater] ruleset: JSON serialization failed: $@\n";
        $json_str = '{}';  # write empty to avoid partial file
    }

    $self->_write_file('ruleset.json', $json_str) or do {
        # Non-fatal: the in-memory callback still proceeds
        warning "[AIVillageBridge::ConfigUpdater] ruleset: failed to persist ruleset.json\n";
    };

    # Notify listeners
    eval { $self->{on_ruleset_updated}->($data) };
    warning "[AIVillageBridge::ConfigUpdater] on_ruleset_updated callback error: $@\n" if $@;

    my $version = $data->{version} // 'unknown';
    message "[AIVillageBridge::ConfigUpdater] Loaded ruleset v$version\n";
    $self->_send_ack($id, "ruleset loaded: v$version");
}

##
# _apply_chat_resp($self, $id, $data)
# data: [{pattern=>'hello|hi', response=>'Hey!', type=>'pub'}, ...]
##
sub _apply_chat_resp {
    my ($self, $id, $data) = @_;

    unless (ref($data) eq 'ARRAY') {
        $self->_send_error($id, 'INVALID_PARAMS', "chat_resp: data must be an array");
        return;
    }

    my @patterns;
    for my $entry (@{$data}) {
        next unless ref($entry) eq 'HASH';
        my $pattern  = $entry->{pattern}  // '';
        my $response = $entry->{response} // '';
        my $type     = $entry->{type}     // 'pub';
        my $from     = $entry->{from}     // '';

        next unless length($pattern) && length($response);

        push @patterns, {
            pattern  => $pattern,
            response => $response,
            type     => $type,
            from     => $from,
        };
    }

    # Notify listeners — they are responsible for compiling regexes and matching
    eval { $self->{on_chat_resp_updated}->(\@patterns) };
    warning "[AIVillageBridge::ConfigUpdater] on_chat_resp_updated callback error: $@\n" if $@;

    my $count = scalar @patterns;
    message "[AIVillageBridge::ConfigUpdater] Updated chat_resp: $count patterns\n";
    $self->_send_ack($id, "chat_resp updated: $count patterns");
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

##
# $updater->_config_key_allowed($key) -> 1 or 0
# Returns 1 if the key matches any whitelisted prefix.
##
sub _config_key_allowed {
    my ($self, $key) = @_;
    for my $prefix (@CONFIG_KEY_PREFIXES) {
        return 1 if index($key, $prefix) == 0;
    }
    return 0;
}

##
# $updater->_write_file($filename, $content) -> 1 on success, 0 on failure
# Writes $content to $self->{control_dir}/$filename, creating directories as needed.
##
sub _write_file {
    my ($self, $filename, $content) = @_;

    my $dir  = $self->{control_dir};
    my $path = "$dir/$filename";

    # Create directory if it doesn't exist
    if (! -d $dir) {
        require File::Path;
        File::Path::make_path($dir) or do {
            error "[AIVillageBridge::ConfigUpdater] Cannot create dir $dir: $!\n";
            return 0;
        };
    }

    open(my $fh, '>:utf8', $path) or do {
        error "[AIVillageBridge::ConfigUpdater] Cannot write $path: $!\n";
        return 0;
    };
    print $fh $content;
    close($fh);

    return 1;
}

##
# $updater->_send_ack($id, $detail)
# Invoke the on_result callback with ('ack', $id, {detail => $detail}).
##
sub _send_ack {
    my ($self, $id, $detail) = @_;
    $detail //= '';
    debug "[AIVillageBridge::ConfigUpdater] ACK id=$id detail=$detail\n";
    eval { $self->{on_result}->('ack', $id, { detail => $detail }) };
    warning "[AIVillageBridge::ConfigUpdater] on_result callback error: $@\n" if $@;
}

##
# $updater->_send_error($id, $code, $message)
# Invoke the on_result callback with ('error', $id, {code => $code, message => $message}).
##
sub _send_error {
    my ($self, $id, $code, $msg) = @_;
    $code //= 'INTERNAL_ERROR';
    $msg  //= 'Unknown error';
    warning "[AIVillageBridge::ConfigUpdater] ERROR id=$id code=$code msg=$msg\n";
    eval { $self->{on_result}->('error', $id, { code => $code, message => $msg }) };
    warning "[AIVillageBridge::ConfigUpdater] on_result callback error: $@\n" if $@;
}

1;
