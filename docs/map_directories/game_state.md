# System: Game State

> Last updated: 2026-04-18 (Session 7 — Map Traversal)

---

## Purpose

`GameState` is the **autoload singleton** for run-wide persistent data. It is the single source of truth for anything that needs to survive across scenes — party roster, equipment, currency, map progress, faction reputation.

**Current status: Partial stub.** Map traversal fields are live. All other planned data is deferred.

---

## Core File

| File | Autoload Name | Role |
|------|--------------|------|
| `scripts/globals/GameState.gd` | `GameState` | Run-wide persistent data |

Registered as an autoload in `project.godot` so it is accessible from any script as `GameState`.

---

## Live Fields & Methods

### Map Progress

| Member | Type | Default | Description |
|--------|------|---------|-------------|
| `player_node_id` | `String` | `"node_o11"` | The node the player is currently on |
| `visited_nodes` | `Array[String]` | `["node_o11"]` | All nodes the player has been to this run |

| Method | Signature | Description |
|--------|-----------|-------------|
| `move_player` | `(node_id: String) -> void` | Updates `player_node_id`; appends to `visited_nodes` if not already there |
| `is_visited` | `(node_id: String) -> bool` | Returns `true` if the node is in `visited_nodes` |
| `is_adjacent_to_player` | `(node_id: String, adjacency: Dictionary) -> bool` | Returns `true` if `node_id` is in the adjacency list for `player_node_id`. The `adjacency` dict is passed in from `MapManager` to keep `GameState` decoupled from map-building data. |

---

## Dependencies

- **MapManager** reads and writes GameState for traversal (move_player, is_visited, is_adjacent_to_player)
- **EndCombatScreen** calls `GameState.add_to_inventory()` stub (no-op currently)

---

## Signals Emitted

None currently.

---

## Planned Responsibilities (Stage 2+)

| Data | Type | Notes |
|------|------|-------|
| Party roster | `Array[UnitData]` | Active + bench units for the run |
| Run seed | `int` | For reproducibility |
| Faction reputation | `Dictionary` | Per-faction standing |
| Currency / resources | `int` | TBD |
| Run flags | `Dictionary` | Misc boolean state |

---

## Notes

- The singleton pattern was chosen so that any scene in the game can access run state without manual node references or signal chains up the tree.
- Do not put **combat-local** state here (selected unit, current turn, etc.) — that belongs in CombatManager. GameState is for data that persists between combat encounters.
- The `adjacency` dict is intentionally passed into `is_adjacent_to_player()` from `MapManager` — GameState should not import or own map topology data.
- **State is not persisted between scene changes.** `player_node_id` and `visited_nodes` reset to their defaults every time the game boots or the scene tree is reloaded. Feature 3 (scene transitions from map → combat → map) will require saving and restoring these values; do not assume they survive a `change_scene_to_file()` call.
