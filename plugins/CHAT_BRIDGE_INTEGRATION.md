# Chat Bridge Integration Guide

## Overview

The `godtier_chat_bridge.pl` plugin captures chat messages from [`ChatQueue::add()`](../src/ChatQueue.pm:55-65) and makes them available to the AI Sidecar for intelligent response generation.

## Integration with AI_Bridge

To enable chat functionality in the AI Sidecar, modify [`AI_Bridge.pl`](AI_Bridge/AI_Bridge.pl:502-517) to include chat messages in the game state.

### Step 1: Add Module Import

At the top of `AI_Bridge.pl`, after the `use` statements (around line 45), add:

```perl
# Import chat bridge for message access
use lib "$Plugins::current_plugin_folder/..";
use GodTierChatBridge;
```

### Step 2: Modify build_game_state()

In the `build_game_state()` function (around line 502), add chat messages to the `extra` field:

**Before:**
```perl
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
```

**After:**
```perl
sub build_game_state {
    my $state = {
        character => build_character_state(),
        actors    => build_actors_state(),
        inventory => build_inventory_state(),
        map       => build_map_state(),
        ai_mode   => AI::state(),
        extra     => {
            chat_messages => GodTierChatBridge::get_chat_messages_for_state(),
        },
    };
    
    if (get_config('AI_Bridge_log_state')) {
        debug_msg("Built game state: " . encode_json($state));
    }
    
    return $state;
}
```

### Complete Modified Function

```perl
sub build_game_state {
    my $state = {
        character => build_character_state(),
        actors    => build_actors_state(),
        inventory => build_inventory_state(),
        map       => build_map_state(),
        ai_mode   => AI::state(),
        extra     => {
            chat_messages => GodTierChatBridge::get_chat_messages_for_state(),
        },
    };
    
    if (get_config('AI_Bridge_log_state')) {
        debug_msg("Built game state: " . encode_json($state));
    }
    
    return $state;
}
```

## Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHAT MESSAGE FLOW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Player sends chat in game                                   │
│         ↓                                                        │
│  2. OpenKore receives packet                                    │
│         ↓                                                        │
│  3. ChatQueue::add($type, $userID, $user, $msg)                │
│         ↓                                                        │
│  4. 🎣 HOOK: godtier_chat_bridge.pl::onChatQueueAdd()          │
│         ↓                                                        │
│  5. Message formatted and stored in @chat_buffer                │
│         ↓                                                        │
│  6. AI_Bridge::build_game_state() calls                         │
│     GodTierChatBridge::get_chat_messages_for_state()           │
│         ↓                                                        │
│  7. Messages included in game_state.extra.chat_messages         │
│         ↓                                                        │
│  8. ZeroMQ sends state to AI Sidecar                            │
│         ↓                                                        │
│  9. chat_manager.py processes messages                          │
│         ↓                                                        │
│  10. AI generates response action                               │
│         ↓                                                        │
│  11. Response sent back to OpenKore                             │
│         ↓                                                        │
│  12. Message displayed in game                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Message Format

### OpenKore Format (Input)
```perl
# From ChatQueue::add()
{
    type   => 'c',              # 'c', 'pm', 'p', 'g'
    userID => "\x12\x34\x56\x78",  # Packed binary
    user   => "PlayerName",
    msg    => "Hello world",
    time   => 1701234567.123,   # High-res timestamp
}
```

### AI Sidecar Format (Output)
```json
{
    "id": "abc123def4567890",
    "channel": "public",
    "sender": "PlayerName",
    "sender_id": 2018915346,
    "content": "Hello world",
    "timestamp": 1701234567
}
```

### Channel Mapping

| OpenKore Type | AI Sidecar Channel | Description |
|---------------|-------------------|-------------|
| `'c'` | `"public"` | Public/map chat |
| `'pm'` | `"whisper"` | Private message |
| `'p'` | `"party"` | Party chat |
| `'g'` | `"guild"` | Guild chat |

## Testing

### 1. Verify Plugin Loads

Start OpenKore and check console for:
```
[ChatBridge] Plugin loaded - monitoring chat messages
```

### 2. Test Message Capture

In OpenKore console:
```perl
# Inject test message
call GodTierChatBridge::inject_test_message('TestPlayer', 'public', 'Test message')

# Check buffer
call print(GodTierChatBridge::dump_buffer())
```

Expected output:
```
[ChatBridge] Test message injected: Test message from TestPlayer
[ChatBridge] Buffer Status:
  Size: 1 / 100
  Messages captured: 1
  ...
```

