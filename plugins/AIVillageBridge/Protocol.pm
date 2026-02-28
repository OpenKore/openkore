package AIVillageBridge::Protocol;

use strict;
use warnings;

use JSON::Tiny qw(from_json to_json);
use Time::HiRes qw(time);
use Log qw(message error warning debug);

# Protocol version this module implements
use constant PROTOCOL_VERSION => 1;

# Priority constants
use constant PRIORITY_CRITICAL => 'critical';
use constant PRIORITY_HIGH     => 'high';
use constant PRIORITY_MEDIUM   => 'medium';
use constant PRIORITY_LOW      => 'low';

# Error code constants
use constant ERR_INVALID_ACTION    => 'INVALID_ACTION';
use constant ERR_INVALID_PARAMS    => 'INVALID_PARAMS';
use constant ERR_TARGET_NOT_FOUND  => 'TARGET_NOT_FOUND';
use constant ERR_EXECUTION_FAILED  => 'EXECUTION_FAILED';
use constant ERR_CONFIG_PARSE_ERROR => 'CONFIG_PARSE_ERROR';
use constant ERR_INTERNAL_ERROR    => 'INTERNAL_ERROR';

# new(bot_id => '...', plugin_version => '...')
sub new {
    my ($class, %args) = @_;
    my $self = bless {
        bot_id         => $args{bot_id}         || 'unknown',
        plugin_version => $args{plugin_version} || '0.0.0',
    }, $class;
    return $self;
}

# encode($msg_hashref) -> "...\n" or undef on error
sub encode {
    my ($self, $msg) = @_;

    unless (defined $msg && ref($msg) eq 'HASH') {
        warning("[AIVillageBridge::Protocol] encode() called with non-hashref argument\n");
        return undef;
    }

    my $json;
    eval {
        $json = to_json($msg);
    };
    if ($@) {
        warning("[AIVillageBridge::Protocol] JSON encode error: $@\n");
        return undef;
    }

    return $json . "\n";
}

# decode($json_line) -> hashref or undef on error
sub decode {
    my ($self, $line) = @_;

    unless (defined $line) {
        warning("[AIVillageBridge::Protocol] decode() called with undef argument\n");
        return undef;
    }

    # Strip trailing newline/whitespace
    $line =~ s/[\r\n]+$//;

    my $msg;
    eval {
        $msg = from_json($line);
    };
    if ($@) {
        warning("[AIVillageBridge::Protocol] JSON decode error: $@\n");
        return undef;
    }

    unless (ref($msg) eq 'HASH') {
        warning("[AIVillageBridge::Protocol] Decoded JSON is not a hash object\n");
        return undef;
    }

    return $msg;
}

# build_hello() -> hashref
# {"type":"hello","protocol_version":1,"bot_id":"bot-1","plugin_version":"0.1.0"}
sub build_hello {
    my ($self) = @_;
    return {
        type             => 'hello',
        protocol_version => PROTOCOL_VERSION,
        bot_id           => $self->{bot_id},
        plugin_version   => $self->{plugin_version},
    };
}

# build_pong($ping_ts) -> hashref
# {"type":"pong","ts":1709000000}
sub build_pong {
    my ($self, $ping_ts) = @_;
    return {
        type => 'pong',
        ts   => defined($ping_ts) ? $ping_ts : time(),
    };
}

# build_event($event_name, $priority, $data_hashref) -> hashref
# {"type":"event","ts":...,"bot_id":"...","event":"pub_msg","priority":"high","data":{...}}
sub build_event {
    my ($self, $event_name, $priority, $data) = @_;

    $data     //= {};
    $priority //= PRIORITY_MEDIUM;

    return {
        type     => 'event',
        ts       => time(),
        bot_id   => $self->{bot_id},
        event    => $event_name,
        priority => $priority,
        data     => $data,
    };
}

# build_state_response($request_id, $state_data_hashref) -> hashref
# {"type":"state_response","id":"req-789","bot_id":"...","ts":...,"data":{...}}
sub build_state_response {
    my ($self, $request_id, $state_data) = @_;

    $state_data //= {};

    return {
        type   => 'state_response',
        id     => $request_id,
        bot_id => $self->{bot_id},
        ts     => time(),
        data   => $state_data,
    };
}

# build_ack($id, $detail_string) -> hashref
# {"type":"ack","id":"cmd-123","status":"ok","result":{"detail":"..."}}
sub build_ack {
    my ($self, $id, $detail) = @_;

    $detail //= '';

    return {
        type   => 'ack',
        id     => $id,
        status => 'ok',
        result => { detail => $detail },
    };
}

# build_error($id, $error_code, $message_string) -> hashref
# {"type":"error","id":"cmd-123","code":"INVALID_ACTION","message":"Unknown action: dance"}
sub build_error {
    my ($self, $id, $error_code, $message) = @_;

    $error_code //= ERR_INTERNAL_ERROR;
    $message    //= 'Unknown error';

    return {
        type    => 'error',
        id      => $id,
        code    => $error_code,
        message => $message,
    };
}

1;
