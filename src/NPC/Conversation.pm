package NPC::Conversation;

use strict;
use warnings;

use Time::HiRes qw(time);

use Globals qw(%ai_v %talk $messageSender);
use Log qw(debug warning error);
use Plugins;
use Translation qw(T TF);

use constant {
	STATE_CLOSED       => 'CLOSED',
	STATE_OPENING      => 'OPENING',
	STATE_TEXT         => 'TEXT',
	STATE_NEXT         => 'NEXT',
	STATE_RESPONSES    => 'RESPONSES',
	STATE_NUMBER_INPUT => 'NUMBER_INPUT',
	STATE_TEXT_INPUT   => 'TEXT_INPUT',
	STATE_CLOSING      => 'CLOSING',
	STATE_BUY_OR_SELL  => 'BUY_OR_SELL',
	STATE_STORE        => 'STORE',
	STATE_SELL         => 'SELL',
	STATE_CASH         => 'CASH',
	STATE_ERROR        => 'ERROR',
};

my %state = _default_state();

sub _default_state {
	return (
		active         => 0,
		state          => STATE_CLOSED,
		npc_id         => undef,
		name_id        => undef,
		npc_name       => undef,
		text_lines     => [],
		last_text      => undef,
		responses      => [],
		image          => undef,
		last_packet    => undef,
		last_update    => 0,
		opened_at      => undef,
		sequence_id    => 0,
		waiting_server => 0,
		error          => undef,
		legacy_talk    => undef,
		scheduled_time => undef,
		can_close      => 0,
	);
}

sub _clone_array {
	my ($items) = @_;
	return [] if !defined $items;
	return [@{$items}];
}

sub _emit_hook {
	my ($hook_name, $extra) = @_;
	my %payload = (
		snapshot         => snapshot(),
		state            => current_state(),
		prompt_state     => prompt_state(),
		npc_id           => current_npc_id(),
		name_id          => current_name_id(),
		npc_name         => current_npc_name(),
		text             => text(),
		text_lines       => text_lines(),
		last_text        => last_text(),
		responses        => responses(),
		legacy_responses => legacy_responses(),
		waiting_server   => is_waiting_server(),
		sequence_id      => sequence_id(),
	);
	if ($extra && ref $extra eq 'HASH') {
		@payload{keys %{$extra}} = values %{$extra};
	}
	Plugins::callHook($hook_name, \%payload);
}

sub _emit_state_changed {
	my ($previous_state, $reason) = @_;
	return if !defined $previous_state && !defined $reason;
	_emit_hook('npc_talk_state_changed', {
		previous_state => $previous_state,
		reason         => $reason,
	});
}

sub _sync_legacy_globals {
	undef %talk;
	delete $ai_v{'npc_talk'};

	return unless $state{active};

	$talk{ID} = $state{npc_id} if defined $state{npc_id};
	$talk{nameID} = $state{name_id} if defined $state{name_id};

	my $message = join("\n", @{$state{text_lines}});
	$talk{msg} = $message if length $message;
	$talk{image} = $state{image} if defined $state{image};

	if (@{$state{responses}}) {
		$talk{responses} = legacy_responses();
	}

	$ai_v{'npc_talk'} = {};
	$ai_v{'npc_talk'}{'ID'} = $state{npc_id} if defined $state{npc_id};
	$ai_v{'npc_talk'}{'talk'} = $state{legacy_talk} if defined $state{legacy_talk};
	$ai_v{'npc_talk'}{'time'} = $state{scheduled_time} if defined $state{scheduled_time};
}

