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
- **Live systems:** 3D combat loop · traversable world map with 5 node types (COMBAT, VENDOR, EVENT, BOSS, CITY) + structured placement rules · save/load · reward system · Badurga city shell (placeholder sections) · threat escalation counter + HUD bar · persistent party (HP/energy carry-over, ally permadeath, run-end summary screen) · party bag inventory (all reward items land in shared bag; equipment + consumables stored as raw dicts) · party sheet overlay (interactive 4-quadrant equip UI, layer 20, full ability pool swap with drag-compare) · CombatActionPanel (right slide-in, player + enemy view, tooltips) · **Kindreds** (owns ability lane — speed/HP bonuses + stat_bonuses + starting_ability_id + ability_pool; no feats; get_kindred_stat_bonus() wired into all 6 derived stats) · **Backgrounds** (owns feat lane — starting_feat_id + 2-feat pool + stat_bonuses; no abilities; get_background_stat_bonus() wired into all 6 derived stats) · **MainMenuScene** (title screen; Continue grayed when no save exists; Start New Run goes to creation without mutating save; Test New Run dev shortcut with 3 random PCs) · **Character Creation** (B2 + B4 — slot-wheel dials for kindred/class/background/portrait; name field + 🎲; Back button; live preview panel showing deterministic HP + STR/DEX/COG/WIL/VIT + class ability + kindred ability + background feat; no stat rolling; _build_pc() builds CombatantData from picks; PC added to party on Begin Run) · **EventLibrary** (data layer — Slice 1; EventData + EventChoiceData resources; events.csv + event_choices.csv; 3 smoke events, 12 tests) · **EventSelector** (Slice 3; static pick_for_node(ring); unseen-first pool, exhaustion fallback, appends to used_event_ids) · **EventManager + EventScene** (Slice 4; CanvasLayer layer 10 overlay; show/hide event UI; condition evaluator + effect dispatcher; 6 condition forms, 7 effect types; event nodes marked cleared on completion) · **FeatLibrary + Feat System** (Slices 1–7 + pool expansion; FeatData resource; feats.csv 32 rows (20 class, 12 background); get_feat/all_feats/grant_feat; stat bonuses apply to all derived stats; feat_ids unified field on CombatantData; save migration strips old kindred feat IDs; 70 tests passing) · **Class Pool Expansion** (abilities.csv 42 rows; 4 unique class defining abilities — tower_slam/arcane_bolt/slipshot/bless auto-granted as slot 0; class ability_pool 13 per class; class feat_pool 10 per class with 20 unique class feats)
- **Last session (Class Pool Expansion, 2026-04-26):** `abilities.csv` +10 rows: 4 class defining abilities (`tower_slam` STR HARM4+push1, `arcane_bolt` COG HARM5 range4, `slipshot` DEX HARM4+travel1, `bless` WIL BUFF STR+1 ally) + 6 new class-pool abilities (`backstab`, `crippling_shot`, `vanishing_step` for Prowler; `lay_on_hands`, `divine_ward`, `rallying_shout` for Warden) → 42 total. `classes.csv`: `starting_ability_id` updated to new definings; `ability_pool` 5→13; `feat_pool` 3→10. `feats.csv` +8 new class feats (`iron_constitution`, `combat_mastery`, `spell_memory`, `evasive_footwork`, `relentless_assault`, `arcane_resilience`, `iron_will`, `veteran_instinct`) → 32 total. Pre-existing test failures fixed (`test_feat_library` + `test_feat_stat_bonus` had stale refs to removed kindred feats). 70 tests passing across 7 suites.
- **Deferred:** Character creation B3 (Dial widget component — scrapped); portrait serialization (deferred to art pass); Badurga section content (all 6 buttons are stubs); Vendor scene content (NodeStub placeholder); ability effects are placeholder; boss difficulty scaling from threat quadrants (Feature 8); level-up picker UI (class ability pool + feat pool exist in data but not wired to any growth mechanic); trigger-based feat effects (effects JSON column is empty — data-layer only); feat rarity/tiering/swapping; recruit mechanic (placeholders); enemy `qte_resolution` retune

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

**Uniformity pass complete (S30–S35 + name-pool migration).** All game-data libraries source from CSV: `BackgroundLibrary`, `ClassLibrary`, `PortraitLibrary`, `ConsumableLibrary`, `EquipmentLibrary`, `KindredLibrary`, `ArchetypeLibrary`, `AbilityLibrary`, `EventLibrary` (two-CSV split — events + event_choices), `FeatLibrary`. Flavor name pools live on `KindredData.name_pool` (not archetype). `EventLibrary` deviates from the single-CSV convention intentionally — events have repeating child rows (choices). Every other new data set follows the single-CSV pattern from day one.

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

Currently saved: `player_node_id`, `visited_nodes`, `map_seed`, `node_types`, `cleared_nodes`, `threat_level`, `party`, `inventory`.
Not yet saved (Stage 2): faction reputation, combat state.
Transient (never saved): `pending_node_type`, `current_combat_node_id` — consumed within a single scene transition.
