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
    $char $field $accountID %config @ai_seq @ai_seq_args
    %monsters %players %npcs %items %portals
    @monstersID @playersID @npcsID @itemsID
    $conState $net $messageSender
);
use Utils qw(distance timeOut);
use AI;

# Import chat bridge for message access
use lib "$Plugins::current_plugin_folder/..";
eval {
    require GodTierChatBridge;
    GodTierChatBridge->import();
};
our $CHAT_BRIDGE_AVAILABLE = !$@;
if ($CHAT_BRIDGE_AVAILABLE) {
    message "[AI_Bridge] Chat bridge plugin detected and loaded\n", "info";
} else {
    warning "[AI_Bridge] Chat bridge plugin not available - chat integration disabled\n";
}

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
    
    # Add party information (P1 Important - Party Bridge)
    my $party_state = build_party_state();
    if ($party_state) {
        $state->{party} = $party_state;
        debug_msg("Included party information with " . $party_state->{member_count} . " members")
            if get_config('AI_Bridge_debug');
    }
    
    # Add guild information (P1 Important - Guild Bridge)
    my $guild_state = build_guild_state();
    if ($guild_state) {
        $state->{guild} = $guild_state;
        debug_msg("Included guild information: " . $guild_state->{name})
            if get_config('AI_Bridge_debug');
    }
    
    # Add companion states (P2 Important - Companion Bridge)
    my $pet_state = build_pet_state();
    if ($pet_state) {
        $state->{pet} = $pet_state;
        debug_msg("Included pet information: " . $pet_state->{name})
            if get_config('AI_Bridge_debug');
    }
    
    my $homun_state = build_homunculus_state();
    if ($homun_state) {
        $state->{homunculus} = $homun_state;
        debug_msg("Included homunculus information: " . $homun_state->{type})
            if get_config('AI_Bridge_debug');
    }
    
    my $merc_state = build_mercenary_state();
    if ($merc_state) {
        $state->{mercenary} = $merc_state;
        debug_msg("Included mercenary information: " . $merc_state->{type})
            if get_config('AI_Bridge_debug');
    }
    
    my $mount_state = build_mount_state();
    $state->{mount} = $mount_state;
    debug_msg("Mount state: mounted=" . $mount_state->{is_mounted})
        if get_config('AI_Bridge_debug');
    
    my $equipment_state = build_equipment_state();
    $state->{equipment} = $equipment_state;
    debug_msg("Included " . scalar(keys %$equipment_state) . " equipped items")
        if get_config('AI_Bridge_debug');
    
    # Add NPC dialogue state (P3 Advanced - NPC Bridge)
    my $npc_dialogue = build_npc_dialogue_state();
    if ($npc_dialogue) {
        $state->{npc_dialogue} = $npc_dialogue;
        debug_msg("In dialogue with NPC: " . $npc_dialogue->{npc_name})
            if get_config('AI_Bridge_debug');
    }
    
    # Add quest state (P3 Advanced - Quest Bridge)
    my $quest_state = build_quest_state();
    $state->{quests} = $quest_state;
    debug_msg("Active quests: " . $quest_state->{quest_count})
        if get_config('AI_Bridge_debug') && $quest_state->{quest_count} > 0;
    
    # Add market data (P3 Advanced - Economy Bridge)
    my $market_state = build_market_state();
    $state->{market} = $market_state;
    debug_msg("Visible vendors: " . $market_state->{vendor_count})
        if get_config('AI_Bridge_debug') && $market_state->{vendor_count} > 0;
    
    # Add environment state (P3 Advanced - Environment Bridge)
    my $environment = build_environment_state();
    $state->{environment} = $environment;
    debug_msg(sprintf("Environment: night=%d, weather=%d",
        $environment->{is_night}, $environment->{weather_type}))
        if get_config('AI_Bridge_debug');
    
    # Add ground items (P3 Advanced - Ground Items Bridge)
    my $ground_items = build_ground_items_state();
    if (@$ground_items > 0) {
        $state->{ground_items} = $ground_items;
        debug_msg("Ground items visible: " . scalar(@$ground_items))
            if get_config('AI_Bridge_debug');
    }
    
    # Add instance state (P4 Final - Instance Bridge)
    my $instance_state = build_instance_state();
    $state->{instance} = $instance_state;
    debug_msg(sprintf("Instance state: in_instance=%d, floor=%d",
        $instance_state->{in_instance}, $instance_state->{current_floor}))
        if get_config('AI_Bridge_debug');
    
    # Add chat messages if bridge is available
    if ($CHAT_BRIDGE_AVAILABLE) {
        eval {
            my $chat_messages = GodTierChatBridge::get_chat_messages_for_state();
            if ($chat_messages && ref($chat_messages) eq 'ARRAY') {
                $state->{extra} = {
                    chat_messages => $chat_messages,
                };
                debug_msg(sprintf("Included %d chat messages in game state", scalar(@$chat_messages)))
                    if get_config('AI_Bridge_debug') && @$chat_messages;
            } else {
                $state->{extra} = {
                    chat_messages => [],
                };
            }
        };
        if ($@) {
            warning "[AI_Bridge] Failed to retrieve chat messages: $@\n";
            $state->{extra} = {
                chat_messages => [],
            };
        }
    } else {
        # Chat bridge not available, provide empty array
        $state->{extra} = {
            chat_messages => [],
        };
    }
    
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
        
        # Enhanced status effects (P1 Important - Combat Bridge)
        status_effects => sub {
            my @effects = ();
            if ($char->{statuses}) {
                foreach my $status_id (keys %{$char->{statuses}}) {
                    my $status = $char->{statuses}{$status_id};
                    push @effects, {
                        effect_id => $status_id,
                        name => $status->{name} || "Status_$status_id",
                        is_negative => $status->{is_negative} || 0,
                        duration => $status->{duration} || 0,
                    };
                }
            }
            return \@effects;
        }->(),
        
        # Active buffs (P1 Important - Buff Bridge)
        buffs => build_buff_state(),
        
        weight         => $char->{weight} // 0,
        weight_max     => $char->{weight_max} // 1,
        zeny           => $char->{zeny} // 0,
        
        # Character Stats (P0 Critical - Progression Bridge)
        str            => $char->{str} || 0,
        agi            => $char->{agi} || 0,
        vit            => $char->{vit} || 0,
        int            => $char->{int} || 0,
        dex            => $char->{dex} || 0,
        luk            => $char->{luk} || 0,
        
        # Experience Values (P0 Critical - Progression Bridge)
        base_exp       => $char->{exp} || 0,
        base_exp_max   => $char->{exp_max} || 0,
        job_exp        => $char->{exp_job} || 0,
        job_exp_max    => $char->{exp_job_max} || 0,
        
        # Available Points (P0 Critical - Progression Bridge)
        stat_points    => $char->{points_free} || 0,
        skill_points   => $char->{points_skill} || 0,
        
        # Learned Skills (P0 Critical - Combat Bridge)
        learned_skills => sub {
            my $skills_hash = {};
            if ($char->{skills}) {
                debug_msg("Extracting learned skills data") if get_config('AI_Bridge_debug');
                foreach my $skill_name (keys %{$char->{skills}}) {
                    my $skill = $char->{skills}{$skill_name};
                    next unless $skill && $skill->{lv};
                    $skills_hash->{$skill_name} = {
                        level   => $skill->{lv},
                        sp_cost => $skill->{sp} || 0,
                    };
                }
                debug_msg(sprintf("Extracted %d learned skills", scalar(keys %$skills_hash)))
                    if get_config('AI_Bridge_debug');
            }
            return $skills_hash;
        }->(),
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