sub _legacy_state_for {
	my ($prompt_state) = @_;
	return undef if !defined $prompt_state || $prompt_state eq STATE_CLOSED;
	return 'initiated'   if $prompt_state eq STATE_OPENING || $prompt_state eq STATE_TEXT;
	return 'next'        if $prompt_state eq STATE_NEXT;
	return 'select'      if $prompt_state eq STATE_RESPONSES;
	return 'number'      if $prompt_state eq STATE_NUMBER_INPUT;
	return 'text'        if $prompt_state eq STATE_TEXT_INPUT;
	return 'close'       if $prompt_state eq STATE_CLOSING;
	return 'buy_or_sell' if $prompt_state eq STATE_BUY_OR_SELL;
	return 'store'       if $prompt_state eq STATE_STORE;
	return 'sell'        if $prompt_state eq STATE_SELL;
	return 'cash'        if $prompt_state eq STATE_CASH;
	return undef;
}

sub _set_prompt_state {
	my ($prompt_state, %opts) = @_;
	my $previous_state = $state{state};

	$state{state} = $prompt_state;
	$state{legacy_talk} = _legacy_state_for($prompt_state);
	$state{waiting_server} = $opts{waiting_server} ? 1 : 0;
	$state{can_close} = $opts{can_close} ? 1 : 0;
	$state{last_update} = time;

	_sync_legacy_globals();
	_emit_state_changed($previous_state, $opts{reason}) if (!defined $opts{emit_state_changed} || $opts{emit_state_changed});
}

sub _begin_conversation {
	my (%args) = @_;
	my $previous_state = $state{state};
	my $is_new = !$state{active}
		|| !defined $state{npc_id}
		|| !defined $args{npc_id}
		|| $state{npc_id} ne $args{npc_id};

	if ($is_new) {
		$state{sequence_id}++;
		$state{opened_at} = time;
		$state{text_lines} = [];
		$state{last_text} = undef;
		$state{responses} = [];
		$state{image} = undef;
		$state{error} = undef;
		$state{waiting_server} = 0;
		$state{can_close} = 0;
	}

	$state{active} = 1;
	$state{npc_id} = $args{npc_id} if exists $args{npc_id};
	$state{name_id} = $args{name_id} if exists $args{name_id};
	$state{npc_name} = $args{npc_name} if exists $args{npc_name};
	$state{scheduled_time} = $args{scheduled_time} if exists $args{scheduled_time};
	$state{last_packet} = $args{last_packet} if exists $args{last_packet};
	$state{last_update} = time;

	_sync_legacy_globals();

	if ($is_new) {
		debug TF("[NPC] Opened conversation with npc_id=%s\n", defined $state{npc_id} ? unpack('V', $state{npc_id}) : 'undef'), 'npc';
		_emit_hook('npc_talk_opened', {
			previous_state => $previous_state,
		});
	}

	return $is_new;
}

sub _mark_waiting_server {
	my (%args) = @_;
	$state{waiting_server} = 1;
	$state{scheduled_time} = exists $args{scheduled_time} ? $args{scheduled_time} : time;
	$state{last_update} = time;
	_sync_legacy_globals();
}

sub _require_sender {
	return 1 if $messageSender;
	error "[NPC] Cannot send NPC interaction packet: message sender is not available.\n";
	return;
}

sub reset {
	my (%args) = @_;
	my $previous_state = $state{state};
	my $sequence_id = $state{sequence_id};

	%state = _default_state();
	$state{sequence_id} = $sequence_id;
	$state{last_update} = time;

	_sync_legacy_globals();
	debug "[NPC] Conversation reset.\n", 'npc';
	_emit_state_changed($previous_state, $args{reason} || 'reset');
}

sub snapshot {
	return {
		active         => $state{active} ? 1 : 0,
		state          => $state{state},
		current_state  => current_state(),
		npc_id         => $state{npc_id},
		name_id        => $state{name_id},
		npc_name       => $state{npc_name},
		text           => text(),
		text_lines     => text_lines(),
		last_text      => $state{last_text},
		responses      => responses(),
		legacy_responses => legacy_responses(),
		image          => $state{image},
		last_packet    => $state{last_packet},
		last_update    => $state{last_update},
		opened_at      => $state{opened_at},
		sequence_id    => $state{sequence_id},
		waiting_server => $state{waiting_server} ? 1 : 0,
		error          => $state{error},
		can_close      => $state{can_close} ? 1 : 0,
		legacy_talk    => $state{legacy_talk},
		scheduled_time => $state{scheduled_time},
	};
}

