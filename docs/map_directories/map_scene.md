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
| `label` | `String` | Display name shown on hover (e.g. `"Ashwood Hollow"`) |
| `is_hub` | `bool` | `true` only for Badurga (center node) |
| `is_player_start` | `bool` | `true` for exactly one node (current: `"The Last Waypost"`, outer ring) |
| `stamp_added` | `bool` | `true` after the visited ✓ stamp Label has been added as a button child |

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

Before any random call in `_build_edge_data()`, the RNG is seeded from `GameState.map_seed`. On a fresh run `GameState.map_seed` is `0`, so MapManager generates a seed via `randi()` and stores it; on subsequent loads the saved seed is restored first. This makes the map topology identical across sessions for a given run.

---

## Adjacency Lookup

Built in `_build_adjacency()` after `_build_edge_data()`. Stored in `_adjacency: Dictionary` (id → `Array[String]`). Each edge is added in both directions (undirected graph). Used by `GameState.is_adjacent_to_player()`.

---

## Rendering

| Element | Implementation |
|---|---|
| Background | `ColorRect` 1280×720, `Color(0.82, 0.74, 0.58)` (parchment) |
| Edges | `Line2D` nodes, `Color(0.55, 0.42, 0.28)`, width 3 px |
| Normal nodes | `Button` with `StyleBoxFlat` circle, `Color(0.72, 0.60, 0.44)`, size 32×32 |
| Hub (Badurga) | `Button` with `StyleBoxFlat` circle, `Color(0.85, 0.65, 0.25)` (gold), size 56×56 |
| All node borders | 2 px default, `Color(0.25, 0.18, 0.10)` |
| Layer order | ColorRect → Line2Ds → Buttons → player marker → hover label |

---

## Player Marker

A `Polygon2D` diamond (4 points ±10 px) in `Color(0.3, 0.6, 1.0)` (blue), centered 26 px above the current node. Stored as `_player_marker: Polygon2D`. On traversal it tweens to the new node position over 0.25 s (TRANS_QUAD, EASE_IN_OUT).

Initial placement at scene load uses `GameState.player_node_id` (which may have been restored by `load_save()`), not the static `is_player_start` flag on the node dict. The `is_player_start` field is kept on node dicts for future run-reset logic but does not drive marker placement.

---

## Node Visual States

Applied by `_refresh_all_node_visuals()`, called at end of `_build_scene()` and after each traversal move.

| State | Condition | bg_color | Border | Modulate |
|---|---|---|---|---|
| **CURRENT** | `id == GameState.player_node_id` | base color | gold `Color(0.9, 0.85, 0.3)`, 3 px | `(1,1,1,1)` |
| **REACHABLE** | adjacent to current node | base color | default `Color(0.25, 0.18, 0.10)`, 2 px | `(1,1,1,1)` |
| **VISITED** | in `GameState.visited_nodes` (and not current) | `base.darkened(0.35)` | default, 2 px | `(1,1,1,0.85)` |
| **LOCKED** | none of the above | `base.darkened(0.15)` | default, 2 px | `(1,1,1,0.5)` |

Visited nodes also receive a small `✓` Label child (stamp). The stamp is added once — `nd["stamp_added"]` prevents duplicates.

---

## Traversal

`_on_node_clicked(node_id)` gates movement:

1. Ignored if `_drag_moved` (click was part of a pan)
2. Ignored if `node_id == GameState.player_node_id` (already here)
3. Ignored if `not GameState.is_adjacent_to_player(node_id, _adjacency)` (not reachable)
4. Otherwise calls `_move_player_to(node_id)`

`_move_player_to(node_id)`:
- Calls `GameState.move_player(node_id)` (updates player position + visited list)
- Calls `GameState.save()` (persists position + visited list + map seed to disk)
- Tweens `_player_marker.position` to `node_map[node_id]["position"] + Vector2(0, -26)` over 0.25 s
- Calls `_refresh_all_node_visuals()`

`_ready()` order after save/load integration:
1. `GameState.load_save()` — restore saved state (or no-op on fresh run)
2. `_build_node_data()` — define all 28 nodes
3. `_build_edge_data()` — seed RNG from `GameState.map_seed`, build deterministic edges
4. `_build_adjacency()` — build undirected adjacency dict
5. `_build_scene()` — render everything; marker placed at `GameState.player_node_id`

---

## Hover Behavior

Uses a **single shared `Label`** (`_hover_label`) repositioned on each hover event.

