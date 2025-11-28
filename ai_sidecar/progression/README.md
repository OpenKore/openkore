# Character Progression Module

Autonomous character progression system for the God-Tier RO AI.

## Overview

This module implements **Phase 3** of the God-Tier AI specification, providing fully autonomous character progression from level 1 to endgame.

### Features

✅ **7-State Lifecycle FSM**: NOVICE → FIRST_JOB → SECOND_JOB → REBIRTH → THIRD_JOB → ENDGAME → OPTIMIZING  
✅ **Auto Stat Distribution**: Intelligent allocation based on build templates with RO stat formulas  
✅ **Job Advancement**: Automated job changes with NPC navigation and prerequisite tracking  
✅ **Build Templates**: 6 archetypes (Melee DPS, AGI Crit, Tank, Magic DPS, Support, Hybrid)  
✅ **Diminishing Returns**: Soft cap handling at 99/130 with penalty calculations  
✅ **State Persistence**: Lifecycle state saved across sessions  

## Architecture

```
progression/
├── lifecycle.py      # CharacterLifecycle FSM
├── stats.py          # StatDistributionEngine
├── job_advance.py    # JobAdvancementSystem
├── manager.py        # ProgressionManager (coordinator)
└── config.yaml       # Configuration
```

### Components

#### CharacterLifecycle
- Manages state transitions through RO progression phases
- Evaluates transition conditions based on levels
- Persists state across sessions
- Provides event hooks for external systems

#### StatDistributionEngine
- Implements RO stat cost formula: `cost = 1 + floor((stat_value - 1) / 10)`
- Auto-allocates points based on build templates
- Handles diminishing returns above soft caps
- Supports custom build ratios

#### JobAdvancementSystem
- Loads job paths and NPC locations from JSON
- Validates requirements (levels, zeny, items)
- Selects next job based on preferences or auto-detection
- Placeholder implementations for job tests

#### ProgressionManager
- Coordinates all progression systems
- Provides unified tick() interface for decision engine
- Priority: Lifecycle → Job Advancement → Stat Allocation
- Auto-detects build type from job class

## Usage

### Basic Usage

```python
from pathlib import Path
from ai_sidecar.progression import ProgressionManager, BuildType

# Initialize manager
manager = ProgressionManager(
    data_dir=Path("data"),
    state_dir=Path("data"),
    build_type=BuildType.HYBRID,
    soft_cap=99
)

await manager.initialize()

# Called every AI tick
actions = await manager.tick(game_state)

# Get progression status
status = manager.get_progression_status(game_state.character)
print(status["lifecycle"]["current_state"])  # "FIRST_JOB"
print(status["stats"]["build_type"])         # "melee_dps"
```

### Configuration

Edit [`progression/config.yaml`](progression/config.yaml) to customize:

```yaml
stats:
  build:
    type: "auto_detect"  # or melee_dps, tank, magic_dps, etc.
    soft_cap: 99         # 99 for pre-renewal, 130 for renewal

job_advancement:
  auto_advance: true
  preferred_path:
    "Swordman": "Knight"  # Choose Knight over Crusader
```

### Build Templates

| Build Type | STR | AGI | VIT | INT | DEX | LUK | Best For |
|------------|-----|-----|-----|-----|-----|-----|----------|
| MELEE_DPS  | 35% | 25% | 10% | 0%  | 25% | 5%  | Knights, Assassins |
| AGI_CRIT   | 25% | 35% | 5%  | 0%  | 15% | 20% | Assassins, Rogues |
| TANK       | 15% | 10% | 40% | 5%  | 20% | 10% | Crusaders, Paladins |
| MAGIC_DPS  | 0%  | 5%  | 15% | 45% | 30% | 5%  | Wizards, Sages |
| SUPPORT    | 0%  | 10% | 25% | 35% | 25% | 5%  | Priests, Monks |
| HYBRID     | 20% | 15% | 20% | 15% | 20% | 10% | Balanced |

## Integration

The progression manager is integrated into the decision engine:

```python
# In decision.py
from ai_sidecar.progression.manager import ProgressionManager

class ProgressionDecisionEngine(DecisionEngine):
    async def decide(self, state: GameState) -> DecisionResult:
        # Priority 1: Progression
        progression_actions = await self.progression_manager.tick(state)
        
        # Priority 2: Combat (Phase 4)
        # Priority 3: Economy (Phase 5)
        
        return DecisionResult(actions=progression_actions)
```

Enable in [`config.yaml`](../config.yaml):

```yaml
decision:
  engine_type: "rule_based"  # Enables progression
```

## Testing

Run unit tests:

```bash
cd openkore-AI/ai_sidecar
pytest tests/test_lifecycle.py -v
pytest tests/test_stats.py -v
pytest tests/test_job_advance.py -v
```

## Data Files

### job_paths.json
Defines job advancement paths with requirements:
- Job tier (1=Novice, 2=First, 3=Second, 4=Third)
- Level requirements
- Zeny costs
- Test requirements

### job_npcs.json
NPC locations for each job:
- Map name
- X/Y coordinates
- NPC name and ID

### stat_costs.json
Reference data for RO stat mechanics:
- Cost per stat level (1-130)
- Cumulative costs
- Soft/hard caps
- Stat effect descriptions

## Limitations

⚠️ **Phase 3 Scope**: This module focuses ONLY on progression:
- ✅ Lifecycle management
- ✅ Stat allocation
- ✅ Job advancement framework
- ❌ Combat AI (Phase 4)
- ❌ Equipment systems (Phase 5)
- ❌ Social features (Phase 6)

⚠️ **Job Test Placeholders**: Job test implementations are placeholders requiring server-specific logic.

## Future Enhancements

Phase 4+ will add:
- Combat AI integration for job tests
- Skill point allocation system
- Equipment progression
- Build optimization based on performance metrics

## License

Part of the God-Tier AI project.