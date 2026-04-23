# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-23 |
| last_groomed | 2026-04-23 |
| sessions_since_groom | 0 |
| groom_trigger | 10 |

> **Grooming rule:** When `sessions_since_groom` reaches `groom_trigger`, run the `map-audit` skill:
> remove entries for deleted files, update descriptions that no longer match the code,
> prune stale "not here" notes, verify bucket file accuracy. Reset `sessions_since_groom` to 0.

---

## System Index

| System | Bucket File | Status | Layer |
|--------|------------|--------|-------|
| [Combat Manager](combat_manager.md) | `combat_manager.md` | ✅ Active (3D) + Legacy (2D) | Core |
| [Grid System](grid_system.md) | `grid_system.md` | ✅ Active (3D) + Legacy (2D) | Core |
| [Unit System](unit_system.md) | `unit_system.md` | ✅ Active (3D) + Legacy (2D) | Core |
| [QTE System](qte_system.md) | `qte_system.md` | ✅ Active | Core |
| [Camera System](camera_system.md) | `camera_system.md` | ✅ Active (3D only) | Presentation |
| [HUD System / StatPanel / UnitInfoBar / CombatActionPanel / EndCombatScreen / RewardGenerator / RunSummaryScene](hud_system.md) | `hud_system.md` | ✅ Active (combat HUD stack) · ⚠️ Legacy HUD.gd kept for 2D | Presentation |
| [Combatant Data Model + ArchetypeLibrary](combatant_data.md) | `combatant_data.md` | ✅ Active | Data |
| [Ability System (AbilityData / EffectData / AbilityLibrary)](ability_system.md) | `ability_system.md` | ✅ Active (22 abilities) | Data |
| [Equipment & Consumables](equipment_system.md) | `equipment_system.md` | ✅ Active (6 equipment, 2 consumables) | Data |
| [Background System](background_system.md) | `background_system.md` | ✅ Active (dormant — first CSV-sourced library) | Data |
| [Unit Data Resource](unit_data.md) | `unit_data.md` | ⚠️ Legacy (2D only) | Data |
| [Game State](game_state.md) | `game_state.md` | ✅ Active (map traversal + save/load + party + inventory) | Global |
| [Map Scene](map_scene.md) | `map_scene.md` | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](party_sheet.md) | `party_sheet.md` | ✅ Active (interactive overlay, layer 20) | Presentation |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D                (cell queries, highlights, world↔grid math)
  ├── Unit3D ×≤6            (HP/energy, movement, animations; player units from GameState.party)
  ├── QTEBar                (multiplier out; enemy simulates via qte_resolution stat)
  ├── CameraController      (built by CM3D; shake on hit)
  ├── UnitInfoBar           (hover-based strip)
  ├── StatPanel             (double-click examine window)
  ├── CombatActionPanel     (right slide-in; player=interactive, enemy=read-only)
  ├── EndCombatScreen       (victory overlay only; defeat bypasses it)
  ├── ArchetypeLibrary      (enemy CombatantData creation)
  ├── GameState             (party read at setup; save() on permadeath and combat end)
  └── RunSummaryScene       (loaded on run-end defeat)

CombatActionPanel
  ├── AbilityLibrary        (button build + tooltips)
  └── ConsumableLibrary     (button + tooltip)

EndCombatScreen
  └── RewardGenerator → EquipmentLibrary + ConsumableLibrary

MapManager
  ├── GameState             (load_save/init_party at startup; travel + entry increments; sets pending_node_type / current_combat_node_id)
  └── PartySheet            (instantiated as child; Party button calls show_sheet())

PartySheet
  ├── GameState             (party + inventory on every show_sheet())
  ├── EquipmentLibrary      (item id resolution)
  ├── ConsumableLibrary     (id resolution for tooltip / compare)
  └── AbilityLibrary        (id resolution for pool + slot labels)

NodeStub          → GameState (reads + clears pending_node_type)
BadurgaManager    → standalone (no deps; returns to MapScene on back)

GameState (autoload)
  ├── ArchetypeLibrary      (init_party() creates PC + 2 allies)
  └── EquipmentLibrary      (load_save resolves equipment slot ids)
