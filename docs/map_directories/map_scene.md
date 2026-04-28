# System: Map Scene

> Last updated: 2026-04-27 (Level-Up — party button glow, UI chrome layout, Dev Menu XP options)

---

## Purpose

`MapScene.tscn` + `MapManager.gd` display the world map as an interactive spider-web of nodes. This is the top-level navigation screen the player returns to between encounters. The player can click adjacent nodes to move their marker across the map; visited and reachable nodes are visually distinct from locked ones.

---

## Files

| File | Role |
|---|---|
| `scenes/map/MapScene.tscn` | Minimal root — root Node2D + script only |
| `scripts/map/MapManager.gd` | Owns the scene; builds all children in `_ready()` |

---

## Node Data Structure

Defined in `_build_node_data()` as `Array[Dictionary]`. Each dictionary has:

| Field | Type | Description |
|---|---|---|
| `id` | `String` | Unique key (e.g. `"badurga"`, `"node_i0"`, `"node_o11"`) |
| `position` | `Vector2` | Screen position in a 1280×720 viewport |
| `angle` | `float` | Placement angle in radians from center (used by gateway edge logic) |
| `label` | `String` | Display name shown on hover — regenerated each load via seeded name pools (not saved to disk) |
| `is_hub` | `bool` | `true` only for Badurga (center node) |
| `is_player_start` | `bool` | Vestigial flag — still set on `"node_o11"` but does not drive marker placement. Marker placement is driven by `GameState.player_node_id` (default `"badurga"`). |
| `stamp_added` | `bool` | `true` after the visited ✓ stamp Label has been added as a button child |
| `cleared_stamp_added` | `bool` | `true` after the cleared ✗ stamp Label has been added as a button child |
| `node_type` | `String` | One of `"COMBAT"`, `"VENDOR"`, `"EVENT"`, `"BOSS"`, `"CITY"` — set by `_assign_node_types()` at end of `_build_node_data()` |

### Layout

| Ring | Count | Radius from center | IDs |
|---|---|---|---|
| Center | 1 | — | `badurga` |
| Inner | 6 | 140 px | `node_i0` … `node_i5` |
| Middle | 9 | 260 px | `node_m0` … `node_m8` |
| Outer | 12 | 380 px | `node_o0` … `node_o11` |

Nodes are evenly spaced around each ring using `cos/sin`, with small per-node degree offsets to break perfect symmetry.

---

## Edge Data Structure

Defined in `_build_edge_data()` as `Array[Array]`. Each entry is `[id_a: String, id_b: String]` (treat as undirected). Also stored in `_node_map: Dictionary` (id → dict) for O(1) lookup.

Connection rules:
- Each ring: closed neighbor chain only — no chords, preventing in-ring crossings
- Hub → inner: 2 randomly selected inner nodes (shuffled each run)
- Inner → middle: 3 stratified-random gateways via `_connect_gateways_v2()`
- Middle → outer: same method + ≥30° exclusion around each inner→middle angle

Before any random call, the RNG is seeded from `GameState.map_seed`. Fresh run: `GameState.map_seed = randi()` before any builder. On reload: the saved seed is restored first — map topology is identical across sessions for a given run.

`_assign_node_types()` uses a **separate** `RandomNumberGenerator` instance seeded from the same `map_seed` (isolated from the global `seed()` call), so type assignment and edge topology are independently reproducible.

---

## Node Types

| Type | Color | Icon | Description |
|---|---|---|---|
| `COMBAT` | `Color(0.70, 0.22, 0.18)` | `X` | Standard enemy encounter |
| `VENDOR` | `Color(0.48, 0.22, 0.68)` | `$` | Buy/sell gear |
| `EVENT` | `Color(0.20, 0.42, 0.72)` | `?` | Random narrative event |
| `BOSS` | `Color(0.40, 0.08, 0.08)` | `!` | Elite enemy; extra red border (3 px, `Color(0.80, 0.15, 0.10)`) |
| `CITY` | `Color(0.85, 0.65, 0.25)` | `★` | Badurga (hub); interior deferred |

CITY is reserved exclusively for `"badurga"`.

### Type Distribution (per ring, per run)

| Ring | Nodes | Distribution |
|---|---|---|
| Outer (12) | 12 | 1 BOSS, 7 COMBAT, 3 EVENT, 1 VENDOR |
| Middle (9) | 9 | 5 COMBAT, 3 EVENT, 1 VENDOR |
| Inner (6) | 6 | 4 COMBAT, 2 EVENT |
| Center | 1 | CITY (always Badurga) |

