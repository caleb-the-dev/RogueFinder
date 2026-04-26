# System: Class Library

> Last updated: 2026-04-26 (class rename + stat_bonuses + ability_pool; wired into CombatantData)

---

## Purpose

A **Class** is the player's combat identity (e.g. Vanguard, Arcanist, Prowler, Warden). Per GAME_BIBLE, each class grants one starting ability at character creation, a stat bonus package applied to all derived stats, a feat pool for future level-up picks, and an ability pool for future level-up expansion.

Class is a separate axis from Background and Kindred — a `vanguard` Crook (Human) is a valid combination.

---

## Core Files

| File | Role |
|------|------|
| `resources/ClassData.gd` | Resource — one class |
| `scripts/globals/ClassLibrary.gd` | Static catalog — lazy CSV load, cached by id |
| `rogue-finder/data/classes.csv` | Source of truth — edit here; Godot reads via `res://data/` |

---

## ClassData

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `class_id` | `String` | Snake_case key (e.g. `"vanguard"`) |
| `display_name` | `String` | Display name (e.g. `"Vanguard"`) — named `display_name` not `class_name` because `class_name` is a reserved GDScript keyword |
| `description` | `String` | Short flavor line for character-creation UI |
| `starting_ability_id` | `String` | 1 action granted at character creation. FK → `AbilityLibrary` |
| `feat_pool` | `Array[String]` | Feat IDs available to this class (pipe-separated in CSV). Data only — assigned at odd levels (not at creation yet). |
| `unlocked_by_default` | `bool` | `true` = available at character creation in fresh saves |
| `tags` | `Array[String]` | Flavor/filter hints (e.g. `["melee", "defender"]`) |
| `stat_bonuses` | `Dictionary` | Flat bonuses applied to all derived stats. Same key:int format as `FeatData.stat_bonuses` — full stat names (e.g. `{"strength": 1, "vitality": 2}`). Parsed from `strength:1\|vitality:2` in CSV. |
| `ability_pool` | `Array[String]` | Full ability ID set for future level-up picker. Parsed pipe-separated from CSV. Data only — not yet wired to UI. |

### Helpers

```gdscript
func has_tag(tag: String) -> bool
```

---

## ClassLibrary

### Data Flow

```
rogue-finder/data/classes.csv   (source of truth — edit here; Godot reads via res://data/)
        │
        ▼  FileAccess.get_csv_line(",")
ClassLibrary._cache             (lazy-loaded Dictionary keyed by id)
```

### Public API

```gdscript
## Returns a populated ClassData. Never returns null — stub for unknown IDs.
## Named get_class_data() because get_class() is a built-in Object method.
static func get_class_data(id: String) -> ClassData
## Returns every loaded class. For character-creation UI / unlock screens.
static func all_classes() -> Array[ClassData]
## Clears the cache and re-reads the CSV.
static func reload() -> void
```

### Private helpers

```gdscript
## Parses "str:1|vit:2" into {"str": 1, "vit": 2}
static func _parse_stat_bonuses(val: String) -> Dictionary
static func _split_pipe(val: String) -> Array[String]
```

### Defined Classes (4 rows)

| ID | Name | Starting Ability | Stat Bonuses | Feat Pool | Tags |
|----|------|-----------------|-------------|-----------|------|
| `vanguard` | Vanguard | `shield_bash` | strength:1, vitality:2 | iron_guard, stalwart, battle_hardened | `melee`, `defender` |
| `arcanist` | Arcanist | `fireball` | cognition:2, willpower:1 | arcane_focus, mana_well, studied_reflexes | `arcane`, `ranged` |
| `prowler` | Prowler | `quick_shot` | dexterity:2, willpower:1 | shadow_step, quick_reflexes, poisoners_precision | `agile`, `stealthy` |
| `warden` | Warden | `inspire` | cognition:1, vitality:1, willpower:1 | war_cry_discipline, thick_skin, shield_discipline | `support`, `divine` |

---

## Integration with CombatantData

`CombatantData.unit_class` stores the **class ID** (lowercase, e.g. `"vanguard"`) — not the display name. All display points call `ClassLibrary.get_class_data(unit_class).display_name`.

```gdscript
## In CombatantData.gd — returns the flat stat bonus from this unit's class.
## Stubs to 0 for unknown class IDs (old saves, enemy archetypes with no class).
func get_class_stat_bonus(stat: String) -> int:
    return ClassLibrary.get_class_data(unit_class).stat_bonuses.get(stat, 0)
```

`get_class_stat_bonus()` is wired into all 5 derived stat formulas:
- `hp_max` → `vitality` class bonus
- `energy_max` → `vitality` class bonus
- `energy_regen` → `willpower` class bonus
- `speed` → `dexterity` class bonus
- `attack` → `strength` class bonus
- `defense` → `armor_defense` class bonus

---

## Dependencies

| Dependent | On |
|-----------|----|
| `ClassData` | Nothing (leaf node) |
| `ClassLibrary` | `ClassData`, `FileAccess` |
| `CombatantData` | `ClassLibrary` (via `get_class_stat_bonus()`) |
| `CharacterCreationManager` | `ClassLibrary` (display name + starting_ability_id + feat_pool) |
| `StatPanel`, `PartySheet`, `UnitInfoBar` | `ClassLibrary` (display name lookup) |

---

## Where NOT to Look

- **Class-based feat assignment at creation** — `feat_pool` data exists but is not wired to the creation flow. Planned for odd-level milestone.
- **Trigger-based class effects** — `ability_pool` column is scaffolding; no level-up picker UI yet.
- **`unit_class` stores ID not display name** — always use `ClassLibrary.get_class_data(unit_class).display_name` for UI.

---

## Key Patterns & Gotchas

- **Lazy load** — `_ensure_loaded()` fires on first call. Cheap but not free; don't call in tight loops.
- **Stub fallback is load-bearing** — unknown IDs return a stub (empty stat_bonuses dict, empty ability_pool), never null. Old saves gracefully fall back.
- **CSV is the only source** — no inline const dict fallback.
- **`stat_bonuses` column format** — `strength:1|vitality:2` (full stat names, same convention as `FeatData`/feats.csv). Parsed by `_parse_stat_bonuses()` into a plain `Dictionary`.
