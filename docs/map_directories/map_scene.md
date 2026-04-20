# Map Scene

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

Defined in `_build_edge_data()` as `Array[Array]`. Each entry is `[id_a: String, id_b: String]` (treat as undirected).

Also stored in `_node_map: Dictionary` (id → dict) for O(1) lookup by id during edge construction and gateway placement.

Connection rules (see also "Edge Layout" section below for the no-crossing design rationale):

- Each ring: closed neighbor chain only — no chords, preventing in-ring crossings
- Hub → inner: 2 randomly selected inner nodes (shuffled each run)
- Inner → middle: 3 stratified-random gateways (randomized each run)
- Middle → outer: 3 stratified-random gateways (randomized each run)

`_build_node_data()` ends by calling `_assign_node_types()`. This method uses a **separate** `RandomNumberGenerator` instance seeded from `GameState.map_seed` (isolated from the global `seed()` call in `_build_edge_data()`), so type assignment and edge topology are independently reproducible from the same seed.

Before any random call in `_build_edge_data()`, the RNG is seeded from `GameState.map_seed`. On a fresh run `GameState.map_seed` is `0`, so MapManager generates a seed via `randi()` and stores it; on subsequent loads the saved seed is restored first. This makes the map topology identical across sessions for a given run.

---

## Adjacency Lookup

Built in `_build_adjacency()` after `_build_edge_data()`. Stored in `_adjacency: Dictionary` (id → `Array[String]`). Each edge is added in both directions (undirected graph). Used by `GameState.is_adjacent_to_player()`.

---

## Node Types

Five node types give each encounter a distinct identity.

| Type | Color | Icon | Description |
|---|---|---|---|
| `COMBAT` | `Color(0.70, 0.22, 0.18)` | `X` | Standard enemy encounter |
| `VENDOR` | `Color(0.48, 0.22, 0.68)` | `$` | Buy/sell gear |
| `EVENT` | `Color(0.20, 0.42, 0.72)` | `?` | Random narrative event |
| `BOSS` | `Color(0.40, 0.08, 0.08)` | `!` | Elite enemy; extra red border (3 px, `Color(0.80, 0.15, 0.10)`) |
| `CITY` | `Color(0.85, 0.65, 0.25)` | `★` | Badurga (hub); interior deferred |

CITY is reserved exclusively for `"badurga"`. The icon is a small `Label` child (font size 10, white) with `MOUSE_FILTER_IGNORE` so it doesn't swallow button press events.

### Type Distribution (per ring, per run)

| Ring | Nodes | Distribution |
|---|---|---|
| Outer (12) | 12 | 1 BOSS, 8 COMBAT, 2 EVENT, 1 VENDOR |
| Middle (9) | 9 | 5 COMBAT, 3 EVENT, 1 VENDOR |
| Inner (6) | 6 | 2 VENDOR, 4 EVENT |
| Center | 1 | CITY (always Badurga) |

Player start node (`node_o11`) is never BOSS — swap logic protects it during assignment. Exactly 1 BOSS per run, always in the outer ring.

---

## Rendering

| Element | Implementation |
|---|---|
| Background | `ColorRect` 1280×720, `Color(0.82, 0.74, 0.58)` (parchment) |
| Edges | `Line2D` nodes, `Color(0.55, 0.42, 0.28)`, width 3 px |
| Normal nodes | `Button` with `StyleBoxFlat` circle, color derived from `node_type`, size 32×32 |
| BOSS node | `Button` size 44×44 (larger than normal); preceded in tree by glow `Polygon2D` |
| Hub (Badurga) | `Button` with `StyleBoxFlat` circle, `Color(0.85, 0.65, 0.25)` (gold), size 56×56 |
| Default node borders | 2 px, `Color(0.25, 0.18, 0.10)` |
| BOSS node borders | Always 3 px, `Color(0.80, 0.15, 0.10)` bright red |
| BOSS glow | `Polygon2D` 32-point circle, radius 34 px, `Color(0.95, 0.15, 0.05, 0.75)`. Looping tween pulses `modulate:a` between 0.1 and 1.0, 0.8 s per phase, TRANS_SINE. Added to `_map_container` **before** the button so it renders behind it. |
| Type icons | `Label` child, font size 10, white, `MOUSE_FILTER_IGNORE` |
| Layer order | ColorRect → Line2Ds → BOSS glow Polygon2Ds → Buttons (+ icon Labels) → player marker → tooltip panel |

