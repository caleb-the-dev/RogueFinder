# System: Party Sheet

> Last updated: 2026-04-23 (split from map_scene.md during map audit; S28 kindred row and 30/40/30 column rebalance)

---

## Purpose

Full-screen interactive overlay for reviewing and managing the party. Opened from the "Party" button in `MapManager`'s UI chrome. This is where the player equips gear, swaps abilities, compares items, and reads stat blocks between encounters.

Runs on `CanvasLayer` at layer 20 — above every other overlay in the map scene. All mutations write directly to the live `CombatantData` instances in `GameState.party`; persistence is deferred to the next map travel (`MapManager` handles the save).

---

## Core Files

| File | Role |
|------|------|
| `scenes/party/PartySheet.tscn` | Minimal shell (root CanvasLayer + script only) |
| `scripts/party/PartySheet.gd` | Full layout + drag-drop + search/sort logic |

---

## Dependencies

| System | How it's used |
|--------|--------------|
| `GameState` | Reads `party` and `inventory` directly on every `show_sheet()` call and after every mutation |
| `EquipmentLibrary` | Resolves equipment ids (when a slot holds an id string rather than an `EquipmentData` instance) |
| `ConsumableLibrary` | Resolves consumable ids for tooltip + compare panels |
| `AbilityLibrary` | Resolves ability ids for the ability pool tab and slot labels |
| `FeatLibrary` | Resolves `kindred_feat_id` to `FeatData` (name + description) for the Feats tab |
| `MapManager` | Owns the `PartySheet` instance; the `_input()` guard blocks map pan/zoom while the sheet is visible |

---

## Public API

| Method | Purpose |
|---|---|
| `show_sheet()` | Calls `_rebuild()` and sets `visible = true` |
| `hide_sheet()` | Hides the CanvasLayer; clears any live drag compare panel |
| `_rebuild()` | Sole re-render path — fully stateless; frees and recreates every child. Called on open and after every mutation. |

### Gotcha — `_process()`

`_process(delta)` runs once per frame while visible. Its only job: clear the drag compare overlay when `get_viewport().gui_is_dragging()` returns false (the drag ended without dropping on a valid target).

---

## Instance State (persists across `_rebuild()`)

| Variable | Type | Purpose |
|---|---|---|
| `_sort_fields[3]` | `Array[String]` | Per-member sort key (`"name"`, `"attribute"`, `"energy"`) |
| `_sort_ascs[3]` | `Array[bool]` | Per-member sort direction |
| `_search_texts[3]` | `Array[String]` | Per-member ability search query |
| `_focus_search_mi` | `int` | Which member's search `LineEdit` gets focus after next rebuild (-1 = none) |
| `_abil_views_wide[3]` | `Array[bool]` | Per-member ability view mode (false=1-per-row, true=2-per-row GridContainer) |
| `_feat_views_wide[3]` | `Array[bool]` | Per-member feat view mode (mirrors ability toggle) |
| `_feat_sort_ascs[3]` | `Array[bool]` | Per-member feat sort direction (Name asc/desc) |
| `_feat_search_texts[3]` | `Array[String]` | Per-member feat search query |
| `_inv_search_text` | `String` | Inventory search query |
| `_inv_sort_field` | `String` | Inventory sort key (`"name"` or `"type"`) |
| `_inv_sort_asc` | `bool` | Inventory sort direction |
| `_inv_view_wide` | `bool` | Inventory view mode |
| `_drag_compare_panel` | `Control` | Live compare overlay; child of the CanvasLayer, not `_content_root` — survives rebuilds |
| `_cmp_existing` / `_cmp_incoming` | `String` | IDs of the pair currently shown in compare panel; guard to skip redundant rebuilds |

---

## Layout — three columns (~30 / 40 / 30)

