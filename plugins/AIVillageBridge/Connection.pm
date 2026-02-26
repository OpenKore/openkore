package AIVillageBridge::Connection;

use strict;
use warnings;

use IO::Socket::INET;
use Errno qw(EAGAIN EWOULDBLOCK EINTR EPIPE ECONNRESET);
use Utils qw(dataWaiting min);
use Log qw(message error warning debug);
use Time::HiRes qw(time);
use JSON::Tiny qw(from_json to_json);

##
# AIVillageBridge::Connection->new(%args)
#
# Constructor. Arguments (as a hash):
#   host            - sidecar host (default '127.0.0.1')
#   port            - sidecar port (default 6801)
#   bot_id          - identifier sent during handshake
#   buffer_size     - max ring buffer entries (default 1000)
#   on_message      - coderef called with decoded hashref for non-internal messages
#   on_connected    - coderef called when handshake completes
#   on_disconnected - coderef called when connection drops
##
sub new {
    my ($class, %args) = @_;

    my $self = bless {
        host        => $args{host}        // '127.0.0.1',
        port        => $args{port}        // 6801,
        bot_id      => $args{bot_id}      // 'bot-unknown',
        buffer_size => $args{buffer_size} // 1000,

        on_message      => $args{on_message}      // sub {},
        on_connected    => $args{on_connected}    // sub {},
        on_disconnected => $args{on_disconnected} // sub {},

        # Internal state
        sock               => undef,
        state              => 'disconnected',  # disconnected | connecting | handshaking | connected
        send_buf           => '',
        recv_buf           => '',
        ring_buffer        => [],

        reconnect_at      => 0,       # connect immediately on first iterate()
        reconnect_backoff => 0,       # 0 signals "first attempt" (see _schedule_reconnect)

        last_ping_time    => 0,
        protocol_version  => undef,
        handshake_pending => 0,
    }, $class;

    return $self;
}

##
# $conn->is_connected()
# Returns true if the connection is fully established (handshake complete).
##
sub is_connected {
    my ($self) = @_;
    return $self->{state} eq 'connected';
}

##
# $conn->send_message($msg_hashref)
#
# Encodes $msg_hashref as a JSON line and enqueues it.
# If connected: appended to send_buf for non-blocking write.
# If disconnected: pushed to ring_buffer (oldest dropped when full).
##
sub send_message {
    my ($self, $msg) = @_;

    my $line;
    eval { $line = to_json($msg) . "\n" };
    if ($@) {
        warning "[AIVillageBridge::Connection] Failed to encode message to JSON: $@\n";
        return;
    }

    if ($self->{state} eq 'connected' || $self->{state} eq 'handshaking') {
        $self->{send_buf} .= $line;
    } else {
        # Enqueue to ring buffer; drop oldest if at capacity
        if (@{$self->{ring_buffer}} >= $self->{buffer_size}) {
            shift @{$self->{ring_buffer}};
            debug "[AIVillageBridge::Connection] Ring buffer full; dropped oldest event\n";
        }
        push @{$self->{ring_buffer}}, $line;
    }
}

##
# $conn->flush_ring_buffer()
#
# Moves all buffered ring_buffer entries into send_buf for transmission.
# Called automatically after a successful handshake.
##
sub flush_ring_buffer {
    my ($self) = @_;

    my $count = scalar @{$self->{ring_buffer}};
    return unless $count;

    message "[AIVillageBridge::Connection] Flushing $count buffered event(s) to sidecar\n";
    while (@{$self->{ring_buffer}}) {
        $self->{send_buf} .= shift @{$self->{ring_buffer}};
    }
}

##
# $conn->disconnect($reason)
#
# Closes the socket, resets state, calls on_disconnected, and schedules a reconnect.
##
sub disconnect {
    my ($self, $reason) = @_;
    $reason //= 'unknown reason';

    if (defined $self->{sock}) {
        eval { close($self->{sock}) };
        $self->{sock} = undef;
    }

    my $prev_state = $self->{state};
    $self->{state}            = 'disconnected';
    $self->{recv_buf}         = '';
    $self->{handshake_pending} = 0;

    message "[AIVillageBridge::Connection] Disconnected: $reason\n";

    # Only call on_disconnected if we were actually connected or connecting
    if ($prev_state ne 'disconnected') {
        eval { $self->{on_disconnected}->() };
        warning "[AIVillageBridge::Connection] on_disconnected callback error: $@\n" if $@;
    }

    $self->_schedule_reconnect();
}

