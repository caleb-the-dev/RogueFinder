# System: HUD System

> Last updated: 2026-04-24 (B4 — CharacterCreationScene live preview panel)

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
- **Start New Run** — calls `GameState.delete_save()` + `GameState.reset()` then transitions to **CharacterCreationScene** (not MapScene directly — B2 wired this 2026-04-24).
- **Quit** — `get_tree().quit()`.

`RunSummaryManager._on_main_menu()` now routes to `MainMenuScene.tscn` (was silently calling `_on_new_run()`).

### Gotchas
- **No CanvasLayer child nodes** — all UI built in `_ready()` / `_build_ui()`. `main.tscn` is a `Node3D` root instancing the scene; the CanvasLayer sits inside.
- **Continue button state is set once at `_ready()`** — if a save is written during the same session, the button state won't update without a scene reload (not a real issue in normal flow).

---

## CharacterCreationScene

Lives at `scenes/ui/CharacterCreationScene.tscn` + `scripts/ui/CharacterCreationManager.gd`.

**Reached via:** `MainMenuManager._on_new_run()` → `change_scene_to_file(CREATION_SCENE_PATH)` after `delete_save()` + `reset()`. `GameState.party` is `[]` on entry.

**On exit:** appends the built PC to `GameState.party`, then routes to `MapScene`. `MapManager._ready()` calls `GameState.init_party()` as a safety fallback — the guard fires immediately because `party` is already non-empty.

### What it does (B2 + B4)

Single-screen character creation. Player picks name, kindred, class, background, and portrait. On Confirm, builds a `CombatantData` from scratch (not via `ArchetypeLibrary.create()`) and appends it to `GameState.party`.

