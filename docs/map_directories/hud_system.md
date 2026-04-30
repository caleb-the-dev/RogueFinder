# System: HUD System

> Last updated: 2026-04-29 (Vendor Slice 1 — EndCombatScreen shows "+X Gold (Total: Y)" line above item cards; show_victory() now takes gold_amount param; RewardGenerator gains gold_drop() method)

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

Sections (in order): Identity → Live State → Attributes → Derived Stats → Equipment → Abilities → **Feats**. Derived stats section shows: **P.Def** (`physical_defense`), **M.Def** (`magic_defense`), **Speed** (`1 + kindred`); and QTE Res for non-player units. No Attack line — ability damage scales from the caster's relevant attribute via `effective_stat()`. Feats appear as a `[b]── Feats ──[/b]` RTL section immediately after Abilities, with numbered entries.

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `show_for` | `(unit: Unit3D) -> void` | Populate and show the panel for this unit |
| `hide_panel` | `() -> void` | Hide the examine window |

### Recent Changes (StatPanel)

| Date | Change |
|------|--------|
| 2026-04-27 | **Dual armor.** Derived stats section replaced single `Defense` line with two lines: `P.Def: X (physical armor)` + `M.Def: X (magic armor)`, reading `d.physical_defense` + `d.magic_defense`. |
| 2026-04-24 | **Slice 2.** Feats section added to the RTL after Abilities (`── Feats ──` bold header, `1. <FeatName>` numbered entry). Resolved by iterating `d.feat_ids` via `FeatLibrary.get_feat(id)`. `FeatLibrary` is now a dependency. |

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
| `show_victory` | `(reward_items: Array, gold_amount: int = 0) -> void` | Displays VICTORY header + gold line + 3 reward cards |

Victory flow — reward cards are `PanelContainer` nodes. Each card has a rarity-colored border and is clickable anywhere. Layout from top to bottom:
- **VICTORY** header (64px, gold).
- **"+X Gold (Total: Y)"** line — Color(0.90, 0.80, 0.30), 22px, centered. Gold has already been added to `GameState.gold` before this screen is shown.
- **"Choose your reward:"** subtitle (18px, dimmed).
- Three item cards:
  - **Item name** — rarity colored, 18px, centered.
  - **Stat bonuses row** (equipment only) — one chip label per bonus (`STR +1` etc.); gold for positive, red for negative. Hover shows tooltip: `"Strength +1 — drives attack damage"`.
  - **Grants: [Ability Name]** (equipment with `granted_ability_ids` only) — light blue label; hover shows: `"ability name\nATTR · cost Energy · range\ndescription"`.
  - **HSeparator.**
  - **Flavor description** — 12px, dimmed, autowrapped.

**Click detection:** `PanelContainer.gui_input` (no overlay button). `_reward_chosen: bool` flag prevents double-fires. Clicking a card:
1. Sets `_reward_chosen = true`.
2. Calls `GameState.add_to_inventory(item)`.
3. Chosen card name label gets `"✓ "` prefix; border widens to 3px.
4. Appends `GameState.current_combat_node_id` to `GameState.cleared_nodes` (if not already present).
5. If the defeated node's type is `"BOSS"`, resets `GameState.threat_level = 0.0`.
6. Calls `GameState.save()`.
7. Calls `_return_to_map()` → `change_scene_to_file("res://scenes/map/MapScene.tscn")`.

There is no intermediate step — reward selection transitions the scene immediately.

**Tooltip rendering:** Stat/ability labels use `MOUSE_FILTER_PASS` so hover events reach them despite the PanelContainer sitting below them. Card click propagates from child labels up to the PanelContainer's `gui_input` since labels don't consume click events.

Reward items come from `RewardGenerator.roll(3)` — plain Dicts: `id`, `name`, `description`, `item_type`, **`rarity`** (int). Rarity color sourced from `EquipmentData.RARITY_COLORS`.

### Recent Changes (EndCombatScreen)

| Date | Change |
|------|--------|
| 2026-04-29 | **Vendor Slice 1 — gold display.** `show_victory(reward_items, gold_amount: int = 0)` signature extended. `_build_victory_layout(items, gold_amount)` now inserts a gold-colored `"+X Gold (Total: Y)"` Label at y=195 above the subtitle. Subtitle font size reduced 22→18px; card_y nudged 250→265 to avoid overlap. Gold is already added to `GameState.gold` by `CombatManager3D._end_combat()` before this screen is shown — the "Total" figure reads the post-credit balance. |
| 2026-04-28 | **Weapon Tier Families — Slice 3.** Reward cards now show stat bonuses (chip labels, hover tooltip) + granted ability name (hover tooltip with cost/range/description). Invisible overlay `Button` removed; `PanelContainer.gui_input` used for click detection (allows child label tooltips to work). `_reward_buttons: Array[Button]` removed; `_reward_chosen: bool` flag prevents double-fires. Card min height 130→160, width 260→270. `_build_reward_card` signature simplified (no `h` param). Helper methods `_stat_abbrev`, `_stat_desc`, `_attr_abbrev` added. |
| 2026-04-28 | **Rarity Foundation — Slice 1.** Reward cards refactored from plain `Button` to `PanelContainer` with rarity-colored border + colored name `Label`; invisible `Button` overlay added for click detection. `_reward_cards` + `_reward_buttons` arrays track cards. |

