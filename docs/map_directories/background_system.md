# System: Background System

> Last updated: 2026-04-23 (split from combatant_data.md during map audit)

---

## Purpose

A **Background** is a character's pre-adventure occupation (e.g. Crook, Soldier, Scholar, Baker). Per GAME_BIBLE, each background grants one starting ability at character creation and contributes a pool of feats the character can draw from at odd levels.

Currently **dormant** — no production code calls `BackgroundLibrary` yet. The infrastructure is ready for the character-creation screen, event system, and feat system when those land.

This is the **first library in the codebase that sources from CSV**. Future migrations of `AbilityLibrary` / `EquipmentLibrary` / `ConsumableLibrary` should follow this shape.

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
| `starting_ability_id` | `String` | 1 action granted at character creation. FK → `AbilityLibrary`. Placeholder ids in CSV until real ability ids are wired. |
| `feat_pool` | `Array[String]` | Pool of feat ids the character can draw from at odd levels (alongside the class feat pool). Placeholder until the feat system exists. |
| `unlocked_by_default` | `bool` | `true` = available at character creation in fresh saves; `false` = meta-progression unlock. |
| `tags` | `Array[String]` | Optional event hooks (e.g. `["criminal", "urban"]`). Per GAME_BIBLE, backgrounds rarely gate events — tags are a light coupling. |
| `description` | `String` | Short flavor line for character-creation UI. |

### Helpers

```gdscript
func has_tag(tag: String) -> bool
```

---

## BackgroundLibrary

### Data Flow

```
rogue-finder/data/backgrounds.csv   (source of truth — edit here; Godot reads via res://data/)
        │
        ▼  FileAccess.get_csv_line(",")
BackgroundLibrary._cache            (lazy-loaded Dictionary keyed by id)
```

### Public API

```gdscript
## Returns a populated BackgroundData. Never returns null — stub for unknown IDs.
static func get_background(id: String) -> BackgroundData
## Back-compat lookup by display name ("Crook" / "Soldier"). Bridges the gap
## while CombatantData.background and ArchetypeLibrary still use PascalCase
## display strings. Delete when snake_case id migration lands.
static func get_background_by_name(display_name: String) -> BackgroundData
## Returns every loaded background. For character-creation UI / unlock screens.
static func all_backgrounds() -> Array[BackgroundData]
## Clears the cache and re-reads the CSV. Useful after editing the CSV mid-session.
static func reload() -> void
```

### Defined Backgrounds (4 seed rows)

| ID | Name | Starting Ability (placeholder) | Unlocked by Default | Tags |
|----|------|--------------------------------|---------------------|------|
| `crook` | Crook | `pickpocket` | `true` | `criminal`, `urban` |
| `soldier` | Soldier | `shield_bash` | `true` | `military`, `disciplined` |
| `scholar` | Scholar | `identify` | `true` | `academic`, `urban` |
| `baker` | Baker | `rally_feast` | `true` | `commoner`, `urban` |

### Parsing Rules

- First row is the header; column names drive field assignment via `match`.
- Arrays use `|` as the in-cell separator (e.g. `criminal|urban`).
- Booleans are literal `true` / `false` lowercase.
- Empty string → empty array for list-typed columns.
- Unknown columns → `push_warning`, row continues.
- Missing `id` → `push_error`, row skipped.
- Cell count mismatch with header → `push_error`, row skipped.

---

## Dependencies

| Dependent | On |
|-----------|----|
| `BackgroundData` | Nothing (leaf node) |
| `BackgroundLibrary` | `BackgroundData`, `FileAccess` |
| *(none yet — dormant)* | |

### Migration note

`CombatantData.background` and `ArchetypeLibrary` pools currently store PascalCase display strings (`"Crook"`, `"Soldier"`) while `BackgroundLibrary` keys on snake_case ids (`"crook"`). `get_background_by_name()` bridges the gap so the library is callable today. Full snake_case-id migration is deferred until the first real consumer lands (character-creation screen).

---

## Where NOT to Look

- **Character-creation UI is NOT here** — not yet built.
- **Feat system is NOT here** — `feat_pool` is scaffolding only.
- **Event-gating logic is NOT here** — `tags` is a passive list; no consumer reads them yet.

---

## Key Patterns & Gotchas

- **Lazy load** — `_ensure_loaded()` fires on first `get_background()` / `all_backgrounds()` call. Cheap but not free; don't call in tight loops.
- **CSV is the only source** — there is no `const BACKGROUNDS: Dictionary` fallback. If the CSV is missing or malformed, the library is empty.
- **Stub fallback is load-bearing** — unknown ids return a stub with an empty feat pool, not null. Safe to call without nil checks.
- **Dormant-but-ready is intentional** — don't wire it prematurely. The first consumer drives the PascalCase → snake_case migration.
