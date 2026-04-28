# System: HUD System

> Last updated: 2026-04-28 (Pause Menu — PauseMenuManager autoload layer 26, SettingsStore autoload, Archetypes Log sub-panel)

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

Displays: portrait · name · archetype · kindred · background · team · live state · attributes · derived stats · equipment · abilities · **feats**. No artwork section. Content is scrollable.

Sections (in order): Identity → Live State → Attributes → Derived Stats → Equipment → Abilities → **Feats**. Derived stats section shows: Attack, **P.Def** (`physical_defense`), **M.Def** (`magic_defense`), Speed, E.Regen; and QTE Res for non-player units. Feats appear as a `[b]── Feats ──[/b]` RTL section immediately after Abilities, with numbered entries. Speed label reads `(1 + kindred)`.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_for` | `(unit: Unit3D) -> void` | Populate and show the panel for this unit |
| `hide_panel` | `() -> void` | Hide the examine window |

### Recent Changes (StatPanel)

| Date | Change |
|------|--------|
| 2026-04-27 | **Dual armor.** Derived stats section replaced single `Defense` line with two lines: `P.Def: X (physical armor)` + `M.Def: X (magic armor)`, reading `d.physical_defense` + `d.magic_defense`. |
| 2026-04-24 | **Slice 2.** Feats section added to the RTL after Abilities (`── Feats ──` bold header, `1. <FeatName>` numbered entry). Resolved via `FeatLibrary.get_feat(d.kindred_feat_id)` — no longer calls `KindredLibrary.get_feat_name()`. `FeatLibrary` is now a dependency. |

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
- **⊕ Recruit button** — below the 2×2 grid; visible **only for the Pathfinder (party[0])**; hidden for all other units including enemies; greyed (disabled) when: energy < 3, `has_acted`, or `GameState.bench.size() >= GameState.BENCH_CAP`; tooltip shows cost/range/mechanic; emits `recruit_selected` when clicked
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
| `recruit_selected` | — | Pathfinder clicks the ⊕ Recruit button; panel closes before emitting |

### Gotchas

- **Tween guard:** `open_for()` kills any in-flight tween before starting a new one. Calling `open_for()` while sliding out cancels the close and slides back in cleanly.
- **Ability buttons are rebuilt** (`queue_free` + recreate) on every `open_for()` call. Do not hold external references to individual buttons.
- **Recruit button persists** — unlike ability buttons, `_recruit_btn` is created once in `_build_ui()` and shown/hidden via `_refresh_recruit()`. Do not `queue_free` it.
- **Recruit button const mirrors CombatManager3D** — `_RECRUIT_ENERGY_COST: int = 3` is duplicated in CombatActionPanel. If the recruit energy cost changes, update both constants.
- **Consumable signal connected once** in `_build_ui()` using `_current_unit` in the handler — no repeated connections on refresh.
- **HP fill uses `anchor_right`** (not pixel size). The bar fill is 0–1 anchored inside a `Control` wrapper, so it scales automatically with the panel width.
- **No save state:** this system is pure presentation. No state survives scene transitions.

### Recent Changes (CombatActionPanel)

| Date | Change |
|------|--------|
| 2026-04-28 | **Follower Slice 4.** `_refresh_recruit()` Pathfinder check extended: also returns `true` when `GameState.test_room_kind == "recruit_test"` and `unit.data.archetype_id == "RogueFinder"` — enables the Recruit button in the recruit test room where `GameState.party` is empty. |
| 2026-04-28 | **Follower Slice 3.** `recruit_selected` signal added. `_recruit_btn: Button` built once in `_build_ui()`, placed below the 2×2 ability grid. `_refresh_recruit(unit)` method handles show/hide and enable/disable; called from `_rebuild_ability_grid()` and `refresh()`. Button is Pathfinder-only (compares `unit.data == GameState.party[0]`). Greys out if energy < 3, `has_acted`, or bench full. Tooltip: "Attempt to recruit a nearby enemy. 3 Energy · Range 3 · Chance depends on target HP and your party's Willpower." Panel closes before emitting `recruit_selected` (same pattern as `ability_selected`). |
| 2026-04-23 | **Kindred label.** Small muted blue-grey label added between name and portrait for both player and enemy views. |

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

## MainMenuScene + CharacterCreationScene

> Moved to [`character_creation.md`](character_creation.md).

---

## PauseMenu

**Layer 26.** Global pause overlay registered as an autoload (`PauseMenu`). Active in all gameplay scenes (MapScene, CombatScene3D, BadurgaScene, CharacterCreationScene). Blocked in MainMenuScene and RunSummaryScene via a scene-file path gate.

**Architecture decision:** Implemented as a CanvasLayer autoload rather than a per-scene instance so it works across all 4+ gameplay scenes without boilerplate. The tradeoff vs per-scene: less control over scene-specific behavior, but the gate function handles the two excluded scenes cleanly.

**SettingsStore:** User preferences live in a separate `SettingsStore` autoload (`scripts/globals/SettingsStore.gd`) persisted to `user://settings.json`. This is distinct from `user://save.json` (run state) so fullscreen and volume prefs survive run deletion. Tradeoff vs folding settings into PauseMenuManager: adds one autoload but keeps settings accessible anywhere without coupling them to the menu lifecycle.

