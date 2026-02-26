package AIVillageBridge;

# IMPORTANT: use lib must come first — enables loading AIVillageBridge/*.pm
use lib $Plugins::current_plugin_folder;

use strict;
use warnings;

use Plugins;
use Globals qw($char $field %players %monsters %npcs %items @ai_seq @ai_seq_args %config);
use Log qw(message error warning debug);
use Time::HiRes qw(time);
use JSON::Tiny qw(from_json to_json);

use AIVillageBridge::Protocol;
use AIVillageBridge::Connection;
use AIVillageBridge::EventFilter;
use AIVillageBridge::NoveltyDetector;
use AIVillageBridge::CommandExecutor;
use AIVillageBridge::ConfigUpdater;
use AIVillageBridge::StateSnapshot;

# ---------------------------------------------------------------------------
# Plugin registration
# ---------------------------------------------------------------------------

Plugins::register('AIVillageBridge', 'AI Village Temporal bridge', \&onUnload, \&onReload);

# ---------------------------------------------------------------------------
# Configuration (read once at load time; env vars override %config)
# ---------------------------------------------------------------------------

my $sidecar_host = $ENV{AIVILLAGE_SIDECAR_HOST} || $ENV{BRIDGE_SIDECAR_HOST} || $config{aiVillageSidecarHost} || '127.0.0.1';
my $sidecar_port = $ENV{AIVILLAGE_SIDECAR_PORT} || $ENV{BRIDGE_SIDECAR_PORT} || $config{aiVillageSidecarPort} || 6801;
my $bot_id       = $ENV{AIVILLAGE_BOT_ID}       || $config{aiVillageBotId}
                   || do { warning "[AIVillageBridge] AIVILLAGE_BOT_ID not set, using 'bot-unknown'\n"; 'bot-unknown' };
my $rate_limit       = $ENV{AIVILLAGE_RATE_LIMIT}       || $config{aiVillageRateLimit}      || 10;
my $buffer_size      = $ENV{AIVILLAGE_BUFFER_SIZE}      || $config{aiVillageBufferSize}     || 1000;
my $item_threshold   = $ENV{AIVILLAGE_ITEM_THRESHOLD}   || $config{aiVillageItemThreshold}  || 100;
my $player_familiar  = $ENV{AIVILLAGE_PLAYER_FAMILIAR}  || $config{aiVillagePlayerFamiliar} || 5;
my $monster_familiar = $ENV{AIVILLAGE_MONSTER_FAMILIAR} || $config{aiVillageMonsterFamiliar}|| 10;
my $control_dir = 'control/ai-village';

# ---------------------------------------------------------------------------
# Module instances (package-level, re-created on reload)
# ---------------------------------------------------------------------------

my $proto;    # AIVillageBridge::Protocol
my $conn;     # AIVillageBridge::Connection
my $filter;   # AIVillageBridge::EventFilter
my $novelty;  # AIVillageBridge::NoveltyDetector
my $executor; # AIVillageBridge::CommandExecutor
my $updater;  # AIVillageBridge::ConfigUpdater
my $snap;     # AIVillageBridge::StateSnapshot
my $hooks_handle;  # Plugins::HookHandles object returned by addHooks
my $cleanup_timer = 0;  # last cleanup timestamp

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

