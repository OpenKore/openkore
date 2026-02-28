package AIVillageBridge::CommandExecutor;

use strict;
use warnings;

use Time::HiRes qw(time);

use Commands;
use Globals qw($char %monsters %players %npcs %items @ai_seq @ai_seq_args);
use AI;
use Log qw(message error warning debug);

# Maximum commands to process per AI_pre tick (prevents hogging the AI loop)
use constant MAX_CMDS_PER_TICK => 3;

# Maximum command queue depth before we start dropping oldest entries
use constant MAX_QUEUE_DEPTH => 50;

# Set of supported action names for quick lookup
my %SUPPORTED_ACTIONS = map { $_ => 1 } qw(
    say
    whisper
    move
    attack
    use_skill
    pick_item
    sit
    stand
    equip
    use_item
    npc_talk
    npc_respond
    emote
    flee
    buy
    sell
    party_chat
    party_create
    party_invite_player
    party_accept
    party_decline
    party_leave
    deal_initiate
    deal_accept
    deal_decline
    deal_add_item
    deal_add_zeny
    deal_finalize
    deal_cancel
);

##
# AIVillageBridge::CommandExecutor->new(%args)
#
# Constructor. Arguments (as a hash):
#   on_result - coderef called with ($type, $id, $data) where type is 'ack' or 'error'
##
sub new {
    my ($class, %args) = @_;

    my $self = bless {
        on_result      => $args{on_result} // sub {},
        queue          => [],
        cmd_delay      => $args{cmd_delay} // 0.5,  # seconds between commands
        _last_cmd_time => 0,
    }, $class;

    return $self;
}

