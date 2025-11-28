#!/usr/bin/env perl
###############################################################################
# AI_Bridge.pl - God-Tier AI Bridge Plugin for OpenKore
###############################################################################
#
# This plugin connects OpenKore to an external AI Sidecar process via ZeroMQ
# IPC, enabling advanced AI decision-making capabilities while maintaining
# graceful degradation if the sidecar is unavailable.
#
# Architecture: OpenKore (Perl/REQ) <-> ZeroMQ <-> AI Sidecar (Python/REP)
#
# Installation:
#   1. Copy this plugin to plugins/AI_Bridge/
#   2. Copy AI_Bridge.txt to plugins/AI_Bridge/
#   3. Ensure ZMQ module is installed (see ZMQ Installation below)
#   4. Start the AI Sidecar before or after OpenKore
#
# ZMQ Installation Options:
#   Option 1 (Recommended): ZMQ::FFI
#     cpanm ZMQ::FFI
#     Requires: libzmq installed on system
#
#   Option 2: ZMQ::LibZMQ4
#     cpanm ZMQ::LibZMQ4
#     Requires: libzmq4 development headers
#
###############################################################################

package AI_Bridge;

use strict;
use warnings;
use utf8;

# OpenKore modules
use Plugins;
use Log qw(message warning error debug);
use Globals qw(
    $char $field $accountID %config %ai_seq @ai_seq_args
    %monsters %players %npcs %items %portals
    @monstersID @playersID @npcsID @itemsID
    $conState $net $messageSender
);
use Utils qw(distance timeOut);
use AI;

# Core Perl modules
use Time::HiRes qw(time gettimeofday tv_interval);
use Scalar::Util qw(blessed);

# JSON handling - try JSON::XS first for performance, fallback to JSON
our $JSON;
BEGIN {
    eval { require JSON::XS; JSON::XS->import(); $JSON = 'JSON::XS'; };
    if ($@) {
        eval { require JSON; JSON->import(); $JSON = 'JSON'; };
        die "AI_Bridge: JSON module required (JSON::XS or JSON)\n" if $@;
    }
}

# ZMQ handling - support both ZMQ::FFI and ZMQ::LibZMQ4
our $ZMQ_MODULE;
our $zmq_context;
our $zmq_socket;

BEGIN {
    # Try ZMQ::FFI first (modern, recommended)
    eval {
        require ZMQ::FFI;
        require ZMQ::FFI::Constants;
        ZMQ::FFI::Constants->import(qw(ZMQ_REQ ZMQ_RCVTIMEO ZMQ_SNDTIMEO ZMQ_LINGER));
        $ZMQ_MODULE = 'ZMQ::FFI';
    };
    
    # Fallback to ZMQ::LibZMQ4
    if ($@) {
        eval {
            require ZMQ::LibZMQ4;
            require ZMQ::Constants;
            ZMQ::Constants->import(qw(ZMQ_REQ ZMQ_RCVTIMEO ZMQ_SNDTIMEO ZMQ_LINGER));
            $ZMQ_MODULE = 'ZMQ::LibZMQ4';
        };
    }
    
    # Neither module available
    if (!$ZMQ_MODULE) {
        die "AI_Bridge: ZMQ module required (ZMQ::FFI or ZMQ::LibZMQ4)\n" .
            "Install with: cpanm ZMQ::FFI (recommended) or cpanm ZMQ::LibZMQ4\n";
    }
}

###############################################################################
# Plugin Registration
###############################################################################

our $VERSION = '0.1.0';
our $PLUGIN_NAME = 'AI_Bridge';

# Plugin state
our %state = (
    connected       => 0,
    last_heartbeat  => 0,
    tick_count      => 0,
    errors_count    => 0,
    reconnect_at    => 0,
    last_state_hash => '',
    degraded_mode   => 0,
);

# Configuration defaults (loaded from AI_Bridge.txt)
our %defaults = (
    AI_Bridge_enabled       => 1,
    AI_Bridge_address       => 'tcp://127.0.0.1:5555',
    AI_Bridge_timeout_ms    => 50,
    AI_Bridge_reconnect_ms  => 5000,
    AI_Bridge_heartbeat_ms  => 5000,
    AI_Bridge_debug         => 0,
    AI_Bridge_log_state     => 0,
);

# Register plugin
Plugins::register($PLUGIN_NAME, "God-Tier AI Bridge v$VERSION", \&onUnload, \&onReload);

