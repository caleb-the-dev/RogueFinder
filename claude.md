# RogueFinder — Claude Session Context

> Drop this file at the start of every session. GAME_BIBLE is the design authority; this file is the build authority.

---

## Project Identity

- **Game:** RogueFinder — tactical turn-based roguelite / creature collector
- **Engine:** Godot 4 (GDScript)
- **Repo:** https://github.com/caleb-the-dev/RogueFinder
- **Docs:** https://docs.godotengine.org/en/stable/
- **Solo dev** — one programmer, one artist (pixel art + learning Blender)
- **Project layout:** The actual Godot project lives in `rogue-finder/`. All `res://` paths resolve there. Scripts under `rogue-finder/scripts/`, scenes under `rogue-finder/scenes/`, resources under `rogue-finder/resources/`. The repo root holds this doc, the bible, and `docs/`.

---

## Current Build State

- **Stage:** Stage 1.5 — 3D combat prototype + traversable world map
- **Entry point:** `main.tscn` → MainMenuScene → (new run) CharacterCreationScene → MapScene | (continue) MapScene
- **Live systems:** 3D combat loop · traversable world map with 5 node types (COMBAT, VENDOR, EVENT, BOSS, CITY) + structured placement rules · save/load · reward system · Badurga city shell (Party Management + Hire Roster live; 6 other sections stub) · threat escalation counter + HUD bar · persistent party (HP/energy carry-over, ally permadeath, run-end summary screen) · party bag inventory (all reward items land in shared bag; equipment + consumables stored as raw dicts) · party sheet overlay (interactive 4-quadrant equip UI, layer 20, full ability pool swap with drag-compare) · CombatActionPanel (right slide-in, player + enemy view, tooltips) · **Kindreds** (owns ability lane — speed/HP bonuses + stat_bonuses + starting_ability_id + ability_pool; no feats; get_kindred_stat_bonus() wired into all 7 derived stats; 22 names per kindred) · **Backgrounds** (owns feat lane — starting_feat_id + 2-feat pool + stat_bonuses; each background gives exactly +1 to one stat; get_background_stat_bonus() wired into all 7 derived stats) · **Classes** (4 classes; each gives exactly 4 total stat points, max +2 per stat, no negatives; class ability_pool 13 per class; class feat_pool 10 per class) · **Temperaments** (21 Pokémon-style natures — 20 give +1 boosted/−1 hindered, 1 neutral "Even"; TemperamentLibrary + TemperamentData; CombatantData.temperament_id @export serialized; get_temperament_stat_bonus() wired into hp_max/energy_max/energy_regen/effective_stat() — i.e. ability damage (NOT speed — dex passthrough severed 2026-04-29; attack stat removed 2026-04-29); randomly assigned at creation, hidden from player pre-creation; displayed in StatPanel + PartySheet) · **MainMenuScene** (title screen; Continue grayed when no save exists; Start New Run goes to creation without mutating save; Test New Run dev shortcut with 3 random PCs) · **Character Creation** (B2 + B4 — slot-wheel dials for kindred/class/background/portrait; name field + 🎲; Back button; live preview panel showing deterministic HP + STR/DEX/COG/WIL/VIT + class ability + kindred ability + background feat; no stat rolling; _build_pc() builds CombatantData from picks; temperament assigned randomly post-picks; PC added to party on Begin Run) · **EventLibrary** (data layer — Slice 1; EventData + EventChoiceData resources; events.csv + event_choices.csv; 3 smoke events, 14 authored) · **EventSelector** (Slice 3; static pick_for_node(ring); unseen-first pool, exhaustion fallback, appends to used_event_ids) · **EventManager + EventScene** (Slice 4; CanvasLayer layer 10 overlay; show/hide event UI; condition evaluator + effect dispatcher; 6 condition forms, 7 effect types; event nodes marked cleared on completion) · **FeatLibrary + Feat System** (Slices 1–7 + pool expansion; FeatData resource; feats.csv 38 rows (20 class, 18 background); get_feat/all_feats/grant_feat; stat bonuses apply to all derived stats; feat_ids unified field on CombatantData; save migration strips old kindred feat IDs) · **Class Pool Expansion** (abilities.csv 54 rows; 4 unique class defining abilities — tower_slam/arcane_bolt/slipshot/bless auto-granted as slot 0; class ability_pool 13 per class; class feat_pool 10 per class with 20 unique class feats) · **Kindred Expansion** (8 kindreds — 4 humanoid + 4 non-humanoid: Skeleton/Giant Rat/Spider/Dragon; each has natural attack + 2 ancestry abilities; auto-populate CharacterCreationManager dials) · **Equipment expansion** (equipment.csv wiped + 9 COMMON placeholder items: 3 weapon/3 armor/3 accessory; consumables.csv 11 items) · **Rarity Foundation Slice 1** (EquipmentData: Rarity enum COMMON/RARE/EPIC/LEGENDARY + rarity field + granted_ability_ids + feat_id + RARITY_COLORS const grey/green/blue/orange + rarity_color() helper; EquipmentLibrary: parses rarity/granted_ability_ids/feat_id CSV columns; RewardGenerator: RARITY_WEIGHTS 60/25/12/3 + weighted tier roll + rarity in all returned dicts; UI: item name text + card borders colored by rarity across PartySheet/EndCombatScreen/MapManager Add Item modal; all add_to_inventory call sites carry rarity; 11 headless tests test_rarity.gd) · **Archetype expansion** (archetypes.csv 9 templates including skeleton_warrior/rat_scrapper/cave_spider/young_dragon; hire_cost column added) · **XP + Level-Up System** (CombatantData level/xp/pending_level_ups; grant_xp(15) on combat win; even levels → ability pick, odd → feat pick; 3-card horizontal overlay layer 25; back-to-back chaining for multi-level batches) · **Dual Armor System** (CombatantData physical_armor + magic_armor fields; physical_defense + magic_defense computed properties with 7-source stacking — base + transient mod + equip + feat + class + kindred + bg; AbilityData.DamageType enum; all 54 abilities tagged PHYSICAL/MAGIC/NONE; HARM formula subtracts matching defense post-QTE; old save migration: armor_defense → both lanes) · **Armor Mod** (transient physical_armor_mod + magic_armor_mod fields on CombatantData, NOT serialized; AbilityData.Attribute gains PHYSICAL_ARMOR_MOD/MAGIC_ARMOR_MOD; _apply_stat_delta clamps to [-10,10]; _attr_snapshots snapshot/restore so mid-combat mods never bleed; stone_guard + divine_ward now mechanically active) · **Test Combat Room** (Dev Menu "Armor Showcase" + "Armor Mod" + "Recruit" buttons share GameState.test_room_mode + test_room_kind dispatcher; recruit scenario = RogueFinder vit10 + 2 allies vs 3 Whelps at 1 HP; returns to map with no save mutation) · **plate_cuirass + warded_robe** (two new ARMOR slot pieces — heavy physical and first magic_armor equipment) · **+ Add Item / Give Gold dev tools** (Dev Menu INVENTORY section; modal A-Z list of every equipment + consumable; "+ Give Gold +100" button) · **Follower System Slices 1–6** (Pathfinder-only "⊕ Recruit 3E" button; RECRUIT_TARGET_MODE; RecruitBar hold-and-release QTE; full success path — enemy removed from board, rename prompt, bench insert or bench-full release modal; bench saved to disk; GameState.release_from_bench + swap_active_bench; BadurgaManager Party Management overlay with bench grid, drag-to-equip, and party swap; 35 headless tests; **event channel** — `recruit_follower` effect + `bench_not_full` condition + 3 follower-offer events in CSVs; **city hire channel** — Hire Roster overlay with seeded 4-card roster, one-at-a-time nav, ability/feat tabs with tooltips, gold economy, BenchSwapPanel on bench-full) · **Pause Menu + Archetypes Log** (ESC or ☰ button; layer 26 CanvasLayer autoload; blocked on MainMenuScene + RunSummaryScene; Settings — volume sliders persist to user://settings.json; Guide stub; Archetypes Log — Pokédex-style with UNKNOWN/ENCOUNTERED/FOLLOWER/PLAYER statuses; GameState.encountered_archetypes + recruited_archetypes both saved; add_to_bench() is canonical recruit hookpoint; 12 headless tests) · **Upgraded Ability System — Slice 2** (AbilityData: upgraded_id: String = "" field; AbilityLibrary: parses upgraded_id CSV column + get_upgraded(base_id) helper — returns linked ability or blank stub, never null; abilities.csv: upgraded_id column added, all 54 rows empty — content wired in Slices 3–5; 6 headless tests test_upgraded_ability.gd) · **Armor Tier Families — Slice 4** (3 armor families × 4 rarities = 12 armor items replacing 3 COMMON placeholders; Iron Plate 5/1 phys-heavy, Scale Mail 3/3 balanced, Mystic Robe 1/5 magic-heavy (no tradeoffs on any armor); Epic = Common +2/+2 both lanes; 6 armor abilities: stone_guard→fortified_guard / guard→enhanced_guard / divine_ward→greater_ward; upgraded_id linked on 3 existing base rows; no code changes — on_equip/on_unequip already live; 7 headless tests) · **Accessory Tier Families — Slice 5** (3 accessory families × 4 rarities = 12 accessories; tier ladder: Common=X:1 · Rare=X:1+feat · Epic=X:1,Y:1+feat · Legendary=X:1,Y:1,Z:2+feat; families: Ring of Valor/Scholar's Amulet/Iron Bracers; `get_feat_stat_bonus()` reads accessory.feat_id at compute-time with dedup — never mutates feat_ids; 5 headless tests; 66 abilities / 36 equipment items total) · **Speed formula** (`CombatantData.speed = 1 + KindredLibrary.get_speed_bonus(kindred)`; dex fully reserved for future dodge/evasion — no passthrough of any kind) · **Weapon Tier Families — Slice 3** (3 STR/DEX/COG families × 4 rarities = 12 weapons; each grants 1 ability; 6 new weapon abilities (blade_strike→heavy_blade_strike / quick_draw→aimed_draw / staff_bolt→empowered_bolt) with upgraded_id linked; CombatantData.on_equip/on_unequip pool lifecycle; all equip/unequip call sites updated; 7 headless tests)
- **Last session (ATK Stat Removal, 2026-04-29):** `CombatantData.attack` computed property removed — no separate attack stat exists. New `effective_stat(stat: String) -> int` method returns raw attribute + all 6 bonus sources (equip/feat/class/kindred/bg/temp). HARM formula in `CombatManager3D._run_harm_defenders` now uses `_get_attribute_value(caster, ability.attribute)` → `effective_stat()` — so a STR ability scales with effective STR, COG with effective COG, etc. `PartySheet` derived stats row reduced from 6 to 5 cols (Atk removed). `StatPanel` Attack line removed. GAME_BIBLE, combatant_data.md, combat_manager.md, party_sheet.md all updated.
- **Previous session (Consumable Pool Expansion — Slice 6, 2026-04-29):** 5 new BUFF +1 consumables added to `consumables.csv`: `steel_tonic` (STR), `quicksilver_draught` (DEX), `clarity_brew` (COG), `iron_word` (WIL), `heartroot_tonic` (VIT). Total: 11 consumables. Pure CSV — zero GDScript changes. `test_consumables.gd` gained 6 new assertions (5 item tests + total count == 11); all 13 tests pass.
- **Previous session (Accessory Tier Families — Slice 5, 2026-04-29):** 3 accessory families × 4 rarities = 12 tiered accessories replace 3 COMMON placeholders. Tier ladder: Common = X:1 stat · Rare = X:1 + background feat · Epic = X:1,Y:1 + same feat · Legendary = X:1,Y:1,Z:2 + same feat. Families: Ring of Valor (STR/VIT/WIL, feat=`combat_training`), Scholar's Amulet (COG/WIL/VIT, feat=`analytical_mind`), Iron Bracers (VIT/STR/DEX, feat=`hearty_constitution`). `CombatantData.get_feat_stat_bonus()` extended to include `accessory.feat_id` at read-time with dedup via a `seen` Dictionary — never writes to `feat_ids`. 5 new headless tests (`test_accessory_feat.gd/.tscn`); `test_rarity.gd` + `test_equipment.gd` updated for tiered armor/accessory reality. Total: 66 abilities, 36 equipment items.
- **Previous session (Armor Tier Families — Slice 4 + speed formula fix, 2026-04-29):** 3 armor families × 4 rarities = 12 tiered armor items replace 3 COMMON placeholders. Distribution rule: `physical_armor + magic_armor = 6` at Common; Epic adds +2/+2 to both lanes. Families: Iron Plate (5/1 phys-heavy), Scale Mail (3/3 balanced), Mystic Robe (1/5 magic-heavy) — **no tradeoffs on any armor family**. `abilities.csv` gained 6 armor abilities: `stone_guard`→`fortified_guard` (BUFF 3 PHYSICAL_ARMOR_MOD), `guard`→`enhanced_guard` (BUFF 3 VIT), `divine_ward`→`greater_ward` (BUFF 3 MAGIC_ARMOR_MOD); `upgraded_id` linked on 3 existing base rows. No code changes for armor — `on_equip`/`on_unequip` already live. **Speed formula**: `CombatantData.speed` simplified to `1 + KindredLibrary.get_speed_bonus(kindred)` — all dex passthrough (equip/feat/class/kindred/bg/temperament via dex) removed; DEX reserved for future dodge/evasion. 7 new headless tests (`test_armor_equip.gd/.tscn`). Total: 66 abilities, 27 equipment items.
- **Previous session (Weapon Tier Families — Slice 3, 2026-04-28):** 3 weapon families (STR/DEX/COG) × 4 rarities = 12 tiered weapons replace the 3 COMMON placeholder weapons. Each weapon grants exactly 1 ability via `granted_ability_ids`. Tier ladder: Common = ability only · Rare = ability + +1 primary stat · Epic = Rare's stat + upgraded ability · Legendary = Epic's stat + extra. `abilities.csv` gained 6 weapon abilities: `blade_strike`→`heavy_blade_strike` (STR PHYSICAL), `quick_draw`→`aimed_draw` (DEX PHYSICAL), `staff_bolt`→`empowered_bolt` (COG MAGIC); `upgraded_id` linked on base rows. `CombatantData.on_equip(eq)` / `on_unequip(eq)` added — add/remove `granted_ability_ids` from `ability_pool` (deduped; active slots never cleared by unequip). All equip/unequip sites updated: `PartySheet`, `BadurgaManager`, `GameState.release_from_bench`. `EquipmentLibrary` parse bug fixed (`.assign()` not typed `Array()` ctor). 7 new headless tests (`test_weapon_equip.gd/.tscn`). Total: 60 abilities, 18 equipment items.
- **Deferred:** Character creation B3 (Dial widget component — scrapped); portrait serialization (deferred to art pass); Badurga remaining 6 sections (Tavern/Bulletin/Weapons/Armor/Accessories/Consumables vendors are stubs); Vendor scene content (NodeStub placeholder); ability effects are placeholder; boss difficulty scaling from threat quadrants (Feature 8); trigger-based feat effects (effects JSON column is empty — data-layer only); feat rarity/tiering/swapping; enemy `qte_resolution` retune; level-up stat bonuses (level grants ability/feat pick only — no automatic stat increases yet); audio bus wiring for volume sliders (sliders persist values but don't affect actual audio yet)

For current feature-by-feature status and history, read `docs/map_directories/map.md` and the bucket files it links. For planned work, read `docs/backlog.md` (only when asked).

---

## Code Conventions

- **Typed GDScript** — always declare types (`var speed: int = 3`)
- `snake_case` vars/funcs, `PascalCase` class/node names, `ALL_CAPS` constants
- One script per scene; prefer **signals** over direct calls
- `@export` for inspector-tweakable values; `@onready` for node refs
- **Placeholder art:** Use the Godot icon (`load("res://icon.svg")`) as the default for all 2D placeholder artwork (portraits, ability icons, item icons). Replace with real art when assets arrive.
- Section headers: `## --- Section Name ---`; comment the *why*, not the *what*
- All `.tscn` files stay **minimal** (root + script only) — build children in `_ready()`
- Signals named as past-tense events: `unit_moved`, `qte_resolved`

---

## Data Libraries

All per-row game data (kindreds, classes, backgrounds, abilities, equipment, consumables, portraits, feats, enemies, etc.) lives in `rogue-finder/data/<name>.csv` with a matching `rogue-finder/scripts/globals/<Name>Library.gd` loader. **Uniform across datasets — no inline `const` dicts of game content.**

**Template:** `BackgroundLibrary.gd`. New libraries mirror its shape:
- `const CSV_PATH := "res://data/<name>.csv"`
- `static var _cache: Dictionary = {}` — lazy-populated
- `static func _ensure_loaded()` — parses once
- `static func get_<name>(id) -> <DataType>` — stub fallback on unknown, never null
- `static func all_<names>() -> Array[<DataType>]`
- `static func reload()` — clear + re-parse (dev/test helper)

**Cell conventions:** pipe-separated for string arrays (`feat_pool = a|b|c`); pipe-separated for ranges (`str_range = 1|4`); JSON for nested structures (`effects = [{"type":"HARM","base_value":5}]`).

**Uniformity pass complete (S30–S35 + name-pool migration + temperament).** All game-data libraries source from CSV: `BackgroundLibrary`, `ClassLibrary`, `PortraitLibrary`, `ConsumableLibrary`, `EquipmentLibrary`, `KindredLibrary`, `ArchetypeLibrary`, `AbilityLibrary`, `EventLibrary` (two-CSV split — events + event_choices), `FeatLibrary`, `TemperamentLibrary`. Flavor name pools live on `KindredData.name_pool` (not archetype). `EventLibrary` deviates from the single-CSV convention intentionally — events have repeating child rows (choices). Every other new data set follows the single-CSV pattern from day one.

---

## Key Design Rules (do not deviate)

- **3v3 combat** — 3 player units vs 3 enemies units
- **Team-based initiative** — all players act, then all enemies
- **Action economy per turn:** Stride (free) + Active Action/Ability (costs Energy) + Consumable (if combatant has one)
- **QTE:** defender-driven Slide bar. HARM only — all other effects auto-resolve. Defender's dodge roll maps to damage multiplier (perfect dodge 0.5×, miss 1.25×). Player units see the bar when defending; enemies instant-sim via `qte_resolution`.
- **Enemy AI:** hidden `qte_resolution` stat (grunt 0.3, elite 0.8)

---

## Testing Approach

Write implementation + tests in one response. Tests go in `/tests/`. Use plain `assert()` — no scene required.

Test: state transitions, damage formula, grid math, win/lose triggers.
Do NOT test: rendering, input, anything needing a live scene.

---

## Teaching Mode

- Comment non-obvious logic; note structural decisions (why a signal, etc.)
- Explain in plain terms when asked — dev knows GML/SQL, learning GDScript
- Do NOT explain things not asked about
- Ask the user for permission before triggering anything from the superpowers plugin.

---

## Version Control Workflow

- Every session, create and push a branch named `claude/<feature>-<YYYYMMDD>` before any work.
- **Never touch `main`** until the user explicitly approves the branch.
- When work is ready, commit + push, then tell the user what was built and list out in numbered bullet points what is needed to be tested.
- On approval: `git checkout main && git merge <branch> --no-ff && git push origin main`.
- If the user rejects, keep iterating on the same branch.

---

## Documentation Protocol

- **`docs/map_directories/map.md`** is the high-level index of all game systems. Read it first when working on an unfamiliar system, then navigate to the relevant bucket file. Only read what you need.
- After any significant logic change or new system, update the relevant bucket `.md` files — changed/new signals, public methods, dependencies, structural decisions. If a change crosses systems, update both bucket files plus `map.md`.
- Do not use this `CLAUDE.md` for workflow scratchwork, placeholders, or session history.
- **`/wrapup`** is the authoritative end-of-session workflow (lives at `~/.claude/skills/wrapup/SKILL.md`). Do not do wrap-up work outside it.

---

## Save System

Save/load is live. Pattern: add a field to `GameState`, include it in `save()`'s data dict, read it back in `load_save()` (use `Array(..., TYPE_T, "", null)` for typed arrays). Save file: `user://save.json`.

**Every new feature that introduces persistent run state must extend the save system.** Ask: "does this data need to survive a session?" If yes, wire `save()`/`load_save()` in the same PR — do not defer.

Currently saved: `player_node_id`, `visited_nodes`, `map_seed`, `node_types`, `cleared_nodes`, `threat_level`, `used_event_ids`, `party`, `bench`, `inventory`.
Not yet saved (Stage 2): faction reputation, combat state.
Transient (never saved): `pending_node_type`, `current_combat_node_id` — consumed within a single scene transition.
