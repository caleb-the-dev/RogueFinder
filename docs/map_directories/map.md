# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-18 |
| last_groomed | 2026-04-18 |
| sessions_since_groom | 0 |
| groom_trigger | 10 |

> **Grooming rule:** When `sessions_since_groom` reaches `groom_trigger`, run a grooming pass:
> remove entries for deleted files, update descriptions that no longer match the code,
> prune stale "not here" notes, verify bucket file accuracy. Reset `sessions_since_groom` to 0.

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
| [Action Menu](#action-menu) | [hud_system.md](hud_system.md) | ✅ Active | Presentation |
| [End Combat Screen](#end-combat-screen) | [hud_system.md](hud_system.md) | ✅ Active | Presentation |
| [Reward Generator](#reward-generator) | [hud_system.md](hud_system.md) | ✅ Active | Global |
| [Combatant Data Model](#combatant-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active (3D) | Data |
| [Ability Data Model](#ability-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Ability Library](#ability-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Consumable Data Model](#consumable-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Consumable Library](#consumable-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Equipment Data Model](#equipment-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Equipment Library](#equipment-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Unit Data Resource](#unit-data-resource) | [unit_data.md](unit_data.md) | ⚠️ Legacy (2D only) | Data |
| [Game State](#game-state) | [game_state.md](game_state.md) | ✅ Active (map traversal + save/load) | Global |
| [Map Scene](#map-scene) | [map_scene.md](map_scene.md) | ✅ Active (traversable + save/load) | World Map |

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
  ├── ActionMenu         (radial pop-up; signals ability_selected, consumable_selected)
  ├── EndCombatScreen    (victory/defeat overlay; shown by _end_combat())
  └── ArchetypeLibrary   (creates CombatantData for each unit at scene load)

EndCombatScreen
  └── RewardGenerator  (shuffled pool of EquipmentLibrary + ConsumableLibrary items)

RewardGenerator
  ├── EquipmentLibrary (all_equipment())
  └── ConsumableLibrary (CONSUMABLES dict)

Unit3D
  └── CombatantData    (stat source — replaces UnitData for 3D)

ActionMenu
  ├── AbilityLibrary      (looked up to build ability buttons)
  └── ConsumableLibrary   (looked up to build consumable button label + tooltip)

StatPanel
  └── CombatantData    (reads all fields for display)

ArchetypeLibrary
  └── CombatantData    (creates instances)

EquipmentLibrary
  └── EquipmentData    (creates instances)

CombatantData
  └── EquipmentData    (weapon / armor / accessory slots)

MapManager
  └── GameState        (reads player_node_id/visited_nodes/map_seed/node_types/cleared_nodes; calls move_player, save, load_save; sets pending_node_type before NodeStub transition; sets current_combat_node_id before CombatScene3D transition)

NodeStub
  └── GameState        (reads+clears pending_node_type)

EndCombatScreen
  ├── RewardGenerator  (shuffled pool of EquipmentLibrary + ConsumableLibrary items)
  └── GameState        (reads current_combat_node_id; appends to cleared_nodes; calls save() on reward selection)

GameState              (autoload — map traversal + save/load live; all other data deferred)
```

---

## System Summaries

### Combat Manager
The central turn state machine. Owns all other scene nodes (builds them in `_ready()`). Routes player input, runs enemy AI, drives the ability targeting flow, applies effects, and decides win/lose conditions. Lives in `CombatScene3D.tscn`.

### Grid System
Tracks which cells are occupied, calculates move ranges, manages per-cell color highlights. Handles world↔grid coordinate math and mouse→cell raycasting. Owns the `CellType` enum (NORMAL / WALL / HAZARD) and environment tile construction (`build_walls()`).

### Unit System
Stateful game object: HP, energy, turn flags (`has_moved`, `has_acted`). Renders as a colored box mesh in 3D. Emits `unit_died` and `unit_moved` signals. Plays lunge/flash animations.

### QTE System
Standalone sliding-bar skill check. Displayed as a CanvasLayer overlay. Emits `qte_resolved(accuracy: float)` when resolved. Used for both player attacks and enemy attacks (enemy uses `qte_resolution` stat to simulate auto-accuracy).

### Camera System
DOS2-style isometric orbit camera. Supports Q/E 45° rotation, scroll zoom, and procedural camera shake (`trigger_shake()`). Built and owned by CombatManager3D.

### HUD System
CanvasLayer that displays HP and energy as ASCII bars for all 6 units. Duck-typed `refresh()` accepts both `Unit` (2D) and `Unit3D` arrays. Legacy 2D only.

### Stat Panel
CanvasLayer overlay (layer 8) opened on double-click of any unit. Shows the complete `CombatantData`. Scrollable. Closed by ✕ or ESC. Lives in `scripts/ui/StatPanel.gd`.

### Unit Info Bar
Condensed CanvasLayer strip (layer 4). Shown on single-click of any unit. Displays name, class, HP bar, energy bar, ATK/DEF/SPD. Hidden on deselect and combat end.

### End Combat Screen
CanvasLayer overlay (layer 15) shown when combat ends. Victory shows a "VICTORY" header + 3 reward buttons from `RewardGenerator.roll(3)` — picking one immediately appends the node to `GameState.cleared_nodes`, saves, and returns to `MapScene.tscn` (no "Onward..." step). Defeat shows "DEFEAT" + "Return to Map" button (node is NOT cleared). Lives in `scripts/ui/EndCombatScreen.gd`.

### Reward Generator
Static utility (`scripts/globals/RewardGenerator.gd`). Combines all `EquipmentLibrary` and `ConsumableLibrary` items into one pool, Fisher-Yates shuffles, and returns `count` distinct Dicts (`id`, `name`, `description`, `item_type`).

### Action Menu
CanvasLayer (layer 12) pop-up shown when a player unit is selected. D-pad layout: 4 ability buttons + 1 consumable center button. Projects the unit's 3D position to screen space. Emits `ability_selected(ability_id)` and `consumable_selected()`. Buttons grey out based on energy and `has_acted` state.

### Combatant Data Model
Two-file system: `CombatantData` (Resource) stores identity, core attributes, and slot data; all derived combat stats are computed properties. `ArchetypeLibrary` (static class) defines 5 archetypes and provides `create()` to instantiate randomized `CombatantData`.

### Ability Data Model
`AbilityData` (Resource) stores all fields for a single ability. `EffectData` (Resource) stores one effect within an ability. `TargetShape` enum: `SELF`, `SINGLE`, `CONE`, `LINE`, `RADIAL`. `EffectType` enum: `HARM`, `MEND`, `FORCE`, `TRAVEL`, `BUFF`, `DEBUFF`.

### Ability Library
`AbilityLibrary` (static class) defines 22 abilities and provides `get_ability(id) -> AbilityData`. Returns a safe stub for unknown IDs. Future CSV import will replace the inline dictionary without changing the API.

### Consumable Data Model
`ConsumableData` (Resource) stores id, name, effect_type, base_value, target_stat, and description for a single consumable. Only MEND, BUFF, and DEBUFF are valid effect types — consumables never HARM, FORCE, or TRAVEL.

### Consumable Library
`ConsumableLibrary` (static class) defines consumables and provides `get_consumable(id) -> ConsumableData`. Never returns null. Currently defines `healing_potion` (MEND 15 HP) and `power_tonic` (BUFF STR +2).

### Equipment Data Model
`EquipmentData` (Resource) stores id, name, slot (WEAPON/ARMOR/ACCESSORY enum), `stat_bonuses` dict (attribute name → int delta), and description. `get_bonus(stat_name)` returns 0 for absent keys, never errors.

### Equipment Library
`EquipmentLibrary` (static class) defines 6 placeholder items (2 per slot) and provides `get_equipment(id) -> EquipmentData` (never null) and `all_equipment() -> Array[EquipmentData]` for reward pools. No archetype starts with equipment — gear comes from rewards.

### Unit Data Resource (Legacy)
Superseded by `CombatantData` for the 3D system. Kept alive for `Unit.gd` (2D) and its test suite.

### Game State
Autoload singleton. Map traversal and save/load are live: tracks `player_node_id`, `visited_nodes`, `map_seed`, `node_types`, and `cleared_nodes` (all saved to disk); `pending_node_type` and `current_combat_node_id` are transient handoffs between scenes. Exposes `move_player()`, `is_visited()`, `is_adjacent_to_player()`, `save()`, `load_save()`, `delete_save()`, `reset()`. Save path: `user://save.json`. All other run-wide data (party roster, reputation, etc.) is deferred to Stage 2.

## World Map

### Map Scene
Interactive world map. 28 named nodes across 4 concentric rings (center hub Badurga + inner/middle/outer). Each node has a procedurally-drawn lore name (seeded per ring — not saved, regenerates from map_seed), a type (COMBAT, RECRUIT, VENDOR, EVENT, BOSS, CITY) with distinct color/icon/hover label, and exactly 1 BOSS per run in the outer ring. Player traverses by clicking adjacent nodes; re-clicking enters the current node. Nodes display five visual states (CURRENT / REACHABLE / CLEARED / VISITED / LOCKED). Bridges use quadrant-aware placement (≥90° intra-pair gap, ≥30° cross-pair exclusion) to prevent straight corridors. Seeded from map_seed — deterministic on reload. Lives in `scenes/map/MapScene.tscn` + `scripts/map/MapManager.gd`.

---

## Cross-Cutting Concerns

### Input Handling
- Always use `_unhandled_input()` for world interaction — never `_input()`. This ensures GUI controls (StatPanel, ActionMenu) consume events before the world layer receives them.
- GUI nodes (CanvasLayer) take priority over 3D scene input automatically in Godot.

### Signal Naming
- All signals use past-tense event names: `unit_moved`, `qte_resolved`, `unit_died`.
- Systems signal *up* to CombatManager3D; CM3D never calls down into systems directly for event flow.

### Scene Building
- All `.tscn` files stay minimal (root node + script only). Children are built entirely in `_ready()`. No scene nesting of sub-scenes.

### Typed GDScript
- Always declare types: `var speed: int = 3`. No untyped vars.
- `snake_case` vars/funcs, `PascalCase` class/node names, `ALL_CAPS` constants.

### Testing
- Tests live in `/tests/`. Use `extends Node`, `_ready()`, plain `assert()`.
- Do NOT test: rendering, input, anything needing a live scene.
- Run headless: `godot --headless --path rogue-finder --import` first, then `godot --headless --path rogue-finder --script tests/<file>.gd`.

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
│   │   ├── ActionMenu.gd        ← radial action pop-up (player unit selection)
│   │   ├── EndCombatScreen.gd   ← victory/defeat overlay (layer 15)
│   │   ├── StatPanel.gd         ← full examine window (double-click)
│   │   ├── UnitInfoBar.gd       ← condensed strip (single-click)
│   │   └── HUD.gd               ← legacy 2D only
│   └── globals/
│       ├── AbilityLibrary.gd    ← ability factory (22 abilities)
│       ├── ArchetypeLibrary.gd  ← archetype factory (3D)
│       ├── ConsumableLibrary.gd ← consumable factory (healing_potion, power_tonic)
│       ├── EquipmentLibrary.gd  ← equipment catalog (6 items, 2 per slot)
│       ├── RewardGenerator.gd   ← shuffled reward pool (equipment + consumables)
│       └── GameState.gd
└── resources/
    ├── AbilityData.gd           ← ability resource (TargetShape/ApplicableTo/Attribute enums)
    ├── EffectData.gd            ← effect sub-resource (EffectType/PoolType/MoveType enums)
    ├── CombatantData.gd         ← active data resource (3D)
    ├── ConsumableData.gd        ← consumable item resource
    ├── EquipmentData.gd         ← equipment item resource (Slot enum, stat_bonuses, get_bonus())
    └── UnitData.gd              ← legacy data resource (2D only)
├── scenes/map/
│   └── MapScene.tscn            ← world map shell (root + script only)
├── scenes/misc/
│   └── NodeStub.tscn            ← placeholder for unimplemented node types (root + script only)
├── scripts/map/
│   └── MapManager.gd            ← builds map scene in _ready()
└── scripts/misc/
    └── NodeStub.gd              ← reads GameState.pending_node_type; shows stub screen with return button
```

---

## Session Log

| Date | Area | Note |
|---|---|---|
| 2026-04-13 | Combat | Stage 1: 2D combat prototype — 6×4 grid, QTE, turn SM, HUD, test suite |
| 2026-04-14 | Combat, Camera, Grid, Unit | Stage 1.5: 3D refactor — CameraController, Unit3D, Grid3D, CombatManager3D |
| 2026-04-14 | Data, UI | Combatant data model, ArchetypeLibrary, UnitInfoBar, StatPanel, ActionMenu |
| 2026-04-15 | Data, Combat | AbilityData/EffectData model, 12 abilities wired; CombatManager3D applies effects |
| 2026-04-16 | Data, Combat | ConsumableData + ConsumableLibrary; consumable effect wired in CombatManager3D |
| 2026-04-17 | Grid, Combat | Wall + hazard environment tiles: CellType enum, build_walls(), hazard on-entry and traversal damage, FORCE path tracking, COLOR_MOVE_HAZARD amber highlight, wall color polish |
| 2026-04-16 | Data | EquipmentData + EquipmentLibrary (6 items); CombatantData slots typed; all derived stats include equipment bonuses |
| 2026-04-17 | UI, Globals | EndCombatScreen (layer 15) + RewardGenerator; win/lose overlay replaces status label text |
| 2026-04-17 | World Map | MapScene + MapManager: static spider-web node map, 28 nodes, hover labels, player marker, debug combat button |
| 2026-04-18 | World Map, GameState | Feature 2: node traversal — adjacency lookup, click gating, GameState wiring (player_node_id, visited_nodes), marker tween, four node visual states (CURRENT/REACHABLE/VISITED/LOCKED), visited stamp, locked hover suppression |
| 2026-04-18 | GameState, MapManager | Session 9: save/load system — map_seed field, save()/load_save()/delete_save(), deterministic map topology via seeded RNG, marker placed from GameState.player_node_id on load |
| 2026-04-18 | MapManager, GameState | Session 10: debug delete-save button — "🗑 Delete Save (debug)" button wipes save file and resets in-memory GameState fields via new reset() method, then reloads scene for a clean fresh-run state without restarting Godot |
| 2026-04-18 | MapManager, GameState, EndCombatScreen, main.tscn | Feature 3: node types, icons, scene routing — 6 node types with colors/icons/hover labels; BOSS extra border; _assign_node_types() deterministic per seed; re-click current node to enter; COMBAT/BOSS → CombatScene3D, others → NodeStub placeholder; game boots into MapScene; EndCombatScreen returns to map |
| 2026-04-18 | GameState, MapManager, EndCombatScreen | Feature 4: scene transition polish + node tracking — current_combat_node_id transient field; cleared_nodes saved to disk; Onward... step on victory before returning to map; defeat button renamed "Return to Map"; CLEARED visual state (red ✗ stamp, darkened); cleared nodes traversable but _enter_current_node() no-ops on them |
| 2026-04-18 | MapManager | Feature 5: procedural names, 1 BOSS, quadrant-aware bridges — three lore name pools (15/20/25) seeded per ring, names regenerate from map_seed (not saved); outer ring reduced to exactly 1 BOSS + RECRUIT slot added; _connect_gateways_v2() enforces ≥90° intra-pair gap and ≥30° cross-pair exclusion; hub connections exclude inner gateway nodes |
| 2026-04-18 | MapManager, GameState, EndCombatScreen | Session 13 UX polish — player always starts at Badurga; Boss node 44×44 + pulsing red Polygon2D glow; EVENT nodes auto-start (no prompt); VENDOR/RECRUIT/CITY show bottom-center yes/no prompt (_show_node_prompt); _desc_for_type() helper; tooltip upgraded to ColorRect panel; EndCombatScreen "Onward..." button removed — reward selection immediately clears + saves + returns to map |