```

---

## Cross-Cutting Concerns

### Input Handling
- Use `_unhandled_input()` for world interaction — never `_input()`. Ensures GUI controls (StatPanel, CombatActionPanel) consume events first.
- Exception: `MapManager._input()` is intentional for pan drag + PartySheet visibility guard (see `map_scene.md`).
- CanvasLayer nodes take priority over 3D input automatically.

### Signal Naming
- Past-tense event names: `unit_moved`, `qte_resolved`, `unit_died`.
- Systems signal *up* to CombatManager3D; CM3D never calls down into systems directly for event flow.

### Scene Building
- All `.tscn` files are minimal (root + script only). Children built in `_ready()`. No scene nesting.

### Typed GDScript
- Always declare types: `var speed: int = 3`. No untyped vars.
- `snake_case` vars/funcs, `PascalCase` class/node names, `ALL_CAPS` constants.

### Testing
- Tests live in `/tests/`. `extends Node`, `_ready()`, plain `assert()`.
- Do NOT test: rendering, input, anything needing a live scene.
- Run headless: import first (`godot --headless --path rogue-finder --import`), then run via a `.tscn` wrapper. See `tests/test_combatant_data.tscn`.

---

## File Locations

```
rogue-finder/
├── main.tscn                           ← entry point; instances MapScene.tscn
├── scripts/
│   ├── camera/CameraController.gd
│   ├── city/BadurgaManager.gd
│   ├── combat/
│   │   ├── CombatManager3D.gd          ← active
│   │   ├── Unit3D.gd                   ← active
│   │   ├── Grid3D.gd                   ← active
│   │   ├── QTEBar.gd
│   │   ├── CombatManager.gd            ← legacy 2D
│   │   ├── Unit.gd                     ← legacy 2D
│   │   └── Grid.gd                     ← legacy 2D
│   ├── globals/
│   │   ├── AbilityLibrary.gd           ← 22 abilities
│   │   ├── ArchetypeLibrary.gd         ← 5 archetypes
│   │   ├── BackgroundLibrary.gd        ← CSV-sourced (res://data/backgrounds.csv)
│   │   ├── ConsumableLibrary.gd        ← healing_potion, power_tonic
│   │   ├── EquipmentLibrary.gd         ← 6 items, 2 per slot
│   │   ├── RewardGenerator.gd          ← shuffled reward pool
│   │   └── GameState.gd                ← autoload
│   ├── map/MapManager.gd
│   ├── misc/NodeStub.gd                ← placeholder stub screen
│   ├── party/PartySheet.gd             ← interactive overlay, layer 20
│   └── ui/
│       ├── CombatActionPanel.gd        ← right slide-in (layer 12)
│       ├── EndCombatScreen.gd          ← victory overlay (layer 15)
│       ├── RunSummaryManager.gd        ← run-end stats
│       ├── StatPanel.gd                ← double-click examine (layer 8)
│       ├── UnitInfoBar.gd              ← hover strip (layer 4)
│       └── HUD.gd                      ← legacy 2D only
├── resources/
│   ├── AbilityData.gd                  ← TargetShape / ApplicableTo / Attribute enums
│   ├── EffectData.gd                   ← EffectType / PoolType / MoveType / ForceType enums
│   ├── CombatantData.gd                ← active data resource (3D)
│   ├── ConsumableData.gd
│   ├── EquipmentData.gd                ← Slot enum, stat_bonuses, get_bonus()
│   ├── BackgroundData.gd
│   └── UnitData.gd                     ← legacy (2D only)
├── data/
│   └── backgrounds.csv                 ← single source; read via res://data/
├── scenes/
│   ├── city/BadurgaScene.tscn
│   ├── combat/
│   │   ├── CombatScene3D.tscn          ← active (3D)
│   │   ├── CombatScene.tscn            ← legacy 2D
│   │   ├── Grid3D.tscn · Grid.tscn
│   │   ├── Unit3D.tscn · Unit.tscn
│   │   └── QTEBar.tscn
│   ├── map/MapScene.tscn
│   ├── misc/NodeStub.tscn
│   ├── party/PartySheet.tscn
│   └── ui/
│       ├── CombatActionPanel.tscn
│       ├── HUD.tscn                    ← legacy 2D only
│       └── RunSummaryScene.tscn
└── tests/                              ← 18 test files; see `tests/test_combatant_data.tscn` for the runner pattern
```

---

## Recent Milestones

Last 5 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-04-23 | docs | Map audit pass — docs/map_directories groomed against codebase. `combatant_data.md` split into 4 files (ability/equipment/background/core); `map_scene.md` split (PartySheet → `party_sheet.md`). ActionMenu refs purged. `EndCombatScreen.show_defeat` doc removed. Missing files added to file tree. |
| 2026-04-23 | CombatantData, ArchetypeLibrary, GameState, StatPanel, CombatActionPanel, PartySheet | S28 Kindreds: added `kindred: String` to CombatantData. Fixed per archetype (Human/Human/Half-Orc/Gnome/Dwarf). Persisted in save/load (old saves default `"Unknown"`). Displayed in three places. PartySheet columns rebalanced to ~30/40/30; HP row restructured. |
| 2026-04-23 | CombatManager3D, CombatActionPanel, UnitInfoBar | S26+S27 Combat UI overhaul: replaced radial ActionMenu with right slide-in `CombatActionPanel` (layer 12). UnitInfoBar converted to hover-based via `_handle_unit_hover()`. Consumable use no longer closes panel. `ActionMenu.gd` deleted. |
| 2026-04-20 | MapManager | S24+S25 Map node placement: RECRUIT removed; inner ring → 4 COMBAT + 2 EVENT; outer → 1 BOSS + 7 COMBAT + 3 EVENT + 1 VENDOR. `_assign_boss_type()` extracted. |
| 2026-04-20 | ArchetypeLibrary, PartySheet | S20–S23 Party Sheet arc: initial overlay → drag-drop gear → 4-quadrant card layout → Ability Pool Swap with compare panels, search/sort, view toggles. |
