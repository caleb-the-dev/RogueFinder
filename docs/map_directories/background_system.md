# System: Background System

> Last updated: 2026-04-27 (kindred expansion — added scavenger + pit_fighter; now 6 backgrounds)

---

## Purpose

A **Background** is a character's pre-adventure occupation (Crook, Soldier, Scholar, Baker). Backgrounds own the **feat lane** — each background grants one defining feat at character creation and holds a pool of 2 additional feats available during the run. No ability is granted by a background (abilities come from class and kindred).

Background stat bonuses apply structurally to all derived stats via `CombatantData.get_background_stat_bonus()`.

---

## Core Files

| File | Role |
|------|------|
| `resources/BackgroundData.gd` | Resource — one background |
| `scripts/globals/BackgroundLibrary.gd` | Static catalog — lazy CSV load, cached by id |
| `rogue-finder/data/backgrounds.csv` | Source of truth — edit here; Godot reads via `res://data/` |

---

## BackgroundData

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `background_id` | `String` | Snake_case key (e.g. `"crook"`) |
| `background_name` | `String` | Display name (e.g. `"Crook"`) |
| `description` | `String` | Short flavor line for character-creation UI |
| `starting_feat_id` | `String` | 1 feat auto-granted at character creation. FK → `FeatLibrary`. Added as `feat_ids[0]` in `_build_pc()`. |
| `feat_pool` | `Array[String]` | 2 feat IDs available to this background during the run. Distinct from `starting_feat_id` (no overlap). |
| `unlocked_by_default` | `bool` | `true` = available at character creation in fresh saves |
| `tags` | `Array[String]` | Event hooks (e.g. `["criminal", "urban"]`). |
| `stat_bonuses` | `Dictionary` | Flat bonuses applied to all derived stats via `CombatantData.get_background_stat_bonus()`. Same key:int format as `FeatData.stat_bonuses` (full stat names). |

### Helpers

```gdscript
func has_tag(tag: String) -> bool
```

---

## BackgroundLibrary

### Public API

```gdscript
## Returns a populated BackgroundData. Never returns null — stub for unknown IDs.
static func get_background(id: String) -> BackgroundData
## Back-compat lookup by display name ("Crook" / "Soldier"). Bridges the gap
## while ArchetypeLibrary still uses PascalCase display strings. Delete when migration lands.
static func get_background_by_name(display_name: String) -> BackgroundData
## Returns every loaded background. For character-creation UI / unlock screens.
static func all_backgrounds() -> Array[BackgroundData]
## Clears the cache and re-reads the CSV. Useful after editing the CSV mid-session.
static func reload() -> void
```

### Private helpers

```gdscript
## Parses "stat:value|stat:value" into a Dictionary. Empty string returns {}.
static func _parse_stat_bonuses(val: String) -> Dictionary
static func _split_pipe(val: String) -> Array[String]
```

### Defined Backgrounds (6 rows)

| ID | Name | Starting Feat | Feat Pool | Stat Bonuses | Tags |
|----|------|--------------|-----------|-------------|------|
| `crook` | Crook | `street_smart` | nimble_fingers, survival_instinct | dexterity:1 | `criminal`, `urban` |
| `soldier` | Soldier | `combat_training` | disciplined_stance, unit_cohesion | strength:1 | `military`, `disciplined` |
| `scholar` | Scholar | `analytical_mind` | focused_study, breadth_of_knowledge | cognition:1 | `academic`, `urban` |
| `baker` | Baker | `hearty_constitution` | enduring_spirit, patient_resolve | vitality:1 | `commoner`, `urban` |
| `scavenger` | Scavenger | `opportunist` | quick_grab, waste_not | dexterity:1 | `criminal`, `feral` |
| `pit_fighter` | Pit Fighter | `crowd_pleaser` | brutal_technique, iron_chin | strength:1 | `combat`, `criminal` |

> **Balance rule (2026-04-27):** each background gives **exactly +1 to a single stat** — no multi-stat spreads, no +2, no negatives.
> **Design note:** Scavenger and Pit Fighter are intentionally species-agnostic — a Giant Rat with Baker background is perfectly valid lore-wise.

### Parsing Rules

