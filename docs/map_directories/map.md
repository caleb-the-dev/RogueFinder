# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-04-29 (Vendor Slice 1 — auto-collect gold on combat victory; RewardGenerator.gold_drop(); EndCombatScreen gold line) |
| last_groomed | 2026-04-29 |
| sessions_since_groom | 1 |
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
| [HUD System / StatPanel / UnitInfoBar / CombatActionPanel / EndCombatScreen / RewardGenerator](hud_system.md) | `hud_system.md` | ✅ Active (combat HUD stack; EndCombatScreen shows gold line on victory; RewardGenerator.gold_drop() live) · ⚠️ Legacy HUD.gd kept for 2D | Presentation |
| [Combatant Data Model + ArchetypeLibrary](combatant_data.md) | `combatant_data.md` | ✅ Active (ArchetypeLibrary CSV-sourced S34; speed = 1 + kindred_bonus only — dex severed; no attack stat — effective_stat() drives HARM) | Data |
| [Ability System (AbilityData / EffectData / AbilityLibrary)](ability_system.md) | `ability_system.md` | ✅ Active (63 abilities — 22 base + 8 kindred natural attacks + 14 ancestry + 4 class definings + 6 class pool + 6 weapon + 3 armor upgrades; upgraded_id live on weapon + armor base abilities) | Data |
| [Equipment & Consumables](equipment_system.md) | `equipment_system.md` | ✅ Active (36 equipment items: 12 tiered weapons + 12 tiered armor + 12 tiered accessories (3 STR/COG/VIT families × 4 rarities); 11 consumables; on_equip/on_unequip pool lifecycle live; accessory feat_id applied at read-time via get_feat_stat_bonus()) | Data |
| [Background System](background_system.md) | `background_system.md` | ✅ Active (6 backgrounds; owns feat lane; +1 single stat per background) | Data |
| [Class Library](class_system.md) | `class_system.md` | ✅ Active (4 classes; 4 total stat points, max +2 per stat; 13-ability pool, 10-feat pool; wired into CombatantData) | Data |
| [Temperament System](combatant_data.md) | `combatant_data.md` | ✅ Active (21 temperaments; +1 boosted / -1 hindered / Even neutral; randomly assigned at creation; hidden until post-creation) | Data |
| [Portrait Library](portrait_system.md) | `portrait_system.md` | ✅ Active (dormant — 6 placeholder portraits, CSV-sourced, S30) | Data |
| [Kindred Library](combatant_data.md) | `combatant_data.md` | ✅ Active (8 kindreds — Human/Half-Orc/Gnome/Dwarf/Skeleton/Giant Rat/Spider/Dragon; owns ability lane; no longer grants feats) | Data |
| [Main Menu + Character Creation](character_creation.md) | `character_creation.md` | ✅ Active (deterministic stats; slot 0 = class ability, slot 1 = kindred ability; bg feat seeds feat_ids; 12 tests) | Presentation |
| [Unit Data Resource](unit_data.md) | `unit_data.md` | ⚠️ Legacy (2D only) | Data |
| [Game State](game_state.md) | `game_state.md` | ✅ Active (map traversal + save/load + party + bench + inventory + gold + XP/level-up; `current_combat_ring` transient field) | Global |
| [Map Scene](map_scene.md) | `map_scene.md` | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](party_sheet.md) | `party_sheet.md` | ✅ Active (interactive overlay layer 20; level-up pick overlay layer 25; 5-col derived stats (no ATK — removed); attribute green/red coloring from items; accessory feat in Feats tab; tooltips show feat+ability; tab state persists across equip) | Presentation |
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
  ├── GameState             (load_save/init_party at startup; travel + entry increments; sets pending_node_type / current_combat_node_id / current_combat_ring; save() after post-tween dispatch)
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
│   │   ├── AbilityLibrary.gd           ← CSV-sourced (res://data/abilities.csv); 63 abilities (22 base + 8 kindred natural attacks + 14 ancestry + 4 class definings + 6 class pool + 6 weapon + 3 armor upgrades)
│   │   ├── ArchetypeLibrary.gd         ← CSV-sourced (res://data/archetypes.csv); 9 archetypes (RogueFinder + 4 original + 4 new kindred templates)
│   │   ├── BackgroundLibrary.gd        ← CSV-sourced (res://data/backgrounds.csv)
│   │   ├── ClassLibrary.gd             ← CSV-sourced (res://data/classes.csv); 4 classes
│   │   ├── ConsumableLibrary.gd        ← CSV-sourced (res://data/consumables.csv); 11 consumables
│   │   ├── EquipmentLibrary.gd         ← CSV-sourced (res://data/equipment.csv); 36 items (12 tiered weapons + 12 tiered armor + 12 tiered accessories); on_equip/on_unequip pool lifecycle
│   │   ├── EventLibrary.gd             ← CSV-sourced (events.csv + event_choices.csv); 17 events (3 smoke + 14 authored)
│   │   ├── EventSelector.gd            ← static picker; ring filter + exhaustion fallback; appends to GameState.used_event_ids
│   │   ├── FeatLibrary.gd              ← CSV-sourced (res://data/feats.csv); 38 feats (20 class, 18 background); parses stat_bonuses
│   │   ├── KindredLibrary.gd           ← CSV-sourced (res://data/kindreds.csv); 8 kindreds (4 humanoid + 4 non-humanoid)
│   │   ├── PortraitLibrary.gd          ← CSV-sourced (res://data/portraits.csv); 6 placeholder portraits
│   │   └── TemperamentLibrary.gd       ← CSV-sourced (res://data/temperaments.csv); 21 temperaments (20 + Even neutral); random_id(rng) helper
│   │   ├── RewardGenerator.gd          ← shuffled reward pool + gold_drop(ring, threat, avg_level) formula
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
│   ├── abilities.csv                   ← 63 abilities; effects as JSON arrays; upgraded_id live on weapon + armor base rows; read via res://data/
│   ├── archetypes.csv                  ← 9 archetypes; read via res://data/
│   ├── backgrounds.csv                 ← 6 backgrounds; read via res://data/
│   ├── classes.csv                     ← 4 classes; read via res://data/
│   ├── consumables.csv                 ← 11 consumables; read via res://data/
│   ├── equipment.csv                   ← 36 items: 12 tiered weapons (3 STR/DEX/COG × 4 rarities) + 12 tiered armor (Iron Plate/Scale Mail/Mystic Robe × 4 rarities) + 12 tiered accessories (Ring of Valor/Scholar's Amulet/Iron Bracers × 4 rarities)
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
└── tests/                              ← 45 test scripts + 32 scene runners. **test_consumables.gd** updated 2026-04-29 (Slice 6): 5 new item assertions (steel_tonic/quicksilver_draught/clarity_brew/iron_word/heartroot_tonic — each checks BUFF, base_value==1, correct target_stat) + total count assertion (11). **test_accessory_feat.gd/.tscn** added 2026-04-29 (5 assertions — Rare accessory adds feat stat bonus, unequip removes, dedup with feat_ids, COMMON no bonus, 36-item count). **test_armor_equip.gd/.tscn** updated for 36-item count. **test_rarity.gd** updated: armor_accessory_all_common now checks all 4 tiers exist (not COMMON-only); granted_ability_ids check narrowed to accessories only; feat_id check verifies COMMON=empty/Rare+=non-empty. **test_equipment.gd** updated: old padded_armor/rough_hide/cloth_robe tests replaced with iron_plate/ring_of_valor_epic/mystic_robe; count updated to 36. **test_armor_equip.gd/.tscn** (7); **test_weapon_equip.gd/.tscn** (7 — on_equip adds to pool, dedup, on_unequip removes, slot preserves on unequip, CSV parse iron_sword, multiple ids round-trip, armor noop). **test_upgraded_ability.gd/.tscn** (6 — upgraded_id default, stub on no-upgrade, round-trip, CSV no upgrade, ability count, never-null). Note: test asserts 60 rows — needs update to 63. test_rarity.gd/.tscn (13); test_pause_menu.gd/.tscn (12); test_hire_roster.gd/.tscn (6); test_recruit_success.gd/.tscn (11); test_recruit_math.gd/.tscn (13); test_armor_mod.gd/.tscn (11); see `tests/test_combatant_data.tscn` for the runner pattern; test_camera_controls.gd (6, extends SceneTree). All `extends Node` tests require a .tscn runner and are invoked with `--headless --path rogue-finder <test>.tscn`; `extends SceneTree` tests use `--script`.
```

---

## Recent Milestones

Last 3 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-04-29 | RewardGenerator, GameState, MapManager, CombatManager3D, EndCombatScreen | **Vendor Slice 1 — Currency Reward Channel.** `RewardGenerator.gold_drop(ring, threat, party_avg_level)` added: formula is `(RING_BASE[ring] + 0.15 * threat + 3.0 * avg_level) * randf_range(0.9, 1.1)`, clamped to ≥ 1. RING_BASE: outer 30, middle 20, inner 12. `GameState.current_combat_ring: String = ""` added as a transient (NOT serialized) field. `MapManager._enter_current_node()` now sets `current_combat_ring` alongside `current_combat_node_id` using existing `_get_ring()`. `CombatManager3D._calc_gold_reward()` computes ring-scaled gold, adds to `GameState.gold` before saving, and passes amount to `EndCombatScreen.show_victory(items, gold)`. `EndCombatScreen.show_victory()` signature extended with `gold_amount: int = 0`; displays `"+X Gold (Total: Y)"` line in Color(0.90, 0.80, 0.30) above item cards. 7 headless tests added (`test_gold_reward.gd/.tscn`). |
| 2026-04-29 | CombatantData, CombatManager3D, PartySheet, StatPanel, GAME_BIBLE | **ATK stat removed.** `CombatantData.attack` computed property deleted — there is no separate attack stat. New method `effective_stat(stat: String) -> int` returns raw attribute + all bonus sources (equip/feat/class/kindred/bg/temp). HARM formula in `_run_harm_defenders` changed from `base_value + caster.data.attack` to `base_value + _get_attribute_value(caster, ability.attribute)`, where `_get_attribute_value` now calls `effective_stat()` for each attribute. A STR-based ability scales with effective STR; COG-based with effective COG; etc. PartySheet derived stats row drops from 6 to 5 cols (Atk removed). StatPanel drops the Attack derived stat line. GAME_BIBLE attack resolution section and damage formula updated to match. |
| 2026-04-29 | consumables.csv, tests/test_consumables.gd | **Consumable Pool Expansion (Slice 6).** 5 new BUFF +1 consumables added to `consumables.csv`: `steel_tonic` (STR), `quicksilver_draught` (DEX), `clarity_brew` (COG), `iron_word` (WIL), `heartroot_tonic` (VIT). Total: 11 consumables. Pure CSV — no GDScript changes. `test_consumables.gd` gained 6 new assertions (5 item tests + count == 11). All 13 tests pass. |
| 2026-04-29 | equipment.csv, CombatantData, PartySheet, tests | **Accessory Tier Families (Slice 5) + PartySheet equipment UI overhaul.** 3 COMMON placeholder accessories replaced by 12 tiered entries across 3 families × 4 rarities. Tier ladder: Common=X:1 · Rare=X:1+feat · Epic=X:1,Y:1+feat · Legendary=X:1,Y:1,Z:2+feat. Families: Ring of Valor (STR/VIT/WIL, feat=`combat_training`), Scholar's Amulet (COG/WIL/VIT, feat=`analytical_mind`), Iron Bracers (VIT/STR/DEX, feat=`hearty_constitution`). `get_feat_stat_bonus()` reads `accessory.feat_id` at compute-time with dedup. `CombatantData.get_equip_bonus()` added as public wrapper. PartySheet: (1) equipment tooltips now show `[Ability] <name>` and `[Feat] <name> (<stat>)` lines; (2) derived stat row expanded from 4 to 6 cols (added Atk + Regen); (3) attribute values show effective total (base+item_bonus) colored green/red when items modify them; (4) accessory feat appears in Feats tab as purple-bordered card; (5) `_active_tab_indices[3]` preserves per-member tab across equip/rebuild. `test_accessory_feat.gd` added (5 assertions); `test_rarity.gd` + `test_equipment.gd` + `test_armor_equip.gd` updated. Totals: 66 abilities, 36 equipment items. |
