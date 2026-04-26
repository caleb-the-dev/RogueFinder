# System: Main Menu + Character Creation

> Last updated: 2026-04-26 (pillar foundation — deterministic stats, kindred ability in slot 1, bg feat seeds feat_ids, Reroll removed)

---

## Status

| System | File | Status |
|--------|------|--------|
| MainMenuScene | `scripts/ui/MainMenuManager.gd` + `scenes/ui/MainMenuScene.tscn` | ✅ Active |
| CharacterCreationScene | `scripts/ui/CharacterCreationManager.gd` + `scenes/ui/CharacterCreationScene.tscn` | ✅ Active (B2 + B4; 12 tests) |

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
- **Test New Run depends on `CharacterCreationManager._build_pc()`** — the static builder is the single source of truth for PC construction. If you change `_build_pc()`'s signature, update `_on_test_new_run()` too.

---

## CharacterCreationScene

Lives at `scenes/ui/CharacterCreationScene.tscn` + `scripts/ui/CharacterCreationManager.gd`.

**Reached via:** `MainMenuManager._on_new_run()` → `change_scene_to_file(CREATION_SCENE_PATH)`. No state is touched on entry — the player can abort with the Back button without nuking an existing save.

**On exit (Begin Run):** `_on_confirm()` calls `GameState.delete_save()` + `GameState.reset()`, builds the PC via `_build_pc(...)`, appends to `GameState.party`, then routes to `MapScene`. `MapManager._ready()` calls `GameState.init_party()` as a safety fallback — the guard fires immediately because `party` is already non-empty.

**On exit (Back):** `_on_back()` simply changes scene to `MainMenuScene`. No state touched.

### What it does (B2 + B4)

Single-screen character creation. Player picks name, kindred, class, background, and portrait. Stats are **fully deterministic** (base 4 + pillar bonuses — no rolling). On Confirm, builds a `CombatantData` from scratch (not via `ArchetypeLibrary.create()`) and appends it to `GameState.party`.

Layout — two-column body inside a full-rect `MarginContainer` (40 px margins). `HBoxContainer` splits into a 3:2 stretch-ratio pair:

