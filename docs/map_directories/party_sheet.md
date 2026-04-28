# System: Party Sheet

> Last updated: 2026-04-27 (XP + Level-Up system — level indicator, level-up overlay, level_up_resolved signal)

---

## Purpose

Full-screen interactive overlay for reviewing and managing the party. Opened from the "Party" / "Level Up Available" button in `MapManager`'s UI chrome. This is where the player equips gear, swaps abilities, compares items, reads stat blocks, and resolves level-up picks between encounters.

Runs on `CanvasLayer` at layer 20 — above every other overlay in the map scene. The level-up pick overlay runs at layer 25, above the party sheet itself. All mutations write directly to the live `CombatantData` instances in `GameState.party`; equipment/ability mutations are NOT saved immediately — `GameState.save()` is called explicitly by the level-up path only (feat grant + pending decrement).

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
| `GameState` | Reads `party` and `inventory` directly on every `show_sheet()` call and after every mutation; `grant_feat()` + `save()` called from level-up overlay; `sample_ability_candidates()` + `sample_feat_candidates()` used to build pick pools |
| `EquipmentLibrary` | Resolves equipment ids (when a slot holds an id string rather than an `EquipmentData` instance) |
| `ConsumableLibrary` | Resolves consumable ids for tooltip + compare panels |
| `AbilityLibrary` | Resolves ability ids for the ability pool tab, slot labels, and level-up pick cards |
| `FeatLibrary` | Resolves each id in `member.feat_ids` to `FeatData` (name + description) for the Feats tab and level-up feat cards |
| `ClassLibrary` | Used indirectly via `GameState.sample_ability_candidates()` / `sample_feat_candidates()` |
| `KindredLibrary` | Used indirectly via `GameState.sample_ability_candidates()` |
| `BackgroundLibrary` | Used indirectly via `GameState.sample_feat_candidates()` |
| `MapManager` | Owns the `PartySheet` instance; listens for `level_up_resolved` to refresh the party button; the `_input()` guard blocks map pan/zoom while the sheet is visible |

---

## Signals

| Signal | Args | Description |
|--------|------|-------------|
| `level_up_resolved` | — | Emitted after the last pending level-up pick overlay closes. `MapManager` listens to refresh the party button glow. |

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

**New-item glow (Slice 5):** Items with `seen == false` render with a gold/amber border + looping alpha pulse. On `mouse_entered`, `item["seen"] = true` and `_rebuild()` fires. Only unseen items get the hover connection.

**Rarity color treatment (Rarity Foundation):** For equipment items, the card border and item name text are colored by `EquipmentData.RARITY_COLORS[item.get("rarity", 0)]`. The unseen gold border takes priority — when `seen == false`, the gold glow overrides the rarity border. Name color is neutral (`Color(0.92, 0.88, 0.78)`) for consumables regardless of rarity. Old inventory dicts without a `rarity` key default to COMMON (0).

### MIDDLE (500 px) — Three member cards stacked

Each card divided into 4 quadrants by 50%-alpha separators:

- **TOP-LEFT:** Name (17 px), Class (13 px gold), Background (13 px green), Kindred (13 px blue-grey), **Temperament (11 px purple — "Temp: Fierce (+STR/-DEX)" or "Temp: Even")**, HP row — text "HP x/x" left-aligned + bar filling remaining width on the same line. Attribute value labels (STR/DEX/COG/WIL/VIT) are plain yellow — green/red tinting is reserved for future equipment stat indicators.
- **TOP-RIGHT:** Derived stats — Speed / P.Def / M.Def / EN Max (blue, 4 cols). `P.Def` = `physical_defense`; `M.Def` = `magic_defense`. Base attributes — STR / DEX / COG / WIL / VIT (yellow, 5 cols). **Level row** (below attributes): "Lv. X" (13 px, blue-grey, centered in TR width) OR "Level Up! (N)" button when `pending_level_ups > 0` (rainbow modulate tween + scale pulse 1.0↔1.07; draws on top of the level label which is suppressed when pending > 0). All labels: `tooltip_text` + `MOUSE_FILTER_PASS`. Abbreviation helper `_stat_abbrev(stat)` maps `"physical_armor"` → `"P.DEF"`, `"magic_armor"` → `"M.DEF"`.
- **BOTTOM-LEFT:** "EQUIPMENT" + 2×2 grid. Each slot is a flat `Button` with sprite icon. Drop target via `set_drag_forwarding()`. **Right-click** an occupied slot to unequip. Dragging bag item over a filled slot shows a compare panel. Disabled when dead. **Occupied slot button text color:** `EquipmentData.RARITY_COLORS[eq.rarity]` — grey for COMMON, escalating for higher tiers. Empty/consumable slots keep their default neutral color.
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