Exactly 1 BOSS per run, always in the outer ring. BOSS assignment is deferred to `_assign_boss_type()`, which runs in `_ready()` after `_build_edge_data()` identifies the 3 middle→outer bridge nodes. The BOSS is guaranteed ≥ 2 ring-hops from any bridge endpoint (bridge node + two ring neighbors excluded). Player start (`node_o11`) is also excluded. All outer nodes are first provisioned as COMBAT/EVENT/VENDOR from a 12-slot pool; one COMBAT is then promoted to BOSS.

---

## Rendering

| Element | Implementation |
|---|---|
| Background | `ColorRect` 1280×720, `Color(0.82, 0.74, 0.58)` (parchment) |
| Edges | `Line2D` nodes, `Color(0.55, 0.42, 0.28)`, width 3 px |
| Normal nodes | `Button` with `StyleBoxFlat` circle, color from `node_type`, size 32×32 |
| BOSS node | `Button` size 44×44; preceded in tree by glow `Polygon2D` |
| Hub (Badurga) | `Button` with `StyleBoxFlat` circle, `Color(0.85, 0.65, 0.25)` gold, size 56×56 |
| BOSS glow | `Polygon2D` 32-point circle, radius 34 px, `Color(0.95, 0.15, 0.05, 0.75)`. Looping tween pulses `modulate:a` between 0.1 and 1.0, 0.8 s per phase. Added to `_map_container` **before** the button so it renders behind. |
| Type icons | `Label` child, font size 10, white, `MOUSE_FILTER_IGNORE` |
| Layer order | ColorRect → Line2Ds → BOSS glow Polygon2Ds → Buttons (+ icon Labels) → player marker → tooltip panel |

---

## Player Marker

A `Polygon2D` diamond (4 points ±10 px) in `Color(0.3, 0.6, 1.0)` (blue), centered 26 px above the current node. Stored as `_player_marker: Polygon2D`. Tweens to the new node position over 0.25 s on traversal.

Initial placement uses `GameState.player_node_id` (restored by `load_save()` if available), not the static `is_player_start` flag.

---

## Node Visual States

Applied by `_refresh_all_node_visuals()`, called at end of `_build_scene()` and after each traversal move.

| State | Condition | bg_color | Border | Modulate | Stamp |
|---|---|---|---|---|---|
| **CURRENT** | `id == GameState.player_node_id` | base color | gold `Color(0.9, 0.85, 0.3)`, 3 px | `(1,1,1,1)` | ✗ if also CLEARED (font 18, bright red, outlined, centered) |
| **REACHABLE** | adjacent to current node | base color | default `Color(0.25, 0.18, 0.10)`, 2 px | `(1,1,1,1)` | — |
| **CLEARED** | `GameState.cleared_nodes.has(id)` **and** `node_type != "CITY"` (and not current) — checked before VISITED | `base.darkened(0.35)` | default, 2 px | `(1,1,1,0.85)` | `✗` bright red `Color(1.0, 0.18, 0.12)`, font 18, dark outline, centered |
| **VISITED** | in `GameState.visited_nodes` (and not current, not cleared) | `base.darkened(0.35)` | default, 2 px | `(1,1,1,0.85)` | `✓` `Color(0.9, 0.95, 0.7)` |
| **LOCKED** | none of the above | `base.darkened(0.15)` | default, 2 px | `(1,1,1,0.5)` | — |

CLEARED nodes are traversable — the player can move through them freely. `_enter_current_node()` returns early on cleared nodes so landing/re-clicking never re-starts combat. CLEARED takes priority over VISITED. Stamps are added once per session via `stamp_added` / `cleared_stamp_added` runtime flags (not persisted). The CURRENT+CLEARED case (player standing on a just-completed node) also renders the ✗ stamp so it appears immediately without requiring movement.

---

## Traversal

`_on_node_clicked(node_id)` gates movement:

1. Ignored if `_drag_moved` (click was part of a pan).
2. If `node_id == GameState.player_node_id` → calls `_enter_current_node()` **only if `_node_prompt == null`**.
3. Ignored if `not GameState.is_adjacent_to_player(node_id, _adjacency)`.
4. Otherwise calls `_move_player_to(node_id)`.

### `_enter_current_node()`