---

## Player Marker

A `Polygon2D` diamond (4 points ±10 px) in `Color(0.3, 0.6, 1.0)` (blue), centered 26 px above the current node. Stored as `_player_marker: Polygon2D`. On traversal it tweens to the new node position over 0.25 s (TRANS_QUAD, EASE_IN_OUT).

Initial placement at scene load uses `GameState.player_node_id` (which may have been restored by `load_save()`), not the static `is_player_start` flag on the node dict. The `is_player_start` field is kept on node dicts for future run-reset logic but does not drive marker placement.

---

## Node Visual States

Applied by `_refresh_all_node_visuals()`, called at end of `_build_scene()` and after each traversal move.

| State | Condition | bg_color | Border | Modulate | Stamp |
|---|---|---|---|---|---|
| **CURRENT** | `id == GameState.player_node_id` | base color | gold `Color(0.9, 0.85, 0.3)`, 3 px | `(1,1,1,1)` | — |
| **REACHABLE** | adjacent to current node | base color | default `Color(0.25, 0.18, 0.10)`, 2 px | `(1,1,1,1)` | — |
| **CLEARED** | `GameState.cleared_nodes.has(id)` (and not current) — checked before VISITED | `base.darkened(0.35)` | default, 2 px | `(1,1,1,0.85)` | `✗` muted red `Color(0.75, 0.25, 0.20)` |
| **VISITED** | in `GameState.visited_nodes` (and not current, not cleared) | `base.darkened(0.35)` | default, 2 px | `(1,1,1,0.85)` | `✓` `Color(0.9, 0.95, 0.7)` |
| **LOCKED** | none of the above | `base.darkened(0.15)` | default, 2 px | `(1,1,1,0.5)` | — |

CLEARED nodes are traversable — the player can move through them freely. Hover behavior is the same as normal nodes (tooltip + scale animation). The only difference: `_enter_current_node()` returns early when `GameState.cleared_nodes.has(GameState.player_node_id)`, so landing on or re-clicking a cleared node never re-starts combat. CLEARED takes priority over VISITED in `_refresh_all_node_visuals()` since a cleared node is always also visited.

Stamps are added once per session — `nd["stamp_added"]` and `nd["cleared_stamp_added"]` prevent duplicates.

---

## Traversal

`_on_node_clicked(node_id)` gates movement:

1. Ignored if `_drag_moved` (click was part of a pan)
2. If `node_id == GameState.player_node_id` → calls `_enter_current_node()` **only if `_node_prompt == null`** (re-click to enter current node; no-ops if a prompt is already showing or the node is cleared)
3. Ignored if `not GameState.is_adjacent_to_player(node_id, _adjacency)` (not reachable)
4. Otherwise calls `_move_player_to(node_id)` to traverse

### Scene Entry — `_enter_current_node()`

Guards cleared nodes first — returns immediately (no entry increment) if `GameState.cleared_nodes.has(player_node_id)`. Otherwise:

1. Increments `GameState.threat_level` by `0.05` (capped at `1.0`) — the **entry increment**. All non-cleared node types including CITY count.
2. Calls `GameState.save()`.
3. Dispatches based on node type:

| Node type | Action |
|---|---|
| `COMBAT` or `BOSS` | Sets `GameState.current_combat_node_id = GameState.player_node_id`, then `change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")` |
| `CITY` | `change_scene_to_file("res://scenes/city/BadurgaScene.tscn")` — loads the Badurga city shell |
| `VENDOR`, `EVENT` | Sets `GameState.pending_node_type = node_type`, then `change_scene_to_file("res://scenes/misc/NodeStub.tscn")` |

`NodeStub` reads and clears `GameState.pending_node_type` in `_ready()` and shows a placeholder screen with a "← Return to Map" button.

**City entry increments threat** — entering Badurga counts as entering a node. "Keep Moving" from the node prompt avoids the entry increment (player never calls `_enter_current_node()`).