sub _init {
    $proto = AIVillageBridge::Protocol->new(bot_id => $bot_id, plugin_version => '0.1.0');
    $snap  = AIVillageBridge::StateSnapshot->new();

    $filter = AIVillageBridge::EventFilter->new(
        rate_limit     => $rate_limit,
        burst_limit    => $rate_limit * 2,
        item_threshold => $item_threshold,
    );

    $novelty = AIVillageBridge::NoveltyDetector->new(
        player_familiar_threshold  => $player_familiar,
        monster_familiar_threshold => $monster_familiar,
        map_familiar_threshold     => 3,
        npc_familiar_threshold     => 2,
    );

    # Attempt to restore persisted ruleset from disk
    _load_persisted_ruleset();

    $executor = AIVillageBridge::CommandExecutor->new(
        on_result => sub {
            my ($type, $id, $data) = @_;
            return unless $conn;
            my $msg;
            if ($type eq 'ack') {
                $msg = $proto->build_ack($id, $data->{detail} || '');
            } else {
                $msg = $proto->build_error($id, $data->{code}, $data->{message});
            }
            $conn->send_message($msg) if $msg;
        },
    );

    $updater = AIVillageBridge::ConfigUpdater->new(
        control_dir => $control_dir,
        on_result   => sub {
            my ($type, $id, $data) = @_;
            return unless $conn;
            my $msg;
            if ($type eq 'ack') {
                $msg = $proto->build_ack($id, $data->{detail} || '');
            } else {
                $msg = $proto->build_error($id, $data->{code}, $data->{message});
            }
            $conn->send_message($msg) if $msg;
        },
        on_ruleset_updated => sub {
            my ($ruleset) = @_;
            $novelty->set_ruleset($ruleset);
        },
        on_chat_resp_updated => sub {
            my ($patterns) = @_;
            # Store compiled chat_resp patterns for use in pub_msg/priv_msg handlers
            $novelty->{chat_resp_patterns} = $patterns;
        },
    );

    $conn = AIVillageBridge::Connection->new(
        host        => $sidecar_host,
        port        => $sidecar_port,
        bot_id      => $bot_id,
        buffer_size => $buffer_size,
        on_message      => \&_on_message,
        on_connected    => \&_on_connected,
        on_disconnected => \&_on_disconnected,
    );

    message "[AIVillageBridge] Initialized. bot_id=$bot_id sidecar=$sidecar_host:$sidecar_port\n", 'system';
}

# ---------------------------------------------------------------------------
# Hook registration (extracted to avoid duplication between load and reload)
# ---------------------------------------------------------------------------

sub _register_hooks {
    $hooks_handle = Plugins::addHooks(
        # Critical (lifecycle)
        ['AI_pre',                              \&onAIPre,              undef],
        ['self_died',                           \&onSelfDied,           undef],
        ['mainLoop_post',                       \&onMainLoopPost,       undef],
        ['initialized',                         \&onInitialized,        undef],
        ['in_game',                             \&onInGame,             undef],
        ['disconnected',                        \&onDisconnected,       undef],
        # High (social + combat)
        ['packet_pubMsg',                       \&onPubMsg,             undef],
        ['packet_privMsg',                      \&onPrivMsg,            undef],
        ['attack_start',                        \&onAttackStart,        undef],
        ['is_casting',                          \&onIsCasting,          undef],
        # Medium (awareness + progression)
        ['target_died',                         \&onTargetDied,         undef],
        ['Network::Receive::map_changed',       \&onMapChanged,         undef],
        ['npc_talk',                            \&onNpcTalk,            undef],
        ['base_level_changed',                  \&onBaseLevelChanged,   undef],
        ['job_level_changed',                   \&onJobLevelChanged,    undef],
        ['item_gathered',                       \&onItemGathered,       undef],
        # Low (background tracking)
        ['player_exist',                        \&onPlayerExist,        undef],
        ['player_disappeared',                  \&onPlayerDisappeared,  undef],
        ['monster_exist',                       \&onMonsterExist,       undef],
        ['item_appeared',                       \&onItemAppeared,       undef],
        ['party_invite',                        \&onPartyInvite,        undef],
        ['incoming_deal',                       \&onIncomingDeal,       undef],
    );
}

# ---------------------------------------------------------------------------
# Unload / Reload callbacks
# ---------------------------------------------------------------------------

sub onUnload {
    Plugins::delHooks($hooks_handle) if $hooks_handle;
    $hooks_handle = undef;
    $conn->disconnect('plugin unloading') if $conn;
    message "[AIVillageBridge] Plugin unloaded\n", 'system';
}

sub onReload {
    Plugins::delHooks($hooks_handle) if $hooks_handle;
    $hooks_handle = undef;
    $conn->disconnect('plugin reloading') if $conn;
    _init();
    _register_hooks();
    message "[AIVillageBridge] Plugin reloaded\n", 'system';
}

# ---------------------------------------------------------------------------
# Connection callbacks
# ---------------------------------------------------------------------------