### 3. Test Message Retrieval

```perl
# Get messages for state
call my $msgs = GodTierChatBridge::get_chat_messages_for_state(); print scalar(@$msgs)
```

Should output the number of buffered messages.

### 4. Test Live Chat Capture

1. Log into a game server
2. Have another player send you a message or send a message yourself
3. Watch OpenKore console for `[ChatBridge] Captured ...` messages
4. Run dump_buffer() to verify messages are stored

### 5. Test AI Sidecar Integration

With AI Sidecar running:

1. Send a chat message in game
2. Check AI Sidecar logs for message processing:
   ```
   Processing chat message from PlayerName: Hello
   ```
3. Verify AI Sidecar response (if configured)

## Memory Management

The plugin automatically manages memory through:

- **Ring Buffer**: Maximum 100 messages (configurable via `$MAX_BUFFER_SIZE`)
- **TTL Expiration**: Messages older than 300 seconds are auto-removed
- **FIFO Eviction**: Oldest messages removed when buffer is full
- **Automatic Cleanup**: Called on every `get_chat_messages_for_state()`

To monitor memory usage:
```perl
call print(GodTierChatBridge::dump_buffer())
```

## Performance Impact

- **Hook overhead**: < 1ms per message
- **Memory per message**: ~100-200 bytes
- **Total memory**: ~10-20 KB for full buffer
- **No blocking operations**: All processing is synchronous and fast

## Troubleshooting

### Messages Not Appearing

**Problem**: Chat messages not showing up in AI Sidecar

**Check:**
1. Plugin loaded: Look for "[ChatBridge] Plugin loaded" message
2. Messages captured: Run `dump_buffer()` to see buffer contents
3. AI_Bridge integration: Verify `extra.chat_messages` is in game state
4. AI Sidecar processing: Check Python logs for message processing

### Buffer Always Empty

**Problem**: `dump_buffer()` shows 0 messages even when chatting

**Possible causes:**
1. Hook not registered: Check plugin load messages
2. ChatQueue::add not being called: Verify game server sends chat packets
3. Messages being filtered: Check if messages from self are being captured (they shouldn't be)

### Memory Growing

**Problem**: OpenKore memory usage increases over time

**Solutions:**
1. Reduce `$MAX_BUFFER_SIZE` (edit plugin file)
2. Reduce `$MESSAGE_TTL` for faster expiration
3. Manually clear buffer: `call GodTierChatBridge::clear_buffer()`

## Advanced Usage

### Custom Buffer Size

Edit `godtier_chat_bridge.pl`:
```perl
our $MAX_BUFFER_SIZE = 50;   # Reduce to 50 messages
our $MESSAGE_TTL = 180;       # Expire after 3 minutes
```

### Get Recent Messages by Channel

```perl
# Get last 5 party messages
my $party_msgs = GodTierChatBridge::get_recent_messages(5, 'party');

# Get last 10 whispers
my $whispers = GodTierChatBridge::get_recent_messages(10, 'whisper');
```

### Monitor Statistics

```perl
my $stats = GodTierChatBridge::get_statistics();
print "Messages captured: $stats->{messages_captured}\n";
print "Buffer size: $stats->{buffer_size}\n";
```

## Security Considerations

### Self-Message Filtering

The plugin automatically filters messages from the bot itself to prevent:
- Feedback loops (bot responding to its own messages)
- Duplicate processing
- Infinite conversation cycles

### Input Validation

All message fields are validated:
- Message content is required
- Sender ID unpacking errors are caught
- Invalid hook arguments are silently ignored

### No Command Execution

The plugin ONLY captures and stores messages. It does NOT:
- Execute any message content
- Modify messages
- Send messages (that's AI_Bridge's job)

## Compatibility

- **OpenKore versions**: 2.1.0+
- **Perl versions**: 5.10+
- **Dependencies**: 
  - `Time::HiRes` (core module)
  - `Digest::MD5` (core module)
  - No external CPAN modules required

## See Also

- [`ChatQueue.pm`](../src/ChatQueue.pm) - OpenKore's chat queue system
- [`AI_Bridge.pl`](AI_Bridge/AI_Bridge.pl) - Main AI bridge plugin  
- [`chat_manager.py`](../ai_sidecar/social/chat_manager.py) - Python chat processor
- [`GODTIER-AI-SPECIFICATION.md`](../docs/GODTIER-AI-SPECIFICATION.md) - Section 4.11 Social Interaction