# Register hooks
my @hooks = (
    Plugins::addHook('AI_pre',     \&onAIPre),
    Plugins::addHook('AI_post',    \&onAIPost),
    Plugins::addHook('packet_pre', \&onPacketPre),
    Plugins::addHook('packet',     \&onPacket),
    Plugins::addHook('start3',     \&onStart),
    Plugins::addHook('mainLoop_pre', \&onMainLoopPre),
);

message "[AI_Bridge] Plugin loaded (using $ZMQ_MODULE + $JSON)\n", "system";

###############################################################################
# Hook Handlers
###############################################################################

=head2 onStart

Called when OpenKore finishes initialization. Establishes initial connection
to the AI Sidecar.

=cut

sub onStart {
    load_config();
    
    return unless get_config('AI_Bridge_enabled');
    
    message "[AI_Bridge] Initializing connection to AI Sidecar...\n", "info";
    connect_to_sidecar();
}

=head2 onUnload

Called when plugin is unloaded. Cleans up ZMQ resources.

=cut

sub onUnload {
    message "[AI_Bridge] Unloading plugin...\n", "info";
    disconnect_from_sidecar();
    
    # Remove hooks
    Plugins::delHook($_) for @hooks;
}

=head2 onReload

Called when plugin configuration is reloaded.

=cut

sub onReload {
    message "[AI_Bridge] Reloading configuration...\n", "info";
    load_config();
    
    # Reconnect if address changed
    disconnect_from_sidecar();
    connect_to_sidecar() if get_config('AI_Bridge_enabled');
}

=head2 onMainLoopPre

Called at start of each main loop iteration. Handles reconnection logic
and periodic tasks.

=cut

sub onMainLoopPre {
    return unless get_config('AI_Bridge_enabled');
    
    my $now = time();
    
    # Handle reconnection attempts
    if (!$state{connected} && $state{reconnect_at} > 0 && $now >= $state{reconnect_at}) {
        debug_msg("Attempting reconnection...");
        connect_to_sidecar();
    }
    
    # Send heartbeat if connected
    if ($state{connected}) {
        my $heartbeat_ms = get_config('AI_Bridge_heartbeat_ms');
        if ($heartbeat_ms > 0 && ($now - $state{last_heartbeat}) * 1000 >= $heartbeat_ms) {
            send_heartbeat();
        }
    }
}

=head2 onAIPre

Called before AI processing. Sends current game state to sidecar and
receives AI decisions to queue.

=cut

sub onAIPre {
    return unless get_config('AI_Bridge_enabled');
    return unless $state{connected};
    return unless $char && $field;
    
    $state{tick_count}++;
    
    my $start_time = [gettimeofday];
    
    # Build game state
    my $game_state = build_game_state();
    
    # Send state update and get decision
    my $decision = send_state_update($game_state);
    
    # Apply decisions if received
    if ($decision && ref($decision) eq 'HASH') {
        apply_decisions($decision);
    }
    
    my $elapsed_ms = tv_interval($start_time) * 1000;
    debug_msg(sprintf("AI_pre tick %d completed in %.2fms", $state{tick_count}, $elapsed_ms));
}

=head2 onAIPost

Called after AI processing. Can be used for cleanup or post-decision
adjustments.

=cut

sub onAIPost {
    return unless get_config('AI_Bridge_enabled');
    # Reserved for post-processing if needed
}

=head2 onPacketPre

Called before packet processing. Can intercept packets for AI analysis.

=cut

sub onPacketPre {
    my (undef, $args) = @_;
    return unless get_config('AI_Bridge_enabled');
    
    # Reserved for packet interception if needed
    # $args->{switch} contains packet ID
    # $args->{msg} contains raw packet data
}

=head2 onPacket

Called after packet processing. Useful for reacting to processed packets.

=cut

sub onPacket {
    my (undef, $args) = @_;
    return unless get_config('AI_Bridge_enabled');
    
    # Reserved for post-packet processing if needed
}

###############################################################################
# ZMQ Connection Management
###############################################################################

=head2 connect_to_sidecar

Establishes ZMQ REQ socket connection to the AI Sidecar.

=cut

