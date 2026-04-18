# System: Game State

> Last updated: 2026-04-18 (Session 12 — Feature 4: Scene Transition Polish + Node Tracking)

---

## Purpose

`GameState` is the **autoload singleton** for run-wide persistent data. It is the single source of truth for anything that needs to survive across scenes — party roster, equipment, currency, map progress, faction reputation.

**Current status: Active.** Map traversal and save/load are live. All other planned data is deferred.

---

## Core File

| File | Autoload Name | Role |
|------|--------------|------|
| `scripts/globals/GameState.gd` | `GameState` | Run-wide persistent data |

Registered as an autoload in `project.godot` so it is accessible from any script as `GameState`.

---

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `SAVE_PATH` | `"user://save.json"` | Godot user data directory — platform-resolved at runtime |

---

## Live Fields & Methods

### Map Progress

| Member | Type | Default | Description |
|--------|------|---------|-------------|
| `player_node_id` | `String` | `"node_o11"` | The node the player is currently on |
| `visited_nodes` | `Array[String]` | `["node_o11"]` | All nodes the player has been to this run |
| `map_seed` | `int` | `0` | RNG seed for `_build_edge_data()`. `0` = not yet seeded (fresh run). Lives here so `load_save()` can restore it before MapManager seeds its RNG. |
| `node_types` | `Dictionary` | `{}` | Maps node id → type string (e.g. `"COMBAT"`, `"BOSS"`, `"CITY"`). Populated by `MapManager._assign_node_types()` on first run; restored from save on subsequent loads. **Saved to disk.** |
| `pending_node_type` | `String` | `""` | Consumed by `NodeStub._ready()` on scene entry to know which stub to display. Set by `MapManager._enter_current_node()` for non-combat/non-city nodes. **NOT saved to disk.** |
| `current_combat_node_id` | `String` | `""` | Set by `MapManager._enter_current_node()` immediately before transitioning to `CombatScene3D`. Read by `EndCombatScreen._on_onward_pressed()` to know which node to append to `cleared_nodes`. **NOT saved to disk** (transient handoff, like `pending_node_type`). |
| `cleared_nodes` | `Array[String]` | `[]` | Nodes where the player completed combat AND collected a reward. Nodes in this array are non-traversable and show a `✗` stamp on the map. **Saved to disk.** |

| Method | Signature | Description |
|--------|-----------|-------------|
| `move_player` | `(node_id: String) -> void` | Updates `player_node_id`; appends to `visited_nodes` if not already there |
| `is_visited` | `(node_id: String) -> bool` | Returns `true` if the node is in `visited_nodes` |
| `is_adjacent_to_player` | `(node_id: String, adjacency: Dictionary) -> bool` | Returns `true` if `node_id` is in the adjacency list for `player_node_id`. The `adjacency` dict is passed in from `MapManager` to keep `GameState` decoupled from map-building data. |

### Save / Load

| Method | Signature | Description |
|--------|-----------|-------------|
| `save` | `() -> void` | Serializes `player_node_id`, `visited_nodes`, `map_seed`, `node_types`, and `cleared_nodes` to `user://save.json` as indented JSON. Called by **MapManager** after every traversal move and after `_assign_node_types()` on first run; also called by **EndCombatScreen** when the player confirms reward collection. |
| `load_save` | `() -> bool` | Reads and deserializes `user://save.json`. Returns `true` if a valid save was found and loaded, `false` on a fresh run or corrupt file. Called by **MapManager** at the start of `_ready()`, before any map data is built. |
| `delete_save` | `() -> void` | Removes `user://save.json` if it exists. Called by **MapManager**'s debug "Delete Save" button before resetting in-memory state. |
| `reset` | `() -> void` | Resets all in-memory fields to fresh-run defaults (`player_node_id = "node_o11"`, `visited_nodes = ["node_o11"]`, `map_seed = 0`, `node_types = {}`, `pending_node_type = ""`, `current_combat_node_id = ""`, `cleared_nodes = []`). Must be called alongside `delete_save()` when wiping a save mid-session. |

---

## Save File Contents

