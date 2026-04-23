# System: HUD System

> Last updated: 2026-04-23 (S29 — StatPanel feat row added; MainMenuScene added)

---

## Status

`HUD.gd` is **no longer used by CombatManager3D**. It remains on disk for the legacy 2D prototype (`CombatScene.tscn`). The 3D system uses two dedicated UI systems instead:

| System | File | Purpose |
|--------|------|---------|
| **UnitInfoBar** | `scripts/ui/UnitInfoBar.gd` | Condensed strip (portrait + bars + stats) shown on single-click |
| **StatPanel** | `scripts/ui/StatPanel.gd` | Full examine window (portrait + scrollable stats) shown on double-click |

---

## UnitInfoBar

**Layer 4.** Shown at the bottom-center of the screen when the mouse **hovers** over any unit. Hidden when the cursor moves off all units. Driven by `CombatManager3D._handle_unit_hover()` on every `InputEventMouseMotion`.

Displays: portrait · name · class · HP bar · Energy bar.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_for` | `(unit: Unit3D) -> void` | Populate and show the bar for this unit |
| `refresh` | `(unit: Unit3D) -> void` | Update HP/Energy bars without repopulating all fields |
| `hide_bar` | `() -> void` | Hide the info strip |

---

## StatPanel

**Layer 8.** Opened on **double-click** of any unit. Closed by the **✕ button** or **ESC**.

Displays: portrait · name · archetype · **kindred** · **kindred feat name** · background · team · all attributes · derived stats · equipment · abilities. No artwork section. Content is scrollable.

Feat name resolved at display time via `KindredLibrary.get_feat_name(d.kindred)` — not stored on `CombatantData`. Speed label reads `(1 + kindred)` since S29.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_for` | `(unit: Unit3D) -> void` | Populate and show the panel for this unit |
| `hide_panel` | `() -> void` | Hide the examine window |

---

## CombatActionPanel

**Layer 12.** Right-side slide-in panel shown when any unit is clicked. Slides in from the right edge (~0.15s cubic tween); slides out when closed. Height auto-fits content.

**Player units:** fully interactive. **Enemy units:** read-only (abilities non-clickable, no consumable/stride sections).

Layout (top to bottom):
- Unit name (centered, large)
- **Kindred** (centered, small, muted blue-grey — shown for both player and enemy units)
- Portrait (centered, `icon.svg` placeholder)
- HP bar + EN bar with color-coded fill and numeric label
- Status effects (BBCode colored chips)
- "Abilities" section: 2×2 grid of buttons; each shows `Name / Cost · Shape`
- Consumable button — hidden for enemies; hidden when slot empty; greyed when `has_acted`
- Stride hint — hidden for enemies; shows `"Click to stride · N tiles left"` or `"No movement remaining"`
- Dialogue stub box (reserved for future combat banter — shows `"..."`)

Ability/consumable buttons show a floating tooltip on hover (positioned to the left of the panel): name, cost, shape, range, description.

Consumable use does **not** close the panel — `CombatManager3D` calls `open_for()` again after applying the effect to refresh content in-place.

Lives in `scripts/ui/CombatActionPanel.gd` + `scenes/ui/CombatActionPanel.tscn`.

### Public API

| Method / Property | Signature | Purpose |
|--------|-----------|---------|
| `open_for` | `(unit: Unit3D, camera: Camera3D) -> void` | Populate and slide in; if already open, kills any close tween and updates content in-place (`camera` kept for signature compat — unused) |
| `close` | `() -> void` | Slide out and hide |
| `refresh` | `(unit: Unit3D) -> void` | Update bars + status + consumable + stride without full rebuild (used mid-combat) |
| `current_unit` | `Unit3D` (read-only property) | The unit currently displayed; `null` when panel is closed |

### Signals

| Signal | Args | Fired when |
|--------|------|-----------|
| `ability_selected` | `ability_id: String` | Player clicks an ability button |
| `consumable_selected` | — | Player clicks the consumable button |