`_move_player_to(node_id)`:
- Dismisses any open node prompt via `_dismiss_prompt()`
- Calls `GameState.move_player(node_id)` (updates player position + visited list)
- Increments `GameState.threat_level` by `0.05` (capped at `1.0`) — the **travel increment**. Always fires regardless of node type or cleared status.
- Calls `GameState.save()` (persists travel increment to disk)
- Tweens `_player_marker.position` to `node_map[node_id]["position"] + Vector2(0, -26)` over 0.25 s
- Calls `_refresh_all_node_visuals()`
- `await tween.finished` — then:
  - If `cleared_nodes.has(node_id)`: returns early (cleared nodes are pass-through — no entry increment)
  - If node type is `COMBAT`, `BOSS`, or `EVENT`: calls `_enter_current_node()` immediately — **auto-starts the encounter** (also fires entry increment)
  - If node type is `VENDOR` or `CITY`: calls `_show_node_prompt(node_id)` — shows a yes/no panel asking the player to enter or keep moving

### Node Prompt

Shown for optional nodes (VENDOR, CITY) after the marker lands. A `PanelContainer` anchored to the root MapManager (not `_map_container`) so it stays fixed on screen while the map pans. Positioned bottom-center after one `process_frame` await so the panel's computed size is available.

| Field / Method | Description |
|---|---|
| `_node_prompt: Control` | Reference to the current prompt panel; `null` when no prompt is showing |
| `_show_node_prompt(node_id)` | Builds and displays the panel: node name + type header, one-line description, "Enter" and "Keep Moving" buttons |
| `_dismiss_prompt()` | `queue_free()`s the panel if valid; sets `_node_prompt = null` |
| `_on_prompt_enter(node_id)` | Dismisses prompt then calls `_enter_current_node()` |
| `_on_prompt_pass()` | Dismisses prompt; player stays at the node without entering |
| `_desc_for_type(t)` | Returns a one-line string description for a given node type (used in both tooltip and prompt) |

Panel style: dark background `Color(0.07, 0.05, 0.03, 0.94)`, 2-px border in the node's type color, rounded corners. Re-clicking the current node while a prompt is open does nothing (the `_on_node_clicked` guard checks `_node_prompt == null`).

`_ready()` order after save/load integration:
1. `GameState.load_save()` — restore saved state (or no-op on fresh run)
2. `GameState.init_party()` — seeds party with PC + 2 allies if `party.is_empty()` (i.e., fresh run or old save with no party key). No-ops if party was loaded from disk.
3. Initialize `map_seed` if zero (fresh run): `GameState.map_seed = randi()` — must happen before node data so names and edge topology share the same seed
4. `_build_node_data()` — define all 28 nodes with placeholder labels; calls `_assign_node_types()` at the end (which assigns seeded names + types)
5. `_build_edge_data()` — seed global RNG from `GameState.map_seed`, build deterministic edges via `_connect_gateways_v2()`
6. `_build_adjacency()` — build undirected adjacency dict
7. Instantiate `PartySheet` — `_party_sheet = PartySheet.new(); add_child(_party_sheet)` — must happen before `_build_scene()` so the Party button can bind to it
8. `_build_scene()` — render everything; marker placed at `GameState.player_node_id`

---

## Hover Behavior

Uses a shared `_tooltip: ColorRect` (dark panel, `Color(0.10, 0.08, 0.06, 0.88)`) with a `_tooltip_label: Label` child. Both live inside `_map_container` so they pan/zoom with the map. The tooltip is repositioned above the hovered node each time (after one `process_frame` await so the label size is computed first).

| Event | Behavior |
|---|---|
| `mouse_entered` | Skip entirely if node is LOCKED; otherwise show `_tooltip` panel above the node (name + type header, one-line description); tween scale → `Vector2(1.25, 1.25)` over 0.12 s |
| `mouse_exited` | Tween scale → `Vector2(1.0, 1.0)` over 0.10 s; hide `_tooltip` |
| Hub hover enter | Same scale tween + tint `StyleBoxFlat.bg_color` to `Color(1.0, 0.85, 0.4)` over 0.12 s |
| Hub hover exit | Tint returns to `Color(0.85, 0.65, 0.25)` over 0.10 s |

