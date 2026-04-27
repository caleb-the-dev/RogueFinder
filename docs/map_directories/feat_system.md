# System: Feat System

> Last updated: 2026-04-26 (class pool expansion — +8 new class feats, 10 pool slots per class, fixed stale kindred-feat test refs)

---

## Status

**Mechanically active.** `FeatLibrary` + `FeatData` + `feats.csv` are live. All display surfaces iterate `feat_ids`. Stat bonuses from feats apply to all derived stats. `GameState.grant_feat()` is the canonical way to add feats during a run.

---

## Purpose

Central registry for passive character feats. Each background grants one defining feat at character creation (`feat_ids[0]`). Event effects can grant additional feats via `GameState.grant_feat()`. Feats apply flat stat bonuses to derived stats, identical in form to equipment bonuses.

> **Note:** Kindred feats were removed in the pillar-foundation session (2026-04-26). The old kindred-source rows (`adaptive`, `relentless`, `tinkerer`, `stonehide`) are deleted from `feats.csv`. Kindred stat bonuses are now structural via `KindredData.stat_bonuses` / `CombatantData.get_kindred_stat_bonus()`. Old saves with these IDs in `feat_ids` are automatically stripped on load.

---

## Core Files

| File | Role |
|------|------|
| `resources/FeatData.gd` | Resource: one feat (id, name, description, source_type, stat_bonuses, effects) |
| `scripts/globals/FeatLibrary.gd` | CSV-native loader; `get_feat()` / `all_feats()` / `reload()` |
| `data/feats.csv` | Data source: 32 feats (20 class, 12 background — kindred rows removed) |

---

## FeatData Fields

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `id` | `String` | `""` | Snake-case key (e.g. `"iron_will"`) |
| `name` | `String` | `""` | Display name (e.g. `"Iron Will"`) |
| `description` | `String` | `""` | One-sentence flavour + mechanic description |
| `source_type` | `String` | `""` | One of: `class`, `background`, `item`, `event` (kindred-source rows deleted in Pillar Foundation) |
| `stat_bonuses` | `Dictionary` | `{}` | `stat_name → int` (e.g. `{"strength": 1}`). Parsed from `stat:value\|stat:value` in CSV. |
| `effects` | `Array` | `[]` | Reserved for future trigger-based effects; parsed from CSV but all rows are empty this session |

---

## FeatLibrary Public API

| Method | Signature | Notes |
|--------|-----------|-------|
| `get_feat` | `(id: String) -> FeatData` | Never null; unknown id returns stub with `name = "Unknown Feat"`, empty `stat_bonuses = {}` |
| `all_feats` | `() -> Array[FeatData]` | All loaded feats (unordered) |
| `reload` | `() -> void` | Clear + re-parse; dev/test helper |

### Internal

- `_cache: Dictionary` — static, keyed by `id`; lazy-populated on first call.
- `_ensure_loaded()` — guards against double-load.
- `_row_to_data()` — maps CSV columns to `FeatData` fields; skips `effects` and `notes` silently.
- `_parse_stat_bonuses(raw)` — splits `"str:1|vit:2"` → `{str: 1, vit: 2}`.

---

## feats.csv — 32 Rows

### Class Feats (20)

Pools are 10 feats each with ~50% overlap. See `class_system.md` for full per-class assignments.

| id | name | stat_bonuses | pool membership |
|----|------|-------------|-----------------|
| `shadow_step` | Shadow Step | dexterity:2 | Prowler |
| `poisoners_precision` | Poisoner's Precision | strength:1 | Prowler |
| `quick_reflexes` | Quick Reflexes | dexterity:1 | Prowler |
| `battle_hardened` | Battle Hardened | strength:2 | Vanguard |
| `thick_skin` | Thick Skin | vitality:1 | All 4 |
| `war_cry_discipline` | War Cry Discipline | willpower:1 | All 4 |
| `arcane_focus` | Arcane Focus | cognition:2 | Arcanist |
| `mana_well` | Mana Well | willpower:1 | Arcanist, Prowler, Warden |
| `studied_reflexes` | Studied Reflexes | cognition:1 | Arcanist |
| `iron_guard` | Iron Guard | armor_defense:2 | Vanguard |
| `stalwart` | Stalwart | vitality:1 | Vanguard, Arcanist, Warden |
| `shield_discipline` | Shield Discipline | armor_defense:1 | Vanguard, Warden |
| `iron_constitution` | Iron Constitution | vitality:2 | Vanguard, Warden |
| `combat_mastery` | Combat Mastery | strength:1 | Vanguard, Prowler |
| `spell_memory` | Spell Memory | cognition:1 | Arcanist, Warden |
| `evasive_footwork` | Evasive Footwork | dexterity:1 | Arcanist, Prowler |
| `relentless_assault` | Relentless Assault | strength:1 | Vanguard, Prowler |
| `arcane_resilience` | Arcane Resilience | vitality:1 | Arcanist, Warden |
| `iron_will` | Iron Will | willpower:2 | Arcanist, Prowler, Warden |
| `veteran_instinct` | Veteran Instinct | armor_defense:1 | Vanguard, Warden |

