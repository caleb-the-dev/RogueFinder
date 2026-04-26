# System: Main Menu + Character Creation

> Last updated: 2026-04-26 (_build_pc sets feat_ids instead of kindred_feat_id)

---

## Status

| System | File | Status |
|--------|------|--------|
| MainMenuScene | `scripts/ui/MainMenuManager.gd` + `scenes/ui/MainMenuScene.tscn` | ✅ Active |
| CharacterCreationScene | `scripts/ui/CharacterCreationManager.gd` + `scenes/ui/CharacterCreationScene.tscn` | ✅ Active (B2 + B4; 11 tests) |

---

## MainMenuScene

**Entry point.** `main.tscn` instances `MainMenuScene.tscn`. Lives at `scenes/ui/MainMenuScene.tscn` + `scripts/ui/MainMenuManager.gd`.

Displays: title · subtitle · four buttons (Continue, Start New Run, Test New Run, Quit).

- **Continue** — disabled when `user://save.json` does not exist. Calls `GameState.load_save()` then `change_scene_to_file(MAP_SCENE_PATH)`.
- **Start New Run** — just transitions to **CharacterCreationScene**. Save is **not** deleted here — the player can hit Back on the creation screen without losing an existing run. Commit + reset happen in `CharacterCreationManager._on_confirm()`.
- **Test New Run** (dev shortcut) — calls `delete_save()` + `reset()` then seeds `GameState.party` with three fully-randomized PCs (random kindred, class, background, portrait, and name pulled from the chosen kindred's name pool) via `CharacterCreationManager._build_pc()`. Transitions directly to `MapScene`, bypassing character creation. Muted purple tint to signal dev affordance.
- **Quit** — `get_tree().quit()`.

`RunSummaryManager._on_main_menu()` routes to `MainMenuScene.tscn`.

### Gotchas
- **No CanvasLayer child nodes** — all UI built in `_ready()` / `_build_ui()`. `main.tscn` is a `Node3D` root instancing the scene; the CanvasLayer sits inside.
- **Continue button state is set once at `_ready()`** — if a save is written during the same session, the button state won't update without a scene reload (not a real issue in normal flow).
- **Test New Run depends on `CharacterCreationManager._build_pc()`** — the static builder is the single source of truth for PC construction. If you change `_build_pc()`'s signature, update `_on_test_new_run()` too. Kept static so this shortcut does not need to instance the creation scene.

---

## CharacterCreationScene

Lives at `scenes/ui/CharacterCreationScene.tscn` + `scripts/ui/CharacterCreationManager.gd`.

**Reached via:** `MainMenuManager._on_new_run()` → `change_scene_to_file(CREATION_SCENE_PATH)`. No state is touched on entry — the player can abort with the Back button without nuking an existing save.

**On exit (Begin Run):** `_on_confirm()` calls `GameState.delete_save()` + `GameState.reset()`, builds the PC via `_build_pc(..., _rolled_stats)`, appends to `GameState.party`, then routes to `MapScene`. `MapManager._ready()` calls `GameState.init_party()` as a safety fallback — the guard fires immediately because `party` is already non-empty.

**On exit (Back):** `_on_back()` simply changes scene to `MainMenuScene`. No state touched.

### What it does (B2 + B4)

Single-screen character creation. Player picks name, kindred, class, background, and portrait. On Confirm, builds a `CombatantData` from scratch (not via `ArchetypeLibrary.create()`) and appends it to `GameState.party`.

Layout — two-column body inside a full-rect `MarginContainer` (40 px margins). `HBoxContainer` splits into a 3:2 stretch-ratio pair:

- **Left column (3)** — all the interactive controls:
  - "← Back to Main Menu" button (top-left, muted)
  - `LineEdit` (name) + 🎲 button (random name from active kindred's pool; "Unit" fallback on empty pool)
  - Four slot-wheel dial columns: Kindred · Class · Background · Portrait
  - "Begin Run" confirm button
- **Right column (2)** — live preview `PanelContainer` showing concrete HP (from rolled VIT), Speed (from kindred), a **🎲 Reroll Stats** button, per-attribute row (STR / DEX / COG / WIL / VIT — **concrete rolled values**, not ranges), class ability name + description, background ability name + description, kindred feat name. Updates live from `_calc_preview()` on every dial change and every reroll. Read-only text rows; the only interactive control inside the panel is the Reroll button. (Armor/defense is rolled behind the scenes by Reroll but not surfaced — it's a gear-driven stat everywhere else in the game and starting armor is uniform enough that a visible roll would be noise.)

Each dial column shows the current selection (20 px, light highlight panel) flanked by ghost neighbours at 25% opacity / 12 px. All children built in `_build_ui()`.

### Public API / Key Methods

| Method | Notes |
|--------|-------|
| `_ready()` | Calls `_load_data()` then `_build_ui()` |
| `_load_data()` | Populates parallel id/display arrays from all four libraries |
| `_build_ui()` | Constructs name row + four dial columns + confirm button |
| `_build_text_dial(header, ids, display, on_select)` | Returns a `PanelContainer` drum column with ▲/▼ and three visible text rows (prev ghost, current highlighted, next ghost). `idx` stored in a single-element `Array[int]` — required because GDScript 4 closures capture locals by value, so a plain `int` would reset to 0 on every press. |
| `_build_portrait_dial()` | Same drum column shape but shows `TextureRect` (icon.svg) for current + smaller greyed icons for prev/next. Arrows disabled (1 portrait option until art ships). |
| `_build_preview_panel()` | Returns a `PanelContainer` holding the live preview — HP + Speed strip, Reroll Stats button, per-attribute row (STR/DEX/COG/WIL/VIT — concrete numbers), class ability name+desc, background ability name+desc, kindred feat name. Stores twelve label refs as instance vars for `_calc_preview()` to push to. |
| `_make_stat_label(text)` | Small helper — one-line `Label` with font size 14 used for the preview panel's stat strip. |
| `_roll_stats()` | Populates `_rolled_stats` dict with fresh `randi_range(1, 4)` values for STR/DEX/COG/WIL/VIT and `randi_range(4, 8)` for armor. Called from `_ready()` (initial seed before UI is built) and from the Reroll button. |
| `_on_reroll_stats()` | Calls `_roll_stats()` then `_calc_preview()` to push new numbers into labels. |
| `_on_back()` | Changes scene to `MainMenuScene`. No state mutation — save survives. |
| `_on_dice_name()` | Reads active kindred's name pool via `KindredLibrary.get_name_pool()`; falls back to "Unit" on empty pool |
| `_on_confirm()` | **Commit point.** Calls `GameState.delete_save()` + `GameState.reset()` first (moved from `MainMenuManager._on_new_run()` so Back can be a clean cancel), then `_build_pc(..., _rolled_stats)`, appends to `GameState.party`, transitions to `MapScene`. |
| `_calc_preview()` | Returns a `Dictionary` of preview values AND pushes them into the thirteen preview labels. Reads `_kindred_idx` / `_class_idx` / `_bg_idx` and `_rolled_stats`. `hp = 10 + kindred_hp_bonus + VIT × 6` (concrete, using rolled VIT), `speed = 1 + kindred_speed_bonus`. Called from `_on_pick_changed()` on every dial spin, from `_on_reroll_stats()`, and once from `_build_ui()` to seed initial values. Signature stays `-> Dictionary` so a future `CharacterCreationPreview` component can consume the same data without a live UI. |
| `static _build_pc(char_name, kindred_id, class_id, bg_id, _portrait_id, rolled_stats = {})` | Builds `CombatantData` field-by-field from picks. **Static** so unit tests call it without a live scene. `rolled_stats` (optional) — dict with keys `str/dex/cog/wil/vit/armor`; when empty, rolls fresh internally (existing tests rely on this); when populated, uses values verbatim (production commit path). |

### _build_pc field assignments

| Field | Source |
|-------|--------|
| `archetype_id` | `"RogueFinder"` (fixed) |
| `is_player_unit` | `true` |
| `character_name` | name input; `""` → `"Unit"` |
| `kindred` | kindred_id (e.g. `"dwarf"`) |
| `feat_ids` | `[KindredLibrary.get_feat_id(kindred_id)]` — single-element array; kindred feat is always index 0 |
| `unit_class` | `ClassLibrary.get_class_data(class_id).display_name` |
| `background` | bg_id (snake_case ID — differs from ally background format which stores PascalCase display strings) |
| `abilities` | `[class.starting_ability_id, bg.starting_ability_id, "", ""]` — always 4 slots |
| `ability_pool` | class + bg ability ids, deduped |
| `strength/dex/cog/wil/vit` | `rolled_stats` dict when provided (production commit path); `randi_range(1, 4)` fallback when dict is empty (back-compat + Test New Run path) |
| `armor_defense` | `rolled_stats.armor` when provided; `randi_range(4, 8)` fallback |
| `qte_resolution` | `0.5` (fixed — player doesn't auto-resolve) |
| `current_hp` | `hp_max` (computed property) |
| `current_energy` | `energy_max` (computed property) |
| `portrait` | Not set — remains `null` (all portraits are icon.svg placeholder; serialization deferred to art pass) |

### Instance Variables

| Var | Type | Notes |
|-----|------|-------|
| `_kindred_ids` | `Array[String]` | Parallel to kindred dial items |
| `_class_ids` | `Array[String]` | |
| `_class_display` | `Array[String]` | Display names for class dial |
| `_bg_ids` | `Array[String]` | |
| `_bg_display` | `Array[String]` | `BackgroundData.background_name` (not `display_name`) |
| `_portrait_ids` | `Array[String]` | Loaded but portrait dial always uses index 0 |
| `_name_field` | `LineEdit` | |
| `_kindred_idx` | `int` | Current kindred dial selection index |
| `_class_idx` | `int` | Current class dial selection index |
| `_bg_idx` | `int` | Current background dial selection index |
| `_preview_hp_lbl` | `Label` | Preview strip — "HP: N" (concrete, from rolled VIT) |
| `_preview_speed_lbl` | `Label` | Preview strip — "Speed: N" |
| `_preview_str_lbl` / `_dex` / `_cog` / `_wil` / `_vit` | `Label` × 5 | Per-attribute row labels — concrete rolled values pushed by `_calc_preview()` |
| `_rolled_stats` | `Dictionary` | `{str, dex, cog, wil, vit, armor}` — seeded in `_ready()`, overwritten on Reroll, consumed by `_on_confirm()` → `_build_pc(..., _rolled_stats)`. `armor` is rolled + persisted but not rendered in the preview. |
| `_preview_class_name` | `Label` | "Class Ability — <name>" row |
| `_preview_class_desc` | `Label` | Class ability description (autowrap, 75% opacity) |
| `_preview_bg_name` | `Label` | "Background Ability — <name>" row |
| `_preview_bg_desc` | `Label` | Background ability description (autowrap, 75% opacity) |
| `_preview_feat_lbl` | `Label` | "Kindred Feat — \<name\>" row |
| `_preview_feat_desc` | `Label` | Feat description (autowrap, 75% opacity) — added Slice 2 |

### Known Inconsistency

`CombatantData.background` stores the snake_case `background_id` for PC-created characters but PascalCase display strings for ally characters created by `ArchetypeLibrary.create()`. `BackgroundLibrary.get_background_by_name()` bridges old code. Migration deferred.

### Dependencies

- `KindredLibrary` — name pool, feat id, speed bonus, hp bonus
- `FeatLibrary` — feat name + description for preview panel (Slice 2)
- `ClassLibrary` — class list, starting ability, display name
- `BackgroundLibrary` — background list, starting ability
- `PortraitLibrary` — portrait list (used for id only; texture not set at v1)
- `AbilityLibrary` — resolves class + background starting abilities for preview name/description (B4)
- `GameState` — appends PC to `GameState.party` on confirm
- `CombatantData` — constructed by `_build_pc()`

### Tests

`tests/test_character_creation.gd` / `test_character_creation.tscn` — 11 unit tests covering `_build_pc()` correctness (all headless; no live scene required). The two newest tests cover the `rolled_stats` param path: one confirms values are used verbatim when provided, the other confirms the internal-roll fallback stays in range when omitted.

### Gotchas

- **`_build_pc()` is static** — keeps unit tests simple. Do not add instance-var access inside it.
- **Closure int capture** — `_build_text_dial()` uses `Array[int]` (single element) as a mutable index. Replacing with a plain `int` will break cycling (resets to 0 on every button press).
- **Portrait not serialized** — `CombatantData.portrait` is `Texture2D` (not JSON-serializable). All portrait options are `icon.svg` at v1 so the loss is invisible. When real art ships: add `portrait_id: String` to `CombatantData`, serialize in `_serialize_combatant()` / `_deserialize_combatant()`, restore texture on load.
- **Preview signature reserved** — `_calc_preview() -> Dictionary` returns the derived preview data even though the inline UI pushes values into labels directly. Signature is preserved so a future `CharacterCreationPreview` component can consume the dict without a live UI. Do not collapse it to `-> void`.
- **Preview nil-guard** — `_calc_preview()` checks `_preview_hp_lbl != null` before pushing label text. This allows calling `_calc_preview()` from static/test contexts without crashing.
- **Stats are rolled at `_ready()` before `_build_ui()`** — so `_rolled_stats` is populated by the time the preview panel tries to render initial values.
- **Commit side-effects live in `_on_confirm()`** — `delete_save()` + `reset()` used to run in `MainMenuManager._on_new_run()`. They were moved here so the Back button is a true cancel. `MainMenuManager._on_test_new_run()` does its own `delete_save()` + `reset()` for the same reason.
- **Previewed stats = persisted stats** — the manager pre-rolls stats and passes them to `_build_pc()` as the `rolled_stats` dict.

### Recent Changes

| Date | Change |
|---|---|
| 2026-04-24 | **Back button + stat reroll.** Back button returns to MainMenu without mutating save state (`delete_save()` + `reset()` moved from `MainMenuManager._on_new_run()` into `_on_confirm()` so Back is a clean cancel). Stats now rolled at `_ready()` and shown as concrete values in the preview (HP + STR/DEX/COG/WIL/VIT). 🎲 Reroll Stats button. Armor rolled + persisted but not surfaced. `_build_pc()` extended with optional `rolled_stats: Dictionary = {}`. 2 new tests (11 total). |
| 2026-04-24 | **Slice 2 — FeatLibrary migration.** `_calc_preview()` resolves feat via `FeatLibrary.get_feat(KindredLibrary.get_feat_id(kindred_id))`. Preview panel gains `_preview_feat_desc` label. `FeatLibrary` added as dependency. |
| 2026-04-24 | **B4 — Live preview panel.** Read-only `PanelContainer` showing HP, Speed, Stats, class ability name+desc, background ability name+desc, kindred feat name. `_calc_preview()` fleshed out; stores twelve label refs as instance vars. `AbilityLibrary` added as dependency. No new tests. |
| 2026-04-24 | **B1+B2 — Character creation scene.** `MainMenuManager._on_new_run()` routes to `CharacterCreationScene`. `_build_pc()` builds `CombatantData` from picks. Slot-wheel dials with ghost neighbours. 9 unit tests. |