| Event | Behavior |
|---|---|
| `mouse_entered` | Skip entirely if node is LOCKED; otherwise tween scale → `Vector2(1.25, 1.25)` over 0.12 s; show `_hover_label` centered 6 px below the node |
| `mouse_exited` | Tween scale → `Vector2(1.0, 1.0)` over 0.10 s; hide `_hover_label` |
| Hub hover enter | Same scale tween + tint `StyleBoxFlat.bg_color` to `Color(1.0, 0.85, 0.4)` over 0.12 s |
| Hub hover exit | Tint returns to `Color(0.85, 0.65, 0.25)` over 0.10 s |

LOCKED nodes feel inert — no scale animation, no label.

---

## Debug Elements (temporary)

| Element | Purpose |
|---|---|
| `"[MAP SCENE]"` label (top-left) | Visual confirmation of scene load |
| `"→ Combat (debug)"` button (top-right) | Loads `res://scenes/combat/CombatScene3D.tscn` — will be removed in Feature 4 |

---

## Pan & Zoom

All map content lives in a `_map_container: Node2D` child. The background and UI chrome (placeholder label, debug button) are fixed children of the root and do not move.

| Action | Behavior |
|---|---|
| LMB hold + drag | Pans the container (`_map_container.position`) |
| Scroll wheel up/down | Zooms in/out (range 0.35 – 2.5), pivoted on the cursor position |

Pan and zoom use `_input()` (not `_unhandled_input`) so drag is captured even when the initial press lands on a node Button. A `_drag_moved: bool` flag (true when drag delta > 4 px) prevents node click callbacks from firing on a drag release.

## Edge Layout (no crossing edges)

Inter-ring connections use **stratified random gateways** — topology is fixed per run (seeded from `GameState.map_seed`), so the same layout reloads identically across sessions:

| Connection | Method |
|---|---|
| Within each ring | Closed chain of adjacent neighbors only — no chords |
| Hub → inner | 2 randomly shuffled inner nodes |
| Inner → middle | 3 gateways: circle divided into 3 sectors, one random angle per sector, closest node in each ring connected |
| Middle → outer | Same 3-gateway stratified approach |

Using closest-to-angle for both sides of a gateway keeps inter-ring edges roughly radial, preventing crossing between gateways. The stratified sampling prevents gateway clustering. The result is 2-3 bottleneck passages between each ring pair, different each run but identical across saves within the same run.

## Entry Point

`MapScene.tscn` is **not** the game entry point. `main.tscn` boots directly into `CombatScene3D.tscn`. The only path to the map is the `"→ Combat (debug)"` button in the map itself, which exits to combat — there is no reverse route yet. Feature 3 will wire up the actual entry flow.

---

## Gotchas

- **`hover_style` is not updated by `_refresh_all_node_visuals()`** — it is a snapshot duplicate of `normal_style` made at build time (`style.duplicate()`). When `_refresh_all_node_visuals()` darkens `normal_style.bg_color` for VISITED or LOCKED nodes, the hover stylebox still lightens from the original base color. This is acceptable for now but means hover tint does not respect the dimmed state. Fix by also updating `hover_style.bg_color` in `_refresh_all_node_visuals()` if that ever becomes an issue.
- **`_input()` not `_unhandled_input()`** — intentional so pan drag is captured even when a press starts on a Button node. Do not change this without accounting for that.
- **Node dict is mutated at runtime** — `nd["stamp_added"]` is set to `true` the first time a visited stamp is added. The dict is the same object in both `_node_data` and `_node_map`, so the mutation is shared.
- **`stamp_added` is not persisted** — it's a runtime-only flag to prevent double-stamping within a session. On every scene load the flag starts `false`, and `_refresh_all_node_visuals()` re-adds stamps for all restored visited nodes correctly. Do not add `stamp_added` to the save file.
- **MapManager holds no persistent state** — all run-wide data lives in `GameState`. On every scene load, `MapManager` fully rebuilds nodes, edges, adjacency, and the scene tree from scratch. Data survives because `GameState` is an autoload singleton (and is backed by `save.json`). Do not try to persist data inside `MapManager` fields directly.
- **`seed()` is a global call** — `_build_edge_data()` calls Godot's global `seed()` function, which affects all subsequent uses of the global RNG. Currently no other system shares that RNG path, but if future code uses `randf()`/`randi()` anywhere after scene load it will be seeded by the map seed. Use `RandomNumberGenerator` instances if independent RNG streams are needed.

---

## Explicitly Deferred

- Node types / encounter categories
- Scene transitions on node click (launch encounter)
- Procedural generation of the map layout
- Fog of war
