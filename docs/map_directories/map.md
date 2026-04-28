# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-28 (Rarity Foundation — Rarity enum, RARITY_COLORS, weighted drops, 9 COMMON placeholders replace old 20 items) |
| last_groomed | 2026-04-25 |
| sessions_since_groom | 19 |
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
| [QTE System — QTEBar + RecruitBar](qte_system.md) | `qte_system.md` | ✅ Active (QTEBar: Slide dodge; RecruitBar: hold-and-release capture) | Core |
| [Camera System](camera_system.md) | `camera_system.md` | ✅ Active (3D only) | Presentation |
| [HUD System / StatPanel / UnitInfoBar / CombatActionPanel / EndCombatScreen / RewardGenerator](hud_system.md) | `hud_system.md` | ✅ Active (combat HUD stack) · ⚠️ Legacy HUD.gd kept for 2D | Presentation |
| [Combatant Data Model + ArchetypeLibrary](combatant_data.md) | `combatant_data.md` | ✅ Active (ArchetypeLibrary CSV-sourced S34) | Data |
| [Ability System (AbilityData / EffectData / AbilityLibrary)](ability_system.md) | `ability_system.md` | ✅ Active (54 abilities — 22 base + 8 kindred natural attacks + 12 ancestry + 4 class definings + 8 class pool additions, CSV-sourced) | Data |
| [Equipment & Consumables](equipment_system.md) | `equipment_system.md` | ✅ Active (9 COMMON placeholder equipment CSV-sourced; 6 consumables CSV-sourced; rarity tier system live) | Data |
| [Background System](background_system.md) | `background_system.md` | ✅ Active (6 backgrounds; owns feat lane; +1 single stat per background) | Data |
| [Class Library](class_system.md) | `class_system.md` | ✅ Active (4 classes; 4 total stat points, max +2 per stat; 13-ability pool, 10-feat pool; wired into CombatantData) | Data |
| [Temperament System](combatant_data.md) | `combatant_data.md` | ✅ Active (21 temperaments; +1 boosted / -1 hindered / Even neutral; randomly assigned at creation; hidden until post-creation) | Data |
| [Portrait Library](portrait_system.md) | `portrait_system.md` | ✅ Active (dormant — 6 placeholder portraits, CSV-sourced, S30) | Data |
| [Kindred Library](combatant_data.md) | `combatant_data.md` | ✅ Active (8 kindreds — Human/Half-Orc/Gnome/Dwarf/Skeleton/Giant Rat/Spider/Dragon; owns ability lane; no longer grants feats) | Data |
| [Main Menu + Character Creation](character_creation.md) | `character_creation.md` | ✅ Active (deterministic stats; slot 0 = class ability, slot 1 = kindred ability; bg feat seeds feat_ids; 12 tests) | Presentation |
| [Unit Data Resource](unit_data.md) | `unit_data.md` | ⚠️ Legacy (2D only) | Data |
| [Game State](game_state.md) | `game_state.md` | ✅ Active (map traversal + save/load + party + bench + inventory + gold + XP/level-up) | Global |
| [Map Scene](map_scene.md) | `map_scene.md` | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](party_sheet.md) | `party_sheet.md` | ✅ Active (interactive overlay layer 20; level-up pick overlay layer 25) | Presentation |
| [Event System](event_system.md) | `event_system.md` | ✅ Active — data + selector + overlay + dispatch + player_pick picker + 17 events (3 smoke + 14 authored) + recruit_follower effect (Slices 1/3/4/5/6/7) | Data / World Map |
| BenchSwapPanel | `event_system.md` | ✅ Active — shared bench-swap comparison UI; used by EventManager (event recruit), CombatManager3D (combat recruit), and BadurgaManager (city hire bench-full path); static builder, no scene | Presentation |
| Hire Roster (BadurgaManager) | `map_scene.md` | ✅ Active — full hire overlay in Badurga; seeded roster generation; one-at-a-time card with nav; ability/feat tabs with tooltips; gold economy | City |
| [Feat System (FeatLibrary / FeatData)](feat_system.md) | `feat_system.md` | ✅ Active — 38 feats (20 class, 18 background), stat bonuses applied, grant_feat() API live | Data |
| [Pause Menu + Settings + Archetypes Log](hud_system.md) | `hud_system.md` | ✅ Active — CanvasLayer layer 26 autoload; ESC toggle; Settings (vol sliders placeholder); Guide stub; Archetypes Log (Pokédex — UNKNOWN/ENCOUNTERED/FOLLOWER/PLAYER statuses) | Presentation |
| [SettingsStore](hud_system.md) | `hud_system.md` | ✅ Active — autoload; user://settings.json; volume prefs (master/music/sfx) | Global |