### Gotchas

- **Tween guard:** `open_for()` kills any in-flight tween before starting a new one. Calling `open_for()` while sliding out cancels the close and slides back in cleanly.
- **Ability buttons are rebuilt** (`queue_free` + recreate) on every `open_for()` call. Do not hold external references to individual buttons.
- **Consumable signal connected once** in `_build_ui()` using `_current_unit` in the handler — no repeated connections on refresh.
- **HP fill uses `anchor_right`** (not pixel size). The bar fill is 0–1 anchored inside a `Control` wrapper, so it scales automatically with the panel width.
- **No save state:** this system is pure presentation. No state survives scene transitions.

---

## EndCombatScreen

**Layer 15.** Shown on **combat victory only**. Full-screen semi-transparent overlay. Built in code; no scene file.

The defeat path bypasses this system entirely — `CombatManager3D._end_combat(false)` calls `_capture_run_summary()` → `_show_run_end_overlay()` → `change_scene_to_file("res://scenes/ui/RunSummaryScene.tscn")`. See `combat_manager.md`.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_victory` | `(reward_items: Array) -> void` | Displays VICTORY header + 3 reward buttons |

Victory flow: 3 reward buttons (item name + description). Clicking one:
1. Calls `GameState.add_to_inventory(item)` (via `has_method()` guard).
2. Disables all reward buttons, highlights chosen with `✓` prefix.
3. Appends `GameState.current_combat_node_id` to `GameState.cleared_nodes` (if not already present).
4. If the defeated node's type is `"BOSS"` (checked via `GameState.node_types.get(...)`), resets `GameState.threat_level = 0.0`.
5. Calls `GameState.save()`.
6. Calls `_return_to_map()` → `change_scene_to_file("res://scenes/map/MapScene.tscn")`.

There is no intermediate "Onward..." step — reward selection is the final input.

The constant is `MAP_SCENE_PATH`; the method is `_return_to_map()` (renamed from `_reload_combat()` in Feature 3).

Reward items come from `RewardGenerator.roll(3)` — plain Dicts with keys `id`, `name`, `description`, `item_type`.

---

## RewardGenerator

Static utility class (`scripts/globals/RewardGenerator.gd`). Builds a shuffled pool from all `EquipmentLibrary` items + all `ConsumableLibrary` items and returns `count` distinct entries as plain Dictionaries.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `roll` | `(count: int) -> Array` | Returns `count` random distinct reward Dicts |

---

## MainMenuScene

**Entry point.** `main.tscn` now instances `MainMenuScene.tscn` (was `MapScene.tscn` directly). Lives at `scenes/ui/MainMenuScene.tscn` + `scripts/ui/MainMenuManager.gd`.

Displays: title · subtitle · three buttons (Continue, Start New Run, Quit).

- **Continue** — disabled when `user://save.json` does not exist. Calls `GameState.load_save()` then `change_scene_to_file(MAP_SCENE_PATH)`.
- **Start New Run** — calls `GameState.delete_save()` + `GameState.reset()` then transitions to MapScene.
- **Quit** — `get_tree().quit()`.

`RunSummaryManager._on_main_menu()` now routes to `MainMenuScene.tscn` (was silently calling `_on_new_run()`).

### Gotchas
- **No CanvasLayer child nodes** — all UI built in `_ready()` / `_build_ui()`. `main.tscn` is a `Node3D` root instancing the scene; the CanvasLayer sits inside.
- **Continue button state is set once at `_ready()`** — if a save is written during the same session, the button state won't update without a scene reload (not a real issue in normal flow).

---

## Legacy HUD.gd

`scripts/ui/HUD.gd` and `scenes/ui/HUD.tscn` are kept for `CombatManager.gd` (2D). Do not delete until the 2D prototype is retired.

Duck-typed `refresh(player_units, enemy_units)` still works for 2D units.
