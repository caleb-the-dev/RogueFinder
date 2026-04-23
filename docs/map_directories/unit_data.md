# System: Unit Data Resource (Legacy 2D)

> Last updated: 2026-04-14 (Session 3 — marked legacy)
> **SUPERSEDED** for the 3D system by `CombatantData` + `ArchetypeLibrary`.
> `UnitData` is kept for `Unit.gd` (2D) and its test suite only. Do not use for new work.

---

## Purpose

`UnitData` is a **pure data container** — a Godot `Resource` subclass with `@export` fields for every unit stat. It is the only formal data contract between the Combat Manager (which constructs stat records) and Unit3D (which reads them in `setup()`).

Using a Resource (rather than a Dictionary or raw arguments) means stats can eventually be stored as `.tres` files and edited in the Godot inspector without code changes.

---

## Core File

| File | Role |
|------|------|
| `resources/UnitData.gd` | Stat resource — `@export` fields only, no methods |

---

## Dependencies

None. `UnitData` is a leaf node with no imports.

---

## Fields

| Field | Type | Placeholder Value | Purpose |
|-------|------|-------------------|---------|
| `unit_name` | `String` | `""` | Display name (shown on Unit label) |
| `is_player_unit` | `bool` | `false` | Determines team color (blue vs red) and AI behavior |
| `hp_max` | `int` | `0` | Maximum hit points |
| `speed` | `int` | `0` | Movement range in cells (Manhattan distance) |
| `attack` | `int` | `0` | Attack stat — used in damage formula |
| `defense` | `int` | `0` | Defense stat — used in damage formula |
| `energy_max` | `int` | `0` | Maximum energy pool |
| `energy_regen` | `int` | `0` | Energy restored at turn start |
| `qte_resolution` | `float` | `0.0` | Enemy-only: simulated QTE accuracy (0.0–1.0) |

---

## Current Stat Presets

The 3D system uses `ArchetypeLibrary.create()` → `CombatantData` for all stat seeding. No `_make_unit_data`-style helper exists anywhere anymore. `UnitData` instances for the legacy 2D tests are constructed inline in those test files.

---

## Usage Pattern (2D legacy path)

`Unit.gd` reads `UnitData` once in `setup()` and copies all live state into its own fields. After `setup()` the unit no longer references the resource. Preserved for backwards compatibility with `tests/test_unit.gd` and other 2D test scaffolding.

---

## Notes

- `qte_resolution` is only meaningful for enemy units. Player units resolve QTE via the QTEBar input system.
- The Resource pattern enables future `.tres` file authoring (e.g., unique enemy types defined in the editor without code changes).
- No signals, no methods — this is intentional. UnitData is a plain data bag, not a behavior class.