=head2 build_party_state

Extracts party information (P1 Important - Party Bridge).

=cut

sub build_party_state {
    my ($self) = @_;
    
    return undef unless $char->{party};
    
    my $party_info = $char->{party};
    my @members = ();
    
    # Extract party members
    if ($party_info->{users}) {
        foreach my $member_id (keys %{$party_info->{users}}) {
            my $member = $party_info->{users}{$member_id};
            next unless $member;
            
            push @members, {
                char_id => $member_id,
                name => $member->{name} || '',
                hp => $member->{hp} || 0,
                hp_max => $member->{hp_max} || 0,
                sp => $member->{sp} || 0,
                sp_max => $member->{sp_max} || 0,
                job_class => $member->{jobID} || 0,
                online => $member->{online} ? 1 : 0,
                is_leader => ($member_id == $party_info->{leader}) ? 1 : 0,
            };
        }
    }
    
    return {
        party_id => $party_info->{name} || '',  # Party name acts as ID
        name => $party_info->{name} || '',
        members => \@members,
        member_count => scalar(@members),
    };
}

=head2 build_guild_state

Extracts guild information (P1 Important - Guild Bridge).

=cut

sub build_guild_state {
    my ($self) = @_;
    
    return undef unless $char->{guild};
    
    my $guild_info = $char->{guild};
    
    return {
        guild_id => $guild_info->{ID} || 0,
        name => $guild_info->{name} || '',
        level => $guild_info->{lvl} || 1,
        member_count => $guild_info->{members} || 0,
        max_members => $guild_info->{max_members} || 0,
        average_level => $guild_info->{average_lv} || 0,
        exp => $guild_info->{exp} || 0,
        exp_max => $guild_info->{next_exp} || 0,
    };
}