sub connect_to_sidecar {
    my $address = get_config('AI_Bridge_address');
    my $timeout_ms = get_config('AI_Bridge_timeout_ms');
    
    eval {
        if ($ZMQ_MODULE eq 'ZMQ::FFI') {
            $zmq_context = ZMQ::FFI->new();
            $zmq_socket = $zmq_context->socket(ZMQ_REQ);
            $zmq_socket->set(ZMQ_RCVTIMEO, 'int', $timeout_ms);
            $zmq_socket->set(ZMQ_SNDTIMEO, 'int', $timeout_ms);
            $zmq_socket->set(ZMQ_LINGER, 'int', 0);
            $zmq_socket->connect($address);
        }
        else {
            # ZMQ::LibZMQ4
            $zmq_context = ZMQ::LibZMQ4::zmq_ctx_new();
            $zmq_socket = ZMQ::LibZMQ4::zmq_socket($zmq_context, ZMQ_REQ);
            ZMQ::LibZMQ4::zmq_setsockopt($zmq_socket, ZMQ_RCVTIMEO, $timeout_ms);
            ZMQ::LibZMQ4::zmq_setsockopt($zmq_socket, ZMQ_SNDTIMEO, $timeout_ms);
            ZMQ::LibZMQ4::zmq_setsockopt($zmq_socket, ZMQ_LINGER, 0);
            ZMQ::LibZMQ4::zmq_connect($zmq_socket, $address);
        }
        
        $state{connected} = 1;
        $state{degraded_mode} = 0;
        $state{reconnect_at} = 0;
        $state{last_heartbeat} = time();
        
        message "[AI_Bridge] Connected to AI Sidecar at $address\n", "success";
    };
    
    if ($@) {
        warning "[AI_Bridge] Failed to connect: $@\n";
        handle_connection_error();
    }
}

=head2 disconnect_from_sidecar

Closes ZMQ socket and context cleanly.

=cut

sub disconnect_from_sidecar {
    eval {
        if ($zmq_socket) {
            if ($ZMQ_MODULE eq 'ZMQ::FFI') {
                $zmq_socket->close();
            }
            else {
                ZMQ::LibZMQ4::zmq_close($zmq_socket);
            }
            $zmq_socket = undef;
        }
        
        if ($zmq_context) {
            if ($ZMQ_MODULE eq 'ZMQ::FFI') {
                # ZMQ::FFI context is auto-cleaned
            }
            else {
                ZMQ::LibZMQ4::zmq_ctx_term($zmq_context);
            }
            $zmq_context = undef;
        }
    };
    
    $state{connected} = 0;
    debug_msg("Disconnected from AI Sidecar");
}

=head2 handle_connection_error

Handles connection failures by entering degraded mode and scheduling
reconnection attempts.

=cut

sub handle_connection_error {
    $state{connected} = 0;
    $state{degraded_mode} = 1;
    $state{errors_count}++;
    
    my $reconnect_ms = get_config('AI_Bridge_reconnect_ms');
    $state{reconnect_at} = time() + ($reconnect_ms / 1000);
    
    # Clean up socket for reconnection
    disconnect_from_sidecar();
    
    warning "[AI_Bridge] Entering degraded mode, reconnect in ${reconnect_ms}ms\n";
}

###############################################################################
# Message Handling
###############################################################################

=head2 send_state_update

Sends current game state to sidecar and receives decision response.

=cut

sub send_state_update {
    my ($game_state) = @_;
    
    my $message = {
        type      => 'state_update',
        timestamp => int(time() * 1000),
        tick      => $state{tick_count},
        payload   => $game_state,
    };
    
    return send_and_receive($message);
}

=head2 send_heartbeat

Sends heartbeat message to sidecar for health monitoring.

=cut

sub send_heartbeat {
    my $message = {
        type      => 'heartbeat',
        timestamp => int(time() * 1000),
        source    => 'openkore',
        status    => $state{degraded_mode} ? 'degraded' : 'healthy',
        stats     => {
            ticks_processed => $state{tick_count},
            errors_count    => $state{errors_count},
        },
        version   => $VERSION,
    };
    
    my $response = send_and_receive($message);
    
    if ($response) {
        $state{last_heartbeat} = time();
        debug_msg("Heartbeat acknowledged");
    }
}

=head2 send_and_receive

Low-level function to send JSON message and receive response via ZMQ.

=cut