sub _on_connected {
    message "[AIVillageBridge] Connected to sidecar $sidecar_host:$sidecar_port\n", 'success';
    # Send a full state snapshot so the sidecar can rebuild context
    my $state = $snap->take();
    my $msg = $proto->build_state_response('initial', $state);
    $conn->send_message($msg);
}

sub _on_disconnected {
    message "[AIVillageBridge] Disconnected from sidecar. Bot continues with Layer 1/2 rules.\n", 'warning';
}

# ---------------------------------------------------------------------------
# Incoming message dispatcher
# ---------------------------------------------------------------------------

sub _on_message {
    my ($msg) = @_;
    return unless ref $msg eq 'HASH' && $msg->{type};

    my $type = $msg->{type};

    if ($type eq 'command') {
        $executor->enqueue($msg);
    }
    elsif ($type eq 'config_update') {
        $updater->apply_update($msg);
    }
    elsif ($type eq 'state_request') {
        my $state    = $snap->take();
        my $response = $proto->build_state_response($msg->{id}, $state);
        $conn->send_message($response);
    }
    else {
        debug "[AIVillageBridge] Unknown message type: $type\n", 'aivillage';
    }
}

# ---------------------------------------------------------------------------
# Persisted ruleset loader
# ---------------------------------------------------------------------------

sub _load_persisted_ruleset {
    my $path = "$control_dir/ruleset.json";
    return unless -f $path;
    eval {
        open(my $fh, '<:utf8', $path) or return;
        my $json = do { local $/; <$fh> };
        close($fh);
        my $ruleset = from_json($json);
        if (ref $ruleset eq 'HASH') {
            $novelty->set_ruleset($ruleset);
            message "[AIVillageBridge] Loaded persisted ruleset v$ruleset->{version}\n", 'system';
        }
    };
    warning "[AIVillageBridge] Could not load persisted ruleset: $@\n" if $@;
}

# ---------------------------------------------------------------------------
# Event emission helper
# ---------------------------------------------------------------------------

sub _dedup_key {
    my ($event_name, $data) = @_;
    my $map = ($field ? $field->name() : '') || '';

    my %key_builders = (
        pub_msg       => sub { ($data->{user} || '') . ':' . $map },
        priv_msg      => sub { $data->{user} || '' },
        monster_exist => sub { ($data->{name} || '') . ':' . $map },
        player_exist  => sub { $data->{name} || '' },
        item_appeared => sub { ($data->{name} || '') . ':' . $map },
        is_casting    => sub {
            ($data->{sourceID} || '') . ':' .
            ($data->{skillID}  || '') . ':' .
            ($data->{targetID} || '')
        },
    );

    return exists $key_builders{$event_name}
        ? $key_builders{$event_name}->()
        : "$event_name:" . ($data->{id} || $data->{name} || '');
}

sub _emit_event {
    my ($event_name, $priority, $data, $always_send) = @_;
    return unless $conn;

    $data        //= {};
    $always_send //= 0;

    # Build dedup key based on event type
    my $dedup_key = _dedup_key($event_name, $data);

    # Run through EventFilter (skip if always_send)
    unless ($always_send) {
        return unless $filter->should_send($event_name, $dedup_key, $priority, $data);
    }

    # Novelty analysis
    my $result = $novelty->analyze($event_name, $data);

    if ($result->{action} eq 'send' || ($always_send && $result->{action} ne 'ignore')) {
        my $msg = $proto->build_event($event_name, $priority, $data);
        $conn->send_message($msg) if $msg;
    }
    elsif ($result->{action} eq 'local' && $result->{command}) {
        # Execute locally via CommandExecutor
        $executor->enqueue({
            type   => 'command',
            id     => 'local-' . time(),
            action => $result->{command}{command} || $result->{command}{type},
            params => $result->{command}{params}  || {},
        });
    }
    elsif ($result->{action} eq 'pickup' && $result->{item_id}) {
        $executor->enqueue({
            type   => 'command',
            id     => 'local-pickup-' . time(),
            action => 'pick_item',
            params => { item_id => $result->{item_id} },
        });
    }
    # 'ignore' and 'flee': ignore drops; flee handled by native AI config
}

# ---------------------------------------------------------------------------
# Hook callbacks
# ---------------------------------------------------------------------------