LOCKED nodes feel inert — no scale animation, no label. CLEARED nodes behave like normal nodes for hover (tooltip + scale) — they are still traversable pass-through points.

Hover label format: `"<node_label> [<Type>]"` (e.g. `"Ashwood Hollow [Combat]"`, `"Badurga [City]"`). Type string is capitalized via `.capitalize()`.

---

## UI Chrome (screen-fixed, not in `_map_container`)

Built in `_add_ui_chrome()` and `_add_threat_meter()`. These elements are children of the root MapManager node, so they stay fixed on screen while the map pans.

| Element | Position | Purpose |
|---|---|---|
| `"[MAP SCENE]"` label | top-left `(12, 8)` | Debug: visual confirmation of scene load |
| Threat meter | left side `(12, 46)` | Run-wide danger gauge — see below |
| `"Party"` button | top-right `(VIEWPORT_SIZE.x - 300, 8)`, 80×36 | Opens `PartySheet` overlay to review party + inventory |
| `"🗑 Delete Save (debug)"` button | top-right `(VIEWPORT_SIZE.x - 212, 8)` | Calls `GameState.delete_save()` + `GameState.reset()` then `reload_current_scene()` |

### Threat Meter — `_add_threat_meter()`

Vertical bar on the left edge (below the debug label). Built entirely in code; no stored reference needed — the map scene fully rebuilds on every load so the displayed value is always current.

| Part | Details |
|---|---|
| "THREAT" header | Font size 11, `Color(0.75, 0.18, 0.12)` dark red, at `(12, 30)` |
| Border outline | `Color(0.45, 0.35, 0.25, 0.9)`, 2 px larger than bar on all sides |
| Background track | `Color(0.06, 0.04, 0.03, 0.95)`, 20×120 px |
| Fill | Height = `threat_level × 120` px, bottom-aligned (grows upward). Color from `_threat_fill_color()`. Only rendered if `threat_level > 0.0`. |
| Tick marks | 1.5 px horizontal lines at 25 / 50 / 75 % positions — mark quadrant thresholds for boss scaling |
| Percentage label | `int(threat_level × 100)%`, below bar, font 12 |

Fill color by quadrant (`_threat_fill_color(t: float) -> Color`):

| Range | Color | Label |
|---|---|---|
| 0–25% | `Color(0.95, 0.75, 0.10)` | yellow-orange |
| 25–50% | `Color(0.95, 0.45, 0.08)` | orange |
| 50–75% | `Color(0.90, 0.22, 0.08)` | red-orange |
| 75–100% | `Color(0.85, 0.08, 0.08)` | bright red |

The quadrant breaks at 25 / 50 / 75 / 100% correspond to planned boss difficulty tiers (Feature 8).

The `"→ Combat (debug)"` button was removed in Feature 3 — real scene routing via `_enter_current_node()` replaced it.

---

## Pan & Zoom

All map content lives in a `_map_container: Node2D` child. The background and UI chrome (placeholder label, debug button) are fixed children of the root and do not move.

| Action | Behavior |
|---|---|
| LMB hold + drag | Pans the container (`_map_container.position`) |
| Scroll wheel up/down | Zooms in/out (range 0.35 – 2.5), pivoted on the cursor position |

Pan and zoom use `_input()` (not `_unhandled_input`) so drag is captured even when the initial press lands on a node Button. A `_drag_moved: bool` flag (true when drag delta > 4 px) prevents node click callbacks from firing on a drag release.

## Edge Layout (no crossing edges)

Inter-ring connections use **quadrant-aware gateways** — topology is fixed per run (seeded from `GameState.map_seed`), so the same layout reloads identically across sessions:

| Connection | Method |
|---|---|
| Within each ring | Closed chain of adjacent neighbors only — no chords |
| Hub → inner | 2 randomly shuffled inner nodes; hub-connected nodes are excluded from IM gateways |
| Inner → middle | 3 gateways via `_connect_gateways_v2()`: circle divided into 3 sectors, one angle sampled per sector, enforcing ≥90° minimum between bridges |
| Middle → outer | Same `_connect_gateways_v2()` call, plus ≥30° exclusion around each inner→middle angle |