=head2 build_buff_state

Extracts active buffs (P1 Important - Buff Bridge).

=cut

sub build_buff_state {
    my ($self) = @_;
    
    my @buffs = ();
    
    # Extract active buffs from status effects
    if ($char->{statuses}) {
        foreach my $status_id (keys %{$char->{statuses}}) {
            my $status = $char->{statuses}{$status_id};
            next unless $status;
            
            # Only include beneficial buffs (filter out debuffs if possible)
            # In OpenKore, statuses include both buffs and debuffs
            # We'll include all with expiry times
            
            push @buffs, {
                buff_id => $status_id,
                name => $status->{name} || "Unknown_$status_id",
                expires_at => $status->{tick} || 0,  # Tick when buff expires
                duration => $status->{duration} || 0,
            };
        }
    }
    
    return \@buffs;
}

=head2 build_pet_state

Extracts pet companion information (P2 Important - Companion Bridge).

=cut

sub build_pet_state {
    my ($self) = @_;
    
    return undef unless $char->{pet};
    
    my $pet = $char->{pet};
    
    return {
        pet_id => $pet->{id} || 0,
        name => $pet->{name} || '',
        intimacy => $pet->{friendly} || 0,  # 0-1000 scale
        hunger => $pet->{hungry} || 0,      # 0-100 scale
        is_summoned => $pet->{appear_time} ? 1 : 0,
    };
}

=head2 build_homunculus_state

Extracts homunculus companion information (P2 Important - Companion Bridge).

=cut

sub build_homunculus_state {
    my ($self) = @_;
    
    return undef unless $char->{homunculus};
    
    my $homun = $char->{homunculus};
    
    return {
        type => $homun->{name} || '',
        level => $homun->{level} || 1,
        hp => $homun->{hp} || 0,
        hp_max => $homun->{hp_max} || 0,
        sp => $homun->{sp} || 0,
        sp_max => $homun->{sp_max} || 0,
        intimacy => $homun->{intimacy} || 0,
        hunger => $homun->{hunger} || 0,
        skill_points => $homun->{points_skill} || 0,
        stats => {
            str => $homun->{str} || 0,
            agi => $homun->{agi} || 0,
            vit => $homun->{vit} || 0,
            int => $homun->{int} || 0,
            dex => $homun->{dex} || 0,
            luk => $homun->{luk} || 0,
        },
    };
}

=head2 build_mercenary_state

Extracts mercenary companion information (P2 Important - Companion Bridge).

=cut

sub build_mercenary_state {
    my ($self) = @_;
    
    return undef unless $char->{mercenary};
    
    my $merc = $char->{mercenary};
    
    return {
        type => $merc->{name} || '',
        level => $merc->{level} || 1,
        hp => $merc->{hp} || 0,
        hp_max => $merc->{hp_max} || 0,
        sp => $merc->{sp} || 0,
        sp_max => $merc->{sp_max} || 0,
        contract_remaining => $merc->{expire_time} || 0,
        faith => $merc->{faith} || 0,
    };
}

=head2 build_mount_state

Extracts mount and cart information (P2 Important - Companion Bridge).

=cut

sub build_mount_state {
    my ($self) = @_;
    
    return {
        is_mounted => $char->{mounted} ? 1 : 0,
        mount_type => $char->{mount_type} || 0,
        has_cart => $char->{cart} ? 1 : 0,
        cart_weight => $char->{cart_weight} || 0,
        cart_weight_max => $char->{cart_max_weight} || 0,
        cart_items_count => $char->{cart_items_count} || 0,
    };
}

=head2 build_equipment_state

Extracts equipped items information (P2 Important - Equipment Bridge).

=cut