---

## Dependency Graph

```
CombatManager3D
  ├── Grid3D                (cell queries, highlights, world↔grid math)
  ├── Unit3D ×≤6            (HP/energy, movement, animations; player units from GameState.party)
  ├── QTEBar                (defender-driven Slide; HARM-only; enemy instant-sims via qte_resolution; awaited inline)
  ├── RecruitBar            (Pathfinder hold-and-release capture; layer 11; awaited inline in _initiate_recruit)
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
  ├── ConsumableLibrary     (button + tooltip)
  └── GameState             (bench.size() + BENCH_CAP for Recruit button enable check)

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
  ├── TemperamentLibrary          (random_id() for hidden temperament assignment in _build_pc())
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

BadurgaManager
  ├── GameState             (gold, bench, party, add_to_bench, release_from_bench, swap_active_bench, save)
  ├── ArchetypeLibrary      (_generate_hire_roster, _create_hire_candidate, get_archetype for hire_cost lookup)
  ├── KindredLibrary        (name pool for deterministic candidate naming)
  ├── AbilityLibrary        (ability name + energy cost + attribute + description for hire card tooltips)
  ├── FeatLibrary           (feat name + description + stat_bonuses for hire card tooltips)
  ├── BackgroundLibrary     (feat pool per background for feats tab)
  ├── TemperamentLibrary    (temperament display in hire card identity)
  └── BenchSwapPanel        (bench-full path on hire)

GameState (autoload)
  ├── ArchetypeLibrary      (init_party() safety-fallback creates default PC)
  ├── EquipmentLibrary      (load_save resolves equipment slot ids)
  ├── ClassLibrary          (sample_ability_candidates + sample_feat_candidates)
  ├── KindredLibrary        (sample_ability_candidates)
  └── BackgroundLibrary     (sample_feat_candidates)

PauseMenu (autoload, CanvasLayer layer 26)
  ├── GameState             (encountered_archetypes + recruited_archetypes for Archetypes Log)
  ├── ArchetypeLibrary      (all_archetypes() for log card display)
  └── SettingsStore         (read/write volume on settings panel)

SettingsStore (autoload)   ← persists to user://settings.json; no deps
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
│   │   ├── RecruitBar.gd               ← hold-and-release capture QTE (layer 11)
│   │   ├── CombatManager.gd            ← legacy 2D
│   │   ├── Unit.gd                     ← legacy 2D
│   │   └── Grid.gd                     ← legacy 2D
│   ├── events/
│   │   └── EventManager.gd             ← CanvasLayer (layer 10) overlay; show/hide event UI; static condition evaluator + effect dispatcher
│   ├── globals/
│   │   ├── AbilityLibrary.gd           ← CSV-sourced (res://data/abilities.csv); 54 abilities (22 base + 8 kindred natural attacks + 12 ancestry + 4 class definings + 8 class pool)
│   │   ├── ArchetypeLibrary.gd         ← CSV-sourced (res://data/archetypes.csv); 9 archetypes (RogueFinder + 4 original + 4 new kindred templates)
│   │   ├── BackgroundLibrary.gd        ← CSV-sourced (res://data/backgrounds.csv)
│   │   ├── ClassLibrary.gd             ← CSV-sourced (res://data/classes.csv); 4 classes
│   │   ├── ConsumableLibrary.gd        ← CSV-sourced (res://data/consumables.csv); 6 consumables
│   │   ├── EquipmentLibrary.gd         ← CSV-sourced (res://data/equipment.csv); 9 COMMON placeholder items; rarity + granted_ability_ids + feat_id columns added
│   │   ├── EventLibrary.gd             ← CSV-sourced (events.csv + event_choices.csv); 17 events (3 smoke + 14 authored)
│   │   ├── EventSelector.gd            ← static picker; ring filter + exhaustion fallback; appends to GameState.used_event_ids
│   │   ├── FeatLibrary.gd              ← CSV-sourced (res://data/feats.csv); 38 feats (20 class, 18 background); parses stat_bonuses
│   │   ├── KindredLibrary.gd           ← CSV-sourced (res://data/kindreds.csv); 8 kindreds (4 humanoid + 4 non-humanoid)
│   │   ├── PortraitLibrary.gd          ← CSV-sourced (res://data/portraits.csv); 6 placeholder portraits
│   │   └── TemperamentLibrary.gd       ← CSV-sourced (res://data/temperaments.csv); 21 temperaments (20 + Even neutral); random_id(rng) helper
│   │   ├── RewardGenerator.gd          ← shuffled reward pool
│   │   ├── SettingsStore.gd            ← autoload; user://settings.json; volume prefs (master/music/sfx)
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
│       ├── PauseMenuManager.gd         ← global pause overlay autoload (layer 26)
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
│   ├── TemperamentData.gd              ← one temperament (id, name, boosted_stat, hindered_stat — both empty for neutral "even")
│   ├── PortraitData.gd                 ← one selectable portrait
│   └── UnitData.gd                     ← legacy (2D only)
├── data/
│   ├── abilities.csv                   ← 54 abilities; effects as JSON arrays; read via res://data/
│   ├── archetypes.csv                  ← 9 archetypes; read via res://data/
│   ├── backgrounds.csv                 ← 6 backgrounds; read via res://data/
│   ├── classes.csv                     ← 4 classes; read via res://data/
│   ├── consumables.csv                 ← 6 consumables; read via res://data/
│   ├── equipment.csv                   ← 9 COMMON placeholder items (3 weapon/3 armor/3 accessory); rarity|granted_ability_ids|feat_id columns added (Slices 3–5 fill tiered families)
│   ├── event_choices.csv               ← 53 choice rows; joined to events by event_id; effects as JSON arrays
│   ├── events.csv                      ← 17 events (3 smoke + 14 authored); ring_eligibility as pipe list
│   ├── feats.csv                       ← 38 feats (20 class, 18 background); kindred rows removed
│   ├── kindreds.csv                    ← 8 kindreds (Human/Half-Orc/Gnome/Dwarf/Skeleton/Giant Rat/Spider/Dragon); read via res://data/
│   ├── temperaments.csv                ← 21 rows; columns: id, name, boosted_stat, hindered_stat; "even" row has empty stats (neutral)
│   └── portraits.csv                   ← 6 placeholder portraits; read via res://data/
├── scenes/
│   ├── city/BadurgaScene.tscn
│   ├── combat/
│   │   ├── CombatScene3D.tscn          ← active (3D)
│   │   ├── CombatScene.tscn            ← legacy 2D
│   │   ├── Grid3D.tscn · Grid.tscn
│   │   ├── Unit3D.tscn · Unit.tscn
│   │   ├── QTEBar.tscn
│   │   └── RecruitBar.tscn             ← minimal (root CanvasLayer + script only)
│   ├── map/MapScene.tscn
│   ├── events/EventScene.tscn          ← minimal (root CanvasLayer + EventManager script)
│   ├── misc/NodeStub.tscn
│   ├── party/PartySheet.tscn
│   └── ui/
│       ├── CharacterCreationScene.tscn ← root CanvasLayer + script only; children built in _ready()
│       ├── CombatActionPanel.tscn
│       ├── HUD.tscn                    ← legacy 2D only
│       ├── MainMenuScene.tscn          ← entry point (instanced by main.tscn)
│       ├── PauseMenuScene.tscn         ← minimal (root CanvasLayer + PauseMenuManager script); registered as PauseMenu autoload
│       └── RunSummaryScene.tscn
└── tests/                              ← 40 test scripts + 27 scene runners. **test_rarity.gd/.tscn** added 2026-04-28 (11 assertions — EquipmentData defaults, RARITY_COLORS, rarity_color(), CSV parse, RARITY_WEIGHTS, roll dict shape, distinct ids, smoke distribution). test_pause_menu.gd/.tscn (12); test_hire_roster.gd/.tscn (6); test_recruit_success.gd/.tscn (11); test_recruit_math.gd/.tscn (13); test_armor_mod.gd/.tscn (11); see `tests/test_combatant_data.tscn` for the runner pattern; test_camera_controls.gd (6, extends SceneTree). All `extends Node` tests require a .tscn runner and are invoked with `--headless --path rogue-finder <test>.tscn`; `extends SceneTree` tests use `--script`.
```

