# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.
> Last updated: 2026-04-14 (Session 3 — Combatant Data Model added)

---

## System Index

| System | Bucket File | Status | Layer |
|--------|------------|--------|-------|
| [Combat Manager](#combat-manager) | [combat_manager.md](combat_manager.md) | ✅ Active (3D) + Legacy (2D) | Core |
| [Grid System](#grid-system) | [grid_system.md](grid_system.md) | ✅ Active (3D) + Legacy (2D) | Core |
| [Unit System](#unit-system) | [unit_system.md](unit_system.md) | ✅ Active (3D) + Legacy (2D) | Core |
| [QTE System](#qte-system) | [qte_system.md](qte_system.md) | ✅ Active | Core |
| [Camera System](#camera-system) | [camera_system.md](camera_system.md) | ✅ Active (3D only) | Presentation |
| [HUD System](#hud-system) | [hud_system.md](hud_system.md) | ✅ Active (duck-typed) | Presentation |
| [Stat Panel](#stat-panel) | *(see combatant_data.md)* | ✅ Active | Presentation |
| [Combatant Data Model](#combatant-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active (3D) | Data |
| [Unit Data Resource](#unit-data-resource) | [unit_data.md](unit_data.md) | ⚠️ Legacy (2D only) | Data |
| [Game State](#game-state) | [game_state.md](game_state.md) | 🔲 Stub | Global |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D           (cell queries, highlights, world↔grid math)
  ├── Unit3D ×6        (HP/energy state, movement, animations)
  ├── QTEBar           (skill-check overlay → accuracy float)
  ├── HUD              (display refresh after every state change)
  ├── CameraController (built by CM3D; shake on hit)
  ├── StatPanel        (unit stat overlay; shown on select, hidden on deselect)
  └── ArchetypeLibrary (creates CombatantData for each unit at scene load)

Unit3D
  └── CombatantData    (stat source — replaces UnitData for 3D)

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
CanvasLayer overlay (layer 8) that pops up when any unit is clicked, showing the complete `CombatantData` for that unit: identity, archetype, background, class, attributes, all derived stats, equipment slots, and ability pool. Hidden on deselect and combat end. Lives in `scripts/ui/StatPanel.gd`.

### Combatant Data Model
Two-file system: `CombatantData` (Resource) stores identity, core attributes, and slot data; all derived combat stats are computed properties. `ArchetypeLibrary` (static class) defines 5 archetypes and provides `create()` to instantiate randomized `CombatantData`. See `combatant_data.md` for full field reference.

### Unit Data Resource (Legacy)
Superseded by `CombatantData` for the 3D system. Kept alive for `Unit.gd` (2D) and its test suite. See `unit_data.md`.

### Game State
Autoload singleton stub. Intended for run-wide data (party roster, items, map progress). Not yet wired to any system.

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
│   │   ├── HUD.gd
│   │   └── StatPanel.gd         ← unit stat overlay (3D)
│   └── globals/
│       ├── ArchetypeLibrary.gd  ← archetype factory (3D)
│       └── GameState.gd
└── resources/
    ├── CombatantData.gd         ← active data resource (3D)
    └── UnitData.gd              ← legacy data resource (2D only)
```