**ESC conflict resolution:** CM3D only marks ESC as handled when it actually does something (cancel recruit mode, deselect a unit). When nothing is selected and mode is IDLE, ESC falls through to PauseMenu. StatPanel ESC is handled inside CM3D's guard block (all input consumed while panel is visible) — PauseMenu never sees those events.

### Scene / Script

| File | Role |
|------|------|
| `scenes/ui/PauseMenuScene.tscn` | Minimal (root CanvasLayer + PauseMenuManager script) |
| `scripts/ui/PauseMenuManager.gd` | Full UI built in `_ready()`; sub-panel switching; ESC handler |
| `scripts/globals/SettingsStore.gd` | Autoload; reads/writes `user://settings.json` |

### Signals

| Signal | When emitted |
|--------|-------------|
| `menu_opened` | On `open_menu()` |
| `menu_closed` | On `close_menu()` |
| `settings_changed` | Any settings slider or toggle changed |
| `archetype_log_opened` | On navigating to the Archetypes Log sub-panel |

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `open_menu` | `() -> void` | Show overlay, pause tree, switch to main buttons |
| `close_menu` | `() -> void` | Hide overlay, unpause tree |
| `_scene_name_is_pauseable` | `static (path: String) -> bool` | Returns false for MainMenuScene and RunSummaryScene |

### Sub-Panels

| Panel | Contents |
|-------|---------|
| **Main** | Resume · Settings · Guide · Archetypes Log · Main Menu · Exit Game |
| **Settings** | ← Back · Fullscreen toggle (calls `DisplayServer.window_set_mode`) · Master/Music/SFX sliders (visible + draggable; audio bus wiring deferred) |
| **Guide** | ← Back · "Guide coming soon." stub |
| **Archetypes Log** | ← Back · Scrollable list of cards per `GameState.encountered_archetypes`; RogueFinder player archetype excluded; empty state shown when none encountered |

### Archetypes Log

Populated from `GameState.encountered_archetypes` on every open. Rebuilt by `_rebuild_log_list()`. Each card shows: archetype name (title-cased from id), kindred · class, and notes text from `ArchetypeData.notes` (parsed from `archetypes.csv`). RogueFinder is always filtered from display — it is the player template, not a collectable creature.

**Recording:** `GameState.record_archetype(id)` is called in `CombatManager3D._setup_units()` for each enemy when combat begins. Encounter is recorded even if the player flees (matches the "encountered" framing). A `TODO` comment marks the recruit site in `GameState.record_archetype()` for future wiring.

### Recent Changes (PauseMenu)

| Date | Change |
|------|--------|
| 2026-04-28 | **Pause Menu + Archetypes Log.** Initial implementation. Layer 26 CanvasLayer autoload. ESC gate, fullscreen toggle, volume sliders (placeholder), guide stub, Archetypes Log panel. SettingsStore autoload. `GameState.encountered_archetypes` + `record_archetype()`. `ArchetypeData.notes` field parsed. CM3D ESC handler fixed to not consume when idle. 8 headless tests. |

---

## Legacy HUD.gd

`scripts/ui/HUD.gd` and `scenes/ui/HUD.tscn` are kept for `CombatManager.gd` (2D). Do not delete until the 2D prototype is retired.

Duck-typed `refresh(player_units, enemy_units)` still works for 2D units.
