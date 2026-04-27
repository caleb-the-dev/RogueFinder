# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-27 (XP + Level-Up system — grant_xp, level/xp/pending fields, pick overlay, map button glow) |
| last_groomed | 2026-04-25 |
| sessions_since_groom | 8 |
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
| [HUD System / StatPanel / UnitInfoBar / CombatActionPanel / EndCombatScreen / RewardGenerator](hud_system.md) | `hud_system.md` | ✅ Active (combat HUD stack) · ⚠️ Legacy HUD.gd kept for 2D | Presentation |
| [Combatant Data Model + ArchetypeLibrary](combatant_data.md) | `combatant_data.md` | ✅ Active (ArchetypeLibrary CSV-sourced S34) | Data |
| [Ability System (AbilityData / EffectData / AbilityLibrary)](ability_system.md) | `ability_system.md` | ✅ Active (42 abilities — 22 base + 4 kindred natural attacks + 6 ancestry + 4 class definings + 6 class pool additions, CSV-sourced) | Data |
| [Equipment & Consumables](equipment_system.md) | `equipment_system.md` | ✅ Active (6 equipment CSV-sourced S32; 2 consumables CSV-sourced S31) | Data |
| [Background System](background_system.md) | `background_system.md` | ✅ Active (owns feat lane — starting_feat_id + stat_bonuses + 2-feat pool; wired into CombatantData) | Data |
| [Class Library](class_system.md) | `class_system.md` | ✅ Active (4 classes, unique defining abilities, 13-ability pool, 10-feat pool per class; wired into CombatantData) | Data |
| [Portrait Library](portrait_system.md) | `portrait_system.md` | ✅ Active (dormant — 6 placeholder portraits, CSV-sourced, S30) | Data |
| [Kindred Library](combatant_data.md) | `combatant_data.md` | ✅ Active (owns ability lane — starting_ability_id + ability_pool + stat_bonuses; no longer grants feats) | Data |
| [Main Menu + Character Creation](character_creation.md) | `character_creation.md` | ✅ Active (deterministic stats; slot 0 = class ability, slot 1 = kindred ability; bg feat seeds feat_ids; 12 tests) | Presentation |
| [Unit Data Resource](unit_data.md) | `unit_data.md` | ⚠️ Legacy (2D only) | Data |
| [Game State](game_state.md) | `game_state.md` | ✅ Active (map traversal + save/load + party + inventory + XP/level-up) | Global |
| [Map Scene](map_scene.md) | `map_scene.md` | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](party_sheet.md) | `party_sheet.md` | ✅ Active (interactive overlay layer 20; level-up pick overlay layer 25) | Presentation |
| [Event System](event_system.md) | `event_system.md` | ✅ Active — data + selector + overlay + dispatch + player_pick picker + 15 events (3 smoke + 12 authored) (Slices 1/3/4/5/6) | Data / World Map |
| [Feat System (FeatLibrary / FeatData)](feat_system.md) | `feat_system.md` | ✅ Active — 32 feats (20 class, 12 background), stat bonuses applied, grant_feat() API live | Data |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D                (cell queries, highlights, world↔grid math)
  ├── Unit3D ×≤6            (HP/energy, movement, animations; player units from GameState.party)
  ├── QTEBar                (defender-driven Slide; HARM-only; enemy instant-sims via qte_resolution; awaited inline)
  ├── CameraController      (built by CM3D; shake on hit; focus_on/restore for QTE camera)
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
  ├── KindredLibrary              (name pool, speed/HP bonuses, stat_bonuses, starting_ability_id)
  ├── ClassLibrary                (class list, display name, starting ability, stat_bonuses)
  ├── BackgroundLibrary           (background list, display name, starting_feat_id, stat_bonuses)
  ├── PortraitLibrary             (portrait id list)
  ├── AbilityLibrary              (resolves class + kindred starting abilities for preview panel)
  ├── FeatLibrary                 (background feat name + description for preview panel)
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
  ├── GameState             (party, inventory, threat_level, save(), add_to_inventory(), remove_from_inventory(), grant_feat())
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
  ├── EquipmentLibrary      (load_save resolves equipment slot ids)
  ├── ClassLibrary          (sample_ability_candidates + sample_feat_candidates)
  ├── KindredLibrary        (sample_ability_candidates)
  └── BackgroundLibrary     (sample_feat_candidates)
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
│   │   ├── AbilityLibrary.gd           ← CSV-sourced (res://data/abilities.csv); 42 abilities (22 base + 4 kindred natural attacks + 6 ancestry + 4 class definings + 6 class pool)
│   │   ├── ArchetypeLibrary.gd         ← CSV-sourced (res://data/archetypes.csv); 5 archetypes
│   │   ├── BackgroundLibrary.gd        ← CSV-sourced (res://data/backgrounds.csv)
│   │   ├── ClassLibrary.gd             ← CSV-sourced (res://data/classes.csv); 4 classes
│   │   ├── ConsumableLibrary.gd        ← CSV-sourced (res://data/consumables.csv); healing_potion, power_tonic
│   │   ├── EquipmentLibrary.gd         ← CSV-sourced (res://data/equipment.csv); 7 items
│   │   ├── EventLibrary.gd             ← CSV-sourced (events.csv + event_choices.csv); 15 events (3 smoke + 12 authored)
│   │   ├── EventSelector.gd            ← static picker; ring filter + exhaustion fallback; appends to GameState.used_event_ids
│   │   ├── FeatLibrary.gd              ← CSV-sourced (res://data/feats.csv); 32 feats (20 class, 12 background); parses stat_bonuses
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
│   ├── FeatData.gd                     ← one feat (id, name, description, source_type, stat_bonuses, effects)
│   ├── KindredData.gd                  ← one kindred (speed/HP bonuses + stat_bonuses + starting_ability_id + ability_pool + name_pool; feat_id removed)
│   ├── PortraitData.gd                 ← one selectable portrait
│   └── UnitData.gd                     ← legacy (2D only)
├── data/
│   ├── abilities.csv                   ← 42 abilities; effects as JSON arrays; read via res://data/
│   ├── archetypes.csv                  ← 5 archetypes; read via res://data/
│   ├── backgrounds.csv                 ← 4 backgrounds; read via res://data/
│   ├── classes.csv                     ← 4 classes; read via res://data/
│   ├── consumables.csv                 ← 2 consumables; read via res://data/
│   ├── equipment.csv                   ← 7 items (rusted_dagger added Slice 4); stat_bonuses as stat:value|stat:value pairs
│   ├── event_choices.csv               ← 46 choice rows; joined to events by event_id; effects as JSON arrays
│   ├── events.csv                      ← 15 events (3 smoke + 12 authored); ring_eligibility as pipe list
│   ├── feats.csv                       ← 32 feats (20 class, 12 background); kindred rows removed
│   ├── kindreds.csv                    ← 4 kindreds; feat_id removed; stat_bonuses + starting_ability_id + ability_pool added; read via res://data/
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
└── tests/                              ← 25 test scripts + 13 scene runners; includes test_event_manager.gd/.tscn + test_event_manager_slice5.gd/.tscn; see `tests/test_combatant_data.tscn` for the runner pattern; test_camera_controls.gd (6 headless assertions, extends SceneTree)
```

---

## Recent Milestones

Last 5 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-04-27 | CombatantData, GameState, CombatManager3D, MapManager, PartySheet, tests | **XP + Level-Up system.** `CombatantData` gained `level: int`, `xp: int`, `pending_level_ups: int` (all serialized; old saves default 1/0/0). `GameState` gained `XP_THRESHOLDS = [20,35,55,80]`, `grant_xp(15)` (15 XP/win; level+pending incremented on threshold cross; level cap 20), `xp_needed_for_next_level()`, `sample_ability_candidates()`, `sample_feat_candidates()` (both static). `CombatManager3D._end_combat(true)` calls `grant_xp(15)` on victory; debug T menu gained "Grant XP +20" and "Force Level-Up" buttons (latter also increments level). `MapManager`: party button promoted to class var `_party_btn`; `_refresh_party_btn()` shows "Level Up Available" with rainbow modulate tween + scale pulse when pending > 0; Dev Menu (bottom-right, renamed from "Events [DEV]") gained XP/LEVEL section with Grant XP + Force Level-Up options. `PartySheet`: `level_up_resolved` signal added; TR quadrant shows "Lv. X" (centered) or rainbow Level Up button (suppresses label); level-up pick overlay (layer 25) shows 3 horizontal `_build_pick_card()` cards matching EndCombatScreen reward style; even levels → ability pick, odd levels → feat pick; multiple pending picks chain back-to-back in one overlay via `_fill_next_pick()` formula `pick_level = pc.level - pc.pending_level_ups + 1`. 11 headless tests added (`test_game_state_xp.gd`); all 70 prior tests still passing. |
| 2026-04-26 | abilities.csv, classes.csv, feats.csv, tests | **Class Pool Expansion — defining abilities + full pools.** 4 class defining abilities added to `abilities.csv` (`tower_slam` STR HARM4+push1, `arcane_bolt` COG HARM5 range4, `slipshot` DEX HARM4+travel1, `bless` WIL BUFF STR+1 ally). 6 new class-pool abilities added (`backstab`, `crippling_shot`, `vanishing_step` for Prowler; `lay_on_hands`, `divine_ward`, `rallying_shout` for Warden). abilities.csv: 32→42 total. `classes.csv` `starting_ability_id` updated to new definings; `ability_pool` 5→13 per class; `feat_pool` 3→10 per class. `feats.csv` +8 new class feats (`iron_constitution`, `combat_mastery`, `spell_memory`, `evasive_footwork`, `relentless_assault`, `arcane_resilience`, `iron_will`, `veteran_instinct`) → 32 total (20 class, 12 bg). Test suite cleanup: pre-existing `test_feat_library.gd` + `test_feat_stat_bonus.gd` failures (stale kindred feat refs `adaptive`/`stonehide`/`relentless`) fixed. 70 tests passing across 7 suites. |
| 2026-04-26 | kindreds.csv, backgrounds.csv, feats.csv, abilities.csv, KindredData, BackgroundData, KindredLibrary, BackgroundLibrary, CombatantData, CharacterCreationManager, GameState, tests | **Pillar Foundation — ability/feat lane split + deterministic stats.** Kindreds now own the ability lane: `stat_bonuses`, `starting_ability_id`, `ability_pool` added to `kindreds.csv` + `KindredData` + `KindredLibrary`; `feat_id` removed. 4 kindred natural attacks + 6 ancestry abilities added to `abilities.csv` (32 total). Backgrounds now own the feat lane: `starting_feat_id` + `stat_bonuses` added to `backgrounds.csv` + `BackgroundData` + `BackgroundLibrary`; `starting_ability_id` removed. `feats.csv` drops 4 kindred rows → 24 feats. `CombatantData` attribute defaults changed 5→4; `get_kindred_stat_bonus()` + `get_background_stat_bonus()` added and wired into all 6 derived stat formulas. `CharacterCreationManager`: `_roll_stats()` + Reroll button removed; stats now `base 4 + pillar bonuses`; slot 0 = class ability, slot 1 = kindred natural attack; `feat_ids` seeded from `bg.starting_feat_id`. Preview panel shows class/kindred ability + background feat. `GameState._deserialize_combatant()` strips old kindred feat IDs on load. `ArchetypeLibrary.create()` seeds `feat_ids = []` (enemies). 77 tests passing across 7 suites (test_class_stat_bonus.gd new, all existing suites updated). |
| 2026-04-26 | feats.csv, FeatData, FeatLibrary, CombatantData, GameState, EventManager, UI | **Feat System Slices 1–7 — mechanically active.** feats.csv expanded to 28 rows (4 kindred, 12 class, 12 background) with `source_type`, `stat_bonuses` (parsed to Dictionary), `effects`, `notes` columns. FeatData gained those fields. FeatLibrary parses `stat:value\|stat:value`. kindreds.csv dropped `feat_name`/`feat_desc`; KindredData + KindredLibrary cleaned up. classes.csv + ClassData + ClassLibrary gained `feat_pool: Array[String]`. CombatantData: `kindred_feat_id` + `feats` consolidated into `feat_ids: Array[String]`; `get_feat_stat_bonus(stat)` added; all 6 derived stat formulas include feat bonuses (flat, same as equipment). GameState: `grant_feat(pc_index, feat_id)` added (deduplication + save); `_serialize_combatant` writes `feat_ids`; `_deserialize_combatant` migrates old saves (kindred_feat_id + feats → feat_ids). EventManager: `feat_grant` effect calls `GameState.grant_feat()`; `feat:ID` condition checks `member.feat_ids`. StatPanel + PartySheet iterate `feat_ids`. 3 new test files (17 new tests); 4 existing test files updated. 84 tests total passing. |
| 2026-04-26 | CameraController.gd, tests/ | **Camera pan session — WASD pan + full orbit right-click + Q/E pivot-Y + QTE zoom.** WASD / arrow keys pan orbit pivot in yaw-relative XZ (W=NE at default yaw). Right-click drag now controls full orbit: horizontal = yaw, vertical = elevation pitch (drag up = more top-down, 15°–80°). `DRAG_SENSITIVITY` halved to 0.2. Q/E repurposed: raise/lower orbit pivot on world Y (`PIVOT_Y_SPEED=5` u/s, clamped −3 to 8). `focus_on` / `restore` upgraded to parallel tweens — pivot position + distance animate simultaneously; zooms to `QTE_DISTANCE=10.0` on focus and back on restore. `_set_distance()` tween helper added; `_pre_qte_distance` field added. ELEVATION_STEP/ELEVATION_SPEED removed; PIVOT_Y_SPEED/MIN/MAX, PAN_SPEED/MIN/MAX, QTE_DISTANCE added. test_camera_controls.gd expanded to 6 assertions. |
| 2026-04-26 | CameraController.gd, tests/ | **Camera overhaul — elevation Q/E + right-click drag rotation + cursor capture.** Q/E now control pitch (`_elevation`, 15°–80° clamped, 10°/press) instead of snapped yaw. Right-click drag rotates yaw continuously (`DRAG_SENSITIVITY = 0.4°/px`). Cursor captured (`MOUSE_MODE_CAPTURED`) while dragging, restored on release. `DEFAULT_ELEVATION` constant promoted to `_elevation: float` variable; `_apply_transform()` uses `_elevation` so focus_on/restore tweens maintain player-set pitch. Removed `ROTATE_STEP`; added `MIN_ELEVATION`, `MAX_ELEVATION`, `ELEVATION_STEP`, `DRAG_SENSITIVITY`, `_dragging`. New headless test suite `test_camera_controls.gd` (3 assertions: upper clamp, lower clamp, default value). |
| 2026-04-26 | QTEBar.gd, CombatManager3D.gd, CameraController.gd, tests/ | **QTE Session B — world-space bar + camera focus.** `start_qte(energy_cost, attacker: Node3D)` — bar now floats above the attacker in world space each frame via `Camera3D.unproject_position(pos + Vector3(0,2,0))`. Full-screen dark overlay removed. `_attacker` cleared after `qte_resolved`. Attacker-death guard in `_process`. Camera smoothly focuses on the attacker before each QTE (0.5 s `focus_on` tween + 0.25 s settle), then restores to grid center after. `CameraController` gained `focus_on()`, `restore()`, `_set_pivot()`, `_home_position`, `_pivot_tween`. New headless test suite `test_qte_world_bar.gd` (3 assertions). |
| 2026-04-26 | QTEBar.gd, CombatManager3D.gd, tests/ | **QTE Reactive Overhaul — Session A (logic).** QTE is now defender-driven and HARM-only. Hold/Target/Directional QTE styles deleted; only Slide remains, always 1 beat. `start_qte()` simplified to `(energy_cost: int)`. Non-HARM effects (MEND/BUFF/DEBUFF/FORCE/TRAVEL) auto-resolve at 1.0. New damage multiplier mapping: defender roll 1.25→0.5, 1.0→0.75, 0.75→1.0, 0.25→1.25. New HARM formula: `max(1, round(dmg_mult * (base_value + caster.attack)))`. Friendly fire (same-team AoE): dmg_mult fixed at 1.0, no QTE. TRAVEL always succeeds (enters destination mode immediately). AoE HARM: one QTE per hit defender, sequential. Player attacks enemies: enemy instant-sims defense (no bar shown). Enemy attacks player units: player sees dodge bar. Deleted `_on_qte_resolved`, `_apply_effects`. Added `_apply_non_harm_effects`, `_get_harm_effect`, `_run_harm_defenders`, `_defender_roll_to_dmg_multiplier`. CM3D uses `await _qte_bar.qte_resolved` inline (no signal handler). Deleted 3 stale test files; added `test_qte_reactive.gd` (6 test functions). Session B (world-space bar) deferred. |
| 2026-04-25 | events.csv, event_choices.csv, MapManager.gd | **Events Slice 6 — full event pass + MapManager improvements.** 12 new events authored (outer: fallen_signpost, roadside_shrine, dry_well, abandoned_campfire, stray_dog, road_patrol; middle: mercenary_camp, burned_farmhouse, standing_stone, river_crossing; inner: mass_grave, ember_idol). Post-testing revision pass: 13 targeted changes including `wounded_traveler` → Wandering Medic, `survivor_in_the_dark` removed, `stray_dog` made recruit placeholder, road_patrol/bridge/farmhouse mechanics adjusted. MapManager: dev event test panel (CanvasLayer layer 30; "Events [DEV]" button; `_is_dev_event` flag prevents node clearing from panel-fired events including nav effects); live threat meter refresh (`_refresh_threat_meter()` called on traversal + event finish); CITY nodes excluded from cleared stamp. Final CSV counts: events.csv 15 rows, event_choices.csv 46 rows. |
| 2026-04-25 | EventManager, GameState, PartySheet | **Events Slice 5 — player_pick picker overlay + new-item glow.** `_on_choice_pressed` is now async (coroutine): pre-scans choice effects for `player_pick` target, shows a centered picker panel (500×200 px, blue border) with one button per alive party member, awaits `target_picked` signal, then dispatches all effects with the resolved member via new `forced_target` param on `dispatch_effect`. `dispatch_effect` signature extended: `forced_target: CombatantData = null` — when non-null and effect target is `player_pick`, uses it directly (static + headless-testable). New `_resolve_with_override` helper. `GameState.add_to_inventory()` now stamps `seen = false` on every incoming dict. PartySheet item cards check `item.get("seen", true)`: unseen → gold border + looping alpha tween; `mouse_entered` sets `seen = true` on the live dict (shared ref) and calls `_rebuild()`. Old saves without `seen` key default to `true`. 7 new headless tests (96 total). |
| 2026-04-25 | EventManager, MapManager, CombatantData, GameState | **Events Slice 4 — EventScene overlay, condition evaluator, effect dispatcher, feats field.** `EventManager.gd` + `EventScene.tscn` created (CanvasLayer layer 10). `show_event()`/`hide_event()` API; choice buttons disabled+dimmed when conditions fail; result panel + Continue flow; `event_finished` + `event_nav` signals. Static `evaluate_condition` (6 forms), `resolve_target` (4 values), `dispatch_effect` (7 types). `CombatantData.feats: Array[String]` added; serialized/deserialized in GameState via typed-array pattern; old saves default to `[]`. MapManager: EVENT branch calls `EventSelector.pick_for_node` + `show_event` instead of NodeStub; `_get_ring()` helper; `_on_event_finished` + `_on_event_nav` handlers mark node cleared + refresh map. `_input()` and `_on_node_clicked()` guard against re-entry while overlay is visible. Cleared stamp: CURRENT+CLEARED now renders ✗ immediately; stamp font 18, bright red, outlined, centered. `rusted_dagger` added to equipment.csv. 19 new headless tests (89 total). |
| 2026-04-24 | EventSelector, GameState, MapManager | **Events Slice 3 — EventSelector + used_event_ids persistence.** `GameState.used_event_ids` (`Array[String]`) added with full save/load/reset wiring (typed-array pattern matching `cleared_nodes`). `EventSelector.gd` created: static `pick_for_node(ring)` filters already-seen ids, exhaustion-falls-back to full ring pool, pushes warning + returns stub for rings with no authored events, appends chosen id to `GameState.used_event_ids`, never calls `save()`. `MapManager._move_player_to()` gains a trailing `GameState.save()` after post-tween dispatch, covering VENDOR/CITY "Keep Moving" path. 7 new headless tests (70 total): 5 EventSelector + 2 GameState save round-trip. EVENT nodes still route to NodeStub — EventScene overlay is Slice 4. |
| 2026-04-24 | FeatLibrary, FeatData, StatPanel, CharacterCreationManager, PartySheet | **Feats Slice 2 — FeatLibrary data foundation + display migration.** `FeatData.gd` resource + `FeatLibrary.gd` (CSV-native, `get_feat()`/`all_feats()`/`reload()`, never-null stub). `feats.csv` seeds 4 kindred feats (`adaptive`, `relentless`, `tinkerer`, `stonehide`). All display surfaces migrated from `KindredLibrary.get_feat_name()` to `FeatLibrary.get_feat(kindred_feat_id)`. StatPanel: `── Feats ──` section in RTL after Abilities, numbered entries. CharacterCreationManager preview: feat name + description label. PartySheet Feats tab: full Abilities-tab-style UI — 1×/2× toggle, Name sort, search bar, `PanelContainer` cards with hover tooltip. 8 new headless tests (63 total). |
