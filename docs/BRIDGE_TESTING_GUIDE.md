# 🧪 Bridge Testing & Validation Guide

> **Comprehensive testing procedures for OpenKore ↔ AI Sidecar bridge system**

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Validation](#quick-validation)
- [P0 Bridge Testing](#p0-bridge-testing-critical)
- [P1 Bridge Testing](#p1-bridge-testing-important)
- [P2 Bridge Testing](#p2-bridge-testing-advanced)
- [P3 Bridge Testing](#p3-bridge-testing-optional)
- [Performance Testing](#performance-testing)
- [Common Issues](#common-issues)
- [Automated Tests](#automated-tests)

---

## Prerequisites

### Required Setup

Before testing, ensure:

- ✅ OpenKore is installed and configured
- ✅ AI Sidecar is running (`python main.py`)
- ✅ AI_Bridge plugin is loaded
- ✅ Test character logged into game server
- ✅ Debug mode enabled for detailed logs

### Enable Debug Mode

Edit `plugins/AI_Bridge/AI_Bridge.txt`:

```ini
AI_Bridge_debug 1
AI_Bridge_log_state 0  # Set to 1 for full state logging (very verbose!)
```

Restart OpenKore to apply changes.

### Test Environment

Recommended test setup:
- **Server**: Private server or test server
- **Character**: Low-level character (Lv 1-10) for stat/skill testing
- **Map**: Safe map with monsters (e.g., `prt_fild08`)
- **Party**: Test party for party features (optional)

---

## Quick Validation

### 1. Connection Test

**Verify OpenKore → AI Sidecar communication**

```perl
# In OpenKore console
call print("AI Bridge Status: " . ($AI_Bridge::state{connected} ? "Connected" : "Disconnected") . "\n")
call print("Ticks processed: " . $AI_Bridge::state{tick_count} . "\n")
```

**Expected Output:**
```
AI Bridge Status: Connected
Ticks processed: 1234
```

**If not connected:**
- Check AI Sidecar is running
- Verify port 5555 is accessible
- Review OpenKore console for error messages

---

### 2. State Transmission Test

**Verify game state is being sent**

Enable state logging temporarily:
```perl
# In OpenKore console
call $config{AI_Bridge_log_state} = 1
```

Wait one AI tick, then check console output:
```
[AI_Bridge] Built game state: {"character":{"name":"TestChar",...}
```

**Disable after test:**
```perl
call $config{AI_Bridge_log_state} = 0
```

---

### 3. Decision Reception Test

**Verify AI decisions are received**

Watch console for decision application:
```
[AI_Bridge] Applied 3 actions
[AI_Bridge] Applying action: move
```

If no actions appear, check AI Sidecar logs for decision generation.

---

## P0 Bridge Testing (Critical)

### ✅ Character Stats Bridge

**What to test**: Basic character attributes extraction

**Test Procedure:**

1. **Check stat extraction**
   ```perl
   # In OpenKore console
   call print("STR: " . $char->{str} . ", AGI: " . $char->{agi} . "\n")
   ```

2. **Enable debug and trigger state update**
   ```perl
   call $config{AI_Bridge_debug} = 1
   ```

3. **Verify in AI Sidecar logs**
   Look for:
   ```
   Character stats: STR=10, AGI=10, VIT=10, INT=10, DEX=10, LUK=10
   ```

4. **Test stat changes**
   - Add stat points manually in game
   - Verify AI detects new values in next tick

**Validation Checklist:**
- [ ] STR value transmitted correctly
- [ ] AGI value transmitted correctly
- [ ] VIT value transmitted correctly
- [ ] INT value transmitted correctly
- [ ] DEX value transmitted correctly
- [ ] LUK value transmitted correctly
- [ ] Values update when manually changed

---

### ✅ Experience Bridge

**What to test**: Base and job experience tracking

**Test Procedure:**

1. **Check initial experience**
   ```perl
   call print("Base EXP: " . $char->{exp} . "/" . $char->{exp_max} . "\n")
   call print("Job EXP: " . $char->{exp_job} . "/" . $char->{exp_job_max} . "\n")
   ```

2. **Kill a monster**
   - Defeat any mob
   - Watch for experience gain

3. **Verify AI Sidecar receives update**
   AI logs should show:
   ```
   Experience gained: +50 base, +10 job
   ```

**Validation Checklist:**
- [ ] Base experience value correct
- [ ] Base experience max correct
- [ ] Job experience value correct
- [ ] Job experience max correct
- [ ] Experience updates after monster kill
- [ ] Level up detected (if applicable)

---

### ✅ Skill Points Bridge

**What to test**: Available stat and skill points

**Test Procedure:**

1. **Check available points**
   ```perl
   call print("Stat points: " . $char->{points_free} . "\n")
   call print("Skill points: " . $char->{points_skill} . "\n")
   ```

2. **Level up** (if possible) to gain points

3. **Verify AI detection**
   AI logs should show:
   ```
   Available points: stat=5, skill=3
   ```

**Validation Checklist:**
- [ ] Stat points count correct
- [ ] Skill points count correct
- [ ] Points update after level up

---

### ✅ Learned Skills Bridge

**What to test**: Skill inventory extraction

**Test Procedure:**

1. **Check learned skills**
   ```perl
   # In OpenKore console
   call my $skills = $char->{skills}; foreach my $sk (keys %$skills) { print "$sk: Lv " . $skills->{$sk}{lv} . "\n" }
   ```

2. **Verify AI receives skill data**
   Look for in AI logs:
   ```
   Learned skills: SM_BASH (Lv 10, SP 15), SM_PROVOKE (Lv 10, SP 13)
   ```

3. **Learn new skill**
   - Add skill points to new skill
   - Verify AI detects addition

**Validation Checklist:**
- [ ] All learned skills transmitted
- [ ] Skill levels correct
- [ ] SP costs accurate
- [ ] New skills detected when learned

---

### ✅ Stat Allocation Action

**What to test**: AI can allocate stat points

**Test Procedure:**

1. **Ensure character has stat points**
   ```perl
   call print("Stat points available: " . $char->{points_free} . "\n")
   ```

2. **Configure AI to allocate STR**
   (This depends on your AI Sidecar configuration)

3. **Trigger AI decision**
   Wait for next AI tick or force decision

4. **Verify stat increase**
   ```perl
   call print("STR increased to: " . $char->{str} . "\n")
   ```

5. **Check console logs**
   ```
   [AI_Bridge] AI requested stat allocation: STR +1
   ```

**Validation Checklist:**
- [ ] AI can allocate STR
- [ ] AI can allocate AGI
- [ ] AI can allocate VIT
- [ ] AI can allocate INT
- [ ] AI can allocate DEX
- [ ] AI can allocate LUK
- [ ] Multiple points can be allocated at once
- [ ] Stat points decrease correctly

---

### ✅ Skill Allocation Action

**What to test**: AI can allocate skill points

**Test Procedure:**

1. **Ensure character has skill points**
   ```perl
   call print("Skill points available: " . $char->{points_skill} . "\n")
   ```

2. **Configure AI to learn skill**
   (Configure target skill in AI Sidecar)

3. **Wait for AI to allocate**

4. **Verify skill learned/leveled**
   ```perl
   call print("Bash level: " . $char->{skills}{'SM_BASH'}{lv} . "\n")
   ```

**Validation Checklist:**
- [ ] AI can learn new skills
- [ ] AI can level up existing skills
- [ ] Skill points decrease correctly
- [ ] Prerequisites are respected

---

## P1 Bridge Testing (Important)

### ✅ Party Coordination Bridge

**What to test**: Party member tracking and healing

**Test Procedure:**

1. **Create or join party**
   ```perl
   # Manual: Use in-game party system
   # Or console: party create TestParty
   ```

2. **Verify party state extraction**
   ```perl
   call print("Party: " . $char->{party}{name} . " (" . scalar(keys %{$char->{party}{users}}) . " members)\n")
   ```

3. **Check AI Sidecar receives party data**
   AI logs:
   ```
   Party detected: TestParty with 2 members
   Member: PlayerName (HP: 5000/6000, SP: 800/1000)
   ```

4. **Test party heal action** (requires Priest/Acolyte)
   - Have party member take damage
   - AI should detect low HP
   - Verify heal action triggered

**Validation Checklist:**
- [ ] Party name transmitted
- [ ] Member count correct
- [ ] Member names correct
- [ ] Member HP/SP values accurate
- [ ] Member job classes transmitted
- [ ] Online/offline status correct
- [ ] Leader designation correct
- [ ] Party heal action works (if applicable)
- [ ] Party buff action works (if applicable)

---

### ✅ Guild Information Bridge

**What to test**: Guild stats and member info

**Test Procedure:**

1. **Join guild** (if not already in one)

2. **Check guild state**
   ```perl
   call print("Guild: " . $char->{guild}{name} . " (Lv " . $char->{guild}{lvl} . ")\n")
   ```

3. **Verify AI receives guild data**
   AI logs:
   ```
   Guild: MyGuild (Level 5, 20/30 members)
   ```

**Validation Checklist:**
- [ ] Guild name transmitted
- [ ] Guild level correct
- [ ] Member count accurate
- [ ] Max members value correct
- [ ] Guild experience tracked
- [ ] Average level calculated

---

### ✅ Buff Tracking Bridge

**What to test**: Active buff detection and monitoring

**Test Procedure:**

1. **Cast self-buff** (e.g., Blessing, Increase AGI)
   ```perl
   # Use skill or have someone buff you
   ```

2. **Check buff status**
   ```perl
   call my $statuses = $char->{statuses}; foreach my $s (keys %$statuses) { print "Status $s: " . $statuses->{$s}{name} . "\n" }
   ```

3. **Verify AI detects buffs**
   AI logs:
   ```
   Active buffs: Blessing (180s remaining), Increase AGI (60s remaining)
   ```

4. **Wait for buff expiration**
   - AI should detect when buff expires

**Validation Checklist:**
- [ ] Buffs detected when applied
- [ ] Buff names correct
- [ ] Buff durations tracked
- [ ] Buff expiration detected
- [ ] Multiple buffs tracked simultaneously

---

### ✅ Enhanced Status Effects Bridge

**What to test**: Debuff and status ailment detection

**Test Procedure:**

1. **Get affected by status** (poison, curse, etc.)
   - Let monster inflict status
   - Or use status-inducing item

2. **Check status effects**
   ```perl
   call foreach my $s (keys %{$char->{statuses}}) { print "Effect: $s\n" }
   ```

3. **Verify AI detects negative effects**
   AI logs:
   ```
   Debuff detected: Poison (is_negative=true, duration=30s)
   ```

**Validation Checklist:**
- [ ] Debuffs detected
- [ ] Positive vs negative classification
- [ ] Duration tracking
- [ ] Status removal detected

---

### ✅ Chat Integration Bridge

**What to test**: Chat message capture and AI responses

**Test Procedure:**

1. **Verify chat bridge loaded**
   Look for in console:
   ```
   [ChatBridge] Plugin loaded - monitoring chat messages
   ```

2. **Inject test message**
   ```perl
   call GodTierChatBridge::inject_test_message('TestPlayer', 'public', 'Hello bot!')
   ```

3. **Check buffer contents**
   ```perl
   call print(GodTierChatBridge::dump_buffer())
   ```

   Expected output:
   ```
   [ChatBridge] Buffer Status:
     Size: 1 / 100
     Recent Messages:
     [public] TestPlayer: Hello bot!
   ```

4. **Verify AI receives messages**
   AI logs:
   ```
   Chat message received: TestPlayer says "Hello bot!" in public
   ```

5. **Test live chat** (in game)
   - Have another player message you
   - Or send message yourself
   - Verify capture

6. **Test AI response** (if configured)
   - AI should generate response
   - Check for `chat_send` action in logs

**Validation Checklist:**
- [ ] Public chat captured
- [ ] Party chat captured
- [ ] Guild chat captured
- [ ] Whisper/PM captured
- [ ] Sender name correct
- [ ] Message content accurate
- [ ] Timestamp recorded
- [ ] Channel mapping correct
- [ ] AI can send responses
- [ ] Self-messages filtered (not captured)

---

## P2 Bridge Testing (Advanced)

### ✅ Pet Management Bridge

**What to test**: Pet state tracking and feeding

**Test Procedure:**

1. **Summon pet** (if you have one)
   ```perl
   # Use pet item in inventory
   ```

2. **Check pet state**
   ```perl
   call if ($char->{pet}) { print "Pet: " . $char->{pet}{name} . " (Intimacy: " . $char->{pet}{friendly} . ")\n" }
   ```

3. **Verify AI receives pet data**
   AI logs:
   ```
   Pet detected: Poring (Intimacy: 850, Hunger: 65)
   ```

4. **Test feed action**
   - Let pet get hungry
   - AI should trigger feed action
   - Verify feeding occurs

**Validation Checklist:**
- [ ] Pet name transmitted
- [ ] Intimacy level correct
- [ ] Hunger level accurate
- [ ] Summoned status tracked
- [ ] Feed action works

---

### ✅ Homunculus Bridge

**What to test**: Homunculus state and skill usage

**Test Procedure:**

1. **Summon homunculus** (Alchemist required)

2. **Check homunculus state**
   ```perl
   call if ($char->{homunculus}) { print "Homun: " . $char->{homunculus}{name} . " Lv " . $char->{homunculus}{level} . "\n" }
   ```

3. **Verify AI receives homunculus data**
   AI logs:
   ```
   Homunculus: Lif (Lv 50, HP: 3000/3500, Intimacy: 910)
   ```

4. **Test homunculus skill action**
   - Configure AI to use homunculus skill
   - Verify skill execution

**Validation Checklist:**
- [ ] Homunculus type/name correct
- [ ] Level transmitted
- [ ] HP/SP values accurate
- [ ] Intimacy tracked
- [ ] Hunger tracked
- [ ] Skill points visible
- [ ] Stats transmitted
- [ ] Homunculus skill action works

---

### ✅ Mercenary Bridge

**What to test**: Mercenary state tracking

**Test Procedure:**

1. **Hire mercenary** (if available)

2. **Check mercenary state**
   ```perl
   call if ($char->{mercenary}) { print "Merc: " . $char->{mercenary}{name} . " (Contract: " . $char->{mercenary}{expire_time} . "s)\n" }
   ```

3. **Verify AI receives mercenary data**
   AI logs:
   ```
   Mercenary: Archer (Lv 30, Contract: 1800s remaining, Faith: 50)
   ```

**Validation Checklist:**
- [ ] Mercenary type correct
- [ ] Level transmitted
- [ ] HP/SP values accurate
- [ ] Contract time tracked
- [ ] Faith value correct

---

### ✅ Mount System Bridge

**What to test**: Mount and cart status

**Test Procedure:**

1. **Mount** (if you have Peco/Dragon/etc.)
   ```perl
   # Use mount skill/item
   ```

2. **Check mount state**
   ```perl
   call print("Mounted: " . ($char->{mounted} ? "Yes" : "No") . "\n")
   ```

3. **Test cart** (Merchant/Blacksmith)
   ```perl
   call if ($char->{cart}) { print "Cart weight: " . $char->{cart_weight} . "/" . $char->{cart_max_weight} . "\n" }
   ```

4. **Verify AI receives mount data**
   AI logs:
   ```
   Mount status: mounted=true, has_cart=true
   ```

5. **Test mount/dismount actions**
   - AI should be able to mount
   - AI should be able to dismount

**Validation Checklist:**
- [ ] Mount status correct
- [ ] Mount type identified
- [ ] Cart presence detected
- [ ] Cart weight tracked
- [ ] Cart item count accurate
- [ ] Mount action works
- [ ] Dismount action works

---

### ✅ Equipment Bridge

**What to test**: Equipped items tracking

**Test Procedure:**

1. **Check equipped items**
   ```perl
   call my $inv = $char->{inventory}; foreach my $item (@{$inv->getItems()}) { if ($item->{equipped}) { print $item->{name} . " in slot " . $item->{equipped} . "\n" } }
   ```

2. **Verify AI receives equipment data**
   AI logs:
   ```
   Equipment: weapon=Dagger, armor=Cotton Shirt, head_top=Cap
   ```

3. **Test equip/unequip actions**
   - Configure AI to equip item
   - Verify equipment change
   - Test unequip

**Validation Checklist:**
- [ ] All equipment slots tracked
- [ ] Item names correct
- [ ] Item IDs accurate
- [ ] Refine levels transmitted
- [ ] Identified status correct
- [ ] Equip action works
- [ ] Unequip action works

---

## P3 Bridge Testing (Optional)

### ✅ NPC Dialogue Bridge

**What to test**: NPC interaction state

**Test Procedure:**

1. **Talk to NPC**
   ```perl
   # Manually click NPC or use: talk <NPC ID>
   ```

2. **Check dialogue state**
   ```perl
   call if ($talk{ID}) { print "In dialogue with NPC\n" }
   ```

3. **Verify AI receives dialogue state**
   AI logs:
   ```
   NPC dialogue: NPC_ID=123456, has_choices=true
   Choice 0: "Buy items"
   Choice 1: "Sell items"
   ```

4. **Test NPC actions**
   - AI should be able to continue dialogue
   - AI should be able to choose options
   - AI should be able to close dialogue

**Validation Checklist:**
- [ ] NPC ID transmitted
- [ ] NPC name correct
- [ ] Dialogue state detected
- [ ] Choice list extracted
- [ ] Choice text accurate
- [ ] npc_talk action works
- [ ] npc_choose action works
- [ ] npc_close action works

---

### ✅ Quest Tracking Bridge

**What to test**: Active quest monitoring

**Test Procedure:**

1. **Accept quest**
   - Take quest from NPC

2. **Check quest list**
   ```perl
   call if ($questList) { foreach my $q (keys %$questList) { print "Quest $q: " . $questList->{$q}{title} . "\n" } }
   ```

3. **Verify AI receives quest data**
   AI logs:
   ```
   Active quest: Find 10 Jellopy (Quest ID: 1001)
   Objectives: mob[Poring]=0/10
   ```

**Validation Checklist:**
- [ ] Quest ID transmitted
- [ ] Quest name/title correct
- [ ] Time limit tracked
- [ ] Mob objectives listed
- [ ] Item objectives listed
- [ ] Completion status accurate

---

### ✅ Market/Economy Bridge

**What to test**: Vendor and price tracking

**Test Procedure:**

1. **Find player vendor**
   - Look for vending shop

2. **Check vendor data**
   ```perl
   call if ($venderLists) { foreach my $v (keys %$venderLists) { print "Vendor: " . $venderLists->{$v}{title} . "\n" } }
   ```

3. **Verify AI receives market data**
   AI logs:
   ```
   Vendor detected: "Cheap Items Here" at (150, 200)
   Item: Red Potion x100 @ 50z each
   ```

4. **Test buy actions**
   - Configure AI to buy from vendor
   - Verify purchase

**Validation Checklist:**
- [ ] Vendor ID transmitted
- [ ] Vendor name correct
- [ ] Vendor position accurate
- [ ] Item list extracted
- [ ] Item prices correct
- [ ] Item quantities accurate
- [ ] buy_from_vendor action works
- [ ] buy_from_npc action works
- [ ] sell_to_npc action works

---

### ✅ Environment Bridge

**What to test**: Time and weather awareness

**Test Procedure:**

1. **Check server time**
   ```perl
   call print("Server time: " . time() . "\n")
   ```

2. **Check night status**
   ```perl
   call print("Is night: " . ($field->isNight() ? "Yes" : "No") . "\n")
   ```

3. **Verify AI receives environment data**
   AI logs:
   ```
   Environment: is_night=false, weather_type=0 (clear)
   ```

**Validation Checklist:**
- [ ] Server time transmitted
- [ ] Day/night status correct
- [ ] Weather type identified

---

### ✅ Ground Items Bridge

**What to test**: Item on ground detection

**Test Procedure:**

1. **Drop item** or find items on ground

2. **Check items list**
   ```perl
   call if ($itemsList) { foreach my $i (keys %$itemsList) { print "Item: " . $itemsList->{$i}{name} . " at (" . $itemsList->{$i}{pos}{x} . "," . $itemsList->{$i}{pos}{y} . ")\n" } }
   ```

3. **Verify AI receives ground item data**
   AI logs:
   ```
   Ground item: Red Potion x1 at (155, 205)
   ```

4. **Test pick_item action**
   - AI should be able to pick up items
   - Verify pickup occurs

**Validation Checklist:**
- [ ] Item ID transmitted
- [ ] Item name correct
- [ ] Item position accurate
- [ ] Item quantity correct
- [ ] pick_item action works

---

## Performance Testing

### Latency Test

**Measure tick processing time**

1. **Enable debug mode**
   ```ini
   AI_Bridge_debug 1
   ```

2. **Watch console for timing**
   ```
   [AI_Bridge] AI_pre tick 12345 completed in 15.23ms
   ```

3. **Calculate average over 100 ticks**

**Targets:**
- CPU mode: < 20ms average
- GPU mode: < 30ms average
- LLM mode: < 3000ms average

**If too slow:**
- Check AI Sidecar CPU usage
- Review decision algorithm complexity
- Consider backend optimization

---

### Throughput Test

**Measure actions per second**

1. **Monitor AI decisions over 1 minute**

2. **Count actions executed**

3. **Calculate rate**: actions / 60 seconds

**Target:** 10-20 actions per second

---

### Memory Test

**Check for memory leaks**

1. **Run OpenKore for 1 hour**

2. **Monitor memory usage**
   ```bash
   ps aux | grep openkore
   ```

3. **Check AI Sidecar memory**
   ```bash
   ps aux | grep python
   ```

**Target:** Stable memory usage (no growth)

---

## Common Issues

### ❌ Connection Refused

**Symptoms:**
```
[AI_Bridge] Failed to connect: Connection refused
```

**Solutions:**
1. Start AI Sidecar before OpenKore
2. Check port 5555 is not in use
3. Verify firewall allows localhost connections
4. Check AI_Bridge_address in config

---

### ❌ Timeout Errors

**Symptoms:**
```
[AI_Bridge] Communication error: timeout
```

**Solutions:**
1. Increase timeout: `AI_Bridge_timeout_ms 100`
2. Check AI Sidecar is responding
3. Review AI Sidecar logs for errors
4. Simplify decision algorithm

---

### ❌ JSON Decode Errors

**Symptoms:**
```
[AI_Bridge] Failed to decode JSON: malformed input
```

**Solutions:**
1. Check for special characters in names/messages
2. Verify AI Sidecar sends valid JSON
3. Update JSON module: `cpanm JSON::XS`

---

### ❌ Actions Not Executing

**Symptoms:**
- AI generates decisions but nothing happens in game

**Solutions:**
1. Check action type is supported
2. Verify action parameters are valid
3. Review apply_single_action() code
4. Check OpenKore command privileges

---

### ❌ Chat Messages Not Captured

**Symptoms:**
- Chat bridge plugin loaded but messages not appearing

**Solutions:**
1. Verify hook is registered: `[ChatBridge] Plugin loaded`
2. Test with injection: `call GodTierChatBridge::inject_test_message()`
3. Check self-message filtering
4. Review ChatQueue::add hook

---

## Automated Tests

### Test Script Template

Save as `test_bridge.pl`:

```perl
#!/usr/bin/perl
use strict;
use warnings;

# Test suite for AI Bridge
my @tests = ();
my $passed = 0;
my $failed = 0;

sub test {
    my ($name, $coderef) = @_;
    print "Testing: $name... ";
    eval { $coderef->(); };
    if ($@) {
        print "FAILED: $@\n";
        $failed++;
    } else {
        print "PASSED\n";
        $passed++;
    }
}

# Test 1: Connection status
test("AI Bridge Connected", sub {
    die "Not connected" unless $AI_Bridge::state{connected};
});

# Test 2: State extraction
test("Character State Extracted", sub {
    die "No character" unless $char;
    die "No character name" unless $char->{name};
});

# Test 3: Chat bridge
test("Chat Bridge Available", sub {
    die "Chat bridge not loaded" unless $AI_Bridge::CHAT_BRIDGE_AVAILABLE;
});

# Add more tests...

print "\n========== Results ==========\n";
print "Passed: $passed\n";
print "Failed: $failed\n";
print "Total: " . ($passed + $failed) . "\n";
```

Run with:
```perl
# In OpenKore console
do "test_bridge.pl"
```

---

## Validation Checklist

Use this checklist to verify complete bridge functionality:

### Core Functionality
- [ ] OpenKore connects to AI Sidecar
- [ ] Game state transmitted successfully
- [ ] AI decisions received
- [ ] Actions executed in game
- [ ] Graceful degradation works

### P0 Bridges (Critical)
- [ ] Character stats extracted
- [ ] Experience values tracked
- [ ] Skill points available
- [ ] Learned skills listed
- [ ] Stat allocation works
- [ ] Skill allocation works

### P1 Bridges (Important)
- [ ] Party information synced
- [ ] Guild information synced
- [ ] Buffs tracked
- [ ] Status effects detected
- [ ] Chat messages captured
- [ ] Party heal/buff works

### P2 Bridges (Advanced)
- [ ] Pet state tracked
- [ ] Homunculus state tracked
- [ ] Mercenary state tracked
- [ ] Mount status tracked
- [ ] Equipment synced
- [ ] Pet feeding works
- [ ] Homunculus skills work
- [ ] Mount/dismount works

### P3 Bridges (Optional)
- [ ] NPC dialogue tracked
- [ ] Quest data extracted
- [ ] Vendor information synced
- [ ] Environment data tracked
- [ ] Ground items detected
- [ ] NPC interaction works
- [ ] Market actions work

### Performance
- [ ] Latency < 30ms (CPU/GPU mode)
- [ ] No memory leaks
- [ ] No connection drops
- [ ] Stable over 1+ hour

---

## Next Steps

After testing, review:

- ⚙️ [Bridge Configuration](BRIDGE_CONFIGURATION.md) - Fine-tune settings
- 📋 [Action Types Reference](ACTION_TYPES_REFERENCE.md) - Complete action catalog
- 🔗 [Integration Guide](AI_SIDECAR_BRIDGE_GUIDE.md) - Architecture details

---

**Last Updated**: December 5, 2025  
**Version**: 1.0.0  
**Test Coverage**: ~90% of implemented features