##
# $conn->iterate()
#
# Main loop tick. Must be called from mainLoop_post (~every 10ms).
# Performs: connect attempt / non-blocking read / line processing / non-blocking write / heartbeat check.
##
sub iterate {
    my ($self) = @_;

    if ($self->{state} eq 'disconnected') {
        $self->_maybe_reconnect();
        return;
    }

    # Non-blocking read
    $self->_do_read();
    return if $self->{state} eq 'disconnected';  # read may have triggered disconnect

    # Heartbeat check (only when fully connected)
    if ($self->{state} eq 'connected') {
        $self->_check_heartbeat();
        return if $self->{state} eq 'disconnected';
    }

    # Non-blocking write
    $self->_do_write();
}

# ---------------------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------------------

##
# $conn->_maybe_reconnect()
# Checks if the reconnect timer has elapsed and attempts a new connection.
##
sub _maybe_reconnect {
    my ($self) = @_;

    return if time() < $self->{reconnect_at};

    message "[AIVillageBridge::Connection] Attempting connection to $self->{host}:$self->{port}\n";

    # Non-blocking connect: returns immediately; socket is usable once writable.
    my $sock = IO::Socket::INET->new(
        PeerHost => $self->{host},
        PeerPort => $self->{port},
        Proto    => 'tcp',
        Blocking => 0,
        Timeout  => 0,
    );

    if (!$sock) {
        # EINPROGRESS / EWOULDBLOCK are expected for non-blocking connects.
        # Any other error means the connect attempt itself failed before queuing.
        unless ($! == EINTR || $! == EWOULDBLOCK || ($! == 115)) {  # 115 = EINPROGRESS
            warning "[AIVillageBridge::Connection] Connect failed immediately: $!\n";
        }
        # Either way, we treat as "in progress" if $sock is defined; here it is not.
        # Schedule a retry.
        $self->_schedule_reconnect();
        return;
    }

    $self->{sock}  = $sock;
    $self->{state} = 'handshaking';
    $self->{last_ping_time} = time();
    $self->{handshake_pending} = 1;

    # Send hello immediately; the kernel will buffer it until the connection completes.
    $self->_send_hello();
}

##
# $conn->_send_hello()
# Encodes and appends the hello handshake message to send_buf.
##
sub _send_hello {
    my ($self) = @_;

    my $hello = {
        type             => 'hello',
        protocol_version => 1,
        bot_id           => $self->{bot_id},
        plugin_version   => '0.1.0',
    };

    my $line;
    eval { $line = to_json($hello) . "\n" };
    if ($@) {
        error "[AIVillageBridge::Connection] Failed to encode hello: $@\n";
        $self->disconnect("hello encode failed");
        return;
    }

    $self->{send_buf} .= $line;
    debug "[AIVillageBridge::Connection] Sent hello handshake\n";
}

##
# $conn->_do_read()
# Attempts a non-blocking sysread. Appends to recv_buf and processes complete lines.
##
sub _do_read {
    my ($self) = @_;

    return unless defined $self->{sock};
    return unless dataWaiting(\$self->{sock}, 0);

    my $bytes = sysread($self->{sock}, my $buf, 4096);

    if (!defined $bytes) {
        if ($! == EAGAIN || $! == EWOULDBLOCK || $! == EINTR) {
            # Transient — nothing to read right now
            return;
        }
        $self->disconnect("read error: $!");
        return;
    }

    if ($bytes == 0) {
        $self->disconnect("remote closed connection");
        return;
    }

    $self->{recv_buf} .= $buf;

    # Parse and dispatch all complete newline-terminated JSON lines
    while ($self->{recv_buf} =~ s/^([^\n]*)\n//) {
        my $line = $1;
        $self->_process_line($line);
        last if $self->{state} eq 'disconnected';  # disconnect inside loop
    }

    # Safety cap: discard oversized recv_buf (max line length per ADR: 64KB)
    if (length($self->{recv_buf}) > 65536) {
        warning "[AIVillageBridge::Connection] recv_buf exceeds 64KB — discarding buffer\n";
        $self->{recv_buf} = '';
    }
}

##
# $conn->_do_write()
# Attempts a non-blocking syswrite of the pending send_buf.
##
sub _do_write {
    my ($self) = @_;

    return unless $self->{send_buf} && defined $self->{sock};

    my $written = syswrite($self->{sock}, $self->{send_buf});

    if (!defined $written) {
        if ($! == EAGAIN || $! == EWOULDBLOCK || $! == EINTR) {
            # Can't write now — try next iteration
            return;
        }
        if ($! == EPIPE || $! == ECONNRESET) {
            $self->disconnect("write error: broken pipe");
            return;
        }
        $self->disconnect("write error: $!");
        return;
    }

    # Consume the written bytes from the front of the buffer
    substr($self->{send_buf}, 0, $written) = '';
    debug "[AIVillageBridge::Connection] Wrote $written byte(s) to sidecar\n";
}

