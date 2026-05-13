# NPC Conversation

`NPC::Conversation` is the central runtime state holder for NPC dialog in OpenKore.

The old `%talk` and `$ai_v{'npc_talk'}` globals still exist only as compatibility mirrors inside this module. Production code should not read or write them directly anymore.

## State Model

The conversation module tracks one normalized conversation snapshot with:

- whether a conversation is active
- the current prompt state
- packed `npc_id` and numeric `name_id`
- NPC name
- full dialog text and per-line text
- current response list
- image name, if present
- last update time
- sequence id
- local waiting-for-server flag
- last error string

Primary prompt states:

- `CLOSED`
- `OPENING`
- `TEXT`
- `NEXT`
- `RESPONSES`
- `NUMBER_INPUT`
- `TEXT_INPUT`
- `WAITING_SERVER`
- `CLOSING`
- `BUY_OR_SELL`
- `STORE`
- `SELL`
- `CASH`
- `ERROR`

`current_state()` returns `WAITING_SERVER` when the local state is waiting for the next server packet. `prompt_state()` returns the raw prompt state without that overlay.

## Public API

Read helpers:

- `NPC::Conversation::is_open()`
- `NPC::Conversation::is_closed()`
- `NPC::Conversation::current_state()`
- `NPC::Conversation::prompt_state()`
- `NPC::Conversation::current_npc_id()`
- `NPC::Conversation::current_name_id()`
- `NPC::Conversation::current_npc_name()`
- `NPC::Conversation::text()`
- `NPC::Conversation::text_lines()`
- `NPC::Conversation::last_text()`
- `NPC::Conversation::responses()`
- `NPC::Conversation::response_count()`
- `NPC::Conversation::response_at($index)`
- `NPC::Conversation::find_response($text)`
- `NPC::Conversation::find_response_regex($pattern, $flags)`
- `NPC::Conversation::expects_continue()`
- `NPC::Conversation::expects_response()`
- `NPC::Conversation::expects_number()`
- `NPC::Conversation::expects_text()`
- `NPC::Conversation::can_close()`
- `NPC::Conversation::last_update_time()`
- `NPC::Conversation::sequence_id()`
- `NPC::Conversation::snapshot()`
- `NPC::Conversation::debug_string()`

Packet-side transitions:

- `NPC::Conversation::on_text_packet(...)`
- `NPC::Conversation::on_continue_packet(...)`
- `NPC::Conversation::on_responses_packet(...)`
- `NPC::Conversation::on_number_input_packet(...)`
- `NPC::Conversation::on_text_input_packet(...)`
- `NPC::Conversation::on_close_packet(...)`
- `NPC::Conversation::on_clear_packet(...)`
- `NPC::Conversation::on_shop_begin(...)`
- `NPC::Conversation::on_store_list(...)`
- `NPC::Conversation::on_sell_list(...)`
- `NPC::Conversation::on_cash_dealer(...)`
- `NPC::Conversation::on_image_packet(...)`
- `NPC::Conversation::clear_image()`
- `NPC::Conversation::on_error($message)`

Send-side helpers:

- `NPC::Conversation::start($npc_id, %info)`
- `NPC::Conversation::continue()`
- `NPC::Conversation::select_response($index)`
- `NPC::Conversation::select_response_text($text)`
- `NPC::Conversation::select_response_regex($pattern, $flags)`
- `NPC::Conversation::send_number($number)`
- `NPC::Conversation::send_text($text)`
- `NPC::Conversation::choose_buy_or_sell('buy'|'sell')`
- `NPC::Conversation::close()`
- `NPC::Conversation::cancel()`
- `NPC::Conversation::reset(%opts)`

## Packet Handler Usage

Receive handlers should stay thin. Parse packet payloads, then hand the state transition to `NPC::Conversation`.

Example:

```perl
NPC::Conversation::on_responses_packet(
    npc_id    => $ID,
    name_id   => $nameID,
    npc_name  => getNPCName($ID),
    responses => \@responses,
);
```

Do not append to `%talk`, set `$ai_v{'npc_talk'}`, or interpret prompt state outside the module.

## Command Usage

Console commands and task logic should interact through the module:

```perl
NPC::Conversation::continue();
NPC::Conversation::select_response($index);
NPC::Conversation::send_number($number);
NPC::Conversation::send_text($text);
NPC::Conversation::cancel();
NPC::Conversation::close();
```

New direct commands:

- `npcTalkContinue`
- `npcTalkSelect <index|text>`
- `npcTalkSelectRegex </regex/[flags]|pattern>`
- `npcTalkNumber <number>`
- `npcTalkText <text>`
- `npcTalkClose`
- `npcTalkCancel`
- `npcTalkReset`
- `npcTalkDebug`

## eventMacro Usage

State conditions now available:

- `npcTalkActive`
- `npcTalkState`
- `npcTalkText`
- `npcTalkTextRegex`
- `npcTalkHasResponses`
- `npcTalkResponseCount`
- `npcTalkResponse`
- `npcTalkResponseRegex`
- `npcTalkExpectsContinue`
- `npcTalkExpectsResponse`
- `npcTalkExpectsNumber`
- `npcTalkExpectsText`
- `npcTalkNpcName`
- `npcTalkNpcId`

Example:

```text
automacro npc_can_continue {
    npcTalkExpectsContinue 1
    call {
        npcTalkContinue
    }
}
```

```text
automacro npc_choose_city {
    npcTalkActive 1
    npcTalkTextRegex /Choose your destination/
    npcTalkResponse "Prontera"
    call {
        npcTalkSelect Prontera
    }
}
```

Existing `NpcMsg*` conditions remain available and still work from the legacy `npc_talk` hook flow.

## Hooks

New hooks emitted by the module:

- `npc_talk_opened`
- `npc_talk_text`
- `npc_talk_responses`
- `npc_talk_number_input`
- `npc_talk_text_input`
- `npc_talk_state_changed`
- `npc_talk_closed`
- `npc_talk_error`

The legacy `npc_talk` and `npc_talk_done` hooks are still emitted by receive handling for compatibility.

## Debugging

Use `npcTalkDebug` to print a sanitized snapshot of the current conversation state.

Typical output includes:

- active flag
- prompt state and current state
- NPC id and name
- text lines
- response list
- waiting state
- sequence id
- last error

## Migration Notes

For plugin authors:

- stop reading `%talk` directly
- stop reading `$ai_v{'npc_talk'}` directly
- call `NPC::Conversation` for state reads
- call `NPC::Conversation` for response sends
- prefer new `npc_talk_state_changed` style hooks if you need stateful behavior

The compatibility mirror is temporary and should be treated as deprecated.
