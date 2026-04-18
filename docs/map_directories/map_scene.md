# Map Scene

## Purpose

`MapScene.tscn` + `MapManager.gd` display the world map as a static, interactive spider-web of nodes. This is the top-level navigation screen the player will return to between encounters. In the current build it is a **visual-only prototype**: no traversal logic, no GameState reads/writes, no scene transitions beyond the debug shortcut.

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
| `label` | `String` | Display name shown on hover (e.g. `"Ashwood Hollow"`) |
| `is_hub` | `bool` | `true` only for Badurga (center node) |
| `is_player_start` | `bool` | `true` for exactly one node (current: `"The Last Waypost"`, outer ring) |

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

---

## Rendering

| Element | Implementation |
|---|---|
| Background | `ColorRect` 1280×720, `Color(0.82, 0.74, 0.58)` (parchment) |
| Edges | `Line2D` nodes, `Color(0.55, 0.42, 0.28)`, width 3 px |
| Normal nodes | `Button` with `StyleBoxFlat` circle, `Color(0.72, 0.60, 0.44)`, size 32×32 |
| Hub (Badurga) | `Button` with `StyleBoxFlat` circle, `Color(0.85, 0.65, 0.25)` (gold), size 56×56 |
| All node borders | 2 px, `Color(0.25, 0.18, 0.10)` |
| Layer order | ColorRect → Line2Ds → Buttons → player marker → hover label |

---

## Player Marker

A `Polygon2D` diamond (4 points ±10 px) in `Color(0.3, 0.6, 1.0)` (blue), centered 26 px above the player-start node. Stored as `_player_marker: Polygon2D`.

---

## Hover Behavior

Uses a **single shared `Label`** (`_hover_label`) repositioned on each hover event.

| Event | Behavior |
|---|---|
| `mouse_entered` | Tween scale → `Vector2(1.25, 1.25)` over 0.12 s; show `_hover_label` centered 6 px below the node |
| `mouse_exited` | Tween scale → `Vector2(1.0, 1.0)` over 0.10 s; hide `_hover_label` |
| Hub hover enter | Same scale tween + tint `StyleBoxFlat.bg_color` to `Color(1.0, 0.85, 0.4)` over 0.12 s |
| Hub hover exit | Tint returns to `Color(0.85, 0.65, 0.25)` over 0.10 s |

---

## Debug Elements (temporary)

| Element | Purpose |
|---|---|
| `"[MAP SCENE]"` label (top-left) | Visual confirmation of scene load |
| `"→ Combat (debug)"` button (top-right) | Loads `res://scenes/combat/CombatScene3D.tscn` — will be removed in Feature 4 |

---

## Node Clicks

`_on_node_clicked(node_id)` prints `"Clicked: <id>"` to console. No other effect.

---

## Pan & Zoom

All map content lives in a `_map_container: Node2D` child. The background and UI chrome (placeholder label, debug button) are fixed children of the root and do not move.

| Action | Behavior |
|---|---|
| LMB hold + drag | Pans the container (`_map_container.position`) |
| Scroll wheel up/down | Zooms in/out (range 0.35 – 2.5), pivoted on the cursor position |

Pan and zoom use `_input()` (not `_unhandled_input`) so drag is captured even when the initial press lands on a node Button. A `_drag_moved: bool` flag (true when drag delta > 4 px) prevents node click callbacks from firing on a drag release.

## Edge Layout (no crossing edges)

Inter-ring connections use **stratified random gateways** — randomized on every scene load:

| Connection | Method |
|---|---|
| Within each ring | Closed chain of adjacent neighbors only — no chords |
| Hub → inner | 2 randomly shuffled inner nodes |
| Inner → middle | 3 gateways: circle divided into 3 sectors, one random angle per sector, closest node in each ring connected |
| Middle → outer | Same 3-gateway stratified approach |

Using closest-to-angle for both sides of a gateway keeps inter-ring edges roughly radial, preventing crossing between gateways. The stratified sampling prevents gateway clustering. The result is 2-3 bottleneck passages between each ring pair, different each run.

## Explicitly Deferred

- Traversal logic and movement restrictions
- Node types / encounter categories
- GameState reads or writes
- Scene transitions on node click
- Procedural generation of the map
- Fog of war / locked nodes
- Save/load of map state
