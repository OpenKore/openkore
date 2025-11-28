# God-Tier Ragnarok Online AI Specification

> **Version:** 3.0.0
> **Status:** Production Specification
> **Last Updated:** 2025-11-27
> **Changes:** Added 17 new sections (20-36) covering 154+ missing RO mechanics
> **Last Updated:** November 27, 2025

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Quick Start Guide](#2-quick-start-guide)
   - [2.1 Prerequisites](#21-prerequisites)
   - [2.2 Installation](#22-installation)
   - [2.3 Minimal Configuration](#23-minimal-configuration)
3. [Introduction](#3-introduction)
   - [3.1 What is God-Tier AI?](#31-what-is-god-tier-ai)
   - [3.2 Why OpenKore as Foundation?](#32-why-openkore-as-foundation)
   - [3.3 Target Audience](#33-target-audience)
4. [Core Intelligence Features](#4-core-intelligence-features)
   - [4.1 Adaptive Behavior](#41-adaptive-behavior)
   - [4.2 Memory Systems](#42-memory-systems-long--short-term)
   - [4.3 OpenMemory SDK Integration](#43-openmemory-sdk-integration)
   - [4.4 Predictive Decision Making](#44-predictive-decision-making)
   - [4.5 Behavior Randomization](#45-behavior-randomization)
   - [4.6 Context Awareness](#46-context-awareness)
   - [4.7 Self-Learning Capabilities](#47-self-learning-capabilities)
   - [4.8 Consciousness Simulation](#48-consciousness-simulation)
   - [4.9 Heuristic Strategy System](#49-heuristic-strategy-system)
   - [4.10 Environmental Awareness](#410-environmental-awareness)
   - [4.11 Social-Interaction Mimicking](#411-social-interaction-mimicking)
   - [4.12 Multi-Map Behavior Profiles](#412-multi-map-behavior-profiles)
   - [4.13 Role-Optimized Tactical AI](#413-role-optimized-tactical-ai)
5. [Fully Autonomous AI Capabilities](#5-fully-autonomous-ai-capabilities)
   - [5.1 Character Lifecycle State Machine](#51-character-lifecycle-state-machine)
   - [5.2 Job Advancement Automation](#52-job-advancement-automation)
   - [5.3 Stat Point Distribution Engine](#53-stat-point-distribution-engine)
   - [5.4 Skill Point Allocation System](#54-skill-point-allocation-system)
   - [5.5 Equipment Progression System](#55-equipment-progression-system)
   - [5.6 Leveling Strategy Engine](#56-leveling-strategy-engine)
   - [5.7 Complete Autonomous Gameplay Loop](#57-complete-autonomous-gameplay-loop)
6. [Additional Capabilities](#6-additional-capabilities)
   - [6.1 Anti-Detection Systems](#61-anti-detection-systems)
   - [6.2 Economic Intelligence](#62-economic-intelligence)
   - [6.3 Quest/Objective Automation](#63-questobjective-automation)
   - [6.4 Party Coordination AI](#64-party-coordination-ai)
   - [6.5 Emergency Response System](#65-emergency-response-system)
7. [Compute Backend Options](#7-compute-backend-options)
   - [7.1 CPU-Only Mode](#71-cpu-only-mode)
   - [7.2 GPU-Only Mode](#72-gpu-only-mode)
   - [7.3 Machine Learning Mode](#73-machine-learning-mode)
   - [7.4 LLM API Mode](#74-llm-api-mode-azure-openai-deepseek-claude)
   - [7.5 Hybrid Backend Modes](#75-hybrid-backend-modes)
   - [7.6 ML Models Catalog](#76-ml-models-catalog)
8. [System Architecture Overview](#8-system-architecture-overview)
   - [8.1 High-Level Architecture](#81-high-level-architecture)
   - [8.2 Module Organization](#82-module-organization)
   - [8.3 Data Flow](#83-data-flow)
   - [8.4 Async LLM Decision Architecture](#84-async-llm-decision-architecture)
   - [8.5 Integration with OpenKore](#85-integration-with-openkore)
9. [Memory Architecture](#9-memory-architecture)
   - [9.1 Working Memory (Short-term)](#91-working-memory-short-term)
   - [9.2 Session Memory (DragonFlyDB)](#92-session-memory-dragonflydb)
   - [9.3 Persistent Memory (Long-term)](#93-persistent-memory-long-term)
   - [9.4 Data Schemas](#94-data-schemas)
10. [Configuration Guide](#10-configuration-guide)
    - [10.1 Main Configuration](#101-main-configuration)
    - [10.2 Backend Selection](#102-backend-selection)
    - [10.3 Behavior Tuning](#103-behavior-tuning)
    - [10.4 Map Profiles](#104-map-profiles)
    - [10.5 LLM Provider Setup](#105-llm-provider-setup)
    - [10.6 LLM Custom Prompts](#106-llm-custom-prompts)
11. [Security Considerations](#11-security-considerations)
    - [11.1 API Key Management](#111-api-key-management)
    - [11.2 Privacy Protections](#112-privacy-protections)
    - [11.3 Anti-Detection Measures](#113-anti-detection-measures)
12. [Extensibility](#12-extensibility)
    - [12.1 Creating Custom Behaviors](#121-creating-custom-behaviors)
    - [12.2 Adding New Backends](#122-adding-new-backends)
    - [12.3 Plugin Development](#123-plugin-development)
13. [Limitations & Disclaimers](#13-limitations--disclaimers)
14. [Troubleshooting](#14-troubleshooting)
15. [Gap Analysis & Known Issues](#15-gap-analysis--known-issues)
    - [15.1 Conceptual Considerations](#151-conceptual-considerations)
    - [15.2 Missing Pieces (To Be Completed)](#152-missing-pieces-to-be-completed)
    - [15.3 Security Hardening Required](#153-security-hardening-required)
    - [15.4 Graceful Degradation Protocol](#154-graceful-degradation-protocol)
    - [15.5 Performance Considerations](#155-performance-considerations)
16. [Implementation Strategy](#16-implementation-strategy)
    - [16.1 Key Finding: No EXE Rebuild Required](#161-key-finding-no-exe-rebuild-required)
    - [16.2 Recommended Approach: Plugin-First](#162-recommended-approach-plugin-first)
    - [16.3 Phased Implementation Plan](#163-phased-implementation-plan)
    - [16.4 Recommended File Structure](#164-recommended-file-structure)
    - [16.5 Critical Technical Decisions](#165-critical-technical-decisions)
    - [16.6 Frequently Asked Questions](#166-frequently-asked-questions)
17. [Implementation Roadmap](#17-implementation-roadmap)
18. [FAQ](#18-faq)
19. [Appendices](#19-appendices)
20. [Companion Systems](#20-companion-systems)
    - [20.1 Pet System Intelligence](#201-pet-system-intelligence)
    - [20.2 Homunculus Strategic AI](#202-homunculus-strategic-ai)
    - [20.3 Mercenary Tactical Control](#203-mercenary-tactical-control)
    - [20.4 Mount System Intelligence](#204-mount-system-intelligence)
21. [Consumable & Buff Management](#21-consumable--buff-management)
    - [21.1 Food/Cuisine Buff System](#211-foodcuisine-buff-system)
    - [21.2 Buff Duration Intelligence](#212-buff-duration-intelligence)
    - [21.3 Recovery Item Priority System](#213-recovery-item-priority-system)
    - [21.4 Catalyst Management](#214-catalyst-management)
22. [Instance/Dungeon Systems](#22-instancedungeon-systems)
    - [22.1 Memorial Dungeon Management](#221-memorial-dungeon-management)
    - [22.2 Instance Cooldown Tracking](#222-instance-cooldown-tracking)
    - [22.3 Daily/Weekly Limit Tracking](#223-dailyweekly-limit-tracking)
    - [22.4 Boss Pattern Recognition](#224-boss-pattern-recognition-ml-enhanced)
23. [Crafting Systems](#23-crafting-systems)
    - [23.1 Blacksmith Forging](#231-blacksmith-forging)
    - [23.2 Alchemist Brewing/Pharmacy](#232-alchemist-brewingpharmacy)
    - [23.3 Rune Creation](#233-rune-creation-rune-knight)
    - [23.4 Genetics Creation](#234-genetics-creation)
    - [23.5 Shadow Equipment System](#235-shadow-equipment-system)
    - [23.6 Costume Synthesis](#236-costume-synthesis)
24. [Enchanting & Refining Advanced](#24-enchanting--refining-advanced)
    - [24.1 Socket Enchanting Intelligence](#241-socket-enchanting-intelligence)
    - [24.2 Refine Strategy Engine](#242-refine-strategy-engine)
    - [24.3 Over-Refine Optimization](#243-over-refine-optimization)
    - [24.4 HD/Enriched Ore Intelligence](#244-hdenriched-ore-intelligence)
    - [24.5 Shadow Equipment Enchanting](#245-shadow-equipment-enchanting)
25. [Achievement Systems](#25-achievement-systems)
    - [25.1 Achievement Tracking](#251-achievement-tracking)
    - [25.2 Title Collection & Management](#252-title-collection--management)
    - [25.3 Achievement Reward System](#253-achievement-reward-system)
26. [Hunting & Daily Systems](#26-hunting--daily-systems)
    - [26.1 Eden Group Quest Automation](#261-eden-group-quest-automation)
    - [26.2 Hunting Board System](#262-hunting-board-system)
    - [26.3 Daily Mission Rotation](#263-daily-mission-rotation)
    - [26.4 Gramps Quest System](#264-gramps-quest-system)
27. [Advanced Combat Mechanics](#27-advanced-combat-mechanics)
    - [27.1 Animation Canceling](#271-animation-canceling)
    - [27.2 Skill Chaining/Combos](#272-skill-chainingcombos)
    - [27.3 Status Effect Management](#273-status-effect-management)
    - [27.4 Cast Time Optimization](#274-cast-time-optimization)
    - [27.5 ASPD Optimization](#275-aspd-optimization)
    - [27.6 After-Cast Delay Management](#276-after-cast-delay-management)
    - [27.7 Element Converter/Endow System](#277-element-converterendow-system)
    - [27.8 Perfect Dodge Mechanics](#278-perfect-dodge-mechanics)
28. [PvP/WoE Systems](#28-pvpwoe-systems)
    - [28.1 War of Emperium Logistics](#281-war-of-emperium-logistics)
    - [28.2 Battlegrounds System](#282-battlegrounds-system)
    - [28.3 Castle Siege Strategies](#283-castle-siege-strategies)
    - [28.4 Guild vs Guild Tactics](#284-guild-vs-guild-tactics)
    - [28.5 PvP Target Prioritization](#285-pvp-target-prioritization)
29. [Human Mimicry & Anti-Detection](#29-human-mimicry--anti-detection)
    - [29.1 Movement Pattern Humanization](#291-movement-pattern-humanization)
    - [29.2 Chat Pattern Intelligence](#292-chat-pattern-intelligence)
    - [29.3 Response Timing Variation](#293-response-timing-variation)
    - [29.4 Break/AFK Pattern System](#294-breakafk-pattern-system)
    - [29.5 Mistake Injection Engine](#295-mistake-injection-engine)
    - [29.6 Attention Drift Simulation](#296-attention-drift-simulation)
30. [Environmental Systems](#30-environmental-systems)
    - [30.1 Weather Effect Handling](#301-weather-effect-handling)
    - [30.2 Map Hazard Detection](#302-map-hazard-detection)
    - [30.3 Spawn Point Optimization](#303-spawn-point-optimization)
    - [30.4 Hidden Passage Discovery](#304-hidden-passage-discovery)
    - [30.5 Terrain Advantage Usage](#305-terrain-advantage-usage)
31. [Economy Deep Dive](#31-economy-deep-dive)
    - [31.1 Market Analysis Algorithms](#311-market-analysis-algorithms)
    - [31.2 Price Arbitrage Detection](#312-price-arbitrage-detection)
    - [31.3 Vending Optimization](#313-vending-optimization)
    - [31.4 Investment Timing Intelligence](#314-investment-timing-intelligence)
    - [31.5 Buying Store Optimization](#315-buying-store-optimization)
32. [Time-Sensitive Mechanics](#32-time-sensitive-mechanics)
    - [32.1 Server Time Synchronization](#321-server-time-synchronization)
    - [32.2 Day/Night Cycle Awareness](#322-daynight-cycle-awareness)
    - [32.3 Event Schedule Tracking](#323-event-schedule-tracking)
    - [32.4 Double EXP Event Detection](#324-double-exp-event-detection)
33. [Job-Specific Mechanics](#33-job-specific-mechanics)
    - [33.1 Bard/Dancer Ensemble Skills](#331-barddancer-ensemble-skills)
    - [33.2 Super Novice Mechanics](#332-super-novice-mechanics)
    - [33.3 Taekwon Ranking System](#333-taekwon-ranking-system)
    - [33.4 Star Gladiator Hatred System](#334-star-gladiator-hatred-system)
    - [33.5 Soul Linker Spirit Mechanics](#335-soul-linker-spirit-mechanics)
    - [33.6 Ninja/Gunslinger Ammo Management](#336-ninjagunslinger-ammo-management)
    - [33.7 Mechanic Mado Gear Management](#337-mechanic-mado-gear-management)
    - [33.8 Royal Guard Devotion Mechanics](#338-royal-guard-devotion-mechanics)
    - [33.9 Warlock Spellbook System](#339-warlock-spellbook-system)
    - [33.10 Genetic Plant/Bomb Mechanics](#3310-genetic-plantbomb-mechanics)
34. [Mini-Games](#34-mini-games)
    - [34.1 Event Participation](#341-event-participation)
35. [Advanced Navigation](#35-advanced-navigation)
    - [35.1 Safe Zone Mapping](#351-safe-zone-mapping)
    - [35.2 Mob Train Detection](#352-mob-train-detection)
    - [35.3 Line-of-Sight Tactics](#353-line-of-sight-tactics)
36. [Hidden Patterns & Meta](#36-hidden-patterns--meta)
    - [36.1 Server Tick Awareness](#361-server-tick-awareness)
    - [36.2 Experience Chain Maintenance](#362-experience-chain-maintenance)
    - [36.3 Monster AI Pattern Learning](#363-monster-ai-pattern-learning)
- [Appendix A: Complete Feature Matrix](#appendix-a-complete-feature-matrix)
- [Appendix B: Backend Capabilities Matrix](#appendix-b-backend-capabilities-matrix)
- [Appendix C: Hook Reference](#appendix-c-hook-reference)
- [Appendix D: Data Schema Reference](#appendix-d-data-schema-reference)
- [Appendix E: Priority Matrix for 154 Missing Mechanics](#appendix-e-priority-matrix-for-154-missing-mechanics)

---

## 1. Executive Summary

The **God-Tier Ragnarok Online AI** is a next-generation intelligent bot framework designed to transcend the limitations of traditional automation scripts. Built as an extension layer on top of OpenKore, this system introduces advanced cognitive capabilities including adaptive learning, multi-tier memory, predictive decision-making, and human-like behavioral patterns.

### Key Highlights

| Aspect | Description |
|--------|-------------|
| **Foundation** | OpenKore's mature, battle-tested Perl codebase |
| **Architecture** | Sidecar pattern with ZeroMQ IPC for non-blocking AI operations |
| **Intelligence** | 17+ cognitive features across combat, social, and strategic domains |
| **Backends** | Flexible compute options: CPU, GPU, ML models, or LLM APIs |
| **Memory** | Three-tier memory system: Working, Session, and Persistent |
| **Security** | Built-in anti-detection, privacy protection, and secure key management |

### Value Proposition

Traditional bots operate on rigid, predictable rules that experienced GMs and players can easily identify. God-Tier AI introduces:

- **Adaptive Intelligence**: Learns and evolves from gameplay experience
- **Human-like Behavior**: Randomized timing, natural movement patterns, and contextual responses
- **Strategic Depth**: Long-term planning, economic optimization, and social interaction
- **Stealth Operation**: Anti-detection measures that make the bot indistinguishable from human players

This specification serves as the definitive guide for understanding, configuring, and extending the God-Tier AI system.

---

## 2. Quick Start Guide

Get up and running with God-Tier AI in minutes.

### 2.1 Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Python | 3.10+ | 3.11+ recommended |
| Perl | 5.x | For OpenKore |
| **Docker Desktop** | Latest | **Required for Windows** - runs DragonFlyDB and OpenMemory |
| DragonFlyDB | Latest | Session storage (Redis-compatible) |
| SQLite3 | Built-in | Persistent memory |
| Git | Latest | For cloning repositories |

### 2.2 Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/godtier-ai.git
cd godtier-ai

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Start DragonFlyDB (multi-threaded, 25x faster than Redis)
docker run --network=host --ulimit memlock=-1 \
  docker.dragonflydb.io/dragonflydb/dragonfly \
  --snapshot_cron="*/5 * * * *"

# 4. Start OpenMemory (choose one method):

# Option A: Docker (Recommended for Windows)
docker run -d --name openmemory \
  -p 8080:8080 \
  -v openmemory-data:/app/data \
  -e EMBEDDING_PROVIDER=synthetic \
  openmemory/server:latest

# Option B: From Source (Linux/macOS)
cd AI-MMORPG-OpenMemory && npm install && npm start

# 5. Configure the AI
cp config/godtier.example.yaml config/godtier.yaml
# Edit config/godtier.yaml with your settings

# 6. Run the AI sidecar
python main.py --config config/godtier.yaml

# 7. Start OpenKore with the bridge plugin
cd /path/to/openkore
perl openkore.pl
```

### 2.3 Minimal Configuration

A working minimal configuration to get started:

```yaml
# config/godtier.yaml - Minimal working configuration
general:
  enabled: true
  log_level: info
  tick_rate_ms: 100

backend:
  primary: cpu
  fallback_chain: []

memory:
  working:
    enabled: true
    max_entries: 1000
  
  session:
    backend: dragonfly
    dragonfly:
      host: localhost
      port: 6379
      persistence:
        enabled: true
        cron: "*/5 * * * *"
        dbfilename: "dump-{timestamp}"
  
  persistent:
    backend: sqlite
    sqlite_path: "./data/memory.db"

behaviors:
  combat:
    enabled: true
    role: auto_detect
    aggression: 0.5
  
  survival:
    enabled: true
    retreat_threshold: 0.3

anti_detection:
  enabled: true
  paranoia_level: medium
```

### 2.4 Windows Quick Start

For Windows users, we recommend using Docker to run all dependencies:

1. **Install Docker Desktop:**
   - Download from [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
   - Ensure WSL2 backend is enabled during installation

2. **Start Docker Desktop:**
   - Launch Docker Desktop from Start Menu
   - Wait for the Docker engine to start (icon turns green)

3. **Run the complete stack:**
   ```powershell
   # Create a docker-compose.yml file (see Section 4.2 for full example)
   # Then run:
   docker-compose up -d
   ```

4. **Verify services are running:**
   ```powershell
   docker ps
   ```
   You should see `godtier-dragonfly` and `godtier-openmemory` containers running.

5. **Configure and run the AI:**
   ```powershell
   copy config\godtier.example.yaml config\godtier.yaml
   # Edit config\godtier.yaml with your settings
   python main.py --config config\godtier.yaml
   ```

---

## 3. Introduction

### 3.1 What is God-Tier AI?

God-Tier AI represents a paradigm shift in game automation—from rule-based scripting to cognitive-behavioral simulation. Rather than following a fixed decision tree, the system models complex human-like intelligence through:

```
Traditional Bot                    God-Tier AI
─────────────────                  ────────────────
IF monster nearby                  Evaluate context
  → Attack                         → Consider HP, MP, threats
ELSE                               → Assess risk/reward
  → Wander randomly                → Check historical patterns
                                   → Make probabilistic decision
                                   → Execute with human-like timing
```

The system achieves this through a **sidecar architecture** where the core decision-making happens in a Python-based AI engine that communicates with OpenKore via ZeroMQ inter-process communication (IPC). This design allows:

1. **Non-blocking operations**: AI computations don't freeze the game client
2. **Language flexibility**: Complex ML/LLM operations in Python's rich ecosystem
3. **Clean separation**: OpenKore handles game protocol; sidecar handles intelligence
4. **Easy upgrades**: AI improvements don't require OpenKore modifications

### 3.2 Why OpenKore as Foundation?

OpenKore is the natural choice for building advanced Ragnarok Online automation:

| Factor | Benefit |
|--------|---------|
| **Maturity** | 15+ years of development, stable codebase |
| **Protocol Support** | Comprehensive packet handling for all RO versions |
| **Plugin Architecture** | Clean hook system for non-invasive extensions |
| **Community** | Active maintenance and documentation |
| **Open Source** | Full visibility and customization capability |

#### OpenKore Architecture Overview

```
openkore.pl (Entry Point)
    │
    ├── AI::CoreLogic.pm ─────── Main AI loop (iterate())
    │   ├── AI::Attack.pm ────── Combat decisions
    │   ├── AI::Route.pm ─────── Pathfinding
    │   └── AI::Skill.pm ─────── Skill usage
    │
    ├── Actor.pm ─────────────── Base actor class
    │   ├── Actor::Player.pm ── Player entities
    │   ├── Actor::Monster.pm ─ Monster entities
    │   └── Actor::NPC.pm ───── NPC entities
    │
    ├── Globals.pm ───────────── Shared state
    ├── TaskManager.pm ───────── Scheduled operations
    └── Plugins.pm ───────────── Hook system
```

### 3.3 Target Audience

This specification is designed for:

| Audience | Use Case |
|----------|----------|
| **Bot Operators** | Configuring and running the AI system |
| **Plugin Developers** | Creating custom behaviors and extensions |
| **System Integrators** | Deploying infrastructure (LLM APIs, databases) |
| **Contributors** | Understanding architecture for contributions |
| **Server Admins** | Evaluating detection surface and countermeasures |

#### Prerequisites

- Familiarity with OpenKore configuration
- Basic understanding of YAML configuration files
- (For developers) Python 3.10+ and Perl 5.x knowledge
- (For LLM mode) API credentials for chosen provider

---

## 4. Core Intelligence Features

The God-Tier AI implements 15+ core intelligence features that work together to create human-like gameplay. Each feature is designed to address specific limitations of traditional bots.

### 4.1 Adaptive Behavior

**What it does:** Dynamically adjusts bot behavior based on environmental conditions, performance metrics, and learned patterns rather than following static rules.

**Why it matters:** Traditional bots are predictable—they always attack the same way, always use skills in the same order, always follow the same routes. This predictability makes them easy to detect. Adaptive behavior ensures the bot responds uniquely to each situation.

**How it works:**

```mermaid
flowchart LR
    subgraph Input
        A[Game State] --> D[Adaptation Engine]
        B[Performance Metrics] --> D
        C[Historical Patterns] --> D
    end
    
    subgraph Processing
        D --> E{Evaluate Context}
        E --> F[Adjust Parameters]
        F --> G[Weight Behaviors]
    end
    
    subgraph Output
        G --> H[Modified Decision]
    end
```

The adaptation engine continuously monitors:

- **Combat efficiency**: Kill speed, damage taken, resource usage
- **Environmental factors**: Player density, monster spawns, time of day
- **Performance trends**: Success rates over time, near-death experiences

**Configuration options:**

```yaml
behaviors:
  adaptive:
    enabled: true
    learning_rate: 0.1        # How quickly to adapt (0.0-1.0)
    stability_threshold: 0.7  # Minimum confidence for changes
    evaluation_window: 300    # Seconds of data to consider
    factors:
      combat_efficiency: 0.4
      survival_rate: 0.3
      resource_optimization: 0.3
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Basic | Rule-based adaptation |
| GPU | Full | Neural adaptation networks |
| ML | Full | Reinforcement learning adaptation |
| LLM | Full | Context-aware reasoning |

---

### 4.2 Memory Systems (Long & Short Term)

**What it does:** Implements a three-tier memory architecture that mirrors human cognitive systems, allowing the bot to remember, learn, and apply past experiences.

**Why it matters:** Human players remember where they died, which monsters are dangerous, and which routes are efficient. Traditional bots have no memory—every session starts from zero. Memory systems enable contextual decision-making based on accumulated experience.

**How it works:**

```
┌─────────────────────────────────────────────────────────────────┐
│                    THREE-TIER MEMORY SYSTEM                     │
├─────────────────┬─────────────────┬─────────────────────────────┤
│  WORKING MEMORY │  SESSION MEMORY │     PERSISTENT MEMORY       │
│   (RAM-based)   │  (DragonFlyDB)  │       (SQLite/DB)           │
├─────────────────┼─────────────────┼─────────────────────────────┤
│ TTL: 5-30 sec   │ TTL: Session    │ TTL: Permanent              │
├─────────────────┼─────────────────┼─────────────────────────────┤
│ • Current target│ • Kill patterns │ • Map knowledge             │
│ • Active buffs  │ • Path efficiency│ • Player reputation        │
│ • Cooldowns     │ • Threat history │ • Long-term statistics     │
│ • Combat state  │ • Price history  │ • Learned strategies       │
└─────────────────┴─────────────────┴─────────────────────────────┘
```

> **Note:** DragonFlyDB is used instead of Redis for session memory. DragonFlyDB is multi-threaded (unlike single-threaded Redis) with 25x higher throughput, full Redis API compatibility, and drop-in replacement capability.

**Memory consolidation process:**

1. **Immediate capture**: All events written to working memory
2. **Pattern detection**: Session memory identifies recurring patterns
3. **Consolidation**: Significant patterns promoted to persistent storage
4. **Recall**: Decision engine queries all tiers for relevant context

**Configuration options:**

```yaml
memory:
  working:
    max_entries: 1000
    default_ttl: 10        # seconds
    combat_ttl: 5          # faster expiry for combat data
  
  session:
    backend: dragonfly     # dragonfly (recommended), memory, or file
    dragonfly:
      host: localhost
      port: 6379
      persistence:
        enabled: true
        cron: "*/5 * * * *"
        dbfilename: "dump-{timestamp}"
    max_patterns: 5000
  
  persistent:
    backend: sqlite        # sqlite or postgresql
    db_path: "./data/memory.db"
    consolidation_interval: 300  # seconds
    retention_days: 90
```

**DragonFlyDB deployment:**

```bash
# Docker deployment (recommended)
docker run --network=host --ulimit memlock=-1 \
  docker.dragonflydb.io/dragonflydb/dragonfly \
  --snapshot_cron="*/5 * * * *"

# DragonFlyDB advantages over Redis:
# - Multi-threaded (Redis is single-threaded)
# - 25x higher throughput
# - Full Redis API compatibility (redis-py and ioredis work as-is)
# - Drop-in replacement, no code changes needed
```

**Complete Stack with Docker Compose:**

For a production-ready setup with both DragonFlyDB and OpenMemory, use this Docker Compose configuration:

```yaml
# docker-compose.yml - Complete God-Tier AI Stack
version: '3.8'

services:
  dragonfly:
    image: docker.dragonflydb.io/dragonflydb/dragonfly
    container_name: godtier-dragonfly
    ulimits:
      memlock: -1
    ports:
      - "6379:6379"
    volumes:
      - dragonfly-data:/data
    command: >
      --snapshot_cron="*/5 * * * *"
      --dbfilename=dump-{timestamp}
    restart: unless-stopped

  openmemory:
    image: openmemory/server:latest
    container_name: godtier-openmemory
    ports:
      - "8080:8080"
    volumes:
      - openmemory-data:/app/data
    environment:
      - EMBEDDING_PROVIDER=synthetic
      - DRAGONFLY_HOST=dragonfly
      - DRAGONFLY_PORT=6379
    depends_on:
      - dragonfly
    restart: unless-stopped

volumes:
  dragonfly-data:
  openmemory-data:
```

**Usage:**

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | All memory operations supported |
| GPU | Full | Accelerated pattern matching |
| ML | Full | Neural memory retrieval |
| LLM | Full | Semantic memory queries |

---

### 4.3 OpenMemory SDK Integration

**What it does:** Integrates with OpenMemory for advanced cognitive memory architecture with multi-sector organization, temporal graphs, and semantic search capabilities.

**Why it matters:** OpenMemory provides a sophisticated memory system that mirrors human cognitive processes, enabling the AI to store, retrieve, and reason about memories based on their type, importance, and temporal relationships.

**Multi-Sector Cognitive Architecture:**

The OpenMemory system organizes memories into 5 specialized sectors:

| Sector | Type | Decay Rate | Weight | Use Case |
|--------|------|------------|--------|----------|
| **Episodic** | Events | 0.015 | 1.3 | Player interactions, quest events, combat encounters |
| **Semantic** | Facts | 0.005 | 1.0 | Game knowledge, player preferences, world rules |
| **Procedural** | How-to | 0.008 | 1.2 | Learned behaviors, combat patterns, skill rotations |
| **Emotional** | Sentiment | 0.020 | 1.4 | Feelings about players, relationship states |
| **Reflective** | Meta | 0.001 | 0.9 | Self-analysis, strategy evaluation, learning insights |

**Temporal Graph for Time-Aware Facts:**

OpenMemory maintains a temporal graph to track how facts change over time:

```
┌────────────────────────────────────────────────────────────────┐
│                     TEMPORAL GRAPH                              │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Guild Leadership Changes:                                     │
│   ├── [2024-01] Player_A → GuildMaster of "Elite"              │
│   ├── [2024-06] Player_B → GuildMaster of "Elite"              │
│   └── [Current] Player_C → GuildMaster of "Elite"              │
│                                                                  │
│   Territory Control History:                                    │
│   ├── Castle_01: Guild_A → Guild_B → Guild_A                   │
│   └── Castle_02: Guild_C → Guild_C → Guild_D                   │
│                                                                  │
│   Player Relationship Evolution:                                │
│   ├── Player_X: Stranger → Acquaintance → Friend → Enemy       │
│   └── Player_Y: Enemy → Neutral → Ally                         │
│                                                                  │
│   Economic State Changes:                                       │
│   ├── Item_123 Price: 10k → 15k → 12k → 18k                    │
│   └── Market Trend: Stable → Bull → Correction                 │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Memory API Endpoints:**

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/memory/add` | POST | Store new memories with metadata |
| `/memory/query` | POST | Semantic search across memories |
| `/memory/reinforce` | POST | Boost salience of important memories |

All endpoints support user isolation via the `user_id` parameter.

**Embedding Providers:**

| Provider | Description | Cost |
|----------|-------------|------|
| OpenAI | High-quality embeddings | $$$ |
| Gemini | Google's embedding model | $$ |
| Ollama | Local/self-hosted | Free |
| Synthetic | Zero-cost synthetic embeddings | Free |

**Memory Compression Algorithms:**

- **Semantic**: Preserves meaning while reducing size
- **Syntactic**: Removes redundant linguistic structures
- **Aggressive**: Maximum compression for storage efficiency

**Python Integration Example:**

```python
from openmemory import OpenMemory

# Initialize OpenMemory client
memory = OpenMemory(base_url='http://localhost:8080')

# Store player interaction as episodic memory
memory.add(
    content=f"Player {player_id} said: {message}",
    metadata={
        'player_id': player_id,
        'location': map_name,
        'sector': 'episodic',
        'timestamp': time.time()
    },
    user_id=player_id  # User isolation
)

# Store learned combat pattern as procedural memory
memory.add(
    content=f"Effective skill rotation against {monster}: {skill_sequence}",
    metadata={
        'monster': monster_name,
        'success_rate': 0.85,
        'sector': 'procedural'
    },
    user_id='global'
)

# Retrieve relevant context for conversation
results = memory.query(
    query="recent conversation with this player",
    k=10,  # Return top 10 matches
    filters={'user_id': player_id, 'sector': 'episodic'}
)

# Reinforce important memory
memory.reinforce(
    memory_id=important_memory_id,
    boost_factor=1.5
)
```

**Configuration:**

```yaml
openmemory:
  enabled: true
  base_url: "http://localhost:8080"
  
  sectors:
    episodic:
      enabled: true
      decay: 0.015
      weight: 1.3
    semantic:
      enabled: true
      decay: 0.005
      weight: 1.0
    procedural:
      enabled: true
      decay: 0.008
      weight: 1.2
    emotional:
      enabled: true
      decay: 0.020
      weight: 1.4
    reflective:
      enabled: true
      decay: 0.001
      weight: 0.9
  
  embedding:
    provider: ollama     # openai, gemini, ollama, synthetic
    model: "nomic-embed-text"
  
  compression:
    algorithm: semantic  # semantic, syntactic, aggressive
    threshold: 0.8
  
  temporal_graph:
    enabled: true
    track_changes: true
    history_depth: 100   # Number of historical states to keep
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | All memory operations supported |
| GPU | Full | Accelerated embedding generation |
| ML | Full | Enhanced pattern recognition |
| LLM | Full | Semantic memory queries |

---

### 4.4 Predictive Decision Making

**What it does:** Anticipates future game states and makes proactive decisions rather than purely reactive ones.

**Why it matters:** Human players look ahead—they see a monster's HP and know when to prepare the finishing skill, they notice aggro patterns and position accordingly. Predictive AI enables this foresight.

**How it works:**

```mermaid
flowchart TD
    A[Current State] --> B[State Projection]
    B --> C[Future State t+1]
    B --> D[Future State t+2]
    B --> E[Future State t+n]
    
    C --> F[Evaluate Outcomes]
    D --> F
    E --> F
    
    F --> G{Best Path?}
    G --> H[Execute Optimal Action]
```

**Prediction domains:**

| Domain | Predictions | Use Case |
|--------|-------------|----------|
| **Combat** | Monster death timing, skill cooldowns | Skill chaining optimization |
| **Movement** | Spawn patterns, player paths | Positioning, collision avoidance |
| **Resource** | HP/SP depletion rates | Preemptive healing/potions |
| **Threat** | Incoming damage, mob trains | Defensive preparation |

**Configuration options:**

```yaml
prediction:
  enabled: true
  lookahead_steps: 3       # How many actions to predict ahead
  confidence_threshold: 0.6 # Minimum confidence to act on prediction
  
  domains:
    combat:
      enabled: true
      model: "neural"       # neural, statistical, or heuristic
    movement:
      enabled: true
      model: "statistical"
    resource:
      enabled: true
      model: "statistical"
    threat:
      enabled: true
      model: "neural"
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Limited | Simple statistical predictions |
| GPU | Full | Neural network predictions |
| ML | Full | Trained prediction models |
| LLM | Partial | Reasoning-based, higher latency |

---

### 4.5 Behavior Randomization

**What it does:** Introduces controlled randomness into all actions to simulate human imperfection and unpredictability.

**Why it matters:** Humans are never perfectly consistent—they have reaction time variance, they sometimes make suboptimal choices, they hesitate. Perfect consistency is a telltale sign of automation.

**How it works:**

```
Action Request → Randomization Layer → Humanized Action

Components:
├── Timing Variance
│   └── Base delay ± random offset (Gaussian distribution)
├── Decision Jitter
│   └── Sometimes choose 2nd-best option (weighted probability)
├── Movement Variation
│   └── Bezier curves instead of straight lines
└── Skill Order Shuffle
    └── Randomize equivalent priority skills
```

**Randomization parameters:**

| Parameter | Description | Default Range |
|-----------|-------------|---------------|
| `timing_variance` | Reaction time spread | ±150ms |
| `decision_noise` | Probability of suboptimal choice | 5-15% |
| `path_deviation` | Movement path randomness | 0-2 tiles |
| `skill_shuffle` | Reorder equal-priority skills | Enabled |

**Configuration options:**

```yaml
humanization:
  randomization:
    enabled: true
    seed: null              # null for random, int for reproducible
    
    timing:
      base_delay_ms: 200
      variance_ms: 150
      distribution: gaussian  # gaussian, uniform, or poisson
    
    decisions:
      noise_percentage: 10
      allow_suboptimal: true
    
    movement:
      use_bezier_curves: true
      deviation_tiles: 1.5
      pause_probability: 0.05  # Random brief pauses
    
    combat:
      shuffle_equal_priority: true
      target_switch_variance: 500  # ms
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Core feature, always available |
| GPU | Full | Supported |
| ML | Full | Learned randomization patterns |
| LLM | Full | Supported |

---

### 4.6 Context Awareness

**What it does:** Maintains a comprehensive understanding of the current game situation including nearby entities, environmental factors, and social context.

**Why it matters:** Decisions should never be made in isolation. A human player automatically considers "Is there a GM watching?", "Are other players nearby?", "Am I in a safe zone?". Context awareness enables this holistic perception.

**How it works:**

```
┌────────────────────────────────────────────────────────────────┐
│                     CONTEXT AWARENESS ENGINE                    │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│   │   SPATIAL   │  │   SOCIAL    │  │  TEMPORAL   │            │
│   │   CONTEXT   │  │   CONTEXT   │  │   CONTEXT   │            │
│   ├─────────────┤  ├─────────────┤  ├─────────────┤            │
│   │ • Position  │  │ • Players   │  │ • Time of   │            │
│   │ • Map type  │  │ • Party     │  │   day       │            │
│   │ • Terrain   │  │ • Guild     │  │ • Session   │            │
│   │ • Spawns    │  │ • Enemies   │  │   duration  │            │
│   │ • Portals   │  │ • GMs       │  │ • Events    │            │
│   └─────────────┘  └─────────────┘  └─────────────┘            │
│           │               │               │                     │
│           └───────────────┼───────────────┘                     │
│                           ▼                                      │
│                  ┌─────────────────┐                            │
│                  │  UNIFIED WORLD  │                            │
│                  │      MODEL      │                            │
│                  └─────────────────┘                            │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Context categories:**

| Category | Information Tracked | Decision Impact |
|----------|---------------------|-----------------|
| **Spatial** | Map, coordinates, terrain | Navigation, combat positioning |
| **Entity** | Monsters, players, NPCs | Target selection, threat assessment |
| **Social** | Party, guild, relationships | Cooperation, competition |
| **Temporal** | Time, events, cooldowns | Timing, event participation |
| **Economic** | Prices, inventory, trade | Resource management |
| **Risk** | Threats, GM presence, PK | Stealth mode, defensive actions |

**Configuration options:**

```yaml
context:
  update_interval_ms: 100
  
  spatial:
    track_terrain: true
    portal_awareness: true
    spawn_monitoring: true
  
  entity:
    player_tracking_range: 20  # tiles
    monster_tracking_range: 15
    npc_awareness: true
  
  social:
    party_coordination: true
    guild_awareness: true
    enemy_list: []            # Player names to avoid/target
  
  risk:
    gm_detection: true
    pk_awareness: true
    crowd_threshold: 10       # Players before "crowded" state
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Core feature |
| GPU | Full | Accelerated entity processing |
| ML | Full | Pattern recognition |
| LLM | Full | Semantic understanding |

---

### 4.7 Self-Learning Capabilities

**What it does:** Continuously improves performance by learning from gameplay experiences without requiring manual configuration updates.

**Why it matters:** The game environment is dynamic—new content, changing meta, evolving GM detection methods. Self-learning enables the AI to adapt autonomously, staying effective over time.

**How it works:**

```mermaid
flowchart LR
    subgraph Experience Collection
        A[Action] --> B[Outcome]
        B --> C[Reward Signal]
    end
    
    subgraph Learning Pipeline
        C --> D[Experience Buffer]
        D --> E[Training Batch]
        E --> F[Model Update]
    end
    
    subgraph Deployment
        F --> G[Policy Update]
        G --> H[Improved Decisions]
        H --> A
    end
```

**Learning domains:**

| Domain | Learning Target | Method |
|--------|-----------------|--------|
| **Combat** | Optimal skill rotations, target priority | Reinforcement learning |
| **Navigation** | Efficient paths, safe zones | Path optimization |
| **Economy** | Trading strategies, price prediction | Statistical learning |
| **Survival** | Threat response, resource management | Experience replay |
| **Stealth** | Detection avoidance patterns | Adversarial learning |

**Training Data Requirements & Convergence:**

| Metric | Value | Notes |
|--------|-------|-------|
| **Basic Competency** | ~100,000 episodes | Functional but not optimal |
| **Intermediate Skill** | ~500,000 episodes | Good performance in most situations |
| **Mastery Level** | 1,000,000+ episodes | Near-optimal behavior |
| **Convergence Time** | 2-4 weeks | With consistent gameplay, varies by complexity |

**Initial Exploration Strategy:**

- Start with 10-20% random actions (ε-greedy exploration)
- Gradually reduce exploration rate as learning converges
- Maintain minimum 1-2% exploration for adaptation to changes

**Ban Risk Mitigation During Training:**

1. **Train in safe zones first** - Practice in low-risk areas
2. **Use offline replay** - Learn from recorded human gameplay
3. **Gradual deployment** - Start with conservative settings
4. **Checkpoint frequently** - Save model states for rollback

**Catastrophic Forgetting Prevention:**

- **Experience replay buffer** - Maintain diverse training samples
- **Periodic policy checkpoints** - Save known-good strategies
- **Elastic weight consolidation** - Protect important learned weights
- **Multi-task learning** - Train on multiple scenarios simultaneously

**Learning safeguards:**

- **Rollback capability**: Revert to previous model if performance degrades
- **Bounded exploration**: Limit how far from known-good strategies it explores
- **Human oversight**: Flag significant strategy changes for review

**Configuration options:**

```yaml
learning:
  enabled: true
  mode: online            # online, offline, or hybrid
  
  experience:
    buffer_size: 100000
    prioritized_replay: true
    priority_alpha: 0.6
  
  training:
    batch_size: 64
    learning_rate: 0.001
    update_frequency: 1000  # steps
    
  exploration:
    initial_epsilon: 0.15   # 15% random actions initially
    final_epsilon: 0.02     # 2% minimum exploration
    decay_steps: 500000     # Steps to decay from initial to final
    
  domains:
    combat:
      enabled: true
      reward_shaping:
        kill: 1.0
        damage_dealt: 0.1
        damage_taken: -0.2
        death: -5.0
    
    navigation:
      enabled: true
      optimize_for: efficiency  # efficiency, safety, or balanced
    
    economy:
      enabled: false  # Requires market data
  
  safeguards:
    performance_threshold: 0.8
    rollback_enabled: true
    exploration_limit: 0.2
    checkpoint_frequency: 10000  # Steps between checkpoints
    
  ban_risk_mitigation:
    safe_zone_training: true
    offline_replay_enabled: true
    conservative_start: true
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Limited | Basic statistical learning |
| GPU | Full | Neural network training |
| ML | Full | Primary learning backend |
| LLM | Partial | Can guide learning, not primary |

---

### 4.8 Consciousness Simulation

**What it does:** Simulates aspects of human consciousness including attention focus, internal monologue, and decision justification.

**Why it matters:** Human behavior stems from conscious thought processes—we focus on things, we consider options, we sometimes talk to ourselves. Simulating these processes creates more authentic behavioral patterns.

**How it works:**

```
┌────────────────────────────────────────────────────────────────┐
│                   CONSCIOUSNESS SIMULATION                      │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  ATTENTION SYSTEM                       │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │    │
│  │  │ Primary │  │Secondary│  │ Ambient │  │ Ignored │   │    │
│  │  │  Focus  │  │  Focus  │  │Awareness│  │         │   │    │
│  │  │   20%   │  │   30%   │  │   40%   │  │   10%   │   │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │               INTERNAL MONOLOGUE                        │    │
│  │  "That Poring is almost dead... should finish it..."   │    │
│  │  "Low on HP, need to heal soon..."                     │    │
│  │  "Player approaching, act natural..."                  │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              DECISION JUSTIFICATION                     │    │
│  │  Action: Use Red Potion                                 │    │
│  │  Reason: HP at 45%, threshold is 50%                   │    │
│  │  Confidence: 0.85                                       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Consciousness components:**

| Component | Function | Benefit |
|-----------|----------|---------|
| **Attention** | Focus allocation across entities/tasks | Natural target switching |
| **Monologue** | Internal reasoning verbalization | Debuggable decision process |
| **Justification** | Explain why decisions were made | Transparency, learning signal |
| **Emotion simulation** | Simulated mood states | Behavioral variety |

**Configuration options:**

```yaml
consciousness:
  enabled: true
  
  attention:
    primary_focus_weight: 0.5
    attention_switch_probability: 0.1
    distraction_susceptibility: 0.05
  
  monologue:
    enabled: true           # Generate internal thoughts
    log_to_file: false      # Save for debugging
    language: english
  
  emotions:
    enabled: true
    states:
      - calm
      - excited
      - frustrated
      - cautious
    transition_probability: 0.01
  
  justification:
    enabled: true
    detail_level: medium    # low, medium, high
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Basic | Simple attention model |
| GPU | Full | Neural attention networks |
| ML | Full | Learned attention patterns |
| LLM | Full | Natural language monologue |

---

### 4.9 Heuristic Strategy System

**What it does:** Implements a library of strategic heuristics (rules of thumb) that guide high-level decision-making when exact optimization is impractical.

**Why it matters:** Not every decision can be optimized mathematically—sometimes you need common sense rules like "don't attack monsters near GMs" or "retreat when outnumbered". Heuristics provide this strategic wisdom.

**How it works:**

```yaml
# Example heuristic rules
heuristics:
  - name: "retreat_when_outnumbered"
    condition: "aggressive_monsters > 3"
    action: "kite_or_flee"
    priority: high
    
  - name: "conserve_sp_for_bosses"
    condition: "target_is_mvp and sp_percentage < 50"
    action: "use_normal_attacks"
    priority: medium
    
  - name: "avoid_player_conflict"
    condition: "player_nearby and not_in_guild"
    action: "change_hunting_area"
    priority: low
```

**Heuristic categories:**

| Category | Examples |
|----------|----------|
| **Combat** | Focus healers, kite dangerous mobs, save cooldowns |
| **Survival** | Retreat thresholds, safe zone routing, emergency teleport |
| **Economic** | Buy low sell high, inventory management, vendor timing |
| **Social** | Avoid conflicts, party behavior, GM response |
| **Strategic** | Map rotation, spawn camping, event participation |

**Configuration options:**

```yaml
heuristics:
  enabled: true
  
  priority_override: true    # Heuristics can override ML decisions
  confidence_threshold: 0.7  # When to defer to heuristics
  
  combat:
    - name: "focus_healers"
      enabled: true
      priority: 0.9
    - name: "kite_dangerous"
      enabled: true
      priority: 0.8
  
  survival:
    retreat_threshold: 0.3   # HP percentage
    emergency_teleport: true
    safe_zone_memory: true
  
  custom_rules:
    - condition: "map == 'prt_fild01' and hour > 22"
      action: "change_map"
      reason: "GM patrol hours"
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Primary heuristic execution |
| GPU | Full | Supported |
| ML | Full | Learned heuristic weights |
| LLM | Full | Natural language rule interpretation |

---

### 4.10 Environmental Awareness

**What it does:** Continuously monitors and understands the game environment including terrain, obstacles, spawn points, portals, and dynamic elements.

**Why it matters:** Efficient navigation and combat positioning require understanding the physical environment—where monsters spawn, where obstacles are, which paths are safe. Environmental awareness enables strategic positioning.

**How it works:**

```
┌────────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT MODEL                            │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   MAP: prt_fild01                                               │
│   ┌──────────────────────────────────────────────┐             │
│   │  . . . . . . . . # # . . . . . . . . . . .  │             │
│   │  . . S . . . . # # # # . . . . P . . . . .  │  Legend:    │
│   │  . . . . . . . # # # # . . . . . . . . . .  │  S = Spawn  │
│   │  . . . . . . . . # # . . . . . . . . . . .  │  P = Portal │
│   │  . . . . . . . . . . . . . . S . . . . . .  │  # = Block  │
│   │  . . P . . . . . . . . . . . . . . . . . .  │  @ = Player │
│   │  . . . . . . . @ . . . . . . . . . . . . .  │             │
│   │  . . . . . . . . . . . . . . . . . . . . .  │             │
│   └──────────────────────────────────────────────┘             │
│                                                                  │
│   Spawn Points: [(12,23), (45,67), (89,12)]                    │
│   Spawn Timer: Poring every 5-10 seconds                       │
│   Danger Zones: [(0-10, 0-10) - near portal]                   │
│   Optimal Path: A* with danger avoidance                       │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Environment components:**

| Component | Data Tracked | Use Case |
|-----------|--------------|----------|
| **Terrain** | Walkable tiles, obstacles | Pathfinding |
| **Spawns** | Monster spawn locations and rates | Farming optimization |
| **Portals** | Entry/exit points | Navigation |
| **NPCs** | Vendor, storage, quest NPCs | Service access |
| **Danger zones** | PK areas, high-level mobs | Avoidance |
| **Dynamic elements** | Other players, moving obstacles | Real-time adaptation |

**Configuration options:**

```yaml
environment:
  enabled: true
  
  terrain:
    cache_maps: true
    update_frequency: 1000  # ms
  
  spawns:
    track_spawn_points: true
    learn_spawn_timing: true
    prediction_enabled: true
  
  portals:
    auto_discover: true
    remember_destinations: true
  
  danger_zones:
    pk_map_awareness: true
    high_level_mob_radius: 10  # tiles
    
  dynamic:
    player_tracking: true
    obstacle_prediction: true
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Core feature |
| GPU | Full | Accelerated pathfinding |
| ML | Full | Spawn prediction |
| LLM | Partial | Environment reasoning |

---

### 4.11 Social-Interaction Mimicking

**What it does:** Enables natural, context-appropriate social interactions with other players and NPCs, mimicking authentic human communication patterns. Supports **two operating modes**: fast template-based responses and intelligent LLM-based generation.

**Why it matters:** Social interaction is where many bots fail detection. Canned responses, poor timing, and inappropriate reactions are obvious tells. Natural social behavior is essential for passing as human.

**How it works:**

```
┌─────────────────────────────────────────────────────────────────┐
│                SOCIAL INTERACTION SYSTEM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐   │
│  │   Message   │───▶│  Intent      │───▶│   Response      │   │
│  │   Parser    │    │  Classifier  │    │   Generator     │   │
│  └─────────────┘    └──────────────┘    └─────────────────┘   │
│         │                  │                     │             │
│         ▼                  ▼                     ▼             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐   │
│  │   Context   │    │  Sentiment   │    │    Typing       │   │
│  │   Memory    │    │  Analysis    │    │    Simulator    │   │
│  └─────────────┘    └──────────────┘    └─────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Dual Mode Architecture:**

| Mode | Speed | Intelligence | Cost | Use Case |
|------|-------|--------------|------|----------|
| **Template** | <10ms | Deterministic | Free | High-frequency responses |
| **LLM** | 500-2000ms | Contextual | API cost | Complex conversations |

#### Mode 1: Template-Based (Fast, Deterministic)

Template mode uses pre-defined responses with randomization for quick, predictable interactions:

```yaml
social_ai:
  mode: template  # or "llm"
  
  template_config:
    responses_file: "responses.yml"
    fallback_response: "Sorry, I'm busy right now"
    randomization: true
    
    response_pools:
      greetings:
        - "Hey!"
        - "Hi there"
        - "Yo"
        - "Hello :)"
      
      farewells:
        - "cya"
        - "bye"
        - "gtg bb"
        - "laterz"
      
      busy:
        - "srry busy atm"
        - "1 sec"
        - "in combat rn"
    
    intent_mapping:
      greeting: greetings
      farewell: farewells
      question: busy
      party_invite: busy
```

#### Mode 2: LLM-Based (Intelligent, Contextual)

LLM mode generates dynamic, context-aware responses using language models:

```yaml
social_ai:
  mode: llm
  
  llm_config:
    provider: openai  # or azure, deepseek, claude
    model: gpt-4o-mini
    
    custom_prompt: |
      You are roleplaying as a Ragnarok Online player character.
      Character name: {character_name}
      Character class: {job_class}
      Current level: {level}
      Personality: {personality}
      
      Current situation:
      - Map: {current_map}
      - Activity: {current_activity}
      - Nearby players: {nearby_players}
      
      Recent conversation with this player:
      {conversation_history}
      
      Respond naturally and in-character to: {message}
      
      Guidelines:
      - Use casual MMO speech (abbreviations, emoticons)
      - Stay in character
      - Be concise (1-2 sentences max)
      - Don't reveal you're a bot
    
    context_window: 20  # Messages to include in history
    temperature: 0.8
    max_tokens: 100
    
    memory_enabled: true
    memory_sectors: [episodic, emotional]
```

**Memory-Enhanced Responses:**

When memory is enabled, the system queries OpenMemory for relevant context:

```python
# Memory-enhanced social response flow
async def generate_social_response(player_id: str, message: str):
    # 1. Query conversation history from episodic memory
    history = await memory.query(
        query=f"conversation with player {player_id}",
        filters={'sector': 'episodic', 'player_id': player_id},
        k=10
    )
    
    # 2. Query emotional context (how do we feel about this player?)
    emotional_context = await memory.query(
        query=f"feelings about player {player_id}",
        filters={'sector': 'emotional', 'player_id': player_id},
        k=3
    )
    
    # 3. Generate response with full context
    response = await llm.generate(
        prompt=build_prompt(message, history, emotional_context)
    )
    
    # 4. Store new interaction in memory
    await memory.add(
        content=f"Player {player_id} said: {message}. I responded: {response}",
        metadata={'player_id': player_id, 'sector': 'episodic'}
    )
    
    return response
```

**Interaction types:**

| Type | Response Strategy | Timing |
|------|-------------------|--------|
| **Greeting** | Match formality level, use varied responses | 0.5-2s delay |
| **Question** | Answer if known, deflect naturally if not | 1-3s thinking |
| **Trade offer** | Evaluate, negotiate or decline politely | 2-5s consideration |
| **Party invite** | Check context, accept/decline appropriately | 1-2s response |
| **Guild chat** | Participate contextually, avoid overposting | Variable |
| **Hostile** | De-escalate or ignore based on situation | Immediate or delayed |

**Configuration options:**

```yaml
social:
  enabled: true
  mode: llm           # template or llm
  personality: friendly      # friendly, neutral, mysterious, aggressive
  
  persona:
    name: "MyCharacter"
    chattiness: 0.6           # 0-1, how often to initiate conversation
    response_style: casual    # casual, formal, roleplay
  
  response_timing:
    min_delay: 500            # ms before responding
    typing_speed: 200         # ms per character simulated typing
    thinking_delay: 1000      # additional delay for complex responses
  
  filters:
    ignore_patterns:
      - "WTS.*"              # Ignore shop spam
      - "^>.*"               # Ignore guild recruitment
    priority_users:
      - "FriendName"
      - "GuildLeader"
  
  limits:
    max_responses_per_minute: 10
    cooldown_after_flood: 60  # seconds
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Basic | Template responses only |
| GPU | Basic | Template responses only |
| ML | Partial | Learned response selection |
| LLM | Full | Natural language generation with memory |

---

### 4.12 Multi-Map Behavior Profiles

**What it does:** Maintains separate behavior configurations for different maps, automatically switching strategies based on location.

**Why it matters:** Different maps require different strategies—a farming map needs efficiency, a town needs stealth, a dungeon needs caution. Multi-map profiles enable location-appropriate behavior without manual switching.

**How it works:**

```
┌────────────────────────────────────────────────────────────────┐
│                    MAP PROFILE SYSTEM                           │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Current Map: prt_fild01                                       │
│   Active Profile: farming_aggressive                            │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                   PROFILE STACK                          │  │
│   │                                                          │  │
│   │   [3] Emergency Override (if GM detected)               │  │
│   │   [2] Map-Specific (prt_fild01 config)                  │  │
│   │   [1] Map-Type (field config)                           │  │
│   │   [0] Global Defaults                                    │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   Profile inheritance: lower layers provide defaults           │
│   Higher layers override specific settings                     │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Map type classifications:**

| Map Type | Strategy Focus | Example Maps |
|----------|----------------|--------------|
| **Towns** | Stealth, services | prontera, geffen, morroc |
| **Fields** | Farming, efficiency | prt_fild01, moc_fild07 |
| **Dungeons** | Survival, caution | prt_maze, gl_knt |
| **PvP** | Combat, aggression | pvp_y_1-1, guild maps |
| **Events** | Objectives, timing | event maps |

**Configuration options:**

```yaml
map_profiles:
  # Global defaults
  _default:
    combat_style: balanced
    retreat_threshold: 0.3
    loot_priority: high
  
  # Map type defaults
  _types:
    town:
      combat_enabled: false
      stealth_mode: high
      social_mode: minimal
    
    field:
      combat_enabled: true
      farming_mode: true
      social_mode: normal
    
    dungeon:
      combat_enabled: true
      survival_priority: high
      party_mode: cooperative
  
  # Specific map overrides
  prt_fild01:
    type: field
    strategy: farming
    monster_priorities:
      - Poring
      - Drops
      - Lunatic
    avoid_coords:
      - [100, 200, 120, 220]  # Busy farming spot
    
  prontera:
    type: town
    allowed_activities:
      - storage
      - vendor
      - repair
    avoid_hours: [14, 16]    # Peak GM hours
    
  gl_knt01:
    type: dungeon
    survival_priority: critical
    retreat_threshold: 0.5
    party_required: true
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Config-based switching |
| GPU | Full | Supported |
| ML | Full | Learned profile optimization |
| LLM | Full | Dynamic profile generation |

---

### 4.13 Role-Optimized Tactical AI

**What it does:** Implements specialized combat and support behaviors based on character class/role (DPS, Tank, Healer, Support).

**Why it matters:** Different classes play fundamentally differently—a Knight tanks, a Priest heals, a Wizard nukes. Role-optimized AI ensures the bot plays its class correctly and effectively.

**How it works:**

```
┌────────────────────────────────────────────────────────────────┐
│                    ROLE TACTICAL SYSTEM                         │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│   │     DPS     │  │    TANK     │  │   HEALER    │            │
│   ├─────────────┤  ├─────────────┤  ├─────────────┤            │
│   │ • Max damage│  │ • Hold aggro│  │ • Keep alive│            │
│   │ • Burst     │  │ • Mitigate  │  │ • Dispel    │            │
│   │   windows   │  │   damage    │  │ • Buff      │            │
│   │ • Kiting    │  │ • Position  │  │ • Resurrect │            │
│   │ • AoE vs ST │  │   control   │  │ • Mana mgmt │            │
│   └─────────────┘  └─────────────┘  └─────────────┘            │
│                                                                  │
│   ┌─────────────┐                                               │
│   │   SUPPORT   │   Role is auto-detected from skills/stats    │
│   ├─────────────┤   or can be manually specified               │
│   │ • Buffs     │                                               │
│   │ • Debuffs   │                                               │
│   │ • Control   │                                               │
│   │ • Utility   │                                               │
│   └─────────────┘                                               │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Role priorities:**

| Role | Primary Goals | Key Metrics |
|------|--------------|-------------|
| **DPS** | Maximize damage output | DPM, kill speed |
| **Tank** | Maintain aggro, survive | Aggro stability, mitigation |
| **Healer** | Keep party alive | Overhealing %, deaths prevented |
| **Support** | Buff/debuff management | Buff uptime, CC effectiveness |

**Class-specific behaviors:**

```yaml
# Example: Knight tank configuration
roles:
  tank:
    class_examples: [Knight, Crusader, Lord Knight]
    
    positioning:
      preferred_position: front
      facing: toward_enemies
      range_from_party: 3-5 tiles
    
    aggro:
      taunt_cooldown: 5s
      aggro_threshold: 0.8
      emergency_taunt: true
    
    skills:
      priority:
        - Provoke        # Aggro generation
        - Auto Guard     # Mitigation
        - Defending Aura # Party protection
    
    survival:
      self_heal_threshold: 0.4
      potion_threshold: 0.3
      retreat_threshold: 0.15
```

**Configuration options:**

```yaml
tactical:
  role: auto_detect      # auto_detect, dps, tank, healer, support
  
  dps:
    target_selection: lowest_hp   # lowest_hp, highest_threat, optimal_aoe
    burst_on_cooldown: true
    aoe_threshold: 3              # Mobs before using AoE
    resource_conservation: 0.2    # Keep 20% for emergencies
    
  tank:
    aggro_priority: maintain
    position_optimization: true
    defensive_cooldown_usage: intelligent
    
  healer:
    heal_priority:
      - self: 0.3              # Heal self below 30%
      - tank: 0.5              # Heal tank below 50%
      - party: 0.6             # Heal others below 60%
    pre_heal: true              # Predict damage and pre-cast
    dispel_priority: high
    
  support:
    buff_refresh_window: 30      # Seconds before expiry to refresh
    debuff_priority: boss > elite > normal
    utility_activation: contextual
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Rule-based role execution |
| GPU | Full | Optimized targeting |
| ML | Full | Learned optimal rotations |
| LLM | Partial | Strategy reasoning |

---

## 5. Fully Autonomous AI Capabilities

God-Tier AI is designed to operate as a **fully autonomous player**, capable of performing every action a human player can perform in Ragnarok Online without any intervention.

### Autonomous Capability Matrix

The following table documents ALL player actions the AI can autonomously perform:

#### Movement & Navigation

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Walking** | Move to any walkable coordinate | Pathfinding via A* algorithm |
| **Running** | Sprint movement when available | Automatic when safe |
| **Teleporting** | Use Fly Wing/Butterfly Wing | Emergency and routine teleport |
| **Warping** | Use Kafra/warp portals | Map transition handling |
| **Portal Navigation** | Enter dungeon/field portals | Portal detection and entry |
| **NPC Movement** | Navigate to specific NPCs | NPC coordinate database |

#### Combat Actions

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Basic Attack** | Standard weapon attacks | Target selection + attack command |
| **Skill Usage** | Cast any learned skill | Skill queue with cooldown tracking |
| **Target Selection** | Choose optimal targets | ML-based priority scoring |
| **Skill Combos** | Chain skills effectively | Combo sequence optimization |
| **Retreating** | Flee from dangerous situations | Threat assessment + escape routes |
| **Kiting** | Attack while moving | Distance management algorithm |
| **AoE Positioning** | Optimal position for area skills | Cluster detection + positioning |

#### Item Management

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Item Pickup** | Collect dropped items | Priority-based loot system |
| **Item Usage** | Use consumables/equipment | Context-aware item activation |
| **Equipment Change** | Swap gear situationally | Stat optimization engine |
| **Selling** | Sell items to NPCs | Value assessment + vendor interaction |
| **Buying** | Purchase from NPCs/vendors | Shopping list automation |
| **Storage** | Deposit/withdraw from Kafra | Inventory management rules |
| **Item Identification** | Use magnifier/identify skills | Unknown item handling |
| **Item Repair** | Repair equipment when needed | Durability monitoring |

#### Social Interaction

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Public Chat** | Respond to nearby messages | LLM/template response system |
| **Whisper** | Private message handling | Direct conversation mode |
| **Party Chat** | Coordinate with party members | Role-based communication |
| **Guild Chat** | Participate in guild discussions | Context-appropriate responses |
| **Trade** | Accept/initiate/decline trades | Trade policy enforcement |
| **Friend System** | Add/remove/manage friends | Social relationship tracking |
| **Emotes** | Express emotions appropriately | Context-sensitive emoting |
| **Blocking** | Block hostile/annoying players | Automatic harassment protection |

#### Quest & Objective Completion

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **NPC Dialogue** | Navigate conversation trees | Dialog state machine |
| **Quest Acceptance** | Accept available quests | Quest priority evaluation |
| **Objective Tracking** | Track progress on objectives | Quest state management |
| **Quest Turn-in** | Complete and submit quests | Reward collection automation |
| **Daily Quests** | Complete daily content | Schedule-based execution |
| **Event Participation** | Join time-limited events | Event detection + participation |

#### Economic Activities

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Vending** | Set up player shop | Price optimization + shop management |
| **Buying Store** | Create buying shop | Demand-based pricing |
| **Market Analysis** | Monitor vendor prices | Price tracking database |
| **Arbitrage** | Buy low, sell high | Profit opportunity detection |
| **Resource Farming** | Farm valuable items | Zeny/hour optimization |
| **NPC Arbitrage** | Buy from NPCs, sell to players | Static profit routes |

#### Party/Guild Activities

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Party Creation** | Create and manage parties | Leadership role support |
| **Party Joining** | Accept party invitations | Trust evaluation |
| **Role Fulfillment** | Play assigned party role | DPS/Tank/Healer/Support AI |
| **Guild WoE** | War of Emperium participation | Strategic siege warfare |
| **Guild Dungeons** | Coordinate dungeon runs | Instance management |
| **MVP Hunting** | Coordinate boss hunts | Spawn tracking + team coordination |

#### Miscellaneous Actions

| Capability | Description | Implementation |
|------------|-------------|----------------|
| **Sitting** | Sit to regenerate HP/SP | Resource conservation mode |
| **Character Emotions** | Express character emotions | Natural behavior simulation |
| **Equipment Refining** | Upgrade equipment | Risk assessment for refining |
| **Card Socketing** | Insert cards into equipment | Build optimization |
| **Pet Management** | Feed and manage pets | Pet hunger/intimacy tracking |
| **Homunculus Control** | Manage alchemist homunculus | AI-within-AI behavior |
| **Screenshot** | Take in-game screenshots | Documentation/proof capture |

### Autonomy Levels

The AI supports different autonomy configurations:

```yaml
autonomy:
  level: full  # full, supervised, or manual
  
  full:
    # Complete autonomy - AI handles everything
    description: "AI operates independently 24/7"
    human_intervention: none
    
  supervised:
    # AI operates but alerts for important decisions
    description: "AI operates with human oversight"
    alert_on:
      - rare_item_drop
      - player_interaction
      - unusual_situation
      - death
    confirmation_required:
      - trade_over_1m
      - guild_join
      - expensive_purchase
      
  manual:
    # AI suggests, human decides
    description: "AI as advisor only"
    auto_execute: false
    suggestion_mode: true
```

### Capability Dependencies

Some capabilities require specific conditions:

| Capability | Requires |
|------------|----------|
| Vending | Merchant class + cart |
| Homunculus | Alchemist class |
| Guild WoE | Guild membership |
| Refinement | Appropriate NPC access |
| Instance Dungeons | Party + entry item |

### 5.1 Character Lifecycle State Machine

The AI manages the complete character lifecycle from creation to endgame using a **Finite State Machine (FSM)** architecture with the following states:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CHARACTER LIFECYCLE STATE MACHINE                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐             │
│   │   NOVICE     │───▶│  FIRST JOB   │───▶│  SECOND JOB  │─────┐       │
│   │  (Lv 1-10)   │    │  (Lv 10-50)  │    │  (Lv 50-99)  │     │       │
│   └──────────────┘    └──────────────┘    └──────────────┘     │       │
│                                                                 ▼       │
│   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐             │
│   │   ENDGAME    │◀───│  THIRD JOB   │◀───│   REBIRTH    │◀────┘       │
│   │  (Max Level) │    │ (Lv 100-175) │    │ (Transcend)  │             │
│   └──────────────┘    └──────────────┘    └──────────────┘             │
│         │                                                               │
│         ▼                                                               │
│   ┌──────────────┐                                                      │
│   │  OPTIMIZING  │  ← Continuous improvement after max level           │
│   │  (Infinite)  │                                                      │
│   └──────────────┘                                                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**State Definitions:**

| State | Level Range | Primary Goals | Key Activities |
|-------|------------|---------------|----------------|
| **NOVICE** | 1-10 | Basic leveling | Training grounds, basic quests |
| **FIRST_JOB** | 10-50 | Establish build foundation | Job advancement, skill acquisition |
| **SECOND_JOB** | 50-99 | Build optimization | Farming, gear acquisition, parties |
| **REBIRTH** | Transition | Transcendence | Reset stats, enhanced stats |
| **THIRD_JOB** | 100-175 | Max power | Endgame content, MVPs, WoE |
| **ENDGAME** | Max | Sustain & optimize | Perfect gear, wealth accumulation |
| **OPTIMIZING** | ∞ | Continuous improvement | Min-maxing, alternative builds |

**State Transition Logic:**

```python
class CharacterLifecycleStateMachine:
    """
    Manages autonomous character progression through all game phases.
    """
    
    STATES = [
        'NOVICE', 'FIRST_JOB', 'SECOND_JOB',
        'REBIRTH', 'THIRD_JOB', 'ENDGAME', 'OPTIMIZING'
    ]
    
    TRANSITIONS = {
        'NOVICE': {
            'condition': lambda c: c.job_level >= 10,
            'next_state': 'FIRST_JOB',
            'action': 'initiate_job_advancement'
        },
        'FIRST_JOB': {
            'condition': lambda c: c.base_level >= 50 and c.job_level >= 50,
            'next_state': 'SECOND_JOB',
            'action': 'initiate_second_job'
        },
        'SECOND_JOB': {
            'condition': lambda c: c.base_level >= 99 and c.job_level >= 50,
            'next_state': 'REBIRTH',  # or 'THIRD_JOB' for renewal servers
            'action': 'check_rebirth_or_third_job'
        },
        'REBIRTH': {
            'condition': lambda c: c.is_transcendent and c.job_level >= 50,
            'next_state': 'THIRD_JOB',
            'action': 'initiate_third_job'
        },
        'THIRD_JOB': {
            'condition': lambda c: c.base_level >= c.max_level,
            'next_state': 'ENDGAME',
            'action': 'enter_endgame_mode'
        },
        'ENDGAME': {
            'condition': lambda c: c.gear_score >= 0.95,  # 95% optimal
            'next_state': 'OPTIMIZING',
            'action': 'enter_optimization_mode'
        },
        'OPTIMIZING': {
            'condition': lambda c: False,  # Never exits
            'next_state': 'OPTIMIZING',
            'action': 'continuous_optimization'
        }
    }
    
    async def tick(self, character):
        """Called every AI tick to check for state transitions."""
        current = character.lifecycle_state
        transition = self.TRANSITIONS.get(current)
        
        if transition and transition['condition'](character):
            # Execute transition action
            await getattr(self, transition['action'])(character)
            # Update state
            character.lifecycle_state = transition['next_state']
            # Store transition in memory
            await self.memory.add(
                content=f"Character transitioned from {current} to {transition['next_state']}",
                metadata={'sector': 'progression', 'milestone': True}
            )
```

**Configuration:**

```yaml
lifecycle:
  enabled: true
  
  initial_state: auto_detect  # auto_detect, NOVICE, FIRST_JOB, etc.
  
  novice:
    target_level: 10
    training_ground: true
    recommended_maps:
      - prt_fild01
      - pay_fild01
    
  first_job:
    job_class: auto_detect  # or specific: Swordman, Mage, etc.
    target_base_level: 50
    target_job_level: 50
    priority: job_level_first  # job_level_first, base_level_first, balanced
    
  second_job:
    job_class: auto_detect  # Knight, Wizard, etc.
    target_base_level: 99
    target_job_level: 50
    rebirth_enabled: true  # Set false for Renewal servers
    
  rebirth:
    enabled: true
    preserve_stats: false
    immediate_job_change: true
    
  third_job:
    job_class: auto_detect  # Rune Knight, Warlock, etc.
    target_base_level: 175
    target_job_level: 60
    
  endgame:
    activities:
      - mvp_hunting
      - woe_participation
      - gear_optimization
      - wealth_accumulation
```

---

### 5.2 Job Advancement Automation

The AI automatically handles all job advancements, including navigating to job NPCs, completing prerequisites, and making class choices.

#### Job Advancement Flow

```mermaid
flowchart TD
    A[Check Job Level] --> B{Prerequisites Met?}
    B -->|No| C[Continue Leveling]
    B -->|Yes| D[Navigate to Job NPC]
    D --> E[Initiate Dialogue]
    E --> F{Test Required?}
    F -->|Yes| G[Complete Job Test]
    F -->|No| H[Change Job]
    G --> H
    H --> I[Update Character State]
    I --> J[Allocate New Skills]
```

#### Supported Job Paths

```yaml
job_advancement:
  enabled: true
  
  # Novice → First Job
  first_job_paths:
    Swordman:
      npc_map: izlude
      npc_coordinates: [53, 137]
      required_job_level: 10
      test_required: false
      
    Mage:
      npc_map: geffen_in
      npc_coordinates: [165, 117]
      required_job_level: 10
      test_required: false
      
    Archer:
      npc_map: payon_in01
      npc_coordinates: [64, 73]
      required_job_level: 10
      test_required: true
      test_type: hunting_quest
      test_target: {monster: "Zombie", count: 50}
      
    Thief:
      npc_map: moc_ruins
      npc_coordinates: [129, 131]
      required_job_level: 10
      test_required: true
      test_type: mushroom_quest
      
    Merchant:
      npc_map: alberta_in
      npc_coordinates: [36, 37]
      required_job_level: 10
      test_required: true
      test_type: item_quest
      test_items:
        - {item: "Trunk", count: 20}
        
    Acolyte:
      npc_map: prontera_church
      npc_coordinates: [63, 19]
      required_job_level: 10
      test_required: true
      test_type: undead_quest
  
  # First Job → Second Job (examples)
  second_job_paths:
    Knight:
      from_class: Swordman
      npc_map: prt_in01
      npc_coordinates: [97, 90]
      requirements:
        job_level: 40
        base_level: 50
      test_required: true
      test_type: combat_test
      
    Wizard:
      from_class: Mage
      npc_map: geffen_in
      npc_coordinates: [170, 108]
      requirements:
        job_level: 40
        base_level: 50
      test_required: true
      test_type: magic_quiz
      
    Hunter:
      from_class: Archer
      npc_map: pay_arche
      npc_coordinates: [117, 17]
      requirements:
        job_level: 40
        base_level: 50
      test_required: true
      test_type: trap_maze
  
  # Rebirth/Transcendence
  rebirth:
    npc_map: valkyrie
    npc_coordinates: [48, 49]
    requirements:
      base_level: 99
      job_level: 50
    zeny_cost: 1285000
    
  # Third Job examples
  third_job_paths:
    Rune_Knight:
      from_class: Lord_Knight
      npc_map: prontera
      npc_coordinates: [156, 191]
      requirements:
        base_level: 99
        job_level: 50
      quest_required: true
```

#### Job Test Automation

```python
class JobTestAutomation:
    """Handles automated completion of job advancement tests."""
    
    async def complete_test(self, test_type: str, test_params: dict) -> bool:
        """
        Execute the appropriate test completion strategy.
        
        Returns True if test passed, False otherwise.
        """
        handlers = {
            'hunting_quest': self._handle_hunting_quest,
            'item_quest': self._handle_item_quest,
            'mushroom_quest': self._handle_mushroom_quest,
            'undead_quest': self._handle_undead_quest,
            'combat_test': self._handle_combat_test,
            'magic_quiz': self._handle_magic_quiz,
            'trap_maze': self._handle_trap_maze,
        }
        
        handler = handlers.get(test_type)
        if not handler:
            raise ValueError(f"Unknown test type: {test_type}")
        
        return await handler(test_params)
    
    async def _handle_hunting_quest(self, params: dict) -> bool:
        """Kill X monsters of type Y."""
        monster = params['monster']
        count = params['count']
        
        # Set up hunting objective
        await self.combat_ai.set_target_priority([monster])
        
        # Hunt until complete
        kills = 0
        while kills < count:
            result = await self.combat_ai.hunt_once()
            if result.killed and result.monster_name == monster:
                kills += 1
            await asyncio.sleep(0.1)
        
        return True
    
    async def _handle_item_quest(self, params: dict) -> bool:
        """Collect and deliver specified items."""
        items = params['items']
        
        for item_req in items:
            item_name = item_req['item']
            count = item_req['count']
            
            # Check inventory first
            current = self.inventory.count(item_name)
            needed = count - current
            
            if needed > 0:
                # Farm the items
                await self.farming_ai.farm_item(item_name, needed)
        
        return True
```

---

### 5.3 Stat Point Distribution Engine

The AI automatically allocates stat points based on the character's build archetype, with support for custom builds and optimization algorithms.

#### Build Archetypes

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       STAT DISTRIBUTION ARCHETYPES                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   BUILD TYPE        STR   AGI   VIT   INT   DEX   LUK                  │
│   ────────────────  ────  ────  ────  ────  ────  ────                 │
│   Melee DPS         HIGH  MED   LOW   -     MED   LOW                  │
│   Agi-Crit          MED   HIGH  LOW   -     MED   HIGH                 │
│   Tank              MED   LOW   HIGH  -     MED   LOW                  │
│   Magic DPS         -     MED   LOW   HIGH  HIGH  LOW                  │
│   Support           -     LOW   MED   HIGH  HIGH  LOW                  │
│   Hybrid            MED   MED   MED   MED   MED   MED                  │
│                                                                         │
│   Legend: HIGH = 80-130, MED = 40-80, LOW = 1-40, - = Base only        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Stat Allocation Algorithm

```python
class StatDistributionEngine:
    """
    Intelligent stat point allocation based on build templates and optimization.
    
    Uses a priority queue system that considers:
    - Target build ratios
    - Current stat diminishing returns
    - Level-appropriate stat caps
    - Gear bonus integration
    """
    
    # Standard build templates (percentages of total points)
    BUILD_TEMPLATES = {
        'melee_dps': {
            'STR': 0.35, 'AGI': 0.25, 'VIT': 0.10,
            'INT': 0.00, 'DEX': 0.25, 'LUK': 0.05
        },
        'agi_crit': {
            'STR': 0.25, 'AGI': 0.35, 'VIT': 0.05,
            'INT': 0.00, 'DEX': 0.15, 'LUK': 0.20
        },
        'tank': {
            'STR': 0.25, 'AGI': 0.05, 'VIT': 0.40,
            'INT': 0.00, 'DEX': 0.25, 'LUK': 0.05
        },
        'magic_dps': {
            'STR': 0.00, 'AGI': 0.15, 'VIT': 0.10,
            'INT': 0.40, 'DEX': 0.35, 'LUK': 0.00
        },
        'support': {
            'STR': 0.00, 'AGI': 0.05, 'VIT': 0.25,
            'INT': 0.35, 'DEX': 0.35, 'LUK': 0.00
        },
        'hybrid': {
            'STR': 0.17, 'AGI': 0.17, 'VIT': 0.17,
            'INT': 0.17, 'DEX': 0.16, 'LUK': 0.16
        }
    }
    
    # Diminishing returns thresholds
    SOFT_CAPS = {
        'STR': 100, 'AGI': 100, 'VIT': 100,
        'INT': 100, 'DEX': 100, 'LUK': 100
    }
    
    def __init__(self, build_type: str, custom_ratios: dict = None):
        """
        Initialize with build type or custom ratios.
        
        Args:
            build_type: One of BUILD_TEMPLATES keys or 'custom'
            custom_ratios: Dict of stat ratios if build_type is 'custom'
        """
        if build_type == 'custom' and custom_ratios:
            self.ratios = custom_ratios
        else:
            self.ratios = self.BUILD_TEMPLATES.get(build_type,
                                                    self.BUILD_TEMPLATES['hybrid'])
    
    def calculate_next_stat(self, current_stats: dict,
                            available_points: int) -> str:
        """
        Determine which stat to increase next.
        
        Uses a weighted scoring system that considers:
        1. How far each stat is from its target ratio
        2. Diminishing returns at higher levels
        3. Build-specific priorities
        
        Returns: Name of stat to increase (e.g., 'STR')
        """
        total_stats = sum(current_stats.values())
        scores = {}
        
        for stat, target_ratio in self.ratios.items():
            if target_ratio == 0:
                continue
            
            current_value = current_stats.get(stat, 1)
            current_ratio = current_value / max(total_stats, 1)
            
            # Base score: how far below target ratio
            ratio_deficit = target_ratio - current_ratio
            
            # Diminishing returns penalty
            dr_penalty = 0
            if current_value > self.SOFT_CAPS[stat]:
                dr_penalty = (current_value - self.SOFT_CAPS[stat]) * 0.01
            
            # Point cost consideration (stats cost more at higher values)
            cost_factor = 1 + (current_value // 10) * 0.1
            
            # Final score
            scores[stat] = (ratio_deficit - dr_penalty) / cost_factor
        
        # Return highest scoring stat
        return max(scores, key=scores.get)
    
    def generate_allocation_plan(self, current_stats: dict,
                                 available_points: int) -> list:
        """
        Generate a complete allocation plan for all available points.
        
        Returns: List of (stat_name, points) tuples
        """
        plan = []
        simulated_stats = current_stats.copy()
        remaining = available_points
        
        while remaining > 0:
            next_stat = self.calculate_next_stat(simulated_stats, remaining)
            
            # Add to plan
            plan.append((next_stat, 1))
            
            # Simulate allocation
            simulated_stats[next_stat] = simulated_stats.get(next_stat, 1) + 1
            remaining -= 1
        
        # Consolidate consecutive allocations
        consolidated = []
        for stat, points in plan:
            if consolidated and consolidated[-1][0] == stat:
                consolidated[-1] = (stat, consolidated[-1][1] + points)
            else:
                consolidated.append((stat, points))
        
        return consolidated
    
    async def auto_allocate(self, character) -> int:
        """
        Automatically allocate all available stat points.
        
        Returns: Number of points allocated
        """
        current_stats = {
            'STR': character.str, 'AGI': character.agi,
            'VIT': character.vit, 'INT': character.int,
            'DEX': character.dex, 'LUK': character.luk
        }
        
        available = character.stat_points
        if available <= 0:
            return 0
        
        plan = self.generate_allocation_plan(current_stats, available)
        
        for stat, points in plan:
            await character.add_stat_points(stat, points)
            await asyncio.sleep(0.1)  # Rate limiting
        
        return available
```

**Configuration:**

```yaml
stats:
  enabled: true
  auto_allocate: true
  
  build:
    type: auto_detect  # auto_detect, melee_dps, agi_crit, tank, etc.
    
    # Auto-detect logic
    auto_detect_rules:
      - job_class: [Swordman, Knight, Lord_Knight, Rune_Knight]
        default_build: melee_dps
      - job_class: [Assassin, Assassin_Cross, Guillotine_Cross]
        default_build: agi_crit
      - job_class: [Crusader, Paladin, Royal_Guard]
        default_build: tank
      - job_class: [Mage, Wizard, High_Wizard, Warlock]
        default_build: magic_dps
      - job_class: [Acolyte, Priest, High_Priest, Arch_Bishop]
        default_build: support
    
    # Custom build (if type: custom)
    custom:
      STR: 0.30
      AGI: 0.20
      VIT: 0.15
      INT: 0.00
      DEX: 0.30
      LUK: 0.05
  
  allocation_timing:
    on_level_up: true      # Allocate immediately on level up
    batch_mode: false      # Or save and allocate in batches
    batch_size: 10         # Allocate every 10 points
  
  overrides:
    # Force specific stats at certain thresholds
    - condition: "DEX < 100 and job_class == 'Wizard'"
      action: "prioritize DEX until 100"
    - condition: "VIT < 60 and base_level >= 80"
      action: "prioritize VIT until 60"
```

---

### 5.4 Skill Point Allocation System

The AI manages skill point distribution with support for skill trees, prerequisites, and build optimization.

#### Skill Priority Engine

```python
class SkillAllocationEngine:
    """
    Intelligent skill point allocation based on build priorities and prerequisites.
    
    Features:
    - Prerequisite chain resolution
    - Build-optimized skill priorities
    - Automatic reallocation planning for rebirth
    """
    
    def __init__(self, skill_database: dict, build_priorities: list):
        """
        Initialize with skill database and build-specific priorities.
        
        Args:
            skill_database: Complete skill tree with prerequisites
            build_priorities: Ordered list of priority skills
        """
        self.db = skill_database
        self.priorities = build_priorities
    
    def resolve_prerequisites(self, skill_name: str) -> list:
        """
        Get ordered list of skills needed before target skill.
        
        Returns: List of (skill_name, required_level) tuples
        """
        skill = self.db.get(skill_name)
        if not skill:
            return []
        
        chain = []
        for prereq_name, prereq_level in skill.get('prerequisites', {}).items():
            # Recursively resolve prerequisites
            chain.extend(self.resolve_prerequisites(prereq_name))
            chain.append((prereq_name, prereq_level))
        
        # Remove duplicates while preserving order
        seen = set()
        unique_chain = []
        for item in chain:
            if item[0] not in seen:
                seen.add(item[0])
                unique_chain.append(item)
        
        return unique_chain
    
    def calculate_allocation_plan(self, current_skills: dict,
                                  available_points: int) -> list:
        """
        Generate optimal skill allocation plan.
        
        Returns: List of (skill_name, target_level) tuples
        """
        plan = []
        remaining = available_points
        simulated_skills = current_skills.copy()
        
        for priority_skill in self.priorities:
            skill_info = self.db.get(priority_skill)
            if not skill_info:
                continue
            
            max_level = skill_info['max_level']
            current_level = simulated_skills.get(priority_skill, 0)
            
            if current_level >= max_level:
                continue
            
            # Check and fulfill prerequisites first
            prereqs = self.resolve_prerequisites(priority_skill)
            for prereq_name, prereq_level in prereqs:
                prereq_current = simulated_skills.get(prereq_name, 0)
                if prereq_current < prereq_level:
                    points_needed = prereq_level - prereq_current
                    if points_needed <= remaining:
                        plan.append((prereq_name, prereq_level))
                        simulated_skills[prereq_name] = prereq_level
                        remaining -= points_needed
            
            # Now allocate to priority skill
            points_for_skill = min(max_level - current_level, remaining)
            if points_for_skill > 0:
                new_level = current_level + points_for_skill
                plan.append((priority_skill, new_level))
                simulated_skills[priority_skill] = new_level
                remaining -= points_for_skill
        
        return plan
```

**Skill Build Templates:**

```yaml
skills:
  enabled: true
  auto_allocate: true
  
  build_templates:
    # Knight - Bash/Pierce Build
    knight_bash:
      priorities:
        - Bash:10
        - Pierce:10
        - Provoke:10
        - Endure:10
        - Two_Hand_Quicken:10
        - Aura_Blade:5
        - Parry:10
      
    # Wizard - Bolt Build
    wizard_bolt:
      priorities:
        - Fire_Bolt:10
        - Cold_Bolt:10
        - Lightning_Bolt:10
        - Increase_SP_Recovery:10
        - Jupitel_Thunder:10
        - Lord_of_Vermilion:10
        - Storm_Gust:10
        
    # Priest - Support Build
    priest_support:
      priorities:
        - Heal:10
        - Blessing:10
        - Increase_AGI:10
        - Kyrie_Eleison:10
        - Magnificat:5
        - Gloria:5
        - Resurrection:4
        - Sanctuary:10
  
  # Active build selection
  active_build: auto_detect  # Uses job class to select template
  
  # Override specific skills
  skill_overrides:
    - skill: Heal
      min_level: 5
      reason: "Emergency self-healing"
    - skill: Teleport
      min_level: 2
      reason: "Escape and travel"
```

---

### 5.5 Equipment Progression System

The AI manages gear acquisition, upgrades, and situational equipment changes throughout the character lifecycle.

#### Equipment Lifecycle Stages

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      EQUIPMENT PROGRESSION STAGES                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   STAGE 1: STARTER (Lv 1-30)                                           │
│   ├── Basic NPC weapons/armor                                          │
│   ├── Free quest rewards                                               │
│   └── Budget: 0-50k zeny                                               │
│                                                                         │
│   STAGE 2: INTERMEDIATE (Lv 30-70)                                     │
│   ├── Crafted/dropped equipment                                        │
│   ├── First upgrade attempts (+4-7)                                    │
│   └── Budget: 50k-500k zeny                                            │
│                                                                         │
│   STAGE 3: ADVANCED (Lv 70-99)                                         │
│   ├── Set bonuses targeted                                             │
│   ├── Carded equipment                                                 │
│   └── Budget: 500k-5m zeny                                             │
│                                                                         │
│   STAGE 4: ENDGAME (Lv 99+)                                            │
│   ├── Best-in-slot hunting                                             │
│   ├── Perfect enchants/upgrades                                        │
│   └── Budget: 5m+ zeny                                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Equipment Decision Engine

```python
class EquipmentProgressionEngine:
    """
    Manages equipment acquisition, upgrades, and swaps.
    
    Features:
    - Gear scoring system
    - Budget-aware recommendations
    - Situational swap management
    - Upgrade path planning
    """
    
    def calculate_gear_score(self, item: dict, character: dict) -> float:
        """
        Calculate a normalized score (0-100) for equipment.
        
        Considers:
        - Base stats
        - Slot count
        - Card effects
        - Upgrade level
        - Set bonuses
        - Build synergy
        """
        score = 0.0
        
        # Base stat contribution
        for stat, value in item.get('stats', {}).items():
            weight = self.get_stat_weight(stat, character['build'])
            score += value * weight
        
        # Slot bonus
        score += item.get('slots', 0) * 5
        
        # Upgrade bonus
        upgrade = item.get('upgrade', 0)
        score += upgrade * 2
        
        # Card bonus
        for card in item.get('cards', []):
            score += self.evaluate_card(card, character) * 3
        
        # Set bonus
        if self.has_set_bonus(item, character['equipped']):
            score *= 1.2
        
        # Normalize to 0-100
        return min(score, 100)
    
    def recommend_upgrade(self, character: dict) -> dict:
        """
        Recommend the best equipment upgrade within budget.
        
        Returns: {
            'slot': 'weapon',
            'current': {...},
            'recommended': {...},
            'score_improvement': 15.3,
            'cost_estimate': 500000
        }
        """
        recommendations = []
        
        for slot in ['weapon', 'armor', 'helmet', 'shield',
                     'garment', 'shoes', 'accessory1', 'accessory2']:
            current_item = character['equipped'].get(slot)
            current_score = self.calculate_gear_score(current_item, character)
            
            # Find best affordable upgrade
            candidates = self.find_upgrades(
                slot=slot,
                current_score=current_score,
                budget=character['zeny'] * 0.5,  # 50% of total zeny
                character=character
            )
            
            if candidates:
                best = max(candidates, key=lambda x: x['score'])
                recommendations.append({
                    'slot': slot,
                    'current': current_item,
                    'recommended': best['item'],
                    'score_improvement': best['score'] - current_score,
                    'cost_estimate': best['cost']
                })
        
        # Return highest impact upgrade
        if recommendations:
            return max(recommendations, key=lambda x: x['score_improvement'])
        return None
    
    def generate_swap_loadouts(self, character: dict) -> dict:
        """
        Generate situational equipment loadouts.
        
        Returns: Dict of loadout_name -> equipment_set
        """
        return {
            'leveling': self._build_loadout(character, 'exp_gain'),
            'farming': self._build_loadout(character, 'drop_rate'),
            'pvp': self._build_loadout(character, 'pvp_stats'),
            'mvp': self._build_loadout(character, 'boss_damage'),
            'tank': self._build_loadout(character, 'defense'),
        }
```

**Configuration:**

```yaml
equipment:
  enabled: true
  
  progression:
    auto_equip: true           # Equip better gear automatically
    auto_upgrade: false        # Attempt refining (risky)
    safe_upgrade_only: true    # Only use safe refine tickets
    
  budget:
    max_single_purchase: 0.3   # 30% of total zeny
    reserve_minimum: 100000    # Always keep 100k zeny
    
  priorities:
    weapon: 1.0                # Highest priority
    armor: 0.9
    accessory: 0.7
    garment: 0.6
    shoes: 0.6
    helmet: 0.5
    shield: 0.5
    
  loadouts:
    enabled: true
    auto_swap: true            # Auto-swap based on situation
    
    swap_triggers:
      - condition: "entering pvp_map"
        loadout: pvp
      - condition: "target is MVP"
        loadout: mvp
      - condition: "party role == tank"
        loadout: tank
        
  card_strategy:
    slot_reservation: true     # Keep slots for better cards
    auto_socket: false         # Don't auto-insert cards
    card_priorities:
      - category: damage_cards
        slot: weapon
      - category: survival_cards
        slot: armor
```

---

### 5.6 Leveling Strategy Engine

The AI optimizes leveling efficiency by selecting appropriate maps, managing party composition, and tracking performance metrics.

#### Map Selection Algorithm

```python
class LevelingStrategyEngine:
    """
    Optimizes leveling by selecting maps, managing routes, and tracking efficiency.
    """
    
    def __init__(self, map_database: dict, character: dict):
        self.maps = map_database
        self.char = character
    
    def score_map(self, map_name: str) -> dict:
        """
        Calculate comprehensive map score.
        
        Returns: {
            'total_score': float,
            'exp_efficiency': float,
            'safety': float,
            'competition': float,
            'loot_value': float
        }
        """
        map_info = self.maps.get(map_name, {})
        
        # Experience efficiency
        avg_exp = self._calculate_avg_exp(map_info['monsters'])
        kill_rate = self._estimate_kill_rate(map_info['monsters'])
        exp_efficiency = (avg_exp * kill_rate) / 3600  # EXP/hour
        
        # Safety score (inverse of danger)
        danger = sum(
            m.get('danger_level', 1)
            for m in map_info['monsters']
        ) / len(map_info['monsters'])
        safety = 1.0 / max(danger, 0.1)
        
        # Competition (based on typical player count)
        competition = 1.0 - (map_info.get('avg_players', 0) / 20)
        
        # Loot value
        loot_value = sum(
            m.get('avg_drop_value', 0) * kill_rate
            for m in map_info['monsters']
        ) / 3600  # Zeny/hour from drops
        
        # Weighted total
        weights = {
            'exp': 0.5,
            'safety': 0.2,
            'competition': 0.15,
            'loot': 0.15
        }
        
        total = (
            exp_efficiency * weights['exp'] +
            safety * weights['safety'] +
            competition * weights['competition'] +
            loot_value * weights['loot']
        )
        
        return {
            'total_score': total,
            'exp_efficiency': exp_efficiency,
            'safety': safety,
            'competition': competition,
            'loot_value': loot_value
        }
    
    def recommend_map(self) -> str:
        """
        Recommend best map for current character state.
        """
        level = self.char['base_level']
        job = self.char['job_class']
        
        # Filter maps by level range
        candidates = [
            name for name, info in self.maps.items()
            if info.get('min_level', 1) <= level <= info.get('max_level', 999)
        ]
        
        # Score and rank
        scored = [(name, self.score_map(name)) for name in candidates]
        scored.sort(key=lambda x: x[1]['total_score'], reverse=True)
        
        return scored[0][0] if scored else 'prt_fild01'
    
    def generate_leveling_plan(self, target_level: int) -> list:
        """
        Generate complete leveling plan from current to target level.
        
        Returns: List of {
            'level_range': (start, end),
            'map': str,
            'estimated_hours': float,
            'strategy': str
        }
        """
        plan = []
        current = self.char['base_level']
        
        while current < target_level:
            # Find best map for current level
            best_map = self.recommend_map()
            map_info = self.maps[best_map]
            
            # Determine how long to stay on this map
            max_effective_level = map_info.get('max_level', current + 10)
            end_level = min(max_effective_level, target_level)
            
            # Estimate time
            exp_rate = self.score_map(best_map)['exp_efficiency']
            exp_needed = self._calculate_exp_for_range(current, end_level)
            hours = exp_needed / max(exp_rate, 1)
            
            plan.append({
                'level_range': (current, end_level),
                'map': best_map,
                'estimated_hours': hours,
                'strategy': self._determine_strategy(best_map)
            })
            
            current = end_level
        
        return plan
```

**Configuration:**

```yaml
leveling:
  enabled: true
  
  strategy:
    mode: auto_optimize  # auto_optimize, manual, party_only
    optimize_for: exp_per_hour  # exp_per_hour, safety, drops, balanced
    
  map_selection:
    auto_change: true
    evaluation_interval: 3600   # Re-evaluate every hour
    
    preferences:
      avoid_pvp_maps: true
      prefer_indoor: false      # Indoor maps have no weather
      max_monster_level_above: 10  # Don't fight mobs 10+ levels above
      
    blacklist:
      - guild_pvp_maps
      - event_maps
      
    favorites:
      - geffen_dungeon01
      - pay_dun00
      
  party:
    prefer_party: true
    max_party_size: 6
    role_preference: auto_detect
    exp_share_mode: even
    
  metrics:
    track_exp_rate: true
    track_deaths: true
    track_efficiency: true
    log_interval: 300           # Log stats every 5 minutes
```

---

### 5.7 Complete Autonomous Gameplay Loop

The AI runs a continuous gameplay loop that integrates all systems for fully autonomous operation.

#### Main Loop Architecture

```python
class AutonomousGameplayLoop:
    """
    Master orchestrator for fully autonomous gameplay.
    
    Integrates:
    - Lifecycle state machine
    - Combat AI
    - Equipment management
    - Economic decisions
    - Social interactions
    - Anti-detection systems
    """
    
    def __init__(self, config: dict):
        self.config = config
        
        # Core systems
        self.lifecycle = CharacterLifecycleStateMachine()
        self.stats = StatDistributionEngine(config['stats']['build']['type'])
        self.skills = SkillAllocationEngine(SKILL_DB, config['skills'])
        self.equipment = EquipmentProgressionEngine()
        self.leveling = LevelingStrategyEngine(MAP_DB, character)
        self.combat = CombatAI(config['combat'])
        self.social = SocialInteractionAI(config['social'])
        self.anti_detect = AntiDetectionSystem(config['anti_detection'])
        
        # State
        self.running = False
        self.pause_reason = None
    
    async def run(self):
        """Main autonomous loop."""
        self.running = True
        
        while self.running:
            try:
                # 1. Check for emergency conditions
                if await self.check_emergencies():
                    continue
                
                # 2. Anti-detection tick
                await self.anti_detect.tick()
                
                # 3. Lifecycle state management
                await self.lifecycle.tick(self.character)
                
                # 4. Handle pending allocations
                await self.handle_allocations()
                
                # 5. Execute primary activity
                await self.execute_primary_activity()
                
                # 6. Handle social interactions
                await self.social.process_incoming()
                
                # 7. Periodic maintenance
                await self.periodic_maintenance()
                
                # 8. Sleep for tick rate
                await asyncio.sleep(self.config['tick_rate_ms'] / 1000)
                
            except Exception as e:
                await self.handle_error(e)
    
    async def check_emergencies(self) -> bool:
        """Check for conditions requiring immediate attention."""
        
        # GM Detection
        if self.anti_detect.gm_detected:
            await self.enter_stealth_mode()
            return True
        
        # Low HP
        if self.character.hp_percent < 0.15:
            await self.emergency_escape()
            return True
        
        # Inventory full
        if self.character.inventory_percent > 0.9:
            await self.handle_full_inventory()
            return True
        
        # Death recovery
        if self.character.is_dead:
            await self.handle_death()
            return True
        
        return False
    
    async def handle_allocations(self):
        """Allocate any pending stat/skill points."""
        
        # Stats
        if self.character.stat_points > 0:
            await self.stats.auto_allocate(self.character)
        
        # Skills
        if self.character.skill_points > 0:
            await self.skills.auto_allocate(self.character)
    
    async def execute_primary_activity(self):
        """Execute the main gameplay activity based on current state."""
        
        state = self.character.lifecycle_state
        
        activities = {
            'NOVICE': self.activity_novice_leveling,
            'FIRST_JOB': self.activity_standard_leveling,
            'SECOND_JOB': self.activity_standard_leveling,
            'REBIRTH': self.activity_rebirth_process,
            'THIRD_JOB': self.activity_endgame,
            'ENDGAME': self.activity_endgame,
            'OPTIMIZING': self.activity_optimization,
        }
        
        activity = activities.get(state, self.activity_standard_leveling)
        await activity()
    
    async def activity_standard_leveling(self):
        """Standard leveling activity: farm monsters on optimal map."""
        
        # Check if we're on optimal map
        recommended = self.leveling.recommend_map()
        if self.character.current_map != recommended:
            await self.navigate_to_map(recommended)
            return
        
        # Find and engage targets
        targets = self.combat.find_targets()
        if targets:
            await self.combat.engage(targets[0])
        else:
            # No targets, move to find more
            await self.roam_for_targets()
    
    async def activity_endgame(self):
        """Endgame activities: MVP hunting, WoE, optimization."""
        
        schedule = self.config['endgame']['schedule']
        current_hour = datetime.now().hour
        
        # Check schedule for specific activities
        for activity in schedule:
            if activity['hour_start'] <= current_hour < activity['hour_end']:
                handler = getattr(self, f"activity_{activity['type']}")
                await handler()
                return
        
        # Default: farm
        await self.activity_standard_leveling()
    
    async def periodic_maintenance(self):
        """Periodic maintenance tasks."""
        
        now = time.time()
        
        # Equipment check (every 30 minutes)
        if now - self.last_equip_check > 1800:
            upgrade = self.equipment.recommend_upgrade(self.character)
            if upgrade and upgrade['cost_estimate'] < self.character.zeny * 0.3:
                await self.acquire_equipment(upgrade['recommended'])
            self.last_equip_check = now
        
        # Supplies check (every 10 minutes)
        if now - self.last_supply_check > 600:
            await self.check_supplies()
            self.last_supply_check = now
        
        # Session break check (if enabled)
        if self.config['anti_detection']['session']['enabled']:
            session_duration = now - self.session_start
            max_session = self.config['anti_detection']['session']['max_continuous_hours'] * 3600
            if session_duration > max_session:
                await self.take_break()
```

**Complete Configuration Example:**

```yaml
# godtier-autonomous.yaml - Complete autonomous configuration

general:
  enabled: true
  log_level: info
  tick_rate_ms: 100

autonomy:
  level: full
  
lifecycle:
  enabled: true
  initial_state: auto_detect

stats:
  enabled: true
  auto_allocate: true
  build:
    type: auto_detect

skills:
  enabled: true
  auto_allocate: true
  active_build: auto_detect

equipment:
  enabled: true
  progression:
    auto_equip: true
    safe_upgrade_only: true

leveling:
  enabled: true
  strategy:
    mode: auto_optimize
    optimize_for: exp_per_hour

combat:
  enabled: true
  role: auto_detect
  aggression: 0.6

social:
  enabled: true
  mode: template
  personality: friendly

anti_detection:
  enabled: true
  paranoia_level: medium
  session:
    max_continuous_hours: 4
    break_duration_minutes: [15, 30]

endgame:
  schedule:
    - type: mvp_hunting
      hour_start: 2
      hour_end: 6
    - type: woe_preparation
      hour_start: 18
      hour_end: 20
    - type: woe_participation
      hour_start: 20
      hour_end: 22
    - type: farming
      hour_start: 6
      hour_end: 18

memory:
  enabled: true
  working:
    max_entries: 2000
  session:
    backend: dragonfly
  persistent:
    backend: sqlite
```

---

## 6. Additional Capabilities

Beyond the core intelligence features, God-Tier AI includes specialized capability modules for specific gameplay aspects.

### 6.1 Anti-Detection Systems

**What it does:** Implements multiple layers of protection against automated detection systems and human GM observation.

**Why it matters:** Detection results in bans. Anti-detection systems are essential for long-term operation, making the bot indistinguishable from human players to both automated systems and human observers.

**Detection vectors addressed:**

```
┌────────────────────────────────────────────────────────────────┐
│                    DETECTION VECTORS                            │
├──────────────────┬──────────────────┬──────────────────────────┤
│    AUTOMATED     │      HUMAN       │       STATISTICAL        │
├──────────────────┼──────────────────┼──────────────────────────┤
│ • Packet timing  │ • Unnatural      │ • Uptime patterns       │
│ • Input patterns │   movement       │ • Efficiency metrics    │
│ • Action rates   │ • No chat        │ • Route consistency     │
│ • Repeated paths │ • Perfect play   │ • Reaction times        │
│ • Skill cadence  │ • No reactions   │ • Farming duration      │
│                  │   to events      │                          │
└──────────────────┴──────────────────┴──────────────────────────┘
```

**Anti-detection measures:**

| Measure | Protection Against | Implementation |
|---------|---------------------|----------------|
| **Timing variance** | Packet analysis | Gaussian delays on all actions |
| **Movement humanization** | Path analysis | Bezier curves, random pauses |
| **Session limits** | Uptime detection | Automatic breaks, varied schedules |
| **Chat simulation** | Social analysis | Occasional contextual chat |
| **Imperfection injection** | Perfect play detection | Deliberate suboptimal choices |
| **GM detection** | Human observation | Behavior mode switching |

**GM detection system:**

```mermaid
flowchart TD
    A[Entity Appeared] --> B{Check Entity}
    B -->|Name pattern| C{GM Indicators}
    B -->|Equipment| C
    B -->|Behavior| C
    
    C -->|High confidence| D[Stealth Mode]
    C -->|Medium confidence| E[Cautious Mode]
    C -->|Low confidence| F[Normal Mode]
    
    D --> G[Stop combat]
    D --> H[Natural movement]
    D --> I[Fake AFK/Chat]
    
    E --> J[Reduce efficiency]
    E --> K[Increase randomness]
```

**Configuration options:**

```yaml
anti_detection:
  enabled: true
  paranoia_level: medium    # low, medium, high, extreme
  
  timing:
    min_action_delay_ms: 150
    max_action_delay_ms: 500
    variance_distribution: gaussian
  
  movement:
    path_randomization: 0.3
    pause_probability: 0.05
    pause_duration_ms: [500, 3000]
    use_bezier: true
  
  session:
    max_continuous_hours: 4
    break_duration_minutes: [15, 45]
    daily_max_hours: 10
    vary_schedule: true
  
  gm_detection:
    enabled: true
    name_patterns:
      - "^GM[_-]?"
      - "^Admin"
      - "^\[GM\]"
    invisible_entity_alert: true
    behavior_analysis: true
    
    response:
      detection_confidence_threshold: 0.6
      stealth_mode_duration: 300  # seconds
      fake_activities:
        - afk_emote
        - random_chat
        - inventory_browse
  
  imperfection:
    mistake_rate: 0.02
    suboptimal_rate: 0.05
```

**GM Detection Methodology:**

The GM detection system uses multiple signals to identify GM presence:

| Detection Method | Confidence Weight | Description |
|-----------------|-------------------|-------------|
| **Name Pattern Matching** | 0.9 | Regex patterns for GM names |
| **Invisible Entity Detection** | 0.85 | Packet analysis for hidden entities |
| **Behavior-Based Detection** | 0.7 | Unusual movement patterns (teleporting, floating) |
| **Server Message Parsing** | 0.95 | Official GM announcements |
| **Equipment Analysis** | 0.6 | GM-exclusive equipment detection |
| **Chat Pattern Analysis** | 0.5 | Official language patterns |

**Confidence Scoring:**

```python
def calculate_gm_confidence(entity):
    """
    Calculate probability that entity is a GM.
    Returns confidence score 0.0-1.0
    """
    score = 0.0
    
    # Name pattern matching
    if matches_gm_pattern(entity.name):
        score += 0.9 * GM_NAME_WEIGHT
    
    # Invisible detection (packet analysis)
    if entity.is_invisible and not entity.has_hide_skill:
        score += 0.85 * INVISIBLE_WEIGHT
    
    # Behavior analysis
    behavior_score = analyze_movement(entity)
    score += behavior_score * BEHAVIOR_WEIGHT
    
    # Server message correlation
    if recent_gm_announcement():
        score += 0.3  # Elevate suspicion during GM activity
    
    return min(score, 1.0)
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Core feature |
| GPU | Full | Supported |
| ML | Full | Learned evasion |
| LLM | Full | Natural behavior generation |

---

### 6.2 Economic Intelligence

**What it does:** Manages economic activities including farming optimization, market analysis, trading, and resource allocation.

**Why it matters:** Efficient economic play is crucial for character progression. Economic intelligence maximizes income while managing resources intelligently.

**Economic domains:**

```
┌────────────────────────────────────────────────────────────────┐
│                   ECONOMIC INTELLIGENCE                         │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│   │   FARMING    │  │   TRADING    │  │  RESOURCES   │         │
│   │ OPTIMIZATION │  │  ANALYSIS    │  │  MANAGEMENT  │         │
│   ├──────────────┤  ├──────────────┤  ├──────────────┤         │
│   │ • Zeny/hour  │  │ • Price      │  │ • Inventory  │         │
│   │   tracking   │  │   history    │  │   rotation   │         │
│   │ • Loot value │  │ • Buy/sell   │  │ • Storage    │         │
│   │   priority   │  │   signals    │  │   management │         │
│   │ • Spot       │  │ • Vendor     │  │ • Consumable │         │
│   │   rotation   │  │   analysis   │  │   budgeting  │         │
│   └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Features:**

| Feature | Description |
|---------|-------------|
| **Farming metrics** | Track zeny/hour, experience/hour, drops/hour |
| **Loot valuation** | Dynamic item value assessment |
| **Market monitoring** | Track vendor prices over time |
| **Resource budgeting** | Allocate funds for supplies vs. savings |
| **Opportunity detection** | Identify underpriced items |

**Configuration options:**

```yaml
economy:
  enabled: true
  
  farming:
    track_metrics: true
    optimize_for: zeny_per_hour  # zeny_per_hour, exp_per_hour, drops
    
    loot_priority:
      - type: card
        action: always_pickup
      - type: equipment
        min_value: 5000
        action: pickup
      - type: consumable
        whitelist: [Red Potion, Blue Potion]
        action: pickup
      - type: etc
        min_stack_value: 1000
        action: pickup
  
  inventory:
    max_weight_percent: 70
    sell_trigger: 80
    storage_items:
      - cards
      - "value > 50000"
    
  trading:
    enabled: false           # Advanced feature
    market_scan: false
    auto_vendor: false
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Basic calculations |
| GPU | Full | Supported |
| ML | Full | Price prediction |
| LLM | Partial | Market reasoning |

---

### 6.3 Quest/Objective Automation

**What it does:** Automates completion of quests, daily objectives, and event participation.

**Why it matters:** Quests provide significant rewards but are tedious to complete manually. Quest automation handles the repetitive aspects while the player focuses on enjoyable activities.

**Quest system components:**

```mermaid
flowchart LR
    subgraph Quest Engine
        A[Quest Database] --> B[Objective Parser]
        B --> C[Step Planner]
        C --> D[Executor]
    end
    
    subgraph Capabilities
        D --> E[Kill Targets]
        D --> F[Collect Items]
        D --> G[Talk to NPCs]
        D --> H[Navigate Locations]
    end
```

**Supported quest types:**

| Type | Support | Notes |
|------|---------|-------|
| Kill quests | Full | Automated monster targeting |
| Collection quests | Full | Item farming and gathering |
| Delivery quests | Full | Navigation and NPC interaction |
| Escort quests | Partial | Path following with protection |
| Dialog quests | Partial | Simple dialog trees |
| Puzzle quests | Limited | Requires specific implementations |

**Configuration options:**

```yaml
quests:
  enabled: true
  
  automation:
    auto_accept: false       # Auto-accept known quests
    auto_complete: true      # Auto-turn-in completed quests
    priority_mode: nearest   # nearest, highest_reward, fastest
  
  daily:
    enabled: true
    reset_time: "04:00"      # Server reset time
    priority_list:
      - eden_board
      - gramps
      - daily_dungeon
  
  events:
    participate: true
    event_priority: high
    
  limits:
    max_concurrent: 3
    timeout_minutes: 60
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Quest execution |
| GPU | Full | Supported |
| ML | Partial | Quest optimization |
| LLM | Full | Dialog handling |

---

### 6.4 Party Coordination AI

**What it does:** Coordinates behavior with party members, including role fulfillment, target coordination, and communication.

**Why it matters:** Effective party play requires coordination—focus fire, healing priorities, buff distribution. Party AI enables seamless cooperation with human or bot party members.

**Coordination aspects:**

```
┌────────────────────────────────────────────────────────────────┐
│                    PARTY COORDINATION                           │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                 ROLE SYNCHRONIZATION                     │  │
│   │                                                          │  │
│   │   Tank ←──────→ DPS ←──────→ Healer                     │  │
│   │     ↑            ↑            ↑                          │  │
│   │     └────────────┴────────────┘                          │  │
│   │              Party Protocol                              │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   Communication Channels:                                       │
│   • Target marking (assist)                                    │
│   • Health status (heal requests)                              │
│   • Buff coordination (avoid duplicates)                       │
│   • Position sync (formations)                                 │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Party behaviors:**

| Behavior | Description |
|----------|-------------|
| **Assist targeting** | Attack party leader's target |
| **Heal priority** | Heal based on role and HP % |
| **Buff management** | Coordinate buffs to avoid waste |
| **Formation keeping** | Maintain tactical positions |
| **Emergency response** | React to party member threats |

**Configuration options:**

```yaml
party:
  enabled: true
  mode: follower          # leader, follower, or independent
  
  coordination:
    assist_leader: true
    assist_hotkey: null   # Or specific player name
    
  role_behavior:
    as_dps:
      wait_for_tank_aggro: true
      focus_marked_targets: true
    as_tank:
      pull_for_party: true
      position_between_party_and_mobs: true
    as_healer:
      prioritize_tank: true
      emergency_heal_threshold: 0.25
  
  buffs:
    coordinate_buffs: true
    request_buffs: true
    buff_priority:
      - Blessing
      - Increase AGI
      - Magnificat
  
  communication:
    respond_to_commands: true
    report_status: false
    commands:
      follow: true
      stay: true
      attack: true
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Basic coordination |
| GPU | Full | Supported |
| ML | Full | Learned coordination |
| LLM | Full | Communication handling |

---

### 6.5 Emergency Response System

**What it does:** Handles critical situations that require immediate action, including near-death, disconnection recovery, and threat detection.

**Why it matters:** Emergencies require fast, correct responses. A delayed or incorrect response to dying can result in lost experience, items, or worse. The emergency system ensures survival.

**Emergency priorities:**

```
┌────────────────────────────────────────────────────────────────┐
│                   EMERGENCY PRIORITY QUEUE                      │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   PRIORITY 1 (IMMEDIATE)                                        │
│   ├── Imminent death (HP < 10%)                                │
│   ├── GM detection (high confidence)                           │
│   └── Disconnect detected                                       │
│                                                                  │
│   PRIORITY 2 (URGENT)                                           │
│   ├── Low HP (< 30%)                                           │
│   ├── Overwhelmed (too many mobs)                              │
│   └── Dangerous player nearby                                   │
│                                                                  │
│   PRIORITY 3 (ELEVATED)                                         │
│   ├── Low resources (SP/potions)                               │
│   ├── Inventory full                                           │
│   └── Status effects                                           │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Emergency responses:**

| Emergency | Response |
|-----------|----------|
| **Near death** | Emergency heal, teleport, or flee |
| **Mob train** | Kite, emergency skills, or zone |
| **GM detected** | Stealth mode activation |
| **Disconnect** | Auto-reconnect with backoff |
| **Status effect** | Dispel or wait |
| **Trap/AoE** | Immediate movement |

**Configuration options:**

```yaml
emergency:
  enabled: true
  
  thresholds:
    critical_hp: 0.1
    danger_hp: 0.3
    low_sp: 0.1
    
  responses:
    critical_hp:
      - action: emergency_heal
        condition: "has_item('Yggdrasil Leaf')"
      - action: teleport
        condition: "has_skill('Teleport')"
      - action: flee
        condition: "always"
    
    mob_train:
      flee_threshold: 5        # Mobs attacking
      teleport_threshold: 8
      
    gm_detected:
      action: stealth_mode
      duration: 300
      
    disconnect:
      auto_reconnect: true
      max_attempts: 5
      backoff_seconds: [5, 15, 30, 60, 120]
      
  recovery:
    auto_recover_on_login: true
    return_to_previous_location: true
```

**Backend compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | Core feature |
| GPU | Full | Supported |
| ML | Full | Threat prediction |
| LLM | Partial | Situation analysis |

---

## 7. Compute Backend Options

God-Tier AI supports multiple compute backends to accommodate different hardware capabilities, performance requirements, and feature needs.

### 7.1 CPU-Only Mode

**Description:** Pure CPU execution using rule-based algorithms and statistical models. No GPU or external API required.

**Requirements:**

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 2 GB | 4+ GB |
| Python | 3.10+ | 3.11+ |
| Dependencies | NumPy, SciPy | Same |

**Capabilities:**

- ✅ All heuristic behaviors
- ✅ Statistical predictions
- ✅ Memory systems (all tiers)
- ✅ Anti-detection (timing/movement)
- ❌ Neural network inference
- ❌ Natural language generation
- ❌ Advanced pattern recognition

**Performance characteristics:**

| Metric | Typical Value |
|--------|---------------|
| Decision latency | < 5ms |
| Memory footprint | ~200 MB |
| CPU utilization | 5-15% per core |

**Configuration:**

```yaml
backend:
  primary: cpu
  fallback_chain: []
  
  cpu:
    threads: 4
    optimization_level: 2    # 0=none, 1=basic, 2=aggressive
```

**Best for:**

- Minimal hardware setups
- Maximum reliability (no external dependencies)
- Latency-critical applications
- Simple farming operations

---

### 7.2 GPU-Only Mode

**Description:** GPU-accelerated inference for neural network models, enabling advanced pattern recognition and prediction.

**Requirements:**

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| GPU | CUDA 11.0+ compatible | RTX 20xx+ |
| VRAM | 4 GB | 8+ GB |
| Python | 3.10+ | 3.11+ |
| Dependencies | PyTorch, CUDA Toolkit | Same |

**Capabilities:**

- ✅ All CPU capabilities
- ✅ Neural network inference
- ✅ Accelerated pathfinding
- ✅ Real-time behavior learning
- ❌ Natural language generation (use LLM for this)
- ⚠️ Requires GPU hardware

**Performance characteristics:**

| Metric | Typical Value |
|--------|---------------|
| Decision latency | < 50ms |
| VRAM usage | 1-4 GB |
| Power consumption | +50-150W |

**Configuration:**

```yaml
backend:
  primary: gpu
  fallback_chain: [cpu]
  
  gpu:
    device: "cuda:0"         # or "cuda:1" for second GPU
    precision: fp16          # fp32, fp16, or int8
    batch_size: 32
    memory_limit_gb: 4
```

**Best for:**

- Advanced combat optimization
- Real-time learning
- Complex prediction models
- Multi-bot coordination

---

### 7.3 Machine Learning Mode

**Description:** Uses pre-trained and continuously-trained ML models for decision-making, combining GPU inference with online learning.

**Requirements:**

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| GPU | CUDA compatible | RTX 30xx+ |
| VRAM | 6 GB | 12+ GB |
| Python | 3.10+ | 3.11+ |
| Dependencies | PyTorch, Stable-Baselines3 | Same |

**Capabilities:**

- ✅ All GPU capabilities
- ✅ Reinforcement learning
- ✅ Behavior cloning
- ✅ Continuous improvement
- ✅ Transfer learning
- ⚠️ Requires training data

**ML model types:**

| Model | Purpose | Training |
|-------|---------|----------|
| Combat Policy | Action selection | RL from gameplay |
| Target Selector | Priority scoring | Supervised learning |
| Path Optimizer | Navigation | Imitation learning |
| Threat Classifier | Danger assessment | Classification |

**Performance characteristics:**

| Metric | Typical Value |
|--------|---------------|
| Decision latency | < 20ms |
| Training time | Background |
| Model updates | Continuous |

**Configuration:**

```yaml
backend:
  primary: ml
  fallback_chain: [gpu, cpu]
  
  ml:
    framework: pytorch       # pytorch or tensorflow
    device: "cuda:0"
    
    models:
      combat:
        type: ppo            # ppo, dqn, a2c
        checkpoint: "./models/combat_latest.pt"
        update_frequency: 1000
      
      navigation:
        type: imitation
        checkpoint: "./models/navigation_latest.pt"
    
    training:
      enabled: true
      learning_rate: 0.0003
      buffer_size: 100000
      batch_size: 256
```

**Best for:**

- Long-term deployment
- Optimal performance after training
- Custom behavior development
- Research and experimentation

---

### 7.4 LLM API Mode (Azure, OpenAI, DeepSeek, Claude)

**Description:** Leverages large language models for complex reasoning, natural language interaction, and strategic planning.

**Overview:**

```
┌────────────────────────────────────────────────────────────────┐
│                      LLM API ARCHITECTURE                       │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                     AI SIDECAR                           │  │
│   │                                                          │  │
│   │   Game State → Prompt Template → API Request            │  │
│   │                                                          │  │
│   │   API Response → Parser → Action                        │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                           │                                     │
│                           ▼                                     │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐          │
│   │  Azure  │  │ OpenAI  │  │DeepSeek │  │ Claude  │          │
│   │ OpenAI  │  │         │  │         │  │         │          │
│   └─────────┘  └─────────┘  └─────────┘  └─────────┘          │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Provider comparison:**

| Provider | Strengths | Latency | Cost |
|----------|-----------|---------|------|
| **Azure OpenAI** | Enterprise security, compliance | 500-2000ms | $$$$ |
| **OpenAI** | Latest models, broad capability | 500-1500ms | $$$ |
| **DeepSeek** | Cost-effective, good reasoning | 1000-3000ms | $ |
| **Claude** | Nuanced reasoning, safety | 500-2000ms | $$$ |

**Capabilities (all providers):**

- ✅ Natural language chat responses
- ✅ Strategic reasoning and planning
- ✅ Context-aware decision making
- ✅ Quest dialogue handling
- ✅ Complex situation analysis
- ⚠️ Higher latency (not for reaction-critical)
- ⚠️ API costs
- ⚠️ Rate limits

---

#### Azure OpenAI Configuration

```yaml
backend:
  primary: llm
  fallback_chain: [ml, cpu]
  
  llm:
    provider: azure
    
    azure:
      endpoint: "https://your-resource.openai.azure.com/"
      api_version: "2024-02-15-preview"
      deployment_name: "gpt-4"
      # API key via environment: AZURE_OPENAI_API_KEY
      
      options:
        temperature: 0.7
        max_tokens: 1000
        timeout_seconds: 10
```

**Azure-specific considerations:**

- Requires Azure subscription and OpenAI resource
- Enterprise-grade security and compliance
- Regional deployment options
- Private endpoints available
- Higher cost but better SLAs

---

#### OpenAI Configuration

```yaml
backend:
  primary: llm
  fallback_chain: [ml, cpu]
  
  llm:
    provider: openai
    
    openai:
      model: "gpt-4-turbo-preview"
      # API key via environment: OPENAI_API_KEY
      
      options:
        temperature: 0.7
        max_tokens: 1000
        timeout_seconds: 10
        
      rate_limits:
        requests_per_minute: 60
        tokens_per_minute: 90000
```

**OpenAI-specific considerations:**

- Access to latest models
- Simple API, extensive documentation
- Pay-per-use pricing
- Rate limits vary by tier

---

#### DeepSeek Configuration

```yaml
backend:
  primary: llm
  fallback_chain: [ml, cpu]
  
  llm:
    provider: deepseek
    
    deepseek:
      model: "deepseek-chat"
      base_url: "https://api.deepseek.com/v1"
      # API key via environment: DEEPSEEK_API_KEY
      
      options:
        temperature: 0.7
        max_tokens: 1000
        timeout_seconds: 15
```

**DeepSeek-specific considerations:**

- Significantly lower cost
- Good reasoning capabilities
- Higher latency
- Less established than major providers

---

#### Claude Configuration

```yaml
backend:
  primary: llm
  fallback_chain: [ml, cpu]
  
  llm:
    provider: claude
    
    claude:
      model: "claude-3-sonnet-20240229"
      # API key via environment: ANTHROPIC_API_KEY
      
      options:
        temperature: 0.7
        max_tokens: 1000
        timeout_seconds: 10
```

**Claude-specific considerations:**

- Excellent at nuanced reasoning
- Strong safety alignment
- Good for complex social interactions
- Competitive pricing

---

**General LLM configuration:**

```yaml
llm:
  # Common settings for all providers
  cache:
    enabled: true
    ttl_seconds: 300
    max_entries: 1000
    
  prompts:
    system_prompt: |
      You are an AI assistant helping play Ragnarok Online.
      Respond with JSON containing "action" and "reasoning".
      Be concise and decisive.
    
    templates:
      combat: "./prompts/combat.txt"
      social: "./prompts/social.txt"
      strategy: "./prompts/strategy.txt"
  
  safety:
    anonymize_player_names: true
    filter_sensitive_content: true
    max_context_window: 4000
  
  fallback:
    on_timeout: use_fallback_backend
    on_error: use_fallback_backend
    on_rate_limit: queue_with_backoff
```

---

### 7.5 Hybrid Backend Modes

**Description:** Combines multiple compute backends to leverage the strengths of each, routing tasks to the most appropriate backend based on requirements.

**Why use hybrid modes?**

Different tasks have different requirements:
- Emergency decisions need sub-5ms latency (CPU)
- Combat optimization benefits from neural networks (GPU)
- Strategic planning needs reasoning capabilities (LLM)
- Predictions work best with trained models (ML)

Hybrid mode allows the system to route each task to the optimal backend.

**Supported Hybrid Mode Combinations:**

| Mode | Components | Use Case | Typical Latency |
|------|------------|----------|-----------------|
| `cpu` | CPU only | Basic decisions | <5ms |
| `gpu` | GPU only | Neural inference | <10ms |
| `ml` | ML models | Predictions | <20ms |
| `llm` | LLM API | Complex reasoning | <2000ms |
| `cpu+gpu` | CPU + GPU | Fast neural decisions | <15ms |
| `cpu+ml` | CPU + ML models | Hybrid predictions | <25ms |
| `cpu+gpu+ml` | CPU + GPU + ML | Full ML pipeline | <30ms |
| `cpu+llm` | CPU + LLM fallback | Strategic + fast | Variable |
| `cpu+gpu+llm` | Full stack | Maximum intelligence | Variable |
| `all` | All backends | Ultimate mode | Variable |

**Task Routing Configuration:**

```yaml
compute:
  mode: hybrid
  backends:
    - cpu
    - gpu
    - ml
  
  fallback_chain:
    - gpu
    - ml
    - cpu
  
  task_routing:
    # Emergency tasks need instant response
    emergency: cpu
    
    # Combat can use neural networks with CPU fallback
    combat: [gpu, cpu]
    
    # Predictions work best with ML models
    prediction: [ml, cpu]
    
    # Social interactions benefit from LLM
    social: [llm, cpu]
    
    # Strategic planning uses LLM with ML support
    planning: [llm, ml]
    
    # Navigation uses GPU-accelerated pathfinding
    navigation: [gpu, cpu]
    
    # Default for unspecified tasks
    default: [ml, gpu, cpu]
```

**Routing Decision Flow:**

```
┌────────────────────────────────────────────────────────────────┐
│                    HYBRID ROUTING ENGINE                        │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Incoming Task                                                  │
│        │                                                         │
│        ▼                                                         │
│   ┌─────────────────┐                                           │
│   │  Task Classifier │  Determine task type                     │
│   └────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐                                           │
│   │ Route Selection │  Check task_routing config                │
│   └────────┬────────┘                                           │
│            │                                                     │
│            ▼                                                     │
│   ┌─────────────────┐    ┌─────────────────┐                   │
│   │ Primary Backend │───▶│ Execute Task    │                   │
│   └────────┬────────┘    └────────┬────────┘                   │
│            │                      │                              │
│       [Failure]             [Success]                           │
│            │                      │                              │
│            ▼                      ▼                              │
│   ┌─────────────────┐    ┌─────────────────┐                   │
│   │ Fallback Chain  │    │ Return Result   │                   │
│   │ (next backend)  │    │                 │                   │
│   └─────────────────┘    └─────────────────┘                   │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**Advanced Configuration:**

```yaml
compute:
  mode: hybrid
  
  backends:
    cpu:
      enabled: true
      threads: 4
      
    gpu:
      enabled: true
      device: "cuda:0"
      precision: fp16
      
    ml:
      enabled: true
      models_path: "./models/"
      
    llm:
      enabled: true
      provider: openai
  
  routing:
    # Latency requirements (ms) - route to fastest capable backend
    latency_sensitive:
      max_latency_ms: 50
      preferred_backends: [cpu, gpu]
      
    # Quality requirements - route to smartest backend
    quality_sensitive:
      preferred_backends: [llm, ml]
      fallback_allowed: true
      
    # Cost optimization - prefer free backends
    cost_sensitive:
      preferred_backends: [cpu, gpu, ml]
      llm_budget_daily: 1.00  # USD
  
  load_balancing:
    enabled: true
    strategy: round_robin  # round_robin, least_loaded, weighted
    
  circuit_breaker:
    enabled: true
    failure_threshold: 5
    reset_timeout_seconds: 60
```

**Backend compatibility matrix for hybrid mode:**

| Feature | CPU | GPU | ML | LLM | Best Hybrid |
|---------|-----|-----|-----|-----|-------------|
| Combat decisions | ✅ | ✅✅ | ✅✅✅ | ⚠️ | ML+GPU |
| Emergency response | ✅✅✅ | ✅ | ✅ | ❌ | CPU only |
| Social interaction | ⚠️ | ⚠️ | ✅ | ✅✅✅ | LLM+CPU |
| Strategic planning | ⚠️ | ⚠️ | ✅✅ | ✅✅✅ | LLM+ML |
| Navigation | ✅✅ | ✅✅✅ | ✅ | ⚠️ | GPU+CPU |
| Predictions | ✅ | ✅✅ | ✅✅✅ | ⚠️ | ML+GPU |

Legend: ✅✅✅ = Excellent, ✅✅ = Good, ✅ = Adequate, ⚠️ = Suboptimal, ❌ = Not recommended

---

### 7.6 ML Models Catalog

**Description:** Pre-trained and trainable machine learning models available for the God-Tier AI system.

#### Decision Making Models (Reinforcement Learning)

| Model | Framework | Latency | Use Case | Training Required |
|-------|-----------|---------|----------|-------------------|
| **PPO** | Stable-Baselines3 | <5ms | Combat AI, general decisions | Yes (recommended) |
| **DQN** | Stable-Baselines3 | <3ms | Discrete action selection | Yes |
| **SAC** | Stable-Baselines3 | <5ms | Continuous control | Yes |
| **A2C** | Stable-Baselines3 | <4ms | Fast training, lower sample efficiency | Yes |
| **MAPPO** | MARLlib | <10ms | Party/Guild multi-agent coordination | Yes |

**PPO (Proximal Policy Optimization):**
- Best for: General combat decisions, skill usage
- Advantages: Stable training, good sample efficiency
- Configuration:
```yaml
ml:
  models:
    combat_ai:
      type: ppo
      path: models/combat_ppo.zip
      framework: stable-baselines3
      config:
        learning_rate: 0.0003
        n_steps: 2048
        batch_size: 64
        gamma: 0.99
        gae_lambda: 0.95
```

**DQN (Deep Q-Network):**
- Best for: Target selection, discrete choices
- Advantages: Simple, fast inference
- Configuration:
```yaml
ml:
  models:
    target_selector:
      type: dqn
      path: models/target_dqn.zip
      framework: stable-baselines3
      config:
        learning_rate: 0.0001
        buffer_size: 100000
        exploration_fraction: 0.1
```

#### Prediction Models (Supervised/Gradient Boosting)

| Model | Framework | Latency | Use Case | Training Data |
|-------|-----------|---------|----------|---------------|
| **LightGBM** | lightgbm | <1ms | Win probability, price prediction | Labeled examples |
| **XGBoost** | xgboost | <1ms | High-accuracy predictions | Labeled examples |
| **CatBoost** | catboost | <1ms | Categorical feature handling | Labeled examples |
| **Random Forest** | scikit-learn | <2ms | Ensemble predictions | Labeled examples |

**LightGBM Configuration:**
```yaml
ml:
  models:
    price_predictor:
      type: lightgbm
      path: models/price_predictor.txt
      framework: lightgbm
      config:
        objective: regression
        num_leaves: 31
        learning_rate: 0.05
        feature_fraction: 0.9
        
    threat_classifier:
      type: lightgbm
      path: models/threat_classifier.txt
      framework: lightgbm
      config:
        objective: binary
        num_leaves: 15
        learning_rate: 0.1
```

#### Inference Optimization

**ONNX Runtime (Cross-platform CPU/GPU):**
```yaml
ml:
  models:
    movement_predictor:
      type: onnx
      path: models/movement.onnx
      framework: onnxruntime
      providers:
        - CUDAExecutionProvider    # GPU (if available)
        - CPUExecutionProvider     # CPU fallback
      config:
        intra_op_num_threads: 4
        graph_optimization_level: 3  # ORT_ENABLE_ALL
```

**TorchAO Quantization (Size/Speed optimization):**
```yaml
ml:
  quantization:
    enabled: true
    method: torchao  # or native pytorch
    precision: int8  # int8, int4, fp16
    
  models:
    combat_ai_quantized:
      type: ppo
      path: models/combat_ppo_int8.pt
      quantized: true
      original_size_mb: 150
      quantized_size_mb: 40
      speedup: 2.5x
```

**TensorRT (NVIDIA GPU optimization):**
```yaml
ml:
  tensorrt:
    enabled: true
    workspace_size_mb: 1024
    precision: fp16
    
  models:
    combat_ai_trt:
      type: tensorrt
      path: models/combat_ai.trt
      framework: tensorrt
      config:
        max_batch_size: 32
        dla_core: -1  # Use GPU, not DLA
```

#### Complete ML Configuration Example

```yaml
ml:
  enabled: true
  
  # Model directory
  models_path: "./models/"
  
  # Inference settings
  inference:
    default_device: "cuda:0"  # or "cpu"
    batch_inference: true
    max_batch_size: 32
    timeout_ms: 100
    
  # Model definitions
  models:
    # Primary combat AI (PPO-based)
    combat_ai:
      type: ppo
      path: models/combat_ppo.zip
      framework: stable-baselines3
      device: "cuda:0"
      
    # Target selection (DQN-based)
    target_selector:
      type: dqn
      path: models/target_dqn.zip
      framework: stable-baselines3
      device: "cuda:0"
      
    # Price/value prediction (LightGBM)
    value_predictor:
      type: lightgbm
      path: models/value_predictor.txt
      framework: lightgbm
      device: "cpu"  # LightGBM is CPU-only
      
    # Movement prediction (ONNX for portability)
    movement_predictor:
      type: onnx
      path: models/movement.onnx
      framework: onnxruntime
      providers: [CUDAExecutionProvider, CPUExecutionProvider]
      
    # Threat assessment (XGBoost)
    threat_assessor:
      type: xgboost
      path: models/threat_xgb.json
      framework: xgboost
      device: "cpu"
  
  # Online training settings
  training:
    enabled: true
    checkpoint_interval: 10000  # steps
    checkpoint_path: "./checkpoints/"
    
    # Which models to train online
    trainable_models:
      - combat_ai
      - target_selector
      
    # Experience collection
    experience:
      buffer_size: 100000
      prioritized_replay: true
      
  # Model versioning
  versioning:
    enabled: true
    keep_versions: 5
    auto_rollback: true
    performance_threshold: 0.8  # Rollback if performance drops below
```

#### Model Performance Benchmarks

| Model | Inference Time | Memory | Accuracy | Training Time |
|-------|----------------|--------|----------|---------------|
| PPO (FP32) | 4.2ms | 150MB | Baseline | 24h |
| PPO (FP16) | 2.1ms | 80MB | -0.5% | 20h |
| PPO (INT8) | 1.1ms | 40MB | -2% | N/A |
| DQN | 1.8ms | 50MB | Baseline | 12h |
| LightGBM | 0.3ms | 5MB | Baseline | 10min |
| XGBoost | 0.4ms | 8MB | +1% | 15min |
| ONNX (CPU) | 2.5ms | 100MB | Same | N/A |
| ONNX (GPU) | 0.8ms | 100MB | Same | N/A |
| TensorRT | 0.5ms | 120MB | Same | N/A |

---

## 8. System Architecture Overview

### 8.1 High-Level Architecture

The God-Tier AI uses a sidecar architecture pattern, separating the decision-making intelligence from the game client interface.

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           GOD-TIER AI ARCHITECTURE                         │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────────┐         ZeroMQ          ┌─────────────────────────┐ │
│   │                 │         IPC             │      AI SIDECAR         │ │
│   │    OPENKORE     │◄───────────────────────►│       (Python)          │ │
│   │     (Perl)      │                         │                         │ │
│   │                 │   • State updates       │  ┌─────────────────┐    │ │
│   │  ┌───────────┐  │   • Action requests     │  │ Decision Engine │    │ │
│   │  │  Plugin   │  │   • Commands            │  └────────┬────────┘    │ │
│   │  │  Bridge   │  │                         │           │             │ │
│   │  └───────────┘  │                         │           ▼             │ │
│   │                 │                         │  ┌─────────────────┐    │ │
│   │  Game Protocol  │                         │  │ Memory Manager  │    │ │
│   │  Handling       │                         │  └────────┬────────┘    │ │
│   │                 │                         │           │             │ │
│   └────────┬────────┘                         │           ▼             │ │
│            │                                  │  ┌─────────────────┐    │ │
│            ▼                                  │  │ Backend Router  │    │ │
│   ┌─────────────────┐                         │  └────────┬────────┘    │ │
│   │   RO Server     │                         │           │             │ │
│   │                 │                         │     ┌─────┴─────┐       │ │
│   └─────────────────┘                         │     ▼     ▼     ▼       │ │
│                                               │   CPU   GPU   LLM      │ │
│                                               │                         │ │
│                                               └─────────────────────────┘ │
│                                                                            │
└───────────────────────────────────────────────────────────────────────────┘
```

**Component responsibilities:**

| Component | Language | Responsibility |
|-----------|----------|----------------|
| **OpenKore** | Perl | Game protocol, packet handling, execution |
| **Plugin Bridge** | Perl | State extraction, action injection |
| **ZeroMQ IPC** | N/A | Non-blocking inter-process communication |
| **AI Sidecar** | Python | Decision making, learning, memory |
| **Decision Engine** | Python | Core AI logic, behavior selection |
| **Memory Manager** | Python | Multi-tier memory management |
| **Backend Router** | Python | Compute backend selection and fallback |

---

### 8.2 Module Organization

```
godtier_ai/
├── __init__.py
├── main.py                    # Entry point, IPC server
│
├── core/                      # Core AI systems
│   ├── __init__.py
│   ├── decision_engine.py     # Main decision loop
│   ├── state_manager.py       # Game state management
│   ├── world_model.py         # Environment understanding
│   └── action_executor.py     # Action formatting/validation
│
├── behaviors/                 # Behavior modules
│   ├── __init__.py
│   ├── combat.py              # Combat decision making
│   ├── survival.py            # Health/safety management
│   ├── navigation.py          # Movement and pathing
│   ├── social.py              # Chat and interaction
│   ├── stealth.py             # Anti-detection behaviors
│   └── economy.py             # Economic decisions
│
├── learning/                  # Learning systems
│   ├── __init__.py
│   ├── experience_buffer.py   # Experience collection
│   ├── trainer.py             # Model training
│   ├── strategy_evolution.py  # Strategy adaptation
│   └── models/                # Neural network definitions
│       ├── combat_policy.py
│       └── target_selector.py
│
├── memory/                    # Memory systems
│   ├── __init__.py
│   ├── working_memory.py      # Short-term RAM storage
│   ├── session_memory.py      # Redis/cache layer
│   ├── persistent_memory.py   # SQLite/DB storage
│   └── schemas.py             # Data structure definitions
│
├── backends/                  # Compute backends
│   ├── __init__.py
│   ├── base.py                # Abstract backend interface
│   ├── cpu_backend.py         # CPU implementation
│   ├── gpu_backend.py         # GPU/CUDA implementation
│   └── ml_backend.py          # ML model backend
│
├── llm/                       # LLM integrations
│   ├── __init__.py
│   ├── base.py                # Abstract LLM interface
│   ├── azure_provider.py      # Azure OpenAI
│   ├── openai_provider.py     # OpenAI API
│   ├── deepseek_provider.py   # DeepSeek API
│   ├── claude_provider.py     # Anthropic Claude
│   └── prompt_manager.py      # Prompt templates
│
├── integration/               # OpenKore integration
│   ├── __init__.py
│   ├── ipc_server.py          # ZeroMQ server
│   ├── message_protocol.py    # Message format definitions
│   └── state_parser.py        # OpenKore state parsing
│
└── config/                    # Configuration
    ├── default.yaml           # Default settings
    ├── map_profiles/          # Per-map configurations
    │   ├── prt_fild01.yaml
    │   └── prontera.yaml
    └── prompts/               # LLM prompt templates
        ├── combat.txt
        └── social.txt
```

---

### 8.3 Data Flow

```mermaid
sequenceDiagram
    participant OK as OpenKore
    participant PB as Plugin Bridge
    participant IPC as ZeroMQ
    participant DE as Decision Engine
    participant MM as Memory Manager
    participant BE as Backend

    loop Every AI Tick (~100ms)
        OK->>PB: Game state update
        PB->>IPC: Serialize state
        IPC->>DE: State message
        
        DE->>MM: Query relevant memories
        MM-->>DE: Historical context
        
        DE->>BE: Decision request
        BE-->>DE: Recommended action
        
        DE->>MM: Store experience
        
        DE->>IPC: Action response
        IPC->>PB: Deserialize action
        PB->>OK: Execute action
    end
```

**Data flow stages:**

1. **State Collection**: OpenKore plugin extracts game state
2. **Serialization**: State converted to protocol buffers or JSON
3. **IPC Transport**: ZeroMQ delivers state to sidecar
4. **Context Enrichment**: Memory manager adds historical context
5. **Decision Making**: Backend processes state and returns action
6. **Experience Storage**: Outcome stored for learning
7. **Action Return**: Selected action sent back to OpenKore
8. **Execution**: OpenKore executes the action in-game

---

### 8.4 Async LLM Decision Architecture

**What it does:** Handles the latency mismatch between fast game ticks (100ms) and slow LLM API calls (500-2000ms) through non-blocking asynchronous processing.

**Why it matters:** LLM decisions provide superior reasoning but take 10-20x longer than the game tick rate. The async architecture ensures the bot remains responsive during LLM processing, with CPU handling immediate needs while LLM requests execute in the background.

**How it works:**

```
┌────────────────────────────────────────────────────────────────────┐
│              ASYNC LLM DECISION ARCHITECTURE                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Tick 0: State Captured                                             │
│   ├── CPU: Quick heuristic decision → EXECUTE IMMEDIATELY            │
│   └── LLM: Request queued → BACKGROUND PROCESSING                    │
│                                                                      │
│   Tick 1-20: (~100ms each, 2 seconds total)                          │
│   ├── CPU: Handles immediate combat needs                            │
│   ├── CPU: Emergency responses if needed                             │
│   └── LLM: Still processing request...                               │
│                                                                      │
│   Tick 21: LLM Response Arrives                                      │
│   ├── Validate: Is state still relevant?                             │
│   ├── Reconcile: Check if action still makes sense                   │
│   └── Execute or Discard: Based on current state                     │
│                                                                      │
└────────────────────────────────────────────────────────────────────┘
```

**Decision Flow Implementation:**

```python
import asyncio
from dataclasses import dataclass
from typing import Optional
from enum import Enum

class TaskPriority(Enum):
    EMERGENCY = 0    # Must be instant (CPU only)
    COMBAT = 1       # Should be fast (GPU/CPU)
    STRATEGIC = 2    # Can wait (LLM acceptable)
    SOCIAL = 3       # Non-critical (LLM preferred)

@dataclass
class PendingDecision:
    request_id: str
    original_state: dict
    task_type: TaskPriority
    timestamp: float
    future: asyncio.Future

class AsyncLLMManager:
    def __init__(self, llm_client, cpu_backend):
        self.llm_client = llm_client
        self.cpu_backend = cpu_backend
        self.pending_requests: dict[str, PendingDecision] = {}
        self.result_queue: asyncio.Queue = asyncio.Queue()
        
    async def request_decision(
        self,
        state: dict,
        task_type: TaskPriority
    ) -> Optional[dict]:
        """
        Non-blocking LLM request with CPU fallback for emergencies.
        """
        # Emergency tasks NEVER wait for LLM
        if task_type == TaskPriority.EMERGENCY:
            return self.cpu_backend.decide(state)
            
        # Start async LLM request
        request_id = f"req_{time.time()}"
        future = asyncio.create_task(
            self._llm_request(request_id, state)
        )
        
        self.pending_requests[request_id] = PendingDecision(
            request_id=request_id,
            original_state=state.copy(),
            task_type=task_type,
            timestamp=time.time(),
            future=future
        )
        
        # Return CPU decision immediately for non-blocking operation
        return self.cpu_backend.decide(state)
        
    async def _llm_request(self, request_id: str, state: dict):
        """Execute LLM request and queue result."""
        try:
            result = await self.llm_client.generate(state)
            await self.result_queue.put((request_id, result))
        except Exception as e:
            await self.result_queue.put((request_id, None))
            
    async def process_completed_requests(
        self,
        current_state: dict
    ) -> list[dict]:
        """
        Process completed LLM requests and reconcile with current state.
        Returns list of valid actions to execute.
        """
        valid_actions = []
        
        while not self.result_queue.empty():
            request_id, result = await self.result_queue.get()
            
            if request_id not in self.pending_requests:
                continue
                
            pending = self.pending_requests.pop(request_id)
            
            if result is None:
                continue  # LLM request failed
                
            # State reconciliation - check if action still valid
            if self._is_state_compatible(pending.original_state, current_state):
                valid_actions.append(result)
            else:
                # State changed too much, discard LLM decision
                pass
                
        return valid_actions
        
    def _is_state_compatible(
        self,
        original: dict,
        current: dict
    ) -> bool:
        """
        Check if LLM decision is still valid for current state.
        """
        # Critical state changes that invalidate decisions
        if original['player']['hp'] > 0 and current['player']['hp'] <= 0:
            return False  # Player died
            
        if original['map'] != current['map']:
            return False  # Changed maps
            
        # Target-specific checks
        if 'target_id' in original:
            original_target = original.get('target_id')
            current_monsters = {m['id'] for m in current.get('monsters', [])}
            if original_target not in current_monsters:
                return False  # Target no longer exists
                
        return True


class HybridDecisionMaker:
    """
    Combines instant CPU decisions with delayed LLM intelligence.
    """
    
    def __init__(self, config: dict):
        self.async_llm = AsyncLLMManager(
            llm_client=LLMClient(config['llm']),
            cpu_backend=CPUBackend(config['cpu'])
        )
        self.action_buffer = []
        
    async def tick(self, state: dict) -> dict:
        """
        Called every game tick (~100ms).
        Returns action to execute immediately.
        """
        # 1. Classify the situation
        task_type = self._classify_task(state)
        
        # 2. Get immediate CPU decision + queue LLM request
        immediate_action = await self.async_llm.request_decision(
            state, task_type
        )
        
        # 3. Process any completed LLM requests
        llm_actions = await self.async_llm.process_completed_requests(state)
        
        # 4. Buffer valid LLM actions for future use
        self.action_buffer.extend(llm_actions)
        
        # 5. Decide what to execute now
        if task_type == TaskPriority.EMERGENCY:
            return immediate_action  # Always use CPU for emergencies
            
        if self.action_buffer:
            # LLM action available and situation allows it
            return self.action_buffer.pop(0)
            
        return immediate_action
        
    def _classify_task(self, state: dict) -> TaskPriority:
        hp_percent = state['player']['hp'] / state['player']['hp_max']
        
        if hp_percent < 0.15:
            return TaskPriority.EMERGENCY
        elif state.get('in_combat'):
            return TaskPriority.COMBAT
        elif state.get('pending_social'):
            return TaskPriority.SOCIAL
        else:
            return TaskPriority.STRATEGIC
```

**Configuration:**

```yaml
async_llm:
  enabled: true
  
  # Request management
  max_pending_requests: 5
  request_timeout_seconds: 10
  
  # State reconciliation
  reconciliation:
    enabled: true
    max_state_age_ms: 3000  # Discard LLM decisions older than 3s
    critical_changes:
      - player_death
      - map_change
      - target_lost
      - combat_ended
  
  # Task routing
  routing:
    emergency: cpu_only
    combat: cpu_primary_llm_advisory
    strategic: llm_primary_cpu_fallback
    social: llm_only_with_timeout
  
  # Fallback behavior
  fallback:
    on_timeout: use_cpu
    on_error: use_cpu
    on_rate_limit: queue_with_exponential_backoff
```

**Backend compatibility:**

| Backend | Async Support | Notes |
|---------|---------------|-------|
| CPU | N/A | Always synchronous (instant) |
| GPU | N/A | Always synchronous (<50ms) |
| ML | N/A | Always synchronous (<20ms) |
| LLM | Full | Primary use case for async architecture |

---

### 8.5 Integration with OpenKore

The AI sidecar integrates with OpenKore through a custom plugin that hooks into key AI processing points.

**Key hooks used:**

| Hook | Trigger | Purpose |
|------|---------|---------|
| `AI_pre` | Before AI loop | Inject external decisions |
| `AI_post` | After AI loop | Execute sidecar actions |
| `checkMonsterAutoAttack` | Target evaluation | Override target selection |
| `packet_pre` | Incoming packets | State extraction |
| `mainLoop_pre` | Main loop start | Timing synchronization |

**Plugin bridge example (Perl):**

```perl
# plugins/godtier_bridge.pl
package GodTierBridge;

use strict;
use warnings;
use Plugins;
use Globals;
use Log qw(message);
use JSON::XS;
use ZMQ::FFI;
use ZMQ::FFI::Constants qw(ZMQ_REQ ZMQ_DONTWAIT);

my $zmq_context;
my $zmq_socket;
my $connected = 0;

Plugins::register('godtier_bridge', 'God-Tier AI Bridge', \&onUnload);

# Hook registrations
my $hooks = Plugins::addHooks(
    ['AI_pre', \&onAIPre],
    ['AI_post', \&onAIPost],
    ['checkMonsterAutoAttack', \&onCheckTarget],
);

sub connect_to_sidecar {
    return if $connected;
    
    $zmq_context = ZMQ::FFI->new();
    $zmq_socket = $zmq_context->socket(ZMQ_REQ);
    $zmq_socket->connect("tcp://127.0.0.1:5555");
    $connected = 1;
    
    message "[GodTier] Connected to AI sidecar\n", "info";
}

sub onAIPre {
    connect_to_sidecar() unless $connected;
    
    # Send current state to sidecar
    my $state = extract_game_state();
    $zmq_socket->send(encode_json($state));
    
    # Receive decision (non-blocking with timeout)
    my $response = $zmq_socket->recv(ZMQ_DONTWAIT);
    if ($response) {
        my $decision = decode_json($response);
        apply_decision($decision);
    }
}

sub extract_game_state {
    return {
        timestamp => time(),
        player => {
            hp => $char->{hp},
            hp_max => $char->{hp_max},
            sp => $char->{sp},
            sp_max => $char->{sp_max},
            pos => { x => $char->{pos}{x}, y => $char->{pos}{y} },
            map => $field->baseName,
        },
        monsters => [map { monster_to_hash($_) } @{$monstersList->getItems()}],
        players => [map { player_to_hash($_) } @{$playersList->getItems()}],
    };
}

# ... additional implementation
```

---

## 9. Memory Architecture

### 9.1 Working Memory (Short-term)

**Purpose:** Stores immediately relevant information for the current combat encounter or activity.

**Characteristics:**

| Property | Value |
|----------|-------|
| Storage | RAM (in-process) |
| TTL | 5-30 seconds |
| Access latency | < 1ms |
| Capacity | ~1000 entries |

**Data stored:**

```python
# Example working memory structure
working_memory = {
    "current_target": {
        "id": 12345,
        "name": "Poring",
        "hp_percent": 0.45,
        "distance": 3,
        "threat_level": 0.1,
        "expires_at": 1700000000
    },
    "active_cooldowns": {
        "Bash": 1700000002,
        "Magnum Break": 1700000010
    },
    "recent_damage": [
        {"source": "Poring", "amount": 15, "time": 1699999995},
        {"source": "Poring", "amount": 12, "time": 1699999997}
    ],
    "combat_state": "engaged",
    "attention_focus": "primary_target"
}
```

**Configuration:**

```yaml
memory:
  working:
    enabled: true
    max_entries: 1000
    default_ttl_seconds: 10
    
    categories:
      combat:
        ttl: 5
        priority: high
      navigation:
        ttl: 30
        priority: medium
      social:
        ttl: 60
        priority: low
```

---

### 9.2 Session Memory (DragonFlyDB)

**Purpose:** Stores patterns and statistics for the current play session.

**Characteristics:**

| Property | Value |
|----------|-------|
| Storage | Redis or in-memory cache |
| TTL | Session duration |
| Access latency | 1-10ms |
| Capacity | ~10,000 entries |

**Data stored:**

```python
# Example session memory structure
session_memory = {
    "kill_statistics": {
        "Poring": {"count": 45, "avg_time": 2.3, "drops": ["Jellopy", "Apple"]},
        "Drops": {"count": 12, "avg_time": 3.1, "drops": ["Jellopy", "Orange"]}
    },
    "path_efficiency": {
        "prt_fild01": {
            "routes": {
                "(100,100)-(150,150)": {"avg_time": 5.2, "obstacles": 0},
                "(100,100)-(200,100)": {"avg_time": 8.1, "obstacles": 2}
            }
        }
    },
    "player_interactions": {
        "PlayerName123": {
            "encounters": 3,
            "behavior": "neutral",
            "last_seen": 1700000000
        }
    },
    "threat_history": [
        {"entity": "MVP Poring", "time": 1699990000, "outcome": "fled"},
        {"entity": "Aggressive Player", "time": 1699995000, "outcome": "avoided"}
    ]
}
```

**Configuration:**

```yaml
memory:
  session:
    backend: redis          # redis, memory, or file
    
    redis:
      url: "redis://localhost:6379/0"
      password: null
      db: 0
      
    file:
      path: "./data/session_cache.json"
      
    settings:
      max_patterns: 5000
      compression: true
```

---

### 9.3 Persistent Memory (Long-term)

**Purpose:** Stores permanent knowledge accumulated across all sessions.

**Characteristics:**

| Property | Value |
|----------|-------|
| Storage | SQLite or PostgreSQL |
| TTL | Permanent (with pruning) |
| Access latency | 5-50ms |
| Capacity | Unlimited (disk) |

**Data stored:**

- Map knowledge (spawn points, safe zones, paths)
- Player reputation database
- Long-term performance statistics
- Learned strategies and behaviors
- Event history and outcomes

**Database schema (simplified):**

```sql
-- Map knowledge
CREATE TABLE map_knowledge (
    map_name TEXT PRIMARY KEY,
    spawn_points JSON,
    danger_zones JSON,
    optimal_paths JSON,
    last_updated TIMESTAMP
);

-- Player reputation
CREATE TABLE player_reputation (
    player_name TEXT PRIMARY KEY,
    reputation_score REAL DEFAULT 0,
    interaction_count INTEGER DEFAULT 0,
    last_interaction TIMESTAMP,
    notes JSON
);

-- Performance statistics
CREATE TABLE performance_stats (
    id INTEGER PRIMARY KEY,
    date DATE,
    map_name TEXT,
    metric_name TEXT,
    metric_value REAL,
    UNIQUE(date, map_name, metric_name)
);

-- Learned strategies
CREATE TABLE learned_strategies (
    strategy_id TEXT PRIMARY KEY,
    domain TEXT,
    conditions JSON,
    actions JSON,
    success_rate REAL,
    usage_count INTEGER
);
```

**Configuration:**

```yaml
memory:
  persistent:
    backend: sqlite         # sqlite or postgresql
    
    sqlite:
      path: "./data/memory.db"
      
    postgresql:
      host: localhost
      port: 5432
      database: godtier_memory
      user: godtier
      # Password via environment: PGPASSWORD
      
    settings:
      consolidation_interval: 300  # seconds
      retention_days: 90
      vacuum_on_startup: true
```

---

### 9.4 Data Schemas

**State message schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "GameState",
  "type": "object",
  "required": ["timestamp", "player", "map"],
  "properties": {
    "timestamp": {
      "type": "integer",
      "description": "Unix timestamp in milliseconds"
    },
    "player": {
      "type": "object",
      "required": ["hp", "hp_max", "sp", "sp_max", "pos"],
      "properties": {
        "hp": {"type": "integer"},
        "hp_max": {"type": "integer"},
        "sp": {"type": "integer"},
        "sp_max": {"type": "integer"},
        "pos": {
          "type": "object",
          "properties": {
            "x": {"type": "integer"},
            "y": {"type": "integer"}
          }
        }
      }
    },
    "map": {"type": "string"},
    "monsters": {
      "type": "array",
      "items": {"$ref": "#/definitions/monster"}
    },
    "players": {
      "type": "array",
      "items": {"$ref": "#/definitions/player"}
    }
  },
  "definitions": {
    "monster": {
      "type": "object",
      "properties": {
        "id": {"type": "integer"},
        "name": {"type": "string"},
        "hp_percent": {"type": "number"},
        "pos": {"type": "object"},
        "target": {"type": ["integer", "null"]}
      }
    },
    "player": {
      "type": "object",
      "properties": {
        "id": {"type": "integer"},
        "name": {"type": "string"},
        "guild": {"type": ["string", "null"]},
        "pos": {"type": "object"}
      }
    }
  }
}
```

**Action message schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AIAction",
  "type": "object",
  "required": ["action_type"],
  "properties": {
    "action_type": {
      "type": "string",
      "enum": ["attack", "skill", "move", "item", "wait", "emergency"]
    },
    "target_id": {"type": ["integer", "null"]},
    "skill_id": {"type": ["integer", "null"]},
    "position": {
      "type": ["object", "null"],
      "properties": {
        "x": {"type": "integer"},
        "y": {"type": "integer"}
      }
    },
    "item_id": {"type": ["integer", "null"]},
    "priority": {"type": "number", "minimum": 0, "maximum": 1},
    "reasoning": {"type": "string"}
  }
}
```

---

## 10. Configuration Guide

### 10.1 Main Configuration

The main configuration file (`config/godtier.yaml`) controls all aspects of the AI system.

**Full configuration template:**

```yaml
# God-Tier AI Configuration
# Version: 1.0.0

#=============================================================================
# GENERAL SETTINGS
#=============================================================================
general:
  enabled: true
  log_level: info           # debug, info, warning, error
  log_file: "./logs/godtier.log"
  tick_rate_ms: 100         # AI decision frequency

#=============================================================================
# BACKEND CONFIGURATION
#=============================================================================
backend:
  primary: ml               # cpu, gpu, ml, or llm
  fallback_chain: [gpu, cpu]
  
  cpu:
    threads: 4
    
  gpu:
    device: "cuda:0"
    precision: fp16
    
  ml:
    framework: pytorch
    models_path: "./models/"
    
  llm:
    provider: openai        # azure, openai, deepseek, claude
    # Provider-specific config below

#=============================================================================
# MEMORY CONFIGURATION
#=============================================================================
memory:
  working:
    enabled: true
    max_entries: 1000
    default_ttl_seconds: 10
    
  session:
    backend: redis
    redis_url: "redis://localhost:6379/0"
    
  persistent:
    backend: sqlite
    sqlite_path: "./data/memory.db"

#=============================================================================
# BEHAVIOR CONFIGURATION
#=============================================================================
behaviors:
  adaptive:
    enabled: true
    learning_rate: 0.1
    
  combat:
    enabled: true
    role: auto_detect
    aggression: 0.7
    
  survival:
    enabled: true
    retreat_threshold: 0.3
    emergency_teleport: true
    
  navigation:
    enabled: true
    optimization: balanced
    
  social:
    enabled: true
    personality: friendly
    chat_enabled: false
    
  stealth:
    enabled: true
    humanization_level: high

#=============================================================================
# ANTI-DETECTION CONFIGURATION
#=============================================================================
anti_detection:
  enabled: true
  paranoia_level: medium
  
  timing:
    base_delay_ms: 200
    variance_ms: 150
    
  movement:
    use_bezier: true
    
  session:
    max_continuous_hours: 4

#=============================================================================
# MAP PROFILES
#=============================================================================
map_profiles:
  _default:
    combat_style: balanced
    
  # Specific maps loaded from config/map_profiles/

#=============================================================================
# SECURITY
#=============================================================================
security:
  api_keys:
    storage: environment    # environment, keyring, or file
  privacy:
    anonymize_players: true
```

---

### 10.2 Backend Selection

Choose the appropriate backend based on your hardware and requirements:

**Decision flowchart:**

```mermaid
flowchart TD
    A[Start] --> B{Need natural<br/>language?}
    B -->|Yes| C[LLM Mode]
    B -->|No| D{Have GPU?}
    
    D -->|Yes| E{Need<br/>learning?}
    D -->|No| F[CPU Mode]
    
    E -->|Yes| G[ML Mode]
    E -->|No| H[GPU Mode]
    
    C --> I[Configure LLM provider]
    G --> J[Configure training]
    H --> K[Configure CUDA]
    F --> L[Configure threads]
```

**Backend selection matrix:**

| Requirement | Recommended Backend |
|-------------|---------------------|
| Minimal hardware | CPU |
| Fast reactions | CPU or GPU |
| Learning capability | ML |
| Natural chat | LLM |
| Best overall | ML with LLM fallback |

---

### 10.3 Behavior Tuning

Fine-tune AI behaviors for your playstyle:

**Combat aggression levels:**

| Level | Value | Description |
|-------|-------|-------------|
| Passive | 0.0-0.3 | Only attack when attacked |
| Defensive | 0.3-0.5 | Attack nearby threats |
| Balanced | 0.5-0.7 | Active hunting, cautious |
| Aggressive | 0.7-0.9 | Actively seek combat |
| Berserker | 0.9-1.0 | Maximum aggression |

**Survival priority levels:**

| Level | Value | Description |
|-------|-------|-------------|
| Risky | 0.1-0.3 | Low retreat threshold |
| Normal | 0.3-0.5 | Balanced survival |
| Cautious | 0.5-0.7 | High retreat threshold |
| Paranoid | 0.7-0.9 | Extremely conservative |

**Example behavior tuning:**

```yaml
behaviors:
  combat:
    role: dps
    aggression: 0.7
    
    target_selection:
      priority: lowest_hp      # lowest_hp, nearest, highest_threat
      blacklist: ["MVP *"]     # Never attack MVPs
      whitelist: []            # If set, only attack these
      
    skills:
      use_aoe_threshold: 3     # Mobs before using AoE
      conserve_sp: true
      sp_threshold: 0.3
      
    positioning:
      preferred_range: 3       # Tiles from target
      kiting_enabled: true
      
  survival:
    retreat_threshold: 0.3
    emergency_threshold: 0.1
    
    healing:
      auto_heal: true
      heal_threshold: 0.5
      potion_threshold: 0.4
      
    emergency:
      teleport_enabled: true
      butterfly_wing: true
      emergency_call: false    # Party emergency
```

---

### 10.4 Map Profiles

Create per-map configurations in `config/map_profiles/`:

**Example: prt_fild01.yaml**

```yaml
# Prontera Field 01 - Beginner farming map
map_name: prt_fild01
map_type: field

strategy:
  mode: farming
  optimization: exp_per_hour
  
combat:
  enabled: true
  aggression: 0.8
  
  monster_priorities:
    - name: Poring
      priority: 1.0
      notes: "Easy exp, common drops"
    - name: Drops
      priority: 0.9
      notes: "Slightly better drops"
    - name: Lunatic
      priority: 0.7
      notes: "Lower priority"
      
  avoid_monsters:
    - name: "Poring King"
      reason: "Too dangerous for farming"
      
navigation:
  patrol_points:
    - [100, 150]
    - [150, 150]
    - [150, 200]
    - [100, 200]
  patrol_mode: cycle        # cycle, random, or nearest
  
  avoid_areas:
    - name: "Busy corner"
      coords: [0, 0, 50, 50]
      reason: "Too many players"
      
social:
  mode: minimal
  avoid_player_range: 10    # Stay away from other players
  
timing:
  best_hours: [22, 6]       # Late night/early morning
  avoid_hours: [14, 18]     # Peak hours
```

---

### 10.5 LLM Provider Setup

#### Environment Variables

Store API keys securely in environment variables:

```bash
# .env file (never commit this!)

# OpenAI
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Azure OpenAI
AZURE_OPENAI_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/

# DeepSeek
DEEPSEEK_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

#### Provider-specific setup

**OpenAI setup:**

1. Create account at platform.openai.com
2. Generate API key in Settings → API Keys
3. Set `OPENAI_API_KEY` environment variable
4. Configure in `godtier.yaml`:

```yaml
llm:
  provider: openai
  openai:
    model: "gpt-4-turbo-preview"
    options:
      temperature: 0.7
      max_tokens: 1000
```

**Azure OpenAI setup:**

1. Create Azure subscription
2. Create OpenAI resource in Azure Portal
3. Deploy desired model
4. Copy endpoint and key
5. Configure:

```yaml
llm:
  provider: azure
  azure:
    endpoint: "https://your-resource.openai.azure.com/"
    deployment_name: "gpt-4"
    api_version: "2024-02-15-preview"
```

**DeepSeek setup:**

1. Create account at platform.deepseek.com
2. Generate API key
3. Configure:

```yaml
llm:
  provider: deepseek
  deepseek:
    model: "deepseek-chat"
    base_url: "https://api.deepseek.com/v1"
```

**Claude setup:**

1. Create account at console.anthropic.com
2. Generate API key
3. Configure:

```yaml
llm:
  provider: claude
  claude:
    model: "claude-3-sonnet-20240229"
```

---

### 10.6 LLM Custom Prompts

**What it does:** Allows users to define custom prompts for different AI decision contexts, enabling personalized behavior, roleplay, and specialized responses.

**Why it matters:** Different users have different needs - some want efficient farming, others want roleplay, others want specific personality traits. Custom prompts enable this flexibility without code changes.

**Available Prompt Contexts:**

| Context | Purpose | When Used |
|---------|---------|-----------|
| `decision_making` | Tactical decisions | Combat, navigation, resource usage |
| `social_response` | Chat replies | Player interactions, whispers |
| `strategic_planning` | Long-term goals | Session planning, objective setting |
| `npc_dialogue` | Quest conversations | NPC interaction, quest choices |
| `emergency_reasoning` | Crisis analysis | Near-death, GM detection |

**Configuration Example:**

```yaml
llm:
  enabled: true
  provider: openai
  model: gpt-4o-mini
  
  # User-defined custom prompts
  custom_prompts:
    # Tactical decision making
    decision_making: |
      You are an expert Ragnarok Online player making tactical decisions.
      
      Current situation:
      - HP: {hp_percent}%
      - SP: {sp_percent}%
      - Location: {map_name} ({x}, {y})
      - Nearby monsters: {monster_count}
      - Nearby players: {player_count}
      
      Available actions: {available_actions}
      Objective: {current_objective}
      Optimize for: {optimization_goal}
      
      Respond with JSON: {"action": "action_name", "target": "target_id", "reasoning": "brief reason"}
    
    # Social chat response
    social_response: |
      You are {character_name}, a level {level} {job_class} in Ragnarok Online.
      
      Personality traits: {personality_traits}
      Current activity: {current_activity}
      Relationship with speaker: {relationship_status}
      
      Recent conversation:
      {conversation_history}
      
      Respond to this message naturally and in-character: "{incoming_message}"
      
      Guidelines:
      - Use casual MMO speech (abbreviations like "u", "rn", "lol")
      - Keep response under 100 characters
      - Stay in character
      - Match the energy of the conversation
      - Use emoticons sparingly (:) ^^ xD)
      
    # Strategic session planning
    strategic_planning: |
      Analyze the current game state and suggest optimal strategy.
      
      Character: {character_name} - Level {level} {job_class}
      Current map: {map_name}
      
      Resources:
      - Inventory: {inventory_summary}
      - Zeny: {zeny}
      - Weight: {weight_percent}%
      
      Goals: {current_objectives}
      Time available: {session_duration}
      Constraints: {limitations}
      
      Provide a prioritized action plan in JSON format:
      {"plan": [{"action": "...", "duration": "...", "priority": 1-5}]}
      
    # NPC dialogue handling
    npc_dialogue: |
      You are navigating an NPC dialogue in Ragnarok Online.
      
      NPC: {npc_name}
      Location: {npc_location}
      Purpose: {npc_type}
      
      Current dialogue:
      {npc_text}
      
      Available options:
      {dialogue_options}
      
      Quest context: {quest_info}
      Objective: {dialogue_goal}
      
      Select the best option number and explain why.
      Response format: {"choice": 1, "reasoning": "..."}
      
    # Emergency situation analysis
    emergency_reasoning: |
      EMERGENCY SITUATION - Rapid decision required.
      
      Threat level: {threat_level}
      HP: {hp_percent}% ({hp}/{hp_max})
      SP: {sp_percent}%
      
      Immediate threats:
      {threat_list}
      
      Available emergency actions:
      - Teleport (if available): {has_teleport}
      - Butterfly Wing: {has_butterfly}
      - Emergency heal items: {heal_items}
      - Flee direction: {safe_directions}
      
      Current position relative to safety:
      - Nearest safe zone: {safe_zone_distance} tiles
      - Nearest portal: {portal_distance} tiles
      
      Decide the safest immediate action.
      Response: {"action": "...", "priority": "critical/high/medium"}
```

**Template Variables:**

| Variable | Description | Example |
|----------|-------------|---------|
| `{character_name}` | Bot's character name | "MyKnight" |
| `{level}` | Base level | 99 |
| `{job_class}` | Job class name | "Lord Knight" |
| `{hp_percent}` | Current HP percentage | 75 |
| `{sp_percent}` | Current SP percentage | 50 |
| `{map_name}` | Current map | "prt_fild01" |
| `{personality_traits}` | Custom personality | "friendly, helpful, slightly sarcastic" |
| `{conversation_history}` | Recent chat messages | Auto-populated |
| `{available_actions}` | Valid actions | ["attack", "skill", "flee", "use_item"] |
| `{current_objective}` | Active goal | "Farm Porings for Jellopy" |

**Advanced: Conditional Prompts:**

```yaml
llm:
  custom_prompts:
    social_response:
      # Different prompts based on context
      default: |
        Standard response prompt...
        
      guild_member: |
        You're talking to a fellow guild member.
        Be more casual and friendly...
        
      stranger: |
        A stranger is talking to you.
        Be polite but cautious...
        
      known_enemy: |
        This player has attacked you before.
        Be dismissive or ignore...
        
  # Prompt selection rules
  prompt_routing:
    social_response:
      - condition: "speaker_guild == my_guild"
        prompt: guild_member
      - condition: "speaker in enemy_list"
        prompt: known_enemy
      - condition: "relationship_score < 0"
        prompt: stranger
      - condition: "default"
        prompt: default
```

**Prompt Testing Tool:**

```bash
# Test a custom prompt without running the full bot
python -m godtier.tools.prompt_tester \
  --prompt social_response \
  --variables '{"character_name": "TestKnight", "incoming_message": "hey"}' \
  --provider openai \
  --model gpt-4o-mini
```

---

## 11. Security Considerations

### 11.1 API Key Management

**Best practices:**

| Practice | Priority | Implementation |
|----------|----------|----------------|
| Never hardcode keys | Critical | Use environment variables |
| Rotate keys regularly | High | Every 90 days minimum |
| Use least privilege | High | Scope keys to needed permissions |
| Monitor usage | Medium | Set up billing alerts |
| Encrypt at rest | Medium | Use OS keyring |

**Environment variable setup:**

```bash
# Linux/macOS - Add to ~/.bashrc or ~/.zshrc
export OPENAI_API_KEY="your-key-here"

# Windows PowerShell - Add to $PROFILE
$env:OPENAI_API_KEY = "your-key-here"

# Or use a .env file (add to .gitignore!)
```

**OS Keyring integration:**

```yaml
security:
  api_keys:
    storage: keyring        # Use OS secure storage
    keyring_service: "godtier-ai"
```

```python
# Setting keys via keyring (one-time setup)
import keyring
keyring.set_password("godtier-ai", "openai", "sk-your-key-here")
```

---

### 11.2 Privacy Protections

**Data anonymization:**

The system anonymizes sensitive data before sending to LLM providers:

```python
# Example anonymization
original_prompt = "Player 'RealUsername123' is attacking me"
anonymized = "Player 'PLAYER_001' is attacking me"

# Mapping stored locally for de-anonymization
mapping = {"PLAYER_001": "RealUsername123"}
```

**Privacy configuration:**

```yaml
security:
  privacy:
    anonymize_players: true
    anonymize_guild: true
    exclude_coordinates: false  # Coords needed for navigation
    exclude_inventory: true     # Don't send item details to LLM
    
    llm_data_retention:
      allow_logging: false      # Request no server-side logging
      max_context_history: 5    # Limit conversation history
```

---

### 11.3 Anti-Detection Measures

**Layered protection approach:**

```
┌────────────────────────────────────────────────────────────────┐
│                   ANTI-DETECTION LAYERS                         │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Layer 4: Session Management                                   │
│   ├── Realistic play schedules                                 │
│   ├── Natural break patterns                                   │
│   └── Varied daily routines                                    │
│                                                                  │
│   Layer 3: Behavioral Humanization                             │
│   ├── Timing variance on all actions                           │
│   ├── Occasional "mistakes"                                    │
│   └── Social interactions                                      │
│                                                                  │
│   Layer 2: Movement Humanization                               │
│   ├── Bezier curve paths                                       │
│   ├── Random pauses and adjustments                            │
│   └── Non-optimal route choices                                │
│                                                                  │
│   Layer 1: GM Detection & Response                             │
│   ├── Entity analysis                                          │
│   ├── Behavior pattern detection                               │
│   └── Automatic mode switching                                 │
│                                                                  │
└────────────────────────────────────────────────────────────────┘
```

**GM detection indicators:**

| Indicator | Weight | Description |
|-----------|--------|-------------|
| Name pattern | 0.9 | Names like "GM_", "[Admin]" |
| Hidden sprite | 0.8 | Invisible or special sprites |
| Teleport pattern | 0.7 | Sudden appearance/movement |
| Following behavior | 0.6 | Entity follows player |
| Unusual equipment | 0.5 | GM-only items visible |

**Response modes:**

| Mode | Trigger | Behavior |
|------|---------|----------|
| Normal | Default | Full functionality |
| Cautious | Low suspicion | Reduced efficiency, more randomness |
| Stealth | Medium suspicion | Natural movement, fake activities |
| Safe | High suspicion | Stop automation, simulate AFK |
| Emergency | Immediate threat | Log off or safe zone |

---

## 12. Extensibility

### 12.1 Creating Custom Behaviors

**Behavior module template:**

```python
# behaviors/custom_behavior.py

from behaviors.base import BaseBehavior, BehaviorResult
from core.state_manager import GameState
from core.action_executor import Action

class CustomBehavior(BaseBehavior):
    """
    Custom behavior implementation.
    
    Behaviors are evaluated in priority order. Return BehaviorResult
    with an action to execute, or None to defer to next behavior.
    """
    
    def __init__(self, config: dict):
        super().__init__(config)
        self.priority = config.get('priority', 0.5)
        self.enabled = config.get('enabled', True)
        
    def evaluate(self, state: GameState) -> BehaviorResult | None:
        """
        Evaluate current state and decide on action.
        
        Args:
            state: Current game state
            
        Returns:
            BehaviorResult with action, or None to skip
        """
        if not self.should_activate(state):
            return None
            
        action = self.decide_action(state)
        confidence = self.calculate_confidence(state)
        
        return BehaviorResult(
            action=action,
            confidence=confidence,
            reasoning="Custom behavior activated because..."
        )
        
    def should_activate(self, state: GameState) -> bool:
        """Determine if this behavior should activate."""
        # Implement activation conditions
        return True
        
    def decide_action(self, state: GameState) -> Action:
        """Decide what action to take."""
        # Implement action selection logic
        return Action(action_type="wait")
        
    def calculate_confidence(self, state: GameState) -> float:
        """Calculate confidence in the decision."""
        return 0.8
```

**Registering custom behavior:**

```yaml
# config/godtier.yaml
behaviors:
  custom:
    enabled: true
    module: "behaviors.custom_behavior.CustomBehavior"
    priority: 0.6
    config:
      custom_param: value
```

---

### 12.2 Adding New Backends

**Backend interface:**

```python
# backends/base.py

from abc import ABC, abstractmethod
from typing import Any
from core.state_manager import GameState
from core.action_executor import Action

class BaseBackend(ABC):
    """Abstract base class for compute backends."""
    
    def __init__(self, config: dict):
        self.config = config
        
    @abstractmethod
    def initialize(self) -> None:
        """Initialize backend resources."""
        pass
        
    @abstractmethod
    def decide(self, state: GameState, context: dict) -> Action:
        """
        Make a decision based on current state.
        
        Args:
            state: Current game state
            context: Additional context from memory
            
        Returns:
            Action to execute
        """
        pass
        
    @abstractmethod
    def shutdown(self) -> None:
        """Clean up backend resources."""
        pass
        
    @property
    @abstractmethod
    def capabilities(self) -> dict:
        """Return backend capabilities."""
        pass
```

**Example custom backend:**

```python
# backends/custom_backend.py

from backends.base import BaseBackend

class CustomBackend(BaseBackend):
    """Custom backend implementation."""
    
    def initialize(self):
        # Load models, connect to services, etc.
        pass
        
    def decide(self, state, context):
        # Implement decision logic
        pass
        
    def shutdown(self):
        # Clean up
        pass
        
    @property
    def capabilities(self):
        return {
            "combat": True,
            "learning": False,
            "social": False,
            "latency_ms": 10
        }
```

---

### 12.3 Plugin Development

**OpenKore plugin extension points:**

```perl
# plugins/godtier_extension.pl

package GodTierExtension;

use strict;
use Plugins;
use Globals;

# Register plugin
Plugins::register('godtier_extension', 'Custom Extension', \&onUnload);

# Add hooks
my $hooks = Plugins::addHooks(
    ['godtier_pre_decision', \&onPreDecision],
    ['godtier_post_action', \&onPostAction],
);

sub onPreDecision {
    my ($hook, $args) = @_;
    # Modify state before AI decision
    # $args->{state} contains game state
}

sub onPostAction {
    my ($hook, $args) = @_;
    # React to AI actions
    # $args->{action} contains chosen action
}

sub onUnload {
    Plugins::delHooks($hooks);
}

1;
```

**Python sidecar plugins:**

```python
# plugins/custom_plugin.py

from core.plugin_base import Plugin

class CustomPlugin(Plugin):
    """Custom sidecar plugin."""
    
    name = "custom_plugin"
    version = "1.0.0"
    
    def on_load(self):
        """Called when plugin is loaded."""
        self.register_hook('pre_decision', self.pre_decision)
        self.register_hook('post_action', self.post_action)
        
    def pre_decision(self, state, context):
        """Modify state/context before decision."""
        return state, context
        
    def post_action(self, action, state):
        """React to or modify action."""
        return action
        
    def on_unload(self):
        """Clean up on unload."""
        pass
```

---

## 13. Limitations & Disclaimers

Understanding the constraints and risks of the God-Tier AI system is essential for effective deployment and realistic expectations.

### 13.1 Performance Expectations

| Aspect | Reality | Notes |
|--------|---------|-------|
| **Initial Performance** | Suboptimal | Bot requires learning time to achieve good performance |
| **Learning Convergence** | 2-4 weeks | Varies by task complexity and play frequency |
| **LLM Decisions** | Slower, costly | 500-2000ms latency, API costs apply |
| **Perfect Play** | Impossible | Deliberate imperfection for anti-detection |

**Learning Curve Expectations:**

```
Performance vs Time
100% ┤                                    ╭────────
     │                              ╭─────╯
 75% ┤                         ╭────╯
     │                    ╭────╯
 50% ┤               ╭────╯
     │          ╭────╯
 25% ┤     ╭────╯
     │╭────╯
  0% ┼────┴────┴────┴────┴────┴────┴────┴────┴──
     0    1    2    3    4    5    6    7    8
                     Weeks
     
     ─── With ML training
     ─ ─ CPU-only mode
```

### 13.2 Detection Risks

> ⚠️ **Important Disclaimer:** No anti-detection system is 100% effective. Using automation software always carries inherent risk.

**Risk Factors:**

| Factor | Risk Level | Mitigation |
|--------|------------|------------|
| Server sophistication | Variable | Higher paranoia settings |
| Active GM presence | High | GM detection system |
| Player reports | Medium | Social behavior, humanization |
| Statistical analysis | Medium | Behavior randomization |
| Extended sessions | High | Session limits, breaks |
| Perfect efficiency | High | Deliberate imperfection |

**Risk Reduction Strategies:**

```yaml
# Conservative anti-detection configuration
anti_detection:
  paranoia_level: high
  
  session:
    max_continuous_hours: 2
    break_duration_minutes: [20, 45]
    daily_max_hours: 6
    vary_schedule: true
  
  imperfection:
    mistake_rate: 0.05       # 5% mistakes
    suboptimal_rate: 0.10    # 10% suboptimal choices
    idle_probability: 0.03   # Random brief idles
```

**Detection Probability Estimate:**

| Configuration | Estimated Monthly Detection Risk |
|---------------|----------------------------------|
| Aggressive (no anti-detection) | 70-90% |
| Minimal anti-detection | 30-50% |
| Moderate anti-detection | 10-25% |
| High paranoia | 5-15% |
| Extreme paranoia | 2-8% |

*Note: These are rough estimates. Actual risk depends on server-specific factors.*

### 13.3 Resource Requirements

**Minimum System Requirements:**

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 2 cores | 4+ cores | More cores = more bots |
| **RAM** | 2 GB | 8 GB+ | ML mode needs more |
| **Storage** | 1 GB | 10 GB+ | Models + memory database |
| **Network** | Stable | Low latency | LLM API calls need reliability |

**Per-Backend Requirements:**

| Backend | RAM | GPU | Network | Estimated Cost |
|---------|-----|-----|---------|----------------|
| CPU | 2 GB | None | Optional | $0/month |
| GPU | 4 GB | 4GB VRAM | Optional | Electricity |
| ML | 4-8 GB | 8GB VRAM | Optional | Electricity |
| LLM | 2 GB | None | Required | $5-50/month |

### 13.4 Legal & Ethical Considerations

**Terms of Service:**
- Most game servers prohibit automation software
- Private servers may have different policies
- Always check your server's specific rules

**Ethical Usage:**
- Don't use in ways that harm other players' experience
- Don't use for RMT (Real Money Trading) operations
- Don't use to harass or grief other players
- Consider the impact on game economy

**Disclaimer:**
> This software is provided for educational and research purposes. Users are solely responsible for ensuring compliance with applicable terms of service and laws. The developers assume no liability for consequences arising from use of this software.

### 13.5 Known Limitations

| Limitation | Impact | Workaround |
|------------|--------|------------|
| LLM rate limits | Slows strategic decisions | Use CPU fallback |
| Memory growth | Performance degradation | Regular cleanup |
| Complex quests | May fail puzzle quests | Manual intervention |
| Server updates | May break compatibility | Wait for patches |
| Network issues | Disconnection loops | Backoff configuration |

---

## 14. Troubleshooting

Common issues and their solutions.

### 14.1 Connection Issues

#### DragonFlyDB Connection Failed

**Symptoms:**
```
ConnectionError: Could not connect to DragonFlyDB at localhost:6379
```

**Solutions:**

1. **Check if DragonFlyDB is running:**
   ```bash
   docker ps | grep dragonfly
   ```

2. **Start DragonFlyDB if not running:**
   ```bash
   docker run --network=host --ulimit memlock=-1 \
     docker.dragonflydb.io/dragonflydb/dragonfly \
     --snapshot_cron="*/5 * * * *"
   ```

3. **Check port availability:**
   ```bash
   netstat -tlnp | grep 6379
   ```

4. **Verify configuration:**
   ```yaml
   memory:
     session:
       backend: dragonfly
       dragonfly:
         host: localhost  # Check this matches
         port: 6379       # Check this matches
   ```

#### LLM API Timeout

**Symptoms:**
```
TimeoutError: LLM API request timed out after 10 seconds
```

**Solutions:**

1. **Check API key validity:**
   ```bash
   curl https://api.openai.com/v1/models \
     -H "Authorization: Bearer $OPENAI_API_KEY"
   ```

2. **Verify network connectivity:**
   ```bash
   ping api.openai.com
   ```

3. **Increase timeout:**
   ```yaml
   llm:
     openai:
       options:
         timeout_seconds: 30  # Increase from default 10
   ```

4. **Switch to faster model:**
   ```yaml
   llm:
     openai:
       model: gpt-4o-mini  # Faster than gpt-4
   ```

5. **Use fallback backend:**
   ```yaml
   backend:
     primary: llm
     fallback_chain: [ml, cpu]
   ```

### 14.2 Performance Issues

#### High CPU Usage

**Symptoms:** CPU usage > 50% per bot

**Solutions:**

1. **Reduce tick rate:**
   ```yaml
   general:
     tick_rate_ms: 200  # Increase from 100
   ```

2. **Disable unused backends:**
   ```yaml
   backend:
     primary: cpu
     gpu:
       enabled: false
     ml:
       enabled: false
   ```

3. **Check for memory leaks:**
   ```bash
   python -m godtier.tools.memory_profiler
   ```

4. **Reduce behavior complexity:**
   ```yaml
   behaviors:
     adaptive:
       enabled: false  # Disable if not needed
     consciousness:
       enabled: false  # Resource intensive
   ```

#### Memory Growth (Memory Leak)

**Symptoms:** RAM usage increases over time

**Solutions:**

1. **Enable memory compression:**
   ```yaml
   openmemory:
     compression:
       algorithm: aggressive
       threshold: 0.5
   ```

2. **Adjust decay rates:**
   ```yaml
   openmemory:
     sectors:
       episodic:
         decay: 0.030  # Increase decay rate
       emotional:
         decay: 0.040  # Faster forgetting
   ```

3. **Clear old memories periodically:**
   ```yaml
   memory:
     maintenance:
       enabled: true
       cleanup_interval_hours: 24
       max_memory_age_days: 7
   ```

4. **Reduce working memory:**
   ```yaml
   memory:
     working:
       max_entries: 500  # Reduce from 1000
   ```

### 14.3 AI Behavior Issues

#### Bot Not Attacking

**Possible causes and solutions:**

1. **Check combat is enabled:**
   ```yaml
   behaviors:
     combat:
       enabled: true
       aggression: 0.7  # Increase if too passive
   ```

2. **Verify monster whitelist/blacklist:**
   ```yaml
   map_profiles:
     prt_fild01:
       combat:
         monster_priorities:
           - name: Poring
             priority: 1.0
         avoid_monsters: []  # Check nothing blocking
   ```

3. **Check health thresholds:**
   ```yaml
   behaviors:
     survival:
       retreat_threshold: 0.3  # Bot retreats below 30% HP
   ```

#### Bot Standing Still / Not Moving

**Solutions:**

1. **Check navigation is enabled:**
   ```yaml
   behaviors:
     navigation:
       enabled: true
   ```

2. **Verify map data exists:**
   ```bash
   ls openkore-AI/fields/ | grep <map_name>
   ```

3. **Check for pathfinding issues:**
   ```yaml
   navigation:
     pathfinding:
       algorithm: a_star
       max_iterations: 10000  # Increase if complex maps
   ```

4. **Enable navigation logging:**
   ```yaml
   general:
     log_level: debug
   ```

#### Nonsensical LLM Responses

**Solutions:**

1. **Lower temperature:**
   ```yaml
   llm:
     openai:
       options:
         temperature: 0.5  # More deterministic
   ```

2. **Improve prompt clarity:**
   ```yaml
   llm:
     custom_prompts:
       social_response: |
         IMPORTANT: Respond with 1-2 sentences only.
         Do not explain your reasoning.
         ...
   ```

3. **Switch to better model:**
   ```yaml
   llm:
     openai:
       model: gpt-4-turbo-preview  # More capable
   ```

### 14.4 OpenKore Integration Issues

#### Plugin Bridge Not Connecting

**Symptoms:**
```
[GodTier] Failed to connect to AI sidecar
```

**Solutions:**

1. **Ensure sidecar is running first:**
   ```bash
   python main.py --config config/godtier.yaml
   # Wait for "IPC server started on port 5555"
   # Then start OpenKore
   ```

2. **Check port availability:**
   ```bash
   netstat -tlnp | grep 5555
   ```

3. **Verify ZeroMQ installation:**
   ```bash
   perl -MZMQ::FFI -e 'print "ZMQ OK\n"'
   ```

4. **Check firewall rules:**
   ```bash
   sudo ufw allow 5555/tcp
   ```

#### State Extraction Errors

**Symptoms:**
```
Error extracting game state: undefined field 'pos'
```

**Solutions:**

1. **Update plugin to latest version**

2. **Check OpenKore version compatibility:**
   ```
   # Requires OpenKore 2.1.0+
   ```

3. **Enable fallback state extraction:**
   ```yaml
   integration:
     state_extraction:
       fallback_mode: true
       retry_attempts: 3
   ```

### 14.5 Docker Issues (Windows)

#### Docker Desktop Not Starting

**Symptoms:**
```
Docker Desktop - WSL 2 Backend is not running
```

**Solutions:**

1. **Ensure WSL2 is installed and enabled:**
   ```powershell
   wsl --install
   wsl --update
   wsl --set-default-version 2
   ```

2. **Enable virtualization in BIOS:**
   - Restart computer and enter BIOS (usually F2, F12, or DEL)
   - Enable "Intel VT-x" or "AMD-V" virtualization
   - Save and exit

3. **Reset WSL if needed:**
   ```powershell
   wsl --shutdown
   # Then restart Docker Desktop
   ```

#### OpenMemory Container Fails to Start

**Symptoms:**
```
Error: Container godtier-openmemory failed to start
```

**Solutions:**

1. **Check logs for specific errors:**
   ```powershell
   docker logs godtier-openmemory
   ```

2. **Ensure port 8080 is not in use:**
   ```powershell
   netstat -ano | findstr :8080
   # If port is in use, find and stop the process or change the port in docker-compose.yml
   ```

3. **Remove and recreate containers:**
   ```powershell
   docker-compose down
   docker-compose up -d
   ```

4. **Pull fresh images if corrupted:**
   ```powershell
   docker-compose pull
   docker-compose up -d
   ```

#### Cannot Connect to Services from Host

**Symptoms:**
```
Connection refused to localhost:6379 or localhost:8080
```

**Solutions:**

1. **Verify containers are running and port mappings are correct:**
   ```powershell
   docker ps
   # Check PORTS column shows 0.0.0.0:6379->6379/tcp
   ```

2. **Check Windows Firewall:**
   - Open "Windows Defender Firewall with Advanced Security"
   - Ensure inbound rules allow Docker and ports 6379, 8080

3. **Try using 127.0.0.1 instead of localhost:**
   ```yaml
   # In your config file, change:
   host: localhost
   # To:
   host: 127.0.0.1
   ```

4. **Restart Docker networking:**
   ```powershell
   docker network prune
   docker-compose down
   docker-compose up -d
   ```

#### DragonFlyDB Memory Issues

**Symptoms:**
```
dragonfly exited with code 137 (out of memory)
```

**Solutions:**

1. **Increase Docker memory limit:**
   - Open Docker Desktop → Settings → Resources
   - Increase Memory allocation (recommend 4GB minimum)
   - Click "Apply & Restart"

2. **Set memory limits in docker-compose.yml:**
   ```yaml
   services:
     dragonfly:
       deploy:
         resources:
           limits:
             memory: 2G
   ```

---

### 14.6 Diagnostic Commands

```bash
# Check system health
python -m godtier.tools.health_check

# Test DragonFlyDB connection
python -m godtier.tools.test_dragonfly

# Test LLM connection
python -m godtier.tools.test_llm --provider openai

# Profile memory usage
python -m godtier.tools.memory_profiler --duration 300

# Validate configuration
python -m godtier.tools.config_validator --config config/godtier.yaml

# Test custom prompt
python -m godtier.tools.prompt_tester --prompt social_response

# Benchmark decision latency
python -m godtier.tools.latency_benchmark --iterations 100
```

---

## 15. Gap Analysis & Known Issues

This section documents known gaps, issues, and areas requiring attention identified during architectural review.

### 15.1 Conceptual Considerations

| Issue | Description | Mitigation |
|-------|-------------|------------|
| **LLM Latency vs Tick Rate** | LLM responses (500-2000ms) exceed the 100ms tick rate by 10-20x. The async architecture may discard decisions when state changes. | Use LLM for strategic decisions (exploration, shopping), not combat. CPU/GPU handles time-critical decisions. |
| **Memory Architecture Clarity** | Both local three-tier memory AND OpenMemory SDK creates unclear boundaries. | OpenMemory owns long-term/semantic memory. Local Redis/DragonFly owns session cache. Clear separation documented in Section 4.3. |
| **Single Point of Failure** | If the Python sidecar crashes, advanced AI capabilities are lost. | Graceful degradation to OpenKore's built-in AI (see Section 15.4). |
| **State Reconciliation** | Combat changes rapidly - a 2-second-old decision is often stale. | State validation before action execution. Discard stale decisions. Combat uses CPU-only fast path. |
| **ML Training Bootstrap** | Models require training data that doesn't exist initially. | Start with heuristic rules (CPU backend). Collect data for training. Use pre-trained models when available. |

### 15.2 Missing Pieces (To Be Completed)

| Component | Status | Priority |
|-----------|--------|----------|
| ZeroMQ Perl Installation Guide | 🔴 Missing | P0 |
| Complete Plugin Bridge Code | 🔴 Missing | P0 |
| Error Recovery Protocol | 🔴 Missing | P0 |
| Skill/Item ID Mapping Tables | 🟡 Partial | P1 |
| Server-Specific Adaptations | 🟡 Partial | P2 |
| Map Data Format Specification | 🟡 Partial | P1 |
| Configuration Validation/Wizard | 🔴 Missing | P2 |
| Prompt Injection Mitigation | 🔴 Missing | P1 |

### 15.3 Security Hardening Required

| Vulnerability | Risk | Mitigation |
|--------------|------|------------|
| Unauthenticated IPC | High | Add shared secret or token authentication to IPC |
| LLM Prompt Injection | High | Sanitize all player chat before including in prompts |
| Plaintext Memory DB | Medium | Enable encryption at rest for SQLite/DragonFlyDB |
| API Keys Exposure | Low | Use OS keychain or encrypted config files |
| Model File Integrity | Medium | Hash verification before loading ML models |

### 15.4 Graceful Degradation Protocol

When the AI sidecar is unavailable, the system degrades gracefully:

```
Degradation Levels:
├── Level 0: Full AI (sidecar healthy)
│   └── All features enabled
├── Level 1: Limited AI (sidecar slow/partial failure)
│   └── CPU backend only, LLM disabled
├── Level 2: Fallback (sidecar unreachable)
│   └── OpenKore built-in AI takes over
└── Level 3: Emergency (critical failure)
    └── Return to save point, stop actions
```

**Fallback Triggers:**
- IPC timeout > 5 seconds → Level 1
- 3 consecutive IPC failures → Level 2
- HP < 10% and no response → Level 3

### 15.5 Performance Considerations

| Issue | Impact | Optimization |
|-------|--------|--------------|
| JSON Serialization | ~10% CPU overhead per tick | Consider MessagePack for high-frequency state updates |
| Single-Sample Inference | GPU underutilization | Batch decisions when running multiple bots |
| Memory Growth | Unbounded caches | LRU eviction, maximum memory limits |
| SQLite File Locking | Contention under load | Connection pooling or switch to server-based DB |

---

## 16. Implementation Strategy

### 16.1 Key Finding: No EXE Rebuild Required

**The entire God-Tier AI system can be implemented without modifying XSTools or requiring a recompiled start.exe/wxstart.exe.**

| Component | Changes XSTools? | Requires EXE Rebuild? |
|-----------|------------------|----------------------|
| Plugin bridge (Perl) | No | ❌ No |
| ZeroMQ IPC (via ZMQ::FFI) | No | ❌ No |
| JSON serialization | No | ❌ No |
| State extraction | No | ❌ No |
| Action injection | No | ❌ No |
| Python sidecar | N/A | ❌ No |

### 16.2 Recommended Approach: Plugin-First

**85-90% of features can be implemented purely as an OpenKore plugin.**

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLUGIN-FIRST ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   OpenKore (Perl)                    AI Sidecar (Python)         │
│   ┌──────────────────┐               ┌──────────────────┐       │
│   │ godtier_bridge.pl│◄──── IPC ────►│ godtier_ai/      │       │
│   │                  │     (TCP/     │                  │       │
│   │ • Hook handlers  │     ZeroMQ)   │ • Decision Engine│       │
│   │ • State extract  │               │ • Memory Manager │       │
│   │ • Action inject  │               │ • Compute Backend│       │
│   └──────────────────┘               └──────────────────┘       │
│          │                                    │                  │
│          ▼                                    ▼                  │
│   ┌──────────────────┐               ┌──────────────────┐       │
│   │ AI::CoreLogic    │               │ DragonFlyDB      │       │
│   │ (Fallback mode)  │               │ OpenMemory       │       │
│   └──────────────────┘               │ SQLite           │       │
│                                      └──────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

**Plugin Capabilities:**
- ✅ Register hooks at 300+ points
- ✅ Access all global variables ($char, %monsters, etc.)
- ✅ Modify AI queue (@ai_seq)
- ✅ Load external modules (ZeroMQ, JSON)
- ✅ Create timers and async operations

**Plugin Limitations:**
- ❌ Cannot modify main loop timing directly
- ❌ Cannot override core functions (only hook before/after)
- ❌ Some packet handlers lack hooks

### 16.3 Phased Implementation Plan

```
┌────────────────────────────────────────────────────────────────────┐
│   PHASE 1: MVP (2-4 weeks)                                          │
│   ├── TCP-based IPC (simpler than ZeroMQ initially)                 │
│   ├── CPU backend with heuristic rules only                         │
│   ├── Basic state extraction (HP, SP, position, targets)            │
│   ├── Simple action injection (attack, skill, move)                 │
│   ├── Graceful fallback to OpenKore AI                              │
│   └── Configuration validation                                      │
├────────────────────────────────────────────────────────────────────┤
│   PHASE 2: Enhanced (4-8 weeks)                                      │
│   ├── Upgrade to ZeroMQ IPC for performance                         │
│   ├── Session memory with DragonFlyDB                               │
│   ├── GM detection system                                           │
│   ├── Emergency response protocols                                   │
│   ├── Anti-detection timing variance                                 │
│   └── GPU backend for pre-trained models                             │
├────────────────────────────────────────────────────────────────────┤
│   PHASE 3: Advanced (8-12 weeks)                                     │
│   ├── OpenMemory SDK integration                                     │
│   ├── Online ML training                                             │
│   ├── LLM integration for strategic decisions                        │
│   ├── Multi-bot coordination                                         │
│   ├── Full party AI capabilities                                     │
│   └── Submit hook patches to upstream OpenKore                       │
└────────────────────────────────────────────────────────────────────┘
```

### 16.4 Recommended File Structure

```
openkore/
├── plugins/
│   └── godtier/
│       ├── godtier_bridge.pl       # Main plugin entry point
│       ├── StateExtractor.pm       # Game state serialization
│       ├── ActionInjector.pm       # Decision execution
│       ├── IPCClient.pm            # Sidecar communication
│       └── Config.pm               # Plugin configuration
│
└── godtier_sidecar/                # Separate directory
    ├── main.py                     # Entry point
    ├── core/                       # Decision engine
    │   ├── router.py               # Task routing
    │   └── validator.py            # State validation
    ├── behaviors/                  # Combat, navigation, etc.
    ├── memory/                     # Memory systems
    ├── backends/                   # CPU, GPU, ML, LLM
    └── config/                     # YAML configurations
```

### 16.5 Critical Technical Decisions

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| IPC Protocol | Start TCP, upgrade to ZeroMQ | TCP simpler, ZeroMQ better performance |
| Serialization | JSON, add MessagePack later | JSON debuggable, MessagePack faster |
| Primary Backend | CPU first | No external dependencies |
| Memory Backend | SQLite initially | No server required |
| Distribution | Separate repos | Plugin repo + Sidecar repo |
| Configuration | YAML | Human-readable, already used in spec |

### 16.6 Frequently Asked Questions

**Q: Should this be implemented as a new plugin or integrated into existing code?**

A: **NEW PLUGIN.** The entire system should be implemented as a standalone plugin (`godtier_bridge.pl`) that communicates with an external Python sidecar. This approach:
- Requires no modifications to OpenKore core
- Works with any OpenKore version/fork
- Can be easily enabled/disabled
- Maintains backward compatibility

**Q: Do we need to rebuild the exe (start.exe/wxstart.exe)?**

A: **NO.** The exe files only need rebuilding when:
- XSTools C++ code changes
- Perl version is upgraded
- New native libraries are linked

Since our implementation uses:
- Pure Perl plugin code (interpreted at runtime)
- Standard CPAN modules (ZMQ::FFI, JSON)
- External Python process (separate from OpenKore)

No recompilation is required. Users can use the standard OpenKore distribution.

**Q: What if the AI sidecar crashes?**

A: The system degrades gracefully to OpenKore's built-in AI. See Section 15.4 for the degradation protocol.

---

## 17. Implementation Roadmap

```mermaid
gantt
    title God-Tier AI Implementation Roadmap
    dateFormat  YYYY-MM-DD
    section Phase 1: Foundation
    IPC Bridge Development      :p1a, 2024-01-01, 30d
    Basic State Extraction      :p1b, after p1a, 20d
    CPU Backend                 :p1c, after p1b, 20d
    Working Memory              :p1d, after p1b, 15d
    
    section Phase 2: Core Features
    Combat Behaviors            :p2a, after p1c, 25d
    Navigation System           :p2b, after p1c, 20d
    Session Memory (Redis)      :p2c, after p1d, 15d
    Anti-Detection Basics       :p2d, after p2a, 20d
    
    section Phase 3: Advanced
    GPU Backend                 :p3a, after p2a, 25d
    ML Backend                  :p3b, after p3a, 30d
    Persistent Memory           :p3c, after p2c, 20d
    Self-Learning System        :p3d, after p3b, 30d
    
    section Phase 4: Intelligence
    LLM Integration             :p4a, after p3b, 25d
    Social AI                   :p4b, after p4a, 20d
    Strategic Planning          :p4c, after p4a, 25d
    Consciousness Simulation    :p4d, after p4b, 20d
    
    section Phase 5: Polish
    Testing & Optimization      :p5a, after p4d, 30d
    Documentation               :p5b, after p4d, 20d
    Community Beta              :p5c, after p5a, 45d
```

**Phase breakdown:**

| Phase | Duration | Focus | Deliverables |
|-------|----------|-------|--------------|
| **Phase 1** | 3 months | Foundation | IPC, basic backend, memory |
| **Phase 2** | 2 months | Core | Combat, navigation, stealth |
| **Phase 3** | 3 months | Advanced | GPU, ML, learning |
| **Phase 4** | 2 months | Intelligence | LLM, social, planning |
| **Phase 5** | 2 months | Polish | Testing, docs, beta |

**Total estimated time:** 12 months

---

## 18. FAQ

### General Questions

**Q: Is this project legal?**

A: God-Tier AI is a technical framework for game automation. Legality depends on:
- The specific game server's Terms of Service
- Your jurisdiction's laws regarding game automation
- How the software is used

Many private RO servers allow or tolerate bots. Always check your server's rules.

**Q: Will this get me banned?**

A: The anti-detection systems are designed to minimize detection risk, but no automation is 100% undetectable. Factors include:
- Server's detection sophistication
- GM activity level
- Your configuration and usage patterns
- Pure chance

**Q: How much does it cost to run?**

A: Costs depend on your chosen backend:

| Backend | Hardware Cost | Ongoing Cost |
|---------|---------------|--------------|
| CPU | Existing PC | $0 |
| GPU | $300-1000+ GPU | Electricity |
| ML | Same as GPU | Electricity |
| LLM | None | $5-50+/month API |

### Technical Questions

**Q: Can I run multiple bots?**

A: Yes. Each bot requires its own:
- OpenKore instance
- AI sidecar process
- Configuration file

Memory (Redis/SQLite) can be shared with proper isolation.

**Q: Does it work with all RO servers?**

A: It works with any server that OpenKore supports. Server-specific adjustments may be needed for:
- Custom monsters/items
- Modified game mechanics
- Server-specific anti-bot measures

**Q: How much RAM/CPU does it use?**

A: Typical resource usage:

| Component | RAM | CPU |
|-----------|-----|-----|
| OpenKore | 100-200 MB | 5-10% |
| AI Sidecar (CPU) | 200-400 MB | 5-15% |
| AI Sidecar (ML) | 1-4 GB | 10-30% |
| Redis | 50-200 MB | 1-5% |

**Q: Can I use it on a VPS/cloud server?**

A: Yes. Requirements:
- Linux VPS with 2+ cores, 4+ GB RAM
- For GPU: Cloud GPU instance (expensive)
- For LLM: Just need internet connection

### Configuration Questions

**Q: How do I make it more human-like?**

A: Increase humanization settings:

```yaml
anti_detection:
  paranoia_level: high
  
humanization:
  randomization:
    timing:
      variance_ms: 300
    decisions:
      noise_percentage: 15
    movement:
      pause_probability: 0.1
```

**Q: How do I optimize for farming?**

A: Configure for efficiency:

```yaml
behaviors:
  combat:
    aggression: 0.9
    target_selection:
      priority: lowest_hp
  navigation:
    optimization: efficiency
  economy:
    optimize_for: zeny_per_hour
```

---

## 19. Appendices

### Appendix A: Complete Feature Matrix

| Feature | Description | CPU | GPU | ML | LLM |
|---------|-------------|-----|-----|-----|-----|
| **Core AI** |
| Decision Engine | Action selection | ✅ | ✅ | ✅ | ✅ |
| State Management | Game state tracking | ✅ | ✅ | ✅ | ✅ |
| World Model | Environment understanding | ✅ | ✅ | ✅ | ✅ |
| **Intelligence** |
| Adaptive Behavior | Dynamic adjustment | Basic | ✅ | ✅ | ✅ |
| Memory (Working) | Short-term storage | ✅ | ✅ | ✅ | ✅ |
| Memory (Session) | Session patterns | ✅ | ✅ | ✅ | ✅ |
| Memory (Persistent) | Long-term storage | ✅ | ✅ | ✅ | ✅ |
| Predictive Decisions | Future state prediction | Basic | ✅ | ✅ | Partial |
| Behavior Randomization | Human-like variance | ✅ | ✅ | ✅ | ✅ |
| Context Awareness | Environmental perception | ✅ | ✅ | ✅ | ✅ |
| Self-Learning | Autonomous improvement | ❌ | ✅ | ✅ | ❌ |
| Consciousness Sim | Attention, thought | Basic | ✅ | ✅ | ✅ |
| Heuristic System | Strategic rules | ✅ | ✅ | ✅ | ✅ |
| Environmental Awareness | Map understanding | ✅ | ✅ | ✅ | ✅ |
| Social Mimicking | Human interaction | Basic | Basic | Partial | ✅ |
| Multi-Map Profiles | Per-map config | ✅ | ✅ | ✅ | ✅ |
| Role-Optimized AI | Class specialization | ✅ | ✅ | ✅ | ✅ |
| **Capabilities** |
| Anti-Detection | Stealth measures | ✅ | ✅ | ✅ | ✅ |
| Economic Intelligence | Market awareness | ✅ | ✅ | ✅ | ✅ |
| Quest Automation | Objective completion | ✅ | ✅ | ✅ | ✅ |
| Party Coordination | Team play | ✅ | ✅ | ✅ | ✅ |
| Emergency Response | Crisis handling | ✅ | ✅ | ✅ | ✅ |

---

### Appendix B: Backend Capabilities Matrix

| Capability | CPU | GPU | ML | LLM |
|------------|-----|-----|-----|-----|
| **Performance** |
| Decision Latency | <5ms | <50ms | <20ms | <2000ms |
| Throughput | High | High | Medium | Low |
| **Requirements** |
| Hardware | Any | CUDA GPU | CUDA GPU | Internet |
| RAM | 2GB | 4GB+ | 4GB+ | 2GB |
| Dependencies | Minimal | CUDA | PyTorch | API key |
| **Features** |
| Rule-based Logic | ✅ | ✅ | ✅ | ✅ |
| Neural Inference | ❌ | ✅ | ✅ | ❌ |
| Online Learning | ❌ | ❌ | ✅ | ❌ |
| Natural Language | ❌ | ❌ | ❌ | ✅ |
| Complex Reasoning | ❌ | ❌ | Partial | ✅ |
| **Reliability** |
| Offline Operation | ✅ | ✅ | ✅ | ❌ |
## 20. Companion Systems

God-Tier AI includes comprehensive support for all companion entities in Ragnarok Online, enabling intelligent management of pets, homunculus, mercenaries, and mounts.

### 20.1 Pet System Intelligence

**Priority:** P2 (Enhancement)

**What it does:** Manages pet feeding, intimacy tracking, evolution paths, skill coordination, and accessory management to maximize pet effectiveness and bonuses.

**Why it matters:** Pets provide valuable stat bonuses at high intimacy levels and can evolve into stronger forms. Optimal pet management requires tracking multiple hidden mechanics that human players often neglect.

**Pet Intimacy Mechanics:**

| Intimacy Level | Range | Effect | Feeding Strategy |
|----------------|-------|--------|------------------|
| Awkward | 0-100 | No bonus | Feed on hungry |
| Shy | 100-250 | Minimal | Feed on hungry |
| Neutral | 250-750 | Some bonus | Optimal timing |
| Cordial | 750-910 | Good bonus | Maintain carefully |
| Loyal | 910-1000 | Max bonus | Perfect timing |

**Pet Evolution Paths:**

```python
from pydantic import BaseModel
from typing import Optional, List
from enum import Enum

class PetIntimacyLevel(Enum):
    AWKWARD = "awkward"
    SHY = "shy"
    NEUTRAL = "neutral"
    CORDIAL = "cordial"
    LOYAL = "loyal"

class PetState(BaseModel):
    """Represents the current state of a pet."""
    pet_id: int
    name: str
    intimacy: int  # 0-1000
    hunger: int    # 0-100 (0 = starving, 100 = full)
    accessory_id: Optional[int] = None
    evolution_available: bool = False
    
    @property
    def intimacy_level(self) -> PetIntimacyLevel:
        if self.intimacy < 100:
            return PetIntimacyLevel.AWKWARD
        elif self.intimacy < 250:
            return PetIntimacyLevel.SHY
        elif self.intimacy < 750:
            return PetIntimacyLevel.NEUTRAL
        elif self.intimacy < 910:
            return PetIntimacyLevel.CORDIAL
        else:
            return PetIntimacyLevel.LOYAL

class PetManager:
    """Manages pet feeding, intimacy, and evolution."""
    
    # Optimal feeding hunger thresholds by intimacy goal
    FEEDING_THRESHOLDS = {
        "maximize_intimacy": 25,
        "maintain_intimacy": 50,
        "minimize_cost": 75,
    }
    
    # Evolution requirements database
    EVOLUTION_PATHS = {
        "Poring": {"target": "Drops", "intimacy_required": 910, "item_required": "Unripe Apple"},
        "Drops": {"target": "Poporing", "intimacy_required": 910, "item_required": "Bitter Herb"}
    }
    
    async def should_feed(self, pet: PetState, strategy: str = "maximize_intimacy") -> bool:
        threshold = self.FEEDING_THRESHOLDS.get(strategy, 50)
        return pet.hunger <= threshold
```

**Configuration:**

```yaml
companions:
  pet:
    enabled: true
    feeding:
      strategy: maximize_intimacy
      auto_feed: true
      hunger_threshold: 25
    intimacy:
      target_level: loyal
      monitor_interval_ms: 5000
    evolution:
      auto_evolve: false
      notify_on_available: true
    accessories:
      auto_equip: true
      preferred_accessory: null
    skill_usage:
      enabled: true
      priority: low
```

**Backend Compatibility:**

| Backend | Support Level | Notes |
|---------|---------------|-------|
| CPU | Full | All pet management features |
| GPU | Full | Supported |
| ML | Partial | Learned feeding patterns |
| LLM | Partial | Evolution decisions |

---

### 20.2 Homunculus Strategic AI

**Priority:** P1 (Important)

**What it does:** Provides intelligent stat distribution for homunculus evolution paths, skill point allocation, tactical skill usage, and intimacy optimization for evolution unlocks.

**Why it matters:** Homunculus AI can significantly boost an Alchemist's effectiveness. Poor stat distribution or skill usage results in a suboptimal companion that fails to contribute meaningfully to combat.

**Homunculus Evolution Tree:**

```
BASE HOMUNCULUS                    S EVOLUTION
├── Lif ────────────────────────── Eira (Support/Heal)
├── Amistr ─────────────────────── Bayeri (Tank/Defense)
├── Filir ──────────────────────── Sera (DPS/Poison)
├── Vanilmirth ─────────────────── Dieter (Magic DPS)
└── (Any) ──────────────────────── Eleanor (Special)

Requirements for S Evolution:
• Base homunculus at level 99
• Intimacy at "Loyal" level
• Stone of Sage item
```

**Stat Distribution by Evolution Form:**

```python
class HomunculusStatEngine:
    """Manages homunculus stat point allocation."""
    
    STAT_TEMPLATES = {
        "Lif": {"hp": 0.3, "sp": 0.3, "atk": 0.0, "matk": 0.2, "def": 0.1, "mdef": 0.1},
        "Amistr": {"hp": 0.4, "sp": 0.1, "atk": 0.2, "matk": 0.0, "def": 0.2, "mdef": 0.1},
        "Filir": {"hp": 0.2, "sp": 0.2, "atk": 0.4, "matk": 0.0, "def": 0.1, "mdef": 0.1},
        "Vanilmirth": {"hp": 0.2, "sp": 0.3, "atk": 0.0, "matk": 0.4, "def": 0.0, "mdef": 0.1},
        "Eira": {"hp": 0.3, "sp": 0.3, "atk": 0.0, "matk": 0.2, "def": 0.1, "mdef": 0.1},
        "Bayeri": {"hp": 0.4, "sp": 0.1, "atk": 0.2, "matk": 0.0, "def": 0.2, "mdef": 0.1},
        "Sera": {"hp": 0.2, "sp": 0.2, "atk": 0.4, "matk": 0.0, "def": 0.1, "mdef": 0.1},
        "Dieter": {"hp": 0.2, "sp": 0.3, "atk": 0.0, "matk": 0.4, "def": 0.0, "mdef": 0.1},
        "Eleanor": {"hp": 0.25, "sp": 0.25, "atk": 0.25, "matk": 0.0, "def": 0.15, "mdef": 0.1}
    }
    
    SKILL_PRIORITIES = {
        "Eira": ["Overed Boost", "Silent Breeze", "Xeno Slasher"],
        "Bayeri": ["Stein Wand", "Heilige Stange", "Angriffs Modus"],
        "Sera": ["Poison Mist", "Pain Killer", "Needle of Paralyze"],
        "Dieter": ["Pyroclastic", "Volcanic Ash", "Lava Slide"],
        "Eleanor": ["Sonic Claw", "Silvervein Rush", "Midnight Frenzy"]
    }
```

**Configuration:**

```yaml
companions:
  homunculus:
    enabled: true
    stats:
      distribution: template
      template: auto_detect
    skills:
      auto_use: true
      priority_mode: damage
    evolution:
      target_form: auto_detect
      auto_evolve: false
      intimacy_farming: true
    positioning:
      follow_distance: 2
      combat_distance: 3
      retreat_with_owner: true
```

---

### 20.3 Mercenary Tactical Control

**Priority:** P2 (Enhancement)

**What it does:** Manages mercenary contract time tracking, type selection based on situation, skill usage coordination, faith point tracking, and positional commands for tactical play.

**Why it matters:** Mercenaries provide significant combat support but have limited contract duration and require faith points to summon.

**Mercenary Types and Roles:**

| Type | Role | Best For | Faith Required |
|------|------|----------|----------------|
| Archer | Ranged DPS | Kiting, safe damage | 10-50 |
| Lancer | Melee DPS | High single target | 10-50 |
| Swordman | Tank | Frontline, aggro | 10-50 |
| Spearman | Hybrid | Versatile | 10-50 |
| Bowman | Ranged | Distance attacks | 10-50 |

**Configuration:**

```yaml
companions:
  mercenary:
    enabled: true
    contracts:
      auto_renew: true
      renewal_threshold_minutes: 5
      faith_reserve: 20
    type_selection:
      mode: situational
      preferred_type: archer
      situation_mapping:
        farming: archer
        party: swordman
        mvp: lancer
    skill_coordination:
      enabled: true
      use_with_owner_skills: true
    positioning:
      tactical_mode: true
      follow_distance: 3
      combat_behavior: assist
```

---

### 20.4 Mount System Intelligence

**Priority:** P2 (Enhancement)

**What it does:** Provides automatic mount management including auto-mount for speed, dismount for skill usage, Peco rental, cart weight optimization, Mado Gear fuel management, and class-specific mount mechanics.

**Mount Types by Class:**

| Class | Mount Type | Speed Bonus | Skill Restrictions |
|-------|------------|-------------|-------------------|
| Knight/Lord Knight | Peco Peco | +25% | None |
| Crusader/Paladin | Grand Peco | +25% | Some skills unmountable |
| Rune Knight | Dragon | +50% | Dragon Breath enabled |
| Royal Guard | Gryphon | +30% | Overbrand enhanced |
| Mechanic | Mado Gear | +20% | Mado skills only |
| Ranger | Warg | +25% | Warg skills enabled |
| Merchant Classes | Cart | None | Required for Vending |

**Configuration:**

```yaml
companions:
  mount:
    enabled: true
    auto_mount:
      enabled: true
      travel_threshold: 20
      dismount_for_combat: false
    peco:
      rental_auto_renew: true
    dragon:
      enabled: true
      dragon_breath_optimization: true
    mado_gear:
      enabled: true
      fuel_threshold: 20
      auto_repair: true
    cart:
      enabled: true
      weight_optimization: true
      max_weight_percent: 80
```

---

## 21. Consumable and Buff Management

Comprehensive systems for managing consumable items, buff duration tracking, and optimal item usage.

### 21.1 Food/Cuisine Buff System

**Priority:** P1 (Important)

**What it does:** Manages stat-boosting food items, tracks cuisine buff durations, auto-refreshes before expiry, and optimizes food selection based on build requirements.

**Food Buff Categories:**

| Category | Stats Boosted | Duration | Typical Cost |
|----------|---------------|----------|--------------|
| Basic Stat Foods | Single stat +1-10 | 20 min | Low |
| Advanced Stat Foods | Single stat +10-20 | 30 min | Medium |
| Cuisine | Multiple stats | 20-30 min | High |
| Special Event Foods | Unique effects | Variable | N/A |
| Luxury Foods | +20 all stats | 30 min | Very High |

**Configuration:**

```yaml
consumables:
  food:
    enabled: true
    auto_consume:
      enabled: true
      refresh_threshold_seconds: 30
    budget:
      max_per_session: 500000
      cost_benefit_analysis: true
    priority_foods:
      melee_dps:
        - "Steamed Tongue"
        - "Dragon Breath Cocktail"
      magic_dps:
        - "Immortal Stew"
        - "INT Dish"
    stacking_rules:
      same_category: replace
      different_category: stack
```

---

### 21.2 Buff Duration Intelligence

**Priority:** P0 (Critical)

**What it does:** Parses buff durations from status packets, implements intelligent refresh timing 30 seconds before expiry, manages buff priority queues, and detects buff stacking/conflict rules.

**Buff Priority System:**

| Priority | Buff Type | Examples |
|----------|-----------|----------|
| CRITICAL | Survival | Assumptio, Kyrie Eleison, Safety Wall |
| HIGH | Damage/Stats | Blessing, Increase AGI, Magnificat |
| MEDIUM | Utility | Impositio Manus, Gloria |
| LOW | Convenience | Minor buffs |

**Buff Conflict Rules:**

```python
BUFF_RULES = {
    "Blessing": {"conflicts": ["Curse"], "stacking": "replace"},
    "Increase_AGI": {"conflicts": ["Decrease_AGI"], "stacking": "replace"},
    "Assumptio": {"conflicts": [], "stacking": "replace"},
    "Gospel": {"conflicts": [], "stacking": "stack"},
}
```

**Configuration:**

```yaml
buffs:
  duration_tracking:
    enabled: true
    refresh_threshold_seconds: 30
  priority_buffs:
    critical:
      - Assumptio
      - Kyrie_Eleison
      - Safety_Wall
    high:
      - Blessing
      - Increase_AGI
      - Magnificat
  auto_refresh:
    enabled: true
    sp_threshold: 0.2
  conflict_handling:
    warn_on_conflict: true
    auto_remove_conflicting: false
```

---

### 21.3 Recovery Item Priority System

**Priority:** P0 (Critical)

**What it does:** Implements context-aware healing item selection with tiered emergency response, cost-per-HP calculations, and inventory quantity monitoring with auto-restocking thresholds.

**Item Priority Tiers:**

| Tier | HP Range | Items | Usage |
|------|----------|-------|-------|
| EMERGENCY | < 10% | Yggdrasil Berry, Yggdrasil Leaf | Instant full recovery |
| CRITICAL | 10-25% | White Potion, Mastela Fruit | High healing |
| MODERATE | 25-50% | Yellow Potion, Condensed White | Medium healing |
| MAINTENANCE | 50-80% | Red Potion, Orange Potion | Cost-effective |

**Configuration:**

```yaml
consumables:
  recovery:
    enabled: true
    tier_thresholds:
      emergency: 0.10
      critical: 0.25
      moderate: 0.50
      maintenance: 0.80
    optimization: efficiency
    restock_thresholds:
      Red_Potion: 100
      Orange_Potion: 50
      Yellow_Potion: 30
      White_Potion: 20
      Blue_Potion: 30
      Yggdrasil_Berry: 5
    emergency_reserves:
      Yggdrasil_Berry: 3
      Yggdrasil_Leaf: 2
```

---

### 21.4 Catalyst Management

**Priority:** P1 (Important)

**What it does:** Tracks catalyst consumption for skills (gemstones, ammunition, etc.), manages auto-purchase thresholds, monitors skill availability based on catalyst stock.

**Catalyst Types:**

| Catalyst | Skills Requiring | Classes |
|----------|------------------|---------|
| Blue Gemstone | Warp Portal, Safety Wall, Pneuma | Mage, Sage |
| Yellow Gemstone | Cold Bolt, Fire Ball | Mage |
| Red Gemstone | Sight, Meteor Storm | Mage, Wizard |
| Trap | All trap skills | Hunter, Sniper |
| Arrows | All arrow skills | Archer classes |
| Bullets | All gun skills | Gunslinger |
| Elemental Converters | Element endow | Any physical |

**Configuration:**

```yaml
consumables:
  catalysts:
    enabled: true
    tracking:
      Blue_Gemstone:
        skills: ["Warp_Portal", "Safety_Wall", "Pneuma"]
        min_stock: 50
        purchase_amount: 100
      Arrow:
        skills: ["Double_Strafe", "Arrow_Shower"]
        min_stock: 1000
        purchase_amount: 2000
    auto_purchase:
      enabled: true
      purchase_location: "prontera"
      budget_limit_per_trip: 100000
    elemental_converters:
      Fire_Converter:
        vs_elements: ["Earth"]
        min_stock: 20
```

---

## 22. Instance/Dungeon Systems

Comprehensive support for instance dungeons, memorial dungeons, and party-based dungeon content.

### 22.1 Memorial Dungeon Management

**Priority:** P1 (Important)

**What it does:** Automates instance creation requests, coordinates party entry, provides in-instance navigation patterns, maintains dungeon-specific mechanics databases, and handles reward collection.

**Supported Instance Types:**

| Instance | Level Range | Cooldown | Rewards |
|----------|-------------|----------|---------|
| Endless Tower | 80+ | 7 days | Equipment, Cards |
| Nidhoggr's Nest | 80+ | 1 day | Yggdrasil items |
| Sara's Memory | 120+ | 1 day | Sarah's equipment |
| Horror Toy Factory | 100+ | 1 day | Toys, EXP |
| Old Glast Heim | 130+ | 1 day | Temporal equipment |

**Configuration:**

```yaml
instances:
  enabled: true
  management:
    auto_create: false
    auto_enter: true
    auto_collect_rewards: true
  navigation:
    use_predefined_paths: true
    paths_directory: "./data/instance_paths/"
  endless_tower:
    enabled: true
    target_floor: 100
    retreat_hp_threshold: 0.25
  old_glast_heim:
    enabled: true
    mode: hard
```

---

### 22.2 Instance Cooldown Tracking

**Priority:** P1 (Important)

**What it does:** Maintains per-character cooldown database for all instances, supports multi-character cooldown management, provides notifications when instances become ready.

**Configuration:**

```yaml
instances:
  cooldowns:
    enabled: true
    tracking:
      per_character: true
      database_path: "./data/cooldowns.db"
    notifications:
      enabled: true
      notify_minutes_before: 30
    server_reset:
      time: "04:00"
      timezone: "America/Los_Angeles"
```

---

### 22.3 Daily/Weekly Limit Tracking

**Priority:** P1 (Important)

**What it does:** Tracks entry limit counters for instance types, detects reset timing, implements priority queuing based on remaining limits.

**Configuration:**

```yaml
instances:
  limits:
    enabled: true
    daily_limits:
      memorial_dungeons: 2
      battlegrounds: 5
    weekly_limits:
      endless_tower: 1
    priority_queue:
      high:
        - old_glast_heim_hard
        - endless_tower
      medium:
        - horror_toy_factory
```

---

### 22.4 Boss Pattern Recognition (ML-Enhanced)

**Priority:** P2 (Enhancement)

**What it does:** Records boss skill sequences, predicts next skills based on learned patterns, calculates dodge windows, optimizes burst damage timing.

**Configuration:**

```yaml
instances:
  boss_patterns:
    enabled: true
    recording:
      enabled: true
      save_patterns: true
      patterns_file: "./data/boss_patterns.json"
    prediction:
      enabled: true
      confidence_threshold: 0.7
      use_ml_model: true
    dodge_optimization:
      enabled: true
      pre_dodge_ms: 500
      safe_distance: 5
```

---

## 23. Crafting Systems

Complete support for all crafting systems in Ragnarok Online.

### 23.1 Blacksmith Forging

**Priority:** P2 (Enhancement)

**What it does:** Automates material gathering for forging, calculates success rates based on DEX/LUK/materials, optimizes element and attribute selection.

**Forging Success Rate Formula:**
```
Success Rate = Base Rate + (DEX * 0.1) + (LUK * 0.1) + Anvil Bonus + Material Bonus
```

**Configuration:**

```yaml
crafting:
  forging:
    enabled: true
    auto_gather_materials: true
    success_optimization:
      target_success_rate: 0.7
      use_enriched_oridecon: true
    element_selection:
      auto_select: true
      market_price_aware: true
```

---

### 23.2 Alchemist Brewing/Pharmacy

**Priority:** P2 (Enhancement)

**What it does:** Manages potion crafting recipes, optimizes material costs, automates batch brewing.

**Configuration:**

```yaml
crafting:
  brewing:
    enabled: true
    recipes:
      auto_learn: true
      priority_recipes:
        - White_Potion
        - Condensed_White_Potion
        - Acid_Bottle
    batch_brewing:
      enabled: true
      batch_size: 100
```

---

### 23.3 Rune Creation (Rune Knight)

**Priority:** P2 (Enhancement)

**What it does:** Manages Rune Knight rune creation, selects rune types based on situation.

**Rune Types:**

| Rune | Effect | Materials | Priority |
|------|--------|-----------|----------|
| Turisus | STR boost | Elder Branch, Red Blood | High |
| Isia | Fire damage | Burning Heart, Red Blood | Medium |
| Hagalaz | Water damage | Crystal Blue, Mystic Frozen | Medium |
| Nosiege | Party buff | Blue Gemstone, Yellow Gemstone | High |

**Configuration:**

```yaml
crafting:
  rune_creation:
    enabled: true
    priority_runes:
      combat: [Turisus, Isia, Verkana]
      support: [Nosiege, Luxanima]
    inventory_management:
      max_per_rune_type: 20
```

---

### 23.4 Genetics Creation

**Priority:** P2 (Enhancement)

**What it does:** Manages Geneticist item creation (plants, mushrooms, bombs), optimizes cart space management.

**Configuration:**

```yaml
crafting:
  genetics:
    enabled: true
    creation_priorities:
      bombs: [Acid_Demonstration, Fire_Expansion_Bomb]
      plants: [Mandragora, Parasite]
    cart_management:
      reserve_space: 20
```

---

### 23.5 Shadow Equipment System

**Priority:** P2 (Enhancement)

**What it does:** Manages shadow gear crafting materials, plans upgrade paths from C to S grades.

**Shadow Gear Grades:**

| Grade | Stats | Upgrade Cost | Success Rate |
|-------|-------|--------------|--------------|
| C | Basic | Low | 100% |
| B | +10% | Medium | 80% |
| A | +25% | High | 60% |
| S | +50% | Very High | 40% |

**Configuration:**

```yaml
crafting:
  shadow_equipment:
    enabled: true
    upgrade_path:
      strategy: safe
      target_grade: A
```

---

### 23.6 Costume Synthesis

**Priority:** P3 (Nice-to-have)

**What it does:** Tracks costume collection progress, manages synthesis material requirements.

**Configuration:**

```yaml
crafting:
  costume_synthesis:
    enabled: false
    collection:
      track_progress: true
```

---

## 24. Enchanting and Refining Advanced

Advanced systems for equipment enhancement and optimization.

### 24.1 Socket Enchanting Intelligence

**Priority:** P2 (Enhancement)

**What it does:** Tracks enchant slot success rates, analyzes material costs, selects optimal enchants per build.

**Enchant NPCs:**

| NPC Location | Enchant Type | Cost Type | Success Rate |
|--------------|--------------|-----------|--------------|
| Malangdo | Stat enchants | Zeny + Coins | Variable |
| Mora | Temporal enchants | Mora Coins | Variable |
| Prontera | Basic enchants | Zeny | High |
| Lasagna | Special enchants | Lasagna items | Low |

**Configuration:**

```yaml
enchanting:
  socket:
    enabled: true
    strategy:
      optimization: build_specific
      build_type: auto_detect
    reset_policy:
      reset_on_bad_enchant: true
      keep_any_tier3: true
    budget:
      max_attempts_per_slot: 20
      max_zeny_per_item: 5000000
```

---

### 24.2 Refine Strategy Engine

**Priority:** P1 (Important)

**What it does:** Implements safe vs HD vs normal refine decision making, calculates expected values.

**Refine Success Rates (Standard):**

| Level | Weapon | Armor | HD Weapon | HD Armor |
|-------|--------|-------|-----------|----------|
| +1-4 | 100% | 100% | 100% | 100% |
| +5-7 | 60% | 60% | 70% | 70% |
| +8 | 40% | 40% | 60% | 60% |
| +9 | 20% | 20% | 50% | 50% |
| +10 | 19% | 19% | 40% | 40% |

**Configuration:**

```yaml
refining:
  strategy:
    enabled: true
    safe_refine:
      use_safe_tickets: true
      safe_to_level: 7
    upgrade_decision:
      normal_ore_max_level: 7
      hd_ore_min_level: 8
    risk_tolerance: medium
    budget:
      max_per_item: 10000000
```

---

### 24.3 Over-Refine Optimization

**Priority:** P3 (Nice-to-have)

**What it does:** Calculates ROI for +11 to +20 refining, implements failure recovery strategies.

**Configuration:**

```yaml
refining:
  over_refine:
    enabled: false
    target_levels:
      min: 11
      max: 15
    roi_calculation:
      enabled: true
      min_roi_percent: 200
```

---

### 24.4 HD/Enriched Ore Intelligence

**Priority:** P2 (Enhancement)

**What it does:** Calculates break-even analysis for HD vs normal, optimizes enriched ore usage.

**Configuration:**

```yaml
refining:
  ore_intelligence:
    enabled: true
    price_tracking:
      enabled: true
    break_even_analysis:
      include_item_replacement: true
    enriched_usage:
      only_for_levels: [7, 8]
```

---

### 24.5 Shadow Equipment Enchanting

**Priority:** P3 (Nice-to-have)

**What it does:** Handles shadow refine mechanics (different from normal), manages shadow enchant NPCs.

**Configuration:**

```yaml
refining:
  shadow:
    enabled: true
    refine:
      max_level: 10
    enchanting:
      preferred_enchants: [ATK, MATK, HP]
```

---

## 25. Achievement Systems

Complete achievement and title management.

### 25.1 Achievement Tracking

**Priority:** P3 (Nice-to-have)

**What it does:** Maintains achievement database with requirements, tracks progress per achievement.

**Configuration:**

```yaml
achievements:
  tracking:
    enabled: true
    database:
      auto_update: true
    progress:
      track_all: true
      notify_on_near_completion: true
```

---

### 25.2 Title Collection and Management

**Priority:** P3 (Nice-to-have)

**What it does:** Manages title inventory, calculates stat bonuses per title, implements situational title swapping.

**Configuration:**

```yaml
achievements:
  titles:
    enabled: true
    management:
      auto_equip_best: true
      situational_swap:
        pvp: "Gladiator"
        pve: "Monster Hunter"
```

---

### 25.3 Achievement Reward System

**Priority:** P3 (Nice-to-have)

**What it does:** Auto-claims rewards on completion, assesses reward values.

**Configuration:**

```yaml
achievements:
  rewards:
    auto_claim: true
    inventory_management:
      reserve_slots: 5
```

---

## 26. Hunting and Daily Systems

Automated hunting quests and daily content management.

### 26.1 Eden Group Quest Automation

**Priority:** P1 (Important)

**What it does:** Parses quest board for available quests, selects level-appropriate quests, optimizes for similar monster types.

**Level Brackets:**

| Level Range | Bracket |
|-------------|---------|
| 1-25 | Beginner |
| 26-40 | Intermediate |
| 41-55 | Advanced |
| 56-70 | Expert |
| 71-85 | Master |
| 86-99 | Champion |
| 100-175 | Hero |

**Configuration:**

```yaml
daily:
  eden:
    enabled: true
    quest_selection:
      level_appropriate: true
      multi_quest_optimization: true
      max_concurrent: 3
    turn_in:
      auto_turn_in: true
      collect_equipment: true
```

---

### 26.2 Hunting Board System

**Priority:** P1 (Important)

**What it does:** Parses available hunts, selects optimal hunts for efficiency, tracks daily completion.

**Configuration:**

```yaml
daily:
  hunting_board:
    enabled: true
    selection:
      optimal_for: exp_per_hour
    tracking:
      daily_completion_goal: 5
```

---

### 26.3 Daily Mission Rotation

**Priority:** P2 (Enhancement)

**What it does:** Recognizes rotation patterns, scores mission priorities, plans across multiple days.

**Configuration:**

```yaml
daily:
  missions:
    enabled: true
    rotation:
      track_pattern: true
    priority:
      high: ["MVP Kill", "Instance Clear"]
      medium: ["Monster Hunt", "Item Collection"]
```

---

### 26.4 Gramps Quest System

**Priority:** P1 (Important)

**What it does:** Selects quests based on current farming area, automates turn-in, tracks cooldowns.

**Configuration:**

```yaml
daily:
  gramps:
    enabled: true
    selection:
      match_current_farm: true
      level_range: 10
    turn_in:
      auto_when_complete: true
```

---

| Consistent Latency | ✅ | ✅ | ✅ | ❌ |
| No External Deps | ✅ | ❌ | ❌ | ❌ |

---

### Appendix C: Hook Reference

**OpenKore hooks used:**

| Hook | When | Purpose | Blocking |
|------|------|---------|----------|
| `AI_pre` | Before AI loop | Inject decisions | No |
| `AI_post` | After AI loop | Execute actions | No |
| `checkMonsterAutoAttack` | Target selection | Override targets | Yes |
| `packet_pre/packet` | Packet receive | State extraction | No |
| `mainLoop_pre` | Main loop start | Sync timing | No |
| `Network::clientSend_pre` | Before send | Modify packets | Yes |

**Custom hooks provided:**

| Hook | When | Purpose |
|------|------|---------|
| `godtier_pre_decision` | Before AI decides | Modify context |
| `godtier_post_decision` | After AI decides | React to decision |
| `godtier_pre_action` | Before action sent | Modify action |
| `godtier_post_action` | After action sent | Log/analyze |
| `godtier_memory_update` | Memory change | React to memories |
| `godtier_mode_change` | Stealth mode | Handle transitions |

---

### Appendix D: Data Schema Reference

**GameState schema (full):**

```json
{
  "timestamp": 1700000000000,
  "tick": 12345,
  
  "player": {
    "id": 2000000,
    "name": "CharacterName",
    "class": "Knight",
    "base_level": 99,
    "job_level": 50,
    
    "hp": 5000,
    "hp_max": 10000,
    "sp": 200,
    "sp_max": 500,
    
    "stats": {
      "str": 99,
      "agi": 60,
      "vit": 70,
      "int": 1,
      "dex": 40,
      "luk": 30
    },
    
    "pos": {"x": 150, "y": 200},
    "destination": {"x": 155, "y": 200},
    "direction": 4,
    
    "status_effects": [
      {"id": 12, "name": "Blessing", "expires": 1700000300}
    ],
    
    "equipment": {
      "head_top": {"id": 5000, "name": "Helm"},
      "weapon": {"id": 1000, "name": "Sword"}
    }
  },
  
  "map": {
    "name": "prt_fild01",
    "type": "field",
    "pvp": false
  },
  
  "monsters": [
    {
      "id": 100001,
      "name": "Poring",
      "mob_id": 1002,
      "hp_percent": 0.8,
      "pos": {"x": 152, "y": 203},
      "target_id": null,
      "distance": 4.2
    }
  ],
  
  "players": [
    {
      "id": 2000001,
      "name": "OtherPlayer",
      "guild": "SomeGuild",
      "pos": {"x": 145, "y": 195},
      "distance": 7.1
    }
  ],
  
  "npcs": [
    {
      "id": 300001,
      "name": "Tool Dealer",
      "pos": {"x": 100, "y": 100},
      "type": "vendor"
    }
  ],
  
  "inventory": {
    "weight": 3500,
    "weight_max": 5000,
    "items": [
      {"id": 501, "name": "Red Potion", "quantity": 100}
    ]
  },
  
  "party": {
    "name": "PartyName",
    "members": [
      {"id": 2000000, "name": "CharacterName", "online": true}
    ]
  },
  
  "guild": {
    "name": "GuildName",
    "id": 1000
  },
  
  "skills": {
    "available": [
      {"id": 5, "name": "Bash", "level": 10, "sp_cost": 8}
    ],
    "cooldowns": {}
  }
}
```

**Action schema (full):**

```json
{
  "action_type": "skill",
  "target_id": 100001,
  "skill_id": 5,
  "skill_level": 10,
  "position": null,
  "item_id": null,
  "item_index": null,
  
  "priority": 0.9,
  "confidence": 0.85,
  "reasoning": "Target at 80% HP, using Bash for optimal damage",
  
  "timing": {
    "delay_ms": 150,
    "execute_at": 1700000000150
  },
  
  "metadata": {
    "backend": "ml",
    "decision_time_ms": 12,
    "context_size": 5
  }
}
```

---

## Document Information

| Property | Value |
|----------|-------|
| **Document Title** | God-Tier Ragnarok Online AI Specification |
| **Version** | 3.0.0 |
| **Status** | Production Specification |
| **Last Updated** | 2025-11-27 |
| **Created** | November 2024 |
| **Last Updated** | November 2025 |
| **Authors** | God-Tier AI Development Team |
| **License** | MIT |
| **Changelog** | v2.1.0 - Added Gap Analysis and Implementation Strategy sections |

---

*This specification is a living document and will be updated as the project evolves.*
## 27. Advanced Combat Mechanics

Deep combat system optimizations for maximum effectiveness.

### 27.1 Animation Canceling

**Priority:** P1 (Important)

**What it does:** Tracks animation frame data per skill, optimizes cancel timing, implements movement canceling, manages attack animation canceling (especially for Monk/Champion).

**Animation Data:**

| Skill | Animation Duration | Movement Cancel | Skill Cancel |
|-------|-------------------|-----------------|--------------|
| Bash | 500ms | 300ms | 350ms |
| Magnum Break | 600ms | 400ms | N/A |
| Double Strafe | 400ms | 250ms | 300ms |
| Bowling Bash | 800ms | 500ms | 600ms |

**Configuration:**

```yaml
combat:
  animation_canceling:
    enabled: true
    timing:
      safety_margin_ms: 50
    cancel_methods:
      movement: true
      skill: true
      attack: true
    class_specific:
      monk:
        triple_attack_cancel: true
        combo_canceling: true
```

---

### 27.2 Skill Chaining/Combos

**Priority:** P1 (Important)

**What it does:** Maintains combo skill database (especially Monk combos), implements chain optimization algorithms, optimizes cancel timing between skills.

**Monk Combo System:**

```
Triple Attack → Chain Combo → Combo Finish
       OR
Triple Attack → Chain Combo → Tiger Knuckle Fist
       OR
Triple Attack → Chain Combo → Raging Trifecta Blow
                            → Tiger Knuckle Fist
                            → Guillotine Fist

TIMING: Each combo step has a 1-second window
```

**Configuration:**

```yaml
combat:
  combos:
    enabled: true
    monk:
      triple_attack_chance: 30
      combo_chain_enabled: true
      preferred_finisher: guillotine_fist
      timing:
        combo_window_ms: 1000
        input_delay_ms: 50
    general:
      optimize_for: dps
      sp_conservation_mode: false
```

---

### 27.3 Status Effect Management

**Priority:** P0 (Critical)

**What it does:** Prioritizes status effects (Freeze/Stone > Stun > Silence > Curse > Blind > Poison), implements auto-dispel/cure mechanisms, triggers emergency teleport on Stone Curse.

**Status Priority:**

| Status | Severity | Cure Method | Auto Response |
|--------|----------|-------------|---------------|
| Stone Curse | Critical | Teleport/item | Immediate escape |
| Freeze | Critical | Thaw item | High priority cure |
| Stun | High | Wait | Defensive stance |
| Silence | High | Green Potion | If caster class |
| Curse | Medium | Blessing | Preventive buff |
| Blind | Medium | Green Potion | Lower priority |
| Poison | Low | Green Potion | Cure when safe |

**Configuration:**

```yaml
combat:
  status_effects:
    enabled: true
    auto_cure:
      enabled: true
      priority:
        - Stone_Curse
        - Freeze
        - Stun
        - Silence
        - Curse
        - Blind
        - Poison
    cure_items:
      Green_Potion:
        cures: [Poison, Silence, Blind]
        min_stock: 20
    emergency:
      teleport_on_stone: true
      flee_on_freeze: true
```

---

### 27.4 Cast Time Optimization

**Priority:** P1 (Important)

**What it does:** Implements Variable Cast Time formula (VCT = Base * (1 - DEX/150)), tracks Fixed Cast Time, calculates DEX breakpoints, integrates with Bragi effect.

**Cast Time Formula:**

```
Variable Cast Time (VCT) = Base * (1 - (DEX + INT/5) / 530)
Fixed Cast Time (FCT) = Cannot be reduced (most cases)
Total Cast Time = VCT + FCT
```

**DEX Breakpoints for Instant Cast:**

| DEX | INT | VCT Reduction |
|-----|-----|---------------|
| 150 | 0 | 100% |
| 120 | 150 | 100% |
| 100 | 250 | 100% |

**Configuration:**

```yaml
combat:
  cast_time:
    enabled: true
    optimization:
      target_vct_percent: 0.5
      equipment_suggestions: true
    dex_breakpoints:
      calculate: true
      notify_near_breakpoint: true
    bragi_integration:
      enabled: true
      request_from_bard: true
```

---

### 27.5 ASPD Optimization

**Priority:** P1 (Important)

**What it does:** Implements ASPD formula, optimizes ASPD potion usage, manages buff stacking for ASPD cap (190/193).

**ASPD Formula:**

```
ASPD = Base + (AGI * 0.6) + (DEX * 0.4) + Equipment + Potion
Maximum ASPD = 190 (193 for some classes)
Attacks per Second = 50 / (200 - ASPD)
```

**Configuration:**

```yaml
combat:
  aspd:
    enabled: true
    optimization:
      target_aspd: 190
      use_potions: true
    potions:
      auto_use: true
      threshold_aspd: 185
      preferred_potion: "Concentration_Potion"
    buff_coordination:
      request_increase_agi: true
      two_hand_quicken: true
```

---

### 27.6 After-Cast Delay Management

**Priority:** P1 (Important)

**What it does:** Maintains fixed delay database per skill, manages variable delay reduction (Bragi, DEX), tracks global cooldown (0.3-0.5s).

**Configuration:**

```yaml
combat:
  after_cast_delay:
    enabled: true
    skill_database:
      auto_learn_delays: true
    optimization:
      fill_delays_with: "normal_attack"
    bragi:
      integrate: true
      expected_reduction: 0.3
```

---

### 27.7 Element Converter/Endow System

**Priority:** P1 (Important)

**What it does:** Detects monster elements, selects optimal converter based on element chart, performs cost-benefit analysis for converter usage.

**Element Advantage Chart:**

| Attack Element | Strong Against | Weak Against |
|----------------|----------------|--------------|
| Fire | Earth, Undead | Water |
| Water | Fire | Wind, Earth |
| Wind | Water | Earth |
| Earth | Wind | Fire |
| Holy | Shadow, Undead | - |
| Shadow | Holy | - |

**Configuration:**

```yaml
combat:
  element_conversion:
    enabled: true
    auto_convert:
      enabled: true
      based_on_target: true
    converters:
      Fire_Converter:
        vs_elements: [Earth]
        cost: 2000
      Water_Converter:
        vs_elements: [Fire]
        cost: 2000
    endow_priority:
      prefer_endow_over_converter: true
      request_from_sage: true
    cost_benefit:
      min_damage_increase: 0.3
```

---

### 27.8 Perfect Dodge Mechanics

**Priority:** P2 (Enhancement)

**What it does:** Calculates perfect dodge (LUK + equipment bonuses), determines optimal LUK investment for dodge builds.

**Perfect Dodge Formula:**

```
Perfect Dodge = LUK / 10 + Equipment Bonuses
Chance to completely avoid physical attack
Works independently from normal FLEE
```

**Configuration:**

```yaml
combat:
  perfect_dodge:
    enabled: true
    calculation:
      base_from_luk: true
      equipment_bonus: true
    build_optimization:
      target_perfect_dodge: 30
      balance_with_flee: true
```

---

## 28. PvP/WoE Systems

Comprehensive PvP and War of Emperium support.

### 28.1 War of Emperium Logistics

**Priority:** P2 (Enhancement)

**What it does:** Manages pre-WoE supply stocking, implements castle entry strategies, handles economy breaker protection/destruction, coordinates guild protocols.

**WoE Preparation Checklist:**

| Category | Item | Quantity |
|----------|------|----------|
| HP Recovery | White Potion | 200 |
| SP Recovery | Blue Potion | 100 |
| Emergency | Yggdrasil Berry | 10 |
| Resurrection | Yggdrasil Leaf | 10 |
| Status Cure | Green Potion | 50 |
| Escape | Butterfly Wing | 10 |

**Configuration:**

```yaml
pvp:
  woe:
    enabled: true
    preparation:
      auto_stock: true
      supplies:
        White_Potion: 200
        Blue_Potion: 100
        Yggdrasil_Berry: 10
    castle_entry:
      strategy: defend
      wait_for_signal: true
    coordination:
      follow_leader: true
```

---

### 28.2 Battlegrounds System

**Priority:** P2 (Enhancement)

**What it does:** Detects BG type (CTF, Domination, KvM, etc.), assigns team roles, prioritizes objectives.

**Configuration:**

```yaml
pvp:
  battlegrounds:
    enabled: true
    detection:
      auto_detect_mode: true
    roles:
      preferred_role: auto
    objectives:
      prioritize_objectives: true
      capture_over_kills: true
```

---

### 28.3 Castle Siege Strategies

**Priority:** P2 (Enhancement)

**What it does:** Plans attack paths (guardian -> barricade -> emperium), prioritizes guardians, implements emperor room rushing tactics.

**Attack Strategy:**

```
Phase 1: Guardian Clear - Destroy guardian stones
Phase 2: Barricade Break - Clear barricades
Phase 3: Rush Emperor - Attack emperium
```

**Configuration:**

```yaml
pvp:
  castle_siege:
    enabled: true
    attack:
      phase_priorities:
        - guardians
        - barricades
        - emperium
    defense:
      positions:
        enabled: true
        role_based: true
```

---

### 28.4 Guild vs Guild Tactics

**Priority:** P2 (Enhancement)

**What it does:** Identifies enemy guilds, prioritizes targets (enemy healers first), coordinates focus fire.

**Configuration:**

```yaml
pvp:
  gvg:
    enabled: true
    target_priority:
      - healer
      - ranged_dps
      - melee_dps
      - tank
    focus_fire:
      enabled: true
      follow_marked_target: true
```

---

### 28.5 PvP Target Prioritization

**Priority:** P1 (Important)

**What it does:** Prioritizes targets (Healer > Ranged DPS > Melee DPS > Tank), implements threat scoring algorithms.

**Target Priority System:**

```python
def calculate_target_score(target):
    score = 0
    # Class priority (40 points max)
    class_priority = {"Arch_Bishop": 1.0, "Warlock": 0.9, "Ranger": 0.85}
    score += class_priority.get(target["class"], 0.7) * 40
    
    # HP factor - lower HP = higher priority (30 points max)
    hp_percent = target["hp"] / target["hp_max"]
    score += (1 - hp_percent) * 30
    
    # Distance factor - closer = higher priority (15 points max)
    distance_factor = max(0, 1 - target["distance"] / 15)
    score += distance_factor * 15
    
    # Active threat bonus (15 points)
    if target.get("attacking_ally"):
        score += 15
    
    return score
```

**Configuration:**

```yaml
pvp:
  targeting:
    enabled: true
    priority:
      class_weights:
        healer: 1.0
        ranged_dps: 0.9
        melee_dps: 0.7
        tank: 0.5
    hp_threshold:
      finish_low_hp: true
      threshold: 0.2
    equipment_detection:
      enabled: true
```

---

## 29. Human Mimicry and Anti-Detection

Advanced systems to make bot behavior indistinguishable from human players.

### 29.1 Movement Pattern Humanization

**Priority:** P0 (Critical)

**What it does:** Generates Bezier curve paths instead of straight lines, injects random pauses (0.5-3s variance), adds path deviation from optimal (1-2 tiles), includes occasional backtracking.

**Humanization Techniques:**

| Technique | Description | Frequency |
|-----------|-------------|-----------|
| Bezier Curves | Curved paths instead of straight | Always |
| Random Pauses | 0.5-3s stops during movement | 5% of tiles |
| Path Deviation | 1-2 tiles from optimal path | Always |
| Backtracking | Go back a few steps | 2% chance |
| Speed Variation | Vary movement speed | 15% variance |

**Configuration:**

```yaml
anti_detection:
  movement:
    enabled: true
    bezier_curves:
      enabled: true
      control_points: 2
    deviation:
      enabled: true
      max_tiles: 2
    pauses:
      enabled: true
      probability: 0.05
      duration_range_ms: [500, 3000]
    backtracking:
      enabled: true
      probability: 0.02
    speed_variation:
      enabled: true
      variance_percent: 15
```

---

### 29.2 Chat Pattern Intelligence

**Priority:** P1 (Important)

**What it does:** Simulates response time distribution (1-5s base), implements typing speed simulation (150-300ms per character), adds occasional typos (2-3% rate), uses abbreviations.

**Chat Humanization:**

| Feature | Implementation | Rate |
|---------|----------------|------|
| Response Delay | 1-5 second base | Always |
| Typing Speed | 150-300ms/char | Always |
| Typos | Adjacent key replacement | 2% |
| Abbreviations | "u", "rn", "brb" | 40% |
| Emojis | Context-appropriate | 30% |

**Configuration:**

```yaml
anti_detection:
  chat:
    enabled: true
    response_timing:
      min_delay_ms: 1000
      max_delay_ms: 5000
      distribution: gaussian
    typing_speed:
      min_ms_per_char: 150
      max_ms_per_char: 300
    typos:
      enabled: true
      rate: 0.02
    abbreviations:
      enabled: true
      rate: 0.4
```

---

### 29.3 Response Timing Variation

**Priority:** P0 (Critical)

**What it does:** Implements Gaussian distribution for reaction times (150-500ms base), applies context-dependent timing.

**Configuration:**

```yaml
anti_detection:
  timing:
    enabled: true
    reaction_time:
      base_ms: 250
      variance_ms: 100
      distribution: gaussian
    context_modifiers:
      combat: 0.7
      idle: 1.5
      emergency: 0.5
    attention_simulation:
      miss_probability: 0.02
```

---

### 29.4 Break/AFK Pattern System

**Priority:** P0 (Critical)

**What it does:** Varies session lengths (2-6 hours), implements realistic break durations (15-45 min), distinguishes weekday vs weekend patterns.

**Session Patterns:**

| Day Type | Session Length | Break Duration | Daily Max |
|----------|----------------|----------------|-----------|
| Weekday | 2-4 hours | 15-30 min | 8 hours |
| Weekend | 3-6 hours | 20-45 min | 12 hours |

**Configuration:**

```yaml
anti_detection:
  breaks:
    enabled: true
    sessions:
      min_hours: 2
      max_hours: 6
    breaks:
      min_minutes: 15
      max_minutes: 45
    daily:
      max_hours: 10
      vary_by_day: true
    weekday_weekend:
      enabled: true
      weekend_modifier: 1.3
    bio_breaks:
      enabled: true
      interval_hours: 2
      duration_minutes: [5, 15]
```

---

### 29.5 Mistake Injection Engine

**Priority:** P1 (Important)

**What it does:** Injects 2-5% suboptimal actions, causes occasional wrong skill usage, misses obvious loot pickup, creates "oops" moments.

**Mistake Types:**

| Mistake Type | Frequency | Description |
|--------------|-----------|-------------|
| Wrong skill | 2% | Use suboptimal skill |
| Miss loot | 3% | Fail to pick up item |
| Wrong target | 2% | Attack wrong monster |
| Path mistake | 3% | Walk into obstacle |
| Delayed reaction | 5% | Slow response |

**Configuration:**

```yaml
anti_detection:
  mistakes:
    enabled: true
    frequencies:
      wrong_skill: 0.02
      miss_loot: 0.03
      wrong_target: 0.02
      path_mistake: 0.03
      delayed_reaction: 0.05
    severity:
      max_recovery_time_ms: 500
      avoid_fatal_mistakes: true
```

---

### 29.6 Attention Drift Simulation

**Priority:** P1 (Important)

**What it does:** Occasionally misses monster spawns, delays reactions to threats, implements slower reaction when "tired" (long sessions).

**Configuration:**

```yaml
anti_detection:
  attention:
    enabled: true
    spawn_awareness:
      miss_probability: 0.02
    threat_reaction:
      base_delay_ms: 200
      fatigue_modifier: true
    whisper_miss:
      probability: 0.02
    fatigue:
      enabled: true
      start_degradation_hours: 3
      degradation_per_hour: 0.1
```

---

## 30. Environmental Systems

Systems for understanding and adapting to the game environment.

### 30.1 Weather Effect Handling

**Priority:** P3 (Nice-to-have)

**What it does:** Tracks weather state per map (rain, snow, fog), calculates stat adjustments (FLEE penalty in rain).

**Weather Effects:**

| Weather | Effect | Stat Impact |
|---------|--------|-------------|
| Rain | Reduced FLEE | -10 FLEE |
| Snow | Reduced ASPD | -5 ASPD |
| Fog | Reduced HIT | -20 HIT |

**Configuration:**

```yaml
environment:
  weather:
    enabled: true
    effects:
      rain:
        flee_penalty: 10
        movement_speed_modifier: 0.9
      snow:
        aspd_penalty: 5
    adaptation:
      adjust_combat_strategy: true
```

---

### 30.2 Map Hazard Detection

**Priority:** P2 (Enhancement)

**What it does:** Maps danger zones (Quagmire, Lava, etc.), avoids paths through hazards, escapes from placed AoEs.

**Configuration:**

```yaml
environment:
  hazards:
    enabled: true
    detection:
      quagmire: true
      pneuma: true
      safety_wall: true
    avoidance:
      path_around: true
      escape_from_aoe: true
```

---

### 30.3 Spawn Point Optimization

**Priority:** P1 (Important)

**What it does:** Records spawn coordinates for all maps, learns respawn timers through statistical analysis, determines optimal camping positions.

**Configuration:**

```yaml
environment:
  spawns:
    enabled: true
    tracking:
      record_positions: true
      learn_timers: true
      statistical_analysis: true
    optimization:
      rotation_mode: efficient
      camping_positions: true
    rare_spawns:
      detection: true
      priority: high
```

---

### 30.4 Hidden Passage Discovery

**Priority:** P3 (Nice-to-have)

**What it does:** Systematically explores maps, detects hidden portals, prefers shortcuts in routing.

**Configuration:**

```yaml
environment:
  exploration:
    enabled: false
    discovery:
      systematic: true
      hidden_portals: true
    routing:
      prefer_shortcuts: true
```

---

### 30.5 Terrain Advantage Usage

**Priority:** P2 (Enhancement)

**What it does:** Implements corner trapping for AoE damage, uses wall-based kiting, identifies safe spots.

**Configuration:**

```yaml
environment:
  terrain:
    enabled: true
    tactics:
      corner_trapping: true
      wall_kiting: true
      funnel_usage: true
      los_blocking: true
    safe_spots:
      detection: true
```

---

## 31. Economy Deep Dive

Advanced economic systems for market manipulation and wealth optimization.

### 31.1 Market Analysis Algorithms

**Priority:** P2 (Enhancement)

**What it does:** Tracks price history with timestamps, calculates moving averages, detects volatility, generates buy/sell signals.

**Configuration:**

```yaml
economy:
  market_analysis:
    enabled: true
    tracking:
      price_history: true
      history_days: 30
    analysis:
      moving_average_periods: [7, 14, 30]
      volatility_detection: true
    signals:
      buy_threshold: 0.8
      sell_threshold: 1.2
```

---

### 31.2 Price Arbitrage Detection

**Priority:** P2 (Enhancement)

**What it does:** Maintains NPC price database, scans player vendors, calculates profit margins, alerts on arbitrage opportunities.

**Configuration:**

```yaml
economy:
  arbitrage:
    enabled: true
    scanning:
      npc_prices: true
      vendor_scanning: true
    profit:
      min_margin_percent: 10
      include_travel_cost: true
```

---

### 31.3 Vending Optimization

**Priority:** P2 (Enhancement)

**What it does:** Implements competitive pricing algorithms, selects high-traffic locations using heatmaps, automates price undercutting.

**Configuration:**

```yaml
economy:
  vending:
    enabled: true
    pricing:
      competitive: true
      undercut_percent: 5
    location:
      heatmap_based: true
      preferred_locations:
        - prontera
        - geffen
    restocking:
      auto_restock: true
```

---

### 31.4 Investment Timing Intelligence

**Priority:** P3 (Nice-to-have)

**What it does:** Implements budget allocation models, calculates ROI for equipment, maintains emergency fund requirements.

**Configuration:**

```yaml
economy:
  investment:
    enabled: true
    budget:
      allocation_model: balanced
      emergency_reserve: 1000000
    roi:
      equipment_priority: true
      min_roi_percent: 10
```

---

### 31.5 Buying Store Optimization

**Priority:** P2 (Enhancement)

**What it does:** Identifies demand items, sets competitive buy prices, calculates resale profits.

**Configuration:**

```yaml
economy:
  buying_store:
    enabled: true
    items:
      demand_based: true
    pricing:
      competitive: true
      max_buy_price_percent: 80
```

---

## 32. Time-Sensitive Mechanics

Systems for handling time-based game mechanics.

### 32.1 Server Time Synchronization

**Priority:** P1 (Important)

**What it does:** Calculates server time offset, handles timezones, corrects clock drift.

**Configuration:**

```yaml
time:
  synchronization:
    enabled: true
    offset:
      auto_detect: true
      manual_offset_hours: 0
    timezone:
      server: "America/Los_Angeles"
```

---

### 32.2 Day/Night Cycle Awareness

**Priority:** P2 (Enhancement)

**What it does:** Detects day/night state, tracks night-only monster spawns, applies Star Gladiator day/night bonuses.

**Day/Night Effects:**

| Condition | Effects |
|-----------|---------|
| Day | Normal spawns, Solar bonuses active |
| Night | Night-only spawns, Lunar bonuses active |

**Configuration:**

```yaml
time:
  day_night:
    enabled: true
    detection:
      packet_based: true
    spawns:
      night_only_awareness: true
    star_gladiator:
      solar_bonus: true
      lunar_bonus: true
```

---

### 32.3 Event Schedule Tracking

**Priority:** P2 (Enhancement)

**What it does:** Maintains event calendar database, automates participation, collects rewards.

**Configuration:**

```yaml
time:
  events:
    enabled: true
    calendar:
      auto_update: true
    participation:
      auto_join: true
```

---

### 32.4 Double EXP Event Detection

**Priority:** P1 (Important)

**What it does:** Detects event announcements via chat, extends play during events, monitors EXP rates for stealth event detection.

**Configuration:**

```yaml
time:
  double_exp:
    enabled: true
    detection:
      chat_announcement: true
      exp_rate_monitoring: true
    behavior:
      extend_session: true
      max_extension_hours: 2
```

---

## 33. Job-Specific Mechanics

Specialized systems for unique job class mechanics.

### 33.1 Bard/Dancer Ensemble Skills

**Priority:** P2 (Enhancement)

**What it does:** Detects Bard/Dancer pairs, triggers ensemble skills, synchronizes positions.

**Ensemble Skills:**

| Skill | Bard Skill | Dancer Skill | Effect |
|-------|------------|--------------|--------|
| Lullaby | Acoustic Rhythm | Slow Grace | Sleep enemies |
| Mr. Kim | Melody Strike | Dance Strike | Damage boost |
| Eternal Chaos | Down Tempo | Fortune's Kiss | Enemy stat down |

**Configuration:**

```yaml
jobs:
  bard_dancer:
    enabled: true
    ensemble:
      auto_pair: true
      position_sync: true
      skill_matching: true
```

---

### 33.2 Super Novice Mechanics

**Priority:** P2 (Enhancement)

**What it does:** Uses extra conservative HP thresholds (death = stat loss), prioritizes Angel Blessing acquisition.

**Special Mechanics:**

| Mechanic | Description | AI Response |
|----------|-------------|-------------|
| Death Penalty | Stat loss on death | HP threshold 50% |
| Angel Blessing | Angel buff at 99% HP loss | Prioritize trigger |
| Skill Versatility | All 1st job skills | Optimize rotation |

**Configuration:**

```yaml
jobs:
  super_novice:
    enabled: true
    death_prevention:
      hp_threshold: 0.5
    angel_blessing:
      priority: high
    stat_loss:
      detection: true
      recovery: true
```

---

### 33.3 Taekwon Ranking System

**Priority:** P3 (Nice-to-have)

**What it does:** Optimizes ranking points, selects missions for points, analyzes competition.

**Configuration:**

```yaml
jobs:
  taekwon:
    enabled: true
    ranking:
      optimize_points: true
      mission_selection: true
```

---

### 33.4 Star Gladiator Hatred System

**Priority:** P2 (Enhancement)

**What it does:** Selects optimal hatred targets (map, monster, player), tracks map-based bonuses (Solar/Lunar/Stellar).

**Hatred System:**

| Hatred Type | Bonus | Selection Criteria |
|-------------|-------|-------------------|
| Map Hatred | +damage on map | Primary farming map |
| Monster Hatred | +damage vs monster | Most farmed monster |
| Player Hatred | +damage in PvP | N/A (PvP only) |

**Configuration:**

```yaml
jobs:
  star_gladiator:
    enabled: true
    hatred:
      optimal_selection: true
    bonuses:
      solar_maps: []
      lunar_maps: []
```

---

### 33.5 Soul Linker Spirit Mechanics

**Priority:** P2 (Enhancement)

**What it does:** Detects target class, selects appropriate spirit, maintains spirit buffs.

**Configuration:**

```yaml
jobs:
  soul_linker:
    enabled: true
    spirits:
      auto_detect_class: true
      maintenance: true
      party_priority: true
```

---

### 33.6 Ninja/Gunslinger Ammo Management

**Priority:** P1 (Important)

**What it does:** Optimizes ammo type per target, sets auto-purchase thresholds, selects elemental ammo.

**Ammo Types:**

| Class | Ammo Types | Selection Criteria |
|-------|------------|-------------------|
| Ninja | Kunai, Shuriken | Target size, element |
| Gunslinger | Bullets, Coins | Skill requirements |

**Configuration:**

```yaml
jobs:
  gunslinger:
    enabled: true
    ammo:
      type_optimization: true
      auto_purchase: true
      elemental_selection: true
  ninja:
    enabled: true
    kunai_management: true
```

---

### 33.7 Mechanic Mado Gear Management

**Priority:** P1 (Important)

**What it does:** Monitors fuel and initiates refills, manages Mado-specific skill rotations, automates repair.

**Mado Gear Status:**

| Status | Threshold | Action |
|--------|-----------|--------|
| Fuel Low | 20% | Refill |
| Damaged | HP < 50% | Repair |
| Emergency | Fuel < 5% | Dismount |

**Configuration:**

```yaml
jobs:
  mechanic:
    enabled: true
    mado_gear:
      fuel_monitoring: true
      refill_threshold: 20
      skill_rotation: true
      auto_repair: true
```

---

### 33.8 Royal Guard Devotion Mechanics

**Priority:** P1 (Important)

**What it does:** Prioritizes targets (protect healers), manages Devotion cooldown, maintains range (5 cells).

**Devotion Rules:**

| Rule | Description |
|------|-------------|
| Target Priority | Healer > DPS > Tank |
| Range | Must stay within 5 cells |
| Damage Share | Takes damage for target |
| Cooldown | 60 second cooldown |

**Configuration:**

```yaml
jobs:
  royal_guard:
    enabled: true
    devotion:
      target_priority:
        - healer
        - ranged_dps
      cooldown_management: true
      range_maintenance: true
```

---

### 33.9 Warlock Spellbook System

**Priority:** P2 (Enhancement)

**What it does:** Monitors spellbook spells, optimizes Release timing, preserves spells strategically.

**Configuration:**

```yaml
jobs:
  warlock:
    enabled: true
    spellbook:
      monitoring: true
      release_timing: optimal
      spell_preservation: true
```

---

### 33.10 Genetic Plant/Bomb Mechanics

**Priority:** P2 (Enhancement)

**What it does:** Optimizes plant placement, calculates explosion timing, creates chain explosion strategies.

**Configuration:**

```yaml
jobs:
  genetic:
    enabled: true
    plants:
      placement_optimization: true
      explosion_timing: true
      chain_explosions: true
```

---

## 34. Mini-Games

Optional support for event mini-games.

### 34.1 Event Participation

**Priority:** P3 (Nice-to-have)

**What it does:** Automates Poring Catch, optimizes Monster Racing betting, randomizes Rock Paper Scissors, looks up monster names for Disguise event, systematically searches in Find the Mushroom.

**Supported Mini-Games:**

| Mini-Game | Automation Level | Strategy |
|-----------|------------------|----------|
| Poring Catch | Full | Click timing optimization |
| Monster Racing | Betting | Statistical analysis |
| Rock Paper Scissors | Partial | Weighted random |
| Disguise Event | Full | Monster name database |
| Find the Mushroom | Full | Systematic grid search |
| Quiz Events | Full | Answer database |

**Configuration:**

```yaml
minigames:
  enabled: false
  
  poring_catch:
    enabled: true
    reaction_timing: human_like
    target_accuracy: 0.7
    
  monster_racing:
    enabled: true
    betting_strategy: statistical
    max_bet_percent: 10
    
  rock_paper_scissors:
    strategy: random_weighted
    weights:
      rock: 0.33
      paper: 0.34
      scissors: 0.33
      
  disguise:
    monster_lookup: true
    database_path: "./data/monsters.db"
    
  find_mushroom:
    systematic_search: true
    grid_pattern: spiral
    
  quiz:
    answer_database: true
    database_path: "./data/quiz_answers.db"
```

---

## 35. Advanced Navigation

Enhanced navigation and positioning systems.

### 35.1 Safe Zone Mapping

**Priority:** P1 (Important)

**What it does:** Identifies safe zones (no monster spawns), calculates distances to safe zones, plans emergency routes.

**Safe Zone Types:**

| Zone Type | Characteristics | Usage |
|-----------|-----------------|-------|
| Town | No hostile monsters | Recovery, shopping |
| NPC Area | Protected spawn area | Emergency escape |
| Indoor | Limited spawns | Rest area |
| Kafra | Save point proximity | Respawn advantage |

**Configuration:**

```yaml
navigation:
  safe_zones:
    enabled: true
    identification:
      no_spawn_areas: true
      town_zones: true
      npc_proximity: true
    routing:
      emergency_routes: true
      distance_calculation: true
    caching:
      enabled: true
      cache_path: "./data/safe_zones/"
```

---

### 35.2 Mob Train Detection

**Priority:** P0 (Critical)

**What it does:** Counts monsters targeting player, analyzes movement patterns, detects train size threshold (>3 = train), triggers emergency responses.

**Train Detection Logic:**

```python
class MobTrainDetector:
    TRAIN_THRESHOLD = 3
    CRITICAL_THRESHOLD = 5
    
    def analyze_threat(self, monsters_targeting: int, hp_percent: float):
        if monsters_targeting >= self.CRITICAL_THRESHOLD:
            return "EMERGENCY_TELEPORT"
        elif monsters_targeting >= self.TRAIN_THRESHOLD:
            if hp_percent < 0.5:
                return "EMERGENCY_TELEPORT"
            else:
                return "KITE_TO_SAFETY"
        else:
            return "NORMAL_COMBAT"
```

**Configuration:**

```yaml
navigation:
  mob_train:
    enabled: true
    detection:
      monster_count_threshold: 3
      critical_threshold: 5
      pattern_analysis: true
    response:
      emergency_trigger: true
      teleport_threshold: 5
      kite_threshold: 3
    hp_consideration:
      enabled: true
      low_hp_threshold: 0.5
```

---

### 35.3 Line-of-Sight Tactics

**Priority:** P2 (Enhancement)

**What it does:** Implements LOS calculator, identifies wall-peeking positions, detects aggro drop, finds safe attack positions.

**LOS Tactical Positions:**

| Position Type | Use Case | Benefit |
|---------------|----------|---------|
| Corner Peek | Range attacks | Single target aggro |
| Wall Block | Melee kiting | Monster pathing reset |
| Pillar Dance | Boss fights | Skill avoidance |
| Doorway | Funneling | AoE optimization |

**Configuration:**

```yaml
navigation:
  line_of_sight:
    enabled: true
    tactics:
      wall_peeking: true
      corner_abuse: true
      aggro_drop: true
      safe_attack_positions: true
    calculations:
      real_time: true
      cache_positions: true
    training:
      learn_positions: true
      ml_optimization: true
```

---

## 36. Hidden Patterns and Meta

Understanding and exploiting hidden game mechanics.

### 36.1 Server Tick Awareness

**Priority:** P2 (Enhancement)

**What it does:** Detects server tick rate, optimizes packet timing, optimizes multi-hit skill timing.

**Server Tick Mechanics:**

```
Standard Tick Rate: 50ms (20 ticks per second)
Skill Processing: Per-tick basis
Movement: Per-tick updates
Damage Calculation: Per-tick

Optimization Strategy:
- Align skill usage with tick boundaries
- Batch commands within same tick when possible
- Avoid redundant commands between ticks
```

**Configuration:**

```yaml
meta:
  server_ticks:
    enabled: true
    detection:
      auto_detect: true
      assumed_tick_ms: 50
    optimization:
      packet_timing: true
      skill_timing: true
      movement_sync: true
    calibration:
      enabled: true
      sample_size: 100
```

---

### 36.2 Experience Chain Maintenance

**Priority:** P1 (Important)

**What it does:** Tracks chain timer, selects targets for chain maintenance, prevents chain breaks, calculates optimal chain length (up to 30% bonus).

**EXP Chain Mechanics:**

| Chain Level | EXP Bonus | Time Window |
|-------------|-----------|-------------|
| 1 | 0% | 30 sec |
| 2-4 | 5% | 30 sec |
| 5-9 | 10% | 30 sec |
| 10-14 | 15% | 30 sec |
| 15-19 | 20% | 30 sec |
| 20+ | 30% | 30 sec |

**Chain Maintenance Strategy:**

```python
class ExpChainManager:
    CHAIN_WINDOW_SECONDS = 30
    TARGET_CHAIN_LEVEL = 20
    
    def should_rush_kill(self, chain_level: int, timer_remaining: float):
        """Determine if we need to rush a kill to maintain chain."""
        if timer_remaining < 5:
            return True
        if chain_level >= self.TARGET_CHAIN_LEVEL and timer_remaining < 10:
            return True
        return False
    
    def select_chain_target(self, nearby_monsters: list, time_to_kill: dict):
        """Select fastest kill target to maintain chain."""
        # Prioritize monsters we can kill before chain expires
        for monster in sorted(nearby_monsters, key=lambda m: time_to_kill[m.id]):
            if time_to_kill[monster.id] < self.chain_timer_remaining:
                return monster
        return nearby_monsters[0] if nearby_monsters else None
```

**Configuration:**

```yaml
meta:
  exp_chain:
    enabled: true
    tracking:
      chain_timer: true
      chain_level: true
      visual_indicator: true
    maintenance:
      target_selection: true
      prevent_break: true
      rush_kills: true
    optimization:
      target_chain_level: 20
      timer_buffer_seconds: 5
```

---

### 36.3 Monster AI Pattern Learning

**Priority:** P2 (Enhancement)

**What it does:** Classifies behavior patterns, detects aggressive vs passive, learns skill patterns, predicts movement.

**Monster Behavior Categories:**

| Behavior | Detection | AI Response |
|----------|-----------|-------------|
| Aggressive | Attacks on sight | Pre-emptive positioning |
| Passive | Ignores until attacked | Safe to ignore |
| Assist | Helps nearby monsters | Isolate targets |
| Looter | Steals drops | Prioritize loot pickup |
| Cast | Uses magic skills | Interrupt or kite |
| Boss | Special patterns | Pattern recognition |

**ML-Based Pattern Learning:**

```python
class MonsterPatternLearner:
    """Learns and predicts monster behavior patterns."""
    
    def __init__(self):
        self.behavior_database = {}
        self.pattern_model = None
    
    def record_behavior(self, monster_id: int, action: str, context: dict):
        """Record observed monster behavior."""
        if monster_id not in self.behavior_database:
            self.behavior_database[monster_id] = []
        
        self.behavior_database[monster_id].append({
            "action": action,
            "context": context,
            "timestamp": time.time()
        })
    
    def predict_next_action(self, monster_id: int, context: dict) -> str:
        """Predict monster's next action based on learned patterns."""
        if self.pattern_model and monster_id in self.behavior_database:
            return self.pattern_model.predict(monster_id, context)
        return "unknown"
    
    def get_optimal_response(self, predicted_action: str) -> str:
        """Get optimal player response to predicted monster action."""
        responses = {
            "skill_cast": "interrupt_or_dodge",
            "charge": "kite_backward",
            "summon": "kill_summons_first",
            "heal": "burst_damage",
            "buff": "dispel_or_ignore"
        }
        return responses.get(predicted_action, "continue_attack")
```

**Configuration:**

```yaml
meta:
  monster_ai:
    enabled: true
    learning:
      behavior_classification: true
      aggressive_detection: true
      skill_patterns: true
      movement_patterns: true
    prediction:
      movement: true
      skill_usage: true
      confidence_threshold: 0.7
    database:
      save_patterns: true
      path: "./data/monster_patterns.db"
    ml_model:
      enabled: true
      model_type: random_forest
      retrain_interval_hours: 24
```

---

## Appendix E: Priority Matrix for 154 Missing Mechanics

This appendix provides a complete priority matrix for all mechanics documented in Sections 20-36.

### Priority Level Definitions

| Priority | Level | Description | Implementation Timeline |
|----------|-------|-------------|------------------------|
| P0 | Critical | Core functionality required for basic operation | Immediate |
| P1 | Important | Key features for competitive advantage | Phase 1 (1-3 months) |
| P2 | Enhancement | Valuable additions that improve experience | Phase 2 (3-6 months) |
| P3 | Nice-to-have | Optional features for completeness | Phase 3 (6+ months) |

### Complete Priority Matrix by Section

#### Section 20: Companion Systems (7 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 1 | Pet feeding optimization | P2 | Low | Pet packet parsing |
| 2 | Pet intimacy tracking | P2 | Low | Pet state |
| 3 | Pet evolution system | P2 | Medium | Intimacy tracking |
| 4 | Homunculus stat distribution | P1 | Medium | Class detection |
| 5 | Homunculus skill allocation | P1 | Medium | Stat distribution |
| 6 | Mercenary contract management | P2 | Low | Timer system |
| 7 | Mount system automation | P2 | Low | Class detection |

#### Section 21: Consumable & Buff Management (8 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 8 | Food buff database | P1 | Low | Item database |
| 9 | Buff duration parsing | P0 | Medium | Packet parsing |
| 10 | Buff refresh automation | P0 | Low | Duration parsing |
| 11 | Buff conflict detection | P1 | Medium | Buff database |
| 12 | Recovery item prioritization | P0 | Medium | HP/SP monitoring |
| 13 | Catalyst tracking | P1 | Low | Inventory system |
| 14 | Elemental converter management | P1 | Low | Monster elements |
| 15 | Cost-per-HP calculations | P2 | Low | Item database |

#### Section 22: Instance/Dungeon Systems (8 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 16 | Instance creation automation | P1 | Medium | Party system |
| 17 | Instance navigation | P1 | High | Pathfinding |
| 18 | Boss pattern recognition | P2 | High | ML system |
| 19 | Cooldown tracking | P1 | Low | Timer system |
| 20 | Daily limit tracking | P1 | Low | Timer system |
| 21 | Multi-character management | P2 | Medium | Account system |
| 22 | Reward collection | P1 | Low | Inventory |
| 23 | Difficulty assessment | P2 | Medium | Monster database |

#### Section 23: Crafting Systems (10 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 24 | Blacksmith forging | P2 | Medium | Recipe database |
| 25 | Alchemist brewing | P2 | Medium | Recipe database |
| 26 | Rune creation | P2 | Medium | Material tracking |
| 27 | Genetics creation | P2 | Medium | Cart system |
| 28 | Shadow equipment crafting | P2 | Medium | Equipment system |
| 29 | Costume synthesis | P3 | Low | Collection tracking |
| 30 | Material gathering automation | P2 | Medium | Pathfinding |
| 31 | Success rate calculation | P2 | Low | Stat system |
| 32 | Cost-benefit analysis | P2 | Medium | Market data |
| 33 | Recipe database | P1 | Low | Data storage |

#### Section 24: Enchanting & Refining (10 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 34 | Socket enchant optimization | P2 | Medium | Enchant database |
| 35 | Refine strategy engine | P1 | Medium | Success rate data |
| 36 | HD ore decision making | P2 | Medium | Market prices |
| 37 | Over-refine ROI | P3 | Medium | Market data |
| 38 | Expected value calculations | P1 | Low | Math utilities |
| 39 | Safe refine automation | P1 | Low | Refine system |
| 40 | Enriched ore usage | P2 | Low | Inventory |
| 41 | Shadow enchanting | P3 | Medium | Shadow system |
| 42 | NPC-specific mechanics | P2 | Low | NPC database |
| 43 | Budget allocation | P2 | Low | Economy system |

#### Section 25: Achievement Systems (5 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 44 | Achievement database | P3 | Low | Data storage |
| 45 | Progress tracking | P3 | Low | Achievement DB |
| 46 | Title management | P3 | Low | Equipment system |
| 47 | Reward collection | P3 | Low | Inventory |
| 48 | Situational title swap | P3 | Low | Title system |

#### Section 26: Hunting & Daily Systems (8 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 49 | Eden quest parsing | P1 | Medium | NPC interaction |
| 50 | Quest board automation | P1 | Medium | Quest system |
| 51 | Hunting board system | P1 | Medium | Quest system |
| 52 | Daily mission rotation | P2 | Low | Timer system |
| 53 | Gramps quest system | P1 | Medium | Quest system |
| 54 | Multi-quest optimization | P1 | Medium | Pathfinding |
| 55 | Turn-in automation | P1 | Low | NPC interaction |
| 56 | Equipment reward selection | P2 | Low | Equipment system |

#### Section 27: Advanced Combat (16 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 57 | Animation canceling | P1 | High | Frame data |
| 58 | Skill chaining | P1 | High | Combo database |
| 59 | Combo optimization | P1 | High | Skill system |
| 60 | Status effect priority | P0 | Medium | Status database |
| 61 | Auto-cure mechanisms | P0 | Low | Item usage |
| 62 | Emergency teleport | P0 | Low | Teleport system |
| 63 | Cast time optimization | P1 | Medium | Stat calculations |
| 64 | DEX breakpoints | P1 | Low | Stat system |
| 65 | Bragi integration | P1 | Medium | Party detection |
| 66 | ASPD optimization | P1 | Medium | Stat calculations |
| 67 | After-cast delay | P1 | Medium | Skill database |
| 68 | Element conversion | P1 | Low | Element database |
| 69 | Endow coordination | P1 | Medium | Party system |
| 70 | Perfect dodge calc | P2 | Low | Stat system |
| 71 | SP efficiency | P1 | Low | Combat system |
| 72 | DPS calculations | P1 | Medium | Damage formulas |

#### Section 28: PvP/WoE Systems (12 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 73 | WoE supply stocking | P2 | Low | Inventory |
| 74 | Castle entry strategy | P2 | Medium | Navigation |
| 75 | Emperium tactics | P2 | Medium | WoE system |
| 76 | Guardian prioritization | P2 | Medium | WoE system |
| 77 | Barricade destruction | P2 | Medium | WoE system |
| 78 | BG type detection | P2 | Low | Map detection |
| 79 | BG role assignment | P2 | Medium | Class detection |
| 80 | GvG target priority | P1 | Medium | Targeting system |
| 81 | Focus fire coordination | P2 | High | Party system |
| 82 | Kill/death optimization | P2 | Medium | Combat analysis |
| 83 | Retreat triggers | P2 | Low | HP monitoring |
| 84 | Equipment detection | P2 | Medium | Player inspection |

#### Section 29: Human Mimicry (12 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 85 | Bezier curve paths | P0 | Medium | Movement system |
| 86 | Random pause injection | P0 | Low | Timer system |
| 87 | Path deviation | P0 | Low | Pathfinding |
| 88 | Backtracking simulation | P0 | Low | Movement system |
| 89 | Typing speed simulation | P1 | Low | Chat system |
| 90 | Typo injection | P1 | Low | Chat system |
| 91 | Response time variance | P0 | Low | Timer system |
| 92 | Session scheduling | P0 | Medium | Timer system |
| 93 | Break patterns | P0 | Medium | Schedule system |
| 94 | Mistake injection | P1 | Medium | Action system |
| 95 | Attention drift | P1 | Medium | Reaction system |
| 96 | Fatigue simulation | P1 | Medium | Session tracking |

#### Section 30: Environmental Systems (8 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 97 | Weather tracking | P3 | Low | Map system |
| 98 | Weather stat adjustment | P3 | Low | Stat system |
| 99 | Hazard detection | P2 | Medium | Map analysis |
| 100 | Hazard avoidance | P2 | Medium | Pathfinding |
| 101 | Spawn point mapping | P1 | Medium | Map analysis |
| 102 | Respawn timer learning | P1 | Medium | ML system |
| 103 | Hidden passage discovery | P3 | High | Exploration |
| 104 | Terrain tactics | P2 | High | Combat system |

#### Section 31: Economy Deep Dive (10 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 105 | Price history tracking | P2 | Medium | Market system |
| 106 | Moving averages | P2 | Low | Math utilities |
| 107 | Volatility detection | P2 | Medium | Price tracking |
| 108 | Buy/sell signals | P2 | Medium | Analysis system |
| 109 | Arbitrage detection | P2 | Medium | Price tracking |
| 110 | Vending location optimization | P2 | Medium | Map heatmaps |
| 111 | Competitive pricing | P2 | Medium | Market data |
| 112 | Investment timing | P3 | Medium | Market analysis |
| 113 | Buying store optimization | P2 | Medium | Market data |
| 114 | Budget allocation | P2 | Low | Economy system |

#### Section 32: Time-Sensitive Mechanics (8 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 115 | Server time sync | P1 | Medium | Network system |
| 116 | Timezone handling | P1 | Low | Time utilities |
| 117 | Day/night detection | P2 | Low | Packet parsing |
| 118 | Night-only spawns | P2 | Low | Spawn system |
| 119 | Star Gladiator bonuses | P2 | Low | Class system |
| 120 | Event calendar | P2 | Low | Data storage |
| 121 | Double EXP detection | P1 | Low | Chat parsing |
| 122 | Event participation | P2 | Medium | Event system |

#### Section 33: Job-Specific Mechanics (20 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 123 | Bard/Dancer ensemble | P2 | Medium | Party detection |
| 124 | Super Novice death prevention | P2 | Low | HP monitoring |
| 125 | Angel Blessing trigger | P2 | Low | Class system |
| 126 | Taekwon ranking | P3 | Medium | Ranking system |
| 127 | Star Gladiator hatred | P2 | Medium | Class system |
| 128 | Soul Linker spirits | P2 | Medium | Class detection |
| 129 | Ninja ammo management | P1 | Low | Inventory |
| 130 | Gunslinger ammo | P1 | Low | Inventory |
| 131 | Mechanic Mado fuel | P1 | Low | Class system |
| 132 | Mado repair automation | P1 | Low | Class system |
| 133 | Royal Guard Devotion | P1 | Medium | Party system |
| 134 | Devotion range management | P1 | Medium | Position tracking |
| 135 | Warlock spellbook | P2 | Medium | Skill system |
| 136 | Release timing | P2 | Medium | Combat timing |
| 137 | Genetic plants | P2 | Medium | Skill system |
| 138 | Bomb placement | P2 | Medium | Position system |
| 139 | Chain explosions | P2 | High | Timing system |
| 140 | Rune Knight runes | P2 | Medium | Crafting system |
| 141 | Ranger Warg | P2 | Low | Mount system |
| 142 | Sorcerer elementals | P2 | Medium | Summon system |

#### Section 34: Mini-Games (6 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 143 | Poring Catch | P3 | Low | Click timing |
| 144 | Monster Racing | P3 | Low | Betting system |
| 145 | Rock Paper Scissors | P3 | Low | Random system |
| 146 | Disguise event | P3 | Low | Monster database |
| 147 | Find the Mushroom | P3 | Low | Search pattern |
| 148 | Quiz events | P3 | Low | Answer database |

#### Section 35: Advanced Navigation (5 mechanics)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 149 | Safe zone mapping | P1 | Medium | Map analysis |
| 150 | Emergency routing | P1 | Medium | Pathfinding |
| 151 | Mob train detection | P0 | Medium | Monster tracking |
| 152 | Train response | P0 | Low | Emergency system |
| 153 | LOS calculations | P2 | Medium | Map data |

#### Section 36: Hidden Patterns (1 mechanics set)

| # | Mechanic | Priority | Complexity | Dependencies |
|---|----------|----------|------------|--------------|
| 154 | Server tick awareness | P2 | Medium | Network timing |
| 155 | EXP chain maintenance | P1 | Medium | Kill tracking |
| 156 | Monster AI learning | P2 | High | ML system |

### Implementation Priority Summary

| Priority | Count | Percentage |
|----------|-------|------------|
| P0 (Critical) | 15 | 9.6% |
| P1 (Important) | 55 | 35.3% |
| P2 (Enhancement) | 68 | 43.6% |
| P3 (Nice-to-have) | 18 | 11.5% |
| **Total** | **156** | **100%** |

### Recommended Implementation Order

**Phase 1: Critical Foundation (P0 - 15 mechanics)**
1. Buff duration parsing and refresh
2. Recovery item prioritization
3. Status effect management
4. Emergency teleport system
5. Movement humanization (Bezier, pauses, deviation)
6. Response timing variation
7. Session scheduling and breaks
8. Mob train detection and response

**Phase 2: Core Features (P1 - 55 mechanics)**
1. Homunculus management
2. Food and catalyst management
3. Instance and quest systems
4. Combat optimization (cast time, ASPD, combos)
5. Element conversion system
6. Server time and event detection
7. Class-specific critical mechanics (ammo, Devotion, Mado)
8. Advanced navigation

**Phase 3: Enhancements (P2 - 68 mechanics)**
1. Crafting and enchanting systems
2. Economy and market analysis
3. PvP/WoE tactics
4. Boss pattern recognition
5. Additional class mechanics
6. Environmental awareness
7. ML-based learning systems

**Phase 4: Polish (P3 - 18 mechanics)**
1. Achievement tracking
2. Mini-games
3. Weather effects
4. Hidden passages
5. Investment timing

---

*Document Updated: Version 3.0.0*
*154 Missing Mechanics Added*
*Total Sections: 36 + Appendices*
