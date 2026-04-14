# System: Unit Data Resource

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

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

## Current Stat Presets (set in CombatManager3D._make_unit_data)

| Unit Type | HP | Atk | Def | Spd | E.Max | E.Regen | QTE Res |
|-----------|-----|-----|-----|-----|-------|---------|---------|
| Player unit | 20 | 10 | 10 | 3 | 10 | 3 | — |
| Grunt enemy | 15 | 8 | 6 | 2 | 10 | 3 | 0.3 |

These are **placeholder values** — balance TBD after Stage 1.5 playtest.

---

## Usage Pattern

```gdscript
# CombatManager3D creates the data:
var data: UnitData = _make_unit_data("Warrior", true, 20, 10, 10, 3, 0.0)

# Unit3D reads it once in setup():
func setup(unit_data: UnitData, pos: Vector2i) -> void:
    unit_name = unit_data.unit_name
    hp_max = unit_data.hp_max
    current_hp = hp_max
    # ... etc
```

After `setup()`, the Unit no longer references the UnitData object. All live state is copied into the Unit's own fields.

---

## Notes

- `qte_resolution` is only meaningful for enemy units. Player units resolve QTE via the QTEBar input system.
- The Resource pattern enables future `.tres` file authoring (e.g., unique enemy types defined in the editor without code changes).
- No signals, no methods — this is intentional. UnitData is a plain data bag, not a behavior class.
