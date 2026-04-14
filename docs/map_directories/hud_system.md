# System: HUD System

> Last updated: 2026-04-14 (Session 2 — Stage 1.5)

---

## Purpose

The HUD displays **HP and energy status bars** for all 6 combatants (3 player, 3 enemy) as ASCII-style text bars. It sits in a CanvasLayer so it always renders over the 3D scene.

The HUD is **duck-typed** — its `refresh()` method accepts any array of objects that have `.unit_name`, `.current_hp`, `.hp_max`, `.current_energy`, `.energy_max`, and `.is_alive` fields. This means it works with both `Unit` (2D) and `Unit3D` without any explicit type dependency.

---

## Core Nodes / Scripts

| File | Scene | Role |
|------|-------|------|
| `scripts/ui/HUD.gd` | `scenes/ui/HUD.tscn` | ASCII HP/energy display |

`.tscn` is minimal. All Label nodes are built in `_build_ui()`.

---

## Dependencies

None. HUD has no runtime imports or node dependencies. It reads duck-typed unit objects passed in by CombatManager.

---

## Signals Emitted

None.

---

## Public Methods

| Method | Signature | Purpose |
|--------|-----------|---------|
| `refresh` | `(player_units: Array, enemy_units: Array) -> void` | Rebuilds all display cards from current unit state. Call after any HP/energy change. |

---

## Display Format

Each unit card is a `Label` node containing a multi-line string like:

```
[Warrior]
HP  [████████░░] 16/20
EN  [██████░░░░] 6/10
```

Dead units show `(dead)` in place of bars.

---

## ASCII Bar Formula (`_mini_bar`)

```
filled = round(current / maximum * width)
bar = "█" × filled + "░" × (width - filled)
```

Default `width` = 10 characters.

---

## Layout

- **Player cards:** anchored bottom-left, stacked vertically, 3 cards
- **Enemy cards:** anchored bottom-right, stacked vertically, 3 cards
- CanvasLayer layer = 5 (below QTEBar at layer 10)

---

## Notes

- `refresh()` iterates up to 3 player units and 3 enemy units. If an array is shorter than 3 (unit died and was removed), the remaining cards show empty.
- CombatManager3D calls `_refresh_hud()` which calls `hud.refresh(player_units, enemy_units)` — this is called after every meaningful state change (turn start, damage applied, unit death, combat end).
- The duck-typing approach was a deliberate decision to avoid a separate HUD rewrite when upgrading from 2D to 3D units.