### LEFT (376 px) — Bag inventory
Header row: "BAG" label + `1×/2×` view toggle. Sort row: Name / Type. Search bar. Scrollable `GridContainer` (1 or 2 columns). Each item row is a `PanelContainer` with drag forwarding producing `{"item": dict}`. In compact (2-column) mode: smaller icon (16 px), smaller text (10 px), no stat-bonus sub-line.

### MIDDLE (500 px) — Three member cards stacked

Each card divided into 4 quadrants by 50%-alpha separators:

- **TOP-LEFT:** Name (17 px), Class (13 px gold), Background (13 px green), **Kindred (13 px blue-grey)**, HP row — text "HP x/x" left-aligned + bar filling remaining width on the same line.
- **TOP-RIGHT:** Derived stats — Speed / Defense / EN Max / EN Regen (blue, 4 cols). Base attributes — STR / DEX / COG / WIL / VIT (yellow, 5 cols). All labels: `tooltip_text` + `MOUSE_FILTER_PASS`.
- **BOTTOM-LEFT:** "EQUIPMENT" + 2×2 grid. Each slot is a flat `Button` with sprite icon. Drop target via `set_drag_forwarding()`. **Right-click** an occupied slot to unequip. Dragging bag item over a filled slot shows a compare panel. Disabled when dead.
- **BOTTOM-RIGHT:** "ABILITIES" + 2×2 grid of slotted abilities as `Control` + `Label`. Drop target for abilities from the right panel. **Right-click** to clear. Hovering drag over a filled slot shows a side-by-side compare panel (`_show_drag_compare()`). Cross-member ability drops are rejected via `_can_drop_ability_here()`.

### RIGHT (374 px) — TabContainer per member card
- **Abilities tab:** Top bar with `1×/2×` view toggle + "drag to slot →" hint. Sort row: Name / Type / EN (per-member, independent). Search bar with live filter (focus restored after each rebuild via `grab_focus.call_deferred()` + `set_caret_column.call_deferred()` — prevents the backwards-typing bug). Scrollable pool list in `VBoxContainer` (1-per-row) or `GridContainer` (2-per-row). Slotted abilities show gold highlight + `●` prefix + `[s1]`–`[s4]` slot badge. In 2-per-row mode the EN/type sub-line is hidden (tooltip still shows it).
- **Feats tab:** Mirrors the Abilities tab layout — 1×/2× view toggle, Name sort (asc/desc toggle), search bar, scrollable list of `PanelContainer` feat cards (gold name label, hover tooltip with full description). Source: `member.kindred_feat_id` as a single-element list (Slice 4 will extend to `member.feats`). Per-member state: `_feat_views_wide`, `_feat_sort_ascs`, `_feat_search_texts`.

---

## Drag-and-Drop

| Validator | Purpose |
|---|---|
| `_can_drop_here(data, slot_type, is_dead)` | Validates equipment/consumable type match and liveness |
| `_can_drop_ability_here(data, target_mi, is_dead)` | Validates ability drag data and member_idx match (cross-member drops rejected) |

| Drop handler | Behavior |
|---|---|
| `_drop_to_slot(item, member_idx, slot_field)` | Displaces existing occupant to bag, equips new item, calls `GameState.remove_from_inventory()`, then `_rebuild()` |
| `_drop_ability_to_slot(data, target_mi, slot_idx)` | Writes `ability_id` into the live slot array, `_rebuild()` |
| `_unequip_item()` / `_unequip_consumable()` | Right-click handlers; same displacement + rebuild pattern |

---

## Drag Compare Panels

All three live on the `CanvasLayer`, not `_content_root` (so they survive `_rebuild()`):

| Function | Purpose |
|---|---|
| `_show_drag_compare(near_pos, existing_id, incoming_id)` | Ability vs ability (AbilityData) |
| `_show_equip_compare(near_pos, cur_eq, incoming)` | Existing `EquipmentData` vs bag item dict |
| `_show_consumable_compare(near_pos, cur_id, incoming)` | Existing consumable vs bag item dict |

