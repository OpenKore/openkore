# AI Sidecar Configuration Guide

## Quick Start

By default, **all AI features are enabled** for full automation. To customize which features your bot uses, follow these steps:

### 1. Copy the Template

```bash
cd openkore-AI/ai_sidecar/config
cp subsystems.yaml.example subsystems.yaml
```

### 2. Edit the Configuration

Open `config/subsystems.yaml` in your editor and modify the subsystems you want to enable/disable.

### 3. Restart AI Sidecar

Restart the AI Sidecar to apply your changes. On startup, you'll see a summary of enabled subsystems:

```
============================================================
AI Sidecar Subsystem Status
============================================================
✅ ENABLED   SOCIAL
✅ ENABLED   PROGRESSION
✅ ENABLED   COMBAT
❌ DISABLED  COMPANIONS
✅ ENABLED   CONSUMABLES
...
============================================================
```

## Configuration Structure

### Basic Format

```yaml
subsystems:
  subsystem_name:
    enabled: true/false
    description: "What this subsystem does"
    features:
      feature_name: true/false
```

### Example: Disable a Subsystem

```yaml
subsystems:
  companions:
    enabled: false  # Disables all companion management
```

### Example: Disable Specific Features

```yaml
subsystems:
  progression:
    enabled: true
    features:
      auto_stat_allocation: true
      auto_skill_allocation: false  # Manual skill allocation only
      job_advancement: true
```

## Available Subsystems

### 🤝 Social Systems
**Purpose**: Chat responses, party coordination, guild management, MVP hunting

**When to disable**: Solo farming, AFK leveling, testing

**Features**:
- `chat_responses`: Auto-respond to chat messages
- `party_coordination`: Coordinate with party members
- `guild_management`: Guild-related automation
- `mvp_hunting`: MVP coordination and tracking

```yaml
social:
  enabled: true
  features:
    chat_responses: true
    party_coordination: true
    guild_management: true
    mvp_hunting: true
```

### 📈 Progression Systems
**Purpose**: Auto stat/skill allocation, job advancement

**When to disable**: Manual character building, pre-configured builds

**Features**:
- `auto_stat_allocation`: Automatic stat point distribution
- `auto_skill_allocation`: Automatic skill point distribution
- `job_advancement`: Auto job change when eligible

```yaml
progression:
  enabled: true
  features:
    auto_stat_allocation: true
    auto_skill_allocation: true
    job_advancement: true
```

### ⚔️ Combat Systems
**Purpose**: Tactical combat, skill rotation, target selection

**When to disable**: Never (core functionality)

**Features**:
- `skill_usage`: AI-driven skill usage
- `target_selection`: Smart target prioritization
- `tactical_positioning`: Movement during combat
- `emergency_actions`: Emergency healing/escape

```yaml
combat:
  enabled: true
  features:
    skill_usage: true
    target_selection: true
    tactical_positioning: true
    emergency_actions: true
```

### 🐾 Companion Systems
**Purpose**: Pet, homunculus, mercenary, mount management

**When to disable**: No companions, manual companion control

**Features**:
- `pet_management`: Pet feeding and care
- `homunculus_ai`: Homunculus AI and evolution
- `mercenary_coordination`: Mercenary hiring and tactics
- `mount_optimization`: Mount usage optimization

```yaml
companions:
  enabled: true
  features:
    pet_management: true
    homunculus_ai: true
    mercenary_coordination: true
    mount_optimization: true
```

### 💊 Consumable Systems
**Purpose**: Buff maintenance, auto-healing, status cure

**When to disable**: Manual buff/heal management (not recommended)

**Features**:
- `buff_maintenance`: Keep buffs active
- `auto_healing`: Automatic HP/SP recovery
- `status_cure`: Auto-cure status ailments
- `food_buffs`: Food buff management

```yaml
consumables:
  enabled: true
  features:
    buff_maintenance: true
    auto_healing: true
    status_cure: true
    food_buffs: true
```

### ⚙️ Equipment Systems
**Purpose**: Equipment scoring and recommendations

**When to disable**: Manual equipment management

**Features**:
- `equipment_evaluation`: Score equipment quality
- `auto_equip_recommendations`: Suggest better gear

```yaml
equipment:
  enabled: true
  features:
    equipment_evaluation: true
    auto_equip_recommendations: true
```

### 💰 Economy Systems
**Purpose**: Market analysis, vendor scanning, storage management

**When to disable**: Manual trading, simple farming

**Features**:
- `market_analysis`: Track market prices
- `vendor_scanning`: Find best vendor prices
- `storage_management`: Auto-storage optimization
- `price_intelligence`: Price tracking and alerts

```yaml
economy:
  enabled: true
  features:
    market_analysis: true
    vendor_scanning: true
    storage_management: true
    price_intelligence: true
```

### 🗣️ NPC/Quest Systems
**Purpose**: NPC dialogue automation, quest tracking

**When to disable**: Manual questing, no quest automation

**Features**:
- `npc_automation`: Auto NPC dialogue
- `quest_tracking`: Quest progress tracking
- `daily_quests`: Daily quest automation

```yaml
npc_quest:
  enabled: true
  features:
    npc_automation: true
    quest_tracking: true
    daily_quests: true
```

### 🏰 Instance Systems
**Purpose**: Endless Tower, Memorial Dungeon automation

**When to disable**: Manual instance runs

**Features**:
- `endless_tower`: Endless Tower navigation
- `memorial_dungeons`: Memorial Dungeon automation

```yaml
instances:
  enabled: true
  features:
    endless_tower: true
    memorial_dungeons: true
```

### 🌤️ Environment Systems
**Purpose**: Time/weather awareness, event detection

**When to disable**: Simple farming, environment doesn't matter

