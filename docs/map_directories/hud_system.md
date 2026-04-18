# System: HUD System

> Last updated: 2026-04-18 (Session 13 grooming — EndCombatScreen no-Onward flow)

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

## EndCombatScreen

**Layer 15.** Shown when combat ends (victory or defeat). Full-screen semi-transparent overlay. Built in code; no scene file.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_victory` | `(reward_items: Array) -> void` | Displays VICTORY header + 3 reward buttons |
| `show_defeat` | `() -> void` | Displays DEFEAT header + "Return to Map" button |

Victory flow: 3 reward buttons (item name + description). Clicking one disables all reward buttons, highlights the chosen button with a `✓` prefix, appends `GameState.current_combat_node_id` to `GameState.cleared_nodes` (if not already present), calls `GameState.save()`, then immediately calls `_return_to_map()` → `change_scene_to_file("res://scenes/map/MapScene.tscn")`. There is no intermediate "Onward..." step — reward selection is the final input.

Defeat flow: single "Return to Map" button → `_return_to_map()` → `MapScene.tscn`. The node is **not** added to `cleared_nodes` on defeat, so it remains re-enterable. Subtitle text: *"Return to the map and try again."*

Both paths return to the map, not combat. The constant is `MAP_SCENE_PATH`; the method is `_return_to_map()` (renamed from `_reload_combat()` in Feature 3).

Reward items come from `RewardGenerator.roll(3)` — plain Dicts with keys `id`, `name`, `description`, `item_type`.

---

## RewardGenerator

Static utility class (`scripts/globals/RewardGenerator.gd`). Builds a shuffled pool from all `EquipmentLibrary` items + all `ConsumableLibrary` items and returns `count` distinct entries as plain Dictionaries.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `roll` | `(count: int) -> Array` | Returns `count` random distinct reward Dicts |

---

## Legacy HUD.gd

`scripts/ui/HUD.gd` and `scenes/ui/HUD.tscn` are kept for `CombatManager.gd` (2D). Do not delete until the 2D prototype is retired.

Duck-typed `refresh(player_units, enemy_units)` still works for 2D units.
