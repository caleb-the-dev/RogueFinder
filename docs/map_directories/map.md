# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-25 (events Slice 4 — EventManager overlay + effect dispatch) |
| last_groomed | 2026-04-23 |
| sessions_since_groom | 15 |
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
| [Combatant Data Model + ArchetypeLibrary](combatant_data.md) | `combatant_data.md` | ✅ Active (ArchetypeLibrary CSV-sourced S34) | Data |
| [Ability System (AbilityData / EffectData / AbilityLibrary)](ability_system.md) | `ability_system.md` | ✅ Active (22 abilities, CSV-sourced S35) | Data |
| [Equipment & Consumables](equipment_system.md) | `equipment_system.md` | ✅ Active (6 equipment CSV-sourced S32; 2 consumables CSV-sourced S31) | Data |
| [Background System](background_system.md) | `background_system.md` | ✅ Active (dormant — CSV-sourced; 3 ability IDs fixed S30) | Data |
| [Class Library](class_system.md) | `class_system.md` | ✅ Active (dormant — 4 classes, CSV-sourced, S30) | Data |
| [Portrait Library](portrait_system.md) | `portrait_system.md` | ✅ Active (dormant — 6 placeholder portraits, CSV-sourced, S30) | Data |
| [Kindred Library](combatant_data.md) | `combatant_data.md` | ✅ Active (CSV-sourced S33; speed + HP bonuses + placeholder feats + name pools) | Data |
| [Main Menu](hud_system.md) | `hud_system.md` | ✅ Active (title screen, continue/new run) | Presentation |
| [Character Creation](hud_system.md) | `hud_system.md` | ✅ Active (B2 + B4 — slot-wheel dials, live preview with concrete rolled stats, Reroll + Back buttons, _build_pc(), 11 tests) | Presentation |
| [Unit Data Resource](unit_data.md) | `unit_data.md` | ⚠️ Legacy (2D only) | Data |
| [Game State](game_state.md) | `game_state.md` | ✅ Active (map traversal + save/load + party + inventory) | Global |
| [Map Scene](map_scene.md) | `map_scene.md` | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](party_sheet.md) | `party_sheet.md` | ✅ Active (interactive overlay, layer 20) | Presentation |
| [Event System](event_system.md) | `event_system.md` | ⚙️ Partial — data + selector + overlay + dispatch live (Slices 1/3/4); player_pick picker in Slice 5 | Data / World Map |
| [Feat System (FeatLibrary / FeatData)](feat_system.md) | `feat_system.md` | ⚙️ Partial — data layer + display (Slice 2); no mechanical effects yet | Data |

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

MainMenuManager
  ├── GameState                   (load_save / reset / delete_save on button press)
  ├── CharacterCreationScene      (new-run path routes here instead of MapScene directly)
  ├── CharacterCreationManager    (Test New Run calls static _build_pc() to seed 3 random PCs)
  ├── KindredLibrary              (Test New Run — random kindred + name pool)
  ├── ClassLibrary                (Test New Run — random class)
  ├── BackgroundLibrary           (Test New Run — random background)
  └── PortraitLibrary             (Test New Run — random portrait id)

CharacterCreationManager
  ├── KindredLibrary              (name pool, feat id, speed/HP bonuses)
  ├── ClassLibrary                (class list, display name, starting ability)
  ├── BackgroundLibrary           (background list, display name, starting ability)
  ├── PortraitLibrary             (portrait id list)
  ├── AbilityLibrary              (resolves class + bg starting abilities for preview panel)
  ├── FeatLibrary                 (feat name + description for preview panel)
  ├── CombatantData               (built by _build_pc())
  └── GameState                   (appends PC to party on confirm)

MapManager
  ├── GameState             (load_save/init_party at startup; travel + entry increments; sets pending_node_type / current_combat_node_id; save() after post-tween dispatch)
  ├── PartySheet            (instantiated as child; Party button calls show_sheet())
  ├── EventManager          (instantiated as child; EVENT branch calls show_event(); event_finished + event_nav signals handled)
  └── EventSelector         (called in EVENT branch of _enter_current_node())

EventSelector (static)
  ├── EventLibrary          (all_events_for_ring — ring pool source)
  └── GameState             (used_event_ids — read for filter, append chosen id)