sub send_and_receive {
    my ($message) = @_;
    
    return undef unless $state{connected} && $zmq_socket;
    
    my $json_msg = encode_json($message);
    
    eval {
        if ($ZMQ_MODULE eq 'ZMQ::FFI') {
            $zmq_socket->send($json_msg);
            my $response_json = $zmq_socket->recv();
            
            if (defined $response_json && length($response_json) > 0) {
                my $response = decode_json($response_json);
                debug_msg("Received response: " . substr($response_json, 0, 100)) 
                    if get_config('AI_Bridge_debug');
                return $response;
            }
        }
        else {
            # ZMQ::LibZMQ4
            my $msg = ZMQ::LibZMQ4::zmq_msg_init_data($json_msg);
            my $rv = ZMQ::LibZMQ4::zmq_msg_send($msg, $zmq_socket, 0);
            ZMQ::LibZMQ4::zmq_msg_close($msg);
            
            if ($rv >= 0) {
                my $recv_msg = ZMQ::LibZMQ4::zmq_msg_init();
                $rv = ZMQ::LibZMQ4::zmq_msg_recv($recv_msg, $zmq_socket, 0);
                
                if ($rv >= 0) {
                    my $response_json = ZMQ::LibZMQ4::zmq_msg_data($recv_msg);
                    ZMQ::LibZMQ4::zmq_msg_close($recv_msg);
                    
                    if (defined $response_json && length($response_json) > 0) {
                        my $response = decode_json($response_json);
                        debug_msg("Received response: " . substr($response_json, 0, 100))
                            if get_config('AI_Bridge_debug');
                        return $response;
                    }
                }
                ZMQ::LibZMQ4::zmq_msg_close($recv_msg);
            }
        }
    };
    
    if ($@) {
        warning "[AI_Bridge] Communication error: $@\n";
        handle_connection_error();
    }
    
    return undef;
}

###############################################################################
# Game State Building
###############################################################################

=head2 build_game_state

Builds comprehensive game state hash from OpenKore globals.

=cut

sub build_game_state {
    my $state = {
        character => build_character_state(),
        actors    => build_actors_state(),
        inventory => build_inventory_state(),
        map       => build_map_state(),
        ai_mode   => AI::state(),
    };
    
    if (get_config('AI_Bridge_log_state')) {
        debug_msg("Built game state: " . encode_json($state));
    }
    
    return $state;
}

=head2 build_character_state

Extracts player character state from $char.

=cut