Layout (all built in `_ready()`):
- `LineEdit` (name) + 🎲 button (random name from active kindred's pool; "Unit" fallback on empty pool)
- Four slot-wheel dial columns: Kindred · Class · Background · Portrait
- **Preview panel** (B4) — read-only `PanelContainer` below the dials showing HP range, Speed, Stats range, class ability name + description, background ability name + description, kindred feat name. Updates live from `_calc_preview()` on every dial change.
- "Begin Run" confirm button

Each dial column shows the current selection (20 px, light highlight panel) flanked by ghost neighbours at 25% opacity / 12 px. All children built in `_build_ui()`; centered via a full-rect `CenterContainer`.

### Public API / Key Methods

| Method | Notes |
|--------|-------|
| `_ready()` | Calls `_load_data()` then `_build_ui()` |
| `_load_data()` | Populates parallel id/display arrays from all four libraries |
| `_build_ui()` | Constructs name row + four dial columns + confirm button |
| `_build_text_dial(header, ids, display, on_select)` | Returns a `PanelContainer` drum column with ▲/▼ and three visible text rows (prev ghost, current highlighted, next ghost). `idx` stored in a single-element `Array[int]` — required because GDScript 4 closures capture locals by value, so a plain `int` would reset to 0 on every press. |
| `_build_portrait_dial()` | Same drum column shape but shows `TextureRect` (icon.svg) for current + smaller greyed icons for prev/next. Arrows disabled (1 portrait option until art ships). |
| `_build_preview_panel()` | Returns a `PanelContainer` (drum style) holding the live preview — HP / Speed / Stats strip, class ability name+desc, background ability name+desc, kindred feat name. Stores eight label refs as instance vars for `_calc_preview()` to push to. |
| `_make_stat_label(text)` | Small helper — one-line `Label` with font size 14 used for the preview panel's stat strip. |
| `_on_dice_name()` | Reads active kindred's name pool via `KindredLibrary.get_name_pool()`; falls back to "Unit" on empty pool |
| `_on_confirm()` | Calls `_build_pc()`, appends to `GameState.party`, transitions to `MapScene` |
| `_calc_preview()` | Returns a `Dictionary` of preview values AND pushes them into the eight preview labels. Reads `_kindred_idx` / `_class_idx` / `_bg_idx`. `hp_min = 10 + kindred_hp_bonus + 6`, `hp_max = 10 + kindred_hp_bonus + 24`, `speed = 1 + kindred_speed_bonus`. Called from `_on_pick_changed()` on every dial spin + once from `_build_ui()` to seed initial values. Signature stays `-> Dictionary` so a future `CharacterCreationPreview` component can consume the same data without a live UI. |
| `static _build_pc(char_name, kindred_id, class_id, bg_id, _portrait_id)` | Builds `CombatantData` field-by-field from picks. **Static** so unit tests call it without a live scene. See _build_pc details below. |

### _build_pc field assignments

| Field | Source |
|-------|--------|
| `archetype_id` | `"RogueFinder"` (fixed) |
| `is_player_unit` | `true` |
| `character_name` | name input; `""` → `"Unit"` |
| `kindred` | kindred_id (e.g. `"dwarf"`) |
| `kindred_feat_id` | `KindredLibrary.get_feat_id(kindred_id)` |
| `unit_class` | `ClassLibrary.get_class_data(class_id).display_name` |
| `background` | bg_id (snake_case ID — differs from ally background format which stores PascalCase display strings) |
| `abilities` | `[class.starting_ability_id, bg.starting_ability_id, "", ""]` — always 4 slots |
| `ability_pool` | class + bg ability ids, deduped |
| `strength/dex/cog/wil/vit` | `randi_range(1, 4)` (placeholder) |
| `armor_defense` | `randi_range(4, 8)` |
| `qte_resolution` | `0.5` (fixed — player doesn't auto-resolve) |
| `current_hp` | `hp_max` (computed property) |
| `current_energy` | `energy_max` (computed property) |
| `portrait` | Not set — remains `null` (all portraits are icon.svg placeholder; serialization deferred to art pass) |

### Instance Variables

| Var | Type | Notes |
|-----|------|-------|
| `_kindred_ids` | `Array[String]` | Parallel to kindred OptionButton/dial items |
| `_class_ids` | `Array[String]` | |
| `_class_display` | `Array[String]` | Display names for class dial |
| `_bg_ids` | `Array[String]` | |
| `_bg_display` | `Array[String]` | `BackgroundData.background_name` (not `display_name`) |
| `_portrait_ids` | `Array[String]` | Loaded but portrait dial always uses index 0 |
| `_name_field` | `LineEdit` | |
| `_kindred_idx` | `int` | Current kindred dial selection index |
| `_class_idx` | `int` | Current class dial selection index |
| `_bg_idx` | `int` | Current background dial selection index |
| `_preview_hp_lbl` | `Label` | Preview strip — "HP: min–max" |
| `_preview_speed_lbl` | `Label` | Preview strip — "Speed: N" |
| `_preview_stats_lbl` | `Label` | Preview strip — fixed "Stats: 1–4" (all core stats roll 1–4 at creation) |
| `_preview_class_name` | `Label` | "Class Ability — <name>" row |
| `_preview_class_desc` | `Label` | Class ability description (autowrap, 75% opacity) |
| `_preview_bg_name` | `Label` | "Background Ability — <name>" row |
| `_preview_bg_desc` | `Label` | Background ability description (autowrap, 75% opacity) |
| `_preview_feat_lbl` | `Label` | "Kindred Feat — <name>" row (no description per B4 spec) |

### Known Inconsistency

`CombatantData.background` stores the snake_case `background_id` for PC-created characters but PascalCase display strings for ally characters created by `ArchetypeLibrary.create()`. `BackgroundLibrary.get_background_by_name()` bridges old code. Migration deferred.

### Dependencies

- `KindredLibrary` — name pool, feat id, feat name, speed bonus, hp bonus
- `ClassLibrary` — class list, starting ability, display name
- `BackgroundLibrary` — background list, starting ability
- `PortraitLibrary` — portrait list (used for id only; texture not set at v1)
- `AbilityLibrary` — resolves class + background starting abilities for preview name/description (B4)
- `GameState` — appends PC to `GameState.party` on confirm
- `CombatantData` — constructed by `_build_pc()`

### Tests

`tests/test_character_creation.gd` / `test_character_creation.tscn` — 9 unit tests covering `_build_pc()` correctness (all headless; no live scene required). B4 adds no new tests — preview is pure derived display (reads library data, pushes to labels) and has no logic worth testing headlessly. Run via:
```
godot --headless --path rogue-finder res://tests/test_character_creation.tscn
```

### Gotchas

- **`_build_pc()` is static** — keeps unit tests simple. Do not add instance-var access inside it.
- **Closure int capture** — `_build_text_dial()` uses `Array[int]` (single element) as a mutable index. Replacing with a plain `int` will break cycling (resets to 0 on every button press).
- **Portrait not serialized** — `CombatantData.portrait` is `Texture2D` (not JSON-serializable). All portrait options are `icon.svg` at v1 so the loss is invisible. When real art ships: add `portrait_id: String` to `CombatantData`, serialize in `_serialize_combatant()` / `_deserialize_combatant()`, restore texture on load.
- **Preview signature reserved** — `_calc_preview() -> Dictionary` returns the derived preview data even though the inline UI pushes values into labels directly. Signature is preserved so a future `CharacterCreationPreview` component can consume the dict without a live UI (e.g. for tooltip previews on hover, or headless tests if formulas grow complex). Do not collapse it to `-> void`.
- **Preview nil-guard** — `_calc_preview()` checks `_preview_hp_lbl != null` before pushing label text. This allows calling `_calc_preview()` from static/test contexts without crashing (labels only exist after `_build_preview_panel()` runs).
- **B4 preview is read-only** — no interactive elements. Preview labels are driven entirely by dial state + library lookups; `_build_pc()` still sources stats from `rng.randi_range()` at confirm time (preview shows range, not the actual rolled values).

### Recent Changes

| Date | Change |
|---|---|
| 2026-04-24 | B4 — Live preview panel. Read-only `PanelContainer` rendered below the dial row showing HP range (`10 + kindred_hp + [6..24]`), Speed (`1 + kindred_speed`), Stats (fixed "1–4"), class ability name+description, background ability name+description, and kindred feat name. `_calc_preview()` fleshed out from stub — still returns `Dictionary` but now also pushes values into eight label refs stored as instance vars. New helpers `_build_preview_panel()` and `_make_stat_label()`. `AbilityLibrary` added as a dependency. No new tests (pure derived display). Existing 9 headless tests untouched. |
| 2026-04-24 | B1+B2 — Character creation scene added. `MainMenuManager._on_new_run()` now routes to `CharacterCreationScene` instead of `MapScene`. `_build_pc()` builds `CombatantData` from picks. Slot-wheel dial columns with ghost neighbours (▲/▼, prev/next at 25% opacity). Portrait dial shows icon.svg placeholder; portrait picker hidden until real art ships. 9 unit tests green. |

---

## Legacy HUD.gd

`scripts/ui/HUD.gd` and `scenes/ui/HUD.tscn` are kept for `CombatManager.gd` (2D). Do not delete until the 2D prototype is retired.

Duck-typed `refresh(player_units, enemy_units)` still works for 2D units.