## Level-Up Overlay (CanvasLayer layer 25)

Opened from the "Level Up! (N)" button in a member card. Runs above the party sheet (layer 25 vs layer 20).

**Entry point:** `_start_level_up(pc: CombatantData)` — finds `pc`'s index in `GameState.party`, builds the overlay, and calls `_fill_next_pick()`.

**Pick routing** — `_fill_next_pick(content, overlay, pc, pc_index)`:
- Computes `pick_level = pc.level - pc.pending_level_ups + 1` to identify which historical level is being resolved.
- `pick_level % 2 == 0` → `_fill_ability_phase()` (ability pick).
- `pick_level % 2 == 1` → `_fill_feat_phase()` (feat pick).
- This correctly orders picks for multi-level batches (e.g., 3 pending at level 4 → picks for lv2/lv3/lv4 in order).

**Each phase** shows a title ("Level Up! — Name"), a subtitle ("Choose an Ability" / "Choose a Feat"), and 3 horizontal pick cards (`_build_pick_card()`). Fewer than 3 cards if the pool is smaller. If the pool is empty, the phase is silently skipped.

**`_build_pick_card(title, subtitle, desc, on_pick)`** — shared helper for both ability and feat phases. Returns a `PanelContainer` with dark background, hover gold-border highlight, and a click handler. Style mirrors `EndCombatScreen`'s reward cards — update both together to keep visual consistency.

**`_finish_level_up(overlay, content, pc, pc_index)`**:
1. Decrements `pc.pending_level_ups`.
2. Calls `GameState.save()`.
3. If `pending_level_ups > 0`: calls `_fill_next_pick()` to show the next pick immediately in the same overlay — no overlay close/reopen.
4. If `pending_level_ups == 0`: calls `overlay.queue_free()`, `_rebuild()`, `level_up_resolved.emit()`.

**Persistence gotcha:** ability picks (`pc.ability_pool.append()`) are NOT saved until `_finish_level_up()` calls `GameState.save()`. Feat picks call `GameState.grant_feat()` which saves internally AND then `_finish_level_up()` saves again — double-save is harmless.

---

## Persistence

**Equipment/ability mutations** write to the live `CombatantData` in `GameState.party[i]` but do NOT call `GameState.save()` — the map saves on next travel. **Level-up picks** call `GameState.save()` explicitly (via `_finish_level_up()`). Dead members cannot be equipped (drop rejected, buttons disabled). Instance vars (`_sort_fields`, `_search_texts`, `_abil_views_wide`, etc.) survive `_rebuild()` but reset on scene reload.

---

## Recent Changes