EventManager
  ├── GameState             (party, inventory, threat_level, save(), add_to_inventory(), remove_from_inventory())
  ├── EquipmentLibrary      (item_gain lookup — checked first)
  └── ConsumableLibrary     (item_gain lookup — fallback)

PartySheet
  ├── GameState             (party + inventory on every show_sheet())
  ├── EquipmentLibrary      (item id resolution)
  ├── ConsumableLibrary     (id resolution for tooltip / compare)
  ├── AbilityLibrary        (id resolution for pool + slot labels)
  └── FeatLibrary           (feat name + description for Feats tab)

NodeStub          → GameState (reads + clears pending_node_type)
BadurgaManager    → standalone (no deps; returns to MapScene on back)

GameState (autoload)
  ├── ArchetypeLibrary      (init_party() safety-fallback creates default PC)
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
├── main.tscn                           ← entry point; instances MainMenuScene.tscn
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
│   ├── events/
│   │   └── EventManager.gd             ← CanvasLayer (layer 10) overlay; show/hide event UI; static condition evaluator + effect dispatcher
│   ├── globals/
│   │   ├── AbilityLibrary.gd           ← CSV-sourced (res://data/abilities.csv); 22 abilities
│   │   ├── ArchetypeLibrary.gd         ← CSV-sourced (res://data/archetypes.csv); 5 archetypes
│   │   ├── BackgroundLibrary.gd        ← CSV-sourced (res://data/backgrounds.csv)
│   │   ├── ClassLibrary.gd             ← CSV-sourced (res://data/classes.csv); 4 classes
│   │   ├── ConsumableLibrary.gd        ← CSV-sourced (res://data/consumables.csv); healing_potion, power_tonic
│   │   ├── EquipmentLibrary.gd         ← CSV-sourced (res://data/equipment.csv); 7 items
│   │   ├── EventLibrary.gd             ← CSV-sourced (events.csv + event_choices.csv); 3 smoke events
│   │   ├── EventSelector.gd            ← static picker; ring filter + exhaustion fallback; appends to GameState.used_event_ids
│   │   ├── FeatLibrary.gd              ← CSV-sourced (res://data/feats.csv); 4 kindred feats
│   │   ├── KindredLibrary.gd           ← CSV-sourced (res://data/kindreds.csv); 4 kindreds
│   │   ├── PortraitLibrary.gd          ← CSV-sourced (res://data/portraits.csv); 6 placeholder portraits
│   │   ├── RewardGenerator.gd          ← shuffled reward pool
│   │   └── GameState.gd                ← autoload
│   ├── map/MapManager.gd
│   ├── misc/NodeStub.gd                ← placeholder stub screen
│   ├── party/PartySheet.gd             ← interactive overlay, layer 20
│   └── ui/
│       ├── CharacterCreationManager.gd ← character creation (B2 + B4); slot-wheel dials; live preview panel; _build_pc()
│       ├── CombatActionPanel.gd        ← right slide-in (layer 12)
│       ├── EndCombatScreen.gd          ← victory overlay (layer 15)
│       ├── MainMenuManager.gd          ← title screen (entry point)
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
│   ├── ArchetypeData.gd                ← one archetype (stat ranges + ability/background pools)
│   ├── BackgroundData.gd
│   ├── ClassData.gd                    ← one playable class
│   ├── EventChoiceData.gd              ← one event choice (label, conditions, effects, result_text)
│   ├── EventData.gd                    ← one non-combat event (id, title, body, ring_eligibility, choices)
│   ├── FeatData.gd                     ← one feat (id, name, description)
│   ├── KindredData.gd                  ← one kindred (speed/HP bonuses + feat)
│   ├── PortraitData.gd                 ← one selectable portrait
│   └── UnitData.gd                     ← legacy (2D only)
├── data/
│   ├── abilities.csv                   ← 22 abilities; effects as JSON arrays; read via res://data/
│   ├── archetypes.csv                  ← 5 archetypes; read via res://data/
│   ├── backgrounds.csv                 ← 4 backgrounds; read via res://data/
│   ├── classes.csv                     ← 4 classes; read via res://data/
│   ├── consumables.csv                 ← 2 consumables; read via res://data/
│   ├── equipment.csv                   ← 7 items (rusted_dagger added Slice 4); stat_bonuses as stat:value|stat:value pairs
│   ├── event_choices.csv               ← 7 choice rows; joined to events by event_id; effects as JSON arrays
│   ├── events.csv                      ← 3 smoke events; ring_eligibility as pipe list
│   ├── feats.csv                       ← 4 kindred feats; read via res://data/
│   ├── kindreds.csv                    ← 4 kindreds; read via res://data/
│   └── portraits.csv                   ← 6 placeholder portraits; read via res://data/
├── scenes/
│   ├── city/BadurgaScene.tscn
│   ├── combat/
│   │   ├── CombatScene3D.tscn          ← active (3D)
│   │   ├── CombatScene.tscn            ← legacy 2D
│   │   ├── Grid3D.tscn · Grid.tscn
│   │   ├── Unit3D.tscn · Unit.tscn
│   │   └── QTEBar.tscn
│   ├── map/MapScene.tscn
│   ├── events/EventScene.tscn          ← minimal (root CanvasLayer + EventManager script)
│   ├── misc/NodeStub.tscn
│   ├── party/PartySheet.tscn
│   └── ui/
│       ├── CharacterCreationScene.tscn ← root CanvasLayer + script only; children built in _ready()
│       ├── CombatActionPanel.tscn
│       ├── HUD.tscn                    ← legacy 2D only
│       ├── MainMenuScene.tscn          ← entry point (instanced by main.tscn)
│       └── RunSummaryScene.tscn
└── tests/                              ← 28 test files (89 tests total); includes test_event_manager.gd/.tscn; see `tests/test_combatant_data.tscn` for the runner pattern
```

---

## Recent Milestones

Last 5 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-04-25 | EventManager, MapManager, CombatantData, GameState | **Events Slice 4 — EventScene overlay, condition evaluator, effect dispatcher, feats field.** `EventManager.gd` + `EventScene.tscn` created (CanvasLayer layer 10). `show_event()`/`hide_event()` API; choice buttons disabled+dimmed when conditions fail; result panel + Continue flow; `event_finished` + `event_nav` signals. Static `evaluate_condition` (6 forms), `resolve_target` (4 values), `dispatch_effect` (7 types). `CombatantData.feats: Array[String]` added; serialized/deserialized in GameState via typed-array pattern; old saves default to `[]`. MapManager: EVENT branch calls `EventSelector.pick_for_node` + `show_event` instead of NodeStub; `_get_ring()` helper; `_on_event_finished` + `_on_event_nav` handlers mark node cleared + refresh map. `_input()` and `_on_node_clicked()` guard against re-entry while overlay is visible. Cleared stamp: CURRENT+CLEARED now renders ✗ immediately; stamp font 18, bright red, outlined, centered. `rusted_dagger` added to equipment.csv. 19 new headless tests (89 total). |
| 2026-04-24 | EventSelector, GameState, MapManager | **Events Slice 3 — EventSelector + used_event_ids persistence.** `GameState.used_event_ids` (`Array[String]`) added with full save/load/reset wiring (typed-array pattern matching `cleared_nodes`). `EventSelector.gd` created: static `pick_for_node(ring)` filters already-seen ids, exhaustion-falls-back to full ring pool, pushes warning + returns stub for rings with no authored events, appends chosen id to `GameState.used_event_ids`, never calls `save()`. `MapManager._move_player_to()` gains a trailing `GameState.save()` after post-tween dispatch, covering VENDOR/CITY "Keep Moving" path. 7 new headless tests (70 total): 5 EventSelector + 2 GameState save round-trip. EVENT nodes still route to NodeStub — EventScene overlay is Slice 4. |
| 2026-04-24 | FeatLibrary, FeatData, StatPanel, CharacterCreationManager, PartySheet | **Feats Slice 2 — FeatLibrary data foundation + display migration.** `FeatData.gd` resource + `FeatLibrary.gd` (CSV-native, `get_feat()`/`all_feats()`/`reload()`, never-null stub). `feats.csv` seeds 4 kindred feats (`adaptive`, `relentless`, `tinkerer`, `stonehide`). All display surfaces migrated from `KindredLibrary.get_feat_name()` to `FeatLibrary.get_feat(kindred_feat_id)`. StatPanel: `── Feats ──` section in RTL after Abilities, numbered entries. CharacterCreationManager preview: feat name + description label. PartySheet Feats tab: full Abilities-tab-style UI — 1×/2× toggle, Name sort, search bar, `PanelContainer` cards with hover tooltip. 8 new headless tests (63 total). |
| 2026-04-24 | EventLibrary, EventData, EventChoiceData | **Events Slice 1 — data library foundation.** `EventData` + `EventChoiceData` resources; `events.csv` (3 smoke events: `chest_rusty`, `wounded_traveler`, `merchant_stall`) + `event_choices.csv` (7 choices covering full effect vocabulary: item_gain, heal/player_pick target, open_vendor nav, threat_delta, no-op). `EventLibrary` loads both CSVs, joins choices by `event_id`+`order`, exposes `get_event`/`all_events`/`all_events_for_ring`/`reload`; stub fallback on unknown id, never null. 12 headless tests. Two-CSV relational split is intentional deviation from single-CSV library convention — events are the first data type with repeating child rows. |
| 2026-04-24 | CharacterCreationManager, MainMenuManager | **Back button + stat reroll.** Left column now has a "← Back to Main Menu" button that returns to MainMenu without mutating save state. To make Back a clean cancel, `delete_save()` + `reset()` were moved from `MainMenuManager._on_new_run()` into `CharacterCreationManager._on_confirm()`. Stats are rolled at `_ready()` and shown concrete in the preview (HP + STR/DEX/COG/WIL/VIT + AC) with a 🎲 Reroll Stats button in the preview panel. `_build_pc()` signature extended with `rolled_stats: Dictionary = {}` — populated dict wins verbatim, empty dict falls back to internal rolling (preserves Test New Run + existing 9 tests). 2 new tests (11 total). |
| 2026-04-24 | MainMenuManager | Added **Test New Run** button — dev shortcut that skips character creation and seeds `GameState.party` with three fully-randomized PCs via `CharacterCreationManager._build_pc()` (random kindred / class / background / portrait / name from kindred pool). Transitions directly to `MapScene`. Muted purple tint to signal dev affordance. 4-button layout still fits 1280×720. |
| 2026-04-24 | CharacterCreationManager | Character creation B4 — Live preview panel added below the dial row. Read-only `PanelContainer` renders HP range (`10 + kindred_hp + [6..24]`), Speed (`1 + kindred_speed`), Stats ("1–4" flat), selected class ability name+description, selected background ability name+description, and kindred feat name. Updates live on every dial spin via `_on_pick_changed()` → `_calc_preview()`. `_calc_preview()` upgraded from `{}` stub to a dict-returning function that also pushes values into eight instance-var `Label` refs. New helpers `_build_preview_panel()` + `_make_stat_label()`. `AbilityLibrary` added as a dependency. No new tests (pure derived display); existing 43 headless tests green. |
| 2026-04-24 | CharacterCreationScene, GameState, MainMenuManager | Character creation B1+B2 — `MainMenuManager._on_new_run()` routes to `CharacterCreationScene` instead of `MapScene`. `CharacterCreationManager` builds `CombatantData` from player picks (kindred/class/background/portrait/name) via static `_build_pc()`. `GameState.init_party()` revised to spawn only the PC (safety fallback; creation screen is the primary populator). UI: slot-wheel dial columns with ghost prev/next neighbours, highlight panel on selection, centered via `CenterContainer`. Portrait picker deferred (icon.svg placeholder; 1 option). 9 unit tests for `_build_pc()` + updated party tests (43 total green). |
| 2026-04-23 | ArchetypeLibrary, KindredLibrary, KindredData | Name-pool migration — `_NAME_POOLS` const dict removed from `ArchetypeLibrary.gd`. Flavor names now live on `KindredData.name_pool` (`Array[String]`) sourced from the new `name_pool` column in `kindreds.csv`. `ArchetypeLibrary.create()` auto-names via `KindredLibrary.get_name_pool(kindred)`; empty pool → `"Unit"` fallback. Closes the last inline-const-dict exception in the data-library uniformity pass. Per-kindred names unchanged (Human ← old archer_bandit pool; Half-Orc ← grunt; Gnome ← alchemist; Dwarf ← elite_guard). Tests: +2 kindred name-pool tests; existing `test_archetype_ally_auto_name_from_pool` unchanged and still green. |
| 2026-04-23 | AbilityLibrary | S35 — Data-library uniformity pass session 6: `AbilityLibrary` migrated from inline `const ABILITIES` dict to `abilities.csv` + CSV-native loader. Effects encoded as JSON arrays in each row. `all_abilities()` / `reload()` added; `get_ability()` signature unchanged. `ABILITIES` dict removed; one caller in `test_class_library.gd` updated. Stale assertions in `test_ability_library.gd` fixed. |
| 2026-04-23 | ArchetypeLibrary, ArchetypeData | S34 — Data-library uniformity pass session 5: `ArchetypeLibrary` migrated from inline `const ARCHETYPES` dict to `archetypes.csv` + CSV-native loader. `ArchetypeData.gd` resource added. `ARCHETYPES` dict removed; callers updated to `all_archetypes()` / `get_archetype()`. `create()` signature unchanged. |
| 2026-04-23 | KindredLibrary, KindredData | S33 — Data-library uniformity pass session 4: `KindredLibrary` migrated from const dict to `kindreds.csv` + CSV-native loader. `KindredData.gd` resource added. All existing getter functions preserved unchanged; `get_kindred()` / `all_kindreds()` / `reload()` added. No caller changes required. |
| 2026-04-23 | EquipmentLibrary, test_equipment | S32 — Data-library uniformity pass session 3: `EquipmentLibrary` migrated from const array to `equipment.csv` + CSV-native loader. `stat_bonuses` stored as `stat:value\|stat:value` pipe pairs. `reload()` added. Two stale speed tests in `test_equipment.gd` fixed (S29 kindred formula: dex no longer drives speed). |
| 2026-04-23 | ConsumableLibrary, RewardGenerator, test_consumables | S31 — Data-library uniformity pass session 2: `ConsumableLibrary` migrated from const dict to `consumables.csv` + CSV-native loader. `all_consumables()` added; `CONSUMABLES` dict removed. `RewardGenerator` and `test_consumables` updated to use `all_consumables()`. |
| 2026-04-23 | CombatantData, KindredLibrary, StatPanel, GameState, MainMenuScene | S29 — Kindred mechanics: `speed` = `1 + kindred_bonus`; `hp_max` = `10 + kindred_bonus + VIT×6`. New `KindredLibrary.gd` (speed/HP/feat data for Human/Half-Orc/Gnome/Dwarf). `kindred_feat_id` added to CombatantData + save/load. StatPanel feat row. `MainMenuScene` / `MainMenuManager` added; `main.tscn` now boots to title screen. `RunSummaryManager` Main Menu button wired. |
| 2026-04-23 | docs | Map audit pass — docs/map_directories groomed against codebase. `combatant_data.md` split into 4 files (ability/equipment/background/core); `map_scene.md` split (PartySheet → `party_sheet.md`). ActionMenu refs purged. `EndCombatScreen.show_defeat` doc removed. Missing files added to file tree. |
| 2026-04-23 | CombatantData, ArchetypeLibrary, GameState, StatPanel, CombatActionPanel, PartySheet | S28 Kindreds: added `kindred: String` to CombatantData. Fixed per archetype (Human/Human/Half-Orc/Gnome/Dwarf). Persisted in save/load (old saves default `"Unknown"`). Displayed in three places. PartySheet columns rebalanced to ~30/40/30; HP row restructured. |
| 2026-04-23 | CombatManager3D, CombatActionPanel, UnitInfoBar | S26+S27 Combat UI overhaul: replaced radial ActionMenu with right slide-in `CombatActionPanel` (layer 12). UnitInfoBar converted to hover-based via `_handle_unit_hover()`. Consumable use no longer closes panel. `ActionMenu.gd` deleted. |
| 2026-04-20 | MapManager | S24+S25 Map node placement: RECRUIT removed; inner ring → 4 COMBAT + 2 EVENT; outer → 1 BOSS + 7 COMBAT + 3 EVENT + 1 VENDOR. `_assign_boss_type()` extracted. |
| 2026-04-20 | ArchetypeLibrary, PartySheet | S20–S23 Party Sheet arc: initial overlay → drag-drop gear → 4-quadrant card layout → Ability Pool Swap with compare panels, search/sort, view toggles. |