# AI_pre — process queued commands
sub onAIPre {
    my ($hookName, $args) = @_;
    eval { $executor->process_queue() if $executor };
    error "[AIVillageBridge] onAIPre error: $@\n" if $@;
}

# mainLoop_post — TCP I/O, periodic cleanup, overflow flush
sub onMainLoopPost {
    my ($hookName, $args) = @_;
    eval {
        return unless $conn;
        $conn->iterate();

        # Periodic cleanup every 300 seconds
        if (time() - $cleanup_timer > 300) {
            $filter->cleanup_cache()      if $filter;
            $novelty->cleanup_context()   if $novelty;
            $cleanup_timer = time();
        }

        # Flush overflow events that passed the rate limiter
        if ($filter) {
            my $overflow = $filter->get_overflow_events();
            for my $ev (@$overflow) {
                my $msg = $proto->build_event($ev->{event_type}, $ev->{priority}, $ev->{data});
                $conn->send_message($msg) if $msg;
            }
        }
    };
    error "[AIVillageBridge] onMainLoopPost error: $@\n" if $@;
}

# initialized — plugin is fully loaded; connection will auto-connect on first iterate()
sub onInitialized {
    my ($hookName, $args) = @_;
    eval {
        message "[AIVillageBridge] Bot initialized, starting sidecar connection\n", 'system';
    };
    error "[AIVillageBridge] onInitialized error: $@\n" if $@;
}

# in_game — entered the game world; send a full state snapshot
sub onInGame {
    my ($hookName, $args) = @_;
    eval {
        return unless $conn && $conn->is_connected();
        my $state = $snap->take();
        my $msg = $proto->build_event('in_game', AIVillageBridge::Protocol::PRIORITY_CRITICAL, $state);
        $conn->send_message($msg) if $msg;
    };
    error "[AIVillageBridge] onInGame error: $@\n" if $@;
}

# disconnected — lost game server connection
sub onDisconnected {
    my ($hookName, $args) = @_;
    eval {
        _emit_event('disconnected', AIVillageBridge::Protocol::PRIORITY_CRITICAL,
            { reason => $args->{reason} || 'unknown' }, 1);
    };
    error "[AIVillageBridge] onDisconnected error: $@\n" if $@;
}

# self_died — character death
sub onSelfDied {
    my ($hookName, $args) = @_;
    eval {
        my $data = {
            map => ($field ? $field->name() : 'unknown'),
            pos => ($char ? { x => $char->{pos}{x} || 0, y => $char->{pos}{y} || 0 }
                          : { x => 0, y => 0 }),
        };
        _emit_event('self_died', AIVillageBridge::Protocol::PRIORITY_CRITICAL, $data, 1);
    };
    error "[AIVillageBridge] onSelfDied error: $@\n" if $@;
}

# packet_pubMsg — public chat message
sub onPubMsg {
    my ($hookName, $args) = @_;
    eval {
        my $data = {
            user => $args->{pubMsgUser} || '',
            msg  => $args->{pubMsg}     || '',
            map  => ($field ? $field->name() : ''),
            pos  => ($char
                ? { x => $char->{pos_to}{x} || 0, y => $char->{pos_to}{y} || 0 }
                : { x => 0, y => 0 }),
        };
        $novelty->track_player($data->{user}) if $data->{user};
        _emit_event('pub_msg', AIVillageBridge::Protocol::PRIORITY_HIGH, $data, 0);
    };
    error "[AIVillageBridge] onPubMsg error: $@\n" if $@;
}

# packet_privMsg — whisper
sub onPrivMsg {
    my ($hookName, $args) = @_;
    eval {
        my $data = {
            user => $args->{privMsgUser} || '',
            msg  => $args->{privMsg}     || '',
        };
        $novelty->track_player($data->{user}) if $data->{user};
        _emit_event('priv_msg', AIVillageBridge::Protocol::PRIORITY_HIGH, $data, 0);
    };
    error "[AIVillageBridge] onPrivMsg error: $@\n" if $@;
}