sub is_open { return $state{active} ? 1 : 0; }
sub is_closed { return $state{active} ? 0 : 1; }
sub current_state { return $state{waiting_server} && $state{state} ne STATE_CLOSED ? 'WAITING_SERVER' : $state{state}; }
sub prompt_state { return $state{state}; }
sub current_npc_id { return $state{npc_id}; }
sub current_name_id { return $state{name_id}; }
sub current_npc_name { return $state{npc_name}; }
sub has_text { return scalar @{$state{text_lines}} ? 1 : 0; }
sub text { return join("\n", @{$state{text_lines}}); }
sub text_lines { return _clone_array($state{text_lines}); }
sub last_text { return $state{last_text}; }
sub has_responses { return scalar @{$state{responses}} ? 1 : 0; }
sub responses { return _clone_array($state{responses}); }
sub response_count { return scalar @{$state{responses}}; }
sub has_image { return defined $state{image} ? 1 : 0; }
sub image { return $state{image}; }
sub expects_continue { return !$state{waiting_server} && $state{state} eq STATE_NEXT; }
sub expects_response { return !$state{waiting_server} && $state{state} eq STATE_RESPONSES; }
sub expects_number { return !$state{waiting_server} && $state{state} eq STATE_NUMBER_INPUT; }
sub expects_text { return !$state{waiting_server} && $state{state} eq STATE_TEXT_INPUT; }
sub can_close {
	return 1 if $state{can_close};
	return 1 if $state{state} =~ /^(?:BUY_OR_SELL|STORE|SELL|CASH)$/;
	return 0;
}
sub last_update_time { return $state{last_update}; }
sub sequence_id { return $state{sequence_id}; }
sub is_waiting_server { return $state{waiting_server} ? 1 : 0; }
sub legacy_talk_state { return $state{legacy_talk}; }
sub scheduled_time { return $state{scheduled_time}; }
sub error_message { return $state{error}; }

sub set_scheduled_time {
	my ($value) = @_;
	$state{scheduled_time} = $value;
	$state{last_update} = time;
	_sync_legacy_globals();
	return $state{scheduled_time};
}

sub clear_scheduled_time {
	undef $state{scheduled_time};
	$state{last_update} = time;
	_sync_legacy_globals();
}

sub set_waiting_server {
	my ($value) = @_;
	$state{waiting_server} = $value ? 1 : 0;
	$state{last_update} = time;
	_sync_legacy_globals();
	return $state{waiting_server};
}

sub response_at {
	my ($index) = @_;
	return undef if !defined $index || $index < 0 || $index >= @{$state{responses}};
	return $state{responses}[$index];
}

sub legacy_responses {
	my @responses = @{$state{responses}};
	push @responses, T('Cancel Chat') if @responses;
	return \@responses;
}

sub cancel_response_index {
	return undef if !@{$state{responses}};
	return scalar @{$state{responses}};
}

sub find_response {
	my ($wanted_text) = @_;
	return undef if !defined $wanted_text;
	for my $index (0 .. $#{$state{responses}}) {
		return $index if $state{responses}[$index] eq $wanted_text;
	}
	return undef;
}

sub find_response_regex {
	my ($pattern, $flags) = @_;
	return undef if !defined $pattern;

	my $regex = eval {
		return $flags && $flags =~ /i/ ? qr/$pattern/i : qr/$pattern/;
	};
	if ($@) {
		warning TF("[NPC] Invalid response regex '%s': %s\n", $pattern, $@), 'npc';
		return undef;
	}

	for my $index (0 .. $#{$state{responses}}) {
		return $index if $state{responses}[$index] =~ $regex;
	}
	return undef;
}

