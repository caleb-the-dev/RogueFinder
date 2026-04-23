# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-23 |
| last_groomed | 2026-04-18 |
| sessions_since_groom | 16 |
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
| [Unit Info Bar](#unit-info-bar) | [hud_system.md](hud_system.md) | ✅ Active (hover strip) | Presentation |
| [Combat Action Panel](#combat-action-panel) | [hud_system.md](hud_system.md) | ✅ Active (right slide-in panel) | Presentation |
| [End Combat Screen](#end-combat-screen) | [hud_system.md](hud_system.md) | ✅ Active (victory only) | Presentation |
| [Run Summary Scene](#run-summary-scene) | [combat_manager.md](combat_manager.md) | ✅ Active | Presentation |
| [Reward Generator](#reward-generator) | [hud_system.md](hud_system.md) | ✅ Active | Global |
| [Combatant Data Model](#combatant-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active (3D) | Data |
| [Ability Data Model](#ability-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Ability Library](#ability-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Consumable Data Model](#consumable-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Consumable Library](#consumable-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Equipment Data Model](#equipment-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Equipment Library](#equipment-library) | [combatant_data.md](combatant_data.md) | ✅ Active | Data |
| [Background Data Model](#background-data-model) | [combatant_data.md](combatant_data.md) | ✅ Active (dormant — no consumers yet) | Data |
| [Background Library](#background-library) | [combatant_data.md](combatant_data.md) | ✅ Active (dormant — first CSV-sourced library) | Data |
| [Unit Data Resource](#unit-data-resource) | [unit_data.md](unit_data.md) | ⚠️ Legacy (2D only) | Data |
| [Game State](#game-state) | [game_state.md](game_state.md) | ✅ Active (map traversal + save/load) | Global |
| [Map Scene](#map-scene) | [map_scene.md](map_scene.md) | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](#party-sheet) | [map_scene.md](map_scene.md) | ✅ Active (interactive equip overlay, layer 20) | Presentation |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D           (cell queries, highlights, world↔grid math)
  ├── Unit3D ×≤6       (HP/energy state, movement, animations; player units from GameState.party)
  ├── QTEBar           (skill-check overlay → accuracy float)
  ├── CameraController (built by CM3D; shake on hit)
  ├── UnitInfoBar         (condensed strip; shown on hover via _handle_unit_hover)
  ├── StatPanel           (full examine window; shown on double-click)
  ├── CombatActionPanel   (right slide-in; player=interactive, enemy=read-only; signals ability_selected, consumable_selected)
  ├── EndCombatScreen  (victory overlay only; defeat bypasses it)
  ├── ArchetypeLibrary (creates CombatantData for enemy units only)
  ├── GameState        (party read at setup; save() on permadeath and combat end)
  └── RunSummaryScene  (loaded via change_scene_to_file on run-end defeat)

EndCombatScreen
  └── RewardGenerator  (shuffled pool of EquipmentLibrary + ConsumableLibrary items)

RewardGenerator
  ├── EquipmentLibrary (all_equipment())
  └── ConsumableLibrary (CONSUMABLES dict)

Unit3D
  └── CombatantData    (stat source — replaces UnitData for 3D)

CombatActionPanel
  ├── AbilityLibrary      (looked up to build ability buttons + tooltips)
  └── ConsumableLibrary   (looked up to build consumable button + tooltip)

StatPanel
  └── CombatantData    (reads all fields for display)

ArchetypeLibrary
  └── CombatantData    (creates instances)

EquipmentLibrary
  └── EquipmentData    (creates instances)

BackgroundLibrary      (static class — lazy CSV load; no consumers yet)
  └── BackgroundData   (creates instances from res://data/backgrounds.csv)

CombatantData
  └── EquipmentData    (weapon / armor / accessory slots)

MapManager
  ├── GameState        (calls load_save() + init_party() at startup; reads player_node_id/visited_nodes/map_seed/node_types/cleared_nodes/threat_level/party; increments threat_level on travel and entry; calls move_player, save, load_save; sets pending_node_type before NodeStub transition; sets current_combat_node_id before CombatScene3D transition; transitions directly to BadurgaScene for CITY nodes)
  └── PartySheet       (instantiated as child in _ready(); Party button calls show_sheet())

PartySheet
  ├── GameState        (reads party + inventory on every show_sheet() call)
  └── EquipmentLibrary (resolves equipment ids for inventory display)

NodeStub
  └── GameState        (reads+clears pending_node_type)

BadurgaManager         (standalone — no dependencies; returns to MapScene on back button)

EndCombatScreen
  ├── RewardGenerator  (shuffled pool of EquipmentLibrary + ConsumableLibrary items)
  └── GameState        (reads current_combat_node_id + node_types; appends to cleared_nodes; resets threat_level to 0.0 on BOSS defeat; calls add_to_inventory() + save() on reward selection)

GameState              (autoload — map traversal + save/load + party roster + party bag inventory live; reputation deferred)
  ├── ArchetypeLibrary   (init_party() calls create() for PC + 2 allies)
  └── EquipmentLibrary   (load_save() resolves equipment slot ids via get_equipment())
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
Condensed CanvasLayer strip (layer 4). Shown on **hover** over any unit (driven by `CombatManager3D._handle_unit_hover()` on `InputEventMouseMotion`). Displays name, class, HP bar, energy bar. Hidden when cursor leaves all units.

### Combat Action Panel
CanvasLayer (layer 12) right-side slide-in panel (~0.15s cubic tween). Opens for **player units** (interactive: ability 2×2 grid, consumable button, stride hint) and **enemy units** (read-only: HP/EN bars, non-clickable abilities). Shows unit name, portrait, HP/EN bars with color-coded fill, status effect chips, and a dialogue stub box. Ability/consumable buttons show a floating tooltip on hover. Consumable use refreshes the panel in-place (no close). After stride, panel refreshes with updated remaining movement. Lives in `scripts/ui/CombatActionPanel.gd` + `scenes/ui/CombatActionPanel.tscn`.

### End Combat Screen
CanvasLayer overlay (layer 15) shown on combat **victory only**. Shows a "VICTORY" header + 3 reward buttons from `RewardGenerator.roll(3)` — picking one immediately appends the node to `GameState.cleared_nodes`, saves, and returns to `MapScene.tscn`. The defeat path now bypasses EndCombatScreen entirely (see Run Summary Scene). Lives in `scripts/ui/EndCombatScreen.gd`.

### Run Summary Scene
Shown after a run-ending defeat (full party wipe). Displays run stats read from `GameState.run_summary`: pc_name, nodes visited/cleared, threat level percentage, fallen allies. Three buttons: Start New Run (reset + delete save + load MapScene), Main Menu (stub — same as Start New Run until a title scene exists), Quit Game. Lives in `scripts/ui/RunSummaryManager.gd` + `scenes/ui/RunSummaryScene.tscn`.

### Reward Generator
Static utility (`scripts/globals/RewardGenerator.gd`). Combines all `EquipmentLibrary` and `ConsumableLibrary` items into one pool, Fisher-Yates shuffles, and returns `count` distinct Dicts (`id`, `name`, `description`, `item_type`).

### Combat Action Panel
See [Combat Action Panel](#combat-action-panel) above.

### Combatant Data Model
Two-file system: `CombatantData` (Resource) stores identity (including `kindred`), core attributes, slot data, and persistent run state (`ability_pool`, `current_hp`, `current_energy`, `is_dead`); all derived combat stats are computed properties. `ArchetypeLibrary` (static class) defines 5 archetypes (each with a fixed `kindred`) and provides `create()` to instantiate randomized `CombatantData` with all persistent fields seeded. Pool ⊇ slots invariant: every non-empty active slot appears in `ability_pool`.

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

### Background Data Model
`BackgroundData` (Resource) stores one character background: `background_id`, `background_name`, `starting_ability_id` (the 1 action granted at creation per GAME_BIBLE), `feat_pool` (odd-level feat draws), `unlocked_by_default` (meta-progression gate), `tags` (optional event hooks), and `description`. Lives at `resources/BackgroundData.gd`.

### Background Library
`BackgroundLibrary` (static class) is the first CSV-sourced library in the codebase — reads `res://data/backgrounds.csv` lazily, caches by id, and returns `BackgroundData` via `get_background(id)` (never null — stub fallback) / `get_background_by_name(display_name)` (back-compat bridge for current PascalCase callers) / `all_backgrounds()` / `reload()`. CSV lives at `rogue-finder/data/backgrounds.csv` (single source of truth; no `docs/csv_data/` mirror). Currently dormant — no production code calls it yet. Lives at `scripts/globals/BackgroundLibrary.gd`.

### Unit Data Resource (Legacy)
Superseded by `CombatantData` for the 3D system. Kept alive for `Unit.gd` (2D) and its test suite.

### Game State
Autoload singleton. Map traversal, save/load, party roster, and party bag inventory are live. Tracks `player_node_id`, `visited_nodes`, `map_seed`, `node_types`, `cleared_nodes`, `threat_level` (float 0.0–1.0), `party: Array[CombatantData]` (index 0 = PC), `inventory: Array` (raw reward dicts `{id, name, description, item_type}`) — all saved to disk. `run_summary: Dictionary` holds stats for the RunSummaryScene after a run-end defeat (not saved to disk). `pending_node_type` and `current_combat_node_id` are transient handoffs. Exposes `move_player()`, `is_visited()`, `is_adjacent_to_player()`, `get_threat_level()`, `init_party()`, `add_to_inventory()`, `remove_from_inventory()`, `save()`, `load_save()`, `delete_save()`, `reset()`. Save path: `user://save.json`. Reputation and other Stage 2+ data deferred.

## World Map

### Map Scene
Interactive world map. 28 named nodes across 4 concentric rings (center hub Badurga + inner/middle/outer). Each node has a procedurally-drawn lore name (seeded per ring — not saved, regenerates from map_seed), a type (COMBAT, VENDOR, EVENT, BOSS, CITY) with distinct color/icon/hover label. Structured placement: inner ring = 4 COMBAT + 2 EVENT only; middle ring = 5 COMBAT + 3 EVENT + 1 VENDOR; outer ring = 7 COMBAT + 3 EVENT + 1 VENDOR + 1 BOSS. BOSS is placed after edges are built, guaranteed ≥ 2 ring-hops from any middle→outer bridge node. Exactly 2 VENDOR nodes per run (1 middle, 1 outer). Player traverses by clicking adjacent nodes; re-clicking enters the current node. Nodes display five visual states (CURRENT / REACHABLE / CLEARED / VISITED / LOCKED). Bridges use quadrant-aware placement (≥90° intra-pair gap, ≥30° cross-pair exclusion) to prevent straight corridors. Seeded from map_seed — deterministic on reload. HUD shows a fixed vertical threat bar (left side) with quadrant tick marks and fill color scaling from yellow to red. Lives in `scenes/map/MapScene.tscn` + `scripts/map/MapManager.gd`.

### Party Sheet
Full-screen interactive overlay (CanvasLayer, layer 20). Opened by the "Party" button in MapManager UI chrome. Three-column layout (~30/40/30): LEFT = inventory bag (drag source, 376 px); MIDDLE = 3 member cards each divided into 4 quadrants (TL: name/class/bg/**kindred**/HP-inline · TR: derived stats + attributes · BL: equipment 2×2 drop targets · BR: slotted abilities 2×2, 500 px); RIGHT = TabContainer per member ("Abilities" pool list / "Feats" placeholder, 374 px). Drag inventory items to matching equipment slots; click a filled slot to unequip. Dead members: slots disabled, card and tabs dimmed. All mutations write directly to `GameState.party[i]`; save deferred to next map travel. Stateless `_rebuild()` re-render. Lives in `scenes/party/PartySheet.tscn` + `scripts/party/PartySheet.gd`.

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
- Run headless: import first (`godot --headless --path rogue-finder --import`), then run via a `.tscn` wrapper (`godot --headless --path rogue-finder res://tests/<file>.tscn --quit`). The `--script` flag requires `extends SceneTree` — test files extend `Node` so they need a scene. See `tests/test_combatant_data.tscn` as the reference pattern.

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
│   │   ├── CombatActionPanel.gd ← right slide-in panel (player=interactive, enemy=read-only)
│   │   ├── EndCombatScreen.gd   ← victory overlay (layer 15; defeat bypassed)
│   │   ├── RunSummaryManager.gd ← run-end stats + new run / quit buttons
│   │   ├── StatPanel.gd         ← full examine window (double-click)
│   │   ├── UnitInfoBar.gd       ← condensed strip (hover-based)
│   │   └── HUD.gd               ← legacy 2D only
│   └── globals/
│       ├── AbilityLibrary.gd    ← ability factory (22 abilities)
│       ├── ArchetypeLibrary.gd  ← archetype factory (3D)
│       ├── BackgroundLibrary.gd ← background catalog (CSV-sourced from res://data/backgrounds.csv)
│       ├── ConsumableLibrary.gd ← consumable factory (healing_potion, power_tonic)
│       ├── EquipmentLibrary.gd  ← equipment catalog (6 items, 2 per slot)
│       ├── BackgroundLibrary.gd ← background catalog (CSV-sourced from res://data/backgrounds.csv)
│       ├── RewardGenerator.gd   ← shuffled reward pool (equipment + consumables)
│       └── GameState.gd
└── resources/
    ├── AbilityData.gd           ← ability resource (TargetShape/ApplicableTo/Attribute enums)
    ├── EffectData.gd            ← effect sub-resource (EffectType/PoolType/MoveType enums)
    ├── CombatantData.gd         ← active data resource (3D)
    ├── ConsumableData.gd        ← consumable item resource
    ├── EquipmentData.gd         ← equipment item resource (Slot enum, stat_bonuses, get_bonus())
    ├── BackgroundData.gd        ← background resource (id, name, starting ability, feat pool, tags)
    └── UnitData.gd              ← legacy data resource (2D only)
├── data/
│   └── backgrounds.csv          ← CSV-backed catalog (single source; read via res://data/)
├── scenes/ui/
│   ├── CombatActionPanel.tscn   ← right slide-in panel shell (root CanvasLayer + script only)
│   └── RunSummaryScene.tscn     ← run-end stats scene (root CanvasLayer + script only)
├── scenes/party/
│   └── PartySheet.tscn          ← party/inventory overlay shell (root CanvasLayer + script only)
├── scenes/map/
│   └── MapScene.tscn            ← world map shell (root + script only)
├── scenes/misc/
│   └── NodeStub.tscn            ← placeholder for unimplemented node types (root + script only)
├── scenes/city/
│   └── BadurgaScene.tscn        ← Badurga hub city shell (root + script only)
├── scripts/party/
│   └── PartySheet.gd            ← interactive party+inventory overlay (4-quadrant cards, drag-drop equip, ability pool tabs)
├── scripts/map/
│   └── MapManager.gd            ← builds map scene in _ready()
├── scripts/misc/
│   └── NodeStub.gd              ← reads GameState.pending_node_type; shows stub screen with return button
└── scripts/city/
    └── BadurgaManager.gd        ← builds Badurga shell in _ready(); 6 placeholder section buttons + return
```

---

## Recent Milestones

Last 3 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-04-23 | CombatantData, ArchetypeLibrary, GameState, StatPanel, CombatActionPanel, PartySheet | S28 Kindreds: added `kindred: String` field to `CombatantData`. Each archetype definition now has a `"kindred"` key (RogueFinder/archer_bandit→Human, grunt→Half-Orc, alchemist→Gnome, elite_guard→Dwarf). Set in `ArchetypeLibrary.create()`; persisted in GameState save/load (old saves default `"Unknown"`). Shown in StatPanel (between Archetype and Background), CombatActionPanel (small muted label below name, player+enemy), and PartySheet TOP-LEFT card. PartySheet column widths rebalanced to 30/40/30. HP row restructured to inline text+bar. GAME_BIBLE updated with Kindred entry. |
| 2026-04-23 | CombatManager3D, CombatActionPanel, UnitInfoBar | S26+S27 Combat UI overhaul: replaced radial ActionMenu with right slide-in CombatActionPanel (layer 12). Player panel: centered name/portrait, HP+EN bars, 2×2 ability grid, consumable button, stride hint with remaining tiles. Enemy panel: same layout, read-only abilities, no consumable/stride. Hover tooltips on all ability/consumable buttons (float left of panel). UnitInfoBar converted from click-persistent to hover-based via `_handle_unit_hover()` on mouse motion. Consumable use no longer closes panel (refreshes in-place). Panel refreshes after stride with updated remaining movement. Panel closes if its shown unit dies. `_hover_cell` var added to CM3D. ActionMenu.gd deleted. |
| 2026-04-20 | MapManager | S25 Map node placement constraints: inner ring changed to 4 COMBAT + 2 EVENT (no VENDOR); outer ring to 7 COMBAT + 3 EVENT + 1 VENDOR + 1 BOSS. BOSS assignment extracted from `_assign_node_types()` to new `_assign_boss_type()` called after `_build_edge_data()`; bridge endpoints captured into `_outer_bridge_ids`; BOSS excluded from bridge node + 2 ring neighbors. `GameState.save()` moved from type assignment to boss assignment step. |
| 2026-04-20 | MapManager | S24 Remove RECRUIT node type: RECRUIT scrubbed from all pools, color/icon/desc helpers, and docs. Outer pool COMBAT count unchanged (slot replaced with COMBAT). |
| 2026-04-20 | ArchetypeLibrary, PartySheet | S23 Ability Pool Swap: `pool_extras` key expands ability pools beyond the 4 active slots (RogueFinder, archer_bandit, grunt now have 4 extras each). Full interactive swap UI: drag from Abilities panel onto BOTTOM-RIGHT slots; right-click to unequip. Per-member sort/search/view in ability panel; inventory gets same treatment. Drag-compare panels for abilities, equipment, and consumables. Backwards-typing fix in search. `_wrap_tooltip()` + opaque tooltip theme. |
| 2026-04-20 | PartySheet | S22 Party Sheet layout redesign: 4-quadrant card layout (TL name/class/bg/HP · TR derived+attrs · BL equipment 2×2 · BR slotted abilities 2×2), full-card separator lines, prominent Class/Background display, TabContainer ability pool + Feats placeholder on right panel. S21: drag-drop gear management loop, `set_drag_forwarding()` pattern, map input block, sprite slot icons, tooltips on everything. Single-file change: `PartySheet.gd`. |
| 2026-04-20 | MapManager, PartySheet | S20 Party Sheet Slice 5: read-only overlay (layer 20) showing 3 party cards (portrait, name, class, HP bar, attributes) + inventory bag. Equipment rows resolve via EquipmentLibrary; consumable rows use description. Dead members greyed with DEFEATED stamp. "Party" button added to MapManager UI chrome. New files: `scenes/party/PartySheet.tscn`, `scripts/party/PartySheet.gd`. |
| 2026-04-19 | BackgroundData, BackgroundLibrary | Added CSV-backed background catalog. Single source at `rogue-finder/data/backgrounds.csv` (dual `docs/csv_data/` mirror scrapped — drift risk > ergonomic benefit). `get_background_by_name()` bridges current PascalCase display strings so the library is callable today; full snake_case-id migration deferred until first real consumer lands. Dormant — no callers yet. First CSV-sourced library; pattern established for future migrations. |
| 2026-04-18 | MapManager, GameState, EndCombatScreen | Session 13 UX polish — Badurga start, BOSS glow, node prompts, instant reward return |
| 2026-04-18 | BadurgaScene, MapManager | Feature 6: Badurga city shell — CITY branch now loads `BadurgaScene.tscn` with 6 placeholder section buttons + return to map |
| 2026-04-18 | GameState, MapManager, EndCombatScreen | Feature 7: Threat escalation counter — `threat_level` float (0.0–1.0) saved to disk; +5% on travel, +5% on node entry; vertical HUD bar with quadrant colors + tick marks; resets to 0 on BOSS defeat |
| 2026-04-19 | CombatManager3D, Unit3D, GameState, RunSummaryScene | S18 Persistent Party Slice 3 + permadeath + run-end: combat pulls player units from `GameState.party`; `Unit3D.setup()` seeds from `current_hp`/`current_energy`; `_attr_snapshots` rolls back stat mutations on combat end; allies die permanently on 0 HP; PC revives at 1 HP on victory; full wipe triggers "RogueFinder has perished" overlay → `RunSummaryScene` (stats + new run/quit buttons); T-key debug menu in combat for faster testing |
| 2026-04-19 | GameState, MapManager | S17 Persistent Party Slice 2: `GameState.party: Array[CombatantData]` added; `init_party()` seeds PC (RogueFinder/"Hero") + 2 allies (archer_bandit, grunt) on fresh runs; `save()` / `load_save()` / `reset()` extended; equipment slots persist as id strings; 6 new headless tests (28 total passing) |
| 2026-04-19 | GameState, EndCombatScreen | S19 Persistent Party Slice 4: `GameState.inventory: Array` (party bag) added; all reward items (equipment + consumables) land as raw dicts on pickup — no auto-assignment; `add_to_inventory()` / `remove_from_inventory(id)` live; save/load/reset extended; EndCombatScreen guard now active; bag UI deferred to Stage 2 |
| 2026-04-18 | CombatantData, ArchetypeLibrary | S16 Persistent Party Slice 1: added `ability_pool`, `current_hp`, `current_energy`, `is_dead` to CombatantData; `create()` seeds all four; pool ⊇ slots invariant |