# attack_start — bot begins attacking a target
sub onAttackStart {
    my ($hookName, $args) = @_;
    eval {
        my $target = $args->{ID} ? $monsters{$args->{ID}} : undef;
        my $data = {
            target_id   => $args->{ID} ? unpack('H*', $args->{ID}) : '',
            target_name => $target ? ($target->{name} || 'unknown') : 'unknown',
            map         => ($field ? $field->name() : ''),
        };
        _emit_event('attack_start', AIVillageBridge::Protocol::PRIORITY_HIGH, $data, 0);
    };
    error "[AIVillageBridge] onAttackStart error: $@\n" if $@;
}

# is_casting — skill cast detected, only if targeting us
sub onIsCasting {
    my ($hookName, $args) = @_;
    eval {
        # Only care about casts targeting our character
        return unless $char && $args->{targetID} && $args->{targetID} eq $char->{ID};
        my $data = {
            sourceID => $args->{sourceID} ? unpack('H*', $args->{sourceID}) : '',
            skillID  => $args->{skillID}  || '',
            targetID => $args->{targetID} ? unpack('H*', $args->{targetID}) : '',
        };
        _emit_event('is_casting', AIVillageBridge::Protocol::PRIORITY_HIGH, $data, 0);
    };
    error "[AIVillageBridge] onIsCasting error: $@\n" if $@;
}

# target_died — a monster was killed
sub onTargetDied {
    my ($hookName, $args) = @_;
    eval {
        my $monster = $args->{monster};
        return unless $monster;
        my $map  = $field ? $field->name() : '';
        my $name = $monster->{name} || 'unknown';
        my $data = { name => $name, map => $map };
        $novelty->track_monster_kill($name, $map);
        _emit_event('target_died', AIVillageBridge::Protocol::PRIORITY_MEDIUM, $data, 0);
    };
    error "[AIVillageBridge] onTargetDied error: $@\n" if $@;
}

# map_changed — character moved to a new map
sub onMapChanged {
    my ($hookName, $args) = @_;
    eval {
        my $map = $args->{map} || '';
        $novelty->track_map_visit($map) if $map;
        my $data = {
            old_map => $args->{oldMap} || '',
            new_map => $map,
            map     => $map,   # alias for NoveltyDetector familiarity check
        };
        _emit_event('map_changed', AIVillageBridge::Protocol::PRIORITY_MEDIUM, $data, 0);
    };
    error "[AIVillageBridge] onMapChanged error: $@\n" if $@;
}

# npc_talk — interacting with an NPC
sub onNpcTalk {
    my ($hookName, $args) = @_;
    eval {
        my $npc_id = $args->{ID} ? unpack('H*', $args->{ID}) : '';
        my $map    = $field ? $field->name() : '';
        $novelty->track_npc($npc_id, $map) if $npc_id;
        my $data = {
            npc_id => $npc_id,
            id     => $npc_id,   # alias for NoveltyDetector NPC key
            msg    => $args->{msg} || '',
            map    => $map,
        };
        _emit_event('npc_talk', AIVillageBridge::Protocol::PRIORITY_MEDIUM, $data, 0);
    };
    error "[AIVillageBridge] onNpcTalk error: $@\n" if $@;
}

# base_level_changed — always escalate, level-ups are always significant
sub onBaseLevelChanged {
    my ($hookName, $args) = @_;
    eval {
        _emit_event('base_level_changed', AIVillageBridge::Protocol::PRIORITY_HIGH,
            { level => $args->{level} || 0 }, 1);
    };
    error "[AIVillageBridge] onBaseLevelChanged error: $@\n" if $@;
}

# job_level_changed — always escalate
sub onJobLevelChanged {
    my ($hookName, $args) = @_;
    eval {
        _emit_event('job_level_changed', AIVillageBridge::Protocol::PRIORITY_HIGH,
            { level => $args->{level} || 0 }, 1);
    };
    error "[AIVillageBridge] onJobLevelChanged error: $@\n" if $@;
}

# item_gathered — picked up an item from the ground
sub onItemGathered {
    my ($hookName, $args) = @_;
    eval {
        my $item = $args->{item};
        return unless $item;
        my $data = {
            name   => $item->{name}  || 'unknown',
            amount => $args->{amount} || 1,
            value  => $item->{price} || $item->{buyValue} || 0,
        };
        _emit_event('item_gathered', AIVillageBridge::Protocol::PRIORITY_MEDIUM, $data, 0);
    };
    error "[AIVillageBridge] onItemGathered error: $@\n" if $@;
}

