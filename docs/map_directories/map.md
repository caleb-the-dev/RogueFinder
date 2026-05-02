# RogueFinder — System Map

> High-level index of all game systems. Read this first each session, then navigate to the relevant bucket file.

---

## Map Metadata

| Field | Value |
|---|---|
| last_updated | 2026-05-02 (Combat Pivot Slice 1 — spd attribute added) |
| last_groomed | 2026-04-29 |
| sessions_since_groom | 10 |
| groom_trigger | 10 |

> **Grooming rule:** When `sessions_since_groom` reaches `groom_trigger`, run the `map-audit` skill:
> remove entries for deleted files, update descriptions that no longer match the code,
> prune stale "not here" notes, verify bucket file accuracy. Reset `sessions_since_groom` to 0.

---

## System Index

| System | Bucket File | Status | Layer |
|--------|------------|--------|-------|
| [Economy — Gold / Pricing / Vendors](economy.md) | `economy.md` | ✅ Active (RewardGenerator.gold_drop() · PricingFormula.price_for() · VendorLibrary 7 seed vendors · StockGenerator.roll_stock() · GameState.vendor_stocks save/load · gold_change event effect · has_gold condition · full vendor loop live) | Data |
| [UI Overlays — VendorOverlay](ui.md) | `ui.md` | ✅ Active (VendorOverlay layer 20 — show_vendor / try_buy; wired to map VENDOR nodes + all 4 Badurga stalls; blocks_pause group) | Presentation |
| [Enemy AI](enemy_ai.md) | `enemy_ai.md` | 🔧 In Progress (Slices 1–3 done — Role data layer + role preference walk + within-bucket scoring (HARM/MEND/BUFF/DEBUFF); FORCE disabled pending Slice 4 multi-step planner; move priority sort live; buff/debuff tracker fields on Unit3D) | Core |
| [Combat Manager](combat_manager.md) | `combat_manager.md` | ✅ Active (3D) + Legacy (2D) | Core |
| [Grid System](grid_system.md) | `grid_system.md` | ✅ Active (3D) + Legacy (2D) | Core |
| [Unit System](unit_system.md) | `unit_system.md` | ✅ Active (3D) + Legacy (2D) | Core |
| [QTE System — QTEBar + RecruitBar](qte_system.md) | `qte_system.md` | ✅ Active (QTEBar: Slide dodge; RecruitBar: hold-and-release capture) | Core |
| [Camera System](camera_system.md) | `camera_system.md` | ✅ Active (3D only) | Presentation |
| [HUD System / StatPanel / UnitInfoBar / CombatActionPanel / EndCombatScreen / RewardGenerator / PricingFormula](hud_system.md) | `hud_system.md` | ✅ Active (combat HUD stack; EndCombatScreen shows gold line on victory; RewardGenerator.gold_drop() + PricingFormula.price_for() live) · ⚠️ Legacy HUD.gd kept for 2D | Presentation |
| [Combatant Data Model + ArchetypeLibrary](combatant_data.md) | `combatant_data.md` | ✅ Active (ArchetypeLibrary CSV-sourced S34; speed = 1 + kindred_bonus only — dex severed; no attack stat — effective_stat() drives HARM; **spd: int = 4** added as 6th core attribute — kindred SPD bonuses live, persisted, shown in PartySheet/StatPanel/CharacterCreation) | Data |
| [Ability System (AbilityData / EffectData / AbilityLibrary)](ability_system.md) | `ability_system.md` | ✅ Active (63 abilities — 22 base + 8 kindred natural attacks + 14 ancestry + 4 class definings + 6 class pool + 6 weapon + 3 armor upgrades; upgraded_id live on weapon + armor base abilities) | Data |
| [Equipment & Consumables](equipment_system.md) | `equipment_system.md` | ✅ Active (36 equipment items: 12 tiered weapons + 12 tiered armor + 12 tiered accessories (3 STR/COG/VIT families × 4 rarities); 11 consumables; on_equip/on_unequip pool lifecycle live; accessory feat_id applied at read-time via get_feat_stat_bonus()) | Data |
| [Background System](background_system.md) | `background_system.md` | ✅ Active (6 backgrounds; owns feat lane; +1 single stat per background) | Data |
| [Class Library](class_system.md) | `class_system.md` | ✅ Active (4 classes; 4 total stat points, max +2 per stat; 13-ability pool, 10-feat pool; wired into CombatantData) | Data |
| [Temperament System](combatant_data.md) | `combatant_data.md` | ✅ Active (21 temperaments; +1 boosted / -1 hindered / Even neutral; randomly assigned at creation; hidden until post-creation) | Data |
| [Portrait Library](portrait_system.md) | `portrait_system.md` | ✅ Active (dormant — 6 placeholder portraits, CSV-sourced, S30) | Data |
| [Kindred Library](combatant_data.md) | `combatant_data.md` | ✅ Active (8 kindreds — Human/Half-Orc/Gnome/Dwarf/Skeleton/Giant Rat/Spider/Dragon; owns ability lane; no longer grants feats; **spd bonus values live** in stat_bonuses: Spider +3, Rat +2, Half-Orc/Dwarf/Skeleton −1, others 0) | Data |
| [Main Menu + Character Creation](character_creation.md) | `character_creation.md` | ✅ Active (deterministic stats; slot 0 = class ability, slot 1 = kindred ability; bg feat seeds feat_ids; **SPD preview label live**; 12 tests) | Presentation |
| [Unit Data Resource](unit_data.md) | `unit_data.md` | ⚠️ Legacy (2D only) | Data |
| [Game State](game_state.md) | `game_state.md` | ✅ Active (map traversal + save/load + party + bench + inventory + gold + XP/level-up; `current_combat_ring` transient field) | Global |
| [Map Scene](map_scene.md) | `map_scene.md` | ✅ Active (traversable + save/load) | World Map |
| [Party Sheet](party_sheet.md) | `party_sheet.md` | ✅ Active (interactive overlay layer 20; level-up pick overlay layer 25; ESC backs out of overlay without consuming pick; ability auto-slot on level-up pick; new-ability gold glow cleared on hover; 5-col derived stats (no ATK); **6-col base attributes (STR/DEX/COG/WIL/VIT/SPD)**; attribute green/red coloring; accessory feat in Feats tab; tab state persists across equip) | Presentation |
| [Event System](event_system.md) | `event_system.md` | ✅ Active — data + selector + overlay + dispatch + player_pick picker + 18 events (3 smoke + 15 authored) + recruit_follower + gold_change + has_gold effects (Slices 1/3/4/5/6/7) | Data / World Map |
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
  ├── GameState             (load_save/init_party at startup; travel + entry increments; sets current_combat_node_id / current_combat_ring; save() after post-tween dispatch; vendor_stocks populated by _generate_vendor_stocks())
  ├── VendorLibrary         (_generate_vendor_stocks — vendors_by_scope("CITY") + vendors_by_scope("WORLD"))
  ├── StockGenerator        (_generate_vendor_stocks — roll_stock() per vendor/node)
  ├── VendorOverlay         (instantiated fresh on VENDOR node entry; closed signal marks node cleared + saves; _vendor_overlay ref)
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
  ├── VendorOverlay         (instantiated by _open_vendor_stall() for each of 4 vendor stall buttons; self-managed lifecycle)
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
  ├── BackgroundLibrary     (sample_feat_candidates)
  ├── VendorLibrary         (regen_world_vendor_stocks — vendors_by_scope("WORLD"))
  └── StockGenerator        (regen_world_vendor_stocks — roll_stock())

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
│   │   ├── EnemyAI.gd                  ← static module; choose_action() + role picker; no instance state
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
│   │   ├── PricingFormula.gd            ← static price_for(item, rng) helper; rarity→base×jitter; caller-supplied RNG
│   │   ├── RewardGenerator.gd          ← shuffled reward pool + gold_drop(ring, threat, avg_level) formula; public eq_to_dict/con_to_dict
│   │   ├── StockGenerator.gd           ← static roll_stock(vendor, seed_int) → Array[{vendor_id,item,price,sold}]; seeded Fisher-Yates; category filter
│   │   ├── VendorLibrary.gd            ← CSV-sourced (res://data/vendors.csv); 7 vendors; vendors_by_scope() helper
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
│       ├── VendorOverlay.gd            ← modal shop overlay (layer 20); show_vendor/try_buy; Slice 6 wires entry points
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
│   ├── VendorData.gd                   ← one vendor (vendor_id, display_name, flavor, category_pool, stock_count, scope)
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
│   ├── vendors.csv                     ← 7 vendors (4 CITY + 3 WORLD); category_pool pipe-separated; read via res://data/
│   └── portraits.csv                   ← 6 placeholder portraits; read via res://data/
├── scenes/
│   ├── ui/VendorOverlay.tscn           ← minimal (CanvasLayer root + VendorOverlay script)
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
└── tests/                              ← 54 test scripts + 40 scene runners. **test_spd_attribute.gd/.tscn** added 2026-05-02 (5 assertions — spd default=4, spd serializes, kindred spd bonus applied in effective_stat, KindredLibrary returns correct spd per kindred, save-dict round-trip). **test_enemy_ai_scoring.gd/.tscn** added 2026-05-01 (13 assertions — AoE-2+ preference, AoE skip, finishing-blow target, best-damage tiebreak, MEND closest-fit, BUFF redundancy skip, DEBUFF redundancy skip, DEBUFF stack cap, FORCE-disabled null, FORCE not-useful drops to HARM, expected-damage accuracy, HEALER stride toward low-HP ally, ATTACKER stride ignores ally). **test_enemy_ai_2.gd/.tscn** added 2026-05-01 (9 assertions — all role preferences, critical-heal threshold, ai_override seam, null fallback). **test_vendor_buy.gd/.tscn** added 2026-04-30 (6 assertions — gold debit, rarity preserved, sold-flag flip, insufficient-gold rejection, already-sold rejection, save round-trip). **test_vendor_stock.gd/.tscn** added 2026-04-30 (7 assertions — determinism, seed variance, category filter, mixed pool coverage, stock count, sold-flag JSON round-trip, regen WORLD-only). **test_vendor_wireup.gd/.tscn** added 2026-04-30 (5 assertions — gold_change debit, gold_change clamp at 0, has_gold at/above/below threshold). **test_consumables.gd** updated 2026-04-29 (Slice 6): 5 new item assertions (steel_tonic/quicksilver_draught/clarity_brew/iron_word/heartroot_tonic — each checks BUFF, base_value==1, correct target_stat) + total count assertion (11). **test_accessory_feat.gd/.tscn** added 2026-04-29 (5 assertions — Rare accessory adds feat stat bonus, unequip removes, dedup with feat_ids, COMMON no bonus, 36-item count). **test_armor_equip.gd/.tscn** updated for 36-item count. **test_rarity.gd** updated: armor_accessory_all_common now checks all 4 tiers exist (not COMMON-only); granted_ability_ids check narrowed to accessories only; feat_id check verifies COMMON=empty/Rare+=non-empty. **test_equipment.gd** updated: old padded_armor/rough_hide/cloth_robe tests replaced with iron_plate/ring_of_valor_epic/mystic_robe; count updated to 36. **test_armor_equip.gd/.tscn** (7); **test_weapon_equip.gd/.tscn** (7 — on_equip adds to pool, dedup, on_unequip removes, slot preserves on unequip, CSV parse iron_sword, multiple ids round-trip, armor noop). **test_upgraded_ability.gd/.tscn** (6 — upgraded_id default, stub on no-upgrade, round-trip, CSV no upgrade, ability count, never-null). Note: test asserts 60 rows — needs update to 63. test_rarity.gd/.tscn (13); test_pause_menu.gd/.tscn (12); test_hire_roster.gd/.tscn (6); test_recruit_success.gd/.tscn (11); test_recruit_math.gd/.tscn (13); test_armor_mod.gd/.tscn (11); see `tests/test_combatant_data.tscn` for the runner pattern; test_camera_controls.gd (6, extends SceneTree). All `extends Node` tests require a .tscn runner and are invoked with `--headless --path rogue-finder <test>.tscn`; `extends SceneTree` tests use `--script`.
```

---

## Recent Milestones

Last 3 merged milestones. For full history, see `git log main`; for per-system history, see the `## Recent Changes` table in each bucket file.

| Date | Area | Note |
|---|---|---|
| 2026-05-02 | CombatantData, KindredLibrary (kindreds.csv), GameState, PartySheet, StatPanel, CharacterCreationManager | **Combat Pivot Slice 1 — SPD attribute foundation.** `CombatantData.spd: int = 4` added as the 6th core attribute (`@export_range(1,10)`). `effective_stat("spd")` handles the full 7-source stack. `kindreds.csv` `stat_bonuses` extended with `spd:X` for all 8 kindreds (Spider +3, Giant Rat +2, Human/Gnome/Dragon 0, Half-Orc/Dwarf/Skeleton −1). `GameState._serialize_combatant()` writes `spd`; `_deserialize_combatant()` reads it with old-save default 4. **PartySheet:** `attr_defs` expanded from 5 to 6 cols (SPD added, uses same green/red item-bonus coloring). **StatPanel:** SPD appended to WIL/VIT line. **CharacterCreationManager:** `_preview_spd_lbl` label added; `_calc_preview()` computes and pushes SPD. **5 headless tests** (`test_spd_attribute.gd`) — all pass. Old combat system unaffected (spd unused there). |
| 2026-05-02 | PartySheet, CombatantData, abilities.csv, feats.csv, equipment.csv, consumables.csv | **UX Polish — ESC level-up, auto-slot, ability glow, functional descriptions.** `PartySheet._level_up_overlay: CanvasLayer` tracks the active pick overlay; added to `"blocks_pause"` group on creation. `_unhandled_input()` two-stage ESC: if overlay is open, frees it without consuming the pick (`pending_level_ups` stays, "Level Up!" button reappears); otherwise closes the sheet. Ability pick on-pick lambda now: (1) appends to `ability_pool`, (2) fills first empty `abilities` slot if any, (3) appends to `new_ability_ids`. `PartySheet._build_ability_pool_tabs()` renders gold all-sides border + alpha pulse for abilities in `new_ability_ids`; `mouse_entered` erases the id and rebuilds. `CombatantData.new_ability_ids: Array[String] = []` added (transient, not serialized — mirrors item `seen` pattern). All four data CSVs rewritten: descriptions are now strictly functional (abilities state damage type/value/range/effects; feats state "+X stat."; equipment states what is granted; consumables state buff type/value). No mechanical values changed. |
| 2026-05-01 | EnemyAI, CombatManager3D, Unit3D, MapManager | **Enemy AI Slice 3 — within-bucket scoring + move priority + FORCE disabled.** `_try_effect_type()` now dispatches to per-type scorers: HARM (AoE-2+→finishing-blow→best-damage), MEND (lowest-HP closest-fit), BUFF (highest-HP non-redundant), DEBUFF (highest-HP non-capped, 3-stack cap). FORCE case returns null — disabled pending Slice 4 multi-step positioning planner. `EnemyAI.MOVE_PRIORITY` const drives turn-order sort in CM3D (HEALER→SUPPORTER→DEBUFFER→ATTACKER→CONTROLLER). `pick_stride_target()` replaces random-hostile stride heuristic; HEALERs/SUPPORTERs stride toward low-HP allies. Three new transient fields on `Unit3D`: `active_buff_ability_ids`, `active_debuff_ability_ids`, `debuff_stat_stacks` — all cleared at `_end_combat()`. Geometry statics extracted from CM3D into EnemyAI (`_get_shape_cells_static`, `_cardinal_direction_static`, etc.); CM3D wraps them. `_spawn_test_room()` p_pos/e_pos params changed to `Array = []` + `.assign()` (Godot 4.5 typed-array default param fix). 6 new dev test rooms (AI SLICE 3 SCORING). 13 new headless tests (`test_enemy_ai_scoring.gd`). 22 tests total across EnemyAI suites — all pass. |
| 2026-05-01 | EnemyAI, CombatManager3D, Unit3D, MapManager | **Enemy AI Slice 2 — role-driven picker.** `EnemyAI.gd` new static module: `choose_action(enemy, allies, hostiles, grid)` — decision flow: ai_override seam → critical-heal override (15% HP) → role preference walk (ROLE_PREFERENCES table per role) → null fallback. `_try_effect_type()` two-pass walk: fresh abilities first, last-used as fallback (prevents spam). `_is_situationally_useful()` per effect type (Slice 2 minimum-viable filters). `_pick_target()` respects applicable_to + effect type context for ANY. Critical-heal override: lowest-HP ally below 15% gets MEND regardless of role preference. `Unit3D` gains `ai_override: String` (Confused seam, dormant) and `last_ability_id: String` (cycling tracker — not cleared in `reset_turn()`). `CombatManager3D._process_enemy_actions()` wired: randi() picks → `EnemyAI.choose_action()`; `last_ability_id` set post-pick; `_player_units_alive()` + `_enemy_units_alive_excluding()` helpers added. Dev panel: 🤖 AI Roles + 🤖 AI Crit-Heal test rooms added. Known limitation: movement step fires before EnemyAI → HEALER walks away from dying ally; fix is Slice 3 role-aware stride. 9 headless tests. |
| 2026-04-30 | MapManager, BadurgaManager, EventManager, PartySheet, PauseMenuManager, VendorOverlay | **Vendor Slice 6 + UI Polish.** Full vendor loop live: `MapManager._enter_current_node()` VENDOR branch instantiates `VendorOverlay`, marks node cleared on close. `_generate_vendor_stocks()` changed to additive (fills missing entries only — fixes old-save migration). `BadurgaManager` 2-column layout (Party Management large left, Hire Roster medium left, 4 vendor stalls right, Tavern/Bulletin coming-soon stubs). `BadurgaManager._open_vendor_stall(vendor_id)` wires all 4 stall buttons. ESC-as-back-button pattern: `PartySheet`, `VendorOverlay`, `EventManager` all join `"blocks_pause"` group; `PauseMenuManager._is_overlay_blocking()` hides ☰ and skips ESC while any member is visible; `PartySheet._unhandled_input` closes sheet on ESC; `BadurgaManager._unhandled_input` closes overlays on ESC. `PartySheet` header gains "GP: X" gold readout. `EventManager.dispatch_effect` gains `gold_change`; `evaluate_condition` gains `has_gold:N`. `road_deal` smoke event (events.csv/event_choices.csv). Dev "🛒 Vendor Test" button removed. 5 headless tests (`test_vendor_wireup`). |
| 2026-04-30 | VendorOverlay, MapManager (dev button) | **Vendor Slice 5 — Vendor Overlay UI.** `VendorOverlay.gd` + `VendorOverlay.tscn` (CanvasLayer layer 20). `show_vendor(instance_key)` pulls `GameState.vendor_stocks[key]`. `try_buy(entry)` static method: validates gold ≥ price and not sold; debits gold, flips sold, adds to inventory with `.duplicate()`, saves. Scrollable stock rows: rarity-colored name · stat summary (`_format_stats` + `_stat_abbr`) · gold price · Buy/SOLD. Gold readout and row states rebuild after each purchase. ESC closes. Dev "🛒 Vendor Test" button in MapManager `inv_row` opens `"vendor_weapon"` stock for end-to-end testing. `ui.md` bucket file created. 6 headless tests (`test_vendor_buy.gd/.tscn`). |
| 2026-04-30 | StockGenerator, GameState.vendor_stocks, MapManager | **Vendor Slice 4 — Stock Manifest + Persistence.** `StockGenerator.gd` (new) — `roll_stock(vendor, seed_int)` returns `Array[{vendor_id, item, price, sold}]`; seeded Fisher-Yates; category filter by `EquipmentData.Slot.keys()[slot].to_lower()`; `PricingFormula.price_for()` per entry. `RewardGenerator._eq_to_dict/_con_to_dict` → public `eq_to_dict/con_to_dict`. `GameState.vendor_stocks: Dictionary = {}` — CITY keyed by vendor_id, WORLD keyed by node_id; wired into `save()`/`load_save()`/`reset()`; `regen_world_vendor_stocks()` added (WORLD-only regen, future boss-cycle trigger). `MapManager._generate_vendor_stocks()` called after `_assign_boss_type()` in `_ready()`; no-op if already populated (loaded save); handles old-save migration. Seed formula: CITY `hash(str(map_seed)+"::"+vendor_id)`; WORLD pick `posmod(hash(str(map_seed)+node_id), count)`; WORLD seed `hash(str(map_seed)+"::"+node_id)`. 7 headless tests. Fixed 6 pre-existing GDScript warnings (RewardGenerator, MapManager, BenchSwapPanel, PartySheet). |
| 2026-04-30 | VendorData, VendorLibrary, vendors.csv | **Vendor Slice 3 — VendorLibrary Data Set.** `VendorData.gd` resource (`vendor_id`, `display_name`, `flavor`, `category_pool: Array[String]`, `stock_count: int`, `scope: String`). `vendors.csv` — 7 seed rows (4 CITY, 3 WORLD). `VendorLibrary.gd` — BackgroundLibrary shape; `get_vendor()` never-null stub; `all_vendors()`; `vendors_by_scope(scope)` for Slice 4; `reload()`. `economy.md` bucket file created; `map.md` updated. 17 headless tests (`test_vendor_library.gd/.tscn`). |
| 2026-04-29 | RewardGenerator, GameState, MapManager, CombatManager3D, EndCombatScreen | **Vendor Slice 1 — Currency Reward Channel.** `RewardGenerator.gold_drop(ring, threat, party_avg_level)` added: formula is `(RING_BASE[ring] + 0.15 * threat + 3.0 * avg_level) * randf_range(0.9, 1.1)`, clamped to ≥ 1. RING_BASE: outer 30, middle 20, inner 12. `GameState.current_combat_ring: String = ""` added as a transient (NOT serialized) field. `MapManager._enter_current_node()` now sets `current_combat_ring` alongside `current_combat_node_id` using existing `_get_ring()`. `CombatManager3D._calc_gold_reward()` computes ring-scaled gold, adds to `GameState.gold` before saving, and passes amount to `EndCombatScreen.show_victory(items, gold)`. `EndCombatScreen.show_victory()` signature extended with `gold_amount: int = 0`; displays `"+X Gold (Total: Y)"` line in Color(0.90, 0.80, 0.30) above item cards. 7 headless tests added (`test_gold_reward.gd/.tscn`). |
| 2026-04-29 | CombatantData, CombatManager3D, PartySheet, StatPanel, GAME_BIBLE | **ATK stat removed.** `CombatantData.attack` computed property deleted — there is no separate attack stat. New method `effective_stat(stat: String) -> int` returns raw attribute + all bonus sources (equip/feat/class/kindred/bg/temp). HARM formula in `_run_harm_defenders` changed from `base_value + caster.data.attack` to `base_value + _get_attribute_value(caster, ability.attribute)`, where `_get_attribute_value` now calls `effective_stat()` for each attribute. A STR-based ability scales with effective STR; COG-based with effective COG; etc. PartySheet derived stats row drops from 6 to 5 cols (Atk removed). StatPanel drops the Attack derived stat line. GAME_BIBLE attack resolution section and damage formula updated to match. |
| 2026-04-29 | consumables.csv, tests/test_consumables.gd | **Consumable Pool Expansion (Slice 6).** 5 new BUFF +1 consumables added to `consumables.csv`: `steel_tonic` (STR), `quicksilver_draught` (DEX), `clarity_brew` (COG), `iron_word` (WIL), `heartroot_tonic` (VIT). Total: 11 consumables. Pure CSV — no GDScript changes. `test_consumables.gd` gained 6 new assertions (5 item tests + count == 11). All 13 tests pass. |
| 2026-04-29 | equipment.csv, CombatantData, PartySheet, tests | **Accessory Tier Families (Slice 5) + PartySheet equipment UI overhaul.** 3 COMMON placeholder accessories replaced by 12 tiered entries across 3 families × 4 rarities. Tier ladder: Common=X:1 · Rare=X:1+feat · Epic=X:1,Y:1+feat · Legendary=X:1,Y:1,Z:2+feat. Families: Ring of Valor (STR/VIT/WIL, feat=`combat_training`), Scholar's Amulet (COG/WIL/VIT, feat=`analytical_mind`), Iron Bracers (VIT/STR/DEX, feat=`hearty_constitution`). `get_feat_stat_bonus()` reads `accessory.feat_id` at compute-time with dedup. `CombatantData.get_equip_bonus()` added as public wrapper. PartySheet: (1) equipment tooltips now show `[Ability] <name>` and `[Feat] <name> (<stat>)` lines; (2) derived stat row expanded from 4 to 6 cols (added Atk + Regen); (3) attribute values show effective total (base+item_bonus) colored green/red when items modify them; (4) accessory feat appears in Feats tab as purple-bordered card; (5) `_active_tab_indices[3]` preserves per-member tab across equip/rebuild. `test_accessory_feat.gd` added (5 assertions); `test_rarity.gd` + `test_equipment.gd` + `test_armor_equip.gd` updated. Totals: 66 abilities, 36 equipment items. |
