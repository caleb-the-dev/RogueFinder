# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.
> Last updated: 2026-04-14 (Session 2 — Stage 1.5 complete)

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
| [Unit Data Resource](#unit-data-resource) | [unit_data.md](unit_data.md) | ✅ Active | Data |
| [Game State](#game-state) | [game_state.md](game_state.md) | 🔲 Stub | Global |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D          (cell queries, highlights, world↔grid math)
  ├── Unit3D ×6       (HP/energy state, movement, animations)
  ├── QTEBar          (skill-check overlay → accuracy float)
  ├── HUD             (display refresh after every state change)
  ├── CameraController(built by CM3D; shake on hit)
  └── UnitData        (stat resource passed into Unit3D.setup())

Unit3D
  └── UnitData        (stat source)

GameState             (autoload stub — not yet wired to anything)
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

### Unit Data Resource
`@tool` Resource class. Holds all unit stats as `@export` fields. The only data contract between the Combat Manager (which constructs it) and Unit3D (which reads it via `setup()`).

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
│   ├── ui/HUD.gd
│   └── globals/GameState.gd
└── resources/UnitData.gd
```