sub build_character_state {
    return {} unless $char;
    
    return {
        name           => $char->{name} // '',
        job_id         => $char->{jobID} // 0,
        base_level     => $char->{lv} // 1,
        job_level      => $char->{lv_job} // 1,
        hp             => $char->{hp} // 0,
        hp_max         => $char->{hp_max} // 1,
        sp             => $char->{sp} // 0,
        sp_max         => $char->{sp_max} // 1,
        position       => {
            x => $char->{pos_to}{x} // $char->{pos}{x} // 0,
            y => $char->{pos_to}{y} // $char->{pos}{y} // 0,
        },
        moving         => $char->{time_move} ? 1 : 0,
        sitting        => ($char->{sitting} // 0) ? 1 : 0,
        attacking      => defined($char->{attack_target}) ? 1 : 0,
        target_id      => $char->{attack_target},
        status_effects => [keys %{$char->{statuses} // {}}],
        weight         => $char->{weight} // 0,
        weight_max     => $char->{weight_max} // 1,
        zeny           => $char->{zeny} // 0,
    };
}

=head2 build_actors_state

Builds list of visible actors (monsters, players, NPCs).

=cut

sub build_actors_state {
    my @actors;
    
    # Monsters
    for my $id (@monstersID) {
        next unless $id && $monsters{$id};
        my $m = $monsters{$id};
        push @actors, {
            id          => $id,
            type        => 2,  # MONSTER
            name        => $m->{name} // '',
            position    => {
                x => $m->{pos_to}{x} // $m->{pos}{x} // 0,
                y => $m->{pos_to}{y} // $m->{pos}{y} // 0,
            },
            hp          => $m->{hp},
            hp_max      => $m->{hp_max},
            moving      => $m->{time_move} ? 1 : 0,
            attacking   => defined($m->{attack_target}) ? 1 : 0,
            target_id   => $m->{attack_target},
            mob_id      => $m->{nameID},
        };
    }
    
    # Players
    for my $id (@playersID) {
        next unless $id && $players{$id};
        my $p = $players{$id};
        push @actors, {
            id          => $id,
            type        => 1,  # PLAYER
            name        => $p->{name} // '',
            position    => {
                x => $p->{pos_to}{x} // $p->{pos}{x} // 0,
                y => $p->{pos_to}{y} // $p->{pos}{y} // 0,
            },
            job_id      => $p->{jobID},
            moving      => $p->{time_move} ? 1 : 0,
            sitting     => ($p->{sitting} // 0) ? 1 : 0,
        };
    }
    
    # NPCs
    for my $id (@npcsID) {
        next unless $id && $npcs{$id};
        my $n = $npcs{$id};
        push @actors, {
            id          => $id,
            type        => 3,  # NPC
            name        => $n->{name} // '',
            position    => {
                x => $n->{pos}{x} // 0,
                y => $n->{pos}{y} // 0,
            },
        };
    }
    
    return \@actors;
}

=head2 build_inventory_state

Extracts inventory items.

=cut

sub build_inventory_state {
    return [] unless $char && $char->{inventory};
    
    my @items;
    my $inv = $char->{inventory};
    
    for my $item (@{$inv->getItems()}) {
        next unless $item;
        push @items, {
            index      => $item->{invIndex} // $item->{binID},
            item_id    => $item->{nameID},
            name       => $item->{name} // '',
            amount     => $item->{amount} // 1,
            equipped   => $item->{equipped} ? 1 : 0,
            identified => $item->{identified} ? 1 : 0,
            type       => $item->{type},
        };
    }
    
    return \@items;
}

=head2 build_map_state

Extracts current map information.

=cut

sub build_map_state {
    return {} unless $field;
    
    return {
        name   => $field->name() // '',
        width  => $field->width() // 0,
        height => $field->height() // 0,
    };
}

###############################################################################
# Decision Application
###############################################################################

=head2 apply_decisions

Applies AI decisions received from the sidecar.

=cut

sub apply_decisions {
    my ($decision) = @_;
    
    return unless $decision->{type} eq 'decision';
    return unless $decision->{actions} && ref($decision->{actions}) eq 'ARRAY';
    
    # Sort actions by priority (lower first)
    my @sorted_actions = sort { 
        ($a->{priority} // 50) <=> ($b->{priority} // 50) 
    } @{$decision->{actions}};
    
    for my $action (@sorted_actions) {
        apply_single_action($action);
    }
    
    debug_msg(sprintf("Applied %d actions", scalar(@sorted_actions)));
}

=head2 apply_single_action

Applies a single action from the AI decision.

=cut

sub apply_single_action {
    my ($action) = @_;
    
    my $type = $action->{type} // return;
    
    debug_msg("Applying action: $type") if get_config('AI_Bridge_debug');
    
    if ($type eq 'move') {
        apply_move_action($action);
    }
    elsif ($type eq 'attack') {
        apply_attack_action($action);
    }
    elsif ($type eq 'skill') {
        apply_skill_action($action);
    }
    elsif ($type eq 'use_item') {
        apply_item_action($action);
    }
    elsif ($type eq 'sit') {
        AI::queue('sit');
    }
    elsif ($type eq 'stand') {
        AI::queue('stand');
    }
    elsif ($type eq 'pick_item') {
        apply_pick_item_action($action);
    }
    elsif ($type eq 'idle') {
        # Do nothing - explicit idle
    }
    elsif ($type eq 'wait') {
        # Reserved for timed waits
    }
    else {
        debug_msg("Unknown action type: $type");
    }
}

sub apply_move_action {
    my ($action) = @_;
    return unless defined $action->{x} && defined $action->{y};
    
    my $x = $action->{x};
    my $y = $action->{y};
    
    AI::queue('move', {
        x => $x,
        y => $y,
        retry => 1,
    });
}

sub apply_attack_action {
    my ($action) = @_;
    return unless defined $action->{target};
    
    my $target_id = $action->{target};
    my $monster = $monsters{$target_id};
    
    if ($monster) {
        AI::queue('attack', $target_id);
    }
}

sub apply_skill_action {
    my ($action) = @_;
    return unless defined $action->{id};
    
    my $skill_id = $action->{id};
    my $level = $action->{level} // 1;
    my $target = $action->{target};
    
    if (defined $target) {
        # Target skill
        AI::queue('skill_use', {
            skill => $skill_id,
            target => $target,
            lv => $level,
        });
    }
    elsif (defined $action->{x} && defined $action->{y}) {
        # Ground skill
        AI::queue('skill_use', {
            skill => $skill_id,
            x => $action->{x},
            y => $action->{y},
            lv => $level,
        });
    }
    else {
        # Self skill
        AI::queue('skill_use', {
            skill => $skill_id,
            target => $char->{ID},
            lv => $level,
        });
    }
}

sub apply_item_action {
    my ($action) = @_;
    return unless defined $action->{id};
    
    my $item_id = $action->{id};
    my $amount = $action->{amount} // 1;
    
    # Find item in inventory
    if ($char && $char->{inventory}) {
        my $item = $char->{inventory}->getByNameID($item_id);
        if ($item) {
            AI::queue('useSelf', {
                item => $item,
                amount => $amount,
            });
        }
    }
}

sub apply_pick_item_action {
    my ($action) = @_;
    return unless defined $action->{target};
    
    my $item_id = $action->{target};
    my $item = $items{$item_id};
    
    if ($item) {
        AI::queue('take', {
            item => $item_id,
        });
    }
}

###############################################################################
# Configuration Management
###############################################################################

=head2 load_config

Loads plugin configuration from AI_Bridge.txt and applies defaults.

=cut

sub load_config {
    # Apply defaults first
    for my $key (keys %defaults) {
        $config{$key} //= $defaults{$key};
    }
    
    debug_msg("Configuration loaded");
}

=head2 get_config

Gets configuration value with fallback to defaults.

=cut

sub get_config {
    my ($key) = @_;
    return $config{$key} // $defaults{$key};
}

###############################################################################
# Utility Functions
###############################################################################

=head2 debug_msg

Outputs debug message if debug mode is enabled.

=cut

sub debug_msg {
    my ($msg) = @_;
    debug "[AI_Bridge] $msg\n" if get_config('AI_Bridge_debug');
}

=head2 encode_json / decode_json

JSON encode/decode wrappers.

=cut

sub encode_json {
    my ($data) = @_;
    if ($JSON eq 'JSON::XS') {
        return JSON::XS::encode_json($data);
    }
    return JSON::encode_json($data);
}

sub decode_json {
    my ($json) = @_;
    if ($JSON eq 'JSON::XS') {
        return JSON::XS::decode_json($json);
    }
    return JSON::decode_json($json);
}

1;

__END__

=head1 NAME

AI_Bridge - God-Tier AI Bridge Plugin for OpenKore

=head1 SYNOPSIS

    # In config.txt or control/config.txt:
    AI_Bridge_enabled 1
    AI_Bridge_address tcp://127.0.0.1:5555
    AI_Bridge_timeout_ms 50
    AI_Bridge_debug 0

=head1 DESCRIPTION

This plugin bridges OpenKore to an external AI Sidecar process via ZeroMQ IPC,
enabling advanced AI decision-making capabilities. The plugin sends game state
updates to the sidecar and receives action decisions to execute.

The architecture follows a sidecar pattern where:
  - OpenKore (Perl) uses ZMQ REQ socket
  - AI Sidecar (Python) uses ZMQ REP socket
  - Communication is JSON-encoded messages

=head1 GRACEFUL DEGRADATION

If the AI Sidecar is unavailable:
  - Plugin enters "degraded mode"
  - OpenKore's built-in AI continues operating
  - Automatic reconnection attempts are made
  - No crashes or blocking behavior

=head1 CONFIGURATION

=over 4

=item AI_Bridge_enabled

Enable/disable the plugin (0 or 1). Default: 1

=item AI_Bridge_address

ZMQ socket address for the sidecar. Default: tcp://127.0.0.1:5555

=item AI_Bridge_timeout_ms

Message timeout in milliseconds. Default: 50

=item AI_Bridge_reconnect_ms

Reconnection attempt interval. Default: 5000

=item AI_Bridge_heartbeat_ms

Heartbeat interval (0 to disable). Default: 5000

=item AI_Bridge_debug

Enable debug logging. Default: 0

=item AI_Bridge_log_state

Log full game state (verbose). Default: 0

=back

=head1 REQUIREMENTS

=over 4

=item * ZMQ module (ZMQ::FFI recommended, or ZMQ::LibZMQ4)

=item * JSON module (JSON::XS recommended, or JSON)

=item * libzmq library installed on system

=back

=head1 AUTHOR

AI MMORPG Team

=head1 VERSION

0.1.0

=cut