# System: HUD System

> Last updated: 2026-04-14 (Session 3 — ActionMenu added)

---

## Status

`HUD.gd` is **no longer used by CombatManager3D**. It remains on disk for the legacy 2D prototype (`CombatScene.tscn`). The 3D system uses two dedicated UI systems instead:

| System | File | Purpose |
|--------|------|---------|
| **UnitInfoBar** | `scripts/ui/UnitInfoBar.gd` | Condensed strip (portrait + bars + stats) shown on single-click |
| **StatPanel** | `scripts/ui/StatPanel.gd` | Full examine window (portrait + scrollable stats) shown on double-click |

---

## UnitInfoBar

**Layer 4.** Shown at the bottom-center of the screen when any unit is clicked.

Displays: portrait · name · class · HP bar · Energy bar. (ATK/DEF/SPD removed — attack varies per ability; those stats belong in the StatPanel examine view.)

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_for` | `(unit: Unit3D) -> void` | Populate and show the bar for this unit |
| `refresh` | `(unit: Unit3D) -> void` | Update HP/Energy bars without repopulating all fields |
| `hide_bar` | `() -> void` | Hide the info strip |

---

## StatPanel

**Layer 8.** Opened on **double-click** of any unit. Closed by the **✕ button** or **ESC**.

Displays: portrait · name · archetype · background · team · all attributes · derived stats · equipment · abilities. No artwork section. Content is scrollable.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_for` | `(unit: Unit3D) -> void` | Populate and show the panel for this unit |
| `hide_panel` | `() -> void` | Hide the examine window |

---

## ActionMenu

**Layer 12.** Shown when a player unit is selected. Closed on deselect, ESC, or when an action is chosen.

D-pad layout: 4 ability buttons (top / right / bottom / left, 80×80 px each) surrounding a slightly smaller consumable button (64×64 px, center). Positioned at the selected unit's projected screen coordinates.

Buttons are greyed out and disabled when:
- Ability slot is empty (`""`)
- `unit.has_acted == true`
- `unit.current_energy < ability.energy_cost`
- `unit.data.consumable == ""`  (consumable button only)

Hover shows a tooltip with ability name, tags, energy cost, and description.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `open_for` | `(unit: Unit3D, camera: Camera3D) -> void` | Populate, position, and show |
| `close` | `() -> void` | Hide the menu |

### Signals

| Signal | Args | Fired when |
|--------|------|-----------|
| `ability_selected` | `ability_id: String` | Player clicks an ability button |
| `consumable_selected` | — | Player clicks the consumable button |

---

## Legacy HUD.gd

`scripts/ui/HUD.gd` and `scenes/ui/HUD.tscn` are kept for `CombatManager.gd` (2D). Do not delete until the 2D prototype is retired.

Duck-typed `refresh(player_units, enemy_units)` still works for 2D units.