---

## Recent Milestones

Last 5 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-04-28 | EquipmentData, EquipmentLibrary, RewardGenerator, equipment.csv, PartySheet, EndCombatScreen, MapManager, GameState, BadurgaManager, tests | **Rarity Foundation (Slice 1).** `EquipmentData` gained `Rarity` enum (COMMON/RARE/EPIC/LEGENDARY), `rarity: int` field, `granted_ability_ids: Array[String]`, `feat_id: String`, `RARITY_COLORS` const (grey/green/blue/orange), `rarity_color()` helper. `EquipmentLibrary` parses the three new CSV columns; stub defaults to COMMON/[]/`""`. Old 20-item `equipment.csv` wiped; replaced with 9 placeholder COMMON items (3 weapon/3 armor/3 accessory). `RewardGenerator` gained `RARITY_WEIGHTS` const (60/25/12/3); `roll()` now buckets equipment by rarity, rolls tier first, picks from bucket, falls back to COMMON for empty tiers; consumables in COMMON bucket; `rarity` field added to all returned dicts. UI rarity color treatment: PartySheet (bag card border + name text + slot button text), EndCombatScreen (PanelContainer cards with colored border + name label — refactored from plain Button), MapManager Add Item modal (font color). All `add_to_inventory` call sites updated to include `rarity`. 11 new headless tests (`test_rarity.gd`); `test_equipment.gd` + `test_dual_armor.gd` + `test_event_manager.gd` updated for new item IDs. |
| 2026-04-28 | PauseMenuManager, SettingsStore, GameState, tests | **Pause Menu — Pokédex log, recruited_archetypes, fullscreen dropped.** Full Pokédex-style Archetypes Log: shows all 9 archetypes with 4 status levels — UNKNOWN (dark silhouette "???"), ENCOUNTERED (seen in combat), FOLLOWER (ever recruited to bench), PLAYER (RogueFinder = "The Pathfinder"). `GameState.recruited_archetypes: Array[String]` + `record_recruited_archetype()` added with save/load/reset wiring; `add_to_bench()` is the canonical hookpoint for all follower paths. Confirm dialogs added to Main Menu + Exit Game. `☰` button + Party button overlap fixed (party shifted left). ESC fixed: was `PROCESS_MODE_WHEN_PAUSED` (couldn't receive initial ESC to open); changed to `PROCESS_MODE_ALWAYS`. CM3D ESC: only consumed when action taken — IDLE falls through to PauseMenu. Fullscreen toggle dropped entirely (CheckBox rendered as non-interactive text). `SettingsStore.fullscreen` field + `set_fullscreen()` removed. 12 headless tests (`test_pause_menu.gd/.tscn`). |
| 2026-04-28 | PauseMenuManager (new), SettingsStore (new), GameState, CombatManager3D, ArchetypeData, ArchetypeLibrary, project.godot, tests | **Pause Menu + Archetypes Log initial.** `PauseMenuManager.gd` added as CanvasLayer autoload (layer 26). ESC toggles open/closed; blocked from MainMenuScene and RunSummaryScene via `_scene_name_is_pauseable()`. Sub-panels: Resume/Settings/Guide/Archetypes Log/Main Menu/Exit. Settings: Master/Music/SFX volume sliders (placeholder). Archetypes Log: initial version from `GameState.encountered_archetypes`. `SettingsStore.gd` autoload — `user://settings.json` separate from run save. `GameState.encountered_archetypes` + `record_archetype()` added with save/load/reset wiring. CM3D records encounter per enemy at combat start. `ArchetypeData.notes` parsed. |
| 2026-04-28 | GameState, BadurgaManager, ArchetypeLibrary, ArchetypeData, MapManager, kindreds.csv, archetypes.csv, tests | **Follower Slice 6 — City Hire Channel.** `GameState.gold: int` added with full save/load/reset wiring; old saves default 0. `archetypes.csv` gained `hire_cost` column (RogueFinder=0, grunts=20, others 25–60); `ArchetypeData.hire_cost: int` added; `ArchetypeLibrary._row_to_data()` parses it. `kindreds.csv` name pools expanded from 6 → 22 names per kindred (reduces hire-card name overlap). `MapManager` dev menu INVENTORY section gained third button: "+ Give Gold +100". `BadurgaManager` Hire Roster overlay: "Hire Roster" added to SECTIONS (2nd position); `_open_hire_roster()` → full CanvasLayer overlay (layer 18) with ◀ / N of Total / ▶ navigation showing one recruit at a time. Roster generation: `_generate_hire_roster(seed, 4)` (deterministic Fisher-Yates, pool = archetypes with hire_cost > 0; stable seed = `map_seed + visited_nodes.size()`). Candidate pre-generation: `_generate_hire_candidates()` + `_create_hire_candidate(arch, rng)` — mirrors `ArchetypeLibrary.create()` with a seeded RNG so the card display and bench insert are identical (fixes identity mismatch bug). Hire card shows: portrait, name, archetype/class/kindred/background/temperament identity, all 10 stats as large 26px chips, Abilities tab (flat pool list with tooltips), Feats tab (scrollable, per rolled background, with tooltips). BenchSwapPanel used for bench-full path (layer 19 above hire overlay); gold restored on Cancel. 6 headless tests (`test_hire_roster.gd/.tscn`). |
| 2026-04-28 | EventManager, CombatManager3D, MapManager, ArchetypeLibrary, BenchSwapPanel (new), tests | **Follower Slices 5–7 — event follower channel + bench-swap comparison panel.** EventManager: `recruit_follower` effect + `bench_not_full` condition; 3 follower-offer events (`wandering_sellsword`, `skeletal_wanderer`, `stray_dog` upgraded). `BenchSwapPanel.gd` added — static builder, shared by EventManager and CombatManager3D; shows left recruit card (portrait, archetype, 10 stats) + right scrollable bench list (portraits, stats + Δ coloring, Swap buttons) + cancel button; "Never Mind" restores event choice list, "Lose Recruit" abandons combat recruit. `dispatch_effect` gains `bench_release_idx` + `prebuilt_follower` params. `ArchetypeLibrary.create()` guards empty `backgrounds` (was crash on skeleton_warrior/rat_scrapper). Dev menu INVENTORY section: "⊕ Add Random to Bench" button added. 6 headless tests (`test_event_follower.gd`); `test_event_library.gd` ring counts updated. |
| 2026-04-28 | CombatManager3D, CombatActionPanel, GameState, MapManager, BadurgaManager, tests | **Follower Slice 4 — recruit success path + bench persistence + Party Management restore.** `_initiate_recruit()` success branch replaced with `await _on_recruit_succeeded(target)`. Full async coroutine: enemy erased from `_enemy_units` + grid; "Recruited!" floating text (0.4 s then hide); `_build_follower()` copies enemy CombatantData to player-side (is_player_unit=true, qte_resolution=0.0, level matched to party[0].level); blocking rename prompt (CanvasLayer layer 16, pre-filled from kindred name pool, Enter or Confirm button); `GameState.add_to_bench()` — on full bench, blocking 9-slot release modal; `target.queue_free()`; camera shake; `_check_win_lose()` deferred until after full flow so recruiting the last enemy triggers victory after the rename. `_make_test_combatant()` gained optional `"hp"` dict key. New `"recruit_test"` test room scenario (RogueFinder vit10 + 2 allies vs 3 Whelps at 1 HP / qte 0.05). `CombatActionPanel._refresh_recruit()` falls back to `archetype_id == "RogueFinder"` check when `test_room_kind == "recruit_test"`. GameState: `bench` now serialized under `"bench"` key (same `_serialize_combatant` format as party); `load_save()` restores bench; `reset()` clears bench. `release_from_bench(index)` added (auto-deequip + save). `swap_active_bench(party_idx, bench_idx)` added (in-place swap; caller deequips first). Bug: `BadurgaManager` called `GameState.swap_active_bench()` which was missing — added. Bug: `BadurgaManager.gd` Party Management overlay (1085 lines) was silently dropped by the follower-bench-ui merge — restored from branch tip. 11 new headless tests (`test_recruit_success.gd/.tscn`) — bench save round-trip, release deequip, level matching. |
| 2026-04-28 | CombatManager3D, CombatActionPanel, Grid3D, GameState, RecruitBar (new), tests | **Follower Slice 3 — Recruit action + hold-and-release QTE.** Pathfinder gets a dedicated "⊕ Recruit 3E" button in CombatActionPanel (below the 2×2 ability grid; Pathfinder-only; greyed when energy <3, already acted, or bench full). Clicking enters RECRUIT_TARGET_MODE: teal highlights appear on living enemies ≤3 Manhattan tiles; hovering shows qualitative odds label ("Very Low"–"Very High") anchored in world space above target. Clicking a teal enemy commits the action (spend 3 energy, has_acted=true), camera focuses on target, and the new RecruitBar QTE fires (layer 11, vertical 40×220 px bar floating above target). Player holds SPACE to push fill faster; releases inside gold window for higher-tier result. Result multiplies base_chance (driven by target HP% 80% + WIL delta 20%, clamped 0.05–0.95) to determine final success roll. On failure: "Failed!" floating text, turn continues. On success: `recruit_attempt_succeeded(target)` emitted — **Slice 4 wires bench insertion + enemy removal**. ESC or off-target click cancels free (no energy spent). `_unit_can_still_act()` updated: Pathfinder is "can still act" if recruit is available, preventing premature auto-end-turn. Grid3D gained `COLOR_RECRUIT_TARGET` teal constant + `"recruit_target"` highlight case. GameState gained `BENCH_CAP=9`, `bench: Array[CombatantData]`, `add_to_bench()` stub (not yet saved to disk). 13 new headless tests (`test_recruit_math.gd/.tscn`). |
| 2026-04-27 | kindreds.csv, abilities.csv, backgrounds.csv, feats.csv, equipment.csv, consumables.csv, archetypes.csv | **Kindred expansion — data only, no code changes.** 4 new kindreds added to `kindreds.csv`: Skeleton (physical tank, P.Armor+2, speed 2, HP 4), Giant Rat (dex swarmer, DEX+2, speed 5, HP 3), Spider (dex debuffer, DEX+1, speed 3, HP 4), Dragon (apex brute, STR+2, speed 1, HP 15). Each kindred got a natural attack + 2 ancestry pool abilities — 12 new ability rows total (`bone_strike`, `grim_endurance`, `death_rattle`, `gnaw`, `scatter`, `pack_instinct`, `venom_bite`, `web_shot`, `skitter`, `claw_swipe`, `draconic_breath`, `scales_up`). 2 new backgrounds: `scavenger` (DEX+1, criminal/feral) + `pit_fighter` (STR+1, combat/criminal) + 6 new background feats. 4 new archetypes: `skeleton_warrior`, `rat_scrapper`, `cave_spider`, `young_dragon`. Equipment 9→20 (war_hammer/twin_daggers/mages_staff/bone_club + hide_armor/silk_shroud/dragonscale_vest + swift_boots/scholars_ring/amulet_of_will/fang_necklace). Consumables 2→6 (rage_draught/focus_brew/swiftness_tonic/antidote). All new kindreds auto-appear in CharacterCreationManager — `all_kindreds()` drives the dial. |
| 2026-04-27 | temperaments.csv, TemperamentData, TemperamentLibrary, CombatantData, ArchetypeLibrary, CharacterCreationManager, GameState, StatPanel, PartySheet, backgrounds.csv, classes.csv, tests | **Temperament system + stat balance.** New Pokémon-style temperament system: `temperaments.csv` (21 rows — 20 non-neutral + "Even"), `TemperamentData.gd` resource, `TemperamentLibrary.gd` (lazy CSV load, `get_temperament()`, `all_temperaments()`, `random_id(rng)`, `reload()`). `CombatantData.temperament_id: String` (@export, serialized); `get_temperament_stat_bonus(stat)` method (+1/−1/0); wired into attack, hp_max, energy_max, energy_regen, speed as sixth flat bonus source. `ArchetypeLibrary.create()` and `CharacterCreationManager._build_pc()` both call `TemperamentLibrary.random_id(rng)` — temperament is hidden from the player before creation. `GameState` serializes `temperament_id`; old saves default to `"even"`. StatPanel: "Temperament: Fierce +STR / -DEX" line with BBCode color-coding (green+/red−) added after Background. PartySheet: "Temp: Fierce (+STR/-DEX)" line in TOP-LEFT (11 px purple-grey) after Kindred; attribute values remain plain yellow (green/red reserved for future equipment indicators). Background balance: all 4 backgrounds now give exactly +1 to one stat (soldier vit dropped, scholar cog reduced to 1, baker wil dropped). Class balance: all 4 classes now give exactly 4 total stat points, max +2 per stat (vanguard +1 str, arcanist +1 wil, prowler cog:1 added, warden +1 wil). 14 new headless tests (`test_temperament.gd`) covering library load, neutral, +1/−1/0 bonus, derived-stat wiring ×4, archetype creation, and CSV rule enforcement for both backgrounds and classes. Test suites updated: test_class_stat_bonus, test_class_library, test_character_creation, test_combatant_data. |
| 2026-04-27 | equipment.csv, GameState, CombatManager3D, MapManager, tests, docs | **Armor Mod test room + new armor pieces + Add Item dev tool.** `equipment.csv` gained `plate_cuirass` (ARMOR — physical_armor +3, dexterity -2) and `warded_robe` (ARMOR — magic_armor +2 — first equipment piece exercising the `_equip_bonus("magic_armor")` codepath). `GameState.test_room_kind: String = "armor_showcase"` added (transient, not serialized) so multiple test scenarios can share `test_room_mode`. `CombatManager3D._setup_test_room_units()` is now a dispatcher; common spawning factored to `_spawn_test_room(player_defs, enemy_defs)`; per-scenario data in `_armor_showcase_*` and `_armor_mod_*` getters. New `armor_mod` scenario: Boran (Dwarf vanguard, `stone_guard`) / Velis (Human warden, `divine_ward`) / Rune (Gnome arcanist) vs Stone Bruiser / Pyromancer / Twin Threat (all 4/4 armor). `MapManager` dev menu: existing "⚔ Test Room" renamed "Armor Showcase"; new sibling "Armor Mod" button. New "INVENTORY" section with "+ Add Item to Inventory" button → modal A-Z list of every equipment + consumable; click drops a copy into `GameState.inventory`. 4 new tests in `test_equipment.gd` (plate_cuirass, warded_robe, magic-armor independence, library size 9); all prior suites still green. |
| 2026-04-27 | AbilityData, CombatantData, AbilityLibrary, CombatManager3D, abilities.csv, tests | **Armor Mod — runtime BUFF/DEBUFF lane.** `AbilityData.Attribute` enum extended with `PHYSICAL_ARMOR_MOD = 6` and `MAGIC_ARMOR_MOD = 7`. `AbilityLibrary._ATTRIBUTE` lookup gained matching string keys. `CombatantData` gained two transient (NOT serialized) `int` fields — `physical_armor_mod` + `magic_armor_mod` — both default 0. `physical_defense` / `magic_defense` formulas extended with the mod field as the sixth source. `CombatManager3D._apply_stat_delta` gained the two new cases (clamp `[-10, 10]`); `STAT_STATUS_NAMES` + `STAT_ABBREV` extended (`P.Hardened`/`P.Cracked`/`P.ARM`, `M.Warded`/`M.Exposed`/`M.ARM`); `_attr_snapshots` build sites in both `_setup_units()` and `_setup_test_room_units()` record the mod fields; `_end_combat()` restores them via `snap.get(..., 0)`. `stone_guard` and `divine_ward` CSV rows updated from the dead `"ARMOR_DEFENSE"` `target_stat` to `"PHYSICAL_ARMOR_MOD"` / `"MAGIC_ARMOR_MOD"` — both abilities now mechanically active. 11 new tests (`test_armor_mod.gd`); all prior 92 tests still pass. |
| 2026-04-27 | AbilityData, CombatantData, ArchetypeData, CombatManager3D, AbilityLibrary, ArchetypeLibrary, GameState, MapManager, PartySheet, StatPanel, CharacterCreationManager, 5 CSVs, tests | **Dual Armor + Test Room.** `armor_defense` field + `defense` property removed from `CombatantData`; replaced by `physical_armor: int` + `magic_armor: int` fields and `physical_defense` + `magic_defense` computed properties, each summing 5 bonus sources. All CSV armor stat keys renamed `armor_defense` → `physical_armor` (feats, kindreds, equipment). `archetypes.csv` `armor_range` column split into `physical_armor_range` + `magic_armor_range` with per-archetype design flavor (grunt physical, alchemist magic). `AbilityData` gained `DamageType` enum + `damage_type` field; all 42 abilities tagged in CSV. `AbilityLibrary` gained `_DAMAGE_TYPE` lookup. `CombatManager3D._run_harm_defenders()` extended with 5th `ability: AbilityData` param; HARM formula now subtracts matching defense post-QTE. `GameState`: serialization writes `physical_armor`/`magic_armor`; deserializer migrates old `armor_defense` to both lanes; `test_room_mode: bool` transient flag added. `MapManager` dev panel gained COMBAT section with "⚔ Test Room" button; sets `test_room_mode` and transitions to combat. `CombatManager3D` test room path: `_setup_test_room_units()` + `_make_test_combatant()`; `_end_combat()` test room branch skips all save/XP/rewards. `_on_unit_died()` guarded against test room. UI: PartySheet derives P.Def+M.Def; StatPanel shows both. 11 new tests (`test_dual_armor.gd`); 92 total passing. |
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