**Features**:
- `day_night_optimization`: Day/night cycle optimization
- `weather_awareness`: Weather-based decisions
- `event_detection`: In-game event detection

```yaml
environment:
  enabled: true
  features:
    day_night_optimization: true
    weather_awareness: true
    event_detection: true
```

## Common Configuration Scenarios

### Combat Bot Only

Minimal setup for pure combat farming:

```yaml
subsystems:
  social: {enabled: false}
  progression: {enabled: false}
  combat: {enabled: true}
  companions: {enabled: false}
  consumables: {enabled: true}  # Keep for survival
  equipment: {enabled: false}
  economy: {enabled: false}
  npc_quest: {enabled: false}
  instances: {enabled: false}
  environment: {enabled: false}
```

### Party Support Role

Optimized for party healing/buffing:

```yaml
subsystems:
  social: {enabled: true}      # Party coordination
  progression: {enabled: false}
  combat: {enabled: true}       # Support skills
  companions: {enabled: true}   # Homunculus support
  consumables: {enabled: true}  # Buff/heal management
  equipment: {enabled: false}
  economy: {enabled: false}
  npc_quest: {enabled: false}
  instances: {enabled: false}
  environment: {enabled: false}
```

### Farming with Market Intelligence

Combat farming with economy features:

```yaml
subsystems:
  social: {enabled: false}
  progression: {enabled: false}
  combat: {enabled: true}
  companions: {enabled: false}
  consumables: {enabled: true}
  equipment: {enabled: true}    # Equipment evaluation
  economy: {enabled: true}      # Market tracking
  npc_quest: {enabled: false}
  instances: {enabled: false}
  environment: {enabled: false}
```

### Leveling Bot

Full automation for leveling:

```yaml
subsystems:
  social: {enabled: false}
  progression: {enabled: true}  # Auto stat/skill allocation
  combat: {enabled: true}
  companions: {enabled: true}   # Pet for extra damage
  consumables: {enabled: true}
  equipment: {enabled: true}    # Gear recommendations
  economy: {enabled: false}
  npc_quest: {enabled: true}    # Quest XP
  instances: {enabled: false}
  environment: {enabled: false}
```

### AFK Farmer

Safe AFK farming setup:

```yaml
subsystems:
  social: {enabled: false}
  progression: {enabled: false}
  combat: {enabled: true}
  companions: {enabled: false}
  consumables: {enabled: true}
  equipment: {enabled: false}
  economy: {enabled: false}
  npc_quest: {enabled: false}
  instances: {enabled: false}
  environment: {enabled: false}
  
# Disable risky features within combat
combat:
  enabled: true
  features:
    skill_usage: true
    target_selection: true
    tactical_positioning: false  # Stay in one spot
    emergency_actions: true
```

## Using Presets

The configuration file includes preset templates for common scenarios:

```yaml
presets:
  full_automation:
    description: "All features enabled (default)"
    enable_all: true
  
  combat_only:
    description: "Only combat features"
    enable: [core, combat, consumables, companions]
  
  farming:
    description: "Optimized for farming"
    enable: [core, combat, consumables, equipment, economy]
```

**Note**: Presets are templates only. To use a preset, manually copy its configuration to the `subsystems` section.

## Verifying Configuration

### Method 1: Check Startup Logs

Watch the startup output for the subsystem status table.

### Method 2: Python Script

```bash
python -c "from ai_sidecar.config.loader import get_config; print(get_config().get_enabled_subsystems())"
```

### Method 3: Config Summary

```python
from ai_sidecar.config.loader import get_config

config = get_config()
summary = config.get_config_summary()
print(f"Enabled: {summary['enabled_subsystems']}/{summary['total_subsystems']}")
```

## Advanced Configuration

### Feature-Level Control

Disable specific features while keeping the subsystem active:

```yaml
consumables:
  enabled: true
  features:
    buff_maintenance: true
    auto_healing: true
    status_cure: false     # Manual status management
    food_buffs: false      # No food buffs
```

### Hybrid Configurations

Mix automated and manual control:

```yaml
progression:
  enabled: true
  features:
    auto_stat_allocation: true   # Auto stats
    auto_skill_allocation: false # Manual skills
    job_advancement: false       # Manual job change
```

## Troubleshooting

### Configuration Not Loading

1. Check file location: `ai_sidecar/config/subsystems.yaml`
2. Verify YAML syntax (use a YAML validator)
3. Check file permissions
4. Review startup logs for error messages

### Subsystem Not Disabling

1. Restart AI Sidecar completely
2. Verify `enabled: false` (not `enabled: False` or `enabled: no`)
3. Check for typos in subsystem names
4. Ensure proper YAML indentation

### Features Still Active

1. Verify the parent subsystem is enabled
2. Check feature names match exactly
3. Feature-level overrides require parent subsystem enabled

## Best Practices

### ✅ Do

- Start with all enabled, disable as needed
- Test configuration changes in safe areas
- Keep `consumables` enabled for survival
- Use feature-level control for fine-tuning
- Document your custom configurations

### ❌ Don't

- Don't disable `core` (it's always required)
- Don't disable `combat` for farming bots
- Don't disable `consumables` without good reason
- Don't modify subsystems.yaml.example (copy it first)
- Don't use tabs for indentation (use spaces)

## Configuration Examples Repository

More examples available in the project wiki and community forums.

## Need Help?

- Check the [AI Sidecar Bridge Guide](docs/AI_SIDECAR_BRIDGE_GUIDE.md)
- Review startup logs for configuration issues
- Test with `combat_only` preset first
- Ask in project discussions

## Configuration Migration

When upgrading AI Sidecar versions:

1. Backup your current `subsystems.yaml`
2. Review new `subsystems.yaml.example` for changes
3. Merge your customizations with new defaults
4. Test thoroughly after upgrade