| Date | Session | What changed |
|---|---|---|
| 2026-04-28 | Rarity Foundation | **Rarity color treatment.** Bag item cards (`_build_draggable_item`): border uses `EquipmentData.RARITY_COLORS[rarity]` for equipment when `seen == true` (gold pulse still takes priority when unseen); item name label uses rarity color for equipment, neutral for consumables. Equipment slot buttons (BL quadrant): occupied slot font color set to `RARITY_COLORS[eq.rarity]`. Old inventory dicts without `rarity` default to COMMON (0). `_push_equipment_to_bag()` now includes `"rarity": eq.rarity` in the dict. |
| 2026-04-27 | Temperament | **Temperament line added to TOP-LEFT.** After the Kindred line, a new "Temp: \<name\> (+STAT/-STAT)" label (11 px, purple-grey `Color(0.72, 0.55, 0.80)`) shows the temperament name and affected stats. Neutral ("Even") shows just the name with no suffix. Attribute value labels (STR/DEX/COG/WIL/VIT) remain plain yellow — green/red reserved for future equipment-based stat modification indicators. `TemperamentLibrary` added as dependency (called once per card build). Kindred row spacing reduced to 16 px (was 18) to make room. |
| 2026-04-27 | Dual Armor | **Derived stats replaced Defense with P.Def + M.Def.** TOP-RIGHT derived stat row changed from Speed/Defense/EN Max/EN Regen to Speed/P.Def/M.Def/EN Max. P.Def shows `member.physical_defense`; M.Def shows `member.magic_defense`. `_stat_abbrev()` updated: `"physical_armor"` → `"P.DEF"`, `"magic_armor"` → `"M.DEF"`. |
| 2026-04-27 | Level-Up | **XP + Level-Up system.** `level_up_resolved` signal added. TR quadrant now shows "Lv. X" (centered, font 13, blue-grey) below STR/DEX/COG/WIL/VIT; label suppressed when `pending_level_ups > 0`. "Level Up! (N)" button shown instead: centered in TR, rainbow modulate tween (red→orange→yellow→green→blue→purple, 0.32 s/step), scale pulse 1.0↔1.07 (0.55 s, TRANS_SINE). Level-up overlay (layer 25): `_start_level_up()` → `_fill_next_pick()` routes by `pick_level % 2`; even = ability, odd = feat. Each phase shows 3 horizontal `_build_pick_card()` cards (style mirrors EndCombatScreen). Multiple pending picks chain back-to-back in one overlay via `_finish_level_up()` → `_fill_next_pick()` loop. `GameState.save()` called on each pick resolution. `level_up_resolved` emitted when all pending are resolved. |
| 2026-04-25 | Slice 5 | **New-item glow.** `_build_draggable_item` checks `item.get("seen", true)`. Unseen items get gold border + looping alpha tween (0.7→1.0, 0.8 s). `mouse_entered` sets `seen = true` on the live dict (shared reference from `GameState.inventory` via shallow `Array.duplicate()`) and calls `_rebuild()`, clearing the glow. |
| 2026-04-24 | Slice 2 | **Feats tab upgraded from placeholder.** Full Abilities-tab-style layout: 1×/2× toggle, Name sort, search bar, scrollable `PanelContainer` feat cards with hover tooltip. Three new per-member state arrays (`_feat_views_wide`, `_feat_sort_ascs`, `_feat_search_texts`). `FeatLibrary` added as dependency. Source is `member.kindred_feat_id` only — Slice 4 extends when `CombatantData.feats` lands. |
| 2026-04-23 | S28 | Kindred label (blue-grey, 13 px) added to TOP-LEFT card below Background. HP row restructured: "HP x/x" text now left-aligned on the same row as the bar. Column widths rebalanced: LEFT 240→376 px, MIDDLE 530→500 px, RIGHT 480→374 px (~30/40/30). Horizontal divider moved y+108→y+118 for the extra text line. |
| 2026-04-20 | S23 | Ability Pool Swap. Drag from Abilities tab onto BOTTOM-RIGHT slots; right-click to clear. Per-member sort/search/view in ability panel (backwards-typing bug fixed via focus+caret restoration). Inventory column upgraded with sort/search/view. Drag-compare panels for all three categories (ability, equipment, consumable) via shared helpers. Opaque tooltip theme + `_wrap_tooltip()`. `_process()` auto-clears compare overlay when drag ends. |
| 2026-04-20 | S22 | Layout redesign. 4-quadrant card layout with full-height + full-width 50%-alpha separators. TOP-LEFT name/class/bg/HP. TOP-RIGHT derived + attrs. BOTTOM-LEFT equipment 2×2. BOTTOM-RIGHT slotted abilities 2×2. Right panel replaced with `TabContainer` (Abilities + Feats placeholder). `_detail_open` pattern removed — fully stateless `_rebuild()`. |
| 2026-04-20 | S21 | Drag-drop gear management via native `set_drag_forwarding()` lambdas. Click filled slot to unequip. Dead member slots disabled + drop rejected. `MapManager._input()` early-return guard. Sprite icons for slot types. Tooltips on all stats, equipment, abilities, inventory items. |
| 2026-04-20 | S20 | Party Sheet Slice 5 — initial read-only overlay (layer 20). 3 party cards (portrait, name, class, HP, attributes) + inventory bag. Equipment rows resolve via EquipmentLibrary. Dead members greyed with DEFEATED stamp. "Party" button in `MapManager._add_ui_chrome()`. |
