# System: Class Library

> Last updated: 2026-04-26 (feat_pool column added to ClassData + ClassLibrary)

---

## Purpose

A **Class** is the player's combat identity (e.g. Rogue, Barbarian, Wizard, Warrior). Per GAME_BIBLE, each class grants one starting ability at character creation and contributes a feat pool the character draws from at odd levels.

Currently **dormant** — no production code calls `ClassLibrary` yet. The infrastructure is ready for the character-creation screen when that lands.

Class is a separate axis from Background and Kindred — a `barbarian` Crook (Human) is a valid combination.

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
| `class_id` | `String` | Snake_case key (e.g. `"rogue"`) |
| `display_name` | `String` | Display name (e.g. `"Rogue"`) — named `display_name` not `class_name` because `class_name` is a reserved GDScript keyword |
| `description` | `String` | Short flavor line for character-creation UI |
| `starting_ability_id` | `String` | 1 action granted at character creation. FK → `AbilityLibrary` |
| `feat_pool` | `Array[String]` | Feat ids available to this class (pipe-separated in CSV). Data only — not assigned at creation yet; reserved for the future level-up feat picker. |
| `unlocked_by_default` | `bool` | `true` = available at character creation in fresh saves |
| `tags` | `Array[String]` | Optional flavor/filter hints (e.g. `["agile", "stealthy"]`) |

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

### Defined Classes (4 seed rows)

| ID | Name | Starting Ability | Feat Pool | Unlocked by Default | Tags |
|----|------|-----------------|-----------|---------------------|------|
| `rogue` | Rogue | `quick_shot` | shadow_step, poisoners_precision, quick_reflexes | `true` | `agile`, `stealthy` |
| `barbarian` | Barbarian | `heavy_strike` | battle_hardened, thick_skin, war_cry_discipline | `true` | `melee`, `berserker` |
| `wizard` | Wizard | `fireball` | arcane_focus, mana_well, studied_reflexes | `true` | `arcane`, `ranged` |
| `warrior` | Warrior | `shield_bash` | iron_guard, stalwart, shield_discipline | `true` | `melee`, `defender` |

---

## Dependencies

| Dependent | On |
|-----------|----|
| `ClassData` | Nothing (leaf node) |
| `ClassLibrary` | `ClassData`, `FileAccess` |
| *(none yet — dormant)* | |

---

## Where NOT to Look

- **Character-creation UI is NOT here** — not yet built.
- **Class feat system is NOT here** — `tags` is scaffolding only.
- **`unit_class` on `CombatantData`** is a plain String today; it is **not** wired to `ClassLibrary`. That migration lands when character creation is built.

---

## Key Patterns & Gotchas

- **Lazy load** — `_ensure_loaded()` fires on first call. Cheap but not free; don't call in tight loops.
- **Stub fallback is load-bearing** — unknown ids return a stub, never null.
- **CSV is the only source** — no inline const dict fallback.