sub on_text_packet {
	my (%args) = @_;
	my $opened = _begin_conversation(%args, last_packet => 'npc_talk');
	my $line = defined $args{text} ? $args{text} : '';
	$state{last_text} = $line;
	push @{$state{text_lines}}, $line;
	$state{responses} = [];
	_set_prompt_state(STATE_TEXT, reason => $opened ? 'open_text' : 'text');
	_emit_hook('npc_talk_text', {
		line => $line,
	});
}

sub on_continue_packet {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_talk_continue');
	_set_prompt_state(STATE_NEXT, reason => 'continue');
}

sub on_responses_packet {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_talk_responses');
	$state{responses} = _clone_array($args{responses});
	_set_prompt_state(STATE_RESPONSES, reason => 'responses');
	debug TF("[NPC] Received %d responses.\n", scalar @{$state{responses}}), 'npc';
	_emit_hook('npc_talk_responses', {
		responses        => responses(),
		legacy_responses => legacy_responses(),
	});
}

sub on_number_input_packet {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_talk_number');
	_set_prompt_state(STATE_NUMBER_INPUT, reason => 'number_input');
	_emit_hook('npc_talk_number_input', {});
}

sub on_text_input_packet {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_talk_text');
	_set_prompt_state(STATE_TEXT_INPUT, reason => 'text_input');
	_emit_hook('npc_talk_text_input', {});
}

sub on_close_packet {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_talk_close');
	$state{responses} = [];
	_set_prompt_state(STATE_CLOSING, can_close => 1, reason => 'close');
	debug "[NPC] Conversation moved to closing state.\n", 'npc';
	_emit_hook('npc_talk_closed', {
		pending_cancel => 1,
	});
}

sub on_clear_packet {
	my (%args) = @_;
	my $had_conversation = is_open();
	my $npc_id = current_npc_id();
	reset(reason => 'clear_packet');
	_emit_hook('npc_talk_closed', {
		pending_cancel => 0,
		npc_id         => $npc_id,
	}) if $had_conversation;
}

sub on_shop_begin {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_store_begin');
	$state{text_lines} = [];
	$state{last_text} = undef;
	$state{responses} = [];
	_set_prompt_state(STATE_BUY_OR_SELL, reason => 'shop_begin');
}

sub on_store_list {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_store_info');
	$state{text_lines} = [];
	$state{last_text} = undef;
	$state{responses} = [];
	_set_prompt_state(STATE_STORE, reason => 'store_list');
}

sub on_sell_list {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'npc_sell_list');
	$state{text_lines} = [];
	$state{last_text} = undef;
	$state{responses} = [];
	_set_prompt_state(STATE_SELL, reason => 'sell_list');
}

sub on_cash_dealer {
	my (%args) = @_;
	_begin_conversation(%args, last_packet => 'cash_dealer');
	$state{text_lines} = [];
	$state{last_text} = undef;
	$state{responses} = [];
	_set_prompt_state(STATE_CASH, reason => 'cash_dealer');
}

sub on_image_packet {
	my (%args) = @_;
	$state{image} = $args{image};
	$state{last_update} = time;
	_sync_legacy_globals();
}

sub clear_image {
	delete $state{image};
	$state{last_update} = time;
	_sync_legacy_globals();
}

sub on_error {
	my ($message) = @_;
	my $previous_state = $state{state};
	$state{error} = $message;
	$state{state} = STATE_ERROR;
	$state{waiting_server} = 0;
	$state{last_update} = time;
	_sync_legacy_globals();
	error TF("[NPC] %s\n", $message);
	_emit_state_changed($previous_state, 'error');
	_emit_hook('npc_talk_error', {
		error => $message,
	});
}

sub start {
	my ($npc_id, %args) = @_;
	return unless defined $npc_id;
	return unless _require_sender();

	_begin_conversation(
		npc_id         => $npc_id,
		name_id        => $args{name_id},
		npc_name       => $args{npc_name},
		last_packet    => 'send_talk',
		scheduled_time => time,
	);
	$state{text_lines} = [];
	$state{last_text} = undef;
	$state{responses} = [];
	_set_prompt_state(STATE_OPENING, waiting_server => 1, reason => 'start');
	$messageSender->sendTalk($npc_id);
	debug TF("[NPC] Sending talk start to npc_id=%s\n", unpack('V', $npc_id)), 'npc';
	return 1;
}