- **Left column (3)** — all the interactive controls:
  - "← Back to Main Menu" button (top-left, muted)
  - `LineEdit` (name) + 🎲 button (random name from active kindred's pool; "Unit" fallback on empty pool)
  - Four slot-wheel dial columns: Kindred · Class · Background · Portrait
  - "Begin Run" confirm button
- **Right column (2)** — live preview `PanelContainer` showing HP, Speed, per-attribute row (STR / DEX / COG / WIL / VIT — **deterministic values from pillar picks**), class ability name + description, kindred ability name + description, background feat name + description. Updates live from `_calc_preview()` on every dial change.

Each dial column shows the current selection (20 px, light highlight panel) flanked by ghost neighbours at 25% opacity / 12 px. All children built in `_build_ui()`.

### Public API / Key Methods

| Method | Notes |
|--------|-------|
| `_ready()` | Calls `_load_data()` then `_build_ui()` |
| `_load_data()` | Populates parallel id/display arrays from all four libraries |
| `_build_ui()` | Constructs name row + four dial columns + confirm button + preview panel |
| `_build_text_dial(header, ids, display, on_select)` | Returns a `PanelContainer` drum column with ▲/▼ and three visible text rows (prev ghost, current highlighted, next ghost). `idx` stored in a single-element `Array[int]` — required because GDScript 4 closures capture locals by value. |
| `_build_portrait_dial()` | Same drum column shape but shows `TextureRect` (icon.svg). Arrows disabled (1 portrait option until art ships). |
| `_build_preview_panel()` | Returns a `PanelContainer` holding: HP + Speed strip, per-attribute row (STR/DEX/COG/WIL/VIT), class ability name+desc, kindred ability name+desc, background feat name+desc. Stores thirteen label refs as instance vars. No Reroll button (stats are deterministic). |
| `_make_stat_label(text)` | One-line `Label` helper with font size 14. |
| `_on_back()` | Changes scene to `MainMenuScene`. No state mutation — save survives. |
| `_on_dice_name()` | Reads active kindred's name pool via `KindredLibrary.get_name_pool()`; falls back to "Unit" on empty pool |
| `_on_confirm()` | **Commit point.** Calls `GameState.delete_save()` + `GameState.reset()`, then `_build_pc(...)`, appends to `GameState.party`, transitions to `MapScene`. |
| `_calc_preview()` | Returns a `Dictionary` of preview values AND pushes them into the preview labels. Reads `_kindred_idx` / `_class_idx` / `_bg_idx`. Computes stats deterministically: `base 4 + class_bonus + kindred_bonus + bg_bonus`. HP and speed computed from pillar picks. Preview shows class ability, kindred ability, background feat. Returns `-> Dictionary` so a future component can consume it without a live UI. |
| `static _build_pc(char_name, kindred_id, class_id, bg_id, _portrait_id)` | Builds `CombatantData` field-by-field from picks. **Static** so unit tests call it without a live scene. Stats are deterministic (no `rolled_stats` param). |

### _build_pc field assignments

| Field | Source |
|-------|--------|
| `archetype_id` | `"RogueFinder"` (fixed) |
| `is_player_unit` | `true` |
| `character_name` | name input; `""` → `"Unit"` |
| `kindred` | kindred_id (e.g. `"Human"`) |
| `unit_class` | class_id (lowercase, e.g. `"arcanist"`) |
| `background` | bg_id (snake_case ID) |
| `strength/dex/cog/wil/vit` | `4 + class_bonus + kindred_bonus + bg_bonus` (all from respective `stat_bonuses` dicts) |
| `armor_defense` | `5` (flat base; pillar armor_defense bonuses flow through `get_kindred_stat_bonus` etc. in derived `defense`) |
| `abilities` | `[class.starting_ability_id, kindred.starting_ability_id, "", ""]` — always 4 slots; slot 0 = class defining, slot 1 = kindred natural attack |
| `ability_pool` | class + kindred ability IDs, deduped |
| `feat_ids` | `[bg_data.starting_feat_id]` — background defining feat; empty if starting_feat_id is `""` |
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
| `_bg_display` | `Array[String]` | `BackgroundData.background_name` |
| `_portrait_ids` | `Array[String]` | Loaded but portrait dial always uses index 0 |
| `_name_field` | `LineEdit` | |
| `_kindred_idx` | `int` | Current kindred dial selection index |
| `_class_idx` | `int` | Current class dial selection index |
| `_bg_idx` | `int` | Current background dial selection index |
| `_preview_hp_lbl` | `Label` | "HP: N" (deterministic from pillar picks) |
| `_preview_speed_lbl` | `Label` | "Speed: N" |
| `_preview_str_lbl` / `_dex` / `_cog` / `_wil` / `_vit` | `Label` × 5 | Per-attribute row labels — deterministic pillar-computed values |
| `_preview_class_name` | `Label` | "Class Ability — \<name\>" row |
| `_preview_class_desc` | `Label` | Class ability description (autowrap, 75% opacity) |
| `_preview_kindred_name` | `Label` | "Kindred Ability — \<name\>" row |
| `_preview_kindred_desc` | `Label` | Kindred ability description (autowrap, 75% opacity) |
| `_preview_feat_lbl` | `Label` | "Background Feat — \<name\>" row |
| `_preview_feat_desc` | `Label` | Feat description (autowrap, 75% opacity) |

### Known Inconsistency

`CombatantData.background` stores the snake_case `background_id` for PC-created characters but PascalCase display strings for ally characters created by `ArchetypeLibrary.create()`. `BackgroundLibrary.get_background_by_name()` bridges old code. Migration deferred.

### Dependencies

- `KindredLibrary` — name pool, speed bonus, hp bonus, stat_bonuses, starting_ability_id
- `ClassLibrary` — class list, starting ability, display name, stat_bonuses
- `BackgroundLibrary` — background list, display name, starting_feat_id, stat_bonuses
- `PortraitLibrary` — portrait id list (used for id only; texture not set at v1)
- `AbilityLibrary` — resolves class + kindred starting abilities for preview name/description
- `FeatLibrary` — feat name + description for background feat preview
- `GameState` — appends PC to `GameState.party` on confirm
- `CombatantData` — constructed by `_build_pc()`

### Tests

`tests/test_character_creation.gd` / `test_character_creation.tscn` — 12 unit tests covering `_build_pc()` correctness (all headless). Tests verify: deterministic stat values (specific combo assertions), kindred ability in slot 1, bg defining feat in `feat_ids[0]`, no kindred feat in `feat_ids`, ability pool membership, dedup, hp/energy seeded at max.

### Gotchas

- **`_build_pc()` is static** — keeps unit tests simple. Do not add instance-var access inside it.
- **`_build_pc()` has no `rolled_stats` param** — removed in pillar-foundation session. Stats are always deterministic.
- **Closure int capture** — `_build_text_dial()` uses `Array[int]` (single element) as a mutable index. Replacing with a plain `int` will break cycling.
- **Portrait not serialized** — `CombatantData.portrait` is `Texture2D` (not JSON-serializable). When real art ships: add `portrait_id: String` to `CombatantData`, serialize in `_serialize_combatant()` / `_deserialize_combatant()`.
- **Preview signature reserved** — `_calc_preview() -> Dictionary` returns the data even though labels are pushed directly. Do not collapse to `-> void`.
- **Preview nil-guard** — `_calc_preview()` checks `_preview_hp_lbl != null` before pushing label text. Allows calling from static/test contexts without crashing.
- **Slot 0 = class, slot 1 = kindred** — `abilities[0]` is the class defining ability, `abilities[1]` is the kindred natural attack. Slot order matters for the action panel rendering.

### Recent Changes

| Date | Change |
|---|---|
| 2026-04-26 | **Pillar foundation.** Stats fully deterministic — `_roll_stats()`, `_on_reroll_stats()`, Reroll Stats button, and `_rolled_stats` dict all removed. `_build_pc()` signature loses `rolled_stats` param; stats are `4 + class_bonus + kindred_bonus + bg_bonus`. Ability seeding changed: slot 0 = class defining ability, slot 1 = kindred natural attack (was: slot 0 = class, slot 1 = bg ability). `feat_ids` seeded from `bg_data.starting_feat_id` (was: kindred feat). Preview panel: kindred ability row added (was: bg ability row); feat row label changed to "Background Feat" (was: "Kindred Feat"). `_preview_bg_name`/`_preview_bg_desc` renamed to `_preview_kindred_name`/`_preview_kindred_desc`; new `_preview_feat_lbl`/`_preview_feat_desc` retain background feat display. 12 tests (was 11). |
| 2026-04-24 | **Back button + stat reroll.** Back button returns to MainMenu without mutating save state. Stats rolled at `_ready()` and shown as concrete values. 🎲 Reroll Stats button (now removed). `_build_pc()` extended with optional `rolled_stats: Dictionary = {}` (now removed). 2 new tests (11 total at time). |
| 2026-04-24 | **Slice 2 — FeatLibrary migration.** `_calc_preview()` resolves feat via `FeatLibrary.get_feat()`. Preview panel gains `_preview_feat_desc` label. |
| 2026-04-24 | **B4 — Live preview panel.** Read-only `PanelContainer` showing HP, Speed, Stats, class ability name+desc, background ability name+desc, kindred feat name. `_calc_preview()` fleshed out. |
| 2026-04-24 | **B1+B2 — Character creation scene.** `MainMenuManager._on_new_run()` routes to `CharacterCreationScene`. `_build_pc()` builds `CombatantData` from picks. Slot-wheel dials with ghost neighbours. 9 unit tests. |