- First row is the header; column names drive field assignment via `match`.
- Arrays use `|` as the in-cell separator (e.g. `criminal|urban`).
- Booleans are literal `true` / `false` lowercase.
- Empty string → empty array for list-typed columns.
- Unknown columns → `push_warning`, row continues.
- Missing `id` → `push_error`, row skipped.
- Cell count mismatch with header → `push_error`, row skipped.

---

## Integration with CombatantData

```gdscript
## In CombatantData.gd — returns flat stat bonus from this unit's background.
## Stubs to 0 for unknown background IDs (old saves, enemy units).
func get_background_stat_bonus(stat: String) -> int:
    return BackgroundLibrary.get_background(background).stat_bonuses.get(stat, 0)
```

`get_background_stat_bonus()` is wired into all 6 derived stat formulas alongside class, kindred, feat, and equipment bonuses.

`CharacterCreationManager._build_pc()` seeds `feat_ids = [bg_data.starting_feat_id]` at creation.

---

## Dependencies

| Dependent | On |
|-----------|----|
| `BackgroundData` | Nothing (leaf node) |
| `BackgroundLibrary` | `BackgroundData`, `FileAccess` |
| `CombatantData` | `BackgroundLibrary` (via `get_background_stat_bonus()`) |
| `CharacterCreationManager` | `BackgroundLibrary` (list, display name, starting_feat_id, stat_bonuses) |

### Migration note

`CombatantData.background` and `ArchetypeLibrary` pools currently store PascalCase display strings (`"Crook"`, `"Soldier"`) while `BackgroundLibrary` keys on snake_case ids (`"crook"`). `get_background_by_name()` bridges the gap. Full snake_case-id migration is deferred.

---

## Where NOT to Look

- **Ability system is NOT here** — backgrounds no longer grant abilities. Abilities come from class (defining) and kindred (natural attack).
- **Feat level-up logic is NOT here** — `feat_pool` is the data pool; picker UI is deferred.
- **Event-gating logic is NOT here** — `tags` is a passive list; conditions evaluated by `EventManager`.

---

## Key Patterns & Gotchas

- **Lazy load** — `_ensure_loaded()` fires on first call. Cheap but not free.
- **Stub fallback is load-bearing** — unknown ids return a stub with empty `stat_bonuses` and empty `feat_pool`, not null.
- **`starting_feat_id` ≠ `feat_pool`** — the defining feat is auto-granted and should not also appear in `feat_pool`. Overlap = the character would draw it twice.
- **Stat bonuses are structural, not feat entries** — `stat_bonuses` flows through `get_background_stat_bonus()` into derived stats at all times, not through `feat_ids`. Do not add a background's stat bonus as a feat entry.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-27 | **Kindred expansion — 2 new backgrounds.** `scavenger` (DEX+1, criminal/feral, feat pool: quick_grab/waste_not) and `pit_fighter` (STR+1, combat/criminal, feat pool: brutal_technique/iron_chin) added. 6 new background feats added to feats.csv. Species-agnostic by design — valid for humanoid and non-humanoid kindreds alike. Backgrounds: 4→6, background feats: 12→18. |
| 2026-04-27 | **Balance pass — single-stat rule.** All backgrounds now give exactly +1 to one stat. soldier: `strength:1\|vitality:1` → `strength:1`. scholar: `cognition:2` → `cognition:1`. baker: `vitality:1\|willpower:1` → `vitality:1`. crook unchanged (`dexterity:1`). |
| 2026-04-26 | **Pillar foundation.** `starting_ability_id` removed; replaced with `starting_feat_id` + `stat_bonuses`. `BackgroundData.gd` updated. `BackgroundLibrary` gains `_parse_stat_bonuses()`. `get_background_stat_bonus()` wired into `CombatantData` derived stats. `CharacterCreationManager._build_pc()` seeds `feat_ids[0]` from `starting_feat_id`. All 4 backgrounds have concrete stat_bonuses and feat assignments. |
| 2026-04-23 | S30 — fixed 3 broken `starting_ability_id` rows (`crook → smoke_bomb`, `scholar → acid_splash`, `baker → healing_draught`). `starting_ability_id` now removed entirely (see above). |