---

## RewardGenerator

Static utility class (`scripts/globals/RewardGenerator.gd`). Selects `count` distinct reward items using weighted rarity tiers and returns them as plain Dictionaries. Equipment is bucketed by `EquipmentData.rarity`; consumables slot into the COMMON bucket.

### Constants

```gdscript
const RARITY_WEIGHTS: Dictionary = {
    EquipmentData.Rarity.COMMON: 60, EquipmentData.Rarity.RARE: 25,
    EquipmentData.Rarity.EPIC: 12,   EquipmentData.Rarity.LEGENDARY: 3
}  # sums to 100
```

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `roll` | `(count: int) -> Array` | Returns `count` distinct reward Dicts with rarity-weighted selection |
| `gold_drop` | `(ring: String, threat: int, party_avg_level: int) -> int` | Returns integer gold earned on combat victory; jittered ±10% |

### Gold Drop Formula

```
RING_BASE:    { "outer": 30, "middle": 20, "inner": 12 }
THREAT_COEFF: 0.15  # scales 0–100 threat int → 0–15 bonus gold
LEVEL_COEFF:  3.0   # scales avg level 1–20 → 3–60 bonus gold

raw  = (RING_BASE[ring] + THREAT_COEFF * threat + LEVEL_COEFF * avg_level) * randf_range(0.9, 1.1)
gold = max(1, round(raw))
```

`threat` is `round(GameState.threat_level * 100)` (0–100 int). Unknown ring strings fall back to `"inner"` base. Caller must seed the global RNG or accept natural random jitter — no seeded RNG parameter (unlike `PricingFormula.price_for`).

### Roll algorithm

1. Bucket all equipment by `eq.rarity`; add all consumables into the COMMON bucket.
2. For each needed slot, call `_roll_rarity()` (weighted 0–99 pick → tier).
3. If the rolled tier's bucket is empty, fall back to COMMON.
4. Pick a random item from the bucket. Retry if already used (max `count × 20` attempts).

### Returned dict keys

`id`, `name`, `description`, `item_type` ("equipment" or "consumable"), **`rarity`** (int).

---

---

## PricingFormula

Static utility class (`scripts/globals/PricingFormula.gd`). Converts any item dict into a deterministic integer price. Paired with `RewardGenerator` — both live in `globals/` and operate on the same item dict shape.

**Key design rule:** the caller always supplies a `RandomNumberGenerator` instance. No global `randi()` fallback. This lets vendor scenes seed the RNG once per shop refresh so prices are stable within a visit and can't be re-rolled by save-scumming.

### Constants

```gdscript
const RARITY_BASE_PRICE: Dictionary = {
    EquipmentData.Rarity.COMMON:     10,
    EquipmentData.Rarity.RARE:       40,
    EquipmentData.Rarity.EPIC:      120,
    EquipmentData.Rarity.LEGENDARY: 400,
}
```

### Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| `price_for` | `(item: Dictionary, rng: RandomNumberGenerator) -> int` | Returns jittered price ≥ 1 for the given item dict |

### Pricing formula

```
base = RARITY_BASE_PRICE[item.rarity]   # defaults to COMMON if key absent
mult = rng.randf_range(0.9, 1.1)
price = max(1, round(base * mult))
```

Consumables all carry `rarity = COMMON` (from `RewardGenerator._con_to_dict`), so they price at 9–11 gold. Revisit if playtesting makes this feel wrong.

### Recent Changes (PricingFormula)

| Date | Change |
|------|--------|
| 2026-04-29 | **Vendor Slice 2 — initial implementation.** `PricingFormula.gd` created. `price_for(item, rng)` method: rarity → base lookup, ±10% jitter, floor 1. 9 headless tests (`test_pricing.gd/.tscn`). |

---

## MainMenuScene + CharacterCreationScene

> Moved to [`character_creation.md`](character_creation.md).

---

## PauseMenu

**Layer 26.** Global pause overlay registered as an autoload (`PauseMenu`). Active in all gameplay scenes (MapScene, CombatScene3D, BadurgaScene, CharacterCreationScene). Blocked in MainMenuScene and RunSummaryScene via a scene-file path gate.

**Architecture decision:** Implemented as a CanvasLayer autoload rather than a per-scene instance so it works across all 4+ gameplay scenes without boilerplate. The tradeoff vs per-scene: less control over scene-specific behavior, but the gate function handles the two excluded scenes cleanly.

**SettingsStore:** User preferences live in a separate `SettingsStore` autoload (`scripts/globals/SettingsStore.gd`) persisted to `user://settings.json`. This is distinct from `user://save.json` (run state) so volume prefs survive run deletion. Tradeoff vs folding settings into PauseMenuManager: adds one autoload but keeps settings accessible anywhere without coupling them to the menu lifecycle.