Guards cleared nodes first — returns immediately if `GameState.cleared_nodes.has(player_node_id)`. Otherwise:

1. Increments `GameState.threat_level` by `0.05` (capped at `1.0`) — the **entry increment**. All non-cleared types count, including CITY.
2. Calls `GameState.save()`.
3. Dispatches by node type:

| Type | Action |
|---|---|
| `COMBAT` or `BOSS` | Sets `GameState.current_combat_node_id`, then `change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")` |
| `CITY` | `change_scene_to_file("res://scenes/city/BadurgaScene.tscn")` |
| `EVENT` | Calls `_get_ring(player_node_id)` → `EventSelector.pick_for_node(ring)` → `_event_manager.show_event(event_data)`. Does NOT change scene. |
| `VENDOR` | Sets `GameState.pending_node_type`, then `change_scene_to_file("res://scenes/misc/NodeStub.tscn")` |

"Keep Moving" from the node prompt avoids the entry increment (player never calls `_enter_current_node()`).

### `_move_player_to(node_id)`

- Dismisses any open node prompt.
- Calls `GameState.move_player(node_id)`.
- Increments `GameState.threat_level` by `0.05` (capped) — the **travel increment**. Always fires.
- Calls `GameState.save()`.
- Tweens marker position over 0.25 s.
- After tween: cleared nodes return early; `COMBAT`/`BOSS`/`EVENT` auto-enter; `VENDOR`/`CITY` show a yes/no prompt.
- After dispatch: `GameState.save()` always fires at the end of the method (covers VENDOR/CITY "Keep Moving" path where `_enter_current_node()` is never called).

### Node Prompt

Shown for optional nodes (VENDOR, CITY). A `PanelContainer` anchored to the root MapManager (not `_map_container`) so it stays fixed on screen. `_node_prompt: Control` holds the reference; `_dismiss_prompt()` frees it. Buttons: "Enter" → `_enter_current_node()`; "Keep Moving" → dismiss only.

### `_ready()` order

`load_save` → `init_party` (if empty) → seed `map_seed` (fresh run) → `_build_node_data` (calls `_assign_node_types`) → `_build_edge_data` (captures bridge endpoints) → `_build_adjacency` → `_assign_boss_type` (promotes one outer COMBAT, saves) → instantiate `PartySheet` → instantiate `EventManager` (connect `event_finished` + `event_nav`) → `_build_scene`.

---

## Hover Behavior

Shared `_tooltip: ColorRect` (dark panel) + `_tooltip_label: Label` child, both inside `_map_container`. Repositioned above the hovered node each time (after one `process_frame` so label size is computed). On `mouse_entered`: skip if LOCKED; otherwise show tooltip + scale to 1.25× over 0.12 s. On `mouse_exited`: scale back over 0.10 s and hide. Hub hover adds a gold `StyleBoxFlat.bg_color` tint alongside the scale. LOCKED nodes feel inert — no scale, no tooltip. Hover format: `"<node_label> [<Type>]"`.

---

## UI Chrome (screen-fixed)

Built in `_add_ui_chrome()` and `_add_threat_meter()`. Children of the root MapManager node — stay fixed while the map pans.

| Element | Position | Purpose |
|---|---|---|
| `"[MAP SCENE]"` debug label | top-left `(12, 8)` | Scene-load confirmation |
| Threat meter | left side `(12, 46)` | Run-wide danger gauge |
| `"Party"` / `"Level Up Available"` button | top-right `(VIEWPORT_SIZE.x - 180, 8)`, 172×36 | Opens `PartySheet`. Text + modulate controlled by `_refresh_party_btn()`. When any party member has `pending_level_ups > 0`: text = "Level Up Available", rainbow modulate tween + scale pulse (1.0↔1.07 sine) start; when all resolved: text = "Party", modulate reset to WHITE, tweens killed. |
| `"Dev Menu"` button | bottom-right `(VIEWPORT_SIZE.x - 314, VIEWPORT_SIZE.y - 40)`, 100×32 | Toggles the dev panel (see Dev Panel section). |
| `"Delete Save (debug)"` button | bottom-right `(VIEWPORT_SIZE.x - 210, VIEWPORT_SIZE.y - 40)`, 202×32 | Calls `GameState.delete_save()` + `reset()` then `reload_current_scene()` |

### Threat Meter — `_add_threat_meter()` / `_refresh_threat_meter()`