##
# $exec->enqueue($cmd_msg)
#
# Enqueue a command message for processing on the next AI_pre tick.
# $cmd_msg should be: {type=>'command', id=>'cmd-123', action=>'say', params=>{...}}
# Oldest entries are dropped when the queue exceeds MAX_QUEUE_DEPTH.
##
sub enqueue {
    my ($self, $cmd_msg) = @_;

    unless (defined $cmd_msg && ref($cmd_msg) eq 'HASH') {
        warning "[AIVillageBridge::CommandExecutor] enqueue() called with non-hashref argument\n";
        return;
    }

    # Cap queue depth — drop oldest to make room
    if (scalar(@{$self->{queue}}) >= MAX_QUEUE_DEPTH) {
        my $dropped = shift @{$self->{queue}};
        warning "[AIVillageBridge::CommandExecutor] Queue full; dropped oldest command: "
            . ($dropped->{id} // 'unknown') . "\n";
    }

    push @{$self->{queue}}, $cmd_msg;
    debug "[AIVillageBridge::CommandExecutor] Enqueued command id=" . ($cmd_msg->{id} // 'unknown')
        . " action=" . ($cmd_msg->{action} // 'unknown') . "\n";
}

##
# $exec->process_queue()
#
# Process up to MAX_CMDS_PER_TICK queued commands. Must be called from an AI_pre hook.
##
sub process_queue {
    my ($self) = @_;

    return unless @{$self->{queue}};

    # Enforce delay between commands
    my $now = Time::HiRes::time();
    if ($self->{cmd_delay} > 0 && ($now - $self->{_last_cmd_time}) < $self->{cmd_delay}) {
        return;  # Too soon since last command, wait for next tick
    }

    my $processed = 0;
    while (@{$self->{queue}} && $processed < MAX_CMDS_PER_TICK) {
        my $cmd = shift @{$self->{queue}};
        $self->_execute($cmd);
        $processed++;
        $self->{_last_cmd_time} = Time::HiRes::time();

        # If delay is configured, only process one command per tick
        # (let the delay gate the next one on the following tick)
        last if $self->{cmd_delay} > 0;
    }
}

##
# $exec->queue_depth()
#
# Returns the current number of commands waiting in the queue.
##
sub queue_depth {
    my ($self) = @_;
    return scalar @{$self->{queue}};
}

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

##
# $exec->_execute($cmd)
# Validates and dispatches a single command hashref.
##
sub _execute {
    my ($self, $cmd) = @_;

    # --- Structural validation ---
    unless (
        defined $cmd
        && ref($cmd) eq 'HASH'
        && defined $cmd->{type}
        && defined $cmd->{id}
        && defined $cmd->{action}
        && defined $cmd->{params}
        && ref($cmd->{params}) eq 'HASH'
    ) {
        my $id = (ref($cmd) eq 'HASH' && defined $cmd->{id}) ? $cmd->{id} : 'unknown';
        $self->_send_error($id, 'INVALID_PARAMS', 'Command message missing required fields: type, id, action, params');
        return;
    }

    my $id     = $cmd->{id};
    my $action = $cmd->{action};
    my $params = $cmd->{params};

    # --- Action whitelist check ---
    unless ($SUPPORTED_ACTIONS{$action}) {
        $self->_send_error($id, 'INVALID_ACTION', "Unknown action: $action");
        return;
    }

    # --- Dispatch ---
    my $dispatch = {
        say         => \&_cmd_say,
        whisper     => \&_cmd_whisper,
        move        => \&_cmd_move,
        attack      => \&_cmd_attack,
        use_skill   => \&_cmd_use_skill,
        pick_item   => \&_cmd_pick_item,
        sit         => \&_cmd_sit,
        stand       => \&_cmd_stand,
        equip       => \&_cmd_equip,
        use_item    => \&_cmd_use_item,
        npc_talk    => \&_cmd_npc_talk,
        npc_respond => \&_cmd_npc_respond,
        emote       => \&_cmd_emote,
        flee        => \&_cmd_flee,
        buy                 => \&_cmd_buy,
        sell                => \&_cmd_sell,
        party_chat          => \&_cmd_party_chat,
        party_create        => \&_cmd_party_create,
        party_invite_player => \&_cmd_party_invite_player,
        party_accept        => \&_cmd_party_accept,
        party_decline       => \&_cmd_party_decline,
        party_leave         => \&_cmd_party_leave,
        deal_initiate       => \&_cmd_deal_initiate,
        deal_accept         => \&_cmd_deal_accept,
        deal_decline        => \&_cmd_deal_decline,
        deal_add_item       => \&_cmd_deal_add_item,
        deal_add_zeny       => \&_cmd_deal_add_zeny,
        deal_finalize       => \&_cmd_deal_finalize,
        deal_cancel         => \&_cmd_deal_cancel,
    };

    my $handler = $dispatch->{$action};
    eval { $handler->($self, $id, $params) };
    if ($@) {
        my $err = $@;
        $err =~ s/\n$//;
        warning "[AIVillageBridge::CommandExecutor] Uncaught exception dispatching action '$action' (id=$id): $err\n";
        $self->_send_error($id, 'EXECUTION_FAILED', $err);
    }
}

# --- Individual command handlers ---

sub _cmd_say {
    my ($self, $id, $params) = @_;

    my $msg = $params->{message};
    unless (defined $msg && length($msg) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "say: 'message' param is required");
        return;
    }

    $msg = $self->_sanitize($msg, 80);
    eval { Commands::run("c $msg") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed say");
}

sub _cmd_whisper {
    my ($self, $id, $params) = @_;

    my $player = $params->{player};
    my $msg    = $params->{message};
    unless (defined $player && length($player) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "whisper: 'player' param is required");
        return;
    }
    unless (defined $msg && length($msg) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "whisper: 'message' param is required");
        return;
    }

    $player = $self->_sanitize($player, 24);
    $msg    = $self->_sanitize($msg, 80);
    eval { Commands::run("pm \"" . $self->_escape($player) . "\" $msg") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed whisper");
}

sub _cmd_move {
    my ($self, $id, $params) = @_;

    my $map = $params->{map};
    my $x   = $params->{x};
    my $y   = $params->{y};

    unless (defined $map && length($map) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "move: 'map' param is required");
        return;
    }
    $map = $self->_sanitize($map, 40);
    unless (defined $x && $x =~ /^\d+$/) {
        $self->_send_error($id, 'INVALID_PARAMS', "move: 'x' param must be a non-negative integer");
        return;
    }
    unless (defined $y && $y =~ /^\d+$/) {
        $self->_send_error($id, 'INVALID_PARAMS', "move: 'y' param must be a non-negative integer");
        return;
    }

    # Clear existing route to avoid conflict
    eval { AI::clear('route') };
    eval { Commands::run("move $map $x $y") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed move");
}

sub _cmd_attack {
    my ($self, $id, $params) = @_;

    my $monster_id = $params->{monster_id};
    unless (defined $monster_id && length($monster_id)) {
        $self->_send_error($id, 'INVALID_PARAMS', "attack: 'monster_id' param is required");
        return;
    }

    # monster_id is a hex string emitted by the plugin (e.g. "0a1b2c3d")
    # %monsters is keyed by binary 4-byte actor IDs — convert before lookup
    my $bin_id = eval { pack('H*', $monster_id) };
    if ($@ || !defined $bin_id) {
        $self->_send_error($id, 'INVALID_PARAMS', "attack: invalid monster_id format");
        return;
    }

    unless (exists $monsters{$bin_id}) {
        $self->_send_error($id, 'TARGET_NOT_FOUND', "attack: monster '$monster_id' not found in current game state");
        return;
    }

    eval { AI::clear('attack'); AI::attack($bin_id) };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed attack");
}

sub _cmd_use_skill {
    my ($self, $id, $params) = @_;

    my $skill       = $params->{skill};
    my $level       = $params->{level};         # optional skill level
    my $target_type = $params->{target_type};   # self, monster, player, location (default: self)
    my $target      = $params->{target};        # target index (for monster/player)
    my $x           = $params->{x};             # for location targeting
    my $y           = $params->{y};             # for location targeting

    unless (defined $skill && length($skill) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "use_skill: 'skill' param is required");
        return;
    }

    $skill = $self->_sanitize($skill, 50);
    $target_type //= 'self';

    my $cmd;
    if ($target_type eq 'self') {
        $cmd = "ss $skill";
        $cmd .= " $level" if defined $level && $level =~ /^\d+$/;
    }
    elsif ($target_type eq 'monster') {
        unless (defined $target && $target =~ /^\d+$/) {
            $self->_send_error($id, 'INVALID_PARAMS', "use_skill: 'target' (monster index) is required for target_type=monster");
            return;
        }
        $cmd = "sm $skill $target";
        $cmd .= " $level" if defined $level && $level =~ /^\d+$/;
    }
    elsif ($target_type eq 'player') {
        unless (defined $target && $target =~ /^\d+$/) {
            $self->_send_error($id, 'INVALID_PARAMS', "use_skill: 'target' (player index) is required for target_type=player");
            return;
        }
        $cmd = "sp $skill $target";
        $cmd .= " $level" if defined $level && $level =~ /^\d+$/;
    }
    elsif ($target_type eq 'location') {
        unless (defined $x && $x =~ /^\d+$/ && defined $y && $y =~ /^\d+$/) {
            $self->_send_error($id, 'INVALID_PARAMS', "use_skill: 'x' and 'y' coords are required for target_type=location");
            return;
        }
        $cmd = "sl $skill $x $y";
        $cmd .= " $level" if defined $level && $level =~ /^\d+$/;
    }
    else {
        $self->_send_error($id, 'INVALID_PARAMS', "use_skill: invalid target_type '$target_type' (expected: self, monster, player, location)");
        return;
    }

    eval { Commands::run($cmd) };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed use_skill ($target_type)");
}

sub _cmd_pick_item {
    my ($self, $id, $params) = @_;

    my $item_id = $params->{item_id};
    unless (defined $item_id && length($item_id)) {
        $self->_send_error($id, 'INVALID_PARAMS', "pick_item: 'item_id' param is required");
        return;
    }

    # item_id is a hex string emitted by the plugin — convert to binary ground item ID
    my $bin_id = eval { pack('H*', $item_id) };
    if ($@ || !defined $bin_id) {
        $self->_send_error($id, 'INVALID_PARAMS', "pick_item: invalid item_id format");
        return;
    }

    unless (exists $items{$bin_id}) {
        $self->_send_error($id, 'TARGET_NOT_FOUND', "pick_item: item '$item_id' not found in current game state");
        return;
    }

    eval { AI::gather($bin_id) };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed pick_item");
}

sub _cmd_sit {
    my ($self, $id, $params) = @_;

    eval { Commands::run("sit") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed sit");
}

sub _cmd_stand {
    my ($self, $id, $params) = @_;

    eval { Commands::run("stand") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed stand");
}

sub _cmd_equip {
    my ($self, $id, $params) = @_;

    my $item_name = $params->{item_name};
    unless (defined $item_name && length($item_name) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "equip: 'item_name' param is required");
        return;
    }

    $item_name = $self->_sanitize($item_name, 100);
    eval { Commands::run("eq $item_name") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed equip");
}

sub _cmd_use_item {
    my ($self, $id, $params) = @_;

    my $item_name = $params->{item_name};
    unless (defined $item_name && length($item_name) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "use_item: 'item_name' param is required");
        return;
    }

    $item_name = $self->_sanitize($item_name, 100);
    eval { Commands::run("is $item_name") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed use_item");
}

sub _cmd_npc_talk {
    my ($self, $id, $params) = @_;

    my $npc_id = $params->{npc_id};
    unless (defined $npc_id && length($npc_id)) {
        $self->_send_error($id, 'INVALID_PARAMS', "npc_talk: 'npc_id' param is required");
        return;
    }

    # npc_id is a hex string emitted by the plugin — convert to binary actor ID
    my $bin_id = eval { pack('H*', $npc_id) };
    if ($@ || !defined $bin_id) {
        $self->_send_error($id, 'INVALID_PARAMS', "npc_talk: invalid npc_id format");
        return;
    }

    unless (exists $npcs{$bin_id}) {
        $self->_send_error($id, 'TARGET_NOT_FOUND', "npc_talk: npc '$npc_id' not found in current game state");
        return;
    }

    # OpenKore's 'talk' command expects a display index; use the NPC's binID which
    # reflects its position in the visible list (set by OpenKore's NPC parser).
    my $bin_idx = $npcs{$bin_id}{binID};
    unless (defined $bin_idx && $bin_idx =~ /^\d+$/) {
        $self->_send_error($id, 'TARGET_NOT_FOUND', "npc_talk: npc '$npc_id' has no binID");
        return;
    }
    eval { Commands::run("talk $bin_idx") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed npc_talk");
}

sub _cmd_npc_respond {
    my ($self, $id, $params) = @_;

    my $response = $params->{response};
    unless (defined $response && length($response) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "npc_respond: 'response' param is required");
        return;
    }

    $response = $self->_sanitize($response, 255);
    eval { Commands::run("talk resp $response") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed npc_respond");
}

sub _cmd_emote {
    my ($self, $id, $params) = @_;

    # OpenKore's 'e' command accepts emotion command strings from tables/emotions.txt
    # (e.g., "lv" for heart, "!" for exclamation, "ho" for delight, "heh" for grin).
    # The Temporal layer should send the command string, not a numeric ID.
    my $emote_cmd = $params->{emote_command} // $params->{emote_id};
    unless (defined $emote_cmd && length($emote_cmd) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "emote: 'emote_command' param is required (e.g., 'lv', '!', 'ho')");
        return;
    }

    $emote_cmd = $self->_sanitize($emote_cmd, 20);
    eval { Commands::run("e $emote_cmd") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed emote");
}

sub _cmd_flee {
    my ($self, $id, $params) = @_;

    # Uses OpenKore's teleport command which requires Fly Wings in inventory.
    # If no Fly Wings are available, the teleport will silently fail.

    # Clear current combat/movement actions so the bot stops fighting
    eval {
        AI::clear('attack');
        AI::clear('route');
    };

    eval { Commands::run("tele") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed flee");
}

sub _cmd_buy {
    my ($self, $id, $params) = @_;

    # PREREQUISITE: NPC store dialog must be open before calling this action.
    # The Temporal workflow should send npc_talk + npc_respond first to navigate
    # to the buy screen. This handler executes the actual purchase.
    my $item_index = $params->{item_index};
    my $quantity   = $params->{quantity} // 1;

    unless (defined $item_index && $item_index =~ /^\d+$/) {
        $self->_send_error($id, 'INVALID_PARAMS', "buy: 'item_index' param must be a non-negative integer");
        return;
    }
    unless ($quantity =~ /^\d+$/ && $quantity > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "buy: 'quantity' must be a positive integer");
        return;
    }

    eval { Commands::run("buy $item_index $quantity") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed buy");
}

sub _cmd_sell {
    my ($self, $id, $params) = @_;

    # PREREQUISITE: NPC sell dialog must be open before calling this action.
    # The Temporal workflow should send npc_talk + npc_respond first to navigate
    # to the sell screen. This handler adds the item and finalizes the sale.
    my $item_index = $params->{item_index};
    my $quantity   = $params->{quantity} // 1;

    unless (defined $item_index && $item_index =~ /^\d+$/) {
        $self->_send_error($id, 'INVALID_PARAMS', "sell: 'item_index' param must be a non-negative integer");
        return;
    }
    unless ($quantity =~ /^\d+$/ && $quantity > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "sell: 'quantity' must be a positive integer");
        return;
    }

    # Add item to sell list, then finalize
    eval { Commands::run("sell $item_index $quantity") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    eval { Commands::run("sell done") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed sell");
}

# --- Party commands ---

sub _cmd_party_chat {
    my ($self, $id, $params) = @_;
    my $msg = $params->{message};
    unless (defined $msg && length($msg) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "party_chat: 'message' param is required");
        return;
    }
    $msg = $self->_sanitize($msg, 80);
    eval { Commands::run("p $msg") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed party_chat");
}

sub _cmd_party_create {
    my ($self, $id, $params) = @_;
    my $name = $params->{name};
    unless (defined $name && length($name) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "party_create: 'name' param is required");
        return;
    }
    $name = $self->_sanitize($name, 24);
    eval { Commands::run("party create \"" . $self->_escape($name) . "\"") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed party_create");
}

sub _cmd_party_invite_player {
    my ($self, $id, $params) = @_;
    my $player = $params->{player};
    unless (defined $player && length($player) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "party_invite_player: 'player' param is required");
        return;
    }
    $player = $self->_sanitize($player, 24);
    eval { Commands::run("party request $player") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed party_invite_player");
}

sub _cmd_party_accept {
    my ($self, $id, $params) = @_;
    eval { Commands::run("party join 1") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed party_accept");
}

sub _cmd_party_decline {
    my ($self, $id, $params) = @_;
    eval { Commands::run("party join 0") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed party_decline");
}

sub _cmd_party_leave {
    my ($self, $id, $params) = @_;
    eval { Commands::run("party leave") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed party_leave");
}

# --- Trade (deal) commands ---

sub _cmd_deal_initiate {
    my ($self, $id, $params) = @_;
    my $player = $params->{player};
    unless (defined $player && length($player) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "deal_initiate: 'player' param is required");
        return;
    }
    $player = $self->_sanitize($player, 24);
    eval { Commands::run("deal \"" . $self->_escape($player) . "\"") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_initiate");
}

sub _cmd_deal_accept {
    my ($self, $id, $params) = @_;
    eval { Commands::run("deal") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_accept");
}

sub _cmd_deal_decline {
    my ($self, $id, $params) = @_;
    eval { Commands::run("deal no") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_decline");
}

sub _cmd_deal_add_item {
    my ($self, $id, $params) = @_;
    my $item = $params->{item_name};
    my $qty  = $params->{quantity} // 1;
    unless (defined $item && length($item) > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "deal_add_item: 'item_name' param is required");
        return;
    }
    unless ($qty =~ /^\d+$/ && $qty > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "deal_add_item: 'quantity' must be a positive integer");
        return;
    }
    $item = $self->_sanitize($item, 100);
    eval { Commands::run("deal add \"" . $self->_escape($item) . "\" $qty") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_add_item");
}

sub _cmd_deal_add_zeny {
    my ($self, $id, $params) = @_;
    my $amount = $params->{amount};
    unless (defined $amount && $amount =~ /^\d+$/ && $amount > 0) {
        $self->_send_error($id, 'INVALID_PARAMS', "deal_add_zeny: 'amount' must be a positive integer");
        return;
    }
    eval { Commands::run("deal add z $amount") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_add_zeny");
}

sub _cmd_deal_finalize {
    my ($self, $id, $params) = @_;
    eval { Commands::run("deal") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_finalize");
}

sub _cmd_deal_cancel {
    my ($self, $id, $params) = @_;
    eval { Commands::run("deal no") };
    if ($@) { $self->_send_error($id, 'EXECUTION_FAILED', $@); return; }
    $self->_send_ack($id, "executed deal_cancel");
}

# --- Helpers ---

##
# $exec->_escape($str) -> string
#
# Escape backslashes and double-quotes so the string is safe to interpolate
# inside a double-quoted argument to Commands::run().
##
sub _escape {
    my ($self, $str) = @_;
    $str =~ s/\\/\\\\/g;
    $str =~ s/"/\\"/g;
    return $str;
}

##
# $exec->_sanitize($str, $max_len) -> string
#
# Strip OpenKore command separators, newlines, trim whitespace, and truncate to $max_len.
##
sub _sanitize {
    my ($self, $str, $max_len) = @_;
    return '' unless defined $str;
    $str =~ s/;;/ /g;       # Strip OpenKore command separator
    $str =~ s/[\r\n]/ /g;   # Strip newlines
    $str =~ s/^\s+|\s+$//g; # Trim whitespace
    $str = substr($str, 0, $max_len) if length($str) > $max_len;
    return $str;
}

##
# $exec->_send_ack($id, $detail)
# Invoke the on_result callback with ('ack', $id, {detail => $detail}).
##
sub _send_ack {
    my ($self, $id, $detail) = @_;
    $detail //= '';
    debug "[AIVillageBridge::CommandExecutor] ACK id=$id detail=$detail\n";
    eval { $self->{on_result}->('ack', $id, { detail => $detail }) };
    warning "[AIVillageBridge::CommandExecutor] on_result callback error: $@\n" if $@;
}

##
# $exec->_send_error($id, $code, $message)
# Invoke the on_result callback with ('error', $id, {code => $code, message => $message}).
##
sub _send_error {
    my ($self, $id, $code, $msg) = @_;
    $code //= 'INTERNAL_ERROR';
    $msg  //= 'Unknown error';
    warning "[AIVillageBridge::CommandExecutor] ERROR id=$id code=$code msg=$msg\n";
    eval { $self->{on_result}->('error', $id, { code => $code, message => $msg }) };
    warning "[AIVillageBridge::CommandExecutor] on_result callback error: $@\n" if $@;
}

1;