**ESC conflict resolution:** CM3D only marks ESC as handled when it actually does something (cancel recruit mode, deselect a unit). When nothing is selected and mode is IDLE, ESC falls through to PauseMenu. StatPanel ESC is handled inside CM3D's guard block (all input consumed while panel is visible) — PauseMenu never sees those events.

**`blocks_pause` group:** `PauseMenuManager._is_overlay_blocking()` checks `get_tree().get_nodes_in_group("blocks_pause")` for any visible `CanvasLayer` member. If one is found, both the ☰ button visibility check (in `_process`) and the ESC open-menu path (in `_unhandled_input`) are suppressed. Current members of this group: `PartySheet` (layer 20), `VendorOverlay` (layer 20), `EventManager` (layer 10). Any future full-screen overlay that manages its own ESC should call `add_to_group("blocks_pause")` in `_ready()`.

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
| **Settings** | ← Back · Master/Music/SFX volume sliders (visible + draggable; values persist; audio bus wiring deferred) |
| **Guide** | ← Back · "Guide coming soon." stub |
| **Archetypes Log** | ← Back · Scrollable Pokédex-style list of all archetypes sorted by status descending |

### Archetypes Log

Pokédex-style. Shows **all** archetypes (from `ArchetypeLibrary.all_archetypes()`), sorted descending by status. Rebuilt by `_rebuild_log_list()` on every panel open.

**Status enum (`_ArchStatus`):**

| Value | Meaning | Card appearance |
|-------|---------|----------------|
| `UNKNOWN (0)` | Never seen in combat, never recruited | Dark silhouette · "???" name · "Not yet encountered in the field." |
| `ENCOUNTERED (1)` | Seen in combat (or recruited) | Full card · `[ Encountered ]` badge (blue) |
| `FOLLOWER (2)` | Ever added to bench — persists after release | Full card · `[ Follower ]` badge (green) |
| `PLAYER (3)` | RogueFinder archetype_id — always this | Full card · `[ You ]` badge (gold) · displayed as "The Pathfinder" |

Status is determined by `_get_arch_status(id)`: checks `recruited_archetypes` first (persistent across releases), then falls back to bench + party scan (handles saves pre-dating `recruited_archetypes`), then `encountered_archetypes`, then UNKNOWN.

Full cards show: archetype name (title-cased), kindred · class (muted), and `ArchetypeData.notes` text if non-empty.

**Recording:**
- Encounters: `GameState.record_archetype(id)` called in `CombatManager3D._setup_units()` for each enemy at combat start (even if player flees).
- Recruits: `GameState.add_to_bench()` calls `record_recruited_archetype(id)` — this is the single hookpoint for all bench-insert paths (combat, event, city hire).

### Recent Changes (PauseMenu)

| Date | Change |
|------|--------|
| 2026-04-30 | **`blocks_pause` group pattern added.** `_is_overlay_blocking()` helper queries `"blocks_pause"` group; `_process` and `_unhandled_input` skip the ☰ button / ESC when any member CanvasLayer is visible. `PartySheet`, `VendorOverlay`, and `EventManager` all join the group on `_ready()`. |
| 2026-04-28 | **Fullscreen toggle removed.** CheckBox was rendering as plain non-interactive text (no hover/focus state). Removed `SettingsStore.fullscreen` field, `set_fullscreen()`, the checkbox row from the settings panel, and `_on_fullscreen_toggled()` from PauseMenuManager. 12 tests still pass. |
| 2026-04-28 | **Pokédex Archetypes Log + recruited_archetypes tracking.** Log rebuilt to show all archetypes with 4 status levels (UNKNOWN/ENCOUNTERED/FOLLOWER/PLAYER). UNKNOWN entries show as dark silhouettes with "???". `GameState.recruited_archetypes` + `record_recruited_archetype()` added — persists Follower status even after bench release. `add_to_bench()` is the single hookpoint. Confirm dialogs added to Main Menu and Exit Game buttons. Party button shifted left (–236 px) to clear ☰ button overlap. ESC handling fixed — `PROCESS_MODE_WHEN_PAUSED` changed to `PROCESS_MODE_ALWAYS` (was never receiving initial ESC to open). CM3D ESC: now only consumed when an action is taken; IDLE+nothing selected falls through to PauseMenu. |
| 2026-04-28 | **Pause Menu + Archetypes Log initial implementation.** Layer 26 CanvasLayer autoload. ESC gate + ☰ button. Settings panel (volume sliders). Guide stub. Archetypes Log panel (initial version). SettingsStore autoload (`user://settings.json`). `GameState.encountered_archetypes` + `record_archetype()`. `ArchetypeData.notes` parsed. 8 headless tests (now 12 after recruited_archetypes tests added). |

---

## Legacy HUD.gd

`scripts/ui/HUD.gd` and `scenes/ui/HUD.tscn` are kept for `CombatManager.gd` (2D). Do not delete until the 2D prototype is retired.

Duck-typed `refresh(player_units, enemy_units)` still works for 2D units.