**`_connect_gateways_v2()` rules:**
- **Intra-pair gap (Rule A):** bridges within the same ring pair must be ≥`min_gap_deg` apart. Enforced by rejecting any candidate within that gap. After 5 failures in a sector, the gap relaxes by 10° increments.
- **Cross-pair exclusion (Rule B):** bridges must be ≥30° away from any angle in the `excluded_angles` array (angles from the previous ring pair). Prevents straight outer→middle→inner corridors.
- **Hub exclusion (Rule C):** inner nodes already used as IM gateway endpoints are excluded from hub connections so the hub is not a shortcut that bypasses middle-ring traversal.

The result is 2-3 forced bottleneck passages between each ring pair, no straight cut-through corridors, and hub connections that always require at least one ring traversal.

## Entry Point

`MapScene.tscn` **is** the game entry point as of Feature 3. `main.tscn` instances `MapScene.tscn` directly. From the map, players enter encounters by moving to nodes: COMBAT, BOSS, and EVENT nodes auto-start after the marker lands; VENDOR and CITY nodes show a yes/no prompt. After combat or a stub scene, `EndCombatScreen` and `NodeStub` both route back to `MapScene.tscn`.

---

## Gotchas

- **`hover_style` is not updated by `_refresh_all_node_visuals()`** — it is a snapshot duplicate of `normal_style` made at build time (`style.duplicate()`). When `_refresh_all_node_visuals()` darkens `normal_style.bg_color` for VISITED or LOCKED nodes, the hover stylebox still lightens from the original base color. This is acceptable for now but means hover tint does not respect the dimmed state. Fix by also updating `hover_style.bg_color` in `_refresh_all_node_visuals()` if that ever becomes an issue.
- **`_input()` not `_unhandled_input()`** — intentional so pan drag is captured even when a press starts on a Button node. Do not change this without accounting for that.
- **Node dict is mutated at runtime** — `nd["stamp_added"]` is set to `true` the first time a visited stamp is added. The dict is the same object in both `_node_data` and `_node_map`, so the mutation is shared.
- **`stamp_added` and `cleared_stamp_added` are not persisted** — they are runtime-only flags to prevent double-stamping within a session. On every scene load both flags start `false`, and `_refresh_all_node_visuals()` re-adds stamps for all restored visited/cleared nodes correctly. Do not add either to the save file.
- **`_enter_current_node()` is the cleared-node guard, not `_on_node_clicked()`** — cleared nodes are fully traversable (you can click them, move to them). The guard that prevents combat re-entry lives at the top of `_enter_current_node()`. Do not add a click guard back to `_on_node_clicked()` — players need to be able to pass through cleared nodes.
- **`current_combat_node_id` must be set before `change_scene_to_file()`** — it's a transient field that EndCombatScreen reads after the scene transition. Setting it after the call would have no effect since GameState survives transitions but the assignment order matters.
- **MapManager holds no persistent state** — all run-wide data lives in `GameState`. On every scene load, `MapManager` fully rebuilds nodes, edges, adjacency, and the scene tree from scratch. Data survives because `GameState` is an autoload singleton (and is backed by `save.json`). Do not try to persist data inside `MapManager` fields directly.
- **`seed()` is a global call** — `_build_edge_data()` calls Godot's global `seed()` function, which affects all subsequent uses of the global RNG. Currently no other system shares that RNG path, but if future code uses `randf()`/`randi()` anywhere after scene load it will be seeded by the map seed. Use `RandomNumberGenerator` instances if independent RNG streams are needed.
- **`GameState.reset()` must be kept in sync with GameState fields** — the debug delete-save button calls `GameState.reset()` before reloading the scene. When new persistent fields are added to `GameState` in future features, also add them to `reset()` so the debug button continues to produce a truly clean state.
- **Type icons use `MOUSE_FILTER_IGNORE`** — the icon `Label` child of each button must have `mouse_filter = Control.MOUSE_FILTER_IGNORE` or it will intercept mouse events and prevent button presses from registering.
- **`node_types` is saved on first assignment** — `_assign_node_types()` calls `GameState.save()` after populating `node_types`. On reload, the saved dict is restored by `load_save()` and `_assign_node_types()` skips re-assignment entirely (non-empty dict check).
- **Node labels are NOT saved** — names regenerate from `map_seed` on every load via `_assign_node_names()`. The three lore pools (`INNER_NAMES`, `MIDDLE_NAMES`, `OUTER_NAMES`) are static constants; the same seed always produces the same names. Do not add `node_names` to the save file.
- **`map_seed` must be set before `_build_node_data()`** — moved from `_build_edge_data()` to `_ready()` so names and edges share the same seed. If you see node labels regenerating differently on reload, check that `map_seed` is being saved (it's saved when the player first moves via `GameState.save()`).
- **1 BOSS per run, outer ring only** — `_assign_node_types()` picks exactly one BOSS node from the outer ring. Remaining 11 outer slots are COMBAT×8, EVENT×2, VENDOR×1.

---

## Recent Changes

| Date | Session | What changed |
|---|---|---|
| 2026-04-18 | S12 Feature 4 | `current_combat_node_id` transient field; `cleared_nodes` saved; CLEARED visual state (red ✗, darkened, 0.85 alpha); cleared nodes pass-through; `_enter_current_node()` guard at top; Onward... victory step |
| 2026-04-18 | S13 Feature 5 | Procedural name pools (INNER 15 / MIDDLE 20 / OUTER 25); names regenerate from `map_seed` — not saved; outer ring reduced to exactly 1 BOSS + 1 RECRUIT + 7 COMBAT + 2 EVENT + 1 VENDOR; `_connect_gateways_v2()` replaces `_connect_gateways()` (≥90° intra-pair, ≥30° cross-pair); hub excludes inner IM gateway nodes; `map_seed` init moved to `_ready()` before builders |
| 2026-04-18 | S13 UX | Player always starts at `"badurga"` (not `"node_o11"`); Boss node size 44×44 + pulsing red `Polygon2D` glow (looping tween); EVENT nodes auto-start (no prompt); VENDOR/RECRUIT/CITY show yes/no node prompt (`_show_node_prompt` / `_dismiss_prompt`); `_desc_for_type()` helper; tooltip upgraded from bare `Label` to `ColorRect` + `Label` panel |
| 2026-04-18 | S13 EndCombatScreen | "Onward..." button removed — picking a reward immediately clears the node, saves, and returns to map |
| 2026-04-18 | S14 Feature 6 | `CITY` branch of `_enter_current_node()` now routes to `res://scenes/city/BadurgaScene.tscn` (was a no-op). Badurga city shell added with 6 placeholder section buttons + return button. |
| 2026-04-18 | S15 Feature 7 | Travel increment (+0.05) added to `_move_player_to()`. Entry increment (+0.05) added to `_enter_current_node()` (replaces int increment; city now counts). Old text label replaced with `_add_threat_meter()` vertical bar + `_threat_fill_color()` helper. |
| 2026-04-20 | S20 Party Sheet Slice 5 | `_party_sheet: PartySheet` field added to `MapManager`. Instantiated in `_ready()` before `_build_scene()`. "Party" button added to `_add_ui_chrome()` at `(VIEWPORT_SIZE.x - 300, 8)` — calls `show_sheet()`. Full layout spec lives in `scripts/party/PartySheet.gd`. |
| 2026-04-20 | S21 Party Sheet Slice 6 | Drag-and-drop gear management. Inventory bag (LEFT col) → equipment slots (MIDDLE col) via native `set_drag_forwarding()` lambdas. Click filled slot to unequip. Dead member slots disabled + drop rejected. `MapManager._input()` early-return guard blocks map pan/zoom when sheet visible. Sprite icons for slot types copied to `res://assets/icons/`. Tooltips on all stats, equipment, abilities, inventory items. |
| 2026-04-20 | S22 Party Sheet layout redesign | Full 4-quadrant card layout. Each member card divided by full-height vertical + full-width horizontal 50%-alpha separators. TOP-LEFT: name/class/bg (prominent separate lines)/HP bar. TOP-RIGHT: derived stats (blue, 4 cols) + base attributes (yellow, 5 cols). BOTTOM-LEFT: equipment 2×2 grid. BOTTOM-RIGHT: slotted abilities 2×2 grid with ability names + hover tooltips. Right panel replaced with `TabContainer` ("Abilities" pool list + "Feats" placeholder). `_detail_open` pattern removed — fully stateless `_rebuild()`. |
| 2026-04-20 | S24 Remove RECRUIT node type | RECRUIT removed from outer pool (replaced with COMBAT — outer ring is now 1 BOSS, 8 COMBAT, 2 EVENT, 1 VENDOR). Removed from `_color_for_type()`, `_icon_for_type()`, `_desc_for_type()`. Doc scrubbed throughout. |
| 2026-04-20 | S23 Ability Pool Swap (Slice 7) | `ArchetypeLibrary`: `pool_extras` key added (3 archetypes now have extras); `create()` seeds them into `ability_pool` without duplicates. `PartySheet`: drag abilities from Abilities tab onto BOTTOM-RIGHT slots; right-click slots to clear/unequip; per-member sort (Name/Type/EN), per-member search bar with focus+caret restoration fix (backwards-typing bug fixed), per-member 1×/2× view toggle for ability pool; inventory column upgraded with sort (Name/Type), search bar, 1×/2× view toggle; drag-compare panels for all three categories (ability vs ability, equipment vs equipment, consumable vs consumable); compare helpers refactored into `_make_compare_panel()` / `_make_compare_col()` / `_add_cmp_label()` / `_add_cmp_desc()`; opaque tooltip theme + `_wrap_tooltip()` word-wrap; `_process()` auto-clears compare overlay when drag ends. |

---

## PartySheet Dependency

`MapManager` instantiates `PartySheet` (from `scripts/party/PartySheet.gd`) as a programmatic child before `_build_scene()`. The Party button in UI chrome calls `_party_sheet.show_sheet()`. `PartySheet` is a `CanvasLayer` at layer 20 — above all other overlays. It reads `GameState.party` and `GameState.inventory` directly; no state is passed in.

**Public API:** `show_sheet()` / `hide_sheet()`. Internal: `_rebuild()` is the sole re-render path — fully stateless; frees and recreates all children on every call. Called on open and after every mutation. `_process()` clears the drag-compare overlay when `get_viewport().gui_is_dragging()` returns false.

**Instance state (persists across rebuilds):**

| Variable | Type | Purpose |
|---|---|---|
| `_sort_fields[3]` | `Array[String]` | Per-member sort key (`"name"`, `"attribute"`, `"energy"`) |
| `_sort_ascs[3]` | `Array[bool]` | Per-member sort direction |
| `_search_texts[3]` | `Array[String]` | Per-member ability search query |
| `_focus_search_mi` | `int` | Which member's search `LineEdit` gets focus after next rebuild (-1 = none) |
| `_abil_views_wide[3]` | `Array[bool]` | Per-member ability view mode (false=1-per-row, true=2-per-row GridContainer) |
| `_inv_search_text` | `String` | Inventory search query |
| `_inv_sort_field` | `String` | Inventory sort key (`"name"` or `"type"`) |
| `_inv_sort_asc` | `bool` | Inventory sort direction |
| `_inv_view_wide` | `bool` | Inventory view mode (false=1-per-row, true=2-per-row) |
| `_drag_compare_panel` | `Control` | Live compare overlay; child of the CanvasLayer, not `_content_root` — survives rebuilds |
| `_cmp_existing` / `_cmp_incoming` | `String` | IDs of the pair currently shown in compare panel; used as a guard to skip redundant rebuilds |

**Layout — three columns:**
- **LEFT (240 px):** Bag inventory. Header row: "BAG" label + `1×/2×` view toggle. Sort row: Name / Type. Search bar. Scrollable `GridContainer` (1 or 2 columns). Each item row is a `PanelContainer` with drag forwarding producing `{"item": dict}`. In compact (2-column) mode: smaller icon (16 px), smaller text (10 px), no stat-bonus sub-line.
- **MIDDLE (530 px):** Three member cards stacked vertically. Each card divided into 4 quadrants by 50%-alpha separators:
  - **TOP-LEFT:** Name (17 px), Class (13 px gold), Background (13 px green), HP bar + label.
  - **TOP-RIGHT:** Derived stats — Speed / Defense / EN Max / EN Regen (blue, 4 cols). Base attributes — STR/DEX/COG/WIL/VIT (yellow, 5 cols). All labels: `tooltip_text` + `MOUSE_FILTER_PASS`.
  - **BOTTOM-LEFT:** "EQUIPMENT" + 2×2 grid. Each slot is a flat `Button` with sprite icon. Drop target via `set_drag_forwarding()`. **Right-click** an occupied slot to unequip. Dragging bag item over a filled slot shows a compare panel. Disabled when dead.
  - **BOTTOM-RIGHT:** "ABILITIES" + 2×2 grid of slotted abilities as `Control` + `Label`. Drop target for abilities from the right panel. **Right-click** to clear. Hovering drag over a filled slot shows a side-by-side compare panel (`_show_drag_compare()`). Dragging one member's ability into another member's slot is blocked (member_idx check in `_can_drop_ability_here()`).
- **RIGHT (480 px):** `TabContainer` per member card:
  - **Abilities tab:** Top bar (right-aligned) with `1×/2×` view toggle + "drag to slot →" hint. Sort row: Name / Type / EN (per-member, independent). Search bar with live filter (focus is restored after each rebuild via `grab_focus.call_deferred()` + `set_caret_column.call_deferred()` to prevent backwards-typing). Scrollable pool list in `VBoxContainer` (1-per-row) or `GridContainer` (2-per-row). Slotted abilities show gold highlight + `●` prefix + `[s1]`–`[s4]` slot badge. In 2-per-row mode the EN/type sub-line is hidden (tooltip still shows it).
  - **Feats tab:** Placeholder label.

**Drag-and-drop:**
- `_can_drop_here(data, slot_type, is_dead)` — validates equipment/consumable type match and liveness.
- `_can_drop_ability_here(data, target_mi, is_dead)` — validates ability drag data and member_idx match (cross-member drops rejected).
- `_drop_to_slot(item, member_idx, slot_field)` — displaces existing occupant to bag, equips new item, calls `GameState.remove_from_inventory()`, then `_rebuild()`.
- `_drop_ability_to_slot(data, target_mi, slot_idx)` — writes ability_id into the live slot array, `_rebuild()`.
- `_unequip_item()` / `_unequip_consumable()` — right-click handlers; same displacement + rebuild pattern.

**Drag compare panels (all three live on the CanvasLayer, not `_content_root`):**
- `_show_drag_compare(near_pos, existing_id, incoming_id)` — ability vs ability (AbilityData).
- `_show_equip_compare(near_pos, cur_eq, incoming)` — existing EquipmentData vs bag item dict.
- `_show_consumable_compare(near_pos, cur_id, incoming)` — existing consumable vs bag item dict.
- All three use shared helpers `_make_compare_panel()`, `_make_compare_col()`, `_add_cmp_label()`, `_add_cmp_desc()`.
- `_clear_drag_compare()` frees the panel and resets `_cmp_existing`/`_cmp_incoming`. Called: on successful drop, on `hide_sheet()`, and automatically by `_process()` when drag ends.

**Tooltip theming:** A `Theme` with a `StyleBoxFlat` for `TooltipPanel` (dark bg, gold border) is set on `_content_root` in `_rebuild()` — overrides Godot's default transparent tooltip. `_wrap_tooltip(text, max_line=40)` word-wraps all tooltip strings while preserving `\n\n` section breaks.

**Map input block:** `MapManager._input()` has an early-return guard: `if _party_sheet != null and _party_sheet.visible: return`. Required because MapManager uses `_input()` (not `_unhandled_input()`); without this guard, map pan/zoom fires through the CanvasLayer overlay.

**Persistence:** All mutations write directly to the live `CombatantData` object in `GameState.party[i]`. `GameState.save()` is NOT called here — MapScene saves on the next map travel. Dead members cannot be equipped (drop rejected, buttons disabled). `_sort_fields`, `_search_texts`, `_abil_views_wide`, etc. are instance vars — they survive `_rebuild()` but reset if the scene is reloaded.

---

## Explicitly Deferred

- Badurga section content — tavern/party-management, bulletin board/quests, and all 4 vendor stalls print `"[Badurga] <id> not yet implemented"` placeholders
- Recruit / Vendor / Event scene content (NodeStub is placeholder)
- Fog of war
