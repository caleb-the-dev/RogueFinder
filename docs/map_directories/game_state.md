# System: Game State

> Last updated: 2026-04-18 (Session 9 — Save/Load System)

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

| Method | Signature | Description |
|--------|-----------|-------------|
| `move_player` | `(node_id: String) -> void` | Updates `player_node_id`; appends to `visited_nodes` if not already there |
| `is_visited` | `(node_id: String) -> bool` | Returns `true` if the node is in `visited_nodes` |
| `is_adjacent_to_player` | `(node_id: String, adjacency: Dictionary) -> bool` | Returns `true` if `node_id` is in the adjacency list for `player_node_id`. The `adjacency` dict is passed in from `MapManager` to keep `GameState` decoupled from map-building data. |

### Save / Load

| Method | Signature | Description |
|--------|-----------|-------------|
| `save` | `() -> void` | Serializes `player_node_id`, `visited_nodes`, and `map_seed` to `user://save.json` as indented JSON. Called by **MapManager** after every traversal move — callers control save timing, not GameState internally. |
| `load_save` | `() -> bool` | Reads and deserializes `user://save.json`. Returns `true` if a valid save was found and loaded, `false` on a fresh run or corrupt file. Called by **MapManager** at the start of `_ready()`, before any map data is built. |
| `delete_save` | `() -> void` | Removes `user://save.json` if it exists. Available for new-game resets; no callers yet. |

---

## Save File Contents

| Key | Corresponds to | Notes |
|-----|---------------|-------|
| `player_node_id` | `GameState.player_node_id` | String |
| `visited_nodes` | `GameState.visited_nodes` | JSON Array — typed back via `Array(..., TYPE_STRING, "", null)` on load |
| `map_seed` | `GameState.map_seed` | int — determines map topology for the run |

**What is saved now:** map position, visited nodes, map topology seed.

**Deferred (Stage 2+):** party roster, inventory, combat state, faction reputation.

---

## Dependencies

- **MapManager** reads and writes GameState for traversal (`move_player`, `is_visited`, `is_adjacent_to_player`) and calls `save()` after every move and `load_save()` at startup
- **EndCombatScreen** calls `GameState.add_to_inventory()` stub (no-op currently)

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