sub build_equipment_state {
    my ($self) = @_;
    
    my %equipment = ();
    
    # Map equipment slots
    my %slot_names = (
        0 => 'head_top',
        1 => 'head_mid',
        2 => 'head_low',
        3 => 'armor',
        4 => 'weapon',
        5 => 'shield',
        6 => 'shoes',
        7 => 'accessory_left',
        8 => 'accessory_right',
        9 => 'garment',
        10 => 'ammo',
    );
    
    # Extract equipped items from inventory
    if ($char->{inventory}) {
        foreach my $item (@{$char->{inventory}->getItems()}) {
            next unless $item->{equipped};
            
            # Determine slot from equipped value
            foreach my $slot_id (keys %slot_names) {
                my $slot_bit = 2 ** $slot_id;
                if ($item->{equipped} & $slot_bit) {
                    $equipment{$slot_names{$slot_id}} = {
                        item_id => $item->{nameID},
                        name => $item->{name},
                        refine_level => $item->{upgrade} || 0,
                        broken => $item->{broken} || 0,
                        identified => $item->{identified} || 0,
                    };
                }
            }
        }
    }
    
    return \%equipment;
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

=head2 build_npc_dialogue_state

Extracts NPC dialogue state (P3 Advanced - NPC Bridge).

=cut

sub build_npc_dialogue_state {
    my ($self) = @_;
    
    # Check if in NPC dialogue
    return undef unless $talk{ID};
    
    my $npc_id = $talk{ID};
    my $npc_name = $talk{nameID} || '';
    
    # Get current dialogue state
    my $state = {
        npc_id => $npc_id,
        npc_name => $npc_name,
        in_dialogue => 1,
    };
    
    # Check if there are dialogue options
    if ($talk{responses}) {
        $state->{has_choices} = 1;
        $state->{choices} = [];
        
        foreach my $key (keys %{$talk{responses}}) {
            push @{$state->{choices}}, {
                index => $key,
                text => $talk{responses}{$key},
            };
        }
    }
    
    # Check if waiting for input
    if ($talk{msg}) {
        $state->{current_text} = $talk{msg};
    }
    
    return $state;
}

=head2 build_quest_state

Extracts quest state (P3 Advanced - Quest Bridge).

=cut

sub build_quest_state {
    my ($self) = @_;
    
    my @active_quests = ();
    
    # Extract quest data from questList
    if ($questList && ref($questList) eq 'HASH') {
        foreach my $quest_id (keys %{$questList}) {
            my $quest = $questList->{$quest_id};
            next unless $quest;
            
            push @active_quests, {
                quest_id => $quest_id,
                name => $quest->{title} || "Quest_$quest_id",
                time_limit => $quest->{time} || 0,
                mob_objectives => $quest->{mobs} || [],
                item_objectives => $quest->{items} || [],
                is_complete => $quest->{complete} ? 1 : 0,
            };
        }
    }
    
    return {
        active_quests => \@active_quests,
        quest_count => scalar(@active_quests),
    };
}

=head2 build_market_state

Extracts market/vendor data (P3 Advanced - Economy Bridge).

=cut

sub build_market_state {
    my ($self) = @_;
    
    my @vendors = ();
    
    # Extract player vendors from venderLists
    if ($venderLists && ref($venderLists) eq 'HASH') {
        foreach my $vendor_id (keys %{$venderLists}) {
            my $vendor = $venderLists->{$vendor_id};
            next unless $vendor;
            
            my @items = ();
            if ($vendor->{items}) {
                foreach my $item (@{$vendor->{items}}) {
                    push @items, {
                        item_id => $item->{nameID},
                        name => $item->{name},
                        price => $item->{price},
                        amount => $item->{amount},
                    };
                }
            }
            
            push @vendors, {
                vendor_id => $vendor_id,
                vendor_name => $vendor->{title} || '',
                position => {
                    x => $vendor->{pos}{x} || 0,
                    y => $vendor->{pos}{y} || 0,
                },
                items => \@items,
            };
        }
    }
    
    return {
        vendors => \@vendors,
        vendor_count => scalar(@vendors),
    };
}

=head2 build_environment_state

Extracts environment/time state (P3 Advanced - Environment Bridge).

=cut

sub build_environment_state {
    my ($self) = @_;
    
    return {
        server_time => time(),  # Unix timestamp
        is_night => $field->isNight() ? 1 : 0,
        weather_type => $weather || 0,  # 0=clear, 1=rain, 2=snow, etc.
    };
}

=head2 build_ground_items_state

Extracts ground items (P3 Advanced - Ground Items Bridge).

=cut

sub build_ground_items_state {
    my ($self) = @_;
    
    my @items = ();
    
    # Extract items on ground
    if ($itemsList && ref($itemsList) eq 'HASH') {
        foreach my $item_id (keys %{$itemsList}) {
            my $item = $itemsList->{$item_id};
            next unless $item;
            
            push @items, {
                id => $item_id,
                item_id => $item->{nameID},
                name => $item->{name},
                amount => $item->{amount} || 1,
                position => {
                    x => $item->{pos}{x} || 0,
                    y => $item->{pos}{y} || 0,
                },
            };
        }
    }
    
    return \@items;
}

=head2 build_instance_state

Extracts instance/dungeon state (P4 Final - Instance Bridge).

=cut

sub build_instance_state {
    my ($self) = @_;
    
    # Check if in instance
    my $in_instance = 0;
    my $instance_name = '';
    my $current_floor = 0;
    my $time_limit = 0;
    
    # Try to detect instance state from map name patterns
    if ($field && $field->{name}) {
        my $map_name = $field->{name};
        
        # Endless Tower detection (map names: 1@tower, 2@tower, etc.)
        if ($map_name =~ /^(\d+)\@tower$/) {
            $in_instance = 1;
            $instance_name = 'Endless Tower';
            $current_floor = $1;
        }
        # Memorial dungeon patterns (e.g., 1@gef, 1@orc, 1@md_gef)
        elsif ($map_name =~ /^(\d+)\@(\w+)$/) {
            $in_instance = 1;
            $instance_name = "Instance_$2";
            $current_floor = $1;
        }
    }
    
    return {
        in_instance => $in_instance,
        instance_name => $instance_name,
        current_floor => $current_floor,
        time_limit => $time_limit,
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
    elsif ($type eq 'allocate_stat') {
        # Allocate stat points (P0 Critical - Progression Bridge)
        my $stat = $action->{stat}; # "STR", "AGI", "VIT", "INT", "DEX", "LUK"
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI requested stat allocation: $stat +$amount");
        
        for (my $i = 0; $i < $amount; $i++) {
            Commands::run("stat_add $stat");
        }
    }
    elsif ($type eq 'allocate_skill') {
        # Allocate skill points (P0 Critical - Combat Bridge)
        my $skill_name = $action->{skill};
        my $level = $action->{level};
        
        debug_msg("AI requested skill allocation: $skill_name to level $level");
        
        # Add skill points until desired level
        Commands::run("skills add $skill_name");
    }
    elsif ($type eq 'party_heal') {
        # Heal party member (P1 Important - Party Bridge)
        my $target_id = $action->{target_id};
        my $skill_name = $action->{skill_name} || 'Heal';
        
        debug_msg("AI requested party heal on target $target_id");
        Commands::run("sl $skill_name $target_id");
    }
    elsif ($type eq 'party_buff') {
        # Buff party member (P1 Important - Party Bridge)
        my $target_id = $action->{target_id};
        my $skill_name = $action->{skill_name};
        
        debug_msg("AI requested party buff $skill_name on target $target_id");
        Commands::run("sl $skill_name $target_id");
    }
    elsif ($type eq 'feed_pet') {
        # Feed pet (P2 Important - Companion Bridge)
        my $food_id = $action->{food_id};
        
        debug_msg("AI requested pet feeding with item $food_id");
        Commands::run("pet feed $food_id");
    }
    elsif ($type eq 'homun_skill') {
        # Homunculus skill (P2 Important - Companion Bridge)
        my $skill_id = $action->{skill_id};
        my $target_id = $action->{target_id} || 0;
        
        debug_msg("AI requested homunculus skill $skill_id");
        Commands::run("homun_skill $skill_id $target_id");
    }
    elsif ($type eq 'mount') {
        # Mount (P2 Important - Companion Bridge)
        debug_msg("AI requested mount");
        Commands::run("mount");
    }
    elsif ($type eq 'dismount') {
        # Dismount (P2 Important - Companion Bridge)
        debug_msg("AI requested dismount");
        Commands::run("mount");  # Toggle command
    }
    elsif ($type eq 'npc_talk') {
        # Initiate NPC dialogue (P3 Advanced - NPC Bridge)
        my $npc_id = $action->{npc_id};
        
        debug_msg("AI requested NPC talk with $npc_id");
        Commands::run("talk $npc_id");
    }
    elsif ($type eq 'npc_choose') {
        # Choose dialogue option (P3 Advanced - NPC Bridge)
        my $choice_index = $action->{choice_index};
        
        debug_msg("AI chose dialogue option $choice_index");
        Commands::run("talk resp $choice_index");
    }
    elsif ($type eq 'npc_close') {
        # Close NPC dialogue (P3 Advanced - NPC Bridge)
        debug_msg("AI closed NPC dialogue");
        Commands::run("talk cont");  # Continue to close
    }
    elsif ($type eq 'chat_send') {
        # Send chat message (P3 Advanced - Communication)
        my $channel = $action->{channel} || 'public';
        my $content = $action->{content};
        
        debug_msg("AI sending chat to $channel: $content");
        
        if ($channel eq 'public') {
            Commands::run("c $content");
        } elsif ($channel eq 'party') {
            Commands::run("p $content");
        } elsif ($channel eq 'guild') {
            Commands::run("g $content");
        } elsif ($channel eq 'whisper') {
            my $target = $action->{target_name};
            Commands::run("pm \"$target\" $content");
        }
    }
    elsif ($type eq 'teleport') {
        # Teleport (P3 Advanced - Movement)
        debug_msg("AI requested teleport");
        Commands::run("tele");
    }
    elsif ($type eq 'drop_item') {
        # Drop inventory item (P3 Advanced - Inventory)
        my $item_index = $action->{item_index};
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI dropping item $item_index x$amount");
        Commands::run("drop $item_index $amount");
    }
    elsif ($type eq 'equip_item') {
        # Equip item (P3 Advanced - Equipment)
        my $item_index = $action->{item_index};
        
        debug_msg("AI equipping item $item_index");
        Commands::run("eq $item_index");
    }
    elsif ($type eq 'unequip_item') {
        # Unequip item (P3 Advanced - Equipment)
        my $slot = $action->{slot};
        
        debug_msg("AI unequipping slot $slot");
        Commands::run("uneq $slot");
    }
    elsif ($type eq 'storage_get') {
        # Get from storage (P3 Advanced - Storage)
        my $item_index = $action->{item_index};
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI getting from storage: $item_index x$amount");
        Commands::run("storage get $item_index $amount");
    }
    elsif ($type eq 'storage_add') {
        # Add to storage (P3 Advanced - Storage)
        my $item_index = $action->{item_index};
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI adding to storage: $item_index x$amount");
        Commands::run("storage add $item_index $amount");
    }
    elsif ($type eq 'buy_from_npc') {
        # Buy from NPC (P3 Advanced - Economy)
        my $item_id = $action->{item_id};
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI buying from NPC: item $item_id x$amount");
        Commands::run("buy $item_id $amount");
    }
    elsif ($type eq 'sell_to_npc') {
        # Sell to NPC (P3 Advanced - Economy)
        my $item_index = $action->{item_index};
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI selling to NPC: $item_index x$amount");
        Commands::run("sell $item_index $amount");
    }
    elsif ($type eq 'buy_from_vendor') {
        # Buy from player vendor (P3 Advanced - Economy)
        my $vendor_id = $action->{vendor_id};
        my $item_index = $action->{item_index};
        my $amount = $action->{amount} || 1;
        
        debug_msg("AI buying from vendor $vendor_id: item $item_index x$amount");
        Commands::run("vender $vendor_id $item_index $amount");
    }
    elsif ($type eq 'enter_instance') {
        # Enter instance dungeon (P4 Final - Instance)
        my $instance_name = $action->{instance_name} || '';
        
        debug_msg("AI requesting instance entry: $instance_name");
        # Implementation depends on specific instance entry mechanism
        # May require NPC dialogue or portal interaction
        # For now, we log the intent
    }
    elsif ($type eq 'next_floor') {
        # Proceed to next floor in instance (P4 Final - Instance)
        debug_msg("AI requesting next floor");
        # Usually involves portal or warp interaction
        Commands::run("move");  # Move to portal location if specified
    }
    elsif ($type eq 'exit_instance') {
        # Exit current instance (P4 Final - Instance)
        debug_msg("AI requesting instance exit");
        Commands::run("tele");  # Or use specific exit mechanism
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