sub continue {
	my (%args) = @_;
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring npcTalkContinue: no active NPC conversation.\n", 'npc';
		return;
	}
	if (!$args{force} && !expects_continue()) {
		warning "[NPC] Ignoring npcTalkContinue: NPC is not waiting for continue.\n", 'npc';
		return;
	}

	$messageSender->sendTalkContinue(current_npc_id());
	_mark_waiting_server();
	debug TF("[NPC] Sending continue to npc_id=%s\n", unpack('V', current_npc_id())), 'npc';
	return 1;
}

sub select_response {
	my ($index, %args) = @_;
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring npcTalkSelect: no active NPC conversation.\n", 'npc';
		return;
	}
	if (!$args{force} && !expects_response()) {
		warning "[NPC] Ignoring npcTalkSelect: no response menu is currently open.\n", 'npc';
		return;
	}
	if (!defined $index || $index !~ /^\d+$/) {
		warning "[NPC] Ignoring npcTalkSelect: response index must be numeric.\n", 'npc';
		return;
	}

	my $cancel_index = cancel_response_index();
	if (defined $cancel_index && $index == $cancel_index) {
		return cancel();
	}

	if ($index < 0 || $index >= response_count()) {
		warning TF("[NPC] Ignoring npcTalkSelect: response index %s is out of range.\n", $index), 'npc';
		return;
	}

	my $response_text = response_at($index);
	$messageSender->sendTalkResponse(current_npc_id(), $index);
	_mark_waiting_server();
	debug TF("[NPC] Sending response index=%s text=\"%s\"\n", $index, $response_text), 'npc';
	return 1;
}

sub select_response_text {
	my ($wanted_text) = @_;
	my $index = find_response($wanted_text);
	if (!defined $index) {
		warning TF("[NPC] Ignoring npcTalkSelect: response '%s' was not found.\n", $wanted_text), 'npc';
		return;
	}
	return select_response($index);
}

sub select_response_regex {
	my ($pattern, $flags) = @_;
	my $index = find_response_regex($pattern, $flags);
	if (!defined $index) {
		warning TF("[NPC] Ignoring npcTalkSelectRegex: no response matched '%s'.\n", $pattern), 'npc';
		return;
	}
	return select_response($index);
}

sub send_number {
	my ($number, %args) = @_;
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring npcTalkNumber: no active NPC conversation.\n", 'npc';
		return;
	}
	if (!$args{force} && !expects_number()) {
		warning "[NPC] Ignoring npcTalkNumber: NPC is not waiting for a number.\n", 'npc';
		return;
	}
	if (!defined $number || $number !~ /^-?\d+$/) {
		warning TF("[NPC] Ignoring npcTalkNumber: '%s' is not numeric.\n", defined $number ? $number : 'undef'), 'npc';
		return;
	}

	$messageSender->sendTalkNumber(current_npc_id(), $number);
	_mark_waiting_server();
	debug TF("[NPC] Sending number=%s\n", $number), 'npc';
	return 1;
}

sub send_text {
	my ($value, %args) = @_;
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring npcTalkText: no active NPC conversation.\n", 'npc';
		return;
	}
	if (!$args{force} && !expects_text()) {
		warning "[NPC] Ignoring npcTalkText: NPC is not waiting for text.\n", 'npc';
		return;
	}
	$value = '' if !defined $value;

	$messageSender->sendTalkText(current_npc_id(), $value);
	_mark_waiting_server();
	debug TF("[NPC] Sending text=\"%s\"\n", $value), 'npc';
	return 1;
}

