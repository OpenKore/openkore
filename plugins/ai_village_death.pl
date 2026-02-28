# ai_village_death.pl
# AI Village — Death event plugin for the 10-lives system (AIRO-31)
#
# Fires an HTTP POST to the Temporal signal server whenever the bot dies,
# including death cause, map, and the current life/lives-remaining counters
# managed in a local state file.
#
# Configuration (in config.txt or via environment variables):
#   ai_village_signal_host [hostname]   (default: localhost)
#   ai_village_signal_port [port]       (default: 7778)
#   ai_village_bot_id      [id]         (default: character name)
#
# State file: control/ai_village_lives.txt
#   Format:  key<TAB>value  (one per line)
#   Keys:    current_life, lives_remaining
#   Example:
#     current_life    3
#     lives_remaining 7

package ai_village_death;

use strict;
use warnings;

use Plugins;
use Globals qw($char $field %config %damageTaken %monsters %players $accountID);
use Log qw(message warning error debug);
use IO::Socket::INET;
use Time::HiRes qw(time);
use Errno qw(EAGAIN EWOULDBLOCK);

# ---------------------------------------------------------------------------
# Plugin registration
# ---------------------------------------------------------------------------

Plugins::register('ai_village_death', 'AI Village death event plugin (AIRO-31)', \&onUnload);

my $hooks = Plugins::addHooks(
    ['self_died', \&onSelfDied, undef],
);

# ---------------------------------------------------------------------------
# Configuration (resolved once at load time; env overrides %config)
# ---------------------------------------------------------------------------

my $signal_host = $ENV{AIVILLAGE_SIGNAL_HOST}
                  || $config{ai_village_signal_host}
                  || 'localhost';

my $signal_port = $ENV{AIVILLAGE_SIGNAL_PORT}
                  || $config{ai_village_signal_port}
                  || 7778;

# bot_id is resolved lazily in onSelfDied because $char may not be set at load time
my $_bot_id_override = $ENV{AIVILLAGE_BOT_ID} || $config{ai_village_bot_id} || '';

# State file lives alongside other control files
my $state_file = 'control/ai_village_lives.txt';

# Max total lives per agent (lives start at this number)
my $max_lives = 10;

# HTTP timeout in seconds for the signal POST
my $http_timeout = 5;

# ---------------------------------------------------------------------------
# Unload callback
# ---------------------------------------------------------------------------

sub onUnload {
    Plugins::delHooks($hooks);
    message "[ai_village_death] Plugin unloaded\n", 'system';
}

# ---------------------------------------------------------------------------
# Death hook callback
# ---------------------------------------------------------------------------

sub onSelfDied {
    my ($hookName, $args) = @_;

    eval {
        # ---- 1. Resolve bot ID ----
        my $bot_id = $_bot_id_override
                     || ($char ? $char->{name} : '')
                     || 'bot-unknown';

        # ---- 2. Resolve current map ----
        my $death_map = ($field ? $field->name() : '') || 'unknown';

        # ---- 3. Determine death cause and type ----
        my ($death_cause, $death_cause_type) = _infer_death_cause();

        # ---- 4. Update lives state file ----
        my ($current_life, $lives_remaining) = _load_lives_state();

        # Increment life counter (1 → 2 means we just died for the 2nd time, etc.)
        $current_life++;
        if ($lives_remaining > 0) {
            $lives_remaining--;
        }

        _save_lives_state($current_life, $lives_remaining);

        # ---- 5. Log the death ----
        message "[ai_village_death] Bot '$bot_id' died on '$death_map' "
              . "(cause: $death_cause [$death_cause_type], "
              . "life=$current_life, remaining=$lives_remaining)\n",
              'ai_village';

        # ---- 6. POST to Temporal signal server ----
        my $payload = _build_json_payload(
            $death_cause, $death_cause_type, $death_map,
            $current_life, $lives_remaining,
        );

        my $url_path = "/signal/death?bot_id=" . _url_encode($bot_id);
        my $success  = _http_post($signal_host, $signal_port, $url_path, $payload);

        if ($success) {
            message "[ai_village_death] Death signal sent successfully\n", 'ai_village';
        } else {
            warning "[ai_village_death] Failed to send death signal to "
                  . "$signal_host:$signal_port — will NOT retry\n";
        }
    };

    if ($@) {
        error "[ai_village_death] onSelfDied error: $@\n";
    }
}

# ---------------------------------------------------------------------------
# Infer death cause from %damageTaken
#
# %damageTaken is keyed by actor name (string) and has sub-hash:
#   {attack} => cumulative damage dealt to us
#
# Strategy: pick the name with the highest accumulated attack damage.
# Then classify it as monster/player/environment by checking the active
# monster and player lists.
# ---------------------------------------------------------------------------

sub _infer_death_cause {
    my $top_name   = 'unknown';
    my $top_damage = 0;

    for my $name (keys %damageTaken) {
        my $dmg = $damageTaken{$name}{attack} // 0;
        if ($dmg > $top_damage) {
            $top_damage = $dmg;
            $top_name   = $name;
        }
    }

    if ($top_name eq 'unknown' || $top_damage == 0) {
        return ('unknown', 'environment');
    }

    # Classify: check if any visible monster matches by name
    for my $monster (values %monsters) {
        if (defined $monster->{name} && $monster->{name} eq $top_name) {
            return ($top_name, 'monster');
        }
    }

    # Check if any visible player matches by name
    for my $player (values %players) {
        if (defined $player->{name} && $player->{name} eq $top_name) {
            return ($top_name, 'player');
        }
    }

    # Damage was recorded from an actor we no longer see — could be monster or player.
    # Assume monster since bots primarily fight PvE; this is a best-effort heuristic.
    return ($top_name, 'monster');
}