### Background Feats (12)

| id | name | stat_bonuses | background |
|----|------|-------------|-----------|
| `street_smart` | Street Smart | dexterity:1 | crook |
| `nimble_fingers` | Nimble Fingers | dexterity:2 | crook |
| `survival_instinct` | Survival Instinct | willpower:1 | crook |
| `disciplined_stance` | Disciplined Stance | armor_defense:1 | soldier |
| `unit_cohesion` | Unit Cohesion | willpower:1 | soldier |
| `combat_training` | Combat Training | strength:1 | soldier |
| `analytical_mind` | Analytical Mind | cognition:2 | scholar |
| `focused_study` | Focused Study | willpower:1 | scholar |
| `breadth_of_knowledge` | Breadth of Knowledge | cognition:1 | scholar |
| `hearty_constitution` | Hearty Constitution | vitality:1 | baker |
| `enduring_spirit` | Enduring Spirit | willpower:1 | baker |
| `patient_resolve` | Patient Resolve | vitality:1 | baker |

---

## Grant API

`GameState.grant_feat(pc_index: int, feat_id: String) -> void` — canonical way to add feats during a run. Deduplicates; calls `save()` immediately. `EventManager.dispatch_effect` routes `feat_grant` effects here.

---

## Stat Bonus Application

Feat stat bonuses apply identically to equipment bonuses — flat additions to derived stats:

| Stat key | Affects derived stat |
|----------|---------------------|
| `strength` | `attack` (+1 per point) |
| `dexterity` | `speed` (+1 per point) |
| `willpower` | `energy_regen` (+1 per point) and `energy_max` (+1 per point) |
| `vitality` | `hp_max` (+1 per point) and `energy_max` (+1 per point) |
| `armor_defense` | `defense` (+1 per point) |
| `cognition` | no derived stat yet; bonus compiles and returns 0 |

**These are flat bonuses to the derived result, not to the base attribute.** A `vitality:1` feat adds +1 to `hp_max` and +1 to `energy_max`, not +6 to `hp_max`. This matches how `_equip_bonus("vitality")` behaves.

---

## Display Surfaces

| Surface | How feats are shown |
|---------|-------------------|
| **StatPanel** | `── Feats ──` section: numbered list iterating `d.feat_ids`. Resolved via `FeatLibrary.get_feat(id)`. |
| **CharacterCreationManager** | Preview panel: "Background Feat — \<name\>" + description. Resolved via `FeatLibrary.get_feat(bg_data.starting_feat_id)`. |
| **PartySheet Feats tab** | Search/sort/1×2× card list iterating `member.feat_ids`. Resolved via `FeatLibrary.get_feat(id)`. |

---

## Dependencies

| System | Role |
|--------|------|
| `BackgroundLibrary` | Provides `starting_feat_id` per background; `FeatLibrary` is the canonical name/desc/bonuses store |
| `CombatantData` | `feat_ids: Array[String]` is the per-unit feat list; `get_feat_stat_bonus()` calls `FeatLibrary` |
| `GameState` | `grant_feat()` mutates `feat_ids` and calls `save()` |
| `EventManager` | `feat_grant` effect routes through `GameState.grant_feat()`; `feat:ID` condition checks `member.feat_ids` |

`FeatLibrary` has no outbound dependencies (no scene, no autoload, no signals).

---

## Gotchas