Vertical bar on the left edge. Built in code; fill and percentage label refs stored for live updates.

| Part | Details |
|---|---|
| "THREAT" header | Font size 11, dark red `Color(0.75, 0.18, 0.12)`, `(12, 30)` |
| Background track | `Color(0.06, 0.04, 0.03, 0.95)`, 20×120 px |
| Fill (`_threat_fill`) | Always present (height 0 when threat = 0). Height = `threat_level × 120` px, bottom-aligned. Color from `_threat_fill_color()`. Ref stored in `_threat_fill: ColorRect`. |
| Tick marks | Horizontal lines at 25 / 50 / 75 % |
| Label (`_threat_pct_lbl`) | `int(threat_level × 100)%` below bar. Ref stored in `_threat_pct_lbl: Label`. |

Fill color by quadrant (`_threat_fill_color(t: float) -> Color`): yellow-orange (0–25%) → orange (25–50%) → red-orange (50–75%) → bright red (75–100%). Quadrant breaks align with planned boss difficulty tiers (Feature 8).

`_refresh_threat_meter()` — updates `_threat_fill.size`, `_threat_fill.position`, `_threat_fill.color`, and `_threat_pct_lbl.text` from current `GameState.threat_level`. Called from: `_move_player_to()` (after travel increment), `_enter_current_node()` (after entry increment), `_on_event_finished()` (after event effects). Guards against null refs (safe to call before `_add_threat_meter()` runs, though in practice it won't be).

---

## Pan & Zoom

All map content lives in a `_map_container: Node2D` child. Background and UI chrome are root children — don't pan.

| Action | Behavior |
|---|---|
| LMB hold + drag | Pans `_map_container.position` |
| Scroll wheel | Zooms (range 0.35–2.5), pivoted on the cursor |

Pan and zoom use `_input()` (not `_unhandled_input`) so drag is captured even when the initial press lands on a node Button. A `_drag_moved: bool` flag (true when drag delta > 4 px) prevents node click callbacks from firing on a drag release.

`MapManager._input()` has an early-return guard when PartySheet is visible — see `party_sheet.md`.

---

## Edge Layout (no crossing edges)

Inter-ring connections use **quadrant-aware gateways** — topology is fixed per run (seeded from `GameState.map_seed`).

| Connection | Method |
|---|---|
| Within each ring | Closed chain of adjacent neighbors only — no chords |
| Hub → inner | 2 randomly shuffled inner nodes; hub-connected nodes excluded from IM gateways |
| Inner → middle | 3 gateways via `_connect_gateways_v2()`: circle divided into 3 sectors, one angle sampled per sector, ≥90° minimum between bridges |
| Middle → outer | Same `_connect_gateways_v2()` call, plus ≥30° exclusion around each inner→middle angle |

**`_connect_gateways_v2()` rules:**
- **Intra-pair gap (Rule A):** bridges within the same ring pair must be ≥`min_gap_deg` apart. After 5 failures in a sector, the gap relaxes by 10° increments.
- **Cross-pair exclusion (Rule B):** bridges must be ≥30° from any angle in the `excluded_angles` array.
- **Hub exclusion (Rule C):** inner nodes already used as IM gateway endpoints are excluded from hub connections.

Result: 2–3 forced bottleneck passages between each ring pair, no straight cut-through corridors.

---

## Entry Point

`MapScene.tscn` is reached after character creation (new run) or main menu "Continue". `main.tscn` loads `MainMenuScene.tscn`, which routes here. From the map, players enter encounters by moving to nodes: COMBAT, BOSS, and EVENT auto-start after the marker lands; VENDOR and CITY show a yes/no prompt. After combat or a stub scene, `EndCombatScreen` and `NodeStub` both route back to `MapScene.tscn`.

---

## PartySheet Dependency

`MapManager` instantiates `PartySheet` as a programmatic child before `_build_scene()`. The Party button in UI chrome calls `_party_sheet.show_sheet()`. Full layout, drag-drop, compare panels, and persistence details: see `party_sheet.md`.

## EventManager Dependency

`MapManager` instantiates `EventScene.tscn` as a programmatic child after `PartySheet`, before `_build_scene()`. Stored as `_event_manager: EventManager`. Signals connected:

| Signal | Handler | Behavior |
|---|---|---|
| `event_finished` | `_on_event_finished()` | Always calls `_refresh_threat_meter()` first. If `_is_dev_event` is true: clears flag and returns (no node clearing, no visual refresh). Otherwise: appends `player_node_id` to `cleared_nodes` (if not already there), calls `_refresh_all_node_visuals()`. |
| `event_nav` | `_on_event_nav(dest: String)` | If `_is_dev_event` is true: clears flag and returns (no node clearing, no scene change). Otherwise: appends `player_node_id` to `cleared_nodes`, calls `GameState.save()`, sets `pending_node_type = dest`, routes to NodeStub. |

`_get_ring(node_id: String) -> String` — private helper used in the EVENT branch of `_enter_current_node()`. Returns `"inner"` if `"node_i"` in id, `"middle"` if `"node_m"` in id, `"outer"` if `"node_o"` in id, `"outer"` as fallback for Badurga or unrecognized ids.

`_input()` early-returns when `_event_manager.visible` OR `_dev_event_panel.visible` is true, blocking pan/zoom while either overlay is open. `_on_node_clicked()` guards the same `_event_manager.visible` condition.

---

## Dev Panel

Accessed via the `"Dev Menu"` button in the map UI chrome (bottom-right). Not part of normal gameplay. Formerly labelled "Events [DEV]".

| Variable | Type | Description |
|---|---|---|
| `_is_dev_event` | `bool` | Set to `true` immediately before `show_event()` is called from dev panel. Cleared in `_on_event_finished` / `_on_event_nav`. Prevents node clearing and nav routing. |
| `_dev_event_panel` | `CanvasLayer` | `null` until first open. Built lazily by `_build_dev_event_panel()`. |
| `_add_item_panel` | `CanvasLayer` | `null` until first open. Built lazily by `_build_add_item_panel()`. Modal A-Z list of every equipment + consumable; clicking a row drops a copy into `GameState.inventory`. |
| `_party_btn` | `Button` | Reference to the Party / "Level Up Available" button. Promoted from local to class var so `_refresh_party_btn()` can update it after scene setup. |
| `_party_btn_rainbow` | `Tween` | Looping modulate tween on `_party_btn`. `null` when inactive. Killed and set to `null` when reverting to "Party" state. |
| `_party_btn_pulse` | `Tween` | Looping scale tween on `_party_btn`. Same lifecycle as `_party_btn_rainbow`. |

**`_toggle_dev_event_panel()`** — calls `_build_dev_event_panel()` on first invocation, then toggles `.visible`.

**`_refresh_party_btn()`** — reads `GameState.party` for any member with `pending_level_ups > 0`. If found: sets button text to "Level Up Available", starts `_party_btn_rainbow` (6-color looping modulate cycle, 0.32 s/step) and `_party_btn_pulse` (scale 1.0↔1.07, TRANS_SINE, 0.55 s) if not already valid; pivot set to button center. If none: resets text to "Party", modulate to WHITE, scale to ONE, kills both tweens. Called from `_ready()` (after `_build_scene()`), `_on_event_finished()`, and on `PartySheet.level_up_resolved` signal.

**`_build_dev_event_panel()`** — creates a `CanvasLayer` (layer 30) with a full-screen dark overlay and a centered `PanelContainer`. Inside (top to bottom): title + close; **XP/LEVEL section** ("Grant XP +20 (all)" + "Force Level-Up (all)", both call `_refresh_party_btn()`); separator; **COMBAT section** with three side-by-side buttons — "⚔ Test Room — Armor Showcase" (armor_showcase), "⚔ Test Room — Armor Mod" (armor_mod), "⊕ Test Room — Recruit" (recruit_test). All three set `GameState.test_room_mode = true` + the matching `test_room_kind`, hide the panel, and `change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")`; `_end_combat()` returns without saving or XP. Separator; **INVENTORY section** with three side-by-side buttons in an `HBoxContainer` — "+ Add Item to Inventory" (calls `_show_add_item_panel()`), "⊕ Add Random to Bench" (picks a random non-RogueFinder archetype via `ArchetypeLibrary.all_archetypes()`, calls `ArchetypeLibrary.create()` with `is_player=true`, calls `GameState.add_to_bench()`; push_warning if bench full), and **"+ Give Gold +100"** (increments `GameState.gold` by 100 and calls `GameState.save()`). Separator; **EVENTS section** with a `ScrollContainer` containing one `Button` per event from `EventLibrary.all_events()`.

**`_show_add_item_panel()` / `_build_add_item_panel()` / `_refresh_add_item_list()`** — separate `CanvasLayer` modal (layer 30) listing every `EquipmentLibrary.all_equipment()` row plus every `ConsumableLibrary.all_consumables()` row, sorted A-Z by display name. Each list row shows `"<name>  [<slot>]"` (slot is `Weapon`/`Armor`/`Accessory` for equipment or `Consumable` for consumables) and is a clickable button. Clicking calls `GameState.add_to_inventory({id, name, description, item_type})` then `GameState.save()` and closes the panel. The list rebuilds via `_refresh_add_item_list()` every time the panel opens so newly-added CSV rows appear without restart. `_input()` early-out gate extended so map drag/zoom is suppressed while the panel is visible.

**`_on_dev_event_selected(event_data: EventData)`** — hides panel, sets `_is_dev_event = true`, calls `_event_manager.show_event(event_data)`.

**Dev-fired events do NOT:**
- Add the event's id to `GameState.used_event_ids` (EventSelector is bypassed)
- Clear the current map node
- Route to vendor/bench on nav effects (nav returns silently)

---

## Gotchas

- **`_input()` not `_unhandled_input()`** — intentional so pan drag is captured when a press starts on a Button node. Don't change. PartySheet, EventManager, and dev panel visibility guards all live here.
- **CITY nodes never get the ✗ stamp** — `is_cleared` excludes `node_type == "CITY"`. Badurga is a repeatable hub, not a clearable node. Do not remove this guard.
- **`_enter_current_node()` is the cleared-node guard, not `_on_node_clicked()`** — cleared nodes are fully traversable. Don't add a click guard back.
- **`current_combat_node_id` must be set before `change_scene_to_file()`** — transient field that EndCombatScreen reads post-transition.
- **MapManager holds no persistent state** — all run-wide data lives in `GameState`. Map rebuilds from scratch every load.
- **`seed()` is a global call** — `_build_edge_data()` calls Godot's global `seed()`. Use `RandomNumberGenerator` instances for independent RNG streams (see `_assign_node_types()`).
- **`GameState.reset()` must stay in sync with GameState fields** — debug delete-save calls `reset()` before reload. New persistent fields need `reset()` additions.
- **Type icons use `MOUSE_FILTER_IGNORE`** — or they intercept mouse events and prevent button presses.
- **`node_types` is saved by `_assign_boss_type()`, not `_assign_node_types()`** — on reload both steps skip (non-empty dict / `"BOSS"` already assigned).
- **Node labels and `stamp_added` flags are NOT saved** — labels regenerate from `map_seed`; stamp flags are per-session only.
- **`map_seed` must be set before `_build_node_data()`** — moved to `_ready()` so names and edges share the same seed.
- **`hover_style` snapshot** — built once from `normal_style`, not refreshed when `_refresh_all_node_visuals()` darkens the base. Known, accepted.

---

## Explicitly Deferred

- Badurga section content — 6 of 8 section buttons are stubs. "Party Management" and "Hire Roster" are live.
- Vendor scene content — `NodeStub` placeholder.
- Fog of war.

---

## Recent Changes

| Date | Session | What changed |
|---|---|---|
| 2026-04-23 | S28 | Doc split — PartySheet section moved to `party_sheet.md`. No `MapManager` behavior change. |
| 2026-04-28 | Rarity Foundation | **Add Item modal: rarity color treatment + rarity in inventory dict.** `_refresh_add_item_list()` now includes `"rarity": eq.rarity` in each equipment row dict. Equipment button text colored via `EquipmentData.RARITY_COLORS[row["rarity"]]`. `_on_add_item_selected()` passes `"rarity"` through to `GameState.add_to_inventory()`. All items are COMMON (grey) until Slices 3–5 add higher-tier content. |
| 2026-04-28 | Follower Slice 6 | **Dev panel: "+ Give Gold +100" button added to INVENTORY section.** Third button in the HBoxContainer row. Increments `GameState.gold` by 100 and saves. |
| 2026-04-28 | Follower Slice 5 | **Dev panel: Recruit test room + Add Random to Bench.** COMBAT section gained "⊕ Test Room — Recruit" button (sets `test_room_kind = "recruit_test"`). INVENTORY section refactored: two buttons now side-by-side in an HBoxContainer — existing "+ Add Item to Inventory" unchanged; new "⊕ Add Random to Bench" picks a random non-RogueFinder archetype and calls `GameState.add_to_bench()`. |
| 2026-04-27 | Armor Mod / Inventory dev | **Second test room + Add Item dev section.** Existing "⚔ Test Room" button renamed "⚔ Test Room — Armor Showcase"; new sibling "⚔ Test Room — Armor Mod" added in the same row, sets `GameState.test_room_kind = "armor_mod"` (alongside `test_room_mode = true`). New "INVENTORY" section in the dev panel with "+ Add Item to Inventory" button — opens a separate `CanvasLayer` modal listing every equipment + consumable in A-Z order; click any row to drop a copy into `GameState.inventory`. List populated lazily and refreshed on every open (hot-reload friendly). `_input()` early-out gate extended so map drag/zoom is suppressed while the add-item panel is visible. |
| 2026-04-27 | Dual Armor | **Test Room button added to dev panel.** "⚔ Test Room (armor showcase)" button added to COMBAT section of dev panel. Sets `GameState.test_room_mode = true` and transitions to `CombatScene3D`. Combat scene spawns hardcoded 3v3 (see `combat_manager.md`). Returns to map on combat end with no save mutation or XP. |
| 2026-04-27 | Level-Up | **Party button glow + UI chrome layout + Dev Menu XP options.** Party button promoted to `_party_btn: Button` class var; `_party_btn_rainbow: Tween` and `_party_btn_pulse: Tween` class vars added. `_refresh_party_btn()` added: shows "Level Up Available" (gold) with rainbow modulate + scale pulse when any member has pending picks; reverts to "Party" (white, no animation) when all resolved; called from `_ready()`, `_on_event_finished()`, and `PartySheet.level_up_resolved` signal. UI chrome layout changed: Party button moved to sole top-right position (172×36 px); "Dev Menu" + "Delete Save" moved to bottom-right corner (100×32 and 202×32 px). Dev panel renamed "Dev Menu"; XP/LEVEL section added at top with "Grant XP +20 (all)" and "Force Level-Up (all)" buttons. `_ready()` now also connects `_party_sheet.level_up_resolved` → `_refresh_party_btn`. |
| 2026-04-25 | Events Slice 6 | **Dev event panel + live threat meter + CITY stamp guard.** `_toggle_dev_event_panel()`, `_build_dev_event_panel()`, `_on_dev_event_selected()` added. `_is_dev_event: bool` and `_dev_event_panel: CanvasLayer` instance vars added. `_on_event_finished()` and `_on_event_nav()` both check `_is_dev_event` first — if true, clear flag and return without clearing nodes or routing. `_input()` gains `_dev_event_panel.visible` guard. Threat meter: fill rect always created (was conditional on `t > 0.0`); `_threat_fill: ColorRect` and `_threat_pct_lbl: Label` refs stored; `_refresh_threat_meter()` added; called from `_move_player_to()`, `_enter_current_node()`, and `_on_event_finished()`. Visual: `is_cleared` in `_refresh_all_node_visuals()` now excludes `node_type == "CITY"` — Badurga never shows ✗. |
| 2026-04-25 | Events Slice 4 | `_event_manager: EventManager` field added. `_ready()` instantiates `EventScene.tscn` after `PartySheet`; connects `event_finished` → `_on_event_finished()` and `event_nav` → `_on_event_nav()`. `_enter_current_node()`: EVENT branch now calls `EventSelector.pick_for_node(_get_ring(...))` + `_event_manager.show_event()` instead of NodeStub. `_get_ring()` private helper added. `_input()` gains `_event_manager.visible` early-return guard. `_on_node_clicked()` guards same condition. Cleared stamp: CURRENT+CLEARED case now also renders ✗; stamp font size 18, bright red, dark outline, centered via PRESET_FULL_RECT. EVENT nodes appended to `cleared_nodes` by both `_on_event_finished` and `_on_event_nav`. |
| 2026-04-24 | Events Slice 3 | `_move_player_to()`: `GameState.save()` added at end of method after dispatch block, covering VENDOR/CITY "Keep Moving" path. |
| 2026-04-20 | S24+S25 | RECRUIT removed. Inner ring → 4 COMBAT + 2 EVENT. Outer → 1 BOSS + 7 COMBAT + 3 EVENT + 1 VENDOR. BOSS assignment extracted to `_assign_boss_type()`; bridge endpoints captured into `_outer_bridge_ids`. |

For older history, see `git log -- scripts/map/MapManager.gd`.
