# 🔗 AI Sidecar Bridge System - Integration Guide

> **Complete documentation for the OpenKore ↔ AI Sidecar bridge system**

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Bridge Layers](#bridge-layers)
- [Data Flow](#data-flow)
- [Subsystem Inventory](#subsystem-inventory)
- [Getting Started](#getting-started)
- [Implementation Details](#implementation-details)
- [Performance Considerations](#performance-considerations)
- [Troubleshooting](#troubleshooting)

---

## Overview

### What is the AI Sidecar Bridge?

The AI Sidecar Bridge is a **high-performance IPC (Inter-Process Communication) system** that connects OpenKore (Perl) to an external AI Sidecar process (Python) via ZeroMQ. This architecture enables:

✅ **Advanced AI Decision-Making** - ML/LLM-powered intelligence separate from game client  
✅ **Clean Separation of Concerns** - OpenKore handles protocol, AI handles decisions  
✅ **Graceful Degradation** - Falls back to built-in AI if sidecar unavailable  
✅ **Multi-Backend Support** - CPU, GPU, ML, or LLM backends  
✅ **Real-time State Sync** - Sub-millisecond latency for game state updates  

### Why This Architecture?

| Traditional Bot | AI Sidecar Architecture |
|-----------------|-------------------------|
| AI logic embedded in bot | AI logic separate process |
| Hard to update/test | Easy to update/iterate |
| Single language (Perl) | Best tool for each job (Perl + Python) |
| Limited by bot capabilities | Access to entire ML/AI ecosystem |
| Difficult debugging | Independent debugging |

---

## Architecture

### System Overview

```
┌────────────────────────────────────────────────────────────────┐
│                   OPENKORE-AI BRIDGE SYSTEM                     │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐      ZeroMQ IPC      ┌─────────────────┐ │
│  │                  │   tcp://127.0.0.1    │                 │ │
│  │   OPENKORE       │◄────────────────────►│  AI SIDECAR     │ │
│  │   (Perl)         │        :5555         │  (Python)       │ │
│  │                  │                      │                 │ │
│  │  ┌────────────┐  │   State Updates      │  ┌───────────┐  │ │
│  │  │ AI_Bridge  │  │  ──────────────►     │  │ Decision  │  │ │
│  │  │  Plugin    │  │                      │  │  Engine   │  │ │
│  │  └────────────┘  │   Action Commands    │  └─────┬─────┘  │ │
│  │                  │  ◄──────────────     │        │        │ │
│  │  ┌────────────┐  │                      │        ▼        │ │
│  │  │   Chat     │  │                      │  ┌───────────┐  │ │
│  │  │  Bridge    │  │                      │  │  Memory   │  │ │
│  │  └────────────┘  │                      │  │  Manager  │  │ │
│  │                  │                      │  └─────┬─────┘  │ │
│  │   Protocol       │                      │        │        │ │
│  │   Handling       │                      │        ▼        │ │
│  │                  │                      │  ┌───────────┐  │ │
│  └────────┬─────────┘                      │  │ Backends  │  │ │
│           │                                │  ├───────────┤  │ │
│           ▼                                │  │CPU│GPU    │  │ │
│  ┌──────────────────┐                      │  │ML │LLM    │  │ │
│  │   RO Server      │                      │  └───────────┘  │ │
│  └──────────────────┘                      └─────────────────┘ │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### OpenKore (Perl) - Game Client Layer
- **Role**: Protocol handling, packet processing, action execution
- **File**: [`plugins/AI_Bridge/AI_Bridge.pl`](../plugins/AI_Bridge/AI_Bridge.pl)
- **Responsibilities**:
  - Extract game state from OpenKore globals
  - Send state updates via ZeroMQ
  - Receive AI decisions
  - Execute actions in-game

#### AI Bridge Plugin
- **Role**: IPC coordinator between OpenKore and AI Sidecar
- **Features**:
  - ZeroMQ REQ socket client
  - JSON message encoding/decoding
  - Graceful degradation on connection loss
  - Automatic reconnection logic
  - Heartbeat monitoring

#### Chat Bridge Plugin
- **Role**: Chat message capture and integration
- **File**: [`plugins/godtier_chat_bridge.pl`](../plugins/godtier_chat_bridge.pl)
- **Features**:
  - Hooks into [`ChatQueue::add()`](../plugins/godtier_chat_bridge.pl:104)
  - Ring buffer (100 messages)
  - Message TTL (300s)
  - Channel mapping (public/party/guild/whisper)

#### AI Sidecar (Python) - Intelligence Layer
- **Role**: AI decision-making and memory management
- **Directory**: [`ai_sidecar/`](../ai_sidecar/)
- **Responsibilities**:
  - Process game state
  - Run decision algorithms (CPU/GPU/ML/LLM)
  - Manage memory systems
  - Return action decisions

---

## Bridge Layers

The bridge system is organized into **priority levels** based on criticality and implementation order:

### 🔴 P0: Critical Bridges (100% Complete)

These bridges are **essential** for basic functionality and character progression.

| Bridge | Completion | Components | Purpose |
|--------|------------|------------|---------|
| **Character Stats** | ✅ 100% | `str`, `agi`, `vit`, `int`, `dex`, `luk` | Core character attributes |
| **Experience** | ✅ 100% | `base_exp`, `job_exp`, `exp_max`, `exp_job_max` | Leveling tracking |
| **Skill Points** | ✅ 100% | `skill_points`, `learned_skills` | Skill system |
| **Stat Allocation** | ✅ 100% | Action: `allocate_stat` | Auto stat point spending |
| **Skill Allocation** | ✅ 100% | Action: `allocate_skill` | Auto skill point spending |

**Implementation**: [`AI_Bridge.pl:650-731`](../plugins/AI_Bridge/AI_Bridge.pl:650-731)

### 🟡 P1: Important Bridges (90% Complete)

These bridges enable **social** and **advanced combat** features.

| Bridge | Completion | Components | Purpose |
|--------|------------|------------|---------|
| **Party Coordination** | ✅ 95% | Party members, HP/SP, healing priority | Group play |
| **Guild Info** | ✅ 90% | Guild stats, members, level | Guild management |
| **Buff Tracking** | ✅ 90% | Active buffs, durations | Combat optimization |
| **Status Effects** | ✅ 90% | Debuffs, ailments | Tactical awareness |
| **Chat Integration** | ✅ 100% | Chat messages, social AI | Communication |

**Implementation**: 
- Party: [`AI_Bridge.pl:828-868`](../plugins/AI_Bridge/AI_Bridge.pl:828-868)
- Guild: [`AI_Bridge.pl:870-893`](../plugins/AI_Bridge/AI_Bridge.pl:870-893)
- Buffs: [`AI_Bridge.pl:895-926`](../plugins/AI_Bridge/AI_Bridge.pl:895-926)
- Chat: [`godtier_chat_bridge.pl`](../plugins/godtier_chat_bridge.pl)

### 🟢 P2: Advanced Bridges (80% Complete)

These bridges provide **companion management** and **equipment** features.

| Bridge | Completion | Components | Purpose |
|--------|------------|------------|---------|
| **Pet Management** | ✅ 80% | Pet state, intimacy, hunger | Pet AI |
| **Homunculus** | ✅ 80% | Homun stats, skills, hunger | Homun AI |
| **Mercenary** | ✅ 80% | Merc state, contract time | Merc management |
| **Mount System** | ✅ 85% | Mount status, cart info | Mobility |
| **Equipment** | ✅ 70% | Equipped items, refine levels | Gear tracking |

**Implementation**:
- Pet: [`AI_Bridge.pl:928-948`](../plugins/AI_Bridge/AI_Bridge.pl:928-948)
- Homunculus: [`AI_Bridge.pl:950-982`](../plugins/AI_Bridge/AI_Bridge.pl:950-982)
- Mercenary: [`AI_Bridge.pl:984-1007`](../plugins/AI_Bridge/AI_Bridge.pl:984-1007)
- Mount: [`AI_Bridge.pl:1009-1026`](../plugins/AI_Bridge/AI_Bridge.pl:1009-1026)
- Equipment: [`AI_Bridge.pl:1028-1076`](../plugins/AI_Bridge/AI_Bridge.pl:1028-1076)

### 🔵 P3: Optional Bridges (60% Complete)

These bridges enable **advanced features** like questing and economy.

| Bridge | Completion | Components | Purpose |
|--------|------------|------------|---------|
| **NPC Dialogue** | ✅ 65% | Dialogue state, choices | Quest automation |
| **Quest Tracking** | ✅ 65% | Active quests, objectives | Quest completion |
| **Market Data** | ✅ 60% | Vendors, prices, items | Economy AI |
| **Environment** | ✅ 50% | Time, weather, events | Context awareness |
| **Ground Items** | ✅ 70% | Items on ground, positions | Loot optimization |

**Implementation**:
- NPC: [`AI_Bridge.pl:1094-1135`](../plugins/AI_Bridge/AI_Bridge.pl:1094-1135)
- Quests: [`AI_Bridge.pl:1137-1169`](../plugins/AI_Bridge/AI_Bridge.pl:1137-1169)
- Market: [`AI_Bridge.pl:1171-1216`](../plugins/AI_Bridge/AI_Bridge.pl:1171-1216)
- Environment: [`AI_Bridge.pl:1218-1232`](../plugins/AI_Bridge/AI_Bridge.pl:1218-1232)
- Ground Items: [`AI_Bridge.pl:1234-1265`](../plugins/AI_Bridge/AI_Bridge.pl:1234-1265)

---

## Data Flow

### State Update Flow (OpenKore → AI Sidecar)

```
┌─────────────────────────────────────────────────────────────┐
│  STEP 1: State Extraction (OpenKore)                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  AI_pre hook triggered                                      │
│         ↓                                                    │
│  build_game_state() called                                  │
│         ↓                                                    │
│  ┌──────────────────────────────────────────────┐          │
│  │ Extract from Globals:                         │          │
│  │  • $char (character state)                    │          │
│  │  • %monsters, %players, %npcs (actors)        │          │
│  │  • $char->{inventory} (items)                 │          │
│  │  • $field (map info)                          │          │
│  │  • $char->{party}, $char->{guild}             │          │
│  │  • $char->{pet}, $char->{homunculus}          │          │
│  │  • $questList, $venderLists, $itemsList      │          │
│  │  • Chat messages (via GodTierChatBridge)     │          │
│  └──────────────────────────────────────────────┘          │
│         ↓                                                    │
│  Format as JSON game_state object                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 2: Message Transmission (ZeroMQ)                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  send_state_update() called                                 │
│         ↓                                                    │
│  Build message envelope:                                    │
│  {                                                           │
│    "type": "state_update",                                  │
│    "timestamp": 1701234567890,                              │
│    "tick": 12345,                                           │
│    "payload": { /* game_state */ }                          │
│  }                                                           │
│         ↓                                                    │
│  JSON encode → ZMQ REQ socket → tcp://127.0.0.1:5555       │
│         ↓                                                    │
│  Wait for response (timeout: 50ms default)                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 3: AI Processing (Python AI Sidecar)                  │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ZMQ REP socket receives message                            │
│         ↓                                                    │
│  Parse JSON, validate game_state                            │
│         ↓                                                    │
│  Decision Engine processes state:                           │
│    • Combat AI (target selection, skills)                   │
│    • Progression AI (stat/skill allocation)                 │
│    • Social AI (chat responses)                             │
│    • Economic AI (trading, market)                          │
│    • Quest AI (dialogue, objectives)                        │
│         ↓                                                    │
│  Generate decision with prioritized actions                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────────────────────┐
│  STEP 4: Decision Application (OpenKore)                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Receive decision response from ZMQ                         │
│         ↓                                                    │
│  apply_decisions() extracts actions                         │
│         ↓                                                    │
│  Sort actions by priority (1 = highest)                     │
│         ↓                                                    │
│  For each action:                                           │
│    apply_single_action()                                    │
│         ↓                                                    │
│    Execute via OpenKore commands:                           │
│      • AI::queue() for movement/combat                      │
│      • Commands::run() for stat/skill/chat                  │
│      • $messageSender for protocol packets                  │
│         ↓                                                    │
│  Actions executed in game                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Timing Diagram

```
Time (ms) │ OpenKore                │ AI Sidecar
──────────┼─────────────────────────┼──────────────────────
    0     │ AI_pre hook             │
    1     │ build_game_state()      │
    3     │ JSON encode             │
    4     │ ZMQ send ───────────────►
    5     │                         │ Receive & parse
    8     │                         │ Process state
   12     │                         │ Generate decision
   15     │                         │ JSON encode
   16     │ ◄─────────────── ZMQ recv
   17     │ Parse decision          │
   19     │ apply_decisions()       │
   25     │ Queue AI actions        │
   30     │ Execute in-game         │
──────────┼─────────────────────────┼──────────────────────
          │ Total: ~30ms per tick   │
```

---

## Subsystem Inventory

### Complete Subsystem Status

| # | Subsystem | Bridge Status | Completion | Priority |
|---|-----------|---------------|------------|----------|
| 1 | **Core (IPC/Decision)** | ✅ Fully Bridged | 100% | P0 |
| 2 | **Social (Chat/Party/Guild/MVP)** | ✅ Bridged | 90% | P1 |
| 3 | **Progression (Stats/Skills/Lifecycle)** | ✅ Bridged | 95% | P0 |
| 4 | **Combat (Skills/Tactics/Targeting)** | ✅ Bridged | 85% | P0 |
| 5 | **Companions (Pet/Homun/Merc/Mount)** | ✅ Bridged | 80% | P2 |
| 6 | **Consumables (Buffs/Recovery/Status)** | ✅ Bridged | 75% | P1 |
| 7 | **Equipment (Scoring/Optimization)** | ⚠️ Partial | 70% | P2 |
| 8 | **Economy (Market/Trading/Storage)** | ⚠️ Partial | 60% | P3 |
| 9 | **NPC/Quest (Dialogue/Automation)** | ⚠️ Partial | 65% | P3 |
| 10 | **Environment (Time/Weather/Events)** | ⚠️ Partial | 50% | P3 |

**Overall Bridge Completion: ~80%** (8/10 subsystems at 70%+)

### Subsystem Details

#### 1. Core (IPC/Decision) - 100% ✅

**What it does**: Foundation for all communication between OpenKore and AI Sidecar.

**Bridge Components**:
- ✅ ZeroMQ REQ/REP socket communication
- ✅ JSON message encoding/decoding
- ✅ Heartbeat monitoring
- ✅ Graceful degradation
- ✅ Automatic reconnection

**Key Files**:
- [`AI_Bridge.pl`](../plugins/AI_Bridge/AI_Bridge.pl) - Main bridge plugin
- [`AI_Bridge.txt`](../plugins/AI_Bridge/AI_Bridge.txt) - Configuration

**Status**: Production-ready, stable

---

#### 2. Social (Chat/Party/Guild/MVP) - 90% ✅

**What it does**: Enables social interaction, party coordination, and guild features.

**Bridge Components**:
- ✅ Chat message capture (public, party, guild, whisper)
- ✅ Party member tracking (HP, SP, position)
- ✅ Guild information sync
- ✅ Party heal/buff targeting
- ⚠️ MVP call-outs (partial)

**Key Files**:
- [`godtier_chat_bridge.pl`](../plugins/godtier_chat_bridge.pl) - Chat capture
- [`AI_Bridge.pl:828-893`](../plugins/AI_Bridge/AI_Bridge.pl:828-893) - Party/Guild extraction

**Missing Features**:
- Advanced party coordination (tactical positioning)
- Guild skill usage automation
- MVP spawn timer integration

**Status**: Fully functional for core features

---

#### 3. Progression (Stats/Skills/Lifecycle) - 95% ✅

**What it does**: Autonomous character progression from Novice to endgame.

**Bridge Components**:
- ✅ Character stats (STR/AGI/VIT/INT/DEX/LUK)
- ✅ Experience tracking (base + job)
- ✅ Stat point allocation (`allocate_stat` action)
- ✅ Skill point allocation (`allocate_skill` action)
- ✅ Learned skills inventory
- ⚠️ Job change detection (partial)

**Key Files**:
- [`AI_Bridge.pl:650-731`](../plugins/AI_Bridge/AI_Bridge.pl:650-731) - Character state
- [`AI_Bridge.pl:1331-1355`](../plugins/AI_Bridge/AI_Bridge.pl:1331-1355) - Allocation actions

**Status**: Core progression fully automated

---

#### 4. Combat (Skills/Tactics/Targeting) - 85% ✅

**What it does**: Intelligent combat decision-making and skill execution.

**Bridge Components**:
- ✅ Monster targeting (actors state)
- ✅ Skill usage (learned skills)
- ✅ Basic attack queuing
- ✅ Status effect tracking
- ⚠️ Combo system (partial)
- ⚠️ Animation canceling (missing)

**Key Files**:
- [`AI_Bridge.pl:733-798`](../plugins/AI_Bridge/AI_Bridge.pl:733-798) - Actor state
- [`AI_Bridge.pl:1520-1566`](../plugins/AI_Bridge/AI_Bridge.pl:1520-1566) - Combat actions
- [`combat/models.py`](../ai_sidecar/combat/models.py) - Combat data models

**Status**: Functional for standard combat

---

#### 5. Companions (Pet/Homun/Merc/Mount) - 80% ✅

**What it does**: Manages pet, homunculus, mercenary, and mount systems.

**Bridge Components**:
- ✅ Pet state (intimacy, hunger)
- ✅ Homunculus state (stats, skills, HP/SP)
- ✅ Mercenary state (contract time, faith)
- ✅ Mount state (mounted, cart)
- ✅ Feed pet action
- ✅ Homunculus skill usage
- ✅ Mount/dismount actions

**Key Files**:
- [`AI_Bridge.pl:928-1026`](../plugins/AI_Bridge/AI_Bridge.pl:928-1026) - Companion extraction
- [`AI_Bridge.pl:1372-1396`](../plugins/AI_Bridge/AI_Bridge.pl:1372-1396) - Companion actions

**Status**: Core features working, evolution system partial

---

#### 6. Consumables (Buffs/Recovery/Status) - 75% ✅

**What it does**: Tracks buffs, debuffs, and manages consumable items.

**Bridge Components**:
- ✅ Active buff tracking
- ✅ Status effect detection
- ✅ Buff duration monitoring
- ⚠️ Item usage automation (partial)
- ⚠️ Potion optimization (missing)

**Key Files**:
- [`AI_Bridge.pl:672-686`](../plugins/AI_Bridge/AI_Bridge.pl:672-686) - Status effects
- [`AI_Bridge.pl:895-926`](../plugins/AI_Bridge/AI_Bridge.pl:895-926) - Buff state

**Status**: Tracking complete, automation partial

---

#### 7. Equipment (Scoring/Optimization) - 70% ⚠️

**What it does**: Tracks equipped items and optimizes gear loadouts.

**Bridge Components**:
- ✅ Equipped items extraction
- ✅ Refine level tracking
- ✅ Equip/unequip actions
- ⚠️ Gear scoring (partial)
- ⚠️ Auto-upgrade (missing)
- ⚠️ Situational loadouts (missing)

**Key Files**:
- [`AI_Bridge.pl:1028-1076`](../plugins/AI_Bridge/AI_Bridge.pl:1028-1076) - Equipment state
- [`AI_Bridge.pl:1447-1460`](../plugins/AI_Bridge/AI_Bridge.pl:1447-1460) - Equip actions

**Status**: Basic tracking works, AI optimization needed

---

#### 8. Economy (Market/Trading/Storage) - 60% ⚠️

**What it does**: Market intelligence, trading, and storage management.

**Bridge Components**:
- ✅ Vendor tracking
- ✅ Item price extraction
- ✅ Buy/sell actions
- ✅ Storage get/add actions
- ⚠️ Market analysis (missing)
- ⚠️ Arbitrage detection (missing)

**Key Files**:
- [`AI_Bridge.pl:1171-1216`](../plugins/AI_Bridge/AI_Bridge.pl:1171-1216) - Market state
- [`AI_Bridge.pl:1461-1501`](../plugins/AI_Bridge/AI_Bridge.pl:1461-1501) - Economy actions

**Status**: Basic economy functional, intelligence layer needed

---

#### 9. NPC/Quest (Dialogue/Automation) - 65% ⚠️

**What it does**: Automated NPC dialogue and quest completion.

**Bridge Components**:
- ✅ NPC dialogue state
- ✅ Dialogue choices extraction
- ✅ NPC talk/choose/close actions
- ⚠️ Quest objective tracking (partial)
- ⚠️ Quest automation (partial)

**Key Files**:
- [`AI_Bridge.pl:1094-1135`](../plugins/AI_Bridge/AI_Bridge.pl:1094-1135) - NPC dialogue
- [`AI_Bridge.pl:1137-1169`](../plugins/AI_Bridge/AI_Bridge.pl:1137-1169) - Quest state
- [`AI_Bridge.pl:1397-1415`](../plugins/AI_Bridge/AI_Bridge.pl:1397-1415) - NPC actions

**Status**: Basic NPC interaction works, complex quests need AI

---

#### 10. Environment (Time/Weather/Events) - 50% ⚠️

**What it does**: Contextual awareness of game environment and events.

**Bridge Components**:
- ✅ Server time tracking
- ✅ Day/night detection
- ✅ Weather state
- ❌ Event detection (missing)
- ❌ Server-wide events (missing)
- ❌ WoE timing (missing)

**Key Files**:
- [`AI_Bridge.pl:1218-1232`](../plugins/AI_Bridge/AI_Bridge.pl:1218-1232) - Environment state

**Status**: Basic tracking, event system not implemented

---

## Getting Started

### Customizing AI Subsystems

**By default, ALL 10 AI subsystems are enabled** for full automation. You can selectively disable features you don't want:

#### Quick Configuration

1. **Copy the template:**
   ```bash
   cd ai_sidecar/config
   cp subsystems.yaml.example subsystems.yaml
   ```

2. **Edit to customize:**
   ```bash
   nano subsystems.yaml
   ```

3. **Restart AI Sidecar** to apply changes

On startup, you'll see which subsystems are active:
```
============================================================
AI Sidecar Subsystem Status
============================================================
✅ ENABLED   SOCIAL
✅ ENABLED   PROGRESSION
✅ ENABLED   COMBAT
❌ DISABLED  COMPANIONS
...
============================================================
```

#### Available Subsystems

All 10 subsystems can be individually enabled/disabled:

- 🤝 **Social**: Chat, party, guild, MVP coordination
- 📈 **Progression**: Auto stat/skill allocation, job advancement
- ⚔️ **Combat**: Tactical combat, skill rotation, targeting
- 🐾 **Companions**: Pet, homunculus, mercenary, mount AI
- 💊 **Consumables**: Buff management, healing, status cure
- ⚙️ **Equipment**: Equipment scoring and optimization
- 💰 **Economy**: Market analysis, trading, storage
- 🗣️ **NPC/Quest**: NPC dialogue and quest automation
- 🏰 **Instances**: Endless Tower, Memorial Dungeons
- 🌤️ **Environment**: Time, weather, event awareness

📖 **Full Configuration Guide**: [CONFIGURATION.md](../ai_sidecar/CONFIGURATION.md)

---

### Prerequisites

1. **OpenKore** - Latest version with Perl 5.10+
2. **Python 3.10+** - For AI Sidecar
3. **ZeroMQ Library** - Communication layer
4. **Perl Modules**:
   - `ZMQ::FFI` (recommended) or `ZMQ::LibZMQ4`
   - `JSON::XS` (recommended) or `JSON`

### Installation Steps

#### 1. Install Perl Dependencies

```bash
# Install ZeroMQ Perl binding (choose one)
cpanm ZMQ::FFI              # Recommended
# or
cpanm ZMQ::LibZMQ4          # Alternative

# Install JSON module (choose one)
cpanm JSON::XS              # Recommended (faster)
# or
cpanm JSON                  # Standard (slower)
```

#### 2. Verify Plugin Installation

Check that the plugins exist:

```bash
ls -la plugins/AI_Bridge/AI_Bridge.pl
ls -la plugins/godtier_chat_bridge.pl
```

#### 3. Configure AI Bridge

Edit `plugins/AI_Bridge/AI_Bridge.txt`:

```ini
# Enable the bridge
AI_Bridge_enabled 1

# ZeroMQ address (default)
AI_Bridge_address tcp://127.0.0.1:5555

# Timeout in milliseconds
AI_Bridge_timeout_ms 50

# Debug mode (0=off, 1=on)
AI_Bridge_debug 0
```

#### 4. Start AI Sidecar

```bash
cd ai_sidecar
python main.py
```

Expected output:
```
[INFO] AI Sidecar starting v3.0.0
[INFO] ZeroMQ server binding to tcp://127.0.0.1:5555
✅ AI Sidecar ready! Listening on: tcp://127.0.0.1:5555
```

#### 5. Start OpenKore

```bash
./start.pl
```

Look for these messages in the console:
```
[AI_Bridge] Plugin loaded (using ZMQ::FFI + JSON::XS)
[AI_Bridge] Connected to AI Sidecar at tcp://127.0.0.1:5555
[ChatBridge] Plugin loaded - monitoring chat messages
✅ God-Tier AI activated!
```

### Verification

Test the connection:

```perl
# In OpenKore console
call print("AI Bridge Connected: " . $AI_Bridge::state{connected} . "\n")
```

Should output: `AI Bridge Connected: 1`

---

## Implementation Details

### State Message Format

Example game state sent to AI Sidecar:

```json
{
  "character": {
    "name": "TestChar",
    "job_id": 4001,
    "base_level": 99,
    "job_level": 50,
    "hp": 8500,
    "hp_max": 10000,
    "sp": 1200,
    "sp_max": 1500,
    "position": { "x": 150, "y": 200 },
    "str": 80,
    "agi": 60,
    "vit": 40,
    "int": 1,
    "dex": 50,
    "luk": 30,
    "stat_points": 5,
    "skill_points": 3,
    "learned_skills": {
      "SM_BASH": { "level": 10, "sp_cost": 15 },
      "SM_PROVOKE": { "level": 10, "sp_cost": 13 }
    },
    "buffs": [
      { "buff_id": 13, "name": "Blessing", "expires_at": 1701234890 }
    ]
  },
  "actors": [
    {
      "id": "1234567890",
      "type": 2,
      "name": "Poring",
      "position": { "x": 155, "y": 205 },
      "hp": 50,
      "hp_max": 60,
      "mob_id": 1002
    }
  ],
  "inventory": [
    {
      "index": 0,
      "item_id": 501,
      "name": "Red Potion",
      "amount": 20,
      "equipped": 0
    }
  ],
  "map": {
    "name": "prt_fild08",
    "width": 400,
    "height": 400
  },
  "party": {
    "party_id": "MyParty",
    "name": "MyParty",
    "members": [
      {
        "char_id": "987654321",
        "name": "PartyMember",
        "hp": 5000,
        "hp_max": 6000,
        "sp": 800,
        "sp_max": 1000,
        "job_class": 23,
        "online": 1,
        "is_leader": 0
      }
    ],
    "member_count": 2
  },
  "extra": {
    "chat_messages": [
      {
        "id": "abc123def4567890",
        "channel": "public",
        "sender": "PlayerName",
        "sender_id": 2018915346,
        "content": "Hello!",
        "timestamp": 1701234567
      }
    ]
  }
}
```

### Decision Message Format

Example AI decision response:

```json
{
  "type": "decision",
  "timestamp": 1701234567890,
  "actions": [
    {
      "type": "allocate_stat",
      "stat": "STR",
      "amount": 2,
      "priority": 1,
      "reason": "Build optimization for Knight"
    },
    {
      "type": "skill",
      "id": "SM_BASH",
      "level": 10,
      "target": "1234567890",
      "priority": 2,
      "reason": "High damage skill on low HP target"
    },
    {
      "type": "chat_send",
      "channel": "public",
      "content": "Hello to you too!",
      "priority": 5,
      "reason": "Respond to greeting"
    }
  ]
}
```

---

## Performance Considerations

### Latency Measurements

| Operation | Typical Time | Target |
|-----------|--------------|--------|
| State extraction | 1-3ms | < 5ms |
| JSON encoding | 0.5-1ms | < 2ms |
| ZMQ transmission | 0.2-0.5ms | < 1ms |
| AI processing (CPU) | 5-10ms | < 20ms |
| AI processing (GPU) | 8-15ms | < 30ms |
| AI processing (LLM) | 500-2000ms | < 3000ms |
| Decision application | 1-2ms | < 5ms |
| **Total (CPU mode)** | **10-20ms** | **< 50ms** |

### Optimization Tips

1. **Use JSON::XS** - 2-3x faster than pure Perl JSON
2. **Enable ZMQ_LINGER=0** - Prevents blocking on close
3. **Set appropriate timeout** - 50ms default, adjust based on backend
4. **Batch actions** - Send multiple actions per decision
5. **Cache repeated queries** - AI Sidecar should cache expensive computations

### Memory Usage

| Component | Memory | Notes |
|-----------|--------|-------|
| AI_Bridge plugin | ~1 MB | Minimal overhead |
| Chat buffer | ~10-20 KB | 100 messages @ ~100 bytes |
| ZMQ context | ~500 KB | Per process |
| JSON encoding | ~50-100 KB | Per message |

---

## Troubleshooting

### Connection Issues

**Problem**: OpenKore can't connect to AI Sidecar

**Check**:
```bash
# Is AI Sidecar running?
ps aux | grep "python main.py"

# Is port 5555 open?
netstat -tlnp | grep 5555

# Check AI Bridge config
grep AI_Bridge_address plugins/AI_Bridge/AI_Bridge.txt
```

**Solution**:
1. Start AI Sidecar first
2. Verify port 5555 is not blocked by firewall
3. Check address matches in both configs

---

### High Latency

**Problem**: Slow decision-making (> 100ms per tick)

**Diagnose**:
```ini
# Enable debug logging
AI_Bridge_debug 1
```

Check OpenKore console for timing:
```
[AI_Bridge] AI_pre tick 12345 completed in 150.23ms
```

**Solutions**:
- Switch from LLM to CPU/GPU backend
- Increase timeout: `AI_Bridge_timeout_ms 100`
- Optimize AI Sidecar decision algorithms
- Use batch processing for expensive operations

---

### Messages Not Captured

**Problem**: Chat messages not appearing in AI Sidecar

**Check**:
```perl
# In OpenKore console
call print(GodTierChatBridge::dump_buffer())
```

**Solutions**:
1. Verify chat bridge plugin loaded: Look for `[ChatBridge] Plugin loaded`
2. Test message injection: `call GodTierChatBridge::inject_test_message('Test', 'public', 'Hi')`
3. Check AI_Bridge integration: Verify `extra.chat_messages` in debug logs

---

### Graceful Degradation Not Working

**Problem**: OpenKore crashes when AI Sidecar disconnects

**Check**:
- Verify `AI_Bridge_enabled 1` in config
- Check for error messages about ZMQ timeouts
- Review connection error handling code

**Expected behavior**:
```
[AI_Bridge] Communication error: timeout
[AI_Bridge] Entering degraded mode, reconnect in 5000ms
```

OpenKore should continue with built-in AI.

---

## Next Steps

- 📖 [Bridge Testing Guide](BRIDGE_TESTING_GUIDE.md) - Validation procedures
- ⚙️ [Bridge Configuration Reference](BRIDGE_CONFIGURATION.md) - All config options
- 📋 [Action Types Reference](ACTION_TYPES_REFERENCE.md) - Complete action list
- 🧪 [AI Sidecar Documentation](../ai_sidecar/README.md) - Python side details

---

**Last Updated**: December 5, 2025  
**Version**: 1.0.0  
**Status**: Production Ready (80% feature complete)