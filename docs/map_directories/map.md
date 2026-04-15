# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.
> Last updated: 2026-04-14 (Session 3 — ActionMenu, AbilityData, AbilityLibrary added)

---

## System Index

| System | Bucket File | Status | Layer |
|--------|------------|--------|-------|
| [Combat Manager](#combat-manager) | [combat_manager.md](combat_manager.md) | ✅ Active (3D) + Legacy (2D) | Core |
| [Grid System](#grid-system) | [grid_system.md](grid_system.md) | ✅ Active (3D) + Legacy (2D) | Core |
| [Unit System](#unit-system) | [unit_system.md](unit_system.md) | ✅ Active (3D) + Legacy (2D) | Core |
| [QTE System](#qte-system) | [qte_system.md](qte_system.md) | ✅ Active | Core |
| [Camera System](#camera-system) | [camera_system.md](camera_system.md) | ✅ Active (3D only) | Presentation |
| [HUD System](#hud-system) | [hud_system.md](hud_system.md) | ⚠️ Legacy 2D only | Presentation |
| [Stat Panel](#stat-panel) | [hud_system.md](hud_system.md) | ✅ Active (double-click examine) | Presentation |
| [Unit Info Bar](#unit-info-bar) | [hud_system.md](hud_system.md) | ✅ Active (single-click strip) | Presentation |
| [Combatant Data Model](#combatant-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active (3D) | Data |
| [Unit Data Resource](#unit-data-resource) | [unit_data.md](unit_data.md) | ⚠️ Legacy (2D only) | Data |
| [Game State](#game-state) | [game_state.md](game_state.md) | 🔲 Stub | Global |
| [Action Menu](#action-menu) | [hud_system.md](hud_system.md) | ✅ Active | Presentation |
| [Ability Data Model](#ability-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Ability Library](#ability-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D           (cell queries, highlights, world↔grid math)
  ├── Unit3D ×6        (HP/energy state, movement, animations)
  ├── QTEBar           (skill-check overlay → accuracy float)
  ├── CameraController (built by CM3D; shake on hit)
  ├── UnitInfoBar      (condensed strip; shown on single-click)
  ├── StatPanel        (full examine window; shown on double-click)
  ├── ArchetypeLibrary (creates CombatantData for each unit at scene load)
  └── ActionMenu       (radial pop-up; signals ability_selected, consumable_selected)

Unit3D
  ├── CombatantData    (stat source — replaces UnitData for 3D)
  └── AbilityLibrary   (looked up by ActionMenu and CombatManager3D)

StatPanel
  └── CombatantData    (reads all fields for display)

ArchetypeLibrary
  └── CombatantData    (creates instances)

GameState              (autoload stub — not yet wired to anything)
```

---

## System Summaries

### Combat Manager
The central turn state machine. Owns all other scene nodes (builds them in `_ready()`). Routes player input, runs enemy AI, drives win/lose conditions. Lives in `CombatScene3D.tscn`.

### Grid System
Tracks which cells are occupied, calculates move ranges, manages per-cell color highlights. Handles world↔grid coordinate math and mouse→cell raycasting.

### Unit System
Stateful game object: HP, energy, turn flags (has_moved, has_acted). Renders as a colored box mesh in 3D. Emits `unit_died` and `unit_moved` signals. Plays lunge/flash animations.

### QTE System
Standalone sliding-bar skill check. Displayed as a CanvasLayer overlay. Emits `qte_resolved(accuracy: float)` when resolved. Used for both player attacks and enemy attacks (enemy uses `qte_resolution` stat to simulate auto-accuracy).

### Camera System
DOS2-style isometric orbit camera. Supports Q/E 45° rotation, scroll zoom, and procedural camera shake (`trigger_shake()`). Built and owned by CombatManager3D.

### HUD System
CanvasLayer that displays HP and energy as ASCII bars for all 6 units. Duck-typed `refresh()` accepts both `Unit` (2D) and `Unit3D` arrays — no explicit type dependency.

### Stat Panel
CanvasLayer overlay (layer 8) opened on **double-click** of any unit. Shows the complete `CombatantData`: portrait, identity, attributes, derived stats, equipment, abilities (no artwork section). Scrollable. Closed by the ✕ button or ESC. Lives in `scripts/ui/StatPanel.gd`.

### Unit Info Bar
Condensed CanvasLayer strip (layer 4) at the bottom-center of the screen. Shown on **single-click** of any unit (player or enemy). Displays portrait, name, class, HP bar, energy bar, ATK/DEF/SPD. Hidden on deselect and combat end. Lives in `scripts/ui/UnitInfoBar.gd`.

### Combatant Data Model
Two-file system: `CombatantData` (Resource) stores identity, core attributes, and slot data; all derived combat stats are computed properties. `ArchetypeLibrary` (static class) defines 5 archetypes and provides `create()` to instantiate randomized `CombatantData`. See `combatant_data.md` for full field reference.

### Unit Data Resource (Legacy)
Superseded by `CombatantData` for the 3D system. Kept alive for `Unit.gd` (2D) and its test suite. See `unit_data.md`.

### Game State
Autoload singleton stub. Intended for run-wide data (party roster, items, map progress). Not yet wired to any system.

### Action Menu
CanvasLayer (layer 12) pop-up shown when a player unit is selected. D-pad layout: 4 ability buttons + 1 consumable center button. Projects the unit's 3D position to screen space. Emits `ability_selected(ability_id)` and `consumable_selected()`. Buttons grey out based on energy and `has_acted` state.

### Ability Data Model
`AbilityData` (Resource) stores all fields for a single ability: ID, name, tags, energy cost, range, target type, description, icon. `TargetType` enum: `SELF`, `SINGLE_ENEMY`, `SINGLE_ALLY`, `AOE`, `CONE`.

### Ability Library
`AbilityLibrary` (static class) defines 12 placeholder abilities and provides `get_ability(id) -> AbilityData`. Returns a safe stub for unknown IDs. Future CSV import will replace the inline dictionary without changing the API.

---

## File Locations

```
res://
├── scripts/
│   ├── camera/CameraController.gd
│   ├── combat/
│   │   ├── CombatManager3D.gd   ← active
│   │   ├── Unit3D.gd            ← active
│   │   ├── Grid3D.gd            ← active
│   │   ├── QTEBar.gd
│   │   ├── CombatManager.gd     ← legacy 2D
│   │   ├── Unit.gd              ← legacy 2D
│   │   └── Grid.gd              ← legacy 2D
│   ├── ui/
│   │   ├── HUD.gd               ← legacy 2D only
│   │   ├── StatPanel.gd         ← full examine window (double-click)
│   │   ├── UnitInfoBar.gd       ← condensed strip (single-click)
│   │   └── ActionMenu.gd        ← radial action pop-up (player unit selection)
│   └── globals/
│       ├── AbilityLibrary.gd    ← ability factory (12 placeholder abilities)
│       ├── ArchetypeLibrary.gd  ← archetype factory (3D)
│       └── GameState.gd
└── resources/
    ├── AbilityData.gd           ← ability data resource (TargetType enum + fields)
    ├── CombatantData.gd         ← active data resource (3D)
    └── UnitData.gd              ← legacy data resource (2D only)
```