# player_exist — a player is visible in the current area
sub onPlayerExist {
    my ($hookName, $args) = @_;
    eval {
        my $player = $args->{player};
        return unless $player;
        my $name = $player->{name} || '';
        $novelty->track_player($name) if $name;
        my $job_id  = $player->{jobID};
        my $job_str = defined($job_id)
            ? ($::jobs_lut{$job_id} || "Job $job_id")
            : 'unknown';
        my $pos = $player->{pos_to} // $player->{pos};
        my $data = {
            name => $name,
            job  => $job_str,
            pos  => (defined $pos && ref $pos eq 'HASH')
                        ? { x => $pos->{x} || 0, y => $pos->{y} || 0 }
                        : { x => 0, y => 0 },
        };
        _emit_event('player_exist', AIVillageBridge::Protocol::PRIORITY_LOW, $data, 0);
    };
    error "[AIVillageBridge] onPlayerExist error: $@\n" if $@;
}

# player_disappeared — a player left our visible range
sub onPlayerDisappeared {
    my ($hookName, $args) = @_;
    eval {
        my $player = $args->{player};
        return unless $player;
        my $data = { name => $player->{name} || '' };
        _emit_event('player_disappeared', AIVillageBridge::Protocol::PRIORITY_LOW, $data, 0);
    };
    error "[AIVillageBridge] onPlayerDisappeared error: $@\n" if $@;
}

# monster_exist — a monster is visible in the current area
sub onMonsterExist {
    my ($hookName, $args) = @_;
    eval {
        my $monster = $args->{monster};
        return unless $monster;
        my $pos = $monster->{pos} // $monster->{pos_to};
        my $data = {
            name  => $monster->{name} || 'unknown',
            level => $monster->{level} || 0,
            id    => $monster->{ID} ? unpack('H*', $monster->{ID}) : '',
            pos   => (defined $pos && ref $pos eq 'HASH')
                         ? { x => $pos->{x} || 0, y => $pos->{y} || 0 }
                         : { x => 0, y => 0 },
            map   => ($field ? $field->name() : ''),
        };
        _emit_event('monster_exist', AIVillageBridge::Protocol::PRIORITY_LOW, $data, 0);
    };
    error "[AIVillageBridge] onMonsterExist error: $@\n" if $@;
}

# item_appeared — a ground item appeared in view
sub onItemAppeared {
    my ($hookName, $args) = @_;
    eval {
        my $item = $args->{item};
        return unless $item;
        my $pos = $item->{pos} // $item->{pos_to};
        my $data = {
            name  => $item->{name} || 'unknown',
            id    => $item->{ID} ? unpack('H*', $item->{ID}) : '',
            value => $item->{price} || $item->{buyValue} || 0,
            pos   => (defined $pos && ref $pos eq 'HASH')
                         ? { x => $pos->{x} || 0, y => $pos->{y} || 0 }
                         : { x => 0, y => 0 },
        };
        _emit_event('item_appeared', AIVillageBridge::Protocol::PRIORITY_LOW, $data, 0);
    };
    error "[AIVillageBridge] onItemAppeared error: $@\n" if $@;
}

# party_invite — always escalate; LLM decides whether to accept
sub onPartyInvite {
    my ($hookName, $args) = @_;
    eval {
        _emit_event('party_invite', AIVillageBridge::Protocol::PRIORITY_HIGH,
            { name => $args->{name} || '', id => $args->{ID} || '' }, 1);
    };
    error "[AIVillageBridge] onPartyInvite error: $@\n" if $@;
}

# incoming_deal — always escalate; LLM decides whether to accept
sub onIncomingDeal {
    my ($hookName, $args) = @_;
    eval {
        _emit_event('incoming_deal', AIVillageBridge::Protocol::PRIORITY_HIGH,
            { name => $args->{name} || '', id => $args->{ID} || '' }, 1);
    };
    error "[AIVillageBridge] onIncomingDeal error: $@\n" if $@;
}

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

_init();
_register_hooks();

1;