- **Single-CSV pattern** — feats follow the standard single-CSV library convention. Add new feats by adding rows to `feats.csv`.
- **`get_feat()` never returns null** — unknown id returns a stub with empty `stat_bonuses`. `get_feat_stat_bonus()` on `CombatantData` is safe with any id.
- **Flat bonus, not attribute bonus** — feat stat bonuses add directly to derived stats, not to base attributes. `vitality:1` ≠ +6 hp_max; it's +1 hp_max.
- **`cognition` has no derived stat yet** — `get_feat_stat_bonus("cognition")` compiles and returns 0. Reserved for ability cost scaling.
- **Background defining feat seeds `feat_ids`** — `feat_ids[0]` is always `bg_data.starting_feat_id` (set in `_build_pc()`). Class feat pool picks and background pool feats are deferred to the level-up mechanic (not yet implemented).
- **Class feat pool is 10 deep** — `ClassData.feat_pool` has 10 IDs per class; not yet assigned at creation. Background `feat_pool` (2 per background) is also data-only.

---

## Tests

| File | Count | Covers |
|------|-------|--------|
| `tests/test_feat_library.gd` / `.tscn` | 11 | CSV loads 32 rows; stat_bonuses parsed (iron_guard, iron_will); source_type parsed (class, background); unknown id returns empty bonuses |
| `tests/test_feat_stat_bonus.gd` / `.tscn` | 8 | `get_feat_stat_bonus()` sums correctly; derived attack/defense/energy_regen increase; unknown id is safe |
| `tests/test_game_state_feat_grant.gd` / `.tscn` | 4 | grant adds id; deduplicates; invalid index no-crashes; save round-trip |
| `tests/test_feat_migration.gd` / `.tscn` | 5 | Old `kindred_feat_id` + `feats` → `feat_ids` migration paths |

Run via:
```
godot --headless --path rogue-finder res://tests/test_feat_library.tscn
godot --headless --path rogue-finder res://tests/test_feat_stat_bonus.tscn
godot --headless --path rogue-finder res://tests/test_game_state_feat_grant.tscn
godot --headless --path rogue-finder res://tests/test_feat_migration.tscn
```

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-04-26 | **Class pool expansion.** `feats.csv` +8 new class feats (`iron_constitution`, `combat_mastery`, `spell_memory`, `evasive_footwork`, `relentless_assault`, `arcane_resilience`, `iron_will`, `veteran_instinct`) → 32 total (20 class, 12 background). Class feat pools expanded from 3 to 10 IDs per class; 20 unique class feats with ~50% cross-class overlap. Test files `test_feat_library.gd` + `test_feat_stat_bonus.gd` updated: replaced stale kindred feat refs (`adaptive`, `stonehide`, `relentless`) with current feats. 70 tests passing across 7 suites. |
| 2026-04-26 | **Slices 1–7.** `feats.csv` expanded to 28 rows + 4 new columns (`source_type`, `stat_bonuses`, `effects`, `notes`). `FeatData` gained `source_type`, `stat_bonuses`, `effects`. `FeatLibrary` parses stat bonuses via `_parse_stat_bonuses()`. `kindreds.csv` dropped `feat_name`/`feat_desc`; `KindredData`+`KindredLibrary` cleaned up. `classes.csv` + `ClassData` + `ClassLibrary` gained `feat_pool`. `CombatantData.kindred_feat_id` + `.feats` consolidated into `feat_ids: Array[String]`; `get_feat_stat_bonus()` added; all derived stat formulas updated. `GameState.grant_feat()` added; `_serialize_combatant` writes `feat_ids`; `_deserialize_combatant` migrates old saves. `EventManager` feat_grant routes through `grant_feat()`; feat condition checks `feat_ids`. StatPanel + PartySheet iterate `feat_ids`. 84 tests passing across 7 suites. |
| 2026-04-24 | **Slice 2 — FeatLibrary data foundation.** `FeatData.gd`, `FeatLibrary.gd`, `feats.csv` (4 kindred feats). Migrated all feat display surfaces from `KindredLibrary.get_feat_name()` / `get_feat_desc()` wrappers to `FeatLibrary.get_feat(id)`. StatPanel: Feats inline RTL section below Abilities. CharacterCreationManager: feat name + description in preview panel. PartySheet: Feats tab upgraded from placeholder to full search/sort/1×2× card list. 8 new headless tests (63 total across all suites). |