| Key | Corresponds to | Notes |
|-----|---------------|-------|
| `player_node_id` | `GameState.player_node_id` | String |
| `visited_nodes` | `GameState.visited_nodes` | JSON Array — typed back via `Array(..., TYPE_STRING, "", null)` on load |
| `map_seed` | `GameState.map_seed` | int — determines map topology for the run |
| `node_types` | `GameState.node_types` | JSON Object (id → type string) — values already strings from JSON, no conversion needed |
| `cleared_nodes` | `GameState.cleared_nodes` | JSON Array — typed back via `Array(raw, TYPE_STRING, "", null)` on load |

**What is saved now:** map position, visited nodes, map topology seed, node type assignments, cleared (completed) nodes.

Note: `pending_node_type` and `current_combat_node_id` are **not** saved — they are transient handoffs consumed within a single scene transition.

**Deferred (Stage 2+):** party roster, inventory, combat state, faction reputation.

---

## Dependencies

- **MapManager** reads and writes GameState for traversal (`move_player`, `is_visited`, `is_adjacent_to_player`); calls `save()` after every move and after `_assign_node_types()`; calls `load_save()` at startup; calls `delete_save()` + `reset()` from the debug button; sets `pending_node_type` before transitioning to NodeStub; sets `current_combat_node_id` before transitioning to CombatScene3D; reads `cleared_nodes` in `_refresh_all_node_visuals()` and `_on_node_clicked()`
- **NodeStub** reads and clears `GameState.pending_node_type` in `_ready()`
- **EndCombatScreen** reads `current_combat_node_id` and appends to `cleared_nodes` when player collects reward ("Onward..."); calls `GameState.save()` at that point; calls `GameState.add_to_inventory()` stub (no-op currently)

---

## Signals Emitted

None currently.

---

## Planned Responsibilities (Stage 2+)

| Data | Type | Notes |
|------|------|-------|
| Party roster | `Array[UnitData]` | Active + bench units for the run |
| Faction reputation | `Dictionary` | Per-faction standing |
| Currency / resources | `int` | TBD |
| Run flags | `Dictionary` | Misc boolean state |

---

## Notes

- The singleton pattern was chosen so that any scene in the game can access run state without manual node references or signal chains up the tree.
- Do not put **combat-local** state here (selected unit, current turn, etc.) — that belongs in CombatManager. GameState is for data that persists between combat encounters.
- The `adjacency` dict is intentionally passed into `is_adjacent_to_player()` from `MapManager` — GameState should not import or own map topology data.
- `map_seed` lives in GameState (not MapManager) so `load_save()` can restore it before MapManager calls `seed()` in `_build_edge_data()`. MapManager generates the seed on a fresh run (`randi()`) and writes it to `GameState.map_seed` — GameState never generates it.
- **Typed-array conversion:** `JSON.parse_string()` returns untyped `Array`. Any `Array[T]` field must be converted back with `Array(raw, TYPE_*, "", null)` when reading from the save. Apply this pattern for any future typed array fields added to the save.
- **`save()` has no null guard on `FileAccess.open()`** — if `user://` is unwritable (rare on desktop, possible on some platforms), it will crash. Add a null check before `file.store_string()` if this becomes an issue in future platform targets.
- **Field defaults are fresh-run values only** — `player_node_id = "node_o11"` and `visited_nodes = ["node_o11"]` are the GDScript initializers. On any run with a valid save file, `load_save()` overwrites them before anything reads them. Do not rely on these defaults in code that runs after `MapManager._ready()`.
- **GameState persists across `change_scene_to_file()` calls** — as an autoload it is never freed. In-memory fields survive scene transitions without saving; `save()` is called explicitly to persist to disk.
- **`load_save()` does NOT reset fields on a missing file** — it returns `false` immediately if `user://save.json` doesn't exist, leaving all in-memory fields unchanged. This means calling `delete_save()` alone before a scene reload is NOT enough for a clean fresh-run state in a live session; you must also call `reset()` to clear the in-memory fields. If you only delete the file, the player marker and visited state persist in memory for the remainder of the session.