sub choose_buy_or_sell {
	my ($mode) = @_;
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring NPC buy/sell choice: no active NPC conversation.\n", 'npc';
		return;
	}
	if (prompt_state() ne STATE_BUY_OR_SELL) {
		warning "[NPC] Ignoring NPC buy/sell choice: NPC is not waiting for a buy/sell choice.\n", 'npc';
		return;
	}

	my $sell = ($mode && $mode eq 'sell') ? 1 : 0;
	$messageSender->sendNPCBuySellList(current_npc_id(), $sell);
	_mark_waiting_server();
	debug TF("[NPC] Sending buy/sell choice=%s\n", $sell ? 'sell' : 'buy'), 'npc';
	return 1;
}

sub close {
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring npcTalkClose: no active NPC conversation.\n", 'npc';
		return;
	}
	if (!can_close()) {
		warning "[NPC] Ignoring npcTalkClose: this conversation is not closable yet.\n", 'npc';
		return;
	}

	my $npc_id = current_npc_id();
	$messageSender->sendTalkCancel($npc_id);
	reset(reason => 'close');
	debug TF("[NPC] Sent talk close to npc_id=%s\n", unpack('V', $npc_id)), 'npc';
	return 1;
}

sub cancel {
	return unless _require_sender();
	if (!current_npc_id()) {
		warning "[NPC] Ignoring npcTalkCancel: no active NPC conversation.\n", 'npc';
		return;
	}

	if (expects_response()) {
		my $cancel_index = cancel_response_index();
		return unless defined $cancel_index;
		$messageSender->sendTalkResponse(current_npc_id(), $cancel_index);
		_mark_waiting_server();
		debug "[NPC] Sent menu cancel response.\n", 'npc';
		return 1;
	} elsif (expects_continue()) {
		return continue(force => 1);
	} elsif (expects_number()) {
		return send_number(0, force => 1);
	} elsif (expects_text()) {
		return send_text('', force => 1);
	} elsif (can_close()) {
		return close();
	}

	warning "[NPC] Ignoring npcTalkCancel: conversation is not in a cancellable state.\n", 'npc';
	return;
}

sub debug_string {
	my $snapshot = snapshot();
	my @lines = (
		"active: $snapshot->{active}",
		"state: $snapshot->{state}",
		"current_state: $snapshot->{current_state}",
		"npc_id: " . (defined $snapshot->{npc_id} ? unpack('V', $snapshot->{npc_id}) : 'undef'),
		"name_id: " . (defined $snapshot->{name_id} ? $snapshot->{name_id} : 'undef'),
		"npc_name: " . (defined $snapshot->{npc_name} ? $snapshot->{npc_name} : 'undef'),
		"waiting_server: $snapshot->{waiting_server}",
		"can_close: $snapshot->{can_close}",
		"legacy_talk: " . (defined $snapshot->{legacy_talk} ? $snapshot->{legacy_talk} : 'undef'),
		"last_update: " . (defined $snapshot->{last_update} ? $snapshot->{last_update} : 'undef'),
		"opened_at: " . (defined $snapshot->{opened_at} ? $snapshot->{opened_at} : 'undef'),
		"sequence_id: " . $snapshot->{sequence_id},
		"error: " . (defined $snapshot->{error} ? $snapshot->{error} : 'undef'),
		"text:",
	);

	if (@{$snapshot->{text_lines}}) {
		for my $index (0 .. $#{$snapshot->{text_lines}}) {
			push @lines, sprintf("  [%d] %s", $index, $snapshot->{text_lines}[$index]);
		}
	} else {
		push @lines, "  <empty>";
	}

	push @lines, "responses:";
	if (@{$snapshot->{responses}}) {
		for my $index (0 .. $#{$snapshot->{responses}}) {
			push @lines, sprintf("  [%d] %s", $index, $snapshot->{responses}[$index]);
		}
		push @lines, sprintf("  [%d] %s", cancel_response_index(), T('Cancel Chat'));
	} else {
		push @lines, "  <empty>";
	}

	return join("\n", @lines) . "\n";
}

1;