Shared helpers: `_make_compare_panel()`, `_make_compare_col()`, `_add_cmp_label()`, `_add_cmp_desc()`.

`_clear_drag_compare()` frees the panel and resets `_cmp_existing` / `_cmp_incoming`. Called on successful drop, on `hide_sheet()`, and automatically by `_process()` when the drag ends without a drop.

---

## Tooltip Theming

A `Theme` with a `StyleBoxFlat` for `TooltipPanel` (dark bg, gold border) is set on `_content_root` in `_rebuild()` — overrides Godot's default transparent tooltip. `_wrap_tooltip(text, max_line=40)` word-wraps tooltip strings while preserving `\n\n` section breaks.

---

## Map Input Block

`MapManager._input()` has an early-return guard: `if _party_sheet != null and _party_sheet.visible: return`. Required because `MapManager` uses `_input()` (not `_unhandled_input()`); without this guard, map pan/zoom fires through the CanvasLayer overlay.

---

## Persistence

All mutations write directly to the live `CombatantData` instance in `GameState.party[i]`. `GameState.save()` is **NOT** called here — MapScene saves on the next map travel. Dead members cannot be equipped (drop rejected, buttons disabled). Instance vars (`_sort_fields`, `_search_texts`, `_abil_views_wide`, etc.) survive `_rebuild()` but reset on scene reload.

---

## Recent Changes

| Date | Session | What changed |
|---|---|---|
| 2026-04-24 | Slice 2 | **Feats tab upgraded from placeholder.** Full Abilities-tab-style layout: 1×/2× toggle, Name sort, search bar, scrollable `PanelContainer` feat cards with hover tooltip. Three new per-member state arrays (`_feat_views_wide`, `_feat_sort_ascs`, `_feat_search_texts`). `FeatLibrary` added as dependency. Source is `member.kindred_feat_id` only — Slice 4 extends when `CombatantData.feats` lands. |
| 2026-04-23 | S28 | Kindred label (blue-grey, 13 px) added to TOP-LEFT card below Background. HP row restructured: "HP x/x" text now left-aligned on the same row as the bar. Column widths rebalanced: LEFT 240→376 px, MIDDLE 530→500 px, RIGHT 480→374 px (~30/40/30). Horizontal divider moved y+108→y+118 for the extra text line. |
| 2026-04-20 | S23 | Ability Pool Swap. Drag from Abilities tab onto BOTTOM-RIGHT slots; right-click to clear. Per-member sort/search/view in ability panel (backwards-typing bug fixed via focus+caret restoration). Inventory column upgraded with sort/search/view. Drag-compare panels for all three categories (ability, equipment, consumable) via shared helpers. Opaque tooltip theme + `_wrap_tooltip()`. `_process()` auto-clears compare overlay when drag ends. |
| 2026-04-20 | S22 | Layout redesign. 4-quadrant card layout with full-height + full-width 50%-alpha separators. TOP-LEFT name/class/bg/HP. TOP-RIGHT derived + attrs. BOTTOM-LEFT equipment 2×2. BOTTOM-RIGHT slotted abilities 2×2. Right panel replaced with `TabContainer` (Abilities + Feats placeholder). `_detail_open` pattern removed — fully stateless `_rebuild()`. |
| 2026-04-20 | S21 | Drag-drop gear management via native `set_drag_forwarding()` lambdas. Click filled slot to unequip. Dead member slots disabled + drop rejected. `MapManager._input()` early-return guard. Sprite icons for slot types. Tooltips on all stats, equipment, abilities, inventory items. |
| 2026-04-20 | S20 | Party Sheet Slice 5 — initial read-only overlay (layer 20). 3 party cards (portrait, name, class, HP, attributes) + inventory bag. Equipment rows resolve via EquipmentLibrary. Dead members greyed with DEFEATED stamp. "Party" button in `MapManager._add_ui_chrome()`. |