# ---------------------------------------------------------------------------
# State file I/O
#
# Format (tab-separated key value, one per line):
#   current_life<TAB>1
#   lives_remaining<TAB>10
# ---------------------------------------------------------------------------

sub _load_lives_state {
    my %state = (
        current_life    => 0,    # 0 means "not yet tracked; first death will make it 1"
        lives_remaining => $max_lives,
    );

    unless (-f $state_file) {
        debug "[ai_village_death] State file '$state_file' not found; using defaults\n";
        return ($state{current_life}, $state{lives_remaining});
    }

    open(my $fh, '<', $state_file) or do {
        warning "[ai_village_death] Cannot read state file '$state_file': $!\n";
        return ($state{current_life}, $state{lives_remaining});
    };

    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*#/ || $line =~ /^\s*$/;
        if ($line =~ /^(\S+)\s+(\S+)$/) {
            $state{$1} = $2;
        }
    }

    close($fh);

    return (int($state{current_life}), int($state{lives_remaining}));
}

sub _save_lives_state {
    my ($current_life, $lives_remaining) = @_;

    open(my $fh, '>', $state_file) or do {
        warning "[ai_village_death] Cannot write state file '$state_file': $!\n";
        return;
    };

    print $fh "current_life     $current_life\n";
    print $fh "lives_remaining  $lives_remaining\n";

    close($fh);
    debug "[ai_village_death] State file updated: life=$current_life remaining=$lives_remaining\n";
}

# ---------------------------------------------------------------------------
# JSON payload builder (manual — no JSON module dependency)
# ---------------------------------------------------------------------------

sub _build_json_payload {
    my ($death_cause, $death_cause_type, $death_map, $current_life, $lives_remaining) = @_;

    my $cause     = _json_string($death_cause);
    my $cause_type = _json_string($death_cause_type);
    my $map        = _json_string($death_map);

    return qq|{"deathCause":$cause,"deathCauseType":$cause_type,"deathMap":$map,"lifeNumber":$current_life,"livesRemaining":$lives_remaining}|;
}

sub _json_string {
    my ($s) = @_;
    $s //= '';
    $s =~ s/\\/\\\\/g;
    $s =~ s/"/\\"/g;
    $s =~ s/\n/\\n/g;
    $s =~ s/\r/\\r/g;
    $s =~ s/\t/\\t/g;
    return qq|"$s"|;
}

# ---------------------------------------------------------------------------
# HTTP POST via raw IO::Socket::INET (no LWP dependency)
# Returns 1 on success (2xx response), 0 on failure.
# ---------------------------------------------------------------------------

sub _http_post {
    my ($host, $port, $path, $body) = @_;

    my $sock = IO::Socket::INET->new(
        PeerHost => $host,
        PeerPort => $port,
        Proto    => 'tcp',
        Timeout  => $http_timeout,
    );

    unless ($sock) {
        warning "[ai_village_death] Could not connect to $host:$port: $!\n";
        return 0;
    }

    my $body_len = length($body);
    my $request  = join("\r\n",
        "POST $path HTTP/1.0",
        "Host: $host:$port",
        "Content-Type: application/json",
        "Content-Length: $body_len",
        "Connection: close",
        "",
        $body,
    );

    # Write request
    my $written = syswrite($sock, $request);
    unless (defined $written && $written == length($request)) {
        warning "[ai_village_death] Failed to write HTTP request: $!\n";
        close($sock);
        return 0;
    }

    # Read response — blocking socket with Timeout; read until EOF or header boundary
    my $response = '';
    while (1) {
        my $buf;
        my $n = sysread($sock, $buf, 4096);
        if (!defined $n) {
            last if $! == EAGAIN || $! == EWOULDBLOCK;  # transient
            last;  # real error
        }
        last if $n == 0;  # EOF
        $response .= $buf;
        last if $response =~ /\r\n\r\n/;  # headers complete
    }

    close($sock);

    # Parse status code from "HTTP/1.x NNN ..."
    if ($response =~ m{^HTTP/\d+\.\d+\s+(\d+)}) {
        my $code = $1;
        if ($code >= 200 && $code < 300) {
            return 1;
        }
        warning "[ai_village_death] Signal server returned HTTP $code\n";
        return 0;
    }

    warning "[ai_village_death] Could not parse HTTP response from signal server\n";
    return 0;
}

# ---------------------------------------------------------------------------
# URL encode a string (percent-encode non-unreserved characters)
# ---------------------------------------------------------------------------

sub _url_encode {
    my ($s) = @_;
    $s =~ s/([^A-Za-z0-9\-._~])/sprintf("%%%02X", ord($1))/ge;
    return $s;
}

# ---------------------------------------------------------------------------
# Startup message
# ---------------------------------------------------------------------------

message "[ai_village_death] Plugin loaded. Signal endpoint: $signal_host:$signal_port"
      . " | State file: $state_file\n", 'system';

1;