##
# $conn->_process_line($line)
# Decodes a single JSON line and handles built-in message types or dispatches to on_message.
##
sub _process_line {
    my ($self, $line) = @_;

    return unless length($line);

    my $msg;
    eval { $msg = from_json($line) };
    if ($@ || !defined $msg || ref($msg) ne 'HASH') {
        warning "[AIVillageBridge::Connection] Failed to decode JSON line: $@\n";
        return;
    }

    my $type = $msg->{type} // '';

    if ($type eq 'ping') {
        # Reply with pong and record timestamp
        $self->{last_ping_time} = time();
        $self->send_message({ type => 'pong' });
        debug "[AIVillageBridge::Connection] Received ping; sent pong\n";
        return;
    }

    if ($type eq 'welcome') {
        if ($self->{state} ne 'handshaking') {
            warning "[AIVillageBridge::Connection] Received welcome in unexpected state '$self->{state}'\n";
            return;
        }
        $self->{protocol_version}  = $msg->{protocol_version};
        $self->{handshake_pending} = 0;
        $self->{state}             = 'connected';
        $self->{last_ping_time}    = time();
        # Reset backoff on successful connect
        $self->{reconnect_backoff} = 0;

        message "[AIVillageBridge::Connection] Handshake complete (protocol_version=$self->{protocol_version})\n";

        # Flush any buffered events accumulated while disconnected
        $self->flush_ring_buffer();

        eval { $self->{on_connected}->() };
        warning "[AIVillageBridge::Connection] on_connected callback error: $@\n" if $@;
        return;
    }

    if ($type eq 'error') {
        my $code = $msg->{code} // '';
        if ($code eq 'VERSION_MISMATCH') {
            error "[AIVillageBridge::Connection] Fatal: sidecar rejected protocol version (VERSION_MISMATCH). Not reconnecting.\n";
            # Close socket without scheduling reconnect
            if (defined $self->{sock}) {
                eval { close($self->{sock}) };
                $self->{sock} = undef;
            }
            $self->{state}            = 'disconnected';
            $self->{recv_buf}         = '';
            $self->{handshake_pending} = 0;
            # Set reconnect_at to a very far future so iterate() never reconnects
            $self->{reconnect_at} = time() + 86400 * 365;
            eval { $self->{on_disconnected}->() };
            return;
        }
        error "[AIVillageBridge::Connection] Received error from sidecar: code=$code msg=" . ($msg->{message} // '') . "\n";
        # Non-fatal error messages are passed to on_message
        eval { $self->{on_message}->($msg) };
        warning "[AIVillageBridge::Connection] on_message callback error: $@\n" if $@;
        return;
    }

    # All other message types go to the plugin's on_message callback
    eval { $self->{on_message}->($msg) };
    warning "[AIVillageBridge::Connection] on_message callback error: $@\n" if $@;
}

##
# $conn->_check_heartbeat()
# Disconnects if no ping has been received in the last 45 seconds.
##
sub _check_heartbeat {
    my ($self) = @_;

    return unless $self->{last_ping_time};

    my $elapsed = time() - $self->{last_ping_time};
    if ($elapsed > 45) {
        warning "[AIVillageBridge::Connection] Heartbeat timeout ($elapsed s since last ping)\n";
        $self->disconnect("heartbeat timeout");
    }
}

##
# $conn->_schedule_reconnect()
# Computes the next reconnect time with exponential backoff + ±20% jitter.
# Sequence: 1, 2, 4, 8, 16, 30 (capped), then stays at ~30s.
##
sub _schedule_reconnect {
    my ($self) = @_;

    if ($self->{reconnect_backoff} == 0) {
        # First attempt — start at 1 second
        $self->{reconnect_backoff} = 1;
    } else {
        $self->{reconnect_backoff} = min(30, $self->{reconnect_backoff} * 2);
    }

    # Apply ±20% jitter: multiply by a value in [0.8, 1.2)
    my $jitter  = 0.8 + rand(0.4);
    my $backoff = $self->{reconnect_backoff} * $jitter;

    $self->{reconnect_at} = time() + $backoff;
    debug "[AIVillageBridge::Connection] Next reconnect in ${backoff}s\n";
}

1;
