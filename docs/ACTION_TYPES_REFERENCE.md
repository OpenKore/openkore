# 📋 Action Types Reference

> **Complete catalog of all action types supported by the AI Sidecar bridge**

## 📋 Table of Contents

- [Overview](#overview)
- [Action Format](#action-format)
- [Movement Actions](#movement-actions)
- [Combat Actions](#combat-actions)
- [Progression Actions](#progression-actions)
- [Party Actions](#party-actions)
- [Companion Actions](#companion-actions)
- [NPC Actions](#npc-actions)
- [Inventory Actions](#inventory-actions)
- [Storage Actions](#storage-actions)
- [Economy Actions](#economy-actions)
- [Communication Actions](#communication-actions)
- [Utility Actions](#utility-actions)
- [Action Priority System](#action-priority-system)

---

## Overview

The AI Sidecar can request OpenKore to execute **30+ different action types** covering all aspects of gameplay. Actions are returned in decision responses and executed by the [`apply_single_action()`](../plugins/AI_Bridge/AI_Bridge.pl:1300) function.

### Action Categories

| Category | Count | Examples |
|----------|-------|----------|
| **Movement** | 2 | move, teleport |
| **Combat** | 2 | attack, skill |
| **Progression** | 2 | allocate_stat, allocate_skill |
| **Party** | 2 | party_heal, party_buff |
| **Companion** | 4 | feed_pet, homun_skill, mount, dismount |
| **NPC** | 3 | npc_talk, npc_choose, npc_close |
| **Inventory** | 4 | use_item, pick_item, drop_item, equip_item, unequip_item |
| **Storage** | 2 | storage_get, storage_add |
| **Economy** | 3 | buy_from_npc, sell_to_npc, buy_from_vendor |
| **Communication** | 2 | chat_send, sit, stand |
| **Utility** | 2 | idle, wait |

---

## Action Format

### Standard Action Structure

All actions follow this JSON format:

```json
{
  "type": "action_type_name",
  "priority": 1-10,
  "reason": "Human-readable explanation",
  ...additional parameters...
}
```

### Common Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | ✅ Yes | Action type identifier |
| `priority` | integer | ❌ No | Priority (1=highest, 10=lowest), default: 5 |
| `reason` | string | ❌ No | Explanation for logging/debugging |

### Priority Guidelines

```
Priority 1-2:   Critical (emergency heals, flee from danger)
Priority 3-4:   Important (combat skills, buff management)
Priority 5-6:   Normal (movement, item usage)
Priority 7-8:   Low (chat, social actions)
Priority 9-10:  Lowest (idle cleanup, delayed actions)
```

---

## Movement Actions

### move

**Purpose**: Move character to specific coordinates.

**Implementation**: [`AI_Bridge.pl:1508-1519`](../plugins/AI_Bridge/AI_Bridge.pl:1508-1519)

**Parameters**:
```json
{
  "type": "move",
  "x": 150,
  "y": 200,
  "priority": 5,
  "reason": "Move to farming spot"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `x` | integer | ✅ Yes | Target X coordinate |
| `y` | integer | ✅ Yes | Target Y coordinate |

**OpenKore Command**: `AI::queue('move', {x => $x, y => $y})`

**Use Cases**:
- Navigate to farming location
- Return to safe spot
- Position for skill usage
- Chase fleeing target

**Example**:
```json
{
  "type": "move",
  "x": 150,
  "y": 200,
  "priority": 5,
  "reason": "Move to optimal farming position"
}
```

---

### teleport

**Purpose**: Use teleport skill or item to random location or save point.

**Implementation**: [`AI_Bridge.pl:1434-1438`](../plugins/AI_Bridge/AI_Bridge.pl:1434-1438)

**Parameters**:
```json
{
  "type": "teleport",
  "priority": 1,
  "reason": "Emergency escape from danger"
}
```

**OpenKore Command**: `Commands::run("tele")`

**Use Cases**:
- Emergency escape (critical HP)
- Unstuck from collision
- Quick repositioning
- Return to town (teleport clip)

**Example**:
```json
{
  "type": "teleport",
  "priority": 1,
  "reason": "HP critical, flee immediately"
}
```

---

## Combat Actions

### attack

**Purpose**: Basic melee attack on target.

**Implementation**: [`AI_Bridge.pl:1521-1531`](../plugins/AI_Bridge/AI_Bridge.pl:1521-1531)

**Parameters**:
```json
{
  "type": "attack",
  "target": "1234567890",
  "priority": 3,
  "reason": "Attack low HP monster"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `target` | string | ✅ Yes | Target actor ID |

**OpenKore Command**: `AI::queue('attack', $target_id)`

**Use Cases**:
- Basic melee combat
- Finish low HP enemies
- Build combo meter
- No SP available for skills

**Example**:
```json
{
  "type": "attack",
  "target": "monster_id_123",
  "priority": 3,
  "reason": "Target at 15% HP, finish with basic attack"
}
```

---

### skill

**Purpose**: Use character skill on target, ground, or self.

**Implementation**: [`AI_Bridge.pl:1533-1566`](../plugins/AI_Bridge/AI_Bridge.pl:1533-1566)

**Parameters (Target Skill)**:
```json
{
  "type": "skill",
  "id": "SM_BASH",
  "level": 10,
  "target": "1234567890",
  "priority": 2,
  "reason": "High damage burst skill"
}
```

**Parameters (Ground Skill)**:
```json
{
  "type": "skill",
  "id": "WZ_METEOR",
  "level": 10,
  "x": 155,
  "y": 205,
  "priority": 2,
  "reason": "AOE damage on grouped enemies"
}
```

**Parameters (Self Skill)**:
```json
{
  "type": "skill",
  "id": "AL_HEAL",
  "level": 10,
  "priority": 1,
  "reason": "Emergency self-heal"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | string/int | ✅ Yes | Skill handle name or ID |
| `level` | integer | ❌ No | Skill level to use (default: 1) |
| `target` | string | ❌ No* | Target actor ID |
| `x` | integer | ❌ No* | Ground target X |
| `y` | integer | ❌ No* | Ground target Y |

*Either `target` OR `x,y` OR neither (self-cast)

**OpenKore Command**: `AI::queue('skill_use', {...})`

**Use Cases**:
- Cast offensive skills
- Self-buff before combat
- AOE damage on grouped enemies
- Heal self or party members
- Support skills (Lex Aeterna, Decrease AGI)

**Examples**:
```json
// Offensive target skill
{
  "type": "skill",
  "id": "SM_BASH",
  "level": 10,
  "target": "monster_123",
  "priority": 2,
  "reason": "Bash for high damage"
}

// Ground AOE skill
{
  "type": "skill",
  "id": "WZ_METEOR",
  "level": 10,
  "x": 155,
  "y": 205,
  "priority": 2,
  "reason": "Meteor Storm on 5 grouped Porings"
}

// Self-buff
{
  "type": "skill",
  "id": "SM_ENDURE",
  "level": 5,
  "priority": 4,
  "reason": "Cast Endure before engaging"
}
```

---

## Progression Actions

### allocate_stat

**Purpose**: Spend stat points on character attributes.

**Implementation**: [`AI_Bridge.pl:1335-1345`](../plugins/AI_Bridge/AI_Bridge.pl:1335-1345)

**Parameters**:
```json
{
  "type": "allocate_stat",
  "stat": "STR",
  "amount": 5,
  "priority": 1,
  "reason": "Build optimization for Knight"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `stat` | string | ✅ Yes | Stat name: STR, AGI, VIT, INT, DEX, LUK |
| `amount` | integer | ❌ No | Points to allocate (default: 1) |

**OpenKore Command**: `Commands::run("stat_add $stat")` (repeated `amount` times)

**Valid Stat Values**:
- `"STR"` - Strength
- `"AGI"` - Agility
- `"VIT"` - Vitality
- `"INT"` - Intelligence
- `"DEX"` - Dexterity
- `"LUK"` - Luck

**Use Cases**:
- Automated stat progression
- Build-optimized allocation
- Stat point spending on level up
- Character build execution

**Example**:
```json
{
  "type": "allocate_stat",
  "stat": "STR",
  "amount": 3,
  "priority": 1,
  "reason": "Allocate 3 STR for AGI Knight build"
}
```

---

### allocate_skill

**Purpose**: Spend skill points on character skills.

**Implementation**: [`AI_Bridge.pl:1346-1355`](../plugins/AI_Bridge/AI_Bridge.pl:1346-1355)

**Parameters**:
```json
{
  "type": "allocate_skill",
  "skill": "SM_BASH",
  "level": 10,
  "priority": 1,
  "reason": "Max Bash for damage output"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `skill` | string | ✅ Yes | Skill handle name |
| `level` | integer | ✅ Yes | Target skill level |

**OpenKore Command**: `Commands::run("skills add $skill_name")`

**Use Cases**:
- Learn new skills
- Level up existing skills
- Execute skill build plan
- Unlock skill prerequisites

**Example**:
```json
{
  "type": "allocate_skill",
  "skill": "SM_BASH",
  "level": 10,
  "priority": 1,
  "reason": "Allocate Bash to level 10 (max)"
}
```

**Notes**:
- Skill prerequisites are NOT automatically checked
- AI must ensure character meets requirements
- Respects skill point availability

---

## Party Actions

### party_heal

**Purpose**: Heal party member using healing skill.

**Implementation**: [`AI_Bridge.pl:1356-1363`](../plugins/AI_Bridge/AI_Bridge.pl:1356-1363)

**Parameters**:
```json
{
  "type": "party_heal",
  "target_id": "party_member_id",
  "skill_name": "AL_HEAL",
  "priority": 1,
  "reason": "Emergency heal on tank at 30% HP"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `target_id` | string | ✅ Yes | Party member actor ID |
| `skill_name` | string | ❌ No | Healing skill (default: "Heal") |

**OpenKore Command**: `Commands::run("sl $skill_name $target_id")`

**Supported Heal Skills**:
- `AL_HEAL` - Basic heal
- `PR_SANCTUARY` - Area heal
- `AB_HIGHNESSHEAL` - Highness Heal
- `HP_ASSUMPTIO` - Assumptio (defensive)

**Use Cases**:
- Emergency heal on low HP member
- Maintain tank HP
- Preventive healing
- Post-combat recovery

**Example**:
```json
{
  "type": "party_heal",
  "target_id": "tank_char_id",
  "skill_name": "AL_HEAL",
  "priority": 1,
  "reason": "Tank at 35% HP, critical heal needed"
}
```

---

### party_buff

**Purpose**: Cast buff on party member.

**Implementation**: [`AI_Bridge.pl:1364-1371`](../plugins/AI_Bridge/AI_Bridge.pl:1364-1371)

**Parameters**:
```json
{
  "type": "party_buff",
  "target_id": "party_member_id",
  "skill_name": "AL_BLESSING",
  "priority": 4,
  "reason": "Buff DPS for boss fight"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `target_id` | string | ✅ Yes | Party member actor ID |
| `skill_name` | string | ✅ Yes | Buff skill name |

**OpenKore Command**: `Commands::run("sl $skill_name $target_id")`

**Common Buff Skills**:
- `AL_BLESSING` - Blessing (+STR/INT/DEX)
- `AL_INCAGI` - Increase AGI (+AGI/ASPD)
- `PR_KYRIE` - Kyrie Eleison (barrier)
- `PR_IMPOSITIO` - Impositio Manus (+ATK)

**Use Cases**:
- Pre-combat buffing
- Maintain critical buffs
- Support role execution
- Boss fight preparation

**Example**:
```json
{
  "type": "party_buff",
  "target_id": "dps_char_id",
  "skill_name": "AL_INCAGI",
  "priority": 4,
  "reason": "Buff DPS with Increase AGI for boss"
}
```

---

## Companion Actions

### feed_pet

**Purpose**: Feed pet to maintain intimacy/hunger.

**Implementation**: [`AI_Bridge.pl:1372-1378`](../plugins/AI_Bridge/AI_Bridge.pl:1372-1378)

**Parameters**:
```json
{
  "type": "feed_pet",
  "food_id": 537,
  "priority": 6,
  "reason": "Pet hunger at 40, feed to maintain intimacy"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `food_id` | integer | ✅ Yes | Food item ID |

**OpenKore Command**: `Commands::run("pet feed $food_id")`

**Common Pet Foods**:
- `537` - Pet Food (general)
- `554` - Sheep Food
- `555` - Chicken Food
- And pet-specific foods...

**Use Cases**:
- Prevent pet from leaving (low intimacy)
- Maintain pet performance
- Automated pet care

**Example**:
```json
{
  "type": "feed_pet",
  "food_id": 537,
  "priority": 6,
  "reason": "Pet hunger 35/100, feed to prevent intimacy loss"
}
```

---

### homun_skill

**Purpose**: Use homunculus skill on target.

**Implementation**: [`AI_Bridge.pl:1379-1386`](../plugins/AI_Bridge/AI_Bridge.pl:1379-1386)

**Parameters**:
```json
{
  "type": "homun_skill",
  "skill_id": 8001,
  "target_id": "monster_id",
  "priority": 3,
  "reason": "Homunculus attack skill"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `skill_id` | integer | ✅ Yes | Homunculus skill ID |
| `target_id` | string | ❌ No | Target actor ID (default: 0) |

**OpenKore Command**: `Commands::run("homun_skill $skill_id $target_id")`

**Use Cases**:
- Homunculus combat participation
- Support skill usage
- Automated companion control

**Example**:
```json
{
  "type": "homun_skill",
  "skill_id": 8001,
  "target_id": "poring_123",
  "priority": 3,
  "reason": "Homunculus Caprice on low HP target"
}
```

---

### mount

**Purpose**: Mount riding creature (Peco, Dragon, etc.).

**Implementation**: [`AI_Bridge.pl:1387-1391`](../plugins/AI_Bridge/AI_Bridge.pl:1387-1391)

**Parameters**:
```json
{
  "type": "mount",
  "priority": 7,
  "reason": "Mount for faster travel"
}
```

**OpenKore Command**: `Commands::run("mount")`

**Use Cases**:
- Increase movement speed
- Access mounted skills
- Long-distance travel

**Example**:
```json
{
  "type": "mount",
  "priority": 7,
  "reason": "Mount Peco for faster farming route"
}
```

---

### dismount

**Purpose**: Dismount from riding creature.

**Implementation**: [`AI_Bridge.pl:1392-1396`](../plugins/AI_Bridge/AI_Bridge.pl:1392-1396)

**Parameters**:
```json
{
  "type": "dismount",
  "priority": 7,
  "reason": "Dismount to use non-mounted skills"
}
```

**OpenKore Command**: `Commands::run("mount")` (toggle)

**Use Cases**:
- Access non-mounted skills
- Enter areas where mount is restricted
- Combat optimization

**Example**:
```json
{
  "type": "dismount",
  "priority": 7,
  "reason": "Dismount to use Bowling Bash"
}
```

---

## NPC Actions

### npc_talk

**Purpose**: Initiate dialogue with NPC.

**Implementation**: [`AI_Bridge.pl:1397-1403`](../plugins/AI_Bridge/AI_Bridge.pl:1397-1403)

**Parameters**:
```json
{
  "type": "npc_talk",
  "npc_id": "npc_actor_id",
  "priority": 5,
  "reason": "Start quest dialogue"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `npc_id` | string | ✅ Yes | NPC actor ID |

**OpenKore Command**: `Commands::run("talk $npc_id")`

**Use Cases**:
- Start quest
- Access NPC shop
- Trigger dialogue tree
- Job advancement NPC

**Example**:
```json
{
  "type": "npc_talk",
  "npc_id": "npc_12345",
  "priority": 5,
  "reason": "Talk to Quest NPC to start 'Find Jellopy' quest"
}
```

---

### npc_choose

**Purpose**: Select dialogue option during NPC conversation.

**Implementation**: [`AI_Bridge.pl:1404-1410`](../plugins/AI_Bridge/AI_Bridge.pl:1404-1410)

**Parameters**:
```json
{
  "type": "npc_choose",
  "choice_index": 0,
  "priority": 5,
  "reason": "Choose 'Accept Quest' option"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `choice_index` | integer | ✅ Yes | 0-based index of choice |

**OpenKore Command**: `Commands::run("talk resp $choice_index")`

**Use Cases**:
- Accept quests
- Navigate dialogue trees
- Access NPC shop/services
- Make dialogue decisions

**Example**:
```json
{
  "type": "npc_choose",
  "choice_index": 0,
  "priority": 5,
  "reason": "Choose option 0: 'I want to buy items'"
}
```

---

### npc_close

**Purpose**: Close NPC dialogue window.

**Implementation**: [`AI_Bridge.pl:1411-1415`](../plugins/AI_Bridge/AI_Bridge.pl:1411-1415)

**Parameters**:
```json
{
  "type": "npc_close",
  "priority": 5,
  "reason": "Exit dialogue after completing transaction"
}
```

**OpenKore Command**: `Commands::run("talk cont")`

**Use Cases**:
- Exit dialogue after quest acceptance
- Close shop after purchase
- Continue after information NPC
- Cleanup after dialogue tree

**Example**:
```json
{
  "type": "npc_close",
  "priority": 5,
  "reason": "Close dialogue after buying potions"
}
```

---

## Inventory Actions

### use_item

**Purpose**: Use consumable item from inventory.

**Implementation**: [`AI_Bridge.pl:1568-1585`](../plugins/AI_Bridge/AI_Bridge.pl:1568-1585)

**Parameters**:
```json
{
  "type": "use_item",
  "id": 501,
  "amount": 1,
  "priority": 2,
  "reason": "Use Red Potion for HP recovery"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id` | integer | ✅ Yes | Item nameID |
| `amount` | integer | ❌ No | Quantity to use (default: 1) |

**OpenKore Command**: `AI::queue('useSelf', {item => $item, amount => $amount})`

**Common Items**:
- `501` - Red Potion
- `502` - Orange Potion
- `503` - Yellow Potion
- `504` - White Potion
- `506` - Green Potion
- `507` - Red Herb
- `508` - Yellow Herb
- `509` - White Herb
- `601` - Fly Wing
- `602` - Butterfly Wing

**Use Cases**:
- HP recovery (potions/herbs)
- SP recovery
- Emergency teleport (Fly Wing)
- Status cure items
- Buff items

**Example**:
```json
{
  "type": "use_item",
  "id": 501,
  "amount": 1,
  "priority": 2,
  "reason": "HP at 45%, use Red Potion"
}
```

---

### pick_item

**Purpose**: Pick up item from ground.

**Implementation**: [`AI_Bridge.pl:1587-1599`](../plugins/AI_Bridge/AI_Bridge.pl:1587-1599)

**Parameters**:
```json
{
  "type": "pick_item",
  "target": "item_actor_id",
  "priority": 6,
  "reason": "Pick up valuable drop"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `target` | string | ✅ Yes | Ground item actor ID |

**OpenKore Command**: `AI::queue('take', {item => $item_id})`

**Use Cases**:
- Collect quest items
- Loot valuable drops
- Gather crafting materials
- Pick up zeny

**Example**:
```json
{
  "type": "pick_item",
  "target": "item_ground_456",
  "priority": 6,
  "reason": "Pick up Jellopy for quest"
}
```

---

### drop_item

**Purpose**: Drop item from inventory to ground.

**Implementation**: [`AI_Bridge.pl:1439-1446`](../plugins/AI_Bridge/AI_Bridge.pl:1439-1446)

**Parameters**:
```json
{
  "type": "drop_item",
  "item_index": 5,
  "amount": 10,
  "priority": 8,
  "reason": "Drop excess arrows to reduce weight"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_index` | integer | ✅ Yes | Inventory slot index |
| `amount` | integer | ❌ No | Quantity to drop (default: 1) |

**OpenKore Command**: `Commands::run("drop $item_index $amount")`

**Use Cases**:
- Weight management
- Remove unwanted items
- Make inventory space
- Discard quest items

**Example**:
```json
{
  "type": "drop_item",
  "item_index": 5,
  "amount": 50,
  "priority": 8,
  "reason": "Drop 50 Jellopies to reduce weight (90% full)"
}
```

---

### equip_item

**Purpose**: Equip item from inventory.

**Implementation**: [`AI_Bridge.pl:1447-1453`](../plugins/AI_Bridge/AI_Bridge.pl:1447-1453)

**Parameters**:
```json
{
  "type": "equip_item",
  "item_index": 3,
  "priority": 5,
  "reason": "Equip fire weapon for water monsters"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_index` | integer | ✅ Yes | Inventory slot index |

**OpenKore Command**: `Commands::run("eq $item_index")`

**Use Cases**:
- Situational gear swapping
- Equip better gear
- Element advantage setup
- Role-specific loadouts

**Example**:
```json
{
  "type": "equip_item",
  "item_index": 3,
  "priority": 5,
  "reason": "Equip Flaming Sword for Poison Spore farming"
}
```

---

### unequip_item

**Purpose**: Unequip item from equipment slot.

**Implementation**: [`AI_Bridge.pl:1454-1460`](../plugins/AI_Bridge/AI_Bridge.pl:1454-1460)

**Parameters**:
```json
{
  "type": "unequip_item",
  "slot": "weapon",
  "priority": 5,
  "reason": "Unequip to switch gear"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `slot` | string | ✅ Yes | Equipment slot name |

**OpenKore Command**: `Commands::run("uneq $slot")`

**Valid Slots**:
- `head_top`, `head_mid`, `head_low`
- `armor`, `weapon`, `shield`
- `shoes`, `garment`
- `accessory_left`, `accessory_right`
- `ammo`

**Use Cases**:
- Gear switching preparation
- Remove broken equipment
- Weight reduction
- Situational unequip

**Example**:
```json
{
  "type": "unequip_item",
  "slot": "weapon",
  "priority": 5,
  "reason": "Unequip Dagger to switch to Bow"
}
```

---

## Storage Actions

### storage_get

**Purpose**: Retrieve item from Kafra storage.

**Implementation**: [`AI_Bridge.pl:1461-1468`](../plugins/AI_Bridge/AI_Bridge.pl:1461-1468)

**Parameters**:
```json
{
  "type": "storage_get",
  "item_index": 2,
  "amount": 100,
  "priority": 7,
  "reason": "Get potions from storage"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_index` | integer | ✅ Yes | Storage slot index |
| `amount` | integer | ❌ No | Quantity to retrieve (default: 1) |

**OpenKore Command**: `Commands::run("storage get $item_index $amount")`

**Use Cases**:
- Restock consumables
- Retrieve quest items
- Get equipment for job change
- Bank management

**Example**:
```json
{
  "type": "storage_get",
  "item_index": 2,
  "amount": 100,
  "priority": 7,
  "reason": "Get 100 Red Potions for farming session"
}
```

**Notes**:
- Must be at Kafra/storage NPC
- Storage must be open
- Item must exist in storage

---

### storage_add

**Purpose**: Deposit item into Kafra storage.

**Implementation**: [`AI_Bridge.pl:1469-1476`](../plugins/AI_Bridge/AI_Bridge.pl:1469-1476)

**Parameters**:
```json
{
  "type": "storage_add",
  "item_index": 8,
  "amount": 200,
  "priority": 7,
  "reason": "Store excess materials"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_index` | integer | ✅ Yes | Inventory slot index |
| `amount` | integer | ❌ No | Quantity to deposit (default: 1) |

**OpenKore Command**: `Commands::run("storage add $item_index $amount")`

**Use Cases**:
- Store excess items
- Bank valuable drops
- Weight management
- Long-term material storage

**Example**:
```json
{
  "type": "storage_add",
  "item_index": 8,
  "amount": 200,
  "priority": 7,
  "reason": "Store 200 Jellopies in bank"
}
```

---

## Economy Actions

### buy_from_npc

**Purpose**: Purchase item from NPC shop.

**Implementation**: [`AI_Bridge.pl:1477-1484`](../plugins/AI_Bridge/AI_Bridge.pl:1477-1484)

**Parameters**:
```json
{
  "type": "buy_from_npc",
  "item_id": 501,
  "amount": 50,
  "priority": 6,
  "reason": "Restock Red Potions"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_id` | integer | ✅ Yes | Item nameID to buy |
| `amount` | integer | ❌ No | Quantity to buy (default: 1) |

**OpenKore Command**: `Commands::run("buy $item_id $amount")`

**Use Cases**:
- Restock consumables
- Buy arrows/ammunition
- Purchase quest items
- Get crafting materials

**Example**:
```json
{
  "type": "buy_from_npc",
  "item_id": 501,
  "amount": 100,
  "priority": 6,
  "reason": "Buy 100 Red Potions from Tool Dealer"
}
```

---

### sell_to_npc

**Purpose**: Sell inventory item to NPC.

**Implementation**: [`AI_Bridge.pl:1485-1492`](../plugins/AI_Bridge/AI_Bridge.pl:1485-1492)

**Parameters**:
```json
{
  "type": "sell_to_npc",
  "item_index": 12,
  "amount": 100,
  "priority": 7,
  "reason": "Sell looted items for zeny"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_index` | integer | ✅ Yes | Inventory slot index |
| `amount` | integer | ❌ No | Quantity to sell (default: 1) |

**OpenKore Command**: `Commands::run("sell $item_index $amount")`

**Use Cases**:
- Convert loot to zeny
- Clear inventory space
- Maintain weight under limit
- Economic optimization

**Example**:
```json
{
  "type": "sell_to_npc",
  "item_index": 12,
  "amount": 150,
  "priority": 7,
  "reason": "Sell 150 Jellopies to NPC for 150z"
}
```

---

### buy_from_vendor

**Purpose**: Purchase from player vendor shop.

**Implementation**: [`AI_Bridge.pl:1493-1501`](../plugins/AI_Bridge/AI_Bridge.pl:1493-1501)

**Parameters**:
```json
{
  "type": "buy_from_vendor",
  "vendor_id": "vendor_actor_id",
  "item_index": 0,
  "amount": 10,
  "priority": 6,
  "reason": "Buy underpriced item from vendor"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `vendor_id` | string | ✅ Yes | Vendor actor ID |
| `item_index` | integer | ✅ Yes | Index in vendor's item list |
| `amount` | integer | ❌ No | Quantity to buy (default: 1) |

**OpenKore Command**: `Commands::run("vender $vendor_id $item_index $amount")`

**Use Cases**:
- Buy from player shops
- Arbitrage opportunities
- Market intelligence
- Rare item acquisition

**Example**:
```json
{
  "type": "buy_from_vendor",
  "vendor_id": "player_vendor_789",
  "item_index": 0,
  "amount": 5,
  "priority": 6,
  "reason": "Buy 5 Eluniums at 2000z each (market price: 2500z)"
}
```

---

## Communication Actions

### chat_send

**Purpose**: Send message to chat channel.

**Implementation**: [`AI_Bridge.pl:1416-1433`](../plugins/AI_Bridge/AI_Bridge.pl:1416-1433)

**Parameters (Public Chat)**:
```json
{
  "type": "chat_send",
  "channel": "public",
  "content": "Hello everyone!",
  "priority": 8,
  "reason": "Respond to greeting"
}
```

**Parameters (Whisper)**:
```json
{
  "type": "chat_send",
  "channel": "whisper",
  "target_name": "PlayerName",
  "content": "Hi there!",
  "priority": 8,
  "reason": "Reply to PM"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `channel` | string | ✅ Yes | Chat channel: public, party, guild, whisper |
| `content` | string | ✅ Yes | Message text |
| `target_name` | string | ❌ No* | Recipient name (whisper only) |

*Required if `channel` = "whisper"

**OpenKore Commands**:
- Public: `Commands::run("c $content")`
- Party: `Commands::run("p $content")`
- Guild: `Commands::run("g $content")`
- Whisper: `Commands::run("pm \"$target\" $content")`

**Use Cases**:
- Social interaction
- Party coordination ("Healing tank")
- Guild announcements
- Trading communication
- Quest coordination

**Examples**:
```json
// Public chat
{
  "type": "chat_send",
  "channel": "public",
  "content": "LF> Party for Orc dungeon",
  "priority": 8,
  "reason": "Find party for quest"
}

// Party chat
{
  "type": "chat_send",
  "channel": "party",
  "content": "Boss spawned at (150, 200)!",
  "priority": 5,
  "reason": "Alert party to MVP"
}

// Guild chat
{
  "type": "chat_send",
  "channel": "guild",
  "content": "WoE starting in 5 minutes",
  "priority": 6,
  "reason": "Guild coordination"
}

// Whisper
{
  "type": "chat_send",
  "channel": "whisper",
  "target_name": "BuyerName",
  "content": "I can sell you 100 Eluniums for 200k",
  "priority": 7,
  "reason": "Trading negotiation"
}
```

---

### sit

**Purpose**: Make character sit down (HP/SP recovery).

**Implementation**: [`AI_Bridge.pl:1321-1322`](../plugins/AI_Bridge/AI_Bridge.pl:1321-1322)

**Parameters**:
```json
{
  "type": "sit",
  "priority": 4,
  "reason": "Recover HP/SP after combat"
}
```

**OpenKore Command**: `AI::queue('sit')`

**Use Cases**:
- HP/SP regeneration
- Wait for party
- AFK positioning
- Recovery between fights

**Example**:
```json
{
  "type": "sit",
  "priority": 4,
  "reason": "Combat complete, sit to recover SP"
}
```

---

### stand

**Purpose**: Make character stand up.

**Implementation**: [`AI_Bridge.pl:1323-1324`](../plugins/AI_Bridge/AI_Bridge.pl:1323-1324)

**Parameters**:
```json
{
  "type": "stand",
  "priority": 3,
  "reason": "Engage approaching monster"
}
```

**OpenKore Command**: `AI::queue('stand')`

**Use Cases**:
- Prepare for combat
- React to approaching enemies
- Movement preparation
- Leave AFK state

**Example**:
```json
{
  "type": "stand",
  "priority": 3,
  "reason": "Monster approaching, stand to engage"
}
```

---

## Utility Actions

### idle

**Purpose**: Explicit no-action state.

**Implementation**: [`AI_Bridge.pl:1329-1331`](../plugins/AI_Bridge/AI_Bridge.pl:1329-1331)

**Parameters**:
```json
{
  "type": "idle",
  "priority": 10,
  "reason": "No threats, wait for events"
}
```

**OpenKore Command**: None (no action queued)

**Use Cases**:
- Explicit wait state
- No threats present
- Waiting for party
- Cooldown periods

**Example**:
```json
{
  "type": "idle",
  "priority": 10,
  "reason": "All skills on cooldown, wait 5 seconds"
}
```

---

### wait

**Purpose**: Timed delay before next action.

**Implementation**: [`AI_Bridge.pl:1332-1334`](../plugins/AI_Bridge/AI_Bridge.pl:1332-1334)

**Parameters**:
```json
{
  "type": "wait",
  "duration_ms": 2000,
  "priority": 9,
  "reason": "Wait for skill cooldown"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `duration_ms` | integer | ❌ No | Wait time in milliseconds |

**OpenKore Command**: Reserved (not fully implemented)

**Use Cases**:
- Cooldown management
- Timing coordination
- Buff synchronization
- Strategic delays

**Example**:
```json
{
  "type": "wait",
  "duration_ms": 3000,
  "priority": 9,
  "reason": "Wait 3s for Blessing to expire before rebuff"
}
```

---

## Action Priority System

### Priority Levels

Actions are executed in **priority order** (lower number = higher priority):

```
Priority 1-2:  🔴 Critical
  - Emergency heals (HP < 20%)
  - Flee from danger
  - Critical buffs (Kyrie before burst)
  - Stat/skill allocation

Priority 3-4:  🟡 Important
  - Offensive skills
  - Party healing (HP < 50%)
  - Combat actions
  - Buff maintenance

Priority 5-6:  🟢 Normal
  - Movement
  - Item pickup
  - Regular item usage
  - NPC interaction

Priority 7-8:  🔵 Low
  - Social chat
  - Weight management
  - Storage operations
  - Non-urgent tasks

Priority 9-10: ⚪ Lowest
  - Idle state
  - Timed waits
  - Cleanup actions
  - Background tasks
```

### Priority Examples

```json
{
  "actions": [
    {
      "type": "skill",
      "id": "AL_HEAL",
      "priority": 1,
      "reason": "HP at 18% - CRITICAL HEAL"
    },
    {
      "type": "attack",
      "target": "monster_123",
      "priority": 3,
      "reason": "Attack low HP target"
    },
    {
      "type": "move",
      "x": 150,
      "y": 200,
      "priority": 5,
      "reason": "Move to next farming spot"
    },
    {
      "type": "chat_send",
      "channel": "party",
      "content": "Ready for next pull",
      "priority": 8,
      "reason": "Party coordination"
    }
  ]
}
```

**Execution Order**: heal → attack → move → chat_send

---

## Complete Action Quick Reference

### Alphabetical Index

| Action | Category | Priority Range | Page |
|--------|----------|----------------|------|
| `allocate_skill` | Progression | 1-2 | [↑](#allocate_skill) |
| `allocate_stat` | Progression | 1-2 | [↑](#allocate_stat) |
| `attack` | Combat | 3-4 | [↑](#attack) |
| `buy_from_npc` | Economy | 6-7 | [↑](#buy_from_npc) |
| `buy_from_vendor` | Economy | 6-7 | [↑](#buy_from_vendor) |
| `chat_send` | Communication | 7-8 | [↑](#chat_send) |
| `dismount` | Companion | 7 | [↑](#dismount) |
| `drop_item` | Inventory | 8 | [↑](#drop_item) |
| `equip_item` | Inventory | 5 | [↑](#equip_item) |
| `feed_pet` | Companion | 6 | [↑](#feed_pet) |
| `homun_skill` | Companion | 3 | [↑](#homun_skill) |
| `idle` | Utility | 10 | [↑](#idle) |
| `mount` | Companion | 7 | [↑](#mount) |
| `move` | Movement | 5-6 | [↑](#move) |
| `npc_choose` | NPC | 5 | [↑](#npc_choose) |
| `npc_close` | NPC | 5 | [↑](#npc_close) |
| `npc_talk` | NPC | 5 | [↑](#npc_talk) |
| `party_buff` | Party | 4 | [↑](#party_buff) |
| `party_heal` | Party | 1-2 | [↑](#party_heal) |
| `pick_item` | Inventory | 6 | [↑](#pick_item) |
| `sell_to_npc` | Economy | 7 | [↑](#sell_to_npc) |
| `sit` | Communication | 4 | [↑](#sit) |
| `skill` | Combat | 2-3 | [↑](#skill) |
| `stand` | Communication | 3 | [↑](#stand) |
| `storage_add` | Storage | 7 | [↑](#storage_add) |
| `storage_get` | Storage | 7 | [↑](#storage_get) |
| `teleport` | Movement | 1 | [↑](#teleport) |
| `unequip_item` | Inventory | 5 | [↑](#unequip_item) |
| `use_item` | Inventory | 2-4 | [↑](#use_item) |
| `wait` | Utility | 9 | [↑](#wait) |

---

## Action Combination Examples

### Example 1: Combat Sequence

```json
{
  "type": "decision",
  "actions": [
    {
      "type": "skill",
      "id": "SM_ENDURE",
      "priority": 4,
      "reason": "Pre-buff with Endure"
    },
    {
      "type": "skill",
      "id": "SM_PROVOKE",
      "target": "monster_123",
      "priority": 3,
      "reason": "Provoke to reduce defense"
    },
    {
      "type": "skill",
      "id": "SM_BASH",
      "level": 10,
      "target": "monster_123",
      "priority": 2,
      "reason": "Finish with max level Bash"
    }
  ]
}
```

---

### Example 2: Party Support

```json
{
  "type": "decision",
  "actions": [
    {
      "type": "party_heal",
      "target_id": "tank_id",
      "skill_name": "AL_HEAL",
      "priority": 1,
      "reason": "Tank at 25% HP - emergency heal"
    },
    {
      "type": "party_buff",
      "target_id": "dps_id",
      "skill_name": "AL_BLESSING",
      "priority": 4,
      "reason": "Buff DPS for boss fight"
    },
    {
      "type": "chat_send",
      "channel": "party",
      "content": "Healing tank, stay grouped",
      "priority": 7,
      "reason": "Party coordination"
    }
  ]
}
```

---

### Example 3: Economic Activity

```json
{
  "type": "decision",
  "actions": [
    {
      "type": "move",
      "x": 120,
      "y": 80,
      "priority": 5,
      "reason": "Move to Kafra storage"
    },
    {
      "type": "storage_add",
      "item_index": 15,
      "amount": 200,
      "priority": 7,
      "reason": "Store 200 Jellopies"
    },
    {
      "type": "storage_get",
      "item_index": 2,
      "amount": 100,
      "priority": 7,
      "reason": "Get 100 Red Potions"
    }
  ]
}
```

---

### Example 4: Quest Automation

```json
{
  "type": "decision",
  "actions": [
    {
      "type": "npc_talk",
      "npc_id": "quest_npc_456",
      "priority": 5,
      "reason": "Talk to quest NPC"
    },
    {
      "type": "npc_choose",
      "choice_index": 0,
      "priority": 5,
      "reason": "Accept quest"
    },
    {
      "type": "npc_close",
      "priority": 5,
      "reason": "Close dialogue"
    },
    {
      "type": "chat_send",
      "channel": "public",
      "content": "Quest accepted, heading to Prontera Field",
      "priority": 8,
      "reason": "Announce quest start"
    }
  ]
}
```

---

## Next Steps

- 🔗 [Integration Guide](AI_SIDECAR_BRIDGE_GUIDE.md) - System architecture
- 🧪 [Testing Guide](BRIDGE_TESTING_GUIDE.md) - Validation procedures
- ⚙️ [Configuration Reference](BRIDGE_CONFIGURATION.md) - Setup options

---

**Last Updated**: December 5, 2025  
**Version**: 1.0.0  
**Actions Documented**: 30+ action types